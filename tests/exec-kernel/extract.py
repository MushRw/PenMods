#!/usr/bin/env python3
"""从 PenMods 源码里**原样**抽出 mod::exec() 内核，生成可编译的单测输入。

为什么不手抄一份：手抄的副本会跟真源码漂移，测出来的就不是要上机的东西了。
这里所有片段都用「锚点 + 断言恰好命中一次」的方式抽取，任何一个锚点找不到
或者命中多次都直接报错 —— 源码一改动就立刻暴露，不会静默产出过期副本。

用法：
    python tools/exec-kernel-test/extract.py [--tree E:\\code\\youdao\\PenMods]
输出：
    tools/exec-kernel-test/build/extracted.inc
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# tests/exec-kernel/ -> 仓库根（src/ 与 xmake.lua 所在处）
DEFAULT_TREE = HERE.parent.parent


def slice_between(text: str, start_anchor: str, end_anchor: str, what: str) -> str:
    """取 [start_anchor 起始位置, end_anchor 起始位置) 之间的原文。"""
    if text.count(start_anchor) != 1:
        raise SystemExit(f"[抽取失败] {what}: 起始锚点命中 {text.count(start_anchor)} 次（应为 1 次）:\n  {start_anchor!r}")
    if text.count(end_anchor) != 1:
        raise SystemExit(f"[抽取失败] {what}: 结束锚点命中 {text.count(end_anchor)} 次（应为 1 次）:\n  {end_anchor!r}")
    begin = text.index(start_anchor)
    end = text.index(end_anchor)
    if end <= begin:
        raise SystemExit(f"[抽取失败] {what}: 结束锚点在起始锚点之前")
    return text[begin:end]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default=str(DEFAULT_TREE), help="PenMods 源码树根目录（含 src/ 的那一层）")
    ap.add_argument("--out", default=str(HERE / "build" / "extracted.inc"), help="输出文件")
    args = ap.parse_args()

    tree = Path(args.tree).resolve()
    utils_h = tree / "src" / "common" / "Utils.h"
    utils_cpp = tree / "src" / "common" / "Utils.cpp"
    for p in (utils_h, utils_cpp):
        if not p.is_file():
            raise SystemExit(f"[抽取失败] 找不到 {p}")

    h = utils_h.read_text(encoding="utf-8")
    cpp = utils_cpp.read_text(encoding="utf-8")

    # ---- 1) 超时档位常量 ----
    consts = slice_between(h, "constexpr int kExecQuickMs", "constexpr int kExecNoTimeout = 0;", "超时常量")
    consts += "constexpr int kExecNoTimeout = 0;"

    # ---- 2) ExecResult ----
    result_struct = slice_between(h, "struct ExecResult {", "\n/// 执行 shell 命令", "ExecResult")
    result_struct = result_struct.rstrip() + "\n"

    # ---- 3) 内核：匿名命名空间的辅助函数 + execWithResult / exec ----
    helpers = slice_between(cpp, "namespace {", "ExecResult execWithResult(const QString& cmd", "内核辅助函数")
    core = slice_between(cpp, "ExecResult execWithResult(const char* cmd, int timeoutMs) {",
                         "// 12.333 -> 12.3, if n=1", "execWithResult 主体")

    # 只丢掉 QString 那两行重载 —— 单测里没有 Qt，其余一字不改。
    dropped = []
    kept = []
    for line in core.splitlines(keepends=True):
        if "QString" in line:
            dropped.append(line.rstrip())
        else:
            kept.append(line)
    core = "".join(kept)

    body = f"""// ============================================================================
// 本文件由 tools/exec-kernel-test/extract.py 自动生成，请勿手改。
// 内容是从 PenMods 的 src/common/Utils.h 与 src/common/Utils.cpp 原样抽取的
// mod::exec() 内核 —— 除了剥掉两行 QString 重载（单测里没有 Qt），没有任何改动。
// 源: {tree}
// ============================================================================

{consts}

{result_struct}
namespace mod {{

{helpers}{core}
}} // namespace mod
"""
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(body, encoding="utf-8")

    print(f"已生成 {out}")
    print(f"  超时常量     {len(consts.splitlines())} 行")
    print(f"  ExecResult   {len(result_struct.splitlines())} 行")
    print(f"  内核         {len(helpers.splitlines()) + len(core.splitlines())} 行")
    if dropped:
        print("  已剔除的 QString 行:")
        for d in dropped:
            print(f"    - {d.strip()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
