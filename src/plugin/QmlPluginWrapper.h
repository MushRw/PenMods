#pragma once

#include "PluginManager.h"
#include "common/service/Singleton.h"
#include <QJSEngine>
#include <QObject>
#include <QQmlEngine>

namespace mod {

/**
 * @brief 为 QML 提供插件管理功能的包装类
 */
class QmlPluginWrapper : public QObject, public Singleton<QmlPluginWrapper> {
    Q_OBJECT
    QML_SINGLETON
    QML_NAMED_ELEMENT(PluginManager)

public:
    explicit QmlPluginWrapper(QObject* parent = nullptr);

    Q_INVOKABLE int         getPluginCount();
    Q_INVOKABLE QJsonObject getPluginInfo(int index);
    Q_INVOKABLE bool        setPluginEnabled(const QString& pluginName, bool enabled);
    Q_INVOKABLE void        uninstallPlugin(const QString& pluginName);
    Q_INVOKABLE void        requestPluginList();

    // 插件页关闭后调用：回收 QML 组件缓存 + JS 堆，并把前后 VmRSS 写进日志。
    // 插件自己的 .so（以及它注册的后台钩子，比如 LX-Pen 的后台播放）不能卸，
    // 那部分常驻是设计使然；这里只收 Qt 侧那些"关了页面也不还"的内存。
    Q_INVOKABLE void        onPluginPageClosed();

signals:
    void pluginListUpdated();
    void pluginStateChanged(const QString& pluginName, bool newState);

private slots:
    void onPluginsChanged();

private:
    PluginManager* m_pluginManager;
    QString        resolvePluginId(const QString& idOrName) const;
    friend class Singleton<QmlPluginWrapper>;
};

} // namespace mod
