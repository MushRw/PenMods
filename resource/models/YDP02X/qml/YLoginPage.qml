import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./components"
import "./i18n"

YBackButtonPage {
    id: id_setting_item
    objectName: "YPage===YLoginPage.qml"
    pageIndex: YEnum.PageIndex.UserCenter


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
        mouseAreaMargins: -20
        visible: id_not_login_loader.visible
        onClicked: {
            id_login_page_scan_qrcode_login_tip.show()
        }
    }


    YLoginPageScanQrcodeLoader {
        id: id_not_login_loader
        visible: id_setting_item.visible && !loginManager.isLogin
    }

    YLoginPageLoginStatusLoader {
        id: id_has_login_loader
        visible: id_setting_item.visible && loginManager.isLogin
        onRequestLoginPageRealTimeDisplay: {
            id_real_time_display.show()
        }
        onRequestLoginPageLogoutConfirm: {
            id_login_out_confirm.show()
        }
        onRequestAddBindAccountDisplay: {
            id_add_bind_account_display.show()
        }
    }

    YAddBindAccountDisplay {
        id: id_add_bind_account_display
    }

    YLoginPageScanQrcodeLoginTip {
        id: id_login_page_scan_qrcode_login_tip
    }

    YLoginPageRealTimeDisplay {
        id: id_real_time_display
    }

    YLoginPageLogoutConfirm {
        id: id_login_out_confirm
    }

    Connections {
        target: loginManager
        ignoreUnknownSignals: true
        onStatusChange: {
            console.warn("YLoginPage.qml===LoginEvent: ", event, " bSuc: ", bSuc)
            switch (event) {
            case YEnum.Login:
                if (bSuc) {
                    loginManager.queryUserInfo()
                } else {
                    qmlGlobal.showToast(YTranslateText.loginFaildPleaseCheckNetwork, YColors.grayNormal)
                }
                break
            case YEnum.Logout:
                if (bSuc) {
                    backButtonClicked()
                } else {
                    qmlGlobal.showToast(YTranslateText.logoutFaildPleaseCheckNetwork, YColors.grayNormal)
                }
                break
            }
        }
    }

    Component.onDestruction:  {
        console.warn("YLoginPage.qml===Component.onDestruction===called")
    }

    onBackButtonClicked: {
        loginManager.stopPollLoginState()
    }

    onVisibleChanged: {
        if (visible) {
            if (loginManager.isLogin) {
                loginManager.queryUserInfo()
            } else {
                loginManager.pollLoginState()
                loginManager.stopPollLoginState()
            }
        }
    }
}
