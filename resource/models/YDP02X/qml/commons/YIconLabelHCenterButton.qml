import QtQuick 2.12

YButtonBase {
    id: id_icon_label_button_bg
    implicitWidth: 124
    implicitHeight: 50
    radius: height/2
    mouseAreaMargins: -5

    property alias iconSource: id_button_icon.imageName
    property alias iconSourceSize: id_button_icon.sourceSize
    property alias spacing: id_label.anchors.leftMargin
    property alias text: id_label.text
    readonly property alias iconItem: id_button_icon
    readonly property alias textItem: id_label
    readonly property alias ukOrUsText: id_label_en_us


    Row {
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        YImage {
            id: id_button_icon
            anchors.verticalCenter: parent.verticalCenter
            cache: true
        }

        Item{
            width: 6
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        YText {
            id: id_label_en_us
            anchors.verticalCenter: parent.verticalCenter
            visible: text.length
            text: ""
        }

        Item{
            width: 4
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: id_label_en_us.visible
        }

        YText {
            id: id_label
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
