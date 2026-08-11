import QtQuick 2.12
import QtQml 2.14
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YLoader {
    id: id_word_book_page_switch_loader
    anchors.fill: parent

    function stopPronounce() {
        soundCenter.stop()
    }

    onActiveChanged: {
        wordBookManager.setCanAutoPlay(active)
        if (active) {
            screenManager.reportAction('wordbook_cardview_enter')
            console.log("YWordBookPageSwitchLoader.qml===wordBookManager.loadMore on active")
            wordBookManager.loadMore()
        }
        else {
            screenManager.reportAction('wordbook_cardview_quit')
            console.log("YWordBookPageSwitchLoader.qml===wordBookManager.loadMore on inactive")
            stopPronounce()
        }
    }

    sourceComponent: YBackgroundIgnoreMouseEvent {

        function showFilter() {
            id_word_book_filter_drawer_layer.show()
        }

        PathView {
            id: id_card_pathview
            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            movementDirection: settingManager.isWbAutoPlay ? PathView.Positive : PathView.Shortest
            pathItemCount: 1
            flickDeceleration: 2000
            path: Path{
                startX: 0
                startY: id_card_pathview.height/2;
                PathLine {
                    x: id_card_pathview.width
                    y: id_card_pathview.height/2
                }
            }
            model: wordBookManager
            onMovingChanged: {
                if (!moving && (id_card_pathview.count < wordBookManager.wordCount)) {
                    wordBookManager.loadMore()
                }
            } // todo 细化 loadMore 逻辑

            onCurrentIndexChanged: {
                console.log("word card index change")
                autoPronounce()
            }

            delegate: id_card_view_delegate

            readonly property alias indexTipWidth: id_index_tip.width
            interactive: !settingManager.isWbAutoPlay
        }

        Connections {
            target: wordBookManager
            ignoreUnknownSignals: true
            enabled: id_word_book_page_switch_loader.active
            onWordCardSoundFinish: {
                if (id_card_pathview.visible) {
                    console.log("word card sound finish")
                    nextWordIndex()
                }
            }
        }

        Connections {
            target: qmlGlobal
            ignoreUnknownSignals: true
            enabled: id_word_book_page_switch_loader.active
            onBackToWordCardView: {
                if (id_card_pathview.visible && !wordBookManager.canAutoPlay()) {
                    console.log("back to word card")
                    wordBookManager.setCanAutoPlay(true)
                    autoPronounce()
                }
            }
        }

        Connections {
            target: settingManager
            ignoreUnknownSignals: true
            enabled: id_word_book_page_switch_loader.active
            onIsWbAutoPlayChanged: {
                if (settingManager.isWbAutoPlay)
                    autoPronounce()
            }
        }

        Connections {
            target: systemBase
            ignoreUnknownSignals: true
            enabled: id_word_book_page_switch_loader.active
            onScreenOn: {
                console.log("wordbook screen on")
                if (settingManager.isWbAutoPlay)
                    autoPronounce()
            }
        }

        function autoPronounce() {
            if (id_word_book_page_switch_loader.active) {
                wordBookManager.autoPronounce(id_card_pathview.currentIndex);
            }
        }


        function nextWordIndex() {
            if (id_word_book_page_switch_loader.active) {
                if (!settingManager.isWbAutoPlay || !wordBookManager.canAutoPlay()) {
                    return
                }
                // 还有未加载的，需要加载
                if (id_card_pathview.currentIndex < id_card_pathview.count) {
                    id_card_pathview.currentIndex =
                            (1 + id_card_pathview.currentIndex) % wordBookManager.wordCount
                }
                if (id_card_pathview.count < wordBookManager.wordCount) {
                    wordBookManager.loadMore()
                }
            }
        }

        Item {
            implicitHeight: 30
            anchors.right: parent.right
            y: - id_card_pathview.currentItem.contentY

            YBackground {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                radius: 21
                width: 54
                YText {
                    id: id_index_tip
                    anchors.centerIn: parent
                    font.pixelSize: 14
                    textFormat: YTextBase.RichText
                    width: paintedWidth
                    text: ("%1<font color=\"%3\">/%2</font>").arg(id_card_pathview.currentIndex + 1).arg(wordBookManager.wordCount).arg(YColors.grayText)
                }
            }
        }

        YVerticalTitleBar {
            onCallBack: {
                if (settingManager.modelChangeCount < 3) {
                    qmlGlobal.showToast(YTranslateText.switchList, "#2D2E33")
                    settingManager.setModelChangeCount(settingManager.modelChangeCount + 1);
                }
                console.log("YWordBookPageCardViewLoader.qml===onBack")
                id_word_book_page_switch_loader.active = false
                id_card_pathview.currentIndex = 0
                stopPronounce()
            }

            YIconButton {
                id: id_more_button_bg
                implicitWidth: 30
                implicitHeight: 30
                mouseAreaMargins: -18
                radius: height/2
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.bottom: parent.bottom
                sourceSize: Qt.size(24, 24)
                imageName: "commons/more"
                onClicked: {
                    id_word_book_page_switch_loader.item.showFilter()
                    console.log("YWordBookPageSwitchLoader.qml===callFilter")
                }
            }
        }

        YWordBookFilterDrawerLayer {
            id: id_word_book_filter_drawer_layer
            currentFilterWordsList: false
        }


        Component.onCompleted: {
            id_card_pathview.currentIndex = 0
            wordBookManager.setCanAutoPlay(true)
            autoPronounce()
        }
    }

    Component {
        id: id_card_view_delegate
        Flickable {
            id: id_item_delegate
            width: PathView.view.width
            height: PathView.view.height
            contentHeight: id_item_delegate_olumn.height

            readonly property var jsonTranslate: model.modelData.translate.length > 0 ?
                                                     JSON.parse(model.modelData.translate) : null
            readonly property bool containsDetails: typeof jsonTranslate.tran != "undefined"

            Column {
                id: id_item_delegate_olumn
                anchors.left: parent.left
                anchors.right: parent.right
                topPadding: 14

                YText {
                    id: id_word
                    height: paintedHeight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: id_item_delegate.PathView.view.indexTipWidth + 4
                    Behavior on anchors.leftMargin {
                        NumberAnimation { duration: 180 }
                    }
                    verticalAlignment: YText.AlignVCenter
                    font.weight: Font.Bold
                    font.pixelSize: 18
                    font.family: {
                        switch (model.modelData.srcLangType) {
                        case YEnum.ZH_CN:
                        case YEnum.ZH_TW:
                            return qmlGlobal.fontFamilyZhCn
                        case YEnum.EN_US:
                        default:
                            return qmlGlobal.fontFamilyEnUs
                        }
                    }
                    text: model.modelData.content
                    elide: YText.ElideRight
                }

                YSpacingForColumn {
                    implicitHeight: 10
                }

                property bool isSentenceDat : {
                    if(null !== id_example_container.exampleJson){
                        if(id_example_container.exampleJson.hasOwnProperty("sentence-pair"))
                            return true
                        else
                            return false
                    }
                    return false
                }

                readonly property bool enSentVisible: {
                    if(isSentenceDat){
                        return ((null !== id_example_container.exampleJson)
                                && (typeof id_example_container.exampleJson["sentence-pair"][0]["sentence-eng"] != "undefined"))
                    }else{
                        return  ((null !== id_example_container.exampleJson)
                                 && (typeof id_example_container.exampleJson.enSent != "undefined"))
                    }
                }


                Item {
                    id: id_example_container
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    height: id_example_column.height
                    visible: id_item_delegate_olumn.enSentVisible

                    readonly property var exampleJson: {
                        console.warn("YWordBookPageCardViewLoader===exampleJson:", model.modelData.example)
                        return (model.modelData.example !== null && model.modelData.example.length > 0)
                                ? JSON.parse(model.modelData.example) : null
                    }

                    YTextBase {
                        id: id_example_label
                        anchors.left: parent.left
                        width: contentWidth
                        font.pixelSize: 18
                        font.family: "Castoro"
                        font.styleName: "italic"
                        color: YColors.grayText
                        text: "eg."
                        visible: id_item_delegate_olumn.enSentVisible
                    }

                    Column {
                        id: id_example_column
                        anchors.left: id_example_label.right
                        anchors.leftMargin: 9
                        anchors.right: parent.right

                        YTextMedium {
                            id: id_example
                            anchors.left: parent.left
                            anchors.right: parent.right
                            wrapMode: YTextMedium.Wrap
                            height: paintedHeight
                            textFormat: YTextMedium.RichText
                            font.pixelSize: 20
                            font.family: {
                                switch (model.modelData.srcLangType) {
                                case YEnum.ZH_CN:
                                case YEnum.ZH_TW:
                                    return qmlGlobal.fontFamilyZhCn
                                case YEnum.EN_US:
                                default:
                                    return qmlGlobal.fontFamilyEnUs
                                }
                            }
                            font.styleName: {
                                switch (model.modelData.srcLangType) {
                                case YEnum.ZH_CN:
                                case YEnum.ZH_TW:
                                    return "normal"
                                case YEnum.EN_US:
                                default:
                                    return "italic"
                                }
                            }
                            text: {
                                if (id_item_delegate_olumn.enSentVisible) {
                                    const regEx = new RegExp(model.modelData.content, "ig")
                                    if(id_item_delegate_olumn.isSentenceDat){
                                        return id_example_container.exampleJson["sentence-pair"][0]["sentence-eng"].replace(regEx, function(param){
                                            return ("<font color=\"%2\">%1</font>").arg(param).arg(YColors.red);
                                        });
                                    }else{
                                        return id_example_container.exampleJson.enSent.replace(regEx, function(param){
                                            return ("<font color=\"%2\">%1</font>").arg(param).arg(YColors.red);
                                        });
                                    }
                                }
                                return ""
                            }
                            visible: id_item_delegate_olumn.enSentVisible
                        }

                        YSpacingForColumn {
                            implicitHeight: 5
                        }

                        YTextBase {
                            id: id_from_label
                            anchors.left: parent.left
                            anchors.right: parent.right
                            width: contentWidth
                            height: contentHeight
                            font.pixelSize: 14
                            color: YColors.grayText
                            visible:  {
                                if (null === id_example_container.exampleJson) {
                                    return false
                                }
                                if(id_item_delegate_olumn.isSentenceDat)
                                    return (typeof id_example_container.exampleJson["sentence-pair"][0]["source"] != "undefined") ? true : false
                                else
                                    return (typeof id_example_container.exampleJson.source != "undefined") ? true : false
                            }
                            text: {
                                if(id_item_delegate_olumn.isSentenceDat){
                                    if (null !== id_example_container.exampleJson
                                            && typeof id_example_container.exampleJson["sentence-pair"][0]["source"] != "undefined") {
                                        return YTranslateText.derivedFromWhere.arg(id_example_container.exampleJson["sentence-pair"][0]["source"])
                                    }
                                }else{
                                    if (null !== id_example_container.exampleJson
                                            && typeof id_example_container.exampleJson.source != "undefined") {
                                        return YTranslateText.derivedFromWhere.arg("《" + id_example_container.exampleJson.source + "》")
                                    }
                                }

                                return ""
                            }
                        }
                    }

                }

                YSpacingForColumn {
                    implicitHeight: 10
                    visible: id_example_container.visible
                }

                YMouseArea {
                    id: id_means_container
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: -10
                    height: 24

                    YTextBase {
                        id: id_means_label
                        anchors.left: parent.left
                        anchors.verticalCenter: id_means.verticalCenter
                        width: contentWidth
                        font.pixelSize: 18
                        font.family: {
                            switch (model.modelData.srcLangType) {
                            case YEnum.ZH_CN:
                            case YEnum.ZH_TW:
                                return qmlGlobal.fontFamilyZhCn
                            case YEnum.EN_US:
                            default:
                                return "Castoro"
                            }
                        }
                        font.styleName: {
                            switch (model.modelData.srcLangType) {
                            case YEnum.ZH_CN:
                            case YEnum.ZH_TW:
                                return "normal"
                            case YEnum.EN_US:
                            default:
                                return "italic"
                            }
                        }
                        color: YColors.grayText
                        text: id_item_delegate.jsonTranslate.pos
                        visible: text.length > 0
                    }

                    YTextBase {
                        id: id_means
                        anchors.left: parent.left
                        anchors.leftMargin: id_means_label.visible ? Math.max(id_means_label.width + 10, 26) : 0
                        anchors.right: parent.right
                        anchors.rightMargin: 24 + 10
                        font.pixelSize: 16
                        font.family: {
                            switch (model.modelData.dictType) {
                            case YEnum.DtChChinese:
                            case YEnum.DtSimple:
                            case YEnum.DtEnChKid:
                                return qmlGlobal.fontFamilyZhCn
                            default:
                                return qmlGlobal.fontFamilyZhCn
                            }
                        }
                        color: YColors.grayText
                        text: id_item_delegate.jsonTranslate.tran
                        elide: YText.ElideRight

                    }
                    YImage {
                        sourceSize: Qt.size(24, 24)
                        imageName: "wordbook/word_detail"
                        anchors.left: id_means.right
                        anchors.verticalCenter: id_means.verticalCenter
                    }

                    onClicked: {
                        wordBookManager.setCanAutoPlay(false)
                        id_word_book_page_switch_loader.stopPronounce()
                        if (!resultManager.entryResult(model.modelData.content,
                                                       model.modelData.srcLang,
                                                       model.modelData.dstLang,
                                                       YEnum.PageIndex.Fav)) {
                            qmlGlobal.showToast(YTranslateText.queryFaildPleaseTryAgain, "#2D2E33")
                        } else {
                            qmlGlobal.showDictPage(YEnum.PageIndex.Fav)
                        }
                    }
                    objectName: "YWordBookPageCardViewLoader.qml_YMouseArea"
                }
            }

        }
    }

    /*
20:18:05.684 [debg]: [YWordBookManager] YWordEntity to string:content: home
translate: {"phonics":[{"position":[0],"sound":"h"},{"position":[1,3],"sound":"əʊ"},{"position":[2],"sound":"m_back"}],"uk":"həʊm","m":[{"m":"家；住所; 家；家庭; （强调归属感的）家乡，故乡，祖国","pos":"n."},{"m":"到家；向家；在家","pos":"adv."}],"us":"hoʊm"}
srcLang: en
dstLang: zh-CHS
dictType: 0
wordGroupType: 4
languageType: 1
16:08:37.065 [debg]: [YWordBookManager] addToWordBook from db start
16:08:37.066 [debg]: [YWordBookManager] YWordEntity to string:content: 发音
translate: {"antonyms":[],"meanings":[{"pos":"动","value":"发出声音（多指发出乐音或语音）","example":["<b>发音</b>方法不同","<b>发音</b>准确。"]}],"pinyin":["fā","yīn"],"synonyms":[]}
srcLang: zh-CHS
dstLang: en
dictType: 200
wordGroupType: 1
languageType: 0
16:08:37.067 [debg]: [YWordBookManager] YWordEntity to string:content: 系列
translate: {"antonyms":[],"meanings":[{"pos":"名","value":"组合成套的、性质相同或相近而又相关联的事物","example":["同属一个<b>系列</b>","<b>系列</b>产品。"]}],"pinyin":["xì","liè"],"synonyms":[]}
srcLang: zh-CHS
dstLang: en
dictType: 200
wordGroupType: 1
languageType: 0
16:08:37.068 [debg]: [YWordBookManager] YWordEntity to string:content: 笔
translate: {"details":[{"antonyms":[],"end":["铅笔","钢笔","手笔","走笔","着笔","曲笔","落笔","大笔","试笔","彩笔","粉笔","援笔","纸笔","随笔","湖笔","宣笔","败笔","伏笔","提笔","信笔","毛笔","绝笔","亲笔"," 振笔","辍笔","画笔","动笔","几笔","秉笔","文笔","简笔","起笔","妙笔","下笔","水笔","执笔","刀笔"],"idioms":["笔走龙蛇","春秋笔法","神来之笔","生花妙笔","投笔从戎","一笔不苟"],"meanings":[{"value":"用于写字、绘画的工具，古代笔杆用竹制成","example":["钢笔","毛笔","铅笔","笔墨纸砚","提笔忘字"]},{"value":"写，记载，记录，或与写作有关的","example":["代笔","亲笔","笔者","笔名","笔录"]},{"value":"写文章或作画的技巧","example":["文笔","伏笔","笔法","曲笔","大笔点绕"]},{"value":"散文，文章，相对于诗体而言的记叙类文学体裁","example":["笔述","随笔","文笔"]},{"value":"不弯的，如笔般直挺的","example":["笔直","笔挺","笔立"]},{"value":"写下的点、画、文字或其他痕迹","example":["绝笔","笔迹","笔画","笔顺"]},{"value":"指汉字的笔画，即横、直、撇、捺等","example":["起笔","笔形","笔顺","笔脚","末笔"]},{"value":"用作量词，用于计算款项、书画作品或笔画的数量","example":["一笔账","一笔钱","一共五笔","一笔好字"]}],"pinyin":"bǐ","start":["笔记","笔者","笔下","笔墨","笔直","笔记本","笔底","笔杆","笔触","笔挺","笔锋","笔立","笔端","笔名","笔调","笔债","笔意","笔头","笔管","笔力","笔体","笔法"],"synonyms":[]}],"radical":"竹(⺮)","stroke":["丿","一","丶","丿","一","丶","丿","一","一","乚"],"strokeCount":10,"structure":"上下结构"}
srcLang: zh-CHS
dstLang: en
dictType: 200
wordGroupType: 2
languageType: 0
16:08:37.068 [debg]: [YWordBookManager] YWordEntity to string:content: 词典
translate: {"antonyms":[],"meanings":[{"pos":"名","value":"收集词语，按一定顺序编排，加以注音、释义等，供人查阅参考的工具书。","example":[]}],"pinyin":["cí","diǎn"],"synonyms":["辞书"]}
srcLang: zh-CHS
dstLang: en
dictType: 200
wordGroupType: 1
languageType: 0
16:08:37.069 [debg]: [YWordBookManager] addToWordBook from db end
16:08:38.208 [warn]:
    */


}

