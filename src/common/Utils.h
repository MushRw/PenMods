// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

class QString;

#include <QColor>

#include <string>

namespace mod {

/// 常用的 exec 超时档位（毫秒）。
///
/// 为什么要显式写：旧的 `exec()` 没有超时，任何不返回的命令都会**永久**阻塞
/// 调用线程；而 36 个调用点里多数在 UI 线程（QML 直接调 `Mod::reboot()`、
/// 开机路径调 `ensureRimeInstalled`）。同仓库的 `ShellExecutor::runSync()`
/// 一直有超时 + kill 兜底，这里补齐（EX-02）。
constexpr int kExecQuickMs  = 3000;  ///< 纯探测：`ps` / `pidof` / `cat` / `amixer` / 网络状态
constexpr int kExecNormalMs = 10000; ///< 服务控制：init 脚本 restart / `update_engine` / `vendor_storage`
constexpr int kExecLongMs   = 120000; ///< 重活：大文件 `md5sum`
/// 开机安装 / OTA：解压整个安装包、跨分区 `cp -r`。纯兜底，不要指望它触发。
constexpr int kExecVeryLongMs = 300000;

/// 不设超时。**只在该命令确实可能长时间运行、且中断它比等下去更糟时使用**
/// （`bash _do_update.sh` 这类 OTA 脚本、`sync && reboot`、`--reboot` 切槽）。
constexpr int kExecNoTimeout = 0;

/// `exec()` 的结构化结果。
///
/// 为的是能区分「命令跑成功了但没输出」和「命令压根没跑起来 / 超时被杀」——
/// 旧的 `std::string` 返回值把这两种情况和空输出混在一起（`EX-14` 在
/// `ShellExecutor` 那一侧是同一个坑）。
struct ExecResult {
    /// stdout。与旧 `exec()` 一致：只去掉末尾一个 `\n` / 一个 `\r`。
    std::string out;
    /// 子进程退出码；`-1` 表示没拿到（启动失败 / 超时被强杀 / 非正常退出）。
    int exitCode = -1;
    /// `/bin/sh` 是否真的起来了（`pipe`+`fork` 都成功）。
    bool launched = false;
    /// 子进程是否**已终止并被回收**。被信号杀死（含超时 SIGKILL）也算 `true` ——
    /// 它回答的是"有没有留下未回收的子进程"；要判断"是不是正常跑完"请看 `exitCode >= 0`。
    bool childExited = false;
    /// 是否因为超时被 SIGKILL。
    bool timedOut = false;

    /// `grep` / `pidof` 这类命令「没找到」时**正常返回非 0**，所以判断成败要看
    /// 具体语义，不要盲目用这个。
    bool ok() const { return launched && childExited && !timedOut && exitCode == 0; }
};

/// 执行 shell 命令，**不会抛异常**。
///
/// 与 `ShellExecutor`（`QProcess`、结构化结果、可取消、给 QML 用）的分工：这里是
/// 最底层的 C++ 同步版本，主要用于开机路径和 C++ 内部"立刻拿一行输出"的场合。
///
/// 与旧实现**保持一致**的语义：
///   - 经 `/bin/sh -c` 执行，所以管道 / 重定向 / `&&` / `;` 都能用；
///   - 只重定向 stdout，**stderr 原样继承**（仍然进主程序的日志文件）；
///   - 结果只去掉末尾一个 `\n` 和一个 `\r`；
///   - 默认不设超时。
///
/// 与旧实现**不同**的两点（EX-02 / EX-03）：
///   1. `pipe()` / `fork()` 失败时返回空串并记日志，**不再 `throw`**。
///      旧实现在 `popen` 失败时抛 `std::runtime_error`，而调用点几乎都没有 catch；
///      异常一旦展开到 QML setter / `Q_INVOKABLE` / Dobby detour 的 C ABI 边界就是
///      `std::terminate` → 主程序退出 → `guardian_run` 立刻重拉 —— 也就是用户
///      看到的"桌面重启"。
///   2. 可以给超时。另外，"子进程已退出、但仍有后台孙进程占着管道"（init 脚本里
///      `start-stop-daemon` 拉起的守护进程就是这样）不再像旧实现那样永久等 EOF，
///      而是收完缓冲数据就返回。
std::string exec(const char* cmd);
std::string exec(const QString& cmd);

/// 带超时的 `exec()`。`timeoutMs <= 0` 等价于不设超时。
std::string exec(const char* cmd, int timeoutMs);
std::string exec(const QString& cmd, int timeoutMs);

/// 需要判断成败 / 超时时用这个。
ExecResult execWithResult(const char* cmd, int timeoutMs = kExecNoTimeout);
ExecResult execWithResult(const QString& cmd, int timeoutMs = kExecNoTimeout);

double dec(double d, uint16 n);

constexpr uint32 H(const char* str, int h = 0) { return !str[h] ? 5381 : (H(str, h + 1) * 33) ^ str[h]; }

inline uint32 do_hash_runtime(const char* str, int h = 0) {
    return !str[h] ? 5381 : (do_hash_runtime(str, h + 1) * 33) ^ str[h];
}

std::string readFile(const char*);

std::string readFileNoLast(const char*);

void showToast(const std::string& content, const QColor& theme = "#1A1B1F");

bool judgeIsLegalFileName(const QString& filename);

QString generateUUID();

/// 模糊匹配歌词文件名：计算两个歌名（不含扩展名）的相似度，返回 0.0 ~ 1.0
double fuzzyLrcMatch(const QString& songName, const QString& lrcName);

} // namespace mod
