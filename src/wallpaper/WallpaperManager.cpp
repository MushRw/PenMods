// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "wallpaper/WallpaperManager.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "common/service/Logger.h"
#include "helper/AntiEmbs.h"
#include "mod/Config.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QQmlContext>
#include <QQuickView>
#include <QRandomGenerator>

namespace mod {

WallpaperManager::WallpaperManager(QObject* parent) : QObject(parent) {
    mCycleTimer = new QTimer(this);
    mCycleTimer->setSingleShot(false);
    connect(mCycleTimer, &QTimer::timeout, this, &WallpaperManager::onCycleTimerTick);

    loadConfig();

    connect(&AntiEmbs::getInstance(), &AntiEmbs::activeChanged, this, &WallpaperManager::updateAvailability);
    updateAvailability();

    // 如果循环模式已启用，扫描文件夹（定时器要等事件循环起来再启动：构造函数
    // 是 dlopen 阶段，此时 start() 会静默失败，循环壁纸就不生效了）。
    // 合并上游：AntiEmbs 激活期间不启动壁纸循环。
    if (mWallpaperMode == 2 && !mWallpaperFolder.isEmpty() && !AntiEmbs::getInstance().isActive()) {
        scanWallpaperFolder();
    }

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView&, QQmlContext*) {
        if (mWallpaperMode == 2 && mCachedImages.size() > 1) {
            startCycleTimer();
        }
    });
}

int WallpaperManager::getWallpaperMode() const { return AntiEmbs::getInstance().isActive() ? 0 : mWallpaperMode; }

void WallpaperManager::setWallpaperMode(int mode) {
    if (AntiEmbs::getInstance().isActive()) {
        return;
    }
    if (mWallpaperMode != mode) {
        mWallpaperMode = mode;
        saveConfig();

        if (mode == 0) {
            // 无壁纸模式：清空当前壁纸
            stopCycleTimer();
            mCurrentWallpaper = "";
            emit currentWallpaperChanged();
        } else if (mode == 1) {
            // 单张自定义
            stopCycleTimer();
            if (!mCustomImagePath.isEmpty()) {
                applyWallpaper(mCustomImagePath);
            }
        } else if (mode == 2) {
            // 随机循环
            scanWallpaperFolder();
            startCycleTimer();
            nextWallpaper();
        }

        emit wallpaperModeChanged();
    }
}

QString WallpaperManager::getCustomImagePath() const { return mCustomImagePath; }

void WallpaperManager::setCustomImagePath(const QString& path) {
    if (AntiEmbs::getInstance().isActive()) {
        return;
    }
    if (mCustomImagePath != path) {
        mCustomImagePath = path;
        saveConfig();
        emit customImagePathChanged();

        if (mWallpaperMode == 1 && !path.isEmpty()) {
            applyWallpaper(path);
        }
    }
}

QString WallpaperManager::getWallpaperFolder() const { return mWallpaperFolder; }

void WallpaperManager::setWallpaperFolder(const QString& path) {
    if (AntiEmbs::getInstance().isActive()) {
        return;
    }
    if (mWallpaperFolder != path) {
        mWallpaperFolder = path;
        saveConfig();
        emit wallpaperFolderChanged();

        // 如果是循环模式，重新扫描并应用
        if (mWallpaperMode == 2) {
            scanWallpaperFolder();
            // AP-03：这句原来漏了。必现路径是"先切到随机循环（此时文件夹为空 →
            // startCycleTimer() 因 mCachedImages.size() <= 1 没起来）→ 再选有图的
            // 文件夹" —— 于是定时器再也没人启动，循环永远停在第一张，只能重启主程序。
            // 与 setWallpaperMode() 的 mode==2 分支保持同一个顺序（扫描 → 起定时 → 换一张）。
            startCycleTimer();
            nextWallpaper();
        }
    }
}

int WallpaperManager::getCycleInterval() const { return mCycleInterval; }

void WallpaperManager::setCycleInterval(int seconds) {
    if (AntiEmbs::getInstance().isActive()) {
        return;
    }
    if (mCycleInterval != seconds && seconds > 0) {
        mCycleInterval = seconds;
        saveConfig();
        emit cycleIntervalChanged();

        if (mWallpaperMode == 2) {
            startCycleTimer();
        }
    }
}

QString WallpaperManager::getCurrentWallpaper() const { return mCurrentWallpaper; }

QStringList WallpaperManager::scanFolder(const QString& folderPath) {
    QStringList result;
    QDir dir(folderPath);
    if (!dir.exists()) {
        return result;
    }

    static const QStringList imageFilters = {"*.png", "*.jpg", "*.jpeg", "*.bmp"};
    QDirIterator it(folderPath, imageFilters, QDir::Files, QDirIterator::NoIteratorFlags);
    while (it.hasNext()) {
        it.next();
        result.append(it.filePath());
    }

    return result;
}

QStringList WallpaperManager::scanWallpaperFolder() {
    mCachedImages.clear();
    mCurrentIndex = -1;

    if (mWallpaperFolder.isEmpty()) {
        emit wallpaperFolderUpdated(mCachedImages);
        return mCachedImages;
    }

    mCachedImages = scanFolder(mWallpaperFolder);
    emit wallpaperFolderUpdated(mCachedImages);
    return mCachedImages;
}

void WallpaperManager::setWallpaper(const QString& path) {
    if (path.isEmpty() || AntiEmbs::getInstance().isActive()) return;

    applyWallpaper(path);

    // 如果是单张模式，更新配置
    if (mWallpaperMode == 1) {
        mCustomImagePath = path;
        saveConfig();
        emit customImagePathChanged();
    }
}

void WallpaperManager::nextWallpaper() {
    if (AntiEmbs::getInstance().isActive() || mCachedImages.isEmpty()) {
        return;
    }

    // 随机选择
    mCurrentIndex = QRandomGenerator::global()->bounded(static_cast<int>(mCachedImages.size()));
    applyWallpaper(mCachedImages.at(mCurrentIndex));
}

void WallpaperManager::onCycleTimerTick() {
    nextWallpaper();
}

void WallpaperManager::saveConfig() {
    auto& config = Config::getInstance();
    config.write("wallpaper", {
        {"mode", mWallpaperMode},
        {"custom_image_path", mCustomImagePath.toStdString()},
        {"wallpaper_folder", mWallpaperFolder.toStdString()},
        {"cycle_interval", mCycleInterval},
        {"last_wallpaper", mCurrentWallpaper.toStdString()}
    });
}

void WallpaperManager::loadConfig() {
    auto cfg = Config::getInstance().read("wallpaper");
    if (cfg.is_null()) return;

    mWallpaperMode   = cfg.value("mode", 0);
    mCustomImagePath = QString::fromStdString(cfg.value("custom_image_path", ""));
    mWallpaperFolder = QString::fromStdString(cfg.value("wallpaper_folder", ""));
    mCycleInterval   = cfg.value("cycle_interval", 300);
    auto lastWall    = QString::fromStdString(cfg.value("last_wallpaper", ""));

    // 应用保存的壁纸（会触发信号通知 QML）
    if (mWallpaperMode == 1 && !mCustomImagePath.isEmpty()) {
        applyWallpaper(mCustomImagePath);
    } else if (mWallpaperMode == 2 && !mWallpaperFolder.isEmpty()) {
        // 循环模式：扫描文件夹并用最后一张壁纸
        scanWallpaperFolder();
        if (!lastWall.isEmpty() && mCachedImages.contains(lastWall)) {
            applyWallpaper(lastWall);
        } else if (!mCachedImages.isEmpty()) {
            nextWallpaper();
        }
        startCycleTimer();
    } else if (mWallpaperMode == 0) {
        // 无壁纸模式：确保发出信号让 QML 清空背景
        mCurrentWallpaper = "";
        emit currentWallpaperChanged();
    }
}

void WallpaperManager::startCycleTimer() {
    if (mCycleTimer && mCycleInterval > 0 && mCachedImages.size() > 1) {
        mCycleTimer->start(mCycleInterval * 1000);
    }
}

void WallpaperManager::stopCycleTimer() {
    if (mCycleTimer) {
        mCycleTimer->stop();
    }
}

void WallpaperManager::applyWallpaper(const QString& path) {
    if (mCurrentWallpaper != path) {
        mCurrentWallpaper = path;
        emit currentWallpaperChanged();
    }
}

void WallpaperManager::updateAvailability() {
    if (AntiEmbs::getInstance().isActive()) {
        stopCycleTimer();
        if (!mCurrentWallpaper.isEmpty()) {
            mCurrentWallpaper.clear();
            emit currentWallpaperChanged();
        }
        emit wallpaperModeChanged();
        return;
    }

    emit wallpaperModeChanged();
    if (mWallpaperMode == 1 && !mCustomImagePath.isEmpty()) {
        applyWallpaper(mCustomImagePath);
    } else if (mWallpaperMode == 2 && !mWallpaperFolder.isEmpty()) {
        scanWallpaperFolder();
        startCycleTimer();
        nextWallpaper();
    }
}

} // namespace mod
