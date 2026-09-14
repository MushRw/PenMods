import QtQuick 2.12
import QtGraphicalEffects 1.14

YTextMedium {
    id: id_text_content

    layer.enabled: true
    layer.effect: DropShadow {
        verticalOffset: 1
        color: YColors.scrimLight
        radius: 3
        samples: 7
    }
}
