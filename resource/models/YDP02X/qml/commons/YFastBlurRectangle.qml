import QtQuick 2.12
import QtGraphicalEffects 1.14

Item {
    readonly property alias maskItem: id_mask_bg
    property alias blurRadius: id_fast_blur.radius

    Rectangle {
        id: id_mask_bg
        anchors.fill: parent
        color: YColors.surface
        radius: height/2
        visible: false
    }

    FastBlur {
        id: id_fast_blur
        anchors.fill: id_mask_bg
        source: id_mask_bg
        // 组件默认：只有毛玻璃模式才真模糊；调用方可用 blurRadius 覆盖
        radius: YColors.glassEnabled ? 64 : 0
        visible: false
    }

    Rectangle {
        id: id_opacity_mask_bg
        anchors.fill: parent
        radius: id_mask_bg.radius
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: id_fast_blur
        maskSource: id_opacity_mask_bg
    }
}
