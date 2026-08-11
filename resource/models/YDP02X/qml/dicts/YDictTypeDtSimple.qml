import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDictTypeBase {
    title: dictType === YEnum.DtSimple ? YTranslateText.dtSimple : YTranslateText.dtEnChKid

    Item {
        width: parent.width
        height: id_dict_content_column.height

        Column {
            id: id_dict_content_column
            width: parent.width
            spacing: 8

            YText {
                id: id_dict_content
                wrapMode: YText.Wrap
                textFormat: YTextBase.RichText
                width: parent.width
                height: paintedHeight
                lineHeightMode: Text.FixedHeight
                lineHeight: 28
                text: {
                    let sResult = ''
                    if (typeof dictJson.pure.m != "undefined") {
                        let mArray = dictJson.pure.m
                        mArray.forEach(function(mean){
                            if (typeof mean.pos !== "undefined") {
                                sResult += '<span style="font-family: Georgia; font-style: italic;'
                                        + (' color: %1; font-size: 14px">').arg(YColors.grayText) + mean.pos + '&nbsp;</span>'
                            }

                            sResult += '<span style="font-family: OPPOSans; font-weight: 500; '
                                    + ('color: %1;">').arg(YColors.white) + mean.m
                                    + '&nbsp;&nbsp;&nbsp;</span>'
                        })
                        if (typeof dictJson.pure.phonics != "undefined")
                            spellManager.phonics  = JSON.stringify(dictJson.pure.phonics);
                        else
                            spellManager.phonics = "";
                        return sResult
                    }
                    else if (typeof dictJson.pure.word != "undefined") {
                        let mArray = dictJson.pure.word.trs
                        mArray.forEach(function(mean){
                            if (typeof mean.pos !== "undefined") {
                                sResult += '<span style="font-family: Georgia; font-style: italic;'
                                        + (' color: %1; font-size: 14px">').arg(YColors.grayText) + mean.pos + '&nbsp;</span>'
                            }

                            if (typeof mean.tran !== "undefined") {
                                sResult += '<span style="font-family: OPPOSans; font-weight: 500; '
                                        + ('color: %1;">').arg(YColors.white) + mean.tran
                                        + '&nbsp;&nbsp;&nbsp;</span>'
                            }

                            if (typeof mean["#text"] !== "undefined") {
                                sResult += '<span style="font-family: Nunito Sans; '
                                        + (' color: %1;">').arg(YColors.white) + mean["#text"] + '&nbsp;</span>'
                            }

                            if (typeof mean["#tran"] !== "undefined") {
                                sResult += '<span style="font-family: OPPOSans; font-weight: 500; '
                                        + ('color: %1;">').arg(YColors.white) + mean["#tran"]
                                        + '&nbsp;&nbsp;&nbsp;</span>'
                            }
                        })

                        spellManager.phonics = "";
                        return sResult
                    }
                }
            }

            readonly property bool haveExample: typeof dictJson.example != "undefined" && dictType !== YEnum.DtEnChKid

            Column {
                width: parent.width
                spacing: 0
                visible: id_dict_content_column.haveExample

                YTextBase {
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamily
                    color: YColors.red
                    width: parent.width
                    height: 22
                    verticalAlignment: YTextBase.AlignBottom
                    text: YTranslateText.bilingualSentences
                    visible: id_dict_content_column.haveExample
                }

                YSpacingForColumn {
                    implicitHeight: 4
                }

                YText {
                    font.family: qmlGlobal.fontFamilyEnUs
                    textFormat: YTextBase.RichText
                    width: parent.width
                    height: paintedHeight
                    text: {
                        if (!visible) return ""
                        let sentpair = dictJson.example["sentence-pair"][0]
                        let qsRst = sentpair["sentence-eng"]
                        const regEx = new RegExp(resultManager.currentQuery, "ig")
                        qsRst = qsRst.replace(regEx, function(param){
                            return ("<font style='color:%2;font-family:%3;font-weight:500;'>%1</font>").arg(param).arg(YColors.red).arg(qmlGlobal.fontFamilyEnUs);
                        });
                        return qsRst
                    }
                    wrapMode: YTextMedium.Wrap
                    visible: id_dict_content_column.haveExample
                }

                YSpacingForColumn {
                    implicitHeight: 4
                }

                YText {
                    font.family: qmlGlobal.fontFamilyZhCn
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
                            qsRst += '<span style="color:#90919999;font-size:14px;">（'
                                    + YTranslateText.exampleSentencesFrom + sentpair["source"] + '）</span>'
                        }
                        return qsRst
                    }
                    visible: id_dict_content_column.haveExample
                }
            }

            readonly property bool haveWfs: typeof dictJson.pure.word.wfs != "undefined" && dictJson.pure.word.wfs.length > 0

            Column {
                width: parent.width
                spacing: 0
                visible: id_dict_content_column.haveWfs

                YTextBase {
                    font.pixelSize: 16
                    font.family: qmlGlobal.fontFamily
                    color: YColors.red
                    width: parent.width
                    height: 22
                    verticalAlignment: YTextBase.AlignBottom
                    text: YTranslateText.wordDifferentTenses
                    visible: id_dict_content_column.haveWfs
                }

                YSpacingForColumn {
                    implicitHeight: 4
                }

                Repeater {
                    id: id_dict_content_wfs_repeater
                    model: id_dict_content_column.haveWfs ? dictJson.pure.word.wfs : null

                    Row {
                        id: id_wfs_word_row
                        spacing: 4
                        width: id_dict_content_column.width
                        height: 27

                        readonly property string wfName: model.modelData.wf.name
                        readonly property string wfValue: model.modelData.wf.value

                        YText {
                            id: id_wfs_word_label
                            color: YColors.grayText
                            font.pixelSize: 16
                            width: contentWidth
                            height: contentHeight
                            anchors.bottom: parent.bottom
                            text: id_wfs_word_row.wfName + ":"
                        }

                        YText {
                            id: id_wfs_word_content
                            color: YColors.blueText
                            wrapMode: YText.Wrap
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            font.family: qmlGlobal.fontFamilyEnUs
                            width: parent.width - parent.spacing - id_wfs_word_label.width
                            height: contentHeight
                            text: id_wfs_word_row.wfValue

                            YMouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                onClicked: {
                                    console.log("YDictTypeDtSimple.qml====id_wfs_word_content wfs Word:", id_wfs_word_content.text)
                                    id_dict_page.requeryWord(id_wfs_word_content.text, "en", "zh-CHS")
                                }
                                objectName: "YDictTypeDtSimple.qml_id_wfs_word_content"
                            }
                        }
                    }
                }
            }
        }
    }
}

/*
  // explosive
{
    "example":{
        "sentence-pair":[
            {
                "sentence-eng":"The &lt;b&gt;explosive&lt;/b&gt; device was timed to go off at the rush hour.",
                "sentence-translation":"该爆炸装置定在交通高峰时间爆炸。",
                "source":"《柯林斯英汉双解大词典》"
            }
        ]
    },
    "pure":{
        "m":[
            {
                "m":"爆炸的；爆炸性的；爆发性的",
                "pos":"adj."
            },
            {
                "m":"炸药；爆炸物",
                "pos":"n."
            }
        ],
        "uk":"ɪkˈspləʊsɪv; ɪkˈspləʊzɪv",
        "us":"ɪkˈsploʊsɪv,ɪkˈsploʊzɪv"
    }
}
  */

