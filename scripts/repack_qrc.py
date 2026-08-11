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
      The resource tree structure and names are preserved; only the
      replaced payloads and the affected data offsets change.

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


def pack(header_path, srcdir, output_path):
    data, names, tree = parse_header(header_path)
    resources = extract_resources(data, tree, names)

    # build path -> (new_content, original_compressed_flag)
    overlay = {}
    for root, _, files in os.walk(srcdir):
        for fn in files:
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, srcdir).replace("\\", "/")
            overlay[rel] = open(full, "rb").read()

    nodes = parse_tree(tree)
    # order leaves by their current data offset to preserve blob order
    leaves = []
    for path, idx, node in walk_tree(tree, names):
        leaves.append((path, idx, node))
    leaves.sort(key=lambda item: item[2]["data_offset"])

    new_data = bytearray()
    for path, idx, node in leaves:
        is_dir = bool(node["flags"] & FLAG_DIRECTORY)
        if path in overlay:
            payload, compressed = encode_payload(overlay[path])
            nodes[idx]["data_offset"] = len(new_data)
            if compressed:
                nodes[idx]["flags"] |= FLAG_COMPRESSED
            else:
                nodes[idx]["flags"] &= ~FLAG_COMPRESSED
        else:
            payload, compressed = resources[path]
            nodes[idx]["data_offset"] = len(new_data)
        new_data += struct.pack(">I", len(payload))
        new_data += payload

    # re-emit the tree with updated data offsets
    new_tree = bytearray()
    for node in nodes:
        new_tree += struct.pack(">I", node["name_off"])
        new_tree += struct.pack(">H", node["flags"])
        if node["flags"] & FLAG_DIRECTORY:
            new_tree += struct.pack(">I", node["child_count"])
            new_tree += struct.pack(">I", node["first_child"])
        else:
            new_tree += struct.pack(">H", node["country"])
            new_tree += struct.pack(">H", node["language"])
            new_tree += struct.pack(">I", node["data_offset"])
        new_tree += struct.pack(">Q", node["mtime"])

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
        + emit_array("qt_resource_name", names)
        + "\n\n"
        + emit_array("qt_resource_struct", bytes(new_tree))
        + "\n\n"
    )
    with open(output_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(header)
    print("packed %d files -> %s (%d bytes)" % (len(leaves), output_path, len(new_data)))


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
            if f.read() != content:
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
