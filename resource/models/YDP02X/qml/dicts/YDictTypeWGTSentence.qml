import QtQuick 2.12

import "../commons"

YDictTypeBase {
    YTextMedium {
        id: id_dict_content
        wrapMode: YText.Wrap
        height: id_dict_content.contentHeight
        lineHeightMode: Text.FixedHeight
        lineHeight: 26
        text: content
        onTextChanged: {
            font.family = qmlGlobal.getFontFamilyNameByLangName(resultManager.dstLang)
        }
    }
}
