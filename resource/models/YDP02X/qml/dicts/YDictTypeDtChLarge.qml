import QtQuick 2.12

import "../commons"
import "../components"
import "../i18n"

YDictTypeBase {
    id: id_dict_type_ch_large
    title: YTranslateText.dtChLarge
    visible: dictSelectDataJson !== null
    property var dictSelectDataJson: null

    Item {
        id: name
        width: parent.width
        height: id_word_Column.height

        Column {
            id: id_word_Column
            spacing: 10
            width: parent.width
            property var modelModelData: dictSelectDataJson

            YDictPinyinListView {
                id: id_dict_ch_pinyin_list_view
                chCharacter: resultManager.currentQuery
                visible: chCharacter.length === 1 && (isFirstDict || chPinyinListData.length > 1)
                isFirstDict: id_dict_type_ch_large.isFirstDict
                onCurrentPinyinChanged: {
                    dictSelectDataJson = getDictSelectPinyinParaphrasesJson(dictJson, currentPinyin, dictType)
                }

                Component.onCompleted: {
                    id_dict_ch_pinyin_list_view.initPinyinListData(dictJson, dictType)
                    dictSelectDataJson = id_dict_ch_pinyin_list_view.getDictSelectPinyinParaphrasesJson(dictJson, id_dict_ch_pinyin_list_view.currentSelectedPinyin, dictType)
                    if (isFirstDict) {
                        resultManager.phoneticSymbolJson = id_dict_ch_pinyin_list_view.currentSelectedPinyin
                        if (settingManager.isAutoPronounce) {
                            id_dict_ch_pinyin_list_view.autoPlayPinyin()
                        }
                    }
                }
            }

            YTextBase {
                font.pixelSize: 18
                wrapMode: YTextBase.Wrap
                textFormat: YTextBase.RichText
                width: id_word_Column.width
                height: contentHeight
                text: visible
                      ? '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1; font-weight: 500">').arg(YColors.white) + dictJson.word + '</span>'
                        + '<span>&nbsp;&nbsp;&nbsp;&nbsp;</span>'
                        + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; color: %1; font-weight: 400;">').arg(YColors.grayText) + id_word_Column.modelModelData.phone + '</span>'
                      : ""
                visible: id_word_Column.modelModelData !== null
            } // text word_phone

            Item {
                id: id_word_trs_item
                width: id_word_Column.width
                height: id_word_trs_content_column.height
                property var modelModelData: id_word_Column.modelModelData === null || (typeof id_word_Column.modelModelData.trs == "undefined") ? null : id_word_Column.modelModelData.trs[0]
                visible: id_word_trs_item.modelModelData !== null
                         && typeof id_word_trs_item.modelModelData.tr != "undefined"
                         && (typeof id_word_trs_item.modelModelData.tr.cn != "undefined"
                             || typeof id_word_trs_item.modelModelData.tr.en != "undefined")

                YTextMedium {
                    id: id_word_trs_index
                    color: YColors.grayText
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamilyZhCn
                    width: 28
                    height: id_word_trs_content_column.height
                    text: ("1.")
                    //text: "1."
                } // Text id_word_trs_index

                Column {
                    id: id_word_trs_content_column
                    spacing: 8
                    anchors.left: id_word_trs_index.right
                    anchors.right: parent.right

                    YTextBase {
                        id: id_word_trs_pos
                        width: parent.width
                        height: contentHeight
                        font.weight: Font.Medium
                        wrapMode: YTextBase.Wrap
                        textFormat: YTextBase.RichText
                        text: {
                            if (!id_word_trs_item.visible) return ""
                            if (!id_word_trs_item.visible) return ""
                            let qsPos = (typeof id_word_trs_item.modelModelData.pos != "undefined")
                                         ? "&lt;" + id_word_trs_item.modelModelData.pos + "&gt;" : ""
                            let qsTranCn = (typeof id_word_trs_item.modelModelData.tr.cn != "undefined")
                                            ? ("（" + id_word_trs_item.modelModelData.tr.cn + "）") : ""
                            let qsTranEn = (typeof id_word_trs_item.modelModelData.tr.en != "undefined")
                                            ? id_word_trs_item.modelModelData.tr.en : ""
                            return '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1; font-size: 16px">').arg(YColors.grayText) + qsPos + '</span>'
                                    + '<span style="font-family: ' + qmlGlobal.fontFamilyZhCn + ('; color: %1; font-size: 18px">').arg(YColors.white) + qsTranCn + '</span>'
                                    + '<span style="font-family: ' + qmlGlobal.fontFamilyEnUs + ('; color: %1; font-size: 18px">').arg(YColors.white) + qsTranEn + '</span>'
                        }
                    } // Text id_word_trs_pos

                    Item {
                        id: id_word_trs_sents_item
                        width: id_word_trs_content_column.width
                        height: id_word_trs_sents_content_column.height
                        property var modelModelData: !id_word_trs_item.visible || (typeof id_word_trs_item.modelModelData.sents == "undefined") ? null : id_word_trs_item.modelModelData.sents[0]

                        YTextBase {
                            id: id_word_trs_sents_index
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            font.family: qmlGlobal.fontFamilyEnUs
                            width: 20
                            height: id_word_trs_sents_content_column.height
                            text: visible ? ("·") : ""
                            visible: id_word_trs_sents_cn.visible || id_word_trs_sents_en.visible
                        }

                        Column {
                            id: id_word_trs_sents_content_column
                            spacing: 4
                            anchors.left: id_word_trs_sents_index.right
                            anchors.right: parent.right

                            YText {
                                id: id_word_trs_sents_cn
                                width: parent.width
                                height: contentHeight
                                font.family: qmlGlobal.fontFamilyZhCn
                                font.weight: Font.Normal
                                wrapMode: YTextBase.Wrap
                                text: visible ? id_word_trs_sents_item.modelModelData.cn : ""
                                visible: id_word_trs_sents_item.modelModelData !== null && typeof id_word_trs_sents_item.modelModelData.cn != "undefined"
                            } // Text id_word_trs_sents_cn


                            YTextBase {
                                id: id_word_trs_sents_en
                                width: parent.width
                                height: contentHeight
                                font.family: qmlGlobal.fontFamilyEnUs
                                font.pixelSize: 18
                                font.weight: Font.Normal
                                wrapMode: YTextBase.Wrap
                                color: YColors.grayText
                                text: visible ? id_word_trs_sents_item.modelModelData.en : ""
                                visible: id_word_trs_sents_item.modelModelData !== null && typeof id_word_trs_sents_item.modelModelData.en != "undefined"
                            } // Text id_word_trs_sents_en

                        } // Column id_word_trs_sents_content_column

                    } // Item id_word_trs_sents_item

                } // Column id_word_trs_content_column

            } // Item id_word_trs_item

        } // Column

    }
}

/*
    // 那
{
    "dataList":[
        {
            "trs":[
                {
                    "tr":{
                        "en":"that",
                        "cn":"Ⅰ□代指示比较远的人或事物"
                    },
                    "sents":[
                        {
                            "en":"Who is that?",
                            "cn":"那是谁?"
                        },
                        {
                            "en":"That was my fault",
                            "cn":"那是我的过错。"
                        },
                        {
                            "en":"That is a factory",
                            "cn":"那是一个工厂。"
                        },
                        {
                            "en":"That was in 1989",
                            "cn":"那是1989年的事。"
                        }
                    ]
                }
            ],
            "phone":"[nà]",
            "notice":"[": ① 单用的“那”限于在动词前。 在动词后面用“那个”， 只有跟“这”对举的时候可以用“那”， 如: 说这道 那 的; 看看这， 看看 那， 真有说 不出的高兴。 ② 在口语里， “那”单用或者后面直接跟名词， 说 nà 或 nè; “那”后面跟量词或数词加量词， 常常说 nèi 或 nè。 以下“那个”、“那会儿”、“那些”、“那样”各条在口语里都常常说 nèi- 或 nè-， “那么些”、“那么样”、“那么着”各条在口语里都常常说 nè-。 Ⅱ □连  (那么) then; in that case: 那 我们就不再等了。 In that case, we won't wait any longer. 你要是跟我们一块走， 那 就得快点。 If you're coming with us, you must hurry. 如果你喜欢， 那 就买吧! If you like it, take it, then."]"
        },
        {
            "trs":[
                {
                    "pos":"名",
                    "tr":{
                        "en":"a surname",
                        "cn":"姓氏"
                    },
                    "sents":[
                        {
                            "en":"Na Rong",
                            "cn":"那荣"
                        }
                    ]
                }
            ],
            "phone":"[nā]"
        },
        {
            "trs":[
                {
                    "pos":"名",
                    "tr":{
                        "en":"a surname",
                        "cn":"姓氏"
                    },
                    "sents":[
                        {
                            "en":"Nuo Jian",
                            "cn":"那鉴"
                        }
                    ]
                }
            ],
            "phone":"[nuó]"
        },
        {
            "trs":[
                {
                    "pos":"代",
                    "tr":{
                        "en":"which; what",
                        "cn":"表示疑问"
                    },
                    "sents":[
                        {
                            "en":"Which one of you is Mr.",
                            "cn":"你们中间那一位是王先生?"
                        },
                        {
                            "en":"What is your favourite kind of music?",
                            "cn":"你最喜欢那种音乐?"
                        },
                        {
                            "en":"What foreign language are you studying?.",
                            "cn":"你学的是那国语言?"
                        }
                    ]
                },
                {
                    "pos":"代",
                    "tr":{
                        "en":"any",
                        "cn":"泛指"
                    }
                },
                {
                    "pos":"副",
                    "tr":{
                        "cn":"表示反问"
                    },
                    "sents":[
                        {
                            "en":"How can there be things as such?",
                            "cn":"那会有这种事?"
                        }
                    ]
                }
            ],
            "phone":"[nǎ]"
        }
    ],
    "word":"那"
}
  */

