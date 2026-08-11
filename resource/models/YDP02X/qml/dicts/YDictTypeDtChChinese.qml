import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YDictTypeBase {
    id: id_dict_type_ch_chinese
    title: YTranslateText.dtChChinese
    property var dictSelectDetailsJson: null

    Item {
        id: name
        width: parent.width
        height: id_for_wgt_ch_group_column.height

        Column {
            id: id_for_wgt_ch_group_column
            spacing: 10
            width: parent.width

            YDictPinyinListView {
                id: id_dict_ch_pinyin_list_view
                chCharacter: resultManager.currentQuery
                visible: chCharacter.length === 1 && (isFirstDict || chPinyinListData.length > 1)
                isFirstDict: id_dict_type_ch_chinese.isFirstDict
                onCurrentPinyinChanged: {
                    dictSelectDetailsJson = getDictSelectPinyinParaphrasesJson(dictJson, currentPinyin, dictType)
                }

                Component.onCompleted: {
                    id_dict_ch_pinyin_list_view.initPinyinListData(dictJson, dictType)
                    dictSelectDetailsJson = id_dict_ch_pinyin_list_view.getDictSelectPinyinParaphrasesJson(dictJson, id_dict_ch_pinyin_list_view.currentSelectedPinyin, dictType)
                    let haveStrokeInfo = false
                    if (typeof dictJson.strokeCount != "undefined") {
                        id_dict_page.strokeCount = dictJson.strokeCount
                        haveStrokeInfo = true
                    }
                    if ((typeof dictJson.structure != "undefined") && (dictJson.structure.length > 0)) {
                        id_dict_page.structure = dictJson.structure.split("结构").join('')
                        haveStrokeInfo = true
                    }
                    if ((typeof dictJson.radical != "undefined") && (dictJson.radical.length > 0)) {
                        id_dict_page.radical = dictJson.radical
                        haveStrokeInfo = true
                    }
                    id_dict_page.needShowStrokeView = haveStrokeInfo
                    if (isFirstDict) {
                        resultManager.phoneticSymbolJson = id_dict_ch_pinyin_list_view.currentSelectedPinyin
                        if (settingManager.isAutoPronounce) {
                            id_dict_ch_pinyin_list_view.autoPlayPinyin()
                        }
                    }
                }
            }

            Repeater {
                model: dictSelectDetailsJson === null ? null : dictSelectDetailsJson.meanings
                Row {
                    width: id_for_wgt_ch_group_column.width
                    height: id_detail_meaning_content.height
                    spacing: 8
                    YTextBase {
                        id: id_detail_meaning_label
                        color: YColors.grayText
                        font.pixelSize: 16
                        width: contentWidth
                        height: contentHeight
                        text: ("%1.").arg(index + 1)
                    }

                    Column {
                        id: id_detail_meaning_content
                        width: parent.width - parent.spacing - id_detail_meaning_label.width
                        spacing: 4

                        YTextMedium {
                            wrapMode: YText.Wrap
                            width: parent.width
                            height: contentHeight
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: model.modelData.value
                        }

                        YTextBase {
                            id: id_detail_meaning_examples
                            wrapMode: YText.Wrap
                            color: YColors.grayText
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 16
                            width: parent.width
                            height: contentHeight
                            text: model.modelData.example.join('、')
                        }
                    }
                }
            }

            YTextBase {
                id: id_word_group_title
                font.pixelSize: 16
                color: YColors.red
                height: contentHeight
                text: YTranslateText.groupOfWords
                visible: id_start_word_row.visible
                         || id_end_word_row.visible
                         || id_idioms_word_row.visible
            }

            Row {
                id: id_start_word_row
                spacing: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_start_word_row_column.height
                visible: dictSelectDetailsJson !== null
                         && (typeof dictSelectDetailsJson.start != "undefined")
                         && (dictSelectDetailsJson.start.length > 0)
                YTextBase {
                    id: id_start_word_label
                    color: YColors.grayText
                    font.pixelSize: 16
                    width: contentWidth
                    height: contentHeight
                    text: "1."
                }

                Column {
                    id: id_start_word_row_column
                    width: parent.width - parent.spacing - id_start_word_label.width
                    spacing: 4

                    YTextMedium {
                        wrapMode: YText.Wrap
                        width: parent.width
                        height: contentHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.wordsBeginningWith.arg(resultManager.currentQuery)
                    }

                    YTextBase {
                        id: id_start_word_value
                        wrapMode: YText.Wrap
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 24
                        width: parent.width
                        height: contentHeight
                        text: id_start_word_row.visible ? dictSelectDetailsJson.start.join('、') : ""
                    }
                }
            }

            Row {
                id: id_end_word_row
                spacing: 10
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_end_word_row_column.height
                visible: dictSelectDetailsJson !== null
                         && (typeof dictSelectDetailsJson.end != "undefined")
                         && (dictSelectDetailsJson.end.length > 0)
                YTextBase {
                    id: id_end_word_label
                    color: YColors.grayText
                    font.pixelSize: 16
                    width: contentWidth
                    height: contentHeight
                    text: {
                        if (id_start_word_row.visible) {
                            return "2."
                        }
                        return "1."
                    }
                }

                Column {
                    id: id_end_word_row_column
                    width: parent.width - parent.spacing - id_end_word_label.width
                    spacing: 4

                    YTextMedium {
                        wrapMode: YText.Wrap
                        width: parent.width
                        height: contentHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.wordsEndingWith.arg(resultManager.currentQuery)
                    }

                    YTextBase {
                        id: id_end_word_value
                        wrapMode: YText.Wrap
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 24
                        width: parent.width
                        height: contentHeight
                        text: id_end_word_row.visible ? dictSelectDetailsJson.end.join('、') : ""
                    }
                }
            }

            Row {
                id: id_idioms_word_row
                spacing: 10
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_idioms_word_column.height
                visible: dictSelectDetailsJson !== null
                         && (typeof dictSelectDetailsJson.idioms != "undefined")
                         && (dictSelectDetailsJson.idioms.length > 0)
                YTextBase {
                    id: id_idioms_word_label
                    color: YColors.grayText
                    font.pixelSize: 16
                    width: contentWidth
                    height: contentHeight
                    text: {
                        if (id_start_word_row.visible) {
                            if (id_end_word_row.visible) {
                                return "3."
                            }
                            return "2."
                        }
                        return "1."
                    }
                }

                Column {
                    id: id_idioms_word_column
                    width: parent.width - parent.spacing - id_idioms_word_label.width
                    spacing: 4

                    YTextMedium {
                        wrapMode: YText.Wrap
                        width: parent.width
                        height: contentHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.anIdiomWith.arg(resultManager.currentQuery)
                    }

                    YTextBase {
                        id: id_idioms_word_value
                        wrapMode: YText.Wrap
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 24
                        width: parent.width
                        height: contentHeight
                        text: id_idioms_word_row.visible ? dictSelectDetailsJson.idioms.join('、') : ""
                    }
                }
            }

            YTextBase {
                id: id_synonyms_antonyms_title
                font.pixelSize: 16
                color: YColors.red
                height: contentHeight
                text: YTranslateText.synonymsAndAntonyms
                visible: id_synonyms_word_row.visible
                         || id_antonyms_word_row.visible
            }

            Row {
                id: id_synonyms_word_row
                spacing: 10
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_synonyms_word_content.height
                visible: dictSelectDetailsJson !== null
                         && (typeof dictSelectDetailsJson.synonyms != "undefined")
                         && (dictSelectDetailsJson.synonyms.length > 0)
                YTextBase {
                    id: id_synonyms_word_label
                    color: YColors.grayText
                    font.pixelSize: 16
                    width: contentWidth
                    height: contentHeight
                    text: "1."
                }

                Column {
                    id: id_synonyms_word_content
                    width: parent.width - parent.spacing - id_synonyms_word_label.width
                    spacing: 4

                    YTextMedium {
                        width: parent.width
                        height: contentHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.synonyms
                    }

                    YTextBase {
                        id: id_synonyms_word_value
                        wrapMode: YText.Wrap
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        width: parent.width
                        height: contentHeight
                        text: id_synonyms_word_row.visible ? dictSelectDetailsJson.synonyms.join('、') : ""
                    }
                }
            }

            Row {
                id: id_antonyms_word_row
                spacing: 10
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_antonyms_word_content.height
                visible: dictSelectDetailsJson !== null
                         && (typeof dictSelectDetailsJson.antonyms != "undefined")
                         && (dictSelectDetailsJson.antonyms.length > 0)
                YTextBase {
                    id: id_antonyms_word_label
                    color: YColors.grayText
                    font.pixelSize: 16
                    width: contentWidth
                    height: contentHeight
                    text: {
                        if (id_synonyms_word_row.visible) {
                            return "2."
                        }
                        return "1."
                    }
                }

                Column {
                    id: id_antonyms_word_content
                    width: parent.width - parent.spacing - id_antonyms_word_label.width
                    spacing: 4

                    YTextMedium {
                        wrapMode: YText.Wrap
                        width: parent.width
                        height: contentHeight
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.antonyms
                    }

                    YTextBase {
                        id: id_antonyms_word_value
                        wrapMode: YText.Wrap
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        width: parent.width
                        height: contentHeight
                        text: id_antonyms_word_row.visible ? dictSelectDetailsJson.antonyms.join('、') : ""
                    }
                }
            }

        }

    }

}

// for YEnum.WGT_Ch === resultManager.currentQueryType
// 易
/*
{
    "details": [
        {
            "antonyms": [
                "难"
            ],
            "end": [
                "容易",
                "贸易",
                "不易",
                "交易",
                "简易",
                "改易",
                "辟易",
                "平易",
                "乐易",
                "难易",
                "更易",
                "移易"
            ],
            "idioms": [
                "平易近人",
                "轻而易举",
                "显而 易见"
            ],
            "meanings": [
                {
                    "value": "不难的，轻松，简单，省力",
                    "example": [
                        "容易",
                        "轻易",
                        "浅易",
                        "易如反掌",
                        "来之不易"
                    ]
                },
                {
                    "value": "一物换一物，交换",
                    "example": [
                        "贸易",
                        "交易",
                        "易货",
                        "国际贸易",
                        "以物易物"
                    ]
                },
                {
                    "value": "改变，发生变化，与原来不一样",
                    "example": [
                        "易容",
                        "易手",
                        "移风易俗",
                        "改弦易辙",
                        "易地而处"
                    ]
                },
                {
                    "value": "和蔼可亲，好相处",
                    "example": [
                        "和易",
                        "平易",
                        "平易近人",
                        "平心易气"
                    ]
                },
                {
                    "value": "态度傲慢 ，轻视",
                    "example": [
                        "躁易",
                        "佻易",
                        "玩易"
                    ]
                },
                {
                    "value": "指古代占卜之书",
                    "example": [
                        "《周易》",
                        "《易经》"
                    ]
                },
                {
                    "value": "铲除杂草，整治",
                    "example": [
                        "易田",
                        "易路"
                    ]
                }
            ],
            "pinyin": "yì",
            "start": [
                "易于",
                "易传",
                "易帜",
                "易水",
                "易与",
                "易经",
                "易地"
            ],
            "synonyms": []
        }
    ],
    "radical": "日(曰)",
    "stroke": [
        "丨",
        "ㄱ",
        "一",
        "一",
        "丿",
        "㇆",
        "丿",
        "丿"
    ],
    "strokeCount": 8,
    "structure": "上下结构"
}
  */
