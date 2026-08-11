import QtQuick 2.12

import "../commons"

// 圆形头像：不依赖 QtGraphicalEffects 的 OpacityMask（在部分设备上不渲染），
// 而是用不透明边框的圆环盖住方形图片的四角，达到圆形效果（与原版 YRoundedImage 一致）。
Item {
    id: id_portrait_root

    property string defaultIconSource: "image://icons/login/dict-logo.png"
    property color borderColor: YColors.grayNormal

    property alias sourceSize: id_portrait_image.sourceSize

    Image {
        id: id_portrait_image
        anchors.fill: parent
        asynchronous: true
        // 经 penavatar 提供器做圆形裁剪（CPU 处理，不依赖着色器）
        source: "image://penavatar/" + encodeURIComponent(
                    (loginManager.iconPath.length > 0) && qmlGlobal.fileExists(loginManager.iconPath)
                        ? loginManager.iconPath.toLoadFileUrl() : defaultIconSource)
        fillMode: Image.PreserveAspectCrop
    }

    // 圆形边框环：边框宽度 9、外扩 9，边框带覆盖方形图片的四角。
    // 边框颜色为 transparent 时头像会显示为方形，请调用方设置不透明颜色。
    Rectangle {
        id: id_ring
        anchors.fill: parent
        anchors.margins: -9
        color: "transparent"
        border.width: 9
        border.color: borderColor
        radius: width / 2
    }
}
