import QtQuick 2.12

// The value of 'objectName' shoud be set, for hot area test

MouseArea {
    id: id_y_mouse_area
    objectName: "YMouseArea.qml"
    acceptedButtons: Qt.LeftButton
    hoverEnabled: false
    scrollGestureEnabled: false

    property bool hotAreaTesting: false // todo use config file open

    function qmlCreateComponent(qmlName) {
        return Qt.createComponent(("qrc:/qml/%1.qml").arg(qmlName))
    }

    // 这里曾经有一句无条件的 `console.log("YMouseArea.qml===...clicked")`。
    // 它是全树触摸基类（68 个文件继承、96 处实例化，键盘单实例就有 120 个按键），
    // 于是**每点一次屏幕就往 /userdata/applog/ 写一条日志**（KB-17，P0）。
    // 更关键的是：基类定义 onClicked 时，凡是自己没写 onClicked 的子类都会
    // 继承这条日志 —— 而它连 objectName 都没区分（默认全是 "YMouseArea.qml"），
    // 打出来的内容没有任何排查价值，只是在持续磨损 flash。已删除。

    YLoader {
        anchors.fill: parent
        active: hotAreaTesting && id_y_mouse_area.enabled
        sourceComponent: Rectangle {
            id: id_hot_area_test
            color: "#80FF0000"
        }
    }

    property bool isPressAndHold: false

    onPressAndHold: {
        isPressAndHold = true
    }

    onReleased: {
        isPressAndHold = false
    }
}
