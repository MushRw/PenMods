pragma Singleton

import QtQuick 2.12

// 全局配色。每个令牌都绑定到 C++ 侧 ThemeManager 的对应色值：
// 切主题时 ThemeManager 发 themeChanged，这些绑定自动重算，
// 所有绑了令牌的界面立刻重绘。主题 id 存在 config.json 的 theme.id。
QtObject {

    readonly property string black: theme.black
    readonly property string white: theme.white

    readonly property string red: theme.red
    readonly property string orange: theme.orange

    readonly property Gradient redDict: Gradient {
        GradientStop { position: 0.0; color: "#FA423C" }
        GradientStop { position: 1.0; color: theme.red }
    }

    readonly property string green: theme.green
    readonly property string yellow: theme.yellow

    readonly property string blueText: theme.blueText
    readonly property string blueRect: theme.blueRect
    readonly property string blueLink: theme.blueLink
    readonly property string blueDeep: theme.blueDeep

    readonly property string grayText: theme.grayText
    readonly property string grayNormal: theme.grayNormal
    readonly property string graySwitchOff: theme.graySwitchOff
    readonly property string grayButton: theme.grayButton

    readonly property string border: theme.border
    readonly property string pressed: theme.pressed
    readonly property string textSecondary: theme.textSecondary
    readonly property string textMuted: theme.textMuted

    readonly property string scrim: theme.scrim
    readonly property string scrimStrong: theme.scrimStrong
    readonly property string scrimLight: theme.scrimLight

    // ---- 透光（磨砂）表面 ----
    // 原版界面里"透光"的地方其实是 8 位 ARGB：`#99` + 不透明底色（如 #991A1B1F
    // = 60% 的 grayNormal）。这里不写死 8 位值，而是从主题令牌算出带 alpha 的版本，
    // 这样切主题时透光面也跟着主题走（写死 8 位值做不到）。
    // 用法：凡是"浮在壁纸/内容之上的容器"（抽屉、弹层、卡片）用它替不透明的
    // grayNormal / grayButton。
    readonly property color grayNormalAsColor: theme.grayNormal
    readonly property color grayButtonAsColor: theme.grayButton

    readonly property color glassLight: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b, 0.40)
    readonly property color glass: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b, 0.60)
    readonly property color glassStrong: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b, 0.92)
    readonly property color glassButton: Qt.rgba(grayButtonAsColor.r, grayButtonAsColor.g, grayButtonAsColor.b, 0.60)
}
