import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YPage {
    id: id_container_index

    readonly property int kNormal: 0
    readonly property int kDelete: 1
    readonly property int kRename: 2
    property int currentMode: kNormal
    property string operatingFileName: ""
    property bool operatingIsDir: false

    // 提取扩展名处理逻辑到查找表，避免巨大的 switch-case，提升查找速度
    readonly property var fileHandlers: {
        "mp3": "play",
        "flac": "play",
        "m4a": "play",
        "wav": "play",
        "ogg": "play",
        "aac": "play",
        "md": "text",
        "txt": "text",
        "json": "text",
        "yml": "text",
        "yaml": "text",
        "xml": "text",
        "lrc": "text",
        "avi": "video",
        "mp4": "video",
        "mov": "video",
        "flv": "video",
        "mkv": "video",
        "webm": "video",
        "jpg": "image",
        "jpeg": "image",
        "gif": "image",
        "svg": "image",
        "ico": "image",
        "png": "image",
        "bmp": "image",
        "webp": "image"
    }

    function showKeyboard() {
        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function (status) {
                    if (status === Component.Ready) {
                        id_page_pop_helper.inputPageCreated(incubator.object);
                    }
                };
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object);
            }
        }
    }

    Component.onCompleted: {
        fileManager.changeDir("");
    }

    onBackButtonClicked: {
        id_pop_container.closeAllPages();
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            id_error_tip.visible = false;
            if (visible && fileManager.canCdUp()) {
                fileManager.changeDir('..');
            } else {
                backButtonClicked();
                fileManager.reset();
            }
        }
    }

    YBaseListView {
        id: id_files_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        spacing: 8
        model: fileManager

        cacheBuffer: 200

        onMovingChanged: {
            if (!moving && atYEnd && fileManager.hasMore)
                fileManager.loadMore();
        }
        header: id_header_component
        footer: fileManager.hasMore ? id_listview_loading_footer : id_listview_loaded_footer
        onBusyingChanged: {
            if (!busying)
                id_files_view.positionViewAtBeginning();
        }

        Component {
            id: id_header_component
            Item {
                width: id_files_view.width
                implicitHeight: 50
                YTextBase {
                    color: YColors.grayText
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    visible: !id_error_tip.visible
                    elide: YTextBase.ElideLeft
                    text: fileManager.currentTitle
                    textFormat: Text.RichText
                }
            }
        }

        Component {
            id: id_listview_loading_footer
            YListViewLoadMoreFooter {}
        }

        Component {
            id: id_listview_loaded_footer
            YSpacing {
                width: id_files_view.width
                implicitHeight: 12
            }
        }

        delegate: Item {
            width: id_files_view.width
            implicitHeight: 50

            FileManagerPageComponentViewItem {
                implicitHeight: parent.implicitHeight
                title: model.fileName
                // 简化绑定
                value: (currentMode == kNormal && !isDir) ? model.sizeStr : ''

                iconComponent.source: {
                    if (currentMode === kDelete)
                        return res.getDisk('audioplayer/delete_indicator');
                    if (currentMode === kRename)
                        return res.get('edit-indicator');
                    // kNormal
                    return isDir ? res.getDisk('settings/info_more_arrow') : '';
                }

                onClicked: {
                    operatingFileName = model.fileName;
                    operatingIsDir = isDir;

                    if (currentMode == kDelete) {
                        id_delete_file_dialog.show();
                        return;
                    }
                    if (currentMode == kRename) {
                        showKeyboard();
                        return;
                    }

                    // kNormal Mode Logic
                    if (isDir) {
                        fileManager.changeDir(model.fileName);
                    } else if (model.isSymLink) {
                        // 如果是软链接，尝试进入链接指向的目录或打开链接指向的文件
                        let linkTarget = model.fileName; // 软链接本身作为文件名传入
                        let fileInfo = Qt.createQmlObject("import QtQuick 2.0; QtObject { property string target: '" + fileManager.getCurrentPathString() + "/" + linkTarget + "' }", id_container_index);

                        // 尝试切换到软链接指向的目录
                        if (!fileManager.changeDir(model.fileName)) {
                            // 如果不能切换目录（说明不是目录），则按文件处理
                            if (model.isExecutable) {
                                fileManager.executeFile(model.fileName);
                            } else {
                                // 使用 Map 查找代替 Switch
                                let type = fileHandlers[model.extName];
                                if (type === "play") {
                                    fileManager.playFromView(model.fileName);
                                } else if (type === "text") {
                                    textReader.open(model.fileName);
                                    id_pop_container.show('FileManagerTextViewer');
                                } else if (type === "video") {
                                    externalPlayer.select(model.fileName);
                                    id_pop_container.show('ExternalPlayer');
                                } else if (type === "image") {
                                    imageViewer.open(model.fileName);
                                    id_pop_container.show('FileManagerImageViewer');
                                } else {
                                    qmlGlobal.showToast("暂不支持该格式", YColors.yellow);
                                }
                            }
                        }
                    } else if (model.isExecutable) {
                        fileManager.executeFile(model.fileName);
                    } else {
                        // 使用 Map 查找代替 Switch
                        let type = fileHandlers[model.extName];
                        if (type === "play") {
                            fileManager.playFromView(model.fileName);
                        } else if (type === "text") {
                            textReader.open(model.fileName);
                            id_pop_container.show('FileManagerTextViewer');
                        } else if (type === "video") {
                            externalPlayer.select(model.fileName);
                            id_pop_container.show('ExternalPlayer');
                        } else if (type === "image") {
                            imageViewer.open(model.fileName);
                            id_pop_container.show('FileManagerImageViewer');
                        } else {
                            qmlGlobal.showToast("暂不支持该格式", YColors.yellow);
                        }
                    }
                }
            }
        }
    }

    YOneButtonDialog {
        id: id_delete_file_dialog
        z: parent.z + 1
        anchors.fill: parent
        tipItem.text: {
            // 简单的三元运算比重复赋值更高效
            let name = operatingFileName.length > 25 ? operatingFileName.substring(0, 24) + '...' : operatingFileName;
            let typeStr = operatingIsDir ? '文件夹' : '文件';
            return "确定要删除" + typeStr + " <i>\"" + name + "\"</i> 吗?";
        }
        tipItem.textFormat: YText.RichText
        buttonItem.text: "确定"
        onClicked: {
            fileManager.remove(operatingFileName);
            close();
        }
    }

    YPagePopHelper {
        id: id_page_pop_helper

        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function () {
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });
            keyboardPage.inputFinished.connect(function (content) {
                fileManager.rename(operatingFileName, content);
            });
            keyboardPage.placeHolderText = "请输入新文件" + (operatingIsDir ? "夹" : "") + "名";
            keyboardPage.enterText(operatingFileName);
            keyboardPage.show();
            qmlGlobal.inputPageShowing = true;
        }
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_FileManagerPageComponent.qml"
    }

    // Toolbar Items
    Item {
        z: parent.z
        visible: !qmlGlobal.inputPageShowing
        anchors.fill: parent
        anchors.topMargin: 80
        anchors.leftMargin: 0

        YIconButton {
            id: id_setting
            width: 30
            height: 30
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.top
            radius: 6
            source: "commons/more"
            onValidClicked: {
                id_pop_container.show('FileManagerDrawerLayer');
            }
        }

        YIconButton {
            id: id_rename
            width: 30
            height: 30
            anchors.top: id_setting.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            radius: 6
            enabled: id_files_view.count > 0 && (currentMode == kNormal || currentMode == kRename)
            source: currentMode == kRename ? "textbook/select-check" : "textbook/guid-scan"
            sourceSize: Qt.size(20, 20)
            onValidClicked: {
                currentMode = (currentMode != kRename) ? kRename : kNormal;
            }
        }

        YIconButton {
            id: id_delete
            width: 30
            height: 30
            anchors.top: id_rename.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            radius: 6
            enabled: id_files_view.count > 0 && (currentMode == kNormal || currentMode == kDelete)
            source: currentMode == kDelete ? "textbook/select-check" : "ic_delete"
            sourceSize: Qt.size(20, 20)
            onValidClicked: {
                currentMode = (currentMode != kDelete) ? kDelete : kNormal;
            }
        }
    }

    YText {
        id: id_error_tip
        anchors.centerIn: parent
        color: YColors.white
        visible: false
        font.pixelSize: 20
        // 如果错误提示不含 HTML，使用 PlainText
        textFormat: Text.PlainText

        Connections {
            target: fileManager
            function onException(msg) {
                id_error_tip.visible = true;
                id_error_tip.text = msg;
            }
        }
    }

    YOneButtonDialog {
        id: id_reload_dialog
        z: parent.z + 1
        anchors.fill: parent
        tipItem.text: "当前文件夹内容发生变化"
        buttonItem.text: "重新加载"
        showClose: false
        onClicked: {
            currentMode = kNormal;
            fileManager.reload();
            close();
        }

        Connections {
            target: fileManager
            function onDirectoryChanged() {
                if (!id_reload_dialog.isShowing && fileManager.shouldNotifyDirChanged())
                    id_reload_dialog.show();
            }
        }
    }

    YDynamicPageStack {
        id: id_pop_container
        logTag: "FileManagerPageComponent"

        // 增加 Component 缓存，避免每次打开文件都重新编译 QML
        property var componentCache: ({})

        function show(tpage) {
            function newComponentInit(incubatorObject) {
                if (!incubatorObject)
                    return;

                registerPage(incubatorObject, tpage, {
                    "pageIndex": YEnum.PageIndex.Audioplayer
                });
                incubatorObject.show();
            }

            closeSameItem(tpage);

            // [核心优化] 检查缓存
            var comp = componentCache[tpage];
            if (!comp) {
                console.log("Creating component cache for:", tpage);
                comp = Qt.createComponent(("./%1.qml").arg(tpage));
                if (comp.status === Component.Error) {
                    console.log("Error loading component:", tpage, comp.errorString());
                    return;
                }
                componentCache[tpage] = comp;
            }

            function incubateComponent() {
                var incubator = comp.incubateObject(id_pop_container);
                if (incubator.status !== Component.Ready) {
                    incubator.onStatusChanged = function (status) {
                        if (status === Component.Ready)
                            newComponentInit(incubator.object);
                    };
                } else {
                    newComponentInit(incubator.object);
                }
            }

            if (comp.status === Component.Ready) {
                incubateComponent();
            } else if (comp.status === Component.Loading) {
                const onComponentStatusChanged = function() {
                    if (comp.status === Component.Loading)
                        return;

                    comp.statusChanged.disconnect(onComponentStatusChanged);
                    if (comp.status === Component.Ready)
                        incubateComponent();
                    else
                        console.error("Error loading component:", tpage,
                                      comp.errorString());
                };
                comp.statusChanged.connect(onComponentStatusChanged);
            }
        }
        anchors.fill: parent
    }
}
