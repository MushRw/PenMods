pragma Singleton

import QtQuick 2.12

// 全局配色。现在支持切换主题：
//   official  —— 现行深灰（默认，值与原状完全一致，零视觉回归）
//   pureBlack —— 纯黑省电（底色压到接近全黑，灰阶整体下移）
// 因为每个色都是绑定表达式，改 YColors.themeId 会让所有绑了令牌的界面立刻重绘。
// 注意：themeId 目前不持久化（重启回到 official），持久化由后续 C++ ThemeManager 负责。

QtObject {
    id: id_colors

    property string themeId: "official"

    readonly property var _official: ({
        "white": "#FFFFFF",
        "black": "#000000",
        "red": "#F03043",
        "orange": "#FF8B20",
        "green": "#13B876",
        "yellow": "#E9900C",
        "blueText": "#509DEB",
        "blueRect": "#2D73DC",
        "blueLink": "#62A8EA",
        "blueDeep": "#2B5278",
        "grayText": "#909199",
        "grayNormal": "#1A1B1F",
        "graySwitchOff": "#515259",
        "grayButton": "#2D2E33",
        "border": "#3F3F3F",
        "pressed": "#444444",
        "textSecondary": "#AAAAAA",
        "textMuted": "#666873",
        "scrim": "#88000000",
        "scrimStrong": "#CC000000",
        "scrimLight": "#4D000000"
    })

    readonly property var _pureBlack: ({
        "white": "#FFFFFF",
        "black": "#000000",
        "red": "#F03043",
        "orange": "#FF8B20",
        "green": "#13B876",
        "yellow": "#E9900C",
        "blueText": "#509DEB",
        "blueRect": "#2D73DC",
        "blueLink": "#62A8EA",
        "blueDeep": "#1E3A55",
        "grayText": "#8C8D95",
        "grayNormal": "#0A0A0C",
        "graySwitchOff": "#3C3D44",
        "grayButton": "#1A1B20",
        "border": "#2B2B30",
        "pressed": "#33343B",
        "textSecondary": "#A0A1A9",
        "textMuted": "#5E5F67",
        "scrim": "#88000000",
        "scrimStrong": "#CC000000",
        "scrimLight": "#4D000000"
    })

    readonly property var _p: themeId === "pureBlack" ? _pureBlack : _official

    readonly property string black: _p.black
    readonly property string white: _p.white

    readonly property string red: _p.red
    readonly property string orange: _p.orange

    readonly property Gradient redDict: Gradient {
        GradientStop {
            position: 0.0
            color: "#FA423C"
        }
        GradientStop {
            position: 1.0
            color: "#F03043"
        }
    }

    readonly property string green: _p.green
    readonly property string yellow: _p.yellow

    readonly property string blueText: _p.blueText
    readonly property string blueRect: _p.blueRect
    readonly property string blueLink: _p.blueLink
    readonly property string blueDeep: _p.blueDeep

    readonly property string grayText: _p.grayText
    readonly property string grayNormal: _p.grayNormal
    readonly property string graySwitchOff: _p.graySwitchOff
    readonly property string grayButton: _p.grayButton

    readonly property string border: _p.border
    readonly property string pressed: _p.pressed
    readonly property string textSecondary: _p.textSecondary
    readonly property string textMuted: _p.textMuted

    readonly property string scrim: _p.scrim
    readonly property string scrimStrong: _p.scrimStrong
    readonly property string scrimLight: _p.scrimLight
}
