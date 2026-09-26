import QtQuick 2.12
import "../../commons"

Item {
    id: root
    anchors.fill: parent
    visible: active
    z: 3000

    property string toolCallId: ""
    property string command: ""
    property var fontFamily
    property bool active: false

    property var queue: []

    signal approved(string toolCallId)
    signal denied(string toolCallId)

    function show(tcId, cmd) {
        if (active) {
            queue.push({"toolCallId": tcId, "command": cmd});
            return;
        }
        toolCallId = tcId;
        command = cmd;
        active = true;
    }

    function processNext() {
        if (queue.length > 0) {
            var next = queue.shift();
            toolCallId = next.toolCallId;
            command = next.command;
        } else {
            active = false;
            toolCallId = "";
            command = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: YColors.scrimPanel
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: dialogCard
        width: 290
        height: contentCol.height + 24
        anchors.centerIn: parent
        radius: 16
        color: YColors.grayNormal
        border.width: 1
        border.color: YColors.orange

        Column {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 8

            Text {
                text: root.queue.length > 0
                    ? "AI 请求执行命令 (" + (root.queue.length + 1) + ")"
                    : "AI 请求执行命令"
                color: YColors.orange
                font.pixelSize: 13
                font.bold: true
                font.family: root.fontFamily || ""
            }

            Rectangle {
                width: parent.width
                height: Math.min(cmdText.implicitHeight + 12, 60)
                radius: 8
                // 命令框是嵌在弹窗里的"凹槽"：比弹窗底（grayNormal）更深一档
                color: YColors.black
                border.width: 1
                border.color: YColors.border
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: cmdText.implicitWidth
                    contentHeight: cmdText.implicitHeight
                    clip: true

                    Text {
                        id: cmdText
                        text: root.command
                        color: YColors.white
                        font.pixelSize: 11
                        font.family: "monospace"
                        wrapMode: Text.Wrap
                        width: parent.parent.width - 12
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Rectangle {
                    width: 100; height: 32; radius: 10
                    // 按钮比弹窗底亮一档，才像可以按
                    color: YColors.grayButton
                    border.width: 1; border.color: YColors.red
                    Text {
                        anchors.centerIn: parent
                        text: "拒绝"
                        color: YColors.red
                        font.pixelSize: 13
                        font.family: root.fontFamily || ""
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.denied(root.toolCallId);
                            root.processNext();
                        }
                    }
                }

                Rectangle {
                    width: 100; height: 32; radius: 10
                    color: YColors.grayButton
                    border.width: 1; border.color: YColors.green
                    Text {
                        anchors.centerIn: parent
                        text: "执行"
                        color: YColors.green
                        font.pixelSize: 13
                        font.family: root.fontFamily || ""
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.approved(root.toolCallId);
                            root.processNext();
                        }
                    }
                }
            }
        }
    }
}
