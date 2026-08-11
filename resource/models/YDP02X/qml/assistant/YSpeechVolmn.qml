import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"
import "../settingpages"

YPage {
    id: id_setting_item
    objectName: "YPage===YSettingVolume.qml"

    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: 276
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
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            soundCenter.stop()
            backButtonClicked()
        }
    }
}

