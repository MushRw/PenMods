import QtQuick 2.12

import "../commons"

YSettingItemBackground {
    id: id_setting_switch_item
    opacity: (id_switch_state_button.pressed || !enabled) ? 0.6 : 1.0
    scale: (!enabled) ? 0.98 : (id_switch_state_button.pressed ? 0.95 : 1.0)

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    transform: Scale {
        origin.x: id_setting_switch_item.width / 2
        origin.y: id_setting_switch_item.height / 2
    }

    property alias title: id_title.text
    property alias switchOn: id_switch_state.switchOn
    readonly property alias switchItem: id_switch_state
    property alias interval: id_delay_switch_timer.interval

    signal clicked()
    signal timerTriggered()

    YTextMedium {
        id: id_title
        width: 168
        wrapMode: Text.WrapAnywhere
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
    }

    YSwitch {
        id: id_switch_state
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
    }

    YMouseArea {
        id: id_switch_state_button
        anchors.fill: parent
        onClicked: {
            switchOn = !switchOn
            id_setting_switch_item.clicked()
            id_delay_switch_timer.restart()
        }
        objectName: "YSettingSwitchItem.qml_YMouseArea"
    }

    YTimer {
        id: id_delay_switch_timer
        interval: 600
        objectName: "YSettingSwitchItem.qml_id_delay_switch_timer"
        onTriggered: {
            timerTriggered()
        }
    }
}
