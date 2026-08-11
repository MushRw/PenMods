import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

Item {
    id: id_dict_type_base_item
    width: 256
    height: !visible ? 0 : id_dict_type_base.height
    readonly property int dictType: model.modelData.dictType
    readonly property string content: model.modelData.content
    readonly property var dictJson: (YEnum.AsyncLocalTran === dictType || YEnum.NetTran === dictType) ? null : JSON.parse(content)
    readonly property bool isFirstDict: index <= 0
    default property alias sourceComponent: id_content_loader.sourceComponent
    property alias title: id_dictionary_title.text
    property bool isShowDetailButton: false

    onDictTypeChanged: {
        let bVisible = false
        switch (dictType) {
        case YEnum.DtChLarge:
        case YEnum.DtChAncientWord:
        //case YEnum.DtChPoemDict:
        case YEnum.DtSenior:
        case YEnum.DtWebster:
        //case YEnum.DtOxford:
        case YEnum.DtKoCh:
        case YEnum.DtChKo:
            bVisible = true
            break
        default:
            break
        }
        isShowDetailButton = bVisible
    }

    function getWords(){
        if (-1 === tagsIndex) {
            return resultManager.mainQuery
        } else {
            const a = resultManager.mainQueryBreakList
            return a[tagsIndex].content
        }
    }

    Column {
        id: id_dict_type_base
        width: parent.width
        spacing: 0

        YTextBase {
            id: id_dictionary_title
            font.pixelSize: 16
            color: YColors.red
            height: id_dictionary_title.contentHeight
            visible: {
                if (isFirstDict) {
                    return false
                }
                else
                {
                    return (id_dictionary_title.text.length > 0)
                }
            }
        }

        YSpacingForColumn {
            visible: id_dictionary_title.visible
            implicitHeight: 6
        }

        YLoader {
            id: id_content_loader
            active: true
            width: parent.width
            height: item.height
            asynchronous: false
        }

        YTextBase {
            visible: text.length > 0
            width: contentWidth
            height: 40
            verticalAlignment: Text.AlignVCenter
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 16
            color: YColors.grayText
            text: {
                if (dictJson!== null && typeof  dictJson.source == "string") {
                    if (dictJson.source === "现代汉语规范词典") {
                        return YTranslateText.chWordSource.arg(YTranslateText.dtChModernChinese)
                    }
                }
                return ""
            }
        }

        YSpacingForColumn {
            visible: id_audio_play_buttons_loader.active
            implicitHeight: 10
        }

        YLoader {
            id: id_audio_play_buttons_loader
            active: isFirstDict && ((dictType !== YEnum.DtChChinese || YEnum.WGT_Ch_Group === resultManager.currentQueryType) && dictType !== YEnum.DtChLarge &&
                                    dictType !== YEnum.DtChAncientWord && dictType != YEnum.DtChIdiom)
            visible: active
            width: parent.width
            sourceComponent: {
                switch (dictType) {
                    case YEnum.AsyncLocalTran:
                    case YEnum.NetTran:
                        return id_sentence_buttons
                }
                switch (resultManager.currentQueryType) {
                case YEnum.WGT_Ch_Group:
                case YEnum.WGT_Ch:
                case YEnum.WGT_Ko_Group:
                case YEnum.WGT_Ko:
                    return id_cn_zh_word_button
                case YEnum.WGT_Sentence:
                case YEnum.WGT_Ja:
                    return id_sentence_buttons
                case YEnum.WGT_En_Group:
                case YEnum.WGT_En:
                default:
                    return id_pronounce_buttons
                }
            }
            onLoaded: {
                if (settingManager.isAutoPronounce && id_dict_page.visible) {
                    audioAutoPlay()
                }
            }
            function audioAutoPlay() {
                item.autoPlay()
                switch (resultManager.currentQueryType) {
                case YEnum.WGT_Sentence:
                case YEnum.WGT_Ja:
                    qmlGlobal.soundSentence()
                    break
                case YEnum.WGT_Ch_Group:
                case YEnum.WGT_Ch:
                    qmlGlobal.soundWGTCh()
                    break
                case YEnum.WGT_Ko_Group:
                case YEnum.WGT_Ko:
                    qmlGlobal.soundWGTKo()
                    break
                case YEnum.WGT_En_Group:
                case YEnum.WGT_En:
                    qmlGlobal.soundWGTEn(resultManager.currentQuery)
                    break
                default:
                    break
                }
            }

            Connections {
                target: qmlGlobal
                ignoreUnknownSignals: true
                enabled: id_audio_play_buttons_loader.isLoaded
                function onShowDictPage(pageIndex) {
                    if (YEnum.PageIndex.Dict === pageIndex && settingManager.isAutoPronounce) {
                        // todo check fav history need or not
                        id_audio_play_buttons_loader.audioAutoPlay()
                    }
                }
            }

            Component {
                id: id_pronounce_buttons

                Column {
                    id: id_pronounce_buttons_grid
                    spacing: 8
                    readonly property var phoneticSymbolJson: {
                        let jsonObjTmp = null
                        try {
                            jsonObjTmp = JSON.parse(resultManager.phoneticSymbolJson)
                        } catch(e) { }
                        return jsonObjTmp
                    }

                    function autoPlay() {
                        if (id_sound_default.visible) {
                            id_sound_default.play()
                        } else {
                            play(YEnum.US === settingManager.autoPronounceType)
                        }
                    }

                    function play(isUS) {
                        if (isUS) {
                            if (id_sound_uk.playing) {
                                id_sound_uk.stop()
                            }
                            id_sound_us.play()
                        } else {
                            if (id_sound_us.playing) {
                                id_sound_us.stop()
                            }
                            id_sound_uk.play()
                        }
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_us
                        width: 256
                        visible: soundCenter.hasUsSound(resultManager.currentQuery)
                                 && id_pronounce_buttons_grid.phoneticSymbolJson !== null
                                 && (typeof id_pronounce_buttons_grid.phoneticSymbolJson.us != "undefined")
                        textItem.wrapMode: YText.Wrap
                        textItem.width: 162
                        ukOrUsText.text: {
                            if (!visible) {
                                return ""
                            }
                            if (!id_sound_uk.visible) {
                                return ('')
                            }
                            if (id_pronounce_buttons_grid.phoneticSymbolJson.us.length > 0) {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>&nbsp;')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandUS)
                            } else {
                                return ('')
                            }
                        }
                        text: {
                            if (!visible) {
                                return ""
                            }
                            if (!id_sound_uk.visible) {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                            }
                            if (id_pronounce_buttons_grid.phoneticSymbolJson.us.length > 0) {
                                return ('<span style="font-family: %1">&frasl;&nbsp;%2&nbsp;&frasl;</span>')
                               .arg(qmlGlobal.fontFamilyEnUs).arg(id_pronounce_buttons_grid.phoneticSymbolJson.us)
                            } else {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandUS)
                            }
                        }
                        onValidClicked: {
                            if (playing) {
                                id_pronounce_buttons_grid.play(true)
                                if (!id_sound_uk.visible) {
                                    qmlGlobal.soundWGTEn(resultManager.currentQuery)
                                } else {
                                    qmlGlobal.soundWGTEn(resultManager.currentQuery, YEnum.US)
                                }
                                logManager.sendHttpLog("action=detail_american_accent_click")
                            }
                        }
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_uk
                        width: 256
                        visible: soundCenter.hasUkSound(resultManager.currentQuery)
                                 && id_pronounce_buttons_grid.phoneticSymbolJson !== null
                                 && (typeof id_pronounce_buttons_grid.phoneticSymbolJson.uk != "undefined")
                        textItem.wrapMode: YText.Wrap
                        textItem.width: 162
                        ukOrUsText.text: {
                            if (!visible) {
                                return ""
                            }
                            if (!id_sound_us.visible) {
                                return ('')
                            }
                            if (id_pronounce_buttons_grid.phoneticSymbolJson.uk.length > 0) {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>&nbsp;')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandEN)
                            } else {
                                return ('')
                            }
                        }
                        text: {
                            if (!visible) {
                                return ""
                            }
                            if (!id_sound_us.visible) {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                            }
                            if (id_pronounce_buttons_grid.phoneticSymbolJson.uk.length > 0) {
                                return ('<span style="font-family: %1">&frasl;&nbsp;%2&nbsp;&frasl;</span>')
                               .arg(qmlGlobal.fontFamilyEnUs).arg(id_pronounce_buttons_grid.phoneticSymbolJson.uk)
                            } else {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandEN)
                            }
                        }
                        onValidClicked: {
                            if (playing) {
                                id_pronounce_buttons_grid.play(false)
                                if (!id_sound_us.visible) {
                                    qmlGlobal.soundWGTEn(resultManager.currentQuery)
                                } else {
                                    qmlGlobal.soundWGTEn(resultManager.currentQuery, YEnum.UK)
                                }
                                logManager.sendHttpLog("action=detail_british_accent_click")
                            }
                        }
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_default
                        width: 256
                        visible: !id_sound_us.visible && !id_sound_uk.visible
                        text: ('<span style="font-family: %1; font-weight: 500">%2</span>')
                        .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                        onValidClicked: {
                            if (playing) {
                                qmlGlobal.soundWGTEn(resultManager.currentQuery)
                            }
                        }
                    }
                }
            }

            Component {
                id: id_sentence_buttons

                Grid {
                    id: id_sentence_buttons_grid
                    columnSpacing: 8
                    rowSpacing: 8
                    columns: 2

                    function autoPlay() {
                        play(true)
                    }

                    function play(isOrg) {
                        if (isOrg) {
                            if (id_sound_tar.playing) {
                                id_sound_tar.stop()
                            }
                            id_sound_org.play()
                        } else {
                            if (id_sound_org.playing) {
                                id_sound_org.stop()
                            }
                            id_sound_tar.play()
                        }
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_org
                        width: 124
                        textItem.textFormat: YText.PlainText
                        text: YTranslateText.original
                        onValidClicked: {
                            if (playing) {
                                id_sentence_buttons_grid.play(true)
                                qmlGlobal.soundSentence()
                                logManager.sendHttpLog("action=detail_trans_sentence_click");
                            }
                        }
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_tar
                        width: 124
                        textItem.textFormat: YText.PlainText
                        text: YTranslateText.translation
                        onValidClicked: {
                            if (playing) {
                                id_sentence_buttons_grid.play(false)
                                qmlGlobal.soundSentence(id_dict_type_base_item.content)
                                logManager.sendHttpLog("action=detail_trans_pronounce_click");
                            }
                        }
                    }
                }
            }

            Component {
                id: id_cn_zh_word_button

                Item {
                    id: id_cn_zh_word_button_item
                    height: id_sound_cn_zh_word.height

                    function autoPlay() {
                        id_sound_cn_zh_word.play()
                    }

                    YAudioPlayIconLabelHCenterButton {
                        id: id_sound_cn_zh_word
                        width: 256
                        textItem.font.family: qmlGlobal.fontFamilyEnUs
                        textItem.textFormat: YText.RichText
                        text: {
                            if (resultManager.phoneticSymbolJson.length > 0) {
                                return resultManager.phoneticSymbolJson
                            } else {
                                return ('<span style="font-family: %1; font-weight: 500">%2</span>')
                                .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                            }
                        }
                        onValidClicked: {
                            if (playing) {
                                switch (resultManager.currentQueryType) {
                                case YEnum.WGT_Ch_Group:
                                    qmlGlobal.soundSentence()
                                    break
                                case YEnum.WGT_Ch:
                                    qmlGlobal.soundWGTCh()
                                    break
                                case YEnum.WGT_Ko_Group:
                                case YEnum.WGT_Ko:
                                    qmlGlobal.soundWGTKo()
                                    break
                                }
                            }
                        }
                    }
                }
            }

        }

        YSpacingForColumn {
            implicitHeight: 10
            visible: id_buttons_grid.visible
        }

        Flow {
            id: id_buttons_grid
            width: parent.width
            visible: isFirstDict
            spacing: 8
            readonly property int visibleBtn: (id_fav_word_button.visible ? 1 : 0)
                                              + (id_follow_pron_button.visible ? 2 : 0)
                                              + (id_spelling_button.visible ? 4 : 0)
                                              + (id_report_button.visible ? 8 : 0)
                                              + (id_switch_button.visible ? 16 : 0)
            property bool oddNumBtn: false

            function countValNum(val) {
                let count = 0;
                while (val > 0)
                {
                    count++
                    val = val & (val - 1)
                }
                return count;
            }

            onVisibleBtnChanged: {
                oddNumBtn = (countValNum(visibleBtn) % 2) > 0
            }

            YIconLabelHCenterButton {
                id: id_fav_word_button
                property bool checked: resultManager.isInWordBook
                iconSource: checked ? "dict/fav-stored" : "dict/fav"
                iconSourceSize: Qt.size(26, 26)
                width: (visible && id_buttons_grid.oddNumBtn && id_buttons_grid.visibleBtn < 2) ? 256 : 124
                text: YTranslateText.dictPageFav
                visible: resultManager.itemCount > 0 && id_dict_content_view.itemAtIndex(0).content !== null
                onValidClicked: {
                    let checkedWord = resultManager.currentQuery
                    if (!checked) {
                        let item = id_dict_content_view.itemAtIndex(0)
                        let simpleParaphrase = simpleParaphraseFunc(item.content, item.dictType)
                        console.warn("YDictPage.qml===id_fav_word_button===onValidClicked: checkedWord:", checkedWord, ", simpleParaphrase:", simpleParaphrase)
                        resultManager.addToWordBook(checkedWord,
                                                    '{"pos":"' + simpleParaphrase[0] + '","tran":"' + simpleParaphrase[1].replace(/"/g,"\\\"") + '"}',
                                                    simpleParaphrase[2], simpleParaphrase[3])
                        logManager.sendHttpLog("action=detail_add_wordbook_click")
                        if (settingManager.isFirstAddWb) {
                            settingManager.isFirstAddWb = false
                            qmlGlobal.showToast(YTranslateText.isFirstAddWb, "#2D2E33")
                        }
                    } else {
                        console.warn("YDictPage.qml===id_fav_word_button===onValidClicked: deleteFromWordBook:", checkedWord)
                        resultManager.deleteFromWordBook(checkedWord)
                        if (settingManager.isFirstRemoveWb) {
                            settingManager.isFirstRemoveWb = false
                            qmlGlobal.showToast(YTranslateText.isFirstRemoveWb, "#2D2E33")
                        }
                    }
                }
            }

            YIconLabelHCenterButton {
                id: id_follow_pron_button
                iconSource: "dict/follow-pron"
                iconSourceSize: Qt.size(26, 26)
                width: (visible && id_buttons_grid.oddNumBtn && id_buttons_grid.visibleBtn < 4) ? 256 : 124
                text: YTranslateText.dictPageFollow
                visible: qmlTranslator.textIsEnglishOnly(resultManager.currentQuery)
                onValidClicked: {
                    if (!wifiManager.onoff || !wifiManager.link) {
                        qmlGlobal.showToast(YTranslateText.noNetworkTip, YColors.grayNormal)
                        return
                    }
                    soundCenter.stop();
                    followManager.ukPhonetic = "";
                    followManager.usPhonetic = "";
                    logManager.sendHttpLog("action=detail_add_follow_click")
                    try {
                        console.log("##############", JSON.stringify(resultManager.phoneticSymbolJson));
                        var phoneticSymbolJson = JSON.parse(resultManager.phoneticSymbolJson);
                    } catch(e) { }
                    if (typeof phoneticSymbolJson != "undefined"){
                        //console.log("&&&&&&&&", phoneticSymbolJson.us);
                        followManager.ukPhonetic = typeof phoneticSymbolJson.uk == "undefined" ? "" : phoneticSymbolJson.uk;
                        followManager.usPhonetic = typeof phoneticSymbolJson.us == "undefined" ? "" : phoneticSymbolJson.us;
                    }
                    followManager.clearResult()
                    followManager.content = resultManager.currentQuery;
                    followManager.isUk = (settingManager.autoPronounceType === YEnum.UK) && followManager.ukPhonetic.length != 0
                    qmlGlobal.showFollowPage();
                }
            }

            YIconLabelHCenterButton {
                id: id_spelling_button
                iconSource: "dict/spelling"
                iconSourceSize: Qt.size(26, 26)
                width: (visible && id_buttons_grid.oddNumBtn && id_buttons_grid.visibleBtn < 8) ? 256 : 124
                text: YTranslateText.dictPageSpell
                visible: spellManager.phonics.length > 0
                onValidClicked: {
                    logManager.sendHttpLog("action=detail_add_spell_click")
                    soundCenter.stop();
                    spellManager.content = resultManager.currentQuery;
                    spellManager.richContent = resultManager.currentQuery;
                    qmlGlobal.showSpellPage();
                }
            }

            YIconLabelHCenterButton {
                id: id_report_button
                iconSource: "dict/report"
                iconSourceSize: Qt.size(26, 26)
                width: (visible && id_buttons_grid.oddNumBtn && id_buttons_grid.visibleBtn < 16) ? 256 : 124
                text: YTranslateText.dictPageReport
                visible: resultManager.isReportButtonVisible
                onValidClicked: {
                    logManager.sendHttpLog("action=detail_improve_click")
                    qmlGlobal.showToast(YTranslateText.thxReport, "#2D2E33")
                    resultManager.reportBadcaseButtonClicked()
                    resultManager.isReportButtonVisible = false
                    id_dict_page.reportedSet.add(resultManager.currentQuery)
                    //enabled = false
                }
            }

            YIconLabelHCenterButton {
                id: id_switch_button
                iconSource: {
                    switch (resultManager.transBtnType) {
                    case YEnum.TBT_Ja:
                        return "dict/switch_jp"
                    case YEnum.TBT_Ch:
                    default:
                        return "dict/switch_ch"
                    }
                }
                iconSourceSize: Qt.size(26, 26)
                width: (visible && id_buttons_grid.oddNumBtn && id_buttons_grid.visibleBtn < 32) ? 256 : 124
                text: YTranslateText.dictPageSwitch
                visible: resultManager.isTransBtnVisible
                onValidClicked: {
                    switch (resultManager.transBtnType) {
                    case YEnum.TBT_Ja:
                        resultManager.transBtnType = YEnum.TBT_Ch
                        break
                    case YEnum.TBT_Ch:
                        resultManager.transBtnType = YEnum.TBT_Ja
                        break
                    }
                    resultManager.queryResult(getWords())
                }
            }

        }

        YSpacingForColumn {
            visible: id_associated_word_loader.active
            implicitHeight: 16
        }

        YLoader {
            id: id_associated_word_loader
            width: parent.width
            active: isFirstDict && resultManager.associatedWord.length > 0
            sourceComponent: Column {
                id: id_associated_word_column
                width: parent.width
                visible: id_associated_word_row.visible
                spacing: 0
                readonly property var associatedWordDictJson: resultManager.associatedTrans.length > 0 ? JSON.parse(resultManager.associatedTrans) : null
                readonly property var phoneticSymbolJson: (associatedWordDictJson !== null && typeof associatedWordDictJson.pure.word != "undefined")
                                                          ? associatedWordDictJson.pure.word : null

                function play(isUS) {
                    if (isUS) {
                        if (id_associated_word_sound_uk.playing) {
                            id_associated_word_sound_uk.stop()
                        }
                        id_associated_word_sound_us.play()
                    } else {
                        if (id_associated_word_sound_us.playing) {
                            id_associated_word_sound_us.stop()
                        }
                        id_associated_word_sound_uk.play()
                    }
                }

                Row {
                    id: id_associated_word_row
                    spacing: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 25

                    YText {
                        id: id_associated_word_label
                        color: YColors.grayText
                        font.pixelSize: 16
                        width: contentWidth
                        height: contentHeight
                        anchors.bottom: parent.bottom
                        text: YTranslateText.relatedWords + ": "
                    }

                    YTextMedium {
                        id: id_associated_word_content
                        color: YColors.blueText
                        wrapMode: YText.Wrap
                        font.pixelSize: 18
                        font.family: qmlGlobal.fontFamilyEnUs
                        width: parent.width - parent.spacing - id_associated_word_label.width
                        height: contentHeight
                        text: resultManager.associatedWord

                        YMouseArea {
                            width: parent.width
                            height: parent.height * 2
                            anchors.centerIn: parent
                            onClicked: {
                                console.log("YDictTypeBase.qml====id_related_word_clicked associatedWord:", resultManager.associatedWord)
                                //id_dict_page.requeryWord(resultManager.associatedWord, "en", "zh-CHS")
                                id_dict_page.clickSearchWord(resultManager.associatedWord)
                            }
                            objectName: "YDictTypeBase.qml_id_related_word_trans"
                        }
                    }
                }

                YSpacingForColumn {
                    implicitHeight: 4
                    visible: id_associated_word_dictJson.visible
                }

                YTextBase {
                    id: id_associated_word_dictJson
                    font.pixelSize: 18
                    wrapMode: YText.Wrap
                    textFormat: YTextBase.RichText
                    width: parent.width
                    height: paintedHeight
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 24
                    text: {
                        if (id_associated_word_column.associatedWordDictJson === null) {
                            return ""
                        }
                        let sResult = ''
                        if (typeof id_associated_word_column.associatedWordDictJson.pure.m != "undefined") {
                            let mArray = id_associated_word_column.associatedWordDictJson.pure.m
                            mArray.forEach(function(mean){
                                if (typeof mean.pos !== "undefined") {
                                    sResult += '<span style="font-family: Georgia; font-style: italic;'
                                            + (' color: %1; font-size: 24px">').arg(YColors.grayText) + mean.pos + '</span>'
                                            + '<span>&nbsp;</span>'
                                }

                                sResult += '<span style="font-family: OPPOSans; font-weight: 500; '
                                        + ('color: %1; font-size: 28px">').arg(YColors.white) + mean.m + '</span>'
                                        + '<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>'
                            })
                            if (typeof id_associated_word_column.associatedWordDictJson.pure.phonics != "undefined")
                                spellManager.phonics  = JSON.stringify(id_associated_word_column.associatedWordDictJson.pure.phonics);
                            else
                                spellManager.phonics = "";
                            return sResult
                        }
                        else if (typeof id_associated_word_column.associatedWordDictJson.pure.word != "undefined") {
                            let mArray = id_associated_word_column.associatedWordDictJson.pure.word.trs
                            mArray.forEach(function(mean){
                                if (typeof mean.pos !== "undefined") {
                                    sResult += '<span style="font-family: Georgia; font-style: italic;'
                                            + (' color: %1; font-size: 24px">').arg(YColors.grayText) + mean.pos + '</span>'
                                            + '<span>&nbsp;</span>'
                                }

                                sResult += '<span style="font-family: OPPOSans; font-weight: 500; '
                                        + ('color: %1; font-size: 28px">').arg(YColors.white) + mean.tran + '</span>'
                                        + '<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>'
                            })

                            spellManager.phonics = "";
                            return sResult
                        }
                    }
                    visible: text.length > 0
                }

                YSpacingForColumn {
                    implicitHeight: 16
                    visible: id_associated_word_sound_us.visible || id_associated_word_sound_uk.visible
                }

                YAudioPlayIconLabelHCenterButton {
                    id: id_associated_word_sound_us
                    visible: soundCenter.hasUsSound(resultManager.associatedWord)
                             && id_associated_word_column.phoneticSymbolJson !== null
                             && (typeof id_associated_word_column.phoneticSymbolJson.usphone != "undefined")
                    width: parent.width
                    text: {
                        let qsRst = ""
                        if (!id_associated_word_sound_uk.visible) {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                        } else if (id_associated_word_column.phoneticSymbolJson.usphone.length > 0) {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>&nbsp;<span style="font-family: %3">&frasl;&nbsp;%4&nbsp;&frasl;</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandUS).arg(qmlGlobal.fontFamilyEnUs).arg(id_associated_word_column.phoneticSymbolJson.usphone)
                        } else {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandUS)
                        }
                        return qsRst
                    }
                    onValidClicked: {
                        if (playing) {
                            id_associated_word_column.play(true)
                            if (!id_associated_word_sound_uk.visible) {
                                qmlGlobal.soundWGTEn(resultManager.associatedWord)
                            } else {
                                qmlGlobal.soundWGTEn(resultManager.associatedWord, YEnum.US)
                            }
                            logManager.sendHttpLog("action=detail_american_accent_click")
                        }
                    }
                }

                YSpacingForColumn {
                    implicitHeight: 8
                    visible: id_associated_word_sound_us.visible && id_associated_word_sound_uk.visible
                }

                YAudioPlayIconLabelHCenterButton {
                    id: id_associated_word_sound_uk
                    visible: soundCenter.hasUkSound(resultManager.associatedWord)
                             && id_associated_word_column.phoneticSymbolJson !== null
                             && (typeof id_associated_word_column.phoneticSymbolJson.ukphone != "undefined")
                    width: parent.width
                    text: {
                        let qsRst = ""
                        if (!id_associated_word_sound_us.visible) {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.pronunciation)
                        } else if (id_associated_word_column.phoneticSymbolJson.ukphone.length > 0) {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>&nbsp;<span style="font-family: %3">&frasl;&nbsp;%4&nbsp;&frasl;</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandEN).arg(qmlGlobal.fontFamilyEnUs).arg(id_associated_word_column.phoneticSymbolJson.ukphone)
                        } else {
                            qsRst = ('<span style="font-family: %1; font-weight: 500">%2</span>')
                            .arg(qmlGlobal.fontFamily).arg(YTranslateText.shorthandEN)
                        }
                        return qsRst
                    }
                    onValidClicked: {
                        if (playing) {
                            id_associated_word_column.play(false)
                            if (!id_associated_word_sound_us.visible) {
                                qmlGlobal.soundWGTEn(resultManager.associatedWord)
                            } else {
                                qmlGlobal.soundWGTEn(resultManager.associatedWord, YEnum.UK)
                            }
                            logManager.sendHttpLog("action=detail_british_accent_click")
                        }
                    }
                }
            }
        }

        YSpacingForColumn {
            implicitHeight: 10
            visible: id_buttons_top_more_row.visible
        }

        Row {
            id: id_buttons_top_more_row
            height: 50
            spacing: 8
            visible: !isFirstDict || isShowDetailButton

            YIconLabelHCenterButton {
                id: id_dict_totop_button
                iconSource: "dict/top"
                iconSourceSize: Qt.size(24, 24)
                spacing: 6
                width: id_dict_detail_button.visible ? 124 : 256
                text: YTranslateText.dictPageGotoTop
                visible: !isFirstDict
                onValidClicked: {
                    resultManager.setTop(dictType)
                    id_dict_page.backToContentTop()
                }
            }

            YIconLabelHCenterButton {
                id: id_dict_detail_button
                iconSource: "dict/detail"
                iconSourceSize: Qt.size(24, 24)
                width: id_dict_totop_button.visible ? 124 : 256
                text: YTranslateText.dictPageMore
                visible: isShowDetailButton
                onValidClicked: {
                    console.log("YDictTypeBase.qml===id_dict_detail_button===onValidClicked")
                    id_dict_page.backContentYPos =  id_container_flickable.contentY
                    if (resultManager.mainQueryBreakList.length > 1) {
                        qmlGlobal.showDictDetailPage(dictType, content, resultManager.mainQueryBreakList[id_dict_page.tagsIndex].content)
                    } else {
                        qmlGlobal.showDictDetailPage(dictType, content, resultManager.mainQuery)
                    }
                }
            }
        }

        YSpacingForColumn {
            implicitHeight: 20

            YVerticalDividingLine {
                id: id_div_line
                anchors.bottom: parent.bottom
                sourceSize: Qt.size(parent.width, 2)
                visible: (resultManager.itemCount > 1) && (index < (resultManager.itemCount - 1))
            }
        }
    }
}
