#!/bin/sh
# PenMods 全新安装：把 aarch64 静态 patchelf 装进系统
# 运行前提：根分区已 remount 为可写
set -e

echo "[init.sh] installing patchelf to /usr/bin ..."
cp -f patchelf /usr/bin/patchelf
chmod +x /usr/bin/patchelf
/usr/bin/patchelf --version
echo "[init.sh] done"
