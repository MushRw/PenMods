import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YMouseArea {
    id: id_word_mouseArea
    width: id_rect_item.width
    height: id_rect_item.height
    property bool rawEnableSet: id_word_bg.clickable && id_word_mouseArea.visible
    //anchors.rightMargin: -5
    //clip:true
    enabled: id_word_bg.clickable && id_word_mouseArea.visible
    property int indexNum: -1
    objectName: "YDictPage.qml_id_delegate_index" + indexNum
    property var charactersList: null
    property bool nextIsNotPunc: true
    property var letterSpace: (nextIsNotPunc && id_word_bg.clickable && charType === YEnum.CT_ENG ? 4 : 3)
    //property var curTagsIndex: -1

    property alias word: id_word.text
    property int charType: YEnum.CT_ENG
    property alias rectItem: id_word_bg
    property alias wordFontFamily: id_word.font.family
    property alias rectLastIsNotNewWord: id_word_bg.lastIsNotNewWord
    property alias rectNextIsNotNewWord: id_word_bg.nextIsNotNewWord
    property alias rectLeftWidth: id_word_bg.leftWidth
    property alias rectRightWidth: id_word_bg.rightWidth
    property var currentPixelSizeItem: 20
    property var rectTimerSetHeight: false
    property var queryType: resultManager.currentQueryType
    property var containWidth: 248
    //property alias imageItem: id_image_loader
    property var  content: ""
    property var rectClickIndex: null
    property var rectIndex: -1
    property var associatedWord: ""
    property alias wordItem: id_word
    //property alias calcTextItem: id_calc_text

    function isChinese(str){
        if(/[\u3220-\uFA29]+/.test(str)){
            return true;
        }else{
            return false;
        }
    }

    Item {
        id:id_rect_item
        width: !id_word_bg.nextIsNotNewWord
               ?id_word_bg.implicitRectWidth +letterSpace : id_word_bg.implicitRectWidth
        height: id_word_bg.height
        clip: true

        Rectangle {
            id: id_word_bg
            property int leftAndRightMargin: 8
            property int leftMove: 5
            property int implicitRectWidth: id_word.width + (clickable ? (leftWidth+rightWidth) : 0)
            width: implicitRectWidth + (id_word_bg.lastIsNotNewWord||id_word_bg.nextIsNotNewWord?leftMove:0)
            anchors.left: parent.left
            anchors.leftMargin: id_word_bg.lastIsNotNewWord ? -leftMove : 0
            property int textPixelSize: id_word.font.pixelSize
            property int textLineCount: id_word.lineCount
            property var lastIsNotNewWord: false
            property var nextIsNotNewWord: false
            property var leftWidth:  0
            property var rightWidth: 0

            height: {
//                if (id_calc_text.isWarp) {
//                    currentPixelSizeItem = 22
//                    rectTimerSetHeight = true
//                }
//                if (currentPixelSizeItem === 38 && !id_calc_text.isWarp)
//                    return queryType === YEnum.WGT_En ? 62 : 59
//                if (currentPixelSizeItem === 22 && !id_calc_small_text.isWarp)
//                    return 33
//                if (currentPixelSizeItem === 32 && !id_calc_text.isWarp)
//                    return 40
                if (id_calc_small_text.isWarp)
                    return id_word.contentHeight + 2
                else
                    return 26
            }
            color: /*(id_word_bg.lastIsNotNewWord || id_word_bg.nextIsNotNewWord) ? YColors.grayNormal :*/ "transparent"
            radius:  id_word_bg.lastIsNotNewWord && id_word_bg.nextIsNotNewWord ? 0 : 8

            readonly property bool clickable: YEnum.CT_PUNC !== charType

//            YLoader {
//                id: id_image_loader
//                active: queryType === YEnum.WGT_En && !id_calc_small_text.isWarp && (id_word.lineCount < 2)
//                sourceComponent: YImage {
//                    anchors.centerIn: parent
//                    sourceSize: Qt.size(containWidth, currentPixelSizeItem === 38 ? 62 : 35)
//                    imageName:  currentPixelSizeItem === 38 ? "spell/bg" : "spell/largebg"
//                }
//            }

//            YTextBase {
//                id: id_calc_text
//                visible: false
//                property bool isWarp: width + 16 > containWidth
////                onIsWarpChanged: {
////                    if (id_calc_text.isWarp)
////                        currentPixelSizeItem = 22
////                }
//                text: content
//                font.family: id_word.font.family
//                font.letterSpacing: id_word.font.letterSpacing
//                width: contentWidth - font.letterSpacing
//                font.weight: id_word.font.weight
//                font.pixelSize: 34/*(charType !== YEnum.CT_CJK && currentPixelSizeItem != 32) ? 38 : 32*/
//                property int pixelSize: id_calc_text.font.pixelSize
////                onPixelSizeChanged: {
////                    if( (rectClickIndex == null || rectClickIndex === rectIndex) && currentPixelSizeItem!=22 &&
////                            charType === YEnum.CT_CJK) {
////                        currentPixelSizeItem = 32
////                    }
////                }
//            }
            YTextBase {
                id: id_calc_small_text
                visible: false
                property bool isWarp: width > containWidth
                text: content
                font.family: id_word.font.family
                font.letterSpacing: id_word.font.letterSpacing
                width: contentWidth - font.letterSpacing
                font.weight: id_word.font.weight
                font.pixelSize: 20
            }

            YTextBase {
                id: id_word
                //anchors.centerIn: parent
                verticalAlignment: Text.AlignVCenter
                anchors.left: parent.left
                anchors.leftMargin: id_word_bg.leftWidth +(id_word_bg.lastIsNotNewWord ? id_word_bg.leftMove : 0)
                property bool haveChinese: charType === YEnum.CT_UNKNOWN ? isChinese(content) : false
                font.family: {
                    switch (charType) {
                    case YEnum.CT_ENG:
                        return qmlGlobal.fontFamilyEnUs
                    case YEnum.CT_CJK:
                        return qmlGlobal.fontFamilyZhCn
                    default:
                        return !haveChinese ? qmlGlobal.fontFamilyEnUs : qmlGlobal.fontFamilyZhCn
                    }
                }
                font.letterSpacing: {
                    switch (charType) {
                    case YEnum.CT_CJK:
                        return 0
                    default:
                        return 0
                    }
                }
                textFormat: YText.RichText
                width:{
                    if(id_calc_small_text.isWarp)
                        return containWidth
                    else
                        return /*currentPixelSizeItem!=22 ? id_calc_text.width :*/ id_calc_small_text.width
                }
                property int curPixelSize: currentPixelSizeItem
//                onCurPixelSizeChanged:{
//                    width= Qt.binding(function(){
//                        if(id_calc_small_text.isWarp)
//                            return  containWidth
//                        else
//                            return  currentPixelSizeItem !== 22 ? id_calc_text.width : id_calc_small_text.width
//                    })
//                }
                anchors.horizontalCenterOffset: id_calc_small_text.isWarp ? 8 : 0
                wrapMode: id_calc_small_text.isWarp ? YText.Wrap : YText.NoWrap
                font.pixelSize: currentPixelSizeItem
                color: /*(id_word_bg.lastIsNotNewWord || id_word_bg.nextIsNotNewWord) ? YColors.red :*/ YColors.grayText
                Component.onCompleted: {
                    if ( contentHeight > parent.height) {
                        anchors.verticalCenter = undefined
                    }
                    else
                        anchors.verticalCenter =  parent.verticalCenter
                }

                font.weight: {
                    switch (charType) {
                    case YEnum.CT_UNKNOWN:
                        return haveChinese ? Font.Normal : Font.Bold
                    case YEnum.CT_CJK:
                        return Font.Normal
                    default:
                        return Font.Bold
                    }
                }
                text: {
                    return content
                }
            }
        }
    }
}
