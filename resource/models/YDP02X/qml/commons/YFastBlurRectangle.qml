import QtQuick 2.12
import QtGraphicalEffects 1.14

// 统一的「表面材质」组件 —— 全树唯一的半透明 / 毛玻璃实现。
//
// 名字沿用 YFastBlurRectangle 是为了不动资源树：repack_qrc.py 只能替换
// qrc_qml.h 里已有的文件，新增 .qml 进不了资源库。改名前先确认打包链路。
//
// 三档材质由 YColors 令牌驱动，调用方只管摆位置：
//   opaque       底色实色（surfaceAlpha = 1.0），不模糊
//   translucent  底色 60% 透光，不模糊
//   glass        底色 60% 透光 + 实时背景模糊
//
// 实时模糊（修掉"模糊跟着控件跑"）的三个要点：
//   1) ShaderEffectSource.live = true —— 每帧重新取景，不是缓存一张贴图；
//   2) sourceRect 用 mapToItem 算"本控件在 backdrop 里的矩形"，控件滑动/动画时
//      取景框跟着重算，模糊内容始终钉在背景上；
//   3) FastBlur.cached = false。
//
// 用法（下拉面板 / 插件抽屉 / 听力练习左侧栏都是这一份）：
//   YFastBlurRectangle {
//       anchors.fill: parent
//       backdrop: id_page_content   // 要模糊的背景内容；不要传自己的祖先（会递归）
//       radius: 16                  // 圆角
//       blurRadius: 48              // 毛玻璃档的强度
//   }
Item {
    id: id_glass

    // 被模糊的背景内容；取景框 = 本控件在 backdrop 坐标系里的矩形
    property Item backdrop: null
    // 毛玻璃档的模糊强度（不透明/半透明档一律不模糊）
    property int blurRadius: 64

    // 表面底色 / 圆角（默认统一走 surface 令牌）
    property alias color: id_surface.color
    property alias radius: id_surface.radius
    // 兼容旧调用方：maskItem.color / maskItem.radius
    readonly property alias maskItem: id_surface

    readonly property bool blurring: YColors.glassEnabled && (null !== id_glass.backdrop)
    readonly property alias backdropSource: id_backdrop_source

    ShaderEffectSource {
        id: id_backdrop_source
        anchors.fill: parent
        visible: false
        live: true
        sourceItem: id_glass.backdrop
        sourceRect: {
            if (null === id_glass.backdrop) {
                return Qt.rect(0, 0, 0, 0);
            }
            var p = id_glass.mapToItem(id_glass.backdrop, 0, 0);
            return Qt.rect(p.x, p.y, id_glass.width, id_glass.height);
        }
    }

    FastBlur {
        id: id_backdrop_blur
        anchors.fill: parent
        source: id_backdrop_source
        radius: YColors.glassEnabled ? id_glass.blurRadius : 0
        cached: false
        transparentBorder: true
        visible: id_glass.blurring
    }

    Rectangle {
        id: id_surface
        anchors.fill: parent
        color: YColors.surface
        radius: 0
    }
}
