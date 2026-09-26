# rootfs 可写窗口 / 口令区 POSIX 原语的行为测试

被测的东西只有一个共同点：**它们的关键分支在正常使用中走不到**，而失败后果都落在最痛的地方。

| 被测对象 | 源码位置 | 正常使用中走不到的分支 | 走错了的后果 |
|---|---|---|---|
| `util::RootFileSystemWritableGuard` | `src/common/util/System.{h,cpp}` | 嵌套进入、remount rw 失败、归还失败、本来就 rw、提前 `return` / 异常展开 | 只读 rootfs 被留在可写（本设备唯一"改不坏"的保险失效） |
| `_replaceFileAtomically` | `src/helper/ServiceManager.cpp` | `tmp` 打不开、短写、`rename` 失败、权限被 umask 削掉 | 毁掉 `/etc/shadow`（全机唯一能登录的账户） |
| `_randomSalt` | `src/helper/ServiceManager.cpp` | CSPRNG 读不到、字母表映射写错 | salt 退化成"只有几十种"，散列形同虚设 |

对照条目：`EX-04`（窗口不异常安全）、`EX-05`（用读-改-写代替引用计数）、`EX-18`（`/etc/shadow` 就地截断重写）、`EX-19`（`$1$` + 弱 salt）。

## 怎么跑

```sh
python3 tests/posix-helpers/extract.py --tree .
g++ -std=c++20 -O1 -g -Wall -Wextra -pthread \
  -I tests/posix-helpers/build tests/posix-helpers/main.cpp \
  -o tests/posix-helpers/build/posix_helpers_test
./tests/posix-helpers/build/posix_helpers_test
```

CI 里同样是两条腿（见 `.github/workflows/posix-helpers-test.yaml`）：

1. **原生 x86_64** —— 全部断言有效，用于回归；
2. **aarch64 全静态** —— 先用 `qemu-aarch64-static` 冒烟，产物再推到真机跑。

## 为什么要抽源码，不手抄

手抄的副本会跟真源码漂移，测出来的就不是要上机的那份逻辑了。`extract.py` 用
「锚点 + 断言恰好命中一次」把片段**原样**切出来（只剥掉窗口计数状态末尾那个匿名命名
空间的闭合），任何一个锚点找不到或命中多次都直接报错。生成结果还会做一次形态自检，
断言守卫类声明、构造 / 析构定义、64 字符静态断言、两个函数的签名都确实抽到了 ——
这些都是"抽漏了就会静默测不到东西"的失败模式。

`extracted.inc` 是**生成物**，不要手改，也不要提交（见 `.gitignore`）。

## remount 桩

守卫真会 `mount -o remount` 真文件系统，所以单测里把
`mod::util::isRootFileSystemWritable` / `mod::util::setRootFileSystemWritable`
换成 `main.cpp` 里的可控实现，用来构造上面那些分支。桩**刻意复刻**了真实现的一个行为：
「已经是目标状态就直接返回 `true`、不做任何事」—— 守卫的去重正是建立在这个短路之上，
桩不复刻就测不出"嵌套时只 remount 一次"。

## 真机上的额外价值

CI 上跑的是宿主内核 + `tmpfs`。推到真机跑时用的是真实的定制内核 + 真实 `ext4`
（`data=ordered`），`fsync` / `rename` 的持久化语义才算数。原子替换那一节在真机上过，
才算真的验证了"掉电不会留下半个 `/etc/shadow`"。

## 真机上不会测到的部分

`_getRandomString` 之外的加密部分（`crypt()` 生成的 `$6$` 散列能否被 `sshd` 接受）
不在这里测 —— 它需要 `libcrypt` 的开发头，交叉静态链接时会引入额外依赖。这一环在
真机上用「改一次密码 → 用 `perl -e 'print crypt(...)'` 复算 → 用新口令 `ssh` 登录」
端到端验证。
