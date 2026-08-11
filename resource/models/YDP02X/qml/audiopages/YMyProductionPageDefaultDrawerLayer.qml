import QtQuick 2.12

import "../commons"
import "../i18n"

YBackground {
    id: id_drawer_layer
    anchors.fill: parent
    visible: false

    property string columnId: ""
    property string columnTitle: ""

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }

    YIconButton {
        id: id_close_button
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        color: YColors.grayNormal
        mouseAreaMargins: -10
        imageName: "commons/close"
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 8
        sourceSize: Qt.size(24, 24)
        onClicked: {
            hide()
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YText {
            id: id_title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
            width: parent.width
            height: 78
            wrapMode: YText.Wrap
            horizontalAlignment: YText.AlignHCenter
            verticalAlignment: YText.AlignVCenter
            text: YTranslateText.myProductionAudiosFilter.arg(columnTitle)
        }

        Row {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 8

            YButton {
                implicitWidth: 120
                color: "#2D2E33"
                text: YTranslateText.cancel
                onClicked: {
                    hide()
                }
            }

            YButton {
                id: id_remove_button
                implicitWidth: 120
                text: YTranslateText.confirm
                onClicked: {
                    logManager.sendHttpLog("action=listening_make_bag_setting_click")
                    columnManager.setDefaultScanning(columnId)
                    hide()
                }
            }
        }
    }

}
