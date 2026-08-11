pragma Singleton
import QtQuick 2.12

// 内部方法，尽量不要使用
QtObject {
    // 缓存主动要求缓存的页面
    property QtObject globalMap: null

    // 缓存栈中的页面对象
    property QtObject stackMap: null

    // 栈视图对象
    property QtObject stackView: null

    // 当前显示的栈 id
    property string currentPopId: ""

    // Global generation for asynchronous page creation. Only the latest
    // request may publish a page into the shared stack.
    property int popRequestSequence: 0

    property QtObject soundCenterPlayingCheckTimer: null

    function beginPopRequest() {
        popRequestSequence += 1;
        return popRequestSequence;
    }

    function isCurrentPopRequest(sequence) {
        return sequence === popRequestSequence;
    }

    function clearStackView() {
        beginPopRequest();
        if (null === stackMap) {
            currentPopId = "";
            return;
        }

        const items = stackMap.values();
        stackMap.clear();
        currentPopId = "";

        // Cleanup from top to bottom without exposing intermediate pages.
        for (let i = items.length - 1; i >= 0; --i) {
            const item = items[i];
            if (!item) {
                continue;
            }
            if (item.hasOwnProperty("backButtonClicked")) {
                item.backButtonClicked();
            } else if (typeof item.destroy === "function") {
                item.destroy(1);
            }
        }
    }

    function removeKey(key, notLoadTop) {
        if ((typeof key === "string") && (key.length > 0) && (null !== stackMap) && stackMap.containsKey(key)) {
            stackMap.pop(key);
            if ((typeof notLoadTop == "undefined") || !notLoadTop) {
                const topKey = stackMap.topKey();
                currentPopId = (null !== topKey) ? topKey : "";
            }
        }
    }
}
