// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include <QFileInfo>

namespace mod::util {

extern QFileInfo getModuleFileInfo();

extern QFileInfo getApplicationFileInfo();

/// 把根文件系统重新挂成可写/只读。设备出厂时 / 是 ro：只有确实要写 rootfs
/// （例如 /etc/input-event-daemon_<model>.conf）时才临时放开，写完立刻还原，
/// 不要像以前那样在开机时整段会话都保持 rw。
/// 返回操作后 / 是否处于期望的状态。
extern bool setRootFileSystemWritable(bool writable);

} // namespace mod::util
