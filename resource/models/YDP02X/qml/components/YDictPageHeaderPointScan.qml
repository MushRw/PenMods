import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    id: id_header_item
    width: id_animated_sprite_container.width + id_header_content.width + 12
    implicitHeight: 44
    objectName: "YDictPageHeaderNormal.qml"

    Item {
        id: id_animated_sprite_container
        implicitWidth: 20
        implicitHeight: 20
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        YAnimatedImagesView {
            id: id_animated_sprite
            objectName: "YDictPageHeaderPointScan.qml"
            anchors.centerIn: parent
            scale: 0.5
            frameSize: Qt.size(64, 64)
            frameCount: 22
            frameDuration: 40
            imageName: "point_scan"
            onCurrentFrameChanged: {
                if (currentFrame >= 21) {
                    stopPlay()
                }
            }
        }
    }

    YTextMedium {
        id: id_header_content
        anchors.left: id_animated_sprite_container.right
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 16
        verticalAlignment: YTextMedium.AlignBottom
        color: YColors.grayText
        text: {
            if (YEnum.ZH_CN === qmlGlobal.language) {
                efficiencyReport.addClock("point_scan_show")
                return YTranslateText.pointScan
            } else
                return ""
        }
        width: paintedWidth
        height: id_animated_sprite_container.height      
    }

    Connections {
        target: resultManager
        ignoreUnknownSignals: true
        onCurrentQueryChanged: {
            if (0 === qmlGlobal.scanType) {
                id_animated_sprite.play()
            }
        }
    }
}

