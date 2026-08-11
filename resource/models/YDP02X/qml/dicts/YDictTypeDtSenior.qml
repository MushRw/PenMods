import QtQuick 2.12

import "../commons"
import "../i18n"

YDictTypeBase {
    id: id_dt_senior
    title: YTranslateText.dtSenior

    Column {
        spacing: 8
        width: parent.width
        Row {
            id: id_word_frequency_container
            spacing: 2
            width: parent.width
            height: id_word_frequency.contentHeight

            YTextBase {
                id: id_word_frequency
                font.pixelSize: 16
                color: YColors.grayText
                text: YTranslateText.wordFrequency
            }
            YSpacing {
                implicitWidth: 6
                implicitHeight: 6
            }
            Repeater {
                model: dictJson.frequency
                YImage {
                    anchors.verticalCenter: id_word_frequency_container.verticalCenter
                    sourceSize: Qt.size(19, 19)
                    imageName: "dict/star"
                }
            }
        }

        YTextBase {
            id: id_dictionary_title
            font.pixelSize: 16
            color: YColors.red
            width: parent.width
            height: contentHeight + 6
            topPadding: 6
            text: YTranslateText.annotationExample
        }

        Item {
            width: parent.width
            height: id_content_column.height

            YTextBase {
                id: id_pos_txt
                font.pixelSize: 14
                font.styleName: "italic"
                font.family: "Castoro"
                color: YColors.grayText
                text: dictJson.trans[0].pos
                width: 28
                wrapMode: YTextBase.Wrap
            }
            Column {
                id: id_content_column
                anchors.left: id_pos_txt.right
                anchors.right: parent.right
                YTextMedium {
                    id: id_sense
                    height: id_sense.contentHeight
                    width: parent.width
                    font.family: qmlGlobal.fontFamilyZhCn
                    text: dictJson.trans[0].sense
                    wrapMode: YTextMedium.Wrap
                }
                YSpacingForColumn {
                    implicitHeight: 4
                }
                YTextMedium {
                    id: id_sents_en
                    height: id_sents_en.contentHeight
                    width: parent.width
                    font.family: qmlGlobal.fontFamilyEnUs
                    textFormat: YTextBase.RichText
                    text: dictJson.trans[0].sents[0].en
                    wrapMode: YTextEnUs.Wrap
                }
                YSpacingForColumn {
                    implicitHeight: 4
                }
                YTextBase {
                    id: id_sents_zh
                    font.pixelSize: 18
                    height: id_sents_zh.contentHeight
                    width: parent.width
                    color: YColors.grayText
                    font.family: qmlGlobal.fontFamilyZhCn
                    textFormat: YTextBase.RichText
                    wrapMode: YTextBase.Wrap
                    text: dictJson.trans[0].sents[0].zh
                          + '<span style="color:#90919999;font-size:14px;">（'
                          + dictJson.trans[0].sents[0].source + '）</span>'
                }
            }
        }

    }
}

