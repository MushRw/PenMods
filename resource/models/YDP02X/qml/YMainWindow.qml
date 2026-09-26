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

    YQuickSettingLayer {
        id: id_quick_setting_layer
        y: - id_quick_setting_layer.height
        // 合并上游：快速设置面板毛玻璃改用 fastBlurTarget（内部 FastBlur），
        // 取景对象 = 主窗口内容容器（等效旧 backdropItem 实时取景语义）
        fastBlurTarget: id_inner_item
    }

    YMouseArea {
        id: id_drag_show_quick_setting
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 40
        height: 14
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

    // ================= 屏幕四边描边光（漏光感）=================
    // 窗口级、纯视觉层：没有 MouseArea，不吃事件。
    //
    // 为什么不用复现当年那个 transparentBorder "漏光" bug：那个是模糊取景越界
    // 采样到透明导致的边缘混色，只在毛玻璃档出现、且颜色随背后内容变化 —— 拿它
    // 当效果不稳定。这里把它的观感用固定的距离衰减重建：三档材质下表现一致。
    //
    // 做法：一个全屏 ShaderEffect，取到四边的最小距离 d，a = (1 - d/edge)^1.6，
    // 越靠边越亮；四角 dx、dy 都小 → 自然叠加成更亮的角。
    // 想调：只改 edgeWidth / glowAlpha / glowColor 三处。
    ShaderEffect {
        id: id_edge_glow
        anchors.fill: parent

        property real edgeWidth: 22.0
        property real glowAlpha: 0.16
        property color glowColor: YColors.white
        property real viewW: width
        property real viewH: height

        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform lowp float qt_Opacity;
            uniform highp float edgeWidth;
            uniform highp float glowAlpha;
            uniform lowp vec4 glowColor;
            uniform highp float viewW;
            uniform highp float viewH;
            void main() {
                highp vec2 p = qt_TexCoord0 * vec2(viewW, viewH);
                highp float dx = min(p.x, viewW - p.x);
                highp float dy = min(p.y, viewH - p.y);
                highp float d = min(dx, dy);
                highp float a = clamp(1.0 - d / edgeWidth, 0.0, 1.0);
                a = pow(a, 1.6) * glowAlpha;
                gl_FragColor = vec4(glowColor.rgb * a, a) * qt_Opacity;
            }"
    }
}
