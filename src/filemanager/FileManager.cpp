// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "filemanager/FileManager.h"
#include "filemanager/player/MusicPlayer.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "common/service/Logger.h"

#include "mod/Mod.h"

#include "tweaker/ColumnDBLimiter.h"

#include <QDateTime>
#include <QFile>
#include <QHash>
#include <QProcess>
#include <QQmlContext>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <QThread>
#include <QMutexLocker>

#include <sys/inotify.h>
#include <unistd.h>
#include <errno.h>

#include <algorithm>
#include <cstring>

namespace mod::filemanager {

static const char* HIDDEN_FLAG = ".HIDDEN_DIR";
static size_t      MAX_FILES   = 65535;

// Natural language sort flag (using a value that doesn't conflict with QDir constants)
static const int NATURAL_SORT = 0x10000; // 65536 - using a value far outside standard QDir sort flags range

FileManager::FileManager() : QAbstractListModel(), Logger("FileManager") {

    mCfg = Config::getInstance().read(mClassName);

    mOrder            = mCfg["order"]["basic"];
    mOrderReversed    = mCfg["order"]["reversed"];
    mHidePairedLyrics = mCfg["hide_paired_lyrics"];
    mShowHiddenFiles  = mCfg["show_hidden_files"];

    // 初始化路径历史，设置初始路径为根目录
    mPathHistory.push_back(mRoot);

    // 打印后缀表：改后缀/新增格式时，日志里一眼能看到当前支持什么
    info("支持的文件后缀表:\n{}", extensionTableText().toStdString());

    setupInotify();
    connect(&Event::getInstance(), &Event::uiCompleted, [this]() {
        if (shouldHiddenAll()) {
            QTimer::singleShot(15000, this, [&]() { setMtpOnoff(false); });
        }
    });
    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("fileManager", this);
    });
}

int FileManager::rowCount(const QModelIndex& parent) const { return mProxyCount; };

QVariant FileManager::data(const QModelIndex& index, int role) const {
    if (!index.isValid()) {
        return {};
    }

    const size_t row = static_cast<size_t>(index.row());
    if (row >= static_cast<size_t>(mProxyCount)) {
        return {};
    }

    auto& entity = mEntities.at(row);

    auto getSizeString = [&]() -> QString {
        auto size = entity->size();
        if (size <= 0) {
            return "0B";
        }
        QList<QString> units = {"B", "KB", "MB", "GB"};
        for (int i = 1; i < units.size() + 1; i++) {
            auto step = pow(1024, i);
            if ((double)size <= step) {
                return QString::number((double)size / step * 1024.0, 'f', 0) + units.at(i - 1);
            }
        } // dict pen's largest storage size is 32GB, lol.
        const_cast<FileManager*>(this)->error("Abnormal file size({}) detected!", size);
        return "-1B";
    };

    auto getExtIcon = [&]() -> QString {
        if (entity->isSymLink()) {
            return "qrc:/images/format/symlink.png";
        }

        if (entity->isDir()) {
            return "qrc:/images/folder-empty.png";
        }
        // 图标同样从单一后缀表派生，不再自己维护一份 switch
        const auto it = extensionTable().constFind(entity->suffix().toLower());
        if (it == extensionTable().constEnd()) {
            return "qrc:/images/file-empty.png";
        }
        return QString("qrc:/images/format/suffix-%1.png").arg(it->icon);
    };

    switch ((UserRoles)role) {
    case UserRoles::FileName:
        return entity->fileName();
    case UserRoles::IsDirectory:
        return entity->isDir();
    case UserRoles::SizeString:
        return getSizeString();
    case UserRoles::ExtensionName:
        return entity->suffix().toLower();
    case UserRoles::ExtensionIcon:
        return getExtIcon();
    case UserRoles::IsExecutable:
        return entity->isExecutable();
    case UserRoles::IsSymLink:
        return entity->isSymLink();
    default:
        return {};
    }
};

QHash<int, QByteArray> FileManager::roleNames() const {
    return QHash<int, QByteArray>{
        {(int)UserRoles::FileName,      "fileName"    },
        {(int)UserRoles::IsDirectory,   "isDir"       },
        {(int)UserRoles::SizeString,    "sizeStr"     },
        {(int)UserRoles::ExtensionName, "extName"     },
        {(int)UserRoles::ExtensionIcon, "extIcon"     },
        {(int)UserRoles::IsExecutable,  "isExecutable"},
        {(int)UserRoles::IsSymLink,     "isSymLink"}
    };
};

void FileManager::onDirectoryChanged(const QString& path) {
    debug("dir-changed: {}", path.toStdString());
    auto url = QUrl(path);
    debug("url.path() {}", url.path().toStdString());
    debug("cur.path() {}", mCurrentPath.path().toStdString());
    if (url.path() == mCurrentPath.path()) {
        emit directoryChanged();
    }
    if (path == mCurrentPlayingPath.path()) {
        refreshPlayList();
    }
}

QDir const& FileManager::getCurrentPath() const { return mCurrentPath; }

QString FileManager::getCurrentPathString() const { return mCurrentPath.path(); }

bool FileManager::changeDir(const QString& dir) {
    if (dir.isEmpty()) {
        // 返回根目录
        mPathHistory.clear();
        mPathHistory.push_back(mRoot);
        mCurrentPath.setPath(mRoot);
    } else if (dir == "..") {
        // 返回上级目录
        if (mPathHistory.size() > 1) {
            mPathHistory.pop_back(); // 弹出当前路径
            QString prevPath = mPathHistory.back(); // 获取上一级路径
            mCurrentPath.setPath(prevPath);
        } else {
            // 如果已经是根目录或路径历史为空，不做任何操作
            return false;
        }
    } else {
        debug("Move to dir -> {}", dir.toStdString());

        // 检查是否是软链接目录
        QString targetPath = mCurrentPath.absoluteFilePath(dir);
        QFileInfo fileInfo(targetPath);

        QString nextPath;
        if (fileInfo.isSymLink()) {
            // 如果是软链接，获取其指向的实际路径
            QString linkTarget = fileInfo.symLinkTarget();
            if (!linkTarget.isEmpty() && QDir(linkTarget).exists()) {
                nextPath = linkTarget;
            } else {
                // 如果软链接无效，尝试直接使用原路径
                nextPath = mCurrentPath.absoluteFilePath(dir);
            }
        } else {
            nextPath = mCurrentPath.absoluteFilePath(dir);
        }

        // 验证路径是否存在
        if (!QDir(nextPath).exists()) {
            return false;
        }

        // 更新路径历史
        mCurrentPath.setPath(nextPath);
        mPathHistory.push_back(nextPath);
    }

    // 更新 inotify 监视（现在全在主线程，不需要锁）
    addInotifyWatch(mCurrentPath.path());

    emit currentTitleChanged();
    reset();
    _initCurrentDir();
    loadMore();
    return true;
}

bool FileManager::canCdUp() const {
    // 检查路径历史栈，如果有多个路径则可以返回上级
    return mPathHistory.size() > 1;
}

void FileManager::loadMore() { loadMore(1500); }

void FileManager::loadMore(int amount) {
    // Do not use 'isHasMore()' here!
    auto finalCount = std::min(mProxyCount + amount, (int)mEntities.size());
    if (finalCount <= mProxyCount) {
        // 没有更多数据时不要再 beginInsertRows(proxyCount, proxyCount - 1)：那是非法区间。
        return;
    }
    beginInsertRows(QModelIndex(), mProxyCount, finalCount - 1);
    mProxyCount = finalCount; // safe: limited by MAX_FILES.
    endInsertRows();
    emit hasMoreChanged();
}

void FileManager::reload() {
    // 重新加载当前目录，但不改变路径历史
    reset();
    _initCurrentDir();
    loadMore();
}

void FileManager::reset() {
    beginResetModel();
    mEntities.clear();
    mProxyCount = 0;
    endResetModel();
    emit hasMoreChanged();
}

void FileManager::remove(const QString& fileName) {
    if (!judgeIsLegalFileName(fileName)) {
        return;
    }
    if (!mCurrentPath.exists(fileName)) {
        return;
    }
    int idx = 0;
    for (const auto& i : mEntities) {
        if (i->fileName() != fileName) {
            idx++;
            continue;
        }

        QString filePath = mCurrentPath.absoluteFilePath(fileName);
        QFileInfo fileInfo(filePath);

        if (fileInfo.isSymLink()) {
            // 如果是软链接，只需删除链接本身，而不删除目标
            mCurrentPath.remove(fileName);
        } else if (i->isDir()) {
            // 不要走 shell：路径里的引号/$(...) 会变成命令注入。
            QDir(filePath).removeRecursively();
        } else {
            mCurrentPath.remove(fileName);
        }
        if (idx < mProxyCount) {
            beginRemoveRows(QModelIndex(), idx, idx);
            mEntities.erase(mEntities.begin() + idx);
            mProxyCount--;
            endRemoveRows();
        } else {
            mEntities.erase(mEntities.begin() + idx);
        }
        markSuspendDirChangedNotifier();
        emit hasMoreChanged();
        break;
    }
}

void FileManager::rename(const QString& fileName, const QString& newFileName) {
    if (!judgeIsLegalFileName(newFileName)) {
        showToast("文件名不能包含特殊字符", "#E9900C");
        return;
    }
    auto newFilePath = mCurrentPath.absoluteFilePath(newFileName);
    markSuspendDirChangedNotifier();
    if (!mCurrentPath.rename(fileName, newFileName)) {
        showToast("修改失败", "#E9900C");
        return;
    }
    auto idx = 0;
    for (auto& i : mEntities) {
        if (i->fileName() == fileName) {
            i->setFile(newFilePath);
            auto midx = index(idx);
            emit dataChanged(midx, midx);
            break;
        }
        idx++;
    }
}

bool FileManager::shouldHiddenAll() const { return QFile(QString("%1/%2").arg(mRoot, HIDDEN_FLAG)).exists(); }

void FileManager::negateHiddenAll() {
    QFile file(QString("%1/%2").arg(mRoot, HIDDEN_FLAG));
    if (file.exists()) {
        file.remove();
        setMtpOnoff(true);
    } else {
        file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate);
        file.write("This directory has been hidden.");
        file.close();
        setMtpOnoff(false);
    }
}

void FileManager::markSuspendDirChangedNotifier() {
    mShouldNotifyDirChanged = false;
    // 复用一个单发定时器：原来每次都新建一个 5s 单发定时器，先到期的那个
    // 会提前把抑制解除。重复调用 start() 本来就是顺延。
    if (mNotifySuppressTimer == nullptr) {
        mNotifySuppressTimer = new QTimer(this);
        mNotifySuppressTimer->setSingleShot(true);
        connect(mNotifySuppressTimer, &QTimer::timeout, this, [this]() { mShouldNotifyDirChanged = true; });
    }
    mNotifySuppressTimer->start(5000);
}

void FileManager::setMtpOnoff(bool onoff) {
    if (onoff && shouldHiddenAll()) {
        return;
    }
    if (onoff) {
        exec("grep usb_mtp_en /tmp/.usb_config || echo usb_mtp_en >> /tmp/.usb_config");
    } else {
        exec("sed -i '/usb_mtp_en/d' /tmp/.usb_config");
    }
    exec("/etc/init.d/S98usbdevice restart");
}

int FileManager::getOrder() const { return mOrder; }

bool FileManager::getOrderReversed() const { return mOrderReversed; }

void FileManager::setOrder(int order) {
    if (mOrder != order) {
        mOrder                 = order;
        mCfg["order"]["basic"] = order;
        WRITE_CFG;
        emit orderChanged();
    }
}

void FileManager::setOrderReversed(bool val) {
    if (mOrderReversed != val) {
        mOrderReversed            = val;
        mCfg["order"]["reversed"] = val;
        WRITE_CFG;
        emit orderReversedChanged();
    }
}

QString FileManager::getCurrentTitle() const {
    // 使用路径历史来构建标题，这样可以正确反映用户导航路径
    if (mPathHistory.empty()) {
        return "(根目录)";
    }

    // 获取当前路径相对于根目录的部分
    auto    path = mCurrentPath.path().remove(0, mRoot.size());
    QString ret  = "(根目录)";
    auto    list = path.split("/", Qt::SkipEmptyParts);
    for (auto i = 0; i < list.size(); i++) {
        auto part = " ﹥ " + list[i];
        if (i == list.size() - 1) { // final
            part = "<font color=\"white\">" + part + "</font>";
        }
        ret += part;
    }
    return ret;
}

bool FileManager::isHasMore() const {
    return !mEntities.empty() && (int)mEntities.size() > mProxyCount; // safe.
}

void FileManager::_initCurrentDir() {
    // 1. 安全检查与重置
    if (Mod::getInstance().isTrustedDevice() && shouldHiddenAll()) {
        emit error("空文件夹");
        reset();
        return;
    }

    // 确保清空旧数据，防止重复追加
    mEntities.clear();

    // 2. 准备标志位和排序参数
    auto order = getOrder();
    auto flags = QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot;
    if (getShowHiddenFiles()) {
        flags |= QDir::Hidden;
    }

    bool useNaturalSort = (order & NATURAL_SORT) != 0;
    bool isReversed     = getOrderReversed() || (order & QDir::Reversed);

    // 如果不使用自然排序，直接让 QDir 处理排序，效率更高
    QDir::SortFlags sortFlags = QDir::NoSort;
    if (!useNaturalSort) {
        sortFlags = static_cast<QDir::SortFlags>(order | QDir::DirsFirst | QDir::IgnoreCase);
        if (isReversed) {
            sortFlags |= QDir::Reversed;
        }
    }

    // 3. 获取文件列表
    QFileInfoList list = mCurrentPath.entryInfoList(flags, sortFlags);

    // 4. 基础校验
    if (list.empty()) {
        emit error("空文件夹");
        reset();
        return;
    }

    // 防止内存滥用
    if (static_cast<size_t>(list.size()) > MAX_FILES) {
        emit error("该目录下文件太多");
        reset();
        return;
    }

    // 5. 执行自然排序 (如果需要)
    if (useNaturalSort) {
        // 显式提取排序位
        bool sortByTime = (order & QDir::Time);
        bool sortBySize = (order & QDir::Size);

        std::sort(
            list.begin(),
            list.end(),
            [isReversed, sortByTime, sortBySize](const QFileInfo& a, const QFileInfo& b) {
                // 始终将文件夹排在文件前面（不受反向排序影响）
                // 如果 a 是文件夹而 b 不是，a 应该排在前面
                if (a.isDir() && !b.isDir()) {
                    return true;
                }
                // 如果 b 是文件夹而 a 不是，b 应该排在前面
                if (!a.isDir() && b.isDir()) {
                    return false;
                }

                // 如果两者都是软链接或都不是软链接，继续下面的排序逻辑
                // 如果其中一个为软链接，另一个不是，优先显示非软链接
                if (a.isSymLink() && !b.isSymLink()) {
                    return false; // 软链接排在后面
                }
                if (!a.isSymLink() && b.isSymLink()) {
                    return true; // 非软链接排在前面
                }

                // 如果两者都是文件夹或都是文件，继续下面的排序逻辑
                // 内部比较 lambda
                auto compareLogic = [&](const QFileInfo& fa, const QFileInfo& fb) -> bool {
                    QString nameA = fa.fileName();
                    QString nameB = fb.fileName();

                    // 极速路径优化
                    if (!nameA.isEmpty() && !nameB.isEmpty()) {
                        QChar cA = nameA.front();
                        QChar cB = nameB.front();
                        if (!cA.isDigit() && !cB.isDigit() && cA.toLower() != cB.toLower()) {
                            return cA.toLower() < cB.toLower();
                        }
                    }

                    if (nameA == nameB) {
                        if (sortByTime) return fa.lastModified() < fb.lastModified();
                        if (sortBySize) return fa.size() < fb.size();
                        return fa.absoluteFilePath() < fb.absoluteFilePath();
                    }

                    return FileManager::naturalCompare(nameA, nameB);
                };

                // 根据 isReversed 决定顺序
                if (isReversed) {
                    return compareLogic(b, a);
                } else {
                    return compareLogic(a, b);
                }
            }
        );
    }

    // 6. 处理同名歌词文件隐藏（先精确匹配，再模糊匹配）
    QSet<QString> filesToHide;
    if (getHidePairedLyrics()) {
        // 收集所有 .lrc 文件
        QVector<QFileInfo> lrcFiles;
        for (const auto& i : list) {
            if (i.suffix().toLower() == "lrc")
                lrcFiles.append(i);
        }

        const QStringList audioExts = {"mp3", "flac", "m4a", "wav", "ogg", "aac"};
        for (const auto& i : list) {
            const QString ext = i.suffix().toLower();
            if (!audioExts.contains(ext))
                continue;

            const QString baseName = i.completeBaseName();
            double        bestScore  = 0.0;
            QString       bestMatch;

            for (const auto& lrc : lrcFiles) {
                const QString lrcBase = lrc.completeBaseName();
                if (lrcBase == baseName) {
                    bestScore  = 1.0;
                    bestMatch  = lrc.absoluteFilePath();
                    break;
                }
                double score = fuzzyLrcMatch(baseName, lrcBase);
                if (score > bestScore) {
                    bestScore = score;
                    bestMatch = lrc.absoluteFilePath();
                }
            }
            if (bestScore >= 0.35 && !bestMatch.isEmpty()) {
                filesToHide.insert(bestMatch);
            }
        }
    }

    // 7. 填充 mEntities
    mEntities.reserve(list.size());

    for (const auto& i : list) {
        if (!filesToHide.empty() && filesToHide.contains(i.absoluteFilePath())) {
            continue;
        }
        if (!getShowHiddenFiles() && i.fileName().startsWith('.')) {
            continue;
        }
        mEntities.emplace_back(std::make_shared<QFileInfo>(i));
    }
}

void FileManager::forEachLoadedEntities(const std::function<void(std::shared_ptr<QFileInfo>)>& callback) {
    for (const auto& i : mEntities) {
        callback(i);
    }
}

// MusicPlayer

bool FileManager::getHidePairedLyrics() const { return mHidePairedLyrics; }

void FileManager::setHidePairedLyrics(bool val) {
    if (mHidePairedLyrics != val) {
        mHidePairedLyrics          = val;
        mCfg["hide_paired_lyrics"] = val;
        WRITE_CFG;
        emit hidePairedLyricsChanged();
    }
}

bool FileManager::getShowHiddenFiles() const { return mShowHiddenFiles; }

void FileManager::setShowHiddenFiles(bool val) {
    if (mShowHiddenFiles != val) {
        mShowHiddenFiles          = val;
        mCfg["show_hidden_files"] = val;
        WRITE_CFG;
        emit showHiddenFilesChanged();
    }
}

void FileManager::playFromView(const QString& fileName) {
    if (mCurrentPlayingPath != mCurrentPath) {
        refreshPlayList();
        mCurrentPlayingPath = mCurrentPath;

        // 更新 inotify 监视（现在全在主线程，不需要锁）
        addInotifyWatch(mCurrentPlayingPath.path());
    }
    size_t idx   = 0;
    bool   valid = false;
    for (auto& file : MusicPlayer::getInstance().getPlayListRef()) {
        if (file->fileName() == fileName) {
            valid = true;
            break;
        }
        idx++;
    }
    if (valid) MusicPlayer::getInstance().play(idx);
}

void FileManager::refreshPlayList() {
    auto& list = MusicPlayer::getInstance().getPlayListRef();
    list.clear();
    forEachLoadedEntities([&](const std::shared_ptr<QFileInfo>& file) {
        // 音频白名单同样从后缀表派生（以前这里另写一份，和图标表漂移过）
        const auto it = extensionTable().constFind(file->suffix().toLower());
        if (it != extensionTable().constEnd() && strcmp(it->handler, "play") == 0) {
            list.emplace_back(file);
        }
    });
}

// ---------------------------------------------------------------------------
// 后缀表（单一来源）
// ---------------------------------------------------------------------------

const QHash<QString, FileManager::ExtensionEntry>& FileManager::extensionTable() {
    static const QHash<QString, ExtensionEntry> table = {
        // 音频
        {"mp3", {"mp3", "play"}},    {"flac", {"mp3", "play"}},
        {"m4a", {"mp3", "play"}},    {"wav", {"mp3", "play"}},
        {"ogg", {"mp3", "play"}},    {"aac", {"mp3", "play"}},
        // 文本
        {"txt", {"txt", "text"}},    {"lrc", {"txt", "text"}},
        {"md", {"md", "text"}},      {"json", {"json", "text"}},
        {"yml", {"xml", "text"}},    {"yaml", {"xml", "text"}},
        {"xml", {"xml", "text"}},    {"log", {"txt", "text"}},
        // 视频
        {"avi", {"mp4", "video"}},   {"mp4", {"mp4", "video"}},
        {"mov", {"mp4", "video"}},   {"flv", {"mp4", "video"}},
        {"mkv", {"mp4", "video"}},   {"webm", {"mp4", "video"}},
        // 图片
        {"png", {"image", "image"}}, {"jpg", {"image", "image"}},
        {"jpeg", {"image", "image"}},{"gif", {"image", "image"}},
        {"bmp", {"image", "image"}}, {"svg", {"image", "image"}},
        {"ico", {"image", "image"}}, {"webp", {"image", "image"}},
    };
    return table;
}

QString FileManager::handlerFor(const QString& extension) const {
    const auto it = extensionTable().constFind(extension.toLower());
    return it == extensionTable().constEnd() ? QString() : QString::fromUtf8(it->handler);
}

QString FileManager::extensionTableText() const {
    QStringList keys = extensionTable().keys();
    std::sort(keys.begin(), keys.end());
    QString out = QString("共 %1 个后缀（打开方式 / 图标）:").arg(keys.size());
    for (const auto& k : keys) {
        const auto e = extensionTable().value(k);
        out += QString("\n  %1 -> %2 (%3)").arg(k, -6).arg(e.handler, -5).arg(e.icon);
    }
    return out;
}

void FileManager::executeFile(const QString& fileName) {
    QString filePath = mCurrentPath.absoluteFilePath(fileName);
    QFileInfo fileInfo(filePath);

    // 如果是软链接，获取目标文件路径
    if (fileInfo.isSymLink()) {
        QString targetPath = fileInfo.symLinkTarget();
        if (!targetPath.isEmpty()) {
            filePath = targetPath;
        }
    }

    if (!QFileInfo(filePath).isExecutable()) {
        emit exception("文件不可执行");
        return;
    }

    QProcess* process = new QProcess(this);
    // 之前启动成功后从不释放：每次执行文件都泄漏一个 QProcess 对象。
    // 注意 Qt 5.15 的 QProcess::finished 是重载（finished(int) 已废弃），
    // 必须用 qOverload 消歧义，否则 &QProcess::finished 推导不出模板参数。
    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), process, &QObject::deleteLater);
    connect(process, &QProcess::errorOccurred, process, &QObject::deleteLater);
    process->start(filePath);
    if (!process->waitForStarted()) {
        emit exception("启动失败");
        process->deleteLater(); // deleteLater 幂等：errorOccurred 那条路可能已经排过
        return;
    }
}

bool FileManager::naturalCompare(const QString& a, const QString& b) {
    const QChar* itA  = a.unicode();
    const QChar* itB  = b.unicode();
    const QChar* endA = itA + a.length();
    const QChar* endB = itB + b.length();

    while (itA != endA && itB != endB) {
        // 检查当前字符是否都是数字
        if (itA->isDigit() && itB->isDigit()) {
            // 1. 跳过前导零
            const QChar* startA = itA;
            while (itA != endA && *itA == '0') ++itA;

            const QChar* startB = itB;
            while (itB != endB && *itB == '0') ++itB;

            // 2. 计算有效数字部分的长度 (即去掉前导零后的长度)
            const QChar* significantA = itA;
            while (itA != endA && itA->isDigit()) ++itA;
            qint64 lenA = itA - significantA;

            const QChar* significantB = itB;
            while (itB != endB && itB->isDigit()) ++itB;
            qint64 lenB = itB - significantB;

            // 3. 比较逻辑
            // 规则 A: 有效数字越长，数值越大 (例如 100 > 50)
            if (lenA != lenB) {
                return lenA < lenB;
            }

            // 规则 B: 长度相同，逐位比较 (例如 123 < 124)
            // 此时不用担心溢出，因为只是字符比较
            for (qint64 i = 0; i < lenA; ++i) {
                if (significantA[i] != significantB[i]) {
                    return significantA[i] < significantB[i];
                }
            }

            // 规则 C: 数值完全相等 (例如 "01" 和 "1")
            // 此时通常比较前导零的个数，或者认为它们“相等”
            // 为了排序稳定性，通常认为较长的原始字符串（即前导零多的）排在后面或前面
            // 这里采用：原数字串较短的排在前面 (即 1 < 01)
            qint64 originLenA = itA - startA; // 包含前导零的长度
            qint64 originLenB = itB - startB;
            if (originLenA != originLenB) {
                return originLenA < originLenB;
            }

            // 如果连前导零都一样，继续循环比较后面的字符
        } else {
            // 普通字符比较：忽略大小写
            // QChar::toLower() 是内联的且很快
            QChar cA = itA->toLower();
            QChar cB = itB->toLower();

            if (cA != cB) {
                return cA < cB;
            }

            ++itA;
            ++itB;
        }
    }

    // 如果一个字符串结束了，较短的排在前面
    return (itA == endA) && (itB != endB);
}

void FileManager::setupInotify() {
    mInotifyFd = inotify_init1(IN_NONBLOCK);
    if (mInotifyFd < 0) {
        error("Failed to initialize inotify: {}", strerror(errno));
        return;
    }

    // 监听当前路径 + 播放路径：两个都要（旧实现只有一个 watch 槽位，
    // 播放路径一加就把当前目录顶掉了）
    if (!mCurrentPath.path().isEmpty()) {
        addInotifyWatch(mCurrentPath.path());
    }
    if (!mCurrentPlayingPath.path().isEmpty()) {
        addInotifyWatch(mCurrentPlayingPath.path());
    }

    // 事件驱动：fd 可读 → onInotifyReadyRead；再经过 300ms 去抖只发一次信号。
    // 不再单开线程 + select 1s 轮询（原来退出时 quit() 打断不了 select，
    // wait() 会死锁；而且每个事件都往主线程排一次 queued 调用）。
    mInotifyNotifier = new QSocketNotifier(mInotifyFd, QSocketNotifier::Read, this);
    connect(mInotifyNotifier, &QSocketNotifier::activated, this, &FileManager::onInotifyReadyRead);

    mDirChangedTimer = new QTimer(this);
    mDirChangedTimer->setSingleShot(true);
    mDirChangedTimer->setInterval(300);
    connect(mDirChangedTimer, &QTimer::timeout, this, &FileManager::dispatchDirChanged);
}

void FileManager::addInotifyWatch(const QString& path) {
    if (mInotifyFd < 0 || path.isEmpty()) {
        return;
    }

    // 同一个目录不重复添加
    for (auto it = mInotifyWatches.constBegin(); it != mInotifyWatches.constEnd(); ++it) {
        if (it.value() == path) {
            return;
        }
    }

    // 上限 8 个（当前目录 + 播放目录 + 少量历史），超了先撤掉最早的
    constexpr int kMaxWatches = 8;
    while (mInotifyWatches.size() >= kMaxWatches) {
        const int oldest = mInotifyWatches.constBegin().key();
        inotify_rm_watch(mInotifyFd, oldest);
        mInotifyWatches.remove(oldest);
    }

    // 注意：不再监听 IN_MODIFY —— 写文件期间事件会爆量，而我们要的只是
    // "目录内容变了"。增删改名才需要刷新列表。
    const int wd = inotify_add_watch(
        mInotifyFd,
        path.toLocal8Bit().data(),
        IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO
    );
    if (wd < 0) {
        error("Failed to add inotify watch for path {}: {}", path.toStdString(), strerror(errno));
        return;
    }
    mInotifyWatches.insert(wd, path);
    debug("Added inotify watch for path: {}", path.toStdString());
}

void FileManager::onInotifyReadyRead() {
    char buffer[4096];
    bool relevant = false;

    // 非阻塞 fd：一次把积压的事件读干净
    while (true) {
        const ssize_t len = read(mInotifyFd, buffer, sizeof(buffer));
        if (len <= 0) {
            if (len < 0 && errno != EAGAIN && errno != EINTR) {
                error("Read error: {}", strerror(errno));
            }
            break;
        }
        int i = 0;
        while (i < static_cast<int>(len)) {
            auto* event = reinterpret_cast<struct inotify_event*>(&buffer[i]);
            if (event->mask & (IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO)) {
                relevant = true;
            }
            i += static_cast<int>(sizeof(struct inotify_event) + event->len);
        }
    }

    // USB 一次拷入上千个文件也只会触发一次刷新（start() 会顺延已有的计时）
    if (relevant && mDirChangedTimer != nullptr) {
        mDirChangedTimer->start();
    }
}

void FileManager::dispatchDirChanged() {
    emit directoryChanged();

    // 如果当前播放路径发生变化，刷新播放列表
    if (mCurrentPath == mCurrentPlayingPath) {
        refreshPlayList();
    }
}

void FileManager::cleanupInotify() {
    if (mDirChangedTimer != nullptr) {
        mDirChangedTimer->stop();
    }

    if (mInotifyNotifier != nullptr) {
        mInotifyNotifier->setEnabled(false);
        delete mInotifyNotifier;
        mInotifyNotifier = nullptr;
    }

    if (mInotifyFd >= 0) {
        for (auto it = mInotifyWatches.constBegin(); it != mInotifyWatches.constEnd(); ++it) {
            inotify_rm_watch(mInotifyFd, it.key());
        }
        mInotifyWatches.clear();
        close(mInotifyFd);
        mInotifyFd = -1;
    }
}

} // namespace mod::filemanager

PEN_HOOK(void, _ZN13YMediaManager13entryMyImportEv, uint64) {}

PEN_HOOK(void, _ZN13YMediaManager16entryMyImportDirERK7QString, uint64, const QString& a2) {}

PEN_HOOK(void, _ZN13YMediaManager20launchMyImportMediasEv, uint64) {}
