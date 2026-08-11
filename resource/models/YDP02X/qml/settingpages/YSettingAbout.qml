import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"
import "../"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingAbout.qml"
    property int clickCount: 0

    function showPage(page,needPasswd,scene) {
        id_page_pop_helper.popItem.show(page,needPasswd,scene)
    }

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.about

            YMouseArea {
                anchors.fill: parent

                onClicked: {
                    if (clickCount <= 0) {
                        id_click_count_timer.start()

                        console.log("ccccccccccccccccc",settingManager.sysDevName + "ii " +settingManager.sysRegionInfo)
                    }

                    clickCount++
                    if (clickCount >= 5) {
                        console.log("YSettingAbout.qml===uploadUserActionLog, cnt ", clickCount)
                        clickCount = 0
                        logManager.uploadUserActionLog()
                        id_click_count_timer.stop()
                    }
                }
                objectName: "YSettingAbout.qml_YMouseArea"
            }

            YTimer {
                id: id_click_count_timer
                interval: 2000
                objectName: "YSettingAbout.qml_id_click_count_timer"
                onTriggered: {
                    if (clickCount > 1) {
                        clickCount--
                    }

                    if (clickCount == 0) {
                        stop()
                    }
                }
            }
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutItem {
                title: YTranslateText.model
                value: settingManager.sysDevName //+ " " +settingManager.sysRegionInfo;
            }

            YSettingAboutItem {
                title: YTranslateText.version
                value: settingManager.sysVersion
            }

            YSettingAboutClickableItem {
                title: "PenMods"
                value: mod.version
                imageName: "settings/info_more_arrow"
                onClicked: {
                    showPage("AboutPenMods")
                }
            }

            YSettingAboutClickableItem {
                title: YTranslateText.memoryStorage
                value: settingManager.memoryStorage + "GB"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    settingManager.updateSystemInfo()
                    showPage("YSettingStorageInfo")
                }
            }

            YSettingAboutItem {
                title: YTranslateText.sysSn
                titleItem.anchors.right: undefined
                titleItem.anchors.rightMargin: undefined
                value: settingManager.sysSn
            }

            // YSettingAboutItem {
            //     title: YTranslateText.macAddress
            //     titleItem.anchors.right: undefined
            //     titleItem.anchors.rightMargin: undefined
            //     value: settingManager.sysMac
            // }

            YSettingAboutClickableItem {
                title: "开发者选项"
                value: ""
                imageName: "settings/info_more_arrow"
                onClicked: {
                    showPage("DeveloperSettingPage",true,'dev_setting')
                }
            }

            /*YSettingAboutItem {
                visible: !qmlGlobal.checkFeature(YEnum.FEATURE_SKU_KO)
                         && !qmlGlobal.checkFeature(YEnum.FEATURE_SKU_EN)
                title: YTranslateText.serviceHotline
                value: qmlGlobal.checkFeature(YEnum.FEATURE_SKU_TW)
                       ? "0800-000150" : "400-800-4163"
            }*/

            YSettingAboutClickableItem {
                title: YTranslateText.certification
                value: ""
                imageName: "settings/info_more_arrow"
                onClicked: {
                    showPage("YSettingCertification")
                }
            }

            YSettingAboutClickableItem {
                title: YTranslateText.resetChoice
                value: ""
                imageName: "settings/info_more_arrow"
                onClicked: {
                    showPage("YSettingReset",true,"reset_page")
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }
    }

    function requestKeyboard(page) {
        let component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        id_page_pop_helper.inputPageCreated(incubator.object,page)
                    }
                }
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object,page)
            }
        }
    }

    YPagePopHelper {
        id: id_page_pop_helper
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_PagePopHelper.qml"
        readonly property alias popItem: id_pop_container

        // ==== KeyBoard ====

        function inputPageCreated(keyboardPage,page) {
            keyboardPage.backButtonClicked.connect(function(){
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null
            })
            keyboardPage.inputFinished.connect(function(content){
                if (content === locker.password) {
                    showPage(page)
                } else {
                    qmlGlobal.showToast("密码错误，请重试",YColors.yellow)
                    requestKeyboard(page)
                }
            })
            keyboardPage.placeHolderText = "请输入密码..."
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }

        // ==== PopHelper ====

        YDynamicPageStack {
            id: id_pop_container
            anchors.fill: parent
            logTag: "YSettingAbout"

            function show(page,needPasswd,scene) {
                if (needPasswd
                        && locker.enabled
                        && !(scene && !locker.getScene(scene))) {
                    requestKeyboard(page)
                    return
                }
                _show(page)
            }

            function _show(aboutPage) {
                createPage(Qt.resolvedUrl(("./%1.qml").arg(aboutPage)), aboutPage, {
                    "pageIndex": YEnum.PageIndex.Setting,
                    "closeOnHomeRelease": true,
                    "closeOnHomeLongPress": true
                })
            }
        }

    }
}
