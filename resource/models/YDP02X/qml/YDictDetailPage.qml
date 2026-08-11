import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./dicts"
import "./i18n"

YBackButtonPage {
    id: id_dict_detail_page
    objectName: "YPage===YDictDetailPage.qml"
    pageIndex: YEnum.PageIndex.DictDetail

    property int dictType: YEnum.NoDict
    property string content: ""
    property bool isNewShow: false

    function getDictJsonObject(){
        try {
            let jsonObj = JSON.parse(content)
            if (typeof jsonObj == "object") {
                return jsonObj
            }
        } catch(e) {
            console.log("YDictDetailPage.qml === getDictJsonObject parse error: ", e)
        }
        return new Object
    }

    onContentChanged: {
        if(content.length) {
            isNewShow = false
            isNewShow = true
        }
        dictJson = getDictJsonObject()
    }

    readonly property var dictJson: {
        try {
            let jsonObj = JSON.parse(content)
            if (typeof jsonObj == "object") {
                return jsonObj
            }
        } catch(e) {
            console.log("YDictDetailPage.qml === dictJson parse error: ", e)
        }
        return new Object
    }
    property alias title: id_title_text.text
    property var showOxfordDetailMeaningblock: false
    property var showOxfordDetailMeaningblockName: ""
    property var backLastPos:null

    Flickable {
        id: id_container_flickable
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        z: id_dict_detail_page.z + 1
        contentHeight: id_dict_content_column.height
        interactive: !id_dict_content_loader.moving

        Column {
            id: id_dict_content_column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            YText {
                id: id_title_text
                width: parent.width
                height: 44
                //horizontalAlignment: YText.AlignHCenter
                verticalAlignment: YText.AlignVCenter
                font.pixelSize: 16
                color: YColors.grayText
            }

            YLoader {
                id: id_dict_content_loader
                asynchronous: false

                active: (YEnum.DtChLarge === dictType
                         || YEnum.DtChAncientWord === dictType
                         || YEnum.DtChPoemDict === dictType
                         || YEnum.DtChIdiom === dictType
                         //英文词典
                         || YEnum.DtOxford === dictType
                         || YEnum.DtSenior === dictType
                         || YEnum.DtWebster === dictType
                         || YEnum.DtEnChKid === dictType
                         //韩文词典
                         || YEnum.DtChKo === dictType
                         || YEnum.DtKoCh === dictType)
                        && JSON.stringify(dictJson) !== '{}'
                        && isNewShow
                sourceComponent: {
                    switch(title){
                    case YTranslateText.fixedCollocation:
                        return id_dt_mango_kid_english_fixed_collocation_component
                    case YTranslateText.synonymsAndSynonyms:
                        return id_dt_mango_kid_english_synonymsAndSynonyms_component
                    case YTranslateText.idiomStory:
                        return id_dt_idiom_story_component
                    case YTranslateText.idiomSource:
                        return id_dt_idiom_source_component
                    }
                    switch (dictType) {
                    case YEnum.DtChLarge:
                        return id_dt_ch_large_component
                    case YEnum.DtChAncientWord:
                        return id_dt_ch_ancientword_component
                    case YEnum.DtChPoemDict:
                        return id_dt_ch_poemdict_component
                    case YEnum.DtSenior:
                        return id_dt_senior_component
                    case YEnum.DtWebster:
                        return id_dt_webster_component
                    case YEnum.DtOxford:
                        return id_dt_oxford_component
                    case YEnum.DtChKo:
                        return id_dt_chko_component
                    case YEnum.DtKoCh:
                        return id_dt_koch_component
                    default:
                        return null
                    }
                }

                Component {
                    id: id_dt_mango_kid_english_synonymsAndSynonyms_component
                    YDictTypeDtMangoKidEnglishSynonymsAndSynonymsDetail{
                        width: id_dict_content_column.width
                    }
                }
                Component {
                    id: id_dt_mango_kid_english_fixed_collocation_component
                    YDictTypeDtMangoKidEnglishFixedCollocationDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_ch_large_component
                    YDictTypeDtChLargeDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_ch_ancientword_component
                    YDictTypeDtChAncientWordDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_ch_poemdict_component
                    YDictTypeDtChPoemDictDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_idiom_story_component
                    YDictTypeDtIdiomStoryDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_idiom_source_component
                    YDictTypeDtIdiomSourceDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_senior_component
                    YDictTypeDtSeniorDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_webster_component
                    YDictTypeDtWebsterDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_oxford_component
                    YDictTypeDtOxfordDetail {
                        width: id_dict_content_column.width

                        onShowMeaningblockChanged: {
                            console.log("YDictDetailPage.qml===id_dt_oxford_component.onShowMeaningblockChanged showMeaningblockName:", showMeaningblockName)
                            if (showMeaningblock) {
                                showOxfordDetailMeaningblockName = showMeaningblockName
                                id_container_flickable.contentY = 0
                            } else {
                                showOxfordDetailMeaningblockName = wordText
                            }
                            showOxfordDetailMeaningblock = showMeaningblock
                        }
                    }
                }

                Component {
                    id: id_dt_chko_component
                    YDictTypeDtChKoDetail {
                        width: id_dict_content_column.width
                    }
                }

                Component {
                    id: id_dt_koch_component
                    YDictTypeDtKoChDetail {
                        width: id_dict_content_column.width
                    }
                }

            }

            YSpacingForColumn {
                implicitHeight: 20
            }
        }
    }

    YIconButton {
        id: id_to_top_button
        opacity: mouseAreaItem.pressed || !enabled ? 0.2 : 1
        implicitWidth: 30
        implicitHeight: 30
        radius: height/2
        mouseAreaMargins: -10
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        imageName: "dict/to-top"
        sourceSize: Qt.size(24, 24)
        visible: id_container_flickable.contentY > id_container_flickable.height * 2
        onValidClicked: {
            id_container_flickable.contentY = 0
        }
    }

    ignoreDefaultBackButtonClicked: true
    onBackButtonClickedCallback: {
        if (showOxfordDetailMeaningblock) {
            if (id_dict_content_loader.isLoaded) {
                id_dict_content_loader.item.meaningblockType = -1
                id_dict_content_loader.item.showMeaningblock = false
                id_container_flickable.contentY = 0
                return
            }
        }
        backButtonClicked()
    }

    onShowOxfordDetailMeaningblockChanged: {
        title = showOxfordDetailMeaningblockName
        console.log("YDictDetailPage.qml===onShowOxfordDetailMeaningblockChanged title:", title)
    }

    Component.onDestruction: {
        console.log("YDictDetailPage.qml===Component.onDestruction===called")
    }

    onVisibleChanged: {
        if (visible) {
            id_container_flickable.contentY = 0
            if(backLastPos!=null){
                id_container_flickable.contentY = backLastPos
                backLastPos=null
            }
        } else {
            soundCenter.stop()
        }
    }
}
