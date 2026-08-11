import QtQuick 2.12
import "../commons"

YSettingResetBase {
    onClicked: {
        console.log("YSettingResetSettingsReset.qml===factoryReset")
        settingManager.factoryReset()
    }
}
