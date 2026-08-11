import QtQuick 2.12
import com.youdao.pen 1.0
import QtGraphicalEffects 1.14

import "../commons"
import "../i18n"

Item {
    id: id_textbook_home_item
    objectName: "YTextbookHome.qml"
    anchors.fill: parent
    property string bookId: settingManager.studyingBookId
    property int exerciseCount: textBookTaskManager.taskTipCount

    function show(){
        id_textbook_home_item.visible = true
    }

    function hidden(){
        id_textbook_home_item.visible = false
    }

    function textbookHomeMenuClicked(index) {
        console.warn("YTextbookHome.qml===textbookHomeMenuClicked===index: ", index)
        let component = null
        switch (index) {
        case YEnum.TextbookHomePageIndex.TextbookHome_Audio:
            logManager.sendHttpLog("action=textbook_listening_click")
            showSubPage(YEnum.Textbook_ListenToAudio, true)
            break
        case YEnum.TextbookHomePageIndex.TextbookHome_Bookmark:
            logManager.sendHttpLog("textbook_collection_click")
            showSubPage(YEnum.Textbook_Favorites, true)
            break
        case YEnum.TextbookHomePageIndex.TextbookHome_Exercisebook:
            showSubPage(YEnum.Textbook_Homework, true)
            break
        }
    }

    Item {
        id: id_textbook_home_list_view_container
        anchors.fill: parent
        anchors.topMargin: 45
        anchors.bottomMargin: 45
        anchors.leftMargin: 54

        YHorizontalListView {
            id: id_textbook_home_list_view
            model: mainMenuModel
            spacing: 12
            anchors.fill: parent
            rightMargin: 24

            header: id_header_component

            Component{
                id: id_header_component
                Column {
                    id: id_textbook_home_column
                    spacing: 8
                    width: 223
                    Row {
                        width: parent.width
                        height: 26
                        rightPadding: 16
                        spacing: 6
                        YText {
                            id: id_result_study_tip
                            font.pixelSize: 18
                            width: 180
                            textFormat: YTextMedium.RichText
                            lineHeight: parent.height
                            lineHeightMode: YTextMedium.FixedHeight
                            wrapMode: YTextBase.Wrap
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: YTranslateText.textbookHomeTip.arg(YColors.red)
                        }

                        YIconButton {
                            implicitWidth: 22
                            implicitHeight: 22
                            id: id_result_study_tip_help
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height/2
                            color: YColors.grayNormal
                            sourceSize: Qt.size(22, 22)
                            opacity: id_result_study_tip_help.pressed ? 0.6 : 1
                            imageName: "textbook/help"
                            mouseAreaMargins: -5
                            onClicked: {
                                id_scan_read_guide.visible = true
                            }
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        width: 185
                        implicitHeight: 36
                        YTextBase {
                            id: id_result_study_publisher
                            font.pixelSize: 15
                            anchors.left: parent.left
                            color: YColors.grayText
                            width: parent.width
                            lineHeight: 20
                            lineHeightMode: YTextMedium.FixedHeight
                            wrapMode: YTextBase.Wrap
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: settingManager.studyingBookPublisher
                        }
                        YTextBase {
                            id: id_result_study_title
                            font.pixelSize: 15
                            anchors{left: parent.left; top: id_result_study_publisher.bottom; topMargin: 4}
                            color: YColors.grayText
                            width: parent.width
                            lineHeight: 20
                            lineHeightMode: YTextMedium.FixedHeight
                            wrapMode: YTextBase.Wrap
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: settingManager.studyingBookTitle
                        }
                    }

                }// Column
            }

            delegate: Item {
                id: id_item_delegate
                width: 110
                height: 80
                anchors.verticalCenter: parent.verticalCenter

                YButtonBase {
                    id: id_textbook_home_menu_button
                    width: parent.width
                    height: parent.height
                    radius: 12
                    antialiasing: true
                    opacity: id_textbook_home_button.pressed ? 0.6 : 1

                    YTextMedium {
                        id: id_textbook_home_menu_text
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        textFormat: YTextBase.RichText
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: qmlGlobal.fontFamilyZhCn
                        text: {
                            switch (pageIndex) {
                            case YEnum.TextbookHomePageIndex.TextbookHome_Audio:
                                return YTranslateText.textbookListenToAudio
                            case YEnum.TextbookHomePageIndex.TextbookHome_Bookmark:
                                return YTranslateText.textbookBookmark
                            case YEnum.TextbookHomePageIndex.TextbookHome_Exercisebook:
                                return YTranslateText.textbookExercisebook
                            default:
                                return ""
                            }
                        }
                    }

                    YImage {
                        id: id_textbook_home_menu_icon
                        anchors.left: id_textbook_home_menu_text.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        sourceSize: Qt.size(20, 20)
                        imageName: iconFg
                        visible: !id_textbook_home_exercise_count.visible
                    }

                    YRectangle {
                        id: id_textbook_home_exercise_count
                        anchors.left: id_textbook_home_menu_text.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4 + (id_textbook_home_exercise_count_text.width > 14
                                     ? id_textbook_home_exercise_count_text.width : 14)
                        height: 28
                        color: YColors.red
                        radius: height * 0.5
                        visible: YEnum.TextbookHomePageIndex.TextbookHome_Exercisebook === pageIndex && exerciseCount > 0

                        YTextMedium {
                            id: id_textbook_home_exercise_count_text
                            width: contentWidth
                            height: 24
                            anchors.centerIn: parent
                            font.pixelSize: 18
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: exerciseCount
                        }
                    }

                    YMouseArea {
                        id: id_textbook_home_button
                        anchors.fill: parent
                        objectName: "YTextbookHome_id_textbook_home_list_view_pageIndex" + pageIndex
                        onClicked: {
                            if (pageIndex === YEnum.TextbookHomePageIndex.TextbookHome_Exercisebook) {
                                if (!wifiManager.internetConnect) {
                                    qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                    return
                                }
                                if (!loginManager.isLogin) {
                                    qmlGlobal.showToast(YTranslateText.accountHasUnbundling, YColors.grayNormal)
                                    return
                                }
                            }
                            textbookHomeMenuClicked(pageIndex)
                        }
                    }
                }
            }

            ListModel {
                id: mainMenuModel
                Component.onCompleted: {
                    append({iconMain: "textbook/guid-listen", iconFg: "textbook/enter-icon", pageIndex: YEnum.TextbookHomePageIndex.TextbookHome_Audio})
                    append({iconMain: "textbook/collect", iconFg: "textbook/enter-icon", pageIndex: YEnum.TextbookHomePageIndex.TextbookHome_Bookmark})
                    if (settingManager.isJoinClass) {
                        append({iconMain: "textbook/homework", iconFg: "textbook/enter-icon", pageIndex: YEnum.TextbookHomePageIndex.TextbookHome_Exercisebook})
                    }
                }
            }
        }

    }

    Item {
        id: id_title_bar_holder
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitWidth: 54

        anchors.topMargin: 45
        anchors.bottomMargin:  45

        ShaderEffectSource {
            id: id_effect_source
            anchors.fill: parent
            sourceItem: id_textbook_home_list_view
            sourceRect: Qt.rect(x - 45, y, width, height)
            visible: false
        }

        FastBlur {
            anchors.fill: parent
            source: id_effect_source
            radius: 64
        }

        Rectangle {
            anchors.fill: parent
            color: "#4D000000"
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
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
    } // YVerticalTitleBar

    YTwoButtonDialog {
        id: id_tip_dialog
        anchors.fill: parent
        buttonItemConfirm.textFamily: qmlGlobal.fontFamilyZhCn
        buttonItemCancel.textFamily: qmlGlobal.fontFamilyZhCn
        tipItem.font.family: qmlGlobal.fontFamilyZhCn
        tipItem.text: YTranslateText.textbookContinueBoughtTip
        onClickedConfirm: {
            id_tip_dialog.close()
            // 设置教材对象
            id_textbook_page.selectTextbookObj =  textBookManager.getStudyingBook()
            id_textbook_page.isContinueBought = true
            showSubPage(YEnum.Textbook_Operation, true)
        }
        onClickedCancel: {
            id_tip_dialog.close()
        }
    }

    YTextBookScanReadGuide {
        id: id_scan_read_guide
        visible: false
    }

    Component.onCompleted: {
        console.warn("YTextbookHome.qml===Component.onCompleted")

        console.warn("YTextbookHome.qml===Component.onCompleted===settingManager.isFirstFollowScanRead:",settingManager.isFirstFollowScanRead)
        if(settingManager.isFirstFollowScanRead){
            settingManager.isFirstFollowScanRead = false
            showSubPage(YEnum.Textbook_ScanReadGuide, false)
        }
        textBookTaskManager.httpGetOwnerClassStatus()
        // 检查是否即将过期
        textBookManager.loadStudyingBook()
    }

    Connections {
        target: textBookManager
        ignoreUnknownSignals: true
        onIsNeedRenewTipChanged: {
            if (textBookManager.isNeedRenewTip) {
                id_tip_dialog.show()
            }
        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        onHideTestBookHome: {
            hidden()
            id_delay_timer.start()
        }
    }

    YTimer {
        id: id_delay_timer
        interval: 500
        objectName: "YTextbookHome.qml_id_delay_timer"
        onTriggered: {
            console.warn("YTextbookHome.qml===YTimer===show()")
            show()
        }
    }
}

