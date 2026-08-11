import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===LockSceneSettingPage.qml"
    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "请设置需要使用密码的场景"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingSwitchItem {
                id: switch_scene_restart
                implicitHeight: 52
                title: "设备重启后"
                switchOn: locker.getScene('restart')
                interval: 0
                visible: false // todo
                onTimerTriggered: {
                    locker.setScene('restart', switchOn)
                }
            }

            YSettingSwitchItem {
                implicitHeight: 52
                title: "点亮屏幕时"
                switchOn: locker.getScene('screen_on')
                interval: 0
                visible: false // todo
                onTimerTriggered: {
                    locker.setScene('screen_on', switchOn)
                }
            }

            YSettingSwitchItem {
                implicitHeight: 52
                title: "隐藏文件设置"
                switchOn: locker.getScene('filemanager')
                interval: 0
                onTimerTriggered: {
                    locker.setScene('filemanager', switchOn)
                }
            }

            YSettingSwitchItem {
                implicitHeight: 52
                title: "重置选项页面"
                switchOn: locker.getScene('reset_page')
                interval: 0
                onTimerTriggered: {
                    locker.setScene('reset_page', switchOn)
                }
            }

            YSettingSwitchItem {
                implicitHeight: 52
                title: "开发者选项页面"
                switchOn: locker.getScene('dev_setting')
                interval: 0
                onTimerTriggered: {
                    locker.setScene('dev_setting', switchOn)
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

}
