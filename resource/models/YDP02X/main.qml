import "./qml"
import "./qml/audioplayer"
import "./qml/commons"
import "./qml/components"
import "./qml/i18n"
import "./qml/utils/utils.js" as UTILS
import QtQuick 2.12
import com.github.penuniverse 1.0
import com.youdao.pen 1.0

YMainWindow {
    id: id_main_menu_root

    function showPage(qrcqml, cachePage, properties) {
        return id_page_pop_helper.pushLegacy(qrcqml, properties, {
            "cache": !!cachePage,
            "animation": true
        });
    }

    function closeAudioPlayer() {
        if (id_audio_player_loader.item) {
            id_audio_player_loader.item.close();
        }
    }

    property var mainKeyboardPage: null
    property bool mainKeyboardPreloadPending: false
    property bool mainKeyboardRequestPending: false

    function setupMainKeyboard(page) {
        if (!page || mainKeyboardPage)
            return;

        mainKeyboardPage = page;
        page.visible = false;
        page.backButtonClicked.connect(function() {
            qmlGlobal.inputPageShowing = false;
            page.visible = false;
            if (typeof page.resetInput === "function")
                page.resetInput("");
        });
        page.inputFinished.connect(function(contents) {
            qmlGlobal.canAutoAddToWb = true;
            if (resultManager.entryResult(contents, "", "", YEnum.PageIndex.Dict, 1)) {
                const pageIndex = (qmlGlobal.currentPageIndex === YEnum.PageIndex.Fav)
                ? YEnum.PageIndex.Fav
                : YEnum.PageIndex.NonePage;
                qmlGlobal.showDictPage(pageIndex);
                resultManager.isReportButtonVisible = true;
                id_scan_words_result_loader.active = false;
            } else {
                qmlGlobal.canAutoAddToWb = false;
                showEmptyAndToast();
            }
        });

        if (mainKeyboardRequestPending) {
            mainKeyboardRequestPending = false;
            activateMainKeyboard();
        }
    }

    function preloadMainKeyboard() {
        if (mainKeyboardPage || mainKeyboardPreloadPending)
            return;
        mainKeyboardPreloadPending = true;

        let component = qmlCreateComponent("YInputPage");
        if (component.status === Component.Error) {
            mainKeyboardPreloadPending = false;
            console.error("!!! YInputPage 组件创建失败 !!!", component.errorString());
            return;
        }

        function incubateKeyboard() {
            let incubator = component.incubateObject(id_page_keyboard.containerItem, {}, Qt.Asynchronous);
            if (incubator.status === Component.Ready) {
                mainKeyboardPreloadPending = false;
                setupMainKeyboard(incubator.object);
            } else {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        mainKeyboardPreloadPending = false;
                        setupMainKeyboard(incubator.object);
                    } else if (status === Component.Error) {
                        mainKeyboardPreloadPending = false;
                        console.error("YInputPage 孵化失败 (Incubation Error)!");
                    }
                };
            }
        }

        if (component.status === Component.Ready) {
            incubateKeyboard();
        } else if (component.status === Component.Loading) {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready)
                    incubateKeyboard();
                else if (component.status === Component.Error) {
                    mainKeyboardPreloadPending = false;
                    console.error("!!! YInputPage 异步加载失败 !!!", component.errorString());
                }
            });
        }
    }

    function activateMainKeyboard() {
        if (!mainKeyboardPage) {
            mainKeyboardRequestPending = true;
            preloadMainKeyboard();
            return;
        }

        if (typeof mainKeyboardPage.resetInput === "function")
            mainKeyboardPage.resetInput(resultManager.mainQuery);
        else
            mainKeyboardPage.enterText(resultManager.mainQuery);
        mainKeyboardPage.placeHolderText = "请输入要查询的内容";
        mainKeyboardPage.show();
        qmlGlobal.inputPageShowing = true;
    }

    function requestKeyboard() {
        activateMainKeyboard();
    }

    Component.onCompleted: {
        console.log("@@@ main.qml ==== Component.onCompleted");
        id_delay_init_timer.start();
        systemBase.headSetInitStatus();
    }

    Item {
        id: id_index_page_host
        anchors.fill: parent
        property alias transitionX: id_index_page_translate.x
        transform: Translate {
            id: id_index_page_translate
            x: 0
        }

        YIndexPage {
            id: id_index_page
        }
    }

    YNavigator {
        id: id_page_pop_helper
        backgroundItem: id_index_page_host
    }

    YScanWordsResultLoader {
        id: id_scan_words_result_loader

        onOcrStart: {
            if (typeof keyBoard !== 'undefined' && (keyBoard.autoSendScan || qmlGlobal.inputPageShowing)) {
                active = false;
                return;
            }
            closeTipDialog();
            closeAudioPlayer();
            closeQuickSetting();
            speechManager.setEnable(false);
        }
        isVerifiyFinished: id_main_menu_root.isVerifiyFinished
    }

    YLoader {
        id: id_audio_player_loader
        anchors.fill: parent
    }

    YPagePopHelper {
        id: id_page_keyboard

        function inputPageCreated(incubatorObject) {
            setupMainKeyboard(incubatorObject);
            activateMainKeyboard();
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_main.qml"
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true

        function onRequestSettingPage(index) {
            if (typeof keyBoard !== 'undefined' && keyBoard.inputPageShowing) {
                qmlGlobal.closeInputPageWhileHomeKeyReleased();
                qmlGlobal.inputPageShowing = false;
            }

            id_page_pop_helper.afterTransition(function() {
                showPage("YSettingPage");
                if (index < YEnum.SettingIndex.SI_COUNT) {
                    id_page_pop_helper.afterTransition(function() {
                        const settingPage = id_page_pop_helper.popItemObject;
                        if (settingPage && typeof settingPage.settingItemClicked === "function")
                            settingPage.settingItemClicked(index, true);
                    });
                }
            });

            id_scan_words_result_loader.hidden();
            closeQuickSetting();
            closeAudioPlayer();
        }

        function onShowLoginPage() {
            console.log("main.qml===onShowLoginPage===called");
            if (!wifiManager.onoff || !wifiManager.link) {
                qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal);
                return;
            }
            showPage("YLoginPage");
        }

        function onShowFollowPage(spellSwitchButtonVisible) {
            const followPage = showPage("YFollowPage");
            if (id_audio_player_loader.item && id_audio_player_loader.item.isShowing) {
                followPage.backButtonClicked.connect(id_audio_player_loader.item.raise);
                id_audio_player_loader.item.hidden();
            }
        }

        function onShowSpellPage(propertiesValue) {
            showPage("YSpellPage");
        }

        function onShowSpeechPage() {
            id_scan_words_result_loader.hidden();
            showPage("YSpeechPage", false);
        }

        function onShowDictPage(pageIndex, ocrContent) {
            console.log("main.qml===onShowDictPage===called pageIndex:", pageIndex);
            const dictPageObj = showPage("YDictPage", true);

            if (!dictPageObj) return;

            dictPageObj.stackQueryResult = [];

            switch (pageIndex) {
                case YEnum.PageIndex.History:
                    dictPageObj.title = YTranslateText.history;
                    break;
                case YEnum.PageIndex.Fav:
                    dictPageObj.title = YTranslateText.favoriteWords;
                    try {
                        dictPageObj.backButtonClicked.disconnect(qmlGlobal.backToWordCardView);
                    } catch(e) {}
                    dictPageObj.backButtonClicked.connect(qmlGlobal.backToWordCardView);
                    break;
                case YEnum.PageIndex.Reading:
                    dictPageObj.title = YTranslateText.touchreading;
                    break;
                default:
                    dictPageObj.title = "";
                    break;
            }

            dictPageObj.visible = true;

            if (ocrContent === "isOcrStart") {
                console.log('ocrContent === "isOcrStart"');
                dictPageObj.isButtonIsRePress = true;
                dictPageObj.isScannig = true;
                dictPageObj.visible = false;
            } else if (ocrContent && ocrContent.length > 0) {
                dictPageObj.ocrContentString = ocrContent;
            }

            resultManager.isReportButtonVisible = false;
        }

        function onQueryFromDictPage(mainQuery, srcLang, dstLang) {
            console.log("main.qml===onQueryFromDictPage===called", mainQuery);
            if (!resultManager.entryResult(mainQuery, srcLang, dstLang)) {
                qmlGlobal.showToast(YTranslateText.queryFaildPleaseTryAgain, "#2D2E33");
            } else {
                const dictPageObj = showPage("YDictPage", true);
                if (dictPageObj)
                    dictPageObj.title = YTranslateText.history;
            }
        }

        function onShowDictDetailPage(dictType, dictContent, qsTitle) {
            console.log("main.qml===onShowDictDetailPage", dictType, qsTitle);
            let dictDetailPageObj = showPage("YDictDetailPage", true);
            if (!dictDetailPageObj) return;

            const titleMap = {
                [YEnum.DtChLarge]: YTranslateText.dtChLarge,
                [YEnum.DtChAncientWord]: YTranslateText.dtChAncientWord,
                [YEnum.DtChPoemDict]: YTranslateText.ancientPoemsReading,
                [YEnum.DtSenior]: YTranslateText.dtSenior,
                [YEnum.DtWebster]: YTranslateText.dtWebster,
                [YEnum.DtOxford]: YTranslateText.dtOxfordNumber,
                [YEnum.DtKoCh]: YTranslateText.dtKoCh,
                [YEnum.DtChKo]: YTranslateText.dtChKo
            };

            dictDetailPageObj.title = titleMap[dictType] || qsTitle;
            dictDetailPageObj.dictType = dictType;
            dictDetailPageObj.content = dictContent;
        }

        function onShowAudioPlayer() {
            if (id_audio_player_loader.item)
                id_audio_player_loader.item.show();
        }

        function onRequestTouchReadingPage(index) {
            if (index < YEnum.RI_COUNT)
                id_page_pop_helper.showWithProperties("YTouchReadingPage", {
                    "currentTabIndex": index
                });
            else
                showPage("YTouchReadingPage");
        }

        function onRequestShowPage(index, cachePage) {
            switch (index) {
                case YEnum.PageIndex.Dict:
                    if (resultManager.mainQuery.length > 0 && !queryTweaks.typeByHand) {
                        qmlGlobal.showDictPage(index);
                    } else {
                        if (queryTweaks.typeByHand)
                            requestKeyboard();
                        else
                            id_scan_words_result_loader.showEmpty();
                    }
                    break;
                case YEnum.PageIndex.Speech:
                    qmlGlobal.showSpeechPage();
                    break;
                case YEnum.PageIndex.Reading:
                    showPage("YTouchReadingPage");
                    break;
                case YEnum.PageIndex.TextBook:
                    showPage("YTextbookPage");
                    break;
                case YEnum.PageIndex.Fav:
                    showPage("YWordBookPage");
                    break;
                case YEnum.PageIndex.Audioplayer:
                    showPage("YAudioPage", cachePage);
                    break;
                case YEnum.PageIndex.History:
                    const resultItem = showPage("YHistoryPage");
                    if (resultItem) historyManager.loadMore();
                    break;
                case YEnum.PageIndex.Setting:
                    showPage("YSettingPage");
                    break;
                case YEnum.PageIndex.PowerOff:
                    showPage("YPowerOffPage");
                    break;
                case PageIndex.AudioRecorder:
                    showPage("AudioRecorder");
                    break;
                case PageIndex.ChatAssistant:
                    showPage("ChatAssistant", true);
                    break;
                case PageIndex.PluginManager:
                    showPage("PluginManager");
                    break;
            }
        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true

        function onOcrCompletedResultChanged() {
            if (typeof keyBoard !== 'undefined' && (keyBoard.autoSendScan || qmlGlobal.inputPageShowing)) {
                id_scan_words_result_loader.active = false;
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
            }
        }

        function onOcrStop(scanType) {
            if (typeof keyBoard !== 'undefined' && (keyBoard.autoSendScan || qmlGlobal.inputPageShowing)) {
                id_scan_words_result_loader.active = false;
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
            }
        }

        function onHomeKeyRelease() {
            console.log("main.qml===onHomeKeyRelease===");
            closeTipDialog();

            if (closeQuickSetting()) return;

            qmlGlobal.closePageWhileHomeKeyReleased();
            qmlGlobal.currentPageIndex = YEnum.PageIndex.NonePage;

            if (qmlGlobal.inputPageShowing) {
                qmlGlobal.closeInputPageWhileHomeKeyReleased();
                qmlGlobal.inputPageShowing = false;
            }

            closeAudioPlayer();

            if (id_scan_words_result_loader.active) {
                qmlGlobal.stopAllAnimationMusic();
                id_scan_words_result_loader.active = false;
            }
            id_page_pop_helper.closeAllPopPage();
        }

        function onHomeKeyDoublePress() {
            console.log("main.qml====onHomeKeyDoublePress");
            if (quickSettingOpening)
                closeQuickSetting();
            else
                openQuickSetting();
        }

        function onPowerKeyLongPress() {
            if (id_audio_player_loader.active)
                id_audio_player_loader.active = false;

            soundCenter.forceStop();
            closeQuickSetting();
            qmlGlobal.requestShowPage(YEnum.PageIndex.PowerOff);
        }

        function onStopContinueScan() {
            id_scan_words_result_loader.showIndex = 0;
        }

        function onHomeKeyLongPress() {
            console.log("main.qml====onHomeKeyLongPress");
            closeQuickSetting();
        }
    }

    YTimer {
        id: id_delay_init_timer
        interval: 200
        onTriggered: {
            console.log("@@@ main.qml ==== id_delay_init_timer.triggered");
            delayInitMainWindow();
            id_index_page.delayInitMainTitleBar();
            if (id_audio_player_loader.source == "") {
                id_audio_player_loader.source = "qml/audioplayer/YAudioPlayer.qml";
            }
            id_audio_player_loader.active = true;
            preloadMainKeyboard();
            id_chat_assistant_preload_timer.start();
        }
    }

    Timer {
        id: id_chat_assistant_preload_timer
        interval: 50
        repeat: false
        onTriggered: id_page_pop_helper.preload("ChatAssistant")
    }
}
