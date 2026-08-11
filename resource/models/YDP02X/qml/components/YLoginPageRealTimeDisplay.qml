import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YBackButtonPage {
    id: id_real_time_display
    anchors.fill: parent
    destroyOnBack: false
    enabled: "disconnecting" !== id_column.state

    function getCurrentState() {
        if (blueToothManager.isAppConnected) {
            return "connected"
        } else if (blueToothManager.linkApp) {
            return "connect_tip"
        } else {
            return "disconnect"
        }
    }

    Connections {
        target: blueToothManager
        ignoreUnknownSignals: true
        onIsAppConnectedChanged: {
            id_column.state = Qt.binding(function(){
                return getCurrentState()
            })
        }
    }

    Column {
        id: id_column
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        state: getCurrentState()
        YSpacingForColumn {
            implicitHeight: 18
        }

        YText {
            anchors.left: parent.left
            anchors.right: parent.right
            wrapMode: YText.Wrap
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            height: 78
            text: {
                switch (id_column.state) {
                case "connecting":
                    return YTranslateText.enterAppHomePage
                case "disconnect":
                    return YTranslateText.checkMoreInfo
                case "connected":
                    return YTranslateText.hasConnectSuccess
                default:
                    return ""
                }
            }
            visible: {
                switch (id_column.state) {
                case "connecting":
                case "disconnect":
                case "connected":
                    return true
                default:
                    return false
                }
            }
        }

//        Row {
//            visible: "connected" === id_column.state
//            spacing: 12
//            anchors.horizontalCenter: parent.horizontalCenter
//            height: Math.max(id_tip.contentHeight, id_start_icon.height)
//            YImage {
//                id: id_start_icon
//                sourceSize: Qt.size(30, 30)
//                imageName: "login/app-connectted"
//                anchors.verticalCenter: parent.verticalCenter
//            }
//            YTextMedium {
//                id: id_tip
//                text: YTranslateText.hasConnectSuccess
//                anchors.verticalCenter: parent.verticalCenter
//            }
//        }

        YSpacingForColumn {
            implicitHeight: {
                switch (id_column.state) {
                case "connecting":
                    return 20
                case "connected":
                    return 8
                case "disconnect":
                default:
                    return 8
                }
            }
        }

        YButton {
            implicitWidth: {
                switch (qmlGlobal.language) {
                case YEnum.EN_US:
                    return 60 + textItem.paintedWidth
                }
                return 200
            }
            anchors.horizontalCenter: parent.horizontalCenter
            color: {
                switch (id_column.state) {
                case "connecting":
                case "connected":
                    return YColors.red
                case "disconnect":
                default:
                    return YColors.grayNormal
                }
            }
            text: {
                switch (id_column.state) {
                case "disconnect":
                    return YTranslateText.connectYdDict
                case "connected":
                    return YTranslateText.removeConnection
                case "disconnecting":
                    return YTranslateText.removingConnection
                case "connecting":
                default:
                    return ""
                }
            }
            visible: {
                switch (id_column.state) {
                case "disconnect":
                case "connected":
                    return true
                case "connecting":
                default:
                    return false
                }
            }
            onClicked: {
                switch (id_column.state) {
                case "disconnect":
                    id_column.state = "connecting"
                    blueToothManager.connectToApp()
                    break
                case "connected":
                    id_column.state = "disconnecting"
                    blueToothManager.disconnectApp()
                    break
                }
            }
            mouseAreaMargins: -6
        }

        YImage {
            sourceSize: Qt.size(24, 24)
            imageName: "login/waiting"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: "connecting" === id_column.state
            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 1920
                running: "connecting" === id_column.state
                loops: NumberAnimation.Infinite
            }
        }
    }


    YIconButton {
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        iconSourceSize: Qt.size(24, 24)
        icon: "login/scan_tip"
        mouseAreaMargins: -26
        onClicked: {
            id_real_time_display_connect_tip.show()
        }
    }

    YLoginPageRealTimeDisplayBlueToothTip {
        anchors.fill: parent
        readonly property bool isConnectTip: "connect_tip" === id_column.state
        onClicked: {
            blueToothManager.turnOff()
            id_column.state = "disconnect"
            close()
        }
        onClosed: {
            backButtonClicked()
        }
        onIsConnectTipChanged: {
            if (isConnectTip) {
                show()
            }
        }
    }

    YLoginPageRealTimeDisplayConnectTip {
        id: id_real_time_display_connect_tip
    }

    onBackButtonClicked: close()
}
