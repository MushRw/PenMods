pragma Singleton

import QtQuick 2.12

// global color defineds, use as colorDefineds

QtObject {

    readonly property string black: "#000000"
    readonly property string white: "#FFFFFF"

    readonly property string red: "#F03043"
    readonly property string orange: "#FF8B20"

    readonly property Gradient redDict: Gradient {
        GradientStop { position: 0.0; color: "#FA423C" }
        GradientStop { position: 1.0; color: "#F03043" }
    }

    readonly property string green: "#13B876"

    readonly property string yellow: "#E9900C"

    readonly property string blueText: "#509DEB"
    readonly property string blueRect: "#2D73DC"

    readonly property string grayText: "#909199"
    readonly property string grayNormal: "#1A1B1F"
    readonly property string graySwitchOff: "#515259"
    readonly property string grayButton: "#2D2E33"

    // ---- 以下为"原先是各页面写死、现升格为令牌"的补充色 ----
    // 蓝色系（保留原设计：AI 助手已改红，其它页面继续用蓝）
    readonly property string blueLink: "#62A8EA"      // 浅蓝：链接、次要强调
    readonly property string blueDeep: "#2B5278"      // 深蓝底：选中、信息卡
    // 灰色系补充
    readonly property string border: "#3F3F3F"        // 分割线 / 细边框
    readonly property string pressed: "#444444"       // 按下态底色
    readonly property string textSecondary: "#AAAAAA" // 次级文字（比 grayText 亮一档）
    readonly property string textMuted: "#666873"     // 更弱的提示文字
    // 带透明度的遮罩
    readonly property string scrim: "#88000000"       // 半透明黑遮罩
    readonly property string scrimStrong: "#CC000000" // 更实的遮罩
    readonly property string scrimLight: "#4D000000"  // 轻遮罩
}
