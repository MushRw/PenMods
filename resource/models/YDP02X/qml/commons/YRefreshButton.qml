import QtQuick 2.12

YIconButton {
    implicitWidth: 30
    implicitHeight: 30
    radius: height/2
    mouseAreaMargins: -10

    iconSourceSize: Qt.size(24, 34)
    icon: "settings/refresh"

    signal refresh()

    onClicked: {
        refresh()
    }
}
