import QtQuick 2.12
import QtGraphicalEffects 1.14
import com.youdao.pen 1.0

Item {    
    YBackgroundIgnoreMouseEvent {
        anchors.fill: parent
        opacity: 0.6
        visible: id_error_tip_timer.running
    }

    Rectangle {
        id: id_global_toast
        implicitHeight: id_tip_content.contentHeight + 30
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        radius: 50
        color: "#E9900C"
        visible: false
        property bool showing: false
        function show(qsMsg, clrBg) {
            id_global_toast.color = clrBg
            id_tip_content.text = qsMsg
            showing = true
            visible = true
            anchors.bottomMargin = (YEnum.Screen.Height - id_global_toast.height) / 2
            id_error_tip_timer.restart()
        }
        YText {
            id: id_tip_content
            anchors.centerIn: parent
            width: 240
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
            color: YColors.white
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: 360
                onStopped: {
                    if (id_global_toast.showing) {
                        id_global_toast.visible = false
                        id_global_toast.showing = false
                    }
                }
            }
        }
        YTimer {
            id: id_error_tip_timer
            interval: 960
            objectName: "YToast.qml_id_error_tip_timer"
            onTriggered: {
                id_global_toast.anchors.bottomMargin = -id_global_toast.height
            }
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        function onShowToast(qsMsg, clrBg) {
            id_global_toast.show(qsMsg, clrBg)
        }
    }
}
