import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

YThreeStatesButton {
    id: id_slide_bluetooth
    imageName: "slide/bt_off"
    state: bluetoothOnoff ? "on" : "off"

    readonly property bool bluetoothOnoff: blueToothManager.onoff

    onCallOn: {
        turnOnTimeoutTimer.restart()
        blueToothManager.turnOn()
    }

    onCallOff: {
        setOff()
        blueToothManager.turnOff()
    }

    onStateChanged: {
        switch(state) {
        case "on":
            id_middle_state_animation.stop()
            imageName = "slide/bt_on"
            break
        case "off":
            id_middle_state_animation.stop()
            imageName = "slide/bt_off"
            break
        case "middle":
            id_middle_state_animation.restart()
            break
        }
    }

    onBluetoothOnoffChanged: {
        if (bluetoothOnoff) {
            if (turnOnTimeoutTimer.running) {
                turnOnTimeoutTimer.stop()
            }
            if (id_slide_bluetooth.state !== "on") {
                setOn()
            }
        } else {
            setOff()
        }
    }

    onTurnOnTimeout: {
        if (blueToothManager.onoff) {
            setOn()
        }
    }

    SequentialAnimation {
        id: id_middle_state_animation
        loops: SequentialAnimation.Infinite
        PropertyAction { target: id_slide_bluetooth; property: "imageName";
            value: "slide/bt_middle_ping" }
        PauseAnimation { duration: waitingDuration }
        PropertyAction { target: id_slide_bluetooth; property: "imageName";
            value: "slide/bt_middle_pang" }
        PauseAnimation { duration: waitingDuration }
    }

    onPressAndHold: {
        qmlGlobal.requestSettingPage(YEnum.SettingIndex.Bluetooth)
    }
}
