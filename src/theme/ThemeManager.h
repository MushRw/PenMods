// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Singleton.h"

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

namespace mod {

// 主题系统：把整套界面用色收敛成"一个可切换的色板"。
//
// 用法：QML 里 YColors.qml 的每个令牌都绑定到 theme.<名字>，所以切主题时
// 所有绑了令牌的界面会自动重绘。色板定义在 _initThemes()，新增主题只要加一份
// map；主题 id 存在 config.json 的 theme.id，开机 beforeUiInitialization 时套用。
//
// 注意：这里只提供颜色，不碰"层级/语义"本身 —— 层级仍由 QML 侧决定用哪个令牌。
class ThemeManager : public QObject, public Singleton<ThemeManager> {
    Q_OBJECT

    Q_PROPERTY(QString     id              READ getId              WRITE setId  NOTIFY themeChanged)
    Q_PROPERTY(QStringList availableThemes READ availableThemes                 CONSTANT)

    // ---- 色板（全部随主题变化，统一用 themeChanged 通知）----
    Q_PROPERTY(QString black          READ black          NOTIFY themeChanged)
    Q_PROPERTY(QString white          READ white          NOTIFY themeChanged)
    Q_PROPERTY(QString red            READ red            NOTIFY themeChanged)
    Q_PROPERTY(QString orange         READ orange         NOTIFY themeChanged)
    Q_PROPERTY(QString green          READ green          NOTIFY themeChanged)
    Q_PROPERTY(QString yellow         READ yellow         NOTIFY themeChanged)
    Q_PROPERTY(QString blueText       READ blueText       NOTIFY themeChanged)
    Q_PROPERTY(QString blueRect       READ blueRect       NOTIFY themeChanged)
    Q_PROPERTY(QString blueLink       READ blueLink       NOTIFY themeChanged)
    Q_PROPERTY(QString blueDeep       READ blueDeep       NOTIFY themeChanged)
    Q_PROPERTY(QString grayText       READ grayText       NOTIFY themeChanged)
    Q_PROPERTY(QString grayNormal     READ grayNormal     NOTIFY themeChanged)
    Q_PROPERTY(QString graySwitchOff  READ graySwitchOff  NOTIFY themeChanged)
    Q_PROPERTY(QString grayButton     READ grayButton     NOTIFY themeChanged)
    Q_PROPERTY(QString border         READ border         NOTIFY themeChanged)
    Q_PROPERTY(QString pressed        READ pressed        NOTIFY themeChanged)
    Q_PROPERTY(QString textSecondary  READ textSecondary  NOTIFY themeChanged)
    Q_PROPERTY(QString textMuted      READ textMuted      NOTIFY themeChanged)
    Q_PROPERTY(QString scrim          READ scrim          NOTIFY themeChanged)
    Q_PROPERTY(QString scrimStrong    READ scrimStrong    NOTIFY themeChanged)
    Q_PROPERTY(QString scrimLight     READ scrimLight     NOTIFY themeChanged)

public:
    QString     getId() const { return mId; }
    void        setId(const QString& id);
    QStringList availableThemes() const;

    // 取当前主题下某个色值（C++ 侧用，比如 markdownToHtml 需要把颜色拼进 HTML）
    QString color(const QString& name) const { return mThemes.value(mId).value(name).toString(); }

    QString black() const { return color("black"); }
    QString white() const { return color("white"); }
    QString red() const { return color("red"); }
    QString orange() const { return color("orange"); }
    QString green() const { return color("green"); }
    QString yellow() const { return color("yellow"); }
    QString blueText() const { return color("blueText"); }
    QString blueRect() const { return color("blueRect"); }
    QString blueLink() const { return color("blueLink"); }
    QString blueDeep() const { return color("blueDeep"); }
    QString grayText() const { return color("grayText"); }
    QString grayNormal() const { return color("grayNormal"); }
    QString graySwitchOff() const { return color("graySwitchOff"); }
    QString grayButton() const { return color("grayButton"); }
    QString border() const { return color("border"); }
    QString pressed() const { return color("pressed"); }
    QString textSecondary() const { return color("textSecondary"); }
    QString textMuted() const { return color("textMuted"); }
    QString scrim() const { return color("scrim"); }
    QString scrimStrong() const { return color("scrimStrong"); }
    QString scrimLight() const { return color("scrimLight"); }

signals:
    void themeChanged();

private:
    friend Singleton<ThemeManager>;
    explicit ThemeManager();

    void _initThemes();
    void _load();
    void _save() const;

    QString mId = "official";
    // 主题 id -> (色名 -> 值)
    QHash<QString, QVariantMap> mThemes;
};

} // namespace mod
