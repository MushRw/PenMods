import QtQuick 2.12
import com.github.penuniverse 1.0

/*
 * ChatMessageIndexPanel - 当前会话消息索引面板
 * 从右侧滑入显示，列出当前会话的所有消息摘要，点击可导航到对应消息位置
 */
Rectangle {
    id: id_root
    width: 0
    height: parent ? parent.height : 170
    color: "#1A2432"
    clip: true
    z: 100
    anchors.right: parent ? parent.right : undefined

    // 面板宽度（动画目标值）
    property real panelWidth: 175
    // 是否正在显示
    property bool isOpen: false
    // 消息摘要列表模型: [{index, role, preview}]
    property var messagePreviews: []
    // 关闭信号
    signal closeRequested
    // 导航到消息索引信号
    signal navigateToMessage(int messageIndex)

    // 动画控制
    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    function open() {
        width = panelWidth;
        isOpen = true;
        refreshPreviews();
    }

    function close() {
        width = 0;
        isOpen = false;
    }

    function toggle() {
        if (isOpen)
            close();
        else
            open();
    }

    function refreshPreviews() {
        // 注意：必须先将所有元素构建到临时数组中，再一次性赋值给属性。
        // 直接 push() 到 messagePreviews 不会触发 QML 的变更通知，
        // 导致 ListView 的 model 无法感知新增数据。
        var newPreviews = [];
        // 通过 chatbot 上下文属性获取当前会话消息
        if (typeof chatbot === 'undefined' || chatbot === null || !chatbot.messages)
            return;
        var msgs = chatbot.messages;
        var displayIndex = 0;
        for (var i = 0; i < msgs.length; i++) {
            var msg = msgs[i];
            var roleLabel, preview, isUser = false, isToolCall = false;

            if (msg.role === 'user') {
                roleLabel = "你";
                isUser = true;
            } else if (msg.role === 'tool') {
                isToolCall = true;
                // 向上查找 tool name
                var tn = "";
                for (var j = i - 1; j >= 0; j--) {
                    var prev = msgs[j];
                    if (prev.role === 'assistant' && prev.toolCallsJson) {
                        try {
                            var tcs = JSON.parse(prev.toolCallsJson);
                            for (var k = 0; k < tcs.length; k++) {
                                if (tcs[k].id === (msg.toolCallId || "")) {
                                    tn = tcs[k]["function"].name || "";
                                    break;
                                }
                            }
                        } catch(e) {}
                        break;
                    }
                }
                roleLabel = tn === "shell_exec" ? "终端" : "搜索";
            } else if (msg.role === 'assistant' && msg.toolCallsJson && msg.toolCallsJson !== "" && (!msg.content || msg.content.trim() === "")) {
                continue;
            } else {
                roleLabel = "AI";
            }

            var rawText = msg.content || "";
            preview = rawText.replace(/<[^>]*>/g, "");
            preview = preview.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, "\"");
            if (isToolCall) {
                preview = roleLabel === "终端" ? "⚙ 命令执行结果" : "🔍 搜索结果";
            } else if (preview.length > 18) {
                preview = preview.substring(0, 18) + "...";
            }
            newPreviews.push({
                "index": displayIndex,
                "role": roleLabel,
                "preview": preview,
                "isUser": isUser,
                "isToolCall": isToolCall
            });
            displayIndex++;
        }
        messagePreviews = newPreviews;
    }

    // 当面板打开时刷新数据
    onIsOpenChanged: {
        if (isOpen)
            refreshPreviews();
    }

    // 面板内容
    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4
        visible: id_root.width > 10

        // 标题栏
        Item {
            width: parent.width
            height: 26

            Text {
                text: "消息索引"
                color: "#FFFFFF"
                font.pixelSize: 12
                font.family: qmlGlobal.fontFamilyZhCn
                font.bold: true
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
            }

            // 关闭按钮
            Rectangle {
                width: 30
                height: 26
                radius: 7
                color: closeIndexMouse.pressed ? "#2B5278" : "transparent"
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "✕"
                    color: "#8899AA"
                    font.pixelSize: 14
                    font.family: qmlGlobal.fontFamilyZhCn
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: closeIndexMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        id_root.closeRequested();
                        id_root.close();
                    }
                }
            }
        }

        // 分割线
        Rectangle {
            width: parent.width
            height: 1
            color: "#2B3A4A"
        }

        // 消息索引列表
        ListView {
            id: indexListView
            width: parent.width
            height: parent.height - 38
            clip: true
            model: messagePreviews
            spacing: 2

            delegate: Rectangle {
                width: indexListView.width
                height: 28
                radius: 6
                color: indexMouse.pressed ? "#253544" : "#182533"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 6
                        rightMargin: 6
                    }
                    spacing: 4

                    // 角色标签
                    Rectangle {
                        width: 22
                        height: 16
                        radius: 3
                        color: modelData.isUser ? "#2B5278" : modelData.isToolCall ? "#1A2E1A" : "#1E3A5F"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: modelData.role
                            color: "#FFFFFF"
                            font.pixelSize: 9
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.bold: true
                            anchors.centerIn: parent
                        }
                    }

                    // 消息预览
                    Text {
                        text: modelData.preview
                        color: "#8899AA"
                        font.pixelSize: 10
                        font.family: qmlGlobal.fontFamilyZhCn
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32
                    }
                }

                MouseArea {
                    id: indexMouse
                    anchors.fill: parent
                    onClicked: {
                        id_root.navigateToMessage(modelData.index);
                        id_root.close();
                    }
                }
            }
        }
    }
}
