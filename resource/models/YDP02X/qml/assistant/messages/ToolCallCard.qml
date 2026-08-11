import QtQuick 2.12

Item {
    id: root

    property string text: ""
    property string rawText: ""
    property string toolState: ""
    property real maxWidth: 300
    property var fontFamily

    property bool expanded: false

    width: maxWidth
    height: cardHeader.height + cardExpanded.height

    Rectangle {
        id: cardHeader
        width: parent.width
        height: 36
        radius: root.expanded ? 0 : 10
        color: {
            if (root.toolState === "searching")
                return "#1A2B3C";
            if (root.toolState === "pending")
                return "#2B2A1A";
            if (root.toolState === "done")
                return "#1A2E1A";
            if (root.toolState === "error")
                return "#2E1A1A";
            return "#1C2533";
        }
        border.width: 1
        border.color: {
            if (root.toolState === "searching")
                return "#2B4A6A";
            if (root.toolState === "pending")
                return "#4A4A2A";
            if (root.toolState === "done")
                return "#2A4A2A";
            if (root.toolState === "error")
                return "#4A2A2A";
            return "#2B3A4A";
        }
        clip: true

        Behavior on radius {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Row {
            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 8
            width: parent.width - 44

            Canvas {
                id: searchIcon
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                property string iconColor: {
                    if (root.toolState === "searching")
                        return "#62A8EA";
                    if (root.toolState === "pending")
                        return "#FFA726";
                    if (root.toolState === "done")
                        return "#4CAF50";
                    if (root.toolState === "error")
                        return "#FF453A";
                    return "#8899AA";
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = iconColor;
                    ctx.lineWidth = 1.8;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(6.5, 6.5, 4.5, 0, 2 * Math.PI);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(9.7, 9.7);
                    ctx.lineTo(13, 13);
                    ctx.stroke();
                }

                onIconColorChanged: requestPaint()

                SequentialAnimation on opacity {
                    id: pulseAnimation
                    running: root.toolState === "searching" || root.toolState === "pending"
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.3
                        duration: 600
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 600
                        easing.type: Easing.InOutSine
                    }
                    onStopped: searchIcon.opacity = 1.0
                }
                Component.onCompleted: opacity = 1.0
            }

            Text {
                text: root.text
                textFormat: Text.PlainText
                color: {
                    if (root.toolState === "searching")
                        return "#62A8EA";
                    if (root.toolState === "pending")
                        return "#FFA726";
                    if (root.toolState === "done")
                        return "#4CAF50";
                    if (root.toolState === "error")
                        return "#FF453A";
                    return "#8899AA";
                }
                font.pixelSize: 12
                font.family: root.fontFamily || ""
                elide: Text.ElideRight
                width: parent.width - searchIcon.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Canvas {
            id: arrowCanvas
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            width: 12
            height: 12
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#8899AA";
                ctx.lineWidth = 1.5;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                if (root.expanded) {
                    ctx.beginPath();
                    ctx.moveTo(2, 8);
                    ctx.lineTo(6, 4);
                    ctx.lineTo(10, 8);
                    ctx.stroke();
                } else {
                    ctx.beginPath();
                    ctx.moveTo(2, 4);
                    ctx.lineTo(6, 8);
                    ctx.lineTo(10, 4);
                    ctx.stroke();
                }
            }
            Connections {
                target: root
                onExpandedChanged: arrowCanvas.requestPaint()
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        id: cardExpanded
        visible: height > 0
        width: cardHeader.width
        anchors.top: cardHeader.bottom
        height: root.expanded ? Math.min(detailText.implicitHeight + 16, 80) : 0
        color: "#111922"
        radius: 10

        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            width: parent.width
            height: 10
            anchors.top: parent.top
            color: parent.color
        }

        border.width: 1
        border.color: "#2B3A4A"
        clip: true

        Flickable {
            id: detailFlick
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: detailText.implicitHeight
            clip: true
            interactive: detailText.implicitHeight > (parent.height - 16)

            Text {
                id: detailText
                width: detailFlick.width
                text: root.rawText
                color: "#667788"
                font.pixelSize: 10
                font.family: "Microsoft YaHei"
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }
}
