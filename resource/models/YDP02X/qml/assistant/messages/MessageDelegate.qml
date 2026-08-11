import QtQuick 2.12

Item {
    id: root

    property string text: ""
    property string rawText: ""
    property bool isUser: false
    property bool isComplete: false
    property bool isThinking: false
    property bool isToolCall: false
    property string toolState: ""
    property bool mathServerAvailable: false
    property int messageIndex: -1
    property real listWidth: 320
    property var fontFamily

    signal longPressed(real globalX, real globalY, int msgIndex)

    width: listWidth
    height: isThinking  ? thinkingDots.height + 8
          : isToolCall  ? toolCallCard.height + 8
          : isUser      ? chatBubble.height + 8
          : mixedBubble.implicitHeight + 26

    ToolCallCard {
        id: toolCallCard
        visible: root.isToolCall
        text: root.text
        rawText: root.rawText
        toolState: root.toolState
        maxWidth: Math.min(root.listWidth - 16, 300)
        fontFamily: root.fontFamily
        x: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    ThinkingDotsIndicator {
        id: thinkingDots
        visible: root.isThinking
        isAnimating: root.isThinking
        anchors.verticalCenter: parent.verticalCenter
        x: 8
    }

    // AI 消息：混合内容渲染（文字 + 数学公式）
    Rectangle {
        visible: !root.isUser && !root.isThinking && !root.isToolCall
        width: Math.min(root.listWidth - 16, 400)
        height: mixedBubble.implicitHeight + 18
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        radius: 16
        color: "#182533"

        MixedContentBubble {
            id: mixedBubble
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            rawText: !root.isUser && !root.isThinking && !root.isToolCall ? root.rawText : ""
            isComplete: root.isComplete
            serverAvailable: root.mathServerAvailable
            maxWidth: Math.min(root.listWidth - 40, 376)
            fontFamily: root.fontFamily
        }
    }

    // 用户消息
    ChatBubble {
        id: chatBubble
        visible: root.isUser
        text: root.text
        isUser: true
        isComplete: root.isComplete
        maxBubbleWidth: Math.min(root.listWidth * 0.85, 400)
        containerWidth: root.listWidth
        fontFamily: root.fontFamily
        anchors.verticalCenter: parent.verticalCenter
        onPressAndHold: {
            var pos = root.mapToItem(null, mouseX, mouseY);
            root.longPressed(pos.x, pos.y, root.messageIndex);
        }
    }

    // 长按手势覆盖 AI 消息气泡
    MouseArea {
        visible: !root.isUser && !root.isThinking && !root.isToolCall
        anchors.fill: parent
        onPressAndHold: {
            var pos = root.mapToItem(null, mouseX, mouseY);
            root.longPressed(pos.x, pos.y, root.messageIndex);
        }
    }
}
