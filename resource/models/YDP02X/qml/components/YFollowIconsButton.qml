import QtQuick 2.12
import "../commons"
import "../animations"
YIconButton {
    id: id_follow_icons_button

    implicitWidth: 44
    implicitHeight: 44
    sourceSize: Qt.size(28, 28)
    icon: playing ? "" : "follow/play1"
    readonly property alias playing: id_playing_animation.running

    property int iconChangedAnimationDuration: 300

    function play() {
        id_playing_animation.state = "playing"
        id_playing_animation.play()
        id_playing_animation.visible = true
    }

    function stop() {
        id_playing_animation.state = "stop"
        id_playing_animation.stopPlay()
        id_playing_animation.visible = false
    }

    YAudioPlayerIndicatorAnimation {
        id: id_playing_animation
        frameSize: Qt.size(28, 28)
        anchors.centerIn: parent
    }
}
