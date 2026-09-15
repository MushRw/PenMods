// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "mod/Config.h"

#include "common/service/Logger.h"

#include <QAbstractListModel>
#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QSocketNotifier>
#include <QTimer>

namespace mod::filemanager {

class FileManager : public QAbstractListModel, public Singleton<FileManager>, private Logger {
    Q_OBJECT

    Q_PROPERTY(QString currentTitle READ getCurrentTitle NOTIFY currentTitleChanged);
    Q_PROPERTY(int order READ getOrder WRITE setOrder NOTIFY orderChanged);
    Q_PROPERTY(bool orderReversed READ getOrderReversed WRITE setOrderReversed NOTIFY orderReversedChanged);
    Q_PROPERTY(bool hasMore READ isHasMore NOTIFY hasMoreChanged);

    // MusicPlayer
    Q_PROPERTY(bool hidePairedLyrics READ getHidePairedLyrics WRITE setHidePairedLyrics NOTIFY hidePairedLyricsChanged);

    // File visibility
    Q_PROPERTY(bool showHiddenFiles READ getShowHiddenFiles WRITE setShowHiddenFiles NOTIFY showHiddenFilesChanged);

    // U 盘（厂商自带 usbmount 会把它挂到 /media/usbN，这里只做"发现 + 跳转"，不自己挂载）
    Q_PROPERTY(bool usbDiskPresent READ isUsbDiskPresent NOTIFY usbDiskChanged);
    Q_PROPERTY(QString usbDiskPath READ getUsbDiskPath NOTIFY usbDiskChanged);

public:
    [[nodiscard]] int rowCount(const QModelIndex& parent) const override;

    [[nodiscard]] QVariant data(const QModelIndex& index, int role) const override;

    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

    // The listener of QFileSystemWatcher,
    // Used to watch currentDir and currentPlayingDir.
    void onDirectoryChanged(const QString& path);

    [[nodiscard]] QDir const& getCurrentPath() const;

    Q_INVOKABLE QString getCurrentPathString() const;

    Q_INVOKABLE bool changeDir(const QString& dir);

    Q_INVOKABLE [[nodiscard]] bool canCdUp() const;

    Q_INVOKABLE void loadMore();

    void loadMore(int amount);

    // reset and load to current position.
    Q_INVOKABLE void reload();

    Q_INVOKABLE void reset();

    Q_INVOKABLE void remove(const QString& fileName);

    Q_INVOKABLE void rename(const QString& fileName, const QString& newFileName);

    [[nodiscard]] bool shouldHiddenAll() const;

    void negateHiddenAll();

    void markSuspendDirChangedNotifier();

    Q_INVOKABLE bool shouldNotifyDirChanged() { return mShouldNotifyDirChanged; };

    void setMtpOnoff(bool);

    [[nodiscard]] int getOrder() const;

    void setOrder(int);

    [[nodiscard]] bool getOrderReversed() const;

    void setOrderReversed(bool);

    [[nodiscard]] QString getCurrentTitle() const;

    [[nodiscard]] bool isHasMore() const;

    void forEachLoadedEntities(const std::function<void(std::shared_ptr<QFileInfo>)>& callback);

    // MusicPlayer

    [[nodiscard]] bool getHidePairedLyrics() const;

    void setHidePairedLyrics(bool);
    
    [[nodiscard]] bool getShowHiddenFiles() const;

    void setShowHiddenFiles(bool);

    // U 盘：只做"发现 + 跳转"，挂载/卸载由厂商的 usbmount 负责
    [[nodiscard]] bool    isUsbDiskPresent() const { return !mUsbDiskPath.isEmpty(); }
    [[nodiscard]] QString getUsbDiskPath() const { return mUsbDiskPath; }
    Q_INVOKABLE bool      openUsbDisk();

    Q_INVOKABLE void playFromView(const QString& fileName);

    Q_INVOKABLE void executeFile(const QString& fileName);

    // 后缀表查询：QML 侧打开文件时用。以前 QML 自己维护一份 fileHandlers，
    // 加上 C++ 的图标表、音频白名单，"支持哪些后缀"有三份清单，已经漂移过。
    Q_INVOKABLE QString handlerFor(const QString& extension) const;

    // 打印后缀表：全部支持的后缀 + 打开方式 + 图标，一行一个（构造时也写进日志）。
    Q_INVOKABLE QString extensionTableText() const;

signals:

    void currentTitleChanged();

    void orderChanged();

    void orderReversedChanged();

    void directoryChanged();

    void hasMoreChanged();

    void exception(const QString& msg);

    // MusicPlayer

    void hidePairedLyricsChanged();
    
    void showHiddenFilesChanged();

    // U 盘挂载状态变化（插入/拔出）
    void usbDiskChanged();

private:
    friend Singleton<FileManager>;
    explicit FileManager();

    // FileManager

    enum class UserRoles { FileName = Qt::UserRole + 1, IsDirectory, SizeString, ExtensionName, ExtensionIcon, IsExecutable, IsSymLink };

    // 单一后缀表：图标名 + 打开方式。getExtIcon / refreshPlayList / QML 打开分发
    // 全部从这一处派生，避免"三份清单各自漂移"——历史上 wav/ogg/aac 在音频白名单里
    // 却不在图标表里，列表里就是一片空白图标。
    struct ExtensionEntry {
        const char* icon;    // qrc:/images/format/suffix-<icon>.png
        const char* handler; // play / text / video / image
    };
    static const QHash<QString, ExtensionEntry>& extensionTable();

    // Natural language comparison function for semantic sorting
    static bool naturalCompare(const QString &a, const QString &b);

    std::string mClassName{"fm"};
    json        mCfg;

    const QString mRoot{"/userdisk/Music"};

    // Inotify variables
    // 走主线程的 QSocketNotifier（不要单开线程 select 轮询）：既能同时监听多个
    // 目录，也不会出现"批量事件 → 上千次 queued 调用"和退出时 wait() 死锁。
    int                             mInotifyFd{-1};
    QHash<int, QString>             mInotifyWatches; // wd -> 目录
    QSocketNotifier*                mInotifyNotifier{nullptr};
    QTimer*                         mDirChangedTimer{nullptr}; // 事件合并/去抖
    QTimer*                         mNotifySuppressTimer{nullptr};
    std::atomic<bool>  mShouldNotifyDirChanged{true};

    int  mOrder;
    bool mOrderReversed;

    QDir                                    mCurrentPath;
    std::vector<std::shared_ptr<QFileInfo>> mEntities;
    int                                     mProxyCount{};

    // 路径历史栈，用于跟踪包括软链接在内的路径变化
    std::vector<QString>                    mPathHistory;

    void _initCurrentDir();

    // Inotify functions
    void setupInotify();
    void cleanupInotify();

    // U 盘：从 /proc/mounts 里找 /media/usbN 的挂载点
    void    refreshUsbDisk();
    QString mUsbDiskPath;
    QTimer* mUsbDiskTimer{nullptr};
    void onInotifyReadyRead();
    void dispatchDirChanged();
    void addInotifyWatch(const QString& path);

    // MusicPlayer

    bool mHidePairedLyrics;

    bool mShowHiddenFiles;

    QDir mCurrentPlayingPath;

    void refreshPlayList();
}; // namespace mod::filemanager
} // namespace mod::filemanager
