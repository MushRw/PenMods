# Singletons & Utilities

## 一、QML 单例

通过 `qmldir` 注册的 4 个单例模块：

### YUtils (`utils/YUtils.qml`)
导航栈和全局状态管理。

| 属性/方法 | 类型 | 用途 |
|---|---|---|
| `globalMap` | YMap | 全局对象引用映射 |
| `stackMap` | YMap | 导航栈对象映射 |
| `stackView` | Item | YStackView 容器引用 |
| `currentPopId` | string | 当前弹窗 ID |
| `clearStackView()` | function | 清除所有弹窗 |
| `removeKey(key)` | function | 从 map 中移除键 |
| `soundCenterPlayingCheckTimer` | Timer | 音频播放状态轮询 |

### YColors (`commons/YColors.qml`)
全局颜色常量。

```
black, white, red, orange, green, yellow
blueText, blueRect
grayText, grayNormal, graySwitchOff, grayButton
redDict (Gradient 渐变)
```

### YTranslateText (`i18n/YTranslateText.qml`)
国际化字符串。

- ~587 个属性，所有 UI 文字集中管理
- 使用 `qsTr()` 进行翻译
- 支持语言：zhCN, zhTW, enUS, jaJP, koKR

### YTimers (`timers/YTimers.qml`)
定时器工具。

| 方法 | 用途 |
|---|---|
| `delayCall(interval, callback)` | 指定毫秒后执行回调 |

## 二、JavaScript 工具

### `utils/utils.js`
原型扩展（通过 `import "./utils/utils.js" as UtilsJs` 导入）：

| 扩展 | 方法 |
|---|---|
| `Number` | `clamp()`, `bound()`, `mod()`, `padZero()` |
| `String` | `format()`, `isNumber()`, `contains()`, `trim()`, `isJson()`, `toLoadFileUrl()`, `urlToLocalFile()` |
| `Array` | `equals()`, `clone()`, `contains()` |
| `Math` | `randomInt(max)` |

### `dicts/YDictOxfordModel.js` (1271 lines, `.pragma library`)
牛津词典数据模型解析。

- `OxfordModelObject` 对象定义
- `createOxfordModel()`, `createOxfordModelByJsonData()`
- `MeanBlockType` 枚举
- 解析函数: `parsePosList`, `parsePhoneticList`, `parseMeanList`, `parseIdiomList`, `parsePhraseList` 等
- 含 HTML 解析工具

### `dicts/YDictOxfordUtilities.js` (1487+ lines, `.pragma library`)
牛津词典格式化工具。

- `parseHtml()`, `htmlNodeToFormatted()`, `htmlToFormatted()`
- 转义序列转换
- 音标格式化
- 不规则动词格式化
- 交叉引用格式化

### `dicts/YDictKoUtils.js` (35 lines)
韩中词典文本格式化。

- `formattedChineseTextBetweenSpecificSymble()`
- `formattedChineseText()`
- `replaceSpecificSymble()`

### `assistant/messages/MathCache.js` (34 lines, `.pragma library`)
数学公式 SVG 渲染缓存（LRU, 最大 80 条）。

- `get(key)`, `set(key, val)`

## 三、数据容器

### YMap (`utils/YMap.qml`)
简单的键值对映射容器：
- `set(key, value)`, `get(key)`, `has(key)`, `remove(key)`, `clear()`, `keys`, `values`

### YStack (`utils/YStack.qml`)
栈数据结构：
- `push(item)`, `pop()`, `peek()`, `isEmpty`
