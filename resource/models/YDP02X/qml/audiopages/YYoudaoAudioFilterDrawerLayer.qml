import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YBackground {
    id: id_drawer_layer
    anchors.fill: parent
    visible: false

    property int currentIndex: YEnum.AudioFilters.AllAudio
    signal filterChanged(string filterString)

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            hide()
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_column.height

        Column {
            id: id_column
            width: parent.width
            topPadding: 16
            bottomPadding: 16

            YTextBase {
                id: id_title
                color: YColors.grayText
                font.pixelSize: 16
                text: YTranslateText.ydListeningChoice
            }

            YSpacingForColumn {
                implicitHeight: 10
            }

            Grid {
                id: id_grid_container
                columns: 2
                spacing: 8
                Repeater {
                    id: id_grid_container_repeater
                    YButton {
                        implicitWidth: 124
                        color: index === currentIndex ? YColors.red : "#2D2E33"
                        mouseAreaMargins: -4
                        textFamily: qmlGlobal.fontFamilyZhCn
                        text: model.modelData
                        onClicked: {
                            if (currentIndex !== index) {
                                currentIndex = index
                                if (0 === index) {
                                    filterChanged("全部")
                                } else {
                                    filterChanged(model.modelData)
                                }
                                hide()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        const columnFilterList = [YTranslateText.all].concat(settingManager.columnFilterList)
        id_grid_container_repeater.model = columnFilterList
    }
}
