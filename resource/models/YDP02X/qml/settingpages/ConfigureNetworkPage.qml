import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===ConfigureNetworkPage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "配置网络"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            DescribedClickableTextBox {
                title: "MAC 地址"
                describe: settingManager.sysMac
                opacityChangableWhenPressed: false
            }

            DescribedClickableTextBox {
                title: "IP 地址"
                describe: networkSettings.localIpAddress
                opacityChangableWhenPressed: false
            }

            DescribedClickableTextBox {
                title: "网关"
                describe: networkSettings.netGateway
                opacityChangableWhenPressed: false
            }

            DescribedClickableTextBox {
                title: "DNS"
                describe: networkSettings.dns
                opacityChangableWhenPressed: false
            }

            YSettingAboutClickableItem {
                title: "代理服务器"
                value: ""
                imageName: "settings/info_more_arrow"
                onClicked: {
                    id_pop_container.show('settingpages/ConfigureProxyPage')
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }
}
