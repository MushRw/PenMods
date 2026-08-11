import QtQuick 2.12
import "../commons"

YIconLabelButton {
    id: id_audio_play_icon_label_button

    implicitHeight: 24
    leftMargin: 0
    rightMargin: 0
    spacing: 9
    textColor: YColors.grayText
    textFormat: YText.RichText
    sourceSize: Qt.size(24, 24)
    icon: "dict/sound"

    readonly property bool playing: "playing" === id_playing_animation.state

    property int iconChangedAnimationDuration: 300

    property double playId: id_playing_animation.audioPlayId

    function play() {
        id_playing_animation.state = "playing"
        id_playing_animation.running = true
    }

    function stop() {
        id_playing_animation.state = "stop"
        id_playing_animation.running = false
    }

    // 播放单词、句子，句子不需要qsPhonetic及type，对于英文单词qsWord与qsPhonetic相同，type用于区分英音和美音
    // 对于汉字，qsWord是汉字本身，qsPhonetic是汉字的拼音以区分多音字
    function playWord(qsWord, qsLang, qsPhonetic, type) {
        if (typeof qsPhonetic === undefined) {
            qsPhonetic = ""
        }
        if (typeof type === undefined) {
            type = 0
        }
        id_delay_check_end_timer.restart()
        playId = soundCenter.play(qsWord, qsLang, qsPhonetic, type)
    }

    function playAudioFileData(fileData, beginPos, endPos) {
        id_delay_check_end_timer.restart()
        if (typeof fileData == "undefined") {
            playId = soundCenter.playFileData("/tmp/cursound")
        } else if (typeof beginPos == "undefined") {
            playId = soundCenter.playFileData(fileData)
        } else {
            playId = soundCenter.playMusicPiece(fileData, beginPos, endPos)
        }
    }

    SequentialAnimation {
        id: id_playing_animation
        loops: Animation.Infinite
        alwaysRunToEnd: true
        property string state: "stop"
        property double audioPlayId: 0
        PropertyAction {
            target: id_audio_play_icon_label_button
            property: "icon"
            value: "dict/sound-1"
        }
        PauseAnimation { duration: iconChangedAnimationDuration }
        PropertyAction {
            target: id_audio_play_icon_label_button
            property: "icon"
            value: "dict/sound-2"
        }
        PauseAnimation { duration: iconChangedAnimationDuration }
        PropertyAction {
            target: id_audio_play_icon_label_button
            property: "icon"
            value: "dict/sound-3"
        }
        PauseAnimation { duration: iconChangedAnimationDuration }
        onRunningChanged: {
            if (!running && ("stop" === id_playing_animation.state)) {
                id_audio_play_icon_label_button.icon = "dict/sound"
            }
        }
    }

    onValidClicked: {
        if (!playing) {
            play()
        } else if (soundCenter.currentPlayId === playId) {
            qmlGlobal.stopAllAnimationMusic()
        }
    }

    YTimer {
        id: id_delay_check_end_timer
        interval: 600
        objectName: "YAudioPlayButton.qml_id_delay_check_end_timer"
    }

    Connections {
        target: soundCenter
        ignoreUnknownSignals: true
        enabled: id_audio_play_icon_label_button.visible
        onEnd: {
            if (id_audio_play_icon_label_button.playing
                    && !id_delay_check_end_timer.running
                    && (seq == playId)) {
                stop()
            }
        }
        onSoundSuspend: {
            if (id_audio_play_icon_label_button.playing
                    && !id_delay_check_end_timer.running
                    && (seq == playId)) {
                stop()
            }
        }
    }
}

