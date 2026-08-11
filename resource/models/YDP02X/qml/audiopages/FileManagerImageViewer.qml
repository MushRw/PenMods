/**
 * 图片查看页 - WebP 动画性能优化版
 * 支持缩放、旋转、拖拽等交互操作
 */

import QtQuick 2.12
import com.youdao.pen 1.0
import Mod.FileManager 1.0 // 导入自定义模块以使用 WebPAnimatedImage
import "../commons"
import "../components"
import "../i18n"

YBackButtonAudioPage {
    id: root

    // 缩放和偏移属性
    property real scaleFactor: 1.0      // 当前缩放系数
    property real fitScale: 1.0         // 图片自适应屏幕的缩放系数
    property int rotationAngle: 0       // 旋转角度（0/90/180/270）
    property real offsetX: 0            // 水平偏移
    property real offsetY: 0            // 垂直偏移

    // 状态标记
    property bool isImageReady: false   // 图片是否加载完成
    property bool isInteracting: false  // 用户正在进行拖拽或缩放
    property bool isAnimating: false    // 正在执行平滑动画（回弹、复位等）

    // 属性动画（仅在 isAnimating 为 true 时启用）
    Behavior on scaleFactor {
        enabled: root.isAnimating
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }
    Behavior on offsetX {
        enabled: root.isAnimating
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }
    Behavior on offsetY {
        enabled: root.isAnimating
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }

    // 工具函数

    // 判断是否为动画格式（gif/webp/apng），以选择合适的组件节省内存
    function isAnimatedSource(sourceUrl) {
        if (!sourceUrl)
            return false;
        var str = sourceUrl.toString().toLowerCase();
        // 优先检查是否为动画 WebP
        if (imageViewer.isAnimatedWebP)
            return true;
        // image:// 协议的图片忽略
        if (str.indexOf("image://") === 0)
            return false;
        // 检查其他动画格式
        return /\.(gif|apng)$/.test(str);
    }

    function _clamp(v, mi, ma) {
        return Math.max(mi, Math.min(v, ma));
    }

    function showButtons() {
        buttonBar.visible = true;
        autoHideTimer.restart();
    }

    function rotateImage() {
        // 旋转是瞬时操作，禁用平滑动画
        isAnimating = false;
        rotationAngle = (rotationAngle + 90) % 360;
        offsetX = 0;
        offsetY = 0;
        updateImageDisplay();
        showButtons();
    }

    function resetView() {
        enableAnimation();
        rotationAngle = 0;
        offsetX = 0;
        offsetY = 0;
        updateImageDisplay();
        showButtons();
    }

    function zoom(factor) {
        enableAnimation();
        var tempScale = scaleFactor * factor;
        // 缩放范围：[fitScale*0.5, 5.0]
        scaleFactor = _clamp(tempScale, fitScale * 0.5, 5.0);
        constrainOffset();
        showButtons();
    }

    function toggleZoom(centerX, centerY) {
        enableAnimation();
        // 如果未达到目标缩放比例，则放大到 fitScale*2.5；否则恢复初始状态
        if (scaleFactor < fitScale * 1.5 - 0.01) {
            var targetScale = Math.max(fitScale * 2.5, 2.0);
            scaleFactor = targetScale;

            var viewCenterW = root.width / 2;
            var viewCenterH = root.height / 2;
            var clickOffsetX = centerX - viewCenterW;
            var clickOffsetY = centerY - viewCenterH;

            // 调整偏移使点击点保持在屏幕中心
            offsetX = -clickOffsetX * (targetScale / fitScale);
            offsetY = -clickOffsetY * (targetScale / fitScale);
        } else {
            scaleFactor = fitScale;
            offsetX = 0;
            offsetY = 0;
        }
        constrainOffset();
    }

    function enableAnimation() {
        isAnimating = true;
        isInteracting = false;
        disableAnimationTimer.restart();
    }

    Timer {
        id: disableAnimationTimer
        interval: 300
        onTriggered: isAnimating = false
    }

    function updateImageDisplay() {
        const sw = getImageWidth();
        const sh = getImageHeight();
        if (sw <= 0 || sh <= 0)
            return;  // 等待图片尺寸加载完成

        // 计算考虑旋转后的视觉尺寸
        const isRotated = (rotationAngle % 180 === 90);
        const visualImgW = isRotated ? sh : sw;
        const visualImgH = isRotated ? sw : sh;

        // 计算自适应屏幕所需的缩放系数
        const scaleW = root.width / visualImgW;
        const scaleH = root.height / visualImgH;
        let targetFitScale = Math.min(scaleW, scaleH);
        if (targetFitScale > 1.0)
            targetFitScale = 1.0;
        root.fitScale = Math.max(targetFitScale, 0.01);

        // 初次加载或复位时，将缩放因子设为自适应值
        if (!isInteracting && !isAnimating) {
            root.scaleFactor = root.fitScale;
            root.offsetX = 0;
            root.offsetY = 0;
        }
    }

    function constrainOffset() {
        if (!isImageReady)
            return;

        const sw = getImageWidth();
        const sh = getImageHeight();
        const isRotated = (rotationAngle % 180 === 90);
        const visualW = (isRotated ? sh : sw) * scaleFactor;
        const visualH = (isRotated ? sw : sh) * scaleFactor;

        // 限制拖动范围：不允许图片完全离开屏幕
        const limitX = Math.max(0, (visualW - root.width) / 2);
        const limitY = Math.max(0, (visualH - root.height) / 2);

        offsetX = _clamp(offsetX, -limitX, limitX);
        offsetY = _clamp(offsetY, -limitY, limitY);
    }

    function getImageWidth() {
        if (!imageLoader.item)
            return 0;
        // 优先使用原始图片尺寸，否则使用隐式宽度
        if (imageLoader.item.sourceSize && imageLoader.item.sourceSize.width > 0)
            return imageLoader.item.sourceSize.width;
        return imageLoader.item.implicitWidth || 0;
    }

    function getImageHeight() {
        if (!imageLoader.item)
            return 0;
        // 优先使用原始图片尺寸，否则使用隐式高度
        if (imageLoader.item.sourceSize && imageLoader.item.sourceSize.height > 0)
            return imageLoader.item.sourceSize.height;
        return imageLoader.item.implicitHeight || 0;
    }

    function getImageStatus() {
        // 自定义组件默认为 Ready 状态（由 C++ 直接初始化）
        if (imageLoader.item && imageLoader.item.status === undefined)
            return Image.Ready;
        return (imageLoader.item) ? imageLoader.item.status : Image.Null;
    }

    Timer {
        id: autoHideTimer
        interval: 3000
        repeat: false
        onTriggered: buttonBar.visible = false
    }

    // 主视图容器
    Rectangle {
        anchors.fill: parent
        color: "black"

        Item {
            id: imageContainer
            anchors.fill: parent

            // 定义缩放后的图片尺寸（不因旋转而改变）
            property real naturalWidth: root.getImageWidth() * scaleFactor
            property real naturalHeight: root.getImageHeight() * scaleFactor

            Loader {
                id: imageLoader
                width: imageContainer.naturalWidth
                height: imageContainer.naturalHeight

                // 居中显示并应用偏移
                x: (parent.width - width) / 2 + root.offsetX
                y: (parent.height - height) / 2 + root.offsetY

                // 在此层统一处理旋转，绕中心点旋转
                rotation: root.rotationAngle
                transformOrigin: Item.Center

                sourceComponent: isAnimatedSource(imageViewer.source) ? animatedImageComponent : staticImageComponent

                // 监听组件加载完成
                onItemChanged: {
                    if (item && item.implicitWidth > 0) {
                        root.isImageReady = true;
                        root.updateImageDisplay();
                    }
                }

                // 监听异步加载的图片尺寸变化
                Connections {
                    target: imageLoader.item
                    ignoreUnknownSignals: true

                    onImplicitWidthChanged: {
                        if (imageLoader.item && imageLoader.item.implicitWidth > 0) {
                            root.isImageReady = true;
                            root.updateImageDisplay();
                        }
                    }
                    onImplicitHeightChanged: {
                        if (imageLoader.item && imageLoader.item.implicitHeight > 0) {
                            root.isImageReady = true;
                            root.updateImageDisplay();
                        }
                    }
                }
            }

            // 静态图片组件
            Component {
                id: staticImageComponent
                Image {
                    anchors.fill: parent
                    source: imageViewer.source
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            // 动画图片组件（自动选择 WebP 或传统动画格式）
            Component {
                id: animatedImageComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: imageViewer.isWebP ? webpAnimatedComponent : legacyAnimatedComponent
                }
            }

            Component {
                id: webpAnimatedComponent
                WebPAnimatedImage {
                    anchors.fill: parent
                    source: "file://" + imageViewer.fullPath
                    running: !root.isInteracting && root.visible
                }
            }

            Component {
                id: legacyAnimatedComponent
                AnimatedImage {
                    anchors.fill: parent
                    source: imageViewer.source
                    playing: !root.isInteracting && root.visible
                    fillMode: Image.PreserveAspectFit
                }
            }

            // 错误提示
            Text {
                anchors.centerIn: parent
                text: "无法加载图片"
                color: "white"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
                visible: root.getImageStatus() === Image.Error
            }

            // 加载中提示
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: root.getImageStatus() === Image.Loading

                Text {
                    text: "加载中..."
                    color: "white"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                }
            }
        }

        // 触摸交互层
        PinchArea {
            id: pinchArea
            anchors.fill: parent
            enabled: isImageReady

            property real initialScale: 1.0
            property real initialOffsetX: 0
            property real initialOffsetY: 0

            onPinchStarted: {
                root.isInteracting = true;
                root.isAnimating = false;
                initialScale = root.scaleFactor;
                initialOffsetX = root.offsetX;
                initialOffsetY = root.offsetY;
                root.showButtons();
            }

            onPinchUpdated: {
                var tempScale = initialScale * pinch.scale;
                tempScale = _clamp(tempScale, fitScale * 0.5, 10.0);
                root.scaleFactor = tempScale;

                var centerDiffX = pinch.center.x - pinch.startCenter.x;
                var centerDiffY = pinch.center.y - pinch.startCenter.y;
                root.offsetX = initialOffsetX + centerDiffX;
                root.offsetY = initialOffsetY + centerDiffY;
            }

            onPinchFinished: {
                root.isInteracting = false;
                root.enableAnimation();
                if (root.scaleFactor < root.fitScale) {
                    root.scaleFactor = root.fitScale;
                }
                root.constrainOffset();
            }

            MouseArea {
                anchors.fill: parent
                enabled: !pinchArea.pinch.active

                property point lastPos: Qt.point(0, 0)

                onPressed: {
                    root.isInteracting = true;
                    root.isAnimating = false;
                    lastPos = Qt.point(mouse.x, mouse.y);
                    root.showButtons();
                }

                onPositionChanged: {
                    if (pressed && isImageReady) {
                        var deltaX = mouse.x - lastPos.x;
                        var deltaY = mouse.y - lastPos.y;
                        root.offsetX += deltaX;
                        root.offsetY += deltaY;
                        lastPos = Qt.point(mouse.x, mouse.y);
                    }
                }

                onReleased: {
                    root.isInteracting = false;
                    root.enableAnimation();
                    root.constrainOffset();
                    root.showButtons();
                }

                onClicked: {
                    root.showButtons();
                }

                onDoubleClicked: {
                    root.toggleZoom(mouse.x, mouse.y);
                }
            }
        }
    }

    // 控制按钮栏
    Item {
        id: buttonBar
        z: 10
        visible: true
        width: childrenRect.width
        height: 36
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 15

        Rectangle {
            anchors.fill: rowLayout
            anchors.margins: -4
            color: "#60000000"
            radius: 16
        }

        Row {
            id: rowLayout
            spacing: 8

            ImageViewButton {
                text: "+"
                onClicked: root.zoom(1.25)
            }

            ImageViewButton {
                text: "−"
                onClicked: root.zoom(0.8)
            }

            ImageViewButton {
                text: "↻"
                fontSize: 16
                onClicked: root.rotateImage()
            }

            ImageViewButton {
                text: "↺"
                fontSize: 18
                onClicked: root.resetView()
            }
        }
    }

    // 图片查看器按钮组件
    component ImageViewButton: Item {
        property alias text: label.text
        property int fontSize: 20
        signal clicked

        width: 32
        height: 32

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 14
            color: mouseArea.pressed ? "#CC000000" : "transparent"
            border.color: "white"
            border.width: 1

            Text {
                id: label
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                font.pixelSize: parent.parent.fontSize
                color: "white"
                font.bold: true
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    // 标题栏
    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: backButtonClicked()
    }

    onWidthChanged: {
        if (isImageReady)
            updateImageDisplay();
    }
    onHeightChanged: {
        if (isImageReady)
            updateImageDisplay();
    }

    Component.onCompleted: {
        Qt.callLater(function () {
            if (isImageReady) {
                updateImageDisplay();
                showButtons();
            }
        });
    }
}
