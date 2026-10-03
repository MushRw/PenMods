#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
c-comment-lint.py —— 抓「注释被提前终结」这个 bug 类。

为什么需要
----------
2026-10-03 CI run 37097331238 在第 11 步「编译 utest.ko」炸出几十条
`error: stray '\\357' in program` / `unknown type name 'msi_irqs'`，原因是在
注释里写了设备路径的**通配形式**：

    /* 同时保证 MSI 是关的（设备 /sys/devices/platform asterisk slash msi_irqs count = 0）；

`platform` 后面的 `*` `/` 把这条 C 注释**就地终结**了 ⇒ 后面的中文
（UTF-8 首字节 0xEF = '\\357'）全被当成代码。同一个写法在 sizeprobe.c 的
注释续行里也有一份（那份只是还没轮到编译，属于定时炸弹）。

这类 bug 的特征非常干净：**`/*/` 三连字符**（斜杠-星号-斜杠）。
正常的单行注释 `/* xxx */` 不会产生它，正常代码里也不该出现它。
所以本检查器**只查这一条**，不做任何"语义猜测"。

（教训：上一版想顺带查「未声明引用 + 括号配平」，结果误报淹没真信号，
  整条闸门被弃用。检查器范围必须收窄到零误报，才有资格当门禁。）

判定流程（两趟，都是精确判据）
------------------------------
趟 1：把**字符串/字符字面量**与**行注释**替换成空格（保留换行 ⇒ 行号不变），
      **块注释原样保留**。在结果上找 `/*/`          → 规则 A（根因）
趟 2：在趟 1 的结果上再按 C 的规则（第一个 `*/` 就结束）剥掉块注释。
      在残留代码里找 `*/`                          → 规则 B（残渣，兜底）

只要 A 或 B 命中就说明有一条注释被提前终结了。字符串字面量里的 `/*/` 是合法的
（已在本趟被替换掉），不会误报。

用法
----
    python3 tools/uac2-kmod/c-comment-lint.py FILE.c [FILE2.c ...]
    python3 tools/uac2-kmod/c-comment-lint.py --dir tools/uac2-kmod

退出码：0 = 干净；1 = 有问题；2 = 用法错误。
"""

import os
import sys


def strip_literals_and_line_comments(src):
    """把字符串/字符字面量、行注释替换成空格；换行保留 ⇒ 行号与原文一一对应。"""
    out = list(src)
    n = len(src)
    i = 0
    while i < n:
        c = src[i]

        if c == '"' or c == "'":
            quote = c
            out[i] = " "
            i += 1
            while i < n:
                if src[i] == "\\":
                    out[i] = " "
                    if i + 1 < n:
                        out[i + 1] = " "
                    i += 2
                    continue
                if src[i] == quote:
                    out[i] = " "
                    i += 1
                    break
                if src[i] != "\n":
                    out[i] = " "
                i += 1
            continue

        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
            continue

        i += 1
    return "".join(out)


def strip_block_comments(s):
    """按 C 规则剥块注释：从 `/*` 到**第一个** `*/`。换行保留 ⇒ 行号不变。"""
    out = list(s)
    n = len(s)
    i = 0
    while i < n:
        if s[i] == "/" and i + 1 < n and s[i + 1] == "*":
            out[i] = " "
            out[i + 1] = " "
            i += 2
            while i < n:
                if s[i] == "*" and i + 1 < n and s[i + 1] == "/":
                    out[i] = " "
                    out[i + 1] = " "
                    i += 2
                    break
                if s[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        i += 1
    return "".join(out)


def scan(src):
    """返回 [(lineno, rule, snippet), ...]"""
    problems = []
    s1 = strip_literals_and_line_comments(src)

    # ── 规则 A：块注释仍完整时，找 `/*/`（= 注释里开了 `/*` 又紧跟 `/`）──
    rule_a_lines = set()
    for lineno, line in enumerate(s1.split("\n"), start=1):
        p = line.find("/*/")
        if p >= 0:
            problems.append((lineno, "A", line.strip()[:120]))
            rule_a_lines.add(lineno)

    # ── 规则 B：剥掉块注释后的残留代码里还有游离 `*/` ──
    s2 = strip_block_comments(s1)
    for lineno, line in enumerate(s2.split("\n"), start=1):
        if lineno in rule_a_lines:
            continue          # 同一行已被 A 报过，不重复
        if line.find("*/") >= 0:
            problems.append((lineno, "B", line.strip()[:120]))

    return problems


def check_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            src = f.read()
    except OSError as e:
        print("  !! 读不了 %s: %s" % (path, e))
        return 1

    problems = scan(src)
    if not problems:
        print("  ✅ %s" % path)
        return 0

    print("  ❌ %s —— %d 处注释提前终结：" % (path, len(problems)))
    for ln, rule, snip in problems:
        print("       行 %d  [规则 %s]  %s" % (ln, rule, snip))
    return 1


def iter_c_files(d):
    for root, _dirs, files in os.walk(d):
        for fn in sorted(files):
            if fn.endswith((".c", ".h")):
                yield os.path.join(root, fn)


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2

    if argv[1] == "--dir":
        if len(argv) < 3:
            sys.stderr.write("--dir 需要目录参数\n")
            return 2
        files = list(iter_c_files(argv[2]))
    else:
        files = [a for a in argv[1:] if not a.startswith("--")]

    if not files:
        sys.stderr.write("没有可检查的文件\n")
        return 2

    print("=== C 注释提前终结检查（%d 个文件）===" % len(files))
    bad = 0
    for f in files:
        bad += check_file(f)
    if bad:
        print("❌ %d 个文件有问题 —— 注释里的 `*/` 会把注释就地终结，"
              "后面的内容会被当成代码" % bad)
        return 1
    print("✅ 全部通过（无 `/*/`，剥干净后无游离 `*/`）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
