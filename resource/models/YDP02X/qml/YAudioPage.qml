import QtQuick 2.12
import QtGraphicalEffects 1.0
import com.youdao.pen 1.0

import "./commons"
import "./components"
import "./audiopages"
import "./i18n"

YBackButtonAudioPage {
    id: id_auido_page
    objectName: "YPage===YAudioPage.qml"
    pageIndex: YEnum.PageIndex.Audioplayer

    function stateNormal(quicklyEnter) {
    }

    Flickable {
        id: id_container
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentWidth: id_button_row.width

        Row {
            id: id_button_row
            topPadding: 10
            bottomPadding: 10
            spacing: 8

            YAudioPageDomainButton {
                id: id_my_imports_button
                name: "文件管理"
                count: "Beta"
                imageName: "audiopage/my_imports"

                onValidClicked: {
                    id_pop_layer.show("audiopages/FileManagerPage")
                }
            }

            YAudioPageDomainButton {
                id: id_yd_listening_button
                name: YTranslateText.ydListening
                count: columnManager.listeningCount + YTranslateText.pieces
                imageName: "audiopage/yd_listening"

                function enterPage() {
                    qmlGlobal.reinitYDListening()
                    id_pop_layer.show("audiopages/YYoudaoAudioPage")
                }

                onValidClicked: {
                    enterPage()
                }
            }

            YAudioPageDomainButton {
                id: id_scan_reading_button
                name: YTranslateText.myProductionAudios
                count: columnManager.productionCount + YTranslateText.pieces
                imageName: "audiopage/scan_audio"

                onValidClicked: {
                    logManager.sendHttpLog("action=listening_make_click")
                    columnManager.loadMore(true, columnManager.domainNameMyProduction)
                    id_pop_layer.show("audiopages/YMyProductionPage")
                }
            }

        }
    }

    Item {
        id: id_effect_item
        implicitWidth: 54
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        ShaderEffectSource {
            id: id_effect_source
            anchors.fill: parent
            sourceItem: id_container
            sourceRect: Qt.rect(x - 54, y , width, height)
        }

        FastBlur {
            anchors.fill: parent
            source: id_effect_source
            radius: 32
        }

        Rectangle {
            anchors.fill: parent
            color: "#4D000000"
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            backButtonClicked()
        }
        objectName: "YBackButtonPage.qml_" + parent.objectName

        YDownloadManagerButton {
            id: id_download_manager_button
            function enterPage() {
                qmlGlobal.reinitAudiosDownloadManager()
                id_pop_layer.show("audiopages/YDownloadAudiosManager")
            }
            onValidClicked: {
                enterPage()
            }
        }

    }

    YPopLayer {
        id: id_pop_layer
    }

    Component.onDestruction: {
        console.log("YAudioPage.qml===Component.onDestruction===called")
    }

    Connections {
        target: qmlGlobal
        onQuicklyEnterYDListening: {
            id_yd_listening_button.enterPage()
        }
        onQuicklyEnterAudiosDownloadManager: {
            id_download_manager_button.enterPage()
        }
        onReinitYDListening: {
            columnManager.wipeData()
            columnManager.loadMore(false, columnManager.domainNameYdListen)
        }
        onReinitAudiosDownloadManager: {
            columnManager.wipeData()
            let domains = [columnManager.domainNameYdListen]
            domains.push(columnManager.domainNameMyProduction)
            columnManager.loadMore(true, domains.join(","))
        }
    }
}
