import QtQuick 2.12

import "../commons"
import "../i18n"

YLoader {
    id: id_connect_wifi_loader
    anchors.fill: parent

    property string devName: ""
    property string addrName: ""
    property bool isDisconnectting: false

    signal callPositionViewAtBeginning()

    sourceComponent: YBackgroundIgnoreMouseEvent {
        Item {
            id: id_title_bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin:10
            implicitHeight:40
            YBackButton {
                id: id_back_button
                //backButtonMouseAreaItem.anchors.leftMargin: -12
                onClicked: {
                    isDisconnectting = false
                    active = false
                }
            }

            YText {
                font.pixelSize: 16
                color: YColors.grayText
                anchors.left:parent.left
                anchors.leftMargin:40
                anchors.verticalCenter: id_back_button.verticalCenter
                text: YTranslateText.bluetooth
            }
            
        }

        YSettingItemBackground {
            id: id_connect_wifi_item
            implicitHeight: 52
            anchors.leftMargin: 50
            anchors.rightMargin: 10
            anchors.top: id_title_bar.bottom
            anchors.topMargin:10

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: id_connect_wifi_icon.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                YTextMedium {
                    text: devName
                    anchors.left: parent.left
                    anchors.right: parent.right
                    elide: YText.ElideRight
                }

                YTextBase {
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

        YButton {
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.top: id_connect_wifi_item.bottom
            anchors.topMargin: 8
            enabled: !isDisconnectting
            text: !isDisconnectting ? YTranslateText.ignoreThisDevice
                                    : YTranslateText.disconneting
            onClicked: {
                isDisconnectting = true
                blueToothManager.ignore(addrName)
            }
        }
    }

    Connections {
        target: blueToothManager
        ignoreUnknownSignals: true
        enabled: id_connect_wifi_loader.active
        onDisconnectFinished: {
            if (addrName === addr) {
                if (bSuc) {
                    active = false
                    callPositionViewAtBeginning()
                }
                isDisconnectting = false
            }
        }
    }
}
