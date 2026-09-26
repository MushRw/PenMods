// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "base/StdInt.h"
#include "base/SymDB.h"

#include <dobby.h>

#define PEN_SYM(sym) (::mod::SymDB::getInstance().query(sym))

#define PEN_CALL(ret_t, sym, args_t...) ((ret_t(*)(args_t))(PEN_SYM(sym)))

#define PEN_HOOK(ret_t, sym, args_t...) PEN_HOOK_ADDR(ret_t, sym, PEN_SYM(#sym), args_t)

// 目标地址解析失败时**绝不能**把 nullptr 交给 DobbyHook：
//   1) PEN_SYM 解析不到就返回 nullptr，而 DobbyHook(nullptr, …) 直接写地址 0 → 崩溃；
//   2) 崩在启动路径上会被厂商崩溃保护放大成 `update_engine --misc=clear` + 切 A/B 槽，
//      整个 rootfs 的 PenMods 补丁全丢（见 docs/rootfs-mods.md 里的事故记录）。
// 所以这里降级为「不挂 hook、记一条 error、功能不可用」，而不是崩。
// 自 2.1.2 起原版符号表已固定并入库（tools/penimg/ + symcheck.py），
// 走到这个分支基本只有一个原因：符号名写错了。校验器能在提交前抓住。
#define PEN_HOOK_ADDR(ret_t, name, addr, args_t...)                                                                    \
    class HookRegistrar_##name {                                                                                       \
    public:                                                                                                            \
        explicit HookRegistrar_##name() {                                                                              \
            if ((addr) == nullptr) {                                                                                   \
                spdlog::error("Hook target not found, hook skipped: {} (feature disabled, NOT a crash).", #name);       \
                return;                                                                                                \
            }                                                                                                          \
            if (DobbyHook(addr, (dobby_dummy_func_t)detour, (dobby_dummy_func_t*)&origin) != 0) {                      \
                spdlog::error("Fail to hook: {} ({:#x}).", #name, reinterpret_cast<uint64>(addr));                     \
            }                                                                                                          \
        }                                                                                                              \
        static ret_t (*origin)(args_t);                                                                                \
        static ret_t detour(args_t);                                                                                   \
    };                                                                                                                 \
    ret_t (*HookRegistrar_##name::origin)(args_t) = nullptr;                                                           \
    static HookRegistrar_##name hookRegistrar_##name;                                                                  \
    ret_t                       HookRegistrar_##name::detour(args_t)
