import QtQuick 2.12
import com.youdao.pen 1.0
import "qrc:/qml/commons"

Item {
    id: id_functions_group_root

    readonly property int spacing: 4
    readonly property real buttonWidth: (width - spacing * 5) / 6

    signal delChar()
    signal enterSpace()
    signal requestClear()
    signal newLine()
    signal requestTogglePinyin()
    signal requestVoiceInput()

    implicitWidth: 300
    implicitHeight: 46
    Component.onCompleted: {
        console.log("ZDS=====qmlGlobal.currentInputStatus: ", qmlGlobal.currentInputStatus);
    }

    YInputTextFunctionButton {
        id: id_abc_chars_button

        width: buttonWidth
        checkedIndicatorScale: YEnum.InputStatus.Lower === qmlGlobal.currentInputStatus || YEnum.InputStatus.Upper === qmlGlobal.currentInputStatus
        onClicked: {
            if (YEnum.InputStatus.Lower === qmlGlobal.currentInputStatus)
                qmlGlobal.currentInputStatus = YEnum.InputStatus.Upper;
            else
                qmlGlobal.currentInputStatus = YEnum.InputStatus.Lower;
        }

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
        width: buttonWidth
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
        width: buttonWidth
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
        id: id_voice_input_button
        width: buttonWidth
        anchors.left: id_symbol_chars_button.right
        anchors.leftMargin: spacing
        checkedIndicatorScale: speechManager.recognizing === YEnum.AS_ASRBegin
        onClicked: {
            requestVoiceInput();
        }

        Item {
            width: 26
            height: 32
            anchors.centerIn: parent

            Rectangle {
                width: 12
                height: 20
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: YColors.white
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
            }

            Rectangle {
                width: 2
                height: 9
                color: YColors.white
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.top: parent.top
                anchors.topMargin: 10
            }

            Rectangle {
                width: 2
                height: 9
                color: YColors.white
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.top: parent.top
                anchors.topMargin: 10
            }

            Rectangle {
                width: 20
                height: 2
                radius: 1
                color: YColors.white
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 18
            }

            Rectangle {
                width: 2
                height: 7
                color: YColors.white
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 21
            }

            Rectangle {
                width: 14
                height: 2
                radius: 1
                color: YColors.white
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
            }
        }
    }

    YInputTextFunctionButton {
        id: id_newline_button
        width: buttonWidth
        anchors.left: id_voice_input_button.right
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
        width: buttonWidth
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
