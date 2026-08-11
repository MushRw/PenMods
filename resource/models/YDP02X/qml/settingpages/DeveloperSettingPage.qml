import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===WordbookSettingPage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "开发者选项"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutClickableItem {
                title: "ADB 服务"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show("ADBManagePage")
                }
            }

            YSettingAboutClickableItem {
                title: "SSH 服务"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show("SSHManagePage")
                }
            }

            DescribedSwitchItem {
                title: "离线资源管理器"
                description: "在后台会定期联网检查离线资源（如词典）是否有更新。"
                switchOn: developerSettings.offlineRM
                interval: 0
                onTimerTriggered: {
                    developerSettings.offlineRM = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }

    }

    YDynamicPageStack {
        id: id_pop_container
        anchors.fill: parent
        logTag: "DeveloperSettingPage"

        function show(page) {
            createPage(Qt.resolvedUrl(("./%1.qml").arg(page)), page, {
                "pageIndex": YEnum.PageIndex.Setting,
                "closeOnHomeRelease": true,
                "closeOnHomeLongPress": true
            })
        }
    }
}
