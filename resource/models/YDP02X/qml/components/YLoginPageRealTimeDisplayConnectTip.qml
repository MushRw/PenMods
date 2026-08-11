import QtQuick 2.12

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
                title: YTranslateText.connectYdDict
            }

            YText {
                font.pixelSize: 18
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: YTextBase.Wrap
                text: YTranslateText.connectYdDictTip1
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
                    sourceSize: Qt.size(222, 64)
                    imageName: "login/tip_0"
                    anchors.centerIn: parent
                }
            }

            YSpacingForColumn {
                implicitHeight: 24
            }

            YText {
                font.pixelSize: 18
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: YTextBase.Wrap
                text: YTranslateText.connectYdDictTip2
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
                    sourceSize: Qt.size(222, 64)
                    imageName: "login/tip_3"
                    anchors.centerIn: parent
                }
            }

            YSpacingForColumn {
                implicitHeight: 24
            }

            YText {
                font.pixelSize: 18
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: YTextBase.Wrap
                text: YTranslateText.connectYdDictTip3
                height: contentHeight
            }

            YSpacingForColumn {
                implicitHeight: 24
            }

            YText {
                font.pixelSize: 18
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: YTextBase.Wrap
                text: YTranslateText.connectYdDictTip4
                height: contentHeight
            }

            YSpacingForColumn {
                implicitHeight: 20
            }
        }
    }
    onBackButtonClicked: close()
}
