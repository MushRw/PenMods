#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kmod-layout.py —— 从 .ko 反推内核 `struct module` 的真实字段偏移（零猜测）

原理
----
内核加载模块时，`.gnu.linkonce.this_module` 这个节里的字段若指向本模块的
其他符号（`.init = init_module`、`.exit = cleanup_module`、`.modinfo_attrs = ...`、
`.syms = __ksymtab` ...），链接器就会在该字段的位置生成一条
`R_AARCH64_ABS64` 重定位。**这条重定位的 `r_offset` 就是该字段在
`struct module` 里的字节偏移**（同一节内，段基址为 0）。

设备原厂 .ko（如 /usr/lib/modules/hci_uart.ko、/system/lib/modules/8723ds.ko）
是用与设备内核完全一致的头文件编出来的，所以它们的 r_offset 就是
**设备内核的真实布局** —— 拿它和我们的产物一比，即可精确知道差在哪。

用法
----
    python kmod-layout.py <file.ko> [<file.ko> ...]
"""
import struct
import sys


def load(path):
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        raise SystemExit('%s: 不是 ELF' % path)
    if d[4] != 2 or d[5] != 1:
        raise SystemExit('%s: 只支持 ELF64-LE' % path)
    e_shoff, = struct.unpack_from('<Q', d, 0x28)
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from('<HHH', d, 0x3a)
    shs = []
    for i in range(e_shnum):
        o = e_shoff + i * e_shentsize
        (name, typ, flags, addr, off, size, link, info,
         align, entsize) = struct.unpack_from('<IIQQQQIIQQ', d, o)
        shs.append(dict(name=name, typ=typ, flags=flags, off=off, size=size,
                        link=link, info=info, align=align, entsize=entsize))
    shstr = shs[e_shstrndx]

    def nm_at(x):
        s = d[shstr['off'] + x:]
        return s[:s.index(b'\0')].decode('utf-8', 'replace')

    for s in shs:
        s['sname'] = nm_at(s['name'])
    return d, shs


def symbols(d, shs):
    """返回 symtab: [ (name, value, shndx, size) ]"""
    for sh in shs:
        if sh['typ'] == 2:  # SHT_SYMTAB
            strsh = shs[sh['link']]
            out = []
            for i in range(sh['size'] // 24):
                o = sh['off'] + i * 24
                (name, info, other, shndx, value,
                 size) = struct.unpack_from('<IBBHQQ', d, o)
                s = d[strsh['off'] + name:]
                s = s[:s.index(b'\0')].decode('utf-8', 'replace')
                out.append((s, value, shndx, size))
            return out
    return []


def relocs(d, shs, sh):
    """返回一个 .rela 节的条目: [ (r_offset, sym_index, r_addend) ]"""
    out = []
    for i in range(sh['size'] // 24):
        o = sh['off'] + i * 24
        r_offset, r_info, r_addend = struct.unpack_from('<QQq', d, o)
        out.append((r_offset, r_info >> 32, r_addend))
    return out


def section_bytes(d, sh):
    return d[sh['off']:sh['off'] + sh['size']]


def report(path):
    d, shs = load(path)
    syms = symbols(d, shs)
    tm = None
    rela = None
    for sh in shs:
        if sh['sname'] == '.gnu.linkonce.this_module':
            tm = sh
        if sh['sname'] == '.rela.gnu.linkonce.this_module':
            rela = sh

    print('=' * 78)
    print('FILE: %s' % path)
    print('=' * 78)
    if tm is None:
        print('  ✗ 没有 .gnu.linkonce.this_module 节')
        return
    print('  .gnu.linkonce.this_module  sh_size = 0x%x = %d' % (tm['size'], tm['size']))

    body = section_bytes(d, tm)
    # 找模块名（name[MODULE_NAME_LEN] 里的可打印字符串）
    for i in range(0, min(len(body), 256)):
        j = body.find(b'\0', i)
        if j < 0:
            break
        seg = body[i:j]
        if 2 <= len(seg) <= 56 and all(32 <= c < 127 for c in seg):
            if any(ch.isalpha() for ch in seg.decode()):
                print('  name 字符串在偏移 %-4d : %r' % (i, seg.decode()))
                break

    if rela is None:
        print('  ✗ 没有 .rela.gnu.linkonce.this_module —— 无法取字段偏移')
        return

    print('  --- 该节的重定位（r_offset 即字段在 struct module 中的偏移）---')
    print('  %-8s %-10s %-14s %s' % ('offset', 'dec', 'type', 'target symbol + addend'))
    rows = []
    for r_offset, sidx, addend in sorted(relocs(d, shs, rela)):
        sname = syms[sidx][0] if sidx < len(syms) else '?'
        rows.append((r_offset, sname, addend))
        print('  0x%04x   %-10d %-14s %s + %d' % (r_offset, r_offset,
                                                  'ABS64', sname, addend))
    return rows


def fingerprint(path):
    """紧凑指纹：size=704 init=368 exit=680 —— 配置矩阵就靠这三个数判对齐。

    注意 ⚠️ 只看总大小是不够的：arm64 上 struct module 结尾带
    ____cacheline_aligned(64)，总大小永远被向上取整到 64 的倍数（768 / 704），
    所以小于 64 字节的差异会被 padding 完全吃掉。init / exit 的偏移才是敏感的。
    """
    d, shs = load(path)
    syms = symbols(d, shs)
    tm = rela = None
    for sh in shs:
        if sh['sname'] == '.gnu.linkonce.this_module':
            tm = sh
        if sh['sname'] == '.rela.gnu.linkonce.this_module':
            rela = sh
    if tm is None:
        return 'NO_THIS_MODULE'
    size = tm['size']
    init = exit_ = None
    if rela is not None:
        for r_offset, sidx, _ in relocs(d, shs, rela):
            sname = syms[sidx][0] if sidx < len(syms) else ''
            if sname == 'init_module':
                init = r_offset
            elif sname == 'cleanup_module':
                exit_ = r_offset
    return 'size=%-4d init=%-4s exit=%-4s' % (
        size,
        init if init is not None else '?',
        exit_ if exit_ is not None else '?')


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    args = sys.argv[1:]
    if args[0] == '--fingerprint':
        for p in args[1:]:
            print('%s  %s' % (fingerprint(p), p))
        return
    for p in args:
        report(p)


if __name__ == '__main__':
    main()
