# Architecture Overview

## 一、整体架构

```
C++ Plugin Layer (com.youdao.pen 1.0)
  └── QML UI Layer (presentation)
        ├── Commons (基础组件库)
        ├── Components (业务组件)
        ├── Pages (页面级组件)
        ├── Assistant (AI 聊天)
        ├── Dicts (词典系统)
        ├── AudioPages (音频学习)
        ├── AudioPlayer (音频播放器)
        ├── SettingPages (设置页面)
        ├── Textbook (课本系统)
        └── Input (输入法系统)
```

## 二、C++ 后端插件

### `com.youdao.pen 1.0` —— 主业务插件
| 对象 | 用途 |
|---|---|
| `YEnum` | 枚举常量（页面索引、词典类型等） |
| `settingManager` | 设置管理（亮度、音量、左右手等） |
| `batteryManager` | 电池管理 |
| `resultManager` | 词典查询结果管理 |
| `qmlGlobal` | QML 全局控制（页面导航、扫描等） |
| `loginManager` | 登录管理 |
| `speechManager` | 语音识别管理 |
| `wifiManager` | WiFi 管理 |
| `wallpaperManager` | 壁纸管理 |
| `soundCenter` | 音频播放中心 |
| `systemBase` | 系统事件（home键、OCR等） |
| `followManager` | 跟读管理 |
| `spellManager` | 拼写管理 |
| `historyManager` | 历史记录 |
| `wordBookManager` | 单词本 |
| `columnManager` | 栏目管理 |
| `readingSeriesManager` | 系列阅读管理 |
| `chatbot` | AI 聊天机器人 |
| `shell` | Shell 命令执行 |
| `audioRecorder` | 音频录制 |
| `locker` | 锁屏管理 |
| `strokeManager` | 笔画管理 |
| `wgt` | 重量/单位管理 |
| `bot` | 机器人管理 |
| `qmlTranslator` | 翻译引擎 |
| `pluginManager` | 插件管理 |
| `res` | 资源管理（图片解析） |

### `com.github.penuniverse 1.0` —— PenMods 扩展插件
提供 Chat AI、插件系统、自定义页面索引等扩展功能。

### `com.youdao.input 1.0` —— 输入法插件
提供 `RimeWrapper` 中文字拼音输入引擎。

## 三、QML 入口

**`YMainWindow.qml`** 是唯一入口点，结构如下：

```
YMainWindow (YWindow)
  ├── id_inner_item          -- 默认内容容器 (default property alias)
  ├── YQuickSettingLayer     -- 下拉快速设置面板
  ├── YMouseArea             -- 拖拽手势触发快速设置
  ├── YScanGuidePage         -- 扫描引导动画
  ├── YStackView             -- 弹窗/导航栈
  ├── YIndexPage             -- 首页/主菜单
  └── YLoader / Connections  -- 全局 Toast、低电量提示等
```

## 四、核心设计模式

1. **动态页面加载**：通过 `qmlGlobal.requestShowPage(index)` 触发，页面组件使用 `Loader` 或 `Qt.createComponent` 动态创建
2. **自定义图片系统**：`YImage` 通过 `imageName` 属性 + C++ 图片解析引擎，而非直接文件路径
3. **左右手支持**：全局旋转 `rotation: settingManager.isRightHandMode ? 0 : 180`
4. **插件架构**：支持运行时从外部加载 QML 插件
5. **流式聊天**：`ChatAssistant` 使用 throttled streaming 渲染 AI 回复
