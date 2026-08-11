import "../commons"
import "../components"
import "../i18n"
import QtQuick 2.12
import com.github.penuniverse 1.0

YSettingItemPage {
    id: id_setting_item

    // 1: hostName
    // 2: port
    // 3: userName
    // 4: password
    property int currentKeyboardState: 0

    function requestKeyboard() {
        let component = qmlCreateComponent("YInputPage");
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready)
                incubator.onStatusChanged = function(status) {
                if (status === Component.Ready)
                    id_page_pop_helper.inputPageCreated(incubator.object);

            };
            else
                id_page_pop_helper.inputPageCreated(incubator.object);
        }
    }

    objectName: "YPage===ConfigureProxyPage.qml"

    Flickable {
        id: id_setting_item_view

        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: 24 + id_title_container.height + id_switch_proxy_state.height + id_proxy_type_label.height + id_proxy_type_switcher.height + id_column.height

        YSettingItemTitle {
            id: id_title_container

            title: "代理服务器"
        }

        DescribedSwitchItem {
            id: id_switch_proxy_state

            anchors.top: id_title_container.bottom
            title: "使用代理"
            description: "这将有助于改善某些服务的连接问题。"
            switchOn: networkSettings.proxyEnabled
            interval: 0
            onTimerTriggered: {
                networkSettings.proxyEnabled = switchOn;
            }
        }

        YText {
            id: id_proxy_type_label

            anchors.left: parent.left
            anchors.top: id_switch_proxy_state.bottom
            anchors.topMargin: 8
            font.pixelSize: 16
            color: YColors.grayText
            height: 21
            text: "选择代理类型"
        }

        Row {
            id: id_proxy_type_switcher

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: id_proxy_type_label.bottom
            anchors.topMargin: 8
            spacing: 8

            YPressedButton {
                implicitWidth: 124
                checkedIndicatorScale: networkSettings.proxyType === 0
                text: "Socks5"
                onClicked: {
                    networkSettings.proxyType = 0;
                }
            }

            YPressedButton {
                implicitWidth: 124
                checkedIndicatorScale: networkSettings.proxyType === 1
                text: "HTTP"
                onClicked: {
                    networkSettings.proxyType = 1;
                }
            }

        }

        Column {
            id: id_column

            anchors.top: id_proxy_type_switcher.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YText {
                font.pixelSize: 16
                color: YColors.grayText
                height: 21
                text: "配置代理"
            }

            DescribedClickableTextBox {
                title: "主机名"
                describe: networkSettings.proxyHostName
                opacityChangableWhenPressed: false
                onClicked: {
                    currentKeyboardState = 1;
                    requestKeyboard();
                }
            }

            DescribedClickableTextBox {
                title: "端口号"
                describe: networkSettings.proxyPort
                opacityChangableWhenPressed: false
                onClicked: {
                    currentKeyboardState = 2;
                    requestKeyboard();
                }
            }

            DescribedClickableTextBox {
                title: "用户名"
                describe: networkSettings.proxyUserName.length != 0 ? networkSettings.proxyUserName : "[未指定]"
                opacityChangableWhenPressed: false
                onClicked: {
                    currentKeyboardState = 3;
                    requestKeyboard();
                }
            }

            DescribedClickableTextBox {
                title: "密码"
                describe: networkSettings.proxyPassword.length != 0 ? networkSettings.proxyPassword : "[未指定]"
                opacityChangableWhenPressed: false
                onClicked: {
                    currentKeyboardState = 4;
                    requestKeyboard();
                }
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

    YPagePopHelper {
        id: id_page_pop_helper

        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });
            keyboardPage.inputFinished.connect(function(content) {
                switch (currentKeyboardState) {
                case 1:
                    networkSettings.proxyHostName = content;
                    break;
                case 2:
                    networkSettings.proxyPort = parseInt(content);
                    break;
                case 3:
                    networkSettings.proxyUserName = content;
                    break;
                case 4:
                    networkSettings.proxyPassword = content;
                    break;
                }
            });
            keyboardPage.show();
            switch (currentKeyboardState) {
            case 1:
                keyboardPage.enterText(networkSettings.proxyHostName);
                break;
            case 2:
                keyboardPage.enterText(networkSettings.proxyPort);
                break;
            case 3:
                keyboardPage.enterText(networkSettings.proxyUserName);
                break;
            case 4:
                keyboardPage.enterText(networkSettings.proxyPassword);
                break;
            }
            qmlGlobal.inputPageShowing = true;
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_YSettingWifi.qml"
    }

}
