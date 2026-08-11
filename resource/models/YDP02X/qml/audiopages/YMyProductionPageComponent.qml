import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YBackButtonAudioPage {
    id: id_container_index

    property bool isScanPage: true
    property string searchCode: ""

    function showKeyboard(keyBoardPage) {
        keyBoardPage.backButtonClicked.connect(function(){
            keyBoardPage.todoDestroy()
            qmlGlobal.inputPageShowing = false
            keyBoardPage = null
        })
        keyBoardPage.inputFinished.connect(function(pwd){
            id_container_index.searchCode = pwd.toUpperCase()
            if (pwd.length > 0) {
                logManager.sendHttpLog("action=listening_make_searchcode_click")
                columnManager.queryCourseByCode(pwd)
            }
        })
        keyBoardPage.visible = true
        qmlGlobal.inputPageShowing = true
    }

    function requestKeyboard() {
        const component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            let incubator = component.incubateObject(id_keyboard_container);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        console.log("Object", incubator.object, "is now ready!");
                        showKeyboard(incubator.object)
                    }
                }
            } else {
                console.log("Object", incubator.object, "is ready immediately!");
                showKeyboard(incubator.object)
            }
        }
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            if (id_youdao_audio_page_column_view.visible) {
                id_youdao_audio_page_column_view.close()
                return
            }

            backButtonClicked()
            columnManager.wipeData()
        }

        YIconButton {
            implicitWidth: 30
            implicitHeight: 30
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            radius: height/2
            sourceSize: Qt.size(24, 24)
            imageName: "audioplayer/search_hw"
            mouseAreaMargins: -10
            onClicked: {
                requestKeyboard()
            }
        }
    }


    YMyProductionPageComponentEmpty {
        anchors.fill: parent
        visible: columnManager.productionCount === 0
    }

    YBaseListView {
        id: id_my_production_result_list_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        anchors.topMargin: 12
        spacing: 8

        busyingInterval: 60
        onMovingChanged: {
            if (!moving && atYEnd && columnManager.hasMore) {
                columnManager.loadMore(true, columnManager.domainNameMyProduction)
            }
        } // todo 细化 loadMore 逻辑
        visible: !empty
        model: columnManager

//        header: YSpacing {
//            width: id_my_production_result_list_view.width
//            implicitHeight: 50
//            YTitle {
//                id: id_title
//                anchors.verticalCenter: parent.verticalCenter
//                text: YTranslateText.myProductionAudios
//            }
//        }

        delegate: Item {
            width: id_my_production_result_list_view.width
            implicitHeight: 50

            YMyProductionPageComponentViewItem {
                implicitHeight: parent.height
                title: (index + 1) + ". " + model.modelData.title
                titleFontFamily: qmlGlobal.fontFamilyZhCn
                value: ""
                isDefaultScan: model.modelData.columnId === settingManager.curScannigColumn

                onLeftClicked: {
                    console.log("YMyProductionPageComponent.qml===entryMyProduct")
                    id_youdao_audio_page_column_view.columnTitle = model.modelData.title
                    id_youdao_audio_page_column_view.currentDownloadState = YEnum.DS_SUCCEED
                    id_youdao_audio_page_column_view.model = mediaManager
                    mediaManager.entryColumn(model.modelData.columnId, true)
                    id_youdao_audio_page_column_view.show()
                }

                onRightClicked: {
                    console.log("YMyProductionPageComponent.qml===setDefaultScanning")
                    confirmDefaultLayer.columnId = model.modelData.columnId
                    confirmDefaultLayer.columnTitle = model.modelData.title
                    confirmDefaultLayer.show()
                }

            }
        }

        footer: (columnManager.itemCount > 0 && columnManager.hasMore)
                ? id_listview_loading_footer : null

        Component {
            id: id_listview_loading_footer

            YListViewLoadMoreFooter {}
        }
    }


    YYoudaoAudioPageColumnView {
        id: id_youdao_audio_page_column_view
        readonly property bool editing: false
    }

    YMyProductionPageComponentSearchResultView {
        id: id_search_result_view
        onSigJupToDtileList:{
            id_search_result_view.close()
            console.log("YMyProductionPageComponent.qml===entryMyProduct")
            id_youdao_audio_page_column_view.columnTitle = courseTitle
            id_youdao_audio_page_column_view.currentDownloadState = YEnum.DS_SUCCEED
            id_youdao_audio_page_column_view.model = mediaManager
            mediaManager.entryColumn(columnId, true)
            id_youdao_audio_page_column_view.show()
        }
    }

    Item {
        id: id_keyboard_container
        anchors.fill: parent
    }

    Connections {
        target: columnManager
        ignoreUnknownSignals: true
        enabled: id_container_index.visible

        onCourseCodeError: {
            console.warn("YMyProductionPageComponent.qml===onCourseCodeError ", errMsg)
            qmlGlobal.showToast(errMsg, YColors.grayNormal)
        }

        onCourseCodeResult: {
            console.log("YMyProductionPageComponent.qml===onCourseCodeResult ", columnId, title, downloadState)
            id_search_result_view.columnId = columnId
            id_search_result_view.searchCode = id_container_index.searchCode
            id_search_result_view.courseTitle = title
            id_search_result_view.downloadState = downloadState
            id_search_result_view.show()
        }

        onDownloadProgress: {
            if (columnId === id_container_index.searchCode) {
                console.log("YMyProductionPageComponent.qml===onDownloadProgress ", columnId, progress)
                if (progress < 0) {
                    id_search_result_view.downloadState = YEnum.DS_FAILURE
                    if (-progress === YEnum.DET_STORAGEINVALID) {
                        qmlGlobal.showToast(YTranslateText.downloadErrorStorageInvalid, YColors.yellow)
                    }
                }
                else if (progress >= 100) {
                    id_search_result_view.downloadState = YEnum.DS_SUCCEED
                    id_search_result_view.progress = progress
                }
                else {
                    id_search_result_view.downloadState = YEnum.DS_ING
                    id_search_result_view.progress = progress
                }
            }
        }
        onProductionCountChanged : {
            if (columnManager.productionCount > 0) {
                columnManager.wipeData()
                columnManager.loadMore(true, columnManager.domainNameMyProduction)
            }
        }
    }

    onBackButtonClicked: {
        columnManager.wipeData()
    }
}

