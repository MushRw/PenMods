import QtQuick 2.12
import com.youdao.pen 1.0

import "../../commons"

YMouseArea {
    id: id_input_text_item
    width: 56
    height: 46
    objectName: "YInputTextItem.qml_YMouseArea"

    property string text: ""
    property bool _isPressAndHoldTriggered: false
    // 标记 onPressed 是否已触发（Flickable 的 pressDelay 可能导致快速点击时 onPressed 被跳过）
    property bool _pressedTriggered: false

    // 用于在快速短按（onPressed 被 pressDelay 跳过）时延迟隐藏高亮
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
        // 在此函数调用时绑定的值尚未重新求值（仍为 0），因此直接使用常量
        id_highlight_item.x = globalPos.x + id_input_text_item.width / 2 - 33
        id_highlight_item.y = globalPos.y + id_input_text_item.height / 2 - 28
    }

    onPressed: {
        _pressedTriggered = true
        _isPressAndHoldTriggered = false
        id_text_item.text = text
        _showHighlight(text)
    }
    onPressAndHold: {
        _isPressAndHoldTriggered = true
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
        // 小写键盘（LowerChars）设置了 skipPressedAction，导致 onReleased 中的 charTriggered 被跳过
        // 因此长按切换字母后，需要在 pressAndHold 中直接输入
        if (switchedText !== text && qmlGlobal.currentInputStatus === YEnum.InputStatus.Lower && !id_input_page.isPinyinMode) {
            id_input_text_title_area.enterChar(switchedText)
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
            charTriggered(id_text_item.text)
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
        radius: 12
        color: YColors.grayNormal
    }

    YTextMedium {
        id: id_text_item
        font.pixelSize: 20
        anchors.centerIn: parent
        text: id_input_text_item.text
    }

}
