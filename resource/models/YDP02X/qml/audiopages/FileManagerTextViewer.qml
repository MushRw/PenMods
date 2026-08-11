import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"
import "../assistant/messages"

YBackButtonAudioPage {
    id: id_container_index

    // ── 内容数据 ──
    property variant stringList: {
        var content = (textReader && textReader.content) ? textReader.content : "";
        if (content === "")
            return [];

        if (!textReader.isMarkdown) {
            return content.split(/\r?\n/);
        }
        return [content];
    }

    readonly property real _contentWidth: id_container_index.width - 54 - 10
    property bool _hasMath: {
        if (textReader && textReader.isMarkdown && textReader.content) {
            return textReader.content.indexOf("$$") !== -1 || textReader.content.indexOf("\\(") !== -1;
        }
        return false;
    }

    property bool _mathServerAvailable: false
    property var _blocks: _hasMath ? _parseBlocks(textReader.content || "") : []

    // ── 自动启动数学公式渲染服务器 ──
    function _tryStartMathServer() {
        if (typeof chatbot === "undefined" || chatbot === null)
            return;
        if (!chatbot.mathRenderEnabled)
            return;
        var serverPath = chatbot.mathServerPath.trim();
        if (serverPath === "")
            return;
        // 检查进程是否已在运行
        var binName = serverPath.replace(/.*\//, "");
        var pattern = "[" + binName[0] + "]" + binName.slice(1);
        var running = typeof shell !== "undefined" && shell !== null ? shell.exec("pgrep -f " + pattern) : "";
        if (running !== "")
            return;
        // 启动服务器
        if (typeof shell !== "undefined" && shell !== null) {
            console.log("[MathServer] 文件管理器启动服务器：", serverPath);
            shell.startDetached(serverPath);
        }
    }

    Component.onCompleted: {
        if (_hasMath)
            _tryStartMathServer();
    }

    // ── 数学服务器健康检查 ──
    Timer {
        id: mathServerProbe
        interval: 5000
        repeat: true
        running: _hasMath && !_mathServerAvailable
        triggeredOnStart: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "http://127.0.0.1:3000/", true);
            xhr.timeout = 2000;
            xhr.onreadystatechange = function () {
                if (xhr.readyState === XMLHttpRequest.DONE)
                    _mathServerAvailable = (xhr.status > 0);
            };
            xhr.ontimeout = function () {
                _mathServerAvailable = false;
            };
            try {
                xhr.send();
            } catch (e) {
                _mathServerAvailable = false;
            }
        }
    }

    YVerticalTitleBar {
        id: id_title_bar
        z: 2
        onCallBack: backButtonClicked()
    }

    // ══════════════════════════════════════════
    // 模式 1：纯文本 / 无公式 Markdown
    // ══════════════════════════════════════════
    ListView {
        id: id_content
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        clip: true
        visible: !(textReader && textReader.isMarkdown && _hasMath)

        model: stringList
        spacing: 6

        delegate: Text {
            width: ListView.view.width

            text: model.modelData
            font.pixelSize: 16
            font.family: qmlGlobal.fontFamilyZhCn

            textFormat: textReader.isMarkdown ? Text.MarkdownText : Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: YColors.white

            lineHeight: 1.2
        }

        header: id_header_component

        Component {
            id: id_header_component
            Item {
                width: id_content.width
                height: header_text.implicitHeight + 20

                YTextBase {
                    id: header_text
                    color: YColors.grayText
                    font.pixelSize: 16
                    anchors.centerIn: parent
                    width: parent.width
                    elide: YTextBase.ElideRight
                    text: textReader.title
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    // ══════════════════════════════════════════
    // 模式 2：Markdown 含数学公式
    // ══════════════════════════════════════════
    Flickable {
        id: id_mathContent
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        clip: true
        visible: textReader && textReader.isMarkdown && _hasMath
        contentHeight: id_mathColumn.height + 20

        Column {
            id: id_mathColumn
            width: parent.width
            spacing: 8
            topPadding: 10
            bottomPadding: 10

            // 标题
            YTextBase {
                width: parent.width
                color: YColors.grayText
                font.pixelSize: 16
                elide: YTextBase.ElideRight
                text: textReader.title
                horizontalAlignment: Text.AlignLeft
            }

            Repeater {
                model: _blocks

                delegate: Loader {
                    width: parent.width
                    sourceComponent: modelData.type === "math_block" ? mathBlockComponent : paragraphComponent

                    onLoaded: {
                        if (modelData.type === "math_block") {
                            item.mContent = modelData.content;
                        } else if (modelData.type === "paragraph") {
                            item.mSegments = modelData.segments;
                        }
                    }
                }
            }
        }
    }

    // 块级公式组件
    Component {
        id: mathBlockComponent
        MathBubble {
            property string mContent: ""
            latex: mContent
            display: true
            serverAvailable: _mathServerAvailable
            maxWidth: _contentWidth
            fontFamily: qmlGlobal.fontFamilyZhCn
        }
    }

    // 段落组件（文字 + 行内公式混排）
    Component {
        id: paragraphComponent
        Flow {
            property var mSegments: []
            width: parent ? parent.width : _contentWidth
            spacing: 4

            Repeater {
                model: mSegments
                delegate: Loader {
                    sourceComponent: modelData.type === "math" ? inlineMathComponent : textComponent

                    onLoaded: {
                        item.mContent = modelData.content;
                    }
                }
            }
        }
    }

    // 行内公式组件
    Component {
        id: inlineMathComponent
        MathBubble {
            property string mContent: ""
            latex: mContent
            display: false
            serverAvailable: _mathServerAvailable
            maxWidth: _contentWidth
            fontFamily: qmlGlobal.fontFamilyZhCn
        }
    }

    // 文字组件
    Component {
        id: textComponent
        Text {
            property string mContent: ""
            text: {
                var txt = mContent;
                if (!txt)
                    return "";
                if (typeof chatbot !== "undefined" && chatbot !== null) {
                    var html = chatbot.markdownToHtml(txt);
                    return html.replace(/^\s*<p>/i, "").replace(/<\/p>\s*$/i, "");
                }
                return txt;
            }
            textFormat: Text.RichText
            width: Math.min(implicitWidth, _contentWidth)
            wrapMode: Text.Wrap
            color: YColors.white
            font.pixelSize: 16
            font.family: qmlGlobal.fontFamilyZhCn
            lineHeight: 1.2
            linkColor: "#62A8EA"
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ── 词法解析器：将 Markdown 解析为 blocks ──
    function _parseBlocks(text) {
        if (!text || text.length === 0)
            return [];

        var blocks = [];
        var currentSegments = [];
        var i = 0;
        var textStart = 0;

        function flushParagraph() {
            if (currentSegments.length > 0) {
                blocks.push({
                    type: "paragraph",
                    segments: currentSegments
                });
                currentSegments = [];
            }
        }

        while (i < text.length) {
            var matchStart = -1, matchEnd = -1, matchType = "";

            // 1. 跳过代码块
            if (text.substr(i, 3) === "```") {
                var end = text.indexOf("```", i + 3);
                if (end !== -1) {
                    matchStart = i;
                    matchEnd = end + 3;
                    matchType = "code";
                }
            } else if (text[i] === "`" && text.substr(i, 3) !== "```") {
                var endC = text.indexOf("`", i + 1);
                if (endC !== -1) {
                    matchStart = i;
                    matchEnd = endC + 1;
                    matchType = "code";
                }
            } else
            // 2. 块级公式
            if (text.substr(i, 2) === "$$") {
                var endD = text.indexOf("$$", i + 2);
                if (endD !== -1) {
                    matchStart = i;
                    matchEnd = endD + 2;
                    matchType = "display";
                }
            } else if (text.substr(i, 2) === "\\[") {
                var endD2 = text.indexOf("\\]", i + 2);
                if (endD2 !== -1) {
                    matchStart = i;
                    matchEnd = endD2 + 2;
                    matchType = "display";
                }
            } else
            // 3. 行内公式
            if (text.substr(i, 2) === "\\(") {
                var endI = text.indexOf("\\)", i + 2);
                if (endI !== -1) {
                    matchStart = i;
                    matchEnd = endI + 2;
                    matchType = "inline";
                }
            } else if (text[i] === "$" && text.substr(i, 2) !== "$$") {
                var endI2 = text.indexOf("$", i + 1);
                if (endI2 !== -1 && text.substr(endI2, 2) !== "$$") {
                    matchStart = i;
                    matchEnd = endI2 + 1;
                    matchType = "inline";
                }
            }

            if (matchStart !== -1) {
                // 将符号前积累的普通文字处理掉
                if (matchStart > textStart) {
                    var pre = text.slice(textStart, matchStart);
                    var lines = pre.split(/\r?\n/);
                    for (var l = 0; l < lines.length; l++) {
                        if (lines[l] !== "")
                            currentSegments.push({
                                type: "text",
                                content: lines[l]
                            });
                        if (l < lines.length - 1)
                            flushParagraph();
                    }
                }

                var tokenContent = text.slice(matchStart, matchEnd);
                if (matchType === "code") {
                    currentSegments.push({
                        type: "text",
                        content: tokenContent
                    });
                } else if (matchType === "display") {
                    flushParagraph();
                    var latexD = tokenContent.startsWith("$$") ? tokenContent.slice(2, -2).trim() : tokenContent.slice(2, -2).trim();
                    blocks.push({
                        type: "math_block",
                        content: latexD
                    });
                } else if (matchType === "inline") {
                    var latexI = tokenContent.startsWith("\\(") ? tokenContent.slice(2, -2).trim() : tokenContent.slice(1, -1).trim();
                    currentSegments.push({
                        type: "math",
                        content: latexI
                    });
                }

                i = matchEnd;
                textStart = matchEnd;
            } else {
                i++;
            }
        }

        // 处理尾部文本
        if (textStart < text.length) {
            var rest = text.slice(textStart);
            var rLines = rest.split(/\r?\n/);
            for (var rl = 0; rl < rLines.length; rl++) {
                if (rLines[rl] !== "")
                    currentSegments.push({
                        type: "text",
                        content: rLines[rl]
                    });
                if (rl < rLines.length - 1)
                    flushParagraph();
            }
        }
        flushParagraph();

        return blocks;
    }

    // ══════════════════════════════════════════
    // 共享的滚动条
    // ══════════════════════════════════════════
    Item {
        id: id_scrollbar_track
        anchors.right: parent.right
        anchors.top: id_content.top
        anchors.bottom: id_content.bottom
        width: 4
        visible: {
            var listViewOk = id_content.visible && id_content.visibleArea.heightRatio < 1.0;
            var mathViewOk = id_mathContent.visible && id_mathContent.contentHeight > id_mathContent.height;
            return (listViewOk || mathViewOk) && id_scrollbar_thumb.opacity > 0.01;
        }

        Rectangle {
            id: id_scrollbar_thumb
            width: parent.width
            radius: 2
            color: YColors.grayText ? YColors.grayText : "#808080"
            opacity: 0.7

            height: {
                if (id_content.visible)
                    return Math.max(20, id_scrollbar_track.height * id_content.visibleArea.heightRatio);
                else
                    return Math.max(20, id_scrollbar_track.height * (id_mathContent.height / id_mathContent.contentHeight));
            }
            y: {
                if (id_content.visible)
                    return id_scrollbar_track.height * id_content.visibleArea.yPosition;
                else
                    return id_scrollbar_track.height * (id_mathContent.contentY / id_mathContent.contentHeight);
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }

        Timer {
            id: id_scrollbar_hide_timer
            interval: 2000
            repeat: false
            onTriggered: id_scrollbar_thumb.opacity = 0.0
        }

        function show() {
            id_scrollbar_thumb.opacity = 0.7;
            id_scrollbar_hide_timer.restart();
        }
    }

    Connections {
        target: id_content
        function onContentYChanged() {
            id_scrollbar_track.show();
        }
        function onMovementStarted() {
            id_scrollbar_track.show();
        }
        function onMovementEnded() {
            id_scrollbar_hide_timer.restart();
        }
    }

    Connections {
        target: id_mathContent
        function onContentYChanged() {
            id_scrollbar_track.show();
        }
        function onMovementStarted() {
            id_scrollbar_track.show();
        }
        function onMovementEnded() {
            id_scrollbar_hide_timer.restart();
        }
    }
}
