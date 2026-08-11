# PenMods

> 适用于有道词典笔 YDP02X 的第三方插件运行时（本分支基于 PenUniverse/PenMods，版本 **2.0.1**）。

## 功能总览

- **重新实现的 AI 助手**
  - 兼容 OpenAI 格式 API，可配置多个模型与提示词
  - 支持 Tool Call（shell 命令执行、Tavily 网络搜索）
  - 数学公式渲染（需自建 MathJax 服务器）、本地文件引用
- **增强文件管理器**
  - 图片查看器（含 WebP 动图）、外部视频播放器
  - 隐藏文件（可加安全锁）、自然排序、无限级子目录
  - 删除/改名/排序，可直接打开 `txt`、`md` 等文本
- **视频播放（v2.0.1 重构）**
  - 随包附带 mpv + Rockchip MPP 硬解播放器，启动时自动部署/自愈
  - 文件管理器点开视频先显示 bili 风格播放页，点播放才启动播放器
  - 退出键会真正停止播放器，不再残留后台播放
- **插件系统**：`/userdisk/PenMods/plugins/` 下按目录放插件（QML + 原生库），如 bili、2048、天气
- **主界面壁纸**、**增强音乐播放器**（lrc 翻译歌词、flac 直接打开）、**中州韵输入法**、**音频守护进程**（`/tmp/audio_wakelocks` 唤醒锁）
- **其他**：列式数据库查询上限调节、A/B 槽切换、快速静音、开机自动挂载可写、vendor_storage 自动修复、OTA 更新

## 外部播放器（视频）

发布包内置 `player.zip`：

- **mpv 0.36.0 + FFmpeg 6.0**（基于 [ffmpeg-rockchip](https://github.com/nyanmisaka/ffmpeg-rockchip)，带 Rockchip MPP 硬解），含配置、字体、触摸控制脚本与屏幕守护
- 结构：`mpv/` 目录（`mpv` 包装脚本、`bin/mpv`、`lib/`、`config/`、`screen_watchdog`）
- 部署位置：`/userdisk/mpv`；`/userdisk/VideoPlayer` 为软链，指向 `/userdisk/mpv/mpv`
- mod 启动时若 `/userdisk/mpv/mpv` 缺失，会从 `/userdata/PenMods/player.zip` 自动解压部署并修复软链（见 `src/mod/PlayerInstaller.cpp`）
- 播放器内容、来源与许可：见 [resource/player/README.md](resource/player/README.md)

## 安装

把以下文件放到 `/userdata/PenMods/` 后重启：

```text
/userdata/PenMods/
├── libPenMods.so            # mod 本体
├── libPenModsResources.so   # 外部 QML 资源库（可选，缺失时回退内置资源）
├── player.zip               # 外部播放器包（缺失时仅视频播放不可用）
└── patch.sh                 # 全新安装时给主程序打补丁用
```

全新安装（未装过 mod 的笔）需要先用 `patchelf` 给主程序
`/oem/YoudaoDictPen/output/YoudaoDictPen` 注入对 `libPenMods.so` 的依赖（自动备份原文件），
仓库的 `scripts/patch.sh` 即为此步骤。

> 注意：本分支不依赖官方 Installer 服务器，直接从 Actions 产物 / 发布包安装。

## 构建

### GitHub Actions（推荐）

推送 `main` 或手动触发 `Build PenMods` 工作流即可，产物包含：

```text
build/linux/arm64-v8a/
├── release/libPenMods.so
├── release/libPenModsResources.so
├── release/libQrcExporter.so
└── player.zip
```

### 本地构建（xmake）

依赖：Linux 环境、aarch64 gcc 6.5 工具链、Qt 5.15.2（aarch64）、zig、xmake。

```shell
xmake f \
  --qt="/path/to/aarch64-linux-qt-5.15.2" \
  --arch=arm64-v8a \
  --build-platform=YDP02X \
  --target-channel=dev \
  --toolchain=zig \
  -m release \
  --cross=aarch64-linux-gnu.2.27 \
  -c
xmake build
```

### 修改 QML

整个界面 QML 编译进 `resource/models/YDP02X/qrc_qml.h`（Qt rcc 格式）。
仓库已提交完整 QML 源树，修改流程：

1. 直接编辑 `resource/models/YDP02X/` 下的 `.qml` 文件
2. 重新打包：
   ```shell
   python3 scripts/repack_qrc.py pack \
     resource/models/YDP02X/qrc_qml.h \
     resource/models/YDP02X \
     resource/models/YDP02X/qrc_qml.h
   ```
3. 构建并部署

`scripts/repack_qrc.py` 支持 `extract / pack / verify` 三个子命令，可无损解包与重打包。

## 设备支持

型号 | 是否支持 | 系统版本 | 备注
-|-|-|-
YDP02x | 🟢 | 2.0.7 / 2.0.8（实测 2.1.2 可运行） | 老系统请先刷到新系统
其他型号 | 🔴 | - | 未适配

## 注意事项

- **PenMods 会拦截原系统 OTA**，系统有更新时需先卸载 mod
- 安装可能导致失去官方保修，一切后果自负
- 从旧版 1.x 升级前需先卸载（`/userdisk/Loader`）
- adb 重启可能丢触摸：重启前先 `echo 0 > /sys/kernel/debug/touchscreen/suspend` 唤醒触摸，必要时手动断电一次

## 开发调试

- **界面截图**：`adb shell "touch /tmp/penmods_screencap"` → mod 抓取当前窗口保存为 `/tmp/penmods_screen.png`，`adb pull` 即可查看
- **日志**：`/userdata/applog/DictPen_*.log`
- **插件**：`/userdisk/PenMods/plugins/`，日志中可见加载状态

## 许可与致谢

- 本仓库 GPL-3.0-only；随包的播放器二进制来自社区构建（mpv / FFmpeg，见 `resource/player/README.md`）
- Credits: [Dobby](https://github.com/jmpews/Dobby)、[Qt Project](https://www.qt.io/)、[injector](https://github.com/kubo/injector)、[ffmpeg-rockchip](https://github.com/nyanmisaka/ffmpeg-rockchip)
