import QtQuick 2.12

import "../commons"

YSettingItemBackground {
    implicitHeight: 50

    property alias title: id_title.text
    property alias titleColor: id_title.color
    property alias titlePixelSize: id_title.font.pixelSize
    property alias titleFontFamily: id_title.font.family
    property int titleLeftMargin: 10
    property alias titleItem: id_title

    property alias value: id_value.text
    property alias valueColor: id_value.color
    property alias valuePixelSize: id_value.font.pixelSize
    property int valueRightMargin: 10
    property alias valueItem: id_value

    YTextMedium {
        id: id_title
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: titleLeftMargin
        anchors.right: id_value.left
        anchors.rightMargin: 20
//        width: 236
        elide: YTextMedium.ElideRight
    }

    YText {
        id: id_value
        color: YColors.grayText
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: valueRightMargin
        font.pixelSize: 16
        visible: text.length > 0
    }
}
