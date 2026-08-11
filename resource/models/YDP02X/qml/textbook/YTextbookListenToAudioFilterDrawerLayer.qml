import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDrawerLayer {
    id: id_drawer_layer

    property int currentIndex: 0
    signal filterChanged(string filterString)

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_unit_content.height

        Column {
            id: id_unit_content
            anchors.top: parent.top
            topPadding: 16
            bottomPadding: 20
            spacing: 10
            width: parent.width

            YTextBase {
                id: id_title
                color: YColors.grayText
                font.pixelSize: 16

                font.family: qmlGlobal.fontFamilyZhCn
                text: YTranslateText.textbookChooseTheUnitToStudy
            }
            Grid {
                id: id_grid_container
                width: parent.width
                columns: 2
                spacing: 8
                Repeater {
                    id: id_grid_container_repeater
                    model: textBookBlockManager.bookDistinctUnitsFilterList
                    YButton {
                        implicitWidth: 124
                        color: index === currentIndex ? YColors.red : "#2D2E33"
                        mouseAreaMargins: -4
                        textFamily: qmlGlobal.fontFamilyZhCn
                        text: model.modelData
                        textItem.wrapMode: YText.WordWrap
                        textItem.horizontalAlignment: YText.AlignHCenter
                        textItem.width: 112
                        textItem.elide: YText.ElideRight
                        textItem.maximumLineCount: 2
                        textItem.textFormat: YText.PlainText
                        onClicked: {
                            if (currentIndex !== index) {
                                currentIndex = index
                                filterChanged(model.modelData)
                                hide()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
       // console.warn("YTextbookListenToAudioFilterDrawerLayer.qml===Component.onCompleted")
       // const distinctUnitsFilterList = textBookBlockManager.bookDistinctUnitsFilterList
       // id_grid_container_repeater.model = distinctUnitsFilterList
    }
}
