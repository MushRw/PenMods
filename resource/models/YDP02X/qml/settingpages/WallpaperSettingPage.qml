import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===WallpaperSettingPage.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height + 20

        Column {
            id: id_column
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            // ======================================
            YSettingItemTitle {
                title: "壁纸模式"
            }

            // 模式选择：无壁纸
            YSettingItemBackground {
                id: id_mode_none
                implicitHeight: 44
                opacity: id_mouse_none.pressed ? 0.6 : 1.0

                property bool isSelected: wallpaperManager.wallpaperMode === 0

                YText {
                    text: "不使用壁纸"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    color: id_mode_none.isSelected ? "#62A8EA" : "#FFFFFF"
                }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    border.width: id_mode_none.isSelected ? 0 : 2
                    border.color: "#5A6B7D"
                    color: id_mode_none.isSelected ? "#2B5278" : "transparent"

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.centerIn: parent
                        color: id_mode_none.isSelected ? "#62A8EA" : "transparent"
                    }
                }

                YMouseArea {
                    id: id_mouse_none
                    anchors.fill: parent
                    onClicked: {
                        wallpaperManager.wallpaperMode = 0
                    }
                }
            }

            // 模式选择：单张自定义
            YSettingItemBackground {
                id: id_mode_single
                implicitHeight: 44
                opacity: id_mouse_single.pressed ? 0.6 : 1.0

                property bool isSelected: wallpaperManager.wallpaperMode === 1

                YText {
                    text: "单张自定义"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    color: id_mode_single.isSelected ? "#62A8EA" : "#FFFFFF"
                }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    border.width: id_mode_single.isSelected ? 0 : 2
                    border.color: "#5A6B7D"
                    color: id_mode_single.isSelected ? "#2B5278" : "transparent"

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.centerIn: parent
                        color: id_mode_single.isSelected ? "#62A8EA" : "transparent"
                    }
                }

                YMouseArea {
                    id: id_mouse_single
                    anchors.fill: parent
                    onClicked: {
                        wallpaperManager.wallpaperMode = 1
                    }
                }
            }

            // 模式选择：随机循环
            YSettingItemBackground {
                id: id_mode_cycle
                implicitHeight: 44
                opacity: id_mouse_cycle.pressed ? 0.6 : 1.0

                property bool isSelected: wallpaperManager.wallpaperMode === 2

                YText {
                    text: "随机循环"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    color: id_mode_cycle.isSelected ? "#62A8EA" : "#FFFFFF"
                }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    border.width: id_mode_cycle.isSelected ? 0 : 2
                    border.color: "#5A6B7D"
                    color: id_mode_cycle.isSelected ? "#2B5278" : "transparent"

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.centerIn: parent
                        color: id_mode_cycle.isSelected ? "#62A8EA" : "transparent"
                    }
                }

                YMouseArea {
                    id: id_mouse_cycle
                    anchors.fill: parent
                    onClicked: {
                        wallpaperManager.wallpaperMode = 2
                    }
                }
            }

            // ======================================
            // 预览区域（仅壁纸模式非 0 时显示）
            // ======================================

            YSettingItemTitle {
                id: id_preview_title
                title: "当前壁纸"
                anchors.left: parent.left
                anchors.right: parent.right
                visible: wallpaperManager.wallpaperMode !== 0
            }

            // 有壁纸：显示预览（使用 Loader 延迟加载，避免空路径错误）
            Loader {
                width: parent.width
                height: 80
                active: wallpaperManager.currentWallpaper.length > 0 && wallpaperManager.wallpaperMode !== 0

                sourceComponent: Rectangle {
                    width: parent.width
                    height: 80
                    radius: 8
                    color: "#182533"
                    border.width: 1
                    border.color: "#2B3A4A"

                    YImage {
                        anchors.fill: parent
                        anchors.margins: 4
                        fillMode: Image.PreserveAspectCrop
                        source: "file://" + wallpaperManager.currentWallpaper
                        sourceSize: Qt.size(parent.width, parent.height)
                    }
                }
            }

            // 无壁纸：显示提示
            YText {
                width: parent.width
                height: 80
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "暂无壁纸"
                color: YColors.grayText
                font.pixelSize: 14
                visible: wallpaperManager.currentWallpaper.length === 0 && wallpaperManager.wallpaperMode !== 0
            }

            // ======================================
            // 选择图片（单张模式）
            // ======================================

            Item {
                width: parent.width
                height: id_single_section.height
                visible: wallpaperManager.wallpaperMode === 1

                Column {
                    id: id_single_section
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    YSettingItemBackground {
                        implicitHeight: 44
                        opacity: id_mouse_pick.pressed ? 0.6 : 1.0

                        YText {
                            text: "选择图片"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                        }

                        YText {
                            text: "浏览"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            color: YColors.grayText
                            font.pixelSize: 14
                        }

                        YMouseArea {
                            id: id_mouse_pick
                            anchors.fill: parent
                            onClicked: {
                                openFileSelector();
                            }
                        }
                    }

                    YText {
                        text: wallpaperManager.customImagePath.length > 0
                            ? "当前: " + wallpaperManager.customImagePath
                            : "尚未选择图片"
                        color: YColors.grayText
                        font.pixelSize: 11
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        wrapMode: Text.Wrap
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ======================================
            // 循环模式：选择文件夹 + 间隔
            // ======================================

            Item {
                width: parent.width
                height: id_cycle_section.height
                visible: wallpaperManager.wallpaperMode === 2

                Column {
                    id: id_cycle_section
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    // 选择文件夹
                    YSettingItemBackground {
                        implicitHeight: 44
                        opacity: id_mouse_folder.pressed ? 0.6 : 1.0

                        YText {
                            text: "选择壁纸文件夹"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                        }

                        YText {
                            text: "浏览"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            color: YColors.grayText
                            font.pixelSize: 14
                        }

                        YMouseArea {
                            id: id_mouse_folder
                            anchors.fill: parent
                            onClicked: {
                                openFileSelector();
                            }
                        }
                    }

                    YText {
                        text: wallpaperManager.wallpaperFolder.length > 0
                            ? "文件夹: " + wallpaperManager.wallpaperFolder
                            : "尚未选择文件夹"
                        color: YColors.grayText
                        font.pixelSize: 11
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        wrapMode: Text.Wrap
                        elide: Text.ElideMiddle
                    }

                    // 切换间隔
                    YText {
                        text: "切换间隔"
                        color: YColors.grayText
                        font.pixelSize: 16
                        font.italic: true
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.topMargin: 8
                    }

                    Item {
                        width: parent.width
                        height: 50

                        YText {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var sec = wallpaperManager.cycleInterval;
                                if (sec < 60) return sec + "秒";
                                if (sec < 3600) return Math.floor(sec / 60) + "分钟";
                                return Math.floor(sec / 3600) + "小时";
                            }
                            color: "#FFFFFF"
                            font.pixelSize: 14
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 80
                            height: 32
                            radius: 6
                            color: "#2C2C2E"

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                YMouseArea {
                                    width: 24
                                    height: 24
                                    onClicked: {
                                        var v = wallpaperManager.cycleInterval;
                                        if (v > 30) wallpaperManager.cycleInterval = v - 30
                                    }
                                    YText {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: "#62A8EA"
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }

                                YMouseArea {
                                    width: 24
                                    height: 24
                                    onClicked: {
                                        var v = wallpaperManager.cycleInterval;
                                        if (v < 3600) wallpaperManager.cycleInterval = v + 30
                                    }
                                    YText {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: "#62A8EA"
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    // 预置间隔快捷按钮
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "30 秒", value: 30 },
                                { label: "1 分",  value: 60 },
                                { label: "5 分",  value: 300 },
                                { label: "10 分", value: 600 },
                                { label: "30 分", value: 1800 }
                            ]

                            Rectangle {
                                width: 48
                                height: 28
                                radius: 6
                                color: wallpaperManager.cycleInterval === modelData.value ? "#2B5278" : "#2C2C2E"
                                border.width: wallpaperManager.cycleInterval === modelData.value ? 1 : 0
                                border.color: "#62A8EA"

                                YText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: wallpaperManager.cycleInterval === modelData.value ? "#62A8EA" : "#8A9BAE"
                                    font.pixelSize: 11
                                }

                                YMouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        wallpaperManager.cycleInterval = modelData.value
                                    }
                                }
                            }
                        }
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 16
            }
        }
    }

    // 用于容纳文件选择器的容器
    Item {
        id: id_selector_container
        anchors.fill: parent
        z: 1000
    }

    // 打开文件选择器
    function openFileSelector() {
        var component = Qt.createComponent("../audiopages/FileManagerSelector.qml");
        if (component.status === Component.Ready) {
            var props = {};
            if (wallpaperManager.wallpaperMode === 1) {
                props.fileExtensions = ["png", "jpg", "jpeg", "bmp"];
            }
            var selector = component.createObject(id_selector_container, props);
            if (selector) {
                selector.fileSelected.connect(onFileSelected);
                selector.fileSelectionCancelled.connect(function() {
                    selector.destroy();
                });
                selector.backButtonClicked.connect(function() {
                    selector.destroy();
                });
                selector.show();
            }
        } else if (component.status === Component.Error) {
            console.error("Failed to load FileManagerSelector:", component.errorString());
        } else {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    var props = {};
                    if (wallpaperManager.wallpaperMode === 1) {
                        props.fileExtensions = ["png", "jpg", "jpeg", "bmp"];
                    }
                    var selector = component.createObject(id_selector_container, props);
                    if (selector) {
                        selector.fileSelected.connect(onFileSelected);
                        selector.fileSelectionCancelled.connect(function() {
                            selector.destroy();
                        });
                        selector.backButtonClicked.connect(function() {
                            selector.destroy();
                        });
                        selector.show();
                    }
                }
            });
        }
    }

    function onFileSelected(path) {
        if (wallpaperManager.wallpaperMode === 1) {
            wallpaperManager.customImagePath = path;
        } else if (wallpaperManager.wallpaperMode === 2) {
            var lastSlash = path.lastIndexOf("/");
            if (lastSlash > 0) {
                wallpaperManager.wallpaperFolder = path.substring(0, lastSlash);
            }
        }
        // 清理所有选择器实例
        for (var i = id_selector_container.children.length - 1; i >= 0; i--) {
            try {
                id_selector_container.children[i].destroy();
            } catch(e) {}
        }
    }
}