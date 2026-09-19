import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===SystemTweakSettingPage.qml"

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

            // 主题：切换 theme.id 会让所有绑定 YColors 的界面立刻重绘，并且写进 config.json
            YText {
                id: id_title_theme
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "主题"
            }

            Row {
                spacing: 8

                Repeater {
                    model: theme.availableThemes

                    Rectangle {
                        width: 96
                        height: 34
                        radius: 8
                        color: theme.id === modelData ? YColors.blueRect : YColors.grayButton
                        border.width: 1
                        border.color: YColors.border

                        YText {
                            anchors.centerIn: parent
                            font.pixelSize: 13
                            text: {
                                if (modelData === "official")
                                    return "官方深灰";
                                if (modelData === "pureBlack")
                                    return "纯黑省电";
                                return modelData;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                theme.id = modelData;
                                qmlGlobal.showToast("主题已切换：" + modelData);
                            }
                        }
                    }
                }
            }

            // 表面风格：全树统一从 theme.surfaceStyle 派生（YColors 的 surface 系列令牌 + glassEnabled）
            YText {
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "界面材质"
            }

            Row {
                spacing: 8

                Repeater {
                    model: ["opaque", "translucent", "glass"]

                    Rectangle {
                        width: 96
                        height: 34
                        radius: 8
                        color: theme.surfaceStyle === modelData ? YColors.blueRect : YColors.surfaceButton
                        border.width: 1
                        border.color: YColors.border

                        YText {
                            anchors.centerIn: parent
                            font.pixelSize: 13
                            text: {
                                if (modelData === "opaque")
                                    return "不透明";
                                if (modelData === "translucent")
                                    return "半透明";
                                return "毛玻璃";
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                theme.surfaceStyle = modelData;
                                qmlGlobal.showToast("界面材质：" + (modelData === "opaque" ? "不透明"
                                                                   : (modelData === "translucent" ? "半透明" : "毛玻璃")));
                            }
                        }
                    }
                }
            }

            YText {
                font.pixelSize: 14
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 20
                width: parent.width
                text: "切换后整个界面立刻换色，并保存在 config.json（重启保持）。"
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

            YSpacingForColumn {
                implicitHeight: 16
            }

            // ======================================
            // 卡顿时用：重启界面（= 重启一次主程序）
            //
            // 背景：厂商的 input-event-daemon 有启动竞态，偶尔会卡进用户态死循环、
            // 白吃一个核（实测 302/300 tick），表现就是界面/播放卡、点一下要等。
            // 重启主程序会把它一起重置（实测重启后立刻恢复平静）。
            YText {
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "卡顿处理"
            }

            YSettingAboutClickableItem {
                implicitHeight: 54
                title: "重启界面"
                value: "卡顿时点这里"
                onClicked: {
                    qmlGlobal.showToast("正在重启界面，请稍候…", YColors.yellow);
                    mod.softReboot();
                }
            }

            YText {
                font.pixelSize: 14
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 20
                width: parent.width
                text: "若界面或播放变卡，重启界面可重置输入守护进程（比重启设备更快）。"
            }
        }

    }

}
