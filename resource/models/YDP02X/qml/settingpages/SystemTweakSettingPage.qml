import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===SystemTweakSettingPage.qml"

    function requestKeyboard() {
        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready)
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready)
                        id_page_pop_helper.inputPageCreated(incubator.object);
                };
            else
                id_page_pop_helper.inputPageCreated(incubator.object);
        }
    }

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height

        Column {
            id: id_column
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            // ======================================

            YText {
                id: id_title_log
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "日志策略"
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "阻止上传行为记录"
                switchOn: loggerMonitor.noUploadUserAction
                interval: 0
                onTimerTriggered: {
                    loggerMonitor.noUploadUserAction = switchOn
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "阻止上传扫描图像"
                switchOn: loggerMonitor.noUploadRawScanImg
                interval: 0
                onTimerTriggered: {
                    loggerMonitor.noUploadRawScanImg = switchOn
                }
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "阻止上传HTTP日志"
                switchOn: loggerMonitor.noUploadHttplog
                interval: 0
                onTimerTriggered: {
                    loggerMonitor.noUploadHttplog = switchOn
                }
            }

            // ======================================

            YText {
                id: id_title_column_db
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "列式数据库"
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "提高单次加载数量"
                switchOn: columnDb.patch
                interval: 0
                onTimerTriggered: {
                    columnDb.patch = switchOn
                }
            }

            // ======================================

            YText {
                id: id_title_other
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "音乐播放器"
            }

            YSettingSwitchItem {
                implicitHeight: 54
                title: "扫描时暂停播放"
                //switchOn: musicPlayer.pauseOnScan
                switchOn: false
                interval: 0
                onTimerTriggered: {
                    musicPlayer.pauseOnScan = switchOn
                }
            }

            // ======================================

            YText {
                id: id_title_vpn
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "VPN"
            }

            DescribedSwitchItem {
                implicitHeight: 54
                title: "启用 VPN"
                description: "使用订阅链接启动本地代理，笔上应用的联网流量将走代理。"
                switchOn: vpnManager.enabled
                interval: 0
                onTimerTriggered: {
                    vpnManager.enabled = switchOn
                }
            }

            DescribedClickableTextBox {
                title: "订阅链接"
                describe: vpnManager.subscriptionUrl.length != 0 ? vpnManager.subscriptionUrl : "[未配置]"
                opacityChangableWhenPressed: false
                onClicked: {
                    requestKeyboard();
                }
            }

            YText {
                font.pixelSize: 14
                color: vpnManager.running ? YColors.green : YColors.grayText
                width: parent.width
                text: vpnManager.running ? "VPN 已连接" : "VPN 未连接"
            }

            YSpacingForColumn {
                implicitHeight: 16
            }
        }

    }

    YPagePopHelper {
        id: id_page_pop_helper

        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });
            keyboardPage.inputFinished.connect(function(content) {
                vpnManager.subscriptionUrl = content;
            });
            keyboardPage.show();
            keyboardPage.enterText(vpnManager.subscriptionUrl);
            qmlGlobal.inputPageShowing = true;
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_SystemTweakSettingPage"
    }
}
