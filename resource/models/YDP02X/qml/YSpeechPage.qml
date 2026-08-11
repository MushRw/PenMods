import QtQuick 2.12
import com.youdao.pen 1.0

import "./components"
import "./commons"
import "./i18n"

// 语音助手页面
YPage {
    id: id_touch_talk_page
    objectName: "YPage===YSpeechPage.qml"
    pageIndex: YEnum.PageIndex.Speech

    Item {
        id: id_touch_talk_views
        anchors.fill: parent
        opacity: id_pop_layer.isShowing ? 0 : 1

        YVerticalTitleBar {
            id: id_title_bar
            onCallBack: {
                backButtonClicked();
            }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10
            anchors.topMargin: 12
            visible: id_listening_animation.running

            YText {
                id: id_listening_title
                font.pixelSize: 19
                width: parent.width
                textFormat: YTextMedium.RichText
                lineHeight: 28
                lineHeightMode: YTextMedium.FixedHeight
                wrapMode: YTextBase.Wrap
                text: YTranslateText.imListening
            }

            YWaveForm {
                id: wave_form
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 52
                amplitude: speechManager.amptitude
            }

        }

        Flickable {
            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10
            contentHeight: id_column.height
            visible: !id_listening_animation.running

            Column {
                id: id_column
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8
                topPadding: 12
                bottomPadding: 10

                YText {
                    id: id_tip_title
                    font.pixelSize: 19
                    width: parent.width
                    textFormat: YTextMedium.RichText
                    lineHeight: 28
                    lineHeightMode: YTextMedium.FixedHeight
                    wrapMode: YTextBase.Wrap
                    text: YTranslateText.longPressedAudioHelper.arg(YColors.red)
                }

                Repeater {
                    model: 6
                    Rectangle{
                        id: id_example_text_rect
                        color: YColors.grayNormal
                        height: 50
                        radius: height / 2
                        width: parent.width
                        YTextBase {
                            id: id_example_text
                            anchors.centerIn: parent
                            font.pixelSize: 18
                            color: YColors.grayText
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: {
                                switch (index) {
                                case 0:
                                    return YTranslateText.exampleText0
                                case 1:
                                    return YTranslateText.exampleText1
                                case 2:
                                    return YTranslateText.exampleText2
                                case 3:
                                    return YTranslateText.exampleText3
                                case 4:
                                    return YTranslateText.exampleText4
                                case 5:
                                    return YTranslateText.exampleText5
                                default:
                                    return ""
                                }
                            }

                            horizontalAlignment : YText.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (speechManager.recognizing === YEnum.AS_ASRBegin ){
            id_listening_animation.running = true;
            wave_form.start()
        } else {
            wave_form.stop()
            id_listening_animation.running = false;
        }
    }

    Component.onDestruction: {
        console.log("YSpeechPage.qml===Component.onDestruction===called")
    }

    SequentialAnimation {
        id: id_listening_animation
        loops: SequentialAnimation.Infinite
        running: false
        PropertyAction { target: id_listening_title; property: "text"; value: YTranslateText.imListening + "..." }
        PauseAnimation { duration: 420 }
        PropertyAction { target: id_listening_title; property: "text"; value: YTranslateText.imListening }
        PauseAnimation { duration: 420 }
        PropertyAction { target: id_listening_title; property: "text"; value: YTranslateText.imListening + "." }
        PauseAnimation { duration: 420 }
        PropertyAction { target: id_listening_title; property: "text"; value: YTranslateText.imListening + ".." }
        PauseAnimation { duration: 420 }
    }

    YPopLayer {
        id: id_pop_layer
        function showPage(qrcqml, properties) {
            console.warn("ZDS==================================qrcqml： ", qrcqml)
            show(qrcqml, false, properties)
            currentShowPage = popItemObject
            currentShowPage.backButtonClicked.connect(function(){
                soundCenter.stop();
                currentShowPage = null
            })
        }
    }

    property var currentShowPage: null

    Connections {
        target: speechManager
        ignoreUnknownSignals: true
        enabled: id_touch_talk_page.visible
        onRecognizingChanged: {
            if (speechManager.recognizing >= YEnum.AS_ASRBegin ){
                if (currentShowPage != null)
                    currentShowPage.backButtonClicked();
                id_listening_animation.running = true;
                wave_form.start()
            } else {
                id_listening_animation.running = false;
                wave_form.stop()
                if (bot.speechAssistant) {
                    backButtonClicked()
                }
            }
        }
        onContentChanged: {
            console.warn("YSpeechPage.qml===", speechManager.content);
            let resJson = JSON.parse(speechManager.content);
            let resType = 0;
            let playTextInfo = "";
            if (resJson.detail !== null){
                if (resJson.detail.keyword == "unknow")
                    resType = YEnum.IntroductionResult
                switch (resJson.detail.intent)
                {
                case 0://设置音量、亮度
                {
                    switch (resJson.detail.action)
                    {
                        case 1:{
                            // 音量
                            id_pop_layer.showPage("assistant/YSpeechVolmn");

                            if (null !== currentShowPage) {
                                switch (resJson.detail.keyword)
                                {
                                    case 1:{
                                        let res = Math.max(0, settingManager.spkVolume - 10)
                                        settingManager.setSpkVolume(res)
                                        if (res == 0)
                                            currentShowPage.title = YTranslateText.volumeMin
                                        else
                                            currentShowPage.title = YTranslateText.volumeDown
                                    }
                                    break;
                                    case 2:{
                                        let res = Math.min(100, settingManager.spkVolume + 10)
                                        settingManager.setSpkVolume(Math.min(100,settingManager.spkVolume + 10))
                                        if (res == 100)
                                            currentShowPage.title = YTranslateText.volumeMax
                                        else
                                            currentShowPage.title = YTranslateText.volumeUp
                                    }
                                    break;
                                    case 3:{
                                        settingManager.setSpkVolume(100)
                                        currentShowPage.title = YTranslateText.volumeMax
                                    }
                                    break;
                                    case 4:{
                                        settingManager.setSpkVolume(1)
                                        currentShowPage.title = YTranslateText.volumeMin
                                    }
                                    break;
                                    case 5:{
                                        settingManager.setSpkVolume(0)
                                        currentShowPage.title = YTranslateText.volumeMute
                                    }
                                    break;
                                    case 6:{
                                        settingManager.setSpkVolume(80)
                                        currentShowPage.title = YTranslateText.volumeAdjust
                                    }
                                    break;
                                }
                            }
                            return;
                        }
                        case 2:{
                            // 亮度
                            id_pop_layer.showPage("settingpages/YSettingBrightness");
                            if (null !== currentShowPage) {
                                switch (resJson.detail.keyword)
                                {
                                    case 1:
                                        let res = Math.min(100, settingManager.lcdBrightness + 10)
                                        settingManager.setLcdBrightness(res)
                                        if (res === 100)
                                            currentShowPage.title = YTranslateText.brightnessMax
                                        else
                                            currentShowPage.title = YTranslateText.brightnessUp
                                    break;
                                    case 2:
                                        settingManager.setLcdBrightness(Math.max(0, settingManager.lcdBrightness - 10))
                                        if (res === 0)
                                            currentShowPage.title = YTranslateText.brightnessMin
                                        else
                                            currentShowPage.title = YTranslateText.brightnessDown
                                    break;
                                    case 3:
                                        settingManager.setLcdBrightness(100)
                                        currentShowPage.title = YTranslateText.brightnessMax
                                    break;
                                    case 4:
                                        settingManager.setLcdBrightness(0)
                                        currentShowPage.title = YTranslateText.brightnessMin
                                    break;
                                    case 5:
                                        settingManager.setLcdBrightness(80)
                                        currentShowPage.title = YTranslateText.brightnessAdjust
                                    break;
                                }
                            }
                            return;
                        }
                        default:
                            resType = YEnum.IntroductionResult
                    }
                }
                case 1://查询天气
                    resType = YEnum.WeatherResult
                    break;
                case 3://计算
                    resType = YEnum.CalcResult
                    break;
                case 6://百科
                    resType = YEnum.WikiResult
                    break;
                default:
                    resType = YEnum.IntroductionResult
                }
            } else {
                if (resJson == null)
                    resType = YEnum.IntroductionResult
                else{
                    if (resJson.result == null)
                        resType = YEnum.IntroductionResult
                    else
                    {
                        let sShow = resJson.result[0].show;
                        let sType = resJson.result[0].type;

                        console.log(sShow, sType, "##########");
                        if (sShow == "INTRODUCTION") {
                            resType = YEnum.IntroductionResult;
                        }
                        else if (sShow == "SENTENCES") {
                            resType = YEnum.SentenceResult;
                        }
                        else if (sShow == "PRONOUNCE") {
                            resType = YEnum.PronounceResult;
                        }
                        else if (sShow == "DETAILS") {
                            if (sType == "POEM"){
                                resType = YEnum.PoemResult;
                            }
                            else if (sType == "AUTHOR") {
                                resType = YEnum.AuthorResult;
                            }
                            else if (sType == "WORD" || sType == "IDIOM"){
                                resType = YEnum.WordCHDetailResult;
                            }
                            else if (sType == "CHAR") {
                                resType = YEnum.CharDetailResult;
                            }
                            else if (sType == "EN_WORD" || sType == "CN_EN") {
                                resType = YEnum.WordENDetailResult;
                            }
                            else if (sType == null){
                                resType = YEnum.ExplainDetailResult;
                            }
                        }
                        else if (sShow == "MEANING") {
                            if (sType == "IDIOM") {
                                resType = YEnum.IdiomMeanResult;
                            }
                            else if (sType == "WORD" || sType == "CHAR") {
                                playTextInfo = resJson.result[0].title
                                resType = YEnum.WordCHMeanResult;
                            }
                            else if(sType == "EN_WORD") {
                                resType = YEnum.WordENMeanResult;
                            }
                        }
                        else if (sShow == "TEXT") {
                            if (resJson.result[0].speech !== null) {
                                playTextInfo = resJson.result[0].speech;
                                resType = YEnum.CommonTextResult;
                            }
                            if (sType == "EN_WORD" || sType == "CHAR") {
                                resType = YEnum.WordTextResult;
                            }
                        }
                        else
                            resType = YEnum.CommonTextResult;
                    }
                    console.log(resType)
                }
            }
            if (playTextInfo.length == 0){
                playTextInfo = resJson.message;
            }
            qmlGlobal.audioPlayId = soundCenter.play(playTextInfo, "ch");
            id_pop_layer.showPage("assistant/YSpeechDetail", {"resType": resType});
        }
    }

    Connections {
        target: qmlGlobal
        enabled: bot.speechAssistant
        function onCurrentPageIndexChanged() {
            console.warn("onCurrentPageIndexChanged")
            if (qmlGlobal.currentPageIndex != YEnum.PageIndex.Speech) {
                backButtonClicked()
            }
        }
    }

}
