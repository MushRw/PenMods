import QtQuick 2.12

import "../i18n"

YDialog {
    id: id_two_button_dialog
    readonly property alias buttonItemConfirm: id_button_confirm
    readonly property alias buttonItemCancel: id_button_cancel
    readonly property alias tipItem: id_tip

    signal clickedConfirm()
    signal clickedCancel()

    Item {
        anchors.fill: parent

        YText {
            id: id_tip
            font.pixelSize: 18
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.right: parent.right
            anchors.rightMargin: 50
            anchors.top: parent.top
            anchors.topMargin: 18
            height: 78
            horizontalAlignment: YText.AlignHCenter
            verticalAlignment: YText.AlignVCenter
            wrapMode: YText.Wrap
        }

        Item {
            anchors.top: id_tip.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: 50
            width: id_button_row.width

            Row {
                id: id_button_row
                spacing: 8
                height: parent.height

                YButton {
                    id: id_button_confirm
                    implicitWidth: 120
                    color: YColors.grayNormal
                    text: YTranslateText.cancel
                    onClicked: {
                        id_two_button_dialog.clickedCancel()
                    }
                }

                YButton {
                    id: id_button_cancel
                    implicitWidth: 120
                    color: YColors.red
                    text: YTranslateText.confirm
                    onClicked: {
                        id_two_button_dialog.clickedConfirm()
                    }
                }
            }
        }

        YIconButton {
            id: id_close_button
            implicitWidth: 30
            implicitHeight: 30
            radius: 17
            color: YColors.grayNormal
            mouseAreaMargins: -15
            imageName: "commons/close"
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 8
            onClicked: {
                close()
                closed()
            }
        }
    }
}
