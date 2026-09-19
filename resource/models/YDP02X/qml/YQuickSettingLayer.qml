import QtQuick 2.12
import com.youdao.pen 1.0
import QtGraphicalEffects 1.14

import "./commons"
import "./components"

Item {
    id: id_quick_setting_layer_root
    width: YEnum.Screen.Width
    height: YEnum.Screen.Height
    state: "close"

    readonly property bool isOpening: ("open" === state)

    property alias fastBlurTarget: id_fast_blur.source

    // ---- 状态行（左上角：日期 / 时间 / 电量）----
    property string timeString: "00:00"
    property string dateString: ""

    function _tickClock() {
        var now = new Date();
        var weekDays = ["日", "一", "二", "三", "四", "五", "六"];
        timeString = Qt.formatTime(now, "HH:mm");
        dateString = (now.getMonth() + 1) + "月" + now.getDate() + "日 周" + weekDays[now.getDay()];
    }

    // 20 秒刷一次足够（分针级），比每秒刷省电
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

    FastBlur {
        id: id_fast_blur
        anchors.fill: parent
        radius: 16
    }

    // 遮罩：原来硬编码 #E6000000（90% 黑），改为跟主题令牌走
    Rectangle {
        anchors.fill: parent
        color: YColors.scrimStrong
    }

    // ================= 左上角状态行：日期 / 时间 / 电量 =================
    Row {
        id: id_status_row
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.topMargin: 10
        spacing: 10

        YText {
            anchors.verticalCenter: parent.verticalCenter
            text: id_quick_setting_layer_root.dateString
            font.pixelSize: 12
            color: YColors.textSecondary
        }

        YText {
            anchors.verticalCenter: parent.verticalCenter
            text: id_quick_setting_layer_root.timeString
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: YColors.white
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 12
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: YColors.textSecondary

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, (parent.width - 4) * Math.min(1, batteryManager.power / 100))
                    height: parent.height - 4
                    radius: 1
                    color: batteryManager.charging ? YColors.green : YColors.white
                }
            }

            YText {
                anchors.verticalCenter: parent.verticalCenter
                text: batteryManager.power + "%"
                font.pixelSize: 12
                color: batteryManager.charging ? YColors.green : YColors.textSecondary
            }
        }
    }

    // ================= 左侧：两个 45° 倾斜的滑块（音量 / 亮度）=================
    Item {
        id: id_slider_area
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.top: id_status_row.bottom
        anchors.bottom: parent.bottom
        width: 196

        // 音量：底座隐藏自带图标（它是水平布局的，旋转后会歪），图标另放
        YVolmueAdjustor {
            id: id_volum_setting
            implicitWidth: 104
            implicitHeight: 18
            rotation: -45
            iconVisible: false
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -46
            anchors.verticalCenterOffset: 20
        }

        // 亮度
        YTouchRegulator {
            id: id_lum_setting
            implicitWidth: 104
            implicitHeight: 18
            rotation: -45
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 46
            anchors.verticalCenterOffset: -20

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
        }

        // 不旋转的小图标（跟着滑块会歪，所以单独放）
        YImage {
            sourceSize: Qt.size(22, 22)
            width: 22
            height: 22
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.bottomMargin: 4
            imageName: {
                if (0 === id_volum_setting.value)
                    return "slide/volum_off";
                if (id_volum_setting.value <= 50)
                    return "slide/volum_half";
                return "slide/volum";
            }
        }

        YImage {
            sourceSize: Qt.size(22, 22)
            width: 22
            height: 22
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 6
            anchors.topMargin: 4
            imageName: {
                if (0 === id_lum_setting.value)
                    return "slide/lum_off";
                if (id_lum_setting.value <= 50)
                    return "slide/lum_half";
                return "slide/lum";
            }
        }
    }

    // ================= 右侧：三个按钮（WiFi / 蓝牙 / 主题）=================
    Column {
        id: id_right_buttons
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        YSlideWifiSetting {
            id: id_slide_wifi
            anchors.horizontalCenter: parent.horizontalCenter
        }

        YSlideBluetoothSetting {
            id: id_slide_bluetooth
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 主题切换（PenMods 自己的令牌系统：官方深灰 / 纯黑省电）
        Rectangle {
            id: id_theme_button
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46
            height: 26
            radius: 13
            color: YColors.glassButton
            border.width: 1
            border.color: YColors.border

            YText {
                anchors.centerIn: parent
                font.pixelSize: 11
                color: YColors.white
                text: ("pureBlack" === theme.id) ? "纯黑" : "深灰"
            }

            YMouseArea {
                anchors.fill: parent
                onClicked: {
                    theme.id = ("pureBlack" === theme.id) ? "official" : "pureBlack";
                    qmlGlobal.showToast("主题：" + (("pureBlack" === theme.id) ? "纯黑省电" : "官方深灰"));
                }
            }
        }
    }

    // ================= 底部：收起指示（点一下收起）=================
    YImage {
        id: id_collapse_indicator
        sourceSize: Qt.size(40, 10)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        imageName: "slide/ic_collapse"
    }

    YMouseArea {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: 80
        height: 24
        onClicked: id_quick_setting_layer_root.forceClose()
    }
}
