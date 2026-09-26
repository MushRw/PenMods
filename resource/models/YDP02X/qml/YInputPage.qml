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

    // KB-29: 多行输入才允许 ↵ 插换行。默认 false —— 键盘的调用方绝大多数是
    // WiFi/SSH/锁屏密码、API Key、文件名、兑换码这类**单行**值，原来 ↵ 一律插 '\n'，
    // 换行被写进值里，提交即失败且界面上看不出原因。单行场景 ↵ 等价「确定」直接提交。
    // 多行调用方（聊天输入、消息编辑、提示词编辑）创建后显式置 true。
    property bool multiline: false

    property int currentPinyinLen: 0

    // 320x170 一屏放完：
    // 输入行 38~70 + 候选行 24(+4) + 键盘 3 行(3*30 + 2*2 = 94) + 底边距 2
    // 原来：标题 70 + 候选 64 + 功能键组 46 + 字母网格(56x46 的键、一行 5 个 → 6 行 301px)
    // ≈ 549px，在 170px 的屏上必须上下滑着找键。
    //
    // 输入行高度按内容自适应：空文本时 34（输入框本体 30，和右侧三个按钮等高对齐 —— 上下各留 2px）；
    // 有内容后跟着文字行数长高（拼音模式要给候选行留位置，封顶 42；非拼音可以到 70），
    // 再长由输入框自己滚动。
    readonly property int inputRowHeight: Math.min(isPinyinMode ? 44 : 70,
                                                   Math.max(30, id_input_text_title_area.neededHeight) + 4)
    readonly property int candidateRowHeight: 24
    readonly property int gridTopGap: 2
    // 底边距：留 2px，让最下面一行按键的圆角不被屏幕边缘切掉（原来贴到 0，看起来像被裁了）
    readonly property int gridBottomMargin: 2

    // 键盘靠近屏幕下沿：三行按键固定锚在底部（键 30 高 + 行距 2，与 YInputTextItem /
    // YInputTextCharsModelBase 保持一致），候选行紧贴键盘上方，输入行从顶部向下长。
    readonly property int keyRowHeight: 30
    readonly property int keyRowSpacing: 2
    readonly property int gridHeight: 3 * keyRowHeight + 2 * keyRowSpacing

    RimeWrapper {
        id: id_rime_backend

        onCommitText: {
            // （原有一句 console.log("Rime Commit: ...")，每次上屏一个字写一条，KB-19）
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
    }

    ListModel {
        id: id_candidate_model
    }

    // 下面两个函数是输入页最热的两条路径：selectCandidate 每选一个候选词一次，
    // enterText **每按一个键一次**。原来的 console.log 就是每次按键往 flash 写一条
    // 日志（KB-19；拼音模式下叠加 onCommitText 一共两条）。已删除。

    function selectCandidate(index, text) {
        id_rime_backend.selectCandidate(index);
    }

    function enterText(text) {
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
            // KB-29: 单行场景 ↵ 直接提交（等价「确定」），不再把 '\n' 写进值里
            if (multiline) {
                id_input_text_title_area.enterChar('\n');
            } else {
                inputFinished(id_input_text_title_area.text);
                backButtonClicked();
            }
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
            // 顶端留 2px：输入框那层淡底的圆角不会被屏幕边缘切掉
            anchors.topMargin: id_input_page.gridBottomMargin

            YInputTextTitleArea {
                id: id_input_text_title_area
                compact: true
                minHeight: id_input_page.inputRowHeight

                anchors.left: parent.left
                // 给「确定」和右边的「拼」之间留出与「返回 / 确定」一致的 4px 间隔
                // （原来标题区右边界正好压在「拼」的左边缘上，两个键贴死）
                anchors.right: id_pinyin_toggle.left
                anchors.rightMargin: 4
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
            // 和返回/确定 一样钉在输入行顶部（固定 30x30）：输入行长高时不能跟着变形/移位
            Rectangle {
                id: id_pinyin_toggle
                width: 30
                height: 30
                // 官方原版里 30x30 的小按钮是 radius 6 且没有描边（和「返回 / 确定」一致）
                radius: 6
                // 状态色用原版的 YColors.red #F03043（原版输入界面里就是它，见
                // YInputTextTitleArea.qml:135）；关闭态用灰按钮底 grayButton。
                color: id_input_page.isPinyinMode ? YColors.red : YColors.grayButton

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2

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

        // 候选词视图（拼音模式）：贴在键盘正上方（键盘锚在屏幕下沿）
        Item {
            id: id_candidate_view
            clip: true

            visible: isPinyinMode
            width: parent.width
            height: visible ? id_input_page.candidateRowHeight : 0

            anchors.bottom: parent.bottom
            anchors.bottomMargin: id_input_page.gridHeight + id_input_page.gridTopGap + id_input_page.gridBottomMargin

            Rectangle {
                id: id_bg_rect
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4

                // 候选行用官方原版取值：底 #2B2B2B、边框 #3F3F3F
                color: "#2B2B2B"
                radius: 8
                border.color: YColors.border
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
                    // 官方原版：拼音串 #AAAAAA
                    color: YColors.textSecondary
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
                        color: mouse_area.pressed ? YColors.pressed : "transparent"
                    }

                    YTextMedium {
                        id: candidate_text
                        anchors.centerIn: parent
                        text: model.text
                        font.pixelSize: 16
                        color: YColors.white
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
                text: "点「拼」切回字母"
                visible: isPinyinMode && id_rime_backend.preeditText.length === 0
                // 官方原版空状态提示色
                color: "#666666"
                font.pixelSize: 12
            }
        }

        YInputTextLowerChars {
            id: id_input_text_lower_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.bottom: parent.bottom
            anchors.bottomMargin: id_input_page.gridBottomMargin
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextUpperChars {
            id: id_input_text_upper_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.bottom: parent.bottom
            anchors.bottomMargin: id_input_page.gridBottomMargin
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextNumberChars {
            id: id_input_text_number_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.bottom: parent.bottom
            anchors.bottomMargin: id_input_page.gridBottomMargin
            anchors.left: parent.left
            anchors.right: parent.right

            onCharEntered: id_input_page.enterText(text)
            onKeyAction: id_input_page.handleKeyAction(action)
        }

        YInputTextSymbolChars {
            id: id_input_text_symbol_chars
            visible: id_input_page.currentKeyboardItem === this
            anchors.bottom: parent.bottom
            anchors.bottomMargin: id_input_page.gridBottomMargin
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
