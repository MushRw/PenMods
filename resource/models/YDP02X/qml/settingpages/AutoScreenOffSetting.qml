import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===AutoScreenOffSetting.qml"
    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "在息屏前 10 秒，屏幕将自动变暗"
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
                    ListElement {t: "30 秒"}
                    ListElement {t: "1 分钟"}
                    ListElement {t: "2 分钟"}
                    ListElement {t: "3 分钟"}
                    ListElement {t: "4 分钟"}
                    ListElement {t: "5 分钟"}
                    ListElement {t: "永不"}
                }

                YSettingAboutClickableItem {
                    title: t
                    opacityChangableWhenPressed: false
                    imageName: screenManager.autoSleepDuration == title ? 'settings/st-check' : ''
                    onClicked: {
                        screenManager.autoSleepDuration = title
                    }
                }

            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

}
