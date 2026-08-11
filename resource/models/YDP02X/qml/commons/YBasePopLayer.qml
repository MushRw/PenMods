import QtQuick 2.12

import "../utils"

QtObject {
    id: id_pop_layer_qml

    property string state: "close"

    readonly property bool isShowing: (null !== popItemObject) && (typeof popItemObject.popId !== "undefined") && (YUtils.currentPopId === popItemObject.popId)
    readonly property QtObject cachePagesMap: YUtils.globalMap
    readonly property QtObject stackPagesMap: YUtils.stackMap
    readonly property string popIdPrefix: "YPopItem_Id_"
    readonly property int count: null !== stackPagesMap ? stackPagesMap.count() : 0

    property var popItemObject: null

    function cachePagesCount() {
        return null !== cachePagesMap ? cachePagesMap.size() : 0;
    }

    function hasCachePage() {
        return cachePagesCount() > 0;
    }

    function showAnimation() {
        state = "show";
    }

    function closeAnimation() {
        state = "close";
    }

    function qmlCreateComponent(qmlName) {
        return Qt.createComponent(("qrc:/qml/%1.qml").arg(qmlName));
    }

    function pop() {
        if ((null === stackPagesMap) || stackPagesMap.isEmpty()) {
            return null;
        }

        const topKey = stackPagesMap.topKey();
        const item = stackPagesMap.value(topKey);
        if (!item) {
            YUtils.removeKey(topKey);
            return null;
        }

        if (item.hasOwnProperty("backButtonClicked")) {
            item.backButtonClicked();
        } else {
            YUtils.removeKey(topKey);
            if (typeof item.destroy === "function") {
                item.destroy(1);
            }
        }
        return item;
    }
}
