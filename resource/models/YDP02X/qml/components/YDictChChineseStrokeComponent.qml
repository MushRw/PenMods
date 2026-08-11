import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    id: id_dict_chinese_stroke_page
    objectName: "YPage===YDictChChineseStrokePage.qml"
    anchors.left: parent.left
    anchors.right: parent.right
    height:/* isImagesExit ?*/ Math.max(id_strokes_animation_background.height, id_stroke_info_column.height)
//                         : id_stroke_radical_structure_text.height

    property string chCharacter: resultManager.currentQuery
    property bool isImagesExit: false

    YImage {
        id: id_strokes_animation_background
        width: 88
        height: 88
        anchors.verticalCenter: parent.verticalCenter
        imageName: isImagesExit ? "dict/chstroke_grid" : "dict/ch_grid"
        sourceSize: Qt.size(parent.width, parent.height)
        //visible: isImagesExit

        YText {
            anchors.centerIn: parent
            visible: !isImagesExit
            text: chCharacter
            font.pixelSize: 55
        }

//        YImage {
//            id: chinesGridBackGround
//            anchors.centerIn: parent
//            imageName: "dict/ch_grid"
//            sourceSize: Qt.size(86, 86)
//            visible: !isImagesExit
//        }

        YStrokesOrderView {
            id: id_strokes_animation
            objectName: "YStrokesOrderView.qml"
            frameSize: Qt.size(parent.width, parent.height)
            frameCount: 0
            frameDuration: 260
            visible: isImagesExit
            z: id_strokes_animation_background.z + 1
        }

        YIconButton {
            id: id_portrait_icon_bg
            implicitWidth: 20
            implicitHeight: 20
            radius: height/2
            mouseAreaMargins: -10
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "transparent"
            icon: "dict/play"
            iconSourceSize: Qt.size(20, 20)
            visible: !id_strokes_animation.playing && isImagesExit

            onClicked: {
                if (isImagesExit) {
                    id_strokes_animation.play()
                }
            }
        }
    }

    Column {
        id: id_stroke_info_column
        anchors.left: id_strokes_animation_background.right
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        //visible: isImagesExit
        spacing: 8

        Row {
            height: id_strokecount_text.height
            visible: id_dict_page.strokeCount > 0
            YText {
                width: paintedWidth
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.grayText
                text: YTranslateText.stroke + ":"
            }

            Item {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
            }

            YText {
                id: id_strokecount_text
                width: 76
                height: paintedHeight
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.white
                wrapMode: YText.Wrap
                text: id_dict_page.strokeCount
            }
        }
        Row {
            height: id_structure_text.height
            visible: id_dict_page.structure !== ""
            YText {
                width: paintedWidth
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.grayText
                text: YTranslateText.structure + ":"
            }

            Item {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
            }

            YText {
                id: id_structure_text
                width: 76
                height: paintedHeight
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.white
                wrapMode: YText.Wrap
                text: id_dict_page.structure
            }
        }
        Row {
            height: id_radical_text.height
            visible: id_dict_page.radical !== ""
            YText {
                width: paintedWidth
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.grayText
                text: YTranslateText.radical + ":"
            }

            Item {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
            }

            YText {
                id: id_radical_text
                width: 76
                height: paintedHeight
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
                font.bold: true
                font.family: "Noto Sans SC"
                color: YColors.white
                wrapMode: YText.Wrap
                text: id_dict_page.radical
            }
        }
    }

//    YText {
//        id: id_stroke_radical_structure_text
//        width: parent.width
//        textFormat: Text.RichText
//        font.family: qmlGlobal.fontFamilyZhCn
//        wrapMode: Text.Wrap
//        visible: !isImagesExit
//        text: {
//            let qsRst = ""
//            if (id_dict_page.strokeCount > 0) {
//                qsRst += ('<span style="color:%1">%2:&nbsp;</span>%3').arg(YColors.grayText).arg(YTranslateText.stroke).arg(id_dict_page.strokeCount)
//            }
//            if (id_dict_page.structure.length > 0) {
//                if (qsRst.length > 0) qsRst += '<span>&nbsp;&nbsp;</span>'
//                qsRst += ('<span style="color:%1">%2:&nbsp;</span>%3').arg(YColors.grayText).arg(YTranslateText.structure).arg(id_dict_page.structure)
//            }
//            if (id_dict_page.radical.length > 0) {
//                if (qsRst.length > 0) qsRst += '<span>&nbsp;&nbsp;</span>'
//                qsRst += ('<span style="color:%1">%2:&nbsp;</span>%3').arg(YColors.grayText).arg(YTranslateText.radical).arg(id_dict_page.radical)
//            }
//            return qsRst
//        }
//    }

    Connections {
        target: strokeManager
        ignoreUnknownSignals: true
        function onImageListChanged() {
            if (strokeManager.imageList.length > 0) {
                id_strokes_animation.frameCount = strokeManager.imageList.length
                id_strokes_animation.imageNameList = strokeManager.imageList
                isImagesExit = true
                id_strokes_animation.play()
            }
        }
    }
}
