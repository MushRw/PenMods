import QtQuick 2.12

import "../commons"

YPage {

    default property alias content: id_content.data
    readonly property alias confirmDefaultLayer: id_confirm_default_layer
    readonly property alias myproductionfilterlayer: id_my_production_page_filter_layer

    Item {
        id: id_content
        anchors.fill: parent
    }

    YMyProductionPageDefaultDrawerLayer {
        id: id_confirm_default_layer
        visible: false
    }

    YMyProductionPageFilterDrawerLayer {
        id: id_my_production_page_filter_layer
        visible: false
    }

    Connections {
        target: mediaManager
        ignoreUnknownSignals: true
        enabled: id_content.visible

        onScanningSearchFound : {
            console.log("YMyProductionPageComponent.qml===getScanningSearchResults ")
            let list = mediaManager.getScanningSearchResults()
            if (list.length > 1) {
                id_my_production_page_filter_layer.updateModel()
                id_my_production_page_filter_layer.show()
            } else if (list.length == 1){
                id_my_production_page_filter_layer.hide()
                id_my_production_page_filter_layer.playAudio(list[0].columnId, list[0].id)
            }
        }
    }
}
