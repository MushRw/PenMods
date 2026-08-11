import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===SSHManagePage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "SSH 服务管理"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutClickableItem {
                id: run_stat
                title: "运行状态"
                iconComponent.source: serviceManager.sshStatus ? res.get("color-success") : res.get("color-notice")
                onClicked: {
                    if (serviceManager.sshStatus) {
                        serviceManager.stopSsh()
                    } else {
                        serviceManager.startSsh()
                    }
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "开机自启动"
                switchOn: serviceManager.sshAutoRun
                interval: 0
                onTimerTriggered: {
                    serviceManager.sshAutoRun = switchOn
                }
            }

            YSettingAboutClickableItem {
                title: "重置 root 账户密码"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    requestKeyboard()
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
        objectName: "from_SSHManagePage.qml"

        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function(){
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null
            })
            keyboardPage.inputFinished.connect(function(content){
                serviceManager.setSshRootPasswd(content)
            })
            keyboardPage.placeHolderText = "请设置密码..."
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }
    }

    function requestKeyboard() {
        let component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        id_page_pop_helper.inputPageCreated(incubator.object)
                    }
                }
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object)
            }
        }
    }

}
