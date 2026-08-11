import QtQuick 2.12

import "../commons"

Column {
    readonly property var dictJson: id_dict_detail_page.dictJson

    spacing: 0

    YDictTypeDtChPoemData {
        width: parent.width
        jsonPoemData: typeof dictJson.poems == "undefined" ? null : dictJson.poems[0]
        authorIntro: (typeof dictJson.authors == "undefined" || dictJson.authors.length <= 0) ? "" : dictJson.authors[0].author.intro
    }
}

