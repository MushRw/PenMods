import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./i18n"

YPage {
    id: id_power_off_page
    objectName: "YPage===YPowerOffPage.qml"
    pageIndex: YEnum.PageIndex.PowerOff

    YText {
        id: id_power_off_tip
        anchors.centerIn: parent
        font.pixelSize: 20
        text: YTranslateText.powerOffing + "..."
    }

    Component.onDestruction: {
        console.log("YPowerOffPage.qml===Component.onDestruction===called")
    }

}
