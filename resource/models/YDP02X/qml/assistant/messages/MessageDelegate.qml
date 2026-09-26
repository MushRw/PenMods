import QtQuick 2.15

Item {
    id: root

    property string text: ""
    property string rawText: ""
    property string reasoningText: ""
    property bool isUser: false
    property bool isComplete: false
    property bool isThinking: false
    property bool isReasoning: false
    property bool isToolCall: false
    property string toolState: ""
    property string attachmentsJson: "[]"
    readonly property var attachments: {
        try {
            return JSON.parse(attachmentsJson || "[]");
        } catch (error) {
            return [];
        }
    }
    property bool mathServerAvailable: false
    property bool textureCacheEnabled: true
    property string renderMode: "full"
    property bool listMoving: false
    property bool navigationJumping: false
    property int messageIndex: -1
    property real listWidth: 320
    property real listContentY: 0
    property real listViewportHeight: 170
    property real richPreloadMargin: 510
    readonly property bool richContentNearViewport:
        y + Math.max(height, 44) >= listContentY - richPreloadMargin
        && y <= listContentY + listViewportHeight + richPreloadMargin
    property var fontFamily
    property bool _pooled: false

    signal longPressed(real globalX, real globalY, int msgIndex)
    signal toolCardExpansionStarted(bool expanding)
    signal richContentCommitStarted(real itemY)
    signal attachmentOpenRequested(string attachmentType, string localPath)

    width: listWidth
    height: messageLoader.height

    Loader {
        id: messageLoader
        width: root.width
        height: item ? item.implicitHeight : 44
        sourceComponent: root.isThinking ? thinkingComponent
                       : root.isReasoning ? reasoningComponent
                       : root.isToolCall ? toolComponent
                       : root.isUser ? userComponent
                       : root.renderMode === "full" ? assistantComponent
                       : simpleAssistantComponent
    }

    Component {
        id: thinkingComponent
        Item {
            implicitWidth: root.width
            implicitHeight: thinkingDots.height + 8

            ThinkingDotsIndicator {
                id: thinkingDots
                isAnimating: true
                anchors.verticalCenter: parent.verticalCenter
                x: 8
            }
        }
    }

    Component {
        id: reasoningComponent
        Item {
            id: reasoningItem
            property bool expanded: false
            property int boundMessageIndex: root.messageIndex
            readonly property bool bodyVisible: expanded
            implicitWidth: root.width

            Component.onCompleted: expanded = !root.isComplete
            onBoundMessageIndexChanged: expanded = !root.isComplete
            implicitHeight: reasoningPanel.height + 8

            Rectangle {
                id: reasoningPanel
                width: Math.min(root.listWidth - 16, 400)
                height: 34 + (reasoningItem.bodyVisible ? 66 : 0)
                x: 8
                radius: 6
                color: "#17222D"
                border.width: 1
                border.color: root.isComplete ? "#2A3947" : "#36546C"
                clip: true

                Rectangle {
                    width: 3
                    height: parent.height
                    color: root.isComplete ? "#526A7D" : "#62A8EA"
                }

                Item {
                    id: reasoningHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 34

                    Rectangle {
                        id: reasoningStatus
                        width: 7
                        height: 7
                        radius: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.isComplete ? "#6F8799" : "#62A8EA"

                        SequentialAnimation on opacity {
                            running: !root.isComplete
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }

                    Text {
                        anchors.left: reasoningStatus.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isComplete ? "推理过程" : "正在推理"
                        color: "#C1D0DC"
                        font.pixelSize: 12
                        font.family: root.fontFamily || ""
                    }

                    Text {
                        anchors.right: reasoningChevron.left
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isComplete ? (reasoningItem.expanded ? "收起" : "查看") : "实时"
                        color: "#6F8799"
                        font.pixelSize: 10
                        font.family: root.fontFamily || ""
                    }

                    Canvas {
                        id: reasoningChevron
                        visible: root.isComplete
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#8297A8";
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            if (reasoningItem.expanded) {
                                ctx.moveTo(2, 8); ctx.lineTo(6, 4); ctx.lineTo(10, 8);
                            } else {
                                ctx.moveTo(2, 4); ctx.lineTo(6, 8); ctx.lineTo(10, 4);
                            }
                            ctx.stroke();
                        }
                        Connections {
                            target: reasoningItem
                            function onExpandedChanged() { reasoningChevron.requestPaint(); }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.isComplete
                        preventStealing: false
                        onClicked: {
                            root.toolCardExpansionStarted(!reasoningItem.expanded);
                            reasoningItem.expanded = !reasoningItem.expanded;
                        }
                    }
                }

                Rectangle {
                    visible: reasoningItem.bodyVisible
                    anchors { left: parent.left; right: parent.right; top: reasoningHeader.bottom; bottom: parent.bottom }
                    anchors.leftMargin: 3
                    color: "#111A23"

                    Flickable {
                        id: reasoningViewport
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        contentWidth: width
                        contentHeight: reasoningText.implicitHeight
                        interactive: root.isComplete && contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        function followLatest() {
                            if (!root.isComplete)
                                contentY = Math.max(0, contentHeight - height);
                        }

                        Text {
                            id: reasoningText
                            width: reasoningViewport.width
                            text: root.rawText
                            color: "#9EB1C0"
                            font.pixelSize: 11
                            font.family: root.fontFamily || ""
                            wrapMode: Text.WrapAnywhere
                            lineHeight: 1.25
                            onImplicitHeightChanged: Qt.callLater(reasoningViewport.followLatest)
                        }

                        onHeightChanged: Qt.callLater(followLatest)
                    }
                }
            }
        }
    }

    Component {
        id: toolComponent
        Item {
            implicitWidth: root.width
            implicitHeight: toolCallCard.height + 8

            ToolCallCard {
                id: toolCallCard
                text: root.text
                rawText: root.rawText
                toolState: root.toolState
                maxWidth: Math.min(root.listWidth - 16, 300)
                fontFamily: root.fontFamily
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                onExpansionStarted: function (expanding) {
                    root.toolCardExpansionStarted(expanding);
                }
            }
        }
    }

    Component {
        id: simpleAssistantComponent
        Item {
            implicitWidth: root.width
            implicitHeight: simpleContent.height + 10

            Column {
                id: simpleContent
                x: 8
                spacing: 8

                AttachmentMessage {
                    attachments: root.attachments
                    fontFamily: root.fontFamily
                    onOpenRequested: function (attachmentType, localPath) {
                        root.attachmentOpenRequested(attachmentType, localPath);
                    }
                    onLongPressed: function (globalX, globalY) {
                        root.longPressed(globalX, globalY, root.messageIndex);
                    }
                }

                SimpleAssistantBubble {
                    id: simpleBubble
                    rawText: root.rawText
                    isComplete: root.isComplete
                    richText: root.renderMode === "basic"
                    maxWidth: Math.min(root.listWidth - 16, 400)
                    fontFamily: root.fontFamily

                    MouseArea {
                        anchors.fill: parent
                        onPressAndHold: {
                            var pos = mapToItem(null, mouseX, mouseY);
                            root.longPressed(pos.x, pos.y, root.messageIndex);
                        }
                    }
                }
            }
        }
    }

    Component {
        id: assistantComponent
        Item {
            id: assistantItem
            implicitWidth: root.width
            implicitHeight: assistantContent.height + 10
            readonly property bool containsMath: root.rawText.indexOf("$") !== -1
                                                 || root.rawText.indexOf("\\(") !== -1
                                                 || root.rawText.indexOf("\\[") !== -1
            readonly property bool textureCacheActive: root.textureCacheEnabled && !root._pooled
                                                       && root.richContentNearViewport
                                                       && root.isComplete && !containsMath
                                                       && mixedBubble.renderReady && aiBubble.height > 0
                                                       && aiBubble.height <= 1024

            Column {
                id: assistantContent
                x: 8
                spacing: 8

                AttachmentMessage {
                    attachments: root.attachments
                    fontFamily: root.fontFamily
                    onOpenRequested: function (attachmentType, localPath) {
                        root.attachmentOpenRequested(attachmentType, localPath);
                    }
                    onLongPressed: function (globalX, globalY) {
                        root.longPressed(globalX, globalY, root.messageIndex);
                    }
                }

            Rectangle {
                id: aiBubble
                width: Math.min(root.listWidth - 16, 400)
                height: mixedBubble.implicitHeight + 18
                radius: 16
                color: "#182533"
                clip: true
                layer.enabled: assistantItem.textureCacheActive
                layer.smooth: false
                layer.mipmap: false

                MixedContentBubble {
                    id: mixedBubble
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    rawText: (root.reasoningText !== ""
                              ? "**推理过程**\n\n" + root.reasoningText + "\n\n**回答**\n\n" : "") + root.rawText
                    isComplete: root.isComplete
                    serverAvailable: root.mathServerAvailable
                    layoutBusy: root.listMoving || root.navigationJumping || !root.richContentNearViewport
                    parseDelay: 16 + Math.abs(root.messageIndex % 4) * 20
                    maxWidth: Math.min(root.listWidth - 44, 372)
                    fontFamily: root.fontFamily
                    onRenderCommitStarted: root.richContentCommitStarted(root.y)
                }

                MouseArea {
                    id: aiMessageGestureArea
                    anchors.fill: parent
                    z: 1
                    onPressAndHold: {
                        var pos = aiMessageGestureArea.mapToItem(null, mouseX, mouseY);
                        root.longPressed(pos.x, pos.y, root.messageIndex);
                    }
                }
            }
            }
        }
    }

    Component {
        id: userComponent
        Item {
            implicitWidth: root.width
            implicitHeight: userContent.height + 10

            Column {
                id: userContent
                width: Math.max(attachmentStrip.implicitWidth, chatBubble.width)
                anchors.right: parent.right
                anchors.rightMargin: 8
                spacing: 8

                AttachmentMessage {
                    id: attachmentStrip
                    anchors.right: parent.right
                    attachments: root.attachments
                    fontFamily: root.fontFamily
                    onOpenRequested: function (attachmentType, localPath) {
                        root.attachmentOpenRequested(attachmentType, localPath);
                    }
                    onLongPressed: function (globalX, globalY) {
                        root.longPressed(globalX, globalY, root.messageIndex);
                    }
                }

                ChatBubble {
                    id: chatBubble
                    text: root.text
                    visible: root.text !== ""
                    isUser: true
                    isComplete: root.isComplete
                    maxBubbleWidth: Math.min(root.listWidth * 0.85, 400)
                    containerWidth: root.listWidth
                    fontFamily: root.fontFamily
                    anchors.right: parent.right
                    onPressAndHold: {
                        var pos = chatBubble.mapToItem(null, mouseX, mouseY);
                        root.longPressed(pos.x, pos.y, root.messageIndex);
                    }
                }
            }
        }
    }

    Timer {
        id: layerRearmTimer
        interval: 16
        repeat: false
        onTriggered: root._pooled = false
    }

    ListView.onPooled: {
        layerRearmTimer.stop();
        root._pooled = true;
    }
    ListView.onReused: {
        root._pooled = true;
        layerRearmTimer.restart();
    }
}
