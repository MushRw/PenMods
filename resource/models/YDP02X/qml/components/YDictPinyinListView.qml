import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

Flickable {
    id: id_dict_pinyin_list_view
    anchors.left: parent.left
    anchors.right: parent.right
    height: 40
    contentWidth: id_dict_ch_pinyin_list.width
    flickableDirection: Flickable.HorizontalFlick
    clip: true

    property string chCharacter: ""
    property var chPinyinListData: []
    property var chPinyinWithNumListData: []
    property int currentDictType: -1
    property string currentSelectedPinyin: ""
    property bool isFirstDict: false

    signal currentPinyinChanged(string currentPinyin)

    function arrayContains(arr, val) {
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] === val) {
                return true;
            }
        }
        return false;
    }

    function initPinyinListData(dictJsonData, dictType) {
        currentDictType = dictType
        currentSelectedPinyin = ""
        chPinyinListData = []
        chPinyinWithNumListData = []
        let chPinyinListDataTmp = []
        let chPinyinWithNumListDataTmp = []
        switch (dictType) {
        case YEnum.DtChChinese:
            dictJsonData.details.forEach(function(dictJsonDataObject){
                if (!arrayContains(chPinyinListDataTmp, dictJsonDataObject.pinyin)) {
                    chPinyinListDataTmp.push(dictJsonDataObject.pinyin)
                    if (typeof dictJsonDataObject.pinyinWithNum != "undefined") {
                        chPinyinWithNumListDataTmp.push(dictJsonDataObject.pinyinWithNum)
                    }
                }
            })
            break
        case YEnum.DtChLarge:
            dictJsonData.dataList.forEach(function(dictJsonDataObject){
                let phoneCur = dictJsonDataObject.phone
                phoneCur = phoneCur.replace(/\[/g, "")
                phoneCur = phoneCur.replace(/\]/g, "")
                if (!arrayContains(chPinyinListDataTmp, phoneCur)) {
                    chPinyinListDataTmp.push(phoneCur)
                    if (typeof dictJsonDataObject.speech != "undefined") {
                        let speechCur = dictJsonDataObject.speech
                        speechCur = speechCur.replace(/\[/g, "")
                        speechCur = speechCur.replace(/\]/g, "")
                        chPinyinWithNumListDataTmp.push(speechCur)
                    }
                }
            })
            break
        case YEnum.DtChAncientWord:
            dictJsonData.phones.forEach(function(dictJsonDataObject){
                if (!arrayContains(chPinyinListDataTmp, dictJsonDataObject.phone)) {
                    chPinyinListDataTmp.push(dictJsonDataObject.phone)
                    if (typeof dictJsonDataObject.speech != "undefined") {
                        chPinyinWithNumListDataTmp.push(dictJsonDataObject.speech)
                    }
                }
            })
            break
        }
        chPinyinListData = chPinyinListDataTmp
        chPinyinWithNumListData = chPinyinWithNumListDataTmp
        if (chPinyinListData.length > 0) {
            currentSelectedPinyin = chPinyinListData[0]
        }
    }

    function getDictSelectPinyinParaphrasesJson(dictJsonData, pinyin, dictType) {
        let jsonObjectMatched = null
        if (typeof pinyin !== "string" || pinyin.length <= 0) {
            return jsonObjectMatched
        }
        switch (dictType) {
        case YEnum.DtChChinese:
            dictJsonData.details.forEach(function(dictDetailObject){
                if (dictDetailObject.pinyin === pinyin) {
                    jsonObjectMatched = dictDetailObject
                }
            })
            break
        case YEnum.DtChLarge:
            dictJsonData.dataList.forEach(function(dictDataObject){
                let phoneCur = dictDataObject.phone
                phoneCur = phoneCur.replace(/\[/g, "")
                phoneCur = phoneCur.replace(/\]/g, "")
                if (phoneCur === pinyin) {
                    jsonObjectMatched = dictDataObject
                }
            })
            break
        case YEnum.DtChAncientWord:
            dictJsonData.paraphrases.forEach(function(dictParaphrasesObject){
                if (dictParaphrasesObject.phone === pinyin) {
                    jsonObjectMatched = dictParaphrasesObject
                }
            })
            break
        }
        return jsonObjectMatched
    }

    function autoPlayPinyin() {
        if (chPinyinListData.length <= 0 || currentSelectedPinyin.length <= 0) {
            return
        }
        id_autoplay_pinyin_timer.restart()
    }

    Row {
        id: id_dict_ch_pinyin_list
        height: 40
        spacing: 10

        Repeater {
            id: id_dict_ch_pinyin_list_repeater
            model: chPinyinListData
            delegate: YAudioPlayIconLabelHCenterButton {
                height: 40
                color: YColors.grayNormal
                textItem.font.pixelSize: 16
                textItem.font.family: qmlGlobal.fontFamilyPinyin
                text: model.modelData
                textItem.color: isCurrentSelectedPinyin ? YColors.red : YColors.white
                iconItem.visible: isFirstDict && isCurrentSelectedPinyin
                width: (iconItem.visible ? iconItem.width : 0) + textItem.width + 24 * 2

                readonly property bool isCurrentSelectedPinyin : currentSelectedPinyin == model.modelData

                onValidClicked: {
                    id_autoplay_pinyin_timer.stop()
                    if (!isCurrentSelectedPinyin) {
                        currentSelectedPinyin = text
                        currentPinyinChanged(currentSelectedPinyin)
                    }
                    if (isFirstDict) {
                        resultManager.phoneticSymbolJson = text
                        if (chPinyinWithNumListData.length === chPinyinListData.length) {
                            id_dict_page.chPinYinsSound = chPinyinWithNumListData[index]
                        } else {
                            id_dict_page.chPinYinsSound = null
                        }
                        qmlGlobal.soundWGTCh()
                    }
                }
            }
        }
    }

    YTimer {
        id: id_autoplay_pinyin_timer
        interval: 100
        onTriggered: {
            if (!isFirstDict) {
                return
            }
            if (!id_dict_page.visible) {
                restart()
                return
            }
            resultManager.phoneticSymbolJson = currentSelectedPinyin
            id_dict_page.chPinYinsSound = null
            for (var i = 0; i < chPinyinListData.length; i++) {
                if (chPinyinListData[i] === currentSelectedPinyin) {
                    if (chPinyinWithNumListData.length === chPinyinListData.length) {
                        id_dict_page.chPinYinsSound = chPinyinWithNumListData[i]
                    }
                    id_dict_ch_pinyin_list_repeater.itemAt(i).play()
                    qmlGlobal.soundWGTCh()
                    break
                }
            }
        }
    }

    Connections {
        target: settingManager
        ignoreUnknownSignals: true
        enabled: id_dict_page.visible
        function onTopShowChDictChanged() {
            if (settingManager.topShowChDict === currentDictType) {
                autoPlayPinyin()
            }
        }
    }
}
