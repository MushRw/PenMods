// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "system/input/ScreenManager.h"
#include "system/input/InputDaemon.h"
#include "system/sound/AudioDaemon.h"

#include "filemanager/player/MusicPlayer.h"

#include "base/YEnum.h"

#include "common/Event.h"

#include <QQmlContext>

namespace mod {

ScreenManager::ScreenManager() {

    mCfg = Config::getInstance().read(mClassName);

    mAutoSleepDuration    = mCfg["sleep_duration"];
    mIntelSleep           = mCfg["intel_sleep"];
    mIntelSleepAudioLock  = mCfg["intel_sleep_audio_lock"];
    mLockScreen           = mCfg.value("lock_screen", true);

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("screenManager", this);
    });

    connect(&AudioDaemon::getInstance(), &AudioDaemon::stateChanged, this, &ScreenManager::onAudioDaemonStateChanged);
}

void ScreenManager::onPlayStateChanged(PlayState state) {
    mPlayState = state;
    updateScreenOff();
}

void ScreenManager::onLrcShowChanged(bool show) {
    mLrcShowing = show;
    updateScreenOff();
}

void ScreenManager::onInPlayerPageChanged(bool in) {
    mInPlayerPage = in;
    updateScreenOff();
}

// Dynamic Actions
void ScreenManager::reportAction(const QString& action) {
    // KB-04/05：所有"是否禁止息屏"的判定收敛到 updateScreenOff() 单一真源，
    // 不再在各个回调里各自 pause/resume（那样会互相抵消，见 KB-05）。
    // 智能休眠开关在 updateScreenOff() 内部统一处理。
    switch (H(action.toLocal8Bit().data())) {
    case H("wordbook_cardview_enter"):
        mInWordbookCard = true;
        updateScreenOff();
        break;
    case H("wordbook_cardview_quit"):
        mInWordbookCard = false;
        updateScreenOff();
        break;
    case H("musicplayer_lrc_show"):
        onLrcShowChanged(true);
        break;
    case H("musicplayer_lrc_hide"):
        onLrcShowChanged(false);
        break;
    }
}

QString ScreenManager::getAutoSleepDurationStr() const {
    auto dur = getAutoSleepDuration();
    if (dur == 0) {
        return "永不";
    }
    if (dur == 30) {
        return "30秒";
    }
    return QString::fromStdString(std::to_string(dur / 60) + "分钟");
}

void ScreenManager::setAutoSleepDurationStr(const QString& str) {
    int dur = 30;
    if (str == "永不") {
        dur = 0;
    }
    if (str.contains("秒")) {
        dur = (int)strtol(str.mid(0, str.indexOf("秒")).toStdString().c_str(), nullptr, 10);
    }
    if (str.contains("分")) {
        dur = (int)strtol(str.mid(0, str.indexOf("分")).toStdString().c_str(), nullptr, 10) * 60;
    }
    setAutoSleepDuration(dur);
}

int ScreenManager::getAutoSleepDuration() const { return mAutoSleepDuration; }

bool ScreenManager::getIntelSleep() const { return mIntelSleep; }

void ScreenManager::setAutoSleepDuration(int val) {
    if (mAutoSleepDuration != val) {
        mAutoSleepDuration     = val;
        mCfg["sleep_duration"] = val;
        InputDaemon::getInstance().setScreenOff(val);
        WRITE_CFG;
        emit autoSleepDurationChanged();
    }
}

void ScreenManager::setIntelSleep(bool val) {
    if (mIntelSleep != val) {
        mIntelSleep         = val;
        mCfg["intel_sleep"] = val;
        WRITE_CFG;
        emit intelSleepChanged();
    }
}

bool ScreenManager::getIntelSleepAudioLock() const { return mIntelSleepAudioLock; }

bool ScreenManager::getLockScreen() const { return mLockScreen; }

void ScreenManager::setIntelSleepAudioLock(bool val) {
    if (mIntelSleepAudioLock != val) {
        mIntelSleepAudioLock         = val;
        mCfg["intel_sleep_audio_lock"] = val;
        WRITE_CFG;
        emit intelSleepAudioLockChanged();
        onAudioDaemonStateChanged();
    }
}

void ScreenManager::setLockScreen(bool val) {
    if (mLockScreen != val) {
        mLockScreen         = val;
        mCfg["lock_screen"] = val;
        WRITE_CFG;
        emit lockScreenChanged();
    }
}

void ScreenManager::onAudioDaemonStateChanged() {
    bool audioActive = AudioDaemon::getInstance().state() == AudioDaemonState::PLAYING;
    if (mIntelSleepAudioLock && audioActive && !mAudioLockActive) {
        mAudioLockActive = true;
    } else if (mAudioLockActive && (!audioActive || !mIntelSleepAudioLock)) {
        mAudioLockActive = false;
    }
    updateScreenOff();
}

void ScreenManager::updateScreenOff() {
    // KB-04：智能休眠关 → 永远允许息屏（不再只在 reportAction 拦，其它回调也要拦）。
    if (!getIntelSleep()) {
        InputDaemon::getInstance().resume();
        return;
    }
    // KB-05：所有"禁止息屏"来源（音频锁 / 单词本卡片 / 播放中且看歌词且在播放页）
    // 合并成一个布尔，单一出口决定 pause/resume，避免各自 pause/resume 互相抵消
    //（例如歌词页 pause → 单词本 pause → 退出单词本 resume → 歌词还在看却已息屏）。
    bool prevent = mAudioLockActive
                || mInWordbookCard
                || (mPlayState == PlayState::PLAYING && mLrcShowing && mInPlayerPage);
    rtSetAutoScreenOff(!prevent);
}

void ScreenManager::rtSetAutoScreenOff(bool val) {
    val ? InputDaemon::getInstance().resume() : InputDaemon::getInstance().pause();
}

} // namespace mod

// MusicPlayer
PEN_HOOK(uint64, _ZN7YGlobal27isInPlayerCenterPageChangedEv, uint64 self, uint64 a2, uint64 a3, uint64 a4, uint64 a5) {
    bool isInPage = PEN_CALL(bool, "_ZNK7YGlobal20isInPlayerCenterPageEv", uint64)(self);
    mod::ScreenManager ::getInstance().onInPlayerPageChanged(isInPage);
    // 离开播放器页面时，清理文件管理器创建的临时软链接
    if (!isInPage) {
        mod::filemanager::MusicPlayer::getInstance().cleanupTempSymlinks();
    }
    return origin(self, a2, a3, a4, a5);
}

PEN_HOOK(
    uint64,
    _ZN19YMediaPlayerManager16playStateChangedEv,
    uint64 self,
    uint64 a2,
    uint64 a3,
    uint64 a4,
    uint64 a5
) {
    mod::ScreenManager ::getInstance().onPlayStateChanged(
        PEN_CALL(PlayState, "_ZNK19YMediaPlayerManager9playStateEv", uint64)(self)
    );
    return origin(self, a2, a3, a4, a5);
}
