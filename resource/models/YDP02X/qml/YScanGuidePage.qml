import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"

YBackgroundIgnoreMouseEvent {
    anchors.fill: parent
    function play() {
        id_scan_guide_animation.play()
    }
    function stop() {
        id_scan_guide_animation.stopPlay()
    }

    signal callBack()

    YBackButton {
        width: 46
        isPositionLeftBar: true
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: id_scan_guide_animation.running ? 0 : YEnum.Screen.Width
        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: 300
            }
        }
        backButtonMouseAreaItem.anchors.topMargin: -12
        onClicked: {
            callBack()
            qmlGlobal.requestHideScanGuide()
        }
    }

    YAnimatedImagesView {
        id: id_scan_guide_animation
        objectName: "YScanGuidePage.qml"
        anchors.fill: parent
        anchors.leftMargin: running ? 0 : YEnum.Screen.Width
        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: 300
            }
        }
        frameSize: Qt.size(YEnum.Screen.Width, YEnum.Screen.Height)
        frameCountLoop: 150
        imageNameLoop: "scan_guide"
        clip: false
    }
}
