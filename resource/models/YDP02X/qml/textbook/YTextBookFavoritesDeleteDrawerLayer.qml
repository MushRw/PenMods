import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDrawerLayer {
    id: id_drawer_layer

    property string blockTitle: ""

    signal filterChanged(bool bdelete)

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YText {
            id: id_title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
            width: parent.width
            height: 78
            wrapMode: YText.Wrap
            horizontalAlignment: YText.AlignHCenter
            verticalAlignment: YText.AlignVCenter
            text: YTranslateText.removeRequest.arg(blockTitle)
        }

        Row {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 8

            YButton {
                implicitWidth: 120
                color: "#2D2E33"
                text: YTranslateText.cancel
                onClicked: {
                    filterChanged(false)
                    hide()
                }
            }

            YButton {
                id: id_remove_button
                implicitWidth: 120
                text: YTranslateText.del
                onClicked: {
                    filterChanged(true)
                    hide()
                }
            }
        }

    }

}

