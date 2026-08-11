import QtQuick 2.12
import QtGraphicalEffects 1.14

import "../commons"

// 圆形头像：图片本体用 OpacityMask 裁成圆形，
// 边框颜色为 transparent 时不显示边框（主页标题栏），
// 需要圆形边框的地方设置 borderColor 即可（如设置页的黑圈）。
Item {
    id: id_portrait_root

    property string defaultIconSource: "image://icons/login/dict-logo.png"
    property color borderColor: YColors.grayNormal

    property alias sourceSize: id_portrait_image.sourceSize

    Image {
        id: id_portrait_image
        anchors.fill: parent
        asynchronous: true
        source: (loginManager.iconPath.length > 0) && qmlGlobal.fileExists(loginManager.iconPath)
                ? loginManager.iconPath.toLoadFileUrl() : defaultIconSource
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    Rectangle {
        id: id_portrait_mask
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: id_portrait_image
        maskSource: id_portrait_mask
    }

    // 圆形边框（transparent 时不显示）
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: borderColor
        radius: Math.min(width, height) / 2
    }
}
