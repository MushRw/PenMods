import QtQuick 2.12

import "../commons"

Rectangle {
    implicitHeight: 52
    anchors.left: parent.left
    anchors.right: parent.right
    color: YColors.grayNormal
    radius: 12

    scale: enabled ? 1.0 : 0.98
}
