import QtQuick 2.12
import QtGraphicalEffects 1.14

// 统一的「表面材质」组件 —— 全树唯一的半透明 / 毛玻璃实现。
//
// 名字沿用 YFastBlurRectangle 是为了不动资源树：repack_qrc.py 只能替换
// qrc_qml.h 里已有的文件，新增 .qml 进不了资源库。
//
// 三档材质由 YColors 令牌驱动：
//   opaque       底色实色（surfacePanel = 1.0），不模糊
//   translucent  底色 90% 透光，不模糊
//   glass        底色 82% 透光 + 实时背景模糊（强度 = YColors.glassBlurRadius）
//
// 支持两层背景（backdrop / backdrop2）：
//   一个 Item 往往装不下"看起来在后面的所有东西"。例：主页的壁纸 id_bg_image 与
//   主页内容 id_main_content 是兄弟节点，只传后者的话抽屉毛玻璃就只糊字和图标、
//   壁纸仍是清楚的（用户实测反馈）。两层各自实时取景、各自模糊，最后共用一层底色，
//   观感等于把合成后的背景一起糊掉。
//
// 实时模糊的四个要点：
//   1) ShaderEffectSource.live = true —— 每帧重新取景，不是缓存一张贴图；
//   2) sourceRect 用显式属性 sourceX / sourceY 拼（不能用 mapToItem：它是 C++ 内部
//      读 x/y，QML 依赖追踪抓不到，控件滑动时取景框不会重算；面板初始还在屏外时
//      取景框会永久停在屏外 → 看起来"模糊没了"）；
//   3) 取景框比表面外扩 blurMargin 再夹到背景范围内 —— 模糊边缘需要"框外"的像素，
//      只按表面自身取景时四条边会被夹断，出现"边上一圈颜色和中间不一样"的分层；
//   4) 模糊用 GaussianBlur：FastBlur 是大半径盒式模糊，暗色渐变上容易出条带。
Item {
    id: id_glass

    // 超出部分（外扩取景多出来的模糊像素）不要漏到表面外面
    clip: true

    // 被模糊的背景内容（画在上层）
    property Item backdrop: null
    // 可选的第二层背景（画在下层，例如壁纸）
    property Item backdrop2: null

    property int blurRadius: YColors.glassBlurRadius
    property real sourceX: id_glass.x
    property real sourceY: id_glass.y
    property real sourceX2: id_glass.x
    property real sourceY2: id_glass.y
    property int blurMargin: Math.ceil(id_glass.blurRadius * 1.5)

    // 表面底色 / 圆角（默认统一走 surfacePanel 令牌）
    property alias color: id_surface.color
    property alias radius: id_surface.radius
    // 兼容旧调用方：maskItem.color / maskItem.radius
    readonly property alias maskItem: id_surface

    readonly property bool blurring: YColors.glassEnabled && (null !== id_glass.backdrop)
    readonly property bool blurring2: YColors.glassEnabled && (null !== id_glass.backdrop2)
    readonly property alias backdropSource: id_backdrop_source

    // 取景框：以 (sx, sy) 为表面左上角，外扩 blurMargin，再夹进背景范围
    function _sourceRectFor(item, sx, sy) {
        var m = id_glass.blurMargin;
        var x0 = sx - m;
        var y0 = sy - m;
        var x1 = sx + id_glass.width + m;
        var y1 = sy + id_glass.height + m;
        if (null !== item) {
            x0 = Math.max(x0, 0);
            y0 = Math.max(y0, 0);
            x1 = Math.min(x1, item.width);
            y1 = Math.min(y1, item.height);
        }
        return Qt.rect(x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0));
    }

    // ================= 背景层 2（下层，例如壁纸）=================
    ShaderEffectSource {
        id: id_source2
        anchors.fill: parent
        visible: false
        live: true
        sourceItem: id_glass.backdrop2
        sourceRect: id_glass._sourceRectFor(id_glass.backdrop2, id_glass.sourceX2, id_glass.sourceY2)
    }

    Item {
        id: id_blur_holder2
        anchors.fill: parent
        visible: id_glass.blurring2
        layer.enabled: id_glass.blurring2 && id_glass.radius > 0
        layer.effect: OpacityMask {
            maskSource: id_blur_mask
        }

        GaussianBlur {
            x: id_source2.sourceRect.x - id_glass.sourceX2
            y: id_source2.sourceRect.y - id_glass.sourceY2
            width: id_source2.sourceRect.width
            height: id_source2.sourceRect.height
            source: id_source2
            radius: YColors.glassEnabled ? id_glass.blurRadius : 0
            samples: 17
            transparentBorder: false
        }
    }

    // ================= 背景层 1（上层，例如主页内容）=================
    ShaderEffectSource {
        id: id_backdrop_source
        anchors.fill: parent
        visible: false
        live: true
        sourceItem: id_glass.backdrop
        sourceRect: id_glass._sourceRectFor(id_glass.backdrop, id_glass.sourceX, id_glass.sourceY)
    }

    // 圆角裁剪用的遮罩（只喂给 OpacityMask，自己不显示）
    Rectangle {
        id: id_blur_mask
        anchors.fill: parent
        radius: id_glass.radius
        color: "white"
        visible: false
    }

    // 模糊层：整层进 layer 再用 OpacityMask 裁成圆角（不裁的话圆角外的方角会漏光）
    Item {
        id: id_blur_holder
        anchors.fill: parent
        visible: id_glass.blurring
        layer.enabled: id_glass.blurring && id_glass.radius > 0
        layer.effect: OpacityMask {
            maskSource: id_blur_mask
        }

        GaussianBlur {
            // 取景框在场景里的左上角 = (sourceRect.x, sourceRect.y)；
            // 它相对表面左上角的偏移 = sourceRect - (sourceX, sourceY)，直接 1:1 摆放。
            x: id_backdrop_source.sourceRect.x - id_glass.sourceX
            y: id_backdrop_source.sourceRect.y - id_glass.sourceY
            width: id_backdrop_source.sourceRect.width
            height: id_backdrop_source.sourceRect.height
            source: id_backdrop_source
            radius: YColors.glassEnabled ? id_glass.blurRadius : 0
            samples: 17
            // 不能开 transparentBorder：边缘按透明采样会"漏光"
            transparentBorder: false
        }
    }

    // 两层共用的底色
    Rectangle {
        id: id_surface
        anchors.fill: parent
        color: YColors.surfacePanel
        radius: 0
    }
}
