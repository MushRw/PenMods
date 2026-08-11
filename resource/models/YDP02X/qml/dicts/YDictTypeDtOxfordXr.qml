import QtQuick 2.12

import "../commons"
import "./YDictOxfordUtilities.js" as OxfordUtilities
import "./YDictOxfordModel.js" as OxfordModel

Column {
    id: id_word_header_xr_column
    width: componentWidth
    spacing: 4

    Repeater {
        id: id_word_header_Xr_text_repeater
        model: typeof xrObj != "object" ? null : OxfordUtilities.xrToFormatted(xrObj, wordText)

        YTextMedium {
            font.family: qmlGlobal.fontFamilyEnUs
            color: YColors.grayText
            textFormat: YTextBase.RichText
            wrapMode: YTextBase.WordWrap
            width: id_word_header_xr_column.width
            text: model.modelData
        }
    }
}
