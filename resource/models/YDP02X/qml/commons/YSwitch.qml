import QtQuick 2.12

Rectangle {
    implicitWidth: 52
    implicitHeight: 30
    radius: height / 2
    smooth: true
    property color onColor: YColors.green
    property color offColor: YColors.graySwitchOff
    color: switchOn ? onColor : offColor
    readonly property bool animationRunning: id_transition_animation.running
    property bool switchOn: false

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: height / 2
        color: YColors.white
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: !switchOn ? 3 : 25
        Behavior on anchors.leftMargin {
            NumberAnimation {
                id: id_transition_animation
            }
        }
    }
}
