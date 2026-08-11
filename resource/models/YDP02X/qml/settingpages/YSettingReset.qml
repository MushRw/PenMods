import QtQuick 2.12

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingReset.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.resetChoice
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutClickableItem {
                title: "卸载 PenMods"
                onClicked: {
                    id_uninstall_penmods_dialog.show()
                }
            }

            YSettingAboutClickableItem {
                title: "切换到 " + mod.getOtherSlot()
                onClicked: {
                    id_change_slot_dialog.show()
                }
            }

            YSettingAboutClickableItem {
                title: YTranslateText.resetSettings
                onClicked: {
                    id_reset_settings.show()
                }
            }

            YSettingAboutClickableItem {
                title: YTranslateText.resetFactory
                onClicked: {
                    id_reset_factory.show()
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

    YOneButtonDialog {
        id: id_uninstall_penmods_dialog
        anchors.fill: parent
        tipItem.text: "反安装PenMods后，系统将软重启以应用更改"
        buttonItem.text: "确认卸载"
        onClicked: {
            mod.uninstall()
        }
    }

    YOneButtonDialog {
        id: id_change_slot_dialog
        anchors.fill: parent
        tipItem.text: "切换槽后，当前槽数据可能丢失\n这是一个未知的操作，若您不明白请勿确认"
        buttonItem.text: "确认切换"
        onClicked: {
            mod.changeSlot()
        }
    }

    YSettingResetSettingsReset {
        id: id_reset_settings
    }

    YSettingResetFactoryReset {
        id: id_reset_factory
    }
}
