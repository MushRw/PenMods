# Signal Flow

## 一、C++ → QML 信号

### 全局导航
| C++ 对象 | 信号 | 响应位置 | 行为 |
|---|---|---|---|
| `qmlGlobal` | `requestShowPage(index)` | 各页面 | 显示/切换到指定页面 |
| `qmlGlobal` | `requestShowScanGuide()` | YMainWindow | 显示扫描引导动画 |
| `qmlGlobal` | `requestSpeechNeedNetWork()` | YMainWindow | 语音需要网络提示 |
| `qmlGlobal` | `currentPageIndexChanged()` | YSpeechPage | 非当前页时关闭语音 |
| `qmlGlobal` | `closeInputPageWhileHomeKeyReleased()` | YInputPage | Home 键关闭输入法 |

### 设备状态
| C++ 对象 | 信号 | 响应位置 | 行为 |
|---|---|---|---|
| `batteryManager` | `lowPower(power)` | YMainWindow | 低电量弹窗 |
| `systemBase` | `ocrStart()` | ChatAssistant, AudioRecorder | OCR 扫描时关闭页面 |
| `systemBase` | `homeKeyPress/release/longPress` | 多处 | 返回/退出/特殊操作 |

### 业务数据
| C++ 对象 | 信号 | 响应位置 | 行为 |
|---|---|---|---|
| `resultManager` | `itemCount` / model 变化 | YDictPage | 更新词典结果列表 |
| `speechManager` | `recognizingChanged` | YSpeechPage | 控制聆听动画 |
| `speechManager` | `contentChanged` | YSpeechPage | 处理语音识别结果 |
| `wallpaperManager` | `currentWallpaperChanged()` | YIndexPage | 切换壁纸 |
| `loginManager` | `statusChange(event, bSuc)` | YLoginPage | 登录/登出处理 |
| `audioRecorder` | `stateChanged`, `notify` | AudioRecorder | 录音状态更新 |
| `chatbot` | `messageReceived` | ChatAssistant | 收到完整消息 |
| `chatbot` | `streamChunk` | ChatAssistant | 流式文本块 |
| `chatbot` | `streamEnd` | ChatAssistant | 流结束 |
| `chatbot` | `errorOccurred` | ChatAssistant | 错误处理 |
| `chatbot` | `toolCallReceived` | ChatAssistant | 工具调用 |
| `pluginManager` | `pluginListUpdated` | PluginManager, YIndexPage | 刷新插件列表 |
| `pluginManager` | `pluginStateChanged` | PluginManager | 插件状态变化 |

## 二、QML → QML 信号

### 页面导航
| 发送者 | 信号 | 接收者 | 行为 |
|---|---|---|---|
| `YPage` | `backButtonClicked()` | 父容器 | 关闭/销毁页面 |
| `YBackButtonPage` | `backButtonClickedCallback()` | 父容器 | 自定义返回行为 |
| `YVerticalTitleBar` | `callBack()` | 所在页面 | 触发返回 |

### 登录流程
| 发送者 | 信号 | 接收者 | 行为 |
|---|---|---|---|
| `YLoginPageLoginStatusLoader` | `requestLoginPageRealTimeDisplay()` | YLoginPage | 显示实时显示界面 |
| `YLoginPageLoginStatusLoader` | `requestLoginPageLogoutConfirm()` | YLoginPage | 显示登出确认 |
| `YLoginPageLoginStatusLoader` | `requestAddBindAccountDisplay()` | YLoginPage | 添加绑定账号 |

### 聊天助手
| 发送者 | 信号 | 接收者 | 行为 |
|---|---|---|---|
| `ChatSessionListPanel` | `sessionSelected(string)` | ChatAssistant | 切换会话 |
| `ChatSessionListPanel` | `newSessionRequested()` | ChatAssistant | 创建新会话 |
| `ChatSessionListPanel` | `renameSessionRequested(id, name)` | ChatAssistant | 重命名会话 |
| `ChatMessageIndexPanel` | `navigateToMessage(int)` | ChatAssistant | 滚动到消息位置 |
| `MessageDelegate` | `longPressed(reax, real, int)` | ChatAssistant | 显示消息上下文菜单 |
| `EdgeSwipeGesture` | `triggered()` | ChatAssistant | 打开/关闭侧边面板 |
| `FileManagerSelector` | `fileSelected(string)` | ChatAssistant | 附件文件选择 |
| `ShellConfirmDialog` | `approved/denied` | ChatAssistant | Shell 命令确认 |

### 词典/单词本
| 发送者 | 信号 | 接收者 | 行为 |
|---|---|---|---|
| `YDictPinyinListView` | `currentPinyinChanged(string)` | YDictPage | 拼音选择 |
| `YFollowLangSwitch` | `filterChanged(int)` | Dictionary | 语言过滤 |
| `YWordBookPageSwitchLoader` | `callCardView()` | YWordBookPage | 切换到卡片视图 |

### 动态弹窗
| 发送者 | 信号 | 接收者 | 行为 |
|---|---|---|---|
| 弹窗 popItem | `closeSameItem(string)` | 父容器 | 关闭相同 ID 的弹窗 |

## 三、信号连接模式

### 动态页面连接模式
```
createComponent → incubateObject → onCreated:
  ├── popStackId = Object.defineProperty(obj, "popStackId", {...})
  ├── obj.backButtonClicked.connect(closeAll)
  ├── obj.qmlGlobal.requestShowPage.connect(obj.closeAll)
  ├── systemBase.homeKeyRelease.connect(obj.closeAll)
  └── obj.closeSameItem.connect(obj.destroy)
```

### 清理机制
```qml
var _connectionCleanups = []
// 每条连接:
var conn = object.signal.connect(handler)
_connectionCleanups.push(function(){ object.signal.disconnect(handler) })
// 清理时:
_connectionCleanups.forEach(function(c){ c() })
```
