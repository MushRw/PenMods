// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Logger.h"

namespace mod {

class ASound : public QObject, public Singleton<ASound>, private Logger {
    Q_OBJECT

public:
    struct VoiceDb {
        float min;
        float max;
    };

    bool setDb(VoiceDb);

    VoiceDb getDb();

private:
    friend Singleton<ASound>;
    explicit ASound();

    struct Config {
        std::string mPath;
        std::string mContent;
    };

    // 默认值取厂商标定值（外级 softvol -40.0 / -1.8）。
    // 原来是 {0.0, -50.0} —— min > max，一旦有人把它写进 rootfs 上的
    // /etc/asound.conf.<model> 就会得到反的音量曲线，且穿透 bind mount 不可回滚（SD-06）。
    VoiceDb mVoiceDb{-40.0f, -1.8f};

    bool _resetConfig();

    // `get_pcba_version` 是个 /bin/sh 脚本（读 GPIO/ADC 判板型），每次 setDb 都 fork 一遍
    // 是纯浪费；板型是硬件跳线，运行期不会变，嗅探一次即可（SD-08）。
    // 失败（exec 抛异常 / 返回空）时不写入，下次调用会重试。
    std::string mPcba;

    Config _getConfig();

    std::string _getRawConfigure(const char* model);
};

} // namespace mod
