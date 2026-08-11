import QtQuick 2.12
import com.youdao.pen 1.0

import "./qml/commons"
import "./qml/components"
import "./qml/settingpages"
import "./qml/i18n"
import "./qml"

YMainWindow {
    id: id_verify_page

    property int verifyState: YEnum.Verify_UILanguageSelect
    property int lastVerifyState: YEnum.Verify_UILanguageSelect
    property bool checkWifiState: true
    property bool showUILanguageSelect: !qmlGlobal.checkFeature(YEnum.FEATURE_SERIAL_D2)

    function showPageByVerfyState(state) {
        console.log("YVerifyPage.qml showPageByVerfyState === verifyState", state)
        if (state > YEnum.Verify_ConfigWifi) {
            checkWifiState = false
        }
        if (id_verify_page.verifyState == YEnum.Verify_UILanguageSelect
                || id_verify_page.verifyState == YEnum.Verify_NetworkFailed
                || id_verify_page.verifyState == YEnum.Verify_VerifyFailed) {
            id_verify_page.lastVerifyState = id_verify_page.verifyState
        } else if (state === YEnum.Verify_ConfigWifi && showUILanguageSelect) {
            id_verify_page.lastVerifyState = YEnum.Verify_UILanguageSelect
        }
        if (state === YEnum.Verify_Login) {
            if (showUILanguageSelect) {
                id_verify_page.lastVerifyState = YEnum.Verify_UILanguageSelect
            } else {
                id_verify_page.lastVerifyState = YEnum.Verify_ConfigWifi
            }
        }
        id_verify_page.verifyState = state
    }

    function startWifiConfig() {
        if (!wifiManager.onoff) {
            showPageByVerfyState(YEnum.Verify_WaitQrWifiConfig)
            wifiManager.turnOn()
        }
        else {
            showPageByVerfyState(YEnum.Verify_ConfigWifi)
        }
    }

    YBackgroundIgnoreMouseEvent {
        anchors.fill: parent
    }

    YLoader {
        id: id_verify_content_loader
        width: id_verify_page.width
        height: id_verify_page.height
        active: true
        sourceComponent: {
            switch (id_verify_page.verifyState) {
            case YEnum.Verify_WaitQrWifiConfig:
            case YEnum.Verify_Verifying:
                return id_waiting_text_component
            case YEnum.Verify_ConfigWifi:
                return id_config_wifi_component
            case YEnum.Verify_Login:
                return id_login_component
            case YEnum.Verify_NetworkFailed:
                return id_network_error_component
            case YEnum.Verify_VerifyFailed:
                return id_verify_faile_component
            case YEnum.Verify_VerifySuccess:
                return id_introduction_component
            case YEnum.Verify_UILanguageSelect:
            default:
                return id_language_select_component
            }
        }
        onSourceComponentChanged: {
            console.log("YVerifyPage.qml === id_verify_content_loader.onSourceComponentChanged: ", id_verify_page.verifyState)
        }
    }

    YStackView {
        id: id_stack_view
        onCurrentPopIdValidChanged: {
            if (!currentPopIdValid) {
                qmlGlobal.currentPageIndex = YEnum.PageIndex.NonePage
            }
        }
    }

    YPopLayer {
        id: id_page_pop_helper
    }

    Component {
        id: id_language_select_component

        Item {
            width: id_verify_page.width
            height: id_verify_page.height

            GridView {
                id: id_language_gridview
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                clip: true
                cellWidth: 154
                cellHeight: 58
                model: id_language_model
                opacity: 1
                cacheBuffer: 600

                delegate: YMouseArea {
                    id: id_language_item_delegate
                    width: id_language_gridview.cellWidth
                    height: id_language_gridview.cellHeight
                    objectName: "YVerifyPage.qml_language_delegate_" + languageName

                    Rectangle {
                        width: id_language_gridview.cellWidth - 8
                        height: id_language_gridview.cellHeight - 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: YColors.grayNormal
                        opacity: parent.pressed ? 0.8 : 1
                        radius: height * 0.5

                        YTextMedium {
                            id: id_label
                            anchors.fill: parent
                            horizontalAlignment: YTextMedium.AlignHCenter
                            verticalAlignment: YTextMedium.AlignVCenter
                            text: {
                                switch (languageEnum) {
                                case YEnum.ZH_CN:
                                    return YTranslateText.languageZhCN
                                case YEnum.EN_US:
                                default:
                                    return YTranslateText.languageEnUS
                                }
                            }

                            font.family: {
                                switch(languageEnum) {
                                case YEnum.ZH_CN:
                                    return qmlGlobal.fontFamilyZhCn
                                case YEnum.EN_US:
                                default:
                                    return qmlGlobal.fontFamilyEnUs
                                }
                            }
                        }
                    }

                    onClicked: {
                        console.log("YVerifyPage.qml === id_language_select_component.language.onClicked, wifi onoff = ", wifiManager.onoff)
                        settingManager.uiLanguage = languageEnum
                        qmlTranslator.loadLanguage(languageEnum)
                        if (!wifiManager.onoff) {
                            showPageByVerfyState(YEnum.Verify_WaitQrWifiConfig)
                            wifiManager.turnOn()
                        } else if (wifiManager.internetConnect) {
                            showPageByVerfyState(YEnum.Verify_Login)
                        } else {
                            showPageByVerfyState(YEnum.Verify_ConfigWifi)
                        }
                    }
                }

                header: Item {
                    id: id_language_title_bar
                    width: id_language_gridview.width
                    implicitHeight: 80

                    property int clickCount: 0

                    YText {
                        id: id_language_title_text
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: YTranslateText.pleaseSelectDeviceLanguage

                        YMouseArea {
                            objectName: "YVerifyPage.qml_id_language_title_text"
                            anchors.fill: parent
                            property var currentShowPage: null

                            function createAndShowAboutPage() {
                                id_page_pop_helper.show("settingpages/YSettingAbout")
                            }

                            onClicked: {
                                if (clickCount <= 0) {
                                    id_click_count_timer.start()
                                }

                                clickCount++
                                if (clickCount >= 5) {
                                    console.log("YVerifyPage.qml===createAndShowAboutPage, cnt ", clickCount)
                                    clickCount = 0
                                    createAndShowAboutPage()
                                    id_click_count_timer.stop()
                                }
                            }
                        }
                    }


                    YTimer {
                        id: id_click_count_timer
                        interval: 2000
                        objectName: "YVerifyPage.qml_id_click_count_timer"
                        onTriggered: {
                            if (clickCount > 1) {
                                clickCount--
                            }

                            if (clickCount == 0) {
                                stop()
                            }
                        }
                    }
                }
            }

            ListModel {
                id: id_language_model

                ListElement {
                    languageName: "Ch"
                    languageEnum: YEnum.ZH_CN
                }

                //            ListElement {
                //                languageName: "Cht"
                //                languageEnum: YEnum.ZH_TW
                //            }

                ListElement {
                    languageName: "En"
                    languageEnum: YEnum.EN_US
                }

                //            ListElement {
                //                languageName: "Ja"
                //                languageEnum: YEnum.JA_JP
                //            }

                //            ListElement {
                //                languageName: "Ko"
                //                languageEnum: YEnum.KO_KR
                //            }
            }
        }
    }

    Component {
        id: id_waiting_text_component

        Item {
            width: id_verify_page.width
            height: id_verify_page.height

            YTextMedium {
                anchors.centerIn: parent
                text: {
                    switch (id_verify_page.verifyState) {
                    case YEnum.Verify_WaitQrWifiConfig:
                        return YTranslateText.openingWifi
                    case YEnum.Verify_VerifySuccess:
                        return YTranslateText.verifySuccess
                    case YEnum.Verify_Verifying:
                    default:
                        return YTranslateText.verifying
                    }
                }
            }
        }
    }

    Component {
        id: id_login_component

        YBackButtonPage {
            visible: true

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
                visible: true
                id: id_not_login_loader
            }

            YLoginPageScanQrcodeLoginTip {
                id: id_login_page_scan_qrcode_login_tip
            }

            onBackButtonClicked: {
                console.log("YVerifyPage.qml === id_login_component.onBackButtonClicked")
                wifiManager.ignore(wifiManager.ssid)
                showPageByVerfyState(id_verify_page.lastVerifyState)
            }
        }
    }

    Component {
        id: id_network_error_component

        Item {
            width: id_verify_page.width
            height: id_verify_page.height

            Column {
                width: parent.width
                spacing: 0

                YSpacingForColumn {
                    implicitHeight: 31
                }

                YText {
                    width: parent.width
                    height: 24
                    horizontalAlignment: YTextMedium.AlignHCenter
                    verticalAlignment: YTextMedium.AlignVCenter
                    text: YTranslateText.verifyFaildForNetwork
                }

                YSpacingForColumn {
                    implicitHeight: 8
                }

                YTextBase {
                    width: parent.width
                    height: 21
                    horizontalAlignment: YTextMedium.AlignHCenter
                    verticalAlignment: YTextMedium.AlignVCenter
                    color: YColors.grayText
                    font.pixelSize: 16
                    text: YTranslateText.customerServiceHotline
                }

                YSpacingForColumn {
                    implicitHeight: 20
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 50
                    spacing: 8

                    YButton {
                        width: 120
                        height: parent.height
                        color: YColors.grayNormal
                        text: YTranslateText.reVerify
                        onClicked: {
                            console.log("YVerifyPage.qml === id_network_error_component.reverify.onClicked")
                            showPageByVerfyState(YEnum.Verify_Verifying)
                            verifyManager.startVerify()
                        }
                    }

                    YButton {
                        width: 120
                        height: parent.height
                        color: YColors.red
                        text: YTranslateText.switchNetwork
                        onClicked: {
                            console.log("YVerifyPage.qml === id_network_error_component.switchwifi.onClicked")
                            startWifiConfig()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: id_verify_faile_component

        Item {
            width: id_verify_page.width
            height: id_verify_page.height

            Column {
                width: parent.width
                spacing: 0

                YSpacingForColumn {
                    implicitHeight: 31
                }

                YTextMedium {
                    width: parent.width
                    height: 24
                    horizontalAlignment: YTextMedium.AlignHCenter
                    verticalAlignment: YTextMedium.AlignVCenter
                    text: YTranslateText.verifyFaild
                }

                YSpacingForColumn {
                    implicitHeight: 8
                }

                YTextBase {
                    width: parent.width
                    height: 21
                    horizontalAlignment: YTextMedium.AlignHCenter
                    verticalAlignment: YTextMedium.AlignVCenter
                    color: YColors.grayText
                    font.pixelSize: 16
                    text: YTranslateText.customerServiceHotline
                }

                YSpacingForColumn {
                    implicitHeight: 20
                }

                YButton {
                    width: 200
                    height: 50
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: YColors.red
                    text: YTranslateText.reVerify
                    onClicked: {
                        console.log("YVerifyPage.qml === id_verify_faile_component.reverify.onClicked")
                        showPageByVerfyState(YEnum.Verify_Verifying)
                        verifyManager.startVerify()
                    }
                }
            }
        }
    }

    Component {
        id: id_config_wifi_component

        YSettingWifi {
            id: id_setting_wifi_view
            width: id_verify_page.width
            height: id_verify_page.height
            visible: true
            defaultTitleBar.backButtonItem.visible: id_verify_page.lastVerifyState !== id_verify_page.verifyState

            onBackButtonClicked: {
                console.log("YVerifyPage.qml === id_config_wifi_component.onBackButtonClicked")
                showPageByVerfyState(id_verify_page.lastVerifyState)
            }

            YTimer {
                id: id_check_wifi_state_timer
                interval: 500
                repeat: true
                onTriggered: {
                    console.log("YVerifyPage.qml === id_check_wifi_state_timer.onTriggered")
                    if (wifiManager.internetConnect) {
                        showPageByVerfyState(YEnum.Verify_Login)
                    }
                }
            }

            Component.onCompleted: {
                if (checkWifiState) {
                    id_check_wifi_state_timer.start()
                }
            }
        }
    }

    Component {
        id: id_introduction_component

        Item {
            id: id_introduction_item
            width: id_verify_page.width
            height: id_verify_page.height
            property int intrImageIndex: 1

            YImage {
                anchors.fill: parent
                imageName: "introduction/introduction" + intrImageIndex + (settingManager.uiLanguage === YEnum.EN_US ? "-en" : "")

                MouseArea {
                    width: 100
                    height: 120
                    anchors.left: parent.left
                    anchors.top: parent.top
                    onClicked: {
                        console.log("YVerifyPage.qml === id_introduction_item.last.onClicked")
                        if (id_introduction_item.intrImageIndex > 1) {
                            id_introduction_item.intrImageIndex -= 1
                        }
                    }
                }

                MouseArea {
                    width: 100
                    height: 120
                    anchors.right: parent.right
                    anchors.top: parent.top
                    onClicked: {
                        console.log("YVerifyPage.qml === id_introduction_item.next.onClicked")
                        if (id_introduction_item.intrImageIndex < 4) {
                            id_introduction_item.intrImageIndex += 1
                        } else {
                            settingManager.isVerified = true
                            verifyManager.openMainPage()
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: verifyManager
        ignoreUnknownSignals: true
        onVerifyStateChanged: {
            console.log("YVerifyPage.qml === verifyManager.onVerifyStateChanged state: ", state)
            showPageByVerfyState(state)
        }
    }

    Connections {
        target: wifiManager
        ignoreUnknownSignals: true
        enabled: id_verify_page.verifyState != YEnum.Verify_UILanguageSelect
        onOnoffChanged: {
            if (wifiManager.onoff) {
                showPageByVerfyState(YEnum.Verify_ConfigWifi)
            }
        }
        onConnectFinished: {
            console.log("YVerifyPage.qml wifiManager.onWifiConnectFinished === ", bSuc)
            if (bSuc) {
                showPageByVerfyState(YEnum.Verify_Login)
            }
        }
    }

    Connections {
        target: loginManager
        ignoreUnknownSignals: true
        onStatusChange: {
            console.warn("YVerifyPage.qml===LoginEvent: ", event, " bSuc: ", bSuc)
            switch (event) {
            case YEnum.Login:
                if (bSuc) {
                    showPageByVerfyState(YEnum.Verify_Verifying)
                    verifyManager.startVerify()
                } else {
                    qmlGlobal.showToast(YTranslateText.loginFaildPleaseCheckNetwork, YColors.grayNormal)
                }
                break
            }
        }
    }

    Component.onCompleted: {
        console.log("YVerifyPage.qml===Component.onCompleted")
        qmlGlobal.currentPageIndex = YEnum.PageIndex.Verify
        if (!showUILanguageSelect) {
            startWifiConfig()
            id_verify_page.lastVerifyState = YEnum.Verify_ConfigWifi
        }
    }
}
