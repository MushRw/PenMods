import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===LockSettingPage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "安全选项"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingSwitchItem {
                id: switch_locker
                implicitHeight: 52
                title: "启用密码锁"
                switchOn: locker.enabled
                interval: 0
                onTimerTriggered: {
                    locker.enabled = switchOn
                }
            }

            YSettingAboutClickableItem {
                title: "设置密码"
                visible: switch_locker.switchOn
                imageName: "settings/info_more_arrow"
                onClicked: {
                    requestKeyboard()
                }
            }

            YSettingAboutClickableItem {
                title: "配置密码使用场景"
                visible: switch_locker.switchOn
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show("LockSceneSettingPage")
                }
            }

            YSettingAboutClickableItem {
                title: "社会安全选项"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show("AntiEmbsSettingPage")
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }

    }

    YPagePopHelper {
        id: id_page_pop_helper
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_LockSettingPage.qml"

        function inputPageCreated(keyboardPage,pwd) {
            keyboardPage.backButtonClicked.connect(function(){
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null
            })
            keyboardPage.inputFinished.connect(function(content){
                if (pwd) {
                    if (pwd !== content) {
                        qmlGlobal.showToast("两次输入的密码不一致",YColors.yellow)
                    } else {
                        locker.password = content
                        qmlGlobal.showToast("密码已修改",YColors.grayNormal)
                    }

                } else if (content.length < 4) {
                    qmlGlobal.showToast("请设置4位以上的密码",YColors.yellow)
                    requestKeyboard()
                } else {
                    requestKeyboard(content)
                }
            })
            if (pwd) {
                keyboardPage.placeHolderText = "请重复一次密码"
            } else {
                keyboardPage.placeHolderText = "请设置密码，最少4位"
            }
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }
    }

    function requestKeyboard(pwd) {
        let component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        id_page_pop_helper.inputPageCreated(incubator.object,pwd)
                    }
                }
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object,pwd)
            }
        }
    }

    YDynamicPageStack {
        id: id_pop_container
        anchors.fill: parent
        logTag: "LockSettingPage"

        function show(page) {
            createPage(Qt.resolvedUrl(("./%1.qml").arg(page)), page, {
                "pageIndex": YEnum.PageIndex.Setting,
                "closeOnHomeRelease": true,
                "closeOnHomeLongPress": true
            })
        }
    }

}
