import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_wifi
    objectName: "YPage===YSettingWifi.qml"

    readonly property bool wifiManagerOnoff: wifiManager.onoff

    property int currentKeyboardState: 0

    function shortUrl(url) {
        if (url.length === 0) return "[未配置]";
        return url.length > 28 ? url.substring(0, 28) + "…" : url;
    }

    function tryScan() {
        id_delay_empty_show_timer.stop()
        if (wifiManagerOnoff) {
            console.log("YSettingWifi.qml tryScan === ")
            id_setting_wifi.state = "wifi_searching"
            id_refresh_button.clickable = false
            wifiManager.tryScan()
        }
    }

    Item {
        id: id_setting_wifi_container
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YBaseListView {
            id: id_setting_wifi_view
            anchors.fill: parent
            model: (switchOn && ("wifi_opening" !== id_setting_wifi.state)
                   && ("wifi_searching" !== id_setting_wifi.state)) ? wifiManager : null
            opacity: (typeof keyBoard !== 'undefined' && keyBoard.inputPageShowing) ? 0 : 1
            property bool switchOn: wifiManager.onoff
            Behavior on opacity {
                NumberAnimation {
                    duration: 480
                }
            }

            Connections {
                target: wifiManager
                ignoreUnknownSignals: true
                enabled: wifiManagerOnoff
                onTurnOnResult: {
                    console.log("YSettingWifi.qml onTurnOnResult === ", bSuc)
                    if (bSuc && ("wifi_searching" !== id_setting_wifi.state)) {
                        tryScan()
                    } else {
                        qmlGlobal.showToast(YTranslateText.connectFaild, "#E9900C")
                    }
                }
                onScanFinished: {
                    id_setting_wifi.state = "wifi_search_finished"
                    id_delay_empty_show_timer.restart()
                    id_refresh_button.rebinding()
                }
                onConnectFinished: {
                    id_setting_wifi.state = "wifi_connected"
                }
                onDisconnectFinished: {
                    id_setting_wifi.state = "wifi_disconnected"
                }
            }

            YTimer {
                id: id_delay_empty_show_timer
                interval: 720
                onTriggered: {
                    if ((0 === wifiManager.itemCount) && ("wifi_off" !== id_setting_wifi.state)) {
                        id_setting_wifi.state = "wifi_empty"
                    }
                }
                objectName: "YSettingWifi.qml_id_delay_empty_show_timer"
            }

            delegate: (switchOn && ("wifi_opening" !== id_setting_wifi.state)
                       && ("wifi_searching" !== id_setting_wifi.state)) ?
                          id_wifi_item_component : id_wifi_item_null_component

            Component {
                id: id_wifi_item_null_component
                Item {
                    width: id_setting_wifi_view.width
                    implicitHeight: 52
                }
            }

            Component {
                id: id_wifi_item_component
                YMouseArea {
                    id: id_wifi_item
                    width: id_setting_wifi_view.width
                    height: 60
                    opacity: id_wifi_item.pressed ? 0.6 : 1
                    objectName: "YSettingWifi.qml_id_wifi_item_index" + index
                    YSettingItemBackground {
                        anchors.fill: parent
                        anchors.bottomMargin: 8

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: id_state_icon.visible
                                           ? id_state_icon.left : parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            YTextMedium {
                                text: model.modelData.ssid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                elide: YText.ElideRight
                            }

                            YText {
                                font.pixelSize: 14
                                color: YColors.grayText
                                visible: (YEnum.LINKED === model.modelData.linkStatus)
                                         || (YEnum.LINKING === model.modelData.linkStatus)
                                         || (YEnum.DISCONNECTING === model.modelData.linkStatus)
                                text: {
                                    switch (model.modelData.linkStatus) {
                                    case YEnum.LINKED:
                                        return YTranslateText.connectSuccess
                                    case YEnum.LINKING:
                                        return YTranslateText.connetingWifi
                                    case YEnum.DISCONNECTING:
                                        return YTranslateText.disconnetingWifi
                                    default:
                                        return ""
                                    }
                                }
                            }
                        }

                        YImage {
                            id: id_state_icon
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(30, 30)
                            visible: (model.modelData.security !== "NONE") || (YEnum.LINKED === model.modelData.linkStatus)
                            imageName: visible ? ((YEnum.LINKED === model.modelData.linkStatus) ? "settings/st-check" : "settings/st-lock") : ""
                        }
                    }

                    onClicked: {
                        switch (model.modelData.linkStatus) {
                        case YEnum.LINKED:
                            id_wifi_detail_loader.wifiName = model.modelData.ssid
                            id_wifi_detail_loader.active = true
                            break
                        case YEnum.UNLINK:
                            if (!wifiManager.connectting) {
                                if (model.modelData.security === "NONE") {
                                    wifiManager.tryConnect(model.modelData.ssid, "")
                                    id_setting_wifi_view.positionViewAtBeginning()
                                } else if (model.modelData.password !== "") {
                                    wifiManager.tryConnect(model.modelData.ssid, model.modelData.password)
                                    id_setting_wifi_view.positionViewAtBeginning()
                                } else {
                                    requestKeyboard(model.modelData.ssid)
                                }
                            } else {
                                qmlGlobal.showToast(YTranslateText.connetingWifi, "#E9900C")
                            }
                            break
                        case YEnum.LINKING:
                            qmlGlobal.showToast(YTranslateText.connetingWifi, "#E9900C")
                            break
                        case YEnum.DISCONNECTING:
                            qmlGlobal.showToast(YTranslateText.disconnetingWifi, "#E9900C")
                            break
                        }
                        // todo 无连接时
                    }
                }
            }

            header: Item {
                width: id_setting_wifi_view.width
                height: 110

                YSettingItemTitle {
                    title: YTranslateText.configWifi
                }

                YSettingSwitchItem {
                    id: id_switch_state
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    title: YTranslateText.sysWifi
                    switchOn: wifiManager.onoff
                    interval: 540
                    onTimerTriggered: {
                        if (id_switch_state.switchOn) {
                            if (!wifiManager.onoff) {
                                id_setting_wifi.state = "wifi_opening"
                                wifiManager.turnOn()
                            }
                        } else if (!id_switch_state.switchOn) {
                            if (wifiManager.onoff) {
                                wifiManager.turnOff()
                            }
                            if ("wifi_off" !== id_setting_wifi.state) {
                                id_setting_wifi.state = "wifi_off"
                            }
                        }
                    }
                    readonly property bool wifiManagerOnoff: wifiManager.onoff
                    onWifiManagerOnoffChanged: {
                        id_switch_state.switchOn = wifiManagerOnoff
                    }
                    Component.onCompleted: {
                        id_setting_wifi_view.switchOn = Qt.binding(function(){
                            return id_switch_state.switchOn
                        })
                    }
                }
            }

        }

        YText {
            id: id_state_tip
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 35
            visible: false
            font.pixelSize: 16
            color: YColors.grayText
        }

        YText {
            id: id_state_tip_waiting
            anchors.verticalCenter: id_state_tip.verticalCenter
            anchors.left: id_state_tip.right
            font.pixelSize: 16
            color: YColors.grayText
            visible: id_opening_animation.running
        }

        SequentialAnimation {
            id: id_opening_animation
            loops: SequentialAnimation.Infinite
            running: false
            PropertyAction { target: id_state_tip_waiting; property: "text"; value: "..." }
            PauseAnimation { duration: 420 }
            PropertyAction { target: id_state_tip_waiting; property: "text"; value: "" }
            PauseAnimation { duration: 420 }
            PropertyAction { target: id_state_tip_waiting; property: "text"; value: "." }
            PauseAnimation { duration: 420 }
            PropertyAction { target: id_state_tip_waiting; property: "text"; value: ".." }
            PauseAnimation { duration: 420 }
        }

        YSettingWifiDetailLoader {
            id: id_wifi_detail_loader
            onActiveChanged: {
                id_setting_button.clickable = !active
                if (active) {
                    id_refresh_button.clickable = false
                } else {
                    id_refresh_button.rebinding()
                }
            }
        }
    }

    YIconButton {
        id: id_setting_button
        width: 30
        height: 30
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 50
        radius: 6
        source: "commons/more"
        onValidClicked: {
            id_pop_container.show('settingpages/ConfigureNetworkPage')
        }
    }

    YRefreshButton {
        id: id_refresh_button
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        clickable: false
        iconOpacity: clickable ? 1 : 0.3
        onRefresh: {
            tryScan()
        }
        function rebinding() {
            clickable = Qt.binding(function(){
                return !id_setting_wifi.animationRunning
                        && id_setting_wifi_view.switchOn
                        && !wifiManager.scanning
            })
        }
    }

    YPagePopHelper {
        id: id_page_pop_helper
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_YSettingWifi.qml"

        property string ssid: ""

        function inputPageCreated(incubatorObject, ssid) {
            id_page_pop_helper.ssid = ssid
            incubatorObject.backButtonClicked.connect(function(){
                qmlGlobal.inputPageShowing = false
                incubatorObject.todoDestroy()
                incubatorObject = null
            })
            incubatorObject.inputFinished.connect(function(content){
                wifiManager.tryConnect(id_page_pop_helper.ssid, content)
                id_setting_wifi_view.positionViewAtBeginning()
            })
            incubatorObject.show()
            qmlGlobal.inputPageShowing = true
        }
    }

    function requestKeyboard(ssid, keyboardState) {
        currentKeyboardState = (keyboardState === undefined ? 0 : keyboardState);
        let component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {

            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        console.log("YSettingWifi.qml===YInputPage", incubator.object, "is now ready!");
                        id_page_pop_helper.inputPageCreated(incubator.object, ssid)
                    }
                }
            } else {
                console.log("YSettingWifi.qml===YInputPage", incubator.object, "is ready immediately!");
                id_page_pop_helper.inputPageCreated(incubator.object, ssid)
            }
        }
    }

    state: "wifi_off"
    states: [
        State {
            name: "wifi_off"
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip;
                text: YTranslateText.openingWifiTip; visible: true }
        },
        State {
            name: "wifi_opening"
            PropertyChanges { target: id_state_tip; text: YTranslateText.openingWifi }
            PropertyChanges { target: id_opening_animation; running: true }
            PropertyChanges { target: id_state_tip; visible: true }
        },
        State {
            name: "wifi_searching"
            PropertyChanges { target: id_state_tip; text: YTranslateText.searchingWifi }
            PropertyChanges { target: id_opening_animation; running: true }
            PropertyChanges { target: id_state_tip; visible: true }
        },
        State {
            name: "wifi_search_finished"
            PropertyChanges { target: id_state_tip; text: "" }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: false }
        },
        State {
            name: "wifi_connected"
            PropertyChanges { target: id_state_tip; text: "" }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: false }
        },
        State {
            name: "wifi_disconnected"
            PropertyChanges { target: id_state_tip; text: "" }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: false }
        },
        State {
            name: "wifi_empty"
            PropertyChanges { target: id_state_tip; text: YTranslateText.noFindWifi }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: true }
        }
    ]

    Component.onCompleted: {
        wifiManager.enableModelUpdate(true)
        tryScan()
    }

    onBackButtonClicked: {
        wifiManager.enableModelUpdate(false)
    }
}
