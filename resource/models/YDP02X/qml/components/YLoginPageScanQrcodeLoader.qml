import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

Item {
    id: id_scan_login_loader
    anchors.fill: parent
    anchors.leftMargin: 54
    anchors.rightMargin: 10

    visible: false
    property var qrCode: ""

    YSettingItemTitle {
        anchors.top: parent.top
        title: YTranslateText.scanQrCodeLogin
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
        height: 22
        font.weight: Font.DemiBold
        text: YTranslateText.youdaoSmartLearningApp
        anchors.left: parent.left
        anchors.top: id_dict_logo.bottom
        anchors.topMargin: 10
    }

    YText {
        id: id_dict_scan_tip
        font.pixelSize: 15
        color: YColors.grayText
        text: YTranslateText.scanQrCodeLoginTip
        anchors.left: parent.left
        anchors.top: id_dict_name.bottom
        anchors.topMargin: 2
    }

    Rectangle {
        id: id_bg_mask
        anchors.fill: parent
        color:"large" === state ? "#CC000000" : Qt.rgba(0,0,0,0)
        state:"normal"
        MouseArea {
            anchors.fill: parent
            onClicked: {
                id_bg_mask.state = id_bg_mask.state === "normal" ? "large" : "normal"
            }
        }
    }

    Rectangle {
        //implicitWidth: 96
        //implicitHeight: 96
        implicitWidth: "large" === id_bg_mask.state ? 150 : 96
        implicitHeight: "large" === id_bg_mask.state ? 150 : 96
        radius: 12
        color: id_qrcode_icon_default.visible ? YColors.grayNormal : YColors.white
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.right: parent.right

        YImageBase {
            id: id_qrcode_icon
            anchors.centerIn: parent
            width: parent.width - 16
            height: parent.height - 16
            source: qrCode
            sourceSize: Qt.size(width,height)
            visible: qrCode.length > 0
        }

        YImage {
            id: id_qrcode_icon_default
            anchors.centerIn: parent
            sourceSize: Qt.size(44, 24)
            imageName: "login/login-default-qr"
            visible: !id_qrcode_icon.visible
        }

        Connections {
            target: loginManager
            ignoreUnknownSignals: true
            enabled: id_scan_login_loader.visible
            onQrReady: {
                if (qrString.length > 0) {
                    qrCode = qrString
                    loginManager.pollLoginState();
                } else {
                    qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                }
            }
        }
    }

    YTimer {
        id: id_check_qrcode_state_timer
        interval: 5000
        objectName: "YLoginPageScanQrcodeLoader.qml_id_check_qrcode_state_timer"
        onTriggered: {
            if (visible && qrCode.length <= 0) {
                loginManager.requestLoginQr()
                id_check_qrcode_state_timer.start()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            loginManager.requestLoginQr()
            id_check_qrcode_state_timer.start()
        } else {
            qrCode = ""
            id_check_qrcode_state_timer.stop()
        }
    }
}
