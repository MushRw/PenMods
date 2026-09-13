import QtQuick 2.12

// 小写字母页：QWERTY 排布，3 行 × 10 列放完 26 字母 + 4 个功能键（退格/空格/回车/数字符号）。
// 大小写切换沿用「长按字母」的既有行为（见 YInputTextItem.onPressAndHold）。
YInputTextCharsModelBase {
    YInputTextItem { text: "q" }
    YInputTextItem { text: "w" }
    YInputTextItem { text: "e" }
    YInputTextItem { text: "r" }
    YInputTextItem { text: "t" }
    YInputTextItem { text: "y" }
    YInputTextItem { text: "u" }
    YInputTextItem { text: "i" }
    YInputTextItem { text: "o" }
    YInputTextItem { text: "p" }

    YInputTextItem { text: "a" }
    YInputTextItem { text: "s" }
    YInputTextItem { text: "d" }
    YInputTextItem { text: "f" }
    YInputTextItem { text: "g" }
    YInputTextItem { text: "h" }
    YInputTextItem { text: "j" }
    YInputTextItem { text: "k" }
    YInputTextItem { text: "l" }
    YInputTextItem { text: "⌫"; action: "backspace" }

    YInputTextItem { text: "z" }
    YInputTextItem { text: "x" }
    YInputTextItem { text: "c" }
    YInputTextItem { text: "v" }
    YInputTextItem { text: "b" }
    YInputTextItem { text: "n" }
    YInputTextItem { text: "m" }
    YInputTextItem { text: "空格"; action: "space" }
    YInputTextItem { text: "↵"; action: "enter" }
    YInputTextItem { text: "?123"; action: "switchNumber" }
}
