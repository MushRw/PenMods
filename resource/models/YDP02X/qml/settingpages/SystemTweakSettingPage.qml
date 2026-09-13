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

            YText {
                id: id_title_sound
                font.pixelSize: 16
                font.italic: true
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 24
                width: parent.width
                text: "声音"
            }

            // 关掉 = 把自带扬声器“卸掉”（asound.conf 里扬声器通路的 Playback Path 由 SPK 改成 OFF），
            // 任何 App（朗读/音乐/提示音）都推不动扬声器；耳机通路不动，插耳机照常有声。
            YSettingSwitchItem {
                implicitHeight: 54
                title: "自带扬声器"
                switchOn: aSound.speakerEnabled
                interval: 0
                onTimerTriggered: {
                    aSound.speakerEnabled = switchOn
                }
            }

            YText {
                id: id_speaker_tip
                font.pixelSize: 14
                color: YColors.grayText
                wrapMode: YText.Wrap
                lineHeightMode: YTextBase.FixedHeight
                lineHeight: 20
                width: parent.width
                text: "关闭后扬声器不会出声（插耳机仍可听），重启后保持；下拉快捷面板里也能一键切换。"
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
        }

    }

}
