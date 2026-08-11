#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""package_player.py - 把播放器文件树打包为 player.zip（根目录 mpv/）。"""

import os
import sys
import zipfile


def main():
    if len(sys.argv) != 3:
        print("usage: package_player.py <mpv-dir> <output.zip>")
        return 2
    src_dir = os.path.abspath(sys.argv[1])
    out_path = sys.argv[2]
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(src_dir):
            for fn in files:
                full = os.path.join(root, fn)
                rel = os.path.join("mpv", os.path.relpath(full, src_dir)).replace(os.sep, "/")
                z.write(full, rel)
    print("player.zip -> %s" % out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
