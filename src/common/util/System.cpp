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

#include <spdlog/spdlog.h>

#include <atomic>
#include <mutex>
#include <optional>
#include <string>

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

// rootfs 可写窗口的引用计数（EX-05）。刻意不用一个 bool 表示"我持有窗口"：
// 两个窗口交叠时，各自记下的"原状态"会互相踩，只有深度回到 0 的那个才应该真正
// remount 回原状态。用原子量而不是裸 int/bool，是为了同一线程嵌套以外的场景也不出 UB。
std::atomic<int>  gRootFsWindowDepth{0};
std::atomic<bool> gRootFsWindowWasWritable{false};

} // namespace

bool isRootFileSystemWritable() { return _rootFileSystemWritableState().value_or(false); }

std::string pcbaVersion() {
    static std::mutex  mutex;
    static std::string cached;
    static bool        probed = false;

    std::lock_guard<std::mutex> lock(mutex);
    if (!probed) {
        // 探测失败（返回空）时不置位 probed，下次调用会重试 —— 不能把一次偶发失败
        // 永久缓存下来，否则整台设备的 asound / input-event-daemon 都会退到兜底分支。
        cached = exec("get_pcba_version", kExecQuickMs);
        probed = !cached.empty();
    }
    return cached;
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
    const auto current = _rootFileSystemWritableState();
    if (current.has_value() && *current == writable) {
        return true;
    }
    // 给超时：remount 正常在百毫秒内完成，卡住时不能把 UI 线程或开机路径一起拖死。
    // 失败（含超时）由下面的回读兜住 —— 回读不到/对不上就返回 false。
    exec(QString("mount -o remount,%1 /").arg(writable ? "rw" : "ro"), kExecNormalMs);
    const auto after = _rootFileSystemWritableState();
    if (!after.has_value()) {
        // 回读不到状态就不能宣称成功。"归还 rootfs"这唯一一步静默失败 =
        // rootfs 停在 rw（本设备唯一"改不坏"的保险失效），必须让调用方看见（SD-03）。
        return false;
    }
    return *after == writable;
}

RootFileSystemWritableGuard::RootFileSystemWritableGuard() : mEntered(false) {
    // fetch_add 返回"加之前"的值：0 表示我是最外层，需要真正打开窗口并记下原始状态；
    // 非 0 表示已经有人在窗口里，/ 本来就是 rw，我只要把计数加一即可。
    if (gRootFsWindowDepth.fetch_add(1, std::memory_order_acq_rel) == 0) {
        gRootFsWindowWasWritable.store(isRootFileSystemWritable(), std::memory_order_relaxed);
        if (!setRootFileSystemWritable(true)) {
            // remount 失败：把计数退回去，让下一个进入者重新尝试。
            gRootFsWindowDepth.fetch_sub(1, std::memory_order_acq_rel);
            return; // mEntered 保持 false
        }
    }
    mEntered = true;
}

RootFileSystemWritableGuard::~RootFileSystemWritableGuard() {
    if (!mEntered) {
        return; // 构造时就没进去，没有任何东西需要归还
    }
    // fetch_sub 返回"减之前"的值：1 表示我是关掉窗口的那个，负责还原。
    if (gRootFsWindowDepth.fetch_sub(1, std::memory_order_acq_rel) == 1) {
        if (!setRootFileSystemWritable(gRootFsWindowWasWritable.load(std::memory_order_relaxed))) {
            // 归还失败 = / 停在 rw（这台设备唯一"改不坏"的保险失效）。析构函数里没地方
            // 把错误返给调用方，只能喊出来 —— 调用方自己的成功路径日志已经写过了（SD-03）。
            spdlog::error("Failed to restore rootfs mount state: / may be left writable!");
        }
    }
}

} // namespace mod::util