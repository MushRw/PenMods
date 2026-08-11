import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingPronunc.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: 210

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.autoPronounceSetting
        }

        YSettingSwitchItem {
            id: id_switch_state_button_rect
            implicitHeight: 52
            anchors.top: id_title_container.bottom
            title: YTranslateText.autoPronounce
            switchOn: settingManager.isAutoPronounce
            onTimerTriggered: {
                if (antiEmbs.autoPronLocked) {
                    qmlGlobal.showToast("自动发音已被其他设置项关闭", YColors.yellow)
                    switchOn = false
                }
                settingManager.isAutoPronounce = switchOn
            }
        }

        Item {
            id: id_speaking_container
            anchors.top: id_switch_state_button_rect.bottom
            visible: settingManager.isAutoPronounce

            YText {
                id: id_speaking_vocal_label
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 18
                font.pixelSize: 16
                color: YColors.grayText
                height: 21
                text: YTranslateText.pronounceChoice
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: id_speaking_vocal_label.bottom
                anchors.topMargin: 8
                spacing: 8
                YPressedButton {
                    id: id_english_button
                    implicitWidth: 124
                    clickable: settingManager.autoPronounceType !== YEnum.UK
                    checkedIndicatorScale: settingManager.autoPronounceType === YEnum.UK
                    text: YTranslateText.pronounceEnglish
                    onClicked: {
                        settingManager.autoPronounceType = YEnum.UK
                    }
                }

                YPressedButton {
                    id: id_american_button
                    implicitWidth: 124
                    clickable: settingManager.autoPronounceType !== YEnum.US
                    checkedIndicatorScale: settingManager.autoPronounceType === YEnum.US
                    text: YTranslateText.pronounceAmerican
                    onClicked: {
                        settingManager.autoPronounceType = YEnum.US
                    }
                }
            }
        }
    }
}
