import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

YBackButtonPage {
    anchors.fill: parent
    destroyOnBack: false

    Item {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 10

        YSettingItemTitle {
            anchors.leftMargin: 34
            title: "爱发电赞助"
        }

        YImage {
            id: id_avatar
            source: "qrc:/images/sponsor/avatar"
            sourceSize: Qt.size(36, 36)
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 54
        }

        YText {
            id: id_sponsor
            font.pixelSize: 17
            font.weight: Font.DemiBold
            height: 22
            text: "捐助 PenMods"
            anchors.left: parent.left
            anchors.top: id_avatar.bottom
            anchors.topMargin: 10
        }

        YTextBase {
            font.pixelSize: 15
            color: YColors.grayText
            height: 22
            text: "非常感谢，您的捐赠可以让\n我们走的更远"
            anchors.left: parent.left
            anchors.top: id_sponsor.bottom
            anchors.topMargin: 2
        }

        Rectangle {
            implicitWidth: 96
            implicitHeight: 96
            radius: 12
            color: YColors.white
            anchors.top: parent.top
            anchors.topMargin: 58
            anchors.right: parent.right

            YImageBase {
                id: id_qrcode_icon
                anchors.centerIn: parent
                width: 86
                height: 86
                sourceSize: Qt.size(width,height)
                source: "qrc:/images/sponsor/qrcode"
            }

        }
    }

    onBackButtonClicked: close()

}

