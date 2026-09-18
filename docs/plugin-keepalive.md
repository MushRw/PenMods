# PenMods 插件「后台保活」需求与实现建议

> 目标读者：接手实现的人。
> 结论先说：**框架里已经有现成约定（`destroyOnBack`），只是插件宿主没用上** —— 最小改动只有一处，纯 QML，不需要动 C++。

---

## 1. 目标

让插件页面关闭后：
1. 插件的**后台逻辑继续跑**（播放、网络、定时任务…）；
2. 再次打开该插件时**复用同一个实例**（队列/位置/UI 状态不丢，而不是重建）。

## 2. 现状（已核对过的事实）

### 2.1 后台逻辑**本来就活着** ✓
插件的 `.so` 只在**禁用/卸载**时卸载（`PenMods/src/plugin/PluginManager.cpp` 的 `unloadSo()`），关闭页面**不会**卸载它。
现成例子：
- `bili_plugin` 的 API server（日志 `BiliPlugin: API server started successfully`）
- `lx-pen` 的 runner 与播放（关掉插件页音乐照放）

也就是说：要做的不是"让插件能后台跑"，而是**别把它的页面对象销毁掉**。

### 2.2 框架已有 `destroyOnBack` 约定 ✓
| 位置 | 现状 |
| --- | --- |
| `resource/models/YDP02X/qml/commons/YPage.qml:15` | `property bool destroyOnBack: true`，`YPage.qml:56` 会尊重它 |
| `commons/YIncubateObjectPopLayer.qml:27,74` | 支持"不销毁、只隐藏" |
| 已有页面在用 | `YLoginPageRealTimeDisplay`、`AFDianQrCode` 等 5 处 `destroyOnBack: false` |

### 2.3 但插件宿主**无条件销毁** ✗
- 插件页宿主：`YIndexPage.qml:477` 的 `YDynamicPageStack { id: id_plugin_pop_container }`（`PluginManager.qml` 里同样用法）
- 创建入口：`YIndexPage.qml:509` → `createPage(componentPath, tpage, { pageIndex, closeOnHomeRelease }, …)`
- 销毁路径有三条，全部走 `_safeDestroy()`：`backButtonClicked`（`YDynamicPageStack.qml:183`）、`closeOnHomeRelease`（`:193`）、`pageIndex` 切页（`:172`）
- `_safeDestroy()`（`YDynamicPageStack.qml:120`）**直接 `incubatorObject.destroy(1)`**，不看 `destroyOnBack` ✗

→ 所以插件在自己的 QML 根节点写 `destroyOnBack: false` **目前没有任何效果**。

## 3. 建议的实现（分三阶段，可独立交付）

### 阶段 1（最小可用，纯 QML，零 C++）
改 `commons/YDynamicPageStack.qml` 一处：

1. **`_safeDestroy()`**：若对象声明了 `destroyOnBack === false`，则
   - `visible = false`、从可见栈里移出（`_releaseObject` 照旧，让 `count` 归零、事件屏障失效）；
   - 但**不调用 `destroy(1)`**，改为放进保活缓存 `_keptAlive[popStackId] = obj`；
   - 保留它的 `Component` 引用（跟随对象生命周期释放）。
2. **`createPage()`**：同一个 `popStackId` 再次创建时，若 `_keptAlive` 里有对象 →
   **直接复用**：`visible = true`、重新 `registerPage`（重连 `backButtonClicked` / `closeOnHomeRelease` 等 cleanups）→ 返回该对象，不再 `Qt.createComponent`。
3. 需要时可加 `releaseKeptAlive(popStackId)`，供内存吃紧或超时回收使用（回收前先调用阶段 2 的 `pageHidden()`）。

**注意（今天实测踩过的坑，务必避免）**：
- 不要在"页面关闭"时用 `QQmlEngine::collectGarbage()` / `trimComponentCache()` 去回收内存 —— 实测会把插件自己的对象/后台状态一起收掉、且 RSS 并不下降（已回退）。
- 重入**必须复用同一实例**，否则会出现两个实例同时跑后台逻辑（例如 lx-pen 会起两个 runner）。

### 阶段 2（生命周期回调，配套插件降频）
框架已有类似约定：页面对象若定义了 `todoDestroy()` 就会被调用（`YIncubateObjectPopLayer.qml:82`）。
按同样风格加两个可选函数：
- `pageShown()` —— 页面进入前台时调用；
- `pageHidden()` —— 页面隐藏/被保活时调用。

插件据此把后台轮询降频。**典型需求**：lx-pen 目前每 50ms 解析一次符号（`lxpen_player.cpp:628-642`），后台应该降到 200ms/10s 级。

### 阶段 3（可选，元数据驱动，插件作者零改动）
`metadata.json` 增加 `"keep_alive": true`，宿主在创建页面时自动设 `destroyOnBack = false`。
需要宿主侧（C++/QML）配合把元数据透传到页面属性。

## 4. 必须写进文档的代价与边界（诚实说明）

1. **内存是代价**：保活的页面常驻内存。本机是 460MB 设备，页面常驻直接影响可用内存 → 因此：
   - **默认仍是销毁**（`destroyOnBack: true`），只有插件显式声明才保活；
   - 建议同时给出"保活超时"或"内存吃紧时回收"的兜底。
2. **没有真正的 OS 级后台服务**：本机不是 Android，没有 service/保活白名单。插件的后台寿命 = 主程序寿命，app 被系统杀掉就一起结束。
3. 保活只解决"页面对象"的生命周期；插件若把自己的状态只放在 QML 里，回收后仍然会丢 → 关键状态建议插件自己落到 C++/JSON（lx-pen 已经这么做）。

## 5. 验收标准（可直接当测试用例）

1. 插件页声明 `destroyOnBack: false` → 退出后页面对象仍在（`count` 归零、对象地址不变）、后台任务继续（音乐继续播）。
2. 再次进入该插件 → **同一个实例**（对象地址与首次一致），队列/位置/UI 状态保留。
3. 声明 `destroyOnBack: true` 或未声明 → 行为与当前完全一致（回归不受影响）。
4. 只起一个后台进程（`ps | grep -c runner` = 1），不出现双实例。
5. 内存可量化：保活前后 `VmRSS` 差值可测；触发回收后 RSS 回落。
6. 与 PenMods 既有 hook 不冲突：对照日志不应出现新的 `Fail to hook`。
7. 实机验证：lx-pen 关闭插件页 → 音乐继续、重开页面队列仍在、短歌播完能自动连播（后者依赖 lx-pen 侧已修的时长感知窗口）。

## 6. 参考：今天相关改动的背景（供实现者理解上下文）

- PenMods 的"输入守护进程重启"曾用 `killall input-event-daemon` + 裸启动，会把该进程拉进 100% 忙循环 → 已改为调用厂商脚本 `/etc/init.d/S99input-event-daemon restart`（提交 `7224799`）。教训：**动厂商进程的生命周期，一律走厂商自己的脚本**。
- 插件与 PenMods 曾出现 hook 抢占（`onClickedPrev/Next/onSoundEnd` 被 lx-pen 先 hook，PenMods 后 hook 失败）→ 按钮已改为接管时直接调 `musicPlayer.clickNext()/clickPrev()`。教训：**框架不要依赖"可能被别人抢的符号"**。
