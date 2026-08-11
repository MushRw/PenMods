# Directory Structure

```
qml/
├── animations/                          # 动画组件
│   ├── YAudioPlayerIndicatorAnimation.qml
│   └── YYoudaoAudioPageColumnViewItemAnimation.qml
│
├── assistant/                           # AI 聊天助手
│   ├── components/                      #   └─ 通用聊天组件
│   │   ├── AttachmentChipsBar.qml
│   │   ├── ChatToastBanner.qml
│   │   └── EdgeSwipeGesture.qml
│   ├── dialogs/                         #   └─ 对话框
│   │   ├── MessageContextMenu.qml
│   │   ├── MoreMenuPopup.qml
│   │   └── ShellConfirmDialog.qml
│   ├── messages/                        #   └─ 消息气泡
│   │   ├── ChatBubble.qml
│   │   ├── MathBubble.qml
│   │   ├── MathCache.js
│   │   ├── MessageDelegate.qml
│   │   ├── MixedContentBubble.qml
│   │   ├── ThinkingDotsIndicator.qml
│   │   └── ToolCallCard.qml
│   ├── YSpeechDetail.qml
│   └── YSpeechVolmn.qml
│
├── audiopages/                          # 音频学习页面
│   ├── ExternalPlayer.qml
│   ├── FileManager*.qml                 # 文件管理相关
│   ├── VideoPlayer.qml
│   ├── YAudioPageDomainButton.qml
│   ├── YBackButtonAudioPage.qml
│   ├── YDownload*.qml                   # 下载管理
│   ├── YMyProduction*.qml               # 我的作品
│   ├── YRemoveColumnDrawerLayer.qml
│   ├── YYoudaoAudio*.qml                # 有道音频
│   └── YAudioPage*.qml
│
├── audioplayer/                         # 音频播放器
│   ├── YAudioPlayer.qml
│   ├── YAudioPlayerFollowPage.qml
│   ├── YAudioPlayerIndicator.qml
│   ├── YAudioPlayerLrcContent.qml
│   ├── YAudioPlayerLrcMouseArea.qml
│   ├── YAudioPlayerPlayBar.qml
│   ├── YAudioPlayerPlayBarSettingItem.qml
│   ├── YAudioPlayerPlayBarVertical.qml
│   └── YAudioPlayerVolumeBar.qml
│
├── commons/                             # 核心基础组件库
│   ├── input/                           #   └─ 自定义输入法
│   │   ├── YInputTextCharsModelBase.qml
│   │   ├── YInputTextFunctionButton.qml
│   │   ├── YInputTextFunctionGroup.qml
│   │   ├── YInputTextItem.qml
│   │   ├── YInputTextLowerChars.qml
│   │   ├── YInputTextNumberChars.qml
│   │   ├── YInputTextSymbolChars.qml
│   │   ├── YInputTextTitleArea.qml
│   │   ├── YInputTextUpperChars.qml
│   │   └── YInputTextItem.qml
│   ├── qmldir                           # 单例注册表 (YColors)
│   ├── YAnimatedImagesView.qml          # 动画图片序列
│   ├── YBackButton*.qml                 # 返回按钮系列
│   ├── YBackground*.qml                 # 背景组件系列
│   ├── YBaseListView.qml                # 列表基类
│   ├── YBasePopLayer.qml                # 弹层基类
│   ├── YBaseTitleBar.qml                # 标题栏基类
│   ├── YBinding.qml                     # 绑定工具
│   ├── YBlurMaskRectangle.qml           # 模糊遮罩
│   ├── YButton*.qml                     # 按钮系列
│   ├── YCircularProgressBar.qml         # 圆形进度条
│   ├── YClickabledImage.qml             # 可点击图片
│   ├── YClickedCountMouseArea.qml       # 计数点击区域
│   ├── YColors.qml                      # [单例] 颜色常量
│   ├── YDialog.qml                      # 对话框基类
│   ├── YDownloadProgressButton.qml      # 下载进度按钮
│   ├── YDrawerLayer.qml                 # 抽屉层
│   ├── YFastBlurRectangle.qml           # 快速模糊
│   ├── YHorizontalListView.qml          # 水平列表
│   ├── YIcon*.qml                       # 图标按钮系列
│   ├── YImage*.qml                      # 图片系列
│   ├── YIncubateObjectPopLayer.qml      # 孵化弹层
│   ├── YItem.qml                        # 根 Item 基类
│   ├── YLoader.qml / YLoaderPage.qml    # 加载器
│   ├── YMouseArea.qml                   # 鼠标区域基类
│   ├── YOneButtonDialog.qml             # 单按钮对话框
│   ├── YPage.qml                        # 页面基类
│   ├── YPagePopHelper.qml               # 页面弹窗辅助
│   ├── YPopItem.qml / YPopLayer.qml     # 弹窗组件
│   ├── YProgressBar.qml                 # 进度条
│   ├── YProgressIndicator.qml           # 进度指示器
│   ├── YRectangle.qml                   # 矩形基类
│   ├── YRefreshButton.qml               # 刷新按钮
│   ├── YRoundedImage.qml                # 圆角图片
│   ├── YSettingResetBase.qml            # 设置重置基类
│   ├── YShadowText.qml                  # 阴影文字
│   ├── YSlider.qml                      # 滑块
│   ├── YSpacing.qml / YSpacingForColumn.qml
│   ├── YStrokesOrderView.qml            # 笔画顺序
│   ├── YSwitch.qml                      # 开关
│   ├── YText*.qml                       # 文字系列
│   ├── YThreeStatesButton.qml           # 三态按钮
│   ├── YTimer.qml                       # 定时器
│   ├── YTitle.qml                       # 标题组件
│   ├── YToast.qml                       # 提示
│   ├── YTouchRegulator.qml              # 触摸调节
│   ├── YTwoButtonDialog.qml             # 双按钮对话框
│   ├── YVerticalDividingLine.qml        # 竖线
│   ├── YVerticalTitleBar*.qml           # 竖排标题栏
│   ├── YWaitingTipsText.qml             # 等待提示
│   └── YWindow.qml                      # 窗口基类
│
├── components/                          # 业务通用组件
│   ├── DescribedClickableTextBox.qml
│   ├── DescribedSwitchItem.qml
│   ├── YAddBindAccountDisplay.qml
│   ├── YAspectFitAlignCenterImage.qml
│   ├── YAudioPlayButton.qml
│   ├── YAudioPlayIconLabelButton.qml
│   ├── YAudioPlayIconLabelHCenterButton.qml
│   ├── YBlurMaskProgressBar.qml
│   ├── YBlurMaskRectangleLabelButton.qml
│   ├── YDictChChineseStrokeComponent.qml
│   ├── YDictPageClickSearchTextItem.qml
│   ├── YDictPageHeader*.qml             # 词典页头系列
│   ├── YDictPinyinListView.qml
│   ├── YFollowIconsButton.qml
│   ├── YFollowLangSwitch.qml
│   ├── YHistoryPageClearTip.qml
│   ├── YHorizontalListViewDelegate.qml  # 首页列表项
│   ├── YListViewLoadMoreFooter.qml
│   ├── YLoginPage*.qml                  # 登录相关系列
│   ├── YMainTitleBar.qml                # 主标题栏
│   ├── YOpacityMaskImage.qml
│   ├── YPointText.qml
│   ├── YScanWordsResultLoader.qml
│   ├── YSetting*.qml                    # 设置相关系列
│   ├── YSlideBluetoothSetting.qml
│   ├── YSlideWifiSetting.qml
│   ├── YSpeechPeomDetailDrawer.qml
│   ├── YUserPortrait.qml
│   ├── YVolmueAdjustor.qml
│   ├── YWaveForm.qml
│   ├── YWordBook*.qml                   # 单词本系列
│
├── dicts/                               # 词典系统
│   ├── YDictKoUtils.js                  # 韩中词典工具
│   ├── YDictOxfordModel.js              # 牛津模型解析
│   ├── YDictOxfordUtilities.js          # 牛津格式化工具
│   ├── YDictPageSearchingTip.qml
│   ├── YDictTypeBase.qml                # 词典类型基类
│   ├── YDictTypeDt*.qml                 # 各词典类型组件
│   └── YDictTypeWGTSentence.qml
│
├── i18n/                                # 国际化
│   ├── qmldir                           # 单例注册表
│   └── YTranslateText.qml               # [单例] 所有可翻译字符串
│
├── settingpages/                        # 设置页面
│   ├── AboutPenMods.qml                 # PenMods 关于
│   ├── ADBManagePage.qml
│   ├── AFDianQrCode.qml
│   ├── AntiEmbsSettingPage.qml
│   ├── AutoScreenOffSetting.qml
│   ├── AutoSuspendSetting.qml
│   ├── BatteryInfoPage.qml
│   ├── ChatAssistantSettings.qml
│   ├── ConfigureNetworkPage.qml
│   ├── ConfigureProxyPage.qml
│   ├── DeveloperSettingPage.qml
│   ├── LockSceneSettingPage.qml
│   ├── LockSettingPage.qml
│   ├── ModelDetailPage.qml
│   ├── ModelManagePage.qml
│   ├── PromptDetailPage.qml
│   ├── PromptManagePage.qml
│   ├── QuerySettingPage.qml
│   ├── SSHManagePage.qml
│   ├── SystemTweakSettingPage.qml
│   ├── Torch.qml
│   ├── WallpaperSettingPage.qml
│   ├── YSettingAbout.qml
│   ├── YSettingBluetooth.qml
│   ├── YSettingBrightness.qml
│   ├── YSettingCertification.qml
│   ├── YSettingDict.qml
│   ├── YSettingHandedness.qml
│   ├── YSettingItemPage.qml
│   ├── YSettingItemTitle.qml
│   ├── YSettingLanguage.qml
│   ├── YSettingMultiLines.qml
│   ├── YSettingPronunc.qml
│   ├── YSettingReset.qml
│   ├── YSettingStorageInfo.qml
│   ├── YSettingTranslate.qml
│   ├── YSettingUpdate.qml
│   ├── YSettingVolume.qml
│   └── YSettingWifi.qml
│
├── textbook/                            # 课本系统
│   ├── YTextBook*.qml                   # 课本操作系列
│   ├── YTextbook*.qml                   # 课本页面系列
│
├── timers/                              # 定时器工具
│   ├── qmldir
│   └── YTimers.qml                      # [单例] 延迟调用
│
├── utils/                               # 工具
│   ├── qmldir
│   ├── utils.js                         # 原型扩展工具函数
│   ├── YMap.qml                         # Map 容器
│   ├── YStack.qml                       # Stack 容器
│   └── YUtils.qml                       # [单例] 导航栈管理
│
├── AudioRecorder.qml                    # 录音页面
├── ChatAssistant.qml                    # AI 聊天页面
├── ChatMessageIndexPanel.qml            # 聊天消息索引面板
├── ChatSessionListPanel.qml             # 聊天会话列表面板
├── PluginManager.qml                    # 插件管理页面
├── YAudioPage.qml                       # 音频学习入口
├── YDictDetailPage.qml                  # 词典详情
├── YDictPage.qml                        # 词典搜索结果
├── YFollowPage.qml                      # 跟读页面
├── YHistoryPage.qml                     # 历史记录
├── YIndexPage.qml                       # 首页/主菜单
├── YInputPage.qml                       # 自定义输入法
├── YLoginPage.qml                       # 登录页面
├── YMainWindow.qml                      # 主窗口入口
├── YPowerOffPage.qml                    # 关机页面
├── YQuickSettingLayer.qml               # 快速设置面板
├── YScanGuidePage.qml                   # 扫描引导
├── YSettingPage.qml                     # 设置入口
├── YSpeechPage.qml                      # 语音助手
├── YSpellPage.qml                       # 拼写页面
├── YStackView.qml                       # 弹窗导航容器
├── YTextbookPage.qml                    # 课本入口
├── YTouchReadingPage.qml                # 触读页面
└── YWordBookPage.qml                    # 单词本入口
