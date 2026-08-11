import "./commons"
import "./components"
import "./i18n"
import "./settingpages"
import QtQuick 2.12
import QtQuick.Layouts 1.12
import com.github.penuniverse 1.0

YBackButtonPage {
    id: pluginManagerPage
    objectName: "YPage===PluginManager.qml"
    pageIndex: PageIndex.PluginManager

    ListModel { id: pluginListModel }

    // --- 动态加载器 ---
    // 用于 "孵化" 插件的 UI。
    // 弹出层容器
    YDynamicPageStack {
        id: id_pop_container
        anchors.fill: parent
        z: 500
        visible: count > 0
        logTag: "PluginManager"

        // 事件屏障：位于动态插件内容之后（z:-1），
        // 插件自身 MouseArea 优先接收事件，
        // 未被覆盖区域由屏障吸收，防止穿透到下层
        MouseArea {
            id: id_pop_event_barrier
            anchors.fill: parent
            z: -1
            onPressed: { mouse.accepted = true; }
            onReleased: { mouse.accepted = true; }
            onClicked: { mouse.accepted = true; }
        }

        /**
         * 显示页面或插件（无缓存版本）
         * @param tpage 页面名称或路径
         * @param properties 初始化属性
         */
        function show(tpage, properties) {
            gc();

            var componentPath = tpage;
            const absoluteUrl = tpage.indexOf("/") === 0
                    || tpage.indexOf(":/") === 0
                    || tpage.indexOf("file:") === 0
                    || tpage.indexOf("qrc:") === 0
                    || tpage.indexOf("://") > 0;
            if (!absoluteUrl) {
                if (tpage.indexOf(".qml") === -1)
                    componentPath = "%1.qml".arg(tpage);
                componentPath = Qt.resolvedUrl("./%1".arg(componentPath));
            }

            console.log("Creating component (no cache):", componentPath);

            createPage(componentPath, tpage, {
                "pageIndex": PageIndex.PluginManager,
                "closeOnHomeRelease": true
            }, properties || {}, function(incubatorObject) {
                if (incubatorObject.hasOwnProperty("focus"))
                    incubatorObject.forceActiveFocus();
            });
        }

        /**
         * 关闭并销毁所有弹出页面
         */
        function closeAll() {
            closeAllPages();
            gc();
        }

        // 容器自身销毁时兜底清理
        Component.onDestruction: {
            closeAll();
        }
    }
    // ------------------

    // 确认卸载对话框
    YTwoButtonDialog {
        id: confirmUninstallDialog
        z: parent.z + 1
        anchors.fill: parent
        property string targetName: ""

        tipItem.text: "确定要卸载插件 \"" + targetName + "\" 吗？\n此操作将删除相关文件。"

        onClickedConfirm: {
            console.log("执行卸载逻辑: " + targetName);
            if (typeof pluginManager !== 'undefined') {
                pluginManager.uninstallPlugin(targetName);
                // 卸载后通常需要刷新，清理旧数据
                pluginManager.requestPluginList();
            }
            close();
        }

        onClickedCancel: {
            close();
        }
    }

    YSettingItemTitle {
        id: titleContainer
        title: "插件管理器"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
    }

    ListView {
        id: pluginListView
        anchors.top: titleContainer.bottom
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        model: pluginListModel
        spacing: 12
        clip: true

        footer: Item { width: parent.width; height: 20 }

        header: Item {
            width: parent.width
            height: pluginListModel.count === 0 ? 100 : 0
            visible: pluginListModel.count === 0
            YText {
                text: "未发现已安装的插件"
                font.pixelSize: 16
                color: YColors.grayText
                anchors.centerIn: parent
            }
        }

        delegate: Rectangle {
            id: pluginItem
            width: pluginListView.width
            height: contentColumn.height + 55
            radius: 12

            color: YColors.grayNormal

            border.color: YColors.grayButton
            border.width: 1

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 15
                spacing: 10

                // 头部区域：图标 + 名称 + 开关
                Item {
                    width: parent.width
                    height: 40

                    YImage {
                        id: pluginIcon
                        width: 32
                        height: 32
                        sourceSize: Qt.size(32, 32)
                        // 优先使用 model.icon，若为空则用默认
                        imageName: (model.icon && model.icon !== "") ? model.icon : "qrc:/images/home/home-plugin.png"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }

                    YTextMedium {
                        id: pluginName
                        text: model.name
                        font.pixelSize: 18
                        elide: Text.ElideRight
                        color: YColors.white
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: pluginIcon.right
                        anchors.leftMargin: 12
                        anchors.right: enableSwitch.left
                        anchors.rightMargin: 10
                    }
                    
                    // 占位，把开关挤到右边
                    Item { width: 1; height: 1; Layout.fillWidth: true } 

                    YSwitch {
                        id: enableSwitch
                        switchOn: model.enabled
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var targetState = !enableSwitch.switchOn;
                                if (pluginManager.setPluginEnabled(model.id, targetState)) {
                                    // 成功则更新 UI，如果后端加载失败会自动回滚，通过 pluginListUpdated 信号修正
                                    enableSwitch.switchOn = targetState; 
                                } else {
                                    // 操作失败（如加载库失败），强制复位开关
                                    enableSwitch.switchOn = false;
                                }
                            }
                        }
                    }
                }

                // 描述区域
                YText {
                    id: pluginDescription
                    width: parent.width
                    text: model.description
                    font.pixelSize: 14
                    color: YColors.grayText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                // 底部信息与操作
                Item {
                    width: parent.width
                    height: 40
                    
                    Row {
                        id: basic_plugin_info
                        anchors.left: parent.left
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        YText { text: "v" + model.version; font.pixelSize: 12; color: YColors.grayText }
                        YText { text: "by " + model.author; font.pixelSize: 12; color: YColors.grayText }
                    }

                    Row {
                        anchors.top: basic_plugin_info.bottom
                        anchors.topMargin: 10
                        anchors.right: parent.right
                        spacing: 10
                        
                        YButton {
                            text: "打开"
                            width: 60; height: 28; pixelSize: 12
                            // 只有启用且加载成功时才显示打开按钮
                            visible: model.enabled && model.loaded
                            onClicked: {
                                id_pop_container.show(model.mainQmlUrl, { "pluginName": model.name });
                            }
                        }

                        YButton {
                            text: "卸载"
                            width: 60; height: 28; pixelSize: 12
                            onClicked: {
                                confirmUninstallDialog.targetName = model.name;
                                confirmUninstallDialog.show();
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (typeof pluginManager !== 'undefined') {
            // 首次加载前也清理一次
            pluginListModel.clear();
            pluginManager.requestPluginList();
        }
    }

    Connections {
        target: (typeof pluginManager !== 'undefined') ? pluginManager : null
        ignoreUnknownSignals: true

        function onPluginListUpdated() {
            // 必须先清空模型，否则每次刷新都会追加到旧列表后面
            pluginListModel.clear();

            var count = pluginManager.getPluginCount();
            for (var i = 0; i < count; i++) {
                pluginListModel.append(pluginManager.getPluginInfo(i));
            }
        }

        function onPluginStateChanged(pluginName, newState) {
            for (var i = 0; i < pluginListModel.count; i++) {
                if (pluginListModel.get(i).name === pluginName) {
                    pluginListModel.setProperty(i, "enabled", newState);
                    break;
                }
            }
        }
    }
}
