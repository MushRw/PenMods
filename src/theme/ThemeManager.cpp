// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "ThemeManager.h"

#include "common/Event.h"
#include "mod/Config.h"

#include <QQmlContext>

namespace mod {

namespace {
// official：与改造前逐值一致（零视觉回归）
QVariantMap officialPalette() {
    return QVariantMap{
        {"black", "#000000"},        {"white", "#FFFFFF"},
        {"red", "#F03043"},          {"orange", "#FF8B20"},
        {"green", "#13B876"},        {"yellow", "#E9900C"},
        {"blueText", "#509DEB"},     {"blueRect", "#2D73DC"},
        {"blueLink", "#62A8EA"},     {"blueDeep", "#2B5278"},
        {"grayText", "#909199"},     {"grayNormal", "#1A1B1F"},
        {"graySwitchOff", "#515259"},{"grayButton", "#2D2E33"},
        {"border", "#3F3F3F"},       {"pressed", "#444444"},
        {"textSecondary", "#AAAAAA"},{"textMuted", "#666873"},
        {"scrim", "#88000000"},      {"scrimStrong", "#CC000000"},
        {"scrimLight", "#4D000000"},
    };
}

// pureBlack：OLED 省电，灰阶整体下移。
//
// 强调色不是简单"调暗"：底色已经是 #0A0A0C，再压暗只会让强调色和背景糊在一起
// （对比度反而下降）。深色主题真正要动的是**饱和度**——高饱和在近黑底上会发闷、
// 边缘发颤。所以这里走"同色相 + 降饱和 + 轻微提亮"，并守住 WCAG 对比度：
//   * 当文字/图标用（orange/green/yellow/blueText/blueLink）：对 #0A0A0C >= 4.5
//   * red 额外当填充用（聊天气泡），上面压白字，所以只做轻度削弱
//     （#F03043 白字 4.03 → #E74D5D 白字 3.74，仍与 official 同档）
//   * blueRect 是纯填充（按钮底），白字要更清楚 → 反而压深（4.57 → 5.51）
QVariantMap pureBlackPalette() {
    return QVariantMap{
        {"black", "#000000"},        {"white", "#FFFFFF"},
        {"red", "#E74D5D"},          {"orange", "#E9A15F"},
        {"green", "#2FC589"},        {"yellow", "#DC9E42"},
        {"blueText", "#83B2E0"},     {"blueRect", "#3268B8"},
        {"blueLink", "#93BCE2"},     {"blueDeep", "#1E3A55"},
        {"grayText", "#8C8D95"},     {"grayNormal", "#0A0A0C"},
        {"graySwitchOff", "#3C3D44"},{"grayButton", "#1A1B20"},
        {"border", "#2B2B30"},       {"pressed", "#33343B"},
        {"textSecondary", "#A0A1A9"},{"textMuted", "#5E5F67"},
        {"scrim", "#88000000"},      {"scrimStrong", "#CC000000"},
        {"scrimLight", "#4D000000"},
    };
}
} // namespace

ThemeManager::ThemeManager() {
    _initThemes();
    _load();

    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView&, QQmlContext* context) {
        context->setContextProperty("theme", this);
    });
}

void ThemeManager::_initThemes() {
    mThemes.insert("official", officialPalette());
    mThemes.insert("pureBlack", pureBlackPalette());
}

QStringList ThemeManager::availableThemes() const { return mThemes.keys(); }

void ThemeManager::setId(const QString& id) {
    if (id == mId || !mThemes.contains(id)) {
        return;
    }
    mId = id;
    _save();
    emit themeChanged();
}

void ThemeManager::setSurfaceStyle(const QString& style) {
    static const QStringList kValid{"opaque", "translucent", "glass"};
    if (style == mSurfaceStyle || !kValid.contains(style)) {
        return;
    }
    mSurfaceStyle = style;
    _save();
    emit themeChanged();
}

double ThemeManager::surfaceAlpha() const { return mSurfaceStyle == "opaque" ? 1.0 : 0.6; }

void ThemeManager::_load() {
    const auto cfg    = Config::getInstance().read("theme");
    const auto id     = QString::fromStdString(cfg.value("id", "official"));
    const auto surf   = QString::fromStdString(cfg.value("surfaceStyle", "translucent"));
    static const QStringList kValid{"opaque", "translucent", "glass"};
    if (mThemes.contains(id)) {
        mId = id;
    }
    if (kValid.contains(surf)) {
        mSurfaceStyle = surf;
    }
}

void ThemeManager::_save() const {
    auto cfg             = Config::getInstance().read("theme");
    cfg["id"]            = mId.toStdString();
    cfg["surfaceStyle"]  = mSurfaceStyle.toStdString();
    Config::getInstance().write("theme", cfg);
}

} // namespace mod
