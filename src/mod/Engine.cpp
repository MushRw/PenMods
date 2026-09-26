// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "spdlog/spdlog.h"
#if PL_BUILD_YDP02X
#include "../resource/models/YDP02X/qrc_qml.h"
#endif

#include <QQmlContext>
#include <QQuickView>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>
#include <dlfcn.h>

#include <cstdlib>

#include "base/YPointer.h"

#include "common/Event.h"
#include "common/util/System.h"
#include "mod/Engine.h"

namespace {

constexpr const char* kResourceLibPath = "/userdata/PenMods/libPenModsResources.so";
/// Qt 的 QML 编译缓存目录。**必须**落在可写分区：默认位置是
/// `$HOME/.cache/NeteaseYoudao/YoudaoDictPen/qmlcache`，而本设备 `HOME=/`、
/// `/` 只读 ⇒ 那个目录永远是空的，每次开机都要重编译全部 QML（HY-05）。
/// 这里改指到 /userdata（ext4 rw、跨重启保留）。
constexpr const char* kQmlCacheDir   = "/userdata/PenMods/qmlcache";
constexpr const char* kResourceStamp = "/userdata/PenMods/.resource_stamp";
constexpr const char* kSelfExeLink   = "/proc/self/exe";

/// 缓存目录所在分区至少要剩这么多空间才启用缓存。
/// /userdata 总共 248M，实测余量常在 100M 上下；留够余量，宁可不缓存
/// （退回 HY-05 之前的行为：每次重编译，但至少不会把分区写满）。
constexpr qint64 kMinFreeBytesForCache = 24LL * 1024 * 1024;

/// 主程序真实路径（`/proc/self/exe` 是符号链接）。
/// 把它算进资源戳，这样厂商 OTA 换了主程序（内含厂商自己的 QML）之后，
/// 缓存也会被判为失效而清掉 —— 否则新主程序会读到旧主程序留下的 .qmlc。
QString selfExecutablePath() {
    const QFileInfo link(QString::fromUtf8(kSelfExeLink));
    const QString   target = link.symLinkTarget();
    return target.isEmpty() ? QString::fromUtf8(kSelfExeLink) : target;
}

// 为什么必须清 QML 编译缓存：rcc 节点里的 mtime 是打包时保留下来的，QML 内容
// 变了 mtime 可能没变，Qt 会继续复用旧的 .qmlc，改了界面却不生效。
void clearQmlCacheIfResourcesChanged() {
    const QString cacheDir = QString::fromUtf8(kQmlCacheDir);

    QString stamp;
    for (const auto& path : {QString::fromUtf8(kResourceLibPath),
                             mod::util::getModuleFileInfo().absoluteFilePath(),
                             selfExecutablePath()}) {
        QFileInfo info(path);
        stamp += QString("%1|%2|%3;")
                     .arg(info.fileName())
                     .arg(info.size())
                     .arg(info.lastModified().toSecsSinceEpoch());
    }
    stamp += QString("cache=%1;").arg(cacheDir);

    QString previous;
    {
        QFile in(QString::fromUtf8(kResourceStamp));
        if (in.open(QIODevice::ReadOnly)) {
            previous = QString::fromUtf8(in.readAll());
        }
    }
    if (!stamp.isEmpty() && previous == stamp) {
        return; // 资源没变，什么都不做
    }

    // 缓存目录在 /userdata（rw），**不需要**再把 rootfs 挂成可写了 —— 以前这里
    // 开着一个 rootfs 可写窗口去删一个永远不存在的目录（EX-04 的 4 个窗口之一，
    // 且是唯一在开机路径上的那个）。
    const QString cacheParent = QFileInfo(cacheDir).absolutePath();
    const QStorageInfo storage(cacheParent);
    if (storage.isValid() && storage.bytesAvailable() < kMinFreeBytesForCache) {
        // 空间不够就干脆不缓存：清掉环境变量，Qt 回落到默认（=写不进去=不缓存）。
        // 比"缓存把 /userdata 写满、然后所有写配置/日志的地方一起失败"强。
        ::unsetenv("QML_DISK_CACHE_PATH");
        spdlog::warn("{} 可用空间不足（{} MiB），本次启动禁用 QML 编译缓存。",
                     cacheParent.toStdString(),
                     storage.bytesAvailable() / 1024 / 1024);
        return; // 不更新资源戳：下次开机还有机会
    }

    const bool cacheExisted = QFileInfo::exists(cacheDir);
    const bool cleared      = !cacheExisted || QDir(cacheDir).removeRecursively();
    if (!cleared) {
        // 没清掉就**不要**更新资源戳：戳一旦更新，下次开机这里会直接 return，
        // 陈旧的 .qmlc 就再也没有机会被清 —— 表现是"改了界面永远不生效"。
        spdlog::warn("QML 编译缓存未能清理（目录存在: {}），本次不更新资源戳。", cacheExisted);
        return;
    }
    spdlog::info("资源已更新，QML 编译缓存已清理（目录存在: {}）", cacheExisted);

    QFile out(QString::fromUtf8(kResourceStamp));
    if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        out.write(stamp.toUtf8());
    }
}

} // namespace

namespace mod::engine {

void redirectQmlDiskCacheBeforeMain() {
    // 只用 libc，**不碰 Qt**：本函数在 main() 之前跑（库构造函数），
    // QtCore 的静态量此时还没初始化完。
    ::setenv("QML_DISK_CACHE_PATH", kQmlCacheDir, 1);
}

} // namespace mod::engine

PEN_HOOK(void, _ZN22YGuiApplicationPrivate6initUiEv, QWindow** self) {

    // 资源/本体换过就先清 QML 缓存，必须在注册资源树之前做。
    clearQmlCacheIfResourcesChanged();

    auto& view    = *(QQuickView*)*self;
    auto* context = view.rootContext();

    mod::YPointer<QQuickView>::setInstance(&view);

    emit mod::Event::getInstance().beforeUiInitialization(view, context);

    bool                 using_external_resources = false;
    const char*          ResourceLibPath          = kResourceLibPath;
    const unsigned char* new_qt_resource_struct;
    const unsigned char* new_qt_resource_data;
    const unsigned char* new_qt_resource_name;
    if (QFile::exists(ResourceLibPath)) {
        void* lib = dlopen(ResourceLibPath, RTLD_NOW);
        if (!lib) {
            spdlog::error("Can't dlopen libPenModsResources.so");
        } else {
            using get_res_t = const unsigned char* (*)();

            auto get_struct = (get_res_t)dlsym(lib, "get_qt_resource_struct");
            auto get_data   = (get_res_t)dlsym(lib, "get_qt_resource_data");
            auto get_name   = (get_res_t)dlsym(lib, "get_qt_resource_name");

            if (get_struct && get_data && get_name) {
                new_qt_resource_struct = get_struct();
                new_qt_resource_data   = get_data();
                new_qt_resource_name   = get_name();

                spdlog::info("Using external Qt res.");
                using_external_resources = true;
            } else {
                spdlog::error("libPenModsResources.so is missing required export symbols, falling back to built-in resources.");
                dlclose(lib);
            }
        }
    }

    // Replace QResources
    PEN_CALL(void*, "_Z21qCleanupResources_qmlv")();
    bool res;
    if (using_external_resources) {
        res = PEN_CALL(bool, "_Z21qRegisterResourceDataiPKhS0_S0_", int, const uchar*, const uchar*, const uchar*)(
            0x3,
            new_qt_resource_struct,
            new_qt_resource_name,
            new_qt_resource_data
        );
    } else {
        res = PEN_CALL(bool, "_Z21qRegisterResourceDataiPKhS0_S0_", int, const uchar*, const uchar*, const uchar*)(
            0x3,
            qt_resource_struct,
            qt_resource_name,
            qt_resource_data
        );
    }
    if (res) {
        spdlog::info("Resource files have been replaced!");
    } else {
        spdlog::error("The resource file replacement failed, reload the original resource file.");
        PEN_CALL(void*, "_Z18qInitResources_qmlv")();
    }

    origin(self);
}
