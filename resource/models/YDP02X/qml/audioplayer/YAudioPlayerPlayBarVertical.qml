import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    anchors.fill: parent
    anchors.topMargin: 54 - 10
    anchors.leftMargin: 10

    function setFollowEnabledState(enabledState) {
        id_mic_button.visible = false
        if (enabledState) {
            id_follow_button_delay_enabled_timer.restart()
        }
    }

    YTimer {
        id: id_follow_button_delay_enabled_timer
        interval: 720
        onTriggered: {
            id_mic_button.visible = Qt.binding(function(){
                return (mediaPlayerManager.mainLrc.length > 0)
                        && (YEnum.EN_US === qmlTranslator.guessTextLang(mediaPlayerManager.mainLrc))
            })
        }
        objectName: "YAudioPlayerPlayBarVertical.qml_id_follow_button_delay_enabled_timer"
    }

    Column {
        id: id_col
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 8

        YIconButton {
            id: id_mic_button
            implicitWidth: 30
            implicitHeight: 30
            radius: 6
            sourceSize: Qt.size(20, 20)
            imageName: "audioplayer/mic"
            mouseAreaMargins: -4
            visible: false
            onValidClicked: {
                enterAudioPlayerFollow()
            }
        }

        YIconButton {
            id: id_repeat_sentence_button
            implicitWidth: 30
            implicitHeight: 30
            radius: 6
            visible: playerMode !== YEnum.PM_Homework_Follow
            sourceSize: Qt.size(20, 20)
            imageName: mediaPlayerManager.repeatEndPos > 0 ? "audioplayer/cancel_sentence" : "audioplayer/repeating_sentence"
            mouseAreaMargins: -4
            onValidClicked: {
                if (mediaPlayerManager.repeatEndPos > 0){
                    qmlGlobal.showToast(YTranslateText.textbookStopRepeatPlaySentence, YColors.grayButton)
                    id_play_bar.truncateAudioState = YEnum.TAS_STOP
                    mediaPlayerManager.closeRepeat()
                } else {
                    qmlGlobal.showToast(YTranslateText.textbookStartRepeatPlaySentence, YColors.grayButton)
                    id_play_bar.truncateAudioState = YEnum.TAS_Sentence
                    mediaPlayerManager.repeatSentence()
                }
            }
        }

        YIconButton {
            implicitWidth: 30
            implicitHeight: 30
            radius: 6
            mouseAreaMargins: -4
            iconSourceSize: Qt.size(20, 20)
            imageName: "audioplayer/more_settings"

            onValidClicked: {
                id_play_bar.show()
            }
        }

    }
}

