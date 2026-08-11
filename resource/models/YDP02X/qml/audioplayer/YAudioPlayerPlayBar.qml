import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    id: id_player_bar_item
    anchors.fill: parent
//    visible: opacity > 0
    state: "close"

    readonly property bool isPlaying: YEnum.PLAYING === mediaPlayerManager.playState
    readonly property int audioSequence: settingManager.audioSequence
    property int truncateAudioState: YEnum.TAS_STOP

    // 倍速设置
    property var rateSettingIndex: 0
    property var rateSettings: [
        {rate: 1.0, title: YTranslateText.prNormal},
        {rate: 0.8, title: YTranslateText.prSlow},
        {rate: 1.2, title: YTranslateText.prHigh},
        {rate: 1.5, title: YTranslateText.prFast}
    ]

    function updatePlaybackRate() {
        rateSettingIndex = getRateSettingIndex(mediaPlayerManager.playbackRate)
    }

    function getRateSettingIndex(rate) {
        for (let i = 0; i < rateSettings.length; ++i) {
            if (Math.abs(rateSettings[i].rate - mediaPlayerManager.playbackRate) < 1e-2) {
                return i
            }
        }
        return 0
    }

    function show() {
        state = "show"
    }

    function close() {
        state = "close"
    }

    function callStopRepeat() {
        if (YEnum.TAS_STOP !== truncateAudioState) {
            mediaPlayerManager.closeRepeat()
            truncateAudioState = YEnum.TAS_STOP
        }
    }

    YBackground {
        id: id_back_mask
        anchors.fill: parent
    }

    YMouseArea {
        id: id_close_mousearea
        objectName: "YAudioPlayerPlayBar.qml_id_close_mousearea"
        anchors.fill: parent

        onClicked: {
            close()
        }
    }

    YBackground {
        id: id_play_bar
        width: 170
        color: YColors.grayButton
        anchors.right: parent.right
        implicitHeight: parent.height
        radius: 14

        Column {
            id: id_play_bar_column
            width: parent.width - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 13

            YAudioPlayerPlayBarSettingItem {
                id: id_lrc_state_button
                mouseAreaMargins: -8

                imageName: {
                    switch (lrcStateList[lrcStateIndex]) {
                    case YEnum.LS_ORIGINAL:
                        return "audioplayer/original26"
                    case YEnum.LS_TRANS:
                        return "audioplayer/trans26"
                    case YEnum.LS_HIDE:
                        return "audioplayer/hide_lrc26"
                    case YEnum.LS_BILINGUAL:
                    default:
                        return "audioplayer/bilingual26"
                    }
                }
                text: {
                    switch (lrcStateList[lrcStateIndex]) {
                    case YEnum.LS_ORIGINAL:
                        return YTranslateText.lsOriginal
                    case YEnum.LS_TRANS:
                        return YTranslateText.lsTrans
                    case YEnum.LS_HIDE:
                        return YTranslateText.lsHide
                    case YEnum.LS_BILINGUAL:
                    default:
                        return YTranslateText.lsBilingual
                    }
                }

                onClicked: {
                    lrcStateIndex = (lrcStateIndex + 1) % lrcStateList.length
                    // TODO first time toast
                    switch (lrcStateList[lrcStateIndex]) {
                    case YEnum.LS_BILINGUAL:
                        screenManager.reportAction('musicplayer_lrc_show')
                        break
                    case YEnum.LS_ORIGINAL:
                        screenManager.reportAction('musicplayer_lrc_show')
                        break
                    case YEnum.LS_TRANS:
                        screenManager.reportAction('musicplayer_lrc_show')
                        break
                    case YEnum.LS_HIDE:
                    default:
                        screenManager.reportAction('musicplayer_lrc_hide')
                        break
                    }
                }
            }

            YAudioPlayerPlayBarSettingItem {
                id: id_repeat_button
                //visible: playerMode === YEnum.PM_AudioPlayer
                imageName: "audioplayer/repeating26"
                textItem.textFormat: YText.RichText
                text: {
                    switch (truncateAudioState) {
                    case YEnum.TAS_ING:
                        return ("<font color=\"%1\">A</font> - B").arg(YColors.red)
                    case YEnum.TAS_PLAYING:
                        return YTranslateText.tasStop
                    case YEnum.TAS_Sentence:
                        return YTranslateText.tasSentence
                    case YEnum.TAS_STOP:
                    default:
                        return YTranslateText.tasPausing
                    }
                }

                onClicked: {
                    truncateAudioState = (truncateAudioState + 1) % YEnum.TAS_COUNT
                    switch (truncateAudioState) {
                    case YEnum.TAS_ING:
                        mediaPlayerManager.startRepeat()
                        break
                    case YEnum.TAS_PLAYING:
                        mediaPlayerManager.endRepeat()
                        break
                    case YEnum.TAS_Sentence:
                        mediaPlayerManager.repeatSentence()
                        break
                    case YEnum.TAS_STOP:
                    default:
                        mediaPlayerManager.closeRepeat()
                        break
                    }
                }
            }
            YAudioPlayerPlayBarSettingItem {
                id: id_playback_rate_setting
                //visible: playerMode !== YEnum.PM_AudioPlayer
                imageName: "audioplayer/rate%1".arg(rateSettings[rateSettingIndex].rate.toFixed(1))
                text: rateSettings[rateSettingIndex].title

                onClicked: {
                    rateSettingIndex = ((rateSettingIndex + 1) % rateSettings.length)
                    let tmpIsPlaying = isPlaying
                    mediaPlayerManager.playbackRate = rateSettings[rateSettingIndex].rate
                    if (tmpIsPlaying) {
                        mediaPlayerManager.onClickedPlay()
                    }
                }
            }
            YAudioPlayerPlayBarSettingItem {
                id: id_audio_sequence
                imageName: {
                    switch (audioSequence) {
                    case YEnum.AS_RANDOM:
                        return "audioplayer/s_random26"
                    case YEnum.AS_SINGLE:
                        return "audioplayer/s_cycle"
                    case YEnum.AS_ORDER:
                        return "audioplayer/sequence26"
                    case YEnum.AS_SINGLE_SHOT:
                    default:
                        return "audioplayer/s_stop_single"
                    }
                }

                text: {
                    switch (audioSequence) {
                    case YEnum.AS_ORDER:
                        return YTranslateText.asOrder
                    case YEnum.AS_RANDOM:
                        return YTranslateText.asRandom
                    case YEnum.AS_SINGLE:
                        return YTranslateText.asSingle
                    case YEnum.AS_SINGLE_SHOT:
                    default:
                        return YTranslateText.asSingleShot
                    }
                }

                onClicked: {
                    settingManager.audioSequence = ((audioSequence + 1) % YEnum.AS_COUNT)
                }
            }
        }

    }


    states: [
        State {
            name: "close"
            PropertyChanges { target: id_play_bar; anchors.rightMargin: -176 }
            PropertyChanges { target: id_close_mousearea; enabled: false }
            PropertyChanges { target: id_back_mask; opacity: 0 }
        },
        State {
            name: "show"
            PropertyChanges { target: id_play_bar; anchors.rightMargin: -16}
            PropertyChanges { target: id_close_mousearea; enabled: true }
            PropertyChanges { target: id_back_mask; opacity: 0.8 }
        }
    ]

    transitions: [
        Transition {
            to: "show"
            NumberAnimation { target: id_back_mask;  properties: "opacity"}
            NumberAnimation { target: id_play_bar; properties: "anchors.rightMargin" }
        },
        Transition {
            to: "close"
            NumberAnimation { target: id_play_bar; properties: "anchors.rightMargin" }
            NumberAnimation { target: id_back_mask;  properties: "opacity"}
        }
    ]

    Connections {
        target: mediaPlayerManager
        ignoreUnknownSignals: true
        enabled: id_play_bar.visible
        function onPlayStateChanged() {
            console.log("YAudioPlayerPlayBar.qml===onPlayStateChanged===",
                        mediaPlayerManager.playState)
            if (YEnum.STOPPED === mediaPlayerManager.playState) {
                truncateAudioState = YEnum.TAS_STOP
            }
        }
    }

    Component.onCompleted: {
        updatePlaybackRate()
    }

    objectName: "YAudioPlayerPlayBar.qml"
}
