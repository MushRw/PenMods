import QtQuick 2.12
import com.github.penuniverse 1.0

import "../commons"
import "../components"
import "../i18n"
import "../settingpages"

YBackButtonPage {
    id: id_setting_item
    objectName: "YPage===ChatAssistantSettingsPage.qml"

    function openKeyboard(placeholder, prefill, onDone) {
        id_settings_pop.pendingCallback = onDone;
        id_settings_pop.pendingPrefill  = prefill || "";
        id_settings_pop.pendingPlaceholder = placeholder || "";
        var component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_settings_pop.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(s) {
                    if (s === Component.Ready) id_settings_pop.inputPageCreated(incubator.object);
                };
            } else {
                id_settings_pop.inputPageCreated(incubator.object);
            }
        }
    }

    Flickable {
        id: id_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "对话相关"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 9

            DescribedSwitchItem {
                title: "流式输出"
                description: "随 LLM 模型处理进度动态更新消息内容"
                switchOn: chatbot.isStreaming
                interval: 0
                onTimerTriggered: {
                    chatbot.isStreaming = !chatbot.isStreaming;
                }
            }

            DescribedSwitchItem {
                title: "扫描结果快速发送"
                description: "扫描文字后当作消息直接发送"
                switchOn: keyBoard.autoSendScanConfig
                interval: 0
                onTimerTriggered: {
                    keyBoard.autoSendScanConfig = !keyBoard.autoSendScanConfig;
                }
            }

            YSettingAboutClickableItem {
                title: "导出当前会话"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    chatbot.saveMessages();
                }
            }

        YSettingItemTitle {
            title: "服务配置"
        }

            YSettingAboutClickableItem {
                title: "模型管理"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    var component = Qt.createComponent("ModelManagePage.qml");
                    var initPage = function (page) {
                        page.backButtonClicked.connect(function () {
                            page.todoDestroy();
                        });
                        page.show();
                    };
                    if (component.status === Component.Ready) {
                        var obj = component.incubateObject(id_setting_item);
                        if (obj.status !== Component.Ready) {
                            obj.onStatusChanged = function (s) {
                                if (s === Component.Ready)
                                    initPage(obj.object);
                            };
                        } else {
                            initPage(obj.object);
                        }
                    } else {
                        console.error("ModelManagePage load error:", component.errorString());
                    }
                }
            }

            YSettingAboutClickableItem {
                title: "提示词管理"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    var component = Qt.createComponent("PromptManagePage.qml");
                    var initPage = function (page) {
                        page.backButtonClicked.connect(function () {
                            page.todoDestroy();
                        });
                        page.show();
                    };
                    if (component.status === Component.Ready) {
                        var obj = component.incubateObject(id_setting_item);
                        if (obj.status !== Component.Ready) {
                            obj.onStatusChanged = function (s) {
                                if (s === Component.Ready)
                                    initPage(obj.object);
                            };
                        } else {
                            initPage(obj.object);
                        }
                    } else {
                        console.error("PromptManagePage load error:", component.errorString());
                    }
                }
            }

            YSettingItemTitle {
                title: "网络搜索 (Tavily)"
            }

            DescribedSwitchItem {
                title: "启用网络搜索"
                description: chatbot.tavilyConfigured ? "已配置 API Key" : "请先配置 Tavily API Key"
                switchOn: chatbot.tavilyEnabled && chatbot.tavilyConfigured
                interval: 0
                enabled: chatbot.tavilyConfigured
                onTimerTriggered: {
                    chatbot.tavilyEnabled = !chatbot.tavilyEnabled;
                }
            }

            YSettingAboutClickableItem {
                title: "密钥"
                value: chatbot.tavilyConfigured ? "已配置" : "未配置"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    openKeyboard("输入 Tavily API Key...", "", function(apiKey) {
                        if (apiKey && apiKey.trim().length > 0) {
                            var cfg = JSON.parse(chatbot.getTavilyConfig());
                            cfg.apiKey = apiKey.trim();
                            chatbot.setTavilyConfig(JSON.stringify(cfg));
                        }
                    });
                }
            }

            YSettingItemTitle {
                title: "Shell 工具"
            }

            DescribedSwitchItem {
                title: "启用 Shell 执行"
                description: "允许 AI 提出 shell 命令（需手动确认）"
                switchOn: chatbot.shellToolEnabled
                interval: 0
                onTimerTriggered: {
                    chatbot.shellToolEnabled = !chatbot.shellToolEnabled;
                }
            }

            YSettingAboutClickableItem {
                id: shellTimeoutItem
                title: "超时时间"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    var cfg = JSON.parse(chatbot.getShellToolConfig());
                    openKeyboard("超时时间（秒）", String(cfg.timeout_ms / 1000), function(val) {
                        var secs = parseInt(val);
                        if (secs >= 1 && secs <= 120) {
                            cfg.timeout_ms = secs * 1000;
                            chatbot.setShellToolConfig(JSON.stringify(cfg));
                        }
                    });
                }
            }

            YSettingAboutClickableItem {
                id: shellOutputItem
                title: "最大输出"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    var cfg = JSON.parse(chatbot.getShellToolConfig());
                    openKeyboard("最大输出（KB）", String(cfg.max_output_bytes / 1024), function(val) {
                        var kb = parseInt(val);
                        if (kb >= 1 && kb <= 64) {
                            cfg.max_output_bytes = kb * 1024;
                            chatbot.setShellToolConfig(JSON.stringify(cfg));
                        }
                    });
                }
            }

            Connections {
                target: chatbot
                onShellToolConfigChanged: {
                    var cfg = JSON.parse(chatbot.getShellToolConfig());
                    shellTimeoutItem.value = (cfg.timeout_ms / 1000) + "s";
                    shellOutputItem.value = (cfg.max_output_bytes / 1024) + " KB";
                }
            }

            Component.onCompleted: {
                var cfg = JSON.parse(chatbot.getShellToolConfig());
                shellTimeoutItem.value = (cfg.timeout_ms / 1000) + "s";
                shellOutputItem.value = (cfg.max_output_bytes / 1024) + " KB";
            }

        YSettingItemTitle {
            title: "数学公式渲染"
        }

            DescribedSwitchItem {
                title: "启用公式渲染"
                description: "使用本地 MathJax 服务将 LaTeX 公式渲染为图片"
                switchOn: chatbot.mathRenderEnabled
                interval: 0
                onTimerTriggered: {
                    chatbot.mathRenderEnabled = !chatbot.mathRenderEnabled;
                }
            }

            YSettingAboutClickableItem {
                id: mathServerPathItem
                title: "服务器路径"
                value: chatbot.mathServerPath !== "" ? chatbot.mathServerPath : "未配置"
                imageName: "settings/info_more_arrow"
                valueItem.elide: Text.ElideMiddle
                valueItem.width: Math.min(valueItem.implicitWidth, 120)
                onClicked: {
                    openKeyboard("MathJax 服务可执行文件路径", chatbot.mathServerPath, function(val) {
                        if (val !== null) chatbot.mathServerPath = val.trim();
                    });
                }
            }

            Connections {
                target: chatbot
                onMathRenderConfigChanged: {
                    mathServerPathItem.value = chatbot.mathServerPath !== "" ? chatbot.mathServerPath : "未配置";
                }
            }

        YSettingItemTitle {
            title: "配置文件"
        }

            YSettingAboutClickableItem {
                title: "重载配置"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    chatbot.reloadConfig();
                }
            }

            YSettingAboutClickableItem {
                title: "清洗配置"
                imageName: "settings/info_more_arrow"
                onClicked: {
                    chatbot.sanitizeConfig();
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }
    }

    YPagePopHelper {
        id: id_settings_pop
        z: 1000
        anchors.fill: parent
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_ChatAssistantSettings.qml"

        property var    pendingCallback:    null
        property string pendingPrefill:     ""
        property string pendingPlaceholder: ""

        function inputPageCreated(kbPage) {
            var cb          = pendingCallback;
            var placeholder = pendingPlaceholder;
            var prefill     = pendingPrefill;

            kbPage.placeHolderText = placeholder;
            kbPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                kbPage.todoDestroy();
            });
            kbPage.inputFinished.connect(function(input) {
                qmlGlobal.inputPageShowing = false;
                kbPage.todoDestroy();
                if (cb && input !== null) cb(input);
            });
            kbPage.enterText(prefill);
            kbPage.show();
            qmlGlobal.inputPageShowing = true;
        }
    }
}
