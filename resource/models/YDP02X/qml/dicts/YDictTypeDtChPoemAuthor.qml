import QtQuick 2.12

import "../commons"
import "../i18n"

Column {
    id: id_poem_dict_author
    spacing: 8

    property var jsonAuthorData: null

    YText {
        id: id_author_name_info
        width: parent.width
        height: contentHeight + 6
        font.family: qmlGlobal.fontFamilyZhCn
        font.weight: Font.Medium
        textFormat: YTextBase.RichText
        wrapMode: YTextBase.Wrap
        topPadding: 6
        text: {
            let qsText = ('<span style="color: %1">').arg(YColors.grayText) + YTranslateText.dynasty + '&nbsp;</span>' + jsonAuthorData.dynasty
            if (typeof jsonAuthorData.zi != "undefined")
                qsText += ('&nbsp;&nbsp;&nbsp;&nbsp;<span style="color: %1">').arg(YColors.grayText) + YTranslateText.called + '&nbsp;</span>' + jsonAuthorData.zi
            if (typeof jsonAuthorData.hao != "undefined")
                qsText += ('&nbsp;&nbsp;&nbsp;&nbsp;<span style="color: %1">').arg(YColors.grayText) + YTranslateText.designation + '&nbsp;</span>' + jsonAuthorData.hao
            if (typeof jsonAuthorData.knownAs != "undefined")
                qsText += ('&nbsp;&nbsp;&nbsp;&nbsp;<span style="color: %1">').arg(YColors.grayText) + YTranslateText.worldName + '&nbsp;</span>' + jsonAuthorData.knownAs
            return qsText
        }
    } // Text id_author_name_info

    YTextBase {
        font.pixelSize: 16
        font.family: qmlGlobal.fontFamily
        font.weight: Font.Normal
        color: YColors.red
        width: parent.width
        height: contentHeight + 6
        text: YTranslateText.introduction
        topPadding: 6
    }

    YTextMedium {
        width: parent.width
        height: paintedHeight
        font.family: qmlGlobal.fontFamilyZhCn
        wrapMode: YTextBase.Wrap
        text: jsonAuthorData.intro
    }

    readonly property bool havePoems: typeof jsonAuthorData.poems != "undefined"

    YTextBase {
        font.pixelSize: 16
        font.family: qmlGlobal.fontFamily
        font.weight: Font.Normal
        color: YColors.red
        width: parent.width
        height: contentHeight + 6
        text: YTranslateText.production
        topPadding: 6
        visible: havePoems
    }

    YTextMedium {
        width: parent.width
        height: paintedHeight
        font.family: qmlGlobal.fontFamilyZhCn
        wrapMode: YTextBase.Wrap
        text: {
            let qsText = ""
            let iFlag = 0
            jsonAuthorData.poems.forEach(function(poemName){
                if (iFlag++ > 0) qsText += '、'
                qsText += '《' + poemName + '》'
            })
            return qsText
        }
        visible: havePoems
    }

}

