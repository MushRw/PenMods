// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "mod/Mod.h"
#include "mod/PlayerInstaller.h"
#include "helper/AvatarProvider.h"

#include "wallpaper/WallpaperManager.h"

#include "base/YPointer.h"

#include "common/Event.h"
#include "common/Utils.h"
#include "common/util/System.h"

#include "Version.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QProcessEnvironment>
#include <QQmlContext>
#include <QQuickView>

namespace mod {

Mod::Mod() {

    spdlog::info("[Mod] 构造函数开始");
    connect(&Event::getInstance(), &Event::uiCompleted, this, &Mod::onUiCompleted);
    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        mCaptureWindow = &view;
        spdlog::info("[Mod] beforeUiInitialization, window={}", fmt::ptr(&view));
        view.engine()->addImageProvider("penavatar", new AvatarProvider(view.engine()));
        // 定时器必须在事件循环就绪后启动（构造函数阶段 start 会失败）
        if (!mCaptureTimer->isActive()) {
            mCaptureTimer->start();
        }
        // Rime 数据必须在 rime::Backend 初始化之前就位：两者都挂在下游的
        // beforeUiInitialization 上，而 Mod 的实例化顺序在前，所以这里会先跑。
        // 否则全新安装的首启里 librime 会先初始化、schema 还没落地，用户得再
        // 重启一次输入法才能用（实测：部署日志比 Rime 初始化晚 1 秒）。
        ensureRimeInstalled();
        context->setContextProperty("mod", this);
        qmlRegisterUncreatableType<PageIndex>(
            QML_PACKAGE_NAME,
            QML_PACKAGE_VERSION_MAJOR,
            QML_PACKAGE_VERSION_MINOR,
            "PageIndex",
            "Not creatable as it is an enum type."
        );
        
        // 将 WallpaperManager 注册到 QML 上下文
        context->setContextProperty("wallpaperManager", &WallpaperManager::getInstance());
        
        // 发射属性变更信号，确保 QML 能正确获取初始值
        emit versionChanged();
        emit cachedSymCountChanged();
        emit buildInfoChanged();
    });

    // 调试截图：touch /tmp/penmods_screencap 触发，输出 /tmp/penmods_screen.png
    mCaptureTimer = new QTimer(this);
    mCaptureTimer->setInterval(500);
    connect(mCaptureTimer, &QTimer::timeout, this, &Mod::onCaptureTick);
    spdlog::info("[Mod] 构造函数完成, capture timer={}", fmt::ptr(mCaptureTimer));
}

bool Mod::isTrustedDevice() const { return true; }

QString Mod::getVersionStr() const { return VERSION_STRING; }

int Mod::getCachedSymCount() const { return static_cast<int>(SymDB::getInstance().count()); }

QString Mod::getBuildInfoStr() const { return BUILD_INFO_STRING; }

QString Mod::getOtherSlot() const {
    return exec("update_engine --misc=display").find("[0]->priority = 15") != std::string::npos ? "System B"
                                                                                                : "System A";
}

void Mod::changeSlot() { exec("update_engine --misc=other --reboot"); }

void Mod::uninstall() {
    try {
        // 要还原 /oem 下的主程序：出厂 rootfs 是 ro，先确认可写。
        util::setRootFileSystemWritable(true);
        QString appDir = util::getApplicationFileInfo().absolutePath();
        QString mainPath = appDir + "/YoudaoDictPen";
        QString tmpPath  = appDir + "/YoudaoDictPen.uninstall_bak";
        QString bakPath  = appDir + "/YoudaoDictPen.original_bak";
        if (!QFile::exists(bakPath)) {
            bakPath = appDir + "/YoudaoDictPen.bak";
        }
        if (!QFile::exists(bakPath)) throw std::runtime_error("无法还原主程序, 因为备份已丢失");

        // 安全还原：先把当前主程序改名保留，再把备份改回主程序。
        // 任意时刻磁盘上都有可用的主程序文件，避免"先删后改"导致主程序丢失。
        QFile::remove(tmpPath);
        if (QFile::exists(mainPath) && !QFile::rename(mainPath, tmpPath)) {
            throw std::runtime_error("无法备份当前主程序");
        }
        if (!QFile::rename(bakPath, mainPath)) {
            if (QFile::exists(tmpPath)) QFile::rename(tmpPath, mainPath); // 尽力恢复
            throw std::runtime_error("无法还原主程序");
        }
        QFile::remove(tmpPath);

        // 清理 mod 自身文件（尽力而为，失败不阻断卸载）
        QFile::remove(util::getModuleFileInfo().absoluteFilePath()); // libPenMods.so
        QDir("/userdata/PenMods").removeRecursively();               // 资源库/配置/安装包
        QDir("/userdisk/mpv").removeRecursively();                   // 随包播放器
        QFile::remove("/userdisk/VideoPlayer");                      // 播放器软链
        // 注：/userdisk/PenMods（插件）、/userdisk/Music/Rime（输入法数据）属于用户数据，保留

        softReboot();
    } catch (const std::exception& e) {
        showToast(e.what(), "#E9900C");
    }
}

void Mod::softReboot() { std::terminate(); }

void Mod::reboot() { exec("sync && reboot"); }

void Mod::onCaptureTick() {
    // 兜底：Engine 在 initUi 钩子开头就会设置 YPointer<QQuickView>，
    // 不依赖 beforeUiInitialization 的连接是否生效。
    if (!mCaptureWindow) {
        auto* view = YPointer<QQuickView>::getInstance();
        if (view) {
            mCaptureWindow = view;
            spdlog::info("[Mod] 通过 YPointer 取得窗口: {}", fmt::ptr(view));
        }
    }
    if (!mCaptureWindow) {
        static bool warned = false;
        if (!warned) {
            warned = true;
            spdlog::warn("[Mod] capture tick: mCaptureWindow 为空");
        }
        return;
    }
    if (!QFile::exists("/tmp/penmods_screencap")) {
        return;
    }
    spdlog::info("[Mod] 检测到截图标志，开始抓取");
    QFile::remove("/tmp/penmods_screencap");
    QImage image = mCaptureWindow->grabWindow();
    spdlog::info("[Mod] grabWindow 完成: {}x{}", image.width(), image.height());
    if (image.save("/tmp/penmods_screen.png", "PNG")) {
        spdlog::info("[ScreenCapture] saved /tmp/penmods_screen.png ({}x{})", image.width(), image.height());
    } else {
        spdlog::error("[ScreenCapture] failed to save screenshot");
    }
}

void Mod::onUiCompleted() const {

    // AutoFix vendor_storage.

    struct StoragedItem {
        QString mName;
        QString mType;
        QString mDefaultValue;
    };

    std::vector<StoragedItem> list = {
#if PL_BUILD_YDP02X
        {"VENDOR_COMPANY_ID",   "string", "COMPANY_HZ"             },
        // YDP021/022 满分版 16G
        {"VENDOR_CUSTOM_ID_0E", "string", "OVERHEAD_D2_SKU_EXA_ADV"}
    // YDP022 经典版 16G:   OVERHEAD_D2_SKU_CLA_ADV
    // YDP032 X3S 16G:     OVERHEAD_X3S_SKU_CHN_STD
    // YDP035 HLK STD:     OVERHEAD_D3_SKU_HILINK_STD
#endif
    };

    // 只在首次启动尝试修复，避免每次开机反复读取失败并刷屏。
    // 注意 vendor_storage 的错误输出在 stderr，必须 2>&1 合并后才能检测到。
    // 只有「不需要修」或「全部修好」才落 .vendor_repaired 标记：原实现无论成败
    // 都写标记，一次失败之后就再也不会重试了。
    if (!QFile::exists("/userdata/PenMods/.vendor_repaired")) {
        bool repairNeeded = false;
        bool allRepaired  = true;
        for (auto i : list) {
            if (exec(QString("vendor_storage -r %1 -t %2 2>&1").arg(i.mName, i.mType)).find("vendor read error -1")
                != std::string::npos) {
                repairNeeded = true;
                spdlog::warn("Automatically repairing vendor_storage: {}", i.mName.toStdString());
                if (exec(QString("vendor_storage -w %1 -t %2 -i %3 2>&1").arg(i.mName, i.mType, i.mDefaultValue))
                        .find("vendor write error")
                    != std::string::npos) {
                    allRepaired = false;
                }
            }
        }
        if (!repairNeeded || allRepaired) {
            QFile repairedFlag("/userdata/PenMods/.vendor_repaired");
            if (repairedFlag.open(QIODevice::WriteOnly)) {
                repairedFlag.write("ok");
                repairedFlag.close();
            }
        } else {
            spdlog::warn("vendor_storage repair did not succeed, will retry on next boot.");
        }
    }

    // 这里不再把 / remount 成 rw：需要写 rootfs 的地方（asound /
    // input-event-daemon 的按机型配置、卸载时还原主程序）各自临时放开再还原，
    // 避免整段会话都处于可写状态。

    // Ensure the bundled external player (mpv) is installed.

    ensurePlayerInstalled();

    // Ensure the bundled Rime input method data is installed.

    ensureRimeInstalled();
}

} // namespace mod

// Bypass the verification.

PEN_HOOK(bool, _ZNK15YSettingManager10isVerifiedEv, void* self) { return true; }

PEN_HOOK(bool, license_verify) { return true; }

// Setup mods.

#include "base/SymDB.h"
#include "base/YPointer.h"

#include "common/Downloader.h"
#include "common/Event.h"
#include "common/Resource.h"

#include "filemanager/FileManager.h"
#include "filemanager/player/MusicPlayer.h"
#include "filemanager/player/VideoPlayer.h"
#include "filemanager/reader/TextReader.h"
#include "filemanager/viewer/ImageViewer.h"
#include "filemanager/player/ExternalPlayer.h"

#include "helper/AntiEmbs.h"
#include "helper/DeveloperSettings.h"
#include "helper/NetworkSettings.h"
#include "helper/ServiceManager.h"

#include "locker/Locker.h"

#include "mod/Config.h"
#include "mod/Mod.h"
#include "mod/Updater.h"

#include "recorder/AudioRecorder.h"

#include "system/battery/BatteryInfo.h"
#include "system/input/InputDaemon.h"
#include "system/input/ScreenManager.h"
#include "system/sound/ASound.h"
#include "system/sound/AudioDaemon.h"

#include "theme/ThemeManager.h"
#include "torch/Torch.h"

#include "tweaker/ColumnDBLimiter.h"
#include "tweaker/KeyBoard.h"
#include "tweaker/LoggerMonitor.h"
#include "tweaker/QueryTweaks.h"
#include "tweaker/TextBookHelper.h"
#include "tweaker/WordBookTweaks.h"

#include "hitokoto/Backend.h"

#include "chatbot/Backend.h"

#include "rime/Backend.h"

#include "plugin/PluginManager.h"

#include "capture/CameraCapture.h"

using namespace mod;

__attribute__((constructor)) static void BeforeMain() {

    // Setup global logger.

    auto global = spdlog::stdout_color_mt("Global");
#ifdef PL_DEBUG
    spdlog::set_level(spdlog::level::debug);
#endif
    spdlog::set_pattern("[%H:%M:%S.%e] [%n] [%l] %v");
    spdlog::set_default_logger(global);

    // Setup mod instances.

#define INSTANCE(x) x::createInstance();

    // base
    INSTANCE(SymDB);
    INSTANCE(YPointerInitializer);

    // mod
    INSTANCE(Config);
    INSTANCE(Mod);
    INSTANCE(Updater);

    // common
    INSTANCE(Downloader);
    INSTANCE(Event);
    INSTANCE(Resource);

    // filemanager
    INSTANCE(filemanager::MusicPlayer);
    INSTANCE(filemanager::VideoPlayer);
    INSTANCE(filemanager::TextReader);
    INSTANCE(filemanager::FileManager);
    INSTANCE(filemanager::ImageViewer);
    INSTANCE(filemanager::ExternalPlayer);

    // helper
    INSTANCE(AntiEmbs);
    INSTANCE(DeveloperSettings);
    INSTANCE(NetworkSettings);
    INSTANCE(ServiceManager);

    // locker
    INSTANCE(Locker);

    // recorder
    INSTANCE(AudioRecorder);

    // system
    INSTANCE(BatteryInfo);
    INSTANCE(InputDaemon);
    INSTANCE(ScreenManager);
    INSTANCE(ASound);
    INSTANCE(AudioDaemon);

    // torch
    INSTANCE(Torch);

    // tweaker
    INSTANCE(ColumnDBLimiter);
    INSTANCE(KeyBoard);
    INSTANCE(LoggerMonitor);
    INSTANCE(ThemeManager);
    INSTANCE(QueryTweaks);
    INSTANCE(TextBookHelper);
    INSTANCE(WordBookTweaks);

    // hitokoto
    INSTANCE(hitokoto::Hitokoto)

    // chatbot
    INSTANCE(chatbot::ChatBot)

    // rime
    INSTANCE(rime::Backend)

    // plugin
    INSTANCE(PluginManager)
    
    // wallpaper
    INSTANCE(WallpaperManager)

    // capture
    INSTANCE(capture::CameraCapture)

#undef INSTANCE
}
