import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"

Flow {
    id: id_dict_listview
    anchors.left: parent.left
    anchors.right: parent.right
    readonly property var koSpecialChar: ["-", ":", "^"]

    property var orgBreakList: resultManager.mainQueryBreakList
    property var breakContentStack: []
    property var breakSentenceStack: []
    property alias repeaterModel: id_breakList_repeter.model
    property var newBreakListArray: new Array//[[{},{}],[{}]]每一个分词以单词或字符为单位分词存进数组
    property var newBreakIndexToRawIndex: []
    property var singleWordLeftMargin: 0
    property var groupWordLeftMargin: chType ? 1 : 3
    property var singleWordRightMargin: 0
    property var groupWordRightMargin: chType ? 1 : 3
    property var clickIndex: null
    property var  isClick: false
    property bool chType: YEnum.WGT_Ch === resultManager.currentQueryType
                          ||YEnum.WGT_Ch_Group === resultManager.currentQueryType
    property bool isScanning: true

    property bool isAutoBreakWords: (resultManager.autoSelectIndex >= 0 || resultManager.mainQueryBreakList.length === 1) && qmlGlobal.scanOldType !== 0

    property var indexMapArray: []
    property var rawBreakListBackArray: []
    //spacing: 2
    focus: true
    property var  mainQueryBreakListNotify :resultManager.mainQueryBreakList
    onMainQueryBreakListNotifyChanged: {
        breakContentStack = []
        breakSentenceStack = []
        clickIndex = null
        isClick = false
        id_dict_page.searchMoreIsClick = false

        if(resultManager.mainQueryBreakList.length <= 0)
            return
        isButtonIsRePress = false
        isScanning = false
        id_breakList_repeter.model = ""
        orgBreakList = resultManager.mainQueryBreakList
        chType = Qt.binding(function(){return YEnum.WGT_Ch === resultManager.currentQueryType
                                       ||YEnum.WGT_Ch_Group === resultManager.currentQueryType})
        let totalArray = new Array
        let breakListData= null
        let arrayData = new Array
        //句子中是否含有中文
        if(YEnum.WGT_Sentence === resultManager.currentQueryType){
            resultManager.mainQueryBreakList.some(function(item){
                if(item.charType===YEnum.CT_CJK){
                    chType=true
                    return true
                }
            })
        }

        isAutoBreakWords = (resultManager.autoSelectIndex >= 0 || resultManager.mainQueryBreakList.length === 1) && qmlGlobal.scanOldType !== 0

        if(isAutoBreakWords) {
            //if(resultManager.autoSelectIndex!=-1)
            let autoSelect = (resultManager.autoSelectIndex === -1 && resultManager.mainQueryBreakList.length === 1) ? 0 : resultManager.autoSelectIndex
            let i = 0;
            if(autoSelect > -1 && autoSelect < resultManager.mainQueryBreakList.length)
            breakListData = id_dict_listview.breakWords(resultManager.mainQueryBreakList[autoSelect].content)
            resultManager.mainQueryBreakList.some(function(item){
                if(i === autoSelect) {
                    let j =0
                    if(breakListData!=null){
                        breakListData.forEach(function(item2) {
                            j++;
                            arrayData.push({"charType":item.charType,"content":item2})})
                    }else
                        arrayData.push({"charType":item.charType,"content":item.content})
                    return true
                }
                i++
            })
        }

        if (arrayData.length)
            orgBreakList = arrayData

        if((YEnum.WGT_Ch !== resultManager.mainQueryType &&
            YEnum.WGT_En !== resultManager.mainQueryType) ||
                (YEnum.WGT_Ch !== resultManager.currentQueryType && YEnum.WGT_En !== resultManager.currentQueryType)) {
            getTotalBreakListArrayNewMethod(orgBreakList,totalArray)
        }

        return  id_breakList_repeter.model = totalArray.length > 0 ? totalArray : orgBreakList
    }

    function breakWords(text,charType = -1) {
        let charactersList = null;
        if (charType !== -1 && charType !== YEnum.CT_PUNC) {
            switch (charType) {
            case YEnum.CT_ENG:
                if (text.indexOf(" ") !== -1) {
                    charactersList = qmlGlobal.englishSentenceToWordsList(text)
                }
                break
            case YEnum.CT_KO:
                charactersList = qmlGlobal.koreanToCharactersList(text)
                break
            case YEnum.CT_CJK:
            default:
                if(text.length>1)
                    charactersList = qmlGlobal.chineseToCharactersList(text)
                break
            }
        } else if(charType === -1) {
            switch (resultManager.currentQueryType) {
            case YEnum.WGT_En_Group:
                charactersList = qmlGlobal.englishSentenceToWordsList(text)
                break
            case YEnum.WGT_Ko_Group:
                charactersList = qmlGlobal.koreanToCharactersList(text)
                break
            case YEnum.WGT_Ch_Group:
            default:
                charactersList = qmlGlobal.chineseToCharactersList(text)
                break
            }
        }
        return charactersList != null && charactersList[0] !== text ? charactersList : null
    }


    function breakWordsNewMethod( text, charType = -1 ) {
        let charactersList = null;
        if ( charType !== -1 && charType !== YEnum.CT_PUNC ) {
            switch (charType) {
            case YEnum.CT_ENG:{
                if (text.indexOf(" ") !== -1) {
                    charactersList = text.split(" ")
                }
            }
            break
            case YEnum.CT_KO:
                charactersList = []
                for (let i=0; i<text.length; i++)
                    charactersList.push(text[i])
                break
            case YEnum.CT_UNKNOWN:
                charactersList = []
                charactersList.push(text)
                break
            case YEnum.CT_CJK:
            default:
            {
                charactersList = []
                for (let i=0; i<text.length; i++)
                    charactersList.push(text[i])
            }
            break
            }
        } else if (charType === -1) {
            switch (resultManager.currentQueryType) {
            case YEnum.WGT_En_Group:
                if (text.indexOf(" ") !== -1) {
                    charactersList = text.split(" ")
                }
                break
            case YEnum.WGT_Ko_Group:
                charactersList = []
                for (let i=0; i<text.length; i++)
                    charactersList.push(text[i])
                break
            case YEnum.WGT_Ch_Group:
            default:
                charactersList = []
                for(let i=0; i<text.length; i++)
                    charactersList.push(text[i])
                break
            }
        }
        return charactersList !== null && charactersList[0] != text ? charactersList : null
    }


    function getTotalBreakListArrayNewMethod(rawBreakList, totalArray, isExternal = 0) {
        console.log("getTotalBreakListArrayNewMethod***********************")
        newBreakIndexToRawIndex=[]
        newBreakListArray=[]
        for(let i = 0;i < rawBreakList.length;i++){
            if( typeof rawBreakList[i] == 'string' ) {
            }
            else {
                getSingleBreakListNewMethod(i, rawBreakList[i], totalArray)
            }
        }
        if(isExternal)
            id_breakList_repeter.model = totalArray
    }

    function getSingleBreakListNewMethod(rawindex, textJson, totalArray) {
        var breakListArray = breakWordsNewMethod(textJson.content,textJson.charType)
        if(breakListArray == null) {
            if(typeof newBreakListArray[rawindex] == "undefined")
                newBreakListArray[rawindex] = []
            newBreakListArray[rawindex].push(textJson)
            totalArray.push(textJson)
            let index = -1
            for(let i = 0 ;i <= rawindex; i++) {
                index += newBreakListArray[i].length
            }
            if(index !== -1)
                newBreakIndexToRawIndex[index] = rawindex
            return
        }else {
            for(var i = 0 ;i < breakListArray.length; i++) {
                var strJson = {'charType':textJson.charType,'content':breakListArray[i]}
                if(typeof newBreakListArray[rawindex] == "undefined")
                    newBreakListArray[rawindex]=[]
                newBreakListArray[rawindex].push(strJson)
                totalArray.push(strJson)
                let index = -1
                for(let i = 0 ;i <= rawindex;i++) {
                    index += newBreakListArray[i].length
                }
                if(index !== -1)
                    newBreakIndexToRawIndex[index]=rawindex
            }
        }
    }

    function getTotalBreakListArray(rawBreakList,totalArray,isExternal = 0) {
        newBreakIndexToRawIndex=[]
        newBreakListArray=[]
        for(let i=0;i<rawBreakList.length;i++) {
            if(typeof rawBreakList[i]=='string') {
            }
            else {
                getSingleBreakList(i,rawBreakList[i],totalArray)
            }
        }
        if(isExternal)
            id_breakList_repeter.model = totalArray
    }

    function getSingleBreakList(rawindex,textJson,totalArray) {
        var breakListArray = breakWords(textJson.content,textJson.charType)
        //console.warn("*********getSingleBreakList:"+JSON.stringify(breakListArray))
        if(breakListArray === null) {
            if(typeof newBreakListArray[rawindex] == "undefined")
                newBreakListArray[rawindex]=[]
            newBreakListArray[rawindex].push(textJson)
            totalArray.push(textJson)
            let index = -1
            for(let i =0 ;i<=rawindex;i++)
            {
                index+=newBreakListArray[i].length
            }
            if(index != -1)
                newBreakIndexToRawIndex[index]=rawindex
            return
        } else {
            for(var i =0 ;i<breakListArray.length; i++) {
                var strJson = {'charType':textJson.charType,'content':breakListArray[i]}
                getSingleBreakList(rawindex,strJson,totalArray)
            }
        }
    }

    function updateRepeaterModel(index, charType, contentText) {
        if (resultManager.autoSelectIndex < 0) {
            resultManager.autoSelectIndex = index
            breakContentStack = []
        } else {
            breakContentStack.push(id_breakList_repeter.model)
        }
        breakSentenceStack.push(contentText)
        resultManager.queryResult(contentText)
        let charactersList
        switch (charType) {
        case YEnum.CT_ENG:
            charactersList = qmlGlobal.englishSentenceToWordsList(contentText)
            break
        case YEnum.CT_KO:
            charactersList = qmlGlobal.koreanToCharactersList(contentText)
            break
        case YEnum.CT_CJK:
        default:
            charactersList = qmlGlobal.chineseToCharactersList(contentText)
            break
        }

        let breakListTmp = []
        charactersList.forEach(function(breakChar){
            breakListTmp.push({charType: charType, content: breakChar})
        })
        id_breakList_repeter.model = breakListTmp
    }

    function backToPrevious() {
        //console.log("YDictPageHeaderView.qml === backToPrevious breakSentenceStack:", breakSentenceStack)
        breakSentenceStack.pop()
        //console.log("YDictPageHeaderView.qml === backToPrevious breakSentenceStack:", breakSentenceStack)
        if (breakContentStack.length > 0) {
            resultManager.queryResult(breakSentenceStack[breakSentenceStack.length - 1])
            id_breakList_repeter.model = breakContentStack.pop()
        } else if (resultManager.autoSelectIndex >= 0) {
            resultManager.autoSelectIndex = -1
            resultManager.queryResult(resultManager.mainQuery)
            id_breakList_repeter.model = orgBreakList
        }
    }

    function itemAtIndex(index) {
        return id_breakList_repeter.itemAt(index)
    }

    Repeater{
        id: id_breakList_repeter
        model: null

        YDictPageHeaderItem {
            id: id_delegate
            enabled: !isScanning && id_delegate.rawEnableSet
            charType: model.modelData.charType
            nextIsNotPunc: index+1 < id_breakList_repeter.model.length && id_breakList_repeter.model[index+1].charType !== YEnum.CT_PUNC

            rectLastIsNotNewWord: rectItem.clickable && newBreakIndexToRawIndex.length>0
                                  && index !== 0
                                  && newBreakIndexToRawIndex[index] === newBreakIndexToRawIndex[index-1]
            rectNextIsNotNewWord: newBreakIndexToRawIndex.length > 0
                                  && index!=newBreakIndexToRawIndex.length-1
                                  && newBreakIndexToRawIndex[index] === newBreakIndexToRawIndex[index+1]
            rectLeftWidth:  rectItem.lastIsNotNewWord ?
                                groupWordLeftMargin :
                                (rectItem.clickable && rectItem.nextIsNotNewWord ? singleWordLeftMargin : 0)
            rectRightWidth:  rectItem.nextIsNotNewWord ?
                                 groupWordRightMargin : (rectItem.clickable && rectItem.lastIsNotNewWord ?
                                                             singleWordRightMargin : 0)
            indexNum: index
            wordItem.color: (0 === qmlGlobal.scanOldType && resultManager.mainQueryBreakList.length > 0 &&  !id_dict_listview.isClick && (isAutoBreakWords ||
                             resultManager.currentQuery === orgBreakList[newBreakIndexToRawIndex[index]].content)) ? YColors.white : YColors.grayText

            readonly property bool isPunc: charType === YEnum.CT_PUNC
            readonly property string contentText: model.modelData.content

            content: model.modelData.content
            rectClickIndex: clickIndex
            rectIndex: index
            associatedWord: resultManager.associatedWord

            onClicked: {
                let iWantSearchVisible = id_head_search_more_loader.visible
                isClick  = true
                clickIndex = index
                soundCenter.stop()
                if ((resultManager.currentQuery !== model.modelData.content && newBreakIndexToRawIndex.length<=0) ||
                        (newBreakIndexToRawIndex.length > index &&
                         resultManager.currentQuery !== orgBreakList[newBreakIndexToRawIndex[index]].content)) {
                    indexMapArray.push(newBreakIndexToRawIndex)
                    rawBreakListBackArray.push(orgBreakList)

                    if( iWantSearchVisible ) {
                        id_dict_page.requeryWord(resultManager.mainQuery, "en", "zh-CHS",id_breakList_repeter.model,true,true)
                    }
                    else {
                        id_dict_page.requeryWord(resultManager.currentQuery, "en", "zh-CHS",id_breakList_repeter.model,true)
                    }

                    resultManager.autoSelectIndex = newBreakIndexToRawIndex[index]
                    resultManager.queryResult(orgBreakList[newBreakIndexToRawIndex[index]].content)
                    if(id_dict_page.reportedSet.has(resultManager.currentQuery)) {
                        resultManager.isReportButtonVisible = false;
                    }
                    else {
                        resultManager.isReportButtonVisible = true;
                    }

                    let charactersList
                    switch (charType) {
                    case YEnum.CT_ENG:
                        charactersList = qmlGlobal.englishSentenceToWordsList(orgBreakList[newBreakIndexToRawIndex[index]].content)
                        break
                    case YEnum.CT_KO:
                        charactersList = qmlGlobal.koreanToCharactersList(orgBreakList[newBreakIndexToRawIndex[index]].content)
                        break
                    case YEnum.CT_CJK:
                    default:
                        charactersList = qmlGlobal.chineseToCharactersList(orgBreakList[newBreakIndexToRawIndex[index]].content)
                        break
                    }

                    let breakListTmp = []
                    charactersList.forEach(function(breakChar){
                        breakListTmp.push({charType: charType, content: breakChar})
                    })
                    orgBreakList = breakListTmp
                    let  totalArray = new Array
                    id_dict_listview.getTotalBreakListArray(orgBreakList,totalArray)
                    id_breakList_repeter.model = totalArray.length > 0 ? totalArray : orgBreakList
                }
            }
        }
    }

    Component {
        id: id_break_word_component

        Item {
            id:id_rect_item
            width: !id_word_bg.nextIsNotNewWord
                   ?id_word_bg.implicitRectWidth+1 : id_word_bg.implicitRectWidth
            height: id_word_bg.height+1
            clip: true
            Rectangle {
                id: id_break_word_content
                height: id_break_word_text.height + 18
                //width: id_break_word_text.width + (isPunc ? 0 : 24)
                color: isPunc ? "transparent" : YColors.grayNormal
                radius: 8
                property int leftAndRightMargin: 8
                property int leftMove: 5
                property int implicitRectWidth: id_word.width + (clickable ? (leftWidth+rightWidth) : 0)
                width: implicitRectWidth + (id_break_word_content.lastIsNotNewWord||id_break_word_content.nextIsNotNewWord?leftMove:0)
                anchors.left: parent.left
                anchors.leftMargin: id_break_word_content.lastIsNotNewWord ? -leftMove : 0
                property int textPixelSize: id_word.font.pixelSize
                property int textLineCount: id_word.lineCount
                property var lastIsNotNewWord: false
                property var nextIsNotNewWord: false
                property var leftWidth:  0
                property var rightWidth: 0
                readonly property int charType: model.modelData.charType
                readonly property bool isPunc: charType === YEnum.CT_PUNC
                readonly property string contentText: model.modelData.content



                YTextBase {
                    id: id_break_word_text_width_cal
                    visible: false
                    anchors.centerIn: parent
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    width: paintedWidth
                    text: id_break_word_content.contentText
                    readonly property bool needWrap: !id_break_word_content.isPunc && (width > (id_dict_listview.width - 24))
                }

                YTextBase {
                    id: id_break_word_text
                    width: id_break_word_text_width_cal.needWrap ? (id_dict_listview.width - 24) : paintedWidth
                    wrapMode:id_break_word_text_width_cal.needWrap ? YText.Wrap : YText.NoWrap
                    anchors.centerIn: parent
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    color: id_break_word_content.isPunc ? YColors.grayText : YColors.red
                    text: id_break_word_content.contentText
                }

                YMouseArea {
                    anchors.fill: parent
                    enabled: !isPunc
                    onClicked: {
                        if (id_breakList_repeter.count <= 1) {
                            return
                        }
                        updateRepeaterModel(index, id_break_word_content.charType, id_break_word_content.contentText)
                    }
                }
            }
        }
    }
}
