import QtQuick 2.12
import QtGraphicalEffects 1.14

// 统一的「表面材质」组件 —— 全树唯一的半透明 / 毛玻璃实现。
//
// 名字沿用 YFastBlurRectangle 是为了不动资源树：repack_qrc.py 只能替换
// qrc_qml.h 里已有的文件，新增 .qml 进不了资源库。
//
// 三档材质由 YColors 令牌驱动，调用方只管摆位置：
//   opaque       底色实色（surfacePanel = 1.0），不模糊
//   translucent  底色 90% 透光，不模糊
//   glass        底色 75% 透光 + 实时背景模糊
//
// 实时模糊（修掉"模糊跟着控件跑 / 模糊干脆没了"）：
//   1) ShaderEffectSource.live = true —— 每帧重新取景，不是缓存一张贴图；
//   2) sourceRect 用显式属性 sourceX / sourceY 拼出来。**不能用 mapToItem**：
//      mapToItem 是 C++ 内部读 x/y，QML 的依赖追踪抓不到，面板滑动时取景框
//      不会重算；而且面板初始 y = -height 在屏外，取景框会永久停在屏外，
//      模糊层就全透明（看起来"模糊没了"）；
//   3) FastBlur.cached = false。
//
// sourceX / sourceY = 本表面左上角在 backdrop 坐标系里的位置。
// 默认取本组件自己的 x / y —— 当本组件与 backdrop 同父、坐标原点一致时（抽屉、
// 听力练习左侧栏）就是对的；不同坐标系时（下拉面板的面板根节点会上下滑）由调用方显式绑定。
//
// 用法：
//   YFastBlurRectangle {
//       anchors.fill: parent
//       backdrop: id_page_content   // 要模糊的背景内容；不要传自己的祖先（会递归）
//       radius: 16                  // 圆角
//       blurRadius: 48              // 毛玻璃档的强度
//   }
Item {
    id: id_glass

    // 被模糊的背景内容
    property Item backdrop: null
    // 毛玻璃档的模糊强度（不透明/半透明档一律不模糊）
    property int blurRadius: 64
    // 取景框左上角（backdrop 坐标系）
    property real sourceX: id_glass.x
    property real sourceY: id_glass.y

    // 表面底色 / 圆角（默认统一走 surfacePanel 令牌）
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
        sourceRect: Qt.rect(id_glass.sourceX, id_glass.sourceY, id_glass.width, id_glass.height)
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
        color: YColors.surfacePanel
        radius: 0
    }
}
