import QtQuick 2.12

import "../commons"

YSettingAboutItem {
    id: id_setting_about_clickable_item
    opacity: (opacityChangableWhenPressed && (id_button.pressed || !enabled)) ? 0.6 : 1
    scale: (!enabled) ? 0.98 : (id_button.pressed ? 0.95 : 1.0)
    valueRightMargin: 8 + id_button_image.width + 10

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    transform: Scale {
        origin.x: id_setting_about_clickable_item.width / 2
        origin.y: id_setting_about_clickable_item.height / 2
    }

    property alias icon: id_setting_about_clickable_item.source
    property string source: ""
    property alias imageName: id_setting_about_clickable_item.source

    property alias iconSourceSize: id_setting_about_clickable_item.sourceSize
    property size sourceSize: Qt.size(24, 24)
    property alias pressed: id_button.pressed
    property bool opacityChangableWhenPressed: true

    property alias iconComponent: id_button_image
    property bool iconLoaded: id_button_image.status == Image.Ready

    signal clicked()

    YImage {
        id: id_button_image
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        sourceSize: id_setting_about_clickable_item.sourceSize
        imageName: id_setting_about_clickable_item.source
    }

    YMouseArea {
        id: id_button
        anchors.fill: parent
        onClicked: {
            id_setting_about_clickable_item.clicked()
        }
        objectName: "YSettingAboutClickableItem.qml_YMouseArea"
    }
}
