import QtQuick 2.12
import QtQml.Models 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Item {
    property bool isNeedNetTip: true
    property string selectedStage: ""
    property string selectedGrade: ""
    readonly property int btnWidth: 124
    readonly property int btnSpaceH: 8
    readonly property int btnSpaceV: 8
    anchors.fill: parent

    onSelectedStageChanged: {
        selectedGrade = ""
    }

    Flickable {
        id: id_setting_item_view
        anchors.fill: parent
        contentHeight: id_select_content_column.height

        Column {
            id: id_select_content_column
            width: parent.width
            spacing: 0

            YSpacingForColumn {
                implicitHeight: 10
            }

            Text {
                width: parent.width
                height: 20
                font.family: qmlGlobal.fontFamilyZhCn
                textFormat: YText.PlainText
                font.pixelSize: 16
                color: YColors.grayText
                text: YTranslateText.textbookSelectStage
            }

            YSpacingForColumn {
                implicitHeight: 16
            }

            Grid {
                id: id_select_stage_btn_grid
                columns: 2
                columnSpacing: btnSpaceH
                rowSpacing: btnSpaceV

                Repeater {
                    model: id_stage_show_model

                    YPressedButton {
                        implicitWidth: btnWidth
                        clickable: stage !== selectedStage
                        checkedIndicatorScale: stage === selectedStage
                        onClicked: {
                            selectedStage = stage
                        }
                        textItem.font.family: qmlGlobal.fontFamilyZhCn
                        text: stageTitle
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 18
            }

            Text {
                width: parent.width
                height: 20
                font.family: qmlGlobal.fontFamilyZhCn
                textFormat: YText.PlainText
                font.pixelSize: 16
                color: YColors.grayText
                text: YTranslateText.textbookSelectGrade
            }

            YSpacingForColumn {
                implicitHeight: 10
            }

            Grid {
                id: id_select_grade_btn_grid
                columns: 2
                columnSpacing: btnSpaceH
                rowSpacing: btnSpaceV

                Repeater {
                    model: id_grade_show_model

                    YPressedButton {
                        visible: stage === selectedStage
                        implicitWidth: btnWidth
                        clickable: gradeId !== selectedGrade
                        checkedIndicatorScale: gradeId === selectedGrade
                        color: YColors.grayButton
                        onClicked: {
                            selectedGrade = gradeId
                        }
                        textItem.font.family: qmlGlobal.fontFamilyZhCn
                        text: title
                    }
                }
            }

            YSpacingForColumn {
                implicitHeight: 14
            }
        }
    }

    ListModel {
        id: id_stage_show_model
    }

    ListModel {
        id: id_grade_show_model
    }

    Connections {
        target: textBookManager
        ignoreUnknownSignals: true
        function onGradesLoadReady() {
            console.trace()
            id_stage_show_model.clear()
            id_grade_show_model.clear()
            let gradesList = textBookManager.getGradesList()
            let stageList = []
            let stageObjList = []
            gradesList.forEach(function(gradeObj){
                if (gradeObj.gradeId === settingManager.defaultGradeId) {
                    selectedStage = gradeObj.stage
                    selectedGrade = gradeObj.gradeId
                }
                if (stageList.indexOf(gradeObj.stage) < 0) {
                    stageList.push(gradeObj.stage)
                    stageObjList.push(gradeObj)
                }
            })
            id_stage_show_model.append(stageObjList)
            id_grade_show_model.append(gradesList)
            if (selectedStage.length <= 0 && id_stage_show_model.count > 0) {
                selectedStage = id_stage_show_model.get(0).stage
            }
        }
    }

    Component.onCompleted: {
        if (id_grade_show_model.count <= 0) {
            if (isNeedNetTip && !wifiManager.internetConnect) {
                qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
            }
            textBookManager.loadAllGrades()
        }
    }
}

