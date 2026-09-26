import QtQuick 2.12

Timer {
    // objectName needs to be set
    //
    // 这里曾经有一句无条件的 `console.log(...)`：全树 52 处用 YTimer，
    // 于是**每次 timer 起停都往 /userdata/applog/ 写一条日志**（KB-18）。
    // 与 YMouseArea.qml 那句同源（KB-17），已一并删除。
}
