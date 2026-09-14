
import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../components"
import "../i18n"

YPage {
    id: id_speech_item
    objectName: "YPage === YSpeechDetail.qml"
    property var resType : 0;
    property var content : JSON.parse(speechManager.content);
    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            soundCenter.forceStop()
            backButtonClicked();
        }
    }

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        contentHeight: id_speech_content.height
        anchors.topMargin: 12
        Column {
            id: id_speech_content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 12
            YTextCH {
                id: id_title_text
                width: parent.width
                horizontalAlignment : YText.AlignHLeft
                verticalAlignment: YText.AlignVCenter
                color: YColors.grayText
                text: speechManager.asrResult
                wrapMode: YTextBase.Wrap
            }

            YSpacingForColumn {
                implicitHeight: 12
            }

            Rectangle{
                // finished
                id: id_speech_introduction
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_introduction_info.height + id_speech_introduction_info.anchors.topMargin * 2
                visible: resType == YEnum.IntroductionResult
                YTextCH {
                    id: id_speech_introduction_info
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    font.pixelSize: 18
                    textFormat: YText.RichText
                    wrapMode: YTextBase.Wrap
                    lineHeight: 26
                    lineHeightMode: YTextMedium.FixedHeight
                    text: content.message;
                }
            }
            Rectangle{
                // finished
                id: id_speech_commontext
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_commontext_info.height + id_speech_commontext_info.anchors.topMargin * 2
                visible: resType == YEnum.CommonTextResult
                YTextCH {
                    id: id_speech_commontext_info
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    font.pixelSize: 18
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 26
                    textFormat: YText.RichText
                    wrapMode: YTextBase.Wrap
                    text: content.result[0].text
                }
            }
            Rectangle{
                // finished
                id: id_speech_calc
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_calc_info.height + id_speech_calc_info.anchors.topMargin * 2
                visible: resType == YEnum.CalcResult
                YTextCH {
                    id: id_speech_calc_info
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 15
                    font.pixelSize: 18
                    textFormat: YText.RichText
                    wrapMode: YTextBase.Wrap
                    text: content.detail.question + "=" + content.detail.result
                }
            }
            Rectangle{
                // finished
                id: id_speech_wiki
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_wiki_info.height + id_speech_wiki_info.anchors.topMargin * 2
                visible: resType == YEnum.WikiResult
                YTextCH {
                    id: id_speech_wiki_info
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    font.pixelSize: 16
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 24
                    textFormat: YText.RichText
                    wrapMode: YTextBase.Wrap
                    text:  '<font size="4">%1</font><p><font color="%3">%2</font>'.arg(content.detail.title).arg(content.detail.content).arg(YColors.grayText)

                }
            }

            Rectangle{
                // finished
                anchors.left: parent.left
                anchors.right: parent.right
                color: YColors.grayNormal
                radius: 12
                height: 108
                visible: resType == YEnum.WeatherResult

                Row {
                    id: id_speech_weather
                    anchors.fill: parent
                    leftPadding: 14
                    topPadding: 26
                    Column {
                        spacing: 10
                        YTextCH{
                            textFormat: YText.RichText
                            font.pixelSize: 22
                            text:  ("%1℃ ~ %2℃").arg(content.detail.lo_temp).arg(content.detail.hi_temp)
                        }
                        Row {
                            spacing: 4
                            YImage{
                                anchors.verticalCenter: parent.verticalCenter
                                sourceSize: Qt.size(16, 16)
                                imageName: "assistant/location"
                            }
                            YTextCH{
                                textFormat: YText.RichText
                                font.pixelSize: 16
                                text: ("%1&nbsp;<font color='%3'>|&nbsp;%2</font>").arg(content.detail.city).arg(content.detail.day).arg(YColors.grayText)
                            }
                        }
                    }

                }
                YImage {
                    id: id_speech_weather_icon
                    sourceSize: Qt.size(60, 60)
                    anchors.right: parent.right
                    anchors.rightMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    imageName: {
                        if (content.detail.weather == "雪" || content.detail.weather == "Snow")
                            return "assistant/snow";
                        if (content.detail.weather == "多云" || content.detail.weather == "阴" || content.detail.weather == "Cloudy2")
                            return "assistant/cloudy2";
                        if (content.detail.weather == "晴转多云" || content.detail.weather == "Cloudy" )
                            return "assistant/cloudy";
                        if (content.detail.weather == "阵雨" || content.detail.weather == "雷阵雨" || content.detail.weather == "Thunderstorm")
                            return "assistant/thunderstorm";
                        if (content.detail.weather == "小雨" || content.detail.weather == "Rain")
                            return "assistant/rain";
                        if (content.detail.weather == "中雨" || content.detail.weather == "Moderaterain")
                            return "assistant/moderaterain";
                        if (content.detail.weather == "大雨" || content.detail.weather == "暴雨" || content.detail.weather == "Heavyrain")
                            return "assistant/heavyrain";
                        if (content.detail.weather.indexOf("雨") >= 0)
                            return "assistant/heavyrain";
                        return "assistant/sunny";
                    }
                }
            }
            Rectangle{
                // finished
                id: id_speech_pronounce
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_pronounce_Col.height
                visible: resType == YEnum.PronounceResult
                Column
                {
                    id: id_speech_pronounce_Col
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    topPadding: 10
                    bottomPadding: 10
                    spacing: 8

                    YTextCH {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        font.pixelSize: 20
                        textFormat: YText.RichText
                        wrapMode: YTextBase.Wrap
                        text:  {
                            let meanings = '';
                            let i = 0;
                            if (content.result[0].result != null) {
                                content.result[0].result.forEach(function(item){
                                    ++i;
                                    meanings += ('<p><font size="2" color="%4">%1.%2%3</font>').arg(i).arg(item.value).arg(JSON.stringify(item.example).replace('[','').replace(']','')).arg(YColors.grayText);
                                })
                            }
                            return '<b>'+ content.result[0].title + '</b>' + meanings
                        }
                    }
                    YAudioPlayIconLabelButton {
                        id: id_speech_sound_word
                        textFontFamily: qmlGlobal.fontFamilyEnUs
                        textFormat: YText.PlainText
                        text: content.result[0].text
                        implicitHeight: 38
                        color: "#2d2e33"
                        onVisibleChanged: {
                            if (visible) {
                                qmlGlobal.audioPlayId = soundCenter.play(content.result[0].title, "ch");
                            }
                        }
                        onValidClicked: {
                            qmlGlobal.audioPlayId = soundCenter.play(content.result[0].title, "ch");
                        }
                    }
                }
            }
            Rectangle{
                // finished
                id: id_speech_wordchmean
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_wordchmean_info.height + id_speech_wordchmean_info.anchors.topMargin * 2
                visible: resType == YEnum.WordCHMeanResult
                YTextCH {
                    id: id_speech_wordchmean_info
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    font.pixelSize: 20
                    textFormat: YText.RichText
                    wrapMode: YTextBase.Wrap
                    text:  {
                        let result = ('<font color="%1">%2</font>').arg(YColors.red).arg(YTranslateText.paraphrase)
                        let i = 0;
                        content.result[0].result.forEach(function(item){
                            ++i
                            let example = '';
                            item.example.forEach(function(item){
                                example += item + ",";
                            })
                            example = example.substring(0, example.length - 1);
                            result += ('<p>%1.%2:&nbsp;<font color="%4">%3</font>').arg(i).arg(example).arg(item.value).arg(YColors.grayText);
                        })
                        return result;
                    }
                }
            }
            Rectangle{
                // finished
                id: id_speech_wordenmean
                color: YColors.grayNormal
                radius: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: id_speech_wordenmean_column.implicitHeight
                visible: resType == YEnum.WordENMeanResult || resType == YEnum.WordENDetailResult
                Column{
                    id: id_speech_wordenmean_column
                    anchors.left: parent.left
                    anchors.right: parent.right
                    topPadding: 10
                    bottomPadding: 10
                    leftPadding: 12
                    rightPadding: 12
                    spacing: 8

                    YTextCH {
                        id: id_speech_wordenmean_info
                        width: parent.width - parent.rightPadding - parent.leftPadding
                        font.pixelSize: 18
                        textFormat: YText.RichText
                        wrapMode: YTextBase.Wrap
                        text:  {
                            let result =''
                            content.result[0].result.forEach(function(item){
                                let example = '';
                                if (resType == YEnum.WordENMeanResult){
                                    item.meaning.forEach(function(exampleitem){
                                        example += exampleitem + ";";
                                    })
                                    example = example.substring(0, example.length - 1);
                                    result += ('<p><span style="font-family: %1">%2</span>&nbsp;%3').arg(qmlGlobal.fontFamilyEnUs).arg(item.pos).arg(example);
                                }
                                if (resType == YEnum.WordENDetailResult){
                                    result += ('<p>%1').arg(item.word)
                                    item.meanings.forEach(function(meanings){
                                        meanings.meaning.forEach(function(exampleitem){
                                            example += exampleitem + ";";
                                        })
                                        example = example.substring(0, example.length - 1);
                                        result += ('&nbsp;<span style="font-family: %1">%2</span>&nbsp;%3 ').arg(qmlGlobal.fontFamilyEnUs).arg(meanings.pos).arg(example);
                                    })
                                }

                            })
                            return result;
                        }
                    }

                    YAudioPlayIconLabelButton {
                        id: id_speech_en_sound_btn
                        implicitHeight: 38
                        textFontFamily: qmlGlobal.fontFamily
                        textFormat: YText.PlinText
                        color: "#2d2e33"
                        text: YTranslateText.pronunciation
                        visible: resType == YEnum.WordENMeanResult
                        onValidClicked: {
                            if (content.result[0].text == null)
                                qmlGlobal.audioPlayId = soundCenter.play(speechManager.asrResult, "en");
                            else
                                qmlGlobal.audioPlayId = soundCenter.play(content.result[0].text, "en");
                        }
                    }
                }
            }


            Column {
                // finished
                id: id_speech_chardetail
                anchors.left: parent.left
                anchors.right: parent.right
                bottomPadding: 4
                spacing: 10
                visible: resType == YEnum.CharDetailResult || resType == YEnum.WordCHDetailResult
                         || resType == YEnum.SentenceResult || resType == YEnum.ExplainDetailResult
                        || resType == YEnum.IdiomMeanResult;
                Repeater {
                    model:  {
                        let result = new Array;
                        content.result[0].result.forEach(function(item){
                            if (resType == YEnum.CharDetailResult)
                                result.push(('%1&nbsp;<font color="%4">%2</font>&nbsp;%3').arg(item.character).arg(item.pinyin).arg(item.meaning).arg(YColors.grayText));
                            else if (resType == YEnum.WordCHDetailResult)
                                result.push(('%1&nbsp;<font color="%4">%2</font>&nbsp;%3').arg(item.word).arg(item.pinyin).arg(item.meaning).arg(YColors.grayText));
                            else if (resType == YEnum.SentenceResult)
                                 result.push(('%1<p><font size="2" color="%3">%2</font>').arg(item.sentence).arg(item.source).arg(YColors.grayText));
                            else if (resType == YEnum.ExplainDetailResult){
                                let meaning = "";
                                item.meanings[0].meaning.forEach(function(item){
                                    meaning += item + "、";
                                });
                                meaning = meaning.substring(0, meaning.length - 1);
                                result.push(('%1<p><font color="%4">%2</font>&nbsp;%3').arg(item.word).arg(item.meanings[0].pos).arg(meaning).arg(YColors.grayText));
                            }else if (resType == YEnum.IdiomMeanResult){
                                result.push(item);
                            }
                        })
                        return result
                    }
                    Rectangle{
                        color: YColors.grayNormal
                        radius: 12
                        anchors.left: id_speech_chardetail.left
                        anchors.right: id_speech_chardetail.right
                        height: id_speech_chardetail_info.height
                        YTextCH {
                            id: id_speech_chardetail_info
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            height: paintedHeight + 20
                            font.pixelSize: 18
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 26
                            textFormat: YText.RichText
                            wrapMode: YTextBase.Wrap
                            verticalAlignment: YTextBase.AlignVCenter
                            text: model.modelData
                            color: YColors.white
                        }
                    }
                }

            }
            Column {
                // finished
                id: id_speech_wordtext
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 4
                bottomPadding: 4
                visible: resType == YEnum.WordTextResult
                Repeater {
                    model: {
                        let result = new Array;
                        let resRelate = content.result[0].text.split('\n')
                        resRelate.forEach(function(item){
                            let resSplite = item.split(/[\:|\：]/g);
                            result.push(('<font color="%3">%1</font> <p>%2').arg(resSplite[0]).arg(resSplite[1]).arg(YColors.red));
                        })
                        return result;
                    }

                    Rectangle{
                        color: YColors.grayNormal
                        radius: 12
                        anchors.left: id_speech_wordtext.left
                        anchors.right: id_speech_wordtext.right
                        height: id_speech_wordtext_info.height
                        YTextCH {
                            id: id_speech_wordtext_info
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            height: paintedHeight + 20
                            font.pixelSize: 18
                            textFormat: YText.RichText
                            wrapMode: YTextBase.Wrap
                            verticalAlignment: YTextBase.AlignVCenter
                            text: model.modelData
                            color: "#ffffff"
                        }
                    }
                }
            }
            Column {
                id: id_speech_peom
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10
                bottomPadding: 4
                visible: resType == YEnum.PoemResult || resType == YEnum.AuthorResult

                Repeater {
                    model: id_peom_model
                    Rectangle{
                        color: YColors.grayNormal
                        radius: 12
                        anchors.left: id_speech_peom.left
                        anchors.right: id_speech_peom.right
                        height: id_speech_peom_info.height
                        YTextCH {
                            id: id_speech_peom_info
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            height: paintedHeight + anchors.topMargin * 2
                            font.pixelSize: 16
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 21
                            textFormat: YText.RichText
                            verticalAlignment: YTextBase.AlignVCenter
                            text: peomInfo
                            color: YColors.grayText
                        }
                        YMouseArea {
                            id: id_repeater_item_mouse_area
                            anchors.fill: parent
                            onClicked:{
                                if (resType == YEnum.PoemResult){
                                    id_follow_drawer_layer.title = peomTitle;
                                    id_follow_drawer_layer.detail = content;
                                    speechManager.queryDetail(peomId, peomTitle)
                                }
                                else if (resType == YEnum.AuthorResult){
                                    id_follow_drawer_layer.title = peomTitle;
                                    id_follow_drawer_layer.detail = content;
                                    id_follow_drawer_layer.show();
                                }
                            }
                            objectName: "YSpeechPage.qml_id_repeater_item_mouse_area"
                        }
                    }
                }
            }
        }
    }
    TextMetrics {
        id: textMetrics
        font.family: qmlGlobal.fontFamily
        font.pixelSize: 16
        elide: Text.ElideRight
        elideWidth: 232
    }
    ListModel {
        id: id_peom_model
        Component.onCompleted: {
            content.result[0].result.forEach(function(item){
                console.log(JSON.stringify(item), item.type);
                let showtext = ""
                if (item.type == "AUTHOR"){
                    textMetrics.text = item.intro
                    showtext = ('<font size="4" color="#ffffff">%1</font> <p>%2').arg(item.name).arg(textMetrics.elidedText);
                    append({"peomInfo": showtext, "peomId": item.name, "peomTitle": item.name, "content": item.intro})
                }
                else if (item.type == "POEM"){
                    textMetrics.text = item.content
                    showtext = ('<font size="4" color="#ffffff">%1</font><p>%2(%3)<p>%4').arg(item.title).arg(item.author).arg(item.dynasty).arg(textMetrics.elidedText);
                    append({"peomInfo": showtext, "peomId": item.id, "peomTitle": item.title, "content": item.content})
                }
            })
        }
    }

    YSpeechPeomDetailDrawer {
        id: id_follow_drawer_layer
    }
    Connections {
        target: speechManager
        ignoreUnknownSignals: true
        onPoemDetailChanged: {
            let showText = ""
            let detail = JSON.parse(speechManager.poemDetail);
            if (detail.result.length > 0) {
                detail.result[0].content.forEach(function(item){
                    item.sentences.forEach(function(sentence){
                        showText += sentence.origin;
                        if (sentence.origin.charAt(sentence.origin.length - 1) != "，") {
                            showText += "<p>"
                        }
                    })
                })
                id_follow_drawer_layer.title = detail.query;
                id_follow_drawer_layer.detail = showText;
            }
            id_follow_drawer_layer.show();
        }
    }

}

/*

    "detail":{
        "intent":3,
        "question":"3+3",
        "result":"6"
    },
    "empty":false,
    "message":"3加3等于6",
    "result":null
    }

    {
        "detail":{
            "content":""兔子"是个多义词，它可以指兔（兔科兔属动物）,兔子（2014年索契冬奥会吉祥物）,兔子（伍美珍作品《同桌冤家》系列角色）,兔子（漫画《sp学园日常录》中的角色）,兔（十二生肖之一）,兔子（跑步运动中定速员(Pacemaker)）,兔子（《Minecraft》的生物）,兔子（英国动画短片）,兔子（男妓的隐语）,兔子（2017年澳大利亚电影）,兔子（街舞舞者）。",
            "intent":6,
            "title":"兔子"
        },
        "empty":false,
        "message":""兔子"是个多义词，它可以指兔（兔科兔属动物）,兔子（2014年索契冬奥会吉祥物）,兔子（伍美珍作品《同桌冤家》系列角色）,兔子（漫画《sp学园日常录》中的角色）,兔（十二生肖之一）,兔子（跑步运动中定速员(Pacemaker)）,兔子（《Minecraft》的生物）,兔子（英国动画短片）,兔子（男妓的隐语）,兔子（2017年澳大利亚电影）,兔子（街舞舞者）。",
        "result":null
    }

{
    "detail":{
        "city":"北京",
        "code":1,
        "day":"12月11日",
        "hi_temp":"5",
        "intent":1,
        "lo_temp":"-6",
        "weather":"晴",
        "week":"周五"
    },
    "empty":false,
    "message":"北京:周五,晴,最低气温-6度,最高气温5度",
    "result":null
}

{
    "detail":null,
    "empty":false,
    "message":null,
    "result":[
        {
            "link":"ydkiddict://kid-dict-youdao.com/query?query=达&type=CHAR",
            "result":null,
            "show":"TEXT",
            "speech":null,
            "text":"部首：辶",
            "title":"达",
            "type":"CHAR",
            "voice":null
        }
    ]
}
*/
