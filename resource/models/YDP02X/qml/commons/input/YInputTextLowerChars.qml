import QtQuick 2.12

YInputTextCharsModelBase {
    id: root
    skipPressedAction: true

    // 定义信号
    signal keyClicked(string text)

    // 定义键盘的字符顺序
    property var keyboardLayout: ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]

    Repeater {
        model: parent.keyboardLayout // 绑定上面的数组

        delegate: YInputTextItem {
            // modelData 就是数组里的字符串 "q", "w" 等
            text: modelData

            // 统一处理点击事件
            onClicked: {
                root.keyClicked(text);
            }
        }
    }
}
