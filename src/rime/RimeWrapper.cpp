#include "RimeWrapper.h"
#include "common/service/Logger.h"
#include "rime_api.h"
#include "spdlog/spdlog.h"
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QTimer>

namespace mod::rime {

RimeApi* RimeWrapper::s_api = nullptr;

namespace {
// librime 全局状态是否已初始化（原来写在 globalInitialize 里的函数内 static，
// 但空闲回收需要复位它，所以提到文件作用域）
bool    g_rimeInitialized  = false;
// 空闲回收定时器（延迟释放，避免频繁开关输入页时反复重载词库）
QTimer* g_idleReleaseTimer = nullptr;
// 活着的 RimeWrapper 实例数：归零才安排回收，避免页面切换期间误释放
int     g_liveInstances    = 0;
} // namespace

// Rime 通知回调
void rimeNotificationHandler(
    void*         context_object,
    RimeSessionId session_id,
    const char*   message_type,
    const char*   message_value
) {
    Q_UNUSED(context_object);
    Q_UNUSED(session_id);
    // 这里仅做日志，避免在静态回调中访问实例成员导致 crash
    spdlog::debug("Rime notification: {} {}", message_type, (message_value ? message_value : ""));
}

// 构造函数只取 API 指针，不做任何重活：
// librime 的全局初始化（加载 6.7MB 词库 + start_maintenance）和建会话都推迟到
// ensureReady()，由第一次真正用输入法时触发。这样即使 QML 很早就 new 出实例，
// 开机阶段也不会付这份代价。
RimeWrapper::RimeWrapper(QObject* parent) : QObject(parent), Logger("RimeWrapper"), m_sessionId(0) {
    ++g_liveInstances;
    if (!s_api) {
        s_api = rime_get_api();
    }
}

// 首次真正用输入法时调用：全局初始化 + 建会话（幂等）
void RimeWrapper::ensureReady() {
    if (m_rimeReady) {
        return;
    }
    m_rimeReady = true;

    // 有实例在用，取消待执行的空闲回收
    if (g_idleReleaseTimer) {
        g_idleReleaseTimer->stop();
    }

    globalInitialize();

    if (s_api && s_api->create_session) {
        m_sessionId = s_api->create_session();
        if (m_sessionId) {
            spdlog::debug("Rime session created: {}", m_sessionId);
        } else {
            spdlog::error("Failed to create Rime session");
        }
    }
}

RimeWrapper::~RimeWrapper() {
    if (m_sessionId && s_api && s_api->destroy_session) {
        s_api->destroy_session(m_sessionId);
        m_sessionId = 0;
    }

    // 最后一个实例没了就延迟回收全局状态：输入页关掉后不该让词库一直占着内存。
    // 留 5 秒宽限，避免"关掉又立刻打开"时反复重载词库。
    if (--g_liveInstances <= 0) {
        g_liveInstances = 0;
        scheduleIdleRelease();
    }
}

// 释放 librime 全局状态（词典/表/prism/内部缓存）
void RimeWrapper::globalRelease() {
    if (!g_rimeInitialized) {
        return;
    }

    if (s_api) {
        // 维护线程还在跑（比如补 melt_eng 表的那次全量维护）时先等它结束，别在部署中途 finalize
        if (s_api->join_maintenance_thread) {
            s_api->join_maintenance_thread();
        }
        if (s_api->finalize) {
            s_api->finalize();
        }
    }

    g_rimeInitialized = false;
    spdlog::info("Rime 全局状态已释放（空闲回收），下次输入会重新加载词库");
}

void RimeWrapper::scheduleIdleRelease(int delayMs) {
    if (!g_idleReleaseTimer) {
        g_idleReleaseTimer = new QTimer(); // 刻意不给 parent：整个 app 生命周期只此一个
        g_idleReleaseTimer->setSingleShot(true);
        QObject::connect(g_idleReleaseTimer, &QTimer::timeout, []() { RimeWrapper::globalRelease(); });
    }
    g_idleReleaseTimer->start(delayMs);
}

#include <cstring> // for memset, strlen, strcpy

// 辅助函数保持不变
static const char* allocateString(const char* source) {
    if (!source) return nullptr;
    size_t len  = std::strlen(source) + 1;
    char*  dest = new char[len];
    std::strcpy(dest, source);
    return dest;
}

void RimeWrapper::globalInitialize() {
    if (g_rimeInitialized) return;

    RimeApi* api = rime_get_api();
    if (!api) {
        spdlog::error("Failed to get Rime API");
        return;
    }
    s_api = api;

    // ==========================================
    // 使用 {0} 显式初始化
    // 这会将所有指针成员（包括 modules）都置为 nullptr
    // ==========================================
    RimeTraits traits = {0};

    // 初始化 data_size (必做)
    RIME_STRUCT_INIT(RimeTraits, traits);

    // 手动分配内存并赋值
    traits.app_name               = allocateString("rime.penmods");
    traits.distribution_name      = allocateString("PenMods");
    traits.distribution_code_name = allocateString("penmods");
    traits.distribution_version   = allocateString("1.0");

    // 定义路径
    const char* userDataPath   = allocateString("/userdisk/Music/Rime");
    const char* logDirPath     = allocateString("/tmp/rime");
    const char* stagingDirPath = allocateString("/userdisk/Music/Rime/build");

    traits.shared_data_dir = userDataPath;
    traits.user_data_dir   = userDataPath;
    traits.log_dir         = logDirPath;
    traits.staging_dir     = stagingDirPath;
    traits.min_log_level   = 1;

    // 显式确保 modules 为空（虽然 {0} 已经做了，但为了保险起见可再次明确）
    traits.modules = nullptr;

    // 创建目录
    QDir().mkpath(userDataPath);
    QDir().mkpath(logDirPath);
    QDir().mkpath(stagingDirPath);

    spdlog::info("Rime Setup...");
    if (api->setup) {
        api->setup(&traits);
    }

    spdlog::info("Rime Initializing...");
    if (api->initialize) {
        api->initialize(&traits);
    }

    if (api->set_notification_handler) {
        api->set_notification_handler(rimeNotificationHandler, nullptr);
    }

    if (api->start_maintenance) {
        // 原来是 start_maintenance(0)：只做增量检查。实测笔上 build/ 里**从来没有**
        // melt_eng.table.bin（rime_ice.table.bin / prism / reverse 都在），而
        // rime_ice.schema.yaml 里挂着 table_translator@melt_eng（英文词库，2.5 万条），
        // 运行时加载不到表就报：
        //     Error opening table file '.../build/melt_eng.table.bin'
        //     Error loading table for dictionary 'melt_eng'
        // 增量检查认为 rime_ice 已是最新，于是永远不会补这一份。
        //
        // 这里做一次性全量维护把它补出来：start_maintenance(1) 走 staging 目录重建
        // 再整体替换，所以**即使重编失败也不会动到现有可用的表**（不会把键盘搞坏），
        // 失败最多是白跑一次。用 stamp 保证只跑一次，避免每次开机都全量重编。
        const QString meltEngTable = "/userdisk/Music/Rime/build/melt_eng.table.bin";
        const QString repairStamp  = "/userdisk/Music/Rime/build/.melt_eng_repair";
        const bool    needRepair   = !QFile::exists(meltEngTable) && !QFile::exists(repairStamp);
        if (needRepair) {
            QFile stamp(repairStamp);
            if (stamp.open(QIODevice::WriteOnly)) {
                stamp.write("1");
                stamp.close();
            }
            spdlog::info("melt_eng 词典表缺失，触发一次性全量维护补齐");
            api->start_maintenance(1); // 1 = full_check
        } else {
            spdlog::info("Rime Maintenance starting...");
            api->start_maintenance(0); // 0 = False
        }
    }

    g_rimeInitialized = true;
    spdlog::info("Rime Global Initialized Successfully");
}

QString     RimeWrapper::preeditText() const { return m_preeditText; }
QStringList RimeWrapper::candidates() const { return m_candidates; }

bool RimeWrapper::processKey(const QString& key) {
    ensureReady(); // 首次真正输入时才加载词库 / 建会话
    if (!m_sessionId || !s_api) {
        qWarning() << "Rime Not Initialized!";
        return false;
    }

    int keycode = 0;
    int mask    = 0;

    // 按键映射 (参考 X11 KeySyms)
    if (key.length() == 1) {
        QChar ch = key[0];
        if (ch.isSpace()) keycode = 0xff20; // Space
        else if (ch == '\b') keycode = 0xff08;
        else keycode = ch.toLatin1(); // 普通字符
    } else if (key == "space") keycode = 0xff20;
    else if (key == "BackSpace" || key == "backspace") keycode = 0xff08;
    else if (key == "Return" || key == "Enter") keycode = 0xff0d;
    else if (key == "Escape") keycode = 0xff1b;
    // 翻页键
    else if (key == "PageUp") keycode = 0xff55;
    else if (key == "PageDown") keycode = 0xff56;
    else if (key == "Up") keycode = 0xff52;
    else if (key == "Down") keycode = 0xff54;
    else if (key == "Left") keycode = 0xff51;
    else if (key == "Right") keycode = 0xff53;
    else {
        // 未知按键不处理
        return false;
    }

    bool handled = false;
    if (s_api->process_key) {
        handled = s_api->process_key(m_sessionId, keycode, mask);
    }

    // 无论是否 handle，都检查一下 context 变化（有时 rime 状态会变）
    updateContext();
    return handled;
}

void RimeWrapper::selectCandidate(int index) {
    ensureReady(); // 首次真正输入时才加载词库 / 建会话
    if (!m_sessionId || !s_api) return;
    if (s_api->select_candidate) {
        s_api->select_candidate(m_sessionId, static_cast<size_t>(index));
        updateContext();
    }
}

void RimeWrapper::clear() {
    if (!m_sessionId || !s_api) return;
    if (s_api->clear_composition) {
        s_api->clear_composition(m_sessionId);
        updateContext();
    }
}

void RimeWrapper::updateContext() {
    if (!m_sessionId || !s_api) return;

    // INIT 会正确设置 data_size，防止 librime 内部处理结构体时出错。
    RimeContext ctx;
    RIME_STRUCT_INIT(RimeContext, ctx);

    if (s_api->get_context && s_api->get_context(m_sessionId, &ctx)) {
        // 1. 更新 Preedit
        QString newPreedit;
        if (ctx.composition.preedit) {
            newPreedit = QString::fromUtf8(ctx.composition.preedit);
        }
        if (m_preeditText != newPreedit) {
            m_preeditText = newPreedit;
            emit preeditTextChanged();
        }

        // 2. 更新 Candidates
        QStringList newCandidates;
        if (ctx.menu.num_candidates > 0 && ctx.menu.candidates) {
            for (int i = 0; i < ctx.menu.num_candidates; ++i) {
                if (ctx.menu.candidates[i].text) {
                    newCandidates << QString::fromUtf8(ctx.menu.candidates[i].text);
                }
            }
        }

        if (m_candidates != newCandidates) {
            m_candidates = newCandidates;
            emit candidatesChanged();
        }

        s_api->free_context(&ctx);
    }

    // 3. 检查 Commit
    RimeCommit commit;

    // 同样使用 INIT
    RIME_STRUCT_INIT(RimeCommit, commit);

    if (s_api->get_commit && s_api->get_commit(m_sessionId, &commit)) {
        if (commit.text) {
            QString commitStr = QString::fromUtf8(commit.text);
            if (!commitStr.isEmpty()) {
                onCommit(commitStr);
            }
        }
        s_api->free_commit(&commit);
    }
}

void RimeWrapper::onCommit(const QString& text) {
    if (!text.isEmpty()) {
        emit commitText(text);
    }
}

} // namespace mod::rime
