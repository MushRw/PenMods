import QtQuick 2.12
import com.youdao.pen 1.0
import "qrc:/qml/commons"

Item {
    id: id_functions_group_root

    readonly property int spacing: 5

    signal delChar()
    signal enterSpace()
    signal requestClear()
    signal newLine()
    // 【新增】请求切换拼音模式的信号
    signal requestTogglePinyin()

    implicitWidth: 300
    implicitHeight: 46
    Component.onCompleted: {
        console.log("ZDS=====qmlGlobal.currentInputStatus: ", qmlGlobal.currentInputStatus);
    }

    YInputTextFunctionButton {
        id: id_abc_chars_button

        checkedIndicatorScale: YEnum.InputStatus.Lower === qmlGlobal.currentInputStatus || YEnum.InputStatus.Upper === qmlGlobal.currentInputStatus
        onClicked: {
            if (YEnum.InputStatus.Lower === qmlGlobal.currentInputStatus)
                qmlGlobal.currentInputStatus = YEnum.InputStatus.Upper;
            else
                qmlGlobal.currentInputStatus = YEnum.InputStatus.Lower;
        }

        // 【新增】长按触发切换拼音模式
        onPressAndHold: {
            requestTogglePinyin()
        }

        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            imageName: YEnum.InputStatus.Upper === qmlGlobal.currentInputStatus ? "input/char_upper" : "input/char_lower"
        }
    }

    YInputTextFunctionButton {
        id: id_number_chars_button
        anchors.left: id_abc_chars_button.right
        anchors.leftMargin: spacing
        checkedIndicatorScale: YEnum.InputStatus.Number === qmlGlobal.currentInputStatus
        onClicked: {
            qmlGlobal.currentInputStatus = YEnum.InputStatus.Number;
        }
        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            imageName: "input/char_digital"
        }
    }

    YInputTextFunctionButton {
        id: id_symbol_chars_button
        anchors.left: id_number_chars_button.right
        anchors.leftMargin: spacing
        checkedIndicatorScale: YEnum.InputStatus.Symbol === qmlGlobal.currentInputStatus
        onClicked: {
            qmlGlobal.currentInputStatus = YEnum.InputStatus.Symbol;
        }
        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            imageName: "input/char_punctuation"
        }
    }

    YInputTextFunctionButton {
        id: id_newline_button
        anchors.left: id_symbol_chars_button.right
        anchors.leftMargin: spacing
        onClicked: {
            newLine();
        }
        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            source: res.get('keyboard/newline')
        }
    }

    YInputTextFunctionButton {
        id: id_del_char_button
        anchors.left: id_newline_button.right
        anchors.leftMargin: spacing
        onClicked: {
            delChar();
        }
        onPressAndHold: {
            requestClear();
        }
        YImage {
            anchors.centerIn: parent
            sourceSize: Qt.size(40, 40)
            imageName: "input/ic_delete"
        }
    }
}
