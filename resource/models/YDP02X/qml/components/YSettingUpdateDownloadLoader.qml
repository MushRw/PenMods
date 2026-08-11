import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../settingpages"
import "../i18n"

YLoader {
    id: id_update_download_loader
    anchors.fill: parent
    active: (YEnum.UPDATE_HAS_NEW_VERSION === otaStatus)
            || (YEnum.UPDATE_DOWNLOAD_PAUSE === otaStatus)
            || (YEnum.UPDATE_DOWNLOADING === otaStatus)
            || (YEnum.UPDATE_ERROR_NO_ENOUGH_MEMORY === otaStatus)
            || (YEnum.UPDATE_DOWNLOAD_FINISHED === otaStatus)
            || (YEnum.UPDATE_INSTALLING === otaStatus)
            || (YEnum.UPDATE_MD5_CHECKING === otaStatus)
            || (YEnum.UPDATE_MD5_CHECK_SUCCESSFULLY === otaStatus)
            || (YEnum.UPDATE_ERROR_MD5_CHECK === otaStatus)
            || (YEnum.UPDATE_INSTALL_FAILED === otaStatus)
            || (YEnum.UPDATE_INSTALL_SUCCESSFULLY === otaStatus)
    sourceComponent: YBackgroundIgnoreMouseEvent {
        objectName: "YSettingUpdateDownloadLoader.qml===sourceComponent"

        YVerticalTitleBarBase {
            objectName: "YVerticalTitleBar.qml"
            YBackButton {
                id: id_back_button
                isPositionLeftBar: true
                onClicked: {
                    closeSettingUpdatePage()
                }
                objectName: "YVerticalTitleBar.qml_" + id_title_bar.objectName
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10
            contentHeight: id_update_download_loader_column.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: id_update_download_loader_column
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
                YSettingItemTitle {
                    id: id_title_bar
                    title: YTranslateText.update
                }
                Rectangle {
                    implicitHeight: 50
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: YColors.grayNormal
                    radius: 12
                    YTextMedium {
                        id: id_new_update_label
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        text: YTranslateText.updateHasNewVersion
                    }
                    YTextBase {
                        id: id_new_update_version
                        anchors.left: id_new_update_label.right
                        anchors.leftMargin: 10
                        anchors.bottom: id_new_update_label.bottom
                        font.pixelSize: 16
                        color: YColors.grayText
                        text: ("(%1)").arg(targetVersion)
                    }
                }
                YSpacingForColumn {
                    implicitHeight: 8
                }

                YButtonBase {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: 50
                    radius: height/2
                    Rectangle {
                        implicitHeight: 50
                        color: ((YEnum.UPDATE_ERROR_MD5_CHECK === otaStatus)
                                || (YEnum.UPDATE_INSTALL_FAILED === otaStatus)
                                || (YEnum.UPDATE_DOWNLOAD_PAUSE === otaStatus))
                               ? YColors.red : YColors.blueRect
                        radius: height/2
                        width: {
                            switch (otaStatus) {
                            case YEnum.UPDATE_DOWNLOAD_PAUSE:
                                return Math.max(80, parent.width * downloadProgress / 100.0)
                            case YEnum.UPDATE_DOWNLOADING:
                                return Math.max(80, parent.width * downloadProgress / 100.0)
                            case YEnum.UPDATE_INSTALLING:
                                return Math.max(80, parent.width * installProgress / 100.0)
                            case YEnum.UPDATE_HAS_NEW_VERSION:
                            case YEnum.UPDATE_ERROR_NO_ENOUGH_MEMORY:
                            case YEnum.UPDATE_DOWNLOAD_FINISHED:
                            case YEnum.UPDATE_MD5_CHECKING:
                            case YEnum.UPDATE_MD5_CHECK_SUCCESSFULLY:
                            case YEnum.UPDATE_ERROR_MD5_CHECK:
                            case YEnum.UPDATE_INSTALL_FAILED:
                            default:
                                return parent.width
                            }
                        }
                    }

                    YTextMedium {
                        id: id_button_tip
                        anchors.centerIn: parent
                        text: {
                            switch (otaStatus) {
                            case YEnum.UPDATE_HAS_NEW_VERSION:
                            case YEnum.UPDATE_ERROR_NO_ENOUGH_MEMORY:
                                return YTranslateText.updateButtonDownloadTip.arg(updateImgSize)
                            case YEnum.UPDATE_DOWNLOADING:
                                return YTranslateText.updateButtonPauseTip.arg(downloadProgress)
                            case YEnum.UPDATE_DOWNLOAD_PAUSE:
                                return YTranslateText.updateButtonContinueTip.arg(downloadProgress)
                            case YEnum.UPDATE_DOWNLOAD_FINISHED:
                                return YTranslateText.updateButtonInstallTip
                            case YEnum.UPDATE_INSTALLING:
                                return YTranslateText.updateButtonInstallingTip.arg(installProgress)
                            case YEnum.UPDATE_MD5_CHECKING:
                                return YTranslateText.updateButtonVerifyingTip
                            case YEnum.UPDATE_MD5_CHECK_SUCCESSFULLY:
                                return YTranslateText.updateButtonVerifyFinishTip
                            case YEnum.UPDATE_ERROR_MD5_CHECK:
                                return YTranslateText.updateButtonVerifyFaildTip
                            case YEnum.UPDATE_INSTALL_FAILED:
                                return YTranslateText.updateButtonInstallFaildTip
                            case YEnum.UPDATE_INSTALL_SUCCESSFULLY:
                                return YTranslateText.updateButtonInstallFinishTip
                            }
                        }
                    }

                    clickable: (YEnum.UPDATE_HAS_NEW_VERSION === otaStatus)
                               || (YEnum.UPDATE_DOWNLOAD_PAUSE === otaStatus)
                               || (YEnum.UPDATE_DOWNLOADING === otaStatus)
                               || (YEnum.UPDATE_ERROR_NO_ENOUGH_MEMORY === otaStatus)
                               || (YEnum.UPDATE_DOWNLOAD_FINISHED === otaStatus)
                               || (YEnum.UPDATE_ERROR_MD5_CHECK === otaStatus)
                               || (YEnum.UPDATE_INSTALL_FAILED === otaStatus)
                               || (YEnum.UPDATE_INSTALL_SUCCESSFULLY === otaStatus)

                    onClicked: {
                        switch (otaStatus) {
                        case YEnum.UPDATE_HAS_NEW_VERSION:
                            downloadStart()
                            break
                        //case YEnum.UPDATE_DOWNLOAD_PAUSE:
                        //    downloadResume()
                        //    break
                        //case YEnum.UPDATE_DOWNLOADING:
                        //    downloadPause()
                        //    break
                        case YEnum.UPDATE_ERROR_NO_ENOUGH_MEMORY:
                            qmlGlobal.showToast(YTranslateText.lowStorageTip
                                                .arg(updateImgSize), "#E9900C")
                            break
                        case YEnum.UPDATE_DOWNLOAD_FINISHED:
                            install()
                            break
                        case YEnum.UPDATE_ERROR_MD5_CHECK:
                            install()
                            break
                        case YEnum.UPDATE_INSTALL_FAILED:
                            install()
                            break
                        case YEnum.UPDATE_INSTALL_SUCCESSFULLY:
                            mod.reboot()
                            break;
                        case YEnum.UPDATE_MD5_CHECK_SUCCESSFULLY:
                        case YEnum.UPDATE_INSTALLING:
                        case YEnum.UPDATE_MD5_CHECKING:
                        default:
                            break
                        }
                    }
                }
                YSpacingForColumn {
                    implicitHeight: 12
                    visible: id_new_update_note.visible
                }
                YTextBase {
                    id: id_new_update_note
                    anchors.left: parent.left
                    anchors.right: parent.right
                    font.pixelSize: 16
                    color: YColors.grayText
                    text: updateNote
                    wrapMode: YTextBase.Wrap
                    visible: updateNote.length > 0
                }
                YSpacingForColumn {
                    implicitHeight: 16
                }
            }
        }

    }
}
