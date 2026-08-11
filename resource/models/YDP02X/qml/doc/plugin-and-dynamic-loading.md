# Plugin & Dynamic Loading

## 一、插件系统

### 架构
```
pluginManager (C++ com.youdao.pen 1.0)
  ├── 发现插件（扫描目录）
  ├── 启用/禁用
  └── 状态通知 (pluginListUpdated, pluginStateChanged)
        │
        ▼
PluginManager.qml (管理界面)
YIndexPage.qml (插件抽屉 - 已启用插件的快捷入口)
```

### 插件生命周期
1. `pluginManager` 发现插件并通知 QML
2. `PluginManager.qml` 显示插件列表，支持启用/禁用
3. 启用后在 `YIndexPage` 底部显示插件抽屉
4. 点击插件图标 → 动态加载插件 UI

## 二、动态加载模式

以下组件使用相同的动态加载模式：

| 位置 | 用途 |
|---|---|
| `YSettingPage` | 加载设置子页面 |
| `PluginManager` | 加载插件弹窗 |
| `ChatAssistant` | 加载聊天弹窗（文件管理、设置等） |
| `YIndexPage` | 加载插件 UI |
| `AudioRecorder` | 加载文件操作界面 |

### 标准实现模板

```qml
Item {
    id: id_pop_container
    z: 500
    signal closeSameItem(string popStackId)

    function newComponentInit(url, properties, popStackId) {
        var component = Qt.createComponent(url)
        var obj = component.incubateObject(id_pop_container, properties)
        obj.onStatusChanged = function(status) {
            if (status === Component.Ready) {
                // 附加 popStackId
                Object.defineProperty(obj, "popStackId", {
                    configurable: true,
                    value: popStackId
                })

                // 信号连接
                obj.backButtonClicked.connect(closeAll)
                qmlGlobal.requestShowPage.connect(obj.closeAll)
                systemBase.homeKeyRelease.connect(obj.closeAll)

                // 清理管理
                var cleanups = []
                cleanups.push(function() {
                    qmlGlobal.requestShowPage.disconnect(obj.closeAll)
                })
                // ... 更多清理
            }
        }
    }

    function closeAll() {
        // 清理所有连接
        // destroy children
    }
}
```

## 三、词典组件动态加载

`YDictPage` 根据 `dictType` 枚举值动态加载对应的词典类型组件：

```qml
// 通过 Loader
YDictTypeBase {
    id: id_result_loader
    // 根据 resultManager 中的 dictType 属性
    // 动态设置 sourceComponent 为对应的 YDictTypeDt*.qml
}
```

## 四、登录状态动态切换

`YLoginPage` 使用 Loader 系列组件根据登录状态切换 UI：

```qml
YLoginPageLoginStatusLoader      → 根据状态加载已登录/未登录界面
  ├── YLoginPageRealTimeDisplay  → 实时显示模式
  ├── YLoginPageLogoutConfirm   → 登出确认
  └── YAddBindAccountDisplay    → 添加绑定账号
```

## 五、图片资源解析

自定义图片引擎通过 C++ 端（`res` 对象）将 `imageName` 解析为实际资源：

```qml
YImage {
    imageName: "home-dict"       // 逻辑名称，非实际路径
    // 内部通过 C++ 引擎查找并渲染
}
```

支持格式：
- 内置图标：`home-*`, `settings/*`, `audiopage/*`, `dict/*`, `login/*` 等
- 外部图片：`file://` 动态加载（壁纸）
- 自定义 Image Provider：`image://icons/portrait.png`
