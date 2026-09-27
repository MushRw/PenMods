# PenMods —— USB Audio Class 2.0 gadget 内核模块（out-of-tree）
#
# 背景
# ----
# 设备内核（Rockchip 4.4.159）没有编译 f_uac2 / u_audio，configfs 里
# `mkdir functions/uac2.0` 返回 ENODEV，而原厂 /etc/init.d/S98usbdevice
# 里的 usb_uac2_en 开关是死的（脚本不检查返回值，静默失败）。
#
# 但实测这三条同时成立，使「自己编一个 .ko 塞进去」成为可能：
#   * CONFIG_MODULES=y                    （/proc/modules 有 hci_uart / 8723ds）
#   * CONFIG_MODVERSIONS=n                （现有 .ko 里 __crc_ 符号数 = 0）
#     ⇒ 不需要 Module.symvers，不必编译整个内核
#   * 模块未签名 / modules_disabled=0
#   * vermagic = 4.4.159 SMP mod_unload aarch64
#
# f_uac2 与 u_audio 是纯上游代码，Rockchip 未做定制，所以用上游
# linux-4.4.159 源码编译即可拿到 vermagic 天然匹配的产物。
#
# 用法
# ----
#   make -C <kernel-src> M=<this-dir> ARCH=arm64 \
#        CROSS_COMPILE=aarch64-linux-gnu- [WITH_UAC2=1] modules
#
# 由 .github/workflows/build-uac2-kmod.yaml 调用。

KDIR      ?=
ARCH      ?= arm64
CROSS_COMPILE ?= aarch64-linux-gnu-

# 空操作探针：任何情况下都可编，用来单独验证加载链路
obj-m += utest.o

# 真实模块。
# ⚠️ 4.4 的 f_uac2.c 是**自包含**的：`usb_f_uac2-y := f_uac2.o`，只 include 一个
#    u_uac2.h。被抽出来的 u_audio.c（ALSA 公共层）是 **4.6+** 才有的拆分，
#    在 4.4 里根本不存在 —— 所以默认只编 f_uac2.o。
#    为了兼容更新的内核，若 CI 传入了 UAC2_OBJS 就以它为准。
ifdef WITH_UAC2
obj-m += usb_uac2.o
usb_uac2-y := $(if $(UAC2_OBJS),$(UAC2_OBJS),f_uac2.o)
endif

.PHONY: all clean
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=$(ARCH) \
		CROSS_COMPILE=$(CROSS_COMPILE) WITH_UAC2=$(WITH_UAC2) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
