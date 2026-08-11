import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

YBackButtonPage {
    anchors.fill: parent
    destroyOnBack: false

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height
        Column {
            id: id_column
            spacing: 0
            anchors.left: parent.left
            anchors.right: parent.right

            YSettingItemTitle {
                title: YTranslateText.loginYdLearningApp
            }

            YText {
                width: parent.width
                font.pixelSize: 18
                wrapMode: YTextBase.Wrap
                text: YTranslateText.loginYdLearningAppTip1
                height: contentHeight
            }

            YSpacingForColumn {
                implicitHeight: 10
            }

            YRectangle {
                implicitHeight: 64
                radius: 8
                width: parent.width
                color: YColors.grayNormal
                YImage {
                    anchors.centerIn: parent
                    sourceSize: Qt.size(220, 64)
                    imageName: "login/tip_4"
                }
            }

            YSpacingForColumn {
                implicitHeight: 24
            }

            YText {
                width: parent.width
                font.pixelSize: 18
                wrapMode: YTextBase.Wrap
                text: YTranslateText.loginYdLearningAppTip2
                height: contentHeight
            }

            YSpacingForColumn {
                implicitHeight: 10
            }

            YRectangle {
                id: id_tip
                implicitHeight: 64
                radius: 8
                width: parent.width
                color: YColors.grayNormal

                 property int clickCnt: 0

                YImage {
                    anchors.centerIn: parent
                    sourceSize: Qt.size(220, 64)
                    imageName: "login/tip_5"
                    YMouseArea {
                        objectName: "YVerifyPage.qml_id_language_title_text"
                        anchors.fill: parent
                        property var currentShowPage: null

                        onClicked: {
                            if (id_tip.clickCnt <= 0) {
                                id_click_count_timer.start()
                            }

                            id_tip.clickCnt++
                            if (id_tip.clickCnt >= 5) {
                                id_tip.clickCnt = 0
                                showPageByVerfyState(YEnum.Verify_Verifying)
                                verifyManager.startVerify()
                                id_click_count_timer.stop()
                            }
                        }
                    }
                }
                YTimer {
                    id: id_click_count_timer
                    interval: 2000
                    objectName: "YVerifyPage.qml_id_click_count_timer"
                    onTriggered: {
                        if (id_tip.clickCnt > 1) {
                            id_tip.clickCnt--
                        }
                        if (id_tip.clickCnt == 0) {
                            stop()
                        }
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 24
            }

            YText {
                width: parent.width
                font.pixelSize: 18
                wrapMode: YTextBase.Wrap
                text: YTranslateText.loginYdLearningAppTip3
                height: contentHeight
            }

            YSpacingForColumn {
                implicitHeight: 10
            }

        }
    }

    onBackButtonClicked: close()
}
