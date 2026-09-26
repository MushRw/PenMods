// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

namespace mod {

class Torch : public QObject, public Singleton<Torch> {
    Q_OBJECT

    Q_PROPERTY(bool switch READ getStatus WRITE setStatus NOTIFY statusChanged);

public:
    // explicit Torch();

    bool getStatus();

    void setStatus(bool);

    /// AP-21：给 QML 的"兜底同步"用。
    ///
    /// QML 侧**不要**写 `id_switch.switchOn = torch.switch` —— 对已绑定属性赋值会
    /// **移除绑定**，绑定机制反而被这个"兜底"废掉。要兜底就调这个：只发 NOTIFY，
    /// 让绑定重新求值（会再读一次 GPIO），值没变界面就不动。
    Q_INVOKABLE void refreshStatus();

signals:

    void statusChanged();

private:
    friend Singleton<Torch>;
    explicit Torch();

    std::string mClassName = "torch";
};


} // namespace mod
