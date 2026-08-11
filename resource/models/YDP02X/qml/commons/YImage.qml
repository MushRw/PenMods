import QtQuick 2.12
import com.youdao.pen 1.0

YImageBase {
    property string imageName: ""
    property string resource: ""
    source: {
        if ("" === imageName) {
            if ("" === resource) {
                return ""
            } else {
                return res.get(resource)
            }
        } else {
            // 如果已经是完整路径（qrc:/ 或 file:/ 或 http），直接返回
            if (imageName.indexOf("qrc:/") === 0 || imageName.indexOf("file:/") === 0) {
                return imageName
            }
            // 否则走原有的 Image Provider 逻辑
            return ("image://icons/%1.png").arg(imageName)
        }
    }
}
