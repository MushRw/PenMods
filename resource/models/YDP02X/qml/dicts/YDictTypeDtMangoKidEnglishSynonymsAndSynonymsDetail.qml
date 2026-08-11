import QtQuick 2.12

import "../commons"
import "../i18n"
import "../components"

Column {
    id:id_synonymsAndSynonyms
    width: id_dict_content_column.width
    property var idDictPageObject
    spacing: 10
    function showPage(qrcqml, cachePage, properties) {
        if ((typeof cachePage !== undefined) && cachePage) {
            return id_page_pop_helper.cacheShow(qrcqml, false, properties)
        }
        return id_page_pop_helper.show(qrcqml, false, false, properties)
    }
    Repeater {
        id: id_synonymsAndSynonyms_repeater
        model: dictJson
        Item {
            id: id_synonymsAndSynonyms_item
            width: parent.width
            height: id_synonymsAndSynonyms_pos_txt.contentHeight+id_synonyms_flow.height

            readonly property var modelModelData: model.modelData
            YTextBase {
                id: id_synonymsAndSynonyms_pos_txt
                font.pixelSize: 18
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.white
                text: ('<span style="font-family:%1; font-style:italic; color:%2;">').arg(qmlGlobal.fontFamilyClass).arg(YColors.grayText)
                      + id_synonymsAndSynonyms_item.modelModelData.pos + '</span> ' + model.modelData.meaning
                width: 244
                wrapMode: YTextBase.Wrap
                textFormat: YText.RichText
                height: id_synonymsAndSynonyms_pos_txt.contentHeight
            }

            Flow{
                id:id_synonyms_flow

                width: 244
                anchors.top: id_synonymsAndSynonyms_pos_txt.bottom
                spacing:0
                Repeater{
                    id:id_synonyms_repeter
                    model:id_synonymsAndSynonyms_item.modelModelData.synonyms

                    YDictPageClickSearchTextItem{
                        word: model.modelData
                        isCHType: false
                        onClicked: {
                            qmlGlobal.queryFromDictPage(model.modelData, "en", "zh-CHS")
                        }
                    }
                }
            }
        }
    }
}
