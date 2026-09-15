#include "QmlPluginWrapper.h"
#include <QFile>
#include <QJsonArray>
#include <QTimer>
#include <QUrl>

#include "spdlog/spdlog.h"

namespace mod {

namespace {
// 当前进程 VmRSS（KB）；读不到返回 -1
qint64 currentRssKb() {
    QFile f("/proc/self/status");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return -1;
    }
    for (const auto& line : QString::fromUtf8(f.readAll()).split('\n')) {
        if (line.startsWith("VmRSS:")) {
            // 不用 QString::SkipEmptyParts（Qt 5.15 已废弃），直接取第一个字段
            return line.mid(6).trimmed().section(' ', 0, 0).toLongLong();
        }
    }
    return -1;
}
} // namespace

QmlPluginWrapper::QmlPluginWrapper(QObject* parent) : QObject(parent), m_pluginManager(&PluginManager::getInstance()) {
    // 连接底层插件管理器的信号
    connect(m_pluginManager, &PluginManager::pluginsChanged, this, &QmlPluginWrapper::onPluginsChanged);
}

int QmlPluginWrapper::getPluginCount() {
    auto& plugins = m_pluginManager->getPlugins();
    return plugins.size();
}

QJsonObject QmlPluginWrapper::getPluginInfo(int index) {
    auto& plugins = m_pluginManager->getPlugins();
    if (index < 0 || index >= plugins.size()) return QJsonObject();

    const auto& plugin = plugins[index];
    QJsonObject obj;
    obj["id"]          = plugin.id; // 必须传递 ID
    obj["name"]        = plugin.name;
    obj["description"] = plugin.description;
    obj["version"]     = plugin.version;
    obj["author"]      = plugin.author;
    // UI 开关状态绑定到 isEnabled (偏好)，但如果 isLoaded 为 false 且 isEnabled 为 true，UI 应该知道出错了
    obj["enabled"] = plugin.isEnabled;
    obj["loaded"]  = plugin.isLoaded;
    obj["icon"]    = plugin.icon.isEmpty() ? "settings/plugin" : plugin.icon;

    // 转换路径为 URL 格式供 QML 使用
    obj["mainQmlUrl"] = QUrl::fromLocalFile(plugin.mainQml).toString();

    return obj;
}

bool QmlPluginWrapper::setPluginEnabled(const QString& pluginId, bool enabled) {
    bool result = m_pluginManager->togglePlugin(resolvePluginId(pluginId), enabled);
    if (result) emit pluginListUpdated();
    return result;
}

void QmlPluginWrapper::uninstallPlugin(const QString& pluginName) {
    bool result = m_pluginManager->uninstallPlugin(resolvePluginId(pluginName));
    if (result) emit pluginListUpdated();
}

void QmlPluginWrapper::requestPluginList() {
    m_pluginManager->scanAndLoadAll();
}

void QmlPluginWrapper::onPluginsChanged() {
    emit pluginListUpdated();
}

void QmlPluginWrapper::onPluginPageClosed() {
    // 插件页销毁后，编译过的 QML 组件和 JS 堆里的对象不会立刻还给系统，
    // RSS 就一直挂在那个高位上。等 2 秒（让销毁/事件收尾）再 GC + trim，
    // 并打印前后 VmRSS —— 这样"有没有真回收"在日志里能直接看到，不靠猜。
    QTimer::singleShot(2000, this, [this]() {
        QQmlEngine* engine = m_pluginManager ? m_pluginManager->engine() : nullptr;
        if (!engine) {
            return;
        }
        const qint64 before = currentRssKb();
        engine->collectGarbage();
        engine->trimComponentCache();
        const qint64 after = currentRssKb();
        spdlog::info("插件页已关闭，回收 QML/JS: VmRSS {} KB -> {} KB", before, after);
    });
}

QString QmlPluginWrapper::resolvePluginId(const QString& idOrName) const {
    const auto& plugins = m_pluginManager->getPlugins();
    for (const auto& p : plugins)
        if (p.id == idOrName) return idOrName;
    for (const auto& p : plugins)
        if (p.name == idOrName) return p.id;
    return idOrName;
}

} // namespace mod