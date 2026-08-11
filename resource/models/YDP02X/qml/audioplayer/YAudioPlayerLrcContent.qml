import QtQuick 2.12
import QtQml.Models 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    id: id_content_container
    anchors.fill: parent
    anchors.leftMargin: 54
    anchors.rightMargin: 10
    readonly property bool isPlaying: YEnum.PLAYING === mediaPlayerManager.playState
    readonly property bool noLrcTip: isShowing && ((lrcStateList && lrcStateIndex < lrcStateList.length && YEnum.LS_HIDE === lrcStateList[lrcStateIndex])
    || !mediaPlayerManager.hasLrc)

    function show() {
        id_delay_show_lrc_timer.restart()
        id_delay_play_state_pause_confirm_timer.restart()
    }

    function playStatePauseConfirm() {
        if (!isPlaying) {
            id_player_state_mask_show.restart()
        }
    }

    onNoLrcTipChanged: {
        if (noLrcTip) {
            id_delay_show_tip_timer.restart()
        } else {
            id_delay_show_tip_timer.stop()
            id_delay_show_tip.visible = false
        }
    }

    YBaseListView {
        id: id_lrc_main_show
        anchors.fill: parent
        spacing: 16
        currentIndex: mediaPlayerManager.currentSentenceId >= 0 ? mediaPlayerManager.currentSentenceId : 0
        model: id_lrc_filter_model

        header: id_header_component
        footer: id_footer_component

        preferredHighlightBegin: height / 2 - 20
        preferredHighlightEnd: height / 2 + 20
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: 500
    }

    Component {
        id: id_header_component
        YBackground {
            id: id_title_area
            width: id_lrc_main_show.width
            implicitHeight: 50

            YText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 16
                color: YColors.grayText
                elide: YText.ElideRight
                font.family: qmlGlobal.fontFamilyZhCn
                text: mediaPlayerManager.title
            }
        }
    }

    Component {
        id: id_footer_component
        Item {
            width: id_lrc_main_show.width
            implicitHeight: 50
            YBackground {
                anchors.fill: parent
            }
        }
    }

    DelegateModel {
        id: id_lrc_filter_model
        model: mediaPlayerManager

        delegate: Item {
            id: id_delegate_item
            width: id_lrc_main_show.width
            height: id_sentence_column.implicitHeight
            // 提取数据，减少深层属性访问
            readonly property var modelData: model.modelData
            readonly property string mainLrc: modelData.mainLrc
            readonly property string transLrc: modelData.transLrc
            readonly property bool isCurrentLrc: modelData.id === mediaPlayerManager.currentSentenceId
            readonly property bool hasKeyPoint: modelData.hasKeyPoint

            readonly property string currentFontFamily: qmlGlobal.fontFamilyZhCn

            Column {
                id: id_sentence_column
                spacing: 4
                width: parent.width

                YText {
                    id: id_sentence_main_lrc
                    width: parent.width
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 26
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 20
                    textFormat: YText.RichText
                    opacity: isCurrentLrc ? 1.0 : 0.16

                    visible: isShowing && !id_delay_show_lrc_timer.running && mediaPlayerManager.hasLrc &&
                    ((YEnum.LS_BILINGUAL === lrcStateList[lrcStateIndex]) || (YEnum.LS_ORIGINAL === lrcStateList[lrcStateIndex]))

                    text: {
                        if (!visible) return ""

                            if (isCurrentLrc) {
                                let endIndex = mediaPlayerManager.sentencePlayingEnd > 0 ? mediaPlayerManager.sentencePlayingEnd :
                                (hasKeyPoint ? 0 : mainLrc.length)

                                let played = mainLrc.substring(0, endIndex)
                                let unplayed = endIndex < mainLrc.length ? mainLrc.substring(endIndex) : ""

                                return `<span style="font-family: ${currentFontFamily}; color:${YColors.blueText}">${played}</span>` +
                                (unplayed ? `<span style="font-family: ${currentFontFamily}; color:${YColors.white}">${unplayed}</span>` : "")
                            } else {
                                return `<span style="font-family: ${currentFontFamily}">${mainLrc}</span>`
                            }
                    }
                }

                YText {
                    id: id_sentence_trans_lrc
                    width: parent.width
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 26
                    wrapMode: TextEdit.Wrap
                    anchors.topMargin: 6
                    textFormat: YText.RichText
                    opacity: isCurrentLrc ? 1.0 : 0.16
                    visible: isShowing && !id_delay_show_lrc_timer.running && mediaPlayerManager.hasLrc &&
                    ((YEnum.LS_BILINGUAL === lrcStateList[lrcStateIndex]) || (YEnum.LS_TRANS === lrcStateList[lrcStateIndex])) &&
                    transLrc.length > 0
                    text: {
                        if (!visible) return ""
                            let txtColor = isCurrentLrc ? (id_sentence_main_lrc.visible ? YColors.grayText : YColors.blueText) : ""
                            if (isCurrentLrc) {
                                return `<span style="font-family: ${currentFontFamily}; color:${txtColor}">${transLrc}</span>`
                            } else {
                                return `<span style="font-family: ${currentFontFamily}">${transLrc}</span>`
                            }
                    }
                }
            }
        }
    }

    YTimer {
        id: id_delay_show_lrc_timer
        interval: 900
    }

    YTimer {
        id: id_delay_play_state_pause_confirm_timer
        interval: 120
        onTriggered: {
            playStatePauseConfirm()
        }
    }

    YAudioPlayerLrcMouseArea {
        objectName: "YAudioPlayer.qml_YText_hasLrc_YMouseArea"
    }

    Item {
        id: id_content_column
        anchors {fill: parent; topMargin: 50}

        YTimer {
            id: id_delay_show_tip_timer
            interval: 500
            onTriggered: {
                if (noLrcTip) {
                    id_delay_show_tip.visible = true
                }
            }
        }

        YSpacingForColumn {
            id: id_delay_show_tip
            implicitHeight: 254 - 50
            visible: false

            YMouseArea {
                anchors.fill: parent
                objectName: "YAudioPlayer.qml_id_no_any_lrc"
                enabled: !id_player_state_mask_container.visible
                onClicked: {
                    id_player_state_mask_show.show()
                }
            }

            Item {
                id: id_no_lrc_show_container
                anchors.top: parent.top
                anchors.topMargin: 30
                anchors.horizontalCenter: parent.horizontalCenter

                width: id_label.width
                implicitHeight: 24

                YText {
                    id: id_label
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: YColors.grayText
                    width: paintedWidth
                    height: paintedHeight
                    text: {
                        if (lrcStateList && lrcStateIndex < lrcStateList.length && YEnum.LS_HIDE === lrcStateList[lrcStateIndex]) {
                            return YTranslateText.subtitleHidden
                        }
                        if (!mediaPlayerManager.hasLrc) {
                            return YTranslateText.noSubtitles
                        }
                        return ""
                    }
                }

                YAudioPlayerLrcMouseArea {
                    objectName: "YAudioPlayer.qml_YText_noLrc_YMouseArea"
                }
            }
        }
    }

    Item {
        id: id_player_state_mask_container
        anchors.fill: parent
        visible: false

        Rectangle {
            id: id_player_state_mask
            anchors.fill: parent
            enabled: false
            color: "#000000"
            radius: 0

            QtObject {
                id: id_player_state_mask_show

                function show() {
                    mediaPlayerManager.onClickedPause()
                    restart()
                }

                function restart() {
                    id_player_state_mask_container.visible = true
                    id_player_state_mask.opacity = 0.8
                    id_player_state_center_indicator.opacity = 1
                    id_player_state_mask.enabled = true
                }
            }

            SequentialAnimation {
                id: id_player_state_mask_hide
                ScriptAction {
                    script: {
                        id_player_state_mask.enabled = false
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: id_player_state_mask; property: "opacity"; to: 0; duration: 1200 }
                    NumberAnimation { target: id_player_state_center_indicator; property: "opacity"; to: 0; duration: 1200 }
                }
                ScriptAction { script: id_player_state_mask_container.visible = false }
            }
        }

        Rectangle {
            id: id_player_state_center_indicator
            implicitWidth: 44
            implicitHeight: 44
            anchors.centerIn: parent
            radius: height/2
            color: YColors.red

            YImage {
                id: id_play_button
                sourceSize: Qt.size(40, 40)
                anchors.centerIn: parent
                imageName: !isPlaying ? "audioplayer/pause" : "audioplayer/play"
            }

            YMouseArea {
                anchors.fill: parent
                anchors.margins: -10
                onClicked: {
                    mediaPlayerManager.onClickedPlay()
                }
            }

            YImage {
                id: id_play_previous_button
                sourceSize: Qt.size(40, 40)
                anchors.right: parent.left
                anchors.rightMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                imageName: "audioplayer/previous54"

                YMouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        console.log("YAudioPlayerLrcContent.qml === id_play_previous_button.onClicked")
                        mediaPlayerManager.onClickedPrev()
                        // 修复：添加 id_play_bar 存在的判断，防止 crash
                        if (typeof id_play_bar !== "undefined") {
                            id_play_bar.updatePlaybackRate()
                            id_play_bar.truncateAudioState = YEnum.TAS_STOP
                        }
                    }
                }
            }

            YImage {
                id: id_play_next_button
                sourceSize: Qt.size(40, 40)
                anchors.left: parent.right
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                imageName: "audioplayer/next54"

                YMouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        console.log("YAudioPlayerLrcContent.qml === id_play_next_button.onClicked")
                        mediaPlayerManager.onClickedNext()
                        // 修复：添加 id_play_bar 存在的判断
                        if (typeof id_play_bar !== "undefined") {
                            id_play_bar.updatePlaybackRate()
                            id_play_bar.truncateAudioState = YEnum.TAS_STOP
                        }
                    }
                }
            }
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            id_player_state_mask_hide.restart()
        }
        else {
            id_player_state_mask_show.restart()
        }
    }
}
