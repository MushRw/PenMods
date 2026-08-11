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
        const useCache = !!cachePage;
        if (useCache)
            return id_page_pop_helper.cacheShow(qrcqml, false, properties);
        return id_page_pop_helper.show(qrcqml, false, properties);
    }

    function closeAudioPlayer() {
        if (id_audio_player_loader.item && id_audio_player_loader.item.isShowing) {
            id_audio_player_loader.item.close();
        }
    }

    function requestKeyboard() {
        let component = qmlCreateComponent("YInputPage");

        if (component.status === Component.Ready) {
            let incubator = component.incubateObject(id_page_keyboard.containerItem);

            let onFinished = function(obj) {
                console.log("main.qml===YInputPage", obj, "is ready!");
                id_page_keyboard.inputPageCreated(obj);
            };

            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        onFinished(incubator.object);
                    } else if (status === Component.Error) {
                        console.error("YInputPage 孵化失败 (Incubation Error)!");
                    }
                };
            } else {
                onFinished(incubator.object);
            }
        }
        else if (component.status === Component.Error) {
            console.error("!!! YInputPage 组件创建失败 (Component Error) !!!");
            console.error(component.errorString());
        }
        else if (component.status === Component.Loading) {
            console.log("YInputPage 正在加载中...");
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    console.log("YInputPage 异步加载完成，请重试或修改代码支持异步");
                } else if (component.status === Component.Error) {
                    console.error("!!! YInputPage 异步加载失败 !!!");
                    console.error(component.errorString());
                }
            });
        }
    }

    Component.onCompleted: {
        console.log("@@@ main.qml ==== Component.onCompleted");
        id_delay_init_timer.start();
        systemBase.headSetInitStatus();
    }

    YIndexPage {
        id: id_index_page
    }

    YStackView {
        id: id_stack_view
        onCurrentPopIdValidChanged: {
            if (!currentPopIdValid)
                qmlGlobal.currentPageIndex = YEnum.PageIndex.NonePage;
        }
    }

    YPopLayer {
        id: id_page_pop_helper
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
            incubatorObject.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                if (typeof incubatorObject.todoDestroy === "function") {
                    incubatorObject.todoDestroy();
                } else {
                    incubatorObject.destroy();
                }
                incubatorObject = null;
            });

            incubatorObject.inputFinished.connect(function(contents) {
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

            incubatorObject.placeHolderText = "请输入要查询的内容";
            incubatorObject.enterText(resultManager.mainQuery);
            incubatorObject.show();
            qmlGlobal.inputPageShowing = true;
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

            showPage("YSettingPage");
            if ((index < YEnum.SettingIndex.SI_COUNT) && id_page_pop_helper.popItemObject)
                id_page_pop_helper.popItemObject.settingItemClicked(index, true);

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
                    showPage("ChatAssistant");
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
        }
    }
}
