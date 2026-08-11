# Navigation & Pages

## 一、页面导航系统

### 页面索引（C++ 枚举）
页面通过 `qmlGlobal.requestShowPage(index)` 切换，索引值定义在 C++ 插件 `YEnum` 中。

### 页面列表

| 页面文件 | 功能 | 基类 |
|---|---|---|
| `YIndexPage.qml` | 首页/主菜单 | YBackground |
| `YDictPage.qml` | 词典搜索结果 | YBackButtonPage |
| `YDictDetailPage.qml` | 词典详情 | YBackButtonPage |
| `YSpeechPage.qml` | 语音助手 | YPage |
| `YTouchReadingPage.qml` | 触读 | YPage |
| `YTextbookPage.qml` | 课本同步 | YPage |
| `YWordBookPage.qml` | 单词本 | YPage |
| `YAudioPage.qml` | 听力练习 | YPage |
| `YHistoryPage.qml` | 历史记录 | YBackButtonPage |
| `YSettingPage.qml` | 系统设置 | YPage |
| `YLoginPage.qml` | 用户登录 | YBackButtonPage |
| `YFollowPage.qml` | 跟读 | YBackButtonPage |
| `YSpellPage.qml` | 拼写 | YPage |
| `YInputPage.qml` | 自定义输入法 | YPage |
| `YPowerOffPage.qml` | 关机 | YPage |
| `AudioRecorder.qml` | 录音 | YBackButtonPage |
| `ChatAssistant.qml` | AI 聊天 | YPage |
| `PluginManager.qml` | 插件管理 | YBackButtonPage |

### 页面生命周期

```
YPage.show()
  ├── visible = true
  ├── state = "show"
  └── 向 C++ 注册当前页面索引 (currentPageIndex)

YPage.todoDestroy()
  ├── state = "close"
  ├── 延迟 destroy() / 从父级移除
  └── 清理 connectionCleanups
```

## 二、导航栈 (YStackView)

`YStackView` 管理弹窗式页面的显示：

- 使用 `YMap` (`id_stack_map`) 存储所有已注册页面
- `YUtils.stackView` 引用栈容器
- 支持同时存在多个弹窗（通过 `stackView.children` 管理）
- 弹窗时显示半透明黑色遮罩

## 三、首页 (YIndexPage)

### 主菜单结构
```
YIndexPage (YBackground)
  ├── YMainTitleBar           -- 顶部状态栏
  ├── YHorizontalListView     -- 横向主菜单
  │     └── YHorizontalListViewDelegate (x6-7)
  │           ├── 词典
  │           ├── AI 助手
  │           ├── 录音
  │           ├── 单词本
  │           ├── 音频播放器 (条件显示)
  │           ├── 历史
  │           ├── 插件管理
  │           └── 设置
  ├── 锁屏层                   -- 闲置/锁屏覆盖层
  ├── 壁纸系统                 -- 动态壁纸（淡入淡出切换）
  └── 插件抽屉                 -- 底部弹出的已启用插件面板
```

### 锁屏系统
- `isLocked` / `isDimmed` 属性控制
- 基于 `locker` C++ 对象管理
- 显示时间、日期、低电量警告

## 四、快速设置层 (YQuickSettingLayer)

下拉手势触发，状态机：

```
"close"  →  "openning"  →  "open"
  ↑                           ↓
"closing"  ←  "open"  ←  (手势上滑/超时)
```

包含：WiFi、蓝牙、亮度、音量、快捷功能入口

## 五、左右手支持

整个 UI 通过 `settingManager.isRightHandMode` 实现 180° 旋转：

```qml
rotation: settingManager.isRightHandMode ? 0 : 180
```
