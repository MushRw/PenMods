import QtQuick 2.12

import "../commons"
import "../i18n"

Column {
    width: id_dict_content_column.width
    spacing: 10
    Repeater {
        id: id_fixed_collocation_repeater
        model: dictJson
        Item {
            id: id_fixed_Collocation_item
            width: parent.width
            height: id_fixed_collocation_key.contentHeight+id_fixed_collocation_value.contentHeight
            readonly property var modelModelData: model.modelData
            YTextBase {
                id: id_fixed_collocation_key
                width: 244
                height: contentHeight
                font.pixelSize: 18
                font.family: qmlGlobal.fontFamilyEnUs
                color: YColors.white
                font.bold: true
                wrapMode: Text.WordWrap
                text: model.modelData.phrase
            }
            YTextBase {
                id: id_fixed_collocation_value
                width: 244
                height: contentHeight
                font.pixelSize: 18
                anchors.top: id_fixed_collocation_key.bottom
                anchors.topMargin: 4
                font.family: qmlGlobal.fontFamilyZhCn
                color: YColors.grayText
                wrapMode: Text.WordWrap
                text: model.modelData.meanings[0]
            }
        }
    }
}
