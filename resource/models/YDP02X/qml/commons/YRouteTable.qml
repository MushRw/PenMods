import QtQuick 2.12
import com.github.penuniverse 1.0
import com.youdao.pen 1.0

// Central route metadata. Pages should not need to know their resource URL.
QtObject {
    function _route(routeId, url, pageIndex, cachePolicy) {
        return {
            "routeId": routeId,
            "url": url,
            "pageIndex": pageIndex,
            "cachePolicy": cachePolicy || "destroy",
            "launchMode": "singleTask"
        };
    }

    function resolve(routeId) {
        switch (routeId) {
        case "dict":
            return _route(routeId, "qrc:/qml/YDictPage.qml", YEnum.PageIndex.Dict);
        case "dict.detail":
            return _route(routeId, "qrc:/qml/YDictDetailPage.qml", YEnum.PageIndex.DictDetail);
        case "speech":
            return _route(routeId, "qrc:/qml/YSpeechPage.qml", YEnum.PageIndex.Speech);
        case "spell":
            return _route(routeId, "qrc:/qml/YSpellPage.qml", YEnum.PageIndex.Spell);
        case "follow":
            return _route(routeId, "qrc:/qml/YFollowPage.qml", YEnum.PageIndex.Follow);
        case "reading":
            return _route(routeId, "qrc:/qml/YTouchReadingPage.qml", YEnum.PageIndex.BookStore);
        case "textbook":
            return _route(routeId, "qrc:/qml/YTextbookPage.qml", YEnum.PageIndex.TextBook);
        case "wordbook":
            return _route(routeId, "qrc:/qml/YWordBookPage.qml", YEnum.PageIndex.Fav);
        case "audio":
            return _route(routeId, "qrc:/qml/YAudioPage.qml", YEnum.PageIndex.Audioplayer);
        case "history":
            return _route(routeId, "qrc:/qml/YHistoryPage.qml", YEnum.PageIndex.History);
        case "settings":
            return _route(routeId, "qrc:/qml/YSettingPage.qml", YEnum.PageIndex.Setting);
        case "login":
            return _route(routeId, "qrc:/qml/YLoginPage.qml", YEnum.PageIndex.UserCenter);
        case "powerOff":
            return _route(routeId, "qrc:/qml/YPowerOffPage.qml", YEnum.PageIndex.PowerOff);
        case "recorder":
            return _route(routeId, "qrc:/qml/AudioRecorder.qml", PageIndex.AudioRecorder);
        case "chat":
            return _route(routeId, "qrc:/qml/ChatAssistant.qml", PageIndex.ChatAssistant);
        case "plugins":
            return _route(routeId, "qrc:/qml/PluginManager.qml", PageIndex.PluginManager);
        }
        return null;
    }

    function routeForPageIndex(pageIndex) {
        switch (pageIndex) {
        case YEnum.PageIndex.Dict: return "dict";
        case YEnum.PageIndex.Speech: return "speech";
        case YEnum.PageIndex.Reading: return "reading";
        case YEnum.PageIndex.TextBook: return "textbook";
        case YEnum.PageIndex.Fav: return "wordbook";
        case YEnum.PageIndex.Audioplayer: return "audio";
        case YEnum.PageIndex.History: return "history";
        case YEnum.PageIndex.Setting: return "settings";
        case YEnum.PageIndex.PowerOff: return "powerOff";
        case PageIndex.AudioRecorder: return "recorder";
        case PageIndex.ChatAssistant: return "chat";
        case PageIndex.PluginManager: return "plugins";
        }
        return "";
    }

    function resolveLegacy(qmlName) {
        var legacyRoutes = {
            "YDictPage": "dict",
            "YDictDetailPage": "dict.detail",
            "YSpeechPage": "speech",
            "YSpellPage": "spell",
            "YFollowPage": "follow",
            "YTouchReadingPage": "reading",
            "YTextbookPage": "textbook",
            "YWordBookPage": "wordbook",
            "YAudioPage": "audio",
            "YHistoryPage": "history",
            "YSettingPage": "settings",
            "YLoginPage": "login",
            "YPowerOffPage": "powerOff",
            "AudioRecorder": "recorder",
            "ChatAssistant": "chat",
            "PluginManager": "plugins"
        };
        var routeId = legacyRoutes[qmlName] || qmlName;
        var route = resolve(routeId);
        if (route)
            return route;

        var resourceName = qmlName;
        if (resourceName.indexOf(".qml") !== resourceName.length - 4)
            resourceName += ".qml";
        var pageIndex = qmlName.indexOf("settingpages/") === 0
                ? YEnum.PageIndex.Setting : -1;
        return _route("legacy:" + qmlName, "qrc:/qml/" + resourceName, pageIndex);
    }
}
