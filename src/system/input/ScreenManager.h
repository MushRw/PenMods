// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "base/YEnum.h"
#include "base/YPointer.h"

#include "common/Utils.h"

#include "mod/Config.h"

#include <QTimer>

namespace mod {

class ScreenManager : public QObject, public Singleton<ScreenManager> {
    Q_OBJECT

    Q_PROPERTY(QString autoShutdownDuration READ getAutoShutdownDurationStr WRITE setAutoShutdownDurationStr NOTIFY
                   autoShutdownDurationChanged);
    Q_PROPERTY(int intelSleep READ getIntelSleep WRITE setIntelSleep NOTIFY intelSleepChanged);
    Q_PROPERTY(bool intelSleepAudioLock READ getIntelSleepAudioLock WRITE setIntelSleepAudioLock NOTIFY
                   intelSleepAudioLockChanged);
    Q_PROPERTY(bool lockScreen READ getLockScreen WRITE setLockScreen NOTIFY lockScreenChanged);

public:
    QString getAutoSleepDurationStr() const;
    QString getAutoShutdownDurationStr() const;

    int getAutoSleepDuration() const;

    bool getIntelSleep() const;

    bool getIntelSleepAudioLock() const;

    bool getLockScreen() const;

    void setAutoSleepDurationStr(const QString&);
    void setAutoShutdownDurationStr(const QString&);

    void setAutoSleepDuration(int);

    void setIntelSleep(bool);

    void setIntelSleepAudioLock(bool);

    void setLockScreen(bool);

    Q_INVOKABLE void reportAction(const QString&);

    // runtime
    void rtSetAutoScreenOff(bool);

    void onPlayStateChanged(PlayState);

    void onLrcShowChanged(bool);

    void onInPlayerPageChanged(bool);

    void onAudioDaemonStateChanged();
    void setSystemBase(YSystemBase* systemBase);
    void resetInactivityTimer();
    void requestPowerOff();

    // 所有"是否禁止息屏"的判定收敛到这一个出口（KB-04/05）。
    void updateScreenOff();

signals:

    void autoSleepDurationChanged();
    void autoShutdownDurationChanged();

    void intelSleepChanged();

    void intelSleepAudioLockChanged();

    void lockScreenChanged();

private:
    friend Singleton<ScreenManager>;
    explicit ScreenManager();

    std::string mClassName = "screen";
    json        mCfg;

    int  mAutoSleepDuration;
    int  mAutoShutdownDuration{0};
    QTimer mInactivityTimer;
    bool mIntelSleep;
    bool mIntelSleepAudioLock;
    bool mLockScreen;
    bool mAudioLockActive = false;

    YSystemBase* mSystemBase = nullptr;

    // Tmp saving;
    bool      mLrcShowing      = false;
    bool      mInPlayerPage    = false;
    bool      mInWordbookCard  = false;
    PlayState mPlayState       = PlayState::STOPPED;
};

} // namespace mod
