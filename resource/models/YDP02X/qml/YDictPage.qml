import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./dicts"
import "./components"
import "./i18n"

YBackButtonPage {
    id: id_dict_page
    objectName: "YPage===YDictPage.qml"
    pageIndex: YEnum.PageIndex.Dict

    readonly property int tagsIndex: id_container_flickable.privateTagsIndex
    readonly property bool displayWords: (id_dict_listview.count > 0)
                                         && (tagsIndex >= 0)
    property var stackQueryResult: []

    property string title: ""

    property bool needShowStrokeView: false
    property int strokeCount: 0
    property string structure: ""
    property string radical: ""
    property int backCountY: 0
    property int backContentYCount : 0
    property bool searchMoreIsClick: false
    property var containWidth: 256 + 6
    property alias needSearchMoreVisible: id_head_search_more_loader.visibleSet
    property var backContentYPos:null

    property var chPinYinsSound: null //中文多音字发音字段
    property var chWordSourceData: ""
    property var ocrContentString: ""
    property var sentenceMeanPos: 0
    property bool isButtonIsRePress: !systemBase.isButtonRelease
    property var reportedSet: new Set()
    property alias isScannig: id_dict_listview.isScanning

    onOcrContentStringChanged:  {
        console.log("headviewModel:"+ocrContentString)
        //id_dict_listview.repeaterModel =  ocrContentString
        id_dict_content_view_repeater_empty_check_timer.restart()
    }

    onIsScannigChanged: {
        if(!isScannig)
            id_dict_content_view_repeater_empty_check_timer.restart()
        else {
            if(resultManager.itemCount) {
                ocrContentString = ""
            }
        }
    }

    function initStrokeInfo() {
        needShowStrokeView = false
        strokeCount = 0
        structure = ""
        radical = ""
    }

    function arrayContains(arr, val) {
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] === val) {
                return true;
            }
        }
        return false;
    }

    function simpleParaphraseFunc(content, dictType) {
        let qsSrcLang = resultManager.srcLang
        let qsDstLang = resultManager.dstLang
        if (dictType === YEnum.AsyncLocalTran || dictType === YEnum.NetTran) {
            return ["", content, qsSrcLang, qsDstLang]
        }

        let dictJson = null;
        try{
            dictJson = JSON.parse(content)
        }
        catch(err){
            console.log("parse dict json error:", err);
            return ["", "", qsSrcLang, qsDstLang]
        }
        let pos = ""
        let trans = ""
        switch (dictType) {
        case YEnum.DtChChinese:
            if (typeof dictJson.meanings != "undefined") {
                if (typeof dictJson.meanings[0].pos != "undefined") pos = dictJson.meanings[0].pos
                if (typeof dictJson.meanings[0].value != "undefined") trans = dictJson.meanings[0].value
            } else if (typeof dictJson.details != "undefined" && typeof dictJson.details[0].meanings != "undefined") {
                if (typeof dictJson.details[0].meanings[0].pos != "undefined") pos = dictJson.details[0].meanings[0].pos
                if (typeof dictJson.details[0].meanings[0].value != "undefined") trans = dictJson.details[0].meanings[0].value
            }
            qsSrcLang = "zh"
            qsDstLang = "zh"
            break
        case YEnum.DtChEnglish:
        case YEnum.DtChEnKid:
            if (typeof dictJson.pure.word != "undefined") {
                trans = dictJson.pure.word.trs[0]["#text"]
            }
            else {
                trans = dictJson.pure[0].w
            }
            qsSrcLang = "zh"
            qsDstLang = "en"
            break
        case YEnum.DtChLarge:
            qsSrcLang = "zh"
            if (typeof dictJson.dataList[0].trs[0].pos != "undefined") pos = dictJson.dataList[0].trs[0].pos
            if (typeof dictJson.dataList[0].trs[0].tr.en != "undefined") {
                trans = dictJson.dataList[0].trs[0].tr.en
                qsDstLang = "en"
            } else if (typeof dictJson.dataList[0].trs[0].tr.cn != "undefined") {
                trans = dictJson.dataList[0].trs[0].tr.cn
                qsDstLang = "zh"
            }
            break
        case YEnum.DtChAncientWord:
            if (typeof dictJson.paraphrases[0].detailParas[0].paraItems[0].para != "undefined") {
                trans = dictJson.paraphrases[0].detailParas[0].paraItems[0].para
            }
            qsSrcLang = "zh"
            qsDstLang = "zh"
            break
        case YEnum.DtSenior:
            if (typeof dictJson.trans[0].pos != "undefined") pos = dictJson.trans[0].pos
            if (typeof dictJson.trans[0].sense != "undefined") trans = dictJson.trans[0].sense
            qsSrcLang = "en"
            qsDstLang = "zh"
            break
        case YEnum.DtWebster:
            if (typeof dictJson.wordList[0].def.sensb[0].et != "undefined") pos = dictJson.wordList[0].def.sensb[0].et
            if (typeof dictJson.wordList[0].def.sensb[0].meaning[0].sense == "undefined") {
                trans = dictJson.wordList[0].def.sensb[0].meaning[0].dt.content[0]
            } else {
                trans = dictJson.wordList[0].def.sensb[0].meaning[0].sense[0].dt.content[0]
            }
            qsSrcLang = "en"
            qsDstLang = "en"
            break
        case YEnum.DtOxford:
            if (typeof dictJson.wordList[0]["p-g"] != "undefined") {
                pos = dictJson.wordList[0]["p-g"][0].p[0].p
                if (typeof dictJson.wordList[0]["p-g"][0]["sd-g"] != "undefined") {
                    trans = dictJson.wordList[0]["p-g"][0]["sd-g"][0].sd.chn.content
                }
            } else {
                pos = dictJson.wordList[0]["h-g"].p[0].p
                if (typeof dictJson.wordList[0]["h-g"]["sd-g"] != "undefined") {
                    trans = dictJson.wordList[0]["h-g"]["sd-g"][0].sd.chn.content
                }
            }
            qsSrcLang = "en"
            qsDstLang = "zh"
            break
        case YEnum.DtTOEFL:
        case YEnum.DtGRE:
        case YEnum.DtSSAT:
        case YEnum.DtSAT:
        case YEnum.DtIELTS:
            qsSrcLang = "en"
            if (typeof dictJson.content.trans[0].pos != "undefined") pos = dictJson.content.trans[0].pos
            if (typeof dictJson.content.trans[0].tran[0].cn != "undefined") {
                trans = dictJson.content.trans[0].tran[0].cn
                qsDstLang = "zh"
            } else {
                trans = dictJson.content.trans[0].tran[0].en
                qsDstLang = "en"
            }
            break
        case YEnum.DtSimple:
        case YEnum.DtEnChKid:
            if (typeof dictJson.pure.word != "undefined" && typeof dictJson.pure.word.trs != "undefined") {
                pos = dictJson.pure.word.trs[0].pos
                trans = dictJson.pure.word.trs[0].tran
            }
            else if (typeof dictJson.pure.m != "undefined") {
                pos = dictJson.pure.m[0].pos
                trans = dictJson.pure.m[0].m
            } else if (typeof dictJson.pure.brief_meaning != "undefined")//mango新词典解析
            {
                pos = dictJson.pure.brief_meaning[0].pos
                trans = dictJson.pure.brief_meaning[0].meanings[0].meaning
            }
            qsSrcLang = "en"
            qsDstLang = "zh"
            break
        case YEnum.DtChKo:
            if (typeof dictJson.dataList[0].meanings.sense[0].pos != "undefined") {
                pos = dictJson.dataList[0].meanings.sense[0].pos
            }
            if (typeof dictJson.dataList[0].meanings.sense[0].trs != "undefined"
                    && typeof dictJson.dataList[0].meanings.sense[0].trs[0].tr != "undefined") {
                trans = dictJson.dataList[0].meanings.sense[0].trs[0].tr
            }
            qsSrcLang = "zh"
            qsDstLang = "ko"
            break
        case YEnum.DtKoCh:
            if (typeof dictJson.dataList[0].pos != "undefined") {
                pos = dictJson.dataList[0].meanings.sense[0].pos
            }
            if (typeof dictJson.dataList[0].meanings.sense[0].trs != "undefined"
                    && typeof dictJson.dataList[0].meanings.sense[0].trs[0].tr != "undefined") {
                trans = dictJson.dataList[0].meanings.sense[0].trs[0].tr
                trans = trans.replace(/<pinyin>.+?<\/pinyin>/g, '')
            }
            qsSrcLang = "ko"
            qsDstLang = "zh"
            break
        default:
            break
        }
        if (typeof pos != "string") pos = ""
        if (typeof trans != "string") {
            trans = ""
        } else {
            //避免换行符和 html tag 影响显示效果，特殊处理一下
            trans = trans.replace(/\n/g, " ")
            trans = trans.replace(/<[^>]+>/g, "")
        }
        return [pos, trans, qsSrcLang, qsDstLang]
    }

    function setPhonic(dictJsonSimple) {
          if (typeof dictJsonSimple.pure.phonics != "undefined") {
              let spellPosArray = []
              for (let m = 0; m < dictJsonSimple.pure.phonics.length; m++) {
                  if (typeof dictJsonSimple.pure.phonics[m].position != "undefined") {
                      for (let j = 0; j < dictJsonSimple.pure.phonics[m].position.length; j++) {
                          spellPosArray.push(dictJsonSimple.pure.phonics[m].position[j])
                      }
                  }
              }
              if(spellPosArray.length === resultManager.currentQuery.length)
               spellManager.phonics  = JSON.stringify(dictJsonSimple.pure.phonics);
          }
      }

    function getDictContentValue(dictType,content,index){
           switch (dictType) {
           case YEnum.DtChChinese:
           case YEnum.DtChIdiom:
               let dictJson = JSON.parse(content)
               if (YEnum.WGT_Ch_Group === resultManager.currentQueryType) {
                   resultManager.phoneticSymbolJson = dictJson.pinyin.join(" ")
                   if(typeof  dictJson.pinyinWithNum != "undefined")
                       chPinYinsSound = typeof dictJson.pinyinWithNum!="string"?dictJson.pinyinWithNum.join(" ")
                                                                               :dictJson.pinyinWithNum
                   if (typeof  dictJson.source != "undefined") {
                       chWordSourceData = dictJson.source
                   }

               } else {
                   resultManager.phoneticSymbolJson = dictJson.details[0].pinyin
                   if(typeof dictJson.details[0].pinyinWithNum != "undefined")
                       chPinYinsSound =typeof dictJson.details[0].pinyinWithNum!="string" ? dictJson.details[0].pinyinWithNum.join(" ")
                                                                                 : dictJson.details[0].pinyinWithNum
               }
               break
           case YEnum.DtChPoemDict:
               let dictJsonStr = JSON.parse(content)
               if(dictJsonStr.source === "poem_data" ){
                   dictJsonStr.poems.some(function(objectJson){
                       if(typeof objectJson.detail.title.origin != "undefined"
                               && typeof objectJson.detail.title.position != "undefined") {
                           let pos = objectJson.detail.title.origin.trim().indexOf(resultManager.currentQuery)
                           let pinYinPosIndexs = objectJson.detail.title.position
                           if (pos === -1) {
                               let originProcess = objectJson.detail.title.origin.replace("·","")
                               pos = originProcess.indexOf(resultManager.currentQuery)
                               for (let k = 0; k < objectJson.detail.title.origin.length; k++) {
                                   if (objectJson.detail.title.origin[k] === '·') {
                                       objectJson.detail.title.origin[k] = ""
                                       for (let m = 0; m < pinYinPosIndexs.length; m++) {
                                           if (pinYinPosIndexs[m] > k + 1) {
                                               pinYinPosIndexs[m]  = pinYinPosIndexs[m] - 1
                                           }
                                       }
                                   }
                               }
                           }
                           if(typeof objectJson.detail.title.pinyinWithNum!="undefined"
                                   && pos != -1 ) {
                               let pinYinJson ="["
                               if(typeof objectJson.detail.title.position!="undefined") {
                                   let pinYinPos = -1
                                   for(let i = 0; i<resultManager.currentQuery.length; i++) {
                                       pinYinPos = pinYinPosIndexs.indexOf(pos+i+1)
                                       if( pinYinPos !== -1) {
                                           pinYinJson+="{"+'"pinYinPos"'+':'+ (i+1)+
                                                   ',"pinyinWithNum"'+':"'+objectJson.detail.title.pinyinWithNum[pinYinPos]+'"},'
                                       } else {
                                       }
                                   }
                                   if (pinYinJson.indexOf("},") !== -1)
                                       pinYinJson = pinYinJson.substr(0,pinYinJson.length -1) + "]"
                                   //                                for(let j = 0; j<objectJson.detail.title.position.length; j++)
                                   //                                {
                                   //                                    pinYinJson+="{"+'"pinYinPos"'+':'+objectJson.detail.title.position[j]+',"pinyinWithNum"'+':"'+objectJson.detail.title.pinyinWithNum[j]+'"}'
                                   //                                    pinYinJson+=(j!=objectJson.detail.title.position.length-1)?",":"]"
                                   //                                }

                               }
                               console.log("*************pinYinJson:"+pinYinJson)
                               chPinYinsSound =pinYinJson.indexOf("{") !== -1 ? pinYinJson : objectJson.detail.title === resultManager.currentQuery ?
                                                                                    (typeof objectJson.detail.title.pinyinWithNum != "string" ?
                                                                                         objectJson.detail.title.pinyinWithNum.join(" ") :
                                                                                         objectJson.detail.title.pinyinWithNum) : null
                               return true
                           }
                       }
                   })
               }
               else if(dictJsonStr.source === "poem_sentence")
               {
                   dictJsonStr.poems.some(function(objectJson){

                       if(typeof objectJson.detail.content!="undefined")
                       {
                           for(let j=0;j<objectJson.detail.content.length;j++)
                           {
                               let contentJson = objectJson.detail.content[j]
                               for(let i=0;i<contentJson.sentences.length;i++)
                               {
                                   let jObjec =contentJson.sentences[i]
                                   let pos = jObjec.origin.trim().indexOf(resultManager.currentQuery)
                                   if(typeof jObjec.pinyinWithNum !="undefined" && pos !== -1)
                                   {
                                       let pinYinJson ="["
                                           if(typeof jObjec.position!="undefined") {
                                               let pinYinPos = -1
                                               for(let i = 0; i < resultManager.currentQuery.length; i++) {
                                                    pinYinPos = jObjec.position.indexOf(pos+i+1)
                                                   if( pinYinPos !== -1) {
                                                       pinYinJson += "{" + '"pinYinPos"' + ':' + (i+1) +
                                                               ',"pinyinWithNum"' + ':"' + jObjec.pinyinWithNum[pinYinPos]+'"},'
                                                   }
                                               }
                                               if (pinYinJson.indexOf("},") !== -1)
                                                   pinYinJson = pinYinJson.substr(0,pinYinJson.length -1) + "]"
   //                                            for(let j = 0; j<jObjec.position.length; j++)
   //                                            {
   //                                                pinYinJson+="{"+'"pinYinPos"'+':'+jObjec.position[j]+',"pinyinWithNum"'+':"'+jObjec.pinyinWithNum[j]+'"}'
   //                                                pinYinJson+=(j!=jObjec.position.length-1)?",":"]"
   //                                            }
                                           }
                                         chPinYinsSound = pinYinJson.indexOf("{") !== -1 ? pinYinJson : null
                                       return true
                                   }
                               }
                           }
                       }
                   })
               }
               break;
           case YEnum.DtSimple:
           case YEnum.DtEnChKid:
               let dictJsonSimple = JSON.parse(content)
               let phoneticJsonObj = new Object
               try{
                   // 格式新旧兼容
                   if (typeof dictJsonSimple.pure.word != "undefined") {
                       if (typeof dictJsonSimple.pure.word.ukphone == "string") {
                           phoneticJsonObj["uk"] = dictJsonSimple.pure.word.ukphone
                       }
                       if (typeof dictJsonSimple.pure.word.usphone == "string") {
                           phoneticJsonObj["us"] = dictJsonSimple.pure.word.usphone
                       }
                   } else {
                       if (typeof dictJsonSimple.pure.uk == "string") {
                           phoneticJsonObj["uk"] = dictJsonSimple.pure.uk
                       }
                       if (typeof dictJsonSimple.pure.us == "string") {
                           phoneticJsonObj["us"] = dictJsonSimple.pure.us
                       }
                   }
               } catch(e) {
               }
               //新词覆盖旧词
               if (typeof dictJsonSimple.pure.phonetics!= "undefined"&& dictJsonSimple.pure.phonetics.length>0)
               {
                   if(typeof dictJsonSimple.pure.phonetics[0].phone!= "undefined")
                       phoneticJsonObj["uk"] = dictJsonSimple.pure.phonetics[0].phone
               }
               if (typeof dictJsonSimple.pure.us_phonetics!= "undefined"&& dictJsonSimple.pure.us_phonetics.length>0)
               {
                   if(typeof dictJsonSimple.pure.us_phonetics[0].phone!= "undefined")
                       phoneticJsonObj["us"] = dictJsonSimple.pure.us_phonetics[0].phone
               }
               resultManager.phoneticSymbolJson = JSON.stringify(phoneticJsonObj)
               if( YEnum.DtEnChKid === dictType) {
                   setPhonic(dictJsonSimple)
                   //else
                   //spellManager.phonics = "";

                   if (typeof dictJsonSimple.pure.phonics != "undefined" && typeof dictJsonSimple.pure.phonics.phone_names != "undefined") {
                       let posArray = null
                       if(typeof dictJsonSimple.pure.phonics.letter_split != "undefined")
                       {
                           posArray=dictJsonSimple.pure.phonics.letter_split.split("/")
                       }
                       let mArray = dictJsonSimple.pure.phonics.phone_names
                       let i =0;
                       let phonicsStr="["
                       if(typeof dictJsonSimple.pure.word != "undefined")
                           spellManager.phonics = id_dict_content_view.getstr(mArray,dictJsonSimple.pure.word, posArray)
                   }
               }
               break
           case YEnum.AsyncLocalTran:
           case YEnum.NetTran:
               //id_dict_listview.visible = true
               //resultManager.phoneticSymbolJson = content
               break
           case YEnum.DtPinYin:
               id_dict_content_view.pinYinDictIndex = index
               break
           default:
               break
           }
       }

//    function requeryWord(word, srcLang, dstLang) {
//        initStrokeInfo()
//        upsetTopButtonStatus()
//        var qsMainQuery = resultManager.mainQuery
//        var qsSrcLang = resultManager.srcLang
//        var qsDstLang = resultManager.dstLang
//        var selectIndex = resultManager.autoSelectIndex
//        var qsTitle = id_dict_page.title
//        var contentYPos = id_container_flickable.contentY
//        stackQueryResult.push([qsMainQuery, qsSrcLang, qsDstLang, qmlGlobal.scanType, selectIndex, qsTitle, contentYPos])
//        qmlGlobal.queryFromDictPage(word, srcLang, dstLang)
//        id_container_flickable.contentY = 0
//    }
    function clickSearchWord(word) {
        if(id_dict_page.needSearchMoreVisible) {
            id_dict_page.requeryWord(resultManager.mainQuery, "en", "zh-CHS",id_dict_listview.repeaterModel,false,true,true,word)
        }
        else{
            id_dict_page.requeryWord(resultManager.currentQuery, "en", "zh-CHS",id_dict_listview.repeaterModel,false,false,true,word)
        }
    }

    function requeryWord(word, srcLang, dstLang,headBreakList=null,isOnlyAdd = false,isSearchMore = false,isEnterNewPage = false,searchWord = null) {
        initStrokeInfo()
        upsetTopButtonStatus()
        var qsMainQuery = resultManager.mainQuery
        var qsSrcLang = resultManager.srcLang
        var qsDstLang = resultManager.dstLang
        var selectIndex = resultManager.autoSelectIndex
        var qsTitle = id_dict_page.title
        var contentYPos = id_container_flickable.contentY
        let listViewDataArray = []
        listViewDataArray.push(id_dict_listview.newBreakIndexToRawIndex)
        listViewDataArray.push(id_dict_listview.rawBreakListBackArray)
        stackQueryResult.push([qsMainQuery, qsSrcLang, qsDstLang, selectIndex, qsTitle, contentYPos,headBreakList,word,isSearchMore,isEnterNewPage,listViewDataArray,qmlGlobal.scanOldType])
        if(!isOnlyAdd)
        {
            qmlGlobal.queryFromDictPage(searchWord===null?word:searchWord, srcLang, dstLang)
        }
        id_container_flickable.contentY = 0
    }


    function backToContentTop() {
        id_container_flickable.contentY = 0
    }

    function upsetTopButtonStatus(){
        id_to_top_button.visible = false
        id_to_top_button.visible = Qt.binding(function(){
            return id_container_flickable.contentY > id_container_flickable.height * 2
        })
    }

    function isChinese(str){
        if(/[\u3220-\uFA29]+/.test(str)){
            return true;
        }else{
            return false;
        }
    }

    function headFontFamily(charType) {
        let haveChinese = charType === YEnum.CT_UNKNOWN ? isChinese(content) : false
        switch (charType) {
        case YEnum.CT_ENG:
            return qmlGlobal.fontFamilyEnUs
        case YEnum.CT_JP:
            return qmlGlobal.fontFamilyJaJp
        case YEnum.CT_KO:
            return qmlGlobal.fontFamilyKoKr
        case YEnum.CT_CJK:
            return qmlGlobal.fontFamilyZhCn
        default:
            return !haveChinese ? qmlGlobal.fontFamilyEnUs : qmlGlobal.fontFamilyZhCn
        }
    }

    Flickable {
        id: id_container_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        z: id_dict_page.z + 1
        contentHeight: id_dict_content_column.height//Math.max(id_dict_content_column.height, id_buttons_column.height)
        flickableDirection: Flickable.VerticalFlick

        Behavior on contentY {
            id: id_content_animation
            enabled: sentenceMeanPos !== 0
            NumberAnimation {
                id: id_transition_animation
                to: sentenceMeanPos;  duration: 500
                onRunningChanged: {
                    if(!running) {
                        sentenceMeanPos = 0
                    }
                }
            }
        }

        onMovingChanged: {
            if (!moving) {
                resultManager.loadMore()
            }
        }

        property int privateTagsIndex: {
            let nLowLimit = 0
            switch (resultManager.mainQueryType) {
            case YEnum.WGT_Sentence:
            case YEnum.WGT_Ch_Group:
            case YEnum.WGT_En_Group:
            case YEnum.WGT_Ko_Group:
                nLowLimit = -1;
                break
            default:
                break
            }
            return resultManager.autoSelectIndex.bound(
                        nLowLimit, resultManager.mainQueryBreakList.length - 1)
        }

        Column {
            id: id_dict_content_column
            anchors.left: parent.left
            width: containWidth
            spacing: 0

            YSpacingForColumn {
                implicitHeight: 20
            }

            YDictPageHeaderItem {
                id: id_word
                visible:  isButtonIsRePress && (!(resultManager.itemCount) &&
                          !id_dict_content_view_repeater_empty_tip.visible)
                enabled: !isScannig
                charType: qmlTranslator.getCharType(ocrContentString)
                anchors.left: parent.left
                anchors.right: parent.right
                width: containWidth - 8
                content: ocrContentString
                onContentChanged: {
                    id_dict_content_view_repeater_empty_check_timer.restart()
                }
            }

            Flickable {
                id: id_header_flickable
                width: containWidth
                contentWidth: containWidth
                interactive:  flickableDirection === Flickable.HorizontalFlick
                height: flickableDirection === Flickable.HorizontalFlick ? 40 : id_dict_listview.height
                flickableDirection: 0 === qmlGlobal.scanOldType ? Flickable.HorizontalFlick : Flickable.VerticalFlick
                visible: !id_stroke_info_item.visible && !id_word.visible

                YDictPageHeaderView {
                    id: id_dict_listview
                }
            }

            YSpacingForColumn {
                id: id_search_loader_space
                implicitHeight: 10
                visible: id_word.visible
                onYChanged: {
                    let beforeContentHeight =  y + height + 34 + 40
                    let moveY = (beforeContentHeight - YEnum.Screen.Height)
                    if (moveY >= 0)
                        id_container_flickable.contentY  = moveY
                }
            }

            YWaitingTipsText {
                id: id_searching
                anchors.left: parent.left
                horizontalAlignment: Text.AlignLeft
                font.family: qmlGlobal.fontFamilyZhCn
                implicitHeight: 24
                font.pixelSize: 18
                color: YColors.grayText
                font.weight: Font.Normal
                text: YTranslateText.searching
                running: false
                visible:  isButtonIsRePress && !isScannig && (!(resultManager.itemCount) &&
                                         !id_dict_content_view_repeater_empty_tip.visible)
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: id_dict_listview.visible && id_stroke_info_item.visible
            }

            YDictChChineseStrokeComponent {
                id: id_stroke_info_item
                visible: needShowStrokeView && resultManager.currentQuery.length
                         && resultManager.currentQueryType === YEnum.WGT_Ch
                         && !isScannig
                         && !id_searching.visible

                onVisibleChanged: {
                    if (needShowStrokeView && resultManager.currentQuery.length === 1) {
                        console.log("YDictPage.qml === id_stroke_info_item.onVisibleChanged strokeManager.queryStrokeByCode:", resultManager.currentQuery)
                        var unicode = qmlTranslator.getUnicode(resultManager.currentQuery)
                        strokeManager.queryStrokeByCode(unicode)
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: id_head_search_more_loader.visible
            }
            //显示我要查
            YLoader{
                id:id_head_search_more_loader
                property var visibleSet : 0 !== qmlGlobal.scanType && 0 !== qmlGlobal.scanOldType &&
                            !searchMoreIsClick && tagsIndex != -1
                            && resultManager.currentQuery !== resultManager.mainQuery
                            && !id_dict_listview.isClick
                asynchronous: true
                visible:id_head_search_more_loader.visibleSet
                active: id_head_search_more_loader.visibleSet
                sourceComponent: id_search_more_component
            }

            Component{
                id:id_search_more_component
                Row{
                    anchors.left: parent.left
                    width: 194
                    height: 24
                    visible: id_head_search_more_loader.visible
                    id: id_search_more_row
                    YText {
                        text: YTranslateText.needSearchMore
                        font.pixelSize: 18
                        color: YColors.white
                    }

                    YMouseArea{
                        width: 155
                        height: 28
                        onClicked: {
                            searchMoreIsClick = true
                            //id_search_more_row.visible = false
                            id_dict_page.requeryWord(resultManager.mainQuery, "en", "zh-CHS",id_dict_listview.repeaterModel,true,true)
                            resultManager.autoSelectIndex = -1
                            resultManager.entryResult(resultManager.mainQuery, resultManager.srcLang, resultManager.dstLang, YEnum.Dict, 1, true)
                        }
                        YText{
                            id: id_more_text
                            text:id_get_middleElide_text.elidedText
                            font.pixelSize: 18
                            color: YColors.blueText
                        }
                        TextMetrics{
                            text:resultManager.mainQuery
                            font.family: qmlGlobal.fontFamily
                            font.pixelSize: 18
                            id:id_get_middleElide_text
                            elideWidth: 194
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }


            YSpacingForColumn {
                implicitHeight: 10
            }


            Flickable {
                id: id_dict_ch_pinyin_list_flickable
                anchors.left: parent.left
                anchors.right: parent.right
                height: 50
                contentWidth: id_dict_ch_pinyin_list.width
                flickableDirection: Flickable.HorizontalFlick
                visible: id_dict_ch_pinyin_list_repeater.count > 1
                clip: true

                Row {
                    id: id_dict_ch_pinyin_list
                    height: 40
                    spacing: 8
                    anchors.bottom: parent.bottom

                    Repeater {
                        id: id_dict_ch_pinyin_list_repeater
                        model: resultManager.chPinyinList

                        YButton {
                            height: 40
                            width: textWidth + 48
                            color: YColors.grayNormal
                            pixelSize: 18
                            textFamily: qmlGlobal.fontFamilyEnUs
                            textWeight: Font.Normal
                            text: model.modelData
                            textColor: resultManager.chPinyinListSelected === text ? YColors.red : YColors.white
                            onClicked: {
                                console.log("YDictPage.qml === id_dict_ch_pinyin_list.btn.onClicked text: ", text)
                                resultManager.chPinyinListSelected = text
                                resultManager.phoneticSymbolJson = text
                                qmlGlobal.soundWGTCh()
                                //id_dict_content_column.forceLayout()
                            }
                        }
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: id_dict_ch_pinyin_list_flickable.visible
            }

            Column {
                id: id_dict_content_view
                spacing: 20
                anchors.left: parent.left
                anchors.right: parent.right

                function itemAtIndex(index) {
                    return id_dict_content_view_repeater.itemAt(index)
                }

                YTimer{
                    id: id_set_button_is_presss
                    repeat: false
                    interval: 500
                    onTriggered: {
                         if ((resultManager.itemCount || id_dict_content_view_repeater_empty_tip.visible)
                                 && systemBase.isButtonRelease)
                          isButtonIsRePress = false
                    }
                }

                onYChanged: {
                   if (resultManager.currentQueryType === YEnum.WGT_Sentence && isButtonIsRePress) {
                        console.warn("***************id_dict_content_viewy"+y)
                        let moveY = (y - YEnum.Screen.Height / 2)
                        console.warn("***************moveY:"+moveY+"******** YEnum.Screen.Height/2:"+ YEnum.Screen.Height / 2)
                        if (moveY >= 0) {
                            sentenceMeanPos = moveY
                            id_container_flickable.contentY  = moveY
                            isButtonIsRePress = false
                        }
                    }
                }

                onHeightChanged: {
                    if (resultManager.itemCount || id_dict_content_view_repeater_empty_tip.visible)
                        id_set_button_is_presss.restart()
                }

                Repeater {
                    id: id_dict_content_view_repeater
                    model: resultManager
                    delegate: YLoader {
                        id: id_dict_content_view_delegate
                        asynchronous: false
                        readonly property int dictType: model.modelData.dictType
                        readonly property string content: model.modelData.content
                        onContentChanged: {
                            if (typeof content != "undefined" && content.length)
                                ocrContentString = ""
                        }

                        active: YEnum.AsyncLocalTran === dictType
                                || YEnum.NetTran === dictType
                                || YEnum.DtChChinese === dictType
                                || YEnum.DtChEnglish === dictType
                                || YEnum.DtChEnKid === dictType
                                || YEnum.DtChLarge === dictType
                                || YEnum.DtChAncientWord === dictType
                                || YEnum.DtChPoemDict === dictType
                                || YEnum.DtChIdiom === dictType
                                //英文词典
                                || YEnum.DtSimple === dictType
                                || YEnum.DtEnChKid === dictType
                                || YEnum.DtOxford === dictType
                                || YEnum.DtGRE === dictType
                                || YEnum.DtSSAT === dictType
                                || YEnum.DtSAT === dictType
                                || YEnum.DtTOEFL === dictType
                                || YEnum.DtIELTS === dictType
                                || YEnum.DtSenior === dictType
                                || YEnum.DtWebster === dictType
                                //韩文词典
                                || YEnum.DtChKo === dictType
                                || YEnum.DtKoCh === dictType
                        sourceComponent: {
                            getDictContentValue(dictType,content,index)
                            switch (dictType) {     
                            case YEnum.DtChChinese:
                                if (YEnum.WGT_Ch_Group === resultManager.currentQueryType) {
                                    return id_dt_ch_chinese_group_component
                                }
                                return id_dt_ch_chinese_component
                            case YEnum.DtChEnglish:
                            case YEnum.DtChEnKid:
                                return id_dt_ch_english_component
                            case YEnum.DtChLarge:
                                return id_dt_ch_large_component
                            case YEnum.DtChAncientWord:
                                return id_dt_ch_ancientword_component
                            case YEnum.DtChPoemDict:
                                return id_dt_ch_poemdict_component
                            case YEnum.DtChIdiom:
                                return id_dt_ch_idiom_component
                            case YEnum.AsyncLocalTran:
                            case YEnum.NetTran:
                                return id_dt_sentence_component
                            case YEnum.DtSenior:
                                return id_dt_senior_component
                            case YEnum.DtTOEFL:
                                return id_dt_toefl_component
                            case YEnum.DtWebster:
                                return id_dt_webster_component
                            case YEnum.DtOxford:
                                return id_dt_oxford_component
                            case YEnum.DtGRE:
                                return id_dt_gre_component
                            case YEnum.DtSSAT:
                                return id_dt_ssat_component
                            case YEnum.DtSAT:
                                return id_dt_sat_component
                            case YEnum.DtIELTS:
                                return id_dt_ielts_component
                            case YEnum.DtChKo:
                                return id_dt_chko_component
                            case YEnum.DtKoCh:
                                return id_dt_koch_component
                            case YEnum.DtEnChKid:
                                return id_dt_mango_kid_english_component
                            case YEnum.DtSimple:
                            default:
                                return id_dt_simple_component
                            }
                        }

                        Component {
                            id: id_dt_simple_component
                            YDictTypeDtSimple {}
                        }

                        Component{
                            id: id_dt_mango_kid_english_component
                            YDictTypeDtMangoKidEnglish{}
                        }

                        Component {
                            id: id_dt_senior_component
                            YDictTypeDtSenior {}
                        }

                        Component {
                            id: id_dt_sentence_component
                            YDictTypeWGTSentence {}
                        }

                        Component {
                            id: id_dt_ch_chinese_component
                            YDictTypeDtChChinese {}
                        }

                        Component {
                            id: id_dt_ch_chinese_group_component
                            YDictTypeDtChChineseGroup {}
                        }

                        Component {
                            id: id_dt_ch_english_component
                            YDictTypeDtChEnglish {}
                        }

                        Component {
                            id: id_dt_ch_large_component
                            YDictTypeDtChLarge {}
                        }

                        Component {
                            id: id_dt_ch_ancientword_component
                            YDictTypeDtChAncientWord {}
                        }

                        Component {
                            id: id_dt_ch_poemdict_component
                            YDictTypeDtChPoemDict {}
                        }

                        Component {
                            id: id_dt_ch_idiom_component
                            YDictTypeDtChChineseIdiom {}
                        }

                        Component {
                            id: id_dt_toefl_component
                            YDictTypeDtTOEFL {}
                        }

                        Component {
                            id: id_dt_webster_component
                            YDictTypeDtWebster {}
                        }

                        Component {
                            id: id_dt_oxford_component
                            YDictTypeDtOxford {}
                        }

                        Component {
                            id: id_dt_gre_component
                            YDictTypeDtGRE {}
                        }

                        Component {
                            id: id_dt_ssat_component
                            YDictTypeDtSSAT {}
                        }

                        Component {
                            id: id_dt_sat_component
                            YDictTypeDtSAT {}
                        }

                        Component {
                            id: id_dt_ielts_component
                            YDictTypeDtIELTS {}
                        }

                        Component {
                            id: id_dt_chko_component
                            YDictTypeDtChKo {}
                        }

                        Component {
                            id: id_dt_koch_component
                            YDictTypeDtKoCh {}
                        }

                        onLoaded: {
                            efficiencyReport.addClock("show_query_qml_result");
                            efficiencyReport.printReport();

                            if ((0 === index) && qmlGlobal.canAutoAddToWb) {
                                let simpleParaphrase = [""]
                                if (resultManager.currentQuery === resultManager.mainQuery) {
                                    simpleParaphrase = simpleParaphraseFunc(content, dictType)
                                }
                                resultManager.addHistory(resultManager.mainQuery, simpleParaphrase[1], resultManager.srcLang, resultManager.dstLang)
                                if (settingManager.isAutoAddWb && resultManager.currentQuery === resultManager.mainQuery) {
                                    resultManager.addToWordBook(resultManager.currentQuery,
                                                                '{"pos":"' + simpleParaphrase[0] + '","tran":"' + simpleParaphrase[1].replace(/"/g,"\\\"") + '"}',
                                                                simpleParaphrase[2], simpleParaphrase[3])
                                    qmlGlobal.canAutoAddToWb = false
                                }
                            }
                        }
                    }
                }

                YTimer {
                    id: id_dict_content_view_repeater_empty_check_timer
                    interval: 3000
                    onTriggered: {
                        if(isScannig) {
                            return restart()
                        }
                        if (0 === id_dict_content_view_repeater_empty_tip.count) {
                            id_dict_content_view_repeater_empty_tip.visible = true
                            if (typeof content != "undefined" && content.length)
                                ocrContentString = ""
                        }
                    }
                    objectName: "YDictPage.qml_id_dict_content_view_repeater_empty_check_timer"
                }

                YSpacingForColumn {
                    id: id_dict_content_view_repeater_empty_tip
                    implicitHeight: 128
                    visible: false

                    readonly property int count: resultManager.itemCount
                    onCountChanged: {
                        id_dict_content_view_repeater_empty_tip.visible = false
                        id_dict_content_view_repeater_empty_check_timer.restart()
                    }

                    YTextMedium {
                        anchors.centerIn: parent
                        text: YTranslateText.noParaphraseFound
                    }
                }

            }

        }

    }

    YIconButton {
        id: id_to_top_button
        opacity: mouseAreaItem.pressed || !enabled ? 0.2 : 1
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        mouseAreaMargins: -10
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        imageName: "dict/to-top"
        sourceSize: Qt.size(24, 24)
        visible: id_container_flickable.contentY > id_container_flickable.height * 2
        onValidClicked: {
            backToContentTop()
        }
    }

    ignoreDefaultBackButtonClicked: true
    function backProcess(){
        if (stackQueryResult.length > 0) {
            backContentYCount = 0;
            var queryResultLast = stackQueryResult.pop()
            backCountY = queryResultLast[5]
            setTimeout( function() {
                backContentYCount++;
                if(id_dict_page.height >= backCountY || backContentYCount > 10) {
                    if(id_container_flickable.contentY < backCountY-5)
                       id_container_flickable.contentY = backCountY
                    timer.stop()
                }else
                    timer.restart()
            },1)
            console.log("*************queryResultLast:"+JSON.stringify(queryResultLast))
            if(reportedSet.has(queryResultLast[7])) {
                resultManager.isReportButtonVisible = false
            }
            else {
                resultManager.isReportButtonVisible = true
            }
            if(queryResultLast[6] !== null)
            {
                //显示我要查界面返回
                if(queryResultLast[8]) {
                    //resultManager.autoSelectIndex = queryResultLast[3]
                    resultManager.entryResult(queryResultLast[0], queryResultLast[1], queryResultLast[2],YEnum.Dict,queryResultLast[11])
                }
                else {
                    //从近义词，反义词等跳转界面返回
                    if(queryResultLast[9]) {
                        //console.log("***************!!!!!!!!!!queryResultLast[10][2]:"+queryResultLast[10][2])
                        //resultManager.autoSelectIndex = -1
                        qmlGlobal.canAutoAddToWb = false
                        resultManager.entryResult(queryResultLast[7], queryResultLast[1], queryResultLast[2],YEnum.Dict,queryResultLast[11])
                        stackQueryResult=[]
                        //resultManager.queryResult(queryResultLast[7])
                        //                        id_dict_listview.pixelSizeArray=queryResultLast[10][0]
                        //                        id_dict_listview.indexMapArray=queryResultLast[10][1]
                        //                        id_dict_listview.rawBreakListBackArray = queryResultLast[10][2]

                    }
                    else {
                        resultManager.autoSelectIndex = -1
                        resultManager.queryResult(queryResultLast[7])
                        id_dict_listview.repeaterModel = []
                        if (id_dict_listview.indexMapArray.length > 0)
                            id_dict_listview.newBreakIndexToRawIndex = id_dict_listview.indexMapArray.pop()
                        if (id_dict_listview.rawBreakListBackArray.length > 0)
                            id_dict_listview.orgBreakList=id_dict_listview.rawBreakListBackArray.pop()
                        id_dict_listview.repeaterModel= queryResultLast[6]
                    }
                }
            }
            else{
                resultManager.entryResult(queryResultLast[0], queryResultLast[1], queryResultLast[2],YEnum.Dict,queryResultLast[11])
                id_dict_page.title = queryResultLast[4]
            }
            id_container_flickable.contentY = queryResultLast[5]
        } else {
            backButtonClicked()
        }
    }

    onBackButtonClickedCallback: {
//        qmlGlobal.stopAllAnimationMusic()
//        initStrokeInfo()
        backProcess()
        soundCenter.forceStop()
//        if (resultManager.autoSelectIndex >= 0) {
//            id_dict_listview.backToPrevious()
//            return
//        }
//        if (stackQueryResult.length > 0) {
//            var queryResultLast = stackQueryResult.pop()
//            resultManager.entryResult(queryResultLast[0], queryResultLast[1], queryResultLast[2], YEnum.Dict, queryResultLast[3])
//            id_dict_page.title = queryResultLast[5]
//            if (queryResultLast[4] >= 0) {
//                let breakItemTmp = resultManager.mainQueryBreakList[queryResultLast[4]]
//                //resultManager.autoSelectIndex = queryResultLast[4]
//                //id_dict_listview.updateRepeaterModel(queryResultLast[4], breakItemTmp.charType, breakItemTmp.content)
//                resultManager.queryResult(breakItemTmp.content)
//            }
//            id_container_flickable.contentY = queryResultLast[6]
//        } else {
//            backButtonClicked()
//        }
    }


    Timer {id: timer}
    function setTimeout(cb,delayTime) {
        //timer = new Timer();
        timer.interval = delayTime;
        timer.repeat = false;
        timer.triggered.connect(cb);
        timer.start();
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
//        enabled: id_dict_page.visible
        function onOcrStart() {
            console.log("YDictPage.qml====ocr_start")
            backToContentTop()
            isButtonIsRePress = true
            isScannig = true
            //visible = false
            id_dict_content_view_repeater_empty_tip.visible = false
            resultManager.clearChPinyinList()
            initStrokeInfo()
            reportedSet.clear()
            //id_fav_word_button.updateChecked()
        }
        function onOcrStop(scanType) {
            //resultManager.phoneticSymbolJson = ""
            isScannig = false
            backToContentTop()
        }
    }

    Connections {
        target: resultManager
        ignoreUnknownSignals: true
        function onCurrentQueryChanged() {
            sentenceMeanPos = 0
            needShowStrokeView = false
            id_stroke_info_item.isImagesExit = false
            chPinYinsSound = null
            id_dict_content_view_repeater_empty_tip.visible = false
            id_dict_content_view_repeater_empty_check_timer.restart()
            interactiveLearningManager.wipeData()
            spellManager.phonics = ""
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        function onHideDictPage() {
            console.log("onHideDictPage!!!!!!")
            id_dict_page.backButtonClicked()
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        enabled: id_dict_page.visible
        function onSoundSentence(qsWord) {
            if (id_dict_page.visible) {
                const sSoundWord = (qsWord.length > 0)
                                 ? qsWord : resultManager.currentQuery
                qmlGlobal.audioPlayId = soundCenter.play(sSoundWord,
                                                         ((qsWord.length > 0) ?
                                                              resultManager.getSoundTargetLanguage() :
                                                              resultManager.getSoundLanguage()))
                console.log("YDictPage.qml===onSoundSentence===sSoundWord:", sSoundWord)
                logManager.sendHttpLog("action=sound_click")
            }
        }
        function onSoundWGTCh() {
            if (id_dict_page.visible) {
                qmlGlobal.audioPlayId = soundCenter.play(resultManager.currentQuery,
                                                         resultManager.getSoundLanguage(),
                                                         chPinYinsSound === null ? resultManager.phoneticSymbolJson : chPinYinsSound,
                                                         settingManager.autoPronounceType)
                console.log("YDictPage.qml===onSoundWGTC===audioPlayId:", qmlGlobal.audioPlayId)
                logManager.sendHttpLog("action=sound_click")
            }
        }
        function onSoundWGTEn(qsWord, autoPronType) {
            if (id_dict_page.visible) {
                const nAutoPronType = (-1 == autoPronType)
                                    ? settingManager.autoPronounceType : autoPronType
                console.log("YDictPage.qml===onSoundWGTEn===nAutoPronType:", nAutoPronType)
                qmlGlobal.audioPlayId = soundCenter.play(qsWord,
                                                         resultManager.getSoundLanguage(),
                                                         resultManager.currentQuery,
                                                         nAutoPronType + 1)
                logManager.sendHttpLog("action=sound_click")
            }
        }
        function onSoundWGTKo() {
            if (id_dict_page.visible) {
                qmlGlobal.audioPlayId = soundCenter.play(resultManager.currentQuery,
                                                         resultManager.getSoundLanguage(),
                                                         chPinYinsSound === null ? resultManager.phoneticSymbolJson : chPinYinsSound,
                                                         settingManager.autoPronounceType)
                console.log("YDictPage.qml===onSoundWGTKo===audioPlayId:", qmlGlobal.audioPlayId)
                logManager.sendHttpLog("action=sound_click")
            }
        }
    }

    Component.onDestruction: {
        console.log("YDictPage.qml===Component.onDestruction===called")
    }

    onBackButtonClicked: {
        resultManager.clearChPinyinList()
        if (YEnum.PLAYING !== mediaPlayerManager.playState) {
            // do not do this, audioplaer is playing
            qmlGlobal.stopAllAnimationMusic()
        }
    }

    onVisibleChanged: {
        upsetTopButtonStatus()
        if (visible) {
            //id_delay_pos_timer.restart()
            id_dict_content_view_repeater_empty_check_timer.restart()
            if(id_dict_page.backContentYPos !=  null){
                id_container_flickable.contentY = id_dict_page.backContentYPos
                id_dict_page.backContentYPos =null
            }
        } else {
            qmlGlobal.canAutoAddToWb = false
            soundCenter.stop()
        }
    }
}
