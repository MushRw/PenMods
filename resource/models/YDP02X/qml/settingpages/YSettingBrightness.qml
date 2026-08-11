import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingBrightness.qml"
    property alias title: id_title_container.title

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height + 10

        YSettingItemTitle {
            id: id_title_container
            title: "屏幕相关设定"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingItemBackground {
                implicitHeight: 60

                YSlider {
                    id: id_slider
                    implicitWidth: 140
                    anchors.centerIn: parent
                    property int lcdSettingBrightness: settingManager.lcdBrightness
                    onValueChanged: {
                        if (lcdSettingBrightness != value) {
                            settingManager.setLcdBrightness(value)
                        }
                    }
                    onLcdSettingBrightnessChanged: {
                        if (lcdSettingBrightness != value) {
                            value = lcdSettingBrightness
                        }
                    }
                    Component.onCompleted: value = settingManager.lcdBrightness
                }

                YClickabledImage {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: id_slider.left
                    anchors.rightMargin: 16
                    imageName: "settings/lum-dec"
                    onClicked: {
                        id_slider.decrementTenValue()
                    }
                }

                YClickabledImage {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: id_slider.right
                    anchors.leftMargin: 16
                    imageName: "settings/lum-inc"
                    onClicked: {
                        id_slider.incrementTenValue()
                    }
                }
            }

            YSettingAboutClickableItem {
                title: "自动息屏"
                imageName: "settings/info_more_arrow"
                value: screenManager.autoSleepDuration
                onClicked: {
                    id_pop_container.show("AutoScreenOffSetting")
                }
            }

            DescribedSwitchItem {
                title: "场景智能息屏"
                description: "切换到音频播放器或单词本卡片模式页面时暂停自动息屏。"
                switchOn: screenManager.intelSleep
                interval: 0
                onTimerTriggered: {
                    screenManager.intelSleep = switchOn
                }
            }

            DescribedSwitchItem {
                title: "场景熄屏跟随音频锁"
                description: "音频锁激活时保持屏幕不熄灭。"
                switchOn: screenManager.intelSleepAudioLock
                interval: 0
                onTimerTriggered: {
                    screenManager.intelSleepAudioLock = switchOn
                }
            }

        }

    }

    YDynamicPageStack {
        id: id_pop_container
        anchors.fill: parent
        logTag: "YSettingBrightness"

        function show(aboutPage) {
            createPage(Qt.resolvedUrl(("./%1.qml").arg(aboutPage)), aboutPage, {
                "pageIndex": YEnum.PageIndex.Setting,
                "closeOnHomeRelease": true,
                "closeOnHomeLongPress": true
            })
        }
    }

}
