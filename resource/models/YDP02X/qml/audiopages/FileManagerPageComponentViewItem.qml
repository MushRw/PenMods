import QtQuick 2.12
import QtGraphicalEffects 1.14
import com.youdao.pen 1.0

import "../commons"
import "../components"

YSettingAboutClickableItem {
    id: id_filemgr_page_component_view_item

    readonly property bool isDir: model.isDir

    YImage {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        asynchronous: true
        source: model.extIcon
    }

    valueRightMargin: 10
    titleLeftMargin: 43

    titlePixelSize: 16
    valuePixelSize: 14
}
