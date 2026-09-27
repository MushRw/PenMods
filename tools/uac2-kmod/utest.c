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
 * 本模块 load/unload 只打日志，不注册任何 function、不碰 USB、不碰 ALSA，
 * 因此即使结构体布局与设备内核不一致也不会造成任何影响。
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/version.h>

static int __init utest_init(void)
{
	pr_info("penmods-utest: loaded OK on Linux %s\n", UTS_RELEASE);
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
MODULE_VERSION("1.0");
