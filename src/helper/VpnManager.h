// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Singleton.h"

#include <QObject>
#include <QProcess>

namespace mod {

// 基于 mihomo（Clash.Meta）的 VPN 代理管理：
// - 订阅链接写入 config，mihomo 以 mixed 端口(7890)本地代理
// - 启用时启动 mihomo 并设置 Qt 应用级代理，关闭时停止并恢复
// - mihomo 二进制随安装包分发（mihomo.gz），缺失时自动解压部署
class VpnManager : public QObject, public Singleton<VpnManager> {
    Q_OBJECT

    Q_PROPERTY(bool enabled READ isEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString subscriptionUrl READ getSubscriptionUrl WRITE setSubscriptionUrl NOTIFY subscriptionUrlChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)

public:
    bool isEnabled() const;

    QString getSubscriptionUrl() const;

    bool isRunning() const;

    Q_INVOKABLE void setSubscriptionUrl(const QString& url);

    Q_INVOKABLE void setEnabled(bool on);

    Q_INVOKABLE void stop();

signals:

    void enabledChanged();
    void subscriptionUrlChanged();
    void runningChanged();

private:
    friend Singleton<VpnManager>;
    explicit VpnManager();

    void start();
    bool ensureMihomo();
    bool writeConfig();

    std::string mClassName = "vpn";

    QString   mSubscriptionUrl;
    bool      mEnabled;
    bool      mRunning;
    QProcess* mProcess;
};

} // namespace mod
