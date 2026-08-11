# 外部播放器包（player.zip）

这是为 YDP02X 准备的第三方播放器（mpv + Rockchip MPP 硬解），随 PenMods 一起分发。

## 内容

- **mpv 0.36.0**（aarch64），链接 FFmpeg 6.0（libavcodec 60.31.102）与 libplacebo、Wayland、ALSA 等自带依赖
- **FFmpeg 6.0** 基于 [nyanmisaka/ffmpeg-rockchip](https://github.com/nyanmisaka/ffmpeg-rockchip) 构建，带
  `librockchip_mpp.so.0` 硬解支持
- `config/`：mpv.conf（`hwdec=rkmpp-copy`、`vo=wlshm`）、modernx 皮肤、触摸控制等脚本
- `screen_watchdog`：播放时保持显示输出的守护程序

## 结构

```
player.zip
└── mpv/
    ├── mpv                  # shell 包装器（写音频唤醒锁 + 启动 bin/mpv）
    ├── bin/mpv
    ├── lib/                 # FFmpeg/MPP/字体/wayland 等动态库
    ├── config/              # mpv.conf、脚本、字体
    └── screen_watchdog      # 屏幕守护（原生 aarch64）
```

## 部署位置

- 播放器安装到 **`/userdisk/mpv`**
- mod 启动时若 `/userdisk/mpv/mpv` 缺失，会自动从 **`/userdata/PenMods/player.zip`** 解压部署，
  并确保 `/userdisk/VideoPlayer` 软链指向 `/userdisk/mpv/mpv`
- 安装器/安装脚本需要把 `player.zip` 放到 `/userdata/PenMods/`

## 许可

mpv 为 GPL-2.0+，FFmpeg 为 LGPL/GPL，本包为社区构建的二进制（非本仓库源码构建），
分发时请遵守各上游许可证（保留源码获取途径：mpv、ffmpeg-rockchip）。

## 重建 zip

原始文件树不提交到 git（避免仓库膨胀）。如需修改配置后重新打包：

1. 从笔上拉取：`adb pull /userdisk/mpv <dir>/mpv`
2. 打包为 `mpv/` 前缀的 zip：`python scripts/package_player.py <dir>/mpv resource/player/player.zip`

`scripts/package_player.py` 会生成与发布包一致的 zip。
