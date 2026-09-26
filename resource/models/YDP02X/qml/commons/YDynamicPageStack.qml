import QtQuick 2.12

Item {
    id: root

    property string logTag: "YDynamicPageStack"
    property var popItemObject: null
    property int count: 0
    property int pendingCount: 0
    property var _pageStack: []
    property var _activeObjects: ({})
    property var _connectionCleanups: ({})
    property var _pendingCreates: ({})
    // 保活缓存：声明 destroyOnBack === false 的页面关闭时不销毁，只隐藏；
    // 同一个 popStackId 再次打开时复用同一个实例（插件后台逻辑不能重启，
    // 否则会出现两份 runner）。见 docs/plugin-keepalive.md。
    property var _keptAlive: ({})
    property var _keptComponents: ({})
    property var _keptAliveAt: ({})
    // 宿主指定要保活的 popStackId（options.keepAlive）。
    // 刻意**不**往页面对象上写属性：QML 的 QObject 型对象不可扩展，
    // `obj.destroyOnBack = false` 会抛 "Cannot assign to non-existent property"，
    // 页面就再也打不开了（实测踩过）。所以标记放在栈里，按 id 记。
    property var _keepAliveIds: ({})
    // 保活超时：隐藏超过这么久就主动回收（0 = 不超时）。
    // 460MB 的设备上不能让插件页面无限期常驻 —— 当前 20 秒（便于测量；
    // 稳定后可调回 60~180 秒，或改成"内存吃紧时回收"）。
    property int keepAliveTimeoutMs: 180000

    signal closeSameItem(string popStackId)

    function updateStackInfo() {
        count = _pageStack.length
        popItemObject = _pageStack.length > 0
                ? _pageStack[_pageStack.length - 1] : null
    }

    function _updatePendingCount() {
        pendingCount = Object.keys(_pendingCreates).length
    }

    function _isCurrentPending(popStackId, pending) {
        return !pending.cancelled && _pendingCreates[popStackId] === pending
    }

    function _finishPending(popStackId, pending) {
        if (_pendingCreates[popStackId] !== pending)
            return false

        delete _pendingCreates[popStackId]
        _updatePendingCount()
        return true
    }

    function _destroyPendingComponent(pending) {
        if (!pending.component)
            return

        const component = pending.component
        pending.component = null
        try {
            component.destroy()
        } catch (error) {
            console.warn(logTag + " component cleanup failed:", error)
        }
    }

    function _discardPendingObject(pending, incubatorObject) {
        if (incubatorObject) {
            try {
                if (incubatorObject.hasOwnProperty("visible"))
                    incubatorObject.visible = false
                incubatorObject.destroy(1)
            } catch (error) {
                console.warn(logTag + " stale page cleanup failed:", error)
            }
        }
        _destroyPendingComponent(pending)
    }

    function _cancelPending(popStackId) {
        const pending = _pendingCreates[popStackId]
        if (!pending)
            return

        delete _pendingCreates[popStackId]
        pending.cancelled = true
        _updatePendingCount()

        if (pending.componentStatusCallback && pending.component) {
            try {
                pending.component.statusChanged.disconnect(
                            pending.componentStatusCallback)
            } catch (error) {}
            pending.componentStatusCallback = null
        }

        // An active incubator must finish before its Component can be released.
        if (!pending.incubator)
            _destroyPendingComponent(pending)
    }

    function _cleanupConnections(popStackId) {
        if (!_connectionCleanups.hasOwnProperty(popStackId))
            return

        const cleanups = _connectionCleanups[popStackId]
        delete _connectionCleanups[popStackId]
        for (let i = 0; i < cleanups.length; ++i) {
            try {
                cleanups[i]()
            } catch (error) {
                console.warn(logTag + " cleanup failed:", error)
            }
        }
    }

    function _removeFromStack(incubatorObject) {
        const index = _pageStack.indexOf(incubatorObject)
        if (index >= 0)
            _pageStack.splice(index, 1)
    }

    function _releaseObject(incubatorObject, popStackId) {
        if (_activeObjects[popStackId] !== incubatorObject)
            return false

        delete _activeObjects[popStackId]
        _removeFromStack(incubatorObject)
        updateStackInfo()
        _cleanupConnections(popStackId)
        return true
    }

    function _safeDestroy(incubatorObject) {
        if (!incubatorObject)
            return

        const popStackId = incubatorObject.popStackId || ""

        // 保活页面：对象自己声明了 destroyOnBack === false，或宿主用 options.keepAlive 指定。
        // 只从可见栈里摘掉并隐藏，对象留着下次复用，这样插件后台逻辑不会被打断。
        if ((incubatorObject.destroyOnBack === false || _keepAliveIds[popStackId] === true)
                && popStackId !== "") {
            if (!_releaseObject(incubatorObject, popStackId))
                return
            try {
                incubatorObject.visible = false
                if (typeof incubatorObject.pageHidden === "function")
                    incubatorObject.pageHidden()
            } catch (error) {
                console.warn(logTag + " hide kept-alive page failed:", error)
            }
            _keptAlive[popStackId] = incubatorObject
            _keptAliveAt[popStackId] = Date.now()
            // 调试标记：QML 的 console.* 进不了 app 日志，所以落一个文件供外部核对
            if (typeof shell !== "undefined")
                shell.startDetached("echo KA_KEEP >> /tmp/ka.log")
            return
        }

        if (!_releaseObject(incubatorObject, popStackId))
            return

        try {
            incubatorObject.visible = false
            if (typeof shell !== "undefined")
                shell.startDetached("echo KA_DESTROY >> /tmp/ka.log")
            incubatorObject.destroy(1)
            // 让 C++ 侧做一次 malloc_trim：glibc 不会自己把销毁后的内存还给内核
            if (typeof pluginManager !== "undefined")
                pluginManager.trimMemory()
        } catch (error) {
            console.warn(logTag + " destroy failed:", error)
        }
    }

    // 主动回收保活页面（内存吃紧 / 插件被禁用时用）
    function releaseKeptAlive(popStackId) {
        const obj = _keptAlive[popStackId]
        if (!obj)
            return
        delete _keptAlive[popStackId]
        delete _keptAliveAt[popStackId]
        delete _keepAliveIds[popStackId]
        try {
            obj.visible = false
            if (typeof obj.pageHidden === "function")
                obj.pageHidden()
            obj.destroy(1)
        } catch (error) {
            console.warn(logTag + " release kept-alive failed:", error)
        }
        if (_keptComponents[popStackId]) {
            try {
                _keptComponents[popStackId].destroy()
            } catch (error) {}
            delete _keptComponents[popStackId]
        }
        // 回收完顺手让 C++ 整理一次堆（glibc 不会自己还给内核）
        if (typeof pluginManager !== "undefined")
            pluginManager.trimMemory()
    }

    function releaseAllKeptAlive() {
        const keys = Object.keys(_keptAlive)
        for (let i = 0; i < keys.length; ++i)
            releaseKeptAlive(keys[i])
    }

    // PL-07: 回收所有 popStackId 不在 validIds 里的保活页面。
    // 插件被禁用/卸载后，它的保活实例必须立刻回收（不能等超时定时器）——
    // 实例里的 QML 引用着插件的上下文属性，插件 .so 已卸载时这就是悬垂。
    // 用法：宿主把"仍然启用且已加载"的插件 mainQmlUrl 列表传进来。
    function releaseStaleKeptAlive(validIds) {
        const keys = Object.keys(_keptAlive)
        for (let i = 0; i < keys.length; ++i) {
            if (!validIds || validIds.indexOf(keys[i]) < 0)
                releaseKeptAlive(keys[i])
        }
    }

    function _registerObject(incubatorObject, popStackId, cleanups) {
        if (!incubatorObject || !popStackId)
            return false

        if (_activeObjects[popStackId]
                && _activeObjects[popStackId] !== incubatorObject) {
            _safeDestroy(_activeObjects[popStackId])
        }

        if (typeof incubatorObject.popStackId === "undefined") {
            Object.defineProperty(incubatorObject, "popStackId", {
                enumerable: false,
                configurable: false,
                writable: false,
                value: popStackId
            })
        }

        _activeObjects[popStackId] = incubatorObject
        _connectionCleanups[popStackId] = cleanups || []
        _pageStack.push(incubatorObject)
        updateStackInfo()

        incubatorObject.Component.destruction.connect(function() {
            _releaseObject(incubatorObject, popStackId)
        })
        return true
    }

    function registerPage(incubatorObject, popStackId, options) {
        if (!incubatorObject)
            return false

        const config = options || {}
        const cleanups = config.cleanups ? config.cleanups.slice() : []

        if (typeof config.pageIndex === "number" && config.pageIndex >= 0) {
            const onRequestShowPage = function(index, cachePage) {
                if (config.pageIndex !== index)
                    root._safeDestroy(incubatorObject)
            }
            qmlGlobal.requestShowPage.connect(onRequestShowPage)
            cleanups.push(function() {
                qmlGlobal.requestShowPage.disconnect(onRequestShowPage)
            })
        }

        if (incubatorObject.hasOwnProperty("backButtonClicked")) {
            const onBackButtonClicked = function() {
                root._safeDestroy(incubatorObject)
            }
            incubatorObject.backButtonClicked.connect(onBackButtonClicked)
            cleanups.push(function() {
                incubatorObject.backButtonClicked.disconnect(onBackButtonClicked)
            })
        }

        if (config.closeOnHomeRelease) {
            const onHomeKeyRelease = function() {
                root._safeDestroy(incubatorObject)
            }
            systemBase.homeKeyRelease.connect(onHomeKeyRelease)
            cleanups.push(function() {
                systemBase.homeKeyRelease.disconnect(onHomeKeyRelease)
            })
        }

        if (config.closeOnHomeLongPress) {
            const onHomeKeyLongPress = function() {
                root._safeDestroy(incubatorObject)
            }
            systemBase.homeKeyLongPress.connect(onHomeKeyLongPress)
            cleanups.push(function() {
                systemBase.homeKeyLongPress.disconnect(onHomeKeyLongPress)
            })
        }

        if (config.component) {
            cleanups.push(function() {
                config.component.destroy()
            })
        }

        return _registerObject(incubatorObject, popStackId, cleanups)
    }

    function createPage(componentUrl, popStackId, options, properties, onReady) {
        closeSameItem(popStackId)

        // 复用保活实例：同一个 popStackId 之前被保活过就直接拿出来用，不再 createComponent。
        // 插件重入必须是同一个实例，否则会起两份后台逻辑（例如 lx-pen 会起两个 runner）。
        const keptObject = _keptAlive[popStackId]
        if (keptObject) {
            delete _keptAlive[popStackId]
            delete _keptAliveAt[popStackId]
            if (typeof shell !== "undefined")
                shell.startDetached("echo KA_REUSE >> /tmp/ka.log")
            const keptConfig = {}
            const keptOptions = options || {}
            Object.keys(keptOptions).forEach(function(key) {
                keptConfig[key] = keptOptions[key]
            })
            // 注意：这里刻意不传 component —— 保活页面的 Component 由 _keptComponents 持有，
            // 否则 registerPage 的清理函数会在页面隐藏时把它一起销毁，下次就复用不了了。
            keptConfig.component = null

            if (!registerPage(keptObject, popStackId, keptConfig)) {
                releaseKeptAlive(popStackId)
                return null
            }

            if (typeof keptObject.pageShown === "function")
                keptObject.pageShown()
            if (typeof keptObject.show === "function")
                keptObject.show()
            else if (keptObject.hasOwnProperty("visible"))
                keptObject.visible = true

            if (typeof onReady === "function")
                onReady(keptObject)
            return keptObject
        }

        const component = Qt.createComponent(componentUrl)
        const pending = {
            "cancelled": false,
            "component": component,
            "componentStatusCallback": null,
            "incubator": null
        }
        _pendingCreates[popStackId] = pending
        _updatePendingCount()

        function initializePage(incubatorObject) {
            if (!_isCurrentPending(popStackId, pending)) {
                _discardPendingObject(pending, incubatorObject)
                return null
            }

            _finishPending(popStackId, pending)
            if (!incubatorObject) {
                _destroyPendingComponent(pending)
                return null
            }

            const config = {}
            const sourceOptions = options || {}
            Object.keys(sourceOptions).forEach(function(key) {
                config[key] = sourceOptions[key]
            })

            // 宿主指定的保活页面（options.keepAlive）：只记在栈里，**不碰页面对象**。
            // Component 由 _keptComponents 持有，所以不走 registerPage 里那条销毁 component 的清理。
            if (sourceOptions.keepAlive === true) {
                _keepAliveIds[popStackId] = true
                _keptComponents[popStackId] = component
                config.component = null
            } else {
                delete _keepAliveIds[popStackId]
                config.component = component
            }

            if (!registerPage(incubatorObject, popStackId, config)) {
                incubatorObject.destroy(1)
                _destroyPendingComponent(pending)
                return null
            }

            if (typeof incubatorObject.show === "function")
                incubatorObject.show()
            else if (incubatorObject.hasOwnProperty("visible"))
                incubatorObject.visible = true

            if (typeof onReady === "function")
                onReady(incubatorObject)
            return incubatorObject
        }

        function incubatePage() {
            if (!_isCurrentPending(popStackId, pending))
                return null

            const incubator = component.incubateObject(root, properties || {})
            pending.incubator = incubator
            if (incubator.status === Component.Ready)
                return initializePage(incubator.object)
            if (incubator.status === Component.Error) {
                _finishPending(popStackId, pending)
                _destroyPendingComponent(pending)
                return null
            }

            incubator.onStatusChanged = function(status) {
                if (status === Component.Ready)
                    initializePage(incubator.object)
                else if (status === Component.Error) {
                    _finishPending(popStackId, pending)
                    _destroyPendingComponent(pending)
                }
            }
            return null
        }

        if (component.status === Component.Ready)
            return incubatePage()

        if (component.status === Component.Loading) {
            const onComponentStatusChanged = function() {
                if (component.status === Component.Loading)
                    return

                component.statusChanged.disconnect(onComponentStatusChanged)
                pending.componentStatusCallback = null
                if (!_isCurrentPending(popStackId, pending)) {
                    _destroyPendingComponent(pending)
                    return
                }

                if (component.status === Component.Ready)
                    incubatePage()
                else {
                    console.error(logTag + " component error:",
                                  component.errorString())
                    _finishPending(popStackId, pending)
                    _destroyPendingComponent(pending)
                }
            }
            pending.componentStatusCallback = onComponentStatusChanged
            component.statusChanged.connect(onComponentStatusChanged)
            return null
        }

        console.error(logTag + " component error:", component.errorString())
        _finishPending(popStackId, pending)
        _destroyPendingComponent(pending)
        return null
    }

    function closeCurrentPage() {
        _safeDestroy(popItemObject)
    }

    function closeAllPages() {
        const pendingKeys = Object.keys(_pendingCreates)
        for (let pendingIndex = 0; pendingIndex < pendingKeys.length;
             ++pendingIndex) {
            _cancelPending(pendingKeys[pendingIndex])
        }

        const pages = _pageStack.slice()
        for (let i = pages.length - 1; i >= 0; --i)
            _safeDestroy(pages[i])
    }

    onCloseSameItem: {
        _cancelPending(popStackId)
        _safeDestroy(_activeObjects[popStackId])
    }

    // 保活超时回收：每 5 秒扫一次（跟 keepAliveTimeoutMs 配合，便于快速观测），
    // 隐藏超过 keepAliveTimeoutMs 的页面主动释放，避免插件页面在 460MB 的设备上无限期常驻。
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (root.keepAliveTimeoutMs <= 0)
                return
            const now = Date.now()
            const keys = Object.keys(root._keptAlive)
            for (let i = 0; i < keys.length; ++i) {
                const id = keys[i]
                const at = root._keptAliveAt[id] || 0
                if (now - at > root.keepAliveTimeoutMs) {
                    if (typeof shell !== "undefined")
                        shell.startDetached("echo KA_RELEASE >> /tmp/ka.log")
                    root.releaseKeptAlive(id)
                }
            }
        }
    }
}
