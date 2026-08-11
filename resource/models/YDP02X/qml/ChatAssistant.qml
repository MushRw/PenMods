import "./commons"
import "./components"
import "./i18n"
import "./settingpages"
import "./audiopages"
import "./assistant/components"
import "./assistant/messages"
import "./assistant/dialogs"
import QtQuick 2.12
import QtGraphicalEffects 1.12
import com.github.penuniverse 1.0

YPage {
    id: id_chat_assistant_page
    objectName: "YPage===ChatAssistant.qml"
    pageIndex: PageIndex.ChatAssistant

    property bool historyLoaded: false
    property string messageContent: ""
    property bool isSearchEnabled: false
    property bool mathServerAvailable: false
    property var keyboardPageRef: null
    property bool isGenerating: false
    property bool captureModeActive: false
    property bool _layoutStabilizing: false
    property bool _preparingSend: false
    property bool _toolCallActive: false
    property int _attachmentReadSeq: 0
    property var _mathProbeRequest: null

    function resetCaptureMode() {
        captureModeActive = false;
        if (typeof cameraCapture !== 'undefined' && cameraCapture !== null)
            cameraCapture.captureEnabled = false;
    }

    function _startMathServer() {
        var serverPath = chatbot.mathServerPath.trim();
        if (serverPath === "") {
            console.log("[MathServer] server_path 未配置，跳过启动");
            return;
        }
        var binName = serverPath.replace(/.*\//, "");
        if (binName === "")
            return;
        var pattern = "[" + binName[0] + "]" + binName.slice(1);
        var running = shell.exec("pgrep -f -- '" + pattern.replace(/'/g, "'\\''") + "'");
        if (running !== "") {
            console.log("[MathServer] 进程已在运行（pid:", running, "），跳过");
            return;
        }
        console.log("[MathServer] 启动服务器：", serverPath);
        shell.startDetached(serverPath);
    }

    Connections {
        target: chatbot
        onMathRenderConfigChanged: {
            if (chatbot.mathRenderEnabled) {
                _startMathServer();
                mathServerProbe.restart();
            } else {
                mathServerProbe.stop();
                if (_mathProbeRequest !== null) {
                    _mathProbeRequest.abort();
                    _mathProbeRequest = null;
                }
                id_chat_assistant_page.mathServerAvailable = false;
            }
        }
    }

    Timer {
        id: mathServerProbe
        interval: 5000
        repeat: true
        running: id_chat_assistant_page.visible && chatbot.mathRenderEnabled && !id_chat_assistant_page.mathServerAvailable
        triggeredOnStart: true
        onTriggered: {
            if (_mathProbeRequest !== null)
                return;
            var xhr = new XMLHttpRequest();
            _mathProbeRequest = xhr;
            xhr.open("GET", "http://127.0.0.1:3000/", true);
            xhr.timeout = 2000;
            xhr.onreadystatechange = function () {
                if (xhr.readyState === XMLHttpRequest.DONE && _mathProbeRequest === xhr) {
                    _mathProbeRequest = null;
                    id_chat_assistant_page.mathServerAvailable = (xhr.status > 0);
                }
            };
            xhr.ontimeout = function () {
                if (_mathProbeRequest === xhr)
                    _mathProbeRequest = null;
                id_chat_assistant_page.mathServerAvailable = false;
            };
            xhr.onerror = xhr.ontimeout;
            try {
                xhr.send();
            } catch (e) {
                if (_mathProbeRequest === xhr)
                    _mathProbeRequest = null;
                id_chat_assistant_page.mathServerAvailable = false;
            }
        }
    }

    ListModel {
        id: attachedFilesModel
    }
    ListModel {
        id: attachedMediaModel
    }

    function clearAttachments() {
        attachedFilesModel.clear();
        attachedMediaModel.clear();
    }

    onVisibleChanged: {
        if (visible) {
            if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
        } else {
            _attachmentReadSeq++;
            _preparingSend = false;
            if (_mathProbeRequest !== null) {
                _mathProbeRequest.abort();
                _mathProbeRequest = null;
            }
            clearAttachments();
            if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                keyBoard.autoSendScan = false;
        }
    }

    function getFileLanguage(filePath) {
        var lowerPath = filePath.toLowerCase();
        if (lowerPath.endsWith(".cpp") || lowerPath.endsWith(".cc") || lowerPath.endsWith(".cxx"))
            return "cpp";
        if (lowerPath.endsWith(".hpp") || lowerPath.endsWith(".hh"))
            return "hpp";
        if (lowerPath.endsWith(".h"))
            return "h";
        if (lowerPath.endsWith(".c"))
            return "c";
        if (lowerPath.endsWith(".py") || lowerPath.endsWith(".python"))
            return "python";
        if (lowerPath.endsWith(".js"))
            return "javascript";
        if (lowerPath.endsWith(".ts") || lowerPath.endsWith(".tsx"))
            return "typescript";
        if (lowerPath.endsWith(".jsx"))
            return "jsx";
        if (lowerPath.endsWith(".html") || lowerPath.endsWith(".htm"))
            return "html";
        if (lowerPath.endsWith(".css"))
            return "css";
        if (lowerPath.endsWith(".json"))
            return "json";
        if (lowerPath.endsWith(".xml") || lowerPath.endsWith(".qml"))
            return "xml";
        if (lowerPath.endsWith(".md") || lowerPath.endsWith(".markdown"))
            return "markdown";
        if (lowerPath.endsWith(".yaml") || lowerPath.endsWith(".yml"))
            return "yaml";
        if (lowerPath.endsWith(".java"))
            return "java";
        if (lowerPath.endsWith(".sh") || lowerPath.endsWith(".bash"))
            return "bash";
        if (lowerPath.endsWith(".cmake") || lowerPath.endsWith("cmakelists.txt"))
            return "cmake";
        if (lowerPath.endsWith(".go"))
            return "go";
        if (lowerPath.endsWith(".rs"))
            return "rust";
        if (lowerPath.endsWith(".lua"))
            return "lua";
        if (lowerPath.endsWith(".sql"))
            return "sql";
        return "";
    }

    function isTextFile(filePath) {
        if (!filePath)
            return false;
        var lowerPath = filePath.toLowerCase();
        var exts = [".txt", ".md", ".json", ".py", ".js", ".ts", ".qml", ".cpp", ".h", ".c", ".java", ".html", ".css", ".xml", ".yaml", ".yml", ".ini", ".log", ".csv"];
        for (var i = 0; i < exts.length; i++) {
            if (lowerPath.endsWith(exts[i]))
                return true;
        }
        return false;
    }

    function readTextFileAsync(filePath, callback) {
        if (!isTextFile(filePath)) {
            callback(null);
            return;
        }
        var fileUrl = filePath.startsWith("file://") ? filePath : "file://" + filePath;
        var xhr = new XMLHttpRequest();
        var completed = false;
        function finish(result) {
            if (completed)
                return;
            completed = true;
            callback(result);
        }
        xhr.open("GET", fileUrl, true);
        xhr.timeout = 5000;
        xhr.onload = function () {
            if (xhr.status === 200 || xhr.status === 0) {
                var text = xhr.responseText;
                if (text.length > 1024 * 1024) {  // 1MB 限制
                    console.warn("文件过大，已忽略:", filePath);
                    finish(null);
                } else {
                    finish(text);
                }
            } else {
                finish(null);
            }
        };
        xhr.onerror = function () {
            finish(null);
        };
        xhr.ontimeout = function () {
            finish(null);
        };
        try {
            xhr.send();
        } catch (e) {
            finish(null);
        }
    }

    function _fileContextText(files) {
        var context = "用户引用了以下文件作为代码审查/分析的上下文：\n\n";
        for (var i = 0; i < files.length; i++) {
            var file = files[i];
            context += "---\n## 文件: " + file.path + "\n```" + file.language + "\n" + file.content + "\n```\n\n";
        }
        return context;
    }

    function openInputPage(placeholder, prefill, onDone) {
        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            let initFunc = function (kp) {
                kp.backButtonClicked.connect(function () {
                    qmlGlobal.inputPageShowing = false;
                    kp.todoDestroy();
                });
                kp.inputFinished.connect(function (input) {
                    qmlGlobal.inputPageShowing = false;
                    if (onDone)
                        onDone(input);
                });
                kp.placeHolderText = placeholder || "";
                if (prefill)
                    kp.enterText(prefill);
                kp.show();
                qmlGlobal.inputPageShowing = true;
            };
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function (s) {
                    if (s === Component.Ready)
                        initFunc(incubator.object);
                };
            } else {
                initFunc(incubator.object);
            }
        }
    }

    function replaceThinkingOrAppend(entry) {
        var last = chatModel.count - 1;
        if (last >= 0 && chatModel.get(last).isThinking) {
            chatModel.remove(last);
            chatModel.insert(last, entry);
        } else {
            chatModel.append(entry);
        }
    }

    function _makeToolCardEntry(toolCallId, toolState, text, rawText, isComplete) {
        return {
            "text": text || "",
            "raw_text": rawText || "",
            "isUser": false,
            "isThinking": false,
            "isComplete": typeof isComplete !== "undefined" ? isComplete : false,
            "isToolCall": true,
            "toolCallId": toolCallId,
            "toolState": toolState,
            "historyIndex": -1
        };
    }

    function updateCardByToolCallId(toolCallId, updates) {
        for (var i = chatModel.count - 1; i >= 0; i--) {
            var item = chatModel.get(i);
            if (item.isToolCall && item.toolCallId === toolCallId) {
                chatModel.remove(i);
                chatModel.insert(i, _makeToolCardEntry(
                    toolCallId,
                    updates.hasOwnProperty("toolState") ? updates.toolState : item.toolState,
                    updates.hasOwnProperty("text") ? updates.text : item.text,
                    updates.hasOwnProperty("raw_text") ? updates.raw_text : item.raw_text,
                    updates.hasOwnProperty("isComplete") ? updates.isComplete : item.isComplete
                ));
                return;
            }
        }
    }

    function _resetStreamState() {
        throttlingTimer.stop();
        generationDoneTimer.stop();
        streamThrottle.content = "";
        streamThrottle.lastIndex = -1;
        streamThrottle.endProcessed = false;
    }

    function _flushStreamBuffer() {
        var index = streamThrottle.lastIndex;
        var content = streamThrottle.content;
        streamThrottle.content = "";
        streamThrottle.lastIndex = -1;
        if (index < 0 || index >= chatModel.count || content === "")
            return -1;

        var item = chatModel.get(index);
        if (item.isUser || item.isToolCall)
            return -1;
        var raw = item.isThinking ? content : (item.raw_text || "") + content;
        chatModel.set(index, {
            "text": raw,
            "raw_text": raw,
            "isThinking": false,
            "isComplete": false
        });
        return index;
    }

    function _scheduleScrollToBottom() {
        if (id_chat_listview.userScrolledUp) {
            id_chat_listview.hasNewMessages = true;
            return;
        }
        if (streamThrottle.scrollScheduled)
            return;
        streamThrottle.scrollScheduled = true;
        Qt.callLater(function () {
            id_chat_listview.scrollToBottom();
            streamThrottle.scrollScheduled = false;
        });
    }

    function _prepareSessionChange() {
        _attachmentReadSeq++;
        _preparingSend = false;
        clearAttachments();
        if (isGenerating && chatbot && typeof chatbot.cancelRequest === "function")
            chatbot.cancelRequest();
        else
            _resetStreamState();
        isGenerating = false;
    }

    function finalizeLastAssistantIfNeeded() {
        throttlingTimer.stop();
        _flushStreamBuffer();
        var lastIdx = chatModel.count - 1;
        if (lastIdx >= 0) {
            var lastItem = chatModel.get(lastIdx);
            if (!lastItem.isUser && !lastItem.isComplete && !lastItem.isThinking && !lastItem.isToolCall) {
                var raw = lastItem.raw_text || "";
                chatModel.set(lastIdx, {
                    "text": chatbot.markdownToHtml(raw),
                    "raw_text": raw,
                    "isComplete": true,
                    "isThinking": false
                });
            }
        }
    }

    ChatToastBanner {
        id: toastBanner
        fontFamily: qmlGlobal.fontFamilyZhCn
    }

    Rectangle {
        anchors.fill: parent
        color: "#0E1621"
        z: -100
    }

    Component.onCompleted: {
        if (historyLoaded)
            return;
        historyLoaded = true;
        loadHistory();
        if (chatbot.mathRenderEnabled)
            _startMathServer();
    }
    Component.onDestruction: {
        _attachmentReadSeq++;
        if (_mathProbeRequest !== null)
            _mathProbeRequest.abort();
        resetCaptureMode();
    }

    function loadHistory() {
        _resetStreamState();
        chatModel.clear();
        if (!chatbot || !chatbot.messages)
            return;
        var history = chatbot.messages;
        var toolNameMap = {};
        for (var i = 0; i < history.length; i++) {
            var msg = history[i];
            if (msg.role === 'assistant' && msg.toolCallsJson) {
                try {
                    var tcs = JSON.parse(msg.toolCallsJson);
                    for (var k = 0; k < tcs.length; k++) {
                        if (tcs[k].id && tcs[k]["function"] && tcs[k]["function"].name)
                            toolNameMap[tcs[k].id] = tcs[k]["function"].name;
                    }
                } catch (e) {}
            }
        }
        for (var idx = 0; idx < history.length; idx++) {
            var m = history[idx];
            if (m.role === 'tool') {
                var toolName = toolNameMap[m.toolCallId] || "";
                var label = toolName === "shell_exec" ? "命令执行结果" : "搜索结果";
                chatModel.append({
                    "text": label,
                    "raw_text": m.content,
                    "isUser": false,
                    "isComplete": true,
                    "isThinking": false,
                    "isToolCall": true,
                    "toolCallId": m.toolCallId || "",
                    "toolState": "done",
                    "historyIndex": idx
                });
                continue;
            }
            if (m.role === 'assistant' && m.toolCallsJson && m.toolCallsJson !== "") {
                if (!m.content || m.content.trim() === "")
                    continue;
            }
            var isUser = m.role === 'user';
            chatModel.append({
                "text": isUser ? m.content : chatbot.markdownToHtml(m.content),
                "isUser": isUser,
                "raw_text": m.content,
                "isComplete": true,
                "isThinking": false,
                "isToolCall": false,
                "toolCallId": "",
                "toolState": "",
                "historyIndex": idx
            });
        }
        _layoutStabilizing = true;
        id_chat_listview.forceLayout();
        id_chat_listview.scrollToBottom();
        id_layout_stabilize_timer.restart();
    }

    function showKeyboard() {
        if (qmlGlobal.inputPageShowing || id_chat_assistant_page.isGenerating || _preparingSend)
            return;
        if (typeof keyBoard !== 'undefined' && keyBoard !== null)
            keyBoard.autoSendScan = false;
        id_session_panel.close();
        id_message_index_panel.close();

        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function (s) {
                    if (s === Component.Ready)
                        id_page_pop_helper.inputPageCreated(incubator.object);
                };
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object);
            }
        }
    }

    function handleUserSend(content) {
        if (_preparingSend || isGenerating)
            return;
        if (!chatbot.isAvailable) {
            toastBanner.error("请先在设置中配置 API 密钥");
            return;
        }

        var mediaParts = [];
        var mediaLabels = [];
        for (var mi = 0; mi < attachedMediaModel.count; mi++) {
            var mediaItem = attachedMediaModel.get(mi);
            mediaLabels.push(mediaItem.label || mediaItem.type);
            if (mediaItem.type === "image_url")
                mediaParts.push({
                    "type": "image_url",
                    "url": mediaItem.url
                });
            else if (mediaItem.type === "input_audio")
                mediaParts.push({
                    "type": "input_audio",
                    "data": mediaItem.data,
                    "format": mediaItem.format
                });
        }

        var hasImageMedia = false;
        for (var miCheck = 0; miCheck < mediaParts.length; miCheck++) {
            if (mediaParts[miCheck].type === "image_url") {
                hasImageMedia = true;
                break;
            }
        }
        if (hasImageMedia && !chatbot.capVision && !chatbot.proxyVisionModelId) {
            toastBanner.warning("当前模型不支持视觉，请在模型设置中配置「视觉代理模型」，本次将仅发送文字");
        }

        // 收集需异步读取的文件
        var fileItems = [];
        for (var fi = 0; fi < attachedFilesModel.count; fi++) {
            var fileItem = attachedFilesModel.get(fi);
            fileItems.push({
                path: fileItem.path,
                name: fileItem.name,
                language: fileItem.language
            });
        }
        clearAttachments();

        function sendMessageInternal(filesArray) {
            _preparingSend = false;
            var displayText = content;
            var filesJson = filesArray.length > 0 ? JSON.stringify(filesArray) : "";

            if (filesArray.length > 0) {
                var names = filesArray.map(function (f) {
                    return f.name;
                }).join(", ");
                displayText = "📎 " + names + "\n\n" + content;
            }
            if (mediaParts.length > 0) {
                displayText = (displayText ? displayText + "\n" : "") + mediaLabels.join(" | ");
            }

            chatModel.append({
                "text": displayText,
                "isUser": true,
                "isComplete": true,
                "isThinking": false,
                "raw_text": content,
                "isToolCall": false,
                "toolCallId": "",
                "toolState": "",
                "historyIndex": -1
            });
            messageContent = "";

            chatModel.append({
                "text": "AI 正在思考...",
                "isUser": false,
                "isThinking": true,
                "isComplete": false,
                "raw_text": "",
                "isToolCall": false,
                "toolCallId": "",
                "toolState": "",
                "historyIndex": -1
            });

            id_chat_assistant_page.isGenerating = true;
            if (mediaParts.length > 0) {
                if (filesArray.length > 0)
                    mediaParts.unshift({
                        "type": "text",
                        "text": _fileContextText(filesArray)
                    });
                chatbot.sendMessageWithMedia(content, JSON.stringify(mediaParts));
            } else {
                chatbot.sendMessage(content, filesJson);
            }

            if (typeof chatbot.getSessions === 'function') {
                var sessionsJson = chatbot.getSessions();
                try {
                    var data = JSON.parse(sessionsJson);
                    var activeId = data.activeSessionId;
                    if (activeId) {
                        var sessions = data.sessions || [];
                        for (var si = 0; si < sessions.length; si++) {
                            if (sessions[si].id === activeId && (sessions[si].messageCount || 0) <= 2) {
                                var autoTitle = content.substring(0, 20);
                                if (content.length > 20)
                                    autoTitle += "...";
                                chatbot.renameSession(activeId, autoTitle);
                                break;
                            }
                        }
                    }
                } catch (e) {}
            }
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
        }

        if (fileItems.length === 0) {
            sendMessageInternal([]);
        } else {
            _preparingSend = true;
            var readSeq = ++_attachmentReadSeq;
            var filesResult = new Array(fileItems.length);
            var pending = fileItems.length;
            for (var i = 0; i < fileItems.length; i++) {
                (function (item, resultIndex) {
                        readTextFileAsync(item.path, function (fileContent) {
                            if (readSeq !== _attachmentReadSeq)
                                return;
                            if (fileContent !== null) {
                                filesResult[resultIndex] = {
                                    path: item.path,
                                    name: item.name,
                                    content: fileContent,
                                    language: item.language
                                };
                            }
                            pending--;
                            if (pending === 0) {
                                var readableFiles = filesResult.filter(function (file) {
                                    return file !== undefined;
                                });
                                sendMessageInternal(readableFiles);
                            }
                        });
                    })(fileItems[i], i);
            }
        }
    }

    function _cppIndex(qmlIndex) {
        var item = chatModel.get(qmlIndex);
        if (item && item.historyIndex !== undefined && item.historyIndex >= 0)
            return item.historyIndex;
        for (var i = qmlIndex - 1; i >= 0; i--) {
            var prev = chatModel.get(i);
            if (prev && prev.historyIndex !== undefined && prev.historyIndex >= 0)
                return prev.historyIndex + (qmlIndex - i);
        }
        return qmlIndex;
    }

    function deleteSingleMessage(index) {
        var cppIndex = _cppIndex(index);
        chatModel.remove(index, 1);
        for (var i = index; i < chatModel.count; i++) {
            var it = chatModel.get(i);
            if (it && it.historyIndex !== undefined && it.historyIndex >= 0)
                chatModel.setProperty(i, "historyIndex", -1);
        }
        if (chatbot && typeof chatbot.deleteMessage === "function")
            chatbot.deleteMessage(cppIndex);
        Qt.callLater(function () {
            id_chat_listview.scrollToBottom();
        });
    }

    function regenerateMessage(index) {
        var cppIndex = _cppIndex(index);
        let countToRemove = chatModel.count - index;
        if (countToRemove > 0)
            chatModel.remove(index, countToRemove);
        chatModel.append({
            "text": "AI 正在重新思考...",
            "raw_text": "",
            "isUser": false,
            "isComplete": false,
            "isThinking": true,
            "isToolCall": false,
            "toolCallId": "",
            "toolState": "",
            "historyIndex": -1
        });
        Qt.callLater(function () {
            id_chat_listview.scrollToBottom();
        });
        if (chatbot && typeof chatbot.regenerateMessage === "function")
            chatbot.regenerateMessage(cppIndex);

        id_chat_assistant_page.isGenerating = true;
    }

    function deleteMessageAndSubsequent(index) {
        var cppIndex = _cppIndex(index);
        let countToRemove = chatModel.count - index;
        if (countToRemove > 0) {
            chatModel.remove(index, countToRemove);
            for (var i = index; i < chatModel.count; i++) {
                var it = chatModel.get(i);
                if (it && it.historyIndex !== undefined && it.historyIndex >= 0)
                    chatModel.setProperty(i, "historyIndex", -1);
            }
            if (chatbot && typeof chatbot.truncateHistory === "function")
                chatbot.truncateHistory(cppIndex);
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
        }
    }

    function navigateToMessageIndex(msgIndex) {
        if (msgIndex < 0 || msgIndex >= chatModel.count)
            return;
        id_chat_listview.positionViewAtIndex(msgIndex, ListView.Beginning);
        id_chat_listview.currentIndex = msgIndex;
        highlightTimer.restart();
    }

    function editMessage(index) {
        var item = chatModel.get(index);
        var cppIndex = _cppIndex(index);
        var oldContent = item.raw_text;
        openInputPage("编辑消息...", oldContent, function (newContent) {
            if (newContent && newContent.trim().length > 0) {
                let countToRemove = chatModel.count - index;
                if (countToRemove > 0)
                    chatModel.remove(index, countToRemove);
                chatModel.append({
                    "text": newContent.trim(),
                    "raw_text": newContent.trim(),
                    "isUser": true,
                    "isComplete": true,
                    "isThinking": false,
                    "isToolCall": false,
                    "toolCallId": "",
                    "toolState": "",
                    "historyIndex": -1
                });
                chatModel.append({
                    "text": "AI 正在思考...",
                    "raw_text": "",
                    "isUser": false,
                    "isComplete": false,
                    "isThinking": true,
                    "isToolCall": false,
                    "toolCallId": "",
                    "toolState": "",
                    "historyIndex": -1
                });
                Qt.callLater(function () {
                    id_chat_listview.scrollToBottom();
                });
                if (chatbot && typeof chatbot.editMessage === "function")
                    chatbot.editMessage(cppIndex, newContent.trim());

                id_chat_assistant_page.isGenerating = true;
            }
        });
    }

    YPagePopHelper {
        id: id_page_pop_helper
        z: 1000
        anchors.fill: parent
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_ChatAssistant.qml"

        function inputPageCreated(keyboardPage) {
            id_chat_assistant_page.keyboardPageRef = keyboardPage;
            keyboardPage.backButtonClicked.connect(function () {
                id_chat_assistant_page.keyboardPageRef = null;
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                    keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
            });
            keyboardPage.inputFinished.connect(function (content) {
                id_chat_assistant_page.keyboardPageRef = null;
                if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                    keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
                if (content && content.trim().length > 0)
                    handleUserSend(content.trim());
            });
            keyboardPage.placeHolderText = "输入消息...";
            keyboardPage.enterText(messageContent);
            keyboardPage.show();
            qmlGlobal.inputPageShowing = true;
        }
    }

    Item {
        id: id_main_content
        anchors.fill: parent
        visible: !qmlGlobal.inputPageShowing
        z: 1

        Rectangle {
            id: id_chat_container
            anchors.fill: parent
            color: "#0E1621"

            ListView {
                id: id_chat_listview
                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 2
                anchors.topMargin: 2
                anchors.bottomMargin: 2

                clip: true
                model: chatModel
                spacing: 10
                cacheBuffer: 200

                add: Transition {
                    enabled: !id_chat_assistant_page.isGenerating && !id_chat_assistant_page._layoutStabilizing
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 150
                    }
                }
                displaced: Transition {
                    enabled: !id_chat_assistant_page.isGenerating && !id_chat_assistant_page._layoutStabilizing
                    NumberAnimation {
                        properties: "y"
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                property bool userScrolledUp: false
                property bool hasNewMessages: false
                property bool _programmaticScroll: false
                property bool _flicking: false
                readonly property real bottomThreshold: 50

                onMovementStarted: {
                    if (!_programmaticScroll)
                        _flicking = true;
                }
                onMovementEnded: {
                    _flicking = false;
                    updateUserScrolledState();
                }
                onContentYChanged: {
                    if (_programmaticScroll)
                        return;
                    if (!_flicking && !moving)
                        return;
                    updateUserScrolledState();
                }

                function updateUserScrolledState() {
                    var distToEnd = contentHeight - contentY - height;
                    userScrolledUp = distToEnd > bottomThreshold;
                    if (!userScrolledUp)
                        hasNewMessages = false;
                }

                function scrollToBottom() {
                    _programmaticScroll = true;
                    positionViewAtEnd();
                    _programmaticScroll = false;
                    userScrolledUp = false;
                    hasNewMessages = false;
                }

                onContentHeightChanged: {
                    if (_layoutStabilizing)
                        id_layout_stabilize_timer.restart();
                }

                footer: Item {
                    height: 16
                    width: parent.width
                }

                Rectangle {
                    width: 120
                    height: 36
                    radius: 18
                    color: "#2B5278"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    opacity: id_chat_listview.hasNewMessages ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    Text {
                        text: "滑到底部"
                        color: "white"
                        font.pixelSize: 14
                        font.family: qmlGlobal.fontFamilyZhCn
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: id_chat_listview.scrollToBottom()
                    }
                }

                delegate: MessageDelegate {
                    text: model.text
                    rawText: model.raw_text
                    isUser: model.isUser
                    isComplete: model.isComplete
                    isThinking: model.isThinking
                    isToolCall: model.isToolCall
                    toolState: model.toolState
                    mathServerAvailable: id_chat_assistant_page.mathServerAvailable
                    messageIndex: model.index
                    listWidth: id_chat_listview.width
                    fontFamily: qmlGlobal.fontFamilyZhCn
                    onLongPressed: id_context_menu.showMenu(globalX, globalY, msgIndex)
                }
            }
        }

        EdgeSwipeGesture {
            edge: "left"
            gestureEnabled: !qmlGlobal.inputPageShowing
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            onTriggered: {
                if (id_session_panel.isOpen)
                    id_session_panel.close();
                else {
                    id_message_index_panel.close();
                    id_session_panel.open();
                }
            }
        }
        EdgeSwipeGesture {
            edge: "right"
            gestureEnabled: !qmlGlobal.inputPageShowing
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            onTriggered: {
                if (id_message_index_panel.isOpen)
                    id_message_index_panel.close();
                else {
                    id_session_panel.close();
                    id_message_index_panel.open();
                }
            }
        }

        Column {
            id: id_empty_state
            anchors.centerIn: parent
            spacing: 10
            visible: chatModel.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "💬"
                font.pixelSize: 40
                font.family: qmlGlobal.fontFamilyZhCn
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "AI 助手"
                font.pixelSize: 15
                color: "#FFFFFF"
                font.family: qmlGlobal.fontFamilyZhCn
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "点击左侧键盘开始对话"
                font.pixelSize: 12
                color: "#5A6B7D"
                font.family: qmlGlobal.fontFamilyZhCn
            }
        }

        YVerticalTitleBar {
            id: id_title_bar
            onCallBack: backButtonClicked()
        }

        Column {
            id: id_column_sidebar
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 10
                bottomMargin: 20
            }
            spacing: 8

            YIconButton {
                width: 28
                height: 28
                radius: 8
                realSource: "qrc:/images/chat/keyboard"
                sourceSize: Qt.size(18, 18)
                color: "#182533"
                border.width: 1
                border.color: "#2B3A4A"
                onValidClicked: showKeyboard()
            }
            YIconButton {
                width: 28
                height: 28
                radius: 8
                realSource: "qrc:/images/chat/more"
                sourceSize: Qt.size(18, 18)
                color: "#182533"
                border.width: 1
                border.color: "#2B3A4A"
                onValidClicked: id_more_menu.show()
            }
            YIconButton {
                width: 28
                height: 28
                radius: 8
                realSource: "qrc:/images/chat/settings"
                sourceSize: Qt.size(18, 18)
                color: "#182533"
                border.width: 1
                border.color: "#2B3A4A"
                onValidClicked: id_pop_container.show("settingpages/ChatAssistantSettings")
            }
        }

        AttachmentChipsBar {
            id: fileChipsBar
            anchors {
                left: id_column_sidebar.right
                leftMargin: 6
                right: parent.right
                rightMargin: 6
                bottom: parent.bottom
                bottomMargin: 6
            }
            filesModel: attachedFilesModel
            mediaModel: attachedMediaModel
            fontFamily: qmlGlobal.fontFamilyZhCn
            visible: attachedFilesModel.count > 0 || attachedMediaModel.count > 0
            z: 100
        }

        Rectangle {
            id: id_stop_button
            width: 28
            height: 28
            radius: 8
            color: "#182533"
            border.width: 1
            border.color: "#2B3A4A"
            visible: id_chat_assistant_page.isGenerating || id_chat_assistant_page._preparingSend
            opacity: visible ? 1.0 : 0.0
            anchors {
                right: parent.right
                rightMargin: 10
                bottom: parent.bottom
                bottomMargin: 20
            }
            z: 100

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Canvas {
                id: stopIcon
                anchors.centerIn: parent
                width: 16
                height: 16
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "#FF6B6B";
                    ctx.fillRect(2, 2, 12, 12);
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (id_chat_assistant_page._preparingSend) {
                        id_chat_assistant_page._attachmentReadSeq++;
                        id_chat_assistant_page._preparingSend = false;
                        toastBanner.warning("已取消发送");
                    } else {
                        chatbot.cancelRequest();
                    }
                }
            }
        }

        MoreMenuPopup {
            id: id_more_menu
            fontFamily: qmlGlobal.fontFamilyZhCn
            tavilyEnabled: chatbot.tavilyEnabled
            tavilyConfigured: chatbot.tavilyConfigured
            onWebSearchToggled: {
                if (!chatbot.tavilyConfigured) {
                    toastBanner.warning("请先在设置中配置 Tavily API Key");
                    return;
                }
                chatbot.tavilyEnabled = !chatbot.tavilyEnabled;
                isSearchEnabled = chatbot.tavilyEnabled;
            }
            onFileReferenceRequested: {
                if (typeof qmlGlobal !== 'undefined' && qmlGlobal !== null) {
                    qmlGlobal.tempFileSelectorConfig = {
                        allowMultiSelect: false,
                        fileExtensions: ["txt", "md", "json", "py", "js", "ts", "qml", "cpp", "h", "c", "java", "html", "css"]
                    };
                }
                id_pop_container.show('audiopages/FileManagerSelector');
            }
            onNewConversationRequested: {
                if (chatbot) {
                    _prepareSessionChange();
                    chatbot.createSession("新对话");
                }
            }
            onAttachImageRequested: {
                captureModeActive = true;
                if (typeof cameraCapture !== 'undefined' && cameraCapture !== null)
                    cameraCapture.captureEnabled = true;
                id_pop_container.show('assistant/dialogs/CapturePreviewPage');
            }
        }

        ChatSessionListPanel {
            id: id_session_panel
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            z: 200

            onSessionSelected: {
                if (typeof chatbot !== 'undefined' && chatbot !== null) {
                    _prepareSessionChange();
                    chatbot.switchSession(sessionId);
                }
            }
            onNewSessionRequested: {
                if (typeof chatbot !== 'undefined' && chatbot !== null) {
                    _prepareSessionChange();
                    chatbot.createSession("新对话");
                }
            }
            onRenameSessionRequested: {
                openInputPage("重命名会话", sessionTitle, function (newTitle) {
                    if (newTitle && newTitle.trim().length > 0 && typeof chatbot !== 'undefined' && chatbot !== null) {
                        chatbot.renameSession(sessionId, newTitle.trim());
                        id_session_panel.refreshSessions();
                    }
                });
            }
            onCloseRequested: close()
        }

        ChatMessageIndexPanel {
            id: id_message_index_panel
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            z: 200

            onNavigateToMessage: navigateToMessageIndex(messageIndex)
            onCloseRequested: close()
        }
    }

    Timer {
        id: highlightTimer
        interval: 1500
        repeat: false
        onTriggered: id_chat_listview.currentIndex = -1
    }

    Timer {
        id: generationDoneTimer
        interval: 200
        repeat: false
        onTriggered: id_chat_assistant_page.isGenerating = false
    }

    Timer {
        id: id_layout_stabilize_timer
        interval: 300
        repeat: false
        onTriggered: {
            if (_layoutStabilizing) {
                id_chat_listview.forceLayout();
                id_chat_listview.scrollToBottom();
                _layoutStabilizing = false;
            }
        }
    }

    YDynamicPageStack {
        id: id_pop_container
        anchors.fill: parent
        z: 500
        visible: popItemObject !== null
        logTag: "ChatAssistant"

        function show(tpage) {
            function restoreAutoSend() {
                if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                    keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
            }
            function newComponentInit(incubatorObject) {
                if (!incubatorObject) {
                    restoreAutoSend();
                    newComponent.destroy();
                    return;
                }

                registerPage(incubatorObject, tpage, {
                    "pageIndex": PageIndex.ChatAssistant,
                    "closeOnHomeRelease": true,
                    "component": newComponent,
                    "cleanups": [restoreAutoSend]
                });
                incubatorObject.show();
            }
            closeSameItem(tpage);
            if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                keyBoard.autoSendScan = false;
            var componentPath = "./%1.qml".arg(tpage);
            var newComponent = Qt.createComponent(componentPath);
            if (newComponent.status === Component.Ready) {
                var incubator = newComponent.incubateObject(id_pop_container);
                if (incubator.status !== Component.Ready) {
                    incubator.onStatusChanged = function (s) {
                        if (s === Component.Ready)
                            newComponentInit(incubator.object);
                        else if (s === Component.Error) {
                            restoreAutoSend();
                            newComponent.destroy();
                        }
                    };
                } else {
                    newComponentInit(incubator.object);
                }
            } else {
                console.error("Component Error: " + newComponent.errorString());
                restoreAutoSend();
                newComponent.destroy();
            }
        }
    }

    ListModel {
        id: chatModel
    }

    QtObject {
        id: streamThrottle
        property string content: ""
        property int lastIndex: -1
        property bool scrollScheduled: false
        property bool endProcessed: false
    }

    Timer {
        id: throttlingTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (_flushStreamBuffer() >= 0)
                _scheduleScrollToBottom();
        }
    }

    Connections {
        target: chatbot
        ignoreUnknownSignals: true

        onMessageReceived: {
            _toolCallActive = false;
            if (isComplete && !streamThrottle.endProcessed) {
                var lastIndex = chatModel.count - 1;
                if (lastIndex >= 0) {
                    var item = chatModel.get(lastIndex);
                    if (!item.isUser && !item.isToolCall) {
                        chatModel.set(lastIndex, {
                            "text": chatbot.markdownToHtml(content),
                            "raw_text": content,
                            "isComplete": true,
                            "isThinking": false
                        });
                    }
                }
                generationDoneTimer.restart();
            }
        }
        onStreamChunk: {
            streamThrottle.endProcessed = false;
            var lastIndex = chatModel.count - 1;
            if (lastIndex < 0)
                return;
            var item = chatModel.get(lastIndex);
            if (item.isUser)
                return;
            if (streamThrottle.lastIndex >= 0 && streamThrottle.lastIndex !== lastIndex)
                _flushStreamBuffer();
            streamThrottle.content += content;
            streamThrottle.lastIndex = lastIndex;
            if (!throttlingTimer.running)
                throttlingTimer.start();
        }
        onStreamStart: {
            _toolCallActive = false;
        }
        onStreamEnd: {
            throttlingTimer.stop();
            _flushStreamBuffer();
            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0) {
                var item = chatModel.get(lastIndex);
                if (!item.isUser && !item.isToolCall) {
                    if (item.isThinking && item.raw_text === "") {
                        return;
                    }
                    var rawContent = item.raw_text;
                    chatModel.set(lastIndex, {
                        "text": chatbot.markdownToHtml(rawContent),
                        "raw_text": rawContent,
                        "isComplete": true,
                        "isThinking": false
                    });
                    _scheduleScrollToBottom();
                }
            }
            if (!_toolCallActive)
                generationDoneTimer.restart();
            streamThrottle.endProcessed = true;
        }
        onErrorOccurred: {
            _resetStreamState();
            _preparingSend = false;
            _toolCallActive = false;
            toastBanner.error(error, 8000);
            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0 && chatModel.get(lastIndex).isThinking)
                chatModel.remove(lastIndex);
            id_chat_assistant_page.isGenerating = false;
        }
        onToolCallReceived: {
            generationDoneTimer.stop();
            finalizeLastAssistantIfNeeded();
            replaceThinkingOrAppend(_makeToolCardEntry("", "done", "⚙️ 调用工具中...", toolCallsJson, true));
        }
        onTavilySearchStarted: {
            generationDoneTimer.stop();
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            finalizeLastAssistantIfNeeded();
            replaceThinkingOrAppend(_makeToolCardEntry(toolCallId, "searching", "正在搜索：" + query, "", false));
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
        }
        onTavilySearchFinished: {
            updateCardByToolCallId(toolCallId, {
                "text": success ? "已完成搜索：" + summary : "搜索失败：" + summary,
                "raw_text": resultText,
                "toolState": success ? "done" : "error",
                "isComplete": true
            });
        }
        onShellCommandPending: {
            generationDoneTimer.stop();
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            finalizeLastAssistantIfNeeded();
            replaceThinkingOrAppend(_makeToolCardEntry(toolCallId, "pending", "请求执行：" + command, command, false));
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
            shellConfirmDialog.show(toolCallId, command);
        }
        onShellCommandStarted: {
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            updateCardByToolCallId(toolCallId, {
                "text": "正在执行...",
                "toolState": "searching"
            });
        }
        onShellCommandFinished: {
            updateCardByToolCallId(toolCallId, {
                "text": success ? "执行完成" : "执行失败：" + summary,
                "raw_text": resultText,
                "toolState": success ? "done" : "error",
                "isComplete": true
            });
        }
        onToolBatchFlushed: {
            generationDoneTimer.stop();
            chatModel.append({
                "text": "AI 正在思考...",
                "raw_text": "",
                "isUser": false,
                "isThinking": true,
                "isComplete": false,
                "isToolCall": false,
                "toolCallId": "",
                "toolState": "",
                "historyIndex": -1
            });
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
        }
        onRequestCancelled: {
            _resetStreamState();
            _toolCallActive = false;
            _attachmentReadSeq++;
            _preparingSend = false;
            var removeIndices = [];
            for (var i = chatModel.count - 1; i >= 0; i--) {
                var item = chatModel.get(i);
                if (item.isThinking) {
                    removeIndices.push(i);
                    continue;
                }
                if (item.isToolCall && !item.isComplete) {
                    updateCardByToolCallId(item.toolCallId, {
                        "text": "已取消",
                        "toolState": "error",
                        "isComplete": true
                    });
                }
            }
            for (var ri = 0; ri < removeIndices.length; ri++)
                chatModel.remove(removeIndices[ri]);
            id_chat_assistant_page.isGenerating = false;
        }
        onSessionSwitched: {
            historyLoaded = false;
            loadHistory();
            historyLoaded = true;
        }
    }

    MessageContextMenu {
        id: id_context_menu
        chatModel: chatModel
        blurSource: id_main_content
        fontFamily: qmlGlobal.fontFamilyZhCn
        onEditRequested: editMessage(index)
        onRegenerateRequested: regenerateMessage(index)
        onDeleteSingleRequested: deleteSingleMessage(index)
        onDeleteSubsequentRequested: deleteMessageAndSubsequent(index)
    }

    ShellConfirmDialog {
        id: shellConfirmDialog
        fontFamily: qmlGlobal.fontFamilyZhCn
        onApproved: chatbot.approveShellCommand(toolCallId)
        onDenied: chatbot.denyShellCommand(toolCallId)
    }

    Connections {
        id: fileSelectorConnections
        target: null
        ignoreUnknownSignals: true

        function onFileSelected(filePath) {
            var fileName = filePath.split('/').pop();
            var language = getFileLanguage(fileName);
            var exists = false;
            for (var i = 0; i < attachedFilesModel.count; i++) {
                if (attachedFilesModel.get(i).path === filePath) {
                    exists = true;
                    break;
                }
            }
            if (!exists)
                attachedFilesModel.append({
                    "path": filePath,
                    "name": fileName,
                    "language": language
                });
        }

    }

    Connections {
        id: capturePreviewConnections
        target: null
        ignoreUnknownSignals: true

        function onCaptureConfirmed(imageBase64) {
            attachedMediaModel.append({
                "type": "image_url",
                "url": "data:image/jpeg;base64," + imageBase64,
                "data": "",
                "format": "",
                "label": "拍摄图片"
            });
            resetCaptureMode();
        }
        function onCaptureCancelled() {
            resetCaptureMode();
        }
    }

    Connections {
        target: id_pop_container
        function onPopItemObjectChanged() {
            if (id_pop_container.popItemObject && typeof id_pop_container.popItemObject.fileSelected !== 'undefined' && typeof id_pop_container.popItemObject.fileSelectionCancelled !== 'undefined')
                fileSelectorConnections.target = id_pop_container.popItemObject;
            else if (id_pop_container.popItemObject && typeof id_pop_container.popItemObject.captureConfirmed !== 'undefined')
                capturePreviewConnections.target = id_pop_container.popItemObject;
            else {
                if (captureModeActive)
                    resetCaptureMode();
                fileSelectorConnections.target = null;
                capturePreviewConnections.target = null;
            }
        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        function onOcrStart() {
            if (typeof keyBoard !== 'undefined' && (keyBoard.autoSendScan || qmlGlobal.inputPageShowing))
                return;
            backButtonClicked();
        }
        function onOcrCompletedResultChanged() {
            if (typeof keyBoard !== 'undefined' && keyBoard.autoSendScan && !qmlGlobal.inputPageShowing && id_chat_assistant_page.visible) {
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
            }
        }
        function onOcrStop(scanType) {
            if (typeof keyBoard !== 'undefined' && keyBoard.autoSendScan && !qmlGlobal.inputPageShowing && id_chat_assistant_page.visible) {
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
            }
        }
    }

    Connections {
        target: keyBoard
        ignoreUnknownSignals: true
        function onAutoSendScanConfigChanged() {
            if (id_chat_assistant_page.visible && typeof keyBoard !== 'undefined' && keyBoard !== null && !qmlGlobal.inputPageShowing)
                keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
        }
        function onScanFinished(content) {
            if (captureModeActive || keyboardPageRef || qmlGlobal.inputPageShowing)
                return;
            if (content && content.trim().length > 0 && id_chat_assistant_page.visible) {
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
                handleUserSend(content.trim());
            }
        }
    }
}
