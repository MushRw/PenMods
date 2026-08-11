import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YBackground {
    id: id_drawer_layer
    anchors.fill: parent
    visible: false

    function playAudio(columnId, mediaId) {
        qmlGlobal.audioPlayingColomnId = columnId
        mediaManager.clickMedia(mediaId)
        qmlGlobal.showAudioPlayer();
        if (YEnum.PLAYING !== mediaPlayerManager.playState) {
            mediaPlayerManager.onClickedPlay()
        }
    }

    function updateModel() {
        let list = mediaManager.getScanningSearchResults()
        console.log("YMyProductionPageFilterDrawerLayer.qml===count ", list.length)
        id_list_container_repeater.model = list
    }

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }

    YIconButton {
        id: id_close_button
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        color: YColors.grayNormal
        mouseAreaMargins: -10
        imageName: "commons/close"
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 8
        sourceSize: Qt.size(24, 24)
        onClicked: {
            hide()
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.topMargin: 16
        anchors.rightMargin: 10

        contentHeight: id_title.height
                       + id_list_container.height + 30


        YTextBase {
            id: id_title
            anchors.top: parent.top
            height: 42
            width: parent.width
            color: YColors.grayText
            font.pixelSize: 16
            wrapMode: Text.WrapAnywhere
            text: YTranslateText.myProductionAudiosContent
        }

        Column {
            id: id_list_container
            anchors.top: id_title.bottom
            anchors.topMargin: 4
            width: parent.width
            spacing: 8

            Repeater {
                id: id_list_container_repeater

                YButton {
                    implicitWidth: parent.width
                    readonly property bool isPlaying: (YEnum.PLAYING === mediaPlayerManager.playState)
                                                      && (mediaManager.playingMediaId === model.modelData.id)
                    color: isPlaying ? YColors.red : "#2D2E33"
                    mouseAreaMargins: -4
                    textItem.width: parent.width - 20

                    TextMetrics {
                        id: textMetrics
                        font.family: qmlGlobal.fontFamily
                        font.pixelSize: 18
                        elide: Text.ElideRight
                        elideWidth: parent.width - 20
                    }
                    textItem.text:
                    {
                        textMetrics.text = model.modelData.title
                        return textMetrics.elidedText
                    }
                    onClicked: {
                        playAudio(model.modelData.columnId, model.modelData.id)
                    }
                }
            }
        }

    }
}
