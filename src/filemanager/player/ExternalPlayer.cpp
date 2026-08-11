// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "filemanager/player/ExternalPlayer.h"

#include "filemanager/FileManager.h"

#include "common/Event.h"
#include "common/Utils.h"

#include <QFile>
#include <QQmlContext>
#include <QLocalSocket>
#include <QProcess>
#include <QThread>

#include <signal.h>
#include <sys/types.h>
#include <unistd.h>

namespace mod::filemanager {

ExternalPlayer::ExternalPlayer() {
    mRunning = false;
    mPollTimer = new QTimer(this);
    mPollTimer->setInterval(500);
    connect(mPollTimer, &QTimer::timeout, this, &ExternalPlayer::refreshRunning);
    mPollTimer->start();

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("externalPlayer", this);
    });
} // namespace mod::filemanager

void ExternalPlayer::select(const QString &path) {
    mOpeningFileName = path;
    emit pathChanged();
}

void ExternalPlayer::open() {
    if (mOpeningFileName.isEmpty() || mRunning) {
        return;
    }
    QString videoPlayer = "/userdisk/VideoPlayer";
    QStringList args;
    args << getOpeningPath();
    QProcess::startDetached(videoPlayer, args);
    refreshRunning();
}

void ExternalPlayer::close() {
    // 1) 优雅退出：通过 mpv 的 IPC socket 发送 quit 命令
    QLocalSocket socket;
    socket.connectToServer("/tmp/mpvsocket");
    if (socket.waitForConnected(300)) {
        socket.write("{\"command\":[\"quit\"]}\n");
        socket.flush();
        socket.waitForBytesWritten(300);
        socket.waitForDisconnected(300);
    }

    // 2) 兜底：终止 mpv 包装脚本记录的进程（其 PID 写入唤醒锁文件）
    QFile lock("/tmp/audio_wakelocks/VideoPlayer.lock");
    if (lock.open(QIODevice::ReadOnly)) {
        bool ok  = false;
        auto pid = lock.readAll().trimmed().toInt(&ok);
        lock.close();
        if (ok && pid > 0 && kill(pid, 0) == 0) {
            kill(pid, SIGTERM);
            for (int i = 0; i < 20 && kill(pid, 0) == 0; ++i) {
                QThread::msleep(100);
            }
            if (kill(pid, 0) == 0) {
                kill(pid, SIGKILL);
            }
        }
    }

    refreshRunning();
}

QString ExternalPlayer::getOpeningPath() {
    return "file://" + FileManager::getInstance().getCurrentPath().absoluteFilePath(mOpeningFileName);
}

QString ExternalPlayer::getFileName() { return mOpeningFileName; }

bool ExternalPlayer::isRunning() { return mRunning; }

void ExternalPlayer::refreshRunning() {
    bool running = false;
    QFile lock("/tmp/audio_wakelocks/VideoPlayer.lock");
    if (lock.exists() && lock.open(QIODevice::ReadOnly)) {
        QByteArray pidData = lock.readAll().trimmed();
        lock.close();
        bool ok  = false;
        auto pid = pidData.toInt(&ok);
        if (ok && pid > 0) {
            running = (kill(pid, 0) == 0);
        } else if (!pidData.isEmpty()) {
            // 锁文件刚创建、尚未写入 PID 时视为运行中
            running = true;
        }
    }
    if (running != mRunning) {
        mRunning = running;
        emit runningChanged();
    }
}

} // namespace mod::filemanager
