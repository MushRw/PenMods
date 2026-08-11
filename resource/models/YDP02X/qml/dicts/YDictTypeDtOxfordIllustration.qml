import QtQuick 2.12

import "../commons"
import "./YDictOxfordUtilities.js" as OxfordUtilities
import "./YDictOxfordModel.js" as OxfordModel

Column {
    id: id_illObjList_column
    width: parent.width
    spacing: 10
    property var illObjList: []

    Repeater {
        model: illObjList

        Column {
            width: id_illObjList_column.width
            spacing: 8
            readonly property var illObj: model.modelData.value

            YTextMedium {
                width: parent.width
                height: contentHeight
                font.family: qmlGlobal.fontFamilyEnUs
                wrapMode: YTextBase.Wrap
                textFormat: YTextBase.RichText
                text: {
                    if (typeof illObj.title == "undefined" || typeof illObj.title.titled == "undefined") {
                        return ""
                    }
                    return OxfordUtilities.illTitleToFormatted(illObj.title.titled, qmlGlobal.fontFamilyZhCn)
                }
                visible: text.length > 0
            }

            YDictTypeDtOxfordIllustrationParaList {
                width: parent.width
                paraObjList: {
                    if (typeof illObj.para == "object") {
                        if (OxfordUtilities.isArrayFn(illObj.para)) {
                            return illObj.para
                        } else {
                            return [illObj.para]
                        }
                    } else {
                        return []
                    }
                }
            }
        }
    }
}
