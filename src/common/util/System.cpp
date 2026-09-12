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

namespace mod::util {

// 直接看 /proc/mounts，避免依赖 mount 命令的输出格式。
bool isRootFileSystemWritable() {
    QFile mounts("/proc/mounts");
    if (!mounts.open(QIODevice::ReadOnly)) {
        return false;
    }
    const auto lines = QString::fromUtf8(mounts.readAll()).split('\n');
    for (const auto& line : lines) {
        const auto parts = line.split(' ');
        if (parts.size() < 4 || parts[1] != "/") {
            continue;
        }
        return parts[3].split(',').contains("rw");
    }
    return false;
}

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
    if (isRootFileSystemWritable() == writable) {
        return true;
    }
    exec(QString("mount -o remount,%1 /").arg(writable ? "rw" : "ro"));
    return isRootFileSystemWritable() == writable;
}

} // namespace mod::util