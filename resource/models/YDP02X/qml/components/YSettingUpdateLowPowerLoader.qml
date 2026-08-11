import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YLoader {
    anchors.fill: parent
    active: wifiManager.internetConnect
            && (((10 > batteryManager.power) && !batteryManager.charging)
                || (YEnum.UPDATE_ERROR_LOW_BATTERY === otaStatus))
    readonly property bool battaryChanging: batteryManager.charging

    sourceComponent: YOneButtonDialog {
        tipItem.text: YTranslateText.lowPowerTip
        tipItem.textFormat: Text.RichText
        buttonItem.text: YTranslateText.iKnow
        //buttonItem.enabled: battaryChanging
        onClicked: {
            closeSettingUpdatePage()
            close()
        }
        onClosed: {
            closeSettingUpdatePage()
            close()
        }
    }
    onLoaded: {
        item.show()
    }
}
