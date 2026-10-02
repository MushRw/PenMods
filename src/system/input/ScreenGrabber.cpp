// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "system/input/ScreenGrabber.h"

#include "common/Event.h"

#include <QByteArray>
#include <QCoreApplication>
#include <QFile>
#include <QImage>
#include <QImageWriter>
#include <QQmlContext>
#include <QScopeGuard>
#include <QStringList>
#include <QThread>

namespace mod {

static const char* kReq  = "/tmp/penmods_shot";
static const char* kLog  = "/tmp/penmods_shot.log";
static const char* kDir  = "/tmp";

ScreenGrabber::ScreenGrabber() {

    connect(&Event::getInstance(), &Event::beforeUiInitialization,
            [this](QQuickView& view, QQmlContext*) {
                mView = &view;
                spdlog::info("ScreenGrabber: 宿主窗口已就绪 {}x{}", view.width(), view.height());
            });

    // 1 秒一次，代价只是两次 stat。不用 QtFileSystemWatcher 是因为设备上
    // inotify 对 /tmp（tmpfs）不一定可靠，而这个轮询足够省。
    mTimer = new QTimer(this);
    mTimer->setInterval(1000);
    connect(mTimer, &QTimer::timeout, this, &ScreenGrabber::tick);
    mTimer->start();
    // 启动即打一行：下次若又出现"哨兵不被消费"，能立刻区分
    // 「Timer 压根没跑」（tick 里那条 debug 一行都不出现）vs「跑了但条件不满足」。
    spdlog::info("ScreenGrabber: 轮询已启动 {}ms", mTimer->interval());
}

void ScreenGrabber::tick() {
    if (mBusy || !mView) return;
    if (!QFile::exists(kReq)) return;

    // 命中过一次就打一行：哨兵不被消费时，这条日志的有无直接指认 Timer 是否在跑。
    spdlog::info("ScreenGrabber: 命中哨兵，抓一帧");
    // 先删哨兵再抓：grabWindow + save 是同步的，但删早了怕丢请求，
    // 删晚了会在这一帧里重复触发 —— 先删，失败也只丢一次请求，可接受。
    QFile::remove(QString::fromUtf8(kReq));
    grabNow();
}

QString ScreenGrabber::grabNow() {

    mBusy = true;
    // maybe_unused：guard 的作用在**析构时**执行（每个 return 分支都会释放 mBusy），
    // 变量本身读不到，编译器会报 unused-variable。
    [[maybe_unused]] auto guard = qScopeGuard([this] { mBusy = false; });

    auto logLine = [](const QString& s) {
        QFile f(QString::fromUtf8(kLog));
        if (f.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
            f.write((s + "\n").toUtf8());
    };

    if (!mView) {
        logLine(QStringLiteral("err no-view"));
        return QStringLiteral("no-view");
    }

    // grabWindow 必须在 GUI 线程。正常情况下 QTimer 就在 GUI 线程，
    // 但显式校验一次 —— 万一将来从别的线程调进来，静默失败会很难查。
    if (QThread::currentThread() != mView->thread()) {
        logLine(QStringLiteral("err wrong-thread %1 vs %2")
                    .arg(quintptr(QThread::currentThread()), 0, 16)
                    .arg(quintptr(mView->thread()), 0, 16));
        return QStringLiteral("wrong-thread");
    }

    QImage img = mView->grabWindow();
    if (img.isNull()) {
        logLine(QStringLiteral("err grab-null"));
        return QStringLiteral("grab-null");
    }

    // 设备上没有 webp 解码器这件事跟这里无关，但 PNG 编码器必须确认存在
    // —— 缺了会写出 0 字节文件，症状和"抓图失败"一模一样，极易误判。
    if (!QImageWriter::supportedImageFormats().contains(QByteArrayLiteral("png"))) {
        logLine(QStringLiteral("err no-png-enc fmt=%1")
                    .arg(QString::fromLatin1(QImageWriter::supportedImageFormats().join(','))));
        return QStringLiteral("no-png-enc");
    }

    const QString path = QString::fromUtf8(kDir) + QStringLiteral("/penmods_shot-%1.png").arg(mSeq++);
    if (!img.save(path, "PNG")) {
        logLine(QStringLiteral("err save-fail %1").arg(path));
        return QStringLiteral("save-fail");
    }

    logLine(QStringLiteral("ok %1 %2x%3 exposed=%4")
                .arg(path)
                .arg(img.width())
                .arg(img.height())
                .arg(mView->isExposed() ? 1 : 0));
    spdlog::info("ScreenGrabber: 已抓取 {}", path.toStdString());
    return path;
}

} // namespace mod
