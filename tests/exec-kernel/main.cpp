// exec 内核行为测试。
//
// 为什么要单独做这个：`mod::exec()` 是所有 shell 调用点的公共依赖，其中不少
// 在开机路径和 UI 线程上；而新内核（fork + 非阻塞读 + 超时 + 收尾宽限）的分支
// 在正常使用中根本走不到（超时、孙进程占着管道），只能主动构造。
//
// 被测代码不是手抄的：`extracted.inc` 由 extract.py 从 PenMods 源码原样抽取，
// 只有两行带 QString 的重载被剥掉（这里没有 Qt）。所以测的就是要上机的那份逻辑。
//
// 三种跑法（见 CI 的 .github/workflows/exec-kernel-test.yaml）：
//   1) CI 原生 x86_64 —— 全部断言有效，用于回归；
//   2) CI 交叉编译成 aarch64 静态二进制后再用 qemu 跑一遍 —— 验证指令集侧没写错；
//   3) 推到真机跑 —— 真实的定制内核 + 真实的 busybox `/bin/sh`，
//      CI 上是 dash，shell 细节（内建命令、`sleep` 是否支持小数、`pgrep` 有无）会不同。
//
// 已知在真机/qemu 上会偏离的断言：`sleep 0.6` 这类**小数秒**依赖 busybox 的
// `sleep` 支持小数；第 9、10 节的 fd/僵尸统计依赖 `/proc` 可用。

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <dirent.h>
#include <fcntl.h>
#include <signal.h>
#include <string>
#include <sys/wait.h>
#include <thread>
#include <type_traits>
#include <unistd.h>
#include <utility>
#include <vector>

// ---------------------------------------------------------------------------
// spdlog 桩：内核里只用到 spdlog::warn / spdlog::error 记日志，这里把 {} 填好打到 stderr，
// 既不影响被测逻辑，也方便观察内核在异常路径上说了什么。
// ---------------------------------------------------------------------------
namespace spdlog {
namespace _stub {

template <class T>
std::string toStr(T&& v) {
    if constexpr (std::is_convertible_v<T, const char*>) {
        return std::string(static_cast<const char*>(v));
    } else if constexpr (std::is_arithmetic_v<std::decay_t<T>>) {
        return std::to_string(v);
    } else {
        return "<non-scalar>";
    }
}

template <class... A>
void emit(const char* level, const char* fmt, A&&... args) {
    std::string out(fmt);
    const std::vector<std::string> vals{toStr(std::forward<A>(args))...};
    size_t pos = 0;
    for (const auto& v : vals) {
        const size_t p = out.find("{}", pos);
        if (p == std::string::npos) break;
        out.replace(p, 2, v);
        pos = p + v.size();
    }
    std::fprintf(stderr, "[%s] %s\n", level, out.c_str());
}

} // namespace _stub

template <class... A>
void warn(const char* fmt, A&&... args) {
    _stub::emit("warn", fmt, std::forward<A>(args)...);
}

template <class... A>
void error(const char* fmt, A&&... args) {
    _stub::emit("error", fmt, std::forward<A>(args)...);
}

} // namespace spdlog

#include "extracted.inc"

// ---------------------------------------------------------------------------
// 极简测试框架
// ---------------------------------------------------------------------------
static int gPass = 0;
static int gFail = 0;

static void ok(bool cond, const std::string& what) {
    std::printf("  [%s] %s\n", cond ? "PASS" : "FAIL", what.c_str());
    std::fflush(stdout);
    if (cond) {
        ++gPass;
    } else {
        ++gFail;
    }
}

static void note(const std::string& what) {
    std::printf("  [note] %s\n", what.c_str());
    std::fflush(stdout);
}

static void section(const char* name) {
    std::printf("\n=== %s ===\n", name);
    std::fflush(stdout);
}

static long long ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

static std::string escaped(const std::string& s) {
    std::string out;
    for (char c : s) {
        if (c == '\n') {
            out += "\\n";
        } else if (c == '\r') {
            out += "\\r";
        } else {
            out += c;
        }
    }
    if (out.size() > 120) out = out.substr(0, 120) + "...<截断>";
    return out;
}

/// /proc/self/fd 里的条目数。用来验证 exec 不泄漏 fd。
static int openFdCount() {
    DIR* d = ::opendir("/proc/self/fd");
    if (d == nullptr) return -1;
    int n = 0;
    while (const auto* e = ::readdir(d)) {
        if (e->d_name[0] != '.') ++n;
    }
    ::closedir(d);
    return n;
}

/// 扫 /proc，统计 ppid 是我、且状态为 Z 的子进程。用来验证 exec 不留僵尸。
static int zombieChildren() {
    DIR* d = ::opendir("/proc");
    if (d == nullptr) return -1;
    const pid_t me = ::getpid();
    int         n  = 0;
    while (const auto* e = ::readdir(d)) {
        const char* nm = e->d_name;
        if (nm[0] < '0' || nm[0] > '9') continue;
        const std::string path = std::string("/proc/") + nm + "/stat";
        std::FILE*        f    = std::fopen(path.c_str(), "r");
        if (f == nullptr) continue;
        char   buf[1024];
        size_t got = std::fread(buf, 1, sizeof buf - 1, f);
        std::fclose(f);
        if (got == 0) continue;
        buf[got]       = '\0';
        const char* cp = std::strrchr(buf, ')');
        if (cp == nullptr || cp[1] != ' ') continue;
        const char state = cp[2];
        int        ppid  = -1;
        if (std::sscanf(cp + 4, "%d", &ppid) != 1) continue;
        if (ppid == static_cast<int>(me) && state == 'Z') ++n;
    }
    ::closedir(d);
    return n;
}

int main() {
    std::printf("mod::exec() 内核行为测试    pid=%d\n", static_cast<int>(::getpid()));
    std::printf("超时档位: quick=%d normal=%d long=%d verylong=%d notimeout=%d\n", mod::kExecQuickMs, mod::kExecNormalMs,
                mod::kExecLongMs, mod::kExecVeryLongMs, mod::kExecNoTimeout);

    // ---------------------------------------------------------------- 1
    section("1. 基本语义：stdout 捕获 / 末尾裁剪 / 退出码");
    {
        auto r = mod::execWithResult("echo hello");
        ok(r.launched && r.childExited && !r.timedOut, "echo hello: launched & childExited & !timedOut");
        ok(r.out == "hello", "echo hello -> \"hello\"（末尾 \\n 被裁），实际 " + escaped(r.out));
        ok(r.exitCode == 0 && r.ok(), "echo hello: exitCode==0 且 ok()==true");

        auto r2 = mod::execWithResult("printf 'abc\\n\\n'");
        ok(r2.out == "abc\n", "printf 'abc\\n\\n' -> \"abc\\n\"（只裁**一个**换行，与旧实现一致），实际 " + escaped(r2.out));

        auto r3 = mod::execWithResult("true");
        ok(r3.out.empty() && r3.exitCode == 0 && r3.ok(), "true -> 空输出但 exitCode==0 且 ok()==true");

        auto r4 = mod::execWithResult("false");
        ok(r4.out.empty() && r4.exitCode == 1 && !r4.ok(), "false -> exitCode==1 且 ok()==false");

        auto r5 = mod::execWithResult("exit 42");
        ok(r5.exitCode == 42, "exit 42 -> exitCode 透传，实际 " + std::to_string(r5.exitCode));

        // 纯字符串版接口（调用点用得最多的那些重载）
        const std::string s = mod::exec("echo str-api");
        ok(s == "str-api", "exec(const char*) -> \"str-api\"，实际 " + escaped(s));
        const std::string s2 = mod::exec("echo timed", mod::kExecQuickMs);
        ok(s2 == "timed", "exec(const char*, int) -> \"timed\"，实际 " + escaped(s2));
    }

    // ---------------------------------------------------------------- 2
    section("2. 只接 stdout：stderr 不进结果（与旧 popen 一致）");
    {
        auto r = mod::execWithResult("echo OUT; echo ERR-TO-STDERR 1>&2");
        ok(r.out == "OUT", "stderr 未被捕获 -> out==\"OUT\"，实际 " + escaped(r.out));
        note("stderr 应出现在**本测试进程**的 stderr 上（runner 会另行断言）");
    }

    // ---------------------------------------------------------------- 3
    section("3. shell 特性：管道 / 重定向 / && / 引号 / 变量");
    {
        ok(mod::exec("echo a b c | wc -w") == "3", "管道 |");
        ok(mod::exec("echo x > /tmp/pl_exec_test && cat /tmp/pl_exec_test") == "x", "重定向 + &&");
        ok(mod::exec("echo 'a b'") == "a b", "引号内空格");
        ok(mod::exec("A=7; echo $A") == "7", "变量赋值与展开");
        ok(mod::exec("false || echo fallback") == "fallback", "|| 短路");
    }

    // ---------------------------------------------------------------- 4
    section("4. 大输出：跨多次 read(4096) 不截断");
    {
        auto r = mod::execWithResult("seq 1 5000");
        ok(r.out.size() > 20000, "seq 1 5000 输出 " + std::to_string(r.out.size()) + " 字节 > 20000");
        ok(std::count(r.out.begin(), r.out.end(), '\n') == 4999, "换行数 == 4999（5000 行，末尾那个被裁掉）");
        ok(r.out.size() >= 4 && r.out.compare(r.out.size() - 4, 4, "5000") == 0, "末行 5000 恰好在末尾（没被截断）");
        // ⚠️ 这里必须用 compare(0,…) 而不是 rfind()：`seq 1 5000` 的输出里 "1\n2"
        // 会在 `21\n22`、`201\n202` 等处**再次出现**，而 rfind 取的是"最后一次出现"，
        // 拿它跟 0 比会永远不成立（第一次跑 CI 就栽在这条上）。
        ok(r.out.compare(0, 4, "1\n2\n") == 0, "首行完整（以 \"1\\n2\\n\" 开头）");
    }

    // ---------------------------------------------------------------- 5
    section("5. 子进程还活着时不能提前收尾");
    {
        const auto t0 = ms();
        auto       r  = mod::execWithResult("echo a; sleep 0.6; echo b");
        const auto dt = ms() - t0;
        ok(r.out == "a\nb", "慢速两段输出完整 -> \"a\\nb\"，实际 " + escaped(r.out));
        ok(dt >= 500, "耗时 " + std::to_string(dt) + "ms >= 500ms（没有提前返回）");
        ok(r.childExited && !r.timedOut && r.exitCode == 0, "正常结束的标记齐全");
    }

    // ---------------------------------------------------------------- 6
    section("6. 孙进程占着管道：不再永久挂住（旧实现卡在这里）");
    {
        const auto t0 = ms();
        auto       r  = mod::execWithResult("(sleep 30 &) ; echo done", 60000);
        const auto dt = ms() - t0;
        ok(r.out == "done", "输出完整 -> \"done\"，实际 " + escaped(r.out));
        ok(r.childExited && !r.timedOut, "childExited==true 且未被判超时");
        ok(dt < 3000, "耗时 " + std::to_string(dt) + "ms < 3000ms（收尾宽限生效；旧实现要等满 30s）");

        const auto t1 = ms();
        auto       r2 = mod::execWithResult("(sleep 30 >/dev/null 2>&1 &) ; echo detached", 60000);
        const auto d2 = ms() - t1;
        ok(r2.out == "detached" && d2 < 3000, "后台进程已把 stdout 指走时也立刻返回（" + std::to_string(d2) + "ms）");
    }

    // ---------------------------------------------------------------- 7
    section("7. 超时：真的会掐断");
    {
        const auto t0 = ms();
        auto       r  = mod::execWithResult("sleep 30", 1000);
        const auto dt = ms() - t0;
        ok(r.launched, "launched==true（确实起来过）");
        ok(r.timedOut, "timedOut==true");
        ok(r.childExited, "被 SIGKILL 后仍已回收 -> childExited==true（不留僵尸）");
        ok(r.exitCode == -1, "被信号杀死 -> exitCode==-1（不是 0），实际 " + std::to_string(r.exitCode));
        ok(dt >= 900 && dt < 4000, "耗时 " + std::to_string(dt) + "ms 落在 [900, 4000)");
        ok(!r.ok(), "ok()==false");

        auto r2 = mod::execWithResult("echo start; sleep 30", 1000);
        ok(r2.out == "start", "超时前已输出的内容仍然拿到 -> \"start\"，实际 " + escaped(r2.out));
        ok(r2.timedOut, "仍标记 timedOut");

        // timeoutMs<=0 表示不设超时
        const auto t1 = ms();
        auto       r3 = mod::execWithResult("sleep 1.5", mod::kExecNoTimeout);
        const auto d3 = ms() - t1;
        ok(!r3.timedOut && r3.childExited && d3 >= 1400,
           "timeout=0 表示不超时：耗时 " + std::to_string(d3) + "ms，正常结束");

        // 负数同样按"不超时"处理
        const auto t2 = ms();
        auto       r4 = mod::execWithResult("sleep 0.8", -5);
        const auto d4 = ms() - t2;
        ok(!r4.timedOut && r4.childExited && d4 >= 700, "负数超时按不超时处理：耗时 " + std::to_string(d4) + "ms");
    }

    // ---------------------------------------------------------------- 8
    section("8. 边界：命令不存在 / 空指针命令");
    {
        auto r = mod::execWithResult("definitely_not_a_command_zzz_2026");
        ok(r.launched, "sh 起来了 -> launched==true");
        ok(r.childExited, "childExited==true");
        ok(r.exitCode == 127, "exitCode==127（sh 的 not found），实际 " + std::to_string(r.exitCode));
        ok(r.out.empty(), "out 为空（错误信息走 stderr），实际 " + escaped(r.out));
        ok(!r.ok(), "ok()==false");

        auto rn = mod::execWithResult(static_cast<const char*>(nullptr), 0);
        ok(!rn.launched && !rn.ok() && rn.out.empty(), "nullptr 命令：返回失败结果，不抛异常、不崩");
    }

    // ---------------------------------------------------------------- 9
    section("9. 资源回收：fd 不泄漏、不留僵尸");
    {
        const int fd0 = openFdCount();
        const int z0  = zombieChildren();
        int       mismatched = 0;
        for (int i = 0; i < 100; ++i) {
            const std::string want = std::to_string(i);
            if (mod::exec(("echo " + want).c_str()) != want) ++mismatched;
        }
        const int fd1 = openFdCount();
        const int z1  = zombieChildren();
        ok(mismatched == 0, "100 次顺序调用输出全部正确（不符 " + std::to_string(mismatched) + " 次）");
        ok(fd0 >= 0 && fd1 <= fd0 + 1, "fd 数未增长：" + std::to_string(fd0) + " -> " + std::to_string(fd1));
        ok(z0 == 0 && z1 == 0, "无僵尸子进程：" + std::to_string(z0) + " -> " + std::to_string(z1));
    }

    // ---------------------------------------------------------------- 10
    section("10. 多线程并发（4 线程 x 25 次）");
    {
        std::atomic<int>         fails{0};
        std::vector<std::thread> threads;
        for (int t = 0; t < 4; ++t) {
            threads.emplace_back([t, &fails] {
                for (int i = 0; i < 25; ++i) {
                    const std::string want = "T" + std::to_string(t) + "-" + std::to_string(i);
                    const auto        r    = mod::exec(("echo " + want).c_str());
                    if (r != want) ++fails;
                }
            });
        }
        for (auto& th : threads) th.join();
        ok(fails.load() == 0, "并发输出全部正确（不符 " + std::to_string(fails.load()) + " 次）");
        ok(zombieChildren() == 0, "并发后无僵尸子进程");
    }

    // ---------------------------------------------------------------- 11
    section("11. 超时按进程组清掉整棵子树（管道另一端的孙进程也要死）");
    {
        // 判据用「命令行里那个独一无二的数字」，而不是"数 sleep 进程个数"：
        // 前者不受前面故意留下的后台 sleep 干扰，也不需要 killall / pkill ——
        // 实测真机的 busybox `pgrep -x sleep` 和 `pgrep sleep` 都匹配不到进程，
        // 只有 `pgrep -f` 可用，所以判据必须建立在 `-f` 上。
        //
        // pattern 写成 `123[4]5` 是经典的 [x] 技巧：正则匹配 "sleep 12345"，
        // 但承载 pgrep 的那个 `sh -c` 命令行里是**字面量** "123[4]5"，不会自匹配。
        constexpr const char* kProbe = R"(pgrep -f "sleep 123[4]5")";

        const std::string leftBefore = mod::exec(kProbe, mod::kExecQuickMs);
        ok(leftBefore.empty(), "开工前没有 sleep 12345 残留，实际 = [" + escaped(leftBefore) + "]");

        // `sleep 12345 | cat`：管道两端**必然**是 fork 出来的进程，所以 sleep 12345
        // 是 sh 的**孙进程** —— "只 kill 直接子进程"的实现会把它留在系统里继续跑。
        // （实测：修复前这一节留下 4 个 sleep，见首次 CI 输出的 note。）
        const auto t0 = ms();
        auto       r  = mod::execWithResult("sleep 12345 | cat", 800);
        const auto dt = ms() - t0;
        ok(r.timedOut, "timedOut==true");
        ok(dt < 4000, "耗时 " + std::to_string(dt) + "ms < 4000ms（没有等满 12345 秒）");

        ::usleep(400 * 1000); // 等 SIGKILL 生效 + 进程被回收
        const std::string left = mod::exec(kProbe, mod::kExecQuickMs);
        ok(left.empty(), "超时后 sleep 12345 无残留（整组被清），实际 = [" + escaped(left) + "]");

        // 对照组：正常结束的管道命令，本来就不该有残留
        auto fine = mod::execWithResult("sleep 0.2 | cat", mod::kExecQuickMs);
        ok(fine.ok(), "对照组 `sleep 0.2 | cat` 正常跑完");
    }

    std::printf("\n----------------------------------------\n");
    std::printf("PASS %d   FAIL %d\n", gPass, gFail);
    std::printf("----------------------------------------\n");
    std::fflush(stdout);
    return gFail > 120 ? 120 : gFail;
}
