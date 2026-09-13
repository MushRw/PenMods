#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_rime_ice_pkg.py —— 把雾凇拼音（rime-ice）加工成词典笔可用的数据包。

为什么要裁剪，见 resource/rime/README.md：笔上的 librime 没编 Lua、也没有 OpenCC
数据，内存只有 ~250MB 可用，原版词库直接编译会 OOM。

本脚本只做四件事（不改上游仓库，输出到独立目录）：

  1. cn_dicts/base.dict.yaml 按词频权重截取（--weight-min，默认 10000）
  2. rime_ice.schema.yaml 的 engine 只保留不依赖 lua / opencc / 拆字的组件
  3. default.yaml 的 schema_list 只留 rime_ice
  4. rime_ice.dict.yaml 只 import 实际打包的词库

用法：
    python scripts/make_rime_ice_pkg.py \
        --src third-party/rime-ice-main \
        --zip resource/rime/rime.zip
"""

import argparse
import os
import shutil
import sys
import zipfile

# 原样带上的文件（路径相对 rime-ice 仓库根）
KEEP_FILES = [
    "cn_dicts/8105.dict.yaml",
    "cn_dicts/others.dict.yaml",
    "symbols_v.yaml",
    "custom_phrase.txt",
    "melt_eng.dict.yaml",
    "en_dicts/en.dict.yaml",
    "en_dicts/en_ext.dict.yaml",
    "en_dicts/cn_en.txt",
]

NEW_IMPORTS = (
    "import_tables:\n"
    "  - cn_dicts/8105     # 字表（常用汉字单字）\n"
    "  - cn_dicts/base     # 基础词库（按词频截取）\n"
    "  - cn_dicts/others   # 杂项\n"
)

TRIMMED_SCHEMA = """# 输入引擎
# 注意：本包面向词典笔，librime 未编 Lua、也没有 OpenCC 数据，
# 因此去掉了全部 lua_* / simplifier(emoji、简繁) / 拆字(radical) 组件。
engine:
  processors:
    - ascii_composer
    - recognizer
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
  translators:
    - punct_translator
    - script_translator
    - table_translator@custom_phrase     # 自定义短语 custom_phrase.txt
    - table_translator@melt_eng          # 英文输入
    - table_translator@cn_en             # 中英混合词汇
  filters:
    - uniquifier                         # 去重
"""

OLD_IMPORTS = (
    "import_tables:\n"
    "  - cn_dicts/8105     # 字表\n"
    "  # - cn_dicts/41448  # 大字表（按需启用）（启用时和 8105 同时启用并放在 8105 下面）\n"
    "  - cn_dicts/base     # 基础词库\n"
    "  - cn_dicts/ext      # 扩展词库\n"
    "  - cn_dicts/tencent  # 腾讯词向量（大词库，部署时间较长）\n"
    "  - cn_dicts/others   # 一些杂项\n"
)


def read(root, rel):
    with open(os.path.join(root, rel.replace("/", os.sep)), encoding="utf-8") as f:
        return f.read()


def write(out, rel, text):
    path = os.path.join(out, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def cut_block(text, key):
    """把某个顶层键的整段（到下一个空行为止）换掉前返回 (前, 后)。"""
    start = text.index(key)
    end = text.index("\n\n", start)
    return start, end


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="rime-ice 仓库解包目录")
    ap.add_argument("--out", default="", help="staging 目录（默认 <zip 同级的 rime-pkg）")
    ap.add_argument("--zip", default="resource/rime/rime.zip", help="输出的数据包路径")
    ap.add_argument("--weight-min", type=int, default=10000, help="base 词库保留的最低词频权重")
    ap.add_argument("--page-size", type=int, default=20, help="每页候选词数量（键盘 UI 横向滑动查看）")
    args = ap.parse_args()

    src = os.path.abspath(args.src)
    if not os.path.isdir(src):
        sys.exit("找不到 rime-ice 源码目录: %s" % src)
    out = os.path.abspath(args.out or os.path.join(os.path.dirname(os.path.abspath(args.zip)), "rime-pkg"))

    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out, exist_ok=True)

    for rel in KEEP_FILES:
        dst = os.path.join(out, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(src, rel.replace("/", os.sep)), dst)

    # 1) base.dict.yaml：保留表头（到 '...' 为止），按权重截取
    kept = 0
    buf = []
    in_head = True
    with open(os.path.join(src, "cn_dicts", "base.dict.yaml"), encoding="utf-8") as f:
        for line in f:
            if in_head:
                buf.append(line)
                if line.startswith("..."):
                    in_head = False
                continue
            if not line.strip() or line.startswith("#"):
                buf.append(line)
                continue
            parts = line.rstrip("\n").split("\t")
            try:
                weight = int(parts[2]) if len(parts) >= 3 else 0
            except ValueError:
                weight = 0
            if weight >= args.weight_min:
                buf.append(line)
                kept += 1
    write(out, "cn_dicts/base.dict.yaml", "".join(buf))
    print("base.dict.yaml: 保留权重 >= %d 的 %d 条" % (args.weight_min, kept))

    # 2) rime_ice.dict.yaml：只 import 实际打包的词库
    text = read(src, "rime_ice.dict.yaml")
    if OLD_IMPORTS not in text:
        sys.exit("rime_ice.dict.yaml 的 import_tables 结构与预期不符，请检查上游是否改版")
    write(out, "rime_ice.dict.yaml", text.replace(OLD_IMPORTS, NEW_IMPORTS))

    # 3) default.yaml：方案列表只留 rime_ice；候选词数量交给 --page-size
    text = read(src, "default.yaml")
    start, end = cut_block(text, "schema_list:")
    text = text[:start] + "schema_list:\n  - schema: rime_ice               # 雾凇拼音（全拼）\n" + text[end:]
    if "page_size: 5" in text:
        text = text.replace("page_size: 5", "page_size: %d" % args.page_size)
    else:
        sys.exit("default.yaml 里没找到 'page_size: 5'，请检查上游是否改版")
    write(out, "default.yaml", text)

    # 4) rime_ice.schema.yaml：裁剪 engine
    text = read(src, "rime_ice.schema.yaml")
    start, end = cut_block(text, "engine:")
    text = text[:start] + TRIMMED_SCHEMA + text[end:]
    write(out, "rime_ice.schema.yaml", text)

    # 5) 打包
    zip_path = os.path.abspath(args.zip)
    os.makedirs(os.path.dirname(zip_path), exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(out):
            for fn in sorted(files):
                full = os.path.join(root, fn)
                z.write(full, os.path.relpath(full, out).replace("\\", "/"))

    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(out) for f in fs)
    print("staging: %s" % out)
    print("zip: %s (%.2f MB, 原始 %.2f MB)" % (zip_path, os.path.getsize(zip_path) / 1048576.0, total / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
