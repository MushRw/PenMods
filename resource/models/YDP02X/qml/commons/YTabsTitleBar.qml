import QtQuick 2.12

Item {
    implicitHeight: 28
    width: id_container_row.width

    property alias spacing: id_container_row.spacing
    property int currentIndex: 0
    property var namesArray: null
    property alias count: id_repeater.count

    Row {
        id: id_container_row
        spacing: 30
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Repeater {
            id: id_repeater
            model: namesArray

            YTextBase {
                font.pixelSize: 16
                color: index === currentIndex ? YColors.red : YColors.grayText
                text: model.modelData
                height: 20
                width: paintedWidth
                verticalAlignment: YTextBase.AlignVCenter
                opacity: id_tab_ma.pressed ? 0.6 : 1

                YMouseArea {
                    id: id_tab_ma
                    anchors.fill: parent
                    anchors.margins: -spacing/2
                    onClicked: {
                        currentIndex = index
                    }
                    objectName: "YTabsTitleBar.qml_YMouseArea"
                }

                Rectangle {
                    visible: index === currentIndex
                    implicitWidth: 24
                    implicitHeight: 3
                    radius: height/2
                    anchors.top: parent.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: YColors.red
                }
            }
        }
    }
}
