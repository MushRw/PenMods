import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YSettingItemPage {
    id: id_setting_item

    objectName: "YPage===YSettingCertification.qml"

    Item {
        id: id_setting_item_view

        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 42

        YSettingItemTitle {
            id: id_title_container

            title: YTranslateText.certification
        }

        YImage {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: id_title_container.bottom
            imageName: {
                //加强版

                if (settingManager.checkskudatawrite()) {
                    if (qmlGlobal.checkFeature(YEnum.FEATURE_SKU_CLA)) {
                        if (settingManager.devCompanyId() === 1)
                            return "settings/certificationnew_cla";
                        else
                            return "settings/certification_cla";
                    } else if (qmlGlobal.checkFeature(YEnum.FEATURE_SKU_EXA)) {
                        if (settingManager.devCompanyId() === 1)
                            return "settings/certificationnew_exa";
                        else
                            return "settings/certification_exa";
                    } else {
                        return "settings/certification";
                    }
                } else {
                    if (settingManager.devCompanyId() === 1)
                        return "settings/certificationnew_2";
                    else
                        return "settings/certification_2";
                }
            }
        }

    }

    YOneButtonDialog {
        id: pen_universe_dialog

        anchors.fill: parent
        tipItem.text: "Project PenUniverse\nMod By: RedbeanW"
        buttonItem.text: "Develop with ❤"
    }

    YTimer {
        id: id_continue_timer

        interval: 480
        objectName: "YSettingCertification.qml_id_continue_timer"
        onTriggered: {
            id_open_adb_button.times = 0;
        }
    }

    YMouseArea {
        id: id_open_adb_button

        property int times: 0

        anchors.fill: parent
        anchors.topMargin: id_title_container.height
        onClicked: {
            //settingManager.openAdb()

            id_continue_timer.restart();
            ++times;
            if (5 === times)
                pen_universe_dialog.show();

        }
        objectName: "YSettingCertification.qml_id_open_adb_button"
    }

}
