// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "tweaker/KeyBoard.h"

#include "common/Event.h"
#include "mod/Config.h"

#include "base/YPointer.h"

#include <QQmlContext>

namespace mod {

KeyBoard::KeyBoard() {
    auto& config  = mod::Config::getInstance();
    json  aiCfg   = config.read("ai");
    // KB-13：这里在**构造函数（开机路径）**上，配置一旦被手改成字符串/数字，
    // `get<bool>()` 会抛 `nlohmann::type_error` → 构造抛异常 → 主程序退出 →
    // guardian 重拉并累计崩溃计数。`contains()` 只保证"键存在"，不保证类型，
    // 所以要连 `is_boolean()` 一起判（与 Locker.cpp 读 bool 的写法一致）。
    m_autoSendScanConfig =
        (aiCfg.contains("auto_send_scan") && aiCfg["auto_send_scan"].is_boolean())
            ? aiCfg["auto_send_scan"].get<bool>()
            : true;

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("keyBoard", this);
    });
}

void KeyBoard::setAutoSendScan(bool value) {
    if (value && m_inputPageShowing)
        return;
    if (m_autoSendScan != value) {
        m_autoSendScan = value;
        emit autoSendScanChanged();
    }
}

void KeyBoard::setInputPageShowing(bool value) {
    if (m_inputPageShowing != value) {
        m_inputPageShowing = value;
        emit inputPageShowingChanged();
    }
}

void KeyBoard::setAutoSendScanConfig(bool value) {
    if (m_autoSendScanConfig != value) {
        m_autoSendScanConfig = value;
        auto& config = mod::Config::getInstance();
        json aiCfg   = config.read("ai");
        if (aiCfg.is_null()) aiCfg = json::object();
        aiCfg["auto_send_scan"] = value;
        config.write("ai", aiCfg, true);
        emit autoSendScanConfigChanged();
    }
}

} // namespace mod

static bool shouldBlockScan() {
    bool inputPageShowing = PEN_CALL(bool, "_ZNK7YGlobal16inputPageShowingEv", void*)(mod::YPointer<YGlobal>::getInstance());
    return inputPageShowing || mod::KeyBoard::getInstance().autoSendScan();
}

PEN_HOOK(bool, _ZN11YSystemBase12onScanFinishERK7QStringi, uint64 self, QString const& content, ScanType scanType) {
    if (shouldBlockScan()) {
        emit mod::KeyBoard::getInstance().scanFinished(content);
        return false;
    }
    return origin(self, content, scanType);
}

PEN_HOOK(uint64, _ZN11YSystemBase8ocrStartEv, uint64 self, uint64 a2, uint64 a3, uint64 a4, uint64 a5) {
    if (shouldBlockScan()) {
        return false;
    }
    return origin(self, a2, a3, a4, a5);
}

PEN_HOOK(uint64, _ZN11YSystemBase7ocrStopEi, uint64 self, int a2, uint64 a3, uint64 a4, uint64 a5) {
    if (shouldBlockScan()) {
        return false;
    }
    return origin(self, a2, a3, a4, a5);
}

PEN_HOOK(
    uint64,
    _ZN11YSystemBase25ocrCompletedResultChangedEv,
    uint64 self,
    uint64 a2,
    uint64 a3,
    uint64 a4,
    uint64 a5
) {
    if (shouldBlockScan()) {
        return false;
    }
    return origin(self, a2, a3, a4, a5);
}
