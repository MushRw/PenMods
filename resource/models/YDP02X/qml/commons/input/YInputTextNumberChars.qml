import QtQuick 2.12

// 数字/常用符号页：3 行 × 10 列。
YInputTextCharsModelBase {
    YInputTextItem { text: "1" }
    YInputTextItem { text: "2" }
    YInputTextItem { text: "3" }
    YInputTextItem { text: "4" }
    YInputTextItem { text: "5" }
    YInputTextItem { text: "6" }
    YInputTextItem { text: "7" }
    YInputTextItem { text: "8" }
    YInputTextItem { text: "9" }
    YInputTextItem { text: "0" }

    YInputTextItem { text: "." }
    YInputTextItem { text: "," }
    YInputTextItem { text: "?" }
    YInputTextItem { text: "!" }
    YInputTextItem { text: "'" }
    YInputTextItem { text: "-" }
    YInputTextItem { text: "/" }
    YInputTextItem { text: ":" }
    YInputTextItem { text: "(" }
    YInputTextItem { text: ")" }

    YInputTextItem { text: "@" }
    YInputTextItem { text: ";" }
    YInputTextItem { text: "\"" }
    YInputTextItem { text: "&" }
    YInputTextItem { text: "*" }
    YInputTextItem { text: "⌫"; action: "backspace" }
    YInputTextItem { text: "空"; action: "space" }
    YInputTextItem { text: "↵"; action: "enter" }
    YInputTextItem { text: "abc"; action: "switchLetter" }
    YInputTextItem { text: "符"; action: "switchSymbol" }
}
