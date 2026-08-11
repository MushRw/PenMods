import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YOneButtonDialog {
    id: id_real_time_display
    anchors.fill: parent

    tipItem.lineHeightMode: Text.FixedHeight
    tipItem.lineHeight: 26
    tipItem.text: YTranslateText.clearHistoryTip
    buttonItem.text: YTranslateText.clearHistory

    onClicked: {
        historyManager.removeAll()
        close()
    }
}
