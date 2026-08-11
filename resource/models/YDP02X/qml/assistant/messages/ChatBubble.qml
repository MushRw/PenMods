import QtQuick 2.12

Rectangle {
    id: root

    property string text: ""
    property bool isUser: false
    property bool isComplete: false
    property real maxBubbleWidth: 400
    property real containerWidth: 320
    property var fontFamily

    signal pressAndHold(real mouseX, real mouseY)

    readonly property real targetWidth: Math.min(Math.max(contentText.implicitWidth + (contentText.text.length <= 1 ? 12 : 24), 40), maxBubbleWidth)
    readonly property real targetHeight: Math.max(contentText.implicitHeight + 18, 36)

    width: targetWidth
    height: targetHeight
    x: isUser ? (containerWidth - width - 8) : 8

    radius: 16
    color: isUser ? "#2B5278" : "#182533"

    Behavior on width {
        enabled: !root.isComplete
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: !root.isComplete
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        onPressAndHold: root.pressAndHold(mouseX, mouseY)
    }

    Text {
        id: contentText
        text: root.text
        width: Math.min(implicitWidth, root.maxBubbleWidth - 24)
        anchors.centerIn: parent
        wrapMode: Text.Wrap
        color: "#FFFFFF"
        font.pixelSize: 14
        font.family: root.fontFamily || ""
        lineHeight: 1.3
        horizontalAlignment: Text.AlignLeft
        textFormat: (root.isUser || !root.isComplete) ? Text.PlainText : Text.RichText
        linkColor: "#62A8EA"
    }
}
