import QtQuick 2.12

Item {
    id: id_back_button_root
    objectName: "YBackButton.qml"

    property bool isPositionLeftBar: false

    width: isPositionLeftBar ? 50 : 160
    height: 50
    opacity: id_back_button.pressed || !enabled ? 0.6 : 1
    property alias iconScale: id_back_button_bg.iconScale
    readonly property alias iconButtonBackgroundItem: id_back_button_bg
    readonly property alias backButtonMouseAreaItem: id_back_button


    signal clicked()

    YIconButton {
        id: id_back_button_bg
        implicitWidth: 30
        implicitHeight: 30
        anchors.verticalCenter: isPositionLeftBar ? undefined : parent.verticalCenter
        anchors.horizontalCenter: isPositionLeftBar ? parent.horizontalCenter : undefined
        radius: 15
        icon: "ic_back"
        iconSourceSize: Qt.size(24, 24)
    }

    YBackButtonBase {
        id: id_back_button
        anchors.fill: parent
        // anchors.margins: -10  <--- 【删除】这行代码导致点击区域向外扩充了 10 像素
        onTriggered:  {
            id_back_button_root.clicked()
        }
        objectName: "YBackButtonBase_" + id_back_button_root.objectName
    }
}
