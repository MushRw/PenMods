// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "base/YPointer.h"

#include "common/service/Singleton.h"

#include <QObject>
#include <QQuickView>
#include <QTimer>

namespace mod {

/// 远程截屏通道（调试 / 验收用）。
///
/// 背景：这台设备上「从外部拿到屏幕画面」的路全被实测堵死了 ——
///   weston 没带 --debug ⇒ weston-screenshooter 拒（permission denied）；
///   外部 wayland 客户端建不出窗口（厂商 weston 只有 fullscreen-shell 类 shell）；
///   qmlscene offscreen/vnc 无 GL ⇒ grabToImage 报 item is not attached to a window；
///   /dev/fb0 禁碰（mmap 实测内核 panic）。
/// 但**宿主自己的 QQuickView 就是那个窗口** —— QQuickWindow::grabWindow()
/// 走的是 Qt 场景图 FBO，跟上面那些外部途径完全不是一回事，从没试过。
///
/// 通道设计（哨兵文件，不 poll 也不占资源以外的任何东西）：
///   电脑侧 `touch /tmp/penmods_shot`  ⇒ 本类 1 秒内抓一帧
///          存成 /tmp/penmods_shot-<n>.png，写 /tmp/penmods_shot.log 记结果
///   电脑侧 `adb pull` 取走。
///
/// 为什么不用 QML 的 grabToImage：那个只在**插件页前台**时有效，而
/// beforeUiInitialization 拿到的 QQuickView 是常驻的 ⇒ 任何页面（含词典主界面、
/// 设置页、锁屏）都能截，这对「人在外面、只想看屏幕」的场景是决定性的。
class ScreenGrabber : public QObject, public Singleton<ScreenGrabber> {
    Q_OBJECT

public:
    Q_INVOKABLE QString grabNow();

private:
    friend Singleton<ScreenGrabber>;
    explicit ScreenGrabber();

    void tick();

    // ⚠️ mTimer 必须是 **指针**且带 this 作 parent。
    // 原先是值成员 `QTimer mTimer`：它在 ScreenGrabber 基类构造之后才构造，
    // 且没有 parent ⇒ 在某些启动顺序下 QTimer 没被挂进 GUI 线程的事件循环，
    // 表现为 mView 已就绪（日志有 "宿主窗口已就绪"）但哨兵永远不被消费、
    // log 一行不写。指针 + setParent(this) 由 QObject 的 child 机制保证线程与生命周期。
    QTimer* mTimer = nullptr;
    QQuickView* mView = nullptr;
    int  mSeq = 0;
    int  mTick = 0;
    bool mBusy = false;
};

} // namespace mod
