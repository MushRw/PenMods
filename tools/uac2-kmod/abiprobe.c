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
