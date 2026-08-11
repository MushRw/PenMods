import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

YBackground {
    id: id_drawer_layer
    anchors.fill: parent
    visible: false

    property string title;
    property string detail;

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            hide()
        }
    }
    Flickable{
        id: id_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height
        Column {
            id: id_column
            anchors.left: parent.left
            width: 256
            YSpacingForColumn {
                implicitHeight: 16
            }

            YTextCH {
                id: id_title
                color: "#ffffff"
                width: parent.width
                font.pixelSize: 20
                wrapMode: YTextBase.Wrap
                font.bold: true
                textFormat : YTextBase.RichText
                text: title
            }

            YSpacingForColumn {
                implicitHeight: 10
            }
            YTextCH {
                id: id_detail
                width: parent.width
                color: "#ffffff"
                font.pixelSize: 18
                wrapMode: YTextBase.Wrap
                textFormat : YTextBase.RichText
                text: detail
            }
            YSpacingForColumn {
                implicitHeight: 4
            }
        }
    }
}
