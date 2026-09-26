// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "System.h"

#include "common/Utils.h"

#include <QFile>

#include <dlfcn.h>
#include <unistd.h>

#include <optional>

namespace mod::util {

namespace {

// 直接看 /proc/mounts，避免依赖 mount 命令的输出格式。
// 返回 nullopt 表示"读不到状态"（/proc/mounts 打不开，或里面没有 / 的挂载项）——
// 必须与"确定是 ro"区分开：原来的 bool 版本在两种情况下都返回 false，
// 于是 setRootFileSystemWritable(false) 会认定"已经是 ro"直接返回成功，
// 而实际上 / 可能停在 rw（SD-03②）。
std::optional<bool> _rootFileSystemWritableState() {
    QFile mounts("/proc/mounts");
    if (!mounts.open(QIODevice::ReadOnly)) {
        return std::nullopt;
    }
    const auto lines = QString::fromUtf8(mounts.readAll()).split('\n');
    for (const auto& line : lines) {
        const auto parts = line.split(' ');
        if (parts.size() < 4 || parts[1] != "/") {
            continue;
        }
        return parts[3].split(',').contains("rw");
    }
    return std::nullopt;
}

} // namespace

bool isRootFileSystemWritable() { return _rootFileSystemWritableState().value_or(false); }

QFileInfo getModuleFileInfo() {
    Dl_info info;
    if (dladdr((void*)getModuleFileInfo, &info) == 0) return {};
    return QFileInfo(info.dli_fname);
}

QFileInfo getApplicationFileInfo() {
    char path[4096];
    if (readlink("/proc/self/exe", path, sizeof(path) - 1) == -1) return {};
    return QFileInfo(path);
}

bool setRootFileSystemWritable(bool writable) {
    const auto current = _rootFileSystemWritableState();
    if (current.has_value() && *current == writable) {
        return true;
    }
    exec(QString("mount -o remount,%1 /").arg(writable ? "rw" : "ro"));
    const auto after = _rootFileSystemWritableState();
    if (!after.has_value()) {
        // 回读不到状态就不能宣称成功。"归还 rootfs"这唯一一步静默失败 =
        // rootfs 停在 rw（本设备唯一"改不坏"的保险失效），必须让调用方看见（SD-03）。
        return false;
    }
    return *after == writable;
}

} // namespace mod::util