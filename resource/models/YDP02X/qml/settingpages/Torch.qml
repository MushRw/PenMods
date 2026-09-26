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
        // 必须给 interval：QML Timer 的默认 interval 是 0，等于让本页以最高频率轮询 C++ 侧状态。
        interval: 1000
        running: true
        repeat: true
        // AP-21：这里原来是 `id_switch.switchOn = torch.switch`。
        // `switchOn: torch.switch` 本身**就是绑定**，而 QML 中对已绑定属性赋值会
        // **移除绑定** —— 这个"每秒兜底同步"正好把绑定机制废掉了。
        // 改成让 C++ 发一次 NOTIFY，绑定自己重新求值（见 Torch::refreshStatus）。
        onTriggered: torch.refreshStatus()
    }

}
