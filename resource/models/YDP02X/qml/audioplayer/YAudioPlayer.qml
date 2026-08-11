import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"
import "../textbook"

Item {
    id: id_audio_player
    anchors.fill: parent
    state: "close"

    // --- Properties ---

    readonly property bool isShowing: state === "show" || id_audio_player_indicator.isShowing
    readonly property int playerMode: mediaPlayerManager.playerMode
    readonly property bool isHidden: isShowing && !visible

    // 优化：移除属性绑定中的副作用（上报埋点），改为纯数据返回
    readonly property var lrcStateList: {
        switch (mediaPlayerManager.lrcState) {
            case YEnum.LS_BILINGUAL:
                return [YEnum.LS_BILINGUAL, YEnum.LS_ORIGINAL, YEnum.LS_TRANS, YEnum.LS_HIDE]
            case YEnum.LS_ORIGINAL:
                return [YEnum.LS_ORIGINAL, YEnum.LS_HIDE]
            case YEnum.LS_TRANS:
                return [YEnum.LS_TRANS, YEnum.LS_HIDE]
            case YEnum.LS_HIDE:
            default:
                return [YEnum.LS_HIDE]
        }
    }

    property int lrcStateIndex: 0

    // --- Signal Handlers & Logic ---

    // 优化：将副作用逻辑（埋点）移至 Connections
    Connections {
        target: mediaPlayerManager
        function onLrcStateChanged() {
            if (!id_audio_player.visible) return;
            switch (mediaPlayerManager.lrcState) {
                case YEnum.LS_BILINGUAL:
                case YEnum.LS_ORIGINAL:
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

    onStateChanged: {
        qmlGlobal.isInPlayerCenterPage = ("show" === state)
    }

    // --- Public Functions ---

    function show() {
        if (state === "show") return
            state = "show"
            if (id_audio_player_indicator.isShowing) {
                id_audio_player_indicator.hide()
            }
            id_ver_play_bar.setFollowEnabledState(true)
            id_play_bar.updatePlaybackRate()

            // 确保对象存在再调用
            if (id_content_container) {
                id_content_container.show()
            }
    }

    function close() {
        console.warn("YAudioPlayer.qml===close()")
        cleanupInternal()

        state = "close"
        if (YEnum.PM_AudioPlayer === playerMode && YEnum.STOPPED !== mediaPlayerManager.playState) {
            // 音乐模式且仍在播放 → 缩小到悬浮球，保留音频引用
            id_audio_player_indicator.show()
            id_audio_player_indicator.closeExtendState()
        } else if (YEnum.STOPPED === mediaPlayerManager.playState) {
            // 播放已停止 → 释放音频引用
            musicPlayer.releaseAudio()
        } else {
            // 其他模式暂停 → 释放音频引用
            mediaPlayerManager.onClickedPause()
            musicPlayer.releaseAudio()
        }
        id_ver_play_bar.setFollowEnabledState(false)
        raise()
    }

    function hidden() {
        console.warn("YAudioPlayer.qml===hidden()")
        cleanupInternal()
        visible = false
        playStatePauseConfirm()
        // 隐藏时释放音频引用（完全退出播放界面）
        musicPlayer.releaseAudio()
    }

    function raise() {
        visible = true
    }

    function playStatePauseConfirm() {
        if (id_content_container) {
            id_content_container.playStatePauseConfirm()
        }
    }

    // 优化：高效的字符串格式化，避免频繁对象创建
    function mmssString(ms) {
        if (ms < 0) ms = 0;
        var totalSeconds = Math.floor(ms / 1000);
        var minutes = Math.floor(totalSeconds / 60);
        var seconds = totalSeconds % 60;

        var mStr = minutes > 9 ? minutes : "0" + minutes;
        var sStr = seconds > 9 ? seconds : "0" + seconds;
        return mStr + ":" + sStr;
    }

    function enterAudioPlayerFollow() {
        console.warn("YAudioPlayer.qml===enterAudioPlayerFollow()")
        mediaPlayerManager.onClickedPause();
        mediaPlayerManager.onResetPlayer();

        resetFollowLogic()

        id_audioplayer_followpage_loader.active = true
    }

    function closeAudioPlayerFollow() {
        console.warn("YAudioPlayer.qml===closeAudioPlayerFollow()")
        id_audioplayer_followpage_loader.active = false
    }

    function submitHomework() {
        console.warn("YAudioPlayer.qml===submitHomework()")
        id_audioplayer_submithomework_dialog_loader.active = true
    }

    // --- Private Helper Functions ---

    function cleanupInternal() {
        closeAudioPlayerFollow()
        id_audioplayer_submithomework_dialog_loader.active = false
    }

    function resetFollowLogic() {
        followManager.ukPhonetic = "";
        followManager.usPhonetic = "";
        followManager.content = mediaPlayerManager.mainLrc

        var scanningColumn = columnManager.columnIsScanning(mediaPlayerManager.ownerId());
        if (scanningColumn && scanningColumn.length > 0) {
            logManager.sendHttpLog("action=listening_make_broadcasting_readfollow_click")
            followManager.classLog = "&resource_bookname=" + scanningColumn
            + "&resource_Lischaptername=" + mediaPlayerManager.title
        } else {
            followManager.classLog = ""
        }
        logManager.sendHttpLog("action=listening_broadcasting_readfollow_click")
        followManager.clearResult()
    }

    // --- UI Components ---

    YBackgroundIgnoreMouseEvent {
        anchors.fill: parent
        // 优化：当不显示时完全透明，但保持 visible 为 true 以防破坏布局计算
        opacity: id_audio_player_indicator.isShowingAndExtendState ? 0.6 : 0
        visible: opacity > 0.01
        onClicked: {
            id_audio_player_indicator.closeExtendState()
        }
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    YBackgroundIgnoreMouseEvent {
        id: id_audio_player_container
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        // 优化：当缩放极小时禁用交互，但不要设为 visible=false，
        // 否则子项的 anchors (如 YAudioPlayerLrcContent) 可能会因找不到父项边界而报错
        enabled: scale > 0.9

        YVerticalTitleBar {
            onCallBack: {
                close()
            }

            YAudioPlayerPlayBarVertical {
                id: id_ver_play_bar
            }
        }

        // 错误日志指出 YAudioPlayerLrcContent.qml:94 有错。
        // 此处确保 content_container 始终有有效的 parent 和 geometry。
        YAudioPlayerLrcContent {
            id: id_content_container
            anchors.fill: parent
        }

        YAudioPlayerPlayBar {
            id: id_play_bar
        }

        YProgressBar {
            id: id_main_progress_bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: YColors.black
            progressColor: YColors.blueText
            progressGradient: Gradient {
                GradientStop { position: 0.0; color: YColors.blueText }
                GradientStop { position: 1.0; color: YColors.blueText }
            }
            progress: mediaPlayerManager.progress

            Rectangle {
                id: id_repeat_progress
                // 优化：逻辑提取，更清晰
                visible: {
                    var s = id_play_bar.truncateAudioState
                    return s === YEnum.TAS_ING || s === YEnum.TAS_PLAYING || s === YEnum.TAS_Sentence
                }

                // 优化：避免在不可见时进行复杂的 margin 计算
                anchors.left: parent.left
                anchors.leftMargin: {
                    if (!visible || !id_play_bar) return 0
                        return id_main_progress_bar.width * (mediaPlayerManager.progress / 100.0)
                }

                anchors.right: parent.right
                anchors.rightMargin: {
                    if (!visible || !id_play_bar) return 0
                        var fullWidth = id_main_progress_bar.width
                        var state = id_play_bar.truncateAudioState

                        if (state === YEnum.TAS_ING) {
                            return fullWidth * ((100 - mediaPlayerManager.progress) / 100.0)
                        } else if (state === YEnum.TAS_PLAYING || state === YEnum.TAS_Sentence) {
                            return fullWidth * ((100 - mediaPlayerManager.progressRepeatB) / 100.0) - 8
                        }
                        return 0
                }
                implicitHeight: 2
                color: "black"
                Rectangle {
                    anchors.fill: parent
                    color: YColors.red
                }
            }
        }
    }

    Item {
        id: id_player_progress_timeinfo_item
        implicitWidth: 200
        implicitHeight: 54
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        // 优化：边界限制计算
        anchors.horizontalCenterOffset: {
            if (!visible) return 0
                var offset = (mediaPlayerManager.progress - 50) * 0.01 * parent.width
                return offset < -284 ? -284 : (offset > 284 ? 284 : offset)
        }
        visible: false

        YBlurMaskRectangle {
            id: id_blur_mask_rectangle
            anchors.fill: parent
            sourceItem: id_audio_player_container
            sourceRect: Qt.rect(parent.x, parent.y, width, height)
            blurRadius: 48
            // 性能优化：父级隐藏时禁用模糊
            visible: parent.visible

            Rectangle {
                anchors.fill: parent
                color: YColors.white
                opacity: 0.14
                radius: height/2
            }
        }

        YTextMedium {
            anchors.centerIn: parent
            font.pixelSize: 16
            textFormat: Text.RichText
            text: ('<span style="font-family: %1; color:%2">%3</span> / %4')
            .arg(qmlGlobal.fontFamilyEnUs).arg(YColors.blueText)
            .arg(mmssString(mediaPlayerManager.currentPos))
            .arg(mmssString(mediaPlayerManager.duration))
        }
    }

    YAudioPlayerIndicator {
        id: id_audio_player_indicator
        onClicked: {
            id_audio_player.show()
        }
        onStopAudio: {
            mediaPlayerManager.onClickedPause()
            musicPlayer.releaseAudio()
        }
    }

    YLoader {
        id: id_audioplayer_followpage_loader
        anchors.fill: parent
        sourceComponent: id_audioplayer_follow_page_component
        active: false
    }

    YLoader {
        id: id_audioplayer_submithomework_dialog_loader
        anchors.fill: parent
        sourceComponent: id_audioplayer_submithomework_dialog_component
        active: false
        onLoaded: {
            if (item) item.show()
        }
    }

    Component {
        id: id_audioplayer_follow_page_component
        YAudioPlayerFollowPage {
            onBackButtonClicked: {
                closeAudioPlayerFollow()
                if (id_audio_player.playerMode === YEnum.PM_Homework_Follow) {
                    close()
                } else {
                    if (typeof currentLrcEntityIndex !== "undefined") {
                        mediaPlayerManager.onFastGotoSentence(currentLrcEntityIndex)
                    }
                    mediaPlayerManager.onClickedPlay()
                }
            }
        }
    }

    Component {
        id: id_audioplayer_submithomework_dialog_component
        YTextbookSubmitHomeworkDialog {
            id: id_audioplayer_submithomework_dialog
            anchors.fill: parent
            submitTipString: {
                switch (id_audio_player.playerMode) {
                    case YEnum.PM_Homework_Follow:
                        return (YTranslateText.textbookFollowSubmitTip).arg(YColors.red).arg(mediaPlayerManager.getFollowResultAverageScore())
                    case YEnum.PM_Homework_Listen:
                        return (YTranslateText.textbookListenSubmitTip).arg((textBookTaskManager.learningDuarition / 60).toFixed(2))
                    default:
                        return ""
                }
            }
            onSubmitHomework: {
                mediaPlayerManager.commitFollowResult()
            }
            onRedoHomework: {
                textBookTaskManager.retryLearning()
                id_audioplayer_submithomework_dialog.close()
                id_audioplayer_submithomework_dialog_loader.active = false
                id_audioplayer_followpage_loader.active = false
            }
            onSubmitFinished: {
                id_audioplayer_submithomework_dialog.close()
                id_audioplayer_submithomework_dialog_loader.active = false
                id_audio_player.close()
            }
            onClosed: {
                id_audioplayer_submithomework_dialog.close()
                id_audioplayer_submithomework_dialog_loader.active = false
                if (id_audio_player.playerMode === YEnum.PM_Homework_Listen) {
                    id_audio_player.close()
                }
            }
        }
    }

    states: [
        State {
            name: "close"
            PropertyChanges { target: id_audio_player_container; scale: 0 }
        },
        State {
            name: "show"
            PropertyChanges { target: id_audio_player_container; scale: 1 }
        }
    ]

    transitions: Transition {
        NumberAnimation { properties: "scale"; duration: 200; easing.type: Easing.InOutQuad }
    }

    // --- Connections ---

    Connections {
        target: textBookTaskManager
        ignoreUnknownSignals: true
        function onLearningDuaritionChanged() {
            id_audio_player.submitHomework()
        }
        function onUploadLearningDataFinished(taskId, success, errCode, errMsg) {
            if (id_audioplayer_submithomework_dialog_loader.status === Loader.Ready && id_audioplayer_submithomework_dialog_loader.item) {
                var item = id_audioplayer_submithomework_dialog_loader.item
                item.submitDoing = false
                if (success) {
                    item.submitDone = true
                } else {
                    qmlGlobal.showToast(errMsg, YColors.grayNormal)
                }
            }
        }
        function onUploadOralAudioFinished(taskId, success, errCode, errMsg) {
            if (id_audioplayer_submithomework_dialog_loader.status === Loader.Ready) {
                if (!success) {
                    qmlGlobal.showToast(errMsg.length > 0 ? errMsg: YTranslateText.textbookHomeworkOralUploadFailed, YColors.grayNormal)
                }
            }
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        function onAudioPlayingColomnIdChanged() {
            var colId = qmlGlobal.audioPlayingColomnId;
            if (colId && colId.length > 0) {
                const qrcColumnId = "qrc:/images/audioplayer/indicator/%1.png".arg(colId)
                if (qmlGlobal.fileExists(qrcColumnId)) {
                    id_audio_player_indicator.indicatorSource = qrcColumnId
                } else {
                    if (qmlGlobal.fileExists(colId)) {
                        id_audio_player_indicator.indicatorSource = colId
                    } else {
                        id_audio_player_indicator.indicatorSource = ""
                    }
                }
            } else {
                id_audio_player_indicator.indicatorSource = ""
            }
        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        enabled: id_audio_player.state === "show"
        function onHomeKeyLongPress() {
            id_audio_player.close()
        }
    }
}
