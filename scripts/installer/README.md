# PenMods 一键安装程序

把本目录（或发布包 zip）放到电脑上，词典笔 USB 连接并开启 ADB
（设置 -> 关于 -> 法律监管，快速连点 7 次）后：

- Windows：双击 `start.cmd`
- 其它系统：`python install.py`

程序会自动完成：解锁 -> 挂载可写 -> 推送 mod/播放器/输入法/VPN 内核 ->
（全新安装时）安装 patchelf 并打补丁 -> 校验 -> 重启。

已装过 PenMods 的笔按**升级**处理，只替换文件、不重复打补丁。

## 发布包内容

```text
install.py / start.cmd
libPenMods.so / libPenModsResources.so
player.zip / rime.zip / mihomo.gz
patch.sh / misc/init.sh / misc/patchelf
```
