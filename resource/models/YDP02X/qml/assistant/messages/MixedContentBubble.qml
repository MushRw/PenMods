import QtQuick 2.12

Column {
    id: root

    property string rawText: ""
    property bool isComplete: false
    property bool serverAvailable: false
    property real maxWidth: 300
    property var fontFamily

    spacing: 6
    width: maxWidth

    property var _blocks: []

    onIsCompleteChanged: {
        if (isComplete)
            _parse();
    }
    onRawTextChanged: {
        if (isComplete)
            _parse();
    }
    Component.onCompleted: {
        if (isComplete)
            _parse();
    }

    // ── 阶段 1：流式加载中，纯文本 ──
    Text {
        visible: !root.isComplete
        width: root.maxWidth
        text: root.rawText
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: "#FFFFFF"
        font.pixelSize: 14
        font.family: root.fontFamily || ""
        lineHeight: 1.3
    }

    // ── 阶段 2：加载完成后 ──
    Repeater {
        model: root.isComplete ? root._blocks : []

        delegate: Loader {
            width: root.maxWidth
            sourceComponent: {
                switch (modelData.type) {
                    case "math_block":  return blockMathComponent;
                    case "code_block":  return codeBlockComponent;
                    case "heading":     return headingComponent;
                    case "list_block":  return listBlockComponent;
                    case "blockquote":  return blockquoteComponent;
                    case "hr":          return hrComponent;
                    case "table":       return tableComponent;
                    default:            return paragraphComponent;
                }
            }

            onLoaded: {
                switch (modelData.type) {
                    case "math_block":
                        item.mContent = modelData.content;
                        break;
                    case "code_block":
                        item.mCode = modelData.content;
                        item.mLanguage = modelData.language || "";
                        break;
                    case "heading":
                        item.mLevel = modelData.level;
                        item.mSegments = modelData.segments;
                        break;
                    case "list_block":
                        item.mItems = modelData.items;
                        item.mOrdered = modelData.ordered || false;
                        break;
                    case "blockquote":
                        item.mSegments = modelData.segments;
                        break;
                    case "hr":
                        break;
                    case "table":
                        item.mHeaders = modelData.headers;
                        item.mRows = modelData.rows;
                        break;
                    default:
                        item.mSegments = modelData.segments;
                        break;
                }
            }
        }
    }

    // 【A】块级公式
    Component {
        id: blockMathComponent
        MathBubble {
            property string mContent: ""
            latex: mContent
            display: true
            serverAvailable: root.serverAvailable
            maxWidth: root.maxWidth
            fontFamily: root.fontFamily
        }
    }

    // 【B】代码块
    Component {
        id: codeBlockComponent
        Rectangle {
            property string mCode: ""
            property string mLanguage: ""

            width: root.maxWidth
            height: codeLabel.implicitHeight + 16
            radius: 6
            color: "#1E1E1E"
            border.color: "#333333"
            border.width: 1

            Text {
                id: codeLabel
                anchors.fill: parent
                anchors.margins: 8
                text: parent.mCode
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: "#D4D4D4"
                font.pixelSize: 12
                font.family: "Courier New, Consolas, monospace"
                lineHeight: 1.4
            }
        }
    }

    // 【C】标题
    Component {
        id: headingComponent
        Flow {
            id: headingFlow
            property int mLevel: 1
            property var mSegments: []
            width: root.maxWidth
            spacing: 2

            Repeater {
                model: mSegments
                delegate: Loader {
                    sourceComponent: modelData.type === "math" ? inlineMathComponent : headingTextComponent
                    onLoaded: {
                        item.mContent = modelData.content;
                        if (item.mLevel !== undefined)
                            item.mLevel = headingFlow.mLevel;
                    }
                }
            }
        }
    }

    // 【C.1】标题文字
    Component {
        id: headingTextComponent
        Text {
            property string mContent: ""
            property int mLevel: 1

            text: _renderMarkdownInline(mContent)
            textFormat: Text.RichText
            width: Math.min(implicitWidth, root.maxWidth)
            wrapMode: Text.Wrap
            color: "#FFFFFF"
            font.pixelSize: _headingSize(mLevel)
            font.bold: true
            font.family: root.fontFamily || ""
            lineHeight: 1.3

            function _headingSize(level) {
                switch (level) {
                    case 1: return 22;
                    case 2: return 18;
                    case 3: return 16;
                    default: return 15;
                }
            }
        }
    }

    // 【D】列表
    Component {
        id: listBlockComponent
        Column {
            id: listBlockRoot
            property var mItems: []
            property bool mOrdered: false
            width: root.maxWidth
            spacing: 4

            Repeater {
                model: mItems
                delegate: Flow {
                    width: root.maxWidth
                    spacing: 4

                    Text {
                        text: listBlockRoot.mOrdered ? (index + 1) + "." : "•"
                        color: "#AAAAAA"
                        font.pixelSize: 14
                        font.family: root.fontFamily || ""
                        width: listBlockRoot.mOrdered ? 20 : 12
                    }

                    Flow {
                        width: root.maxWidth - (listBlockRoot.mOrdered ? 24 : 16)
                        spacing: 4

                        Repeater {
                            model: modelData
                            delegate: Loader {
                                sourceComponent: modelData.type === "math" ? inlineMathComponent : textComponent
                                onLoaded: item.mContent = modelData.content
                            }
                        }
                    }
                }
            }
        }
    }

    // 【E】引用块
    Component {
        id: blockquoteComponent
        Row {
            property var mSegments: []
            width: root.maxWidth
            spacing: 0

            Rectangle {
                width: 3
                height: quoteCol.height
                color: "#555555"
                radius: 1
            }

            Column {
                id: quoteCol
                width: parent.width - 10
                leftPadding: 8

                Repeater {
                    model: parent.parent.mSegments
                    delegate: Loader {
                        width: quoteCol.width - 8
                        sourceComponent: modelData.type === "math" ? inlineMathComponent : quoteTextComponent
                        onLoaded: item.mContent = modelData.content
                    }
                }
            }
        }
    }

    // 【E.1】引用文字
    Component {
        id: quoteTextComponent
        Text {
            property string mContent: ""
            text: _renderMarkdownInline(mContent)
            textFormat: Text.RichText
            width: parent ? parent.width : root.maxWidth
            wrapMode: Text.Wrap
            color: "#AAAAAA"
            font.pixelSize: 14
            font.family: root.fontFamily || ""
            font.italic: true
            lineHeight: 1.3
        }
    }

    // 【F】分割线
    Component {
        id: hrComponent
        Rectangle {
            width: root.maxWidth
            height: 1
            color: "#444444"
        }
    }

    // 【G】表格
    Component {
        id: tableComponent
        Rectangle {
            property var mHeaders: []
            property var mRows: []

            width: root.maxWidth
            height: tableText.implicitHeight + 2
            radius: 4
            color: "#1A1A1A"
            border.color: "#333333"
            border.width: 1

            Text {
                id: tableText
                anchors.fill: parent
                anchors.margins: 4
                text: _tableHtml()
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: "#DDDDDD"
                font.pixelSize: 11
                font.family: root.fontFamily || ""
                lineHeight: 1.2

                function _tableHtml() {
                    var html = '<table border="0" cellpadding="3" cellspacing="0" width="100%">';
                    html += '<tr bgcolor="#2A2A2A">';
                    for (var h = 0; h < mHeaders.length; h++) {
                        html += '<td><font color="#FFFFFF"><b>' + _cellHtml(mHeaders[h]) + '</b></font></td>';
                    }
                    html += '</tr>';
                    for (var r = 0; r < mRows.length; r++) {
                        var bg = (r % 2 === 0) ? '#1E1E1E' : '#222222';
                        html += '<tr bgcolor="' + bg + '">';
                        for (var c = 0; c < mRows[r].length; c++) {
                            html += '<td><font color="#DDDDDD">' + _cellHtml(mRows[r][c]) + '</font></td>';
                        }
                        html += '</tr>';
                    }
                    html += '</table>';
                    return html;
                }

                function _cellHtml(raw) {
                    if (!raw) return "";
                    return root._renderMarkdownInline(raw);
                }
            }
        }
    }

    // 【2】普通段落
    Component {
        id: paragraphComponent
        Flow {
            property var mSegments: []
            width: root.maxWidth
            spacing: 4

            Repeater {
                model: mSegments
                delegate: Loader {
                    sourceComponent: modelData.type === "math" ? inlineMathComponent : textComponent
                    onLoaded: item.mContent = modelData.content
                }
            }
        }
    }

    // 【2.1】行内公式
    Component {
        id: inlineMathComponent
        MathBubble {
            property string mContent: ""
            latex: mContent
            display: false
            serverAvailable: root.serverAvailable
            maxWidth: root.maxWidth
            fontFamily: root.fontFamily
        }
    }

    // 【2.2】文字
    Component {
        id: textComponent
        Text {
            property string mContent: ""
            text: _renderMarkdownInline(mContent)
            textFormat: Text.RichText
            width: Math.min(implicitWidth, root.maxWidth)
            wrapMode: Text.Wrap
            color: "#FFFFFF"
            font.pixelSize: 14
            font.family: root.fontFamily || ""
            lineHeight: 1.3
            linkColor: "#62A8EA"
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ── 行内 Markdown 渲染 ──
    function _renderMarkdownInline(raw) {
        if (!raw || raw.length === 0)
            return "";

        if (typeof chatbot !== "undefined" && chatbot !== null && chatbot.markdownToHtml) {
            var html = chatbot.markdownToHtml(raw);
            if (html && html.length > 0) {
                html = html.replace(/^\s*<p[^>]*>/i, "");
                html = html.replace(/<\/p>\s*$/i, "");
                html = html.replace(/\n/g, "");
                return html;
            }
        }

        var t = raw;

        t = t.replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");

        var codeSpans = [];
        t = t.replace(/`([^`\n]+?)`/g, function(match, code) {
            var ph = "\x00C" + codeSpans.length + "\x00";
            codeSpans.push('<code style="background:#3a3a3a;padding:1px 4px;border-radius:3px;font-family:Consolas,monospace;font-size:12px;color:#E8A0BF">' + code + '</code>');
            return ph;
        });

        t = t.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<a href="$2" style="color:#62A8EA">[$1]</a>');
        t = t.replace(/\[([^\]]+?)\]\(([^)]+?)\)/g, '<a href="$2" style="color:#62A8EA;text-decoration:none">$1</a>');
        t = t.replace(/\*\*\*(.+?)\*\*\*/g, '<b><i>$1</i></b>');
        t = t.replace(/___(.+?)___/g, '<b><i>$1</i></b>');
        t = t.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
        t = t.replace(/__(.+?)__/g, '<b>$1</b>');
        t = t.replace(/\*(.+?)\*/g, '<i>$1</i>');
        t = t.replace(/_(.+?)_/g, '<i>$1</i>');
        t = t.replace(/~~(.+?)~~/g, '<s>$1</s>');
        t = t.replace(/==(.+?)==/g, '<span style="background:#FFFF0033">$1</span>');

        for (var i = 0; i < codeSpans.length; i++) {
            t = t.replace("\x00C" + i + "\x00", codeSpans[i]);
        }

        return t;
    }

    // ── 解析器 ──
    function _parse() {
        var text = rawText;
        if (!text || text.length === 0) {
            _blocks = [];
            return;
        }

        var blocks = [];
        var currentSegments = [];
        var i = 0;
        var textStart = 0;

        function flushParagraph() {
            if (currentSegments.length > 0) {
                blocks.push({ type: "paragraph", segments: currentSegments });
                currentSegments = [];
            }
        }

        function lineEnd(from) {
            var pos = text.indexOf("\n", from);
            return pos === -1 ? text.length : pos;
        }

        function isLineStart(pos) {
            if (pos === 0) return true;
            for (var j = pos - 1; j >= 0; j--) {
                if (text[j] === "\n") return true;
                if (text[j] !== " " && text[j] !== "\t") return false;
            }
            return true;
        }

        while (i < text.length) {

            // ── 1. 围栏代码块 ``` ──
            if (text.substr(i, 3) === "```") {
                var afterTick = i + 3;
                var langEnd = lineEnd(afterTick);
                var lang = text.slice(afterTick, langEnd).trim();
                var codeStart = langEnd + 1;
                var closing = text.indexOf("\n```", codeStart);
                if (closing !== -1) {
                    if (i > textStart) {
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    }
                    flushParagraph();
                    blocks.push({ type: "code_block", content: text.slice(codeStart, closing), language: lang });
                    i = closing + 4;
                    textStart = i;
                    continue;
                }
            }

            // ── 2a. 块级公式 $$ ──
            if (text.substr(i, 2) === "$$") {
                var endD = text.indexOf("$$", i + 2);
                if (endD !== -1) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    blocks.push({ type: "math_block", content: text.slice(i + 2, endD).trim() });
                    i = endD + 2;
                    textStart = i;
                    continue;
                }
            }

            // ── 2b. 块级公式 \[ ──
            if (text.substr(i, 2) === "\\[") {
                var endD2 = text.indexOf("\\]", i + 2);
                if (endD2 !== -1) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    blocks.push({ type: "math_block", content: text.slice(i + 2, endD2).trim() });
                    i = endD2 + 2;
                    textStart = i;
                    continue;
                }
            }

            // ── 行首结构 ──
            if (isLineStart(i)) {
                var le = lineEnd(i);
                var currentLine = text.slice(i, le);

                // ── 3. 标题 ──
                var hm = currentLine.match(/^(#{1,6})\s+(.+)$/);
                if (hm) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    var headingText = hm[2].trim().replace(/\s+#+\s*$/, "");
                    blocks.push({ type: "heading", level: hm[1].length, segments: [{ type: "text", content: headingText }] });
                    i = le + 1;
                    textStart = i;
                    continue;
                }

                // ── 4. 分割线 ──
                if (/^(\*{3,}|-{3,}|_{3,})\s*$/.test(currentLine)) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    blocks.push({ type: "hr" });
                    i = le + 1;
                    textStart = i;
                    continue;
                }

                // ── 5. 引用块 ──
                if (/^>\s?/.test(currentLine)) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    var bqSegs = [];
                    while (i < text.length && isLineStart(i) && /^>\s?/.test(text.slice(i, lineEnd(i)))) {
                        var bqLine = text.slice(i, lineEnd(i));
                        var bqContent = bqLine.replace(/^>\s?/, "").trim();
                        bqSegs.push({ type: "text", content: bqContent.length > 0 ? bqContent : "\n" });
                        i = lineEnd(i) + 1;
                    }
                    textStart = i;
                    if (bqSegs.length > 0)
                        blocks.push({ type: "blockquote", segments: bqSegs });
                    continue;
                }

                // ── 6. 无序列表 ──
                if (/^[\-\*\+]\s+/.test(currentLine)) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    var ulItems = [];
                    while (i < text.length && isLineStart(i)) {
                        var ulLe = lineEnd(i);
                        var ulLine = text.slice(i, ulLe);
                        if (!/^[\-\*\+]\s+/.test(ulLine)) break;
                        ulItems.push([{ type: "text", content: ulLine.replace(/^[\-\*\+]\s+/, "").trim() }]);
                        i = ulLe + 1;
                    }
                    textStart = i;
                    blocks.push({ type: "list_block", ordered: false, items: ulItems });
                    continue;
                }

                // ── 7. 有序列表 ──
                if (/^\d+\.\s+/.test(currentLine)) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    flushParagraph();
                    var olItems = [];
                    while (i < text.length && isLineStart(i)) {
                        var olLe = lineEnd(i);
                        var olLine = text.slice(i, olLe);
                        if (!/^\d+\.\s+/.test(olLine)) break;
                        olItems.push([{ type: "text", content: olLine.replace(/^\d+\.\s+/, "").trim() }]);
                        i = olLe + 1;
                    }
                    textStart = i;
                    blocks.push({ type: "list_block", ordered: true, items: olItems });
                    continue;
                }

                // ── 8. 表格 ──
                if (/^\|/.test(currentLine)) {
                    var tableLines = [];
                    var tableStartIdx = i;
                    while (i < text.length && isLineStart(i) && /^\|/.test(text.slice(i, lineEnd(i)))) {
                        tableLines.push(text.slice(i, lineEnd(i)));
                        i = lineEnd(i) + 1;
                    }

                    if (tableLines.length >= 2) {
                        var headerCells = _parseTableRow(tableLines[0]);
                        var sepCells = _parseTableRow(tableLines[1]);
                        var isSep = true;
                        for (var s = 0; s < sepCells.length; s++) {
                            if (!/^:?-+:?$/.test(sepCells[s])) { isSep = false; break; }
                        }

                        if (isSep && headerCells.length > 0) {
                            if (tableStartIdx > textStart)
                                _appendText(text.slice(textStart, tableStartIdx), currentSegments, flushParagraph);
                            flushParagraph();
                            var dataRows = [];
                            for (var r = 2; r < tableLines.length; r++)
                                dataRows.push(_parseTableRow(tableLines[r]));
                            for (var dr = 0; dr < dataRows.length; dr++) {
                                while (dataRows[dr].length < headerCells.length)
                                    dataRows[dr].push("");
                                dataRows[dr] = dataRows[dr].slice(0, headerCells.length);
                            }
                            blocks.push({ type: "table", headers: headerCells, rows: dataRows });
                            textStart = i;
                            continue;
                        }
                    }

                    _appendText(text.slice(tableStartIdx, i), currentSegments, flushParagraph);
                    textStart = i;
                    continue;
                }
            }

            // ── 9. 行内公式 \( ──
            if (text.substr(i, 2) === "\\(") {
                var endI = text.indexOf("\\)", i + 2);
                if (endI !== -1) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    currentSegments.push({ type: "math", content: text.slice(i + 2, endI).trim() });
                    i = endI + 2;
                    textStart = i;
                    continue;
                }
            }

            // ── 10. 行内公式 $ ──
            if (text[i] === "$" && text.substr(i, 2) !== "$$") {
                if (i + 1 < text.length && text[i + 1] !== " " && text[i + 1] !== "\n") {
                    var endI2 = -1;
                    var sf = i + 1;
                    while (sf < text.length) {
                        var found = text.indexOf("$", sf);
                        if (found === -1) break;
                        if (found + 1 < text.length && text[found + 1] === "$") { sf = found + 2; continue; }
                        if (found > i + 1 && text[found - 1] !== " ") { endI2 = found; break; }
                        sf = found + 1;
                    }
                    if (endI2 !== -1) {
                        if (i > textStart)
                            _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                        currentSegments.push({ type: "math", content: text.slice(i + 1, endI2).trim() });
                        i = endI2 + 1;
                        textStart = i;
                        continue;
                    }
                }
            }

            // ── 11. 行内代码 ` ──
            if (text[i] === "`" && text.substr(i, 3) !== "```") {
                var endC = text.indexOf("`", i + 1);
                if (endC !== -1 && endC > i + 1) {
                    if (i > textStart)
                        _appendText(text.slice(textStart, i), currentSegments, flushParagraph);
                    currentSegments.push({ type: "text", content: text.slice(i, endC + 1) });
                    i = endC + 1;
                    textStart = i;
                    continue;
                }
            }

            i++;
        }

        // 尾部
        if (textStart < text.length)
            _appendText(text.slice(textStart), currentSegments, flushParagraph);
        flushParagraph();

        _blocks = blocks;
    }

    function _parseTableRow(line) {
        var cells = [];
        var trimmed = line.replace(/^\s*\|/, "").replace(/\|\s*$/, "");
        var parts = trimmed.split("|");
        for (var p = 0; p < parts.length; p++)
            cells.push(parts[p].trim());
        return cells;
    }

    function _appendText(text, segments, flushFn) {
        if (!text || text.length === 0) return;
        var lines = text.split(/\r?\n/);
        for (var l = 0; l < lines.length; l++) {
            if (lines[l] !== "")
                segments.push({ type: "text", content: lines[l] });
            if (l < lines.length - 1)
                flushFn();
        }
    }
}
