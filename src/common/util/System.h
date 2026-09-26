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
/// isRootFileSystemWritable() 自己取一次。**新代码请用下面的守卫，不要直接调它**
/// （手写「记状态 → 置 rw → 写 → 还原」已知不安全，见 EX-04 / EX-05）。
extern bool setRootFileSystemWritable(bool writable);

/// 临时把 rootfs 放开为可写的 RAII 守卫（EX-04 / EX-05）。
///
/// 手写「记下 isRootFileSystemWritable() → 置 rw → 写 → 还原」有两个已知缺陷：
///   1. **不异常安全**：窗口内任何提前 `return` 或异常展开都会漏掉「还原」，
///      把 `/` 永久留在 rw —— 本设备唯一「改不坏」的保险就此失效（EX-04）；
///   2. **靠读-改-写做状态**：两处窗口交叠时各自记下的「原状态」互相踩，后一个
///      把 `/` 还原成前一个以为的初始值；再叠加 `ofstream` 只在 open 时查
///      `good()`、`<<` 失败不回查 → 写入静默丢失（EX-05）。
///
/// 这个守卫用析构函数保证还原（缺陷 1），用引用计数保证嵌套时只有最外层真正
/// remount、只有最外层负责还原（缺陷 2）。典型用法：
///
///     util::RootFileSystemWritableGuard guard;
///     if (!guard.ok()) {
///         return false;           // remount 失败，/ 仍是 ro，别写
///     }
///     ... 写 rootfs 上的文件 ...
///     // 出作用域自动还原；提前 return / 抛异常也一样
///
/// 注意：守卫**不做跨线程互斥**。现有使用点（`ASound` / `InputDaemon` /
/// `Engine` 开机清缓存 / `ServiceManager`）全在 UI 线程或开机路径，同线程嵌套
/// 安全；真要在多线程并发进入，还需要额外的互斥 —— 当前并不需要。
class RootFileSystemWritableGuard {
public:
    RootFileSystemWritableGuard();
    ~RootFileSystemWritableGuard();

    RootFileSystemWritableGuard(const RootFileSystemWritableGuard&)            = delete;
    RootFileSystemWritableGuard& operator=(const RootFileSystemWritableGuard&) = delete;
    RootFileSystemWritableGuard(RootFileSystemWritableGuard&&)                 = delete;
    RootFileSystemWritableGuard& operator=(RootFileSystemWritableGuard&&)      = delete;

    /// 是否成功进入可写状态。`false` = remount 失败，`/` 仍是 ro，调用方必须放弃写入。
    bool ok() const { return mEntered; }

private:
    bool mEntered;
};

} // namespace mod::util
