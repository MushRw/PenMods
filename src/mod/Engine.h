// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

namespace mod::engine {

/// 必须在 main() 之前调用（由 libPenMods.so 的构造函数调用，见 Mod.cpp）。
///
/// 把 Qt 的 QML 编译缓存（.qmlc）从默认位置 `/.cache/...` 挪到可写分区。
/// 默认是 `QStandardPaths::CacheLocation` = `$HOME/.cache/<组织>/<应用>/qmlcache`，
/// 而本设备 `HOME=/`、`/` 是**只读** rootfs ⇒ 该目录从来没被写出来过
/// （实测 `/.cache/NeteaseYoudao/YoudaoDictPen/` 存在但永远是空的），
/// 于是每次启动都要把 qrc 里 751 个 QML 重新编译一遍。
///
/// 为什么只能在库加载时设：Qt 用 `QML_DISK_CACHE_PATH` 环境变量决定缓存目录，
/// 而 PenMods 最早的 hook（`YGuiApplicationPrivate::initUi`）进来时
/// QQuickView / QQmlEngine 已经建好了，那时再设可能已经晚了。
/// 库构造函数（patchelf 注入的 NEEDED 库）跑在 main() 之前，是最早的安全点。
void redirectQmlDiskCacheBeforeMain();

} // namespace mod::engine
