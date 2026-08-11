import "../commons"
import "../i18n"
import QtQuick 2.12
import com.github.penuniverse 1.0

Item {
    property color portraitBorderColor: "#000000"
    readonly property bool needReloadUserPortrait: (wifiManager.internetConnect && loginManager.isLogin && !qmlGlobal.fileExists(loginManager.iconPath))

    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    onNeedReloadUserPortraitChanged: {
        if (needReloadUserPortrait)
            id_reload_user_portrait_timer.restart();
    }
    Component.onCompleted: {
        if (needReloadUserPortrait)
            id_reload_user_portrait_timer.restart();
    }

    YUserPortrait {
        id: id_portrait_icon

        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        sourceSize: Qt.size(30, 30)
        defaultIconSource: "image://icons/portrait.png"

        // 使用不透明边框，圆环会盖住方形图片的四角，恢复圆形头像
        borderColor: YColors.black

        YMouseArea {
            anchors.fill: parent
            anchors.margins: -6
            onClicked: {
                if (loginManager.isLogin)
                    logManager.sendHttpLog("action=home_account_click");
                else
                    logManager.sendHttpLog("action=home_login_click");
                qmlGlobal.showLoginPage();
            }
            objectName: "YMainTitleBar.qml_id_login_button"
        }
    }

    Row {
        id: id_icon_container

        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: id_battary_value.left
        anchors.rightMargin: 18
        height: 18

        YImage {
            id: id_bluetooth_headset_icon

            sourceSize: Qt.size(18, 18)
            imageName: "settings/bluetooth-headset"
            visible: blueToothManager.link || systemBase.digHeadset
        }

        YImage {
            id: id_bluetooth_icon

            sourceSize: Qt.size(18, 18)
            imageName: "settings/bluetooth"
            visible: blueToothManager.onoff
        }

        YImage {
            id: id_wifi_icon

            sourceSize: Qt.size(18, 18)
            visible: wifiManager.onoff && wifiManager.link
            imageName: {
                if (wifiManager.signalStrength > 70)
                    return "settings/wifi";
                else if (wifiManager.signalStrength > 30)
                    return "settings/wifi-medium";
                else
                    return "settings/wifi-low";
            }
        }

        YText {
            id: id_time

            //anchors.centerIn: parent
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 16
            text: timeManager.currentTime
            width: paintedWidth
            height: paintedHeight
        }
    }

    YText {
        id: id_battary_value

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: id_battary_icon_border.left
        anchors.rightMargin: 12
        font.pixelSize: 16
        text: ("%1%").arg(battaryPercentage)
        width: paintedWidth
        height: paintedHeight
    }

    Rectangle {
        id: id_battary_icon_border

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: battaryChanging ? id_charging_icon.left : parent.right
        width: 28
        height: 14
        border.width: 2
        border.color: "#FFFFFF"
        color: "transparent"
        radius: 10
        smooth: true

        Item {
            id: id_battary_icon

            width: 22
            height: 8
            anchors.centerIn: parent

            Item {
                id: id_progress_resource

                anchors.fill: parent
                smooth: true
                clip: true
                anchors.rightMargin: (100 - battaryPercentage) * id_battary_icon.width / 100

                Rectangle {
                    id: id_indicator_resource_percentage

                    implicitWidth: id_battary_icon.width
                    implicitHeight: id_battary_icon.height
                    anchors.right: parent.right
                    anchors.rightMargin: -parent.anchors.rightMargin
                    color: {
                        if (battaryChanging)
                            return (100 > battaryPercentage) ? "#00FF66" : YColors.white;

                        return (20 > battaryPercentage) ? YColors.red : YColors.white;
                    }
                    radius: height / 2
                    smooth: true
                }
            }
        }
    }

    YImage {
        id: id_charging_icon

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        sourceSize: Qt.size(14, 14)
        imageName: "ic_battery_flash"
        visible: battaryChanging
    }

    YTimer {
        id: id_reload_user_portrait_timer

        interval: 3000
        onTriggered: {
            if (needReloadUserPortrait)
                loginManager.queryUserInfo();
            else
                console.warn("YMainTitleBar.qml===no need reload");
        }
        objectName: "YMainTitleBar.qml_id_reload_user_portrait_timer"
    }

}
