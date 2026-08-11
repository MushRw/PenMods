import QtQuick 2.12

import "../commons"
import "../components"

YMouseArea {
    id: id_adjustor_bg
    implicitWidth: 360
    implicitHeight: 80
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    readonly property bool isShowing: "show" === id_adjustor.state

    function show() {
        if (!isShowing) {
            id_adjustor.state = "show"
            id_showing_timer.restart()
        }
    }

    function close() {
        id_adjustor.state = "close"
    }

    YTimer {
        id: id_showing_timer
        interval: 1500
        onTriggered: {
            id_adjustor.state = "closing"
        }
        objectName: "YAudioPlayerVolumeBar.qml_id_showing_timer"
    }

    YVolmueAdjustor {
        id: id_adjustor
        implicitWidth: 300
        implicitHeight: 44
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 18
        iconWidth: 32
        iconHeight: 32
        iconLeftMargin: 20
        state: "close"

        onSpkSettingVolumeChanged: {
            if (isShowing) {
                id_showing_timer.restart()
            }
        }

        onPressedChanged: {
            if (isShowing) {
                if (id_adjustor.pressed) {
                    id_showing_timer.stop()
                } else {
                    id_showing_timer.restart()
                }
            }
        }

        states: [
            State {
                name: "close"
                PropertyChanges {
                    target: id_adjustor_bg
                    enabled: false
                    visible: false
                    opacity: 1
                }
                PropertyChanges {
                    target: id_adjustor
                    height: 44
                    iconVisible: true
                }
            }, State {
                name: "closing"
                PropertyChanges {
                    target: id_adjustor_bg
                    enabled: false
                    opacity: 0
                }
                PropertyChanges {
                    target: id_adjustor
                    height: 12
                    iconVisible: false
                }
            }, State {
                name: "show"
                PropertyChanges {
                    target: id_adjustor_bg
                    enabled: true
                    opacity: 1
                    visible: true
                }
                PropertyChanges {
                    target: id_adjustor
                    height: 44
                    iconVisible: true
                }
            }
        ]

        transitions: [
            Transition {
                from: "show"
                to: "closing"
                SequentialAnimation {
                    NumberAnimation { properties: "height"; duration: 480 }
                    NumberAnimation { properties: "opacity"; duration: 1200 }
                    ScriptAction { script: id_adjustor_bg.close() }
                }
            }
        ]
    }
}
