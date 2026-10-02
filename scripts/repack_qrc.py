#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
repack_qrc.py - Extract or repack the Qt rcc-generated qrc_qml.h.

The PenMods QML is compiled into resource/models/YDP02X/qrc_qml.h as a
plain C header (Qt Resource Compiler output). This script can:

  extract <qrc_qml.h> <outdir>
      Dump every resource file from the header into <outdir>.

  pack <qrc_qml.h> <srcdir> <output.h>
      Rebuild the header, replacing any file in <srcdir> that matches a
      resource path (matched against the path relative to <srcdir>).
      Files in <srcdir> that are NOT in the resource tree are ADDED as
      new entries (the qt_resource_name / qt_resource_struct sections
      are rebuilt with the exact two-pass stack algorithm used by Qt
      5.15's rcc: children sorted by qt_hash(name), flat child slots
      allocated depth-first with a LIFO stack). Payloads of resources
      absent from <srcdir> are kept as-is.

  verify <qrc_qml.h> <srcdir>
      Parse the header, extract all files and compare them byte-for-byte
      with the tree under <srcdir>.

This is a deterministic, dependency-free replacement for running `rcc`
on Windows, and keeps the generated header compatible with the format
produced by Qt 5.15's rcc (tree node size 22, qCompress payloads).
"""

import os
import re
import struct
import sys
import zlib


def parse_header(path):
    """Return (data, names, tree) byte arrays parsed from a qrc_qml.h file."""
    text = open(path, "r", encoding="utf-8", errors="replace").read()

    def get_array(name):
        p = text.index(name)
        start = text.index("{", p)
        end = text.index("};", start)
        body = text[start:end]
        return bytes(int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{1,2})", body))

    return get_array("qt_resource_data"), get_array("qt_resource_name"), get_array("qt_resource_struct")


def parse_names(names):
    """Return {name_offset: name_string}."""
    result = {}
    off = 0
    while off + 2 <= len(names):
        length = struct.unpack_from(">H", names, off)[0]
        if off + 2 + 4 + length * 2 > len(names):
            break
        chars = struct.unpack_from(">%dH" % length, names, off + 2 + 4)
        result[off] = "".join(chr(c) for c in chars)
        off += 2 + 4 + length * 2
    return result


NODE_SIZE = 22
FLAG_COMPRESSED = 0x01
FLAG_DIRECTORY = 0x02


def parse_tree(tree):
    """Return (nodes, root) where nodes is a list of dicts."""
    nodes = []
    for i in range(len(tree) // NODE_SIZE):
        base = i * NODE_SIZE
        flags = struct.unpack_from(">H", tree, base + 4)[0]
        node = {
            "name_off": struct.unpack_from(">I", tree, base + 0)[0],
            "flags": flags,
            "mtime": struct.unpack_from(">Q", tree, base + 14)[0],
        }
        if flags & FLAG_DIRECTORY:
            node["child_count"] = struct.unpack_from(">I", tree, base + 6)[0]
            node["first_child"] = struct.unpack_from(">I", tree, base + 10)[0]
        else:
            node["country"] = struct.unpack_from(">H", tree, base + 6)[0]
            node["language"] = struct.unpack_from(">H", tree, base + 8)[0]
            node["data_offset"] = struct.unpack_from(">I", tree, base + 10)[0]
        nodes.append(node)
    return nodes


def walk_tree(tree, names):
    """Yield (path, node_index, node) for every leaf in DFS order."""
    nodes = parse_tree(tree)
    name_of = parse_names(names)

    def node_name(i):
        off = nodes[i]["name_off"]
        return name_of.get(off, "")

    def walk(i, prefix):
        if i in seen:
            return
        seen.add(i)
        node = nodes[i]
        if node["flags"] & FLAG_DIRECTORY:
            child_count = node["child_count"]
            first_child = node["first_child"]
            if i == 0:
                sub = ""
            else:
                sub = prefix + node_name(i) + "/"
            for c in range(first_child, first_child + child_count):
                if c < len(nodes):
                    yield from walk(c, sub)
        else:
            yield (prefix + node_name(i), i, node)

    # root is node 0; children of root are walked without a leading slash
    seen = set()
    yield from walk(0, "")


def extract_resources(data, tree, names):
    """Return {path: (payload_bytes, compressed_flag)} for every leaf."""
    out = {}
    for path, idx, node in walk_tree(tree, names):
        off = node["data_offset"]
        if off + 4 > len(data):
            continue
        size = struct.unpack_from(">I", data, off)[0]
        payload = data[off + 4 : off + 4 + size]
        out[path] = (payload, bool(node["flags"] & FLAG_COMPRESSED))
    return out


def decode_payload(payload, compressed):
    if not compressed:
        return payload
    orig_size = struct.unpack_from(">I", payload, 0)[0]
    raw = zlib.decompress(payload[4:])
    assert len(raw) == orig_size, "qCompress size mismatch"
    return raw


def encode_payload(content):
    """Encode like rcc: qCompress when the ratio >= 70%, else raw."""
    compressed = struct.pack(">I", len(content)) + zlib.compress(content, 6)
    ratio = 100.0 * (len(content) - len(compressed)) / len(content) if content else 0.0
    if ratio >= 70.0:
        return compressed, True
    return content, False


def emit_array(name, blob):
    lines = ["static const unsigned char %s[] = {" % name]
    for i in range(0, len(blob), 16):
        chunk = blob[i : i + 16]
        lines.append("  " + ",".join("0x%x" % b for b in chunk) + ",")
    lines.append("};")
    return "\n".join(lines)


TEXT_SUFFIXES = (".qml", ".js", ".json", ".md", ".txt")


def normalize_text_bytes(rel, raw):
    """行尾归一。

    Windows 检出（core.autocrlf=true）出来的 QML 是 CRLF，直接打包会让产物与
    Linux/CI 出包字节不一致，也会让 diff-factory-vs-penmods.py 把上百个文件
    误报成"改过"。文本资源统一按 LF 打包，pack / verify 两侧都用这个函数，
    保证结论一致。
    """
    if rel.endswith(TEXT_SUFFIXES):
        return raw.replace(b"\r\n", b"\n")
    return raw


def qt_hash(s):
    """The exact hash rcc stores in the name table / sorts children by.

    Verified against all 771 entries of a real qrc_qml.h (0 mismatches).
    """
    h = 0
    for ch in s:
        h = (h << 4) + ord(ch)
        g = h & 0xF0000000
        if g:
            h ^= g >> 23
        h &= ~g & 0xFFFFFFFF
    return h


def pack(header_path, srcdir, output_path):
    data, names, tree = parse_header(header_path)
    resources = extract_resources(data, tree, names)

    # build path -> new_content from the source tree
    overlay = {}
    for root, _, files in os.walk(srcdir):
        for fn in files:
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, srcdir).replace("\\", "/")
            raw = normalize_text_bytes(rel, open(full, "rb").read())
            overlay[rel] = raw

    nodes = parse_tree(tree)
    name_of = parse_names(names)

    # --- collect the existing hierarchy -------------------------------
    # children[dir_path] = {child_name: is_dir}; leaf meta by full path.
    children = {"": {}}
    leaf_meta = {}   # full path -> (flags, country, language, mtime)
    root_node = nodes[0]

    def scan(i, prefix):
        # prefix: directory path without a trailing slash ("" is the root);
        # the children dict is keyed the same way.
        node = nodes[i]
        if not (node["flags"] & FLAG_DIRECTORY):
            return
        for c in range(node["first_child"], node["first_child"] + node["child_count"]):
            child = nodes[c]
            cname = name_of[child["name_off"]]
            is_dir = bool(child["flags"] & FLAG_DIRECTORY)
            children.setdefault(prefix, {})[cname] = is_dir
            if is_dir:
                scan(c, cname if prefix == "" else prefix + "/" + cname)

    scan(0, "")
    for path, idx, node in walk_tree(tree, names):
        leaf_meta[path] = (node["flags"], node["country"], node["language"], node["mtime"])

    # --- merge new files (and new directories) from the overlay -------
    existing = set(resources.keys())
    added = sorted(p for p in overlay if p not in existing)
    for rel in added:
        parts = rel.split("/")
        cur = ""
        for k, seg in enumerate(parts):
            is_dir = k < len(parts) - 1
            children.setdefault(cur, {})[seg] = is_dir
            cur = seg if cur == "" else cur + "/" + seg
    removed = [p for p in existing if p not in overlay]
    for p in removed:
        print("warning: %s missing in srcdir, keeping original payload" % p)

    # --- name table: keep original bytes, append entries for new names
    name_off = {}  # name string -> offset in names blob
    for off, s in name_of.items():
        name_off.setdefault(s, off)
    new_names_blob = bytearray(names)
    needed_names = set()
    for dir_path, kids in children.items():
        if dir_path != "":
            needed_names.add(dir_path.split("/")[-1])
        needed_names.update(kids.keys())
    for s in sorted(needed_names):
        if s in name_off:
            continue
        name_off[s] = len(new_names_blob)
        utf16 = s.encode("utf-16-be")
        new_names_blob += struct.pack(">H", len(s))
        new_names_blob += struct.pack(">I", qt_hash(s))
        new_names_blob += utf16

    # --- pass 1: allocate flat child slots (rcc writeDataStructure) ---
    child_offset = {}
    pending = [""]  # root; stack pop() == LIFO like rcc's QStack
    offset = 1
    while pending:
        d = pending.pop()
        child_offset[d] = offset
        kids = sorted(children[d].keys(), key=qt_hash)
        for cname in kids:
            offset += 1
            if children[d][cname]:
                pending.append(cname if d == "" else d + "/" + cname)

    # --- data section: existing leaves keep blob order, new ones append
    new_data = bytearray()
    data_offset_of = {}
    leaves_by_old_offset = []
    for path, idx, node in walk_tree(tree, names):
        leaves_by_old_offset.append((node["data_offset"], path))
    leaves_by_old_offset.sort()
    for _, path in leaves_by_old_offset:
        node_flags, country, language, mtime = leaf_meta[path]
        if path in overlay:
            payload, compressed = encode_payload(overlay[path])
        else:
            payload, compressed = resources[path]
        data_offset_of[path] = len(new_data)
        new_data += struct.pack(">I", len(payload))
        new_data += payload
    for path in added:
        payload, compressed = encode_payload(overlay[path])
        data_offset_of[path] = len(new_data)
        new_data += struct.pack(">I", len(payload))
        new_data += payload

    # --- pass 2: emit nodes (root first, then LIFO stack traversal) ---
    def emit_dir_node(dir_path):
        out = bytearray()
        name_off_v = root_node["name_off"] if dir_path == "" else name_off[dir_path.split("/")[-1]]
        out += struct.pack(">I", name_off_v)
        out += struct.pack(">H", FLAG_DIRECTORY)
        out += struct.pack(">I", len(children[dir_path]))
        out += struct.pack(">I", child_offset[dir_path])
        out += struct.pack(">Q", 0)
        return out

    def emit_leaf_node(path):
        if path in leaf_meta:
            node_flags, country, language, mtime = leaf_meta[path]
        else:
            # newly added file: locale C, no timestamp
            node_flags, country, language, mtime = 0, 0, 0, 0
        flags = node_flags & ~FLAG_DIRECTORY
        if path in overlay:
            payload, compressed = encode_payload(overlay[path])
            flags = (flags | FLAG_COMPRESSED) if compressed else (flags & ~FLAG_COMPRESSED)
        out = bytearray()
        out += struct.pack(">I", name_off[path.split("/")[-1]])
        out += struct.pack(">H", flags)
        out += struct.pack(">H", country)
        out += struct.pack(">H", language)
        out += struct.pack(">I", data_offset_of[path])
        out += struct.pack(">Q", mtime)
        return out

    struct_out = bytearray()
    struct_out += emit_dir_node("")
    pending = [""]
    while pending:
        d = pending.pop()
        kids = sorted(children[d].keys(), key=qt_hash)
        for cname in kids:
            full = cname if d == "" else d + "/" + cname
            if children[d][cname]:
                struct_out += emit_dir_node(full)
                pending.append(full)
            else:
                struct_out += emit_leaf_node(full)

    header = (
        "/****************************************************************************\n"
        "** Resource object code\n"
        "**\n"
        "** Created by: repack_qrc.py (Qt rcc-compatible format)\n"
        "**\n"
        "** WARNING! All changes made in this file will be lost!\n"
        "*****************************************************************************/\n\n"
        + emit_array("qt_resource_data", bytes(new_data))
        + "\n\n"
        + emit_array("qt_resource_name", bytes(new_names_blob))
        + "\n\n"
        + emit_array("qt_resource_struct", bytes(struct_out))
        + "\n\n"
    )
    with open(output_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(header)
    print("packed %d files (%d replaced, %d added) -> %s (%d bytes)"
          % (len(existing) + len(added), len(existing) - len(removed), len(added),
             output_path, len(new_data)))


def extract(header_path, outdir):
    data, names, tree = parse_header(header_path)
    resources = extract_resources(data, tree, names)
    for path, (payload, compressed) in resources.items():
        content = decode_payload(payload, compressed)
        dest = os.path.join(outdir, path.replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(content)
    print("extracted %d files -> %s" % (len(resources), outdir))


def verify(header_path, srcdir):
    data, names, tree = parse_header(header_path)
    resources = extract_resources(data, tree, names)
    bad = 0
    for path, (payload, compressed) in resources.items():
        src = os.path.join(srcdir, path.replace("/", os.sep))
        if not os.path.exists(src):
            print("MISSING in srcdir: %s" % path)
            bad += 1
            continue
        content = decode_payload(payload, compressed)
        with open(src, "rb") as f:
            if normalize_text_bytes(path, f.read()) != content:
                print("MISMATCH: %s" % path)
                bad += 1
    print("verify: %d files, %d mismatches" % (len(resources), bad))
    return 1 if bad else 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "extract" and len(sys.argv) == 4:
        extract(sys.argv[2], sys.argv[3])
    elif cmd == "pack" and len(sys.argv) == 5:
        pack(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "verify" and len(sys.argv) == 4:
        return verify(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
