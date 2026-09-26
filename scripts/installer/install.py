#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PenMods YDP02X 一键安装/升级程序

用法：
    python install.py            # 自动使用本目录下的发布文件
    python install.py <dir>      # 指定发布包目录

流程：检测 ADB 设备 -> 解锁 -> 挂载可写 -> 推送文件 -> pen_recover.sh
（安装 patchelf、给主程序打补丁、MALLOC/XDG 调参、chattr +i 上锁，全幂等）
-> 校验 -> 重启。
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
    "patch.sh",
    "misc/init.sh",
    "misc/patchelf",
    # 系统 CA 库：切槽/OTA 后可能整个消失，导致 Bili 插件等 Go 程序 HTTPS 全失败
    "misc/ca-certificates.crt",
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

    adb("shell", "mkdir -p /userdata/PenMods/misc")

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

    # SH-02：推送一键恢复脚本。它覆盖 init.sh + patch.sh 之外的关键步骤：
    # MALLOC 调参、XDG_DATA_HOME 注入（插件配置/历史落可写分区）、CA 恢复、
    # zram、chattr +i 上锁、清崩溃计数——全新安装缺少上锁一步时，厂商资源
    # 通道会在首次重启把主程序写回原版，mod 直接消失（docs/rootfs-mods.md 复盘结论）。
    recover_local = os.path.join(pkg_dir, "pen_recover.sh")
    if not os.path.exists(recover_local):
        # 发布包未带时回退到仓库内的 scripts/tweaks/pen_recover.sh
        here = os.path.dirname(os.path.abspath(__file__))      # scripts/installer
        recover_local = os.path.join(os.path.dirname(here), "tweaks", "pen_recover.sh")
    if not os.path.exists(recover_local):
        fail("找不到 pen_recover.sh（发布包与 scripts/tweaks/ 均无），无法保证补丁存活")
    log("推送 pen_recover.sh ...")
    tmp = recover_local + ".lf"
    with open(recover_local, "rb") as f:
        data = f.read().replace(b"\r\n", b"\n")
    with open(tmp, "wb") as f:
        f.write(data)
    r = adb("push", tmp, "/userdata/PenMods/recover.sh")
    os.remove(tmp)
    if r.returncode != 0:
        fail("推送 pen_recover.sh 失败: %s" % r.stderr.strip())

    if not is_upgrade:
        # 先解锁再打补丁：上次安装留下的 chattr +i 会让 patch.sh 的 mv 失败
        adb("shell", "chattr -i /oem/YoudaoDictPen/output/YoudaoDictPen 2>/dev/null")
        log("执行 pen_recover.sh（init + patch + 调参 + 上锁，全幂等）...")
        adb("shell", "sh /userdata/PenMods/recover.sh")
    else:
        log("校验主程序依赖（升级）...")
        r = adb("shell", "/usr/bin/patchelf --print-needed /oem/YoudaoDictPen/output/YoudaoDictPen")
        if "libPenMods.so" not in r.stdout:
            # 升级时发现补丁被 OTA/厂商通道还原 → 跑恢复脚本补齐，而不是直接失败
            log("主程序依赖缺失（疑似被 OTA/厂商通道还原），执行 pen_recover.sh 恢复...")
            adb("shell", "chattr -i /oem/YoudaoDictPen/output/YoudaoDictPen 2>/dev/null")
            adb("shell", "sh /userdata/PenMods/recover.sh")

    log("校验主程序依赖...")
    r = adb("shell", "/usr/bin/patchelf --print-needed /oem/YoudaoDictPen/output/YoudaoDictPen")
    if "libPenMods.so" not in r.stdout:
        fail("校验失败：主程序未包含 libPenMods.so 依赖")

    log("清除 QML 缓存（确保新界面生效）...")
    adb("shell", "rm -rf /.cache/NeteaseYoudao/YoudaoDictPen/qmlcache")

    log("唤醒触摸并重启设备...")
    adb("shell", "echo 0 > /sys/kernel/debug/touchscreen/suspend")
    adb("shell", "sync")
    time.sleep(1)
    adb("shell", "sync")
    adb("shell", "reboot")

    log("完成！设备正在重启，开机后即可使用 PenMods（含播放器、输入法）。")


if __name__ == "__main__":
    main()
