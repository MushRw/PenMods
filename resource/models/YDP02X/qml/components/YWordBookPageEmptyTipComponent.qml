import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Column {
    spacing: 10
    anchors.top: parent.top
    anchors.topMargin: 74
    anchors.horizontalCenter: parent.horizontalCenter

    property bool isWordTab: true

    Row {
        id: id_tip_star
        spacing: 4
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.max(id_tip.contentHeight, id_start_icon.height)
        YTextMedium {
            id: id_tip
            text: YTranslateText.wordbookEmptyTip
            anchors.bottom: parent.bottom
        }
        YImage {
            id: id_start_icon
            width: 24
            height: 24
            sourceSize: Qt.size(24, 24)
            imageName: "wordbook/star"
            anchors.bottom: parent.bottom
        }
    }

    YTextBase {
        anchors.horizontalCenter: parent.horizontalCenter
        //text: YTranslateText.wordbookAddTip.arg(
        //          (wordBookManager.tabType === YEnum.WGT_Sentence)
        //          ? YTranslateText.phraseOrSentence
        //          : YTranslateText.word)
        text: {
            if (workBookTweaks.phraseTab) {
                let type
                switch (wordBookManager.tabType) {
                case YEnum.WGT_Sentence:
                    type = YTranslateText.sentence
                    break
                case 2 /* mod: word */:
                    type = YTranslateText.word
                    break
                case 3: /* mod: phrase */
                    type = YTranslateText.phrase
                    break
                default:
                    type = ""

                }
                return YTranslateText.wordbookAddTip.arg(type)
            }
            // original.
            return YTranslateText.wordbookAddTip.arg(
                              (wordBookManager.tabType === YEnum.WGT_Sentence)
                              ? YTranslateText.phraseOrSentence
                              : YTranslateText.word)
        }
        font.pixelSize: 16
        color: "#878A99"
    }
}
