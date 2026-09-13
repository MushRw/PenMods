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

    // 自带扬声器总开关（随时“卸载/加载”扬声器，防止不小心外放）：
    // 关闭时把生成的 asound.conf 里扬声器通路的 Playback Path 由 SPK 改成 OFF，
    // TTS / 音乐 / 提示音都推不动扬声器；耳机通路（HP）保持原样，插耳机照常有声。
    Q_PROPERTY(bool speakerEnabled READ isSpeakerEnabled WRITE setSpeakerEnabled NOTIFY speakerEnabledChanged)

public:
    void onUiCompleted();

    struct VoiceDb {
        float min;
        float max;
    };

    bool setDb(VoiceDb);

    VoiceDb getDb();

    [[nodiscard]] bool isSpeakerEnabled() const;

    // 立即重写 asound.conf、把当前播放通路切到 OFF、停掉提示音进程，并把状态写进 config.json
    void setSpeakerEnabled(bool);

signals:

    void speakerEnabledChanged();

private:
    friend Singleton<ASound>;
    explicit ASound();

    struct Config {
        std::string mPath;
        std::string mContent;
    };

    VoiceDb mVoiceDb{};

    bool mSpeakerEnabled{true};

    bool _resetConfig();

    Config _getConfig();

    std::string _getRawConfigure(const char* model);
};

} // namespace mod
