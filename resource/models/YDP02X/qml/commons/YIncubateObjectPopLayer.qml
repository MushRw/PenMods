import QtQuick 2.12

YBackgroundIgnoreMouseEvent {
    id: id_pop_layer_qml
    anchors.fill: parent
    visible: "close" !== state
    enabled: "close" !== state
    state: "close"

    readonly property bool isShowing: ("show" === state)

    property var popItemObject: null

    function showAnimation() {
        state = "show"
        visible = true
    }

    function closeAnimation() {
        state = "close"
        visible = false
    }

    onIsShowingChanged: {
        if (!isShowing) {
            if (null !== popItemObject) {
                if (popItemObject.hasOwnProperty("destroyOnBack")
                        && !popItemObject.destroyOnBack) {
                    console.log("YBasePopLayer.qml===destroy===not need called")
                    popItemObject.visible = false
                    return
                }
                console.log("YBasePopLayer.qml===destroy===will be called")
                popItemObject.visible = false
                popItemObject.destroy(1)
                popItemObject = null
            }
        }
    }

    function quickShow(qrcqml, callback) {
        show(qrcqml, true, false, callback)
    }

    function show(qrcqml, animationEnabled, cachePage, callback, isShow) {
        console.log("YIncubateObjectPopLayer.qml===qrcqml: ", qrcqml,
                    "===animationEnabled: ", animationEnabled,
                    "===cachePage: ", cachePage)
        let component = qmlCreateComponent(qrcqml)
        let incubator = component.incubateObject(id_pop_layer_qml);
        if (incubator.status !== Component.Ready) {
            incubator.onStatusChanged = function(status) {
                if (status === Component.Ready) {
                    __incubatorObjectReady(incubator.object, isShow)
                    callback(incubator.object)
                    console.log("YIncubateObjectPopLayer===", incubator.object, "is now ready!");
                }
            }
        } else {
            __incubatorObjectReady(incubator.object, isShow)
            callback(incubator.object)
            console.log("YIncubateObjectPopLayer===", incubator.object, "is ready immediately!");
        }
    }

    function backendCreate(qrcqml, callback) {
        show(qrcqml, true, false, callback, false)
    }

    function __incubatorObjectReady(incubatorObject, isShow) {
        popItemObject = incubatorObject
        console.log("YIncubateObjectPopLayer.qml===popItemObject: ", popItemObject)
        if (typeof cachePage != "undefined") {
            if (popItemObject.hasOwnProperty("destroyOnBack")) {
                popItemObject.destroyOnBack = !cachePage
            }
        }

        if (popItemObject.hasOwnProperty("backButtonClicked")) {
            popItemObject.backButtonClicked.connect(function(){
                id_pop_layer_qml.close()
                if (popItemObject.hasOwnProperty("todoDestroy")) {
                    popItemObject.todoDestroy()
                }
            })
        }

        if (typeof isShow == "undefined" || isShow) {
            delayShow()
        }
    }

    function delayShow() {
        popItemObject.visible = true
        state = "show"
        visible = true
        showAnimation()
    }

    function close() {
        state = "close"
        closeAnimation()
        console.log("YIncubateObjectPopLayer.qml===close===called")
    }

}
