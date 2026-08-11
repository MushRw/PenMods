import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

Flickable {
    id: id_scan_login_loader
    anchors.fill: parent
    anchors.leftMargin: 54
    anchors.rightMargin: 10
    contentHeight: id_column.height

    signal requestLoginPageRealTimeDisplay()
    signal requestLoginPageLogoutConfirm()
    signal requestAddBindAccountDisplay()

    Column {
        id: id_column
        anchors.left: parent.left
        anchors.right: parent.right

        YSettingItemTitle {
            title: YTranslateText.userCenter
        }

        YSettingAboutItem {
            id: id_user_icon_bg
            implicitHeight: 50
            color: YColors.grayNormal
            titleItem.wrapMode: Text.Wrap
            valueRightMargin: 30
            titleFontFamily: {
                switch (qmlGlobal.language) {
                case YEnum.EN_US:
                    if (!qmlTranslator.textIsEnglishOnly(loginManager.userName)) {
                        return qmlGlobal.fontFamilyZhCn
                    }
                    return qmlGlobal.fontFamilyEnUs
                }
                return qmlGlobal.fontFamilyZhCn
            }
            title: loginManager.isLogin ? loginManager.userName : YTranslateText.unlogin
            value: ""

            YUserPortrait {
                id: id_user_icon
                width: 30
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12
                borderColor: id_user_icon_bg.color
            }
        }

        YSpacingForColumn {
            implicitHeight: 8
        }

        YSettingAboutClickableItem {
            id: id_add_bind_account_bg
            implicitHeight: 50
            color: YColors.grayNormal
            title: YTranslateText.addBindAccount
            value: ""
            source: "login/add-account"

            onClicked: {
                requestAddBindAccountDisplay()
            }
        }

        YSpacingForColumn {
            implicitHeight: 8
        }

        YSettingSwitchItem {
            id: id_switch_state
            implicitHeight: 74
            title: YTranslateText.autoUploadLearningData
            switchOn: settingManager.isAutoUploadData
            onTimerTriggered: {
                settingManager.isAutoUploadData = switchOn
                switchOn = Qt.binding(function() { return settingManager.isAutoUploadData })
            }
        }

        YSpacingForColumn {
            implicitHeight: 8
        }

        YSettingAboutClickableItem {
            opacityChangableWhenPressed: false
            color: pressed ? "#111216" : YColors.grayNormal
            title: YTranslateText.realTimeDisplay
            value: ""
            imageName: blueToothManager.isAppConnected ? "settings/st-check" : "settings/info_more_arrow"

            onClicked: {
                logManager.sendHttpLog("action=account_display_click")
                requestLoginPageRealTimeDisplay()
            }
        }

        YSpacingForColumn {
            implicitHeight: 8
        }

        YButton {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: 50
            radius: 12
            color: pressed ? "#111216" : YColors.grayNormal
            text: YTranslateText.logout
            textColor: YColors.red
            onClicked: {
                requestLoginPageLogoutConfirm()
            }
        }

        YSpacingForColumn {
            implicitHeight: 20
        }
    }
}
