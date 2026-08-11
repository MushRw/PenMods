import QtQuick 2.12

import "../commons"

YIconButton {
    implicitWidth: 30
    implicitHeight: 30
    radius: height/2
    mouseAreaMargins: -25
    iconSourceSize: Qt.size(24, 24)
    icon: "commons/download"

    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.bottom: parent.bottom
}
