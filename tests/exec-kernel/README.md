# mod::exec() 内核行为测试

`mod::exec()` 是所有 shell 调用点的公共依赖，其中不少落在开机路径和 UI 线程上。
它的关键分支 —— **超时被强杀**、**子进程已退出但后台孙进程还占着管道**（init 脚本里
`start-stop-daemon` 拉起的守护进程就是这样）、**`pipe`/`fork` 失败** —— 在正常使用中
根本走不到，只有主动构造才能验证。旧实现（`popen` + `fgets` 到 EOF）就卡在第二类上
**永久挂住**。

这个目录是一份独立的小测试（不链接 Qt、不进 `libPenMods.so` 的构建图）。

## 被测代码是抽取来的，不是手抄的

`extract.py` 用「锚点 + 断言恰好命中一次」的方式，从 `src/common/Utils.h` 与
`src/common/Utils.cpp` 里把内核原样切出来生成 `build/extracted.inc`（只剥掉两行带
`QString` 的重载，因为这里没有 Qt）。任何锚点找不到或命中多次都会直接报错退出。

这样做的原因：手抄一份副本会跟真源码漂移，测出来的就不是要上机的东西了。源码一改动，
这里就会立刻失败，而不是静默地继续测一份过期副本。

## 怎么跑

```bash
cd tests/exec-kernel

# 1) 抽取内核（不带 --tree 时默认就是仓库根，即 src/ 所在的那一层）
python3 extract.py                     # 也可以 --tree /path/to/PenMods

# 2) 编译 + 运行（宿主机 / CI）
g++ -std=c++20 -O1 -g -pthread -I build main.cpp -o build/exec_test_native
./build/exec_test_native
```

退出码 = 失败断言数（上限 120），所以可以直接当 CI 判据。

### 交叉编译成真机能跑的静态二进制

真机的 glibc 是 2.27，所以**必须** `-static`，否则链接出来的动态可执行要求
glibc 2.38+，笔上根本起不来：

```bash
aarch64-linux-gnu-g++ -std=c++20 -O1 -static -pthread -I build main.cpp -o build/exec_test_aarch64

export MSYS_NO_PATHCONV=1
adb push build/exec_test_aarch64 /tmp/ && adb shell "chmod +x /tmp/exec_test_aarch64 && /tmp/exec_test_aarch64"
```

静态二进制 + `/tmp` 运行，不碰系统分区，跑完删掉即可。

## CI

`.github/workflows/exec-kernel-test.yaml` 两个 job：

| job | 做什么 |
| --- | --- |
| `native` | ubuntu x86_64 原生编译并运行，**全部断言有效**，作为回归门禁 |
| `aarch64` | 交叉编译成全静态 aarch64 → `qemu-aarch64-static` 冒烟 → 上传 artifact（真机可直接跑） |

## 三种运行环境的差异（别把结论用错地方）

- **CI 原生 x86_64**：断言全部有效。`/bin/sh` 是 dash。
- **qemu-aarch64**：验证指令集侧没写错；`/proc` 相关统计（第 9、10 节的 fd / 僵尸数）
  看到的是 qemu 进程自己的，趋势可用、绝对值不要当真。
- **真机**：真实定制内核 + 真实 busybox `/bin/sh`。这里才验证得到 shell 细节 ——
  `sleep` 是否支持小数秒、有没有 `pgrep`、`seq` 的行为。dash 与 busybox sh 在这些
  内建命令上**并不一致**。

## 为什么不能用宿主机的 MSYS/MinGW 跑

Windows 上的 MinGW 没有 `fork()`；MSYS 虽然有，但它的 `/proc` 是模拟的、`fork` 语义
也与 Linux 不同，第 9、10 节会给出误导性的结果。这个内核只能在真 Linux 上验证。
