// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "common/Utils.h"

#include "base/YPointer.h"

#include <QUuid>

#include <spdlog/spdlog.h>

#include <cerrno>
#include <chrono>
#include <cstring>
#include <ctime>

#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

namespace mod {

namespace {

/// 轮询间隔。分辨率够用（短命令不会被明显拖慢），又不至于空转烧 CPU。
constexpr auto kPollInterval = std::chrono::milliseconds(2);

/// 子进程**已经退出**、管道却还没 EOF 时，额外等多久收尾。
///
/// 出现这种情况说明还有"后台孙进程"持有写端 —— 典型的如 init 脚本里
/// `start-stop-daemon` 拉起的守护进程（`S98usbdevice` / `S99input-event-daemon`
/// 都是）。旧实现会一直 `fgets` 到 EOF，也就是**永久挂住**；这里把缓冲数据收完
/// 就返回，因为命令本身确实已经结束了。
constexpr auto kDrainGrace = std::chrono::milliseconds(300);

/// EOF 之后为"回收子进程"留的时间上限。正常情况下子进程早已是僵尸，
/// 第一次 `waitpid(WNOHANG)` 就能收到；这个上限只是保证不在这里永久阻塞。
constexpr auto kReapTimeout = std::chrono::milliseconds(2000);

void _sleepBriefly() {
    const struct timespec ts{
        0, static_cast<long>(std::chrono::duration_cast<std::chrono::nanoseconds>(kPollInterval).count())};
    ::nanosleep(&ts, nullptr);
}

/// 把管道上已到达的数据读干。返回 false 表示 EOF（写端已全部关闭）。
bool _readAvailable(int fd, std::string& out) {
    char buffer[4096];
    while (true) {
        const ssize_t n = ::read(fd, buffer, sizeof buffer);
        if (n > 0) {
            out.append(buffer, static_cast<size_t>(n));
            continue;
        }
        if (n == 0) return false;
        if (errno == EINTR) continue;
        if (errno == EAGAIN || errno == EWOULDBLOCK) return true;
        return false; // 其它读错误：按结束处理，让收尾逻辑决定退出码
    }
}

} // namespace

ExecResult execWithResult(const QString& cmd, int timeoutMs) {
    return execWithResult(cmd.toUtf8().constData(), timeoutMs);
}

ExecResult execWithResult(const char* cmd, int timeoutMs) {
    ExecResult result;
    if (cmd == nullptr) {
        spdlog::error("[exec] 收到空命令指针，未执行");
        return result;
    }

    int fds[2] = {-1, -1};
    if (::pipe(fds) != 0) {
        spdlog::error("[exec] pipe() 失败（{}），命令未执行: {}", std::strerror(errno), cmd);
        return result;
    }

    const pid_t pid = ::fork();
    if (pid < 0) {
        spdlog::error("[exec] fork() 失败（{}），命令未执行: {}", std::strerror(errno), cmd);
        ::close(fds[0]);
        ::close(fds[1]);
        return result;
    }

    if (pid == 0) {
        // 子进程。多线程进程里 fork 出来的子进程只保证 async-signal-safe 的函数可用
        // （其它线程可能在 fork 那一刻正持有 malloc / stdio 的锁），所以从这里到
        // execv 之间：不开 C++ 流、不分配内存、不打日志。
        //
        // 自建进程组（下称 kill(-pid) 要用）：`sh -c` 背后往往还有孙进程 —— 管道的
        // 两端、`&` 起的后台任务、复合命令 —— 超时时只 kill 直接子进程会把它们留在
        // 系统里继续跑。实测：旧写法杀 `sleep 12345 | cat` 后 sleep 仍在。
        ::setpgid(0, 0);
        ::close(fds[0]);
        if (::dup2(fds[1], STDOUT_FILENO) < 0) {
            ::_exit(127);
        }
        if (fds[1] != STDOUT_FILENO) {
            ::close(fds[1]);
        }
        // 只重定向 stdout：stderr 原样继承，仍进主程序的日志文件（与旧 popen 一致）。
        // 用 execv 而不是 popen：execv 是 execve(…, environ) 的薄封装，不碰 stdio。
        char* const argv[] = {const_cast<char*>("/bin/sh"), const_cast<char*>("-c"), const_cast<char*>(cmd), nullptr};
        ::execv(argv[0], argv);
        ::_exit(127); // execv 失败（例如 /bin/sh 不存在）
    }

    result.launched = true;

    // 与子进程里那次 setpgid 是竞态关系，两边都做才能保证父进程准备 kill 之前
    // 进程组一定已建立。子进程 exec 之后再调用会失败（EACCES），忽略即可 ——
    // 那种情况下组早就建好了。
    ::setpgid(pid, pid);

    // 关键：父进程必须关掉写端，否则永远等不到 EOF。
    ::close(fds[1]);

    // 非阻塞读，才能在等数据的同一循环里检查"子进程是否已退出"和"是否超时"。
    const int fdFlags = ::fcntl(fds[0], F_GETFL, 0);
    if (fdFlags >= 0) {
        ::fcntl(fds[0], F_SETFL, fdFlags | O_NONBLOCK);
    }

    const auto started     = std::chrono::steady_clock::now();
    auto       childGoneAt = started;
    bool       childGone   = false;
    bool       timedOut    = false;
    int        status      = 0;

    while (true) {
        if (!_readAvailable(fds[0], result.out)) {
            break; // EOF：命令把 stdout 关掉了
        }

        if (!childGone) {
            const pid_t reaped = ::waitpid(pid, &status, WNOHANG);
            if (reaped == pid) {
                childGone          = true;
                childGoneAt        = std::chrono::steady_clock::now();
                result.exitCode    = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
                result.childExited = true;
            } else if (reaped < 0 && errno != EINTR) {
                childGone   = true; // ECHILD 等：不是我们的直接子进程，不再等它
                childGoneAt = std::chrono::steady_clock::now();
            }
        } else if (std::chrono::steady_clock::now() - childGoneAt > kDrainGrace) {
            break; // 命令已退出，只是后台孙进程还占着管道
        }

        if (timeoutMs > 0
            && std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - started).count()
                   >= timeoutMs) {
            timedOut = true;
            break;
        }

        _sleepBriefly();
    }

    ::close(fds[0]);

    if (!childGone) {
        // 走到这里只有两种可能：超时（子进程还在跑），或者刚读完 EOF、子进程正在退出的路上。
        if (timedOut) {
            // 用**负 pid** 命中整个进程组（见子进程分支里 setpgid 的说明）：
            // 这样管道另一端、`&` 起的后台任务、复合命令会一起被清掉，
            // 而不是只杀掉 sh 这个替死鬼、把子孙丢在系统里继续跑。
            ::kill(-pid, SIGKILL);
            spdlog::warn("[exec] 命令超时（{} ms），已强制结束该进程组: {}", timeoutMs, cmd);
        }
        const auto reapDeadline = std::chrono::steady_clock::now() + kReapTimeout;
        while (true) {
            const pid_t reaped = ::waitpid(pid, &status, WNOHANG);
            if (reaped == pid) {
                result.exitCode    = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
                result.childExited = true;
                break;
            }
            if (reaped < 0 && errno != EINTR) {
                break;
            }
            if (std::chrono::steady_clock::now() >= reapDeadline) {
                spdlog::error("[exec] 子进程 {} 在 {} ms 内仍未回收，放弃等待: {}", static_cast<long>(pid),
                              static_cast<long>(kReapTimeout.count()), cmd);
                break;
            }
            _sleepBriefly();
        }
    }

    result.timedOut = timedOut;
    if (!result.out.empty() && result.out.back() == '\n') result.out.pop_back();
    if (!result.out.empty() && result.out.back() == '\r') result.out.pop_back();
    return result;
}

std::string exec(const QString& cmd) { return execWithResult(cmd, kExecNoTimeout).out; }

std::string exec(const char* cmd) { return execWithResult(cmd, kExecNoTimeout).out; }

std::string exec(const QString& cmd, int timeoutMs) { return execWithResult(cmd, timeoutMs).out; }

std::string exec(const char* cmd, int timeoutMs) { return execWithResult(cmd, timeoutMs).out; }

// 12.333 -> 12.3, if n=1
double dec(double d, uint16 n) { return round(d * pow(10, n)) / pow(10, n); }

std::string readFileNoLast(const char* path) {
    auto str = readFile(path);
    if (!str.empty() && str.back() == '\n') str.pop_back();
    if (!str.empty() && str.back() == '\r') str.pop_back();
    return str;
}

std::string readFile(const char* path) {
    std::ifstream ifile;
    ifile.open(path, std::ios::in);
    if (!ifile.good()) {
        return "";
    }
    std::string str((std::istreambuf_iterator<char>(ifile)), std::istreambuf_iterator<char>());
    return str;
}

void showToast(const std::string& content, const QColor& theme) {
    PEN_CALL(uint64, "_ZN7YGlobal9showToastERK7QStringRK6QColor", YGlobal*, const QString&, const QColor&)
    (YPointer<YGlobal>::getInstance(), QString::fromStdString(content), theme);
}

bool judgeIsLegalFileName(const QString& filename) {
    return !(
        filename.contains(QStringLiteral("/")) || filename.contains(QStringLiteral("\\"))
        || filename.contains(QStringLiteral("\"")) || filename.contains(QStringLiteral("\n"))
        || filename.contains(QStringLiteral(":")) || filename.contains(QStringLiteral("?"))
        || filename.contains(QStringLiteral("*")) || filename.contains(QStringLiteral("|"))
        || filename.contains(QStringLiteral("<")) || filename.contains(QStringLiteral(">"))
        || filename.contains(QStringLiteral("$"))
    );
}

QString generateUUID() { return QUuid::createUuid().toString().remove("{").remove("}"); }

double fuzzyLrcMatch(const QString& songName, const QString& lrcName) {
    if (songName.isEmpty() || lrcName.isEmpty())
        return 0.0;
    if (songName == lrcName)
        return 1.0;
    // 一方包含另一方
    if (songName.contains(lrcName) || lrcName.contains(songName)) {
        double ratio = static_cast<double>(qMin(songName.length(), lrcName.length()))
                       / qMax(songName.length(), lrcName.length());
        return 0.85 * ratio;
    }
    // 去掉常见的修饰后缀后再比较
    auto stripSuffix = [](QString s) -> QString {
        static const QStringList patterns = {"-", "—", "–", "(", "（", "[", "【"};
        for (const auto& p : patterns) {
            int idx = s.indexOf(p);
            if (idx > 0)
                s = s.left(idx).trimmed();
        }
        return s;
    };
    QString a = stripSuffix(songName);
    QString b = stripSuffix(lrcName);
    if (a == b)
        return 0.9;
    if (a.contains(b) || b.contains(a))
        return 0.8;
    // 计算公共前缀长度
    int commonPrefix = 0;
    int minLen       = qMin(a.length(), b.length());
    while (commonPrefix < minLen && a[commonPrefix] == b[commonPrefix])
        ++commonPrefix;
    if (commonPrefix > 0)
        return 0.5 * static_cast<double>(commonPrefix) / qMax(a.length(), b.length());
    return 0.0;
}

} // namespace mod
