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
        anchors.rightMargin: 10
        // 内容整体右移 54，等价于原来的 leftMargin: 54，
        // 但列表本身铺满整宽，滚动时内容会从左侧毛玻璃栏底下滑过去（取景才对得上）
        contentWidth: 54 + id_button_row.width

        Row {
            id: id_button_row
            x: 54
            topPadding: 10
            bottomPadding: 10
            spacing: 8

            YAudioPageDomainButton {
                id: id_my_imports_button
                visible: !antiEmbs.active
                name: "文件管理"
                count: "Beta"
                imageName: "audiopage/my_imports"

                onValidClicked: {
                    id_pop_layer.show("audiopages/FileManagerPage")
                }
            }

            // 插件管理：从首页搬到这里，沿用首页那张图标
            // 合并上游（antiembs）：防嵌入模式激活时隐藏敏感入口
            YAudioPageDomainButton {
                id: id_plugin_manager_button
                name: "插件管理"
                count: ""
                imageName: "qrc:/images/home/home-plugin.png"
                visible: typeof antiEmbs !== "undefined" ? !antiEmbs.active : true

                onValidClicked: {
                    id_pop_layer.show("PluginManager")
                }
            }

            // 有道听力：按需求去掉入口（隐藏并让位置布局不再占位）
            YAudioPageDomainButton {
                id: id_yd_listening_button
                name: YTranslateText.ydListening
                count: columnManager.listeningCount + YTranslateText.pieces
                imageName: "audiopage/yd_listening"
                visible: false
                height: 0

                function enterPage() {
                    qmlGlobal.reinitYDListening()
                    id_pop_layer.show("audiopages/YYoudaoAudioPage")
                }

                onValidClicked: {
                    enterPage()
                }
            }

            // 扫读音频：按需求去掉入口
            YAudioPageDomainButton {
                id: id_scan_reading_button
                name: YTranslateText.myProductionAudios
                count: columnManager.productionCount + YTranslateText.pieces
                imageName: "audiopage/scan_audio"
                visible: false
                height: 0

                onValidClicked: {
                    logManager.sendHttpLog("action=listening_make_click")
                    columnManager.loadMore(true, columnManager.domainNameMyProduction)
                    id_pop_layer.show("audiopages/YMyProductionPage")
                }
            }

        }
    }

    // 听力练习左侧栏：统一走 commons/YFastBlurRectangle
    // （原来是自己搭 ShaderEffectSource + FastBlur + 半透明矩形，且取景框写成 x-54 取到屏外）
    YFastBlurRectangle {
        id: id_effect_item
        implicitWidth: 54
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        backdrop: id_container
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
