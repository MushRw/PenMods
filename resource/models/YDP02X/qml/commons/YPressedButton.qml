import QtQuick 2.12

YPressedBaseButton {
    implicitHeight: 50
    radius: height/2
    color: YColors.grayNormal

    property int pixelSize: 18
    readonly property alias textItem: id_button_tip
    property alias text: id_button_tip.text
    property alias textColor: id_button_tip.color
    property alias textWidth: id_button_tip.contentWidth

    YTextMedium {
        id: id_button_tip
        anchors.centerIn: parent
        font.pixelSize: pixelSize
    }
}
