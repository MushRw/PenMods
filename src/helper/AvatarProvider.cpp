// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "helper/AvatarProvider.h"

#include <QImageReader>
#include <QPainter>
#include <QPainterPath>
#include <QQmlEngine>
#include <QUrl>

#include <spdlog/spdlog.h>

namespace mod {

AvatarProvider::AvatarProvider(QQmlEngine* engine)
    : QQuickImageProvider(QQuickImageProvider::Image), m_iconsProvider(nullptr) {
    if (engine) {
        m_iconsProvider = engine->imageProvider("icons");
    }
    if (!m_iconsProvider) {
        spdlog::warn("[AvatarProvider] 应用 icons 图片提供器未注册，默认头像可能无法加载");
    }
}

QImage AvatarProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize) {
    QString source = QUrl::fromPercentEncoding(id.toUtf8());

    QImage image;
    if (source.startsWith("image://icons/")) {
        // 应用自己的图标提供器，转调其 requestImage 取原图
        QString iconId = source.mid(QStringLiteral("image://icons/").size());
        if (m_iconsProvider) {
            // 图片提供器必然是 QQuickImageProvider 派生
            auto* prov = static_cast<QQuickImageProvider*>(m_iconsProvider);
            QSize providerSize;
            image = prov->requestImage(iconId, &providerSize, requestedSize);
        }
    } else {
        // QImageReader 只接受本地路径：file:// 需转成路径，qrc:/ 需去掉 qrc 前缀
        QString path = source;
        if (source.startsWith("file://")) {
            path = QUrl(source).toLocalFile();
        } else if (source.startsWith("qrc:/")) {
            path = source.mid(3); // qrc:/xxx -> :/xxx
        }
        QImageReader reader(path);
        if (reader.canRead()) {
            image = reader.read();
        }
    }

    if (image.isNull()) {
        spdlog::warn("[AvatarProvider] 无法加载头像源: {}", source.toStdString());
        return image;
    }

    int s = requestedSize.isValid() ? qMax(requestedSize.width(), requestedSize.height()) : image.width();
    s    = qMax(1, s);
    image = image.scaled(s, s, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    image = image.copy((image.width() - s) / 2, (image.height() - s) / 2, s, s);

    QImage out(s, s, QImage::Format_ARGB32_Premultiplied);
    out.fill(Qt::transparent);
    QPainter p(&out);
    p.setRenderHint(QPainter::Antialiasing, true);
    QPainterPath path;
    path.addEllipse(0, 0, s, s);
    p.setClipPath(path);
    p.drawImage(0, 0, image);
    p.end();

    if (size) {
        *size = QSize(s, s);
    }
    return out;
}

} // namespace mod
