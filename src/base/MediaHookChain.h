// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */
#pragma once

#include <cstdint>
#include <map>
#include <utility>
#include <vector>

#include "base/StdInt.h"

// LX-01 修复：宿主（PEN_HOOK）与 lx-pen 插件都 hook 了同一批媒体控制函数
// （onClickedPrev / onClickedNext / onSoundEnd）。Dobby 每个目标只支持一个 trampoline，
// 谁先加载谁赢，另一个的 hook 必然失败（部署日志里那 3 条 `Fail to hook` 就是现场）。
//
// 这里把 3 个冲突目标收口到一个引用计数的 hook 链：第一个订阅者用 DobbyHook 装 trampoline，
// 后续订阅者不重复 DobbyHook，而是被「前置」到链头，其 original 指向当前链头，链尾指向真正的
// 原函数。这样 host 的接管逻辑与 lx-pen 的音乐导航**都**会执行，不再互相覆盖。
//
// 仅对这 3 个已知签名的目标生效，不动其他 100+ 个 PEN_HOOK 站点，启动路径风险被锁在最小范围。
namespace mod {

class MediaHookChain {
public:
    // 订阅某个媒体目标的 detour。target 必须是 3 个已知目标之一，否则返回 -1（交给原 DobbyHook）。
    // 成功返回 0；outOriginal 收到「该订阅者应调用的下一跳」（链头订阅者拿到真原函数）。
    static int subscribe(void* target, void* detour, void** outOriginal);
    // 退订：插件卸载时调用。只把该插件的 detour 从链上摘掉并修补其余订阅者的转发指针；
    // **链上还有其他订阅者（如宿主）时绝不动 Dobby hook**——DobbyDestroy 会拆掉唯一
    // 的 trampoline，宿主的 hook 就一起没了；而且运行中拆除 = 在音频线程可能正在执行
    // 目标函数的同时改写代码页（实测禁用插件时桌面重启一次的候选成因）。链空了才
    // DobbyDestroy 并抹掉节点，保证下次 subscribe 重新装钩。0 = 成功，非 0 = 失败。
    static int unsubscribe(void* target, void* detour);
    // hookFunctionImpl 用来判断目标是否归本链管。
    static bool isChainedTarget(void* target);

    // 每个目标一个、签名正确的 trampoline。仅把调用转交给当前链头。
    static uint64 wrapOnClickedPrev(void* self, bool a2);
    static uint64 wrapOnClickedNext(void* self, bool a2);
    static void*  wrapOnSoundEnd(void* self, uint32 a2);

private:
    struct Node {
        void* head     = nullptr;  // 当前链头 detour
        void* trueOrig = nullptr;  // DobbyHook 返回的真原函数
        // 订阅者登记表（按订阅先后）：{detour, outOriginal 指针}。
        // 退订时要靠 origPtr 修补「下一跳订阅者」的转发指针，所以必须存指针本身。
        std::vector<std::pair<void*, void**>> subs;
    };
    static Node& nodeFor(void* target);
    // 函数局部静态：宿主 registrar 在静态初始化期就会调用 subscribe()，
    // 跨编译单元的全局对象初始化顺序不可依赖，必须用「首次使用时构造」规避。
    static std::map<void*, Node>& nodes();

    static void* s_addrPrev;
    static void* s_addrNext;
    static void* s_addrEnd;
    static bool  s_resolved;
    static void  resolve();
};

}  // namespace mod
