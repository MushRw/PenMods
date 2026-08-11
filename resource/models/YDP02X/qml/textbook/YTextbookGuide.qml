import QtQuick 2.12
import QtGraphicalEffects 1.0
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

Item {
    id: id_textbook_guide_item
    objectName: "YTextBookGuide.qml"
    anchors.fill: parent

    YVerticalTitleBar {
        onCallBack: {
            id_textbook_page.subPageCallBack()
        }
    }

    YMouseArea {
        id: id_select_textbook_mousearea
        anchors.left: parent.left
        anchors.leftMargin: 54
        anchors.top: parent.top
        anchors.topMargin: 24
        width: 110
        height: 110

        YImage {
            id: id_select_textbook_image
            anchors.fill: parent
            imageName: ("textbook/guide-%1").arg(imageIndex)
            property int imageIndex: 1
            YTimer {
                id: id_select_textbook_image_timer
                repeat: true
                interval: 5000
                onTriggered: {
                    id_select_textbook_image.imageIndex %= 3
                    id_select_textbook_image.imageIndex += 1
                }
            }
        }

        Item {
            id: id_effect_item
            implicitWidth: parent.width
            implicitHeight: 46
            anchors.bottom: parent.bottom
            clip: true

            ShaderEffectSource {
                id: id_effect_source
                anchors.fill: parent
                sourceItem: id_select_textbook_image
                sourceRect: Qt.rect(0, id_select_textbook_image.height - height, width, height)
            }

            FastBlur {
                anchors.fill: parent
                source: id_effect_source
                radius: 32
            }

            Rectangle {
                anchors.fill: parent
                color: "#661A1B1F"
            }
        }

        Text {
            height: contentHeight
            width: contentWidth
            anchors.centerIn: id_effect_item
            font.pixelSize: 16
            font.family: qmlGlobal.fontFamilyZhCn
            font.weight: Font.Bold
            color: YColors.white
            text: YTranslateText.textbookGuidSelect
            z: id_effect_item.z + 1
        }

        onClicked: {
            id_textbook_page.showSubPage(YEnum.Textbook_Select, false)
        }
    }

    Grid {
        id: id_textbook_guide_grid
        anchors.top: parent.top
        anchors.topMargin: 21
        anchors.left: parent.left
        anchors.leftMargin: 200
        columns: 1
        rowSpacing: 14
        Repeater {
            model: iconTextModel

            Item {
                implicitWidth: 94
                implicitHeight: 21

                YImage {
                    sourceSize: Qt.size(20, 20)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    imageName: iconName
                }

                Text {
                    height: parent.height
                    width: contentWidth
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamilyZhCn
                    color: YColors.grayText
                    text: textContent
                }
            }
        }

        ListModel {
            id: iconTextModel
            Component.onCompleted: {
                append({iconName: "textbook/guid-audio", textContent:YTranslateText.textbookGuidAudio})
                append({iconName: "textbook/guid-scan", textContent:YTranslateText.textbookGuidScan})
                append({iconName: "textbook/guid-listen", textContent:YTranslateText.textbookGuidListen})
                append({iconName: "textbook/guid-spoken", textContent:YTranslateText.textbookGuidSpoken})
            }
        }
    }

    Component.onCompleted: {
        id_select_textbook_image_timer.start()
    }
}

