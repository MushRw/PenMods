import QtQuick 2.12

import "../utils"

// Global page stack for components derived from YPage.
YBasePopLayer {
    id: root

    property var _pendingRequest: null
    property var _connectedItem: null
    property var _backCallback: null
    property var _destructionCallback: null

    function _propertiesFromArguments(propertiesOrCache, legacyProperties) {
        if ((typeof legacyProperties === "object") && (null !== legacyProperties)) {
            return legacyProperties;
        }
        if ((typeof propertiesOrCache === "object") && (null !== propertiesOrCache)) {
            return propertiesOrCache;
        }
        return ({});
    }

    function _cacheFromArguments(propertiesOrCache) {
        return (typeof propertiesOrCache === "boolean") && propertiesOrCache;
    }

    function _applyProperties(item, properties) {
        if (!item || (typeof properties !== "object") || !properties) {
            return;
        }

        Object.keys(properties).forEach(function (key) {
            try {
                item[key] = properties[key];
            } catch (error) {
                console.warn("YPopLayer property update failed:", key, error);
            }
        });
    }

    function _disconnectItemCallbacks() {
        if (!_connectedItem) {
            return;
        }

        if (_backCallback && _connectedItem.hasOwnProperty("backButtonClicked")) {
            try {
                _connectedItem.backButtonClicked.disconnect(_backCallback);
            } catch (error) {}
        }
        if (_destructionCallback) {
            try {
                _connectedItem.Component.destruction.disconnect(_destructionCallback);
            } catch (error) {}
        }

        _connectedItem = null;
        _backCallback = null;
        _destructionCallback = null;
    }

    function _connectItemCallbacks(item) {
        if (_connectedItem === item) {
            return;
        }

        _disconnectItemCallbacks();
        _connectedItem = item;

        if (item.hasOwnProperty("backButtonClicked")) {
            _backCallback = function () {
                if (root.popItemObject === item) {
                    root.popItemObject = null;
                    root.closeAnimation();
                }
            };
            item.backButtonClicked.connect(_backCallback);
        }

        _destructionCallback = function () {
            if (root.popItemObject === item) {
                root.popItemObject = null;
                root.closeAnimation();
            }
            if (root._connectedItem === item) {
                root._connectedItem = null;
                root._backCallback = null;
                root._destructionCallback = null;
            }
        };
        item.Component.destruction.connect(_destructionCallback);
    }

    function _activate(popIdValue, item, animationEnabled, properties) {
        if (!item) {
            return null;
        }

        _applyProperties(item, properties);
        if (item.hasOwnProperty("animationEnabled")) {
            item.animationEnabled = animationEnabled !== false;
        }

        if (stackPagesMap.containsKey(popIdValue)) {
            stackPagesMap.top(popIdValue);
        } else {
            stackPagesMap.put(popIdValue, item);
        }

        popItemObject = item;
        _connectItemCallbacks(item);
        YUtils.currentPopId = popIdValue;
        showAnimation();

        if (typeof item.show === "function") {
            item.show();
        } else if (item.hasOwnProperty("visible")) {
            item.visible = true;
        }
        return item;
    }

    function _destroyComponent(component) {
        if (!component) {
            return;
        }
        try {
            component.destroy();
        } catch (error) {
            console.warn("YPopLayer component cleanup failed:", error);
        }
    }

    function _cancelPendingRequest() {
        const pending = _pendingRequest;
        if (!pending) {
            return;
        }

        _pendingRequest = null;
        pending.cancelled = true;
        if (pending.statusCallback) {
            try {
                pending.component.statusChanged.disconnect(pending.statusCallback);
            } catch (error) {}
            pending.statusCallback = null;
        }
        _destroyComponent(pending.component);
        pending.component = null;
    }

    function _isPendingCurrent(pending) {
        return !pending.cancelled && (_pendingRequest === pending) && YUtils.isCurrentPopRequest(pending.sequence);
    }

    function _finishPending(pending) {
        if (_pendingRequest === pending) {
            _pendingRequest = null;
        }
    }

    function _createReadyPage(pending) {
        if (!_isPendingCurrent(pending)) {
            _finishPending(pending);
            _destroyComponent(pending.component);
            pending.component = null;
            return null;
        }

        const component = pending.component;
        const item = component.createObject(YUtils.stackView, pending.properties);
        _finishPending(pending);
        if (!item) {
            console.error("YPopLayer failed to create page:", pending.qmlName, component.errorString());
            _destroyComponent(component);
            pending.component = null;
            return null;
        }

        Object.defineProperty(item, "popId", {
            enumerable: false,
            configurable: false,
            writable: false,
            value: pending.popId
        });
        if (pending.cachePage) {
            if (item.hasOwnProperty("destroyOnBack")) {
                item.destroyOnBack = false;
            }
            cachePagesMap.put(pending.popId, item);
        }

        const result = _activate(pending.popId, item, pending.animationEnabled, pending.properties);
        _destroyComponent(component);
        pending.component = null;
        return result;
    }

    function _show(qrcqml, animationEnabled, cachePage, properties) {
        if ((typeof qrcqml !== "string") || (qrcqml.length < 1) || (null === stackPagesMap) || (null === YUtils.stackView) || (cachePage && (null === cachePagesMap))) {
            console.error("YPopLayer cannot show page:", qrcqml);
            return null;
        }

        _cancelPendingRequest();
        const sequence = YUtils.beginPopRequest();
        const popIdValue = popIdPrefix + qrcqml;

        if (cachePage && cachePagesMap.containsKey(popIdValue)) {
            const cacheItem = cachePagesMap.value(popIdValue);
            if (cacheItem) {
                return _activate(popIdValue, cacheItem, animationEnabled, properties);
            }
            cachePagesMap.remove(popIdValue);
        }

        if (stackPagesMap.containsKey(popIdValue)) {
            const stackItem = stackPagesMap.value(popIdValue);
            if (stackItem) {
                return _activate(popIdValue, stackItem, animationEnabled, properties);
            }
            stackPagesMap.remove(popIdValue);
        }

        const component = qmlCreateComponent(qrcqml);
        const pending = {
            "animationEnabled": animationEnabled,
            "cachePage": cachePage,
            "cancelled": false,
            "component": component,
            "popId": popIdValue,
            "properties": properties,
            "qmlName": qrcqml,
            "sequence": sequence,
            "statusCallback": null
        };
        _pendingRequest = pending;

        if (component.status === Component.Ready) {
            return _createReadyPage(pending);
        }
        if (component.status === Component.Loading) {
            const onStatusChanged = function () {
                if (component.status === Component.Loading) {
                    return;
                }

                component.statusChanged.disconnect(onStatusChanged);
                pending.statusCallback = null;
                if (!_isPendingCurrent(pending)) {
                    _finishPending(pending);
                    _destroyComponent(component);
                    pending.component = null;
                    return;
                }
                if (component.status === Component.Ready) {
                    _createReadyPage(pending);
                } else {
                    console.error("YPopLayer component error:", qrcqml, component.errorString());
                    _finishPending(pending);
                    _destroyComponent(component);
                    pending.component = null;
                }
            };
            pending.statusCallback = onStatusChanged;
            component.statusChanged.connect(onStatusChanged);
            return null;
        }

        console.error("YPopLayer component error:", qrcqml, component.errorString());
        _finishPending(pending);
        _destroyComponent(component);
        pending.component = null;
        return null;
    }

    // Supports both show(qml, animation, properties) and the legacy
    // show(qml, animation, cachePage, properties) form.
    function show(qrcqml, animationEnabled, propertiesOrCache, legacyProperties) {
        return _show(qrcqml, animationEnabled, _cacheFromArguments(propertiesOrCache), _propertiesFromArguments(propertiesOrCache, legacyProperties));
    }

    function cacheShow(qrcqml, animationEnabled, properties) {
        return _show(qrcqml, animationEnabled, true, _propertiesFromArguments(properties, undefined));
    }

    function showWithProperties(qrcqml, properties) {
        return show(qrcqml, false, properties);
    }

    function close() {
        popItemObject = null;
        closeAnimation();
    }

    function closeAllPopPage() {
        _cancelPendingRequest();
        _disconnectItemCallbacks();
        popItemObject = null;
        closeAnimation();
        YUtils.clearStackView();
    }

    Component.onDestruction: {
        _cancelPendingRequest();
        _disconnectItemCallbacks();
    }
}
