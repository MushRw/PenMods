#!/bin/sh
# 给 /usr/bin/runDictPen 加 glibc 内存调参，降低多线程堆碎片（实测 RSS -7%）
#
# 背景（YDP02X，460MB 内存）：主程序 44~52 线程，glibc 默认会给每个线程分配一个
# malloc arena（上限 8 × 核数），60 多个无路径匿名映射里最大几块会随时间从
# 30MB 涨到 62MB —— 典型 arena 碎片。限制 arena 数量能显著压低这部分。
#
# 实测（都是"重启后约 90 秒"的新鲜状态，可比）：
#   改前                            VmRSS 181 MB
#   ARENA_MAX=2 + TRIM=131072       VmRSS 168 MB   (-14 MB, -7.4%)   <- 采用
#   ARENA_MAX=1 + TRIM/MMAP=65536   VmRSS 166 MB   (只再多 1 MB，且单 arena 有锁竞争，弃用)
#
# 可逆：原文件备份在 /userdata/runDictPen.bak
#   mount -o remount,rw / && cp /userdata/runDictPen.bak /usr/bin/runDictPen && sync
#
# 生效时机：下次重启主程序（guardian_run 会用新脚本重新拉起）。

F=/usr/bin/runDictPen

if grep -q '^export MALLOC_ARENA_MAX=2' "$F"; then
    echo "已经打过补丁，跳过"
    exit 0
fi

mount -o remount,rw / || { echo "!! remount rw 失败"; exit 1; }
[ -f /userdata/runDictPen.bak ] || cp -a "$F" /userdata/runDictPen.bak

# 插在 export APP_ROOT_PATH 之后（必须在启动主程序之前）
sed -i '/^export MALLOC_ARENA_MAX/d' "$F"
sed -i '/^export MALLOC_TRIM_THRESHOLD_/d' "$F"
sed -i '/^export MALLOC_MMAP_THRESHOLD_/d' "$F"
sed -i '/^export APP_ROOT_PATH=/a export MALLOC_ARENA_MAX=2' "$F"
sed -i '/^export MALLOC_ARENA_MAX=2/a export MALLOC_TRIM_THRESHOLD_=131072' "$F"

sync
echo "--- 结果 ---"
grep -n 'MALLOC\|APP_ROOT_PATH' "$F"

cd /tmp
mount -o remount,ro / 2>/dev/null
echo "（若这里报 Device or resource busy，是因为正在运行的启动脚本还持有被替换的
 旧 inode；无害，下次重启自动恢复只读。）"
