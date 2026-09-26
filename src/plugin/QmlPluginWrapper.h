#pragma once

#include "PluginManager.h"
#include "common/service/Singleton.h"
#include <QJSEngine>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>

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
    Q_INVOKABLE bool        uninstallPlugin(const QString& pluginName); // PL-06: 返回成败，QML 才知道要不要刷新/提示
    Q_INVOKABLE void        requestPluginList();

    // 内存整理：QML 在插件页销毁 / 保活释放后调用；构造时也会起一个每 5 分钟的定时器。
    // 只 free 不 trim 的话 glibc 不会把内存还给内核（实测关掉插件页后 RSS 一点不降），
    // 所以这里显式 malloc_trim(0)，并做成防抖（QML 的 destroy 是延迟生效的）。
    Q_INVOKABLE void        trimMemory();

signals:
    void pluginListUpdated();
    void pluginStateChanged(const QString& pluginName, bool newState);

private slots:
    void onPluginsChanged();

private:
    PluginManager* m_pluginManager;
    QTimer*        m_trimTimer = nullptr;   // 防抖用的单次定时器
    QString        resolvePluginId(const QString& idOrName) const;
    friend class Singleton<QmlPluginWrapper>;
};

} // namespace mod
