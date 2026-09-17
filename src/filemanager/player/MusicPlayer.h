// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "base/YEnum.h"

#include "common/service/Logger.h"

#include <QDir>
#include <QTimer>

namespace mod::filemanager {

using PlayFile = std::shared_ptr<QFileInfo>;
using PlayList = std::vector<PlayFile>;

class MusicPlayer : public QObject, public Singleton<MusicPlayer>, private Logger {
    Q_OBJECT

public:
    void play(size_t idx);

    Q_INVOKABLE void clickNext();

    Q_INVOKABLE void clickPrev();

    Q_INVOKABLE void clickRand();

    void onSoundEnd();

    PlayList& getPlayListRef() { return mPlayList; };

    static AudioSequence getCurrentAudioSequence();

    static bool mIsTakeOver;

    /// 供 QML 用：当前播放是否由 mod 接管。
    ///
    /// 接管时必须直接调上面的 clickNext/clickPrev，**不能**走厂商的
    /// mediaPlayerManager.onClickedNext/onClickedPrev：那两个符号会被别的插件
    /// （如 lx-pen）先 hook 走，PenMods 的同名 hook 会失败（实测三条
    /// "Fail to hook: onClickedPrev/Next/onSoundEnd"），而厂商原逻辑又不认识
    /// mod 注入的 fake 实体，结果是切歌无效。
    Q_INVOKABLE bool isTakeOver() const { return mIsTakeOver; }

    /// 供 QML 调⽤：释放当前 MUSIC 引⽤（播放停⽌/关闭播放器时）
    Q_INVOKABLE void releaseAudio();

    /// 清理当前临时软链接
    void cleanupTempSymlinks();

private:
    friend Singleton<MusicPlayer>;
    explicit MusicPlayer();

    PlayList mPlayList;

    struct {
        PlayFile mFile;
        size_t   mIndex{0};
        bool     mIsEnd{true};

        void setPlaying(size_t idx) {
            mIsEnd = false;
            mIndex = idx;
        }

    } mCurrentPlaying;

    /// 为指定文件在 /tmp 创建 .mp3 后缀的临时软链接
    /// @return 返回 .mp3 软链接路径，若原文件已是 .mp3 则返回原路径
    QString createTempSymlinks(const PlayFile& file, QString& outLrcPath);

    void _play(const PlayFile& file);

    // 临时软链接路径，用于清理
    QString mTempAudioLink;
};
} // namespace mod::filemanager
