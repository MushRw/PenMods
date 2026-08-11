import "./commons"
import "./components"
import "./i18n"
import QtQuick 2.12
import QtGraphicalEffects 1.12
import com.github.penuniverse 1.0
import com.youdao.pen 1.0

YBackground {
    id: id_container_index

    property bool isLocked: false
    property bool isDimmed: false

    property int idleInterval: 15000
    property int dimInterval: 25000

    MouseArea {
        anchors.fill: parent
        z: 100
        enabled: !isLocked

        propagateComposedEvents: true
        hoverEnabled: true

        onPressed: {
            resetIdleStatus();
            mouse.accepted = false;
        }
        onReleased: {
            resetIdleStatus();
            mouse.accepted = false;
        }
        onPositionChanged: {
            resetIdleStatus();
            mouse.accepted = false;
        }
        onWheel: {
            resetIdleStatus();
            wheel.accepted = false;
        }
    }

    Timer {
        id: id_idle_timer
        interval: idleInterval
        repeat: false

        running: !isLocked && Qt.application.active && (qmlGlobal.currentPageIndex === YEnum.PageIndex.NonePage)
                 && screenManager.lockScreen

        onTriggered: {
            if (qmlGlobal.currentPageIndex !== YEnum.PageIndex.NonePage) {
                return;
            }

            id_container_index.isLocked = true;
            id_dim_timer.start();
        }
    }

    Timer {
        id: id_dim_timer
        interval: dimInterval
        repeat: false
        running: false
        onTriggered: {
            if (id_container_index.isLocked) {
                id_container_index.isDimmed = true;
            }
        }
    }

    function resetIdleStatus() {
        if (id_container_index.isLocked || id_container_index.isDimmed) {
            id_container_index.isLocked = false;
            id_container_index.isDimmed = false;
            id_dim_timer.stop();
            updateTimeStrings();
        }

        if (id_idle_timer.running) {
            id_idle_timer.restart();
        }
    }

    property string currentTimeString: "00:00"
    property string currentDateString: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateTimeStrings()
    }

    function updateTimeStrings() {
        var now = new Date();
        currentTimeString = Qt.formatTime(now, "HH:mm");
        var month = now.getMonth() + 1;
        var day = now.getDate();
        var dayOfWeek = now.getDay();
        var weekDays = ["日", "一", "二", "三", "四", "五", "六"];
        currentDateString = month + "月" + day + "日 星期" + weekDays[dayOfWeek];
    }

    function delayInitMainTitleBar() {
        id_main_titlebar_loader.source = "components/YMainTitleBar.qml";
        id_main_titlebar_loader.active = true;
    }

    function getPageTitle(index) {
        switch (index) {
        case YEnum.PageIndex.Dict:
            return YTranslateText.dict;
        case YEnum.PageIndex.Speech:
            return YTranslateText.speech;
        case YEnum.PageIndex.Reading:
            return YTranslateText.touchreading;
        case YEnum.PageIndex.TextBook:
            return YTranslateText.textbookSynchronous;
        case YEnum.PageIndex.Fav:
            return YTranslateText.favoriteWords;
        case YEnum.PageIndex.Audioplayer:
            return YTranslateText.listeningExercise;
        case YEnum.PageIndex.History:
            return YTranslateText.history;
        case YEnum.PageIndex.Setting:
            return YTranslateText.settings;
        case PageIndex.AudioRecorder:
            return "录音机";
        case PageIndex.ChatAssistant:
            return "AI 助手";
        case PageIndex.PluginManager:
            return "插件管理";
        default:
            return "";
        }
    }

    function mainMenuClicked(index, logAction) {
        if (logAction && logAction.length > 0)
            logManager.sendHttpLog(logAction);
        if (index === YEnum.PageIndex.PowerOff && typeof id_page_pop_helper !== "undefined") {
            id_page_pop_helper.show("YPowerOffPage");
        }
        qmlGlobal.requestShowPage(index);
    }

    anchors.fill: parent

    // 壁纸控制：通过 WallpaperManager 管理
    Connections {
        target: wallpaperManager
        ignoreUnknownSignals: true
        function onCurrentWallpaperChanged() {
            applyWallpaper();
        }
    }

    function applyWallpaper() {
        var path = wallpaperManager.currentWallpaper || "";
        if (wallpaperManager.wallpaperMode === 0) {
            // 无壁纸模式：不显示任何图片（纯黑）
            id_bg_image.source = "";
        } else if (path.length > 0 && path.indexOf("/") === 0) {
            // 使用文件路径壁纸
            id_bg_image.source = "file://" + path;
        } else if (path.length > 0) {
            id_bg_image.source = id_bg_image.defaultPath;
        } else {
            // 模式非0但无壁纸路径：使用默认背景
            id_bg_image.source = id_bg_image.defaultPath;
        }
    }

    Image {
        id: id_bg_image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop

        property string defaultPath: "qrc:/images/background/bg.png"

        source: defaultPath

        Behavior on source {
            SequentialAnimation {
                NumberAnimation {
                    target: id_bg_image
                    property: "opacity"
                    to: 0
                    duration: 200
                }
                PropertyAction {
                    target: id_bg_image
                    property: "source"
                }
                NumberAnimation {
                    target: id_bg_image
                    property: "opacity"
                    to: 1
                    duration: 500
                }
            }
        }

        onStatusChanged: {
            if (status === Image.Error) {
                source = defaultPath;
            }
        }
    }

    FastBlur {
        id: id_bg_blur
        anchors.fill: id_bg_image
        source: id_bg_image
        radius: 64
        transparentBorder: true
        opacity: isDimmed ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 800
                easing.type: Easing.InOutQuad
            }
        }
    }

    Rectangle {
        id: id_dark_overlay
        anchors.fill: parent
        color: "black"
        opacity: isDimmed ? 0.4 : 0.0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 800
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: isLocked
        z: 99
        onClicked: {
            resetIdleStatus();
        }
    }

    Item {
        id: id_lock_screen_layer
        anchors.fill: parent
        z: 50
        opacity: isLocked ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 500
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: currentTimeString
                color: "white"
                font.pixelSize: 80
                font.weight: Font.Light
                font.family: "Roboto"
                anchors.horizontalCenter: parent.horizontalCenter
                style: Text.Outline
                styleColor: "#40000000"
            }

            Text {
                text: currentDateString
                color: "white"
                font.pixelSize: 28
                anchors.horizontalCenter: parent.horizontalCenter
                style: Text.Outline
                styleColor: "#40000000"
            }
        }
    }

    Item {
        id: id_main_content
        anchors.fill: parent
        opacity: isLocked ? 0.0 : 1.0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        YLoader {
            id: id_main_titlebar_loader
            width: parent.width
            height: 50
        }

        YHorizontalListView {
            id: id_main_menu_list_view
            anchors.fill: parent
            anchors.topMargin: 56
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 12
            spacing: 8
            model: mainMenuModel
            clip: false

            delegate: YHorizontalListViewDelegate {
                id: id_item_delegate
                width: 112
                height: 102

                Item {
                    id: id_content_wrapper
                    anchors.fill: parent
                    scale: id_main_menu_icon_button.pressed ? 0.96 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }

                    YImage {
                        anchors.fill: parent
                        sourceSize: Qt.size(112, 102)
                        imageName: ("%1-bg").arg(iconFg)
                        antialiasing: true
                    }

                    YImage {
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        width: 40
                        height: 40
                        sourceSize: Qt.size(40, 40)
                        imageName: iconFg
                    }

                    YText {
                        height: 24
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        text: getPageTitle(pageIndex)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "black"
                        opacity: id_main_menu_icon_button.pressed ? 0.1 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }
                }

                YMouseArea {
                    id: id_main_menu_icon_button
                    anchors.fill: parent
                    onClicked: mainMenuClicked(pageIndex, logAction)
                }
            }
        }
    }

    ListModel {
        id: mainMenuModel
        Component.onCompleted: {
            append({
                "iconFg": "home-dict",
                "pageIndex": YEnum.PageIndex.Dict,
                "logAction": "action=home_search_click"
            });
            append({
                "iconFg": "home-textbook",
                "pageIndex": PageIndex.ChatAssistant,
                "logAction": ""
            });
            append({
                "iconFg": "home-speech",
                "pageIndex": PageIndex.AudioRecorder,
                "logAction": ""
            });
            append({
                "iconFg": "home-fav",
                "pageIndex": YEnum.PageIndex.Fav,
                "logAction": "action=home_wordbook_click"
            });
            if (qmlGlobal.checkFeature(YEnum.FEATURE_AUDIO)) {
                append({
                    "iconFg": "home-audioplayer",
                    "pageIndex": YEnum.PageIndex.Audioplayer,
                    "logAction": "action=home_listening_clik"
                });
            }
            append({
                "iconFg": "home-history",
                "pageIndex": YEnum.PageIndex.History,
                "logAction": "action=home_history_click"
            });
            append({
                "iconFg": "qrc:/images/home/home-plugin.png",
                "pageIndex": PageIndex.PluginManager,
                "logAction": ""
            });
            append({
                "iconFg": "home-setting",
                "pageIndex": YEnum.PageIndex.Setting,
                "logAction": "action=home_settings_click"
            });
        }
    }

    ListModel {
        id: id_plugin_drawer_model
    }

    function refreshPluginDrawer() {
        id_plugin_drawer_model.clear();
        if (typeof pluginManager === "undefined")
            return;
        var count = pluginManager.getPluginCount();
        for (var i = 0; i < count; i++) {
            var info = pluginManager.getPluginInfo(i);
            if (info.enabled && info.loaded) {
                id_plugin_drawer_model.append(info);
            }
        }
    }

    Connections {
        target: (typeof pluginManager !== 'undefined') ? pluginManager : null
        ignoreUnknownSignals: true
        function onPluginListUpdated() {
            refreshPluginDrawer();
        }
        function onPluginStateChanged(pluginName, newState) {
            refreshPluginDrawer();
        }
    }

    Component.onCompleted: {
        refreshPluginDrawer();
        // 初始化时应用壁纸
        applyWallpaper();
    }

    YDynamicPageStack {
        id: id_plugin_pop_container
        anchors.fill: parent
        z: 500
        visible: count > 0
        logTag: "YIndexPage plugin"

        // 事件屏障：位于动态插件内容之后（z:-1），
        // 插件自身 MouseArea 优先接收事件，
        // 未被覆盖区域由屏障吸收，防止穿透到下层
        MouseArea {
            id: id_plugin_event_barrier
            anchors.fill: parent
            z: -1
            onPressed: { mouse.accepted = true; }
            onReleased: { mouse.accepted = true; }
            onClicked: { mouse.accepted = true; }
        }

        function show(tpage, properties) {
            var componentPath = tpage;
            const absoluteUrl = tpage.indexOf("/") === 0
                    || tpage.indexOf(":/") === 0
                    || tpage.indexOf("file:") === 0
                    || tpage.indexOf("qrc:") === 0
                    || tpage.indexOf("://") > 0;
            if (!absoluteUrl) {
                if (tpage.indexOf(".qml") === -1)
                    componentPath = "%1.qml".arg(tpage);
                componentPath = Qt.resolvedUrl("./%1".arg(componentPath));
            }

            createPage(componentPath, tpage, {
                "pageIndex": YEnum.PageIndex.NonePage,
                "closeOnHomeRelease": true
            }, properties || {}, function(incubatorObject) {
                if (incubatorObject.hasOwnProperty("focus"))
                    incubatorObject.forceActiveFocus();
            });
        }

        function closeAll() {
            closeAllPages();
        }
    }

    Item {
        id: id_plugin_drawer
        anchors.fill: parent
        z: 400
        visible: id_plugin_drawer_model.count > 0

        property bool isOpen: false
        property real panelHeight: 140
        readonly property real openY: parent.height - panelHeight
        readonly property real closedY: parent.height

        MouseArea {
            id: id_drawer_overlay
            anchors.fill: parent
            enabled: id_plugin_drawer.isOpen
            hoverEnabled: false

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: id_plugin_drawer.isOpen ? 0.5 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
            }

            onClicked: {
                id_plugin_drawer.closeDrawer();
            }
        }

        Rectangle {
            id: id_drawer_panel
            width: parent.width
            height: id_plugin_drawer.panelHeight
            y: id_plugin_drawer.closedY
            color: "#252525"
            radius: 16

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 8
                width: 40
                height: 5
                radius: 3
                color: "#444444"
            }

            ListView {
                id: id_plugin_horizontal_list
                anchors.fill: parent
                anchors.topMargin: 25
                anchors.bottomMargin: 10
                orientation: ListView.Horizontal
                model: id_plugin_drawer_model
                spacing: 15
                leftMargin: 20
                rightMargin: 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    width: 70
                    height: 90

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 54
                            height: 54
                            radius: 12
                            color: "#333333"
                            anchors.horizontalCenter: parent.horizontalCenter

                            YImage {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                sourceSize: Qt.size(36, 36)
                                imageName: (model.icon && model.icon !== "") ? model.icon : "qrc:/images/home/home-plugin.png"
                            }
                        }

                        YText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: model.name
                            font.pixelSize: 13
                            color: "white"
                            width: 70
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    YMouseArea {
                        anchors.fill: parent
                        onClicked: {
                            id_plugin_drawer.closeDrawer();
                            id_plugin_pop_container.show(model.mainQmlUrl, {
                                "pluginName": model.name
                            });
                        }
                    }
                }
            }
        }

        YMouseArea {
            id: id_drawer_drag_handle
            anchors.left: parent.left
            anchors.right: parent.right
            height: id_plugin_drawer.isOpen ? 40 : 30
            y: id_drawer_panel.y - (id_plugin_drawer.isOpen ? 0 : 30)

            drag.target: id_drawer_panel
            drag.axis: Drag.YAxis
            drag.minimumY: id_plugin_drawer.openY
            drag.maximumY: id_plugin_drawer.closedY

            onReleased: {
                var distToOpen = Math.abs(id_drawer_panel.y - id_plugin_drawer.openY);
                var distToClosed = Math.abs(id_drawer_panel.y - id_plugin_drawer.closedY);

                if (distToOpen < distToClosed) {
                    id_plugin_drawer.openDrawer();
                } else {
                    id_plugin_drawer.closeDrawer();
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: 30
            height: 4
            radius: 2
            color: "white"
            opacity: 0.3
            visible: !id_plugin_drawer.isOpen
        }

        function openDrawer() {
            isOpen = true;
            id_drawer_panel.y = openY;
        }

        function closeDrawer() {
            isOpen = false;
            id_drawer_panel.y = closedY;
        }
    }
}
