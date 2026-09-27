/*
 * PenMods —— 内核模块加载性探针（空操作模块）
 *
 * 目的：在触碰任何真实功能之前，先验证三件事：
 *   1) vermagic 是否与设备内核严格匹配（设备实测为
 *      `4.4.159 SMP mod_unload aarch64`）。不匹配则 insmod 直接
 *      报 "invalid module format"，后面所有工作都没有意义。
 *   2) 自编模块能否 insmod / rmmod（CONFIG_MODULES=y、未签名、
 *      modules_disabled=0 已实测，这里做端到端确认）。
 *   3) 内核 dmesg 通道正常，能看到模块的自己打的日志。
 *
 * 本模块 load/unload 只打日志 + 只读自己那块内存，不注册任何 function、
 * 不碰 USB、不碰 ALSA，因此即使结构体布局与设备内核不一致也不会造成影响。
 *
 * ─────────────────────────────────────────────────────────────────────
 * 附加功能：反扫内核真实的结构体字段偏移
 * ─────────────────────────────────────────────────────────────────────
 * 背景（见 .github/workflows/build-uac2-kmod.yaml）：
 *   设备侧 `.gnu.linkonce.this_module` 节 = **704** 字节，而我们用上游
 *   arm64 defconfig 编出来是 **768**，差 64 字节。这 64 字节就是
 *   struct module 里若干 `#ifdef` 块的有无。布局不一致的后果实测为：
 *     * /proc/modules 第三列（module_refcount）打出 9400318 这种垃圾值
 *     * rmmod 报 "Resource temporarily unavailable"(EAGAIN)
 *
 * 猜配置是不可靠的。这里改用一个**硬测量**：
 *   内核加载模块时，是按**它自己的**偏移往 `__this_module` 这块内存里
 *   写字段的（name / init / exit / module_core / taints ... 都由内核或
 *   loader 的 relocation 填好）。而我们读的是**我们的**偏移。于是——
 *     * 内核写 `name` 的地方，一定躺着一份 `"utest\0"`
 *     * 内核写 `init` / `exit` 的地方，一定躺着一个等于
 *       我们 utest_init / utest_exit 的运行时地址的字
 *   扫出这三个值的位置，就得到了内核真实的
 *   `offsetof(struct module, name/init/exit)`；拿它和我们的
 *   `offsetof(...)` 一减，就能反推出设备到底开了哪些 `#ifdef` 块，
 *   从而把 CI 的 config 精确对齐，而不必反复试错。
 *
 * 全程只读自己模块的那块内存，不写、不外传、不进任何持久化路径。
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/version.h>
#include <linux/string.h>

extern struct module __this_module;

/* 前置声明：utest_init 里要拿 utest_exit 的地址来反扫内核偏移，
 * 而 utest_exit 定义在后面（C 里用后定义的标识符必须先知会编译器）。 */
static int __init utest_init(void);
static void __exit utest_exit(void);

/* 只扫描我们自己那块 this_module 内存；超出 sizeof 的字节不碰 */
#define SCAN_MAX ((int)sizeof(struct module))

static int __init utest_init(void)
{
	unsigned long base = (unsigned long)&__this_module;
	unsigned long ip = (unsigned long)(void *)utest_init;
	unsigned long ep = (unsigned long)(void *)utest_exit;
	int i;

	/* 故意不用 UTS_RELEASE —— 它在 include/generated/utsrelease.h 里，
	 * 需要额外 include 才能拿到，而 LINUX_VERSION_CODE 由 linux/version.h
	 * 直接提供，省一个依赖。 */
	pr_info("penmods-utest: loaded OK (built for kernel %u.%u.%u, code %u)\n",
		(LINUX_VERSION_CODE >> 16) & 0xff,
		(LINUX_VERSION_CODE >> 8) & 0xff,
		LINUX_VERSION_CODE & 0xff,
		LINUX_VERSION_CODE);

	pr_info("penmods-utest: &__this_module = %px\n", (void *)&__this_module);
	pr_info("penmods-utest: sizeof(struct module) [OURS] = %d\n", SCAN_MAX);

	/* ── 1) name：找内核写进去的 "utest" 字符串 ─────────────────── */
	for (i = 0; i + 6 <= SCAN_MAX; i++) {
		const char *c = (const char *)(base + i);
		if (c[0] != 'u')
			continue;
		if (!memcmp(c, "utest", 5) && c[5] == '\0')
			pr_info("penmods-utest: [KERNEL] offsetof(name) = %4d   (ours = %d)\n",
				i, (int)offsetof(struct module, name));
	}

	/* ── 2) init / exit：找内核写进去的那两个函数指针 ───────────── */
	for (i = 0; i + 8 <= SCAN_MAX; i += 8) {
		unsigned long v = *(const unsigned long *)(base + i);
		if (v == ip)
			pr_info("penmods-utest: [KERNEL] offsetof(init) = %4d   (ours = %d)\n",
				i, (int)offsetof(struct module, init));
#ifdef CONFIG_MODULE_UNLOAD
		if (v == ep)
			pr_info("penmods-utest: [KERNEL] offsetof(exit) = %4d   (ours = %d)\n",
				i, (int)offsetof(struct module, exit));
#endif
	}

	/* ── 3) 把所有像内核地址的 8 字节字列出来 ───────────────────────
	 * 人工比对：哪一段是 list_head（next/prev 都指向内核的模块链表）、
	 * 哪一段是 percpu 指针（refptr）、哪一段是 module_core 基址。
	 * 这些就是「内核视图」的骨架，能直接把布局差异钉死。
	 */
	pr_info("penmods-utest: --- kernel-region words inside __this_module ---\n");
	for (i = 0; i + 8 <= SCAN_MAX; i += 8) {
		unsigned long v = *(const unsigned long *)(base + i);
		if (v >= 0xffffff8000000000UL)
			pr_info("penmods-utest:   [%4d] = 0x%016lx\n", i, v);
	}

	return 0;
}

static void __exit utest_exit(void)
{
	pr_info("penmods-utest: unloaded OK\n");
}

module_init(utest_init);
module_exit(utest_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("PenMods");
MODULE_DESCRIPTION("PenMods kernel module loadability probe (no-op)");
MODULE_VERSION("1.1");
