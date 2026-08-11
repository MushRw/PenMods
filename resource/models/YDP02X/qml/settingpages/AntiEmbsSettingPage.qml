import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===AntiEmbsSettingPage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "防尴尬选项"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingSwitchItem {
                implicitHeight: 54
                title: "蓝牙断连时自动静音"
                switchOn: antiEmbs.autoMute
                interval: 0
                onTimerTriggered: {
                    antiEmbs.autoMute = switchOn
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "禁用自动发音/朗读"
                switchOn: antiEmbs.autoPronLocked
                interval: 0
                onTimerTriggered: {
                    antiEmbs.autoPronLocked = switchOn
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "按键小助手"
                visible: mod.trustedDevice
                switchOn: antiEmbs.fastHide
                interval: 0
                onTimerTriggered: {
                    antiEmbs.fastHide = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }

    }
}
