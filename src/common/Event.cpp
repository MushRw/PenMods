// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "common/Event.h"
#include "system/input/ScreenManager.h"

#include <QQmlContext>

#include <spdlog/spdlog.h>

#include <exception>

namespace {

/// 把「同步调用一批槽函数」的异常兜住。
///
/// Event 的 emit 点**全部位于 Dobby detour 内部**（`headSetInitStatus` / `_do_button_press` /
/// `currentPageIndexChanged` / `AsyncQuery::prepare`），而这些槽会去碰文件系统、跑 shell
/// （`mod::exec()` 在 `popen` 失败时直接 `throw`）和厂商 API。异常一旦展开到 detour 的
/// C ABI 边界就是 `std::terminate` → 主程序退出 → `guardian_run` 立刻重拉。若两次启动
/// 间隔 < 15 秒并累计 6 次，厂商崩溃保护会 `update_engine --misc=clear` + 切 A/B 槽，
/// **整份 rootfs 补丁丢失** —— 这就是用户看到的「桌面重启」的成因之一。
///
/// 结论：单个槽失败应该只丢它自己的功能，不该让整个桌面消失（EX-04 / SD-04）。
/// 注意别把这里当成"静默吞异常"：异常一定会以 error 级别写进日志。
template <class F>
void emitSafely(const char* what, F&& fn) {
    try {
        fn();
    } catch (const std::exception& e) {
        spdlog::error("[Event] {} 的订阅者抛出异常（已忽略，避免杀掉主程序）: {}", what, e.what());
    } catch (...) {
        spdlog::error("[Event] {} 的订阅者抛出了非 std 异常（已忽略）", what);
    }
}

} // namespace

namespace mod {

Event::Event() {
    connect(this, &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("builtinEvents", this);
    });
}

} // namespace mod

PEN_HOOK(void*, _ZN11YSystemBase17headSetInitStatusEv, void* self) {
    mod::ScreenManager::getInstance().setSystemBase(reinterpret_cast<YSystemBase*>(self));
    static bool called = false;
    if (!called) {
        called = true;
        emitSafely("beforeUiCompleted", [] { emit mod::Event::getInstance().beforeUiCompleted(); });
        auto result = origin(self);
        emitSafely("uiCompleted", [] { emit mod::Event::getInstance().uiCompleted(); });
        return result;
    }
    return origin(self);
}

PEN_HOOK(
    uint64,
    _ZN14YButtonMonitor16_do_button_pressE11button_id_tiii,
    uint64 self,
    uint32 buttonId,
    int    unk_a3,
    int    unk_a4,
    int    unk_a5
) {
    switch (buttonId) {
    case 3: {
        emitSafely("homeButtonPressed", [] { emit mod::Event::getInstance().homeButtonPressed(); });
        break;
    }
    case 6:
    default:
        break;
    }
    return origin(self, buttonId, unk_a3, unk_a4, unk_a5);
}

PEN_HOOK(void*, _ZN7YGlobal23currentPageIndexChangedEv, void* self, void* a2, void* a3, void* a4, void* a5) {
    emitSafely("currentPageIndexChanged", [self] {
        emit mod::Event ::getInstance().currentPageIndexChanged(
            PEN_CALL(int, "_ZNK7YGlobal16currentPageIndexEv", void*)(self)
        );
    });
    return origin(self, a2, a3, a4, a5);
}

PEN_HOOK(uint64, _ZN8Database10AsyncQuery7prepareERK7QString, void* self, QString& a2) {
    emitSafely("beforeDatabasePrepareAsyncQuery", [&a2] {
        emit mod::Event::getInstance().beforeDatabasePrepareAsyncQuery(a2);
    });
    return origin(self, a2);
}

// EARLY INITIALIZED.
