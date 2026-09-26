// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "system/input/InputDaemon.h"
#include "system/input/ScreenManager.h"

#include "system/battery/BatteryInfo.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "common/util/System.h"

#include <QDateTime>

#include <sstream>
#include <unistd.h>
#include <vector>

namespace mod {

InputDaemon::InputDaemon() : Logger("InputDaemon") {
    mWatchdogTimer = new QTimer(this);
    mWatchdogTimer->setInterval(60 * 1000);
    connect(mWatchdogTimer, &QTimer::timeout, this, &InputDaemon::onWatchdogTick);
    connect(&Event::getInstance(), &Event::uiCompleted, this, &InputDaemon::onUiCompleted);
}

void InputDaemon::onUiCompleted() {
    reset();
    // 看门狗在 UI 就绪后再启动（事件循环已运行）
    mWatchdogTimer->start();
}

bool InputDaemon::setScreenOff(uint32 sec) {
    mScreenOff = sec;
    if (sec > 10) {
        mBackLightDown = sec - 10;
    } else {
        mBackLightDown = 0;
    }
    _resetConfig();
    return true;
}

bool InputDaemon::setSystemSuspend(uint32 sec) {
    if (sec <= mBackLightDown && sec != 0) {
        return false;
    }
    mSystemSuspend = sec;
    _resetConfig();
    return true;
}

void InputDaemon::reset() {
    setScreenOff(ScreenManager::getInstance().getAutoSleepDuration());
    setSystemSuspend(BatteryInfo::getInstance().getAutoSuspendDuration());
}

void InputDaemon::pause() { PEN_CALL(void*, "stop_auto_screen_off")(); }

void InputDaemon::resume() { PEN_CALL(void*, "start_auto_screen_off")(); }

bool InputDaemon::_resetConfig() {
    auto cfg = _getConfig();
    // 目标是 rootfs 上的 /etc/input-event-daemon_<model>.conf：只在真正写文件的
    // 这段时间把 / 临时放开为可写，写完还原（原来是开机就整段会话保持 rw）。
    const bool wasWritable = util::isRootFileSystemWritable();
    util::setRootFileSystemWritable(true);
    std::ofstream ofile(cfg.mPath);
    if (!ofile.good()) {
        util::setRootFileSystemWritable(wasWritable);
        return false;
    }
    ofile << QString::fromStdString(cfg.mContent)
                 .replace("{backlight_down}", mBackLightDown ? QString::number(mBackLightDown) : "#")
                 .replace("{screen_off}", mScreenOff ? QString::number(mScreenOff) : "#")
                 .replace("{system_suspend}", mSystemSuspend ? QString::number(mSystemSuspend) : "#")
                 .toStdString();
    ofile.close();
    util::setRootFileSystemWritable(wasWritable);

    // 重启守护进程一律走厂商自己的脚本（它支持 restart）：
    // 它会 bind-mount 正确的配置、并以 `input-event-daemon -v` 加合适环境启动。
    // 以前这里是自己 `killall` + 裸 `input-event-daemon`，见 _restartDaemon() 的说明。
    exec("/etc/init.d/S99input-event-daemon restart", kExecNormalMs);
    return true;
}

std::string InputDaemon::_getRawConfigure(const char* model) {
    switch (H(model)) {
    case H("Cherry"):
        return R"(
#
# /etc/input-event-daemon.conf
#

[Global]
listen = /dev/input/by-path/platform-adc-keys-event
listen = /dev/input/by-path/platform-led_control-event
listen = /dev/input/by-path/platform-ff190000.i2c-event


[Keys]
#POWER        = system_sleep_wakeup auto
#POWER         = screen_onoff switch
#POWER        = system_sleep_wakeup resume
#MUTE         = amixer -q set Master mute
#FN+VOLUMEUP  = factory_reset_cfg
#CTRL+ALT+ESC = beep

[Switches]
RADIO:0 = ifconfig wlan0 down

[Idle]
{backlight_down}s = screen_onoff backlight_down
{screen_off}s = len_onoff.sh off; screen_onoff off
{system_suspend}s = killall -9 hilink-server; system_sleep_wakeup suspend
reset = sleep 0.1;screen_onoff on; sleep 1; killall -9 system_sleep_wakeup
)";
    case H("Cherry_3566"):
        return R"(#
# /etc/input-event-daemon.conf
#

[Global]
listen = /dev/input/by-path/platform-adc-keys-event
listen = /dev/input/by-path/platform-led_control-event
listen = /dev/input/by-path/platform-fe5a0000.i2c-event

[Keys]
#POWER        = system_sleep_wakeup auto
#POWER         = screen_onoff switch
#POWER        = system_sleep_wakeup resume
#MUTE         = amixer -q set Master mute
#FN+VOLUMEUP  = factory_reset_cfg
#CTRL+ALT+ESC = beep

[Switches]
RADIO:0 = ifconfig wlan0 down

[Idle]
{backlight_down}s = screen_onoff backlight_down
{screen_off}s = len_onoff.sh off; screen_onoff off
{system_suspend}s = killall -9 hilink-server; system_sleep_wakeup suspend
reset = sleep 0.1; screen_onoff on; system_post_wakeup; sleep 1; killall -9 system_sleep_wakeup
)";
    case H("V4"):
        return R"(
#
# /etc/input-event-daemon.conf
#

[Global]
listen = /dev/input/event2
listen = /dev/input/event3
listen = /dev/input/event4

[Keys]
#POWER        = system_sleep_wakeup auto
#POWER         = screen_onoff switch
#POWER        = system_sleep_wakeup resume
#MUTE         = amixer -q set Master mute
#FN+VOLUMEUP  = factory_reset_cfg
#CTRL+ALT+ESC = beep

[Switches]
RADIO:0 = ifconfig wlan0 down

[Idle]
{backlight_down}s = screen_onoff backlight_down
{screen_off}s = len_onoff.sh off; screen_onoff off
{system_suspend}s = killall -9 hilink-server; system_sleep_wakeup suspend
reset = screen_onoff on; sleep 1; killall -9 system_sleep_wakeup
)";
    case H("Exam"):
        return R"(
#
# /etc/input-event-daemon.conf
#

[Global]
listen = /dev/input/event2
listen = /dev/input/event3
listen = /dev/input/event4

[Keys]
#POWER        = system_sleep_wakeup auto
#POWER         = screen_onoff switch
#POWER        = system_sleep_wakeup resume
#MUTE         = amixer -q set Master mute
#FN+VOLUMEUP  = factory_reset_cfg
#CTRL+ALT+ESC = beep

[Switches]
RADIO:0 = ifconfig wlan0 down

[Idle]
{backlight_down}s = screen_onoff backlight_down
{screen_off}s = len_onoff.sh off; screen_onoff off
{system_suspend}s = killall -9 hilink-server; system_sleep_wakeup suspend
reset = sleep 0.1; screen_onoff on; system_post_wakeup; sleep 1; killall -9 system_sleep_wakeup
)";
    case H("V0"):
    default:
        return R"(#
# /etc/input-event-daemon.conf
#

[Global]
listen = /dev/input/event1
listen = /dev/input/event2
listen = /dev/input/event3

[Keys]
#POWER        = system_sleep_wakeup auto
#POWER         = screen_onoff switch
#POWER        = system_sleep_wakeup resume
#MUTE         = amixer -q set Master mute
#FN+VOLUMEUP  = factory_reset_cfg
#CTRL+ALT+ESC = beep

[Switches]
RADIO:0 = ifconfig wlan0 down

[Idle]
{backlight_down}s = screen_onoff backlight_down
{screen_off}s = len_onoff.sh off; screen_onoff off
{system_suspend}s = system_sleep_wakeup suspend
reset = screen_onoff on; sleep 1; killall -9 system_sleep_wakeup
)";
    }
}

InputDaemon::Config InputDaemon::_getConfig() {
    // 与 ASound 共用同一个缓存过的板型探测（EX-10 / SD-08）：
    // `get_pcba_version` 是 /bin/sh 脚本，以前两处各 fork 一遍。
    const std::string pcba = util::pcbaVersion();
    if (pcba == "Dictpen2.0_V4") {
        return {"/etc/input-event-daemon_V4.conf", _getRawConfigure("V4")};
    }
    if (pcba == "Dictpen2.0_V0") {
        return {"/etc/input-event-daemon_V0.conf", _getRawConfigure("V0")};
    }
    if (pcba == "Exam_V0") {
        return {"/etc/input-event-daemon_Exam.conf", _getRawConfigure("Exam")};
    }
    if (pcba.find("Cherry_V0") != std::string::npos) {
        return {"/etc/input-event-daemon_Cherry.conf", _getRawConfigure("Cherry")};
    }
    if (pcba.find("Cherry-3566") != std::string::npos || pcba == "Kiwi-3566_V0") {
        return {"/etc/input-event-daemon_Cherry-3566.conf", _getRawConfigure("Cherry_3566")};
    }
    warn("Unable to find a matching input-event-daemon configuration file for this pcba({}).", pcba);
    return {"/etc/input-event-daemon_V0.conf", _getRawConfigure("V0")};
}

void InputDaemon::onWatchdogTick() {
    if (mWatchdogDisabled) {
        return;
    }

    auto pidStr = exec("pidof input-event-daemon", kExecQuickMs);
    pid_t pid   = -1;
    try {
        pid = std::stoi(pidStr);
    } catch (...) {
        pid = -1;
    }

    if (pid <= 0) {
        // daemon 已退出，直接拉起
        warn("input-event-daemon 未在运行，看门狗拉起");
        _restartDaemon();
        return;
    }

    bool   ok    = false;
    uint64 ticks = _readDaemonTicks(pid, ok);
    if (!ok) {
        mWatchdogPid = -1;
        return;
    }

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (mWatchdogPid == pid && mWatchdogLastTimeMs > 0 && ticks >= mWatchdogLastTicks) {
        double dt = (now - mWatchdogLastTimeMs) / 1000.0;
        if (dt > 0) {
            double usage =
                double(ticks - mWatchdogLastTicks) / (double(sysconf(_SC_CLK_TCK)) * dt);
            if (usage > 0.15) {
                mWatchdogBusyCount++;
                warn("input-event-daemon CPU {:.0f}%（第 {} 次连续偏高）", usage * 100.0, mWatchdogBusyCount);
                if (mWatchdogBusyCount >= 3) {
                    warn("input-event-daemon 疑似忙循环，看门狗重启...");
                    _restartDaemon();
                    mWatchdogBusyCount = 0;
                    mWatchdogPid       = -1;
                    mWatchdogLastTimeMs = 0;
                }
            } else {
                mWatchdogBusyCount = 0;
            }
        }
    }

    mWatchdogPid        = pid;
    mWatchdogLastTicks  = ticks;
    mWatchdogLastTimeMs = now;
}

bool InputDaemon::_restartDaemon() {
    mWatchdogRestarts++;
    if (mWatchdogRestarts >= 3) {
        mWatchdogDisabled = true;
        warn("input-event-daemon 重启多次仍异常，看门狗已停用");
        return false;
    }
    // 以前这里是 `killall input-event-daemon` + 裸 `input-event-daemon`。
    // 这个 2021 年的老程序对"启动方式"敏感：被手工拉起时有时会卡进忙循环
    // （实测 100% 一个核、wchan=0、纯用户态空转、且只在启动后出现），
    // 看门狗于是反复"修"它、3 次无效后放弃 —— 最终留下一个 100% 的实例。
    // 这就是"装了新版 PenMods 后放音乐会卡"的根因（1.0 没有这个看门狗，反而正常）。
    // 改成调厂商自己的 init 脚本：它做 `mount --bind` 配置 + 以 `-v` 启动，
    // 和开机时完全一致，不会再制造坏实例。
    exec("/etc/init.d/S99input-event-daemon restart", kExecNormalMs);
    info("input-event-daemon 已通过厂商脚本重启");
    return true;
}

uint64 InputDaemon::_readDaemonTicks(pid_t pid, bool& ok) {
    ok = false;
    auto s = readFile(("/proc/" + std::to_string(pid) + "/stat").c_str());
    auto closeParen = s.rfind(')');
    // /proc/pid/stat: "pid (comm) state ppid ... utime stime ..."
    if (closeParen == std::string::npos || closeParen + 2 >= s.size()) {
        return 0;
    }
    std::string rest = s.substr(closeParen + 2);
    std::vector<std::string> fields;
    std::istringstream iss(rest);
    std::string token;
    while (iss >> token) {
        fields.push_back(token);
    }
    // fields[0]=state, fields[1]=ppid, ..., fields[11]=utime, fields[12]=stime
    if (fields.size() < 13) {
        return 0;
    }
    try {
        uint64 utime = std::stoull(fields[11]);
        uint64 stime = std::stoull(fields[12]);
        ok           = true;
        return utime + stime;
    } catch (...) {
        return 0;
    }
}

} // namespace mod
