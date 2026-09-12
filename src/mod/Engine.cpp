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

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <dlfcn.h>

#include "base/YPointer.h"

#include "common/Event.h"
#include "common/util/System.h"

namespace {

constexpr const char* kResourceLibPath = "/userdata/PenMods/libPenModsResources.so";
constexpr const char* kQmlCacheDir     = "/.cache/NeteaseYoudao/YoudaoDictPen/qmlcache";
constexpr const char* kResourceStamp   = "/userdata/PenMods/.resource_stamp";

// QML 编译缓存（.qmlc/.jsc）在 rootfs 上，而 / 默认只读：以前是靠"开机把 /
// 挂成 rw"才清得掉。现在只在"资源库/本体确实换了"时临时放开一下。
// 为什么必须清：rcc 节点里的 mtime 是打包时保留下来的，QML 内容变了 mtime
// 可能没变，Qt 会继续复用旧的 .qmlc，改了界面却不生效。
void clearQmlCacheIfResourcesChanged() {
    QString stamp;
    for (const auto& path :
         {QString::fromUtf8(kResourceLibPath), mod::util::getModuleFileInfo().absoluteFilePath()}) {
        QFileInfo info(path);
        stamp += QString("%1|%2|%3;")
                     .arg(info.fileName())
                     .arg(info.size())
                     .arg(info.lastModified().toSecsSinceEpoch());
    }

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

    const bool wasWritable = mod::util::isRootFileSystemWritable();
    mod::util::setRootFileSystemWritable(true);
    const bool removed = QDir(QString::fromUtf8(kQmlCacheDir)).removeRecursively();
    mod::util::setRootFileSystemWritable(wasWritable);
    spdlog::info("资源已更新，QML 编译缓存已清理（目录存在: {}）", removed);

    QFile out(QString::fromUtf8(kResourceStamp));
    if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        out.write(stamp.toUtf8());
    }
}

} // namespace

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
