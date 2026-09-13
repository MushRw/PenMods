import QtQuick 2.12

// 大写字母页：与小写页同样的 3×10 网格（长按字母也能切回小写，见 YInputTextItem）。
YInputTextCharsModelBase {
    YInputTextItem { text: "Q" }
    YInputTextItem { text: "W" }
    YInputTextItem { text: "E" }
    YInputTextItem { text: "R" }
    YInputTextItem { text: "T" }
    YInputTextItem { text: "Y" }
    YInputTextItem { text: "U" }
    YInputTextItem { text: "I" }
    YInputTextItem { text: "O" }
    YInputTextItem { text: "P" }

    YInputTextItem { text: "A" }
    YInputTextItem { text: "S" }
    YInputTextItem { text: "D" }
    YInputTextItem { text: "F" }
    YInputTextItem { text: "G" }
    YInputTextItem { text: "H" }
    YInputTextItem { text: "J" }
    YInputTextItem { text: "K" }
    YInputTextItem { text: "L" }
    YInputTextItem { text: "⌫"; action: "backspace" }

    YInputTextItem { text: "Z" }
    YInputTextItem { text: "X" }
    YInputTextItem { text: "C" }
    YInputTextItem { text: "V" }
    YInputTextItem { text: "B" }
    YInputTextItem { text: "N" }
    YInputTextItem { text: "M" }
    YInputTextItem { text: "空"; action: "space" }
    YInputTextItem { text: "↵"; action: "enter" }
    YInputTextItem { text: "123"; action: "switchNumber" }
}
