import QtQuick 2.12

Item {
    id: root

    property string edge: "left"
    property real edgeWidth: 40
    property real threshold: 60
    property bool gestureEnabled: true
    property color indicatorColor: "#2B5278"

    signal triggered()

    width: edgeWidth

    property real _startX: 0
    property real _currentX: 0
    property bool _isDragging: false

    MouseArea {
        id: gestureArea
        anchors.fill: parent
        z: 50

        onPressed: {
            if (!root.gestureEnabled) return;
            root._startX = mouseX;
            root._currentX = mouseX;
            root._isDragging = true;
        }

        onPositionChanged: {
            if (!root._isDragging || !root.gestureEnabled) return;
            root._currentX = mouseX;
            var delta = (root.edge === "left")
                ? (root._currentX - root._startX)
                : (root._startX - root._currentX);
            if (delta > 0) {
                indicator.opacity = Math.min(delta / root.threshold, 1.0);
            }
        }

        onReleased: {
            if (!root._isDragging || !root.gestureEnabled) {
                root._isDragging = false;
                indicator.opacity = 0;
                return;
            }

            var delta = (root.edge === "left")
                ? (root._currentX - root._startX)
                : (root._startX - root._currentX);

            if (delta > root.threshold) {
                root.triggered();
            }

            root._isDragging = false;
            indicator.opacity = 0;
        }

        onCanceled: {
            root._isDragging = false;
            indicator.opacity = 0;
        }
    }

    Rectangle {
        id: indicator
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        x: root.edge === "left" ? 0 : (parent.width - width)
        width: 3
        color: root.indicatorColor
        opacity: 0
        z: 60

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
