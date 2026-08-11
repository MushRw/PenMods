import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YDialog {
    anchors.fill: parent

    property bool confirmLogout: false
    property bool needUpload: true
    property bool uploadDoing: false
    property int uploadProgress: 20

    function logoutAccount() {
        loginManager.logout()
        close()
        closed()
    }

    Item {
        anchors.fill: parent
        visible: !uploadDoing

        Item {
            id: id_tip_item
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.right: parent.right
            anchors.rightMargin: 50
            anchors.top: parent.top
            anchors.topMargin: 18
            height: 78

            YText {
                id: id_tip_text
                font.pixelSize: 18
                width: parent.width
                anchors.centerIn: parent
                horizontalAlignment: YText.AlignHCenter
                verticalAlignment: YText.AlignVCenter
                wrapMode: YText.Wrap
                textFormat: Text.RichText
                text: confirmLogout ? YTranslateText.logoutUploadHistoryRecord
                                    : YTranslateText.logoutWillNotBeAbleToSync
            }
        }

        Item {
            id: id_button_item
            height: 50
            width: id_button_row.width
            anchors.top: id_tip_item.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                id: id_button_row
                height: id_button_item.height
                spacing: 16

                YButton {
                    id: id_logout_button
                    implicitWidth: 200
                    text: YTranslateText.logout
                    visible: !confirmLogout
                    enabled: !uploadDoing
                    onClicked: {
                        if (needUpload) {
                            confirmLogout = true
                        } else {
                            if (!wifiManager.internetConnect) {
                                qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                return
                            }
                            logoutAccount()
                        }
                    }
                }

                YButton {
                    id: id_logout_not_upload_button
                    implicitWidth: 140
                    color: YColors.grayButton
                    text: YTranslateText.logoutNotUpload
                    visible: confirmLogout
                    enabled: !uploadDoing
                    onClicked: {
                        if (!wifiManager.internetConnect) {
                            qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                            return
                        }
                        logoutAccount()
                    }
                }

                YButton {
                    id: id_logout_after_upload_button
                    implicitWidth: 140
                    text: YTranslateText.logoutAfterUpload
                    visible: confirmLogout
                    enabled: !uploadDoing
                    onClicked: {
                        if (!wifiManager.internetConnect) {
                            qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                            return
                        }
                        if (!loginManager.isLogin) {
                            qmlGlobal.showToast(YTranslateText.accountHasUnbundling, YColors.grayNormal)
                            return
                        }
                        historyManager.startUploadHistory()
                        uploadDoing = true
                    }
                }
            }
        }

        YIconButton {
            id: id_close_button
            implicitWidth: 30
            implicitHeight: 30
            radius: height/2
            color: YColors.grayNormal
            mouseAreaMargins: -22
            imageName: "commons/close"
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 8
            enabled: !uploadDoing
            onClicked: {
                close()
                closed()
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: uploadDoing

        Row {
            spacing: 10
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter

            YCircularProgressBar {
                id: id_progress_bar
                anchors.verticalCenter: parent.verticalCenter
                lineCap: "round"
                lineWidth: 6
                size: 40
                progressValue: uploadProgress

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1920
                    running: uploadDoing
                    loops: NumberAnimation.Infinite
                    alwaysRunToEnd: true
                }
            }

            YText {
                width: contentWidth
                height: 40
                font.pixelSize: 18
                verticalAlignment: YText.AlignVCenter
                text: YTranslateText.logoutHistoryUploading
            }
        }
    }

    Connections {
        target: historyManager
        ignoreUnknownSignals: true
        enabled: visible
        onHasNotUpload: {
            console.log("YLoginPageLogoutConfirm.qml===historyManager.hasNotUpload count:", count)
            needUpload = count > 0
            if (confirmLogout) {
                logoutAccount()
            }
        }
        onUploadProgress: {
            console.log("YLoginPageLogoutConfirm.qml===historyManager.uploadProgress value:", value)
            if (uploadDoing && value > uploadProgress) {
                uploadProgress = value
            }
        }
        onUploadFinished: {
            console.log("YLoginPageLogoutConfirm.qml===historyManager.uploadFinished suf:", suf)
            if (suf) {
                logoutAccount()
            } else {
                uploadDoing = false
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            historyManager.checkHasNotUpload()
        } else {
            confirmLogout = false
            needUpload = true
            uploadDoing = false
            uploadProgress = 20
        }
    }

    Component.onCompleted: {
        historyManager.checkHasNotUpload()
        console.log("YLoginPageLogoutConfirm.qml===Component.onCompleted===called")
    }

    Component.onDestruction: {
        console.log("YLoginPageLogoutConfirm.qml===Component.onDestruction===called")
    }
}
