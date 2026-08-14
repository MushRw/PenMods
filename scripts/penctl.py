#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
penctl.py - 通过 adb 从电脑上查看/调整词典笔设置

用法：
    python penctl.py status                 # 设备状态总览
    python penctl.py screenshot [out.png]   # 截图（默认存到 screenshots/）
    python penctl.py brightness <0-255>     # 背光亮度
    python penctl.py screen on|off|state    # 屏幕开关
    python penctl.py touch on|off|state     # 触摸（休眠/唤醒）
    python penctl.py torch on|off|state     # 笔头灯（GPIO15）
    python penctl.py volume <0-100|state>   # 音量（amixer Master）
    python penctl.py sleep <秒|never>       # 自动息屏时长（写 mod 配置，重启应用生效）
    python penctl.py config get <键路径>     # 读 mod 配置，如 ai.activeModelId
    python penctl.py config set <键路径> <JSON值>
    python penctl.py reboot [--yes]         # 重启笔

所有写操作都有保护：先确认设备在线并解锁 adb，再执行。
"""

import json
import os
import subprocess
import sys
import tempfile
import time


def adb(*args):
    return subprocess.run(
        ["adb"] + list(args),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def sh_out(cmd):
    r = adb("shell", cmd)
    return r.stdout.strip()


def fail(msg):
    print("[错误] " + msg)
    sys.exit(1)


def ensure_device():
    r = adb("devices")
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == "device":
            return parts[0]
    fail("未检测到词典笔，请连接并开启 ADB（设置 -> 关于 -> 法律监管，连点 7 次）")


def auth_if_needed():
    r = adb("shell", "uname -a")
    if "login with \"adb shell auth\"" in r.stdout:
        print("[penctl] 解锁 ADB ...")
        subprocess.run(
            "echo CherryYoudao | adb shell auth",
            shell=True, capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        time.sleep(2)
        r = adb("shell", "uname -a")
        if "login with \"adb shell auth\"" in r.stdout:
            fail("ADB 认证失败")


def read_config():
    r = adb("shell", "cat /userdata/PenMods/config.json")
    if r.returncode != 0 or not r.stdout.strip():
        fail("读取 mod 配置失败")
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError as e:
        fail("解析 mod 配置失败: %s" % e)


def write_config(cfg):
    data = json.dumps(cfg, ensure_ascii=False, indent=4)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        f.write(data)
        tmp = f.name
    r = adb("push", tmp, "/userdata/PenMods/config.json")
    os.unlink(tmp)
    if r.returncode != 0:
        fail("写回 mod 配置失败")


def resolve_key(cfg, path):
    cur = cfg
    for part in path.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def cmd_status():
    serial = ensure_device()
    auth_if_needed()
    print("设备: %s" % serial)
    print("系统: " + sh_out("uname -r"))
    print("电量: " + sh_out("cat /sys/class/power_supply/battery/capacity 2>/dev/null || cat /sys/class/power_supply/*/capacity 2>/dev/null"))
    print("背光: " + sh_out("cat /sys/class/backlight/backlight/brightness 2>/dev/null"))
    print("触摸: " + ("休眠" if sh_out("cat /sys/kernel/debug/touchscreen/suspend 2>/dev/null") == "1" else "活跃"))
    print("手电: " + sh_out("cat /sys/class/gpio/gpio15/value 2>/dev/null").replace("1", "开").replace("0", "关"))
    print("WiFi: " + sh_out("wpa_cli status 2>/dev/null | grep wpa_state | cut -d= -f2"))
    print("uptime: " + sh_out("cat /proc/uptime | awk '{print int($1/60)\" 分钟\"}'"))
    cfg = read_config()
    print("Mod 版本: " + str(resolve_key(cfg, "version")))


def cmd_screenshot(out):
    ensure_device()
    auth_if_needed()
    sh_out("echo 0 > /sys/kernel/debug/touchscreen/suspend")
    sh_out("rm -f /tmp/penmods_screen.png; touch /tmp/penmods_screencap")
    time.sleep(2)
    if not out:
        outdir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "screenshots")
        os.makedirs(outdir, exist_ok=True)
        out = os.path.join(outdir, "pen_%s.png" % time.strftime("%Y%m%d_%H%M%S"))
    r = adb("pull", "/tmp/penmods_screen.png", out)
    if r.returncode != 0:
        fail("截图拉取失败（请确认 mod 的截图功能可用）")
    print("截图已保存: %s" % out)


def cmd_brightness(val):
    ensure_device()
    auth_if_needed()
    if not (0 <= val <= 255):
        fail("亮度范围 0-255")
    sh_out("echo %d > /sys/class/backlight/backlight/brightness" % val)
    print("背光已设为: " + sh_out("cat /sys/class/backlight/backlight/brightness"))


def cmd_screen(action):
    ensure_device()
    auth_if_needed()
    if action == "on":
        sh_out("screen_onoff on; echo 0 > /sys/kernel/debug/touchscreen/suspend")
        print("屏幕已点亮")
    elif action == "off":
        sh_out("screen_onoff off")
        print("屏幕已关闭")
    elif action == "state":
        print("背光: %s" % sh_out("cat /sys/class/backlight/backlight/brightness"))
        print("触摸: %s" % ("休眠" if sh_out("cat /sys/kernel/debug/touchscreen/suspend") == "1" else "活跃"))
    else:
        fail("用法: penctl.py screen on|off|state")


def cmd_touch(action):
    ensure_device()
    auth_if_needed()
    if action == "on":
        sh_out("echo 0 > /sys/kernel/debug/touchscreen/suspend")
        print("触摸已唤醒")
    elif action == "off":
        sh_out("echo 1 > /sys/kernel/debug/touchscreen/suspend")
        print("触摸已休眠")
    elif action == "state":
        print("触摸: %s" % ("休眠" if sh_out("cat /sys/kernel/debug/touchscreen/suspend") == "1" else "活跃"))
    else:
        fail("用法: penctl.py touch on|off|state")


def cmd_torch(action):
    ensure_device()
    auth_if_needed()
    if action in ("on", "off"):
        v = "1" if action == "on" else "0"
        sh_out("echo %s > /sys/class/gpio/gpio15/value" % v)
        print("手电筒: " + ("开" if action == "on" else "关"))
    elif action == "state":
        print("手电筒: " + sh_out("cat /sys/class/gpio/gpio15/value").replace("1", "开").replace("0", "关"))
    else:
        fail("用法: penctl.py torch on|off|state")


def cmd_volume(val):
    ensure_device()
    auth_if_needed()
    if val == "state":
        print(sh_out("amixer sget Master 2>/dev/null | grep -oE '\\[[0-9]+%\\]' | head -1"))
    elif val.isdigit() and 0 <= int(val) <= 100:
        sh_out("amixer -q sset Master %d%%" % int(val))
        print("音量: %s%%" % val)
    else:
        fail("用法: penctl.py volume <0-100|state>")


def cmd_sleep(val):
    ensure_device()
    auth_if_needed()
    sec = 0 if val == "never" else int(val)
    cfg = read_config()
    screen = cfg.get("screen", {})
    screen["sleep_duration"] = sec
    cfg["screen"] = screen
    write_config(cfg)
    print("自动息屏已设为 %s 秒（0=永不）。重启应用后生效。" % sec)


def cmd_config(action, path, value=None):
    ensure_device()
    auth_if_needed()
    cfg = read_config()
    if action == "get":
        result = resolve_key(cfg, path)
        if result is None:
            fail("键不存在: %s" % path)
        print(json.dumps(result, ensure_ascii=False))
    elif action == "set":
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            parsed = value  # 允许纯字符串/数字
        parts = path.split(".")
        cur = cfg
        for part in parts[:-1]:
            cur = cur.setdefault(part, {})
        cur[parts[-1]] = parsed
        write_config(cfg)
        print("已写入 %s = %s（重启应用后生效）" % (path, json.dumps(parsed, ensure_ascii=False)))
    else:
        fail("用法: penctl.py config get|set <键路径> [值]")


def cmd_reboot(force):
    ensure_device()
    auth_if_needed()
    if not force:
        ans = input("确认重启词典笔？[y/N] ").strip().lower()
        if ans not in ("y", "yes"):
            print("已取消")
            return
    sh_out("echo 0 > /sys/kernel/debug/touchscreen/suspend; sync; sync; reboot")
    print("重启指令已发送")


COMMANDS = {
    "status": lambda args: cmd_status(),
    "screenshot": lambda args: cmd_screenshot(args[0] if args else None),
    "brightness": lambda args: cmd_brightness(int(args[0]) if args else fail("缺少亮度值")),
    "screen": lambda args: cmd_screen(args[0] if args else fail("缺少 on/off/state")),
    "touch": lambda args: cmd_touch(args[0] if args else fail("缺少 on/off/state")),
    "torch": lambda args: cmd_torch(args[0] if args else fail("缺少 on/off/state")),
    "volume": lambda args: cmd_volume(args[0] if args else "state"),
    "sleep": lambda args: cmd_sleep(args[0] if args else fail("缺少秒数/never")),
    "config": lambda args: cmd_config(args[0], args[1], args[2] if len(args) > 2 else None)
        if len(args) >= 2 else fail("用法: penctl.py config get|set <键路径> [值]"),
    "reboot": lambda args: cmd_reboot("--yes" in args),
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    try:
        COMMANDS[sys.argv[1]](sys.argv[2:])
    except SystemExit:
        raise
    except Exception as e:
        fail(str(e))


if __name__ == "__main__":
    main()
