import QtQuick 2.12
import com.youdao.pen 1.0
import "qrc:/qml/commons"

// 符号页：3 行 × 10 列（26 个符号 + 退格/空格/回车/回到字母）。
YInputTextCharsModelBase {
    YInputTextItem { text: "." }
    YInputTextItem { text: "," }
    YInputTextItem { text: "?" }
    YInputTextItem { text: "!" }
    YInputTextItem { text: "'" }
    YInputTextItem { text: "-" }
    YInputTextItem { text: "/" }
    YInputTextItem { text: ":" }
    YInputTextItem { text: ";" }
    YInputTextItem { text: "(" }

    YInputTextItem { text: ")" }
    YInputTextItem { text: "$" }
    YInputTextItem { text: "&" }
    YInputTextItem { text: "@" }
    YInputTextItem { text: "\"" }
    YInputTextItem { text: "[" }
    YInputTextItem { text: "]" }
    YInputTextItem { text: "{" }
    YInputTextItem { text: "}" }
    YInputTextItem { text: "#" }

    YInputTextItem { text: "%" }
    YInputTextItem { text: "^" }
    YInputTextItem { text: "*" }
    YInputTextItem { text: "+" }
    YInputTextItem { text: "=" }
    YInputTextItem { text: "_" }
    YInputTextItem { text: "⌫"; action: "backspace" }
    YInputTextItem { text: "空"; action: "space" }
    YInputTextItem { text: "↵"; action: "enter" }
    YInputTextItem { text: "abc"; action: "switchLetter" }
}
