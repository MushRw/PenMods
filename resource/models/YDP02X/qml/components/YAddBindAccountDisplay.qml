import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

YBackButtonPage {
    anchors.fill: parent
    destroyOnBack: false
    property var bindQrCode: ""
    signal requestAddBindAccountTipDisplay()

    Item {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YSettingItemTitle {
            title: YTranslateText.addBindAccount
        }

        YImage {
            id: id_dict_logo
            imageName: "login/dict-logo"
            sourceSize: Qt.size(36, 36)
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 64
        }

        YText {
            id: id_dict_name
            font.pixelSize: 17
            font.weight: Font.DemiBold
            height: 22
            text: YTranslateText.youdaoSmartLearningApp
            anchors.left: parent.left
            anchors.top: id_dict_logo.bottom
            anchors.topMargin: 10
        }

        YTextBase {
            id: id_dict_scan_tip
            font.pixelSize: 15
            color: YColors.grayText
            height: 22
            text: YTranslateText.scanQrCodeBindAccountTip
            anchors.left: parent.left
            anchors.top: id_dict_name.bottom
            anchors.topMargin: 2
        }

        Rectangle {
            implicitWidth: 96
            implicitHeight: 96
            radius: 12
            color: id_qrcode_icon_default.visible ? YColors.grayNormal : YColors.white
            anchors.top: parent.top
            anchors.topMargin: 58
            anchors.right: parent.right

            YImageBase {
                id: id_qrcode_icon
                anchors.centerIn: parent
                width: 86
                height: 86
                sourceSize: Qt.size(width,height)
                source: bindQrCode
                visible: bindQrCode.length > 0
            }

            YImage {
                id: id_qrcode_icon_default
                anchors.centerIn: parent
                sourceSize: Qt.size(44, 24)
                imageName: "login/login-default-qr"
                visible: !id_qrcode_icon.visible
            }
        }
    }

    Connections {
        target: loginManager
        ignoreUnknownSignals: true
        enabled: id_add_bind_account_display.visible
        onBindQrReady: {
            if (visible) {
                if (qrString.length > 0) {
                    bindQrCode = qrString
                } else {
                    qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                }
                id_update_bind_qrcode_timer.interval = 60 * 5000
                id_update_bind_qrcode_timer.start()
            }
        }
    }

    YTimer {
        id: id_check_bind_qrcode_state_timer
        interval: 5000
        objectName: "YAddBindAccountDisplay.qml_id_check_bind_qrcode_state_timer"
        onTriggered: {
            if (visible && bindQrCode.length <= 0) {
                loginManager.asyncRequestBindQr()
                id_check_bind_qrcode_state_timer.start()
            }
        }
    }

    YTimer {
        id: id_update_bind_qrcode_timer
        interval: 1000 * 60 * 5
        objectName: "YAddBindAccountDisplay.qml_id_update_bind_qrcode_timer"
        onTriggered: {
            if (visible && bindQrCode.length > 0) {
                loginManager.asyncRequestBindQr()
            }
        }
    }

    onBackButtonClicked: close()

    onVisibleChanged: {
        if (visible) {
            loginManager.asyncRequestBindQr()
            id_check_bind_qrcode_state_timer.start()
        } else {
            bindQrCode = ""
            id_check_bind_qrcode_state_timer.stop()
            id_update_bind_qrcode_timer.stop()
        }
    }
}

