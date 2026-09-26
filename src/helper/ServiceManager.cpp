// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "ServiceManager.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "common/util/System.h"

#include <QFile>
#include <QQmlContext>

#include <crypt.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <spdlog/spdlog.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <string>

namespace mod {

namespace {

/// `crypt()` 的 base64 字母表，正好 64 个字符。
///
/// 必须正好 64：`byte & 0x3F` 把 256 个取值映到 64 个字母上，每个字母恰好 4 个前置 ——
/// **无模偏**。原实现用 52 个字符（只有大小写字母）配 `% 52`，字母的前置个数 4 或 5 不等，
/// 是带偏的（EX-19）。
constexpr char kCryptSaltAlphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./";
static_assert(sizeof(kCryptSaltAlphabet) - 1 == 64, "salt 字母表必须正好 64 个字符");

/// 从内核 CSPRNG 读随机字节（`/dev/urandom`，本机实测存在且 0666）。
///
/// 刻意**不用** `QRandomGenerator`：它跑的是确定性 PRNG（内部状态可从输出反推），拿它
/// 生成口令 salt 等于把 salt 的随机性归零（EX-19）。失败时返回 false —— 调用方必须放弃
/// 改口令，而不是退回 PRNG 拿一个"看起来随机"的东西。
bool _fillRandomBytes(char* out, size_t len) {
    const int fd = ::open("/dev/urandom", O_RDONLY);
    if (fd < 0) {
        return false;
    }
    size_t done = 0;
    while (done < len) {
        const ssize_t n = ::read(fd, out + done, len - done);
        if (n > 0) {
            done += static_cast<size_t>(n);
            continue;
        }
        if (n < 0 && errno == EINTR) {
            continue;
        }
        ::close(fd);
        return false;
    }
    ::close(fd);
    return true;
}

/// 生成 `crypt()` 用的 salt：`length` 个字符，取自 64 字符的 crypt base64 表。
/// 返回空串表示**拿不到 CSPRNG**，调用方必须放弃改口令。
///
/// 做成自由函数（而不是 ServiceManager 的成员）是为了能被 tests/posix-helpers 原样抽出去
/// 做行为测试 —— 它不依赖 `this`，也不依赖 Qt。
std::string _randomSalt(size_t length) {
    if (length == 0 || length > 64) {
        return {}; // 跟 kCryptSaltAlphabet 与栈上缓冲区的容量绑定，越界直接拒
    }
    char raw[64];
    if (!_fillRandomBytes(raw, length)) {
        return {};
    }
    std::string ret;
    ret.reserve(length);
    for (size_t i = 0; i < length; i++) {
        ret += kCryptSaltAlphabet[static_cast<unsigned char>(raw[i]) & 0x3F];
    }
    return ret;
}

/// 原子替换 rootfs 上的一个文件：同目录 tmp → write → fsync → rename → fsync 目录。
///
/// 调用方**必须**已经持有 rootfs 可写窗口（`util::RootFileSystemWritableGuard`）。
/// 任何失败路径都只清理 tmp，绝不动目标文件本身。`mode` 必须由调用方从原文件上取下来
/// 传进来：rename 是"把新 inode 换到那个名字上"，**不会继承**旧文件的权限，不显式 chmod
/// 就会按 umask 掉到 0644 —— 对 /etc/shadow 来说等于把口令散列变成全机可读。
///
/// 刻意不用 `O_CLOEXEC` / `O_DIRECTORY`：这两个宏在 glibc 里归 `__USE_XOPEN2K8` 管，
/// 而本项目是 `-std=c++23`（严格 ISO，不给 `_GNU_SOURCE`）交叉编译，不保证可见；
/// 而它们在这里也没必要 —— fd 从 open 到 close 之间不会 exec，目录也只需能 fsync。
///
/// 收 `(ptr, len)` 而不是 `QByteArray`：这是个纯 POSIX 原语，不依赖 Qt，
/// 于是可以被 tests/posix-helpers 原样抽出来在宿主 / 真机上跑。
bool _replaceFileAtomically(const std::string& path, const char* tmpPath, const void* data, size_t len,
                            mode_t mode) {
    // tmp 与目标必须同目录：同一文件系统内 rename 才是原子的（跨文件系统会直接失败）。
    const int fd = ::open(tmpPath, O_WRONLY | O_CREAT | O_TRUNC, mode);
    if (fd < 0) {
        return false;
    }
    // open() 给的 mode 会被 umask 削掉（umask 022 时 0660 变成 0640），显式 fchmod 一次
    // 让权限严格等于原文件。失败不阻断：最终权限只会更窄、不会更宽。
    ::fchmod(fd, mode);

    bool        ok   = true;
    const char* p    = static_cast<const char*>(data);
    size_t      left = len;
    while (left > 0) {
        const ssize_t n = ::write(fd, p, left);
        if (n > 0) {
            p += n;
            left -= static_cast<size_t>(n);
            continue;
        }
        if (n < 0 && errno == EINTR) {
            continue;
        }
        ok = false;
        break;
    }

    // fsync 必须在 rename **之前**：ext4（本机是 data=ordered）下 rename 只是元数据操作，
    // 先把数据落盘再改名，才能保证改名之后看到的是完整内容，而不是"名字换了、内容还是空的"。
    if (ok && ::fsync(fd) != 0) {
        ok = false;
    }
    if (::close(fd) != 0) {
        ok = false;
    }
    if (!ok) {
        ::unlink(tmpPath);
        return false;
    }

    if (::rename(tmpPath, path.c_str()) != 0) {
        ::unlink(tmpPath);
        return false;
    }

    // 目录项也 fsync 一次，让 rename 本身持久化（否则掉电可能回退到旧文件）。
    // 这里用 O_RDONLY 打开目录（不带 O_DIRECTORY，理由见上面的说明）：Linux 上目录 fd
    // 不能 read，但可以 fsync。
    const auto slash = path.find_last_of('/');
    const auto dir   = (slash == std::string::npos) ? std::string(".") : path.substr(0, slash);
    const int  dirfd = ::open(dir.c_str(), O_RDONLY);
    if (dirfd >= 0) {
        ::fsync(dirfd);
        ::close(dirfd);
    }
    return true;
}

/// 只在**不存在**时留一份 /etc/shadow 的备份（0600）。
///
/// 这台设备上就 root 一个能登录的账户，口令库改坏就没有第二个账户能进；有备份则可以用
/// adb 的 root shell 把它拷回去，是唯一低成本的救援点。刻意不覆盖已有备份：否则第二次
/// 改口令时"备份"就变成了上一次的新口令，救不回出厂状态。
bool _ensureShadowBackup(const char* path, const char* bakPath) {
    struct stat st{};
    if (::stat(bakPath, &st) == 0) {
        return true; // 已有备份，不覆盖
    }
    QFile in(path);
    if (!in.open(QIODevice::ReadOnly)) {
        return false;
    }
    const QByteArray original = in.readAll();
    in.close();
    if (original.isEmpty()) {
        return false; // 读不到内容就别写一个空备份，那比没有更糟
    }
    // 备份本身也走原子路径：写坏备份不该留下半截文件。
    return _replaceFileAtomically(bakPath, "/etc/.shadow.penmods.bak.tmp", original.constData(),
                                 static_cast<size_t>(original.size()), 0600);
}

/// 有没有名字叫 `wanted` 的进程在跑 —— 扫 `/proc/*/comm`，**不 fork**。
///
/// EX-07：这个函数会被 `Q_PROPERTY` 的 READ 调用（`getSshStatus`），而 QML 每次重新求值
/// 绑定都会调一次（`SSHManagePage.qml:34/36` 绑了它）⇒ **这里绝不能 fork**。
/// 旧实现是 `exec("ps | grep [s]sh")`：一次求值 = `sh` + `ps` + `grep` 三个进程，
/// 而且直接违反同项目自己在 `Torch.cpp:29` 写下的规则（"这是 Q_PROPERTY 的 READ，
/// 会被 QML 轮询；不要用 exec()"）。
///
/// 扫 `/proc` 同样是一百多次 `open`，但比 fork+exec 便宜一个数量级，且不产生进程；
/// 语义与 `ps | grep sshd` 等价（看进程名，不看命令行）。
bool _isProcessRunning(const char* wanted) {
    DIR* proc = ::opendir("/proc");
    if (proc == nullptr) {
        return false;
    }
    const size_t wantedLen = std::strlen(wanted);
    bool         found     = false;
    while (struct dirent* ent = ::readdir(proc)) {
        // 只认纯数字的目录项（pid）。`/proc` 下还有 self / thread-self 这类软链，
        // 跟着它们会重复统计；非数字的一律跳过。
        bool allDigits = true;
        for (const char* p = ent->d_name; *p != '\0'; ++p) {
            if (*p < '0' || *p > '9') {
                allDigits = false;
                break;
            }
        }
        if (!allDigits) {
            continue;
        }

        char path[64];
        std::snprintf(path, sizeof path, "/proc/%s/comm", ent->d_name);
        const int fd = ::open(path, O_RDONLY);
        if (fd < 0) {
            continue; // 进程刚好退出，正常
        }
        char    comm[64]{};
        ssize_t n = -1;
        do {
            n = ::read(fd, comm, sizeof comm - 1);
        } while (n < 0 && errno == EINTR);
        ::close(fd);
        if (n <= 0) {
            continue;
        }
        comm[static_cast<size_t>(n)] = '\0';
        // `comm` 以换行结尾（内核就是这么给的），比到换行为止。
        const size_t len = std::strcspn(comm, "\n");
        if (len == wantedLen && std::strncmp(comm, wanted, len) == 0) {
            found = true;
            break;
        }
    }
    ::closedir(proc);
    return found;
}

} // namespace

ServiceManager::ServiceManager() {

    mCfg = Config::getInstance().read(mClassName);

    mAdbAutoRun          = mCfg["adb_autorun"];
    mSkipAdbVerification = mCfg["adb_skip_verification"];
    mSshAutoRun          = mCfg["ssh_autorun"];

    connect(&Event::getInstance(), &Event::uiCompleted, this, &ServiceManager::onUiCompleted);
    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("serviceManager", this);
    });
}

void ServiceManager::onUiCompleted() {
    if (!getAdbStatus() && getAdbAutoRun()) {
        startAdb(true);
    }
    if (!getSshStatus() && getSshAutoRun()) {
        startSsh(true);
    }
    if (getSkipAdbVerification()) {
        _passAdbVerification();
    }
}

bool ServiceManager::getAdbStatus() const {
    return readFileNoLast("/tmp/.usb_config").find("usb_adb_en") != std::string::npos;
}

bool ServiceManager::getSshStatus() const {
    // EX-07：这是 `Q_PROPERTY(bool sshStatus READ ...)` 的 READ，`SSHManagePage.qml:34/36`
    // 绑了它 ⇒ QML 每次重新求值这个绑定都会调一次，所以**这里不能 fork**。
    // 旧实现 `exec("ps | grep [s]sh")` 一次求值就起 sh + ps + grep 三个进程。
    // 现在扫 `/proc/*/comm`（见 `_isProcessRunning`），语义等价于 `ps | grep sshd`，零进程。
    return _isProcessRunning("sshd");
}

bool ServiceManager::startAdb(bool dontShowToast) {
    PEN_CALL(uint64, "adb_onoff", char)(1);
    if (!dontShowToast) {
        showToast("ADB服务已启用");
    }
    emit adbStatusChanged();
    return true;
}
bool ServiceManager::stopAdb(bool dontShowToast) {
    PEN_CALL(uint64, "adb_onoff", char)(0);
    if (!dontShowToast) {
        showToast("ADB服务已停用");
    }
    emit adbStatusChanged();
    return true;
}

bool ServiceManager::startSsh(bool dontShowToast) {
    exec("sshd_sevice start", kExecNormalMs);
    if (!dontShowToast) {
        showToast("SSH服务已启用");
    }
    emit sshStatusChanged();
    return true;
}

bool ServiceManager::stopSsh(bool dontShowToast) {
    exec("sshd_sevice stop", kExecNormalMs);
    if (!dontShowToast) {
        showToast("SSH服务已停用");
    }
    emit sshStatusChanged();
    return true;
}

bool ServiceManager::getAdbAutoRun() const { return mAdbAutoRun; }

bool ServiceManager::getSshAutoRun() const { return mSshAutoRun; }

bool ServiceManager::getSkipAdbVerification() const { return mSkipAdbVerification; }

void ServiceManager::setSkipAdbVerification(bool val) {
    if (mSkipAdbVerification != val) {
        mSkipAdbVerification          = val;
        mCfg["adb_skip_verification"] = val;
        if (val) {
            _passAdbVerification();
        }
        WRITE_CFG;
        emit skipAdbVerificationChanged();
    }
}

void ServiceManager::setAdbAutoRun(bool val) {
    if (mAdbAutoRun != val) {
        mAdbAutoRun         = val;
        mCfg["adb_autorun"] = val;
        WRITE_CFG;
        emit adbAutoRunChanged();
    }
}

void ServiceManager::setSshAutoRun(bool val) {
    if (mSshAutoRun != val) {
        mSshAutoRun         = val;
        mCfg["ssh_autorun"] = val;
        WRITE_CFG;
        emit sshAutoRunChanged();
    }
}

bool ServiceManager::setSshRootPasswd(const QString& val) {
    constexpr const char* kShadowPath    = "/etc/shadow";
    constexpr const char* kShadowBakPath = "/etc/shadow.penmods.bak";
    constexpr const char* kShadowTmpPath = "/etc/.shadow.penmods.tmp";

    if (val.isEmpty()) {
        // 空口令会让 sshd 直接拒登（OpenSSH 的 PermitEmptyPasswords 默认 no），
        // 用户看到"重设成功"却被锁在门外 —— 必须先挡住。
        showToast("密码不能为空", "#E9900C");
        return false;
    }

    // ① 先在内存里把新内容算出来。这一段只读 /etc/shadow，**不需要 rootfs 可写** ——
    //    可写窗口只包住真正的落盘，越短越好（同 SD-02 的原则）。
    QString updated;
    bool    isModified = false;
    {
        QFile shadow(kShadowPath);
        if (!shadow.open(QIODevice::ReadOnly)) {
            showToast("无法读取口令文件", "#E9900C");
            return false;
        }
        while (!shadow.atEnd()) {
            const auto line = QString(shadow.readLine());
            // 注意：**不能**写 `const auto data` —— 下面要把新散列写回 `data[1]`，
            // 而 const QStringList 的 operator[] 返回 const QString&，赋值编不过。
            auto data = line.split(':');
            if (data.length() < 2 || data[0] != "root" || isModified) {
                updated.append(line);
                continue;
            }

            const std::string salt = _randomSalt(16);
            if (salt.empty()) {
                // 拿不到 CSPRNG 就放弃，**不能**退回 QRandomGenerator 顶上：那等于 salt 没随机。
                spdlog::error("Failed to read random bytes from /dev/urandom, refuse to reset root password.");
                showToast("无法生成随机盐", "#E9900C");
                return false;
            }
            // $6$ = SHA-512-crypt。真机实测本机 libxcrypt 4.4 支持 $1$ / $5$ / $6$ /
            // 不支持 $y$；原实现用的 $1$（MD5-crypt）在现代 GPU 上是每哈希亚毫秒级的
            // 暴力破解目标，而这个账户是 SSH 的 root（EX-19）。
            const QByteArray setting = QString("$6$%1$").arg(QString::fromStdString(salt)).toUtf8();
            // 口令按 UTF-8 交给 crypt：SSH 客户端送上来的就是 UTF-8 字节，换成别的编码
            // 会让"非 ASCII 口令"在本地和 sshd 两侧算出不同的散列，用户永远登不上。
            const QByteArray password = val.toUtf8();
            const char*      crypted  = crypt(password.constData(), setting.constData());
            if (crypted == nullptr || crypted[0] == '\0' || crypted[0] == '*') {
                spdlog::error("crypt() failed for the new root password, refuse to touch /etc/shadow.");
                showToast("无法加密密码", "#E9900C");
                return false;
            }
            data[1] = QString::fromUtf8(crypted);
            updated.append(data.join(':'));
            isModified = true;
        }
    }
    if (!isModified) {
        showToast("Root账户找不到", "#E9900C");
        return false;
    }

    // ② 落盘。这一段必须在 rootfs 可写时做。
    //
    //    /etc/shadow 是这台机器上唯一的口令数据库。旧写法用 `WriteOnly | Truncate` **就地
    //    重写**：open 成功的那一刻文件已经被清零，之后任何中断（掉电 / OOM kill / 写失败 /
    //    磁盘满）都会留下空的或截断的 /etc/shadow —— root 再也登不上、SSH 全废，而且当时
    //    没有任何备份。现在改成同目录 tmp + fsync + rename（与 Config::_save() 同一套做法），
    //    目标文件要么是完整的旧内容、要么是完整的新内容，不存在中间态（EX-18）。
    //
    //    而且出厂时 / 是 ro（真机实测 `/dev/root on / type ext4 (ro,...)`），旧写法根本没
    //    处理这一点 —— 它的 `WriteOnly|Truncate` 打开必然 EROFS 失败。也就是说：
    //    这个功能在真机上**从来就没成功过**（EX-18 后半）。
    util::RootFileSystemWritableGuard guard;
    if (!guard.ok()) {
        spdlog::error("Failed to remount / writable, abort resetting root password.");
        showToast("无法写入只读系统分区", "#E9900C");
        return false;
    }

    // 落盘前先留一份出厂备份（见 _ensureShadowBackup 的说明）。
    // 失败不阻断主流程：备份是加分项，口令本身已经能改成功。
    const bool backupOk = _ensureShadowBackup(kShadowPath, kShadowBakPath);

    struct stat st{};
    mode_t      mode = 0600;
    if (::stat(kShadowPath, &st) == 0) {
        mode = st.st_mode & 07777; // 原文件是 0600 root:root，照搬，别让 rename 把它冲掉
    }

    const QByteArray updatedBytes = updated.toUtf8();
    if (!_replaceFileAtomically(kShadowPath, kShadowTmpPath, updatedBytes.constData(),
                                static_cast<size_t>(updatedBytes.size()), mode)) {
        spdlog::error("Failed to atomically replace {}, the original file is untouched.", kShadowPath);
        showToast("写入口令文件失败", "#E9900C");
        return false;
    }
    if (!backupOk) {
        spdlog::warn("Root password updated, but the rescue backup {} could not be written.", kShadowBakPath);
    }
    showToast("密码重设成功");
    return true;
}

void ServiceManager::_passAdbVerification() { exec("touch /tmp/.adb_auth_verified", kExecQuickMs); }

} // namespace mod
