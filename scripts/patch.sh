#!/bin/sh
# 给主程序加 DT_NEEDED 依赖（PenMods 的唯一入口）：主程序启动时才会把
# /userdata/PenMods/libPenMods.so 带起来。
#
# 为什么脚本要自己找 patchelf：系统 OTA / A/B 槽位切换会把 rootfs 换回原版，
# /usr/bin/patchelf（以及 misc/init.sh 装的 glibc 库）会一起消失。此时直接跑
# 本脚本只会得到 "patchelf: not found"。安装包自带的 misc/patchelf 在
# /userdata 上，OTA 不会动它，所以优先用它。
#
# 本脚本可重复执行：已经带依赖就直接退出，也保留最初的原版备份。

APP_PATH=/oem/YoudaoDictPen/output
MOD_PATH=/userdata/PenMods
SELF_DIR=$(dirname "$0")

PATCHELF=""
for c in "$SELF_DIR/misc/patchelf" "$MOD_PATH/misc/patchelf" /usr/bin/patchelf; do
    if [ -x "$c" ]; then
        PATCHELF="$c"
        break
    fi
done
echo "patchelf = ${PATCHELF:-<not found>}"

if [ -z "$PATCHELF" ]; then
    echo "!! 找不到 patchelf，无法打补丁"
    exit 1
fi

# / 默认只读，补丁要写 rootfs
mount -o remount,rw / 2>/dev/null || true

if grep -aq "libPenMods.so" "$APP_PATH/YoudaoDictPen"; then
    echo "主程序已经带 libPenMods.so 依赖，无需重复打补丁"
    exit 0
fi

cp "$APP_PATH/YoudaoDictPen" "$APP_PATH/YoudaoDictPen.temp"
"$PATCHELF" --add-needed $MOD_PATH/libPenMods.so "$APP_PATH/YoudaoDictPen.temp"
# 只在没有备份时保存原版，避免重复执行把备份覆盖成"已打过补丁的版本"
if [ ! -f "$APP_PATH/YoudaoDictPen.original_bak" ]; then
    mv "$APP_PATH/YoudaoDictPen" "$APP_PATH/YoudaoDictPen.original_bak"
fi
mv "$APP_PATH/YoudaoDictPen.temp" "$APP_PATH/YoudaoDictPen"
sync
echo "补丁完成：$(grep -ac libPenMods.so "$APP_PATH/YoudaoDictPen") 处依赖字符串"
