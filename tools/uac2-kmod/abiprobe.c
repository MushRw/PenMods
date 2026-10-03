/*
 * PenMods —— ABI 探针（内核结构体真实字段偏移的测量工具）
 *
 * 为什么需要它
 * ------------
 * 设备内核是「4.4.159 + 厂商补丁」的树，而我们的模块是用上游 4.4.159 头文件
 * 编的。两者的结构体布局**在若干处不一致**，后果实测为：
 *   - struct module: 内核读到的 mod->init 是 0，直接跳过 init 调用
 *   - struct usb_function_instance: configfs mkdir 时 function_make() 从偏移
 *     160 处读到一个"函数指针"，实际读到的是我们 p_chmask/p_srate 两个 int
 *     （0x0000bb80_00000003）⇒ 跳到垃圾地址 ⇒ oops ⇒ panic_on_oops=1 ⇒ 重启
 *
 * 光靠猜是没用的。这里用「**硬测量**」：调用内核自己的初始化函数
 * （它们按**内核自己的**偏移往我们提供的内存里写字段），然后扫描那块内存里的
 * 特征值，反推出内核的真实字段偏移。全程只碰自己 kzalloc 的那块内存：
 *   - 不注册任何 function / 驱动 / configfs 项
 *   - 不碰 USB、不碰 UDC、不碰 ALSA
 *   - 不写任何持久化路径
 * 因此可以放心 insmod/rmmod（不需要重启设备）。
 *
 * 用法：insmod abiprobe.ko ; dmesg | grep penmods-abiprobe ; rmmod abiprobe
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/err.h>
#include <linux/configfs.h>
#include <linux/usb/composite.h>
#include <linux/device.h>
#include <linux/platform_device.h>	/* sizeof(struct platform_device) 需要完整类型 */
#include <sound/core.h>			/* struct snd_pcm 布局（2026-10-03 aplay oops） */
#include <sound/pcm.h>

#define ABIPROBE_BUFSZ 512
#define ABIPROBE_NAME  "PMABIPROBE"

/* 扫描「自指的 list_head」：INIT_LIST_HEAD 后 next == prev == &自己。
 * 内核按自己的偏移初始化 cg_children / default_groups，
 * 扫出来的位置即内核真实的 offsetof(字段)。 */
static void abiprobe_scan_selflist(const char *tag, void *buf, int n)
{
	unsigned long base = (unsigned long)buf;
	int i;

	for (i = 0; i + 16 <= n; i += 8) {
		unsigned long *p = (unsigned long *)(base + i);

		if (p[0] == base + i && p[1] == base + i)
			pr_info("penmods-abiprobe: [KERNEL] %s: 自指 list_head @ %d\n",
				tag, i);
	}
}

/* 找字符串出现的位置（内核写 ci_namebuf 的位置） */
static int abiprobe_find_str(void *buf, int n, const char *needle)
{
	int len = (int)strlen(needle) + 1;
	int i;

	for (i = 0; i + len <= n; i++)
		if (!memcmp((char *)buf + i, needle, len))
			return i;
	return -1;
}

/* 找「值等于某个地址」的 8 字节字（内核把 ci_name 指向 ci_namebuf） */
static void abiprobe_find_ptr(const char *tag, void *buf, int n, unsigned long want)
{
	unsigned long base = (unsigned long)buf;
	int i;

	for (i = 0; i + 8 <= n; i += 8) {
		if (*(unsigned long *)(base + i) == want)
			pr_info("penmods-abiprobe: [KERNEL] %s: 指向 0x%lx 的指针 @ %d\n",
				tag, want, i);
	}
}

/* ── 运行时反查：解码**内核自己**的 usb_put_function_instance 机器码 ──────────
 *
 * 为什么值得做：`BUILD_BUG_ON` 只能证明"**我们的头文件**自洽"，证明不了
 * "**内核和我们**对上了"。而这次踩的两次坑，恰恰都是后者错、前者过。
 * 最可靠的 ground truth 是内核自己的机器码 —— 平时看不到，但 oops 现场会带。
 * 这里在**正常运行时**把它读出来（零风险：只读内核 .text，不写、不注册）。
 *
 * 4.4 的 `usb_put_function_instance()` 只做 4 件事：
 *     if (!fi) return;
 *     mod = fi->fd->mod;
 *     fi->free_func_inst(fi);
 *     module_put(mod);
 * ⇒ 机器码里必然有两条 `ldr xN, [x0, #imm]`（x0 = fi），
 *   它们的 imm 就是内核认为的 offsetof(fd) 和 offsetof(free_func_inst)。
 *   和我们头文件里的 offsetof 一比，立刻知道内核侧对不对。
 *
 * 设备实测（见 CI 里 composite.h 补丁的注释）：
 *     ldr x2, [x0, #128]   ; fi->fd
 *     ldr x1, [x0, #152]   ; fi->free_func_inst
 *
 * kallsyms_lookup_name 在 4.4 是 EXPORT_SYMBOL_GPL；用 weak 引用，
 * 万一某内核不导出也不会让编译/加载失败，只会打印"不可用"。
 */
extern unsigned long kallsyms_lookup_name(const char *name)
	__attribute__((weak));

static void abiprobe_check_kernel_code(const char *fname)
{
	const u32 *p;
	unsigned long addr;
	int i, found = 0, offs[4];

	pr_info("penmods-abiprobe: ============ 内核自己怎么读这个结构体 ============\n");
	if (!kallsyms_lookup_name) {
		pr_info("penmods-abiprobe: [内核码] kallsyms_lookup_name 不可用，跳过\n");
		return;
	}
	addr = kallsyms_lookup_name(fname);
	if (!addr) {
		pr_info("penmods-abiprobe: [内核码] 找不到 %s\n", fname);
		return;
	}
	pr_info("penmods-abiprobe: [内核码] %s @ 0x%lx\n", fname, addr);

	p = (const u32 *)addr;
	for (i = 0; i < 24 && found < 4; i++) {
		u32 w = p[i];
		int imm;

		/* LDR (immediate, unsigned offset), 64-bit：
		 *   11 111 0 01 01 imm12 Rn Rt   ⇒ 掩码 bits[31:22] == 0xF9400000/2^22 */
		if ((w & 0xFFC00000) != 0xF9400000)
			continue;
		if (((w >> 5) & 0x1F) != 0)	/* Rn 必须是 x0（= fi） */
			continue;
		imm = (int)(((w >> 10) & 0xFFF) * 8);
		offs[found++] = imm;
		pr_info("penmods-abiprobe: [内核码]   +0x%02x: ldr x%u, [x0, #%d]\n",
			i * 4, w & 0x1F, imm);
	}

	if (found < 2) {
		pr_info("penmods-abiprobe: [内核码] ⚠️ 只扫到 %d 条 ldr xN,[x0,#imm]"
			"（编译器换了写法？）—— 不作结论\n", found);
		return;
	}
	/* 源码顺序：先 fd，后 free_func_inst */
	if (offs[0] == (int)offsetof(struct usb_function_instance, fd) &&
	    offs[1] == (int)offsetof(struct usb_function_instance, free_func_inst))
		pr_info("penmods-abiprobe: [内核码] ✅ 内核按 fd=%d / free_func_inst=%d 读，"
			"与我们头文件的 %d / %d 完全一致\n",
			offs[0], offs[1],
			(int)offsetof(struct usb_function_instance, fd),
			(int)offsetof(struct usb_function_instance, free_func_inst));
	else
		pr_info("penmods-abiprobe: [内核码] ❌ 偏移不一致！内核用 %d / %d，"
			"我们头文件是 %d / %d ⇒ **绝对不要**再往下建 uac2 function，"
			"先把这两个偏移对齐\n",
			offs[0], offs[1],
			(int)offsetof(struct usb_function_instance, fd),
			(int)offsetof(struct usb_function_instance, free_func_inst));
}

/* ── uac2 function instance 往返测试（零 configfs mkdir / 零 USB / 零 UDC）────
 *
 * 目的：把 `mkdir functions/uac2.0` 里**唯一真正危险的那段路径**单独跑一遍，
 * 但不创建任何 configfs 目录、不碰 UDC ⇒ 随时可以撤销、不会影响 adb。
 *
 *   ① usb_get_function_instance("uac2")
 *        内核按**它自己的**偏移读 usb_function_driver.alloc_inst（我们的代码）
 *        → 我们的 uac2_alloc_inst() 分配 f_uac2_opts，并调
 *          config_group_init_type_name(&fi->group, "uac2", &uac2_func_type)
 *          —— **内核按它自己的偏移往我们这块内存里写 config_group 的字段**
 *   ② usb_put_function_instance(fi)
 *        → 内核按**它自己的**偏移读 fi->free_func_inst 并调用
 *
 * 两处都是"内核用自己的偏移读/写我们的结构体"。布局一旦不对就是当场 oops，
 * 而设备 panic_on_oops=1 ⇒ 立刻重启。反过来说：
 * **"跑完没崩 + 两条日志都在 + rmmod rc=0" 就是 configfs/usb_function_instance
 *   ABI 正确的强判据**，而且比 mkdir 更早、更安全地暴露问题。
 *
 * 用 __attribute__((weak)) 引用符号：万一内核没导出它们，也不会编译/链接失败，
 * 只会打印"符号不可用"。
 */
extern struct usb_function_instance *usb_get_function_instance(const char *name)
	__attribute__((weak));
extern void usb_put_function_instance(struct usb_function_instance *fi)
	__attribute__((weak));

static void abiprobe_uac2_roundtrip(void)
{
	struct usb_function_instance *fi;

	pr_info("penmods-abiprobe: ================= uac2 往返测试 =================\n");
	if (!usb_get_function_instance || !usb_put_function_instance) {
		pr_info("penmods-abiprobe: [uac2] 符号未导出，跳过往返测试\n");
		return;
	}

	fi = usb_get_function_instance("uac2");
	if (IS_ERR(fi)) {
		pr_info("penmods-abiprobe: [uac2] 拿不到实例 err=%ld "
			"（-19=ENODEV ⇒ usb_uac2.ko 没加载，或它的 init 没被执行）\n",
			(long)PTR_ERR(fi));
		return;
	}

	pr_info("penmods-abiprobe: [uac2] 拿到实例 OK ⇒ usb_uac2 的 init 确实注册了 uac2\n");
	pr_info("penmods-abiprobe: [uac2] ours: sizeof(usb_function_instance)=%d "
		"fd=%d set_inst_name=%d free_func_inst=%d\n",
		(int)sizeof(struct usb_function_instance),
		(int)offsetof(struct usb_function_instance, fd),
		(int)offsetof(struct usb_function_instance, set_inst_name),
		(int)offsetof(struct usb_function_instance, free_func_inst));

	usb_put_function_instance(fi);
	pr_info("penmods-abiprobe: [uac2] put 往返成功 —— 内核按它的偏移读到了我们的 "
		"free_func_inst，ABI 自洽\n");
}

/* ── struct device 布局探测（2026-09-27 的 oops 逼出来的）──────────────────
 *
 * 事故：把 uac2.0 link 进 configs/b.1 并绑 UDC 时炸在
 *     afunc_bind() → platform_device_register() → platform_device_add()
 *     → device_add() → sysfs_create_groups() → internal_create_group()
 *     Unable to handle kernel paging request at virtual address a9be7bfdd65f03d8
 * 即：内核从 `dev->groups` 读到一个垃圾指针（里面是 `ret` 的指令编码
 * d65f03c0），说明 **offsetof(struct device, groups) 两边不一致**。
 *
 * 为什么 mkdir/rmdir 一路平安：4.4 的 f_uac2 把 platform_device 的创建放在
 * `afunc_bind()` 里，只有 function 真正 bind（link + 绑 UDC）才走到那里。
 *
 * 为什么难对齐：`struct device` 是 Kconfig 影响最多的结构体之一
 * （CONFIG_PM / NUMA / ACPI / DMA_CMA / IOMMU / PINCTRL ...），而我们 CI 用的是
 * **上游 arm64 defconfig**，设备是厂商定制 config（且 /proc/config.gz 没开，
 * 拿不到真 config）。
 *
 * 探测手法：`device_add()` 里必然有一句
 *     sysfs_create_groups(&dev->kobj, dev->groups);
 * ⇒ 在它的机器码里找到 `bl sysfs_create_groups`，把它前面十几条指令打出来：
 *   其中 `ldr xN, [dev寄存器, #imm]` 的 imm 就是内核认为的 offsetof(groups)，
 *   `add xN, dev寄存器, #imm` 的 imm 是 offsetof(kobj)（可交叉验证）。
 * 全程**只读内核 .text**，不写、不注册、不碰 USB/UDC/ALSA ⇒ 可放心 insmod。
 */
static void abiprobe_dump_insns(const u32 *p, int from, int to, const char *tag)
{
	int i;

	for (i = from; i <= to; i++) {
		u32 w = p[i];

		if ((w & 0xFFC00000) == 0xF9400000) {		/* ldr xN,[xM,#imm] */
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: ldr x%u, [x%u, #%lu]\n",
				tag, i * 4, w & 0x1F, (w >> 5) & 0x1F,
				(unsigned long)(((w >> 10) & 0xFFF) * 8));
		} else if ((w & 0xFFC00000) == 0xF9000000) {	/* str xN,[xM,#imm] */
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: str x%u, [x%u, #%lu]\n",
				tag, i * 4, w & 0x1F, (w >> 5) & 0x1F,
				(unsigned long)(((w >> 10) & 0xFFF) * 8));
		} else if ((w & 0xFF800000) == 0x91000000) {	/* add xN,xM,#imm */
			unsigned long imm = (w >> 10) & 0xFFF;

			if (w & 0x00400000)			/* sh=1 ⇒ imm << 12 */
				imm <<= 12;
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: add x%u, x%u, #%lu\n",
				tag, i * 4, w & 0x1F, (w >> 5) & 0x1F, imm);
		} else if ((w & 0xFFE0FFE0) == 0xAA0003E0) {	/* mov xN, xM */
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: mov x%u, x%u\n",
				tag, i * 4, w & 0x1F, (w >> 16) & 0x1F);
		} else if ((w & 0xFC000000) == 0x94000000) {	/* bl */
			int o26 = w & 0x03FFFFFF;

			if (o26 & 0x02000000)
				o26 |= (int)~0x03FFFFFF;
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: bl %+d\n",
				tag, i * 4, o26 * 4);
		} else if (w == 0xD65F03C0) {
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: ret\n", tag, i * 4);
		} else {
			pr_info("penmods-abiprobe: [dev] %s +0x%03x: .word 0x%08x\n",
				tag, i * 4, w);
		}
	}
}

#define ABIPROBE_DEV_SCAN_INSNS 430	/* device_add 约 0x514 字节，够覆盖 */

static void abiprobe_check_device_add(void)
{
	const u32 *p;
	unsigned long addr, scg;
	int i, hits = 0;

	pr_info("penmods-abiprobe: ============== struct device 布局探测 ==============\n");
	if (!kallsyms_lookup_name) {
		pr_info("penmods-abiprobe: [dev] kallsyms_lookup_name 不可用，跳过\n");
		return;
	}

	pr_info("penmods-abiprobe: [dev] ours: sizeof(struct device)=%d "
		"sizeof(struct platform_device)=%d\n",
		(int)sizeof(struct device), (int)sizeof(struct platform_device));
	pr_info("penmods-abiprobe: [dev] ours: kobject=%d mutex=%d dev_pm_info=%d\n",
		(int)sizeof(struct kobject), (int)sizeof(struct mutex),
		(int)sizeof(struct dev_pm_info));
	pr_info("penmods-abiprobe: [dev] ours: parent=%d p=%d kobj=%d init_name=%d type=%d\n",
		(int)offsetof(struct device, parent), (int)offsetof(struct device, p),
		(int)offsetof(struct device, kobj), (int)offsetof(struct device, init_name),
		(int)offsetof(struct device, type));
	pr_info("penmods-abiprobe: [dev] ours: mutex=%d bus=%d driver=%d platform_data=%d "
		"driver_data=%d power=%d pm_domain=%d\n",
		(int)offsetof(struct device, mutex), (int)offsetof(struct device, bus),
		(int)offsetof(struct device, driver),
		(int)offsetof(struct device, platform_data),
		(int)offsetof(struct device, driver_data),
		(int)offsetof(struct device, power),
		(int)offsetof(struct device, pm_domain));
#ifdef CONFIG_GENERIC_MSI_IRQ_DOMAIN
	pr_info("penmods-abiprobe: [dev] ours: msi_domain=%d\n",
		(int)offsetof(struct device, msi_domain));
#endif
#ifdef CONFIG_PINCTRL
	pr_info("penmods-abiprobe: [dev] ours: pins=%d\n",
		(int)offsetof(struct device, pins));
#endif
#ifdef CONFIG_GENERIC_MSI_IRQ
	pr_info("penmods-abiprobe: [dev] ours: msi_list=%d\n",
		(int)offsetof(struct device, msi_list));
#endif
#ifdef CONFIG_NUMA
	pr_info("penmods-abiprobe: [dev] ours: numa_node=%d\n",
		(int)offsetof(struct device, numa_node));
#endif
	pr_info("penmods-abiprobe: [dev] ours: dma_mask=%d coherent=%d dma_pfn_offset=%d "
		"dma_parms=%d dma_pools=%d dma_mem=%d\n",
		(int)offsetof(struct device, dma_mask),
		(int)offsetof(struct device, coherent_dma_mask),
		(int)offsetof(struct device, dma_pfn_offset),
		(int)offsetof(struct device, dma_parms),
		(int)offsetof(struct device, dma_pools),
		(int)offsetof(struct device, dma_mem));
#ifdef CONFIG_DMA_CMA
	pr_info("penmods-abiprobe: [dev] ours: cma_area=%d\n",
		(int)offsetof(struct device, cma_area));
#endif
	pr_info("penmods-abiprobe: [dev] ours: of_node=%d fwnode=%d devt=%d id=%d "
		"devres_lock=%d devres_head=%d knode_class=%d\n",
		(int)offsetof(struct device, of_node),
		(int)offsetof(struct device, fwnode),
		(int)offsetof(struct device, devt),
		(int)offsetof(struct device, id),
		(int)offsetof(struct device, devres_lock),
		(int)offsetof(struct device, devres_head),
		(int)offsetof(struct device, knode_class));
	pr_info("penmods-abiprobe: [dev] ours: ★class=%d groups=%d release=%d iommu_group=%d\n",
		(int)offsetof(struct device, class),
		(int)offsetof(struct device, groups),
		(int)offsetof(struct device, release),
		(int)offsetof(struct device, iommu_group));
	/* #ifdef 状态：一眼看出哪一项与设备内核不一致 */
#ifdef CONFIG_PINCTRL
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_PINCTRL=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_PINCTRL=n\n");
#endif
#ifdef CONFIG_DMA_CMA
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_DMA_CMA=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_DMA_CMA=n\n");
#endif
#ifdef CONFIG_GENERIC_MSI_IRQ
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_GENERIC_MSI_IRQ=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_GENERIC_MSI_IRQ=n\n");
#endif
#ifdef CONFIG_GENERIC_MSI_IRQ_DOMAIN
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_GENERIC_MSI_IRQ_DOMAIN=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_GENERIC_MSI_IRQ_DOMAIN=n\n");
#endif
#ifdef CONFIG_NUMA
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_NUMA=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_NUMA=n\n");
#endif
#ifdef CONFIG_PM_SLEEP
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_PM_SLEEP=y\n");
#else
	pr_info("penmods-abiprobe: [dev] ours: CONFIG_PM_SLEEP=n\n");
#endif

	addr = kallsyms_lookup_name("device_add");
	scg  = kallsyms_lookup_name("sysfs_create_groups");
	if (!addr || !scg) {
		pr_info("penmods-abiprobe: [dev] 符号缺失：device_add=0x%lx "
			"sysfs_create_groups=0x%lx\n", addr, scg);
		return;
	}
	pr_info("penmods-abiprobe: [dev] device_add @ 0x%lx，sysfs_create_groups @ 0x%lx\n",
		addr, scg);

	p = (const u32 *)addr;
	for (i = 0; i < ABIPROBE_DEV_SCAN_INSNS; i++) {
		u32 w = p[i];
		int o26;
		unsigned long tgt;

		if ((w & 0xFC000000) != 0x94000000)
			continue;
		o26 = w & 0x03FFFFFF;
		if (o26 & 0x02000000)
			o26 |= (int)~0x03FFFFFF;
		tgt = (unsigned long)(p + i) + ((long)o26 * 4);
		if (tgt != scg)
			continue;
		hits++;
		pr_info("penmods-abiprobe: [dev] ★ bl sysfs_create_groups @ +0x%x，"
			"前 14 条指令：\n", i * 4);
		abiprobe_dump_insns(p, (i >= 14) ? i - 14 : 0, i, "dev");
	}
	if (!hits)
		pr_info("penmods-abiprobe: [dev] ⚠️ 未找到 bl sysfs_create_groups"
			"（扫了 %d 条指令）\n", ABIPROBE_DEV_SCAN_INSNS);

	/* ── 把 device_add 里**所有** [x19, #imm] 的访问打出来 ──────────────
	 * x19 在 device_add 里就是 dev —— 已由三条访问交叉证实：
	 *     [x19,#88]  = dev->type    （与我们一致）
	 *     [x19,#752] = dev->class   （我们 744）
	 *     [x19,#760] = dev->groups  （我们 752）
	 * 把这些偏移逐一与我们编译的成员表对照，就能**定位差异落在哪一段**
	 * —— 是关键区间的某个 #ifdef 成员，还是 struct dev_pm_info 内部差了。 */
	pr_info("penmods-abiprobe: [dev] device_add 里所有 [x19, #imm] 访问（x19 = dev）：\n");
	{
		int cnt = 0;
		int j;

		for (j = 0; j < ABIPROBE_DEV_SCAN_INSNS; j++) {
			u32 w = p[j];
			unsigned long imm;

			if (((w >> 5) & 0x1F) != 19)
				continue;
			if ((w & 0xFFC00000) == 0xF9400000) {
				imm = ((w >> 10) & 0xFFF) * 8;
				pr_info("penmods-abiprobe: [dev]   +0x%03x: ldr x%u, [x19, #%lu]\n",
					j * 4, w & 0x1F, imm);
				cnt++;
			} else if ((w & 0xFFC00000) == 0xF9000000) {
				imm = ((w >> 10) & 0xFFF) * 8;
				pr_info("penmods-abiprobe: [dev]   +0x%03x: str x%u, [x19, #%lu]\n",
					j * 4, w & 0x1F, imm);
				cnt++;
			}
		}
		pr_info("penmods-abiprobe: [dev] 共 %d 条 [x19, #imm] 访问\n", cnt);
	}
}

/* ── struct snd_pcm 布局探测（2026-10-03 aplay oops 逼出来的）───────────────
 *
 * 事故（真机，aplay -D hw:1,0 打开 UAC2 的 PCM 时）：
 *     PC is at uac2_pcm_open+0x20/0x190 [usb_uac2]
 *     30d8  f9400816   ldr  x22, [x0, #16]     ; substream->private_data
 *     30e0  f85f02c1   ldur x1,  [x22, #-16]   ; ← 崩，x22 = 0
 * 即 `substream->private_data` 是 0。它在 `snd_pcm_attach_substream()` 里由
 *     substream->private_data = pcm->private_data;
 * 拷过来 ⇒ 真正错的是**我们写 `pcm->private_data` 的偏移**。
 *
 * 根因：我们的 CI 里 `CONFIG_SND` 从未真正打开（workflow 漏了 `--enable SOUND`，
 * 而 `config SND depends on SOUND`，arm64 defconfig 又完全没有 sound 配置项）
 * ⇒ `CONFIG_SND_VERBOSE_PROCFS` = n ⇒ `struct snd_pcm_str` 尾部少了
 * proc_root / proc_info_entry 两个指针（×2 个 stream = 32 字节）
 * ⇒ struct snd_pcm 里 private_data 的偏移比内核**小 32** ⇒ 那句
 * `pcm->private_data = uac2;` 写到了内核结构体的别的字段上，内核在真偏移处
 * 读到 kzalloc 出来的 0。
 *
 * 这里仍然**不靠推理** —— 读内核自己的机器码：
 *   ① `_snd_pcm_new()` 里有 `pcm = kzalloc(sizeof(*pcm), GFP_KERNEL);`
 *      展开成 `mov w0, #<size>` … `bl __kmalloc`，那个立即数就是内核的
 *      sizeof(struct snd_pcm)。
 *   ② `snd_pcm_attach_substream()` 里有 `substream->private_data =
 *      pcm->private_data;`，机器码形如 `ldr xN,[xP,#imm]` + `str xN,[xS,#16]`。
 *      str 的 imm 必然是 16（oops 现场也证实），所以找到那条 str 再回溯
 *      写同一寄存器的那条 ldr，imm 就是 offsetof(struct snd_pcm, private_data)。
 * 全程**只读内核 .text**，不碰 ALSA / USB / UDC ⇒ 可放心 insmod。
 *
 * ⚠️ 函数名踩过的坑（值得记住）：`kzalloc(sizeof(*pcm))` 那一句在
 *    **`_snd_pcm_new()`** 里（static，名字带**下划线前缀**），而
 *    `snd_pcm_new()` / `snd_pcm_new_internal()` 都只是 28 字节的薄 wrapper
 *    （尾调用 `_snd_pcm_new`）。第一版照 4.4 源码去找 `snd_pcm_new_internal`
 *    时，kallsyms 报出它和 `snd_pcm_attach_substream` 只差 **0x34 字节**
 *    —— 一个几百字节的函数不可能只占 52 字节，正是这个"不可能的数字"
 *    暴露了找错了函数。教训：**kallsyms 的地址是准的，不合理的间距说明
 *    你找错了符号**。
 */
#define ABIPROBE_SNDPCM_SCAN	96	/* _snd_pcm_new 长 0x150=336B ⇒ 84 条，留余量 */
#define ABIPROBE_ATTACH_SCAN	180	/* snd_pcm_attach_substream 长 0x294=660B ⇒ 165 条 */

static int abiprobe_find_kzalloc_size(const char *fname)
{
	const u32 *p;
	unsigned long addr;
	int i, j;

	if (!kallsyms_lookup_name)
		return -1;
	addr = kallsyms_lookup_name(fname);
	if (!addr) {
		pr_info("penmods-abiprobe: [pcm] 找不到 %s\n", fname);
		return -1;
	}
	p = (const u32 *)addr;
	pr_info("penmods-abiprobe: [pcm] %s @ 0x%lx —— 扫 %d 条指令找 kzalloc 的 size\n",
		fname, addr, ABIPROBE_SNDPCM_SCAN);
	for (i = 0; i < ABIPROBE_SNDPCM_SCAN; i++) {
		u32 w = p[i];
		int imm;

		/* MOVZ (wide immediate) 32-bit：0x52800000 | (imm16<<5) | Rd
		 * 只认 Rd = w0（kzalloc 的 size 参数就是 w0） */
		if ((w & 0xFFE0001F) != 0x52800000)
			continue;
		imm = (int)((w >> 5) & 0xFFFF);
		if (imm < 256 || imm > 16384)
			continue;
		/* 往后 10 条内必须有 bl（= kzalloc 展开出来的 __kmalloc） */
		for (j = i + 1; j <= i + 10 && j < ABIPROBE_SNDPCM_SCAN + 32; j++) {
			if ((p[j] & 0xFC000000) != 0x94000000)
				continue;
			pr_info("penmods-abiprobe: [pcm]   +0x%03x: movz w0, #%d   ...   +0x%03x: bl\n",
				i * 4, imm, j * 4);
			return imm;
		}
	}
	pr_info("penmods-abiprobe: [pcm] 没扫到（编译器没把它编成 movz w0, #imm）\n");
	return -1;
}

static int abiprobe_find_pcm_privdata_off(void)
{
	const u32 *p;
	unsigned long addr;
	int i, j, rt;

	if (!kallsyms_lookup_name)
		return -1;
	addr = kallsyms_lookup_name("snd_pcm_attach_substream");
	if (!addr) {
		pr_info("penmods-abiprobe: [pcm] 找不到 snd_pcm_attach_substream\n");
		return -1;
	}
	p = (const u32 *)addr;
	for (i = 0; i < ABIPROBE_ATTACH_SCAN; i++) {
		u32 w = p[i];
		unsigned imm;

		/* STR (immediate, unsigned offset) 64-bit：
		 *   0xF9000000 | (imm12 << 10) | (Rn << 5) | Rt
		 * 我们要的是 `substream->private_data` 那一句：偏移恒为 16
		 * ⇒ imm12 = 16 / 8 = 2。 */
		if ((w & 0xFFC00000) != 0xF9000000)
			continue;
		imm = ((w >> 10) & 0xFFF) * 8;
		if (imm != 16)
			continue;
		rt = (int)(w & 0x1F);
		/* 回溯 ≤16 条，找写**同一寄存器**的 LDR —— 那正是 pcm->private_data */
		for (j = i - 1; j >= 0 && j >= i - 16; j--) {
			u32 w2 = p[j];
			unsigned v;

			if ((w2 & 0xFFC00000) != 0xF9400000)
				continue;
			if ((int)(w2 & 0x1F) != rt)
				continue;
			v = ((w2 >> 10) & 0xFFF) * 8;
			if (v < 128 || v > 2048)
				continue;	/* 不是 private_data 那个量级 */
			pr_info("penmods-abiprobe: [pcm]   +0x%03x: str x%u, [x%u, #16]   ←   "
				"+0x%03x: ldr x%u, [x%u, #%u]\n",
				i * 4, rt, (w >> 5) & 0x1F,
				j * 4, rt, (w2 >> 5) & 0x1F, v);
			return (int)v;
		}
	}
	pr_info("penmods-abiprobe: [pcm] 没扫到 private_data 的偏移\n");
	return -1;
}

static void abiprobe_check_snd_pcm(void)
{
	int ksz, koff;

	pr_info("penmods-abiprobe: ============= struct snd_pcm 布局探测 =============\n");
	pr_info("penmods-abiprobe: [pcm] ours: sizeof(snd_pcm)=%d sizeof(snd_pcm_str)=%d "
		"sizeof(snd_pcm_substream)=%d\n",
		(int)sizeof(struct snd_pcm), (int)sizeof(struct snd_pcm_str),
		(int)sizeof(struct snd_pcm_substream));
	pr_info("penmods-abiprobe: [pcm] ours: streams=%d open_mutex=%d open_wait=%d "
		"private_data=%d private_free=%d\n",
		(int)offsetof(struct snd_pcm, streams),
		(int)offsetof(struct snd_pcm, open_mutex),
		(int)offsetof(struct snd_pcm, open_wait),
		(int)offsetof(struct snd_pcm, private_data),
		(int)offsetof(struct snd_pcm, private_free));
	pr_info("penmods-abiprobe: [pcm] ours: snd_pcm_str: proc_root=%d proc_info_entry=%d\n",
		(int)offsetof(struct snd_pcm_str, proc_root),
		(int)offsetof(struct snd_pcm_str, proc_info_entry));

	ksz = abiprobe_find_kzalloc_size("_snd_pcm_new");
	koff = abiprobe_find_pcm_privdata_off();

	if (ksz > 0 && koff > 0) {
		if (ksz == (int)sizeof(struct snd_pcm) &&
		    koff == (int)offsetof(struct snd_pcm, private_data))
			pr_info("penmods-abiprobe: [pcm] ✅ 内核与 OURS **完全一致**"
				"（sizeof=%d / private_data=%d）⇒ 可以安全绑 UDC\n",
				ksz, koff);
		else
			pr_info("penmods-abiprobe: [pcm] ❌ **不一致**！内核 sizeof=%d / private_data=%d，"
				"我们 %d / %d ⇒ 绝对不要绑 UDC（会和 2026-10-03 一样 oops）\n",
				ksz, koff, (int)sizeof(struct snd_pcm),
				(int)offsetof(struct snd_pcm, private_data));
	} else {
		pr_info("penmods-abiprobe: [pcm] ⚠️ 没能同时取到两个 ground truth，不作结论\n");
	}
}

static void abiprobe_ours(void)
{	pr_info("penmods-abiprobe: ================= 我们编译时的偏移 (ours) =================\n");
	pr_info("penmods-abiprobe: ours: CONFIGFS_ITEM_NAME_LEN = %d\n",
		(int)CONFIGFS_ITEM_NAME_LEN);
	pr_info("penmods-abiprobe: ours: sizeof(config_item)=%d sizeof(config_group)=%d\n",
		(int)sizeof(struct config_item), (int)sizeof(struct config_group));
	pr_info("penmods-abiprobe: ours: config_item: ci_name=%d ci_namebuf=%d ci_kref=%d\n",
		(int)offsetof(struct config_item, ci_name),
		(int)offsetof(struct config_item, ci_namebuf),
		(int)offsetof(struct config_item, ci_kref));
	pr_info("penmods-abiprobe: ours: config_group: cg_item=%d cg_children=%d "
		"cg_subsys=%d default_groups=%d\n",
		(int)offsetof(struct config_group, cg_item),
		(int)offsetof(struct config_group, cg_children),
		(int)offsetof(struct config_group, cg_subsys),
		(int)offsetof(struct config_group, default_groups));
	pr_info("penmods-abiprobe: ours: sizeof(usb_function_instance)=%d\n",
		(int)sizeof(struct usb_function_instance));
	pr_info("penmods-abiprobe: ours: usb_function_instance: group=%d cfs_list=%d "
		"fd=%d set_inst_name=%d free_func_inst=%d\n",
		(int)offsetof(struct usb_function_instance, group),
		(int)offsetof(struct usb_function_instance, cfs_list),
		(int)offsetof(struct usb_function_instance, fd),
		(int)offsetof(struct usb_function_instance, set_inst_name),
		(int)offsetof(struct usb_function_instance, free_func_inst));
}

static int __init abiprobe_init(void)
{
	struct config_item_type t;
	void *buf;
	int off;

	/* ── 编译期硬门禁：ABI 复刻的目标值 ────────────────────────────────
	 * `config_group` / `config_item` 与上游 4.4.159 **完全一致**（112 / 80）。
	 * `usb_function_instance` 尾部多一个 8 字节字段（见 CI 里 composite.h 补丁
	 * 的注释）：设备内核自己的 usb_put_function_instance() 机器码是
	 *     ldr x2, [x0, #128]   ; fi->fd
	 *     ldr x1, [x0, #152]   ; fi->free_func_inst（上游应在 144）
	 * ⇒ fd=128、set_inst_name=136、free_func_inst=152、sizeof=160。
	 * 一旦补丁失效、锚点变了或被谁删了，这里**直接编译失败**，而不是产出一个
	 * 会把内核 oops 掉的模块 —— 设备 panic_on_oops=1，偏移一错就当场重启。
	 * ⚠️ 判据必须 mkdir + rmdir 都过：4.4 的 f_uac2 从不设 set_inst_name，
	 *    所以 set_inst_name 那一段赌错也看不出来，只有 rmdir 走
	 *    usb_put_function_instance() 取 free_func_inst 时才暴露。 */
	BUILD_BUG_ON(sizeof(struct config_item) != 80);
	BUILD_BUG_ON(sizeof(struct config_group) != 112);
	BUILD_BUG_ON(offsetof(struct config_group, cg_children) != 80);
	BUILD_BUG_ON(offsetof(struct config_group, default_groups) != 104);
	BUILD_BUG_ON(sizeof(struct usb_function_instance) != 160);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, fd) != 128);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, set_inst_name) != 136);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, free_func_inst) != 152);

	abiprobe_ours();

	/* ★ 运行时再验一次：直接解码**内核自己**的 usb_put_function_instance 机器码，
	 *   看它从 fi 的哪个偏移取 fd / free_func_inst。这是独立于我们头文件的证据 ——
	 *   哪怕上面 8 条 BUILD_BUG_ON 全过，也只能说明"我们的头文件自洽"，只有这条
	 *   才能说明"内核和我们对上了"。 */
	abiprobe_check_kernel_code("usb_put_function_instance");

	/* ★ 探 struct device 的布局 —— 2026-09-27 绑 UDC 时崩在
	 *   afunc_bind→platform_device_register→device_add→sysfs_create_groups，
	 *   即 offsetof(struct device, groups) 两边不一致。 */
	abiprobe_check_device_add();

	/* ★ 探 struct snd_pcm 的布局 —— 2026-10-03 `aplay -D hw:1,0` 时崩在
	 *   uac2_pcm_open+0x20（解引用 substream->private_data = NULL）。
	 *   根因是 `pcm->private_data` 的偏移比内核小 32 字节。
	 *   ⚠️ 这一项**必须在绑 UDC 之前跑通过**才能继续 —— 设备 panic_on_oops=1，
	 *   偏移错了不是"加载失败"，而是当场 oops + 重启。 */
	abiprobe_check_snd_pcm();

	buf = kzalloc(ABIPROBE_BUFSZ, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;

	/* ★ 关键：让内核按它自己的偏移初始化一个 config_group。
	 * 内核会初始化 cg_item（含名字）以及 cg_children 自指 list_head。
	 * （4.4 的 default_groups 是个普通指针，不会被 INIT_LIST_HEAD，
	 *   所以只该看到 ci_entry@32 和 cg_children@80 两个自指 list_head。） */
	memset(&t, 0, sizeof(t));
	t.ct_owner = THIS_MODULE;
	config_group_init_type_name((struct config_group *)buf, ABIPROBE_NAME, &t);

	pr_info("penmods-abiprobe: ================= 内核实际写入的位置 (KERNEL) =================\n");

	off = abiprobe_find_str(buf, ABIPROBE_BUFSZ, ABIPROBE_NAME);
	if (off >= 0) {
		pr_info("penmods-abiprobe: [KERNEL] config_item: ci_namebuf 处的名字串 @ %d "
			"(ours = %d)\n", off, (int)offsetof(struct config_item, ci_namebuf));
		abiprobe_find_ptr("config_item", buf, ABIPROBE_BUFSZ,
				  (unsigned long)buf + off);
	} else {
		pr_info("penmods-abiprobe: [KERNEL] 没找到名字串（内核可能用了 kstrdup）\n");
	}
	abiprobe_scan_selflist("config_group", buf, ABIPROBE_BUFSZ);

	kfree(buf);

	/* 再跑一遍 uac2 的实例创建/销毁往返（需要 usb_uac2.ko 已加载） */
	abiprobe_uac2_roundtrip();

	return 0;
}

static void __exit abiprobe_exit(void)
{
	pr_info("penmods-abiprobe: unloaded OK\n");
}

module_init(abiprobe_init);
module_exit(abiprobe_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("PenMods");
MODULE_DESCRIPTION("PenMods kernel struct ABI probe (read-only, no side effects)");
MODULE_VERSION("1.0");
