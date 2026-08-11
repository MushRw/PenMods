pragma Singleton

import QtQuick 2.12

// global color defineds, use as colorDefineds

QtObject {

    readonly property string black: "#000000"
    readonly property string white: "#FFFFFF"

    readonly property string red: "#F03043"
    readonly property string orange: "#FF8B20"

    readonly property Gradient redDict: Gradient {
        GradientStop { position: 0.0; color: "#FA423C" }
        GradientStop { position: 1.0; color: "#F03043" }
    }

    readonly property string green: "#13B876"

    readonly property string yellow: "#E9900C"

    readonly property string blueText: "#509DEB"
    readonly property string blueRect: "#2D73DC"

    readonly property string grayText: "#909199"
    readonly property string grayNormal: "#1A1B1F"
    readonly property string graySwitchOff: "#515259"
    readonly property string grayButton: "#2D2E33"
}
