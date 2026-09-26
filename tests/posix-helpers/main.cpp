// rootfs 可写窗口守卫 + 口令区两个 POSIX 原语的行为测试。
//
// 为什么要单独做这个：这三样东西的"关键分支"在正常使用中一辈子走不到 ——
//   * `RootFileSystemWritableGuard`：嵌套进入、remount 到 rw 失败、还原失败、
//     本来就 rw（Mod::uninstall 留下的状态）、提前 return / 异常展开；
//   * `_replaceFileAtomically`：tmp 打不开、短写、rename 失败、权限被 umask 削掉；
//   * `_randomSalt`：CSPRNG 读不到、字母表映射写错（会退化成"只有几十种 salt"）。
// 而它们的失败后果都落在最痛的地方：前者把只读 rootfs 留在可写，后者毁掉 /etc/shadow。
//
// 被测代码不是手抄的：`extracted.inc` 由 extract.py 从 PenMods 源码原样抽取。
// remount 通过 `mod::util::setRootFileSystemWritable` 换成可控桩（见下），其余一字不改。
//
// 三种跑法（见 CI 的 .github/workflows/posix-helpers-test.yaml）：
//   1) CI 原生 x86_64 —— 全部断言有效，用于回归；
//   2) CI 交叉编译成 aarch64 静态二进制，先用 qemu 冒烟，再推真机跑；
//   3) 真机跑 —— 真实的定制内核 + 真实 ext4，`fsync` / `rename` 语义才算数。

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <set>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <type_traits>
#include <unistd.h>
#include <utility>
#include <vector>

// ---------------------------------------------------------------------------
// spdlog 桩：守卫的析构在"还原失败"时会 spdlog::error，这里把 {} 填好打到 stderr。
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
void error(const char* fmt, A&&... args) {
    _stub::emit("error", fmt, std::forward<A>(args)...);
}

template <class... A>
void warn(const char* fmt, A&&... args) {
    _stub::emit("warn", fmt, std::forward<A>(args)...);
}

} // namespace spdlog

#include "extracted.inc"

// ---------------------------------------------------------------------------
// remount 桩：接管 mod::util::isRootFileSystemWritable / setRootFileSystemWritable。
//
// 刻意复刻真实现的一个行为：**已经是目标状态就直接返回 true、不做任何事**。
// 守卫的去重（"嵌套时只有最外层 remount"）正好建立在这个短路之上，桩不复刻就测不出来。
// ---------------------------------------------------------------------------
static bool gFsWritable      = false; // 桩眼里的 /proc/mounts 状态
static int  gRemounts        = 0;     // 真正执行的 remount 次数（短路不计）
static int  gRemountsToRw    = 0;
static int  gRemountsToRo    = 0;
static bool gFailRemountToRw = false; // 注入：remount rw 失败
static bool gFailRemountToRo = false; // 注入：remount ro（归还）失败

namespace mod::util {

bool isRootFileSystemWritable() { return gFsWritable; }

bool setRootFileSystemWritable(bool writable) {
    if (gFsWritable == writable) {
        return true; // 与真实现的短路一致
    }
    ++gRemounts;
    if (writable) {
        ++gRemountsToRw;
        if (gFailRemountToRw) return false;
    } else {
        ++gRemountsToRo;
        if (gFailRemountToRo) return false;
    }
    gFsWritable = writable;
    return true;
}

} // namespace mod::util

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

static std::string stats() {
    return "remounts=" + std::to_string(gRemounts) + " (rw=" + std::to_string(gRemountsToRw) +
           ", ro=" + std::to_string(gRemountsToRo) + ")";
}

/// 复位桩状态：默认"出厂状态"= / 是 ro。
static void resetStub(bool writable = false) {
    gFsWritable      = writable;
    gRemounts        = 0;
    gRemountsToRw    = 0;
    gRemountsToRo    = 0;
    gFailRemountToRw = false;
    gFailRemountToRo = false;
}

// ---------------------------------------------------------------------------
// 文件工具
// ---------------------------------------------------------------------------
static bool writeFileRaw(const std::string& path, const void* data, size_t len, mode_t mode) {
    const int fd = ::open(path.c_str(), O_WRONLY | O_CREAT | O_TRUNC, mode);
    if (fd < 0) return false;
    ::fchmod(fd, mode);
    const char* p    = static_cast<const char*>(data);
    size_t      left = len;
    while (left > 0) {
        const ssize_t n = ::write(fd, p, left);
        if (n <= 0) {
            ::close(fd);
            return false;
        }
        p += n;
        left -= static_cast<size_t>(n);
    }
    ::close(fd);
    return true;
}

static bool readFileRaw(const std::string& path, std::string& out) {
    std::FILE* f = std::fopen(path.c_str(), "rb");
    if (f == nullptr) return false;
    char   buf[4096];
    size_t got = 0;
    out.clear();
    while ((got = std::fread(buf, 1, sizeof buf, f)) > 0) {
        out.append(buf, got);
    }
    std::fclose(f);
    return true;
}

static bool exists(const std::string& path) {
    struct stat st{};
    return ::stat(path.c_str(), &st) == 0;
}

/// 返回 st_mode & 07777；取不到返回 0xFFFF（当成"不等于任何期望值"）。
static int fileMode(const std::string& path) {
    struct stat st{};
    if (::stat(path.c_str(), &st) != 0) return 0xFFFF;
    return static_cast<int>(st.st_mode & 07777);
}

static long long fileSize(const std::string& path) {
    struct stat st{};
    if (::stat(path.c_str(), &st) != 0) return -1;
    return static_cast<long long>(st.st_size);
}

/// 隐藏 tmp 也统计进来（`.shadow.penmods.tmp` 这种以点开头的），用来断言"没有残留"。
static int dirEntryCountAll(const std::string& dir) {
    int  n = 0;
    DIR* d = ::opendir(dir.c_str());
    if (d == nullptr) return -1;
    while (const auto* e = ::readdir(d)) {
        if (std::strcmp(e->d_name, ".") == 0 || std::strcmp(e->d_name, "..") == 0) continue;
        ++n;
    }
    ::closedir(d);
    return n;
}

int main() {
    std::printf("rootfs 守卫 + 口令区 POSIX 原语 行为测试    pid=%d\n", static_cast<int>(::getpid()));
    const mode_t startUmask = ::umask(0);
    std::printf("sizeof(mode_t)=%zu  进程启动 umask=%04o\n", sizeof(mode_t), static_cast<unsigned>(startUmask));
    ::umask(startUmask);

    // ================================================================ 1
    section("1. 守卫基本窗口：ro → rw → ro，各恰好一次");
    {
        resetStub(false);
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(guard.ok(), "guard.ok() == true（/ 本来是 ro，remount 成功）");
            ok(gFsWritable, "窗口内 / 是 rw");
            ok(gRemountsToRw == 1 && gRemountsToRo == 0, "进入时恰好 remount rw 一次，" + stats());
        }
        ok(!gFsWritable, "出作用域后 / 回到 ro（RAII 生效）");
        ok(gRemountsToRo == 1 && gRemounts == 2, "离开时恰好 remount ro 一次，" + stats());
    }

    // ================================================================ 2
    section("2. 嵌套窗口：只 remount 一次，只有最外层负责还原");
    {
        resetStub(false);
        {
            mod::util::RootFileSystemWritableGuard outer;
            ok(outer.ok(), "外层 ok()");
            {
                mod::util::RootFileSystemWritableGuard inner;
                ok(inner.ok(), "内层 ok()");
                ok(gRemountsToRw == 1, "内层进入**不再** remount（引用计数生效），" + stats());
            }
            ok(gRemountsToRo == 0, "内层析构**不**还原（还没到最外层），" + stats());
            ok(gFsWritable, "内层析构后 / 仍是 rw");
        }
        ok(!gFsWritable, "最外层析构后 / 回到 ro");
        ok(gRemountsToRo == 1 && gRemounts == 2, "整个嵌套周期只有 1 次 rw + 1 次 ro，" + stats());
    }

    // ================================================================ 3
    section("3. 三层嵌套：计数没漏减");
    {
        resetStub(false);
        {
            mod::util::RootFileSystemWritableGuard a;
            { mod::util::RootFileSystemWritableGuard b; { mod::util::RootFileSystemWritableGuard c; } }
            ok(gFsWritable && gRemountsToRo == 0, "三层结束后 / 仍是 rw，" + stats());
        }
        ok(!gFsWritable && gRemountsToRo == 1 && gRemounts == 2, "最外层析构后恰好归还一次，" + stats());
    }

    // ================================================================ 4
    section("4. 进入失败：ok()==false，不留下待还原状态，计数能复位");
    {
        resetStub(false);
        gFailRemountToRw = true;
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(!guard.ok(), "remount rw 失败时 ok() == false");
            ok(!gFsWritable, "/ 仍是 ro（没有假装成功）");
        }
        ok(gRemountsToRo == 0, "没进窗口就不该尝试 remount ro（不能凭空还原），" + stats());

        // 关键：失败路径必须把引用计数退回去，否则后续所有进入者都会以为"已经在窗口里"。
        gFailRemountToRw = false;
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(guard.ok() && gFsWritable, "上一次失败没有把计数卡住，后续仍能正常开窗口");
            ok(gRemountsToRw == 2, "这次是真的 remount 了 rw（不是被计数骗过去），" + stats());
        }
        ok(!gFsWritable && gRemountsToRo == 1, "窗口正常关闭，" + stats());
    }

    // ================================================================ 5
    section("5. 还原失败：/ 停在 rw（真实现里这正是要报警的状态），且不崩");
    {
        resetStub(false);
        gFailRemountToRo = true;
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(guard.ok(), "进入成功");
        }
        ok(gFsWritable, "归还失败时 / 停在 rw —— 守卫自己会 spdlog::error，不该静默");
        note("上面 stderr 里应该有一条 `Failed to restore rootfs mount state` —— 那是守卫在喊");
        gFailRemountToRo = false;

        // 还原失败后计数也必须归零，否则下次进窗口会不 remount 而直接写 ro 文件系统。
        resetStub(false);
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(guard.ok() && gRemountsToRw == 1, "下一轮进入仍然正常 remount rw，" + stats());
        }
        ok(!gFsWritable, "下一轮窗口也能正常归还");
    }

    // ================================================================ 6
    section("6. 起始就是 rw（Mod::uninstall 留下的状态）：全程零 remount");
    {
        resetStub(true);
        {
            mod::util::RootFileSystemWritableGuard guard;
            ok(guard.ok(), "已经 rw 时进入成功");
            ok(gRemounts == 0, "本就 rw → 进入时不做任何 remount，" + stats());
        }
        ok(gFsWritable, "离开后仍是 rw —— 守卫把\"现状\"当原状态还给设备，不擅自收紧");
        ok(gRemounts == 0, "归还也不需要 remount，" + stats());
    }

    // ================================================================ 7
    section("7. RAII 的意义：提前 return / 异常展开也会还原（EX-04 的核心）");
    {
        resetStub(false);
        auto earlyReturn = []() -> bool {
            mod::util::RootFileSystemWritableGuard guard;
            if (!guard.ok()) return false;
            return true; // 在作用域里提前返回
        };
        ok(earlyReturn(), "带守卫的函数正常返回");
        ok(!gFsWritable && gRemountsToRo == 1, "提前 return 也会还原，" + stats());

        resetStub(false);
        try {
            mod::util::RootFileSystemWritableGuard guard;
            throw std::runtime_error("boom");
        } catch (const std::runtime_error&) {
        }
        ok(!gFsWritable && gRemountsToRo == 1, "异常展开也会还原，" + stats());
    }

    // ================================================================ 8
    section("8. 原子替换：成功路径（内容 / 权限 / 无 tmp 残留）");
    char        tmpl[] = "/tmp/penmods-posix-XXXXXX";
    const char* dirEnv = ::mkdtemp(tmpl);
    if (dirEnv == nullptr) {
        ok(false, "无法在 /tmp 建临时目录，后面的替换测试全部跳过");
    } else {
        const std::string dir(dirEnv);
        note("临时目录 " + dir);

        const std::string target = dir + "/shadow";
        const std::string tmp    = dir + "/.shadow.penmods.tmp";

        ok(writeFileRaw(target, "OLD-CONTENT", 11, 0600), "准备原文件（0600）");
        ::umask(022);
        ok(::umask(022) == 022, "umask 确实是 022");
        ok(mod::_replaceFileAtomically(target, tmp.c_str(), "NEW-CONTENT", 11, 0600), "原子替换成功");
        std::string got;
        ok(readFileRaw(target, got) && got == "NEW-CONTENT", "内容是新的，实际 = [" + got + "]");
        ok(!exists(tmp), "临时文件已被 rename 走，没有残留");
        ok(fileMode(target) == 0600, "权限保持 0600");
        ok(dirEntryCountAll(dir) == 1, "目录里只剩目标文件（条目数 " + std::to_string(dirEntryCountAll(dir)) + "）");

        // ============================================================ 9
        section("9. 原子替换：umask 不能削掉权限（fchmod 的意义）");
        {
            const mode_t old = ::umask(0077); // 常见的收紧 umask
            ok(mod::_replaceFileAtomically(target, tmp.c_str(), "X", 1, 0640), "替换成功（umask 0077）");
            ok(fileMode(target) == 0640,
               "结果权限是 0640 而不是 0600 —— 证明 fchmod 生效，没被 umask 削掉");
            ok(dirEntryCountAll(dir) == 1, "无 tmp 残留");
            ::umask(old);
        }

        // ============================================================ 10
        section("10. 原子替换：失败路径绝不碰目标文件（旧实现会毁掉 /etc/shadow 的地方）");
        {
            ok(writeFileRaw(target, "KEEPME", 6, 0600), "把目标文件置成 KEEPME");
            ok(!mod::_replaceFileAtomically(target, (dir + "/no-such-dir/x.tmp").c_str(), "NEW", 3, 0600),
               "tmp 目录不存在 → 返回 false");
            std::string keep;
            ok(readFileRaw(target, keep) && keep == "KEEPME", "目标文件原封不动，实际 = [" + keep + "]");
            ok(fileMode(target) == 0600 && fileSize(target) == 6, "权限与长度都没被改");
        }

        // ============================================================ 11
        section("11. 原子替换：空内容 / 含 NUL 的二进制 / 256KB");
        {
            ok(mod::_replaceFileAtomically(target, tmp.c_str(), "", 0, 0600), "写空内容成功");
            ok(fileSize(target) == 0, "结果是 0 字节文件");

            const std::string bin("a\0b\0c", 5); // 含 3 个 NUL
            ok(mod::_replaceFileAtomically(target, tmp.c_str(), bin.data(), bin.size(), 0600),
               "写含 NUL 的内容成功");
            std::string got2;
            ok(readFileRaw(target, got2) && got2.size() == 5 && got2 == bin,
               "5 字节原样写入（说明用的是显式长度，不是 strlen）");

            std::string big;
            big.reserve(256 * 1024);
            for (int i = 0; i < 256 * 1024; ++i) big.push_back(static_cast<char>('a' + (i % 26)));
            ok(mod::_replaceFileAtomically(target, tmp.c_str(), big.data(), big.size(), 0600), "写 256KB 成功");
            std::string got3;
            ok(readFileRaw(target, got3) && got3 == big, "256KB 内容逐字节一致");
            ok(dirEntryCountAll(dir) == 1, "无 tmp 残留");
        }
    }

    // ================================================================ 12
    section("12. salt：长度 / 字母表 / 唯一性 / 边界");
    {
        const std::string s16 = mod::_randomSalt(16);
        ok(s16.size() == 16, "16 字符请求返回 16 字符，实际 " + std::to_string(s16.size()));

        bool inAlphabet = true;
        for (char c : s16) {
            if (std::strchr(mod::kCryptSaltAlphabet, c) == nullptr) inAlphabet = false;
        }
        ok(inAlphabet, "字符全部落在 crypt base64 字母表内，实际 = [" + s16 + "]");

        std::set<std::string> seen;
        for (int i = 0; i < 200; ++i) seen.insert(mod::_randomSalt(16));
        ok(seen.size() == 200, "200 次取样两两不同（实际 " + std::to_string(seen.size()) + " 个）");

        ok(mod::_randomSalt(0).empty(), "长度 0 → 空串（不越界）");
        ok(mod::_randomSalt(65).empty(), "长度 65 → 空串（不越界）");
        ok(mod::_randomSalt(64).size() == 64, "长度 64 是上边界，可用");
    }

    // ================================================================ 13
    section("13. salt：64 个字符都要出现，且分布没有明显偏（映射写错的照妖镜）");
    {
        // 映射若退化成"只有前 N 个字符"或用了带偏的 `% 52`，这一节会直接炸。
        const int rounds = 2000;
        int       hist[64];
        std::memset(hist, 0, sizeof hist);
        int badChars = 0;
        for (int i = 0; i < rounds; ++i) {
            const std::string s = mod::_randomSalt(16);
            if (s.size() != 16) {
                ++badChars;
                continue;
            }
            for (char c : s) {
                const char* p = std::strchr(mod::kCryptSaltAlphabet, c);
                if (p == nullptr) {
                    ++badChars;
                    continue;
                }
                ++hist[p - mod::kCryptSaltAlphabet];
            }
        }
        ok(badChars == 0, "全部字符合法（异常 " + std::to_string(badChars) + " 个）");

        int minv = hist[0], maxv = hist[0], used = 0;
        for (int v : hist) {
            minv = std::min(minv, v);
            maxv = std::max(maxv, v);
            if (v > 0) ++used;
        }
        const long long total = static_cast<long long>(rounds) * 16;
        note("总样本 " + std::to_string(total) + "，期望每字符 " + std::to_string(total / 64) +
             "，实际 min=" + std::to_string(minv) + " max=" + std::to_string(maxv) + " used=" +
             std::to_string(used) + "/64");
        ok(used == 64, "64 个字符全部出现过（实际 " + std::to_string(used) + "/64）");
        // 期望 500/桶、标准差约 22，350/650 是 ±6.8σ，正常绝不会误报。
        ok(minv >= 350 && maxv <= 650, "分布无明显偏（min>=350 且 max<=650）");
    }

    // ================================================================ 14
    section("14. salt 真的能当 crypt setting 用（形态检查，不做散列）");
    {
        const std::string salt    = mod::_randomSalt(16);
        const std::string setting = "$6$" + salt + "$";
        ok(setting.size() == 20, "`$6$` + 16 字符 salt + `$` 共 20 字符，实际 " + std::to_string(setting.size()));
        ok(setting.find('$') == 0 && setting.rfind('$') == 19, "$ 只在首尾");
        ok(setting.find('\n') == std::string::npos && setting.find(':') == std::string::npos,
           "不含换行 / 冒号（它们会破坏 /etc/shadow 的行与字段）");
    }

    std::printf("\n----------------------------------------\n");
    std::printf("PASS %d   FAIL %d\n", gPass, gFail);
    std::printf("----------------------------------------\n");
    std::fflush(stdout);
    return gFail > 120 ? 120 : gFail;
}
