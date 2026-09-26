// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "mod/PlayerInstaller.h"

#include "common/Utils.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <spdlog/spdlog.h>

namespace mod {

namespace {

constexpr const char* kPlayerMarker  = "/userdisk/mpv/mpv";
constexpr const char* kPlayerArchive = "/userdata/PenMods/player.zip";
constexpr const char* kVideoPlayer   = "/userdisk/VideoPlayer";
constexpr const char* kPlayerWrapper = "/userdisk/mpv/mpv";
constexpr const char* kRimeMarker    = "/userdisk/Music/Rime/rime_ice.schema.yaml";
constexpr const char* kRimePayload   = "rime_ice.schema.yaml";
constexpr const char* kRimeArchive   = "/userdata/PenMods/rime.zip";

constexpr const char* kPlayerStage = "/tmp/player_install";
constexpr const char* kRimeStage   = "/tmp/rime_install";

/// 准备解压暂存目录：清掉旧的再建。
///
/// 原来是 `rm -rf ... && mkdir -p ...` —— 一条 shell，且**失败完全静默**。
/// 用 Qt 做同样的事，失败能拿到原因。
bool prepareStage(const char* dir, const char* what) {
    QDir d(QString::fromUtf8(dir));
    if (d.exists() && !d.removeRecursively()) {
        spdlog::error("[PlayerInstaller] {} 暂存目录 {} 清理失败", what, dir);
        return false;
    }
    if (!QDir().mkpath(QString::fromUtf8(dir))) {
        spdlog::error("[PlayerInstaller] {} 暂存目录 {} 创建失败", what, dir);
        return false;
    }
    return true;
}

/// 部署完删掉暂存目录。
///
/// 原来的代码从不清理解压产物。这里 `/tmp` 是 **tmpfs —— 占的是内存**，
/// 而设备一共只有 460MB：播放器包解压完留在 `/tmp` 就等于常驻吃掉那份内存，
/// 一直到下次重启。
void cleanupStage(const char* dir) {
    if (!QDir(QString::fromUtf8(dir)).removeRecursively()) {
        spdlog::warn("[PlayerInstaller] 暂存目录 {} 清理失败（不影响部署结果）", dir);
    }
}

/// 给一个文件加上可执行位。原来是 `chmod +x a b c`，失败同样静默。
bool setExecutable(const char* path) {
    if (!QFile::exists(QString::fromUtf8(path))) {
        spdlog::error("[PlayerInstaller] 需要加可执行位的文件不存在：{}", path);
        return false;
    }
    QFile f(QString::fromUtf8(path));
    const auto perms = f.permissions();
    if (!f.setPermissions(perms | QFile::ExeOwner | QFile::ExeGroup | QFile::ExeOther)) {
        spdlog::error("[PlayerInstaller] 无法给 {} 加可执行位（{}）", path, f.errorString().toStdString());
        return false;
    }
    return true;
}

/// 跑一条"重活"并检查它到底成了没有。
///
/// 这段路径原来一律只看"产物文件在不在"，所以 `unzip` 失败、`cp` 被 OOM 杀、
/// 超时被 SIGKILL —— 三种情况打出来的都是"安装包内容不完整"/"部署后仍缺少"，
/// 把人往完全错误的地方带（EX-12）。
bool runHeavyStep(const QString& cmd, const char* what) {
    const qint64 started = QDateTime::currentMSecsSinceEpoch();
    const auto   res     = execWithResult(cmd, kExecVeryLongMs);
    const qint64 cost    = QDateTime::currentMSecsSinceEpoch() - started;

    if (res.ok()) {
        spdlog::info("[PlayerInstaller] {} 完成（{} ms）", what, cost);
        return true;
    }
    spdlog::error("[PlayerInstaller] {} 失败：exitCode={} launched={} timedOut={}（{} ms）", what, res.exitCode,
                  res.launched, res.timedOut, cost);
    if (!res.out.empty()) {
        spdlog::error("[PlayerInstaller] {} 的输出：{}", what, res.out);
    }
    return false;
}

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

    // 注意：下面几步是**开机路径上的同步重活**（解压 + 跨分区拷贝），会阻塞启动
    // 十几秒到几分钟。真正的解法是移出 UI 线程并给进度（见 §EX-4 迁移），
    // 这里先保证：每一步的成败都**能被看见**，失败原因不再被误报成"包不完整"。
    if (!prepareStage(kPlayerStage, "播放器")) {
        return;
    }

    const QString stageMpv = QString("%1/mpv").arg(kPlayerStage);

    bool ok = runHeavyStep(QString("unzip -q -o \"%1\" -d %2").arg(kPlayerArchive, kPlayerStage), "解压播放器包");
    if (ok && !QFile::exists(stageMpv + "/mpv")) {
        spdlog::error("[PlayerInstaller] 安装包内容不完整（缺少 mpv/mpv）");
        ok = false;
    }

    if (ok) {
        // 目标目录若已存在，`cp -r src dst` 会拷成 dst/src 这一层多余的目录，所以先删。
        QDir target("/userdisk/mpv");
        if (target.exists() && !target.removeRecursively()) {
            spdlog::error("[PlayerInstaller] 旧播放器目录 /userdisk/mpv 删除失败");
            ok = false;
        } else {
            ok = runHeavyStep(QString("cp -r %1 /userdisk/mpv").arg(stageMpv), "拷贝播放器");
        }
    }

    if (ok) {
        ok = setExecutable("/userdisk/mpv/mpv") && setExecutable("/userdisk/mpv/bin/mpv") &&
             setExecutable("/userdisk/mpv/screen_watchdog");
    }

    cleanupStage(kPlayerStage);

    if (!ok) {
        return;
    }
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

    if (!prepareStage(kRimeStage, "Rime")) {
        return;
    }

    bool ok = runHeavyStep(QString("unzip -q -o \"%1\" -d %2").arg(kRimeArchive, kRimeStage), "解压 Rime 包");
    if (ok && !QFile::exists(QString("%1/%2").arg(kRimeStage, kRimePayload))) {
        spdlog::error("[PlayerInstaller] rime.zip 内容不完整（缺少 {}）", kRimePayload);
        ok = false;
    }

    if (ok && !QDir().mkpath("/userdisk/Music/Rime")) {
        spdlog::error("[PlayerInstaller] 目标目录 /userdisk/Music/Rime 创建失败");
        ok = false;
    }

    if (ok) {
        // 必须递归拷贝：雾凇拼音的词库在 cn_dicts/、en_dicts/ 子目录里，
        // 老版本的 `cp -f .../*` 会把子目录直接丢掉。
        // `src/.` 的写法保证连同隐藏文件一起复制到目标目录内部。
        ok = runHeavyStep(QString("cp -rf %1/. /userdisk/Music/Rime/").arg(kRimeStage), "拷贝 Rime 数据");
    }

    cleanupStage(kRimeStage);

    if (QFile::exists(kRimeMarker)) {
        spdlog::info("[PlayerInstaller] Rime 数据部署完成（雾凇拼音）");
    } else {
        spdlog::error("[PlayerInstaller] 部署后仍缺少 {}", kRimeMarker);
    }
}

} // namespace mod
