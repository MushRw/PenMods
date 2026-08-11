import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YSettingItemPage {
    id: id_setting_item
    objectName: "YPage===YSettingDict.qml"

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_label.height + id_ch_flow.height
                       + id_label_en.height + id_en_flow.height + 10

        YSettingItemTitle {
            id: id_label
            title: YTranslateText.dictionaryFirstWhenScanChinese
        }

        Flow {
            id: id_ch_flow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_label.bottom
            spacing: 8

            Repeater {
                model: qmlGlobal.language === YEnum.ZH_CN ? id_ch_model : id_ch_model_en

                YPressedButton {
                    implicitWidth: 256
                    clickable: dictIndex !== settingManager.topShowChDict
                    checkedIndicatorScale: dictIndex === settingManager.topShowChDict
                    onClicked: {
                        settingManager.topShowChDict = dictIndex
                    }
                    text: {
                        switch (dictIndex) {
                        case YEnum.DtChEnglish:
                            return YTranslateText.dtChEnglish
                        case YEnum.DtChEnKid:
                            return YTranslateText.dtChEnKid
                        case YEnum.DtChChinese:
                            return YTranslateText.dtChChinese
                        case YEnum.DtChLarge:
                            return YTranslateText.dtChLarge
                        case YEnum.DtChAncientWord:
                            return YTranslateText.dtChAncientWord
                        case YEnum.DtChPoemDict:
                            return YTranslateText.dtChPoemDict
                        case YEnum.DtChIdiom:
                            return YTranslateText.dtChIdiom
                        default:
                            return ""
                        }
                    }
                    pixelSize: currentPixelSize

                    YImage {
                        id: id_ch_dict_loading
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        imageName: "settings/loading"
                        visible: {
                            var show = settingManager.dictRemoedList.contains(srcName);
                            if (show) {
                                id_ch_dict_animation.start()
                            } else {
                                id_ch_dict_animation.stop()
                            }
                            return show;
                        }
                        RotationAnimator {
                            id: id_ch_dict_animation
                            target: id_ch_dict_loading
                            from: 0
                            to: 360
                            duration: 1000
                            running: false
                            loops: Animation.Infinite
                        }
                    }
                }
            }
        }

        YSettingItemTitle {
            id: id_label_en
            anchors.left: parent.left
            anchors.top: id_ch_flow.bottom
            title: YTranslateText.dictionaryFirstWhenScanEnglish
        }

        Flow {
            id: id_en_flow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_label_en.bottom
            spacing: 8

            Repeater {
                model: qmlGlobal.language === YEnum.ZH_CN ? id_en_model : id_en_model_en

                YPressedButton {
                    implicitWidth: 256
                    clickable: dictIndex !== settingManager.topShowDict
                    checkedIndicatorScale: dictIndex === settingManager.topShowDict
                    onClicked: {
                        settingManager.topShowDict = dictIndex
                    }
                    text: {
                        switch (dictIndex) {
                        case YEnum.DtSimple:
                            return YTranslateText.dtSimple
                        case YEnum.DtEnChKid:
                            return YTranslateText.dtEnChKid
                        case YEnum.DtSenior:
                            return YTranslateText.dtSenior
                        case YEnum.DtWebster:
                            return YTranslateText.dtWebsterSetting
                        case YEnum.DtOxford:
                            return YTranslateText.dtOxford
                        case YEnum.DtSSAT:
                            return YTranslateText.dtSSAT
                        case YEnum.DtSAT:
                            return YTranslateText.dtSAT
                        case YEnum.DtGRE:
                            return YTranslateText.dtGRE
                        case YEnum.DtTOEFL:
                            return YTranslateText.dtTOEFL
                        case YEnum.DtIELTS:
                            return YTranslateText.dtIELTS
                        default:
                            return ""
                        }
                    }
                    pixelSize: currentPixelSize

                    YImage {
                        id: id_dict_loading
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        imageName: "settings/loading"
                        visible: {
                            var show = settingManager.dictRemoedList.contains(srcName);
                            if (show) {
                                id_dict_animation.start()
                            } else {
                                id_dict_animation.stop()
                            }
                            return show;
                        }
                        RotationAnimator {
                            id: id_dict_animation
                            target: id_dict_loading
                            from: 0
                            to: 360
                            duration: 1000
                            running: false
                            loops: Animation.Infinite
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: id_ch_model

        Component.onCompleted: {
            append({"dictIndex": YEnum.DtChEnglish, "currentPixelSize": 16, "srcName": "ceV2.dat"})
//            append({"dictIndex": YEnum.DtChEnKid, "currentPixelSize": 16, "srcName": "cekidV2.dat"})
            append({"dictIndex": YEnum.DtChChinese, "currentPixelSize": 16, "srcName": "charV2.dat"})
            if (qmlGlobal.checkFeature(YEnum.FEATURE_DICT_CHLARGE)) {
                append({"dictIndex": YEnum.DtChLarge, "currentPixelSize": 16, "srcName": "ce-largeV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_ANCIENTPOEM)) {
                append({"dictIndex": YEnum.DtChAncientWord, "currentPixelSize": 16, "srcName": "ancientwordV2.dat"})
                append({"dictIndex": YEnum.DtChPoemDict, "currentPixelSize": 16, "srcName": "poem_dataV2.dat"})
            }
            append({"dictIndex": YEnum.DtChIdiom, "currentPixelSize": 16, "srcName": "idiomV2.dat"})
        }
    }

    ListModel {
        id: id_ch_model_en

        Component.onCompleted: {
            append({"dictIndex": YEnum.DtChEnglish, "currentPixelSize": 14, "srcName": "ceV2.dat"})
//            append({"dictIndex": YEnum.DtChEnKid, "currentPixelSize": 14, "srcName": "cekidV2.dat"})
            append({"dictIndex": YEnum.DtChChinese, "currentPixelSize": 14, "srcName": "charV2.dat"})
            if (qmlGlobal.checkFeature(YEnum.FEATURE_DICT_CHLARGE)) {
                append({"dictIndex": YEnum.DtChLarge, "currentPixelSize": 16, "srcName": "ce-largeV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_ANCIENTPOEM)) {
                append({"dictIndex": YEnum.DtChAncientWord, "currentPixelSize": 14, "srcName": "ancientwordV2.dat"})
                append({"dictIndex": YEnum.DtChPoemDict, "currentPixelSize": 14, "srcName": "poem_dataV2.dat"})
            }
            append({"dictIndex": YEnum.DtChIdiom, "currentPixelSize": 16, "srcName": "idiomV2.dat"})
        }
    }

    ListModel {
        id: id_en_model

        Component.onCompleted: {
            append({"dictIndex": YEnum.DtSimple, "currentPixelSize": 16, "srcName": "ecV2.dat"})
            append({"dictIndex": YEnum.DtEnChKid, "currentPixelSize": 16, "srcName": "eckidV2.dat"})
            if (qmlGlobal.checkFeature(YEnum.FEATURE_DICT_SENIOR)) {
                append({"dictIndex": YEnum.DtSenior, "currentPixelSize": 16, "srcName": "seniordictV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_WEBSTER)) {
                append({"dictIndex": YEnum.DtWebster, "currentPixelSize": 16, "srcName": "websterV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_OXFORD)) {
                append({"dictIndex": YEnum.DtOxford, "currentPixelSize": 16, "srcName": "oxfordV2.dat"})
            }
            append({"dictIndex": YEnum.DtSSAT, "currentPixelSize": 16, "srcName": "ssatV2.dat"})
            append({"dictIndex": YEnum.DtSAT, "currentPixelSize": 16, "srcName": "satV2.dat"})
            append({"dictIndex": YEnum.DtGRE, "currentPixelSize": 16, "srcName": "greV2.dat"})
            append({"dictIndex": YEnum.DtTOEFL, "currentPixelSize": 16, "srcName": "toeflV2.dat"})
            append({"dictIndex": YEnum.DtIELTS, "currentPixelSize": 16, "srcName": "ieltsV2.dat"})
        }
    }

    ListModel {
        id: id_en_model_en

        Component.onCompleted: {
            append({"dictIndex": YEnum.DtSimple, "currentPixelSize": 14, "srcName": "ecV2.dat"})
            append({"dictIndex": YEnum.DtEnChKid, "currentPixelSize": 14, "srcName": "eckidV2.dat"})
            if (qmlGlobal.checkFeature(YEnum.FEATURE_DICT_SENIOR)) {
                append({"dictIndex": YEnum.DtSenior, "currentPixelSize": 16, "srcName": "seniordictV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_WEBSTER)) {
                append({"dictIndex": YEnum.DtWebster, "currentPixelSize": 14, "srcName": "websterV2.dat"})
            }
            if (qmlGlobal.checkFeature(YEnum.FEATURE_OXFORD)) {
                append({"dictIndex": YEnum.DtOxford, "currentPixelSize": 16, "srcName": "oxfordV2.dat"})
            }
            append({"dictIndex": YEnum.DtSSAT, "currentPixelSize": 16, "srcName": "ssatV2.dat"})
            append({"dictIndex": YEnum.DtSAT, "currentPixelSize": 16, "srcName": "satV2.dat"})
            append({"dictIndex": YEnum.DtGRE, "currentPixelSize": 16, "srcName": "greV2.dat"})
            append({"dictIndex": YEnum.DtTOEFL, "currentPixelSize": 16, "srcName": "toeflV2.dat"})
            append({"dictIndex": YEnum.DtIELTS, "currentPixelSize": 16, "srcName": "ieltsV2.dat"})
        }
    }
}


