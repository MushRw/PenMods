import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingAboutItem {
    id: id_setting_about_clickable_item
    opacity: (opacityChangableWhenPressed && (id_left_button.pressed || !enabled)) ? 0.6 : 1
    valueRightMargin: 8 + id_button_icon_loader.item.width + 13

    property alias icon: id_setting_about_clickable_item.source
    property string source: ""
    property alias imageName: id_setting_about_clickable_item.source

    property alias iconSourceSize: id_setting_about_clickable_item.sourceSize
    property size sourceSize: Qt.size(24, 24)
    property alias pressed: id_left_button.pressed
    property bool opacityChangableWhenPressed: true

    property alias iconComponent: id_button_icon_loader.sourceComponent
    property alias iconLoaded: id_button_icon_loader.isLoaded

    property bool isDefaultScan: false

    signal leftClicked()
    signal rightClicked()

    YLoader {
        id: id_button_icon_loader
        active: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 13
        sourceComponent: YImage {
            sourceSize: id_setting_about_clickable_item.sourceSize
            imageName: id_setting_about_clickable_item.source
        }
    }


    YMouseArea {
        id: id_left_button
        width: parent.width - id_right_button.width - 20
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        onClicked: {
            id_setting_about_clickable_item.leftClicked()
        }
        objectName: "YSettingAboutItem.qml_YMouseArea_left"
    }

    YMouseArea {
        id: id_right_button
        height: parent.height
        width: 50
        anchors.top: parent.top
        anchors.right: parent.right
        enabled: !isDefaultScan
        onClicked: {
            id_setting_about_clickable_item.rightClicked()
        }
        objectName: "YSettingAboutItem.qml_YMouseArea_right"
    }

    iconComponent: isDefaultScan ? id_default_component
                                 : id_scan_setting_component

    Component {
        id: id_default_component
        YImage {
            sourceSize: Qt.size(24, 24)
            imageName: "audioplayer/default_scan"
        }
    }

    Component {
        id: id_scan_setting_component
        YImage {
            sourceSize: Qt.size(24, 24)
            imageName: "audioplayer/scan_setting"
        }
    }

    titlePixelSize: 16
    valuePixelSize: 14
}
