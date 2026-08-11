import QtQuick 2.12

import "../commons"
import "../i18n"

Item {
    width: parent.width
    height: id_wordinfo_column.height

    Column {
        id: id_wordinfo_column
        width: parent.width
        spacing: 8

        YTextBase {
            id: id_wordHead_text
            wrapMode: YText.Wrap
            textFormat: YTextBase.RichText
            color: "#FFFFFF"
            width: parent.width
            height: paintedHeight
            text: {
                let qsRst = '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + '; font-size: 18px; font-weight: 500;">' + dictJson.wordHead + '</span>'
                if (typeof dictJson.content.ukphone != "undefined") {
                    qsRst += '<span>&nbsp;&nbsp;&nbsp;&nbsp;</span>'
                             + '<span style="font-family: ' + qmlGlobal.fontFamily + ('; font-size: 16px; color: %1; font-weight: 500;">').arg(YColors.grayText) + YTranslateText.shorthandEN + '</span>'
                             + '<span>&nbsp;&nbsp;</span>'
                             + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; font-size: 16px; color: %1; font-weight: 400;">&frasl;&nbsp;').arg(YColors.grayText) + dictJson.content.ukphone + '&nbsp;&frasl;</span>'
                }
                if (typeof dictJson.content.usphone != "undefined") {
                    qsRst += '<span>&nbsp;&nbsp;&nbsp;&nbsp;</span>'
                             + '<span style="font-family: ' + qmlGlobal.fontFamily + ('; font-size: 16px; color: %1; font-weight: 500;">').arg(YColors.grayText) + YTranslateText.shorthandUS + '</span>'
                             + '<span>&nbsp;&nbsp;</span>'
                             + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; font-size: 16px; color: %1; font-weight: 400;">&frasl;&nbsp;').arg(YColors.grayText) + dictJson.content.usphone + '&nbsp;&frasl;</span>'
                }
                return qsRst
            }
        } // Text id_wordHead_text

        YTextMedium {
            font.pixelSize: 16
            color: YColors.red
            width: parent.width
            height: 24
            verticalAlignment: YTextBase.AlignBottom
            text: YTranslateText.paraphrase
            visible: id_content_trans_repeater.count > 0
        }

        Repeater {
            id: id_content_trans_repeater
            model: typeof dictJson.content.trans != "undefined" ? dictJson.content.trans : null

            Item {
                width: id_wordinfo_column.width
                height: id_content_trans_tran.height
                YTextBase {
                    id: id_content_trans_pos_text
                    color: YColors.grayText
                    font.pixelSize: 14
                    font.family: "Castoro"
                    font.styleName: "italic"
                    width: 28
                    height: 22
                    verticalAlignment: Text.AlignBottom
                    text: model.modelData.pos
                }

                YTextBase {
                    id: id_content_trans_tran
                    anchors.left: id_content_trans_pos_text.right
                    anchors.right: parent.right
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    wrapMode: YText.Wrap
                    textFormat: YTextBase.RichText
                    height: paintedHeight
                    text: {
                        let w = ''
                        let flag = 0;
                        model.modelData.tran.forEach(function(eTran){
                            if (flag++ > 0) w += '<span>&nbsp;&nbsp;&nbsp;</span>'
                            w += '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1;"> ').arg(YColors.white) + eTran.cn + ' </span>'
                                    + '<span>&nbsp;</span>'
                                    + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; color: %1;">').arg(YColors.grayText) + eTran.en + '</span>'
                        })
                        return w
                    }
                }
            }
        } // Repeater id_content_trans_repeater

        YTextMedium {
            font.pixelSize: 16
            color: YColors.red
            width: parent.width
            height: 28
            verticalAlignment: YTextBase.AlignBottom
            text: YTranslateText.synonymsAndSynonyms
            visible: id_content_synos_repeater.count > 0
        }

        Repeater {
            id: id_content_synos_repeater
            model: typeof dictJson.content.synos != "undefined" ? dictJson.content.synos : null

            Item {
                width: id_wordinfo_column.width
                height: id_content_synos_syno.height
                YTextBase {
                    id: id_content_synos_pos_text
                    color: YColors.grayText
                    font.pixelSize: 14
                    font.family: "Castoro"
                    font.styleName: "italic"
                    width: 28
                    height: 22
                    verticalAlignment: Text.AlignBottom
                    text: model.modelData.syno.pos
                }

                YTextBase {
                    id: id_content_synos_syno
                    anchors.left: id_content_synos_pos_text.right
                    anchors.right: parent.right
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    wrapMode: YText.Wrap
                    textFormat: YTextBase.RichText
                    height: paintedHeight
                    text: {
                        let ws = ''
                        let flag = 0;
                        model.modelData.syno.ws.forEach(function(ew){
                            if (flag++ > 0) ws += ' / '
                            ws += ew.w
                        })
                        return '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1;">').arg(YColors.white) + model.modelData.syno.tran + '</span>'
                                + '  '
                                + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; color: %1;">').arg(YColors.grayText) + ws + '</span>'
                    }
                }
            }
        } // Repeater id_content_synos_repeater

        readonly property bool haveStem: typeof dictJson.content.rel_word != "undefined"
                                         && typeof dictJson.content.rel_word.stem != "undefined"

        YTextMedium {
            font.pixelSize: 16
            color: YColors.red
            width: parent.width
            height: 28
            verticalAlignment: YTextBase.AlignBottom
            text: YTranslateText.cognate
            visible: id_wordinfo_column.haveStem
        }

        YTextBase {
            id: id_content_stem
            font.family: qmlGlobal.fontFamilyEnUs
            font.weight: Font.Medium
            color: "#FFFFFF"
            font.pixelSize: 18
            wrapMode: YText.Wrap
            textFormat: YTextBase.RichText
            width: parent.width
            height: paintedHeight
            text: visible ? "root: " + dictJson.content.rel_word.stem : ""
            visible: id_wordinfo_column.haveStem
        }

        Repeater {
            id: id_content_rel_word_rels_repeater
            model: id_wordinfo_column.haveStem ? dictJson.content.rel_word.rels : null

            Item {
                id: id_rel_word_rels_item
                width: id_wordinfo_column.width
                height: id_rel_word_rels_rel_words_column.height
                //property var modelModelData: model.modelData

                YTextBase {
                    id: id_content_rels_rel_pos_text
                    color: YColors.grayText
                    font.pixelSize: 14
                    font.family: "Castoro"
                    font.styleName: "italic"
                    width: 28
                    height: 22
                    verticalAlignment: Text.AlignBottom
                    text: model.modelData.rel.pos
                    //text: id_rel_word_rels_item.modelModelData.rel.pos
                }

                Column {
                    id: id_rel_word_rels_rel_words_column
                    anchors.left: id_content_rels_rel_pos_text.right
                    anchors.right: parent.right
                    spacing: 8
                    property var modelModelData: model.modelData

                    Repeater {
                        id: id_content_rel_word_rels_rel_words_repeater
                        model: id_rel_word_rels_rel_words_column.modelModelData.rel.words

                        YTextBase {
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            wrapMode: YText.Wrap
                            textFormat: YTextBase.RichText
                            width: id_rel_word_rels_rel_words_column.width
                            height: paintedHeight
                            text: '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; color: %1;">').arg(YColors.white) + model.modelData.word + '&nbsp;</span>'
                                  + '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1;">').arg(YColors.grayText) + model.modelData.tran + '</span>'
                        }

                    } // Repeater id_content_rel_word_rels_rel_words_repeater

                } // Column id_rel_word_rels_rel_words_column

            } // Item id_rel_word_rels_item

        } // Repeater id_content_rel_word_rels_repeater

        YTextMedium {
            font.pixelSize: 16
            color: YColors.red
            width: parent.width
            height: 28
            verticalAlignment: YTextBase.AlignBottom
            text: YTranslateText.exampleSentences
            visible: id_content_sentences_repeater.count > 0
        }

        Repeater {
            id: id_content_sentences_repeater
            model: dictJson.content.sentences

            Item {
                id: id_content_sentences_item
                width: id_wordinfo_column.width
                height: id_content_sentences_column.height

                YTextBase {
                    id: id_sentences_index_text
                    color: YColors.grayText
                    font.family: qmlGlobal.fontFamilyZhCn
                    font.pixelSize: 16
                    width: 28
                    height: id_content_sentences_column.height
                    text:  index + 1
                }

                Column {
                    id: id_content_sentences_column
                    anchors.left: id_sentences_index_text.right
                    anchors.right: parent.right
                    spacing: 6

                    YText {
                        font.family: qmlGlobal.fontFamilyEnUs
                        font.weight: Font.Medium
                        width: parent.width
                        height: paintedHeight
                        text: model.modelData.sEn
                        wrapMode: YTextMedium.Wrap
                    }

                    YTextBase {
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 18
                        textFormat: YTextBase.RichText
                        wrapMode: YTextBase.Wrap
                        color: YColors.grayText
                        width: parent.width
                        height: paintedHeight
                        text: {
                            if (!visible) return ""
                            let qsRst = ""
                            if (typeof model.modelData.sCn != "undefined") {
                                qsRst += model.modelData.sCn
                            }
                            if (typeof model.modelData.source != "undefined") {
                                qsRst += '<span style="color:#90919999;font-size:14px;">（'
                                        + YTranslateText.exampleSentencesFrom + model.modelData.source + '）</span>'
                            }
                            return qsRst
                        }
                        visible: typeof model.modelData.sCn != "undefined" || typeof model.modelData.source != "undefined"
                    }

                }

            }

        } // Repeater id_content_sentences_repeater

    }

}// Item root


