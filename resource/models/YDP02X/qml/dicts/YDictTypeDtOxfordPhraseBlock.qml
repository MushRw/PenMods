import QtQuick 2.12

import "../commons"
import "./YDictOxfordUtilities.js" as OxfordUtilities
import "./YDictOxfordModel.js" as OxfordModel

Column {
    id: id_word_phraseblock_column
    width: parent.width
    spacing: 10
    property string qsPos: ""
    property var phraseObjList: []

    Repeater {
        model: phraseObjList

        Item {
            id: id_phraseObj_item
            width: id_word_phraseblock_column.width
            height: id_phraseObj_content_column.height
            readonly property var phraseObj: model.modelData

            YText {
                id: id_phraseObj_index
                width: 28
                topPadding: 4
                height: id_phraseObj_content_column.height
                anchors.left: parent.left
                font.family: qmlGlobal.fontFamilyZhCn
                font.pixelSize: 16
                color: YColors.grayText
                text: "%1.".arg(index + 1)
            }

            Column {
                id: id_phraseObj_content_column
                anchors.left: id_phraseObj_index.right
                anchors.right: parent.right
                spacing: 4

                YText {
                    width: parent.width
                    height: contentHeight
                    font.family: qmlGlobal.fontFamilyEnUs
                    wrapMode: YTextBase.Wrap
                    textFormat: YTextBase.RichText
                    color: YColors.grayText
                    text: {
                        var vFormattedText = ""
                        if (typeof id_phraseObj_item.phraseObj != "object") {
                            return vFormattedText
                        }
                        var vFormatted = ""
                        var qsPh = ""
                        if (OxfordUtilities.isArrayFn(id_phraseObj_item.phraseObj.pv)) {
                            id_phraseObj_item.phraseObj.pv.forEach(function(qsPhTmp){
                                if (qsPh.length > 0) {
                                    qsPh += " | "
                                }
                                qsPh += qsPhTmp
                            })
                        }
                        if (qsPh.length > 0) {
                            vFormatted += OxfordUtilities.formatText(OxfordUtilities.htmlToFormatted(qsPh), "#FFFFFF", 500)
                            vFormatted += "&nbsp;&nbsp;"
                        }
                        vFormatted += OxfordUtilities.grToFormatted(id_phraseObj_item.phraseObj)
                        if (OxfordUtilities.isArrayFn(id_phraseObj_item.phraseObj["vs-g"])) {
                            vFormatted += OxfordUtilities.vsgToFormatted(id_phraseObj_item.phraseObj["vs-g"])
                        }
                        if (typeof id_phraseObj_item.phraseObj.mixStr == "string") {
                            vFormatted += OxfordUtilities.htmlToFormatted(d_phraseObj_item.phraseObj.mixStr)
                        }
                        console.log("YDictTypeDtOxfordPhraseBlock.qml === phraseObj.pv: ", vFormatted)
                        return vFormatted
                    }
                    visible: text.length >= 0
                }

                YDictTypeDtOxfordIdiomNg {
                    width: id_phraseObj_content_column.width
                    ngObjList: OxfordUtilities.isArrayFn(id_phraseObj_item.phraseObj["n-g"]) ? id_phraseObj_item.phraseObj["n-g"] : []
                    qsPosCur: id_word_phraseblock_column.qsPos
                }
            }
        }
    }
}
