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

namespace mod {

QImage AvatarProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize) {
    QString source = QUrl::fromPercentEncoding(id.toUtf8());

    QImage image;
    if (source.startsWith("image://icons/")) {
        // 应用自己的图标提供器，转调其 requestImage 取原图
        QString iconId = source.mid(QStringLiteral("image://icons/").size());
        if (m_engine) {
            if (QQmlImageProviderBase* base = m_engine->imageProvider("icons")) {
                auto* prov = qobject_cast<QQuickImageProvider*>(base);
                if (!prov) return image;
                QSize providerSize;
                image = prov->requestImage(iconId, &providerSize, requestedSize);
            }
        }
    } else {
        QImageReader reader(source);
        if (reader.canRead()) {
            image = reader.read();
        }
    }

    if (image.isNull()) {
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
