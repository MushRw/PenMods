import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"

YSettingItemPage {
    id: page
    objectName: "YPage===AutoShutdownSetting.qml"
    property alias title: titleItem.title

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: titleItem.height + column.height

        YSettingItemTitle {
            id: titleItem
            title: "请调节无操作自动关机时长"
        }

        Column {
            id: column
            anchors.top: titleItem.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            Repeater {
                model: ["15 分钟", "30 分钟", "60 分钟", "120 分钟", "关闭"]

                YSettingAboutClickableItem {
                    required property string modelData
                    title: modelData
                    imageName: screenManager.autoShutdownDuration === modelData ? "settings/st-check" : ""
                    opacityChangableWhenPressed: false
                    onClicked: screenManager.autoShutdownDuration = modelData
                }
            }
        }
    }
}
