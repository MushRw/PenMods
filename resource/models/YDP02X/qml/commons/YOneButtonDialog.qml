import QtQuick 2.12

YDialog {
    id: id_one_button_dialog
    readonly property alias buttonItem: id_button
    property alias tipItem: id_tip
    property bool showClose: true

    signal clicked()

    Item {
        anchors.fill: parent

        YText {
            id: id_tip
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

        YButton {
            id: id_button
            implicitWidth: 200
            anchors.top: id_tip.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: YColors.red
            onClicked: {
                id_one_button_dialog.clicked()
            }
        }

        YIconButton {
            id: id_close_button
            implicitWidth: 30
            implicitHeight: 30
            radius: height/2
            visible: showClose
            color: YColors.grayNormal
            mouseAreaMargins: -10
            imageName: "commons/close"
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            sourceSize: Qt.size(24, 24)
            onClicked: {
                close()
                closed()
            }
        }
    }
}


