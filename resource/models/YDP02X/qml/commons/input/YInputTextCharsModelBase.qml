import QtQuick 2.12

import "../../commons"

Flow {
    id: id_input_text_chars_model_base_view
    width: 300
    spacing: 5

    readonly property alias containerItem: id_input_text_chars_model_base_view

    property bool skipPressedAction: false // 为了能够区别对待小写字母按钮，我们需要一个判断条件（特定于 qml/commons/input/YInputTextLowerChars.qml）
    function charTriggered(text) {
        if (!skipPressedAction) {
            id_input_text_title_area.enterChar(text);
        }
    }

    function charPressed(text, posX, posY) {
        // 注意：id_highlight_item.width/height 绑定到 visible 属性，
        // 在此函数被调用时绑定的值尚未重新求值（仍为 0），
        // 因此直接使用常量 66/2=33, 56/2=28
        id_highlight_item_content.text = text;
        id_highlight_item.x = posX - 33;
        id_highlight_item.y = posY - 28;
    }

    function charRelessed() {
        id_highlight_item_content.text = "";
    }
}
