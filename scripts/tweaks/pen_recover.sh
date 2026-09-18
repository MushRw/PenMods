#!/bin/sh
# PenMods 一键恢复（系统 OTA / A-B 槽位切换 / 厂商资源通道覆盖 rootfs 之后跑这个）
#
# 背景：PenMods 的所有改动都落在 **rootfs** 上（/oem、/usr/bin、/lib、/etc），
# 系统升级或切槽会把 rootfs 换回原版；此外厂商的"资源更新/修复"通道还会在
# 运行期把 /oem/YoudaoDictPen/output/YoudaoDictPen 写回原版（实测：打上补丁后
# 一次重启就没了）。/userdata、/userdisk 上的数据不受影响。
#
# 所以本脚本恢复完之后**必须给这些文件加不可变属性**（chattr +i），
# 否则厂商通道会把它们再写回去（加锁后实测补丁稳定存活）。
#
# 用法：  sh /userdata/PenMods/recover.sh
# 之后：  主程序会被重启（killall YoudaoDictPen，guardian_run 自动拉起）

set -x
mount -o remount,rw / 2>/dev/null

# 1) patchelf + glibc 库（misc/init.sh 会把 /lib/libm.so.6 等换成配套版本）
cd /userdata/PenMods/misc && sh ./init.sh

# 2) 主程序补丁（幂等：已带依赖就直接退出）
PATH=/userdata/PenMods/misc:$PATH sh /userdata/PenMods/patch.sh

# 3) runDictPen 的 glibc 内存调参
F=/usr/bin/runDictPen
if ! grep -q MALLOC_ARENA_MAX "$F"; then
    cp -a "$F" /userdata/runDictPen.bak
    sed -i '/^export APP_ROOT_PATH=/a export MALLOC_ARENA_MAX=2' "$F"
    sed -i '/^export MALLOC_ARENA_MAX=2/a export MALLOC_TRIM_THRESHOLD_=131072' "$F"
fi
grep -n MALLOC "$F"

# 4) zram swap（S20 必须早于 S21mountall，开机顺序才正确）
if [ -f /userdata/PenMods/misc/S20zramswap ]; then
    cp -f /userdata/PenMods/misc/S20zramswap /etc/init.d/S20zramswap
    chmod 755 /etc/init.d/S20zramswap
    sh -n /etc/init.d/S20zramswap && /etc/init.d/S20zramswap start
fi

# 5) 上锁：不加这一步，厂商通道会把上面这些文件再写回原版
for f in /usr/bin/patchelf /lib/libm.so.6 /usr/lib/libstdc++.so.6 /lib/libcrypt.so.1 \
         /usr/bin/runDictPen /etc/init.d/S20zramswap /oem/YoudaoDictPen/output/YoudaoDictPen; do
    chattr +i "$f" 2>/dev/null
    printf "%-45s %s\n" "$f" "$(lsattr "$f" 2>/dev/null | awk '{print $1}')"
done

# 6) 清崩溃计数。否则 runDictPen 的">5 次崩溃"保护会执行
#    update_engine --misc=clear + reboot —— 那会把笔重启到另一个槽位，
#    PenMods 的 rootfs 改动又会全丢。
rm -f /tmp/app_crash_count /tmp/app_crash_time

sync
echo "=== 恢复完成，重启主程序 ==="
killall YoudaoDictPen
