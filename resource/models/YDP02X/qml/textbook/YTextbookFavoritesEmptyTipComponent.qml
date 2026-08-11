import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    anchors.fill: parent
    anchors.topMargin: 70
    anchors.leftMargin: 70

    YTextBase {
        width: 224
        anchors.left: parent.left
        font.family: qmlGlobal.fontFamilyZhCn
        text: YTranslateText.textbookFavoritesEmptyTip
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 16
        wrapMode: Text.WrapAnywhere
        color: "#909199"
    }
}
