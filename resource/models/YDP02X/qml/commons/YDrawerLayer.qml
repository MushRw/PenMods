import QtQuick 2.12
import com.youdao.pen 1.0

YBackground {
    id: id_drawer_layer
    width: YEnum.Screen.Width
    height: YEnum.Screen.Height
    anchors.left: parent.left
    visible: false
    objectName: "YDrawerLayer.qml_id_drawer_layer"

    function show() {
         visible = true
    }
    function hide() {
        visible = false
    }

    YBackground {
        id: id_bg
        anchors.fill: parent
        opacity: 0.7
    }

    YIconButton {
        id: id_close_button
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        color: YColors.grayNormal
        mouseAreaMargins: -10
        imageName: "commons/close"
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 8
        sourceSize: Qt.size(24, 24)
        onClicked: {
            hide()
        }
    }
}
