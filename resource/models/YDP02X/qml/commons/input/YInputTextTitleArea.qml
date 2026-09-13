import QtQuick 2.12
import com.youdao.pen 1.0

import "../../commons"
import "../../i18n"

Item {
    anchors.left: parent.left
    anchors.right: parent.right
    // compact 模式供紧凑键盘使用：一行放完输入框 + 确定 + 返回（原来最少要 70px）
    property bool compact: false
    property int minHeight: 70
    height: Math.max(id_input_core_background.contentHeight, minHeight)

    readonly property bool acceptabled: id_input_core.length
    property alias text: id_input_core.text
    property alias placeHolderText: id_placeholder_text.text

    signal backed()
    signal accepted()

    function delChar() {
        id_input_core.remove(Math.max(0, id_input_core.cursorPosition - 1),
                             id_input_core.cursorPosition)
        if (!id_input_core.activeFocus) {
            id_input_core.forceActiveFocus()
        }
    }

    function enterChar(text) {
        id_input_core.insert(id_input_core.cursorPosition, text)
        if (!id_input_core.activeFocus) {
            id_input_core.forceActiveFocus()
        }
    }

    function clear() {
        id_input_core.clear()
    }

    YIconButton {
        id: id_back_button_bg
        implicitWidth: 30
        implicitHeight: 30
        radius: 6
        icon: "ic_back"
        sourceSize: Qt.size(24, 24)
        anchors.right: compact ? id_accepted_button_background.left : parent.right
        anchors.rightMargin: compact ? 4 : 0
        anchors.top: compact ? undefined : parent.top
        anchors.verticalCenter: compact ? parent.verticalCenter : undefined

        YBackButtonBase {
            anchors.fill: parent
            anchors.margins: -10
            onTriggered: {
                backed()
            }
        }
    }

    YIconButton {
        id: id_accepted_button_background
        anchors.right: parent.right
        anchors.bottom: compact ? undefined : parent.bottom
        anchors.bottomMargin: compact ? 0 : 5
        anchors.verticalCenter: compact ? parent.verticalCenter : undefined
        implicitWidth: 30
        implicitHeight: 30
        radius: 6
        color: YColors.grayNormal
        enabled: acceptabled
        sourceSize: Qt.size(24, 24)
        imageName: "textbook/select-check"
        mouseAreaMargins: -10
        onClicked: {
            accepted()
        }
    }

    Flickable {
        id: id_input_core_background
        anchors.left: parent.left
        anchors.right: id_back_button_bg.left
        anchors.rightMargin: compact ? 4 : 0
        anchors.top: compact ? parent.top : undefined
        anchors.bottom: compact ? parent.bottom : undefined
        anchors.topMargin: compact ? 0 : 8
        contentHeight: id_input_core.contentHeight
        implicitHeight: 35 + id_input_core.height
        clip: true
        interactive: false

        function ensureVisible(r) {
            if (contentX >= r.x)
                contentX = r.x;
            else if (contentX + width <= r.x + r.width)
                contentX = r.x + r.width - width;
            if (contentY >= r.y)
                contentY = r.y;
            else if (contentY + height <= r.y + r.height)
                contentY = r.y + r.height - height;
        }

        TextEdit {
            id: id_input_core
            anchors.fill: parent
            font.family: qmlGlobal.fontFamily
            font.pixelSize: 18
            color: YColors.white
            cursorDelegate: id_cursor_delegate
            wrapMode: TextEdit.WrapAnywhere
            onCursorRectangleChanged: id_input_core_background.ensureVisible(cursorRectangle)

            YTextBase {
                id: id_placeholder_text
                anchors.fill: parent
                opacity: !id_input_core.length && !id_input_core.inputMethodComposing ? 1 : 0
                color: YColors.grayText
                font: id_input_core.font
                wrapMode: id_input_core.wrapMode
                text: YTranslateText.inputTip
            }
        }
    }

    Connections {
        target: keyBoard
        function onScanFinished(content) {
            id_input_core.insert(id_input_core.cursorPosition, content)
            if (!id_input_core.activeFocus) {
                id_input_core.forceActiveFocus()
            }
        }
    }

    Component {
        id: id_cursor_delegate
        Rectangle {
            id: id_cursor_context
            width: 2
            height: 20
            opacity: 0
            color: YColors.red
            SequentialAnimation {
                running: !id_input_core.readOnly && id_input_core.activeFocus
                loops: SequentialAnimation.Infinite
                ScriptAction { script: id_cursor_context.opacity = 1 }
                PauseAnimation { duration: 600 }
                ScriptAction { script: id_cursor_context.opacity = 0 }
                PauseAnimation { duration: 600 }
            }
        }
    }
}
