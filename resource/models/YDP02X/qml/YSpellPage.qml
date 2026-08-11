import QtQuick 2.12
import com.youdao.pen 1.0

import "./commons"
import "./components"

YPage {
    id: id_spell_page
    objectName: "YPage===YSpellPage.qml"
    pageIndex: YEnum.PageIndex.Spell

    YVerticalTitleBar {
        id: id_title_bar
        onCallBack: {
            soundCenter.suspend()
            spellManager.enableReply = true
            backButtonClicked()
        }
        YIconButton {
            id: id_replay_button_bg
            implicitWidth: 30
            implicitHeight: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            enabled: spellManager.enableReply
            iconSourceSize: Qt.size(24, 24)
            icon: "/spell/replay"
            radius: height / 2
            mouseAreaMargins: -5
            onClicked: {
                spellManager.reset();
                //spellManager.replay();
                id_delay_timer.start()
                logManager.sendHttpLog("action=detail_add_spell_again_click")
            }
        }
    }
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: id_title_bar.right
        anchors.right: parent.right
        YImage {
            id: id_spell_bg
            anchors.centerIn: parent
            //sourceSize: Qt.size(252, 42)
            imageName: spellManager.content.length < 30 ? "spell/bg" : "spell/largebg"
        }
        YText {
            id: id_content_label
            anchors.topMargin: -10
            font.family: "Poppins"
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: spellManager.content.length < 30 ? 30 : 24
            textFormat: YText.RichText
            font.weight: Font.DemiBold
            text: spellManager.richContent
        }
    }


    Component.onCompleted: {
        id_delay_timer.start()
    }
    YTimer {
        id: id_delay_timer
        interval: 500
        objectName: "YSpellPage.qml_delay_timer"
        onTriggered: {
            spellManager.enableReply = false
            spellManager.reset();
            spellManager.replay();
        }
    }
    Component.onDestruction: {
        spellManager.enableReply = true
        spellManager.reset();
        soundCenter.suspend()
        console.log("YSpellPage.qml===Component.onDestruction===called")
    }

    onVisibleChanged: {
        if (visible) {
            id_delay_timer.start()
        }
    }

    Connections {
        target : systemBase
        ignoreUnknownSignals :true
        onOcrStart: {
            console.log("YSpellPage.qml===Connections::systemBase.onOcrStart===called")
            soundCenter.suspend()
            spellManager.enableReply = true
            backButtonClicked()
        }
    }
}
