import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./utils"
import "./i18n"

YWindow {
    rotation: settingManager.isRightHandMode ? 0 : 180
    default property alias content: id_inner_item.data

    property int battaryPower: 0
    readonly property int battaryPercentage: batteryManager.power
    readonly property bool battaryChanging: batteryManager.charging
    readonly property bool quickSettingOpening: id_quick_setting_layer.isOpening
    readonly property bool isVerifiyFinished: settingManager.isVerified && (qmlGlobal.currentPageIndex !== YEnum.PageIndex.Verify)

    function closeQuickSetting() {
        if (id_quick_setting_layer.isOpening) {
            id_quick_setting_layer.close()
            return true
        }
        return false
    }

    function openQuickSetting() {
        if (!id_quick_setting_layer.isOpening) {
            id_quick_setting_layer.open()
        }
    }

    function closeTipDialog() {
        id_speech_need_network_loader.setInactive()
        id_battery_power_low_loader.setInactive()
    }

    function delayInitMainWindow() {
        id_speech_need_network_loader.source = "commons/YOneButtonDialog.qml"

        id_battery_power_low_loader.source = "commons/YOneButtonDialog.qml"
    }

    Item {
        id: id_inner_item
        anchors.fill: parent
    }

    ShaderEffectSource {
        id: id_effect_source
        anchors.fill: parent
        sourceItem: id_inner_item
        sourceRect: Qt.rect(0 , 0 + id_quick_setting_layer.y, width, height)
        visible: false
    }

    YQuickSettingLayer {
        id: id_quick_setting_layer
        y: - id_quick_setting_layer.height
        fastBlurTarget: id_effect_source
    }

    YMouseArea {
        id: id_drag_show_quick_setting
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 80
        height: 8
        drag.target: id_quick_setting_layer
        drag.axis: Drag.YAxis
        drag.minimumY: - id_quick_setting_layer.height
        drag.maximumY: 0
        enabled: isVerifiyFinished
        objectName: "YMainWindow.qml_id_drag_show_quick_setting"

        property real pressedY: 0
        onPressed: {
            pressedY = id_quick_setting_layer.y
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
            objectName: "YMainWindow.qml_id_check_timer"
            interval: 300
        }

        function doReleased() {
            if (id_quick_setting_layer.y > - id_quick_setting_layer.height * 4.0/5
                    || (id_check_timer.running
                        && (id_quick_setting_layer.y - pressedY > 10))) {
                id_quick_setting_layer.reopen()
            } else {
                id_quick_setting_layer.forceClose()
            }
        }
    }

    YLoader {
        id: id_speech_need_network_loader
        anchors.fill: parent
        onLoaded: {
            item.tipItem.text = YTranslateText.speechNeedNetWork
            item.buttonItem.text = YTranslateText.configWifi
            item.clicked.connect(function() {
                qmlGlobal.requestSettingPage(YEnum.SettingIndex.Network)
                id_speech_need_network_loader.setInactive()
            })
            item.closed.connect(function() { id_speech_need_network_loader.active = false })
            item.show()
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        function onRequestSpeechNeedNetWork() {
            id_speech_need_network_loader.setActive()
        }

        function onRequestShowScanGuide() {
            if (null === id_scan_guide_container.scanGuideItem) {
                function newComponentInit(incubatorObject) {
                    if (null === id_scan_guide_container.scanGuideItem) {
                        incubatorObject.callBack.connect(id_scan_guide_container.closeScanGuide)
                        systemBase.homeKeyPress.connect(id_scan_guide_container.closeScanGuide)
                        systemBase.homeKeyLongPress.connect(id_scan_guide_container.closeScanGuide)
                        id_scan_words_result_loader.ocrStart.connect(id_scan_guide_container.closeScanGuide)
                        id_scan_guide_container.closeAllScanGuide.connect(incubatorObject.stop)
                        id_scan_guide_container.scanGuideItem = incubatorObject
                    }
                    id_scan_guide_container.showScanGuide()
                }

                const incubator = id_scan_guide_component.incubateObject(id_scan_guide_container)
                if (incubator.status !== Component.Ready) {
                    incubator.onStatusChanged = function(status) {
                        if (status === Component.Ready) {
                            newComponentInit(incubator.object)
                        }
                    }
                } else {
                    newComponentInit(incubator.object)
                }
            } else {
                id_scan_guide_container.showScanGuide()
            }
        }
    }

    YLoader {
        id: id_battery_power_low_loader
        anchors.fill: parent
        onLoaded: {
            item.tipItem.text = YTranslateText.batteryPowerLow.arg(battaryPower)
            item.buttonItem.text = YTranslateText.ok
            item.clicked.connect(function() { id_battery_power_low_loader.active = false })
            item.closed.connect(function() { id_battery_power_low_loader.active = false })
            item.show()
        }
    }

    Connections {
        target: batteryManager
        ignoreUnknownSignals: true
        function onLowPower(power) {
            if (!battaryChanging) {
                battaryPower = power
                id_battery_power_low_loader.setActive()
            }
        }
    }

    Item {
        id: id_scan_guide_container
        anchors.fill: parent
        visible: false
        property var scanGuideItem: null
        signal closeAllScanGuide()
        function closeScanGuide() {
            if (null !== scanGuideItem) {
                visible = false
                scanGuideItem.stop()
                closeAllScanGuide()
            }
        }
        function showScanGuide() {
            if (null !== scanGuideItem) {
                scanGuideItem.play()
                visible = true
            }
        }
    }

    Component {
        id: id_scan_guide_component
        YScanGuidePage {
        }
    }

    YLoader {
        id: id_toast_loader
        width: parent.width
        height: parent.height
        active: true
        sourceComponent: YToast {}
    }

    // above is virtual
    YMap {
        id: id_global_map
        Component.onCompleted: {
            YUtils.globalMap = id_global_map
        }
    }

    YMap {
        id: id_stack_map
        Component.onCompleted: {
            YUtils.stackMap = id_stack_map
        }
    }

    YTimer {
        id: id_sound_center_playing_check_timer
        interval: 1800
        repeat: true
        onTriggered: {
            if (!soundCenter.isPlaying()) {
                qmlGlobal.soundCenterNotPlayingBroadcast()
                id_sound_center_playing_check_timer.stop()
            }
        }
        Component.onCompleted: {
            YUtils.soundCenterPlayingCheckTimer
                    = id_sound_center_playing_check_timer
        }
        objectName: "YMainWindow.qml_id_sound_center_playing_check_timer"
    }
}
