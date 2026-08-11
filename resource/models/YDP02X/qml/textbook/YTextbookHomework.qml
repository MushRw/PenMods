import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

Item {
    id: id_textbook_homework
    objectName: "YTextbookHomework.qml"
    anchors.fill: parent

    signal backButtonClicked()

    property bool tabTypeIsHistory: false

    YVerticalTitleBar {
        onCallBack: {
            id_homework_page_switch_loader.active = false
            textBookTaskManager.wipeData()
            id_textbook_page.subPageCallBack()
            backButtonClicked()
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
            imageName: "textbook/switch"
            onClicked: {
                logManager.sendHttpLog("action=textbook_change_click")
                showSubPage(YEnum.Textbook_MyTextbook, true)
            }
        }
    }

    YLoader {
        id: id_homework_page_switch_loader
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        active: true
        asynchronous: false

        function checkEmpty() {
            if (isLoaded) {
                item.delayCheckEmptyTimer.recheck()
                textBookTaskManager.entryTask(tabTypeIsHistory)
            }
        }

        onLoaded: {
            checkEmpty()
        }

        sourceComponent: id_content_component

        Component {
            id: id_content_component
            YBackgroundIgnoreMouseEvent {

                readonly property bool wordsListEmpty: (0 === id_homework_switch_listview.count)

                readonly property alias delayCheckEmptyTimer: id_delay_check_empty_timer

                function showFilter() {
                    id_homework_switch_drawer_layer.show()
                }

                YBaseListView {
                    id: id_homework_switch_listview
                    anchors.fill: parent


                    model: textBookTaskManager
                    spacing: 8

                    onMovingChanged: {
                        if (!moving && atYEnd && textBookTaskManager.hasMore) {
                            textBookTaskManager.loadMore()
                        }
                    }

                    delegate: id_normal_delegate
                    header: id_header

                    footer: (textBookTaskManager.itemCount > 0 && textBookTaskManager.hasMore)
                            ? id_listview_loading_footer : id_listview_loaded_footer

                    Component {
                        id: id_listview_loading_footer

                        YListViewLoadMoreFooter {}
                    }

                    Component {
                        id: id_listview_loaded_footer

                        YSpacing {
                            width: id_homework_switch_listview.width
                            implicitHeight: 12
                        }
                    }

                    Component.onCompleted: {
                        id_textbook_homework.backButtonClicked.connect(function(){
                            id_homework_switch_listview.header = null
                            id_header.destroy()
                            id_homework_switch_listview.model = null
                            id_normal_delegate.destroy()
                        })
                    }
                }

                Item {
                    id: id_empty_tip_item
                    anchors.top: parent.top
                    anchors.topMargin: 89
                    anchors.left: parent.left
                    anchors.leftMargin: 65
                    width: id_empty_tip_text.width
                    visible: false

                    YText {
                        id: id_empty_tip_text
                        height: 21
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: tabTypeIsHistory ? YTranslateText.textbookHomeworkHistoryEmptyTip
                                               : YTranslateText.textbookHomeworkCurrentEmptyTip
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    YTimer {
                        id: id_delay_check_empty_timer
                        interval: 1000

                        function recheck() {
                            id_empty_tip_item.visible = false
                            restart()
                        }

                        function reshow() {
                            id_empty_tip_item.visible = Qt.binding(function(){
                                return (0 === id_homework_switch_listview.count)
                            })
                        }

                        onTriggered: {
                            reshow()
                        }
                        objectName: "YTextbookHomework.qml_id_delay_check_empty_timer"
                    }
                }

                Component.onCompleted: {
                    id_delay_check_empty_timer.recheck()
                }

                Component {
                    id: id_normal_delegate
                    YMouseArea {
                        id: id_normal_delegate_item
                        width: ListView.view.width
                        height: 70
                        readonly property var taskEntity: model.modelData

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height
                            color: YColors.grayNormal
                            opacity: parent.pressed ? 0.6 : 1
                            radius: 12

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7

                                YTextMedium {
                                    id: id_item_title
                                    width: parent.width
                                    height: contentHeight
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    font.pixelSize: 16
                                    elide: YTextEnUs.ElideRight
                                    text: id_normal_delegate_item.taskEntity.title
                                }

                                Row {
                                    height: 20
                                    spacing: 6
                                    anchors.left: parent.left
                                    YImage {
                                        id: id_item_icon
                                        imageName: {
                                            switch(id_normal_delegate_item.taskEntity.type) {
                                            case YEnum.TTT_Listen:
                                                return "textbook/homework-listen"
                                            case YEnum.TTT_Follow:
                                            default:
                                                return "textbook/homework-follow"
                                            }
                                        }
                                        sourceSize: Qt.size(20, 20)
                                        visible: !id_item_upload_button.visible
                                    }

                                    YImage {
                                        id: id_item_upload_button
                                        sourceSize: Qt.size(20, 20)
                                        imageName: "textbook/homework-upload"
                                        visible: tabTypeIsHistory &&  (YEnum.TTT_Follow === id_normal_delegate_item.taskEntity.type)
                                                 && id_normal_delegate_item.taskEntity.solved && !id_normal_delegate_item.taskEntity.upload

                                    }

                                    YText {
                                        id: id_item_time
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: contentWidth
                                        height: contentHeight
                                        color: id_item_upload_button.visible ? YColors.blueText : YColors.grayText
                                        font.family: qmlGlobal.fontFamilyZhCn
                                        font.pixelSize: 14
                                        text: {
                                            if (tabTypeIsHistory) {
                                                switch(id_normal_delegate_item.taskEntity.type) {
                                                case YEnum.TTT_Follow:
                                                    return id_normal_delegate_item.taskEntity.solved ? (id_normal_delegate_item.taskEntity.upload ? YTranslateText.textbookTaskDone : YTranslateText.textbookTaskReupload) : YTranslateText.textbookTaskUndone
                                                case YEnum.TTT_Listen:
                                                default:
                                                    return id_normal_delegate_item.taskEntity.solved ? YTranslateText.textbookTaskDone : YTranslateText.textbookTaskUndone
                                                }
                                            } else {
                                                return id_normal_delegate_item.taskEntity.expirationString + YTranslateText.textbookTaskDeadline
                                            }
                                        }
                                    }

                                }
                            }
                        }

                        onClicked: {
                            if (!tabTypeIsHistory) {

                                id_homework_task_guide.taskId = id_normal_delegate_item.taskEntity.id
                                id_homework_task_guide.taskType = id_normal_delegate_item.taskEntity.type
                                if ((YEnum.TTT_Listen === id_normal_delegate_item.taskEntity.type) && settingManager.needShowListenTaskGuide) {
                                    id_homework_task_guide.visible = true
                                    settingManager.needShowListenTaskGuide = false
                                }
                                else if ((YEnum.TTT_Follow === id_normal_delegate_item.taskEntity.type) && settingManager.needShowFollowTaskGuide) {
                                    id_homework_task_guide.visible = true
                                    settingManager.needShowFollowTaskGuide = false
                                }
                                else {
                                    textBookTaskManager.clickMedia(id_normal_delegate_item.taskEntity.id)
                                }
                            }
                            else if (id_item_upload_button.visible){
                                id_textbook_submithomework_dialog.show()
                                textBookTaskManager.retryUploadOralAudios(id_normal_delegate_item.taskEntity.id)
                            }
                        }
                    }
                }

                Component {
                    id: id_header
                    Item {
                        id: id_title_bar
                        width: ListView.view.width
                        implicitHeight: 50

                        YTabsTitleBar {
                            id: id_tab_title_bar
                            anchors.top: id_title_bar.top
                            anchors.topMargin: 15
                            anchors.left: id_title_bar.left
                            anchors.leftMargin: 4
                            namesArray: [YTranslateText.textbookTOLearn, YTranslateText.textbookHistoryWork]

                            onCurrentIndexChanged: {
                                updateUI()
                                id_homework_page_switch_loader.checkEmpty()
                            }

                            function updateUI() {
                                if (currentIndex === 0) {
                                    tabTypeIsHistory = false
                                } else if (currentIndex === 1) {
                                    tabTypeIsHistory = true
                                } else {
                                    console.log("index not hold : ", currentIndex)
                                }
                            }

                            Component.onCompleted: {
                                updateUI()
                            }
                        }
                    }
                }

            }
        }
    }

    YTextBookTaskGuide {
        id: id_homework_task_guide
        visible: false
    }

    YTextbookSubmitHomeworkDialog {
        id: id_textbook_submithomework_dialog
        anchors.fill: parent
        onSubmitFinished: {
            id_textbook_submithomework_dialog.close()
        }
        onClosed: {
            id_textbook_submithomework_dialog.close()
        }

        Component.onCompleted: {
            id_textbook_submithomework_dialog.submitDoing = true
        }

        Connections {
            target: textBookTaskManager
            ignoreUnknownSignals: true
            onUploadOralAudioFinished: {
                console.log("YTextbookHomework.qml===onUploadOralAudioFinished", success, errMsg)
                if (success) {
                    id_textbook_submithomework_dialog.submitDoing = false
                    id_textbook_submithomework_dialog.submitDone = true
                }
                else {
                    id_textbook_submithomework_dialog.close()
                    qmlGlobal.showToast(errMsg.length > 0 ? errMsg: YTranslateText.textbookHomeworkOralNotExist, "#2D2E33")
                }
            }
        }
    }

}

