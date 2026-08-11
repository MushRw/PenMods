import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_bluetooth
    objectName: "YPage===YSettingBluetooth.qml"

    function tryScan() {
        if (id_setting_bluetooth_view.bluetoothSwitchOn) {
            console.log("YSettingBluetooth.qml tryScan === ")
            id_refresh_button.clickable = false
            id_setting_bluetooth.state = "bluetooth_searching"
            blueToothManager.tryScan()
        }
    }
    function reConnect() {
        if (id_setting_bluetooth_view.bluetoothSwitchOn) {
            console.log("YSettingBluetooth.qml reConnect === ")
            id_setting_bluetooth.state = "bluetooth_reconnect"
            blueToothManager.reConnectHistoricalDevice()
        }
    }

    YText {
        id: id_state_tip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 22
        anchors.top: parent.top
        anchors.topMargin: 114
        font.pixelSize: 16
        color: YColors.grayText
    }

    YText {
        id: id_state_tip_waiting
        anchors.verticalCenter: id_state_tip.verticalCenter
        anchors.left: id_state_tip.right
        font.pixelSize: 16
        color: YColors.grayText
        visible: id_state_tip.visible && id_opening_animation.running
    }

    YBaseListView {
        id: id_setting_bluetooth_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        model: blueToothManager
        property bool bluetoothSwitchOn: blueToothManager.onoff

        onCountChanged: {
            if (("bluetooth_searching" === id_setting_bluetooth.state)
                    && (id_setting_bluetooth_view.count > 0)) {
                id_state_tip.visible = false
            }
        }

        Connections {
            target: blueToothManager
            ignoreUnknownSignals: true
            onTurnOnResult: {
                if (bSuc) {
                    console.log("zypper onTurnOnResult tryScan")
                    tryScan()
                }
            }

            onScanOnOffChanged: {
                if (!onoff) {
                    id_setting_bluetooth_view.scanningFinished()
                }
            }

            onScanningChanged: {
                if (!blueToothManager.scanning) {
                    id_setting_bluetooth_view.scanningFinished()
                }
            }

            onConnectFinished: {
                if (!bSuc) {
                    qmlGlobal.showToast(YTranslateText.connectFaild, "#E9900C")
                } else {
                    id_setting_bluetooth_view.positionViewAtBeginning()
                }
                id_refresh_button.rebinding()
            }
        }

        function scanningFinished() {
            if (id_setting_bluetooth_view.bluetoothSwitchOn) {
                if (0 === id_setting_bluetooth_view.count) {
                    id_setting_bluetooth.state = "bluetooth_search_failed"
                } else {
                    id_setting_bluetooth.state = "bluetooth_search_finished"
                }
                id_refresh_button.rebinding()
            }
        }

        delegate: (bluetoothSwitchOn && ("bluetooth_opening" !== id_setting_bluetooth.state))
                  ? id_bluetooth_item_component : id_bluetooth_item_null_component

        Component {
            id: id_bluetooth_item_null_component
            Item {
                width: id_setting_bluetooth_view.width
                implicitHeight: 52
            }
        }

        Component {
            id: id_bluetooth_item_component
            YMouseArea {
                id: id_bluetooth_item
                width: id_setting_bluetooth_view.width
                height: 60
                opacity: id_bluetooth_item.pressed ? 0.6 : 1
                objectName: "YSettingBluetooth.qml_id_bluetooth_item_index" + index
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
                            text: model.modelData.devName
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
                                    return YTranslateText.conneting
                                case YEnum.DISCONNECTING:
                                    return YTranslateText.disconneting + "..."
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
                        imageName: "settings/st-check"
                        visible: YEnum.LINKED === model.modelData.linkStatus
                    }
                }

                onClicked: {
                    switch (model.modelData.linkStatus) {
                    case YEnum.UNLINK:
                        if (blueToothManager.isAppConnected) {
                            id_bluetooth_change_loader.addrName = model.modelData.addr
                            id_bluetooth_change_loader.active = true
                        } else {
                            blueToothManager.tryConnect(model.modelData.addr)
                        }
                        break
                    case YEnum.LINKED:
                        id_bluetooth_detail_loader.devName = model.modelData.devName
                        id_bluetooth_detail_loader.addrName = model.modelData.addr
                        id_bluetooth_detail_loader.active = true
                        break
                    }
                }
            }
        }

        header: Item {
            width: id_setting_bluetooth_view.width
            height: 110

            YSettingItemTitle {
                title: YTranslateText.configBluetooth
            }

            YSettingSwitchItem {
                id: id_switch_state
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                title: YTranslateText.bluetooth
                switchOn: blueToothManager.onoff
                onClicked: {
                    if (id_switch_state.switchOn) {
                        id_setting_bluetooth.state = "bluetooth_opening"
                    } else {
                        id_setting_bluetooth.state = "bluetooth_off"
                    }
                }
                onTimerTriggered: {
                    if (id_switch_state.switchOn) {
                        blueToothManager.turnOn()
                    } else {
                        blueToothManager.turnOff()
                    }
                }
                readonly property bool blueToothOnoff: blueToothManager.onoff
                onBlueToothOnoffChanged: {
                    id_switch_state.switchOn = blueToothOnoff
                    if (!blueToothOnoff) {
                        id_setting_bluetooth.state = "bluetooth_off"
                    }
                }
                Component.onCompleted: {
                    id_setting_bluetooth_view.bluetoothSwitchOn = Qt.binding(function(){
                        return id_switch_state.switchOn
                    })
                }
            }
        }

        footer: YSpacing {
            width: id_setting_bluetooth_view.width
            height: 8
        }
    }

    YRefreshButton {
        id: id_refresh_button
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        clickable: blueToothManager.link || blueToothManager.linkApp
        iconOpacity: clickable ? 1 : 0.3
        onRefresh: {
            id_delay_try_scan_timer.restart()
        }
        function rebinding() {
            clickable = Qt.binding(function(){
                return id_setting_bluetooth_view.bluetoothSwitchOn
                        && ("bluetooth_opening" !== id_setting_bluetooth.state)
                        && ("bluetooth_searching" !== id_setting_bluetooth.state)
            })
        }
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

    state: {
        if (!blueToothManager.onoff) {
            return "bluetooth_off"
        } else {
            if (blueToothManager.link || blueToothManager.linkApp) {
                return "bluetooth_search_finished"
            } else {
                return "bluetooth_searching"
            }
        }
    }
    states: [
        State {
            name: "bluetooth_off"
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip;
                text: YTranslateText.openBluetoothTip; visible: true }
        },
        State {
            name: "bluetooth_opening"
            PropertyChanges { target: id_state_tip; text: YTranslateText.openingBluetooth }
            PropertyChanges { target: id_opening_animation; running: true }
            PropertyChanges { target: id_state_tip; visible: true }
        },
        State {
            name: "bluetooth_searching"
            PropertyChanges { target: id_state_tip; text: YTranslateText.searchingDevice }
            PropertyChanges { target: id_opening_animation; running: true }
            PropertyChanges { target: id_state_tip; visible: true }
        },
        State {
            name: "bluetooth_search_finished"
            PropertyChanges { target: id_state_tip; text: "" }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: false }
        },
        State {
            name: "bluetooth_search_failed"
            PropertyChanges { target: id_state_tip; text: YTranslateText.noBluetoothDevice }
            PropertyChanges { target: id_opening_animation; running: false }
            PropertyChanges { target: id_state_tip; visible: true }
        },
        State {
            name: "bluetooth_reconnect"
            PropertyChanges { target: id_state_tip; text: YTranslateText.reconnecting }
            PropertyChanges { target: id_opening_animation; running: true }
            PropertyChanges { target: id_state_tip; visible: true }
        }
    ]

    onStateChanged: {
        console.log("ZDS===YSettingBluetooth.qml===onStateChanged:", state)
    }

    Component.onCompleted: {
        blueToothManager.enableModelUpdate(true)
        id_delay_check_timer.restart()
    }

    onBackButtonClicked: {
        blueToothManager.enableModelUpdate(false)
    }

    YSettingBluetoothDetailLoader {
        id: id_bluetooth_detail_loader
        onCallPositionViewAtBeginning: {
            id_setting_bluetooth_view.positionViewAtBeginning()
        }
    }

    YSettingBluetoothChangeLoader {
        id: id_bluetooth_change_loader
        active: blueToothManager.isAppConnected
        onCallPositionViewAtBeginning: {
            id_setting_bluetooth_view.positionViewAtBeginning()
        }
    }

    YTimer {
        id: id_delay_try_scan_timer
        interval: 360
        objectName: "YSettingBluetooth.qml_id_delay_try_scan_timer"
        onTriggered: {
            if (id_setting_bluetooth_view.bluetoothSwitchOn) {
                tryScan()
            }
        }
    }

    YTimer {
        id: id_delay_check_timer
        interval: 360
        objectName: "YSettingBluetooth.qml_id_delay_check_timer"
        onTriggered: {
            if (id_setting_bluetooth_view.bluetoothSwitchOn
                    && !blueToothManager.link && !blueToothManager.linkApp) {
                tryScan()
            }
        }
    }
}
