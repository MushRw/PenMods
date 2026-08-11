import QtQuick 2.12

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingMultiLines.qml"

    Item {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.continueScanSetting
        }

        YSettingSwitchItem {
            id: id_switch_state_button_rect
            implicitHeight: 52
            anchors.top: id_title_container.bottom
            title: YTranslateText.continueScan
            switchOn: settingManager.isContinueScan
            onTimerTriggered: {
                settingManager.isContinueScan = id_switch_state_button_rect.switchOn
            }
        }

        YText {
            id: id_speaking_vocal_label
            anchors.top: id_switch_state_button_rect.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: YText.AlignHCenter
            font.pixelSize: 16
            lineHeightMode: Text.FixedHeight
            lineHeight: 22
            textFormat: YText.RichText
            color: YColors.grayText
            text: YTranslateText.continueScanTip
        }
    }

}
