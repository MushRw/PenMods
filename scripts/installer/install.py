#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PenMods YDP02X 一键安装/升级程序

用法：
    python install.py            # 自动使用本目录下的发布文件
    python install.py <dir>      # 指定发布包目录

流程：检测 ADB 设备 -> 解锁 -> 挂载可写 -> 推送文件 -> （全新安装时）安装
patchelf 并给主程序打补丁 -> 校验 -> 重启。
"""

import os
import shutil
import subprocess
import sys
import time


REQUIRED_FILES = [
    "libPenMods.so",
    "libPenModsResources.so",
    "player.zip",
    "rime.zip",
    "mihomo.gz",
    "patch.sh",
    "misc/init.sh",
    "misc/patchelf",
]


def log(msg):
    print("[PenMods] " + msg, flush=True)


def fail(msg):
    print("[错误] " + msg, flush=True)
    sys.exit(1)


def adb(*args):
    return subprocess.run(
        ["adb"] + list(args), capture_output=True, text=True, errors="replace"
    )


def find_device():
    r = adb("devices")
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == "device":
            return parts[0]
    return None


def wait_for_device(timeout=180):
    deadline = time.time() + timeout
    while time.time() < deadline:
        dev = find_device()
        if dev:
            return dev
        time.sleep(3)
    return None


def auth_if_needed():
    r = adb("shell", "uname -a")
    if "login with \"adb shell auth\"" in r.stdout:
        log("设备需要认证，使用默认密码解锁...")
        p = subprocess.run(
            'echo CherryYoudao | adb shell auth',
            shell=True, capture_output=True, text=True, errors="replace",
        )
        time.sleep(2)
        r = adb("shell", "uname -a")
        if "login with \"adb shell auth\"" in r.stdout:
            fail("ADB 认证失败")
    elif r.returncode != 0:
        fail("无法与设备通信: " + r.stderr.strip())


def main():
    pkg_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))

    missing = [f for f in REQUIRED_FILES if not os.path.exists(os.path.join(pkg_dir, f))]
    if missing:
        fail("发布包缺少文件: " + ", ".join(missing))

    log("检测 ADB 设备...")
    dev = find_device()
    if not dev:
        log("未检测到设备，等待连接（请在笔上开启 ADB：设置 -> 关于 -> 法律监管，连点 7 次）...")
        dev = wait_for_device()
    if not dev:
        fail("未检测到设备")
    log("设备: " + dev)

    auth_if_needed()

    log("挂载根分区可写...")
    adb("shell", "mount -o remount,rw /")

    # 判断全新安装还是升级
    r = adb("shell", "ls /oem/YoudaoDictPen/output/YoudaoDictPen.original_bak")
    is_upgrade = "original_bak" in r.stdout
    if is_upgrade:
        log("检测到已安装过 PenMods，按升级处理（不重复打补丁）")
    else:
        log("全新安装，将安装 patchelf 并给主程序打补丁")

    adb("shell", "mkdir -p /userdata/PenMods/misc /userdata/PenMods/vpn")

    def push(local, remote):
        local_path = os.path.join(pkg_dir, local)
        # shell 脚本统一转成 LF，避免设备端 sh 报错
        if local.endswith((".sh",)) or local in ("patch.sh", "misc/init.sh"):
            tmp = local_path + ".lf"
            with open(local_path, "rb") as f:
                data = f.read().replace(b"\r\n", b"\n")
            with open(tmp, "wb") as f:
                f.write(data)
            r = adb("push", tmp, remote)
            os.remove(tmp)
        else:
            r = adb("push", local_path, remote)
        if r.returncode != 0:
            fail("推送 %s 失败: %s" % (local, r.stderr.strip()))

    for f in REQUIRED_FILES:
        log("推送 %s ..." % f)
        push(f, "/userdata/PenMods/" + f)

    adb("shell", "chmod +x /userdata/PenMods/misc/init.sh /userdata/PenMods/misc/patchelf /userdata/PenMods/patch.sh")

    if not is_upgrade:
        log("执行 init.sh（安装 patchelf）...")
        adb("shell", "cd /userdata/PenMods/misc && sh init.sh")
        log("执行 patch.sh（注入 libPenMods.so）...")
        adb("shell", "cd /userdata/PenMods && sh patch.sh")

    log("校验主程序依赖...")
    r = adb("shell", "/usr/bin/patchelf --print-needed /oem/YoudaoDictPen/output/YoudaoDictPen")
    if "libPenMods.so" not in r.stdout:
        fail("校验失败：主程序未包含 libPenMods.so 依赖")

    log("唤醒触摸并重启设备...")
    adb("shell", "echo 0 > /sys/kernel/debug/touchscreen/suspend")
    adb("shell", "sync")
    time.sleep(1)
    adb("shell", "sync")
    adb("shell", "reboot")

    log("完成！设备正在重启，开机后即可使用 PenMods（含播放器、输入法、VPN 内核均已就位）。")


if __name__ == "__main__":
    main()
