import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===ADBManagePage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "ADB 服务管理"
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
                iconComponent.source: serviceManager.adbStatus ? res.get("color-success") : res.get("color-notice")
                onClicked: {
                    if (serviceManager.adbStatus) {
                        serviceManager.stopAdb()
                    } else {
                        serviceManager.startAdb()
                    }
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "开机自启动"
                switchOn: serviceManager.adbAutoRun
                interval: 0
                onTimerTriggered: {
                    serviceManager.adbAutoRun = switchOn
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "跳过密码验证"
                switchOn: serviceManager.skipAdbVerification
                interval: 0
                onTimerTriggered: {
                    serviceManager.skipAdbVerification = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

}
