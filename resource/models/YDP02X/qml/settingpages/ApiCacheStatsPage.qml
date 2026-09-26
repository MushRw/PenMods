import QtQuick 2.12
import com.github.penuniverse 1.0

import "../commons"
import "../components"

YBackButtonPage {
    id: root
    objectName: "YPage===ApiCacheStatsPage.qml"

    function rateText(rate) {
        return Number(rate || 0).toFixed(1) + "%";
    }

    function tokenText(cached, total) {
        if (!total || total <= 0)
            return "暂无数据";
        return "命中 " + cached + " / 输入 " + total + " tokens";
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: contentColumn.height + 16
        clip: true

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 7

            YSettingItemTitle {
                title: "API 缓存统计"
            }

            DescribedClickableTextBox {
                title: "最近一次 · " + root.rateText(chatbot.apiCacheStats.lastRate)
                describe: root.tokenText(chatbot.apiCacheStats.lastCachedTokens,
                                         chatbot.apiCacheStats.lastInputTokens)
                describeItem.width: width - 20
                describeItem.font.pixelSize: 12
                opacityChangableWhenPressed: false
            }

            DescribedClickableTextBox {
                title: "本次运行累计 · " + root.rateText(chatbot.apiCacheStats.totalRate)
                describe: root.tokenText(chatbot.apiCacheStats.totalCachedTokens,
                                         chatbot.apiCacheStats.totalInputTokens)
                describeItem.width: width - 20
                describeItem.font.pixelSize: 12
                opacityChangableWhenPressed: false
            }

            YSettingAboutClickableItem {
                title: "清零统计"
                value: String(chatbot.apiCacheStats.sampleCount || 0) + " 个样本"
                imageName: "settings/info_more_arrow"
                onClicked: chatbot.resetApiCacheStats()
            }
        }
    }
}
