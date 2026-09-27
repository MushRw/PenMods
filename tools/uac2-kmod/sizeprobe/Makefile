# 结构体尺寸指纹探针（只编一个 .o，不加载；用 nm -S 读 sizeof）
#
# 单独一个目录是为了不被「ABI 修正」步骤的 tools/uac2-kmod/*.ko 通配到，
# 也不会被上传成产物。
obj-m += sizeprobe.o
