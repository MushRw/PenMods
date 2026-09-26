// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "mod/Mod.h"

#include "base/YEnum.h"

#include <spdlog/spdlog.h>

#define FEATURE_ENABLE(fea)  (supportFeatures |= 1UL << ((fea) & 0x3F))
// 原实现是 "|= 0"，等于什么都没做（宏当前没被使用，但语义是错的）。
// supportFeatures 是 std::bitset，用 set(pos, false) 清位。
#define FEATURE_DISABLE(fea) (supportFeatures.set((fea) & 0x3F, false))
#define FEATURE_HAS(fea)     (((1UL << (fea & 0x3F)) & supportFeatures.to_ulong()) != 0)

PEN_HOOK(void, _ZN2FT11InitFeatureEv) {
    origin();

    if (!mod::Mod::getInstance().isTrustedDevice()) {
        return;
    }

    // `FT::s_supportFeatures` 不在主程序里：它由 libControls.so.1.0.0 导出
    // （.dynsym GLOBAL OBJECT，8 字节 .bss），只能运行时解析得到地址。
    // 这是全仓唯一一个「跨模块 + 数据符号」的引用，必须判空后再解引用 ——
    // 空指针解引用会崩在功能初始化路径上，而启动路径的崩溃会被厂商保护
    // 放大成 update_engine --misc=clear + 切槽（整份 rootfs 补丁丢失）。
    auto* raw = PEN_SYM("_ZN2FT17s_supportFeaturesE");
    if (!raw) {
        spdlog::error("FT::s_supportFeatures not resolved, feature unlock skipped (libControls.so not loaded?).");
        return;
    }
    auto& supportFeatures = *static_cast<std::bitset<60>*>(raw);

    FEATURE_ENABLE(DictPenFeature::OXFORD);
    FEATURE_ENABLE(DictPenFeature::WEBSTER);

    FEATURE_ENABLE(DictPenFeature::LANG_JPN);
    FEATURE_ENABLE(DictPenFeature::LANG_KOR);
    FEATURE_ENABLE(DictPenFeature::KOJN); // enable wordbook filter.
}
