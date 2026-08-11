import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"
import "../components"

Column {
    spacing: 10
    id: id_idiom_story_dict_column
    YText {
        id: id_author_content_text
        anchors.left: parent.left
        width: parent.width
        height: contentHeight
        clip: true
        font.family: qmlGlobal.fontFamilyZhCn
        font.pixelSize: 18
        color: YColors.white
        wrapMode: YTextBase.Wrap
        text:{
          return  "     "+dictJson.story
        }
        YAudioPlayButton {
            width: 24
            implicitHeight: 24
            sourceSize: Qt.size(24, 24)
            imageName: "dict/sound"
            id: id_sound_icon
            textFontFamily: qmlGlobal.fontFamilyEnUs
            textFormat: YText.PlainText
            leftMargin: 0
            anchors.left: parent.left
            anchors.top:parent.top
            color: YColors.black
            text: ""
            onValidClicked: {
                if (playing) {
                    playWord(dictJson.story, "zh")
                }
            }
        }
    }
}
