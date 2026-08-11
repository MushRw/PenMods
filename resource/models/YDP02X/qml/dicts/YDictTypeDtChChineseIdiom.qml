import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"
import "../components"

YDictTypeBase {
    id: id_dict_type_ch_chinese_idiom
    title: YTranslateText.dtChIdiom

    Item {
        width: parent.width
        height: id_for_wgt_ch.height

        Column {
            id: id_for_wgt_ch
            spacing: 0
            width: parent.width

            Item {
                id: id_pinyin_content_item
                height: id_pinyin_content_value.height + 16
                width: parent.width
                visible: pinyinContent.length > 0
                readonly property string pinyinContent: typeof dictJson.pinyin != "undefined" ? dictJson.pinyin.join(" ") : null
                readonly property string pinyinWithNum: typeof dictJson.pinyinWithNum != "undefined" ? dictJson.pinyinWithNum.join(" ") : null

                Component.onCompleted: {
                    if(isFirstDict && settingManager.isAutoPronounce) {
                        id_pinyin_sound_button.play()
                        id_pinyin_sound_button.playWord(resultManager.currentQuery, resultManager.getSoundLanguage(), chPinYinsSound === null ? resultManager.phoneticSymbolJson : chPinYinsSound,settingManager.autoPronounceType)
                    }
                }

                YAudioPlayButton {
                    id: id_pinyin_sound_button
                    width: 24
                    implicitHeight: 24
                    sourceSize: Qt.size(24, 24)
                    imageName: "dict/sound"
                    textFormat: YText.PlainText
                    leftMargin: 0
                    anchors.left: parent.left
                    color: YColors.black
                    onValidClicked: {
                        if (playing) {
                            playWord(resultManager.currentQuery, "zh", id_pinyin_content_item.pinyinWithNum)
                        }
                    }
                }

                YText {
                    id: id_pinyin_content_value
                    wrapMode: YText.Wrap
                    color: YColors.grayText
                    font.family: qmlGlobal.fontFamilyPinyin
                    font.pixelSize: 18
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 24
                    anchors.left: id_pinyin_sound_button.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    height: contentHeight
                    text: id_pinyin_content_item.pinyinContent
                }
            }

            YTextBase {
                id: id_detail_meaning_examples
                wrapMode: YText.Wrap
                color: YColors.white
                font.family: qmlGlobal.fontFamilyZhCn
                font.pixelSize: 18
                width: parent.width
                height: contentHeight
                text: dictJson.meaning
                visible: (typeof dictJson.meaning !== "undefined")
                         && (dictJson.meaning.length > 0)
                textFormat: YTextBase.PlainText
            }

            YSpacingForColumn{
                height: 16
                visible: id_story_word_value.visible
            }

            YText {
                wrapMode: YText.Wrap
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.red
                text: YTranslateText.idiomStory
                font.pixelSize: 16
                visible: id_story_word_value.visible
            }

            YSpacingForColumn{
                height: 6
                visible:id_story_word_value.visible
            }

            YText {
                id: id_story_word_value
                wrapMode: YText.Wrap
                color: YColors.white
                font.family: qmlGlobal.fontFamilyZhCn
                font.pixelSize: 18
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                width: parent.width
                height: contentHeight
                text: {
                    if(typeof dictJson.story!="undefined" && dictJson.story.length>48)
                    {
                        loadMoreVisible=true
                        return "     "+dictJson.story.substr(0,48).trim()+"..."
                    }else
                    {
                        loadMoreVisible=false
                        try {
                        return "     "+typeof dictJson.story != "undefined" &&
                                typeof dictJson.story.length!="undefined" && dictJson.story.length ? dictJson.story.trim() : ""
                        } catch (e) {
                            console.log("YDictTypeDtChChineseIdiom.qml, exception:"+e)
                            return "     "
                        }
                    }
                }
                visible: typeof dictJson.story!="undefined" && dictJson.story.length ? true : false
                property bool loadMoreVisible: false
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
                    //anchors.topMargin: 2
                    color: YColors.black
                    text: ""
                    onValidClicked: {
                        if (playing) {
                            logManager.sendHttpLog("action=detail_idiom_story")
                            playWord(dictJson.story.trim(), "zh")
                        }
                    }
                }
            }

            YSpacingForColumn{
                height: 6
                visible:id_story_word_value.loadMoreVisible
            }

            YButton {
                id: id_dict_story_detail_button
                radius: height / 2
                width: 98
                height: 40
                anchors.left: parent.left
                pixelSize: 16
                text: YTranslateText.loadmore
                color: YColors.grayNormal
                textColor: YColors.white
                visible: id_story_word_value.loadMoreVisible
                onValidClicked: {
                    id_dict_page.backContentYPos = id_container_flickable.contentY
                    qmlGlobal.showDictDetailPage(dictType, JSON.stringify({"story":dictJson.story.trim()}), YTranslateText.idiomStory)
                }
            }

            YSpacingForColumn{
                height: 16
                visible: id_source_word_value.visible
            }

            YText {
                wrapMode: YText.Wrap
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.red
                text: YTranslateText.idiomSource
                font.pixelSize: 16
                visible: id_source_word_value.visible
            }

            YSpacingForColumn{
                height: 6
                visible: id_source_word_value.visible
            }

            YTextBase {
                id: id_source_word_value
                property bool loadMoreVisible: false
                wrapMode: YText.Wrap
                color: YColors.white
                font.family: qmlGlobal.fontFamilyZhCn
                font.pixelSize: 18
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                width: parent.width
                height: contentHeight
                text: {
                    if(dictJson.source.length>48)
                    {
                         loadMoreVisible=true
                        return dictJson.source.substr(0,48)+"..."
                    }else
                    {
                        loadMoreVisible=false
                        return dictJson.source.length ? dictJson.source : ""
                    }
                }
                visible: typeof dictJson.source != "undefined" && dictJson.source.length?true:false
            }

            YSpacingForColumn{
                height: 6
                visible: id_source_word_value.loadMoreVisible
            }

            YButton {
                id: id_dict_detail_button
                radius: id_dict_story_detail_button.radius
                width: id_dict_story_detail_button.width
                height: id_dict_story_detail_button.height
                anchors.left: parent.left
                text: YTranslateText.loadmore
                color: YColors.grayNormal
                textColor: YColors.white
                visible: id_source_word_value.loadMoreVisible
                onValidClicked: {
                    id_dict_page.backContentYPos = id_container_flickable.contentY
                    qmlGlobal.showDictDetailPage(dictType, JSON.stringify({"source":dictJson.source}), YTranslateText.idiomSource)
                }
            }

            YSpacingForColumn{
                height: 16
                visible: id_synonyms_word_value.visible
            }

            YText {
                wrapMode: YText.Wrap
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.red
                text: YTranslateText.synonyms
                font.pixelSize: 16
                visible: id_synonyms_word_value.visible
            }
            YSpacingForColumn{
                height: 6
                visible: id_synonyms_word_value.visible
            }

            Flow{
                id:id_synonyms_word_value
                width: 256
                spacing: 10
                visible: typeof dictJson.synonyms != "undefined" && dictJson.synonyms.length
                Repeater{
                    id:id_synonyms_repeter
                    model: dictJson.synonyms
                    YDictPageClickSearchTextItem{
                        word:model.modelData
                        isCHType: true
                        onClicked: {
                            id_dict_page.clickSearchWord(model.modelData)
                        }
                    }
                }
            }

            YSpacingForColumn{
                height: 16
                visible: id_antonyms_word_value.visible
            }

            YText {
                wrapMode: YText.Wrap
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.red
                text: YTranslateText.antonyms
                font.pixelSize: 16
                visible: id_antonyms_word_value.visible
            }

            YSpacingForColumn{
                height: 6
                visible: id_antonyms_word_value.visible
            }

            Flow{
                id:id_antonyms_word_value
                width: 256
                spacing: 10
                visible: typeof dictJson.antonyms != "undefined" && dictJson.antonyms.length
                Repeater{
                    id:id_antonyms_repeter
                    model: dictJson.antonyms
                    YDictPageClickSearchTextItem{
                        word:model.modelData
                        isCHType: true
                        onClicked: {
                            id_dict_page.clickSearchWord(model.modelData)
                        }
                    }
                }
            }

            YSpacingForColumn{
                height: 16
                visible: id_exampleSentences_column.visible
            }

            YText {
                wrapMode: YText.Wrap
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.red
                text: YTranslateText.exampleSentences
                font.pixelSize: 16
                visible: id_exampleSentences_column.visible
            }

            YSpacingForColumn{
                height: 6
                visible: id_exampleSentences_column.visible
            }

            Column {
                id: id_exampleSentences_column
                width: 256
                spacing: 10
                visible: typeof dictJson.sentence != "undefined" && dictJson.sentence.length
                Repeater{
                    id:id_exampleSentences_repeter
                    model: dictJson.sentence
                    YTextBase {
                        id: id_exampleSentences_value
                        wrapMode: YText.Wrap
                        color: YColors.white
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 18
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 24
                        width: id_exampleSentences_column.width
                        height: contentHeight
                        textFormat: Text.RichText
                        text: {
                            if (typeof model.modelData.sentence == "string") {
                                let qsRst = model.modelData.sentence
                                const regEx = new RegExp(resultManager.currentQuery, "ig")
                                qsRst = qsRst.replace(regEx, function(param){
                                    return ("<font style='color:%2;'>%1</font>").arg(param).arg(YColors.red);
                                });
                                return qsRst
                            }
                            return ""
                        }
                        visible: text.length > 0
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("YDictTypeDtChChineseIdiom.qml ==== Component.onCompleted dictType:" + dictType + ", dictJson:" + dictJson)
    }
}
/*
一丝不苟
{
    "antonyms":[
        "粗枝大叶",
        "敷衍了事",
        "粗心大意"
    ],
    "meaning":"一点儿也不马虎。形容人做事认真细致。",
    "pinyin":[
        "yì",
        "sī",
        "bù",
        "gǒu"
    ],
    "sentence":[
        {
            "sentence":"她对待工作一丝不苟，认真负责。",
            "source":"",
            "type":"SENTENCE"
        }
    ],
    "source":"清朝吴敬梓的《儒林外史》第四回：“上司访知，见世叔一丝不苟，升迁就在指日。”",
    "story":"　　在明朝，皇帝禁止宰杀用来耕地的牛。有一天，乡绅张静斋与举人范进去拜访汤知县。汤知县招待他们时，有位老人送来了五十斤牛肉。汤知县以前收了老百姓很多礼物，但是皇上有禁令，不允许宰牛，这个老人送来的牛肉，汤知县不知道该怎么办，于是汤知县请教张静斋。张静斋说道：“你可以把那位送礼的老人抓起来，把送来的牛肉堆在大枷上面，贴告示说明他犯的错误。皇上如果知道你办事这样认真，肯定会提拔你的。”汤知县听后，就照着办了。
　　后来，人们用“一丝不苟”这个成语指做事情非常认真仔细。",
    "synonyms":[

    ]
}
  */
