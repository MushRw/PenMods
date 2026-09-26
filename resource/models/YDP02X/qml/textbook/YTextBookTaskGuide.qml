import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"

Item {
     id: id_textbook_task_guide_item
     anchors.fill: parent
     visible: false
     property int taskType: YEnum.TTT_Listen
     property int taskId: -1

     YBackgroundIgnoreMouseEvent {
         anchors.fill: parent
     }

    YLoader {
        id: id_guide_content_loader
        width: id_textbook_task_guide_item.width
        height: id_textbook_task_guide_item.height
        sourceComponent: id_introduction_component
        onSourceComponentChanged: {
            console.log("YTextBookTaskGuide.qml === id_guide_content_loader.onSourceComponentChanged: ")
        }

        onLoaded: {
            item.initImageModel()
        }

        ListModel {
            id: id_follow_guide_image

            ListElement {
                image: "textbook/taskfollow_guide1"
            }
            ListElement {
                image: "textbook/taskfollow_guide2"
            }
            ListElement {
                image: "textbook/taskfollow_guide3"
            }
        }

        ListModel {
            id: id_listen_guide_image

            ListElement {
                image: "textbook/tasklisten_guide1"
            }
            ListElement {
                image: "textbook/tasklisten_guide2"
            }
            ListElement {
                image: "textbook/tasklisten_guide3"
            }
        }

        Component {
            id: id_introduction_component

            Item {
                id: id_introduction_item
                width: id_textbook_task_guide_item.width
                height: id_textbook_task_guide_item.height
                property int intrImageIndex: 0
                property var model: YEnum.TTT_Listen === id_textbook_task_guide_item.taskType ? id_listen_guide_image: id_follow_guide_image
                // UI-01: 翻页上限原来硬编码 `< 2`（按 3 张图写死），引导图不足 3 张时
                // 索引会累加越界，`model.get(2).image` 直接抛 TypeError。上限一律按
                // model.count 推导；取图也判空兜底。
                readonly property int intrImageLastIndex: (model && model.count > 0) ? model.count - 1 : 0

                function initImageModel()
                {
                    id_introduction_item.intrImageIndex = 0
                }

                // 越界/空模型时返回空串，不再抛 TypeError
                function currentImageUrl() {
                    var m = id_introduction_item.model;
                    if (!m || m.count <= 0) return "";
                    var idx = id_introduction_item.intrImageIndex;
                    if (idx < 0 || idx >= m.count) return "";
                    var it = m.get(idx);
                    return (it && it.image !== undefined) ? it.image : "";
                }

                YImage {
                    id: id_image_bg
                    anchors.fill: parent
                    imageName: id_introduction_item.currentImageUrl()

                    MouseArea {
                        width: 100
                        height: 120
                        anchors.left: parent.left
                        anchors.top: parent.top
                        onClicked: {
                            console.log("YTextBookTaskGuide.qml === id_introduction_item.last.onClicked")
                            if (id_introduction_item.intrImageIndex > 0) {
                                id_introduction_item.intrImageIndex -= 1
                            }
                        }
                    }

                    MouseArea {
                        width: 100
                        height: 120
                        anchors.right: parent.right
                        anchors.top: parent.top
                        onClicked: {
                            console.log("YTextBookTaskGuide.qml === id_introduction_item.next.onClicked")
                            if (id_introduction_item.intrImageIndex < id_introduction_item.intrImageLastIndex) {
                                id_introduction_item.intrImageIndex += 1
                            } else {
                                id_textbook_task_guide_item.visible = false
                                if (id_textbook_task_guide_item.taskId > 0) {
                                    textBookTaskManager.clickMedia(id_textbook_task_guide_item.taskId)
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                    }
                }

            }
        }
    }

    onVisibleChanged: {
        id_guide_content_loader.active = visible
    }

}
