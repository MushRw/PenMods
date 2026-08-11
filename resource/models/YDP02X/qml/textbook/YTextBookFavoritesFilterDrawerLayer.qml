import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDrawerLayer {
    id: id_drawer_layer

    property int currentIndex: 0
    signal filterChanged(int filterInt)

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YText {
            id: id_title
            anchors.top: parent.top
            anchors.left: parent.left
            font.pixelSize: 18
            width: parent.width
            height: 20
            color: YColors.grayText
            wrapMode: YText.Wrap
            verticalAlignment: YText.AlignVCenter
            text: YTranslateText.textbookFavoritesChooseSort
        }

        Column {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: id_title.bottom
            anchors.topMargin: 10
            spacing: 8

            YButton {
                implicitWidth: parent.width
                color: currentIndex === 0? YColors.red : YColors.grayButton
                text: YTranslateText.textbookFavoritesSortByTime
                onClicked: {
                    currentIndex = 0
                    filterChanged(currentIndex)
                    hide()
                }
            }

            YButton {
                implicitWidth: parent.width
                color: currentIndex === 1? YColors.red : YColors.grayButton
                text: YTranslateText.textbookFavoritesSortByContent
                onClicked: {
                    currentIndex = 1
                    filterChanged(currentIndex)
                    hide()
                }
            }
        }

    }

}

