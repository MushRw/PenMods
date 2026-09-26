#include "QmlPluginWrapper.h"
#include <QFile>
#include <QJsonArray>
#include <QTimer>
#include <QUrl>

#include <malloc.h> // malloc_trim

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
            return line.mid(6).trimmed().section(' ', 0, 0).toLongLong();
        }
    }
    return -1;
}
} // namespace

QmlPluginWrapper::QmlPluginWrapper(QObject* parent) : QObject(parent), m_pluginManager(&PluginManager::getInstance()) {
    // 连接底层插件管理器的信号
    connect(m_pluginManager, &PluginManager::pluginsChanged, this, &QmlPluginWrapper::onPluginsChanged);

    // 空闲内存整理：每 5 分钟一次。插件页反复开关会在 glibc arena 里留下碎片，
    // 只 free 不 trim 时这部分不会还给内核，足迹会单调上涨（实测 1 小时涨 260MB）。
    auto* periodicTrim = new QTimer(this);
    periodicTrim->setInterval(5 * 60 * 1000);
    connect(periodicTrim, &QTimer::timeout, this, [this]() { trimMemory(); });
    periodicTrim->start();
}

void QmlPluginWrapper::trimMemory() {
    if (!m_trimTimer) {
        m_trimTimer = new QTimer(this);
        m_trimTimer->setSingleShot(true);
        // 防抖 3 秒：QML 的 destroy(1) 是延迟生效的，立刻 trim 会赶在对象析构之前
        m_trimTimer->setInterval(3000);
        connect(m_trimTimer, &QTimer::timeout, this, []() {
            const qint64 before = currentRssKb();
            malloc_trim(0);
            spdlog::info("内存整理 malloc_trim(0): VmRSS {} KB -> {} KB", before, currentRssKb());
        });
    }
    m_trimTimer->start();
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

// PL-06: 原来返回 void，QML 拿不到失败信息。改返回 bool。
bool QmlPluginWrapper::uninstallPlugin(const QString& pluginName) {
    bool result = m_pluginManager->uninstallPlugin(resolvePluginId(pluginName));
    if (result) emit pluginListUpdated();
    return result;
}

void QmlPluginWrapper::requestPluginList() {
    m_pluginManager->scanAndLoadAll();
}

void QmlPluginWrapper::onPluginsChanged() {
    emit pluginListUpdated();
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