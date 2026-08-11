import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../animations"

YSettingAboutClickableItem {
    id: id_youdao_audio_page_column_view_item

    property bool isDownloadManagerView: false

    valueRightMargin: (isDownloadManagerView && !editing) ?  10 : (10 + 24 + 8)
    readonly property int downloadState: model.modelData.downloadState
    readonly property int progress: model.modelData.progress
    readonly property bool isPlaying: (YEnum.PLAYING === mediaPlayerManager.playState)
                                      && (mediaManager.playingMediaId === model.modelData.id)

    iconComponent.visible: false

    titleColor: isPlaying ? YColors.red : YColors.white

    YYoudaoAudioPageColumnViewItemStatus {
        visible: !isPlaying && !editing
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        downloadState: id_youdao_audio_page_column_view_item.downloadState
        progress: id_youdao_audio_page_column_view_item.progress
        isAuthorized: columnManager.currentOpenColumnIsAuthorized
        mediaId: model.modelData.id
    }

    YYoudaoAudioPageColumnViewItemAnimation {
        visible: isPlaying
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        running: isPlaying && iconLoaded
    }

    YImage {
        visible: isDownloadManagerView && editing
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        sourceSize: Qt.size(24, 24)
        imageName: "audioplayer/delete_indicator"
    }

    titlePixelSize: 16
    valuePixelSize: 14
}
