import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===AutoSuspendSetting.qml"
    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "请调节自动休眠触发时长"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            Repeater {
                id: rep
                model: ListModel {
                    ListElement {t: "5 分钟"}
                    ListElement {t: "10 分钟"}
                    ListElement {t: "20 分钟"}
                    ListElement {t: "40 分钟"}
                    ListElement {t: "永不"}
                }

                YSettingAboutClickableItem {
                    title: t
                    imageName: batteryInfo.autoSuspendDuration == title ? 'settings/st-check' : ''
                    opacityChangableWhenPressed: false
                    onClicked: {
                        batteryInfo.autoSuspendDuration = title
                    }
                }

            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

}
