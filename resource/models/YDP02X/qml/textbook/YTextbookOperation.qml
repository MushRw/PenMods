import QtQuick 2.12
import QtGraphicalEffects 1.0
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

YBackgroundIgnoreMouseEvent {
    id: id_textbook_operation_item
    objectName: "YTextBookOperation.qml"
    anchors.fill: parent
    readonly property var textbookObj: id_textbook_page.selectTextbookObj
    readonly property bool textbookIsBought: textbookObj.isBought
    readonly property bool textbookIsExpirated: textbookObj.isExpirated
    readonly property int textbookDownloadState: textbookObj.downloadState
    property int showContentState: YEnum.TB_OS_Bought
    property bool showBoughtTipDetail: false
    property var paymentMethod: YEnum.OC_WX
    property var paymentQrContent: ""
    property var paymentQrcodeOrderId: ""

    function updateShowContentState() {
        //console.log("YTextbookOperation.qml === updateShowContentState textbookObj.isBought:", textbookObj.isBought)
        //console.log("YTextbookOperation.qml === updateShowContentState textbookObj.isExpirated:", textbookObj.isExpirated)
        //console.log("YTextbookOperation.qml === updateShowContentState textbookObj.downloadState:", textbookObj.downloadState)
        if (textbookObj.isBought) {
            if (textbookObj.isExpirated) {
                showContentState = YEnum.TB_OS_Rebought
            } else if (textbookObj.downloadState === YEnum.DS_SUCCEED) {
                showContentState = YEnum.TB_OS_StartStudy
            } else {
                showContentState = YEnum.TB_OS_Download
            }
        } else {
            showContentState = YEnum.TB_OS_Bought
        }
    }

    function showKeyboard(keyBoardPage) {
        keyBoardPage.backButtonClicked.connect(function(){
            keyBoardPage.todoDestroy()
            qmlGlobal.inputPageShowing = false
            keyBoardPage = null
        })
        keyBoardPage.inputFinished.connect(function(pwd){
            if (pwd.length > 0) {
                textBookManager.payByRedeemCode(textbookObj.bookId, pwd.toUpperCase())
                qmlGlobal.showToast(YTranslateText.textbookVerificationCodeVerifying, YColors.grayNormal)
            }
        })
        keyBoardPage.placeHolderText = YTranslateText.textbookInputVerificationCode
        keyBoardPage.visible = true
        qmlGlobal.inputPageShowing = true
    }

    function requestKeyboard() {
        const component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            let incubator = component.incubateObject(id_keyboard_container);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready) {
                        console.log("Object", incubator.object, "is now ready!");
                        showKeyboard(incubator.object)
                    }
                }
            } else {
                console.log("Object", incubator.object, "is ready immediately!");
                showKeyboard(incubator.object)
            }
        }
    }

    onTextbookIsBoughtChanged: {
        //console.log("YTextbookOperation.qml === onTextbookDownloadStateChanged textbookIsBought:", textbookIsBought)
        updateShowContentState()
    }

    onTextbookIsExpiratedChanged: {
        //console.log("YTextbookOperation.qml === onTextbookDownloadStateChanged textbookIsExpirated:", textbookIsExpirated)
        updateShowContentState()
    }

    onTextbookDownloadStateChanged: {
        //console.log("YTextbookOperation.qml === onTextbookDownloadStateChanged textbookDownloadState:", textbookDownloadState)
        updateShowContentState()
    }

    YVerticalTitleBar {
        onCallBack: {
            if (showContentState === YEnum.TB_OS_PaymentQrcode) {
                textBookManager.stopOrderStatusCheckLoop()
                showContentState = YEnum.TB_OS_Bought
            } else if (showBoughtTipDetail) {
                showBoughtTipDetail = false
            } else {
                id_textbook_page.closeOperationSubPage()
            }
        }
        objectName: "YBackButtonPage.qml_" + id_textbook_operation_item.objectName

        YIconButton {
            id: id_textbook_block_delete_button
            implicitWidth: 30
            implicitHeight: 30
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 10
            radius: height * 0.5
            color: YColors.grayButton
            icon: "ic_delete"
            iconSourceSize: Qt.size(24, 24)
            visible: textbookObj.downloadState === YEnum.DS_SUCCEED

            onClicked: {
                id_textbook_operation_drawer_layer.drawerLayerType = 2
                id_textbook_operation_drawer_layer.show()
            }
        }

        YIconButton {
            id: id_vertical_bottom_button_icon
            implicitWidth: 30
            implicitHeight: 30
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 10
            sourceSize: Qt.size(24, 24)
            visible: icon.length > 0
            radius: height / 2
            icon: {
                switch (showContentState) {
                case YEnum.TB_OS_Bought:
                    return "textbook/verification-code"
                case YEnum.TB_OS_StartStudy:
                case YEnum.TB_OS_ContinueBought:
                case YEnum.TB_OS_PaymentQrcode:
                case YEnum.TB_OS_Download:
                case YEnum.TB_OS_Rebought:
                default:
                    return ""
                }
            }
            YMouseArea {
                anchors.fill: parent
                anchors.bottomMargin: -10

                onClicked: {
                    if (id_vertical_bottom_button_icon.icon.indexOf("code") >= 0) {
                        logManager.sendHttpLog("action=textbook_coupon_click")
                        id_textbook_operation_drawer_layer.drawerLayerType = 1
                        id_textbook_operation_drawer_layer.show()
                    }
                }
            }
        }
    }

    Item {
        id: id_textbook_operation_content
        anchors.fill: parent
        anchors.leftMargin: 54
        anchors.rightMargin: 10


        Rectangle {
            id: id_textbook_icon
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            color: "#000000"
            radius: 16

            Loader {
                id: id_textbook_icon_loader
                anchors.fill: parent
                sourceComponent: {
                    if ((showContentState === YEnum.TB_OS_PaymentQrcode)) {
                        return id_textbook_payment_qrcode_component
                    } else {
                        return id_textbook_brief_component
                    }
                }
            }

            Component {
                id: id_textbook_payment_qrcode_component

                Item {
                    id: id_textbook_icon_item_root
                    width: id_textbook_icon.width
                    height: id_textbook_icon.height

                    YTextMedium {
                        id: id_textbook_fullTitle_text
                        width: parent.width
                        height: 44
                        lineHeightMode: Text.FixedHeight
                        lineHeight: height/2
                        anchors.top: parent.top
                        anchors.left: parent.left
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                        font.family: qmlGlobal.fontFamilyZhCn
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        text: textbookObj.fullTitle
                    }

                    YBackground {
                        id: id_qrcode_bg
                        anchors.top: id_textbook_fullTitle_text.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        width: 90
                        height: 90
                        color: YColors.white
                        radius: 8
                        Image {
                            id: id_qrcode_icon
                            anchors.fill: parent
                            visible: paymentQrContent.length > 0
                            source: visible ? paymentQrContent : ""
                        }

                        YImage {
                            id: id_qrcode_icon_default
                            anchors.centerIn: parent
                            sourceSize: Qt.size(44, 24)
                            imageName: "login/login-default-qr"
                            visible: !id_qrcode_icon.visible
                        }

                    }

                    Column {
                        anchors.left: id_qrcode_bg.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.top: id_qrcode_bg.top
                        anchors.bottom: id_qrcode_bg.bottom
                        spacing: 8

                        YText {
                            id: id_textbook_price_text
                            width: parent.width
                            height: 21
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                            color: YColors.grayText
                            text: YTranslateText.textbookPrice

                            YTextMedium {
                                id: id_textbook_price_info_text
                                anchors.fill: parent
                                anchors.leftMargin: 50
                                font.family: qmlGlobal.fontFamilyZhCn
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                                color: YColors.red
                                text: textbookObj.priceBrief
                            }
                        }



                        YText {
                            id: id_textbook_bought_tip_text
                            width: parent.width
                            height: 60
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 20
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 15
                            verticalAlignment: Text.AlignVCenter
                            color: YColors.grayText
                            textFormat: Text.RichText
                            text: {
                                let qsPayMethod = ""
                                switch (paymentMethod) {
                                case YEnum.OC_WX:
                                    qsPayMethod = YTranslateText.textbookPaymentTipWeChat
                                    break
                                case YEnum.OC_ALI:
                                default:
                                    qsPayMethod = YTranslateText.textbookPaymentTipAlipay
                                    break
                                }
                                return YTranslateText.textbookPaymentTip.arg('<span style="color:' + YColors.red + ';">' + qsPayMethod + '</span>')

                            }
                        }

                    }
                }
            }

            Component {
                id: id_textbook_brief_component

                Item {
                    id: id_textbook_brief
                    anchors.fill: parent

                    Item {
                        id: id_textbook_icon_item_root
                        width: 102
                        height: id_textbook_icon.height

                        Image {
                            id: _image
                            readonly property string iconSource: qmlGlobal.fileExists(textbookObj.icon) ? textbookObj.icon.toLoadFileUrl()
                                                                                                        : "image://icons/textbook/book_default.png"

                            smooth: true
                            visible: false
                            anchors.fill: parent
                            source: iconSource
                            sourceSize: Qt.size(parent.width, parent.height)
                            antialiasing: true

                            Rectangle {
                                width: parent.width
                                height: 46
                                anchors.bottom: parent.bottom
                                color: "#000000"
                                opacity: 0.5
                            }
                        }
                        OpacityMask {
                            id: mask_image
                            anchors.fill: _image
                            source: _image
                            maskSource: id_textbook_icon
                            visible: true
                            antialiasing: true
                        }

                        YShadowText {
                            id: id_item_publisher
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            maximumLineCount: 2
                            font.pixelSize: 14
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: textbookObj.publisher
                            wrapMode: YText.WrapAnywhere
                            elide: YText.ElideRight
                            visible: _image.iconSource.indexOf("book_default.png") > 0
                        }

                        YText {
                            id: id_item_title
                            anchors.top: id_item_publisher.bottom
                            anchors.topMargin: 8
                            anchors.left: id_item_publisher.left
                            anchors.right: id_item_publisher.right
                            height: 18
                            font.pixelSize: 14
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: textbookObj.title
                            elide: YText.ElideRight
                            visible: _image.iconSource.indexOf("book_default.png") > 0
                        }


                        Item {
                            width: parent.width
                            height: 46
                            anchors.bottom: parent.bottom

                            YImage {
                                id: id_item_bottom_shop_image
                                imageName: "textbook/shopping-cart"
                                sourceSize: Qt.size(18, 18)
                                width: sourceSize.width
                                height: sourceSize.height
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 13
                                visible: showContentState === YEnum.TB_OS_Bought
                            }

                            YTextMedium {
                                id: id_item_bottom_shop_text
                                color: YColors.white
                                font.family: qmlGlobal.fontFamilyZhCn
                                font.pixelSize: 14
                                width: 56
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 13
                                text: YTranslateText.textbookClickToBuy
                                visible: showContentState === YEnum.TB_OS_Bought
                            }

                            YTextMedium {
                                id: id_item_bottom_expiration_text
                                color: YColors.white
                                width: contentWidth
                                height: contentHeight
                                font.family: qmlGlobal.fontFamilyZhCn
                                font.pixelSize: {
                                    switch (showContentState) {
                                    case YEnum.TB_OS_ContinueBought:
                                    case YEnum.TB_OS_Download:
                                    case YEnum.TB_OS_StartStudy:
                                        return 13
                                    default:
                                        return 14
                                    }
                                }
                                anchors.centerIn: parent
                                text: {
                                    switch (showContentState) {
                                    case YEnum.TB_OS_ContinueBought:
                                    case YEnum.TB_OS_Download:
                                    case YEnum.TB_OS_StartStudy:
                                        return textbookObj.expirationString + YTranslateText.textbookExpire
                                    case YEnum.TB_OS_Rebought:
                                        return YTranslateText.textbookExpire
                                    }
                                    return ""
                                }
                                visible: text.length > 0
                            }
                        }

                        YMouseArea {
                            id: id_clickabled_button
                            anchors.fill: parent
                            anchors.margins: -10
                            enabled: showContentState === YEnum.TB_OS_Bought
                            onClicked: {
                                if (showContentState === YEnum.TB_OS_Bought) {
                                    logManager.sendHttpLog("action=textbook_purchase_click")
                                    id_textbook_operation_drawer_layer.drawerLayerType = 0
                                    id_textbook_operation_drawer_layer.show()
                                }
                            }
                            objectName: "YTextbookOperation.qml_textbookicon"
                        }
                    }

                    Item {
                        id: id_textbook_content
                        anchors.left: id_textbook_icon_item_root.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        height: id_textbook_icon.height

                        YTextMedium {
                            id: id_textbook_fullTitle_text
                            width: parent.width
                            height: 48
                            lineHeightMode: Text.FixedHeight
                            lineHeight: height/2
                            anchors.top: parent.top
                            anchors.left: parent.left
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 18
                            verticalAlignment: Text.AlignVCenter
                            text: textbookObj.fullTitle
                            YMouseArea {
                                anchors.fill: parent
                                anchors.margins: -20
                                onClicked: {
                                    showBoughtTipDetail = true
                                    id_textbook_operation_drawer_layer.drawerLayerType = 3
                                    id_textbook_operation_drawer_layer.show()
                                }
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: true
                            sourceComponent: {
                                switch (showContentState) {
                                case YEnum.TB_OS_ContinueBought:
                                case YEnum.TB_OS_Download:
                                case YEnum.TB_OS_StartStudy:
                                case YEnum.TB_OS_Rebought:
                                    return id_textbook_dowmload_content_component
                                case YEnum.TB_OS_Bought:
                                case YEnum.TB_OS_PaymentQrcode:
                                default:
                                    return id_textbook_bought_content_component
                                }
                            }
                        }

                        Component {
                            id: id_textbook_dowmload_content_component

                            Item {
                                id: id_textbook_dowmload_content
                                anchors.fill: parent

                                YText {
                                    id: id_textbook_active_code_text
                                    width: parent.width
                                    height: 21
                                    anchors.bottom: id_textbook_dowmload_button_row.top
                                    anchors.bottomMargin: 4
                                    anchors.left: parent.left
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    font.pixelSize: 16
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    color: YColors.grayText
                                    text: textbookObj.activeCode.length > 0 ? YTranslateText.textbookActiveCode + textbookObj.activeCode : ""
                                }

                                Row {
                                    id: id_textbook_dowmload_button_row
                                    anchors.bottom: parent.bottom
                                    height: 50
                                    spacing: 8

                                    YDownloadProgressButton {
                                        id: id_download_progress_button
                                        implicitWidth: 142
                                        buttonColor: YColors.grayButton
                                        progressColor: YColors.blueRect
                                        visible: showContentState === YEnum.TB_OS_Download
                                        clickable: visible
                                        textFamily: qmlGlobal.fontFamilyZhCn
                                        text: textbookObj.downloadState !== YEnum.DS_ING
                                              ? YTranslateText.clickToDownload
                                              : YTranslateText.downloadProgress.arg(textbookObj.progress)
                                        onDownload: {
                                            if (textbookObj.downloadState === YEnum.DS_SUCCEED) {
                                                return
                                            }
                                            if (!wifiManager.internetConnect) {
                                                qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                                return
                                            }
                                            if (textbookObj.downloadState !== YEnum.DS_ING) {
                                                textBookManager.downloadBook(textbookObj.bookId)
                                            } else {
                                                textBookManager.downloadPause(textbookObj.bookId)
                                            }
                                        }
                                        Component.onCompleted: {
                                            id_download_progress_button.progress = Qt.binding(function() {
                                                return textbookObj.progress
                                            })
                                        }
                                    }

                                    YButton {
                                        height: parent.height
                                        width: 142
                                        color: YColors.blueRect
                                        visible: {
                                            switch (showContentState) {
                                            case YEnum.TB_OS_ContinueBought:
                                            case YEnum.TB_OS_StartStudy:
                                            case YEnum.TB_OS_Rebought:
                                                return true
                                            default:
                                                return false
                                            }
                                        }
                                        textFamily: qmlGlobal.fontFamilyZhCn
                                        text: {
                                            switch (showContentState) {
                                            case YEnum.TB_OS_ContinueBought:
                                                return YTranslateText.textbookContinueBuy
                                            case YEnum.TB_OS_StartStudy:
                                                return YTranslateText.textbookStartStudy
                                            case YEnum.TB_OS_Rebought:
                                                return YTranslateText.textbookRebought
                                            default:
                                                return ""
                                            }
                                        }
                                        onValidClicked: {
                                            switch (showContentState) {
                                            case YEnum.TB_OS_ContinueBought:
                                            case YEnum.TB_OS_Rebought:
                                                showContentState = YEnum.TB_OS_Bought
                                                break
                                            case YEnum.TB_OS_StartStudy:
                                                textBookManager.setDefaultGrade(textbookObj.gradeId)
                                                textBookManager.setStudyingBook(textbookObj.bookId)
                                                showSubPage(YEnum.Textbook_Home, false)
                                                break
                                            default:
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: id_textbook_bought_content_component

                            Item {
                                id: id_textbook_bought_content
                                anchors.fill: parent

                                YText {
                                    id: id_textbook_price_text
                                    width: contentWidth
                                    height: id_textbook_price_info_text.height
                                    anchors.bottom: id_textbook_bought_tip_text.top
                                    anchors.bottomMargin: 2
                                    anchors.left: parent.left
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    color: YColors.grayText
                                    text: YTranslateText.textbookPrice
                                }

                                YTextMedium {
                                    id: id_textbook_price_info_text
                                    anchors.left: id_textbook_price_text.right
                                    anchors.right: parent.right
                                    height: 21
                                    width: contentWidth
                                    anchors.verticalCenter: id_textbook_price_text.verticalCenter
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    color: YColors.red
                                    text: textbookObj.priceBrief
                                }

                                YText {
                                    id: id_textbook_bought_tip_text
                                    anchors.left: parent.left
                                    anchors.right: id_textbook_bought_tip_detail_image.left
                                    height: 72
                                    lineHeightMode: Text.FixedHeight
                                    lineHeight: 24
                                    anchors.bottom: parent.bottom
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideRight
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    color: YColors.grayText
                                    text: textbookObj.remark

                                    Behavior on height {
                                        NumberAnimation { duration: 60 }
                                    }
                                }

                                YImage {
                                    id: id_textbook_bought_tip_detail_image
                                    width: 24
                                    height: 24
                                    sourceSize: Qt.size(24, 24)
                                    imageName: "textbook/enter-icon"
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom

                                    YMouseArea {
                                        id: id_textbook_bought_tip_detail_clickarea
                                        anchors.fill: parent
                                        anchors.margins: -20
                                        onClicked: {
                                            showBoughtTipDetail = true
                                            id_textbook_operation_drawer_layer.drawerLayerType = 3
                                            id_textbook_operation_drawer_layer.show()
                                        }
                                    }
                                }

                            }
                        }

                    }
                }
            }
        }

    }

    Item {
        id: id_keyboard_container
        anchors.fill: parent
    }

    YDrawerLayer {
        id: id_textbook_operation_drawer_layer
        z: id_textbook_operation_content.z + 1
        property var drawerLayerType: 0 // 0 支付方式, 1 兑换验证码, 2 删除教材包, 3 教材详情

        Flickable {
            id: id_textbook_operation_drawer_layer_item
            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 10

            contentHeight: id_textbook_operation_drawer_layer_loader.height

            Loader {
                id: id_textbook_operation_drawer_layer_loader
                active: id_textbook_operation_drawer_layer.visible
                sourceComponent: {
                    switch (id_textbook_operation_drawer_layer.drawerLayerType) {
                    case 0:
                        return id_payment_method_component
                    case 1:
                        return id_exchange_verification_code_component
                    case 2:
                        return id_delete_textbook_block_component
                    case 3:
                    default:
                        return id_textbook_detail_component
                    }
                }

                Component {
                    id: id_textbook_detail_component

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        topPadding: 12
                        width: id_textbook_operation_drawer_layer_item.width
                        spacing: 0

                        YTextMedium {
                            id: id_textbook_fullTitle_text
                            width: parent.width
                            height: 72
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 24
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 18
                            verticalAlignment: Text.AlignVCenter
                            text: textbookObj.fullTitle
                        }


                        YSpacingForColumn {
                            implicitHeight: 10
                        }


                        YText {
                            id: id_textbook_price_text
                            width: parent.width
                            height: 21
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                            color: YColors.grayText
                            text: YTranslateText.textbookPrice

                            YTextMedium {
                                id: id_textbook_price_info_text
                                anchors.fill: parent
                                anchors.leftMargin: 50
                                font.family: qmlGlobal.fontFamilyZhCn
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                                color: YColors.red
                                text: textbookObj.priceBrief
                            }
                        }

                        YText {
                            id: id_textbook_bought_tip_text
                            width: parent.width
                            height: contentHeight
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 22
                            wrapMode: Text.WrapAnywhere
                            font.family: qmlGlobal.fontFamilyZhCn
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                            color: YColors.grayText
                            text: textbookObj.remark

                        }
                    }
                }

                Component {
                    id: id_payment_method_component

                    Column {
                        width: id_textbook_operation_drawer_layer_item.width
                        spacing: 0

                        YSpacingForColumn {
                            implicitHeight: 15
                        }

                        YText {
                            width: parent.width
                            height: 21
                            color: YColors.grayText
                            font.pixelSize: 16
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: YTranslateText.textbookSelectPaymentMethod
                        }

                        YSpacingForColumn {
                            implicitHeight: 20
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 60

                            YImageButton {
                                sourceSize: Qt.size(60, 60)
                                imageName: "textbook/payment-method-wechat"

                                YText {
                                    width: contentWidth
                                    height: 21
                                    font.pixelSize: 16
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 7
                                    text: YTranslateText.textbookPaymentMethodWeChat
                                }

                                onClicked: {
                                    if (!wifiManager.internetConnect) {
                                        qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                        return
                                    }
                                    logManager.sendHttpLog("action=textbook_purchase_wechat_click")
                                    paymentQrContent = ""
                                    paymentQrcodeOrderId = ""
                                    textBookManager.queryQrcode(textbookObj.bookId, YEnum.OC_WX)
                                    paymentMethod = YEnum.OC_WX
                                    showBoughtTipDetail = false
                                    showContentState = YEnum.TB_OS_PaymentQrcode
                                    id_textbook_operation_drawer_layer.hide()
                                }
                            }

                            YImageButton {
                                sourceSize: Qt.size(60, 60)
                                imageName: "textbook/payment-method-alipay"

                                YText {
                                    width: contentWidth
                                    height: 21
                                    font.pixelSize: 16
                                    font.family: qmlGlobal.fontFamilyZhCn
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 7
                                    text: YTranslateText.textbookPaymentMethodAlipay
                                }

                                onClicked: {
                                    if (!wifiManager.internetConnect) {
                                        qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                        return
                                    }
                                    logManager.sendHttpLog("action=textbook_purchase_alipay_click")
                                    paymentQrContent = ""
                                    paymentQrcodeOrderId = ""
                                    textBookManager.queryQrcode(textbookObj.bookId, YEnum.OC_ALI)
                                    paymentMethod = YEnum.OC_ALI
                                    showBoughtTipDetail = false
                                    showContentState = YEnum.TB_OS_PaymentQrcode
                                    id_textbook_operation_drawer_layer.hide()
                                }
                            }
                        }
                    }
                }

                Component {
                    id: id_exchange_verification_code_component

                    Item {
                        width: id_textbook_operation_drawer_layer_item.width
                        height: id_textbook_operation_drawer_layer_item.height

                        YText {
                            id: id_exchange_verification_code_text
                            width: parent.width
                            height: 78
                            anchors.top: parent.top
                            anchors.topMargin: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAnywhere
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: YTranslateText.textbookExchangeVerificationCode
                        }

                        YButton {
                            id: id_exchange_verification_code_cancel
                            anchors.top: id_exchange_verification_code_text.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            width: 120
                            color: YColors.grayButton
                            textFamily: qmlGlobal.fontFamilyZhCn
                            text: ("取消")

                            onValidClicked: {
                                id_textbook_operation_drawer_layer.hide()
                            }
                        }

                        YButton {
                            id: id_exchange_verification_code_confirm
                            anchors.verticalCenter: id_exchange_verification_code_cancel.verticalCenter
                            anchors.left: id_exchange_verification_code_cancel.right
                            anchors.leftMargin: 8
                            width: 120
                            textFamily: qmlGlobal.fontFamilyZhCn
                            text: ("确认")

                            onValidClicked: {
                                if (!wifiManager.internetConnect) {
                                    qmlGlobal.showToast(YTranslateText.networkAbnormalPleaseCheck, YColors.grayNormal)
                                    return
                                }
                                id_textbook_operation_drawer_layer.hide()
                                requestKeyboard()
                            }
                        }
                    }
                }

                Component {
                    id: id_delete_textbook_block_component

                    Item {
                        width: id_textbook_operation_drawer_layer_item.width
                        height: id_textbook_operation_drawer_layer_item.height

                        YText {
                            id: id_exchange_verification_code_text
                            width: parent.width
                            height: 78
                            anchors.top: parent.top
                            anchors.topMargin: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAnywhere
                            font.family: qmlGlobal.fontFamilyZhCn
                            text: ("确认删除“%1”吗？").arg(textbookObj.title)
                        }

                        YButton {
                            id: id_exchange_verification_code_cancel
                            anchors.top: id_exchange_verification_code_text.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            width: 120
                            color: YColors.grayButton
                            textFamily: qmlGlobal.fontFamilyZhCn
                            text: ("取消")

                            onValidClicked: {
                                id_textbook_operation_drawer_layer.hide()
                            }
                        }

                        YButton {
                            id: id_exchange_verification_code_confirm
                            anchors.verticalCenter: id_exchange_verification_code_cancel.verticalCenter
                            anchors.left: id_exchange_verification_code_cancel.right
                            anchors.leftMargin: 8
                            width: 120
                            textFamily: qmlGlobal.fontFamilyZhCn
                            text: ("删除")

                            onValidClicked: {
                                textBookManager.remove(textbookObj.bookId)
                                id_textbook_operation_drawer_layer.hide()
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: textBookManager
        ignoreUnknownSignals: true

        onQrcodeReady: {
            if (bookId === textbookObj.bookId) {
                paymentQrContent = qrcontent
                paymentQrcodeOrderId = orderId
            }
        }

        onPayStatusChanged: {
            //console.log("YTextbookOperation.qml === bookId:", bookId)
            //console.log("YTextbookOperation.qml === isPayed:", isPayed)
            //console.log("YTextbookOperation.qml === chanel:", chanel)
            //console.log("YTextbookOperation.qml === errMsg:", errMsg)
            //console.log("YTextbookOperation.qml === textbookObj.bookId:", textbookObj.bookId)
            if (bookId === textbookObj.bookId)
            switch (chanel) {
            case YEnum.OC_REDEEM:
                qmlGlobal.showToast((isPayed ? YTranslateText.textbookRedeemSuccessful
                                            : YTranslateText.textbookRedeemFailed), YColors.grayButton)
                break
            case YEnum.OC_ALI:
            case YEnum.OC_WX:
                qmlGlobal.showToast((isPayed ? YTranslateText.textbookPaymentSuccessful
                                            : YTranslateText.textbookPaymentFailed), YColors.grayButton)
                break
            }
            if (isPayed) {
                showContentState = YEnum.TB_OS_Download
            }
        }
    }

    Component.onCompleted: {
        // TODO 检查即将过期,设置继续购买
        if (settingManager.studyingBookId === textbookObj.bookId && id_textbook_page.isContinueBought) {
            showContentState = YEnum.TB_OS_ContinueBought
            id_textbook_page.isContinueBought = false
        }
    }
}

