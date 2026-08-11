import QtQuick 2.12

import "../commons"

YButtonBase {
    id: id_icon_label_button_bg
    implicitWidth: 160
    implicitHeight: 26
    mouseAreaMargins: 0
    radius: 0
    color: YColors.grayButton

    property alias imageName: id_button_icon.imageName
    property alias sourceSize: id_button_icon.sourceSize

    property int spacing: 8
    property alias text: id_label.text
    readonly property alias textItem: id_label

    Item {
        anchors.centerIn: parent
        width: id_button_icon.width + spacing + id_label.width
        implicitHeight: 26

        YImage {
            id: id_button_icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            sourceSize: Qt.size(26, 26)
        }

        YText {
            id: id_label
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 16
            width: paintedWidth
            height: paintedHeight
        }
    }
}
