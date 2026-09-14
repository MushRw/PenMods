#ifndef RIMEWRAPPER_H
#define RIMEWRAPPER_H

#include <QObject>
#include <QString>
#include <QStringList>

// 引入 librime API 包装头文件
#include "RimeApiWrapper.h"
#include "common/service/Logger.h"

namespace mod::rime {

class RimeWrapper : public QObject, private Logger {
    Q_OBJECT

    Q_PROPERTY(QString preeditText READ preeditText NOTIFY preeditTextChanged)
    Q_PROPERTY(QStringList candidates READ candidates NOTIFY candidatesChanged)

public:
    explicit RimeWrapper(QObject *parent = nullptr);
    ~RimeWrapper();

    QString preeditText() const;
    QStringList candidates() const;

    // 处理按键
    Q_INVOKABLE bool processKey(const QString &key);
    
    // 选中第 index 个候选词
    Q_INVOKABLE void selectCandidate(int index);
    
    // 重置 Rime 会话
    Q_INVOKABLE void clear();

    // 静态全局初始化函数（现在由 ensureReady 惰性调用）
    static void globalInitialize();

signals:
    void preeditTextChanged();
    void candidatesChanged();
    void commitText(const QString &text); 

private:
    // 首次真正用到输入法时才做：全局初始化 + 建会话。
    // 构造函数里什么都不做，因此即使 QML 很早就 new 出这个对象，也不会在开机阶段加载词库。
    void ensureReady();

    void updateContext();
    void onCommit(const QString &text);

private:
    RimeSessionId m_sessionId;    // Rime 会话 ID
    bool          m_rimeReady = false; // 是否已完成全局初始化 + 建会话
    QString m_preeditText;        // 预编辑文本
    QStringList m_candidates;     // 候选词列表
    
    // 缓存 API 指针，避免每次都获取
    static RimeApi* s_api;
};

} // namespace mod::rime

#endif // RIMEWRAPPER_H