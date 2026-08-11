import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YBackground {
    id: id_drawer_layer
    anchors.fill: parent
    visible: false

    property int currentIndex: settingManager.wbLanguageFilter
    signal filterChanged(int langType)

    property bool currentFilterWordsList: true

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            hide()
        }
    }

    Flickable {
        id: id_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height

        Column {
            id: id_column
            width: parent.width
            YSpacingForColumn {
                implicitHeight: 16
            }

            YTextBase {
                id: id_title
                color: YColors.grayText
                font.pixelSize: 16
                text: YTranslateText.switchLanguage
                visible: currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: currentFilterWordsList
            }

            Grid {
                anchors.left: parent.left
                anchors.right: parent.right
                visible: currentFilterWordsList
                columns: 2
                rowSpacing: 8
                columnSpacing: 6

                Repeater {
                    model: id_filter_model
                    YButton {
                        implicitWidth: {
                            switch(settingManager.uiLanguage){
                                // todo other language
                            case YEnum.ZH_CN:
                            default:
                                return 125
                            }
                        }
                        color: langType === currentIndex ? YColors.red : "#2D2E33"
                        mouseAreaMargins: -4
                        text: {
                            switch (langType) {
                            case YEnum.ZH_CN:
                                return YTranslateText.chinese
                            case YEnum.EN_US:
                                return YTranslateText.english
                            case YEnum.JA_JP:
                                return YTranslateText.japanese
                            case YEnum.KO_KR:
                                return YTranslateText.korean
                            case YEnum.LT_NUM:
                            default:
                                return YTranslateText.all
                            }
                        }

                        onClicked: {
                            if (currentIndex !== langType) {
                                currentIndex = langType
                                filterChanged(currentIndex)
                                hide()
                            }
                        }
                    }
                }
            }

            YTextBase {
                id: id_setting
                color: YColors.grayText
                font.pixelSize: 16
                anchors.left: parent.left
                text: YTranslateText.playSettings
                visible: !currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: !currentFilterWordsList
            }

            YSettingSwitchItem {
                color: "#2D2E33"
                switchItem.offColor: "#515259"
                title: YTranslateText.autoReadAloud
                switchOn: settingManager.isWbAutoPronounce
                onTimerTriggered: {
                    if (antiEmbs.autoPronLocked) {
                        qmlGlobal.showToast("自动发音已被其他设置项关闭", YColors.yellow)
                        switchOn = false
                    }
                    settingManager.isWbAutoPronounce = switchOn
                }
                visible: !currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 8
                visible: !currentFilterWordsList
            }

            YSettingSwitchItem {
                color: "#2D2E33"
                switchItem.offColor: "#515259"
                title: YTranslateText.autoPlay
                switchOn: settingManager.isWbAutoPlay
                onTimerTriggered: {
                    settingManager.isWbAutoPlay = switchOn
                }
                visible: !currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 18
                visible: currentFilterWordsList
            }

            YTextBase {
                id: id_autoAddWb
                color: YColors.grayText
                font.pixelSize: 16
                anchors.left: parent.left
                text: YTranslateText.addWbSetting
                visible: currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: currentFilterWordsList
            }

            YSettingSwitchItem {
                color: "#2D2E33"
                switchItem.offColor: "#515259"
                title: YTranslateText.autoCollectAfterScan
                switchOn: settingManager.isAutoAddWb
                onTimerTriggered: {
                    settingManager.isAutoAddWb = switchOn
                    if (switchOn){
                        logManager.sendHttpLog("action=wordbook_scan_on_click")
                    } else {
                        logManager.sendHttpLog("action=wordbook_scan_off_click")
                    }
                }
                visible: currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 8
                visible: currentFilterWordsList
            }

            YSettingSwitchItem {
                color: "#2D2E33"
                switchItem.offColor: "#515259"
                visible: currentFilterWordsList
                implicitHeight: 54
                title: '添加 "词组" 选项卡'
                switchOn: workBookTweaks.phraseTab
                interval: 0
                onTimerTriggered: {
                    workBookTweaks.phraseTab = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 8
                visible: currentFilterWordsList
            }

            YSettingSwitchItem {
                color: "#2D2E33"
                switchItem.offColor: "#515259"
                visible: currentFilterWordsList
                implicitHeight: 54
                title: "单词间大小写不敏感"
                switchOn: workBookTweaks.noCaseSensitive
                interval: 0
                onTimerTriggered: {
                    workBookTweaks.noCaseSensitive = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 18
                visible: currentFilterWordsList
            }

            YTextBase {
                id: id_exportNow
                color: YColors.grayText
                font.pixelSize: 16
                anchors.left: parent.left
                text: "数据导出"
                visible: currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: currentFilterWordsList
            }

            YSettingAboutClickableItem {
                color: "#2D2E33"
                title: "基本词典释义数据"
                enabled: !workBookTweaks.exporting
                visible: currentFilterWordsList
                iconComponent.visible: !workBookTweaks.exporting
                imageName: "settings/info_more_arrow"

                YCircularProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    visible: workBookTweaks.exporting
                    progressValue: workBookTweaks.exportProgress
                }

                onClicked: workBookTweaks.doExport()
            }

            YSpacingForColumn {
                implicitHeight: 18
                visible: currentFilterWordsList
            }

            YTextBase {
                id: id_sync
                color: YColors.grayText
                font.pixelSize: 16
                anchors.left: parent.left
                text: YTranslateText.wordbookSyncTime
                visible: currentFilterWordsList
            }

            YSpacingForColumn {
                implicitHeight: 10
                visible: currentFilterWordsList
            }

            YSettingItemBackground {
                enabled: YEnum.SYS_SYNCING !== wordBookManager.syncState
                color: "#2D2E33"
                opacity: id_sync_button.pressed || !enabled ? 0.6 : 1
                visible: currentFilterWordsList
                YTextMedium {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    font.family: wordBookManager.lastSyncTime <= 0 ?
                                     qmlGlobal.fontFamily : qmlGlobal.fontFamilyEnUs
                    text: {
                        console.log("YWordBookFilterDrawerLayer.qml====wordBookManager.lastSyncTime: ",
                                    wordBookManager.lastSyncTime)
                        if (wordBookManager.lastSyncTime <= 0) {
                            return YTranslateText.clickToSync
                        }
                        return Qt.formatDateTime(new Date(wordBookManager.lastSyncTime),
                                                 "yyyy.MM.dd   hh:mm")
                    }
                }

                YImage {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(24, 24)
                    imageName: {
                        switch(wordBookManager.syncState) {
                        case YEnum.SYS_SYNCED:
                            return "wordbook/wb-synced"
                        case YEnum.SYS_SYNCING:
                            return "wordbook/wb-syncing"
                        case YEnum.SYS_UNSYNCED:
                        default:
                            return "wordbook/wb-unsync"
                        }
                    }
                }

                YMouseArea {
                    id: id_sync_button
                    anchors.fill: parent
                    onClicked : {
                        if (wifiManager.isOnline()) {
                            if (loginManager.isLogin) {
                                wordBookManager.startSync()
                            } else {
                                qmlGlobal.showToast(YTranslateText.accountHasUnbundling, YColors.grayNormal)
                            }
                        } else {
                            qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                        }
                    }
                    objectName: "YWordBookFilterDrawerLayer.qml_YMouseArea"
                }
            }

            YSpacingForColumn {
                implicitHeight: 28
            }
        }
    }

    ListModel {
        id: id_filter_model

        Component.onCompleted: {
            append({langType: YEnum.LT_NUM})
            append({langType: YEnum.ZH_CN})
            append({langType: YEnum.EN_US})
            if (qmlGlobal.checkFeature(YEnum.FEATURE_KOJN)) {
                append({langType: YEnum.JA_JP})
                append({langType: YEnum.KO_KR})
            }
        }
    }
}
