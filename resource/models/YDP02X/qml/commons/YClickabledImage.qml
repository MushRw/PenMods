import QtQuick 2.12

YImage {
    id: id_clickabled_image
    sourceSize: Qt.size(30, 30)
    opacity: id_clickabled_button.pressed || !enabled ? 0.6 : 1

    property alias mouseAreaMargins: id_clickabled_button.anchors.margins

    signal clicked()

    YMouseArea {
        id: id_clickabled_button
        anchors.fill: parent
        anchors.margins: -10
        onClicked: {
            id_clickabled_image.clicked()
        }
        objectName: "YClickabledImage.qml_YMouseArea"
    }
}
