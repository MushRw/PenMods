import QtQuick 2.12

YButtonBase {
    id: id_button_bg
    implicitHeight: 50
    radius: height/2
    color: YColors.red

    property int pixelSize: 18
    readonly property alias textItem: id_button_tip
    property alias text: id_button_tip.text
    property alias textColor: id_button_tip.color
    property alias textWidth: id_button_tip.contentWidth
    property alias textFamily: id_button_tip.font.family
    property alias textWeight: id_button_tip.font.weight

    YTextMedium {
        id: id_button_tip
        anchors.centerIn: parent
        font.pixelSize: pixelSize
        textFormat: YTextMedium.RichText
    }
}
