import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

YTouchRegulator {
    id: id_volmue_adjustor

    readonly property int spkSettingVolume: settingManager.spkVolume

    property alias iconWidth: id_icon.width
    property alias iconHeight: id_icon.height
    property alias iconLeftMargin: id_icon.anchors.leftMargin
    property alias iconVisible: id_icon.visible

    YImage {
        id: id_icon
        sourceSize: Qt.size(30, 30)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16

        YMouseArea {
            anchors.fill: parent
            enabled: antiEmbs.fastMute
            onClicked: {
                settingManager.setSpkVolume(0)
            }
        }

        imageName: {
            if (0 === id_volmue_adjustor.value) {
                return "slide/volum_off"
            } else if (id_volmue_adjustor.value <= 50) {
                return "slide/volum_half"
            } else {
                return "slide/volum"
            }
        }
    }

    onValueChanged: {
        if (spkSettingVolume != value) {
            settingManager.setSpkVolume(value)
        }
    }

    onSpkSettingVolumeChanged: {
        if (spkSettingVolume !== value) {
            value = spkSettingVolume
        }
    }

    function rebinding() {
        value = Qt.binding(function(){ return spkSettingVolume })
    }

    Component.onCompleted: rebinding()
}
