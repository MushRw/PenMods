import QtQuick 2.12

import "../../commons"

Flow {
    id: id_input_text_chars_model_base_view

    // 一行 10 个键：10 * 28 + 9 * 2 = 298 <= 300
    width: 300
    spacing: 2

    readonly property alias containerItem: id_input_text_chars_model_base_view

    // 输入统一交给 YInputPage 处理（拼音模式要经过 Rime），这里只负责转发。
    signal charEntered(string text)
    signal keyAction(string action)

    function charTriggered(text, action) {
        if (action !== undefined && action !== null && action.length > 0) {
            keyAction(action);
            return;
        }
        charEntered(text);
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
