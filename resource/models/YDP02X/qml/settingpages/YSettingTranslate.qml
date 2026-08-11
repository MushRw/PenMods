import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingTranslate.qml"

    Item {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.priorityTranslationLanguageChoice
        }

        Grid {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_title_container.bottom
            columns: 2
            spacing: 8

            YPressedButton {
                implicitWidth: 124
                clickable: settingManager.transLanguage !== YEnum.EN_US
                checkedIndicatorScale: settingManager.transLanguage === YEnum.EN_US
                text: YTranslateText.english
                visible: qmlGlobal.checkFeature(YEnum.FEATURE_LANG_ENG)
                onClicked: {
                    settingManager.transLanguage = YEnum.EN_US
                }
            }

            YPressedButton {
                implicitWidth: 124
                clickable: settingManager.transLanguage !== YEnum.ZH_CN
                checkedIndicatorScale: settingManager.transLanguage === YEnum.ZH_CN
                text: YTranslateText.chinese
                visible: false // mod: only support chinese version.
                onClicked: {
                    settingManager.transLanguage = YEnum.ZH_CN
                }
            }

            YPressedButton {
                implicitWidth: 124
                clickable: settingManager.transLanguage !== YEnum.JA_JP
                checkedIndicatorScale: settingManager.transLanguage === YEnum.JA_JP
                text: YTranslateText.japanese
                visible: qmlGlobal.checkFeature(YEnum.FEATURE_LANG_JPN)
                onClicked: {
                    settingManager.transLanguage = YEnum.JA_JP
                }
            }

            YPressedButton {
                implicitWidth: 124
                clickable: settingManager.transLanguage !== YEnum.KO_KR
                checkedIndicatorScale: settingManager.transLanguage === YEnum.KO_KR
                text: YTranslateText.korean
                visible: qmlGlobal.checkFeature(YEnum.FEATURE_LANG_KOR)
                onClicked: {
                    settingManager.transLanguage = YEnum.KO_KR
                }
            }

            YPressedButton {
                implicitWidth: 124
                clickable: settingManager.transLanguage !== YEnum.ES_ES
                checkedIndicatorScale: settingManager.transLanguage === YEnum.ES_ES
                text: YTranslateText.spanish
                visible: qmlGlobal.checkFeature(YEnum.FEATURE_LANG_ES)
                pixelSize: 26
                onClicked: {
                    settingManager.transLanguage = YEnum.ES_ES
                }
            }
        }

    }
}
