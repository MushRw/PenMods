import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

Item {
    id: id_quick_music_player
    anchors.fill: parent

    signal adjustSettingsRequested()
    signal playerRequested()

    readonly property bool isPlaying: mediaPlayerManager.playState === YEnum.PLAYING
    readonly property string currentTitle: mediaPlayerManager.title || ""
    readonly property var currentSentenceData: id_lrc_view.currentItem ? id_lrc_view.currentItem["lyricData"] : null
    readonly property string currentLyric: !mediaPlayerManager.hasLrc
                                         ? ""
                                         : (currentSentenceData && currentSentenceData.mainLrc
                                            ? currentSentenceData.mainLrc
                                            : (mediaPlayerManager.mainLrc || ""))

    ListView {
        id: id_lrc_view
        width: 1
        height: 1
        visible: true
        opacity: 0
        interactive: false
        currentIndex: mediaPlayerManager.currentSentenceId >= 0 ? mediaPlayerManager.currentSentenceId : 0
        model: mediaPlayerManager
        delegate: Item {
            property var lyricData: model.modelData
        }
    }

    YTextMedium {
        id: id_title
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: id_adjust_button.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 8
        height: 22
        elide: YText.ElideRight
        font.pixelSize: 16
        text: currentTitle
    }

    YIconButton {
        id: id_adjust_button
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 4
        implicitWidth: 30
        implicitHeight: 30
        radius: 8
        mouseAreaMargins: -4
        sourceSize: Qt.size(20, 20)
        imageName: "audioplayer/more_settings"
        onValidClicked: adjustSettingsRequested()
        objectName: "YQuickMusicPlayer.qml_id_adjust_button"
    }

    YText {
        id: id_lyric
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: id_title.bottom
        anchors.topMargin: 1
        height: 38
        color: YColors.grayText
        font.pixelSize: 14
        elide: YText.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
        text: currentLyric.length > 0 ? currentLyric : "暂无歌词"
    }

    YMouseArea {
        id: id_open_player_area
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: id_adjust_button.left
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: id_lyric.bottom
        z: 2
        onClicked: playerRequested()
        objectName: "YQuickMusicPlayer.qml_id_open_player_area"
    }

    Row {
        id: id_control_row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 8

        YIconButton {
            implicitWidth: 34
            implicitHeight: 34
            radius: 10
            mouseAreaMargins: -3
            sourceSize: Qt.size(24, 24)
            imageName: "audioplayer/previous54"
            onValidClicked: mediaPlayerManager.onClickedPrev()
            objectName: "YQuickMusicPlayer.qml_id_previous_button"
        }

        YIconButton {
            implicitWidth: 42
            implicitHeight: 42
            radius: 12
            anchors.verticalCenter: id_control_row.verticalCenter
            mouseAreaMargins: -3
            sourceSize: Qt.size(28, 28)
            imageName: !isPlaying ? "audioplayer/pause" : "audioplayer/play"
            onValidClicked: {
                if (isPlaying) {
                    mediaPlayerManager.onClickedPause()
                } else {
                    mediaPlayerManager.onClickedPlay()
                }
            }
            objectName: "YQuickMusicPlayer.qml_id_play_button"
        }

        YIconButton {
            implicitWidth: 34
            implicitHeight: 34
            radius: 10
            mouseAreaMargins: -3
            sourceSize: Qt.size(24, 24)
            imageName: "audioplayer/next54"
            onValidClicked: mediaPlayerManager.onClickedNext()
            objectName: "YQuickMusicPlayer.qml_id_next_button"
        }

        YIconButton {
            implicitWidth: 34
            implicitHeight: 34
            radius: 10
            mouseAreaMargins: -3
            sourceSize: Qt.size(22, 22)
            imageName: "commons/close"
            onValidClicked: musicPlayer.stop()
            objectName: "YQuickMusicPlayer.qml_id_stop_button"
        }
    }
}
