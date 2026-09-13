import QtQuick 2.12
import com.youdao.pen 1.0

import "../../commons"

YMouseArea {
    id: id_input_text_item

    // 紧凑键盘尺寸：原来 56x46 时一行只排得下 5 个键，26 个字母要 6 行（约 301px），
    // 在 320x170 的屏幕上必须上下滑。现在 28x30，一行 10 个，3 行放完全部字母+功能键。
    width: keyWidth
    height: keyHeight
    property int keyWidth: 28
    property int keyHeight: 30

    objectName: "YInputTextItem.qml_YMouseArea"

    property string text: ""

    // 非空表示这是功能键（backspace/space/enter/switchNumber/switchSymbol/switchLetter），
    // 由 YInputPage 统一处理，不走文本输入。
    property string action: ""

    property bool _isPressAndHoldTriggered: false
    // 标记 onPressed 是否已触发（Flickable 的 pressDelay 可能导致快速点击时 onPressed 被跳过）
    property bool _pressedTriggered: false

    // 用于快速短按（onPressed 被 pressDelay 跳过）时延迟隐藏高亮
    Timer {
        id: _hideHighlightTimer
        interval: 150
        onTriggered: {
            charRelessed()
        }
    }

    function _showHighlight(btnText) {
        _hideHighlightTimer.stop()
        var globalPos = id_input_text_item.mapToItem(id_highlight_item.parent, 0, 0)
        id_highlight_item_content.text = btnText
        // 注意：id_highlight_item.width/height 绑定到 visible 属性，
        // 在此函数被调用时绑定的值尚未重新求值（仍为 0），因此直接使用常量
        // 键盘现在贴在屏幕下沿，最下面一行的放大气泡要夹在屏幕内，否则会被裁掉。
        var host = id_highlight_item.parent
        var maxX = host ? Math.max(host.width - 66, 0) : 10000
        var maxY = host ? Math.max(host.height - 56, 0) : 10000
        id_highlight_item.x = Math.min(Math.max(globalPos.x + id_input_text_item.width / 2 - 33, 0), maxX)
        id_highlight_item.y = Math.min(Math.max(globalPos.y + id_input_text_item.height / 2 - 28, 0), maxY)
    }

    onPressed: {
        _pressedTriggered = true
        _isPressAndHoldTriggered = false
        id_text_item.text = text
        _showHighlight(text)
    }
    onPressAndHold: {
        _isPressAndHoldTriggered = true

        // 长按退格 = 清空（原来这个功能挂在功能键组的退格上，现在键位并进网格）
        if (action === "backspace") {
            charTriggered("", "clear")
            id_text_item.text = text
            return
        }

        var switchedText = text
        switch (qmlGlobal.currentInputStatus) {
        case YEnum.InputStatus.Lower:
            switchedText = text.toUpperCase()
            id_text_item.text = switchedText
            break
        case YEnum.InputStatus.Upper:
            switchedText = text.toLowerCase()
            id_text_item.text = switchedText
            break
        case YEnum.InputStatus.Number:
        case YEnum.InputStatus.Symbol:
        default:
            id_text_item.text = text
            break
        }
        // 长按切换大小写后直接输入；功能键不做这个处理
        if (action.length === 0 && switchedText !== text && !id_input_page.isPinyinMode) {
            charTriggered(switchedText, "")
            id_text_item.text = text
        }
    }
    onReleased: {
        // 如果 onPressed 被 Flickable 的 pressDelay 跳过（快速短按），
        // 需要在 onReleased 中手动显示高亮反馈
        if (!_pressedTriggered) {
            _showHighlight(id_text_item.text)
        }
        // 启动定时器延迟隐藏高亮，确保用户能看到反馈
        _hideHighlightTimer.start()

        // 只有在没有长按触发的情况下，才调用 charTriggered
        if (!_isPressAndHoldTriggered) {
            charTriggered(id_text_item.text, action)
        }
        id_text_item.text = text
        _isPressAndHoldTriggered = false
        _pressedTriggered = false
    }
    onCanceled: {
        _hideHighlightTimer.stop()
        charRelessed()
        id_text_item.text = text
        _isPressAndHoldTriggered = false
        _pressedTriggered = false
    }

    Rectangle {
        id: id_normal_area
        anchors.fill: parent
        radius: 8
        // 按下用 #444444：官方原版（YInputPage 候选词按下态）就是这个值，
        // 之前用 Qt.lighter 算出来的色不在官方色板里。
        color: {
            if (id_input_text_item.pressed) {
                return "#444444"
            }
            return id_input_text_item.action.length > 0 ? YColors.grayButton : YColors.grayNormal
        }
        Behavior on color {
            ColorAnimation {
                duration: 80
            }
        }
    }

    YTextMedium {
        id: id_text_item
        // 多字符标签（abc / 123）在 28px 宽的键里会顶出边框，所以：
        // 1) 多字符缩到 13px（12px 看起来比字母键弱太多）；2) 限制宽度 + 居中 + 溢出省略。
        width: Math.max(id_input_text_item.width - 4, 8)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.pixelSize: id_input_text_item.text.length > 1 ? 13 : 16
        anchors.centerIn: parent
        text: id_input_text_item.text
    }

}
