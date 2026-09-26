// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */
#include "base/MediaHookChain.h"

#include <dobby.h>

#include "base/SymDB.h"

namespace mod {

void* MediaHookChain::s_addrPrev = nullptr;
void* MediaHookChain::s_addrNext = nullptr;
void* MediaHookChain::s_addrEnd  = nullptr;
bool  MediaHookChain::s_resolved = false;

// 函数局部静态：宿主 registrar 在静态初始化期就会调用 subscribe()，
// 跨编译单元的全局对象初始化顺序不可依赖，必须用「首次使用时构造」规避。
std::map<void*, MediaHookChain::Node>& MediaHookChain::nodes() {
    static std::map<void*, Node> instance;
    return instance;
}

void MediaHookChain::resolve() {
    s_addrPrev = SymDB::getInstance().query("_ZN19YMediaPlayerManager13onClickedPrevEb");
    s_addrNext = SymDB::getInstance().query("_ZN19YMediaPlayerManager13onClickedNextEb");
    s_addrEnd  = SymDB::getInstance().query("_ZN19YMediaPlayerManager10onSoundEndEj");
    s_resolved = true;
}

bool MediaHookChain::isChainedTarget(void* target) {
    if (!s_resolved) resolve();
    return target == s_addrPrev || target == s_addrNext || target == s_addrEnd;
}

MediaHookChain::Node& MediaHookChain::nodeFor(void* target) {
    return nodes()[target];
}

int MediaHookChain::subscribe(void* target, void* detour, void** outOriginal) {
    if (!s_resolved) resolve();
    if (target != s_addrPrev && target != s_addrNext && target != s_addrEnd) return -1;

    auto it = nodes().find(target);
    if (it == nodes().end()) {
        // 第一个订阅者：装 Dobby trampoline（用对应目标的签名正确 wrapper）。
        void* wrapper = nullptr;
        if (target == s_addrPrev)
            wrapper = reinterpret_cast<void*>(&wrapOnClickedPrev);
        else if (target == s_addrNext)
            wrapper = reinterpret_cast<void*>(&wrapOnClickedNext);
        else
            wrapper = reinterpret_cast<void*>(&wrapOnSoundEnd);

        void* trueOrig = nullptr;
        int   rc       = DobbyHook(target, (dobby_dummy_func_t)wrapper,
                                  (dobby_dummy_func_t*)&trueOrig);
        if (rc != 0) return rc;
        Node n;
        n.head     = detour;
        n.trueOrig = trueOrig;
        nodes()[target] = n;
        *outOriginal    = trueOrig;
    } else {
        // 后续订阅者：前置到链头；其 original 指向原链头，原链头成为它的下一跳。
        *outOriginal       = it->second.head;
        it->second.head    = detour;
    }
    return 0;
}

uint64 MediaHookChain::wrapOnClickedPrev(void* self, bool a2) {
    Node& n = nodeFor(s_addrPrev);
    using Fn = uint64 (*)(void*, bool);
    Fn head = reinterpret_cast<Fn>(n.head ? n.head : n.trueOrig);
    return head(self, a2);
}

uint64 MediaHookChain::wrapOnClickedNext(void* self, bool a2) {
    Node& n = nodeFor(s_addrNext);
    using Fn = uint64 (*)(void*, bool);
    Fn head = reinterpret_cast<Fn>(n.head ? n.head : n.trueOrig);
    return head(self, a2);
}

void* MediaHookChain::wrapOnSoundEnd(void* self, uint32 a2) {
    Node& n = nodeFor(s_addrEnd);
    using Fn = void* (*)(void*, uint32);
    Fn head = reinterpret_cast<Fn>(n.head ? n.head : n.trueOrig);
    return head(self, a2);
}

}  // namespace mod
