import QtQuick 2.12

import "../commons"

YButtonBase {
    implicitWidth: 110
    implicitHeight: 150

    property alias name: id_text.text
    property alias count: id_item_total.text
    property alias imageName: id_icon.imageName

    YImage {
        id: id_icon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 24
        sourceSize: Qt.size(40, 40)
        imageName: ""
    }

    Column {
        id: id_text_container
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 5

        YText {
            id: id_text
            anchors.left: parent.left
            anchors.right: parent.right
            height: paintedHeight
        }

        YText {
            id: id_item_total
            anchors.left: parent.left
            anchors.right: parent.right
            font.pixelSize: 14
            color: "#99FFFFFF"
            height: paintedHeight
        }
    }
}
