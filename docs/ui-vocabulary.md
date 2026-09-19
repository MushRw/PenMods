# 词典笔 UI 术语表（沟通用）

> 目的：让你我指代同一个东西时零歧义。
> **用法：以后直接说"名字"就行**（例如"下拉快速设置 → 卡片圆角"、"插件抽屉 → 面板底色"）。
>
> 为什么给 `文件 + id/objectName` 而不是行号：行号会随改动漂移，而 `id` / `objectName`
> 是稳定的，`grep` 一下就能定位。行号只在括号里给个大概。

## 一、顶层框架

| 术语 | 文件 | 定位标识 |
| --- | --- | --- |
| 主窗口 / 内容容器 | `YMainWindow.qml` | `id_inner_item` |
| **下拉快速设置触发条**（屏幕顶部中间那条窄条） | `YMainWindow.qml` | `id_drag_show_quick_setting`（默认 x 40–280、高 14） |
| **下拉快速设置层**（整个面板） | `YQuickSettingLayer.qml` | `id_quick_setting_layer_root`（在 YMainWindow 里叫 `id_quick_setting_layer`） |
| 面板磨砂模糊 | `YQuickSettingLayer.qml` | `id_fast_blur`（`fastBlurTarget` 指向底图 `ShaderEffectSource`） |
| 面板遮罩（原 `#E6000000`） | `YQuickSettingLayer.qml` | 紧随 `id_fast_blur` 的那个 `Rectangle` |
| 面板内容网格 | `YQuickSettingLayer.qml` | `Grid`（2×2，`rowSpacing`/`columnSpacing`/`padding`） |
| ├ 音量 | `YQuickSettingLayer.qml` | `id_volum_setting`（`YVolmueAdjustor`） |
| ├ WiFi | `YQuickSettingLayer.qml` | `id_slide_wifi`（`YSlideWifiSetting`） |
| ├ 亮度 | `YQuickSettingLayer.qml` | `id_lum_setting`（`YTouchRegulator` + lum 图标） |
| ├ 蓝牙 | `YQuickSettingLayer.qml` | `id_slide_bluetooth`（`YSlideBluetoothSetting`） |
| └ 收起指示图 | `YQuickSettingLayer.qml` | 底部 `imageName: "slide/ic_collapse"` 的 `YImage` |
| 页面栈 / 插件弹层 | `YIndexPage.qml` | `id_plugin_pop_container`（`YDynamicPageStack`） |

## 二、首页

| 术语 | 文件 | 定位标识 |
| --- | --- | --- |
| 首页根 | `YIndexPage.qml` | `id_container_index` |
| 壁纸 / 壁纸模糊 / 暗化层 | `YIndexPage.qml` | `id_bg_image` / `id_bg_blur` / `id_dark_overlay` |
| 锁屏层 | `YIndexPage.qml` | `id_lock_screen_layer` |
| 主内容 | `YIndexPage.qml` | `id_main_content` |
| 标题栏 | `YIndexPage.qml` | `id_main_titlebar_loader` |
| **横向主菜单**（首页那排格子） | `YIndexPage.qml` | `id_main_menu_list_view` |
| 主菜单格子 | `components/YHorizontalListViewDelegate.qml` | 宽 112 × 高 102，背景图 `home-*-bg` |
| **插件抽屉**（底部上拉那块） | `YIndexPage.qml` | `id_plugin_drawer` |
| ├ 抽屉面板 | `YIndexPage.qml` | `id_drawer_panel` |
| ├ 拖拽把手 | `YIndexPage.qml` | `id_drawer_drag_handle` |
| ├ 抽屉插件列表 | `YIndexPage.qml` | `id_plugin_horizontal_list` |
| └ 抽屉遮罩 | `YIndexPage.qml` | `id_drawer_overlay`（其内 `Rectangle` 是压暗层） |

## 三、通用组件与令牌

| 术语 | 文件 | 说明 |
| --- | --- | --- |
| **配色令牌** | `commons/YColors.qml` | 全部绑定 C++ `theme.*`；含 `glassLight / glass / glassStrong / glassButton`（由令牌算出 alpha，切主题跟随） |
| 主题管理器（C++） | `src/theme/ThemeManager.{h,cpp}` | 预设 `official`（官方深灰）/ `pureBlack`（纯黑省电），持久化在 `config.json` 的 `theme.id` |
| 磨砂组件 | `commons/YFastBlurRectangle.qml` | `FastBlur` + `OpacityMask` 的现成磨砂矩形 |
| 列表基类 | `commons/YBaseListView.qml` | `cacheBuffer: 1000`（横向列表子类 `commons/YHorizontalListView.qml`，默认 `clip: true`） |
| 通用弹窗 | `commons/YDialog.qml` | 遮罩 `#E6000000` |

## 四、页面

| 术语 | 文件 |
| --- | --- |
| 系统设置页（**主题切换**、重启界面按钮都在这） | `settingpages/SystemTweakSettingPage.qml` |
| 插件管理页 | `PluginManager.qml` |
| 文件管理（含 U 盘行） | `audiopages/FileManagerPageComponent.qml` |
| 文本 / Markdown 查看 | `audiopages/FileManagerTextViewer.qml` |
| 图片查看 | `audiopages/FileManagerImageViewer.qml` |
| AI 助手（聊天） | `ChatAssistant.qml` |
| ├ 普通气泡 / 富文本气泡 | `assistant/messages/ChatBubble.qml` / `assistant/messages/MixedContentBubble.qml` |
| └ 语音/词典详情 | `assistant/YSpeechDetail.qml` |
| 词典页 / 词典详情 | `YDictPage.qml` / `YDictDetailPage.qml` |

## 五、怎么跟我描述改动（模板）

```
[目标] 下拉快速设置层
[区域] 面板内容网格（Grid）
[期望] rowSpacing 14→18；列间距 28→24；内容整体下移 6px
[不动] 音量 / WiFi / 亮度 / 蓝牙 四个控件本身
[验收] 截图里 Grid 行距变大、四件各自位置相应下移，其余不变
```

- 需要"位置"精确到像素时，用我给的那张**带网格截图**：一格 = 20px，顶部带是 x 刻度、左侧带是 y 刻度，红框是区域编号（A/B/C…）。
- 需要"像某个现有东西"时，直接说**术语名**或**组件文件名**，我会去读它的源码照做。
- 一次只提一个意图 + 明确"哪里不动"，我改完会**自己截图核对**并把图发给你。
