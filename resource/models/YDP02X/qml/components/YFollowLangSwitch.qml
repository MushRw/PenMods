import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YDrawerLayer {
    id: id_drawer_layer

    property int currentIndex: settingManager.autoPronounceType
    signal filterChanged(int langType)

    Column {
        id: id_column
        anchors.fill: parent
        width: 350
        YSpacingForColumn {
            implicitHeight: 24
        }

        YTextBase {
            id: id_title
            color: YColors.grayText
            font.pixelSize: 26
            anchors.left: parent.left
            anchors.leftMargin: 4
            text: YTranslateText.pronuncChoice
        }

        YSpacingForColumn {
            implicitHeight: 16
        }

        YButton {
            implicitWidth: 350
            color: currentIndex === YEnum.UK ? YColors.red : "#2D2E33"
            mouseAreaMargins: -4
            text: YTranslateText.pronuncEnglish
            onClicked: {
                if (currentIndex !== YEnum.UK ) {
                    currentIndex = YEnum.UK
                    filterChanged(currentIndex)
                    hide()
                }
            }
        }

        YSpacingForColumn {
            implicitHeight: 10
        }

        YButton {
            implicitWidth: 350
            color: currentIndex === YEnum.US ? YColors.red : "#2D2E33"
            mouseAreaMargins: -4
            text: YTranslateText.pronuncAmerica
            onClicked: {
                if (currentIndex !== YEnum.US ) {
                    currentIndex = YEnum.US
                    filterChanged(currentIndex)
                    hide()
                }
            }
        }
    }
}
