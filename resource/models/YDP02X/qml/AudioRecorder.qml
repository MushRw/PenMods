import "./commons"
import "./components"
import "./i18n"
import "./settingpages"
import QtQuick 2.12
import com.github.penuniverse 1.0

YBackButtonPage {
    //    showToast("输入流采样率异常", YColors.yellow)
    //    break
    // temp...

    id: id_audio_recorder

    pageIndex: PageIndex.AudioRecorder
    property bool locked: false

    function start() {
        if (locked)
            return ;

        locked = true;
        audioRecorder.start();
        locked = false;
    }

    function stop() {
        if (locked)
            return ;

        locked = true;
        switch (audioRecorder.stop()) {
        case AudioRecorder.OpenError:
            qmlGlobal.showToast("打开输入设备时出现错误", YColors.yellow);
            break;
        case AudioRecorder.IOError:
            qmlGlobal.showToast("从输入设备读取数据时出现错误", YColors.yellow);
            break;
        case AudioRecorder.FatalError:
            qmlGlobal.showToast("输入设备引发无法恢复的错误", YColors.yellow);
            break;
        case AudioRecorder.NoError:
        case AudioRecorder.UnderrunError:
        default:
            qmlGlobal.showToast("录音保存成功");
            break;
        }
        locked = false;
    }

    function ts2str(ts) {
        let s = ts % 60;
        ts -= s;
        let m = (ts / 60) % 60;
        ts -= m * 60;
        let h = ts / 3600;
        if (s < 10)
            s = "0" + String(s);

        if (m < 10)
            m = "0" + String(m);

        if (h < 10)
            h = "0" + String(h);

        return `${h}:${m}:${s}`;
    }

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

    objectName: "YPage===AudioRecorder.qml"
    Component.onCompleted: {
        id_column_main.update();
    }
    onBackButtonClicked: {
        stop();
    }
    Flickable {
        id: id_item_container

        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10
        contentHeight: id_title_container.height + id_column_main.height

        YSettingItemTitle {
            id: id_title_container

            title: "录音机"
        }

        Column {
            id: id_column_main

            function update() {
                switch (audioRecorder.state) {
                case AudioRecorder.ActiveState:
                    id_state.title = '正在录音';
                    id_state.value = '00:00:00';
                    id_state.source = '';
                    break;
                case AudioRecorder.SuspendedState:
                    id_state.title = '暂停';
                    id_state.source = 'audioplayer/play';
                    break;
                case AudioRecorder.IdleState:
                case AudioRecorder.StoppedState:
                case AudioRecorder.InterruptedState:
                case AudioRecorder.WaitingState:
                    id_state.title = '就绪';
                    id_state.value = '';
                    id_state.source = 'audioplayer/mic';
                    break;
                }
            }

            anchors.top: id_title_container.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            YSettingAboutClickableItem {
                id: id_state

                opacityChangableWhenPressed: false
                sourceSize: Qt.size(24, 24)
                onClicked: {
                    switch (audioRecorder.state) {
                    case AudioRecorder.ActiveState:
                        stop();
                        break;
                    case AudioRecorder.SuspendedState:
                        break;
                    case AudioRecorder.IdleState:
                    case AudioRecorder.StoppedState:
                    case AudioRecorder.InterruptedState:
                    case AudioRecorder.WaitingState:
                        start();
                        break;
                    }
                }
            }

            YSettingAboutClickableItem {
                title: audioRecorder.state == AudioRecorder.ActiveState || audioRecorder.state == AudioRecorder.WaitingState ? "修改文件名" : "文件名"
                enabled: audioRecorder.state == AudioRecorder.ActiveState
                value: audioRecorder.fileName
                imageName: "settings/info_more_arrow"
                onClicked: requestKeyboard()
            }

            YSpacingForColumn {
                implicitHeight: 4
            }

        }

    }

    Connections {
        property int currentSeconds: 0

        function onStateChanged() {
            id_column_main.update();
            switch (audioRecorder.state) {
            case AudioRecorder.ActiveState:
                break;
            case AudioRecorder.SuspendedState:
                break;
            case AudioRecorder.StoppedState:
            case AudioRecorder.InterruptedState:
                stop();
                break;
            case AudioRecorder.IdleState:
                break;
            }
        }

        function onNotify() {
            currentSeconds += 1;
            id_state.value = ts2str(currentSeconds);
        }

        target: audioRecorder
        ignoreUnknownSignals: true
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 80
        anchors.leftMargin: 0

        Column {
            id: id_column_sidebar

            anchors.left: parent.left
            anchors.topMargin: 12
            spacing: 8
            visible: !qmlGlobal.inputPageShowing

            YIconButton {
                id: id_start_record

                property bool recording: false

                width: 30
                height: 30
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.bottom: parent.bottom
                radius: 6
                enabled: audioRecorder.state != AudioRecorder.ActiveState || audioRecorder.state == AudioRecorder.WaitingState
                source: "audioplayer/mic"
                sourceSize: Qt.size(20, 20)
                onValidClicked: {
                    start();
                }
            }

            YIconButton {
                id: id_play_record

                width: 30
                height: 30
                anchors.top: id_start_record.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 10
                radius: 6
                enabled: audioRecorder.state != AudioRecorder.ActiveState && audioRecorder.state != AudioRecorder.WaitingState
                source: "audioplayer/pause"
                sourceSize: Qt.size(24, 24)
                onValidClicked: {
                }
            }

            YIconButton {
                id: id_stop_record

                width: 30
                height: 30
                anchors.top: id_play_record.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 10
                radius: 6
                enabled: audioRecorder.state == AudioRecorder.ActiveState && audioRecorder.state != AudioRecorder.WaitingState
                source: "textbook/select-check"
                sourceSize: Qt.size(20, 20)
                onValidClicked: {
                    stop();
                }
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
                let ret = audioRecorder.setFileName(content);
                switch (ret) {
                case AudioRecorder.SetPathResult.Ok:
                    qmlGlobal.showToast('文件名已修改');
                    break;
                case AudioRecorder.SetPathResult.IllegalSymbolDetected:
                    qmlGlobal.showToast('文件名不能包含特殊字符', YColors.yellow);
                    break;
                }
            });
            keyboardPage.enterText(audioRecorder.fileName);
            keyboardPage.show();
            qmlGlobal.inputPageShowing = true;
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_AudioRecorder.qml"
    }

    Connections {
        target: systemBase
        ignoreUnknownSignals: true
        onOcrStart: {
            backButtonClicked();
        }
    }

}
