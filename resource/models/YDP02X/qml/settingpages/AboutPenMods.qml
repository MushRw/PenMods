import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YSettingItemPage {
    id: id_setting_item

    objectName: "YPage===AboutPenMods.qml"

    Flickable {
        id: id_setting_item_view

        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container

            title: "关于 PenMods"
        }

        Column {
            id: id_column

            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutItem {
                title: "版本"
                value: mod.version
            }

            DescribedClickableTextBox {
                opacityChangableWhenPressed: false
                describeItem.width: 200
                title: "构建信息"
                describe: mod.buildInfo
            }

            YSettingAboutItem {
                title: "已缓存符号计数"
                value: mod.cachedSymCount
            }

            YSettingAboutItem {
                title: "GitHub"
                value: "PenUniverse"
            }

            DescribedClickableTextBox {
                opacityChangableWhenPressed: false
                describeItem.width: 200
                title: "Telegram 社群"
                describe: "https://t.me/PenUniverse"
            }

            DescribedClickableTextBox {
                opacityChangableWhenPressed: false
                describeItem.width: 200
                title: "特别鸣谢"
                describe: "Dobby (Hook Framework)\nQt Project\nNetease Youdao\nRedbeanW (Developer)\nAll Sponsors..."
            }

            YSettingAboutClickableItem {
                title: "捐助项目发展"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show("AFDianQrCode");
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
        logTag: "AboutPenMods"

        function show(page) {
            createPage(Qt.resolvedUrl(("./%1.qml").arg(page)), page, {
                "pageIndex": YEnum.PageIndex.Setting,
                "closeOnHomeRelease": true,
                "closeOnHomeLongPress": true
            });
        }
    }

}
