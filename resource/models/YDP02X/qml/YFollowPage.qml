import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./components"
import "./i18n"
import QtGraphicalEffects 1.14

YBackButtonPage {
    id: id_follow_item
    objectName: "YPage===YFollowPage.qml"
    pageIndex: YEnum.PageIndex.Follow

    property var recognisePersistant : new Array;
    property alias score_on : id_follow_star_on.model;
    property alias score_off : id_follow_star_off.model;
    readonly property var wordslist : followManager.content.split(/([\ |\~|\`|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\-|\_|\+|\=|\||\\|\[|\]|\{|\}|\;|\:|\"|\'|\,|\<|\.|\>|\/|\?|\s+])/g);

    Flickable {
        id: id_follow_content_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 26
        contentHeight: id_follow_content_column.height

        Column {
            id: id_follow_content_column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            YSpacingForColumn {
                implicitHeight: id_follow_content.lineCount > 1 ? 6 : 20
            }

            YTextMedium {
                id: id_follow_content
                height: paintedHeight
                font.pixelSize: 20
                horizontalAlignment: Qt.AlignHCenter
                textFormat: YText.RichText
                lineHeightMode: Text.FixedHeight
                lineHeight: 27
                wrapMode: YTextBase.WrapAtWordBoundaryOrAnywhere
                width: parent.width
                text: {
                    try{
                        var phoneticSymbolJson = JSON.parse(followManager.result);
                    } catch(e){}
                    var res = "";
                    if (typeof phoneticSymbolJson != "undefined" &&
                            typeof phoneticSymbolJson.isFinal != "undefined"
                            && followManager.ukPhonetic.length === 0
                            &&followManager.usPhonetic.length === 0 ){
                        //最终结果
                        let mistakewords = ""
                        if (typeof phoneticSymbolJson.isFinal != "undefined" && phoneticSymbolJson.isFinal && !followManager.isRecording){
                            console.log(JSON.stringify(phoneticSymbolJson.words));
                            for (var i = 0; i < phoneticSymbolJson.words.length; i++){
                                if (phoneticSymbolJson.words[i].pronunciation < 60){
                                    res += ('<font color="%2">%1</font>'.arg(phoneticSymbolJson.words[i].word).arg(YColors.red));
                                    mistakewords += phoneticSymbolJson.words[i].word + "_"
                                } else {
                                    res += (phoneticSymbolJson.words[i].word);
                                }
                                res += " "
                            }
                            if (followManager.classLog.length > 0) {
                                let qsLog = "resource_spesentence=" + followManager.content +
                                        "&resource_sentence_pronunciation_view=" + phoneticSymbolJson.pronunciation +
                                        "&resource_sentence_fluency_view=" + phoneticSymbolJson.fluency +
                                        "&resource_sentence_integrity_view=" + phoneticSymbolJson.integrity +
                                        "&resource_sentence_overall_view=" + phoneticSymbolJson.overall +
                                        "&resource_repeat_speed_view=" + phoneticSymbolJson.speed +
                                        "&resource_wrong_sentencepronunciation_view=" + mistakewords;
                                        + followManager.classLog;
                                //console.log(qsLog);
                                logManager.sendClassAudioLogToServer(qsLog);
                            }
                        }
                        //中间结果
                        ///console.log("@@@@@@@@@@!!" + phoneticSymbolJson.isFinal)
                        if (!phoneticSymbolJson.isFinal)
                        {
                            recognisePersistant.push(phoneticSymbolJson.refText)
                            for (i = 0; i < wordslist.length; i++){
                                if (recognisePersistant.indexOf(wordslist[i]) >= 0) {
                                    res += ('<font color="%2">%1</font>'.arg(wordslist[i]).arg(YColors.blueText));
                                }else {
                                    res += wordslist[i];
                                }
                                console.log(res)
                            }
                        }
                    }
                    if (res.length === 0) {
                        res = followManager.content;
                    }
                    return ('<span style="font-family: %1;">%2</span>')
                    .arg(qmlGlobal.fontFamilyEnUk).arg(res)

                }
            }

            Item {
                id: id_row_pron
                anchors.horizontalCenter: parent.horizontalCenter
                height: id_follow_phonetic.height
                width: id_follow_pron_switch_button.width + 6 + id_follow_phonetic.width
                visible: followManager.ukPhonetic.length > 0 || followManager.usPhonetic.length > 0

                YIconLabelButton {
                    id: id_follow_pron_switch_button
                    textFontFamily: qmlGlobal.fontFamily
                    leftMargin: 0
                    rightMargin: 0
                    height: 24
                    spacing: 4
                    source: "follow/switch"
                    sourceSize: Qt.size(24, 24)
                    textFormat: YText.PlainText
                    color: YColors.black
                    textColor: YColors.grayText
                    enabled: !id_sound_play.playing
                    text: followManager.isUk ? YTranslateText.shorthandEN
                                             : YTranslateText.shorthandUS
                    onValidClicked: {
                        followManager.isUk = !followManager.isUk
                    }
                }

                YText {
                    id: id_follow_phonetic
                    anchors.left: id_follow_pron_switch_button.right
                    anchors.leftMargin: 6
                    textFormat: YText.RichText
                    wrapMode: YTextBase.WrapAnywhere
                    color: YColors.grayText
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 24
                    width: id_follow_phonetic_content.width > 180 ? 180 : id_follow_phonetic_content.width
                    text: {
                        if (followManager.result !== "" && !followManager.isRecording) {
                            var score = 0
                            var res = ""
                            var phoneticSymbolJson = JSON.parse(followManager.result);
                            if (typeof phoneticSymbolJson.words != "undefined"){
                                for (var i = 0;i < phoneticSymbolJson.words[0].phonemes.length ; i++){
                                    if (phoneticSymbolJson.words[0].phonemes[i].pronunciation < 60){
                                        res += ('<font color="%2">%1</font>'.arg(phoneticSymbolJson.words[0].phonemes[i].phoneme).arg(YColors.red));
                                    } else {
                                        res += (phoneticSymbolJson.words[0].phonemes[i].phoneme);
                                    }
                                }
                                //console.log(JSON.stringify(phoneticSymbolJson));
                                score = phoneticSymbolJson.overall;
                            }
                            else {
                                res += ('<font color="%2">%1</font>'.arg(followManager.isUk? followManager.ukPhonetic: followManager.usPhonetic).arg(YColors.red));
                            }

                            if (score > 90){
                                score_off = 0
                                score_on = 5
                            }
                            else if (score >80){
                                score_off = 1
                                score_on = 4
                            }
                            else if (score >60){
                                score_off = 2
                                score_on = 3
                            }
                            else if (score >40){
                                score_off = 3
                                score_on = 2
                            }
                            else {
                                score_off = 4
                                score_on = 1
                            }
                            id_score_item.visible = true
                            id_score_animation.start()
                            if (followManager.isUk){
                                return ('&nbsp;/<span style="font-family: %1;">%2</span>/')
                                .arg(qmlGlobal.fontFamilyEnUk).arg(res)
                            }
                            else{
                                return ('&nbsp;/<span style="font-family: %1; ">%2</span>/')
                                .arg(qmlGlobal.fontFamilyEnUs).arg(res)
                            }

                        }
                        else
                        {
                            if (followManager.isUk && followManager.ukPhonetic.length !== 0) {
                                return ('&nbsp;/<span style="font-family: %1;">%2</span>/')
                                .arg(qmlGlobal.fontFamilyEnUk).arg(followManager.ukPhonetic)
                            } else if (followManager.usPhonetic.length !== 0) {
                                return ('&nbsp;/<span style="font-family: %1;">%2</span>/')
                                .arg(qmlGlobal.fontFamilyEnUs).arg(followManager.usPhonetic)
                            } else
                                return ""
                        }
                    }

                    YText {
                        id: id_follow_phonetic_content
                        textFormat: YText.RichText
                        text: id_follow_phonetic.text
                        width: paintedWidth
                        visible: false
                    }
                }
            }

            Item {
                id: id_score_item
                height: 24
                width: 120
                anchors.horizontalCenter: parent.horizontalCenter
                onVisibleChanged: {
                    if (!visible) {
                        id_score.width = 1
                    }
                    else {
                        id_follow_content_flickable.contentY = id_follow_content_flickable.contentHeight
                    }
                }
                Row {
                    id: id_score
                    clip: true
                    Repeater {
                        id : id_follow_star_on
                        YImage {
                            sourceSize: Qt.size(24, 24)
                            imageName: "follow/star_on"
                        }
                    }
                    Repeater {
                        id : id_follow_star_off
                        YImage {
                            sourceSize: Qt.size(24, 24)
                            imageName: "follow/star_off"
                        }
                    }

                    SequentialAnimation {
                        id: id_score_animation
                        loops: 1
                        running: false
                        PropertyAction { target: id_score; property: "width"; value: 1; }
                        PauseAnimation { duration: 100 }
                        PropertyAction { target: id_score; property: "width"; value: 24 }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: id_score; property: "width"; value: 48 }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: id_score; property: "width"; value: 72 }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: id_score; property: "width"; value: 96 }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: id_score; property: "width"; value: 120 }
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 60
            }
        }
    }

    Item {
        anchors.left: id_follow_content_flickable.left
        anchors.right: id_follow_content_flickable.right
        anchors.bottom: parent.bottom
        height: 60
        clip: true

        ShaderEffectSource {
            id: id_effect_source
            anchors.fill: parent
            sourceItem: id_follow_content_flickable
            sourceRect: Qt.rect(0, id_follow_item.height - height, width, height)
            visible: false
        }

        FastBlur {
            anchors.fill: parent
            source: id_effect_source
            radius: 32
        }
    }

    YBackgroundIgnoreMouseEvent {
        anchors.left: id_follow_content_flickable.left
        anchors.right: id_follow_content_flickable.right
        anchors.bottom: parent.bottom
        height: 60
        color: YColors.black
        opacity: 0.9

        YFollowIconsButton {
            id: id_sound_play
            anchors.centerIn: parent
            width: 64
            height: 46
            radius: height / 2
            color: YColors.red
            onValidClicked: {
                soundCenter.forceStop();
                if (playing) {
                    stop();
                    followManager.stopFollow();
                    recognisePersistant = [];
                }
                else {
                    play()
                    id_score_item.visible = false
                    followManager.startFollow(followManager.content,
                                              followManager.isUk ? followManager.ukPhonetic : followManager.usPhonetic, 10);
                }
            }
            onPlayingChanged: {
            }
        }

        YIconButton {
            id: id_follow_content_pron
            anchors.verticalCenter: id_sound_play.verticalCenter
            anchors.right: id_sound_play.left
            anchors.rightMargin: 34
            width: 40
            height: 40
            radius: height / 2
            enabled: !id_sound_play.playing
            source: "follow/play_content"
            sourceSize: Qt.size(24, 24)
            //visible: !(followManager.ukPhonetic.length > 0 || followManager.usPhonetic.length > 0)
            onValidClicked: {
                soundCenter.play(followManager.content, "en",
                         followManager.content,
                         followManager.isUk ? 1 : 2)
            }
        }

        YIconButton {
            id: id_follow_my_pron
            anchors.verticalCenter: id_sound_play.verticalCenter
            anchors.left: id_sound_play.right
            anchors.leftMargin: 34
            width: 40
            height: 40
            radius: height / 2
            enabled: !id_sound_play.playing
            source: "follow/play_my"
            sourceSize: Qt.size(24, 24)
            //visible: !(followManager.ukPhonetic.length > 0 || followManager.usPhonetic.length > 0)
            onValidClicked: {
                soundCenter.playFileData("/tmp/cursound")
            }
        }
    }

    Connections {
        target: followManager
        ignoreUnknownSignals: true
        onVadStop: {
            id_sound_play.validClicked();

        }
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        onOcrStart: {
            backButtonClicked()

        }
    }
    Component.onCompleted: {
        id_sound_play.validClicked();
        id_sound_play.play()
    }

    onBackButtonClicked: {
        followManager.stopFollow();
    }
    Component.onDestruction: {
        console.log("YFollowPage.qml===Component.onDestruction===called")
    }

}
