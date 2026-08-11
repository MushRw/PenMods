import QtQuick 2.12

import "../commons"

YRoundedImage {
    property string defaultIconSource: "image://icons/login/dict-logo.png"
    source: (loginManager.iconPath.length > 0) && qmlGlobal.fileExists(loginManager.iconPath)
            ? loginManager.iconPath.toLoadFileUrl() : defaultIconSource
}
