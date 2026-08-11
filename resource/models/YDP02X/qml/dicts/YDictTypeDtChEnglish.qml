import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDictTypeBase {
    title: dictType === YEnum.DtChEnglish ? YTranslateText.dtChEnglish : YTranslateText.dtChEnKid

    Item {
        width: parent.width
        height: id_dict_content_column.height

        Column {
            id: id_dict_content_column
            width: parent.width
            spacing: 10

            Repeater {
                id: id_dict_pure_repeater
                model: {
                    if (typeof dictJson.pure.word != "undefined") {
                        return dictJson.pure.word.trs
                    }
                    else {
                        return dictJson.pure
                    }
                }

                Column {
                    id: id_dict_word_container
                    width: id_dict_content_column.width
                    spacing: 4
                    property string enWord: {
                        if (typeof model.modelData.w != "undefined") {
                            return model.modelData.w
                        }
                        else {
                            return model.modelData["#text"]
                        }
                    }

                    property string chMean: {
                        if (typeof model.modelData.m != "undefined") {
                            let sResult = ""
                            let flag = 0
                            model.modelData.m.forEach(function(mean){
                                if (flag++ > 0) sResult += "; "
                                sResult += mean.m
                            })
                            return sResult
                        }
                        else if (typeof model.modelData["#tran"] != "undefined"){
                            return model.modelData["#tran"]
                        }
                        else {
                            return ""
                        }
                    }
                    YTextMedium {
                        id: id_dict_word
                        wrapMode: YText.Wrap
                        width: parent.width
                        height: paintedHeight
                        color: YColors.blueText
                        font.family: qmlTranslator.textIsEnglishOnly(text) ? qmlGlobal.fontFamilyEnUs : qmlGlobal.fontFamilyZhCn
                        text: id_dict_word_container.enWord
                        visible: text.length > 0

                        YMouseArea {
                            width: parent.width
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                //id_dict_page.requeryWord(qmlTranslator.getStartEnglistText(id_dict_word_container.enWord), "en", "zh-CHS")
                                id_dict_page.clickSearchWord(id_dict_word_container.enWord)
                            }
                            objectName: "YDictTypeDtChEnglish.qml_id_dict_trans"
                        }
                    }

                    YTextMedium {
                        id: id_dict_means
                        color: YColors.grayText
                        font.family: qmlGlobal.fontFamilyZhCn
                        width: parent.width
                        elide: Text.ElideRight
                        text: id_dict_word_container.chMean
                        visible: text.length > 0
                    }
                }

            } // Repeater id_dict_m_repeater

            readonly property bool haveExample: typeof dictJson.example != "undefined" && dictType !== YEnum.DtChEnKid
            Column {
                width: parent.width
                spacing: 4
                visible: id_dict_content_column.haveExample

                YTextBase {
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamily
                    font.weight: Font.Medium
                    color: YColors.red
                    width: parent.width
                    height: 24
                    verticalAlignment: YTextBase.AlignBottom
                    text: YTranslateText.bilingualSentences
                    visible: id_dict_content_column.haveExample
                }

                YText {
                    font.family: qmlGlobal.fontFamilyZhCn
                    textFormat: YTextBase.RichText
                    width: parent.width
                    height: paintedHeight
                    text: {
                        if (!visible) return ""
                        let sentpair = dictJson.example["sentence-pair"][0]
                        let qsRst = sentpair["sentence-eng"]
                        const regEx = new RegExp(resultManager.currentQuery, "ig")
                        qsRst = qsRst.replace(regEx, function(param){
                            return ("<font style='color:%2;font-family:%3;font-weight:500;'>%1</font>").arg(param).arg(YColors.red).arg(qmlGlobal.fontFamilyZhCn);
                        });
                        return qsRst
                    }
                    wrapMode: YTextMedium.Wrap
                    visible: id_dict_content_column.haveExample
                }

                YText {
                    font.family: qmlGlobal.fontFamilyEnUs
                    textFormat: YTextBase.RichText
                    wrapMode: YTextBase.Wrap
                    color: YColors.grayText
                    width: parent.width
                    height: paintedHeight
                    text: {
                        if (!visible) return ""
                        let sentpair = dictJson.example["sentence-pair"][0]
                        let qsRst = sentpair["sentence-translation"]
                        if (typeof sentpair.source != "undefined") {
                            qsRst += '<span style="color:#90919999;font-size:14px;font-family:'
                                    + qmlGlobal.fontFamilyZhCn + ';">（'
                                    + YTranslateText.exampleSentencesFrom + sentpair["source"] + '）</span>'
                        }
                        return qsRst
                    }
                    visible: id_dict_content_column.haveExample
                }

            }
        }
    }
}
/*
    // 明
{
    "example":{
        "sentence-pair":[
            {
                "sentence-eng":"她几乎不敢亮&lt;b&gt;明&lt;/b&gt;观点。",
                "sentence-translation":"She hardly dared to venture an opinion.",
                "source":"《牛津词典》"
            }
        ]
    },
    "pure":[
        {
            "m":[
                {
                    "m":"（颜色）明亮的，鲜艳的; 光线充足的；明亮的; 晴朗的；阳光明媚的; 聪明的",
                    "pos":"adj."
                }
            ],
            "phonics":[{"position":[0,1],"sound":"br"},{"position":[2,3,4],"sound":"aɪ"},{"position":[5],"sound":"t"}],
            "uk":"braɪt",
            "us":"braɪt",
            "w":"bright"
        },
        {
            "m":[
                {
                    "m":"清澈的；透明的; 清楚的；清晰的；明确的; 容易看见的；听得清的; 畅通无阻的；无障碍的",
                    "pos":"adj."
                },
                {
                    "m":"清除；清理",
                    "pos":"v."
                }
            ],
            "phonics":[{"position":[0,1],"sound":"kl"},{"position":[2,3,4],"sound":"ɪə"}],
            "uk":"klɪər",
            "us":"klɪr",
            "w":"clear"
        },
        {
            "m":[
                {
                    "m":"视力好的；有洞察力的；聪明的",
                    "pos":"adj."
                }
            ],
            "uk":"'klɪə'saɪtɪd",
            "us":"ˌklɪrˈsaɪtɪd",
            "w":"clearsighted"
        },
        {
            "m":[
                {
                    "m":"懂得；理解；领会; 体谅；谅解",
                    "pos":"v."
                }
            ],
            "phonics":[{"position":[0],"sound":"ʌ"},{"position":[1],"sound":"n_back"},{"position":[2],"sound":"d"},{"position":[3,4],"sound":"ə"},{"position":[5,6],"sound":"st_front"},{"position":[7],"sound":"æ"},{"position":[8,9],"sound":"nd"}],
            "uk":"ˌʌndəˈstænd",
            "us":"ˌʌndərˈstænd",
            "w":"understand"
        },
        {
            "m":[
                {
                    "m":"诚实的；可信的；正直的; 坦诚的；直率的",
                    "pos":"adj."
                }
            ],
            "phonics":[{"position":[0],"sound":""},{"position":[1],"sound":"ɒ"},{"position":[2],"sound":"n_front"},{"position":[3],"sound":"ɪ"},{"position":[4,5],"sound":"st_back"}],
            "uk":"ˈɒnɪst",
            "us":"ˈɑːnɪst",
            "w":"honest"
        }
    ]
}


{
    "source": {
        "name": "有道词典",
        "url": "http://dict.youdao.com"
    },
    "word": {
        "trs": [{
            "voice": "humiliation&type=2",
            "#text": "humiliation",
            "#tran": "丢脸，耻辱；蒙羞；谦卑；"
        }, {
            "voice": "shame&type=2",
            "#text": "shame",
            "#tran": "羞耻，羞愧；憾事，带来耻辱的人；使丢脸，使羞愧；(Shame)人名；(科特)沙梅；"
        }, {
            "voice": "exinanition&type=2",
            "#text": "exinanition",
            "#tran": "虚弱；屈辱；空竭；"
        }, {
            "voice": "humiliate&type=2",
            "#text": "humiliate",
            "#tran": "羞辱；使…丢脸；耻辱；"
        }],
        "phone": "xiū rǔ",
        "return-phrase": "羞辱"
    }
}
  */

