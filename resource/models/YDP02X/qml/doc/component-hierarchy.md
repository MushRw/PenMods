# Component Hierarchy

## 一、继承链

### 根基类
```
Item (QtQuick)
  └── YItem (commons/YItem.qml)
        ├── YWindow (commons/YWindow.qml)             -- 设置 Screen 宽高
        └── YPopItem (commons/YPopItem.qml)           -- 弹窗基类
              └── YPage (commons/YPage.qml)            -- 页面基类 (show/close/todoDestroy)
                    ├── YBackButtonPage (commons/YBackButtonPage.qml)
                    │     ├── YDictPage
                    │     ├── YDictDetailPage
                    │     ├── YLoginPage
                    │     ├── YHistoryPage
                    │     ├── YFollowPage
                    │     ├── PluginManager
                    │     ├── AudioRecorder
                    │     └── ... (所有带返回按钮的页面)
                    ├── YSpeechPage
                    ├── YSettingPage
                    ├── YPowerOffPage
                    ├── YWordBookPage
                    ├── YTextbookPage
                    ├── YTouchReadingPage
                    ├── YSpellPage
                    ├── YInputPage
                    └── ChatAssistant
```

### Rectangle 系列
```
Rectangle (QtQuick)
  └── YRectangle (commons/YRectangle.qml)
        ├── YBackground (commons/YBackground.qml)     -- 黑色背景
        │     └── YIndexPage
        └── YBackgroundIgnoreMouseEvent
              └── YScanGuidePage
```

### 按钮系列
```
YButtonBase (commons/YButtonBase.qml)
  ├── YButton (commons/YButton.qml)
  ├── YIconButton (commons/YIconButton.qml)
  ├── YIconCheckedButton (commons/YIconCheckedButton.qml)
  ├── YIconLabelButton (commons/YIconLabelButton.qml)
  ├── YIconLabelHCenterButton (commons/YIconLabelHCenterButton.qml)
  └── YPressedBaseButton (commons/YPressedBaseButton.qml)
        └── YPressedButton (commons/YPressedButton.qml)
```

### 文字系列
```
YTextBase (commons/YTextBase.qml)
  ├── YText (commons/YText.qml)
  ├── YTextCH (commons/YTextCH.qml)
  ├── YTextEnUs (commons/YTextEnUs.qml)
  └── YTextMedium (commons/YTextMedium.qml)
```

### 图片系列
```
YImageBase (commons/YImageBase.qml)
  ├── YImage (commons/YImage.qml)            -- 使用 imageName + C++ 引擎
  ├── YRoundedImage (commons/YRoundedImage.qml)
  ├── YClickabledImage (commons/YClickabledImage.qml)
  └── YImageButton (commons/YImageButton.qml)
```

### 标题栏系列
```
YBaseTitleBar (commons/YBaseTitleBar.qml)
  ├── YVerticalTitleBar (commons/YVerticalTitleBar.qml)
  ├── YTabsTitleBar (commons/YTabsTitleBar.qml)
  └── YMainTitleBar (components/YMainTitleBar.qml)
```

### 对话框系列
```
YDialog (commons/YDialog.qml)
  ├── YOneButtonDialog (commons/YOneButtonDialog.qml)
  └── YTwoButtonDialog (commons/YTwoButtonDialog.qml)
```

### 弹层系列
```
YBasePopLayer (commons/YBasePopLayer.qml)
  ├── YPopLayer (commons/YPopLayer.qml)
  ├── YPagePopHelper (commons/YPagePopHelper.qml)
  ├── YIncubateObjectPopLayer (commons/YIncubateObjectPopLayer.qml)
  └── YDrawerLayer (commons/YDrawerLayer.qml)
```

## 二、词典类型组件（动态加载）

所有词典类型继承 `YDictTypeBase`，由 `YDictPage` 根据 `dictType` 枚举动态加载：

```
YDictTypeBase
  ├── YDictTypeDtSimple              -- 简洁词典
  ├── YDictTypeDtSenior              -- 高阶词典
  ├── YDictTypeDtOxford              -- 牛津词典
  ├── YDictTypeDtChChinese           -- 中文字典
  ├── YDictTypeDtChChineseGroup      -- 中文词组
  ├── YDictTypeDtChEnglish           -- 汉英词典
  ├── YDictTypeDtChLarge             -- 大汉英
  ├── YDictTypeDtChAncientWord       -- 古汉语
  ├── YDictTypeDtChPoemDict          -- 诗词词典
  ├── YDictTypeDtChChineseIdiom      -- 成语词典
  ├── YDictTypeDtTOEFL / GRE / SAT / SSAT / IELTS
  ├── YDictTypeDtChKo / DtKoCh       -- 韩汉词典
  ├── YDictTypeDtWebster             -- 韦氏词典
  ├── YDictTypeDtMangoKidEnglish     -- 芒果英语
  └── YDictTypeWGTSentence           -- 句子翻译
```

## 三、页面组合关系

```
YMainWindow
  ├── YQuickSettingLayer             -- 下拉快速设置（独立层）
  ├── YIndexPage                     -- 首页（主菜单 + 锁屏）
  │     └── YMainTitleBar            -- 状态栏（时间、电量、蓝牙）
  │
  ├── YStackView                     -- 弹窗导航栈容器
  │     └── (各页面按需动态加载)
  │
  ├── YScanGuidePage                 -- 扫描引导（全屏遮罩动画）
  │
  └── 全局 Toast / 对话框            -- YLoader 动态创建
```

## 四、动态页面加载模式

通用动态加载模式（用于 `YSettingPage`、`PluginManager`、`ChatAssistant`、`AudioRecorder`）：

1. 定义 `Item` 容器（`z: 500`）+ `signal closeSameItem(string popStackId)`
2. `Qt.createComponent()` + `incubateObject()` 动态实例化
3. 通过 `Object.defineProperty` 附加 `popStackId`
4. 连接 `backButtonClicked`、`qmlGlobal.requestShowPage`、`systemBase.homeKeyRelease` 等信号
5. 使用 `_connectionCleanups` 数组管理清理
