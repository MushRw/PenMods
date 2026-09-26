// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "torch/Torch.h"

#include "common/Event.h"
#include "common/Utils.h"

#include <QFile>
#include <QQmlContext>

#if PL_BUILD_YDP02X
constexpr auto LED_DEFAULT_GPIO_ID = 15;
#endif

namespace mod {

Torch::Torch() {
    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        context->setContextProperty("torch", this);
    });
}

bool Torch::getStatus() {
#if PL_BUILD_YDP02X
    // 这是 Q_PROPERTY 的 READ，会被 QML 轮询；不要用 exec()（popen+fork+cat）。
    QFile value(QString("/sys/class/gpio/gpio%1/value").arg(LED_DEFAULT_GPIO_ID));
    if (!value.open(QIODevice::ReadOnly)) {
        return false;
    }
    return value.readAll().trimmed() == "1";
#else
    return false;
#endif
}

void Torch::setStatus(bool stat) {
    if (getStatus() != stat) {
        if (stat) {
#if PL_BUILD_YDP02X
            PEN_CALL(void*, "led_on", uint32)(LED_DEFAULT_GPIO_ID);
#endif
        } else {
#if PL_BUILD_YDP02X
            PEN_CALL(void*, "led_off", uint32)(LED_DEFAULT_GPIO_ID);
#endif
        }
        emit statusChanged();
    }
}

void Torch::refreshStatus() {
    // 无脑发：绑定会重新求值 `torch.switch`（= 再读一次 GPIO），
    // 值真变了 QML 才会更新，没变就是一次 sysfs 读的代价。
    emit statusChanged();
}

} // namespace mod
