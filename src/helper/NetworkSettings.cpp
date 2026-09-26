// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "helper/NetworkSettings.h"

#include "common/Event.h"

#include <QAbstractSocket>
#include <QFile>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QNetworkProxy>
#include <QQmlContext>
#include <QStringList>

namespace mod {

NetworkSettings::NetworkSettings() {

    mCfg = Config::getInstance().read(mClassName);

    mProxyEnabled  = mCfg["proxy_enabled"];
    mProxyType     = mCfg["proxy_type"];
    mProxyHostName = QString::fromStdString(mCfg["proxy_hostname"]);
    mProxyPort     = mCfg["proxy_port"];
    mProxyUserName = QString::fromStdString(mCfg["proxy_username"]);
    mProxyPassword = QString::fromStdString(mCfg["proxy_password"]);

    connect(this, &NetworkSettings::proxyEnabledChanged, this, &NetworkSettings::_refreshApplicationProxy);
    connect(this, &NetworkSettings::proxyTypeChanged, this, &NetworkSettings::_refreshApplicationProxy);
    connect(this, &NetworkSettings::proxyHostNameChanged, this, &NetworkSettings::_refreshApplicationProxy);
    connect(this, &NetworkSettings::proxyPortChanged, this, &NetworkSettings::_refreshApplicationProxy);
    connect(this, &NetworkSettings::proxyUserNameChanged, this, &NetworkSettings::_refreshApplicationProxy);
    connect(this, &NetworkSettings::proxyPasswordChanged, this, &NetworkSettings::_refreshApplicationProxy);

    _refreshApplicationProxy();

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("networkSettings", this);
    });
}

bool NetworkSettings::getProxyEnabled() const { return mProxyEnabled; }
void NetworkSettings::setProxyEnabled(bool enabled) {
    if (mProxyEnabled != enabled) {
        mProxyEnabled         = enabled;
        mCfg["proxy_enabled"] = enabled;
        WRITE_CFG;
        emit proxyEnabledChanged();
    }
}

NetworkSettings::Type NetworkSettings::getProxyType() const { return mProxyType; }
void                  NetworkSettings::setProxyType(Type type) {
    if (mProxyType != type) {
        mProxyType         = type;
        mCfg["proxy_type"] = type;
        WRITE_CFG;
        emit proxyTypeChanged();
    }
}

QString NetworkSettings::getProxyHostName() const { return mProxyHostName; }
void    NetworkSettings::setProxyHostName(const QString& hostName) {
    if (mProxyHostName != hostName) {
        mProxyHostName         = hostName;
        mCfg["proxy_hostname"] = hostName.toStdString();
        WRITE_CFG;
        emit proxyHostNameChanged();
    }
}

int  NetworkSettings::getProxyPort() const { return mProxyPort; }
void NetworkSettings::setProxyPort(int port) {
    if (mProxyPort != port) {
        mProxyPort         = port;
        mCfg["proxy_port"] = port;
        WRITE_CFG;
        emit proxyPortChanged();
    }
}

QString NetworkSettings::getProxyUserName() const { return mProxyUserName; }
void    NetworkSettings::setProxyUserName(const QString& userName) {
    if (mProxyUserName != userName) {
        mProxyUserName         = userName;
        mCfg["proxy_username"] = userName.toStdString();
        WRITE_CFG;
        emit proxyUserNameChanged();
    }
}

QString NetworkSettings::getProxyPassword() const { return mProxyPassword; }
void    NetworkSettings::setProxyPassword(const QString& password) {
    if (mProxyPassword != password) {
        mProxyPassword         = password;
        mCfg["proxy_password"] = password.toStdString();
        WRITE_CFG;
        emit proxyPasswordChanged();
    }
}

void NetworkSettings::_refreshApplicationProxy() {
    QNetworkProxy proxy;
    proxy.setType([this]() {
        if (!mProxyEnabled) {
            return QNetworkProxy::NoProxy;
        }
        switch (mProxyType) {
        case Socks5:
            return QNetworkProxy::Socks5Proxy;
        case HTTP:
            return QNetworkProxy::HttpProxy;
        default:
            return QNetworkProxy::NoProxy;
        }
    }());
    proxy.setHostName(mProxyHostName);
    proxy.setPort(mProxyPort);
    if (!mProxyUserName.isEmpty()) {
        proxy.setUser(mProxyUserName);
        proxy.setPassword(mProxyPassword);
    }
    QNetworkProxy::setApplicationProxy(proxy);
}

// 下面三个都是 `Q_PROPERTY` 的 READ，`ConfigureNetworkPage.qml:39/45/51` **同一屏绑了三条**，
// 而 `networkChanged` 由厂商的 WiFi hook `_ZN12YWifiManager22internetConnectChangedEv` 驱动
// ⇒ **每次联网状态抖动，一屏就是三个 shell**（`getLocalIpAddress` 那条还是 5 段管道 / 6 个进程）。
//
// EX-08：三条信息都有无 fork 的来源（内核接口 / `/proc` / `/etc` 文件），逐个换掉。
// Q_PROPERTY 的 READ 里不能 fork —— 这是同项目自己在 `Torch.cpp:29` 写下的规则。

QString NetworkSettings::getLocalIpAddress() const {
    for (const QHostAddress& addr : QNetworkInterface::allAddresses()) {
        // 只取 IPv4、跳过 127.0.0.1（对应原来那三段 grep 的意图）。
        // 多个网卡时返回第一个 —— UI 只有一行 describe，列出全部反而显示不下。
        if (addr.protocol() == QAbstractSocket::IPv4Protocol && !addr.isLoopback()) {
            return addr.toString();
        }
    }
    return "不可用";
}

QString NetworkSettings::getNetGateway() const {
    // 默认路由 = `/proc/net/route` 里 Destination 为 `00000000` 的那行。
    // ⚠️ Gateway 字段是**小端**十六进制：设备上实测 `0100A8C0` → 192.168.0.1。
    QFile route("/proc/net/route");
    if (!route.open(QIODevice::ReadOnly)) {
        return "不可用";
    }
    const QStringList lines = QString::fromUtf8(route.readAll()).split('\n');
    for (int i = 1; i < lines.size(); ++i) { // 第 0 行是表头
        const QStringList fields = lines.at(i).simplified().split(' ');
        if (fields.size() < 3 || fields.at(1) != "00000000") {
            continue; // 不是默认路由
        }
        bool ok = false;
        const quint32 gw = fields.at(2).toUInt(&ok, 16);
        if (!ok || gw == 0) {
            continue; // 网关为 0 表示直连，没有默认网关
        }
        // 小端：内核把 32 位地址按字节倒序写成 8 个十六进制字符，翻回来再输出。
        const int b0 = static_cast<int>((gw >> 24) & 0xFF);
        const int b1 = static_cast<int>((gw >> 16) & 0xFF);
        const int b2 = static_cast<int>((gw >> 8) & 0xFF);
        const int b3 = static_cast<int>(gw & 0xFF);
        return QString::number(b3) + "." + QString::number(b2) + "." + QString::number(b1) + "."
             + QString::number(b0);
    }
    return "不可用";
}

QString NetworkSettings::getDNS() const {
    QFile resolv("/etc/resolv.conf");
    if (!resolv.open(QIODevice::ReadOnly)) {
        return "不可用";
    }
    const QStringList lines = QString::fromUtf8(resolv.readAll()).split('\n');
    QStringList       servers;
    for (const QString& line : lines) {
        const QStringList fields = line.simplified().split(' ');
        if (fields.size() >= 2 && fields.at(0) == "nameserver") {
            servers << fields.at(1);
        }
    }
    if (servers.isEmpty()) {
        return "不可用";
    }
    // 实测设备上有两条（223.5.5.5 / 223.6.6.6）。旧实现的 awk 是按行输出的，
    // 这里用空格连起来 —— UI 只有一行 describe。
    return servers.join(" ");
}

} // namespace mod

PEN_HOOK(void*, _ZN12YWifiManager22internetConnectChangedEv, void* a1, void* a2, void* a3, void* a4, void* a5) {
    emit mod::NetworkSettings::getInstance().networkChanged();
    return origin(a1, a2, a3, a4, a5);
}
