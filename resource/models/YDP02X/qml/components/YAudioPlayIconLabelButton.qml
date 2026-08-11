import QtQuick 2.12
import "../commons"

YIconLabelButton {
    id: id_audio_play_icon_label_button

    implicitHeight: 50
    leftMargin: 24
    rightMargin: 24
    spacing: 12
    textColor: YColors.grayText
    textFormat: YText.RichText
    sourceSize: Qt.size(24, 24)
    icon: "dict/sound"

    readonly property alias playing: id_playing_animation.running

    property int iconChangedAnimationDuration: 300

    function play() {
        id_playing_animation.audioPlayId = 0
        id_playing_animation.state = "playing"
        id_playing_animation.running = true
    }

    function stop() {
        id_playing_animation.audioPlayId = 0
        id_playing_animation.state = "stop"
        id_playing_animation.running = false
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
        if (playing) {
            stop()
            soundCenter.stop()
        } else {
            play()
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        //enabled: id_audio_play_icon_label_button.visible
        onAudioPlayIdChanged: {
            if (id_audio_play_icon_label_button.playing) {
                id_playing_animation.audioPlayId = qmlGlobal.audioPlayId
            }
        }
    }

    Connections {
        target: soundCenter
        ignoreUnknownSignals: true
        //enabled: id_audio_play_icon_label_button.visible
        onEnd: {
            if ((id_audio_play_icon_label_button.playing)
                    && (seq == id_playing_animation.audioPlayId)) {
                stop()
            }
        }
    }
}
