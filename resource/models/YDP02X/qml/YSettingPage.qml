import "./commons"
import "./components"
import "./i18n"
import QtQuick 2.12
import com.youdao.pen 1.0

YPage {
    id: id_setting_page
    pageIndex: YEnum.PageIndex.Setting

    property int currentShowIndex: -1

    function showSettingPage(settingPage, needPwd, scene, popThisPage) {
        id_pop_container.show(settingPage, needPwd, scene, popThisPage);
    }

    function requestKeyboard(page, popThisPage) {
        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready)
                incubator.onStatusChanged = function(status) {
                if (status === Component.Ready)
                    id_page_pop_helper.inputPageCreated(incubator.object, page, popThisPage);

            };
            else
                id_page_pop_helper.inputPageCreated(incubator.object, page, popThisPage);
        }
    }

    function settingItemClicked(index, popThisPage = false) {
        console.log("YSettingPage.qml===settingItemClicked===index: ", index);
        currentShowIndex = index;
        let component = null;
        switch (index) {
        case YEnum.SettingIndex.Network:
            logManager.sendHttpLog("action=settings_network_click");
            showSettingPage("settingpages/YSettingWifi", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Bluetooth:
            logManager.sendHttpLog("action=settings_bluetooth_click");
            showSettingPage("settingpages/YSettingBluetooth", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Volume:
            logManager.sendHttpLog("action=settings_sound_click");
            settingManager.updateVolumeAndLcd();
            showSettingPage("settingpages/YSettingVolume", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Brightness:
            logManager.sendHttpLog("action=settings_brightness_click");
            settingManager.updateVolumeAndLcd();
            showSettingPage("settingpages/YSettingBrightness", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Translate:
            logManager.sendHttpLog("action=settings_translate_click");
            showSettingPage("settingpages/YSettingTranslate", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Dict:
            logManager.sendHttpLog("action=settings_dict_click");
            showSettingPage("settingpages/YSettingDict", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Pronunc:
            logManager.sendHttpLog("action=settings_pronounce_click");
            showSettingPage("settingpages/YSettingPronunc", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Handedness:
            logManager.sendHttpLog("action=settings_direction_click");
            showSettingPage("settingpages/YSettingHandedness", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Language:
            logManager.sendHttpLog("action=settings_language_click");
            showSettingPage("settingpages/YSettingLanguage", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.MultiLines:
            logManager.sendHttpLog("action=settings_multiline_click");
            showSettingPage("settingpages/YSettingMultiLines", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.Update:
            logManager.sendHttpLog("action=settings_update_click");
            showSettingPage("settingpages/YSettingUpdate", false, undefined, popThisPage);
            break;
        case YEnum.SettingIndex.About:
            logManager.sendHttpLog("action=settings_about_click");
            showSettingPage("settingpages/YSettingAbout", false, undefined, popThisPage);
            break;
        case 201:
            showSettingPage("settingpages/BatteryInfoPage", false, undefined, popThisPage);
            break;
        case 203:
            showSettingPage("settingpages/SystemTweakSettingPage", false, undefined, popThisPage);
            break;
        case 205:
            showSettingPage("settingpages/QuerySettingPage", false, undefined, popThisPage);
            break;
        case 206:
            showSettingPage("settingpages/LockSettingPage", true, undefined, popThisPage);
            break;
        case 207:
            showSettingPage("settingpages/Torch", false, undefined, popThisPage);
            break;
        case 208:
            showSettingPage("settingpages/WallpaperSettingPage", false, undefined, popThisPage);
            break;
        }
    }

    objectName: "YPage===YSettingPage.qml"
    onBackButtonClicked: {
        id_pop_container.closeAllPages();
    }
    Component.onDestruction: {
        console.log("YSettingPage.qml===Component.onDestruction===called");
    }
    Item {
        id: id_setting_views

        anchors.fill: parent

        GridView {
            id: id_setting_gridview

            readonly property bool isMoveToUp: (verticalVelocity > 0)

            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10
            clip: true
            cellWidth: 256
            cellHeight: 58
            model: id_setting_model
            cacheBuffer: 1000

            delegate: YMouseArea {
                id: id_item_delegate

                width: id_setting_gridview.cellWidth
                height: id_setting_gridview.cellHeight
                objectName: "YSettingPage.qml_delegate_index" + index
                onClicked: {
                    settingItemClicked(settingIndex);
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - 8
                    color: YColors.grayNormal
                    opacity: parent.pressed ? 0.6 : 1
                    radius: 12

                    YImage {
                        id: id_icon

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        source: settingIcon
                        sourceSize: Qt.size(24, 24)
                    }

                    YTextMedium {
                        //    return YTranslateText.brightness

                        id: id_label

                        anchors.left: id_icon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (settingIndex) {
                            case YEnum.SettingIndex.Network:
                                return YTranslateText.network;
                            case YEnum.SettingIndex.Bluetooth:
                                return YTranslateText.bluetooth;
                            case YEnum.SettingIndex.Volume:
                                return YTranslateText.volume;
                            case YEnum.SettingIndex.Brightness:
                                return "屏幕";
                            case YEnum.SettingIndex.Translate:
                                return YTranslateText.translate;
                            case YEnum.SettingIndex.Dict:
                                return YTranslateText.dictionary;
                            case YEnum.SettingIndex.Pronunc:
                                return YTranslateText.pronunc;
                            case YEnum.SettingIndex.Handedness:
                                return YTranslateText.handedness;
                            case YEnum.SettingIndex.Language:
                                return YTranslateText.deviceLanguage;
                            case YEnum.SettingIndex.MultiLines:
                                return YTranslateText.multi;
                            case YEnum.SettingIndex.Update:
                                return YTranslateText.update;
                            case YEnum.SettingIndex.About:
                                return YTranslateText.about;
                            case 201:
                                return "电池信息";
                            case 203:
                                return "系统微调";
                            case 205:
                                return "扫描查询";
                            case 206:
                                return "安全";
                            case 207:
                                return "笔头 LED";
                            case 208:
                                return "壁纸";
                            default:
                                return "";
                            }
                        }
                        elide: YText.ElideRight
                    }

                }

            }

            header: YSpacing {
                width: id_setting_gridview.width
                implicitHeight: 12
            }

            footer: YSpacing {
                width: id_setting_gridview.width
                implicitHeight: 12
            }

        }

    }

    YVerticalTitleBar {
        id: id_title_bar

        onCallBack: {
            backButtonClicked();
        }

        YButtonBase {
            id: id_portrait_icon_bg

            implicitWidth: 30
            implicitHeight: 30
            mouseAreaMargins: -10
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            opacity: id_back_button.pressed || !enabled ? 0.6 : 1
            color: YColors.grayNormal
            radius: height / 2
            onClicked: {
                if (loginManager.isLogin)
                    logManager.sendHttpLog("action=settings_account_click");
                else
                    logManager.sendHttpLog("action=settings_login_click");
                qmlGlobal.showLoginPage();
            }

            YUserPortrait {
                id: id_portrait_icon

                width: 30
                height: 30
                anchors.centerIn: parent
                sourceSize: Qt.size(30, 30)
                defaultIconSource: "image://icons/portrait.png"
                borderColor: YColors.black
            }

        }

    }

    YPagePopHelper {
        id: id_page_pop_helper

        function inputPageCreated(keyboardPage, page, popThisPage) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });
            keyboardPage.inputFinished.connect(function(content) {
                if (content === locker.password) {
                    showSettingPage(page, false, undefined, popThisPage);
                } else {
                    qmlGlobal.showToast("密码错误，请重试", YColors.yellow);
                    requestKeyboard(page, popThisPage);
                }
            });
            keyboardPage.placeHolderText = "请输入密码...";
            keyboardPage.show();
            qmlGlobal.inputPageShowing = true;
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_YSettingPage.qml"
    }

    YDynamicPageStack {
        id: id_pop_container
        logTag: "YSettingPage"

        function show(page, needPasswd, scene, popThisPage) {
            if (needPasswd && locker.enabled && !(scene && !locker.getScene(scene))) {
                requestKeyboard(page, popThisPage);
                return ;
            }
            _show(page, popThisPage);
        }

        function _show(settingPage, popThisPage) {
            createPage(Qt.resolvedUrl(("./%1.qml").arg(settingPage)), settingPage, {
                "pageIndex": YEnum.PageIndex.Setting,
                "closeOnHomeRelease": true,
                "closeOnHomeLongPress": true
            }, undefined, function(incubatorObject) {
                if (popThisPage)
                    incubatorObject.backButtonClicked.connect(id_setting_page.backButtonClicked);
                if ("settingpages/YSettingUpdate" === settingPage && wifiManager.internetConnect && null !== id_pop_container.popItemObject)
                    incubatorObject.checkUpdate();
            });
        }

        anchors.fill: parent
    }

    ListModel {
        id: id_setting_model

        Component.onCompleted: {
            append({
                "settingIndex": YEnum.SettingIndex.Network,
                "settingIcon": res.getDisk("settings/ic_network")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Bluetooth,
                "settingIcon": res.getDisk("settings/ic_bluetooth")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Volume,
                "settingIcon": res.getDisk("settings/ic_sounds")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Brightness,
                "settingIcon": res.get("setting/screen")
            });
            if (qmlGlobal.checkFeature(YEnum.FEATURE_LANG_JPN) || qmlGlobal.checkFeature(YEnum.FEATURE_LANG_KOR) || qmlGlobal.checkFeature(YEnum.FEATURE_LANG_ES))
                append({
                "settingIndex": YEnum.SettingIndex.Translate,
                "settingIcon": res.getDisk("settings/ic_translate")
            });

            append({
                "settingIndex": YEnum.SettingIndex.Dict,
                "settingIcon": res.getDisk("settings/ic_dict")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Pronunc,
                "settingIcon": res.getDisk("settings/ic_pronunc")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Handedness,
                "settingIcon": res.getDisk("settings/ic_handedness")
            });
            if (!qmlGlobal.checkFeature(YEnum.FEATURE_SERIAL_D2))
                append({
                "settingIndex": YEnum.SettingIndex.Language,
                "settingIcon": res.getDisk("settings/ic_language")
            });

            append({
                "settingIndex": 206,
                "settingIcon": res.get("setting/lock")
            });
            append({
                "settingIndex": 205,
                "settingIcon": res.get("setting/scan")
            });
            append({
                "settingIndex": 201,
                "settingIcon": res.get("setting/battery")
            });
            append({
                "settingIndex": 207,
                "settingIcon": res.get("setting/torch")
            });
            append({
                "settingIndex": 208,
                "settingIcon": res.get("setting/background")
            });
            append({
                "settingIndex": 203,
                "settingIcon": res.get("setting/sys_tweak")
            });
            append({
                "settingIndex": YEnum.SettingIndex.Update,
                "settingIcon": res.getDisk("settings/ic_update")
            });
            append({
                "settingIndex": YEnum.SettingIndex.About,
                "settingIcon": res.getDisk("settings/ic_about")
            });
        }
    }

}
