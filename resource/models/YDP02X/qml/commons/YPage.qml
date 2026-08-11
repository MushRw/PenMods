import QtQuick 2.12
import com.youdao.pen 1.0

import "../utils"

YPopItem {
    id: id_ypage_root
    anchors.fill: parent
    objectName: "YPage.qml_YMouseArea"

    signal backButtonClicked

    property int pageIndex: -1
    property bool animationEnabled: true
    property bool destroyOnBack: true
    property bool indexPageShowAnimationRunning: false

    readonly property bool animationRunning: false

    function show() {
        id_private_data.state = "show";
        visible = true;
    }

    function close() {
        todoDestroy();
    }

    function syncCurrentPageIndex() {
        if (visible && pageIndex >= 0 && qmlGlobal.currentPageIndex !== pageIndex) {
            qmlGlobal.currentPageIndex = pageIndex;
        }
    }

    function todoDestroy() {
        id_private_data.state = "close";
        id_private_data.todoDestroy();
        visible = false;
    }

    onBackButtonClicked: {
        console.warn("YPage.qml===backButtonClicked===objectName: ", objectName);
        YUtils.beginPopRequest();
        close();
        if (typeof id_ypage_root.popId != "undefined") {
            YUtils.removeKey(id_ypage_root.popId);
        }
    }

    YBackground {
        id: id_private_data
        anchors.fill: parent
        state: "close"

        function todoDestroy() {
            if (destroyOnBack && ("close" === state)) {
                id_ypage_root.visible = false;
                id_ypage_root.destroy(1);
                console.warn("YPage.qml===destroy===called");
            }
        }
    }

    Connections {
        target: id_ypage_root

        function onVisibleChanged() {
            id_ypage_root.syncCurrentPageIndex();
        }

        function onPageIndexChanged() {
            id_ypage_root.syncCurrentPageIndex();
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        enabled: id_ypage_root.visible
        function onClosePageWhileHomeKeyReleased() {
            console.log("YPage.qml===onClosePageWhileHomeKeyReleased===");
            backButtonClicked();
        }
    }

    Component.onDestruction: {
        if (typeof id_ypage_root.popId === "undefined") {
            return;
        }

        const key = id_ypage_root.popId;
        if ((null !== YUtils.stackMap) && (YUtils.stackMap.value(key) === id_ypage_root)) {
            YUtils.removeKey(key);
        }
        if ((null !== YUtils.globalMap) && (YUtils.globalMap.value(key) === id_ypage_root)) {
            YUtils.globalMap.remove(key);
        }
    }
}
