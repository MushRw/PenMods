import QtQuick 2.12

import "../commons"

Item {
    id: id_title_container
    anchors.left: parent.left
    anchors.right: parent.right
    height: id_title_item.height + 28

    property alias title: id_title_item.text
    property alias titleFontFamily: id_title_item.font.family

    YText {
        id: id_title_item
        font.pixelSize: 16
        color: YColors.grayText
        textFormat: YTextBase.RichText
        wrapMode: YText.Wrap
        anchors.verticalCenter: parent.verticalCenter
        lineHeightMode: YTextBase.FixedHeight
        lineHeight: 22
        width: parent.width
    }
}

