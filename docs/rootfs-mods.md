# rootfs 级改动的脆弱性与恢复

> 这份文档记录 2026-09-18 事故的完整结论：**PenMods 被系统还原、界面回到原版**。
> 目标读者：以后再遇到"PenMods 怎么没了"的人。

## 一句话结论

PenMods 的改动分两类：

| 类别 | 位置 | 会不会被系统还原 |
| --- | --- | --- |
| 数据/插件 | `/userdata/PenMods`、`/userdisk`（插件、rime、会话） | **不会** |
| rootfs 改动 | `/oem/YoudaoDictPen/output/YoudaoDictPen`（补丁）、`/usr/bin/patchelf`、`/lib/libm.so.6` 等三个 glibc 库、`/usr/bin/runDictPen`（内存调参）、`/etc/init.d/S20zramswap` | **会被还原** |

rootfs 一被换掉，主程序就回到原版，于是**不会加载 `libPenMods.so`**：界面还是原版、
`/proc/<pid>/maps` 里没有 PenMods、应用日志里也没有 `Found plugin`。
`/userdata`、`/userdisk` 上的东西都还在。

## 本次事故的链条（都有实测证据）

1. **触发**：当时笔上跑着一个"启动即自动录音 2.5 秒"的临时调试 QML（为了验证录音
   lame 码率）。它让主程序**反复崩溃**（`/userdisk/Music/录音文件/` 里留下一串
   0 字节的 `新录音NN.mp3`）。
2. **厂商崩溃保护**：`/usr/bin/runDictPen` 末尾有
   ```sh
   if [ `cat /tmp/app_crash_count` -gt 5 ] ; then
       /usr/bin/update_engine --misc=clear   # 清 A/B 槽位元数据
       reboot                                # 重启 → 切到另一个槽
   fi
   ```
   → 笔重启到 **另一个槽位**（`cmdline` 里 `androidboot.slot_suffix=_b`），那份 rootfs
   是出厂原版，补丁全没。
3. **二次覆盖**：即使重新打好补丁，厂商的"资源更新/修复"通道在**运行期**还会把
   `/oem/YoudaoDictPen/output/YoudaoDictPen` 写回原版（实测：22:50 打补丁、22:52
   重启，22:56 就变回原版；静置不重启则 90 秒内稳定不变 → 说明是启动路径触发的）。
   它同样会还原 `/usr/bin/patchelf`、三个 glibc 库、`runDictPen`、`S20zramswap`。

## 恢复办法

一键脚本：`sh /userdata/PenMods/recover.sh`（源码 `scripts/tweaks/pen_recover.sh`）。
它做四件事，**最后一步是关键**：

1. `misc/init.sh`：装回 `patchelf` 与三个 glibc 库；
2. `patch.sh`：给主程序加 `DT_NEEDED /userdata/PenMods/libPenMods.so`（幂等）；
3. `runDictPen` 的 `MALLOC_ARENA_MAX=2` / `MALLOC_TRIM_THRESHOLD_=131072`、`S20zramswap`；
4. **对以上每个文件 `chattr +i` 上锁** —— 不上锁，第 1~3 步做完还是会被厂商通道写回去。

上锁后实测：`lsattr` 为 `----i---------e---`，`grep -c PenMods` 主程序为 1，
`/proc/<pid>/maps` 里 PenMods 有 23 个映射，应用日志出现
`Resource files have been replaced!` / `Using external Qt res.`，4 个插件全部加载。

## 做实验时的红线

- **不要在 App 启动路径上调用重型厂商 API**（录音、播放、相机…）。崩溃会被
  `runDictPen` 的计数保护放大成 `update_engine --misc=clear` + `reboot`，
  直接丢掉整个 rootfs 的改动。调试代码要么用 `Timer` 延迟，要么做成手动触发。
- 上机验证优先用"能落盘的外部证据"（`shell.startDetached` 写 `/tmp/*.log`），
  而不是让 App 在启动时做副作用动作。
- 每次动 rootfs 之后，顺手 `lsattr` 确认锁还在。

## 相关命令

```sh
# 查看槽位与更新状态
cat /proc/cmdline
update_engine --misc=display

# 查看 rootfs 改动是否还在
ls -l /usr/bin/patchelf /etc/init.d/S20zramswap
grep -c MALLOC /usr/bin/runDictPen
grep -a -c PenMods /oem/YoudaoDictPen/output/YoudaoDictPen   # 0 = 补丁丢了

# 解锁（要在升级系统前临时解锁时用）
chattr -i /oem/YoudaoDictPen/output/YoudaoDictPen
```

## 附：系统 CA 库也会丢（2026-09-20 事故）

切槽 / OTA 之后除了 PenMods 自己的改动，**系统 CA 库也可能整个消失**，
症状是「B 站（Bili 插件）连不上」，但 WiFi、DNS、App 启动都正常：

```sh
ls -l /etc/ssl/certs/ca-certificates.crt   # No such file → 就是这个问题
ls /etc/ssl/certs | wc -l                  # 0
```

原因：Bili 插件的 `server` / `bili-sms` 是 **Go 二进制**，包内不带证书
（`bili_plugin_*.zip` 里没有任何 cert 文件），Go 只认系统 CA
（`/etc/ssl/certs/ca-certificates.crt`，或 `SSL_CERT_FILE` / `SSL_CERT_DIR`），
bundle 一缺，插件所有 HTTPS 请求全失败。

恢复（bundle 从厂商 rootfs 镜像里抽，132 张证书 / 270,954 字节）：

```sh
mount -o remount,rw /
mkdir -p /etc/ssl/certs
cp -f /tmp/ca.crt /etc/ssl/certs/ca-certificates.crt
chmod 644 /etc/ssl/certs/ca-certificates.crt
chattr +i /etc/ssl/certs/ca-certificates.crt    # 同样要上锁
killall YoudaoDictPen                            # 让插件 server 重启，重读 CA
```

抽取思路：在 `system.img` 里找 `-----BEGIN CERTIFICATE-----` 最密的那一簇
（最大连续块），从首块行首切到末块行尾，再逐块 `PEM → DER` 校验。
