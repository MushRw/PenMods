// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "helper/VpnManager.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "mod/Config.h"

#include <QDir>
#include <QFile>
#include <QNetworkProxy>
#include <QThread>

#include <spdlog/spdlog.h>

namespace mod {

namespace {

constexpr const char* kVpnDir    = "/userdata/PenMods/vpn";
constexpr const char* kMihomo    = "/userdata/PenMods/vpn/mihomo";
constexpr const char* kMihomoGz  = "/userdata/PenMods/vpn/mihomo.gz";
constexpr const char* kConfig    = "/userdata/PenMods/vpn/config.yaml";
constexpr int         kMixedPort = 7890;

} // namespace

VpnManager::VpnManager() : mEnabled(false), mRunning(false), mProcess(nullptr) {
    json cfg = Config::getInstance().read(mClassName);
    if (cfg.contains("subscription_url")) {
        mSubscriptionUrl = QString::fromStdString(cfg["subscription_url"].get<std::string>());
    }
    if (cfg.contains("enabled")) {
        mEnabled = cfg["enabled"].get<bool>();
    }

    connect(&Event::getInstance(), &Event::uiCompleted, this, [this]() {
        // 开机自动连接（配置里开启时）
        if (mEnabled) {
            start();
        }
    });
}

bool VpnManager::isEnabled() const { return mEnabled; }

QString VpnManager::getSubscriptionUrl() const { return mSubscriptionUrl; }

bool VpnManager::isRunning() const { return mRunning; }

void VpnManager::setSubscriptionUrl(const QString& url) {
    if (mSubscriptionUrl != url) {
        mSubscriptionUrl = url;
        json cfg         = Config::getInstance().read(mClassName);
        cfg["subscription_url"] = url.toStdString();
        Config::getInstance().write(mClassName, cfg, true);
        emit subscriptionUrlChanged();
    }
}

void VpnManager::setEnabled(bool on) {
    if (mEnabled == on) {
        return;
    }
    mEnabled = on;
    json cfg  = Config::getInstance().read(mClassName);
    cfg["enabled"] = on;
    Config::getInstance().write(mClassName, cfg, true);
    emit enabledChanged();

    if (on) {
        start();
    } else {
        stop();
    }
}

void VpnManager::start() {
    if (mRunning) {
        return;
    }
    if (mSubscriptionUrl.isEmpty()) {
        spdlog::warn("[Vpn] 未配置订阅链接，无法启动");
        return;
    }
    if (!ensureMihomo() || !writeConfig()) {
        return;
    }

    if (!mProcess) {
        mProcess = new QProcess(this);
    }
    mProcess->setWorkingDirectory(kVpnDir);
    mProcess->setProgram(kMihomo);
    mProcess->setArguments({"-d", kVpnDir, "-f", "config.yaml"});
    mProcess->start();
    if (!mProcess->waitForStarted(3000)) {
        spdlog::error("[Vpn] mihomo 启动失败: {}", mProcess->errorString().toStdString());
        mProcess->kill();
        return;
    }

    // 应用级代理：笔上 Qt 应用（含插件）的联网走本地 mixed 端口
    QNetworkProxy::setApplicationProxy(QNetworkProxy(QNetworkProxy::Socks5Proxy, "127.0.0.1", kMixedPort));
    mRunning = true;
    emit runningChanged();
    spdlog::info("[Vpn] mihomo 已启动，应用代理 127.0.0.1:{}", kMixedPort);
}

void VpnManager::stop() {
    if (mProcess && mProcess->state() != QProcess::NotRunning) {
        mProcess->terminate();
        if (!mProcess->waitForFinished(3000)) {
            mProcess->kill();
            mProcess->waitForFinished(1000);
        }
    }
    QNetworkProxy::setApplicationProxy(QNetworkProxy::DefaultProxy);
    if (mRunning) {
        mRunning = false;
        emit runningChanged();
        spdlog::info("[Vpn] mihomo 已停止，应用代理已恢复");
    }
}

bool VpnManager::ensureMihomo() {
    QDir().mkpath(kVpnDir);
    if (QFile::exists(kMihomo)) {
        return true;
    }
    if (!QFile::exists(kMihomoGz)) {
        spdlog::warn("[Vpn] mihomo 缺失且未找到安装包 {}", kMihomoGz);
        return false;
    }
    spdlog::info("[Vpn] 从 {} 解压部署 mihomo...", kMihomoGz);
    exec(QString("gzip -dc \"%1\" > \"%2\"").arg(kMihomoGz, kMihomo));
    exec(QString("chmod +x \"%1\"").arg(kMihomo));
    if (!QFile::exists(kMihomo)) {
        spdlog::error("[Vpn] mihomo 解压失败");
        return false;
    }
    return true;
}

bool VpnManager::writeConfig() {
    QString config =
        "mixed-port: " + QString::number(kMixedPort) + "\n"
        "allow-lan: false\n"
        "mode: rule\n"
        "log-level: info\n"
        "\n"
        "proxy-providers:\n"
        "  airport:\n"
        "    type: http\n"
        "    url: \"" + mSubscriptionUrl + "\"\n"
        "    interval: 3600\n"
        "    path: ./airport.yaml\n"
        "\n"
        "proxy-groups:\n"
        "  - name: PROXY\n"
        "    type: url-test\n"
        "    url: \"http://www.gstatic.com/generate_204\"\n"
        "    interval: 300\n"
        "    use:\n"
        "      - airport\n"
        "\n"
        "rules:\n"
        "  - MATCH,PROXY\n";
    QFile file(kConfig);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        spdlog::error("[Vpn] 无法写入 {}", kConfig);
        return false;
    }
    file.write(config.toUtf8());
    file.close();
    return true;
}

} // namespace mod
