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

    // ---- 表面风格（跟随 theme.surfaceStyle：opaque / translucent / glass）----
    // 全树所有"面板 / 卡片 / 浮层"的背景都应该用下面这些令牌，
    // 不要再自己写 8 位 ARGB（历史上散落了 #992D2E33、#991A1B1F、#661A1B1F、#CC1A1B1F…）。
    // glass 模式额外由 glassEnabled / glassRadius 打开毛玻璃模糊。
    readonly property color grayNormalAsColor: theme.grayNormal
    readonly property color grayButtonAsColor: theme.grayButton

    readonly property string surfaceStyle: theme.surfaceStyle
    readonly property bool glassEnabled: ("glass" === surfaceStyle)
    readonly property real surfaceAlpha: theme.surfaceAlpha

    readonly property color surface: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b, surfaceAlpha)
    readonly property color surfaceButton: Qt.rgba(grayButtonAsColor.r, grayButtonAsColor.g, grayButtonAsColor.b, surfaceAlpha)
    // 面板/抽屉这类浮在最上层的表面比卡片更实一点（半透时 0.92）
    readonly property color surfaceStrong: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b,
                                                   (1.0 === surfaceAlpha) ? 1.0 : 0.92)
    // 面板遮罩：不透明模式下全黑，否则保留改造前的 90% 黑
    readonly property color scrimPanel: Qt.rgba(0, 0, 0, ("opaque" === surfaceStyle) ? 1.0 : 0.9)
    // 菜单 / 浮层这类深色表面（原 "#AA000000" 一族）：不透明模式=实黑
    readonly property color surfaceDark: Qt.rgba(0, 0, 0, ("opaque" === surfaceStyle) ? 1.0 : 0.72)
    // 毛玻璃模糊强度：三个浮层表面（下拉面板 / 插件抽屉 / 听力练习左侧栏）
    // 共用同一个值，不然三处"模糊程度不一样"
    readonly property int glassBlurRadius: 14
    // 浮层大表面（下拉面板 / 插件抽屉 / 听力练习左侧栏）：比卡片实，别太透；
    // 毛玻璃档留 25% 给背后的模糊透出来
    readonly property color surfacePanel: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b,
                                                  ("opaque" === surfaceStyle) ? 1.0
                                                                              : (("glass" === surfaceStyle) ? 0.82 : 0.90))
    // 毛玻璃模糊半径（0 = 不模糊）
    readonly property int glassRadius: glassEnabled ? 16 : 0

    // 原版开关类按钮「开启」态的蓝渐变（YThreeStatesButton 的 #4DA0FF -> #457AE6），
    // 按当前材质的透明度派生：不透明模式=实色，半透明/毛玻璃=60%，随设置自动变。
    readonly property color accentTop: Qt.rgba(0x4D / 255, 0xA0 / 255, 0xFF / 255, surfaceAlpha)
    readonly property color accentBottom: Qt.rgba(0x45 / 255, 0x7A / 255, 0xE6 / 255, surfaceAlpha)

    // ---- 兼容别名（改造期间旧名继续可用，逐文件替换后可删）----
    readonly property color glassLight: Qt.rgba(grayNormalAsColor.r, grayNormalAsColor.g, grayNormalAsColor.b, 0.40)
    readonly property color glass: surface
    readonly property color glassStrong: surfaceStrong
    readonly property color glassButton: surfaceButton
}
