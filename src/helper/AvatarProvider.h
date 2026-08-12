// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include <QQuickImageProvider>

class QQmlEngine;

namespace mod {

// 圆形头像图片提供器：把任意来源（file://、qrc:/、image://icons/...）的图片
// 居中裁切成圆形。纯 CPU 处理，不依赖着色器，保证在低性能设备上正常渲染。
class AvatarProvider : public QQuickImageProvider {
public:
    explicit AvatarProvider(QQmlEngine* engine);

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;

private:
    // 在 GUI 线程构造时解析并缓存（图片提供器 requestImage 运行在图片线程，
    // 不能直接访问 QQmlEngine）
    QQmlImageProviderBase* m_iconsProvider;
};

} // namespace mod
