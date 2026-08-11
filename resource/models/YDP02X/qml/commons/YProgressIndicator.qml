import QtQuick 2.12

Item {
    id: id_progress_indicator

    implicitWidth: id_background.width + spacing + id_progress_label.width
    implicitHeight: Math.max(id_background.height, id_progress_label.height)

    property alias backgroundColor: id_background.color
    property alias foregroundColor: id_foreground.color
    property int progress: 0
    property alias progressBarHeight: id_background.height
    property alias progressBarWidth: id_background.width
    property alias progressLabelHeight: id_progress_label.height
    property alias progressLabelWidth: id_progress_label.width
    property alias radius: id_background.radius
    property int spacing: 11

    Rectangle {
        id: id_background
        implicitWidth: 200
        implicitHeight: 6
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: "#29292E"
        radius: 8

        readonly property int stepValue: Math.ceil(width / 100.0)
    }

    Rectangle {
        id: id_foreground
        implicitHeight: id_background.height
        width: Math.min(id_background.stepValue * progress, id_background.width)
        anchors.verticalCenter: parent.verticalCenter
        radius: id_background.radius
        visible: width > 8
        color: "#509DEB"
    }

    YText {
        id: id_progress_label
        width: 38
        height: 24
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 18
        color: id_foreground.color
        text: ("%1%").arg(progress)
    }
}
