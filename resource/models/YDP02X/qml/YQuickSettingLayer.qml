import QtQuick 2.12
import com.youdao.pen 1.0
import QtGraphicalEffects 1.14

import "./commons"
import "./components"

// 下拉快速设置面板
//
// 布局（320x170，屏幕边距 16、节奏 8）：
//   · 左上竖排：时间（大）→ 日期 → 电量 + 百分比
//   · 中间两条 45° 胶囊（音量在左下、亮度在右上），图标在胶囊左端并反向旋转保持正立
//   · 右侧两个圆：WiFi（上）/ 蓝牙（下），圆心 (272,54)/(272,124)、半径 26
//   · 左下空档放主题切换
//
// 几何约束（按参考图重算，参考图那版状态块与胶囊外接框是重叠的）：
//   胶囊外接框 = (100+24)/±√2 ≈ ±44，所以：
//     状态块 x 16..104 / y 10..76
//     音量圆心 (150,80) -> 外接框 106..194 / 36..124
//     亮度圆心 (198,116) -> 外接框 154..242 / 72..160
//     右侧圆     x 246..298
//   两条胶囊的垂直间距 = |Δx+Δy|·0.707 ≈ 59 > 胶囊厚度 24，所以视觉上不会压在一起。
Item {
    id: id_quick_setting_layer_root
    width: YEnum.Screen.Width
    height: YEnum.Screen.Height
    state: "close"

    readonly property bool isOpening: ("open" === state)

    // 背景内容（YFastBlurRectangle 实时取景用），由 YMainWindow 注入
    property Item backdropItem: null

    // ---- 状态块（时间 / 日期 / 电量）----
    property string timeString: "00:00"
    property string dateString: ""
    property string shortDateString: ""

    function _tickClock() {
        var now = new Date();
        var weekDays = ["日", "一", "二", "三", "四", "五", "六"];
        timeString = Qt.formatTime(now, "HH:mm");
        dateString = now.getFullYear() + "/" + (now.getMonth() + 1) + "/" + now.getDate()
                + " 周" + weekDays[now.getDay()];
        shortDateString = (now.getMonth() + 1) + "/" + now.getDate() + " 周" + weekDays[now.getDay()];
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: id_quick_setting_layer_root._tickClock()
    }

    Component.onCompleted: _tickClock()

    function close() {
        if ("open" === state) {
            forceClose()
        }
    }

    function open() {
        if ("close" === state) {
            reopen()
        }
    }

    function reopen() {
        state = "openning"
        id_open_close_animator.to = 0
        id_open_close_animator.restart()
        _tickClock()
        settingManager.updateVolumeAndLcd()
    }

    function forceClose() {
        state = "closing"
        id_volum_setting.rebinding()
        id_lum_setting.rebinding()
        id_open_close_animator.to = - id_quick_setting_layer_root.height
        id_open_close_animator.restart()
    }

    YMouseArea {
        anchors.fill: parent
        drag.target: id_quick_setting_layer_root
        drag.axis: Drag.YAxis
        drag.minimumY: - id_quick_setting_layer_root.height
        drag.maximumY: 0
        objectName: "YQuickSettingLayer.qml_YMouseArea"
        enabled: settingManager.isVerified
        property real pressedY: 0
        onPressed: {
            pressedY = id_quick_setting_layer_root.y
            id_check_timer.restart()
        }

        onReleased: {
            doReleased()
        }

        onCanceled: {
            doReleased()
        }

        YTimer {
            id: id_check_timer
            interval: 300
            objectName: "YQuickSettingLayer.qml_id_check_timer"
        }

        function doReleased() {
            if (id_quick_setting_layer_root.y < - id_quick_setting_layer_root.height / 5
                    || (id_check_timer.running
                        && (pressedY - id_quick_setting_layer_root.y > 10))) {
                id_quick_setting_layer_root.forceClose()
            } else {
                id_quick_setting_layer_root.reopen()
            }
        }
    }

    YAnimator {
        id: id_open_close_animator
        target: id_quick_setting_layer_root
        from: id_quick_setting_layer_root.y
        to: - id_quick_setting_layer_root.height
        duration: 200
        running: false
        alwaysRunToEnd: true
        onRunningChanged: {
            if (!running) {
                if ("openning" === id_quick_setting_layer_root.state) {
                    id_quick_setting_layer_root.state = "open"
                } else if ("closing" === id_quick_setting_layer_root.state) {
                    id_quick_setting_layer_root.state = "close"
                }
            }
        }
    }

    // 面板表面：统一走 commons/YFastBlurRectangle（与插件抽屉、听力练习左侧栏同一份实现）
    // 毛玻璃档是实时模糊：取景框用面板根节点的 y 显式绑定，面板滑动时跟着重算，
    // 模糊内容钉在背景上（不能用 mapToItem：QML 依赖追踪抓不到它，取景框会永久停在屏外）
    YFastBlurRectangle {
        anchors.fill: parent
        backdrop: id_quick_setting_layer_root.backdropItem
        sourceY: id_quick_setting_layer_root.y
    }

    // ================= 左上：时间 / 日期 / 电量（竖排）=================
    Column {
        id: id_status_block
        anchors.left: parent.left
        anchors.top: parent.top
        // 时间和电量往角上再靠一点
        anchors.leftMargin: 10
        anchors.topMargin: 8
        spacing: 4

        // 时间 + 日期压成一行（第二次改），电量仍两行，放在下方
        Row {
            spacing: 6

            YText {
                anchors.verticalCenter: parent.verticalCenter
                text: id_quick_setting_layer_root.timeString
                font.pixelSize: 20
                font.weight: Font.Bold
                color: YColors.white
            }

            YText {
                anchors.verticalCenter: parent.verticalCenter
                text: id_quick_setting_layer_root.shortDateString
                font.pixelSize: 10
                color: YColors.textSecondary
            }
        }

        // 电量：间距照原版标题栏（百分比 —12px— 电池框 —0px— 充电闪电，闪电紧贴框）
        Row {
            spacing: 12

            YText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 16
                text: ("%1%").arg(batteryManager.power)
                width: paintedWidth
                height: paintedHeight
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 14
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: YColors.white

                    Item {
                        width: 22
                        height: 8
                        anchors.centerIn: parent

                        Item {
                            anchors.fill: parent
                            clip: true
                            anchors.rightMargin: (100 - batteryManager.power) * 22 / 100

                            Rectangle {
                                width: 22
                                height: 8
                                radius: height / 2
                                color: {
                                    if (batteryManager.charging)
                                        return (100 > batteryManager.power) ? "#00FF66" : YColors.white;
                                    return (20 > batteryManager.power) ? YColors.red : YColors.white;
                                }
                            }
                        }
                    }
                }

                YImage {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(14, 14)
                    width: 14
                    height: 14
                    imageName: "ic_battery_flash"
                    visible: batteryManager.charging
                }
            }
        }
    }

    // ================= 两条 45° 胶囊：音量（左下）/ 亮度（右上）=================
    // 音量
    YVolmueAdjustor {
        id: id_volum_setting
        implicitWidth: 170
        implicitHeight: 44
        rotation: -45
        iconVisible: false
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
        // 整组右移（圆也右移后解锁）：中心 94 -> 112，间距 73 不变 -> 仍是约 7.6px
        anchors.horizontalCenterOffset: 112
        anchors.verticalCenterOffset: 85

        YImage {
            sourceSize: Qt.size(24, 24)
            width: 24
            height: 24
            rotation: 45
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            imageName: {
                if (0 === id_volum_setting.value)
                    return "slide/volum_off";
                if (id_volum_setting.value <= 50)
                    return "slide/volum_half";
                return "slide/volum";
            }
        }
    }

    // 亮度
    YTouchRegulator {
        id: id_lum_setting
        implicitWidth: 170
        implicitHeight: 44
        rotation: -45
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
        // 厚度 44，中心距 73（间距不变）；整组右移：中心 167 -> 185
        anchors.horizontalCenterOffset: 185
        anchors.verticalCenterOffset: 85

        property int lcdSettingBrightness: settingManager.lcdBrightness

        onValueChanged: {
            if (lcdSettingBrightness != value) {
                settingManager.setLcdBrightness(value)
            }
        }
        onLcdSettingBrightnessChanged: {
            if (lcdSettingBrightness != value) {
                value = lcdSettingBrightness
            }
        }

        function rebinding() {
            value = Qt.binding(function(){ return lcdSettingBrightness })
        }

        Component.onCompleted: rebinding()

        YImage {
            sourceSize: Qt.size(24, 24)
            width: 24
            height: 24
            rotation: 45
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            imageName: {
                if (0 === id_lum_setting.value)
                    return "slide/lum_off";
                if (id_lum_setting.value <= 50)
                    return "slide/lum_half";
                return "slide/lum";
            }
        }
    }

    // ================= 右侧两个按钮：WiFi（上）/ 蓝牙（下）=================
    // 底样式照原版 YButtonBase / YThreeStatesButton：关闭=grayNormal 灰底，开启=蓝渐变
    // #4DA0FF->#457AE6；但按用户要求做成**圆形**（radius = width/2）。
    Item {
        id: id_wifi_button
        width: 52
        height: 52
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
        anchors.horizontalCenterOffset: 290
        anchors.verticalCenterOffset: 54

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: YColors.surface
            visible: !wifiManager.onoff
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: wifiManager.onoff
            gradient: Gradient {
                GradientStop { position: 0.0; color: YColors.accentTop }
                GradientStop { position: 1.0; color: YColors.accentBottom }
            }
        }

        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(26, 26)
            width: 26
            height: 26
            imageName: wifiManager.onoff ? "slide/wifi_on" : "slide/wifi_off"
        }

        YMouseArea {
            anchors.fill: parent
            onClicked: {
                if (wifiManager.onoff)
                    wifiManager.turnOff();
                else
                    wifiManager.turnOn();
            }
            onPressAndHold: qmlGlobal.requestSettingPage(YEnum.SettingIndex.Network)
        }
    }

    Item {
        id: id_bt_button
        width: 52
        height: 52
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
        anchors.horizontalCenterOffset: 290
        anchors.verticalCenterOffset: 124

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: YColors.surface
            visible: !blueToothManager.onoff
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: blueToothManager.onoff
            gradient: Gradient {
                GradientStop { position: 0.0; color: YColors.accentTop }
                GradientStop { position: 1.0; color: YColors.accentBottom }
            }
        }

        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(26, 26)
            width: 26
            height: 26
            imageName: blueToothManager.onoff ? "slide/bt_on" : "slide/bt_off"
        }

        YMouseArea {
            anchors.fill: parent
            onClicked: {
                if (blueToothManager.onoff)
                    blueToothManager.turnOff();
                else
                    blueToothManager.turnOn();
            }
            onPressAndHold: qmlGlobal.requestSettingPage(YEnum.SettingIndex.Bluetooth)
        }
    }

    // 主题切换按钮暂不放（等布局定稿后再加）
}
