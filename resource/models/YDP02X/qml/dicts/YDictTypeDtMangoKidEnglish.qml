import QtQuick 2.12

import "../commons"
import "../i18n"
import "../components"
import com.youdao.pen 1.0

YDictTypeBase{
    title: YTranslateText.dtEnChKid
    Item{
        width: parent.width
        height: id_dict_content_column.height
        id:id_kid_item

        Column {
            id: id_dict_content_column
            readonly property var dictJson: JSON.parse(content)
            width: parent.width
            spacing: 0

            Column {
                width: id_dict_content_column.width
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                function getMeanModel(){
                    if (typeof dictJson.pure.m != "undefined") {
                        return  dictJson.pure.m
                    }
                    if(typeof dictJson.pure.brief_meaning != "undefined")
                    {
                        return dictJson.pure.brief_meaning
                    }
                }
                Repeater {
                    id: id_trans_repeater
                    model:{
                        let modelData = null
                        if (typeof dictJson.pure!= "undefined" &&typeof dictJson.pure.m != "undefined") {
                            modelData = dictJson.pure.m
                        }
                        if(typeof dictJson.pure.brief_meaning != "undefined"){
                            modelData = dictJson.pure.brief_meaning
                        }
                        return modelData
                    }
                    Item {
                        id: id_trans_item
                        width: parent.width
                        height: id_pos_mean.height
                        readonly property var modelModelData: model.modelData
                        Column{
                            id:id_pos_mean
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 10
                            Repeater{
                                model: {
                                    let modelData = null
                                    if (typeof id_trans_item.modelModelData.pos != "undefined") {
                                        modelData = new Array
                                        modelData.push(id_trans_item.modelModelData)
                                    }
                                    if (typeof id_trans_item.modelModelData.meanings !="undefined")
                                        modelData = id_trans_item.modelModelData.meanings
                                    return modelData
                                }
                                Column {
                                    id: id_trans_sense_column
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: 6

                                    Row{
                                        height: id_trans_pos_txt.contentHeight
                                        YTextBase {
                                            id: id_trans_pos_txt
                                            font.pixelSize: 18
                                            color: YColors.white
                                            wrapMode: YTextBase.Wrap
                                            height: contentHeight
                                            textFormat: YText.RichText
                                            // anchors.bottom: id_sense.bottom
                                            font.family: qmlGlobal.fontFamilyZhCn
                                            text: {
                                                if (typeof modelModelData.m != "undefined") {
                                                    if(typeof modelModelData.pos != "undefined") {
                                                        return  ('<span style="font-family:%1; font-style:italic; color:%2;">').arg(qmlGlobal.fontFamilyClass).arg(YColors.grayText)
                                                                + modelModelData.pos +'</span> ' + modelModelData.m
                                                    } else {
                                                        return  ('<span style="font-family:%1; font-style:italic; color:%2;">').arg(qmlGlobal.fontFamilyClass).arg(YColors.grayText)
                                                                + modelModelData.pos + '</span> '
                                                    }
                                                }
                                                if (typeof id_trans_item.modelModelData.pos !="undefined")
                                                    return  ('<span style="font-family:%1; font-style:italic; color:%2;">').arg(qmlGlobal.fontFamilyClass).arg(YColors.grayText)
                                                            + id_trans_item.modelModelData.pos + '</span> ' + model.modelData.meaning
                                            }
                                            width: 244
                                        }
                                    }

                                    Column{
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        spacing: 6
                                        Repeater {
                                            id: id_trans_sents_repeater
                                            model: {
                                                if (typeof id_trans_item.modelModelData.meanings!= "undefined"&&typeof id_trans_item.modelModelData.meanings[index].sentences != "undefined")
                                                    return id_trans_item.modelModelData.meanings[index].sentences
                                            }

                                            Column {
                                                id: id_trans_sents_column
                                                //anchors.leftMargin: -25
                                                anchors.right: parent.right
                                                anchors.left: parent.left
                                                //anchors.rightMargin: 16
                                                //width: id_trans_sense_column.width
                                                spacing: 4
                                                readonly property var modelModelData: model.modelData

                                                YTextMedium {
                                                    id: id_sents_en
                                                    height: id_sents_en.contentHeight
                                                    //anchors.right: parent.right
                                                    //anchors.rightMargin: 16
                                                    anchors.left: parent.left
                                                    width: 244
                                                    font.family: qmlGlobal.fontFamilyEnUs
                                                    text: (typeof id_trans_sents_column.modelModelData.sentence != "undefined")
                                                          ? "      " + id_trans_sents_column.modelModelData.sentence : ""
                                                    font.pixelSize: 18
                                                    wrapMode: YTextEnUs.WordWrap
                                                    YAudioPlayButton {
                                                        width: 24
                                                        implicitHeight: 24
                                                        sourceSize: Qt.size(24, 24)
                                                        imageName: "dict/sound"
                                                        id: id_follow_content_pron
                                                        textFontFamily: qmlGlobal.fontFamilyEnUs
                                                        textFormat: YText.PlainText
                                                        leftMargin: 0
                                                        anchors.left: parent.left
                                                        anchors.top:parent.top
                                                        anchors.topMargin: 2
                                                        //anchors.verticalCenter: parent.verticalCenter

                                                        color: YColors.black
                                                        //enabled: !id_sound_play.playing
                                                        text: ""
                                                        visible: id_sents_en.text.length
                                                        onValidClicked: {
                                                            let isUk,ukPhonetic,usPhonetic;
                                                            try {
                                                                console.log("##############",JSON.stringify(resultManager.phoneticSymbolJson));
                                                                var phoneticSymbolJson = JSON.parse(resultManager.phoneticSymbolJson);
                                                            } catch(e) { }
                                                            if (typeof phoneticSymbolJson != "undefined"){
                                                                ukPhonetic = typeof phoneticSymbolJson.uk == "undefined" ? "" : phoneticSymbolJson.uk;
                                                                usPhonetic = typeof phoneticSymbolJson.us == "undefined" ? "" : phoneticSymbolJson.us;
                                                            }
                                                            isUk = (settingManager.autoPronounceType === YEnum.UK) && ukPhonetic.length != 0
                                                            if (playing) {
                                                                logManager.sendHttpLog("action=detail_sentence_tts_click")
                                                                playWord(id_trans_sents_column.modelModelData.sentence, "en",
                                                                         id_trans_sents_column.modelModelData.sentence,
                                                                         isUk ? 1 : 2)
                                                            }
                                                        }
                                                    }
                                                }

                                                YTextBase {
                                                    id: id_sents_zh
                                                    font.pixelSize: 16
                                                    height: id_sents_zh.contentHeight
                                                    width: parent.width
                                                    color: YColors.grayText
                                                    font.family: qmlGlobal.fontFamilyZhCn
                                                    textFormat: YTextBase.RichText
                                                    wrapMode: YTextBase.Wrap
                                                    text: {
                                                        if(typeof id_trans_sents_column.modelModelData.meaning != "undefined")
                                                            return id_trans_sents_column.modelModelData.meaning
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            YSpacingForColumn{
                visible: id_anagram_wfs_repeater.count > 0
                height: 16
            }

            //单词变形
            YTextBase {
                font.pixelSize: 16
                color: YColors.red
                height:  22
                text: YTranslateText.wordsInflection
                visible: id_anagram_wfs_repeater.count > 0
            }

            YSpacingForColumn{
                visible: id_anagram_wfs_repeater.count > 0
                height: 6
            }
            Column {
                width: id_dict_content_column.width
                spacing: 6
                Repeater {
                    id: id_anagram_wfs_repeater
                    model: {
                        let result = new Array
                        if(typeof dictJson.pure.tenses != "undefined" &&typeof dictJson.pure.tenses.third_person_singular != "undefined")
                            result.push({"key":YTranslateText.thirdPersonSingular,"value":dictJson.pure.tenses.third_person_singular})
                        if(typeof dictJson.pure.tenses != "undefined" &&typeof dictJson.pure.tenses.present_participle != "undefined")
                            result.push({"key":YTranslateText.presentParticiple,"value":dictJson.pure.tenses.present_participle})
                        if(typeof dictJson.pure.tenses != "undefined" &&typeof dictJson.pure.tenses.past != "undefined")
                            result.push({"key":YTranslateText.past,"value":dictJson.pure.tenses.past})
                        if(typeof dictJson.pure.tenses != "undefined" &&typeof dictJson.pure.tenses.past_participle != "undefined")
                            result.push({"key":YTranslateText.pastParticiple,"value":dictJson.pure.tenses.past_participle})
                        return result
                    }
                    Item {
                        id: id_anagram_wfs_item
                        width: parent.width
                        height: id_wordsInflection_value.contentHeight

                        readonly property var modelModelData: model.modelData
                        YTextBase {
                            id: id_wordsInflection_key
                            width: id_wordsInflection_key.contentWidth
                            height: id_wordsInflection_key.contentHeight
                            font.pixelSize: 18
                            font.family: qmlGlobal.fontFamilyZhCn
                            color: YColors.grayText
                            text: id_anagram_wfs_item.modelModelData.key
                        }
                        YMouseArea{
                            width: id_wordsInflection_value.width
                            height: id_wordsInflection_value.height
                            anchors.left: id_wordsInflection_key.right
                            anchors.leftMargin: 10
                            YTextBase {
                                id: id_wordsInflection_value
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: {
                                    switch (id_anagram_wfs_item.modelModelData.key){
                                    case YTranslateText.thirdPersonSingular:
                                        return 200
                                    case YTranslateText.presentParticiple:
                                        return 224
                                    case YTranslateText.past:
                                        return 244
                                    case YTranslateText.pastParticiple:
                                        return 224
                                    }
                                }
                                height: contentHeight
                                font.pixelSize: 18
                                font.family: qmlGlobal.fontFamily
                                color: YColors.blueText
                                wrapMode: Text.Wrap
                                font.bold: true
                                text: id_anagram_wfs_item.modelModelData.value
                            }
                            onClicked: {
                                id_dict_page.clickSearchWord(id_anagram_wfs_item.modelModelData.value)
                            }
                        }
                    }
                }
            }

            YSpacingForColumn{
                visible: id_fixed_collocation_repeater.count > 0
                height: 16
            }

            //固定搭配
            YTextBase {
                id:id_fix_text
                font.pixelSize: 16
                color: YColors.red
                height:  22
                text: YTranslateText.fixedCollocation
                visible: id_fixed_collocation_repeater.count > 0 &&(
                             typeof  dictJson.pure.phrases!= "undefined"
                             && dictJson.pure.phrases.length > 0
                             && typeof dictJson.pure.phrases[0].phrase!= "undefined"
                             && dictJson.pure.phrases[0].phrase.length > 0)
            }
            YSpacingForColumn{
                visible: id_fixed_collocation_repeater.count > 0
                height: 6
            }
            Column {
                id:id_fixed_collocation_column
                width: id_dict_content_column.width
                spacing: 6
                property bool fixedLoadmoreVisible: false
                Repeater {
                    id: id_fixed_collocation_repeater
                    model: {
                        let fixedCollocationResult = new Array
                        let i =0
                        if(typeof  dictJson.pure.phrases!= "undefined")
                        {
                            dictJson.pure.phrases.some(item=>{
                                                           i++
                                                           fixedCollocationResult.push(item)
                                                           if(i>=3 && i<dictJson.pure.phrases.length)
                                                           {
                                                               id_fixed_collocation_column.fixedLoadmoreVisible =true
                                                               return true;
                                                           }
                                                           else
                                                           return false
                                                       })
                        }
                        return fixedCollocationResult
                    }
                    Item {
                        id: id_fixed_Collocation_item
                        width: parent.width
                        height: id_fixed_collocation_key.contentHeight+id_fixed_collocation_value.contentHeight

                        readonly property var modelModelData: model.modelData
                        YTextBase {
                            id: id_fixed_collocation_key
                            width: 244
                            height: contentHeight
                            font.pixelSize: 18
                            font.family: qmlGlobal.fontFamilyEnUs
                            color: YColors.white
                            font.bold: true
                            wrapMode: Text.WordWrap
                            text: id_fixed_Collocation_item.modelModelData.phrase
                        }
                        YTextBase {
                            id: id_fixed_collocation_value
                            width: 244
                            height: contentHeight
                            font.pixelSize: 16
                            anchors.top: id_fixed_collocation_key.bottom
                            anchors.topMargin: 4
                            font.family: qmlGlobal.fontFamilyZhCn
                            color: YColors.grayText
                            wrapMode: Text.WordWrap
                            text: id_fixed_Collocation_item.modelModelData.meanings[0]
                        }
                    }
                }
            }

            YSpacingForColumn{
                visible: id_fixed_collocation_repeater.count>0
                         && id_fix_text.visible
                         && id_fixed_collocation_column.fixedLoadmoreVisible
                height: 6
            }
            //全部按钮
            YButtonBase {
                width: parent.width
                height: 50
                visible: id_fixed_collocation_repeater.count>0
                         && id_fix_text.visible
                         && id_fixed_collocation_column.fixedLoadmoreVisible
                radius: height / 2
                YTextMedium {
                    id: id_button_tip
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: YTranslateText.loadmore
                }
                onClicked: {
                    logManager.sendHttpLog("action=detail_more_click&dict=kid-ec&card_name=collocation")
                    id_dict_page.backContentYPos =  id_container_flickable.contentY
                    qmlGlobal.showDictDetailPage(dictType, JSON.stringify(dictJson.pure.phrases), YTranslateText.fixedCollocation)
                }
            }

            YSpacingForColumn{
                visible: id_synonymsAndSynonyms_repeater.count > 0 && id_fix_text.visible
                height: 16
            }

            //同近义词
            YTextBase {
                font.pixelSize: 16
                color: YColors.red
                height:  22
                text: YTranslateText.synonymsAndSynonyms
                visible: id_synonymsAndSynonyms_repeater.count > 0
            }

            YSpacingForColumn{
                visible: id_synonymsAndSynonyms_repeater.count > 0
                height: 6
            }

            Column {
                id:id_synonymsAndSynonyms
                width: id_dict_content_column.width
                property bool synonymsMoreVisible: false
                spacing: 6
                function showPage(qrcqml, cachePage, properties) {
                    if ((typeof cachePage !== undefined) && cachePage) {
                        return id_page_pop_helper.cacheShow(qrcqml, false, properties)
                    }
                    return id_page_pop_helper.show(qrcqml, false, false, properties)
                }
                Repeater {
                    id: id_synonymsAndSynonyms_repeater
                    model: {
                        let resultArray = new Array
                        let i =0;
                        dictJson.pure.synonyms.some(item=>{
                                                        i++
                                                        resultArray.push(item)
                                                        if(i>=3 && i<dictJson.pure.synonyms.length)
                                                        {
                                                            id_synonymsAndSynonyms.synonymsMoreVisible =true
                                                            return true;
                                                        }
                                                        else
                                                        return false;
                                                    } )
                        return resultArray
                    }
                    Item {
                        id: id_synonymsAndSynonyms_item
                        width: parent.width
                        height: id_synonymsAndSynonyms_pos_txt.contentHeight+id_synonyms_flow.height

                        readonly property var modelModelData: model.modelData
                        YTextBase {
                            id: id_synonymsAndSynonyms_pos_txt
                            font.pixelSize: 18
                            font.family: qmlGlobal.fontFamilyZhCn
                            color: YColors.white
                            text: ('<span style="font-family:%1; font-style:italic; color:%2;">').arg(qmlGlobal.fontFamilyClass).arg(YColors.grayText)
                                  + id_synonymsAndSynonyms_item.modelModelData.pos + '</span>' + id_synonymsAndSynonyms_item.modelModelData.meaning
                            width: 244
                            wrapMode: YTextBase.Wrap
                            textFormat: YText.RichText
                            height: id_synonymsAndSynonyms_pos_txt.contentHeight
                        }

                        Flow{
                            id:id_synonyms_flow
                            width: 244
                            anchors.top: id_synonymsAndSynonyms_pos_txt.bottom
                            spacing:0
                            Repeater{
                                id:id_synonyms_repeter
                                model:{
                                    let resultArray = new Array
                                    let i =0;
                                    id_synonymsAndSynonyms_item.modelModelData.synonyms.some(item=>{
                                                                                                 i++
                                                                                                 resultArray.push(item)
                                                                                                 if(i>=3 && i<id_synonymsAndSynonyms_item.modelModelData.synonyms.length)
                                                                                                 {
                                                                                                     id_synonymsAndSynonyms.synonymsMoreVisible =true
                                                                                                     return true;
                                                                                                 }
                                                                                                 else
                                                                                                 return false;
                                                                                             } )
                                    return resultArray
                                }
                                YDictPageClickSearchTextItem{
                                    word:model.modelData
                                    isCHType: false
                                    onClicked: {
                                        id_dict_page.clickSearchWord(model.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            YSpacingForColumn{
                visible:  id_synonymsAndSynonyms_repeater.count>0 && id_synonymsAndSynonyms.synonymsMoreVisible
                height: 6
            }

            //全部按钮
            YButtonBase {
                width: parent.width
                height: 50
                visible: id_synonymsAndSynonyms_repeater.count>0 && id_synonymsAndSynonyms.synonymsMoreVisible
                radius:height/2
                YTextMedium {
                    id: id_all_button
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: YTranslateText.loadmore
                }
                onClicked: {
                    logManager.sendHttpLog("action=detail_more_click&dict=kid-ec&card_name=synonym")
                    id_dict_page.backContentYPos =  id_container_flickable.contentY
                    qmlGlobal.showDictDetailPage(dictType, JSON.stringify(dictJson.pure.synonyms), YTranslateText.synonymsAndSynonyms)
                }
            }
        }
        YPopLayer {
            id: id_page_pop_helper
        }
    }
}
