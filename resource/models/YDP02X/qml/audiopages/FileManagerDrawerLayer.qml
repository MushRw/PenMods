import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"
import "../settingpages"

YBackButtonPage {
    id: id_setting_item
    objectName: "YPage===FileManagerDrawerPage.qml"

    property bool passedVerification: false

    Flickable {
        id: id_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column.height

        YSettingItemTitle {
            id: id_title_container
            title: "选择排序方式"
        }

        Column {
            id: id_column
            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 9

            Grid {
                id: id_grid
                anchors.left: parent.left
                anchors.right: parent.right
                columns: 2
                rowSpacing: 8
                columnSpacing: 6

                Repeater {
                    id: rep
                    model: id_filter_model
                    YButton {
                        id: id_button
                        implicitWidth: 125
                        mouseAreaMargins: -4
                        color: orderType == fileManager.order ? YColors.red : "#2D2E33"
                        text: {
                            switch (orderType) {
                            case 0x00:
                                return "文件名";
                            case 0x01:
                                return "修改日期";
                            case 0x02:
                                return "大小";
                            case 0x80:
                                return "类型";
                            case 0x10000:  // NATURAL_SORT constant value
                                return "自然排序";
                            }
                        }
                        onClicked: {
                            fileManager.order = orderType;
                            fileManager.reload();
                            close();
                        }
                    }
                }
            }

            YText {
                text: "其他设置"
                color: YColors.grayText
                font.pixelSize: 16
                anchors.left: parent.left
            }

            YSettingSwitchItem {
                title: '反转排列顺序'
                switchOn: fileManager.orderReversed
                onTimerTriggered: {
                    fileManager.orderReversed = switchOn;
                }
            }

            DescribedSwitchItem {
                title: "自动隐藏歌词文件"
                description: "隐藏已匹配到歌曲的 lrc 歌词文件。"
                switchOn: fileManager.hidePairedLyrics
                interval: 0
                onTimerTriggered: {
                    fileManager.hidePairedLyrics = switchOn;
                }
            }

            DescribedSwitchItem {
                id: hidden_files_setting
                title: "显示隐藏文件"
                description: "显示以 . 开头的隐藏文件。"
                switchOn: fileManager.showHiddenFiles
                interval: 0
                onTimerTriggered: {
                    if (id_setting_item.passedVerification == false && locker.enabled && locker.getScene("filemanager")) {
                        switchOn = !switchOn;
                        id_setting_item.requestKeyboard();
                    }
                    if (!locker.enabled || !locker.getScene("filemanager") || id_setting_item.passedVerification == true) {
                        fileManager.showHiddenFiles = switchOn;
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }
        }
    }

    ListModel {
        id: id_filter_model
        Component.onCompleted: {
            append({
                orderType: 0x00
            });
            append({
                orderType: 0x01
            });
            append({
                orderType: 0x02
            });
            append({
                orderType: 0x80
            });
            append({
                orderType: 0x10000  // NATURAL_SORT constant value (65536 in decimal)
            });
            // id_delay_timer.start()
        }
    }

    onBackButtonClicked: fileManager.reload()

    function requestKeyboard() {
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

    YPagePopHelper {
        id: id_page_pop_helper
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_PagePopHelper.qml"

        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function () {
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });
            keyboardPage.inputFinished.connect(function (content) {
                if (content === locker.password) {
                    hidden_files_setting.switchOn = !hidden_files_setting.switchOn
                    fileManager.showHiddenFiles = hidden_files_setting.switchOn;
                    passedVerification = true;
                } else {
                    qmlGlobal.showToast("密码错误，请重试", YColors.yellow);
                    requestKeyboard();
                }
            });
            keyboardPage.placeHolderText = "请输入密码...";
            keyboardPage.show();
            qmlGlobal.inputPageShowing = true;
        }
    }
}
