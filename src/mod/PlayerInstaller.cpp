// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "mod/PlayerInstaller.h"

#include "common/Utils.h"

#include <QFile>
#include <QFileInfo>

#include <spdlog/spdlog.h>

namespace mod {

namespace {

constexpr const char* kPlayerMarker  = "/userdisk/mpv/mpv";
constexpr const char* kPlayerArchive = "/userdata/PenMods/player.zip";
constexpr const char* kVideoPlayer   = "/userdisk/VideoPlayer";
constexpr const char* kPlayerWrapper = "/userdisk/mpv/mpv";
constexpr const char* kRimeMarker    = "/userdisk/Music/Rime/luna_pinyin.schema.yaml";
constexpr const char* kRimeArchive   = "/userdata/PenMods/rime.zip";

void repairVideoPlayerLink() {
    QFileInfo info(kVideoPlayer);
    if (info.isSymLink()) {
        if (info.symLinkTarget() == kPlayerWrapper) {
            return; // 已经指向正确位置
        }
        // 旧安装指向 /userdisk/bin/mpv（重复副本），统一纠正
        QFile::remove(kVideoPlayer);
    } else if (info.exists()) {
        return; // 非软链的普通文件/目录，不要动
    }
    QFile::link(kPlayerWrapper, kVideoPlayer);
}

} // namespace

void ensurePlayerInstalled() {
    if (QFile::exists(kPlayerMarker)) {
        // 播放器已存在，只修正软链
        repairVideoPlayerLink();
        return;
    }

    if (!QFile::exists(kPlayerArchive)) {
        spdlog::warn("[PlayerInstaller] 播放器缺失，且未找到安装包 {}", kPlayerArchive);
        return;
    }

    spdlog::info("[PlayerInstaller] 播放器缺失，从 {} 部署...", kPlayerArchive);
    exec("rm -rf /tmp/player_install && mkdir -p /tmp/player_install");
    exec(QString("unzip -q -o \"%1\" -d /tmp/player_install").arg(kPlayerArchive));
    if (!QFile::exists("/tmp/player_install/mpv/mpv")) {
        spdlog::error("[PlayerInstaller] 安装包内容不完整（缺少 mpv/mpv）");
        return;
    }

    exec("rm -rf /userdisk/mpv && cp -r /tmp/player_install/mpv /userdisk/mpv");
    exec("chmod +x /userdisk/mpv/mpv /userdisk/mpv/bin/mpv /userdisk/mpv/screen_watchdog");

    if (!QFile::exists(kPlayerMarker)) {
        spdlog::error("[PlayerInstaller] 部署后仍缺少 {}", kPlayerMarker);
        return;
    }
    spdlog::info("[PlayerInstaller] 播放器部署完成");
    repairVideoPlayerLink();
}

void ensureRimeInstalled() {
    if (QFile::exists(kRimeMarker)) {
        // 已安装（或用户已放置自定义方案），不覆盖
        return;
    }

    if (!QFile::exists(kRimeArchive)) {
        spdlog::warn("[PlayerInstaller] Rime 数据缺失，且未找到安装包 {}", kRimeArchive);
        return;
    }

    spdlog::info("[PlayerInstaller] Rime 数据缺失，从 {} 部署...", kRimeArchive);
    exec("rm -rf /tmp/rime_install && mkdir -p /tmp/rime_install");
    exec(QString("unzip -q -o \"%1\" -d /tmp/rime_install").arg(kRimeArchive));
    if (!QFile::exists("/tmp/rime_install/luna_pinyin.schema.yaml")) {
        spdlog::error("[PlayerInstaller] rime.zip 内容不完整（缺少 luna_pinyin.schema.yaml）");
        return;
    }

    exec("mkdir -p /userdisk/Music/Rime && cp -f /tmp/rime_install/* /userdisk/Music/Rime/");
    if (QFile::exists(kRimeMarker)) {
        spdlog::info("[PlayerInstaller] Rime 数据部署完成");
    } else {
        spdlog::error("[PlayerInstaller] 部署后仍缺少 {}", kRimeMarker);
    }
}

} // namespace mod
