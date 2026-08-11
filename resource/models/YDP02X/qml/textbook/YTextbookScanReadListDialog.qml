import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YDialog {
    id: id_textbook_scan_read_list_dialog
    anchors.fill: parent

    property int currentIndex: -1
    property int currentPage: -1
    property int searchType: YEnum.ST_Page
    property string keyword: ""
    property string selectMode: "page"  // page、title、none
    property var itemPageMap: null

    function updateModel(keyword, searchType, list) {
        id_textbook_scan_tts_tip_timer.stop()

        id_textbook_scan_read_list_dialog.currentIndex = -1
        id_textbook_scan_read_list_dialog.searchType = searchType
        id_textbook_scan_read_list_dialog.keyword = keyword
        if (0 === list.length) {
            selectMode = "none"
            return
        }

        let pageList = []
        itemPageMap = {}
        list.forEach(item => {
                         if (!itemPageMap.hasOwnProperty(item.page)) {
                             itemPageMap[item.page] = []
                             pageList.push(item)
                         }

                         itemPageMap[item.page].push(item)
                     })

        selectMode = pageList.length > 1 ? "page" : "title"
        id_textbook_scan_read_list_gridview.model = pageList.length > 1 ? pageList : list
        if (1 === pageList.length) {
            currentPage = pageList[0].page
            itemPageMap = null
        }

        if (YEnum.ST_Page === searchType) {
            id_textbook_scan_tts_tip_timer.tip = YTranslateText.textbookHomeworkPageFormat.arg(currentPage)
            id_textbook_scan_tts_tip_timer.start()
        }
        else if (pageList.length > 1){
            id_textbook_scan_tts_tip_timer.tip = YTranslateText.textbookHomeworkPageTtsTip
            id_textbook_scan_tts_tip_timer.start()
        }

        console.log("YTextbookScanReadListDialog.qml===count:", selectMode, id_textbook_scan_read_list_gridview.model.length)
    }

    Item {
        anchors.fill: parent

        YTimer {
            id: id_textbook_scan_tts_tip_timer
            property string tip: ""
            repeat: false
            interval: 0
            objectName: "YTextbookPage.qml_id_textbook_scan_tts_tip_timer"
            onTriggered: {
                soundCenter.play(tip, "zh");
            }
        }

        YIconButton {
            id: id_close_button
            implicitWidth: 30
            implicitHeight: 30
            radius: height/2
            color: YColors.grayNormal
            mouseAreaMargins: -22
            imageName: "commons/close"
            sourceSize: Qt.size(24, 24)
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 8
            onClicked: {
                close()
                closed()
                textBookBlockManager.clearSearchInfo()
            }
        }

        GridView {
            id: id_textbook_scan_read_list_gridview
            anchors.fill: parent
            anchors.leftMargin: 50
            anchors.rightMargin: 10
            anchors.topMargin: 14
            cellWidth: 130
            cellHeight: YEnum.ST_Page === searchType || "title" === selectMode ? 66 : 58

            visible: selectMode !== "none"
            header:  {
                if (YEnum.ST_Page === searchType) {
                    return id_textbook_list_gridview_page_search_header
                } else {
                    return id_textbook_list_gridview_keyword_search_header
                }
            }
            delegate: Item {
                width: id_textbook_scan_read_list_gridview.cellWidth
                height: id_textbook_scan_read_list_gridview.cellHeight

                YButton{
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom

                    width: 124
                    height: YEnum.ST_Page === searchType || "title" === selectMode ? 58 : 50
                    radius: 40
                    pixelSize: YEnum.ST_Page === searchType || "title" === selectMode ? 17 : 18
                    color: currentIndex===index ? YColors.red : YColors.grayNormal
                    mouseAreaMargins: -4
                    textItem.width: YEnum.ST_Page === searchType || "title" === selectMode ? 112 : 100
                    textItem.textFormat: Text.PlainText
                    textItem.elide: Text.ElideRight
                    textItem.maximumLineCount: 2
                    textItem.horizontalAlignment: Text.AlignHCenter
                    textFamily: qmlGlobal.fontFamilyZhCn
                    textItem.wrapMode: YText.WordWrap
                    text: {
                        if ("page" === selectMode) {
                            return model.modelData.page > 0 ? YTranslateText.textbookHomeworkPageFormat.arg(model.modelData.page) : model.modelData.unitTitle
                        }
                        else {
                            let titleOriginal = model.modelData.title
                            let rstMatch = titleOriginal.match(/第.*?页[ _]{0,1}/)
                            if (rstMatch !== null && rstMatch.length > 0) {
                                return titleOriginal.substring(titleOriginal.indexOf(rstMatch[0]) + rstMatch[0].length)
                            }
                            return titleOriginal
                        }
                    }
                    onClicked: {
                        id_textbook_scan_tts_tip_timer.stop()
                        console.log("YTextbookScanReadListDialog.qml===model.modelData.page:", model.modelData.page)
                        currentIndex = index
                        console.log("YTextbookScanReadListDialog.qml===onClicked===blockId: ", model.modelData.blockId)
                        if (itemPageMap && itemPageMap[model.modelData.page].length > 1) {
                            updateModel(keyword, searchType, itemPageMap[model.modelData.page])
                        }
                        else {
                            textBookBlockManager.clickMedia(model.modelData.blockId, true)
                            if (YEnum.PLAYING !== mediaPlayerManager.playState) {
                                mediaPlayerManager.onClickedPlay()
                            }
                            //                        close()
                        }
                    }
                }
            }

            footer: YSpacing {
                implicitHeight: 20
            }

            Component {
                id:id_textbook_list_gridview_page_search_header
                Item {
                    width: id_textbook_scan_read_list_gridview.width
                    height: 44
                    YText {
                        font.pixelSize: 16
                        anchors.fill: parent
                        wrapMode: Text.WrapAnywhere
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.RichText
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: YTranslateText.textbookHomeworkScanReadListTip.arg(currentPage).arg(YColors.grayText)
                    }
                }
            }

            Component {
                id:id_textbook_list_gridview_keyword_search_header
                Item {
                    width: id_textbook_scan_read_list_gridview.width
                    height: id_keyword_header_column.height
                    Column {
                        id: id_keyword_header_column
                        spacing: 2
                        width: parent.width
                        YText {
                            font.pixelSize: 16
                            width: parent.width
                            height: 22
                            visible: text.length > 0
                            verticalAlignment: Text.AlignVCenter
                            color: YColors.white
                            elide: YTextBase.ElideRight
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: keyword
                        }

                        YText {
                            width: parent.width
                            font.pixelSize: 16
                            height: 44
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAnywhere
                            color: YColors.grayText
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: "title" === selectMode? YTranslateText.textbookHomeworkPageKeywordTip.arg(currentPage): YTranslateText.textbookHomeworkPageTip
                        }
                    }
                }
            }
        }


        Item {
            id: id_no_result_page
            anchors.fill: parent
            anchors.leftMargin: 54
            visible: selectMode === "none"

            YText {
                id: id_no_result_page_header
                anchors {left: parent.left; top: parent.top; topMargin: 14}
                font.pixelSize: 16
                width: parent.width
                height: 22
                visible: text.length > 0
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                color: YColors.white
                elide: YTextBase.ElideRight
                font.family: qmlGlobal.fontFamilyZhCn
                text: keyword
            }

            YTextMedium {
                anchors {top: id_no_result_page_header.bottom; topMargin: 44}
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 16
                width: 250
                visible: text.length > 0
                verticalAlignment : Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: YColors.grayText
                wrapMode: Text.WrapAnywhere
                font.family: qmlGlobal.fontFamilyZhCn
                text: YTranslateText.textbookBlocksSearchNotFound
            }
        }

    }

    Component.onCompleted: {
        console.log("YTextbookScanReadListDialog.qml===Component.onCompleted===called")
    }

    Component.onDestruction: {
        console.log("YTextbookScanReadListDialog.qml===Component.onDestruction===called")
    }

    onVisibleChanged: {
        console.log("YTextbookScanReadListDialog.qml===onClosed===called")
        if (!visible) {
            id_textbook_scan_read_list_gridview.model = null
            itemPageMap = null
            currentIndex = -1
            id_textbook_scan_tts_tip_timer.stop()
        }
    }
}

