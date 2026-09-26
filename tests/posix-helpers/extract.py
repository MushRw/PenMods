#!/usr/bin/env python3
"""从 PenMods 源码里**原样**抽出两个不安全就没人看得见的 POSIX 原语，生成单测输入：

  1. `util::RootFileSystemWritableGuard`（EX-04 / EX-05）—— rootfs 可写窗口的 RAII +
     引用计数。真实现会 remount 真文件系统，所以它的关键分支（嵌套进入、进入失败、
     还原失败、本来就 rw）在正常使用中一辈子走不到，只能把 remount 换成可控桩来构造。
  2. `_randomSalt` / `_replaceFileAtomically`（EX-18 / EX-19）—— 口令 salt 的随机源与
     `/etc/shadow` 的原子替换。失败路径（tmp 打不开、短写、rename 失败）同样走不到。
  3. `_isProcessRunning`（EX-07）—— `Q_PROPERTY` READ 里判断 sshd 在不在的进程探测，
     扫 `/proc/*/comm` 代替 `exec("ps | grep [s]sh")`。它每被 QML 求值一次就跑一遍，
     写错了最典型的后果是"永远返回 false"⇒ UI 上的 SSH 开关看起来永远是关的。

为什么不手抄一份：手抄的副本会跟真源码漂移，测出来的就不是要上机的东西了。这里所有
片段都用「锚点 + 断言恰好命中一次」抽取，任何一个锚点找不到或命中多次都直接报错。

用法：
    python3 tests/posix-helpers/extract.py [--tree <仓库根>]
输出：
    tests/posix-helpers/build/extracted.inc
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# tests/posix-helpers/ -> 仓库根（src/ 与 xmake.lua 所在处）
DEFAULT_TREE = HERE.parent.parent


def slice_between(text: str, start_anchor: str, end_anchor: str, what: str) -> str:
    """取 [start_anchor 起始位置, end_anchor 起始位置) 之间的原文。"""
    if text.count(start_anchor) != 1:
        raise SystemExit(
            f"[抽取失败] {what}: 起始锚点命中 {text.count(start_anchor)} 次（应为 1 次）:\n  {start_anchor!r}"
        )
    if text.count(end_anchor) != 1:
        raise SystemExit(f"[抽取失败] {what}: 结束锚点命中 {text.count(end_anchor)} 次（应为 1 次）:\n  {end_anchor!r}")
    begin = text.index(start_anchor)
    end = text.index(end_anchor)
    if end <= begin:
        raise SystemExit(f"[抽取失败] {what}: 结束锚点在起始锚点之前")
    return text[begin:end]


def strip_trailing_anon_close(text: str, what: str) -> str:
    """剥掉片段末尾的 `} // namespace`（匿名命名空间的闭合）。

    System.cpp 里的窗口计数状态住在文件级匿名命名空间里，只抽中间一段会留下一个没有
    开头的 `}`。这里显式断言它确实在末尾，再把它摘掉；摘失败就等于生成的文件括号不平衡，
    编译期才会炸，不如在这里先炸。
    """
    body = text.rstrip()
    if not body.endswith("} // namespace"):
        raise SystemExit(f"[抽取失败] {what}: 片段末尾不是 `}} // namespace`，无法安全剥离:\n  ...{body[-80:]!r}")
    return body[: -len("} // namespace")].rstrip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default=str(DEFAULT_TREE), help="PenMods 源码树根目录（含 src/ 的那一层）")
    ap.add_argument("--out", default=str(HERE / "build" / "extracted.inc"), help="输出文件")
    args = ap.parse_args()

    tree = Path(args.tree).resolve()
    system_h = tree / "src" / "common" / "util" / "System.h"
    system_cpp = tree / "src" / "common" / "util" / "System.cpp"
    service_cpp = tree / "src" / "helper" / "ServiceManager.cpp"
    for p in (system_h, system_cpp, service_cpp):
        if not p.is_file():
            raise SystemExit(f"[抽取失败] 找不到 {p}")

    sh = system_h.read_text(encoding="utf-8")
    sc = system_cpp.read_text(encoding="utf-8")
    sm = service_cpp.read_text(encoding="utf-8")

    # ---- 1) 守卫的类声明（必须有：只有 .cpp 里的构造/析构定义是编译不过的）----
    guard_decl = slice_between(sh, "class RootFileSystemWritableGuard {", "} // namespace mod::util", "守卫类声明")
    guard_decl = guard_decl.rstrip()

    # ---- 2) 窗口引用计数状态 ----
    window = slice_between(sc, "// rootfs 可写窗口的引用计数", "bool isRootFileSystemWritable()", "窗口计数状态")
    window = strip_trailing_anon_close(window, "窗口计数状态")

    # ---- 3) 守卫的构造 / 析构定义 ----
    guard_impl = slice_between(
        sc, "RootFileSystemWritableGuard::RootFileSystemWritableGuard()", "} // namespace mod::util", "守卫实现"
    )
    guard_impl = guard_impl.rstrip()

    # ---- 4) salt 生成（字母表 + CSPRNG 读取 + _randomSalt）----
    salt = slice_between(sm, "/// `crypt()` 的 base64 字母表", "bool _replaceFileAtomically", "salt 生成")
    salt = salt.rstrip()

    # ---- 5) 原子替换 ----
    # 结束锚点取 `_ensureShadowBackup` 的**文档注释开头**，而不是它的函数定义 —— 否则
    # 会把那段注释一起带进来，结尾留一个悬空的 /// 块。
    replace = slice_between(sm, "bool _replaceFileAtomically", "/// 只在**不存在**时留一份", "原子替换")
    replace = replace.rstrip()

    # ---- 6) 进程探测（EX-07）----
    # 结束锚点取 `ServiceManager::ServiceManager()` 的定义，再用 strip_trailing_anon_close
    # 摘掉匿名命名空间的闭合 —— 直接拿 `} // namespace` 当锚点会命中两次（文件末尾还有
    # 一个 `} // namespace mod`，它是前者的**子串**）。
    proc_scan = slice_between(sm, "/// 有没有名字叫 `wanted` 的进程在跑", "ServiceManager::ServiceManager()", "进程探测")
    proc_scan = strip_trailing_anon_close(proc_scan, "进程探测")

    body = f"""// ============================================================================
// 本文件由 tests/posix-helpers/extract.py 自动生成，请勿手改。
// 内容是从 PenMods 的 src/common/util/System.{{h,cpp}} 与 src/helper/ServiceManager.cpp
// **原样**抽取的 POSIX 原语（只剥掉了窗口计数状态末尾那个匿名命名空间的闭合），
// 没有任何其他改动。
//
// 注意：守卫的析构里用了 `spdlog::error`，本文件**故意不包含** spdlog —— 包含它的
// 那个 .cpp（main.cpp）必须在 include 本文件**之前**先把桩定义好。
// 源: {tree}
// ============================================================================

#include <atomic>
#include <cerrno>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

namespace mod {{
namespace util {{

// ---- 类声明来自 src/common/util/System.h ----
{guard_decl}

// ---- remount 桩声明。真实现会 `mount -o remount,...` 真文件系统；单测里换成
//      main.cpp 提供的可控实现，才能把"进入失败 / 还原失败 / 已经 rw"这些分支构造出来。----
bool isRootFileSystemWritable();
bool setRootFileSystemWritable(bool writable);

// ---------------- 原样抽取自 src/common/util/System.cpp ----------------
// 窗口计数状态（原文件里它住在文件级匿名命名空间里；这里剥离了那个闭合）
{window}

{guard_impl}

}} // namespace util

// ---------------- 原样抽取自 src/helper/ServiceManager.cpp ----------------
{salt}

{replace}

{proc_scan}

}} // namespace mod
"""

    # ---- 生成结果自检 ----
    # 这些断言都对应"实际会让单测静默失效或编译不过"的失败模式，改源码时先在这里炸掉。
    problems = []
    if guard_decl.count("class RootFileSystemWritableGuard") != 1:
        problems.append("生成结果里守卫类声明不是恰好 1 处")
    if "RootFileSystemWritableGuard::RootFileSystemWritableGuard()" not in body:
        problems.append("没抽到守卫的构造函数定义")
    if "RootFileSystemWritableGuard::~RootFileSystemWritableGuard()" not in body:
        problems.append("没抽到守卫的析构函数定义")
    if "gRootFsWindowDepth" not in body or "gRootFsWindowWasWritable" not in body:
        problems.append("没抽到窗口引用计数的两个静态状态（守卫会编译不过）")
    if "constexpr char kCryptSaltAlphabet[]" not in body:
        problems.append("没抽到 salt 字母表")
    if "/// `crypt()` 的 base64 字母表" not in body:
        problems.append("salt 字母表的说明注释没跟着抽出来（锚点可能已过期）")
    if "static_assert(sizeof(kCryptSaltAlphabet) - 1 == 64" not in body:
        problems.append("没抽到 salt 字母表的 64 字符静态断言")
    if "std::string _randomSalt(size_t length)" not in body:
        problems.append("没抽到 _randomSalt 的定义")
    if "bool _replaceFileAtomically(const std::string& path, const char* tmpPath, const void* data, size_t len," not in body:
        problems.append("没抽到 _replaceFileAtomically 的定义（签名可能已经改过）")
    if "_ensureShadowBackup" in body:
        problems.append("把 _ensureShadowBackup 的注释一起带进来了（结束锚点应指向它的文档注释开头）")
    if "bool _isProcessRunning(const char* wanted)" not in body:
        problems.append("没抽到 _isProcessRunning 的定义（签名可能已经改过）")
    if "::opendir(\"/proc\")" not in body:
        problems.append("没抽到 /proc 扫描（_isProcessRunning 的实现体可能已过期）")
    if body.count("namespace mod {") != 1:
        problems.append("生成结果里 `namespace mod {` 不是恰好 1 处")
    if problems:
        raise SystemExit("[抽取自检失败] 生成的原语与预期形态不符：\n  - " + "\n  - ".join(problems))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(body, encoding="utf-8")

    print(f"已生成 {out}")
    print(f"  守卫类声明   {len(guard_decl.splitlines())} 行")
    print(f"  窗口计数状态 {len(window.splitlines())} 行")
    print(f"  守卫实现     {len(guard_impl.splitlines())} 行")
    print(f"  salt 生成    {len(salt.splitlines())} 行")
    print(f"  原子替换     {len(replace.splitlines())} 行")
    print(f"  进程探测     {len(proc_scan.splitlines())} 行")
    return 0


if __name__ == "__main__":
    sys.exit(main())
