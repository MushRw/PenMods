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
        n.trueOrig = trueOrig;
        n.head     = detour;
        n.subs.push_back({detour, outOriginal});
        nodes()[target] = n;
        *outOriginal    = trueOrig;
    } else {
        // 后续订阅者：前置到链头；其 original 指向原链头，原链头成为它的下一跳。
        // 去重守卫：同一 detour 重复订阅（如插件被 init_plugin 二次初始化）时
        // 不再入链，直接把现有转发指针回填——重复入链会让退订语义混乱。
        for (auto& s : it->second.subs) {
            if (s.first == detour) {
                *outOriginal = *s.second;
                return 0;
            }
        }
        *outOriginal                     = it->second.head;
        it->second.head                  = detour;
        it->second.subs.push_back({detour, outOriginal});
    }
    return 0;
}

int MediaHookChain::unsubscribe(void* target, void* detour) {
    if (!s_resolved) resolve();

    auto it = nodes().find(target);
    if (it == nodes().end()) return -1;

    Node& n           = it->second;
    auto& subs        = n.subs;
    auto  sub         = subs.end();
    for (auto s = subs.begin(); s != subs.end(); ++s) {
        if (s->first == detour) { sub = s; break; }
    }
    if (sub == subs.end()) return -2; // 不是本链的订阅者（可能已退订）

    // 这个订阅者原本把调用转发给谁（下一跳）：链头订阅者是 trueOrig，其余是订阅当时的链头
    void* savedForward = *sub->second;
    bool  wasHead      = (n.head == detour);

    // 修补「更晚订阅、下一跳指向本 detour」的订阅者：让它跳过本订阅者。
    // （退订链头时不存在这样的订阅者——没人指向链头，由 wrapper 直接调用。）
    for (auto s = subs.begin(); s != subs.end(); ++s) {
        if (s != sub && *s->second == detour) {
            *s->second = savedForward;
            break;
        }
    }

    subs.erase(sub);

    if (subs.empty()) {
        // 最后一个订阅者走了：现在才轮到拆 Dobby hook（目标字节还原、trampoline 释放），
        // 并抹掉节点，保证下次 subscribe() 会重新 DobbyHook。
        int rc = DobbyDestroy(target);
        nodes().erase(it);
        if (rc != 0)
            spdlog::warn("[MediaHookChain] DobbyDestroy failed at {:#x} (rc={})",
                         reinterpret_cast<uint64_t>(target), rc);
        return rc;
    }

    if (wasHead) {
        // 退订的是链头：新链头 = 现在最晚的订阅者。它的转发指针**不能动**——
        // 它当初订阅时拿到的那一跳，连同被摘链头在内的所有更晚订阅者现在都已
        // 被摘掉或绕开，修补循环已把指向它们的转发指针改写干净，所以新链头的
        // orig 必然仍指向存活节点或 trueOrig。此处若把它改成被摘者的下一跳
        // （savedForward），会让最早订阅者自指死循环（实测会导致播放链路卡死）。
        n.head = subs.back().first;
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
