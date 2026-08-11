import QtQuick 2.12
import com.youdao.pen 1.0
import "./commons"
import "./commons/input"

import com.youdao.input 1.0

YPage {
    id: id_input_page
    visible: true
    objectName: "YPage===YInputPage.qml"

    readonly property int bottomMargin: isPinyinMode && id_candidate_view.visible ? 32 : 12
    property alias placeHolderText: id_input_text_title_area.placeHolderText

    property bool isPinyinMode: false

    property int currentPinyinLen: 0

    RimeWrapper {
        id: id_rime_backend

        onCommitText: {
            console.log("Rime Commit: " + text + ", Current Raw Pinyin Len: " + currentPinyinLen);

            for (var i = 0; i < currentPinyinLen; i++) {
                id_input_text_title_area.delChar();
            }

            id_input_text_title_area.enterChar(text);

            var remaining = id_rime_backend.preeditText;
            if (remaining.length > 0) {
                id_input_text_title_area.enterChar(remaining);
                currentPinyinLen = remaining.length;
            } else {
                currentPinyinLen = 0;
                id_candidate_model.clear();
            }
        }

        onCandidatesChanged: {
            id_candidate_model.clear();
            var list = id_rime_backend.candidates;
            for (var i = 0; i < list.length; i++) {
                id_candidate_model.append({
                    "text": list[i]
                });
            }
        }
    }

    function togglePinyinMode() {
        isPinyinMode = !isPinyinMode;
        id_rime_backend.clear();
        id_candidate_model.clear();
        currentPinyinLen = 0;
        console.log("=== 切换拼音模式: " + isPinyinMode + " ===");
    }

    ListModel {
        id: id_candidate_model
    }

    function selectCandidate(index, text) {
        console.log("选中候选词索引: " + index + ", 内容: " + text);
        id_rime_backend.selectCandidate(index);
    }

    function enterText(text) {
        console.log("Input: " + text + ", PinyinMode: " + isPinyinMode);

        if (isPinyinMode) {
            var lowerText = text.toLowerCase();

            id_input_text_title_area.enterChar(text);

            currentPinyinLen += text.length;

            id_rime_backend.processKey(lowerText);
        } else {
            id_input_text_title_area.enterChar(text);
        }
    }

    signal inputFinished(string text)

    property Item currentKeyboardItem: {
        switch (qmlGlobal.currentInputStatus) {
        case YEnum.InputStatus.Upper:
            return id_input_text_upper_chars;
        case YEnum.InputStatus.Number:
            return id_input_text_number_chars;
        case YEnum.InputStatus.Symbol:
            return id_input_text_symbol_chars;
        case YEnum.InputStatus.Lower:
        default:
            return id_input_text_lower_chars;
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        contentWidth: width

        contentHeight: id_top_spacer.height + id_input_text_function_group.height + (id_input_page.currentKeyboardItem ? id_input_page.currentKeyboardItem.height : 0) + bottomMargin + id_input_text_title_area.height + (id_candidate_view.visible ? id_candidate_view.height : 0) + 3 + 5 + (id_candidate_view.visible ? 8 : 0)

        clip: true
        pressDelay: 100
        flickDeceleration: 1000

        Item {
            id: id_top_spacer
            width: parent.width
            height: 20
        }

        YInputTextTitleArea {
            id: id_input_text_title_area
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_top_spacer.bottom
            onBacked: {
                backButtonClicked();
            }
            onAccepted: {
                inputFinished(id_input_text_title_area.text);
                backButtonClicked();
            }
        }

        // 候选词视图
        Item {
            id: id_candidate_view
            clip: true

            visible: isPinyinMode
            width: parent.width

            height: isPinyinMode ? 64 : 0

            anchors.top: id_input_text_title_area.bottom
            anchors.topMargin: 8

            Rectangle {
                id: id_bg_rect
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                color: "#2B2B2B"
                radius: 12
                border.color: "#3F3F3F"
                border.width: 1
            }

            Item {
                id: id_left_container
                height: id_bg_rect.height
                anchors.left: id_bg_rect.left
                anchors.leftMargin: 12
                anchors.top: id_bg_rect.top

                width: id_rime_backend.preeditText.length > 0 ? (id_pre_edit.contentWidth + 20) : 0
                visible: width > 0

                YTextMedium {
                    id: id_pre_edit
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: id_rime_backend.preeditText
                    color: "#AAAAAA"
                    font.pixelSize: 18
                }

                Rectangle {
                    width: 1
                    height: 24
                    color: "#555555"
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: id_list_view
                anchors.left: id_left_container.right
                anchors.leftMargin: id_left_container.visible ? 10 : 4
                anchors.right: parent.right
                anchors.rightMargin: 10

                anchors.top: id_bg_rect.top
                anchors.bottom: id_bg_rect.bottom

                orientation: ListView.Horizontal
                clip: true
                model: id_candidate_model
                spacing: 10

                delegate: Item {
                    width: candidate_text.contentWidth + 24
                    height: id_list_view.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 36
                        radius: 8
                        color: mouse_area.pressed ? "#444444" : "transparent"
                    }

                    YTextMedium {
                        id: candidate_text
                        anchors.centerIn: parent
                        text: model.text
                        font.pixelSize: 22
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: mouse_area
                        anchors.fill: parent
                        onClicked: selectCandidate(index, model.text)
                    }
                }
            }

            YTextMedium {
                anchors.centerIn: id_bg_rect
                text: "长按 “abc” 键退出"
                visible: isPinyinMode && id_rime_backend.preeditText.length === 0
                color: "#666666"
                font.pixelSize: 14
            }
        }

        YInputTextFunctionGroup {
            id: id_input_text_function_group
            anchors.top: id_candidate_view.visible ? id_candidate_view.bottom : id_input_text_title_area.bottom
            anchors.topMargin: 3
            anchors.left: parent.left
            anchors.right: parent.right

            onDelChar: {
                if (isPinyinMode && currentPinyinLen > 0) {
                    id_input_text_title_area.delChar();
                    currentPinyinLen = Math.max(0, currentPinyinLen - 1);
                    id_rime_backend.processKey("BackSpace");
                } else {
                    id_input_text_title_area.delChar();
                }
            }
            onEnterSpace: {
                if (isPinyinMode && id_candidate_model.count > 0) {
                    selectCandidate(0, id_candidate_model.get(0).text);
                } else {
                    id_input_text_title_area.enterChar(' ');
                }
            }
            onRequestClear: {
                id_rime_backend.clear();
                id_candidate_model.clear();
                currentPinyinLen = 0;
                id_input_text_title_area.clear();
            }
            onNewLine: {
                if (currentPinyinLen > 0) {
                    id_rime_backend.clear();
                    currentPinyinLen = 0;
                }
                id_input_text_title_area.enterChar('\n');
            }
            onRequestTogglePinyin: {
                togglePinyinMode();
            }
        }

        YInputTextLowerChars {
            id: id_input_text_lower_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_input_text_function_group.bottom
            anchors.topMargin: 5

            onKeyClicked: {
                id_input_page.enterText(text);
            }
        }

        YInputTextUpperChars {
            id: id_input_text_upper_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_input_text_function_group.bottom
            anchors.topMargin: 5
        }

        YInputTextNumberChars {
            id: id_input_text_number_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_input_text_function_group.bottom
            anchors.topMargin: 5
        }

        YInputTextSymbolChars {
            id: id_input_text_symbol_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_input_text_function_group.bottom
            anchors.topMargin: 5
            onEnterSpace: {
                id_input_text_title_area.enterChar(' ');
            }
        }

        Rectangle {
            id: id_highlight_item
            width: visible ? 66 : 0
            height: visible ? 56 : 0
            radius: 12
            visible: id_highlight_item_content.text.length > 0
            color: "#36373D"
            YTextMedium {
                id: id_highlight_item_content
                font.pixelSize: 18
                anchors.centerIn: parent
                text: ""
            }
        }
    }

    Connections {
        target: qmlGlobal
        ignoreUnknownSignals: true
        enabled: id_input_page.visible
        onCloseInputPageWhileHomeKeyReleased: {
            id_input_page.backButtonClicked();
        }
    }

    Component.onCompleted: {
        if (typeof keyBoard !== 'undefined' && keyBoard !== null) {
            keyBoard.inputPageShowing = true;
            keyBoard.autoSendScan = false;
        }
    }

    onVisibleChanged: {
        qmlGlobal.inputPageShowing = visible;
        if (typeof keyBoard !== 'undefined' && keyBoard !== null) {
            if (visible) {
                keyBoard.inputPageShowing = true;
                keyBoard.autoSendScan = false;
            } else {
                keyBoard.autoSendScan = keyBoard.autoSendScanConfig;
                keyBoard.inputPageShowing = false;
            }
        }
        if (!visible) {
            isPinyinMode = false;
            id_rime_backend.clear();
            id_candidate_model.clear();
            currentPinyinLen = 0;
        }
    }
}
