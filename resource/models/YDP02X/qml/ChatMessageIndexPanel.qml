import QtQuick 2.12
import com.github.penuniverse 1.0
import "commons"

/*
 * ChatMessageIndexPanel - 当前会话消息索引面板
 * 从右侧滑入显示，列出当前会话的所有消息摘要，点击可导航到对应消息位置
 */
Rectangle {
    id: id_root
    width: 0
    height: parent ? parent.height : 170
    color: YColors.grayNormal
    clip: true
    z: 100
    anchors.right: parent ? parent.right : undefined

    // 面板宽度（动画目标值）
    property real panelWidth: 175
    property var fontFamily
    // 是否正在显示
    property bool isOpen: false
    // 实际聊天 ListModel；索引必须与消息 ListView 的 delegate 索引一致。
    property var messageModel: null
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
        // Build from the exact ListModel used by the chat ListView. Backend history
        // indices diverge when reasoning and grouped tool cards create extra delegates.
        var newPreviews = [];
        if (!messageModel || messageModel.count === undefined) {
            messagePreviews = newPreviews;
            return;
        }

        for (var i = 0; i < messageModel.count; i++) {
            var msg = messageModel.get(i);
            var isUser = msg.isUser === true;
            var isToolCall = msg.isToolCall === true;
            var isReasoning = msg.isReasoning === true;
            var roleLabel = isUser ? "你" : isToolCall ? "工具" : isReasoning ? "推理" : "AI";
            var rawText = msg.raw_text || msg.text || "";
            var preview = rawText.replace(/<[^>]*>/g, "");
            preview = preview.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, "\"");
            preview = preview.replace(/\s+/g, " ").trim();
            if (msg.isThinking && preview.length === 0)
                preview = "正在思考";
            else if (preview.length > 18)
                preview = preview.substring(0, 18) + "...";

            newPreviews.push({
                "index": i,
                "role": roleLabel,
                "preview": preview,
                "isUser": isUser,
                "isToolCall": isToolCall
            });
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
                color: YColors.white
                font.pixelSize: 12
                font.family: id_root.fontFamily || ""
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
                color: closeIndexMouse.pressed ? YColors.graySwitchOff : "transparent"
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "✕"
                    color: YColors.grayText
                    font.pixelSize: 14
                    font.family: id_root.fontFamily || ""
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
            color: YColors.border
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
                color: indexMouse.pressed ? YColors.graySwitchOff : YColors.grayButton

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
                        // 角色标签：用户=状态红，工具调用=grayButton，其余用比条目底更深一档的灰
                        color: modelData.isUser ? YColors.red : modelData.isToolCall ? YColors.grayButton : YColors.grayNormal
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: modelData.role
                            color: YColors.white
                            font.pixelSize: 9
                            font.family: id_root.fontFamily || ""
                            font.bold: true
                            anchors.centerIn: parent
                        }
                    }

                    // 消息预览
                    Text {
                        text: modelData.preview
                        color: YColors.grayText
                        font.pixelSize: 10
                        font.family: id_root.fontFamily || ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
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
