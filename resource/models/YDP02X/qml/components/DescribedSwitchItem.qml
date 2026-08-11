import QtQuick 2.12

import "../commons"

YSettingItemBackground {
    id: id_described_switch_item
    implicitHeight: 44 + id_describe.contentHeight
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
        origin.x: id_described_switch_item.width / 2
        origin.y: id_described_switch_item.height / 2
    }

    property alias title: id_title.text
    property alias description: id_describe.text
    property alias switchOn: id_switch_state.switchOn
    readonly property alias switchItem: id_switch_state
    readonly property alias describeItem: id_describe
    property alias interval: id_delay_switch_timer.interval

    signal clicked()
    signal timerTriggered()

    YText {
        id: id_title
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 10
    }

    YText {
        id: id_describe
        anchors.top: id_title.bottom
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: YColors.grayText
        font.pixelSize: 14
        width: parent.width - id_switch_state.anchors.rightMargin - 75
        wrapMode: Text.Wrap
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
            id_described_switch_item.clicked()
            id_delay_switch_timer.restart()
        }
        objectName: "DescribedSwitchItem.qml_YMouseArea"
    }

    YTimer {
        id: id_delay_switch_timer
        interval: 600
        objectName: "DescribedSwitchItem.qml_id_delay_switch_timer"
        onTriggered: {
            timerTriggered()
        }
    }
}
