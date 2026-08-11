import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.github.penuniverse 1.0
import com.youdao.pen 1.0

YBackButtonAudioPage {
    id: id_external_player
    pageIndex: PageIndex.ExternalPlayer

    readonly property int barHeight: 36
    property bool controlsVisible: true

    function showControls() {
        controlsVisible = true;
        id_hide_timer.restart();
    }

    function toggleControls() {
        controlsVisible = !controlsVisible;
        if (controlsVisible)
            id_hide_timer.restart();
    }

    // ============ 第1层：占位画面（最底层） ============
    Rectangle {
        id: id_placeholder_layer
        anchors.fill: parent
        color: "#000000"

        Column {
            anchors.centerIn: parent
            spacing: 10

            // 播放图标（Canvas 绘制，避免字体缺失）
            Canvas {
                id: id_play_badge
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, 34, 0, Math.PI * 2);
                    ctx.fillStyle = "rgba(255,255,255,0.10)";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.moveTo(29, 20);
                    ctx.lineTo(29, 52);
                    ctx.lineTo(54, 36);
                    ctx.closePath();
                    ctx.fillStyle = "#FFFFFF";
                    ctx.fill();
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: externalPlayer.fileName
                color: "#AAAAAA"
                font.pixelSize: 12
                elide: Text.ElideMiddle
                width: 280
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: externalPlayer.running ? "播放器运行中，点左上角返回以退出" : "点击下方播放按钮以开始"
                color: "#999999"
                font.pixelSize: 12
            }
        }
    }

    // ============ 第2层：点击区域（切换控制栏） ============
    MouseArea {
        id: id_click_area
        anchors.fill: parent
        anchors.topMargin: barHeight
        anchors.bottomMargin: barHeight
        onClicked: id_external_player.toggleControls()
    }

    // ============ 第3层：顶部栏（返回 + 文件名） ============
    Rectangle {
        id: id_top_bar
        width: parent.width
        height: barHeight
        anchors.top: parent.top
        visible: id_external_player.controlsVisible
        opacity: id_external_player.controlsVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.85) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        Item {
            id: id_back_btn
            width: 40
            height: barHeight

            Canvas {
                anchors.centerIn: parent
                width: 18
                height: 18
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(12, 3);
                    ctx.lineTo(5, 9);
                    ctx.lineTo(12, 15);
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 退出播放器（修复：返回键之前先真正停止 mpv）
                    if (externalPlayer.running)
                        externalPlayer.close();
                    id_external_player.backButtonClicked();
                }
            }
        }

        Text {
            anchors.left: id_back_btn.right
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: externalPlayer.fileName
            color: "#FFFFFF"
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }
    }

    // ============ 第3层：底部栏（播放/暂停） ============
    Rectangle {
        id: id_bottom_bar
        width: parent.width
        height: barHeight
        anchors.bottom: parent.bottom
        visible: id_external_player.controlsVisible
        opacity: id_external_player.controlsVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
        }

        Item {
            id: id_play_btn
            width: 44
            height: barHeight

            Canvas {
                id: id_play_icon
                anchors.centerIn: parent
                width: 22
                height: 22

                function refresh() {
                    requestPaint();
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#FFFFFF";
                    if (externalPlayer.running) {
                        // 暂停：两条竖条
                        ctx.fillRect(4, 3, 5, 16);
                        ctx.fillRect(13, 3, 5, 16);
                    } else {
                        // 播放：三角
                        ctx.beginPath();
                        ctx.moveTo(4, 2);
                        ctx.lineTo(4, 20);
                        ctx.lineTo(20, 11);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Connections {
                    target: externalPlayer
                    function onRunningChanged() {
                        id_play_icon.refresh();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (externalPlayer.running) {
                        qmlGlobal.showToast("播放器已在运行");
                        return;
                    }
                    externalPlayer.open();
                    id_external_player.showControls();
                }
            }
        }

        Text {
            anchors.left: id_play_btn.right
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: externalPlayer.running ? "正在播放，返回以退出" : "点击播放"
            color: "#FFFFFF"
            font.pixelSize: 12
        }
    }

    // ============ 自动隐藏控制栏 ============
    Timer {
        id: id_hide_timer
        interval: 3500
        onTriggered: id_external_player.controlsVisible = false
    }

    Component.onCompleted: {
        id_hide_timer.start();
    }

    // 无论通过哪种方式退出页面（返回键/主页键/系统关闭），都确保播放器停止
    Component.onDestruction: {
        if (externalPlayer.running)
            externalPlayer.close();
    }
}
