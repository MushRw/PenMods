import QtQuick 2.12

Item {
    id: id_title_bar
    implicitHeight: 80
    anchors.left: parent.left
    anchors.leftMargin: 16
    anchors.right: parent.right
    anchors.rightMargin: 16

    readonly property alias titleItem : id_title
    readonly property alias backButtonItem : id_back_button
    property alias title: id_title.text
    property alias titlesize: id_title.font.pixelSize
    signal callBack()

    YBackButton {
        id: id_back_button
        onClicked: {
            callBack()
        }
    }

    YTitle {
        id: id_title
    }
}
