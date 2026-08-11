import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===Torch.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "笔头 LED"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingSwitchItem {
                id: id_switch
                implicitHeight: 54
                title: "开关状态"
                interval: 0
                switchOn: torch.switch
                onTimerTriggered: {
                    torch.switch = switchOn
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

        YText {
            id: id_state_tip
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: id_column.bottom
            font.pixelSize: 16
            text: "长时间开启笔头灯可能影响续航"
            color: YColors.grayText
        }

    }

    Timer {
        running: true
        repeat: true
        onTriggered: id_switch.switchOn = torch.switch
    }

}
