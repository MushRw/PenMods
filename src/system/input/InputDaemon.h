// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Logger.h"

#include <QTimer>

namespace mod {

class InputDaemon : public QObject, public Singleton<InputDaemon>, private Logger {
    Q_OBJECT

public:
    void onUiCompleted();

    // Set to 0 will never execute;
    bool setScreenOff(uint32 sec);
    bool setSystemSuspend(uint32 sec);

    // Reset input daemon from cfg.
    void reset();

    // temporary settings.
    void pause();

    void resume();

private:
    friend Singleton<InputDaemon>;
    explicit InputDaemon();

    struct Config {
        std::string mPath;
        std::string mContent;
    };

    uint32 mBackLightDown = 30;
    uint32 mScreenOff     = 60;
    uint32 mSystemSuspend = 600;

    bool _resetConfig();

    Config _getConfig();

    std::string _getRawConfigure(const char* model);

    // input-event-daemon 忙循环看门狗：
    // 厂商 daemon 长时间运行后可能陷入高 CPU 空转（实测 ~25%），
    // 周期性采样其 CPU，持续偏高则重启一次；反复重启无效则停用看门狗。
    void   onWatchdogTick();
    bool   _restartDaemon();
    uint64 _readDaemonTicks(pid_t pid, bool& ok);

    QTimer* mWatchdogTimer       = nullptr;
    int     mWatchdogBusyCount   = 0;
    int     mWatchdogRestarts    = 0;
    bool    mWatchdogDisabled    = false;
    pid_t   mWatchdogPid         = -1;
    uint64  mWatchdogLastTicks   = 0;
    qint64  mWatchdogLastTimeMs  = 0;
};

} // namespace mod
