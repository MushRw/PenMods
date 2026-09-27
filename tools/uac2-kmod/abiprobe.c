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

static void abiprobe_ours(void)
{
	pr_info("penmods-abiprobe: ================= 我们编译时的偏移 (ours) =================\n");
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

	/* ── 编译期硬门禁：configfs ABI 复刻的目标值 ──────────────────────
	 * 全部由真机实测反推（见 CI 里 configfs.h 补丁的注释、本文件顶部说明）：
	 *   sizeof(struct config_group) = 120     （上游 4.4.159 是 112，差 +8：
	 *                                          设备把 default_groups 从
	 *                                          `**` 指针回移植成 list_head）
	 *   usb_function_instance: fd=136  set_inst_name=144  free_func_inst=152
	 *                          sizeof=160
	 * 一旦补丁失效、锚点变了或被谁删了，这里**直接编译失败**，而不是产出一个
	 * 会把内核 oops 掉的模块 —— 设备 panic_on_oops=1，偏移一错就当场重启。
	 * ⚠️ 判据必须 mkdir + rmdir 都过：加多了 8 字节时 mkdir 照样成功，
	 *    只在 rmdir 调 free_func_inst 时才崩。 */
	BUILD_BUG_ON(sizeof(struct config_group) != 120);
	BUILD_BUG_ON(sizeof(struct usb_function_instance) != 160);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, fd) != 136);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, set_inst_name) != 144);
	BUILD_BUG_ON(offsetof(struct usb_function_instance, free_func_inst) != 152);

	abiprobe_ours();

	buf = kzalloc(ABIPROBE_BUFSZ, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;

	/* ★ 关键：让内核按它自己的偏移初始化一个 config_group。
	 * 内核会写 cg_item（含名字）以及 cg_children / default_groups 两个
	 * 自指 list_head。 */
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
