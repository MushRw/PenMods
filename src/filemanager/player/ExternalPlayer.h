// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Singleton.h"

#include <QObject>
#include <QTimer>

namespace mod::filemanager {

class ExternalPlayer : public QObject, public Singleton<ExternalPlayer> {
    Q_OBJECT

    Q_PROPERTY(QString path READ getOpeningPath NOTIFY pathChanged)
    Q_PROPERTY(QString fileName READ getFileName NOTIFY pathChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)

public:
    // 只记录要打开的文件，不启动播放器（由 QML 播放页的播放按钮触发 open）
    Q_INVOKABLE void select(const QString &path);

    // 启动外部播放器（/userdisk/VideoPlayer），若已在运行则忽略
    Q_INVOKABLE void open();

    // 退出外部播放器：优先通过 mpv IPC 优雅退出，失败则终止锁文件中的进程
    Q_INVOKABLE void close();

    Q_INVOKABLE bool isRunning();

    QString getOpeningPath();
    QString getFileName();

signals:

    void pathChanged();
    void runningChanged();

private:
    friend Singleton<ExternalPlayer>;
    explicit ExternalPlayer();

    void refreshRunning();

    QString mOpeningFileName;
    QTimer* mPollTimer;
    bool    mRunning;
};

}
