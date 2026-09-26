import "./commons"
import "./components"
import "./i18n"
import "./settingpages"
import "./audiopages"
import "./assistant/components"
import "./assistant/messages"
import "./assistant/messages/ChatNavigation.js" as ChatNavigation
import "./assistant/dialogs"
import QtQuick 2.15
import QtGraphicalEffects 1.12
import com.github.penuniverse 1.0

YPage {
    id: id_chat_assistant_page
    objectName: "YPage===ChatAssistant.qml"
    pageIndex: PageIndex.ChatAssistant
    deferHomeCloseUntilLongPress: true

    property bool historyLoaded: false
    property string messageContent: ""
    property bool isSearchEnabled: false
    property bool mathServerAvailable: false
    property bool bubbleTextureCacheEnabled: true
    property var keyboardPageRef: null
    property var _keyboardComponent: null
    property var _keyboardIncubator: null
    property bool _keyboardRequested: false
    property bool isGenerating: false
    property bool captureModeActive: false
    property bool _layoutStabilizing: false
    property bool _preparingSend: false
    property bool _toolCallActive: false
    property int _attachmentReadSeq: 0
    property int _pendingJumpIndex: -1
    property int _navigationTargetIndex: -1
    property bool _navigationJumping: false
    property int _jumpAttempts: 0
    property int _jumpStableFrames: 0
    property int _followAttempts: 0
    property int _followStableFrames: 0
    property real _followLastContentHeight: -1
    property var _mathProbeRequest: null

    function _beginRichContentCommit() {
        if (id_chat_listview.moving)
            return;
        if (id_rich_content_anchor_timer.running)
            return;

        var distanceToBottom = id_chat_listview.contentHeight - id_chat_listview.contentY - id_chat_listview.height;
        if (!id_chat_listview.userScrolledUp && distanceToBottom <= id_chat_listview.bottomThreshold) {
            id_rich_content_anchor_timer.pinBottom = true;
            id_rich_content_anchor_timer.anchorIndex = -1;
            id_rich_content_anchor_timer.beginTracking();
            return;
        }

        var anchorIndex = id_chat_listview.indexAt(4, id_chat_listview.contentY + 1);
        if (anchorIndex < 0)
            anchorIndex = id_chat_listview.indexAt(id_chat_listview.width / 2, id_chat_listview.contentY + 1);
        if (anchorIndex < 0)
            return;
        var anchorItem = id_chat_listview.itemAtIndex(anchorIndex);
        if (!anchorItem)
            return;

        id_rich_content_anchor_timer.pinBottom = false;
        id_rich_content_anchor_timer.anchorIndex = anchorIndex;
        id_rich_content_anchor_timer.anchorOffset = anchorItem.y - id_chat_listview.contentY;
        id_rich_content_anchor_timer.beginTracking();
    }

    function resetCaptureMode() {
        captureModeActive = false;
        if (typeof cameraCapture !== 'undefined' && cameraCapture !== null)
            cameraCapture.captureEnabled = false;
    }

    // 与 FileManagerTextViewer.qml 共用同一个入口：探测与启动都在 C++ 侧做完，
    // 且**不经 shell**（EX-11）。QML 侧不再自己拼命令行。
    function _startMathServer() {
        chatbot.ensureMathServerRunning();
    }

    Connections {
        target: chatbot
        function onMathRenderConfigChanged() {
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
            Qt.callLater(consumePendingVoiceChat);
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
                kp.multiline = true; // KB-29: 聊天/消息编辑是多行输入，↵ 保留换行语义
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

    function _appendAnswerPlaceholder() {
        chatModel.append({
            "text": "",
            "raw_text": "",
            "reasoning_text": "",
            "isUser": false,
            "isThinking": false,
            "isReasoning": false,
            "isComplete": false,
            "isToolCall": false,
            "toolCallId": "",
            "toolState": "",
            "historyIndex": -1
        });
        return chatModel.count - 1;
    }

    function _completeLastReasoningCard() {
        for (var i = chatModel.count - 1; i >= 0; i--) {
            var item = chatModel.get(i);
            if (item.isReasoning && !item.isComplete) {
                _beginRichContentCommit();
                chatModel.setProperty(i, "isComplete", true);
                return;
            }
            if (item.isUser)
                return;
        }
    }

    function _makeReasoningEntry(content) {
        return {
            "text": "",
            "raw_text": content || "",
            "reasoning_text": "",
            "isUser": false,
            "isThinking": false,
            "isReasoning": true,
            "isComplete": false,
            "isToolCall": false,
            "toolCallId": "",
            "toolState": "",
            "historyIndex": -1
        };
    }

    function _makeToolCardEntry(toolCallId, toolState, text, rawText, isComplete, entries) {
        return {
            "text": text || "",
            "raw_text": rawText || "",
            "isUser": false,
            "isThinking": false,
            "isReasoning": false,
            "isComplete": typeof isComplete !== "undefined" ? isComplete : false,
            "isToolCall": true,
            "toolCallId": toolCallId,
            "toolState": toolState,
            "toolEntriesJson": entries ? JSON.stringify(entries) : "",
            "historyIndex": -1
        };
    }

    function _applyToolGroup(index, entries) {
        var completed = 0;
        var hasError = false;
        var activeState = "done";
        var details = [];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (entry.complete)
                completed++;
            if (entry.state === "error")
                hasError = true;
            else if (!entry.complete)
                activeState = entry.state || "searching";
            details.push((i + 1) + ". " + entry.text + (entry.raw ? "\n" + entry.raw : ""));
        }
        var allComplete = completed === entries.length;
        var state = hasError ? "error" : (allComplete ? "done" : activeState);
        var title = entries.length === 1 ? entries[0].text
                                        : "工具调用 " + entries.length + " 项 · " + completed + " 已完成";
        chatModel.set(index, {
            "text": title,
            "raw_text": details.join("\n\n"),
            "toolState": state,
            "isComplete": allComplete,
            "toolCallId": entries.length > 0 ? entries[0].id : "",
            "toolEntriesJson": JSON.stringify(entries)
        });
    }

    function _upsertToolEntry(toolCallId, text, rawText, toolState, isComplete) {
        var groupIndex = -1;
        var entries = [];
        for (var searchIndex = chatModel.count - 1; searchIndex >= 0; searchIndex--) {
            var candidate = chatModel.get(searchIndex);
            if (candidate.isUser)
                break;
            if (!candidate.isToolCall || !candidate.toolEntriesJson)
                continue;
            var candidateEntries;
            try { candidateEntries = JSON.parse(candidate.toolEntriesJson); } catch (e) { candidateEntries = []; }
            for (var candidateIndex = 0; candidateIndex < candidateEntries.length; candidateIndex++) {
                if (candidateEntries[candidateIndex].id === toolCallId) {
                    groupIndex = searchIndex;
                    entries = candidateEntries;
                    break;
                }
            }
            if (groupIndex >= 0)
                break;
        }
        if (groupIndex < 0 && chatModel.count > 0) {
            var last = chatModel.get(chatModel.count - 1);
            if (last.isToolCall && last.toolEntriesJson) {
                groupIndex = chatModel.count - 1;
                try { entries = JSON.parse(last.toolEntriesJson); } catch (e) { entries = []; }
            }
        }
        if (groupIndex < 0) {
            entries = [];
            replaceThinkingOrAppend(_makeToolCardEntry("", toolState, text, rawText, isComplete, entries));
            groupIndex = chatModel.count - 1;
        }

        var entryIndex = -1;
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].id === toolCallId) {
                entryIndex = i;
                break;
            }
        }
        var entry = { "id": toolCallId, "text": text || "工具调用", "raw": rawText || "",
                      "state": toolState || "searching", "complete": !!isComplete };
        if (entryIndex >= 0)
            entries[entryIndex] = entry;
        else
            entries.push(entry);
        _applyToolGroup(groupIndex, entries);
    }

    function updateCardByToolCallId(toolCallId, updates) {
        for (var i = chatModel.count - 1; i >= 0; i--) {
            var item = chatModel.get(i);
            if (!item.isToolCall)
                continue;
            if (item.toolEntriesJson) {
                var entries;
                try { entries = JSON.parse(item.toolEntriesJson); } catch (e) { entries = []; }
                for (var j = 0; j < entries.length; j++) {
                    if (entries[j].id !== toolCallId)
                        continue;
                    if (updates.hasOwnProperty("toolState")) entries[j].state = updates.toolState;
                    if (updates.hasOwnProperty("text")) entries[j].text = updates.text;
                    if (updates.hasOwnProperty("raw_text")) entries[j].raw = updates.raw_text;
                    if (updates.hasOwnProperty("isComplete")) entries[j].complete = updates.isComplete;
                    _applyToolGroup(i, entries);
                    return;
                }
            }
            if (item.toolCallId === toolCallId) {
                chatModel.setProperty(i, "toolState", updates.hasOwnProperty("toolState") ? updates.toolState : item.toolState);
                chatModel.setProperty(i, "text", updates.hasOwnProperty("text") ? updates.text : item.text);
                chatModel.setProperty(i, "raw_text", updates.hasOwnProperty("raw_text") ? updates.raw_text : item.raw_text);
                chatModel.setProperty(i, "isComplete", updates.hasOwnProperty("isComplete") ? updates.isComplete : item.isComplete);
                return;
            }
        }
    }

    function _findCurrentAnswerIndex() {
        for (var i = chatModel.count - 1; i >= 0; i--) {
            var item = chatModel.get(i);
            if (item.isUser)
                return -1;
            if (!item.isToolCall && !item.isReasoning && !item.isThinking && !item.isComplete)
                return i;
        }
        return -1;
    }

    function _resetStreamState() {
        throttlingTimer.stop();
        generationDoneTimer.stop();
        streamThrottle.content = "";
        streamThrottle.lastIndex = -1;
        streamThrottle.targetKind = "";
        streamThrottle.endProcessed = false;
    }

    function _flushStreamBuffer() {
        var index = streamThrottle.lastIndex;
        var content = streamThrottle.content;
        var targetKind = streamThrottle.targetKind;
        streamThrottle.content = "";
        streamThrottle.lastIndex = -1;
        streamThrottle.targetKind = "";
        if (content === "")
            return -1;

        var item = index >= 0 && index < chatModel.count ? chatModel.get(index) : null;
        var targetStillValid = item && !item.isUser && !item.isToolCall && !item.isReasoning && !item.isComplete
                               && (targetKind === "" || (targetKind === "thinking" && item.isThinking)
                                   || (targetKind === "answer" && !item.isThinking));
        if (!targetStillValid) {
            // The thinking row can be removed when a delayed reasoning chunk arrives.
            // Never write the buffered answer into the row now occupying its old index.
            index = _findCurrentAnswerIndex();
            if (index < 0) {
                _appendAnswerPlaceholder();
                index = chatModel.count - 1;
            }
            item = chatModel.get(index);
        }

        var raw = item.isThinking ? content : (item.raw_text || "") + content;
        chatModel.set(index, {
            "text": raw,
            "raw_text": raw,
            "isUser": false,
            "isThinking": false,
            "isReasoning": false,
            "isToolCall": false,
            "isComplete": false,
            "toolCallId": "",
            "toolState": "",
            "historyIndex": -1
        });
        return index;
    }

    function _followLatestMessage() {
        _followAttempts = 0;
        _followStableFrames = 0;
        _followLastContentHeight = -1;
        id_chat_listview.userScrolledUp = false;
        id_chat_listview.hasNewMessages = false;
        id_chat_listview.scrollToBottom();
        id_follow_latest_timer.restart();
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
            id_chat_listview.scrollToBottom(true);
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
                    "text": "",
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
        color: YColors.black
        z: -100
    }

    Component.onCompleted: {
        _ensureKeyboardPage(false);
        if (historyLoaded)
            return;
        historyLoaded = true;
        loadHistory();
        if (chatbot.mathRenderEnabled)
            _startMathServer();
        Qt.callLater(consumePendingVoiceChat);
    }
    Component.onDestruction: {
        _attachmentReadSeq++;
        if (_mathProbeRequest !== null)
            _mathProbeRequest.abort();
        resetCaptureMode();
    }

    function consumePendingVoiceChat() {
        var text = mod.pendingVoiceChatText.trim();
        if (text.length === 0 || _preparingSend || isGenerating)
            return;
        mod.pendingVoiceChatText = "";
        handleUserSend(text);
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
            if (m.role === 'system')
                continue;
            if (m.role === 'tool') {
                var toolName = toolNameMap[m.toolCallId] || "";
                var label = toolName === "shell_exec" ? "命令执行结果" : "搜索结果";
                _upsertToolEntry(m.toolCallId || "", label, m.content, "done", true);
                chatModel.setProperty(chatModel.count - 1, "historyIndex", idx);
                continue;
            }
            if (m.role === 'assistant' && m.reasoning) {
                chatModel.append(_makeReasoningEntry(m.reasoning));
                chatModel.setProperty(chatModel.count - 1, "isComplete", true);
            }
            if (m.role === 'assistant' && m.toolCallsJson && m.toolCallsJson !== "") {
                if (!m.content || m.content.trim() === "")
                    continue;
            }
            var isUser = m.role === 'user';
            var messageAttachments = [];
            var messageParts = m.parts || [];
            for (var partIndex = 0; partIndex < messageParts.length; partIndex++) {
                if (messageParts[partIndex].type === "image_url" || messageParts[partIndex].type === "file")
                    messageAttachments.push(messageParts[partIndex]);
            }
            chatModel.append({
                "text": isUser ? m.content : "",
                "attachmentsJson": JSON.stringify(messageAttachments),
                "isUser": isUser,
                "raw_text": m.content,
                "reasoning_text": "",
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
        id_chat_listview.scrollToTop();
        id_layout_stabilize_timer.restart();
    }

    function _showCachedKeyboard() {
        if (!keyboardPageRef)
            return;
        _keyboardRequested = false;
        keyboardPageRef.placeHolderText = "输入消息...";
        keyboardPageRef.resetInput(messageContent);
        keyboardPageRef.show();
        qmlGlobal.inputPageShowing = true;
    }

    function _initializeKeyboardPage(keyboardPage) {
        keyboardPageRef = keyboardPage;
        keyboardPage.multiline = true; // KB-29: 聊天输入多行，↵ 保留换行语义
        keyboardPage.backButtonClicked.connect(function () {
            qmlGlobal.inputPageShowing = false;
            if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
        });
        keyboardPage.inputFinished.connect(function (content) {
            if (typeof keyBoard !== 'undefined' && keyBoard !== null)
                keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
            if (content && content.trim().length > 0)
                handleUserSend(content.trim());
        });
        if (_keyboardRequested)
            _showCachedKeyboard();
    }

    function _ensureKeyboardPage(showWhenReady) {
        if (showWhenReady)
            _keyboardRequested = true;
        if (keyboardPageRef) {
            if (_keyboardRequested)
                _showCachedKeyboard();
            return;
        }
        if (_keyboardComponent !== null || _keyboardIncubator !== null)
            return;

        var component = Qt.createComponent("qrc:/qml/YInputPage.qml", Component.Asynchronous);
        _keyboardComponent = component;
        function incubateKeyboard() {
            if (_keyboardComponent !== component || component.status !== Component.Ready)
                return;
            var incubator = component.incubateObject(id_page_pop_helper.containerItem,
                                                     { "visible": false, "destroyOnBack": false },
                                                     Qt.Asynchronous);
            _keyboardIncubator = incubator;
            function keyboardReady() {
                if (incubator.status === Component.Ready) {
                    _keyboardIncubator = null;
                    _keyboardComponent = null;
                    _initializeKeyboardPage(incubator.object);
                    component.destroy();
                } else if (incubator.status === Component.Error) {
                    _keyboardIncubator = null;
                    _keyboardComponent = null;
                    component.destroy();
                }
            }
            if (incubator.status === Component.Ready)
                keyboardReady();
            else
                incubator.onStatusChanged = keyboardReady;
        }
        if (component.status === Component.Ready)
            incubateKeyboard();
        else if (component.status === Component.Loading)
            component.statusChanged.connect(incubateKeyboard);
        else
            _keyboardComponent = null;
    }

    function showKeyboard() {
        if (qmlGlobal.inputPageShowing || id_chat_assistant_page.isGenerating || _preparingSend)
            return;
        if (typeof keyBoard !== 'undefined' && keyBoard !== null)
            keyBoard.autoSendScan = false;
        id_session_panel.close();
        id_message_index_panel.close();
        _ensureKeyboardPage(true);
    }

    function handleUserSend(content) {
        if (_preparingSend || isGenerating)
            return;
        if (!chatbot.isAvailable) {
            toastBanner.error("请先在设置中配置 API 密钥");
            return;
        }

        var mediaParts = [];
        for (var mi = 0; mi < attachedMediaModel.count; mi++) {
            var mediaItem = attachedMediaModel.get(mi);
            if (mediaItem.type === "image_url")
                mediaParts.push({
                    "type": "image_url",
                    "url": mediaItem.url,
                    "label": mediaItem.label || "图片"
                });
            else if (mediaItem.type === "input_audio")
                mediaParts.push({
                    "type": "input_audio",
                    "data": mediaItem.data,
                    "format": mediaItem.format,
                    "label": mediaItem.label || "音频"
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
            var nonImageLabels = [];
            var messageAttachments = [];
            for (var mediaIndex = 0; mediaIndex < mediaParts.length; mediaIndex++) {
                if (mediaParts[mediaIndex].type === "image_url")
                    messageAttachments.push({
                        "type": "image_url",
                        "source": mediaParts[mediaIndex].url,
                        "localPath": "",
                        "name": mediaParts[mediaIndex].label
                    });
                else
                    nonImageLabels.push(mediaParts[mediaIndex].label);
            }
            if (nonImageLabels.length > 0)
                displayText = (displayText ? displayText + "\n" : "") + nonImageLabels.join(" | ");
            for (var fileIndex = 0; fileIndex < filesArray.length; fileIndex++)
                messageAttachments.push({
                    "type": "file",
                    "localPath": filesArray[fileIndex].path,
                    "name": filesArray[fileIndex].name,
                    "mimeType": "text/plain",
                    "language": filesArray[fileIndex].language || "",
                    "size": filesArray[fileIndex].content ? filesArray[fileIndex].content.length : 0
                });

            var userModelIndex = chatModel.count;
            chatModel.append({
                "text": displayText,
                "attachmentsJson": JSON.stringify(messageAttachments),
                "isUser": true,
                "isComplete": true,
                "isThinking": false,
                "raw_text": content,
                "reasoning_text": "",
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
                if (filesArray.length > 0) {
                    for (var requestFileIndex = 0; requestFileIndex < filesArray.length; requestFileIndex++)
                        mediaParts.push({
                            "type": "file",
                            "localPath": filesArray[requestFileIndex].path,
                            "name": filesArray[requestFileIndex].name,
                            "mimeType": "text/plain",
                            "language": filesArray[requestFileIndex].language || "",
                            "size": filesArray[requestFileIndex].content ? filesArray[requestFileIndex].content.length : 0
                        });
                }
                chatbot.sendMessageWithMedia(content, JSON.stringify(mediaParts));
            } else {
                chatbot.sendMessage(content, filesJson);
            }

            if (messageAttachments.length > 0 && chatbot.messages.length > 0) {
                var savedMessage = chatbot.messages[chatbot.messages.length - 1];
                var savedParts = savedMessage.parts || [];
                if (savedParts.length > 0)
                    chatModel.setProperty(userModelIndex, "attachmentsJson", JSON.stringify(savedParts));
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
            _followLatestMessage();
        }

        sendMessageInternal(fileItems);
    }

    function _syncHistoryIndices() {
        if (!chatbot || !chatbot.messages)
            return;

        var history = chatbot.messages;
        var cursor = 0;

        function consumeToolTurn() {
            var start = cursor;
            if (cursor < history.length && history[cursor].role === "assistant"
                    && history[cursor].toolCallsJson) {
                cursor++;
            }
            while (cursor < history.length && history[cursor].role === "tool")
                cursor++;
            return cursor > start ? start : -1;
        }

        function consumeMessage(role) {
            while (cursor < history.length) {
                var message = history[cursor];
                if (message.role === role) {
                    var index = cursor;
                    cursor++;
                    return index;
                }
                if (message.role === "assistant" && message.toolCallsJson) {
                    consumeToolTurn();
                    continue;
                }
                if (message.role === "tool") {
                    cursor++;
                    continue;
                }
                cursor++;
            }
            return -1;
        }

        for (var rowIndex = 0; rowIndex < chatModel.count; rowIndex++) {
            var row = chatModel.get(rowIndex);
            var historyIndex = -1;
            if (row.isReasoning || row.isThinking) {
                historyIndex = -1;
            } else if (row.isToolCall) {
                historyIndex = consumeToolTurn();
            } else if (row.isUser) {
                historyIndex = consumeMessage("user");
            } else {
                historyIndex = consumeMessage("assistant");
            }
            if (row.historyIndex !== historyIndex)
                chatModel.setProperty(rowIndex, "historyIndex", historyIndex);
        }
    }

    function _cppIndex(qmlIndex) {
        _syncHistoryIndices();
        var item = chatModel.get(qmlIndex);
        if (item && item.historyIndex !== undefined && item.historyIndex >= 0)
            return item.historyIndex;
        return -1;
    }

    function deleteSingleMessage(index) {
        var cppIndex = _cppIndex(index);
        if (cppIndex < 0)
            return;
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
        if (cppIndex < 0)
            return;
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
        if (cppIndex < 0)
            return;
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
        id_navigation_target_expiry_timer.stop();
        id_message_jump_timer.stop();
        _pendingJumpIndex = msgIndex;
        _navigationTargetIndex = msgIndex;
        _navigationJumping = true;
        _jumpAttempts = 0;
        _jumpStableFrames = 0;
        id_chat_listview.currentIndex = msgIndex;
        id_chat_listview._programmaticScroll = true;
        id_chat_listview.positionViewAtIndex(msgIndex, ListView.Beginning);
        id_chat_listview._programmaticScroll = false;
        id_message_jump_timer.restart();
    }

    function editMessage(index) {
        var item = chatModel.get(index);
        var cppIndex = _cppIndex(index);
        if (cppIndex < 0)
            return;
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
    }

    Item {
        id: id_main_content
        anchors.fill: parent
        visible: !qmlGlobal.inputPageShowing
        z: 1

        Rectangle {
            id: id_chat_container
            anchors.fill: parent
            color: YColors.black

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
                // Retain several long neighbors; rich delegates outside the preload window stay lightweight.
                cacheBuffer: Math.min(2400, Math.max(1600, Math.round(height * 10)))
                reuseItems: true

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
                    if (!_programmaticScroll) {
                        _flicking = true;
                        if (id_rich_content_anchor_timer.running)
                            id_rich_content_anchor_timer.stop();
                        if (_navigationTargetIndex >= 0) {
                            _navigationTargetIndex = -1;
                            _navigationJumping = false;
                            _pendingJumpIndex = -1;
                            id_navigation_target_expiry_timer.stop();
                        }
                        if (id_follow_latest_timer.running)
                            id_follow_latest_timer.stop();
                        if (_layoutStabilizing) {
                            _layoutStabilizing = false;
                            id_layout_stabilize_timer.stop();
                        }
                    }
                }
                onMovementEnded: {
                    _flicking = false;
                    updateUserScrolledState();
                    id_list_bounds_guard_timer.restart();
                }
                onContentYChanged: {
                    if (_programmaticScroll)
                        return;
                    if (id_chat_assistant_page._navigationTargetIndex >= 0 && (moving || _flicking)) {
                        id_chat_assistant_page._navigationTargetIndex = -1;
                        id_chat_assistant_page._navigationJumping = false;
                        id_chat_assistant_page._pendingJumpIndex = -1;
                        id_message_jump_timer.stop();
                    }
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

                function scrollToTop() {
                    id_bottom_scroll_animation.stop();
                    _programmaticScroll = true;
                    positionViewAtBeginning();
                    _programmaticScroll = false;
                    userScrolledUp = false;
                    hasNewMessages = false;
                }

                function scrollToBottom(animated) {
                    id_bottom_scroll_animation.stop();
                    var targetY = Math.max(originY, originY + contentHeight - height);
                    if (animated && Math.abs(targetY - contentY) > 1) {
                        _programmaticScroll = true;
                        id_bottom_scroll_animation.from = contentY;
                        id_bottom_scroll_animation.to = targetY;
                        id_bottom_scroll_animation.start();
                    } else {
                        _programmaticScroll = true;
                        positionViewAtEnd();
                        _programmaticScroll = false;
                    }
                    userScrolledUp = false;
                    hasNewMessages = false;
                }

                NumberAnimation {
                    id: id_bottom_scroll_animation
                    target: id_chat_listview
                    property: "contentY"
                    duration: 90
                    easing.type: Easing.OutQuad
                    onStopped: id_chat_listview._programmaticScroll = false
                }

                onContentHeightChanged: {
                    if (_layoutStabilizing)
                        id_layout_stabilize_timer.restart();
                    if (!moving && !id_rich_content_anchor_timer.running)
                        id_list_bounds_guard_timer.restart();
                }

                header: Item {
                    width: id_chat_listview.width
                    height: 10
                }

                footer: Item {
                    height: 16
                    width: id_chat_listview.width
                }

                Rectangle {
                    width: 120
                    height: 36
                    radius: 18
                    color: YColors.red
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
                    reasoningText: model.reasoning_text || ""
                    isUser: model.isUser
                    isComplete: model.isComplete
                    isThinking: model.isThinking
                    isReasoning: model.isReasoning || false
                    isToolCall: model.isToolCall
                    toolState: model.toolState
                    attachmentsJson: model.attachmentsJson || "[]"
                    mathServerAvailable: id_chat_assistant_page.mathServerAvailable
                    textureCacheEnabled: id_chat_assistant_page.bubbleTextureCacheEnabled
                    renderMode: chatbot.bubbleRenderMode
                    listMoving: id_chat_listview.moving
                    navigationJumping: id_chat_assistant_page._navigationJumping
                    messageIndex: model.index
                    listWidth: id_chat_listview.width
                    listContentY: id_chat_listview.contentY
                    listViewportHeight: id_chat_listview.height
                    richPreloadMargin: id_chat_listview.height * 2
                    fontFamily: qmlGlobal.fontFamilyZhCn
                    onLongPressed: id_context_menu.showMenu(globalX, globalY, msgIndex)
                    onAttachmentOpenRequested: function (attachmentType, localPath) {
                        if (attachmentType === "image_url") {
                            if (imageViewer.openAbsolute(localPath))
                                id_pop_container.show("audiopages/FileManagerImageViewer");
                            else
                                toastBanner.error("图片附件不可用");
                        } else if (attachmentType === "file") {
                            if (textReader.openAbsolute(localPath))
                                id_pop_container.show("audiopages/FileManagerTextViewer");
                            else
                                toastBanner.error("文本附件不可用");
                        }
                    }
                    onToolCardExpansionStarted: {
                        if (expanding)
                            id_tool_expansion_anchor_timer.preserveViewport();
                    }
                    onRichContentCommitStarted: function (itemY) {
                        if (id_chat_assistant_page._navigationTargetIndex >= 0) {
                            id_chat_assistant_page._pendingJumpIndex = id_chat_assistant_page._navigationTargetIndex;
                            id_chat_assistant_page._jumpAttempts = 0;
                            id_chat_assistant_page._jumpStableFrames = 0;
                            id_chat_assistant_page._navigationJumping = true;
                            id_navigation_target_expiry_timer.stop();
                            id_message_jump_timer.restart();
                        } else {
                            id_chat_assistant_page._beginRichContentCommit();
                        }
                    }
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
                color: YColors.white
                font.family: qmlGlobal.fontFamilyZhCn
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "点击左侧键盘开始对话"
                font.pixelSize: 12
                color: YColors.graySwitchOff
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
                color: YColors.grayNormal
                border.width: 1
                border.color: YColors.border
                onValidClicked: showKeyboard()
            }
            YIconButton {
                width: 28
                height: 28
                radius: 8
                realSource: "qrc:/images/chat/more"
                sourceSize: Qt.size(18, 18)
                color: YColors.grayNormal
                border.width: 1
                border.color: YColors.border
                onValidClicked: id_more_menu.show()
            }
            YIconButton {
                width: 28
                height: 28
                radius: 8
                realSource: "qrc:/images/chat/settings"
                sourceSize: Qt.size(18, 18)
                color: YColors.grayNormal
                border.width: 1
                border.color: YColors.border
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
            color: YColors.grayNormal
            border.width: 1
            border.color: YColors.border
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
                    ctx.fillStyle = YColors.red;
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
            tavilyEnabled: chatbot.toolsEnabled && chatbot.tavilyEnabled
            tavilyConfigured: chatbot.toolsEnabled && chatbot.tavilyConfigured
            onWebSearchToggled: {
                if (!chatbot.toolsEnabled)
                    return;
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
            messageModel: chatModel
            fontFamily: qmlGlobal.fontFamilyZhCn

            onNavigateToMessage: navigateToMessageIndex(messageIndex)
            onCloseRequested: close()
        }
    }

    Timer {
        id: id_navigation_target_expiry_timer
        interval: 1200
        repeat: false
        onTriggered: {
            _navigationTargetIndex = -1;
            _navigationJumping = false;
            _pendingJumpIndex = -1;
            id_message_jump_timer.stop();
        }
    }

    Timer {
        id: highlightTimer
        interval: 1500
        repeat: false
        onTriggered: id_chat_listview.currentIndex = -1
    }

    Timer {
        id: id_rich_content_anchor_timer
        property int anchorIndex: -1
        property real anchorOffset: 0
        property bool pinBottom: false
        property int ticks: 0
        property int stableFrames: 0
        property real lastContentHeight: -1
        interval: 16
        repeat: true

        function beginTracking() {
            ticks = 0;
            stableFrames = 0;
            lastContentHeight = -1;
            restart();
        }

        onTriggered: {
            if (id_chat_listview.moving) {
                stop();
                anchorIndex = -1;
                return;
            }
            var minY = id_chat_listview.originY;
            var maxY = Math.max(minY, minY + id_chat_listview.contentHeight - id_chat_listview.height);
            var currentY = isFinite(id_chat_listview.contentY) ? id_chat_listview.contentY : minY;
            var targetY = Math.max(minY, Math.min(currentY, maxY));
            if (pinBottom) {
                targetY = maxY;
            } else if (anchorIndex >= 0) {
                var anchorItem = id_chat_listview.itemAtIndex(anchorIndex);
                if (anchorItem)
                    targetY = Math.max(minY, Math.min(anchorItem.y - anchorOffset, maxY));
            }
            id_chat_listview._programmaticScroll = true;
            id_chat_listview.contentY = targetY;
            id_chat_listview._programmaticScroll = false;

            var currentHeight = id_chat_listview.contentHeight;
            if (lastContentHeight >= 0 && Math.abs(currentHeight - lastContentHeight) <= 1)
                stableFrames++;
            else
                stableFrames = 0;
            lastContentHeight = currentHeight;
            ticks++;
            if ((ticks >= 10 && stableFrames >= 3) || ticks >= 30) {
                stop();
                anchorIndex = -1;
                id_list_bounds_guard_timer.restart();
            }
        }
    }

    Timer {
        id: id_list_bounds_guard_timer
        interval: 0
        repeat: false
        onTriggered: {
            if (id_chat_listview.moving || id_rich_content_anchor_timer.running)
                return;
            id_chat_listview.forceLayout();
            var minY = id_chat_listview.originY;
            var maxY = Math.max(minY, minY + id_chat_listview.contentHeight - id_chat_listview.height);
            var currentY = isFinite(id_chat_listview.contentY) ? id_chat_listview.contentY : minY;
            var boundedY = Math.max(minY, Math.min(currentY, maxY));
            if (!isFinite(id_chat_listview.contentY) || Math.abs(boundedY - id_chat_listview.contentY) > 0.5) {
                id_chat_listview._programmaticScroll = true;
                id_chat_listview.contentY = boundedY;
                id_chat_listview._programmaticScroll = false;
            }
            id_chat_listview.returnToBounds();
        }
    }

    Timer {
        id: id_tool_expansion_anchor_timer
        property real anchorContentY: 0
        property int ticks: 0
        interval: 20
        repeat: true

        function preserveViewport() {
            anchorContentY = id_chat_listview.contentY;
            ticks = 0;
            restart();
        }

        onTriggered: {
            id_chat_listview.forceLayout();
            var maxY = Math.max(id_chat_listview.originY,
                                id_chat_listview.originY + id_chat_listview.contentHeight - id_chat_listview.height);
            id_chat_listview._programmaticScroll = true;
            id_chat_listview.contentY = Math.max(id_chat_listview.originY, Math.min(anchorContentY, maxY));
            id_chat_listview._programmaticScroll = false;
            ticks++;
            if (ticks >= 10)
                stop();
        }
    }

    Timer {
        id: id_follow_latest_timer
        interval: 20
        repeat: true
        onTriggered: {
            id_chat_listview.forceLayout();
            id_chat_listview.scrollToBottom();
            _followAttempts++;

            var sameHeight = Math.abs(id_chat_listview.contentHeight - _followLastContentHeight) <= 1;
            var targetY = Math.max(id_chat_listview.originY,
                                   id_chat_listview.originY + id_chat_listview.contentHeight - id_chat_listview.height);
            var atBottom = Math.abs(targetY - id_chat_listview.contentY) <= 1;
            _followStableFrames = sameHeight && atBottom ? _followStableFrames + 1 : 0;
            _followLastContentHeight = id_chat_listview.contentHeight;
            if ((_followAttempts >= 8 && _followStableFrames >= 3) || _followAttempts >= 25)
                stop();
        }
    }

    Timer {
        id: id_message_jump_timer
        interval: 20
        repeat: true
        onTriggered: {
            var index = _pendingJumpIndex;
            if (index < 0 || index >= chatModel.count) {
                stop();
                _pendingJumpIndex = -1;
                _navigationTargetIndex = -1;
                _navigationJumping = false;
                return;
            }

            id_chat_listview.forceLayout();
            id_chat_listview._programmaticScroll = true;
            id_chat_listview.positionViewAtIndex(index, ListView.Beginning);
            id_chat_listview._programmaticScroll = false;
            _jumpAttempts++;

            var targetItem = id_chat_listview.itemAtIndex(index);
            var expectedY = targetItem !== null
                          ? ChatNavigation.clampedTargetY(id_chat_listview.originY,
                                                          id_chat_listview.contentHeight,
                                                          id_chat_listview.height,
                                                          targetItem.y)
                          : id_chat_listview.originY;
            var aligned = targetItem !== null && Math.abs(expectedY - id_chat_listview.contentY) <= 1;
            _jumpStableFrames = aligned ? _jumpStableFrames + 1 : 0;
            if (_jumpStableFrames >= 2 || _jumpAttempts >= 40) {
                stop();
                _pendingJumpIndex = -1;
                _navigationJumping = false;
                id_navigation_target_expiry_timer.restart();
                highlightTimer.restart();
            }
        }
    }

    Timer {
        id: generationDoneTimer
        interval: 200
        repeat: false
        onTriggered: {
            id_chat_assistant_page.isGenerating = false;
            consumePendingVoiceChat();
        }
    }

    Timer {
        id: id_layout_stabilize_timer
        interval: 300
        repeat: false
        onTriggered: {
            if (_layoutStabilizing) {
                id_chat_listview.forceLayout();
                id_chat_listview.scrollToTop();
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
        dynamicRoles: true
    }

    QtObject {
        id: streamThrottle
        property string content: ""
        property int lastIndex: -1
        property string targetKind: ""
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
        target: mod
        function onPendingVoiceChatTextChanged() {
            if (id_chat_assistant_page.visible)
                Qt.callLater(consumePendingVoiceChat);
        }
    }

    Connections {
        target: chatbot
        ignoreUnknownSignals: true

        function onMessageReceived(content, isComplete) {
            _toolCallActive = false;
            _completeLastReasoningCard();
            if (isComplete && !streamThrottle.endProcessed) {
                var lastIndex = chatModel.count - 1;
                if (lastIndex < 0 || chatModel.get(lastIndex).isUser
                        || chatModel.get(lastIndex).isToolCall || chatModel.get(lastIndex).isReasoning)
                    lastIndex = _appendAnswerPlaceholder();
                chatModel.set(lastIndex, {
                    "text": "",
                    "raw_text": content,
                    "isComplete": true,
                    "isThinking": false,
                    "isReasoning": false
                });
                generationDoneTimer.restart();
            }
        }
        function onReasoningChunk(content) {
            if (!content)
                return;

            // Flush answer text before changing rows. Otherwise the saved index
            // can point at the newly inserted reasoning card.
            if (streamThrottle.content !== "")
                _flushStreamBuffer();

            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0 && chatModel.get(lastIndex).isReasoning) {
                chatModel.setProperty(lastIndex, "raw_text", chatModel.get(lastIndex).raw_text + content);
                return;
            }
            if (lastIndex >= 0 && chatModel.get(lastIndex).isThinking)
                chatModel.remove(lastIndex);

            // Keep late reasoning before an already-created answer row.
            var answerIndex = _findCurrentAnswerIndex();
            if (answerIndex >= 0)
                chatModel.insert(answerIndex, _makeReasoningEntry(content));
            else
                chatModel.append(_makeReasoningEntry(content));
            _scheduleScrollToBottom();
        }
        function onStreamChunk(content) {
            streamThrottle.endProcessed = false;
            _completeLastReasoningCard();
            var lastIndex = chatModel.count - 1;
            if (lastIndex < 0)
                return;
            var item = chatModel.get(lastIndex);
            if (item.isUser)
                return;
            if (item.isToolCall || item.isReasoning || item.isComplete) {
                lastIndex = _appendAnswerPlaceholder();
                item = chatModel.get(lastIndex);
            }
            // Keep the thinking bubble until the buffered first chunk is committed.
            // _flushStreamBuffer() switches the state and text in one model update.
            if (streamThrottle.lastIndex >= 0 && streamThrottle.lastIndex !== lastIndex)
                _flushStreamBuffer();
            streamThrottle.content += content;
            streamThrottle.lastIndex = lastIndex;
            streamThrottle.targetKind = item.isThinking ? "thinking" : "answer";
            if (!throttlingTimer.running)
                throttlingTimer.start();
        }
        function onStreamStart() {
            _toolCallActive = false;
            _resetStreamState();
        }
        function onMessagesChanged() {
            _syncHistoryIndices();
        }
        function onImageAttachmentsReceived(attachments) {
            for (var index = chatModel.count - 1; index >= 0; index--) {
                var item = chatModel.get(index);
                if (item.isUser || item.isToolCall || item.isReasoning)
                    continue;
                chatModel.setProperty(index, "attachmentsJson", JSON.stringify(attachments));
                _scheduleScrollToBottom();
                return;
            }
        }
        function onStreamEnd() {
            throttlingTimer.stop();
            _completeLastReasoningCard();
            _flushStreamBuffer();
            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0) {
                var item = chatModel.get(lastIndex);
                if (!item.isUser && !item.isToolCall && !item.isReasoning) {
                    if (item.isThinking && item.raw_text === "") {
                        return;
                    }
                    var rawContent = item.raw_text;
                    chatModel.set(lastIndex, {
                        "text": "",
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
        function onErrorOccurred(error) {
            _completeLastReasoningCard();
            _resetStreamState();
            _preparingSend = false;
            _toolCallActive = false;
            toastBanner.error(error, 8000);
            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0 && chatModel.get(lastIndex).isThinking)
                chatModel.remove(lastIndex);
            id_chat_assistant_page.isGenerating = false;
            Qt.callLater(consumePendingVoiceChat);
        }
        function onToolCallProgress(text, isComplete) {
            generationDoneTimer.stop();
            _completeLastReasoningCard();
            _toolCallActive = !isComplete;
            finalizeLastAssistantIfNeeded();
            _upsertToolEntry("__server__", text, "", isComplete ? "done" : "searching", isComplete);
        }
        function onToolCallReceived(toolCallsJson) {
            generationDoneTimer.stop();
            _completeLastReasoningCard();
            finalizeLastAssistantIfNeeded();
            var lastIndex = chatModel.count - 1;
            if (lastIndex >= 0 && chatModel.get(lastIndex).isThinking)
                chatModel.remove(lastIndex);
        }
        function onTavilySearchStarted(toolCallId, query) {
            generationDoneTimer.stop();
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            finalizeLastAssistantIfNeeded();
            _upsertToolEntry(toolCallId, "正在搜索：" + query, "", "searching", false);
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
        }
        function onTavilySearchFinished(toolCallId, success, summary, resultText) {
            updateCardByToolCallId(toolCallId, {
                "text": success ? "已完成搜索：" + summary : "搜索失败：" + summary,
                "raw_text": resultText,
                "toolState": success ? "done" : "error",
                "isComplete": true
            });
        }
        function onShellCommandPending(toolCallId, command) {
            generationDoneTimer.stop();
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            finalizeLastAssistantIfNeeded();
            _upsertToolEntry(toolCallId, "请求执行：" + command, command, "pending", false);
            Qt.callLater(function () {
                id_chat_listview.scrollToBottom();
            });
            shellConfirmDialog.show(toolCallId, command);
        }
        function onShellCommandStarted(toolCallId, command) {
            _toolCallActive = true;
            id_chat_assistant_page.isGenerating = true;
            updateCardByToolCallId(toolCallId, {
                "text": "正在执行...",
                "toolState": "searching"
            });
        }
        function onShellCommandFinished(toolCallId, success, summary, resultText) {
            updateCardByToolCallId(toolCallId, {
                "text": success ? "执行完成" : "执行失败：" + summary,
                "raw_text": resultText,
                "toolState": success ? "done" : "error",
                "isComplete": true
            });
        }
        function onToolBatchFlushed() {
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
        function onRequestCancelled() {
            _completeLastReasoningCard();
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
            Qt.callLater(consumePendingVoiceChat);
        }
        function onSessionSwitched(sessionId) {
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
            if (mod.voiceChatEnabled)
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
            if (captureModeActive || (keyboardPageRef && keyboardPageRef.visible)
                    || qmlGlobal.inputPageShowing || id_pop_container.count > 0)
                return;
            if (content && content.trim().length > 0 && id_chat_assistant_page.visible) {
                if (typeof qmlGlobal.hideDictPage === 'function')
                    qmlGlobal.hideDictPage();
                handleUserSend(content.trim());
            }
        }
    }
}
