# 设备侧系统小改动（不属于 mod 编译产物）

这里放**不改 mod 代码、直接落到笔的系统里**的脚本。它们不参与 xmake 构建，
安装方式都是：临时把 `/` 挂成 rw → 拷贝 → 恢复 ro（见每节说明）。

---

## S20zramswap —— 用 zram 压缩交换替代直接写 eMMC

### 为什么

笔是 460MB 内存，厂商在 `/etc/fstab` 里挂了一个 **1GB 的 eMMC swap**
（`/dev/block/by-name/swap` → `/dev/mmcblk1p13`，由 `/etc/init.d/S21mountall.sh` 执行
`mkswap + swapon`）。实测冷页是**直接写到 eMMC**的：

- 一次开机周期内 `pswpout` 63,563 页 ≈ **248MB 写到 eMMC**
- 主程序（`YoudaoDictPen`）长期 `VmRSS 122MB + VmSwap 127MB`

代价是 eMMC 写入磨损 + 唤醒换页慢。内核里其实**编译了 zram**（`/dev/zram0` 存在，
默认 `disksize=0` 未启用，算法 `lzo`），但 **没有 zswap**（没有 `/sys/module/zswap`）。

### 做法

`S20zramswap` 排在 `S21mountall.sh` **之前**（`rcS` 按 `S??` 排序）：

```
S10init → S10udev → S20urandom → S20zramswap → S21mountall.sh(挂 eMMC swap)
```

内核是**按激活顺序**分配 swap 优先级的（先挂的最高，`-1`）。所以 zram 拿到 `-1`
被优先使用，eMMC 那个 1GB swap 变成 `-2` 只做兜底 —— 不需要改 fstab，也不需要
`swapon -p`（笔上的 busybox `swapon` 不支持 `-p`）。

另外把 `vm.swappiness` 提到 `100`：zram 上换页是内存压缩、不写盘，代价很低，
把冷页优先压进内存比挤掉页缓存更划算。

### 实测效果（受控压力测试：往 tmpfs 灌 100MB）

| 指标 | 结果 |
| --- | --- |
| zram 用量 | 13,764 KB |
| eMMC swap 用量 | **0**（零写入） |
| zram 统计 | 原始 14.1MB → 压缩 3.09MB → **占内存 3.5MB**（这批数据 4.6x；真实数据约 2-3x） |
| OOM | 无 |

注意 zram 只按**实际存进去的量**占内存，所以 `disksize` 开大不浪费
（256MB 设备约能容纳 500–800MB 原始数据）。

### 安装

```sh
adb push S20zramswap /userdata/S20zramswap
adb shell 'mount -o remount,rw / && \
           cp /userdata/S20zramswap /etc/init.d/S20zramswap && \
           chmod 755 /etc/init.d/S20zramswap && sync && \
           mount -o remount,ro /'
```

### 查看 / 停用

```sh
adb shell /etc/init.d/S20zramswap status   # swap 设备、swappiness、压缩统计
adb shell /etc/init.d/S20zramswap stop     # 只停 zram，eMMC swap 不受影响
```

### 回退

```sh
adb shell 'mount -o remount,rw / && rm /etc/init.d/S20zramswap && sync && mount -o remount,ro /'
# 重启后即回到"只用 eMMC swap"的原状；本次运行中也可先 /etc/init.d/S20zramswap stop
```

注意：A/B 双槽的 OTA 换槽后 `/etc` 会被换掉，需要重新安装一次。
