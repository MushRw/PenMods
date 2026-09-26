// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include <QFileInfo>

#include <string>

namespace mod::util {

extern QFileInfo getModuleFileInfo();

extern QFileInfo getApplicationFileInfo();

/// 硬件板型，即 `get_pcba_version` 的输出（例如本机是 `Exam_V0`）。
///
/// 该值由板上的硬件跳线 / ADC 决定，**运行期不会变**；而探测本身是 fork 一个
/// `/bin/sh` 脚本去读 GPIO（`/usr/bin/get_pcba_version`，2191 字节）。项目里
/// 至少有两处需要它（`ASound` 选 asound 模板、`InputDaemon` 选 input-event-daemon
/// 模板），以前各自 fork 一遍 —— 收敛到这里只探一次（EX-10 / SD-08）。
///
/// 探测失败（命令没跑起来、超时、输出为空）**不写缓存**，下次调用自动重试，
/// 不会把一次偶发失败永久固定下来。
extern std::string pcbaVersion();

/// / 当前是否可写（直接读 /proc/mounts）。
extern bool isRootFileSystemWritable();

/// 把根文件系统重新挂成可写/只读。设备出厂时 / 是 ro：只有确实要写 rootfs
/// （例如 /etc/input-event-daemon_<model>.conf）时才临时放开，写完立刻还原，
/// 不要像以前那样在开机时整段会话都保持 rw。
/// 注意：返回值是「操作后是否处于期望状态」，不是「操作前」——想恢复原状要先用
/// isRootFileSystemWritable() 自己取一次。
extern bool setRootFileSystemWritable(bool writable);

} // namespace mod::util
