#pragma once

#include <dobby.h>

using uint64 = unsigned long long;

#define PEN_SYM(sym) (SymDB::getInstance().query(sym))

#define PEN_CALL(ret_t, sym, args_t...) ((ret_t(*)(args_t))(PEN_SYM(sym)))

#define PEN_HOOK(ret_t, sym, args_t...) PEN_HOOK_ADDR(ret_t, sym, PEN_SYM(#sym), args_t)

// 同 src/base/Hook.h：解析失败时降级为「不挂 hook」，不要把 nullptr 交给 DobbyHook。
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
