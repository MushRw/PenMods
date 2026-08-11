import QtQuick 2.12

import "../commons"

YSettingItemBackground {
    id: id_described_clickable_item
    implicitHeight: 46 + id_describe.contentHeight
    opacity: (opacityChangableWhenPressed && (id_button.pressed || !enabled)) ? 0.6 : 1
    scale: (id_button.pressed || !enabled) ? 0.95 : 1.0

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
        origin.x: id_described_clickable_item.width / 2
        origin.y: id_described_clickable_item.height / 2
    }

    property alias title: id_title.text
    property alias describe: id_describe.text
    property alias value: id_value.text

    property alias pressed: id_button.pressed
    property bool opacityChangableWhenPressed: true

    property alias describeItem: id_describe

    signal clicked()

    YText {
        id: id_title
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 10
        anchors.leftMargin: 10
    }

    YText {
        id: id_describe
        anchors.top: id_title.bottom
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: YColors.grayText
        font.pixelSize: 14
        width: parent.width - id_value.anchors.rightMargin - 80
        wrapMode: Text.Wrap
    }

    YText {
        id: id_value
        color: YColors.grayText
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        font.pixelSize: 16
        visible: text.length > 0
    }

    YMouseArea {
        id: id_button
        anchors.fill: parent
        onClicked: {
            id_described_clickable_item.clicked()
        }
        objectName: "DescribedClickableTextBox_YMouseArea"
    }

}
