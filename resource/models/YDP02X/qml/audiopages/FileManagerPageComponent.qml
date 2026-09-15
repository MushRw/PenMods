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

    // 打开一个条目，唯一入口：
    //   目录 -> 进目录；软链接 -> 先当目录试，进不去再当文件；可执行 -> 执行；
    //   其余 -> 按 C++ 后缀表（fileManager.handlerFor）分发到播放器/文本/视频/图片。
    // 以前这段逻辑在 onClicked 里抄了两遍（软链接一份、普通文件一份），后缀映射
    // 也是 QML 自己维护的一份 fileHandlers，和 C++ 的图标表/音频白名单漂移过。
    function openEntry(fileName, isDir, isSymLink, isExecutable, extName) {
        if (isDir) {
            fileManager.changeDir(fileName);
            return;
        }
        if (isSymLink && fileManager.changeDir(fileName)) {
            return; // 软链接指向目录
        }
        if (isExecutable) {
            fileManager.executeFile(fileName);
            return;
        }
        var type = fileManager.handlerFor(extName);
        if (type === "play") {
            fileManager.playFromView(fileName);
        } else if (type === "text") {
            textReader.open(fileName);
            id_pop_container.show('FileManagerTextViewer');
        } else if (type === "video") {
            externalPlayer.select(fileName);
            id_pop_container.show('ExternalPlayer');
        } else if (type === "image") {
            imageViewer.open(fileName);
            id_pop_container.show('FileManagerImageViewer');
        } else {
            qmlGlobal.showToast("暂不支持该格式", YColors.yellow);
        }
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
                implicitHeight: 50 + (id_usb_disk_entry.visible ? 50 : 0)

                // U 盘入口：厂商自带的 usbmount 已经把 U 盘挂到 /media/usbN，
                // 这里只做"发现 + 跳转"，插上/拔下时自动出现和消失。
                YSettingAboutClickableItem {
                    id: id_usb_disk_entry
                    width: parent.width
                    implicitHeight: 50
                    visible: fileManager.usbDiskPresent
                    title: "U 盘"
                    value: fileManager.usbDiskPath
                    imageName: "settings/info_more_arrow"
                    onClicked: {
                        if (!fileManager.openUsbDisk())
                            qmlGlobal.showToast("U 盘已断开", YColors.yellow);
                    }
                }

                YTextBase {
                    color: YColors.grayText
                    font.pixelSize: 16
                    anchors.top: id_usb_disk_entry.visible ? id_usb_disk_entry.bottom : parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: !id_error_tip.visible
                    elide: YTextBase.ElideLeft
                    verticalAlignment: Text.AlignVCenter
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

                    // kNormal Mode Logic：目录/软链接/可执行/普通文件的打开分发只有一个入口
                    openEntry(model.fileName, isDir, model.isSymLink, model.isExecutable, model.extName);
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
