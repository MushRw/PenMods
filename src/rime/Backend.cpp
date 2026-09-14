#include "Backend.h"
#include "RimeWrapper.h"
#include "common/Event.h"

namespace mod::rime {

Backend::Backend() : Logger("Rime"), m_rimeWrapper(nullptr)
{
    connect(&Event::getInstance(), &Event::beforeUiInitialization, [this](QQuickView& view, QQmlContext* context) {
        Q_UNUSED(view);
        initialize(context->engine(), nullptr);
    });
}

void Backend::initialize(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);

    // 1. 注册 QML 类型
    qmlRegisterType<RimeWrapper>("com.youdao.input", 1, 0, "RimeWrapper");

    // Rime 全局初始化（加载 6.7MB 词库 + start_maintenance）已改到 RimeWrapper
    // 构造函数里惰性触发：QML 只在打开输入页时才 new 出实例，不输入法就不付这份代价。
    // 注意：不需要创建 m_rimeWrapper 实例给 setContextProperty
    // 因为 QML 文件里自己写了 "RimeWrapper { id: ... }"
    // QML 会自己 new 一个出来，那个 new 出来的实例会自动调用构造函数创建 Session

    qInfo() << "Rime backend registered and initialized";
}

} // namespace mod::rime