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
        duration: 120
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

    Rectangle {
        anchors.fill: parent
        color: "#E6000000"
    }

    Grid {
        anchors.top: parent.top
        columns: 2
        rows: 2
        rowSpacing: 12
        columnSpacing: 24
        padding: 20

        YVolmueAdjustor {
            id: id_volum_setting
        }

        YSlideWifiSetting {
            id: id_slide_wifi
        }

        YTouchRegulator {
            id: id_lum_setting
            property int lcdSettingBrightness: settingManager.lcdBrightness
            YImage {
                sourceSize: Qt.size(30, 30)
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                imageName: {
                    if (0 === id_lum_setting.value) {
                        return "slide/lum_off"
                    } else if (id_lum_setting.value <= 50) {
                        return "slide/lum_half"
                    }  else {
                        return "slide/lum"
                    }
                }
            }
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


        YSlideBluetoothSetting {
            id: id_slide_bluetooth
        }
    }


    YImage {
        sourceSize: Qt.size(40, 10)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        imageName: "slide/ic_collapse"
    }
}

