import QtQuick 2.12

import "../commons"
import "../components"

YSettingAboutClickableItem {
    id: id_my_production_search_result_view_item
    implicitHeight: 50

    property int downloadState: 0 //todo model.modelData.downloadState
    property int progress: 0 //todo model.modelData.progress

    iconComponent.visible: false
    
    YYoudaoAudioPageColumnViewItemStatus {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        downloadState: id_my_production_search_result_view_item.downloadState
        progress: id_my_production_search_result_view_item.progress
        isAuthorized: true
    }

    titlePixelSize: 16
    valuePixelSize: 14
}
