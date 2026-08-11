import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YPage {
    id: id_container_index

    // 文件选择器的属性
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property bool allowMultiSelect: false
    property var selectedFiles: []
    property var fileExtensions: [] // 允许的文件扩展名，空表示所有文件
    signal fileSelected(string filePath)
    signal fileSelectionCancelled()

    // 从 FileManagerPageComponent 继承的属性
    readonly property int kNormal: 0
    readonly property int kDelete: 1
    readonly property int kRename: 2
    property int currentMode: kNormal
    property string operatingFileName: ""
    property bool operatingIsDir: false

    Component.onCompleted: {
        fileManager.changeDir("");
    }

    onBackButtonClicked: {
        fileSelectionCancelled();
        id_pop_container.popItemObject = null;
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            id_error_tip.visible = false;
            if (visible && fileManager.canCdUp()) {
                fileManager.changeDir('..');
            } else {
                fileSelectionCancelled();
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
                    text: "选择文件"
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
                id: fileItem
                implicitHeight: parent.implicitHeight
                title: model.fileName
                // 简化绑定
                value: (currentMode == kNormal && !isDir) ? model.sizeStr : ''

                iconComponent.source: {
                    // kNormal Mode - 显示选择指示器
                    if (selectedFiles.indexOf(model.fileName) !== -1) {
                        return res.getDisk('settings/info_selected');
                    }
                    // kNormal
                    return isDir ? res.getDisk('settings/info_more_arrow') : '';
                }

                onClicked: {
                    operatingFileName = model.fileName;
                    operatingIsDir = isDir;

                    // 文件选择逻辑
                    if (isDir) {
                        fileManager.changeDir(model.fileName);
                    } else if (model.isSymLink) {
                        // 如果是软链接，尝试进入链接指向的目录
                        if (!fileManager.changeDir(model.fileName)) {
                            // 如果不能切换目录（说明不是目录），则按文件处理
                            // 检查文件扩展名是否符合要求
                            if (fileExtensions.length > 0 && fileExtensions.indexOf(model.extName) === -1) {
                                qmlGlobal.showToast("不支持的文件格式", YColors.yellow);
                                return;
                            }

                            if (allowMultiSelect) {
                                // 多选模式
                                var index = selectedFiles.indexOf(model.fileName);
                                if (index === -1) {
                                    // 添加到选择列表
                                    selectedFiles.push(model.fileName);
                                } else {
                                    // 从选择列表移除
                                    selectedFiles.splice(index, 1);
                                }
                                // 更新 UI
                                id_files_view.model.data(id_files_view.model.index(model.index, 0),
                                    id_files_view.model.roles.ExtensionIcon);
                            } else {
                                // 单选模式
                                selectedFilePath = fileManager.getCurrentPathString() + "/" + model.fileName;
                                fileSelected(selectedFilePath);
                                backButtonClicked();
                            }
                        }
                    } else {
                        // 检查文件扩展名是否符合要求
                        if (fileExtensions.length > 0 && fileExtensions.indexOf(model.extName) === -1) {
                            qmlGlobal.showToast("不支持的文件格式", YColors.yellow);
                            return;
                        }

                        if (allowMultiSelect) {
                            // 多选模式
                            var index = selectedFiles.indexOf(model.fileName);
                            if (index === -1) {
                                // 添加到选择列表
                                selectedFiles.push(model.fileName);
                            } else {
                                // 从选择列表移除
                                selectedFiles.splice(index, 1);
                            }
                            // 更新 UI
                            id_files_view.model.data(id_files_view.model.index(model.index, 0),
                                id_files_view.model.roles.ExtensionIcon);
                        } else {
                            // 单选模式
                                selectedFilePath = fileManager.getCurrentPathString() + "/" + model.fileName;
                                fileSelected(selectedFilePath);
                                backButtonClicked();
                        }
                    }
                }
            }
        }
    }

    // 底部操作栏 - 仅在多选模式下显示
    Item {
        id: id_bottom_toolbar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        visible: allowMultiSelect

        Rectangle {
            anchors.fill: parent
            color: "#2B3A4A"
        }

        Row {
            anchors.centerIn: parent
            spacing: 20

            YButton {
                text: "取消"
                width: 80
                height: 36
                radius: 6
                color: "#5A6B7D"
                textColor: "#FFFFFF"
                onClicked: {
                    fileSelectionCancelled();
                    backButtonClicked();
                }
            }

            YButton {
                text: "确认 (" + selectedFiles.length + ")"
                width: 120
                height: 36
                radius: 6
                color: "#2B5278"
                textColor: "#FFFFFF"
                enabled: selectedFiles.length > 0
                onClicked: {
                    if (selectedFiles.length > 0) {
                        // 构建完整路径
                        var paths = [];
                        for (var i = 0; i < selectedFiles.length; i++) {
                            paths.push(fileManager.getCurrentPathString() + "/" + selectedFiles[i]);
                        }
                        selectedFilePath = paths.join(";");
                        fileSelected(selectedFilePath);
                        backButtonClicked();
                    }
                }
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
}