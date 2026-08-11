import QtQuick 2.12

import "../commons"
import "../i18n"

YLoader {
    id: id_connect_wifi_loader
    anchors.fill: parent

    property string wifiName: ""

    sourceComponent: YBackgroundIgnoreMouseEvent {

        Item {
            id: id_title_bar
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: 50

            YText {
                font.pixelSize: 16
                color: YColors.grayText
                anchors.verticalCenter: parent.verticalCenter
                text: YTranslateText.configWifi
            }
        }

        YSettingItemBackground {
            id: id_connect_wifi_item
            implicitHeight: 52
            anchors.top: id_title_bar.bottom

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: id_connect_wifi_icon.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                YTextMedium {
                    text: wifiName
                    anchors.left: parent.left
                    anchors.right: parent.right
                    elide: YText.ElideRight
                }

                YText {
                    font.pixelSize: 14
                    color: YColors.grayText
                    text: YTranslateText.connectSuccess
                }
            }

            YImage {
                id: id_connect_wifi_icon
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                sourceSize: Qt.size(30, 30)
                imageName: "settings/st-check"
            }
        }

        onClicked: {
            id_connect_wifi_loader.active = false
        }

        YButton {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_connect_wifi_item.bottom
            anchors.topMargin: 8
            text: YTranslateText.ignoreThisWifi
            onClicked: {
                wifiManager.ignore(wifiName)
                active = false
            }
        }
    }
}