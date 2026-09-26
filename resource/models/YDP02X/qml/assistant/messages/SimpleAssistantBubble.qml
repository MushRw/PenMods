import QtQuick 2.12

Rectangle {
    id: root

    property string rawText: ""
    property bool isComplete: false
    property bool richText: false
    property real maxWidth: 300
    property var fontFamily

    readonly property string renderedText: richText && isComplete && typeof chatbot !== "undefined"
                                        && chatbot !== null ? chatbot.markdownToHtml(rawText) : rawText

    width: Math.min(maxWidth, messageText.implicitWidth + 26)
    height: Math.max(messageText.implicitHeight + 18, 36)
    implicitWidth: width
    implicitHeight: height
    radius: 16
    color: "#182533"
    clip: true

    Text {
        id: messageText
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        anchors.topMargin: 9
        anchors.bottomMargin: 9
        text: root.renderedText
        textFormat: root.richText && root.isComplete ? Text.RichText : Text.PlainText
        wrapMode: Text.WrapAnywhere
        color: "#FFFFFF"
        font.pixelSize: 14
        font.family: root.fontFamily || ""
        lineHeight: 1.3
        linkColor: "#62A8EA"
    }
}
