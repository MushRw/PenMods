import QtQuick 2.12
import com.youdao.pen 1.0
import "./commons"
import "./commons/input"

import com.youdao.input 1.0

YPage {
    id: id_input_page
    visible: true
    objectName: "YPage===YInputPage.qml"

    property alias placeHolderText: id_input_text_title_area.placeHolderText

    property bool isPinyinMode: false

    property int currentPinyinLen: 0

    // 320x170 一屏放完：
    // 输入行 34 + 候选行 24(+4) + 键盘 3 行(3*30 + 2*2 = 94) + 底边距 4 ≈ 160
    // 原来：标题 70 + 候选 64 + 功能键组 46 + 字母网格(56x46 的键、一行 5 个 → 6 行 301px)
    // ≈ 549px，在 170px 的屏上必须上下滑着找键。
    readonly property int inputRowHeight: 34
    readonly property int candidateRowHeight: 24
    readonly property int gridTopGap: 2
    readonly property int bottomMargin: 4

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

    // 功能键统一在这里处理（退格/空格/回车/清空/切换键盘页）
    function handleKeyAction(action) {
        switch (action) {
        case "backspace":
            if (isPinyinMode && currentPinyinLen > 0) {
                id_input_text_title_area.delChar();
                currentPinyinLen = Math.max(0, currentPinyinLen - 1);
                id_rime_backend.processKey("BackSpace");
            } else {
                id_input_text_title_area.delChar();
            }
            break;
        case "clear":
            id_rime_backend.clear();
            id_candidate_model.clear();
            currentPinyinLen = 0;
            id_input_text_title_area.clear();
            break;
        case "space":
            if (isPinyinMode && id_candidate_model.count > 0) {
                selectCandidate(0, id_candidate_model.get(0).text);
            } else {
                id_input_text_title_area.enterChar(' ');
            }
            break;
        case "enter":
            if (currentPinyinLen > 0) {
                id_rime_backend.clear();
                currentPinyinLen = 0;
            }
            id_input_text_title_area.enterChar('\n');
            break;
        case "switchNumber":
            qmlGlobal.currentInputStatus = YEnum.InputStatus.Number;
            break;
        case "switchSymbol":
            qmlGlobal.currentInputStatus = YEnum.InputStatus.Symbol;
            break;
        case "switchLetter":
            qmlGlobal.currentInputStatus = YEnum.InputStatus.Lower;
            break;
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
        // 所有按键都在这一页，禁止纵向滚动
        contentHeight: height
        interactive: false

        clip: true
        pressDelay: 100
        flickDeceleration: 1000

        Item {
            id: id_input_row
            width: parent.width
            height: id_input_page.inputRowHeight

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            YInputTextTitleArea {
                id: id_input_text_title_area
                compact: true
                minHeight: id_input_page.inputRowHeight

                anchors.left: parent.left
                anchors.right: id_pinyin_toggle.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                onBacked: {
                    backButtonClicked();
                }
                onAccepted: {
                    inputFinished(id_input_text_title_area.text);
                    backButtonClicked();
                }
            }

            // 拼音开关：原来靠“长按 abc 键”，改成一键切换更好找
            Rectangle {
                id: id_pinyin_toggle
                width: 30
                radius: 6
                color: id_input_page.isPinyinMode ? YColors.blueRect : YColors.grayButton

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                YTextMedium {
                    anchors.centerIn: parent
                    text: "拼"
                    font.pixelSize: 16
                    color: YColors.white
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: id_input_page.togglePinyinMode()
                }
            }
        }

        // 候选词视图（拼音模式）
        Item {
            id: id_candidate_view
            clip: true

            visible: isPinyinMode
            width: parent.width
            height: visible ? id_input_page.candidateRowHeight : 0

            anchors.top: id_input_row.bottom
            anchors.topMargin: 4

            Rectangle {
                id: id_bg_rect
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4

                color: "#2B2B2B"
                radius: 8
                border.color: "#3F3F3F"
                border.width: 1
            }

            Item {
                id: id_left_container
                height: id_bg_rect.height
                anchors.left: id_bg_rect.left
                anchors.leftMargin: 8
                anchors.top: id_bg_rect.top

                width: id_rime_backend.preeditText.length > 0 ? (id_pre_edit.contentWidth + 14) : 0
                visible: width > 0

                YTextMedium {
                    id: id_pre_edit
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: id_rime_backend.preeditText
                    color: "#AAAAAA"
                    font.pixelSize: 14
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: "#555555"
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: id_list_view
                anchors.left: id_left_container.right
                anchors.leftMargin: id_left_container.visible ? 8 : 4
                anchors.right: parent.right
                anchors.rightMargin: 8

                anchors.top: id_bg_rect.top
                anchors.bottom: id_bg_rect.bottom

                orientation: ListView.Horizontal
                clip: true
                model: id_candidate_model
                spacing: 8

                delegate: Item {
                    width: candidate_text.contentWidth + 16
                    height: id_list_view.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 22
                        radius: 6
                        color: mouse_area.pressed ? "#444444" : "transparent"
                    }

                    YTextMedium {
                        id: candidate_text
                        anchors.centerIn: parent
                        text: model.text
                        font.pixelSize: 16
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
                text: "点右侧「拼」切回字母"
                visible: isPinyinMode && id_rime_backend.preeditText.length === 0
                color: "#666666"
                font.pixelSize: 12
            }
        }

        YInputTextLowerChars {
            id: id_input_text_lower_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_candidate_view.visible ? id_candidate_view.bottom : id_input_row.bottom
            anchors.topMargin: id_input_page.gridTopGap
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextUpperChars {
            id: id_input_text_upper_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_candidate_view.visible ? id_candidate_view.bottom : id_input_row.bottom
            anchors.topMargin: id_input_page.gridTopGap
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextNumberChars {
            id: id_input_text_number_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_candidate_view.visible ? id_candidate_view.bottom : id_input_row.bottom
            anchors.topMargin: id_input_page.gridTopGap
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextSymbolChars {
            id: id_input_text_symbol_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.top: id_candidate_view.visible ? id_candidate_view.bottom : id_input_row.bottom
            anchors.topMargin: id_input_page.gridTopGap
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
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
