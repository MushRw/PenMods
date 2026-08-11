import QtQuick 2.12
import "qrc:/qml/commons"

YInputTextCharsModelBase {
    signal enterSpace()

    YInputTextFunctionButton {
        color: YColors.grayNormal
        onClicked: {
            enterSpace()
        }
        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            imageName: "input/ic_space"
        }
    }

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
    YInputTextItem { text: "\\" }
    YInputTextItem { text: "|" }
    YInputTextItem { text: "~" }
    YInputTextItem { text: "<" }
    YInputTextItem { text: ">" }
    YInputTextItem { text: "￥" }
}
