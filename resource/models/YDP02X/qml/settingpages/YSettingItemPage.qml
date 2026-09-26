import QtQuick 2.12

import "../commons"

YBackButtonPage {
    id: id_setting_item
    objectName: "YSettingItemPage.qml"

    function openSettingPage(page, properties) {
        var qmlName = page.indexOf("/") >= 0 ? page : "settingpages/" + page;
        return navigate(qmlName, properties || {}, {
            "animation": true,
            "cache": false
        });
    }
}
