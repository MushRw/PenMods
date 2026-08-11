import QtQuick 2.12

import "../commons"
import "../i18n"

Item {
    id: id_poem_sentence_dict
    height: id_poem_sentence_dict_column.height

    property var jsonPoemData: null
    property var sentenceKeyWord: ""
    property int nCurExplanationIdx: 1
    property int iExplanationIndex: 1
    property var poemSentenceArr: []
    onJsonPoemDataChanged: {
        nCurExplanationIdx = 1
        iExplanationIndex = 1
        poemSentenceArr = []
        if (sentenceKeyWord.length > 0) {
            jsonPoemData.detail.content.forEach(function(contentObj){
                contentObj.sentences.forEach(function(sentenceObj){
                    if (sentenceObj.origin.indexOf(sentenceKeyWord) >= 0) {
                        poemSentenceArr.push(sentenceObj)
                    }
                })
            })
        }
    }

    Column {
        id: id_poem_sentence_dict_column
        width: id_poem_sentence_dict.width

        Repeater {
            id: id_detail_explanation_sentence_repeater
            model: id_poem_sentence_dict.poemSentenceArr

            Column {
                id: id_detail_explanation_sentence_column
                width: id_poem_sentence_dict.width
                spacing: 8
                readonly property var modelModelData: model.modelData

                Column {
                    width: id_poem_sentence_dict.width
                    spacing: 4

                    YTextMedium {
                        width: parent.width
                        height: paintedHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        color: YColors.grayText
                        wrapMode: YTextBase.Wrap
                        textFormat: YTextBase.RichText
                        visible: id_detail_explanation_sentence_column.modelModelData !== null
                        Component.onCompleted: {
                            let qsFormatResult = ""
                            console.log("YDictTypeDtChPoemSentence.qml === poem sentence formatted:", id_detail_explanation_sentence_column.modelModelData.formatted)
                            if (id_detail_explanation_sentence_column.modelModelData !== null)
                            {
                                qsFormatResult = id_detail_explanation_sentence_column.modelModelData.formatted;
                                qsFormatResult = qsFormatResult.replace(/mark/g, "u");
                                console.log("YDictTypeDtChPoemSentence.qml === poem sentence qsFormatResult after replace:", qsFormatResult)
                                var nExplanationPos = 0;
                                var nLastPos = 0;
                                while ((nExplanationPos = qsFormatResult.indexOf("</u>", nLastPos)) !== -1)
                                {
                                    qsFormatResult = qsFormatResult.slice(0, nExplanationPos + 4)
                                                     + "[" + id_poem_sentence_dict.nCurExplanationIdx + "]"
                                                     + qsFormatResult.slice(nExplanationPos + 4);
                                    nLastPos = nExplanationPos + 4;
                                    id_poem_sentence_dict.nCurExplanationIdx++;
                                }
                            }
                            console.log("YDictTypeDtChPoemSentence.qml === poem sentence qsFormatResult:", qsFormatResult)
                            text = qsFormatResult;
                        }
                    }

                    YTextMedium {
                        id: id_poem_translate_text
                        width: parent.width
                        height: paintedHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        wrapMode: YTextBase.Wrap
                        text: visible ? id_detail_explanation_sentence_column.modelModelData.translate : ""
                        visible: id_detail_explanation_sentence_column.modelModelData !== null
                    }

                } // Column id_detail_translate_column

                YTextBase {
                    id: id_detail_explanation_text
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamily
                    font.weight: Font.Normal
                    color: YColors.red
                    width: parent.width
                    height: contentHeight + 6
                    text: YTranslateText.annotation
                    topPadding: 6
                    visible: id_detail_explanation_sentence_column.modelModelData !== null
                             && typeof id_detail_explanation_sentence_column.modelModelData.explanations != "undefined"
                             && id_detail_explanation_sentence_column.modelModelData.explanations.length > 0
                }

                Repeater {
                    id: id_detail_explanation_sentence_explanation_repeater
                    model: id_detail_explanation_text.visible ? id_detail_explanation_sentence_column.modelModelData.explanations : null

                    YTextMedium {
                        width: id_poem_sentence_dict.width
                        height: paintedHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        wrapMode: YTextBase.Wrap
                        textFormat: YTextBase.RichText
                        Component.onCompleted: {
                            let qsExplanation = ('<span style="color:%1;">[').arg(YColors.grayText) + id_poem_sentence_dict.iExplanationIndex + ']</span>'
                            qsExplanation += qmlGlobal.getChinese(model.modelData.word) + ':&nbsp;' + qmlGlobal.getChinese(model.modelData.meaning)
                            text = qsExplanation
                            id_poem_sentence_dict.iExplanationIndex += 1
                        }
                    }

                } // Repeater id_detail_explanation_sentence_explanation_repeater

            } // Column id_detail_explanation_sentence_column

        } // Repeater id_detail_explanation_sentence_repeater

    } // Column id_poem_sentence_dict_column
}

