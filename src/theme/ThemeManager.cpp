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

// pureBlack：OLED 省电，灰阶整体下移（语义色不变）
QVariantMap pureBlackPalette() {
    return QVariantMap{
        {"black", "#000000"},        {"white", "#FFFFFF"},
        {"red", "#F03043"},          {"orange", "#FF8B20"},
        {"green", "#13B876"},        {"yellow", "#E9900C"},
        {"blueText", "#509DEB"},     {"blueRect", "#2D73DC"},
        {"blueLink", "#62A8EA"},     {"blueDeep", "#1E3A55"},
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

void ThemeManager::_load() {
    const auto cfg = Config::getInstance().read("theme");
    const auto id  = QString::fromStdString(cfg.value("id", "official"));
    if (mThemes.contains(id)) {
        mId = id;
    }
}

void ThemeManager::_save() const {
    auto cfg      = Config::getInstance().read("theme");
    cfg["id"]     = mId.toStdString();
    Config::getInstance().write("theme", cfg);
}

} // namespace mod
