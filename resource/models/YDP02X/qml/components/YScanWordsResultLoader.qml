import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

/*
    显示查词的空结果和正在扫描的结果
*/

YLoader {
    id: id_scan_result_loader
    anchors.fill: parent

    property bool isVerifiyFinished: false
    property int scanWordType: 1
    property int showIndex: 0
    property bool searchTimerIsRun: false

    function showEmpty() {
        id_search_timer.stop()
        qmlGlobal.requestShowScanGuide()
        hidden()
    }

    function showEmptyAndToast() {
        if (!isOidScanning) {
            soundCenter.stop()
            showEmpty()
            qmlGlobal.showToast(YTranslateText.cannotFindContentTryAgain, "#2D2E33")
            qmlGlobal.hideDictPage()
        }
    }

    function startOcrFunction(isStartOid = false) {
        ocrStart(isStartOid)
        if (!isStartOid) {
            show()
        } else {
//            qmlGlobal.hideDictPage()
        }
    }

    function hidden() {
        if (active) {
            active = false
        }
    }

    function show() {
        if (!active) {
            active = true
        }
    }

    signal ocrStart(bool isStartOid)

    sourceComponent: id_ocr_scan_word_result_component

    Component {
        id: id_ocr_scan_word_result_component
        YBackgroundIgnoreMouseEvent {
            Flickable {
                anchors.fill: parent
                contentHeight: id_scan_result_appand_area.contentHeight
                contentY: Math.max(0, id_scan_result_appand_area.contentHeight - 156)
                Row {
                    id: id_row
                    height: parent.height

                    YBackButton {
                        id: id_result_empty_back_button
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 10
                        isPositionLeftBar: true
                        onClicked: {
                            hidden()
                        }
                    }

                    YSpacing {
                        implicitWidth: 0
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                    }

                    TextEdit {
                        id: id_scan_result_appand_area
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 12
                        width: 256
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        color: YColors.grayText
                        font.pixelSize: 20
                        font.family: {
                            switch (qmlTranslator.getCharType(systemBase.ocrCompletedResult)) {
                            case YEnum.CT_ENG:
                                return qmlGlobal.fontFamilyEnUs
                            case YEnum.CT_JP:
                                return qmlGlobal.fontFamilyJaJp
                            case YEnum.CT_KO:
                                return qmlGlobal.fontFamilyKoKr
                            default:
                                return qmlGlobal.fontFamilyZhCn
                            }
                        }
                        onTextChanged: {
                            if (resultManager.itemCount && active) {
                                resultManager.resetStatus()
                                soundCenter.stop()
                            }
                        }
                        //font.weight: Font.Bold
                        cursorPosition: text.length
                        cursorDelegate: Rectangle {
                            id: id_cursor_context
                            width: 2
                            height: 20
                            opacity: 0
                            color: YColors.red
                            SequentialAnimation {
                                running: id_scan_result_appand_area.activeFocus
                                loops: SequentialAnimation.Infinite
                                ScriptAction { script: id_cursor_context.opacity = 1 }
                                PauseAnimation { duration: 600 }
                                ScriptAction { script: id_cursor_context.opacity = 0 }
                                PauseAnimation { duration: 600 }
                            }
                        }
                        YMouseArea {
                            anchors.fill: parent
                            objectName: "YScanWordsResultLoader.qml_id_scan_result_appand_area"
                        }
                        Connections {
                            target: id_scan_result_loader
                            ignoreUnknownSignals: true
                            enabled: isVerifiyFinished
                            function onLoaded() {
                                id_scan_result_appand_area.forceActiveFocus()
                            }
                        }
                        YTimer {
                            id: id_show_timer
                            interval: 12
                            repeat: true
                            onTriggered: {
                                showIndex++
                                if (searchTimerIsRun) {
                                    if (systemBase.isButtonRelease)
                                        id_search_timer.restart()
                                    else
                                        id_search_timer.stop()
                                }
                                id_scan_result_appand_area.text = systemBase.ocrCompletedResult.substring(0,showIndex)
                                soundCenter.stop()
                                showDictPage(systemBase.ocrCompletedResult.substring(0,showIndex))
                                if (showIndex > systemBase.ocrCompletedResult.length) {
                                    stop()
                                }
                            }
                        }
                        Connections {
                            target: systemBase
                            ignoreUnknownSignals: true
                            enabled: isVerifiyFinished
                            function onOcrCompletedResultChanged() {
                                console.log("************onOcrCompletedResultChanged enter")
                                if (showIndex > systemBase.ocrCompletedResult.length) {
                                    showIndex = systemBase.ocrCompletedResult.length
                                }
                                if (systemBase.ocrCompletedResult.length >= showIndex || !systemBase.isButtonRelease) {
                                    id_show_timer.start()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    property bool isOidScanning: false
    property bool isReStartOid: true

    Connections {
        target: resultManager
        ignoreUnknownSignals: true
        enabled: isVerifiyFinished
        function onNoResultSignal() {
            if (!isOidScanning) {
                showEmptyAndToast()
            }
        }
    }

    function showDictPage(content){
        if(content.length && qmlGlobal.currentPageIndex !== YEnum.PageIndex.TextBook && qmlGlobal.currentPageIndex !== YEnum.PageIndex.Math &&
                qmlGlobal.currentPageIndex !== YEnum.PageIndex.Audioplayer)
        {
            let pageIndex = qmlGlobal.currentPageIndex === YEnum.PageIndex.Fav ? YEnum.PageIndex.Fav
                                                                               : YEnum.PageIndex.NonePage
            qmlGlobal.showDictPage(pageIndex,content)
            resultManager.isReportButtonVisible = true
            visible = false
            //hidden()
        } else if (qmlGlobal.currentPageIndex === YEnum.PageIndex.TextBook
                   || qmlGlobal.currentPageIndex === YEnum.PageIndex.Math
                   || qmlGlobal.currentPageIndex === YEnum.PageIndex.Audioplayer) {
            visible = true
        }
    }

    function searchWord(){
        if (resultManager.entryResult(systemBase.ocrCompletedResult, "", "", YEnum.PageIndex.Dict, scanWordType)) {
            if (active) {
                let pageIndex = qmlGlobal.currentPageIndex === YEnum.PageIndex.Fav ? YEnum.PageIndex.Fav
                                                                                   : YEnum.PageIndex.NonePage
                qmlGlobal.showDictPage(pageIndex)
                resultManager.isReportButtonVisible = true
                hidden()
            }
        } else {
            qmlGlobal.canAutoAddToWb = false
            showEmptyAndToast()
        }
    }

    YTimer {
        id: id_search_timer
        interval: 680
        property int timerCount: 0
        onTriggered: {
            searchTimerIsRun = false
            if (active) searchWord()
        }
    }

    YTimer {
        id:id_start_delay_hide_dict
        repeat: false
        interval: 500
        onTriggered: {
            if(isOidScanning) {
                 qmlGlobal.hideDictPage()
            }
        }
    }

    YTimer {
        id:id_start_delay_hide
        repeat: false
        interval: 500
        onTriggered: {
            if(isOidScanning) {
                 hidden()
            }
        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        enabled: isVerifiyFinished
        function onIsOidStart(isOid) {
            if (qmlGlobal.inputPageShowing) {
                return
            }
            console.warn("YScanWordsResultLoader.qml====IsOidStart: ", isOid)
            resultManager.resetStatus()
            isOidScanning = isOid
            show()
            ocrStart(isOid);
//            startOcrFunction(isOid)
//            if (isOidScanning) {
//                hidden()
//            }
        }
        function onOidStop(bSuccess) {
            console.warn("YScanWordsResultLoader.qml====oid_stop bSuccess: ", bSuccess)
            isReStartOid = bSuccess
            if (!bSuccess) {
                id_start_delay_hide_dict.stop()
                id_start_delay_hide.stop()
                isOidScanning = false // continue scan words function
                startOcrFunction(isOidScanning)
                resultManager.resetStatus()
            } else {
                id_start_delay_hide_dict.interval = 0
                id_start_delay_hide_dict.restart()
                hidden()
            }
        }

        function onHideScanWordResult() {
            console.warn("YScanWordsResultLoader.qml====onHideScanWordResult")
            hidden()
        }

        function onOcrStart(){
            console.warn("YScanWordsResultLoader.qml====onOcrStart")
            //showDictPage("isOcrStart")
            //resultManager.isReturnSearch = false
            searchTimerIsRun = false
            soundCenter.stop()
            id_search_timer.stop()
        }

        function onOcrStop(scanType) {
            console.warn("YScanWordsResultLoader.qml====ocr_stop scanType: ", scanType)
            logManager.sendHttpLog(scanType ? "action=scansearch_click" : "action=pointscan_click")
            qmlGlobal.canAutoAddToWb = true
            id_start_delay_hide_dict.stop()
            scanWordType = scanType
            if ((systemBase.ocrCompletedResult.length === 0)) {
                qmlGlobal.canAutoAddToWb = false
                showEmptyAndToast()
            } else {
                if (settingManager.isContinueScan && scanType !== 0 ) {
                    searchTimerIsRun = true
                    id_search_timer.restart()
                } else {
                    searchWord()
                }
            }
        }

        function onHomeKeyRelease() {
            console.log("YScanWordsResultLoader.qml===onHomeKeyRelease===")
            isOidScanning = false
        }
    }
}
