import QtQuick 2.12
import com.github.penuniverse 1.0

import "../commons"
import "../components"
import "../i18n"
import "../settingpages"

YBackButtonPage {
    id: id_detail_page
    objectName: "YPage===ModelDetailPage.qml"

    // 传入的模型数据（空对象 = 新建）
    property var modelData: ({})
    readonly property bool isNew: !modelData || !modelData.id

    signal modelSaved()
    signal modelDeleted()

    // 本地编辑缓冲（从 modelData 初始化）
    property var fd: ({})

    // 当前激活的键盘字段 key（保留供外部可能引用）

    // 根据 modelData 初始化 fd
    function initFormData() {
        var cap = modelData.capabilities || {};
        fd = {
            "name":           modelData.name        || "",
            "provider":       modelData.provider    || "",
            "endpoint":       modelData.endpoint    || "",
            "modelId":        modelData.modelId     || "",
            "apiKey":         modelData.apiKey      || "",
            "temperature":    modelData.temperature !== undefined ? String(modelData.temperature) : "0.7",
            "maxContextSize": modelData.maxContextSize || 0,
            "capText":        cap.text      !== undefined ? cap.text      : true,
            "capVision":      cap.vision    || false,
            "capAudio":       cap.audio     || false,
            "capToolCall":    cap.toolCall  || false,
            "capReasoning":   cap.reasoning || false,
            "extraParams":    modelData.extraParams ? JSON.stringify(modelData.extraParams) : "",
            "proxyVisionModelId":  modelData.proxyVisionModelId  || "",
            "proxyVisionPrompt":   modelData.proxyVisionPrompt   || ""
        };
    }

    function openKeyboard(key, placeholder) {
        id_detail_pop.currentKey         = key;
        id_detail_pop.currentPlaceholder = placeholder;
        id_detail_pop.currentPrefill     = fd[key] !== undefined ? String(fd[key]) : "";
        var component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_detail_pop.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(s) {
                    if (s === Component.Ready) id_detail_pop.inputPageCreated(incubator.object);
                };
            } else {
                id_detail_pop.inputPageCreated(incubator.object);
            }
        }
    }

    function saveModel() {
        if (!fd.name || !fd.endpoint || !fd.modelId) {
            showToast("名称、接口地址和模型 ID 为必填项", 2);
            return;
        }

        var modelId = isNew ? generateId(fd.name) : modelData.id;

        var modelObj = {
            "id":             modelId,
            "name":           fd.name,
            "provider":       fd.provider || "",
            "endpoint":       fd.endpoint,
            "modelId":        fd.modelId,
            "apiKey":         fd.apiKey || "",
            "temperature":    parseFloat(fd.temperature) || 0.7,
            "maxContextSize": fd.maxContextSize || 0,
            "capabilities": {
                "text":      fd.capText,
                "vision":    fd.capVision,
                "audio":     fd.capAudio,
                "toolCall":  fd.capToolCall,
                "reasoning": fd.capReasoning
            },
            "extraParams":    fd.extraParams || "",
            "proxyVisionModelId":  fd.proxyVisionModelId || "",
            "proxyVisionPrompt":   fd.proxyVisionPrompt  || ""
        };

        var success = chatbot.addModel(JSON.stringify(modelObj));
        if (success) {
            showToast(isNew ? "模型已添加" : "模型已更新", 1);
            modelSaved();
            backButtonClicked();
        } else {
            showToast("保存失败，请检查输入", 2);
        }
    }

    function generateId(name) {
        return name.toLowerCase().replace(/[^a-z0-9]/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "") || "model";
    }

    property var visionModelList: []
    property bool proxySelectorOpen: false

    function refreshVisionModels() {
        var list = [];
        try {
            var modelsJson = JSON.parse(chatbot.getModels());
            var models = modelsJson.models || modelsJson;
            if (Array.isArray(models)) {
                for (var i = 0; i < models.length; i++) {
                    var m = models[i];
                    var cap = m.capabilities || {};
                    if (cap.vision && m.id !== (modelData.id || ""))
                        list.push({ "modelId": m.id, "modelName": m.name || m.id });
                }
            }
        } catch (e) {}
        visionModelList = list;
    }

    function getProxyModelName() {
        if (!fd.proxyVisionModelId) return "未设置";
        try {
            var modelsJson = JSON.parse(chatbot.getModels());
            var models = modelsJson.models || modelsJson;
            if (Array.isArray(models)) {
                for (var i = 0; i < models.length; i++) {
                    if (models[i].id === fd.proxyVisionModelId) return models[i].name || models[i].id;
                }
            }
        } catch (e) {}
        return "已删除的模型";
    }

    property string toastMsg: ""
    property bool toastVisible: false
    property int toastType: 0

    function showToast(msg, type) {
        toastMsg = msg;
        toastType = type || 0;
        toastVisible = true;
        id_toast_timer.restart();
    }

    Timer {
        id: id_toast_timer
        interval: 2500
        onTriggered: toastVisible = false
    }

    Component.onCompleted: {
        initFormData();
    }

    onModelDataChanged: {
        initFormData();
    }

    // Toast
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: toastVisible ? 16 : -40
        width: id_toast_text.implicitWidth + 32
        height: 30
        radius: 6
        color: toastType === 2 ? "#4A1A1D" : toastType === 1 ? "#1A3A2A" : "#1A2A3A"
        z: 2000
        visible: opacity > 0
        opacity: toastVisible ? 1 : 0

        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: id_toast_text
            anchors.centerIn: parent
            text: toastMsg
            color: toastType === 2 ? "#FF6B6B" : toastType === 1 ? "#4CAF50" : YColors.grayText
            font.pixelSize: 12
            font.family: qmlGlobal.fontFamilyZhCn
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_detail_col.height + 24
        clip: true

        Column {
            id: id_detail_col
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            YSettingItemTitle {
                title: isNew ? "添加模型" : "编辑模型"
            }

            // ─── 基本信息 ─────────────────────────────
            YText {
                text: "基本信息"
                color: YColors.grayText
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.leftMargin: 4
            }

            DescribedClickableTextBox {
                title: "模型名称"
                describe: fd.name || "点击输入显示名称"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("name", "请输入模型名称")
            }

            DescribedClickableTextBox {
                title: "提供商"
                describe: fd.provider || "点击输入（选填）"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("provider", "请输入提供商名称")
            }

            // ─── 接口配置 ─────────────────────────────
            YText {
                text: "接口配置"
                color: YColors.grayText
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.leftMargin: 4
            }

            DescribedClickableTextBox {
                title: "接口地址"
                describe: fd.endpoint || "点击输入 API 服务端点 URL"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("endpoint", "https://api.example.com/v1")
            }

            DescribedClickableTextBox {
                title: "模型 ID"
                describe: fd.modelId || "点击输入传给 API 的 model 参数"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("modelId", "请输入模型 ID")
            }

            DescribedClickableTextBox {
                title: "API 密钥"
                describe: fd.apiKey ? "●".repeat(Math.min(fd.apiKey.length, 12)) : "点击输入身份验证密钥"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("apiKey", "请输入 API 密钥")
            }

            // ─── 高级选项 ─────────────────────────────
            YText {
                text: "高级选项"
                color: YColors.grayText
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.leftMargin: 4
            }

            DescribedClickableTextBox {
                title: "温度"
                describe: fd.temperature !== undefined ? String(fd.temperature) : "0.7"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("temperature", "0.0 ~ 2.0")
            }

            DescribedClickableTextBox {
                title: "上下文窗口大小"
                describe: fd.maxContextSize > 0 ? String(fd.maxContextSize) + " tokens" : "未设置"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("maxContextSize", "输入模型最大上下文 Token 数，0 为未设置")
            }

            DescribedClickableTextBox {
                title: "自定义请求体参数"
                describe: (fd.extraParams && fd.extraParams !== "{}") ? fd.extraParams : "点击输入额外 JSON 参数"
                describeItem.color: YColors.grayText
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("extraParams", "{ \"top_p\": 0.9 }")
            }

            // ─── 模型能力 ─────────────────────────────
            YText {
                text: "模型能力"
                color: YColors.grayText
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.leftMargin: 4
            }

            DescribedSwitchItem {
                title: "文本"
                description: "支持文本输入与生成"
                switchOn: fd.capText
                interval: 0
                onTimerTriggered: { fd.capText = switchOn; fd = fd; }
            }

            DescribedSwitchItem {
                title: "图像（Vision）"
                description: "支持图片输入"
                switchOn: fd.capVision
                interval: 0
                onTimerTriggered: { fd.capVision = switchOn; fd = fd; }
            }

            DescribedSwitchItem {
                title: "音频"
                description: "支持音频输入"
                switchOn: fd.capAudio
                interval: 0
                onTimerTriggered: { fd.capAudio = switchOn; fd = fd; }
            }

            DescribedSwitchItem {
                title: "工具使用（Tool Call）"
                description: "支持函数调用"
                switchOn: fd.capToolCall
                interval: 0
                onTimerTriggered: { fd.capToolCall = switchOn; fd = fd; }
            }

            DescribedSwitchItem {
                title: "推理（Reasoning）"
                description: "支持思维链推理模式"
                switchOn: fd.capReasoning
                interval: 0
                onTimerTriggered: { fd.capReasoning = switchOn; fd = fd; }
            }

            // ─── 视觉代理设置（仅 Vision 关闭时显示）────
            YText {
                text: "视觉代理设置"
                color: YColors.grayText
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.leftMargin: 4
                visible: !fd.capVision
            }

            DescribedClickableTextBox {
                title: "视觉代理模型"
                describe: getProxyModelName()
                describeItem.color: fd.proxyVisionModelId ? YColors.textColor : YColors.grayText
                visible: !fd.capVision
                opacityChangableWhenPressed: false
                onClicked: {
                    refreshVisionModels();
                    if (visionModelList.length === 0) {
                        showToast("暂无支持视觉的模型，请先添加", 2);
                        return;
                    }
                    proxySelectorOpen = true;
                }
            }

            DescribedClickableTextBox {
                title: "代理提示词"
                describe: fd.proxyVisionPrompt || "点击输入（默认：请详细描述图片内容）"
                describeItem.color: fd.proxyVisionPrompt ? YColors.textColor : YColors.grayText
                visible: !fd.capVision
                opacityChangableWhenPressed: false
                onClicked: openKeyboard("proxyVisionPrompt", "请输入发给视觉模型的分析提示词")
            }

            YSettingAboutClickableItem {
                title: isNew ? "添加模型" : "保存修改"
                onClicked: saveModel()
            }

            YSettingAboutClickableItem {
                title: "删除模型"
                visible: !isNew
                onClicked: {
                    id_delete_dialog.tipItem.text = "确定删除模型「" + (modelData.name || modelData.id) + "」吗？此操作不可撤销。";
                    id_delete_dialog.show();
                }
            }
        }
    }

    // ─── 视觉代理模型选择器覆盖层 ─────────────────
    Rectangle {
        anchors.fill: parent
        color: "#AA000000"
        visible: proxySelectorOpen
        z: 1500

        MouseArea {
            anchors.fill: parent
            onClicked: proxySelectorOpen = false
        }

        Rectangle {
            width: 260
            height: Math.min(260, visionModelList.length * 40 + 80)
            color: "#1C1C1E"
            radius: 12
            anchors.centerIn: parent

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                YText {
                    text: "选择视觉代理模型"
                    color: "white"
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle { width: parent.width - 24; height: 1; color: "#333"; anchors.horizontalCenter: parent.horizontalCenter }

                Flickable {
                    width: parent.width - 8
                    height: parent.height - 52
                    contentHeight: id_proxy_model_col.height
                    clip: true

                    Column {
                        id: id_proxy_model_col
                        width: parent.width

                        Repeater {
                            model: visionModelList
                            YSettingAboutClickableItem {
                                title: modelData.modelName
                                imageName: modelData.modelId === fd.proxyVisionModelId ? 'settings/st-check' : ''
                                onClicked: {
                                    fd.proxyVisionModelId = modelData.modelId;
                                    fd = fd;
                                    proxySelectorOpen = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    YTwoButtonDialog {
        id: id_delete_dialog
        z: 1500
        anchors.fill: parent

        onClickedConfirm: {
            if (chatbot.removeModel(modelData.id)) {
                showToast("已删除: " + (modelData.name || modelData.id), 1);
                modelDeleted();
                close();
                backButtonClicked();
            } else {
                showToast("删除失败", 2);
                close();
            }
        }
        onClickedCancel: {
            close();
        }
    }

    YPagePopHelper {
        id: id_detail_pop
        z: 1000
        anchors.fill: parent
        objectName: "from_ModelDetailPage.qml"
        isShowing: qmlGlobal.inputPageShowing

        property string currentKey: ""
        property string currentPlaceholder: ""
        property string currentPrefill: ""

        function inputPageCreated(kbPage) {
            var key         = currentKey;
            var placeholder = currentPlaceholder;
            var prefill     = currentPrefill;

            kbPage.placeHolderText = placeholder;

            kbPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                kbPage.todoDestroy();
            });

            kbPage.inputFinished.connect(function(input) {
                qmlGlobal.inputPageShowing = false;
                kbPage.todoDestroy();
                if (input !== null) {
                    if (key === "temperature") {
                        var t = parseFloat(input);
                        fd[key] = isNaN(t) ? "0.7" : String(Math.max(0, Math.min(2, t)));
                    } else if (key === "maxContextSize") {
                        var n = parseInt(input);
                        fd[key] = (isNaN(n) || n < 0) ? 0 : n;
                    } else if (key === "extraParams") {
                        if (input.trim() !== "") {
                            try {
                                JSON.parse(input);
                                fd[key] = input;
                            } catch(e) {
                                showToast("额外参数不是合法 JSON，已清空", 2);
                                fd[key] = "";
                            }
                        } else {
                            fd[key] = "";
                        }
                    } else {
                        fd[key] = input;
                    }
                    fd = fd;
                }
            });

            kbPage.enterText(prefill);
            kbPage.show();
            qmlGlobal.inputPageShowing = true;
        }
    }
}
