import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingUpdate.qml"

//    readonly property string currentVersion: updateManager.currentVersion
//    readonly property string targetVersion: "YDP021_1.3.5" // updateManager.targetVersion
//    readonly property string updateNote: "1. 「语音翻译」43种语言在线互译\n2. 「拍照翻译」快捷重拍和阅读模式\n3.  下拉菜单支持快捷设置" // updateManager.updateNote
//    readonly property real updateImgSize: 300 // updateManager.updateImgSize
//    readonly property int downloadProgress: 45 // updateManager.downloadProgress
//    readonly property int installProgress: 38 // updateManager.installProgress
//    readonly property int otaStatus: YEnum.UPDATE_HAS_NEW_VERSION // updateManager.otaStatus

    readonly property string currentVersion: updateManager.currentVersion
    readonly property string targetVersion:  updateManager.targetVersion
    readonly property string updateNote: updateManager.updateNote
    readonly property real updateImgSize: updateManager.updateImgSize
    readonly property int downloadProgress: updateManager.downloadProgress
    readonly property int installProgress: updateManager.installProgress
    readonly property int otaStatus: updateManager.otaStatus

    function checkUpdate() {
        updater.check()
    }

    // 开始下载新版本
    function downloadStart() {
        updater.download()
    }

    // 安装新版本
    function install() {
        updater.install()
    }

    // 取消安装新版本
    function cancelInstall() {
//        updateManager.cancelInstall()
    }

    function closeSettingUpdatePage() {
        backButtonClicked()
    }

    Connections {
        target: updateManager
        ignoreUnknownSignals: true
        onCurrentVersionChanged: {
            console.log("ZDS===YSettingUpdate.qml===onCurrentVersionChanged:",
                        currentVersion)
        }
        onTargetVersionChanged: {
            console.log("ZDS===YSettingUpdate.qml===targetVersionChanged:",
                        targetVersion)
        }
        onUpdateNoteChanged: {
            console.log("ZDS===YSettingUpdate.qml===updateNoteChanged:",
                        updateNote)
        }
        onOtaStatusChanged: {
            console.log("ZDS===YSettingUpdate.qml===onOtaStatusChanged:",
                        otaStatus)
            switch (otaStatus) {
                case YEnum.UPDATE_LATEST_VERSION: // 已安装最新版本，无需升级
                    break
            }
        }
    }

    Item {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10

        YSettingItemTitle {
            id: id_title_container
            title: YTranslateText.update
        }

        YSettingUpdateCheckUpdate {
            anchors.top: id_title_container.bottom
            anchors.topMargin: 28
        }

        YSettingUpdateNoUpdate {
            anchors.top: id_title_container.bottom
            anchors.topMargin: 18
        }
    }

    YSettingUpdateCheckNetworkLoader {
        id: id_setting_update_check_network_loader
        onCheckNetwork: {
            id_pop_layer.show("settingpages/YSettingWifi")
        }
    }

    YSettingUpdateDownloadLoader {
        id: id_setting_update_download_loader
    }

    YSettingUpdateLowPowerLoader {
        id: id_setting_update_low_power_loader
    }

    YPopLayer {
        id: id_pop_layer
        onPopItemObjectChanged: {
            if (null !== popItemObject) {
                popItemObject.backButtonClicked.connect(function(){
                    checkUpdate()
                })
            }
        }
    }

    onBackButtonClicked: {
        console.warn("YSettingUpdate.qml===onBackButtonClicked===")
    }
}
