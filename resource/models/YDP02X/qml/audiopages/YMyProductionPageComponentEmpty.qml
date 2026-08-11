import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YItem {
    id: id_container_index
    anchors.fill: parent
    anchors.leftMargin: 54
    anchors.rightMargin: 10
    anchors.topMargin: 12

    YText {
        anchors.top: parent.top
        width: parent.width
        wrapMode: YText.Wrap
        text: YTranslateText.myProductionAudiosTip
        font.family: qmlGlobal.fontFamilyZhCn
        font.pixelSize: {
            switch (qmlGlobal.language) {
            case YEnum.EN_US:
                return 16
            }
            return 18
        }
    }

    YTextBase {
        width: parent.width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        font.family: qmlGlobal.fontFamilyZhCn
        wrapMode: YTextBase.Wrap
        color: YColors.grayText
        font.pixelSize: 14
        text: YTranslateText.myProductionAudiosMethods.arg("https://ting.youdao.com")
    }
}
