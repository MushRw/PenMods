import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YPage {
    id: id_setting_item
    objectName: "YPage===YSettingVolume.qml"

    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: 290 + switch_fast_mute.height + switch_low_voice.height
        interactive: !id_slider_moving_timer.running

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.adjustVolume
        }

        YSettingItemBackground {
            id: id_slider_rect
            implicitHeight: 60
            anchors.top: id_title_container.bottom

            YSlider {
                id: id_slider
                implicitWidth: 140
                anchors.centerIn: parent
                property int spkSettingVolume: settingManager.spkVolume
                onValueChanged: {
                    id_slider_moving_timer.restart()
                    if (spkSettingVolume != value) {
                        settingManager.setSpkVolume(value)
                    }
                }
                onSpkSettingVolumeChanged: {
                    if (spkSettingVolume != value) {
                        value = spkSettingVolume
                    }
                }
                Component.onCompleted: value = spkSettingVolume
            }

            YTimer {
                id: id_slider_moving_timer
                interval: 300
                objectName: "YSettingVolume.qml_id_slider_moving_timer"
            }

            YClickabledImage {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: id_slider.left
                anchors.rightMargin: 16
                mouseAreaMargins: -4
                imageName: "settings/sound-dec"
                onClicked: {
                    id_slider.decrementTenValue()
                }
            }

            YClickabledImage {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: id_slider.right
                anchors.leftMargin: 16
                mouseAreaMargins: -4
                imageName: "settings/sound-inc"
                onClicked: {
                    id_slider.incrementTenValue()
                }
            }
        }

        DescribedSwitchItem {
            id: switch_fast_mute
            anchors.left: parent.left
            anchors.top: id_slider_rect.bottom
            anchors.topMargin: 8
            title: "快速静音"
            description: "点击控制中心的音量图标时直接静音。"
            switchOn: antiEmbs.fastMute
            interval: 0
            onTimerTriggered: {
                antiEmbs.fastMute = switchOn
            }
        }

        YSettingSwitchItem {
            id: switch_low_voice
            anchors.left: parent.left
            anchors.top: switch_fast_mute.bottom
            anchors.topMargin: 8
            implicitHeight: 54
            title: "降低最低音量"
            switchOn: antiEmbs.lowVoiceMode
            interval: 0
            onTimerTriggered: {
                antiEmbs.lowVoiceMode = switchOn
            }
        }

        YText {
            id: id_speaking_rate_label
            anchors.left: parent.left
            anchors.top: switch_low_voice.bottom
            anchors.topMargin: 12
            height: 20
            font.pixelSize: 16
            color: YColors.grayText
            text: YTranslateText.soundSpeedChoice
        }

        Grid {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_speaking_rate_label.bottom
            anchors.topMargin: 8
            columns: 2
            spacing: 8

            YPressedButton {
                id: id_quickly_button
                implicitWidth: 124
                clickable: settingManager.audioSpeed !== YEnum.SPEED_QUICK
                checkedIndicatorScale: settingManager.audioSpeed === YEnum.SPEED_QUICK
                text: YTranslateText.soundSpeedQuick
                onClicked: {
                    logManager.sendHttpLog("action=setting_sound_f_click")
                    settingManager.audioSpeed = YEnum.SPEED_QUICK
                    soundCenter.play("How are you", "en")
                }
            }

            YPressedButton {
                id: id_middle_button
                implicitWidth: 124
                clickable: settingManager.audioSpeed !== YEnum.SPEED_MID
                checkedIndicatorScale: settingManager.audioSpeed === YEnum.SPEED_MID
                text: YTranslateText.soundSpeedMiddle
                onClicked: {
                    logManager.sendHttpLog("action=setting_sound_m_click")
                    settingManager.audioSpeed = YEnum.SPEED_MID
                    soundCenter.play("How are you", "en")
                }
            }

            YPressedButton {
                id: id_slowly_button
                implicitWidth: 124
                clickable: settingManager.audioSpeed !== YEnum.SPEED_SLOW
                checkedIndicatorScale: settingManager.audioSpeed === YEnum.SPEED_SLOW
                text: YTranslateText.soundSpeedSlow
                onClicked: {
                    logManager.sendHttpLog("action=setting_sound_s_click")
                    settingManager.audioSpeed = YEnum.SPEED_SLOW
                    soundCenter.play("How are you", "en")
                }
            }
        }

    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            soundCenter.stop()
            backButtonClicked()
        }
    }
}

