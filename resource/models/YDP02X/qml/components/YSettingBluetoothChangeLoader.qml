import QtQuick 2.12

import "../commons"
import "../i18n"

YLoader {
    id: id_connect_wifi_loader
    anchors.fill: parent

    property string addrName: ""
    property bool isDisconnectting: false

    signal callPositionViewAtBeginning()

    sourceComponent: YOneButtonDialog {
        tipItem.text: YTranslateText.connectOtherBluetoothTip
        tipItem.textFormat: Text.RichText
        buttonItem.enabled: !isDisconnectting
        buttonItem.text: !isDisconnectting ? YTranslateText.continueString
                                           : YTranslateText.switchingConnection
        onClicked: {
            isDisconnectting = true
            blueToothManager.turnOn()
            close()
        }
        onClosed: {
            isDisconnectting = false
            active = false
        }
    }

    onLoaded: {
        item.show()
    }

    Connections {
        target: blueToothManager
        ignoreUnknownSignals: true
        enabled: id_connect_wifi_loader.active
        onConnectFinished: {
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
