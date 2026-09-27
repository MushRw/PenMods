#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
layout-patch.py —— 把 .ko 的 .gnu.linkonce.this_module 重定位搬到设备内核的真实字段偏移上

背景（为什么需要这一步）
------------------------
内核加载模块时，`struct module` 这块内存是**内核按它自己的字段偏移**读写的：

  * `do_init_module()`      读 `offsetof(struct module, init)`  并调用它
  * `sys_delete_module()`   读 `offsetof(struct module, exit)` / `refcnt`
  * `move_module()`         写 `module_init` / `module_core` / `*_size` ...

而 `.gnu.linkonce.this_module` 的内容是**我们的头文件**编出来的：其
`.init = init_module` / `.exit = cleanup_module` 两条重定位的 `r_offset`
就是**我们的** `offsetof`。两边不一致 ⇒ 内核在 `mod->init` 位置读到 0：

  * `insmod` 返回 0（`if (mod->init != NULL)` 判空跳过），但 dmesg 里没有我们的日志
  * `rmmod` 读错位置的 `refcnt` ⇒ 报 EAGAIN "Resource temporarily unavailable"
  * `/proc/modules` 的 refcount 打出垃圾值

实测设备内核（原厂 hci_uart.ko / 8723ds.ko 互相印证）：
    size=704   offsetof(name)=24   offsetof(init)=368   offsetof(exit)=680
而上游 arm64 4.4.159 defconfig 编出来的是 init=344 / exit=672。
`struct module` 里那些 `#ifdef` 组合（mutex 尺寸、SMP/TREE_LOOKUP/…）牵一发动全身，
与其猜厂商的 .config，不如**按实测偏移直接改这两条重定位** —— 只影响
`struct module` 这一个 ABI，不牵动任何其它结构体。

为什么这样是安全的
------------------
原厂 .ko 的这个节，**除了偏移 24 处的模块名以外全是 0**，也只有 2 条重定位。
也就是说内核看到的这块内存，正常情况下就是「一堆 0 + 名字 + 两个函数指针」。
我们把同样的东西放到内核期望的位置，语义上与原厂模块**逐字节等价**。
其余字段（mkobj / param_lock / syms / percpu / mtn_core …）内核自己会初始化，
它写在它自己的偏移上，只要节**足够大**就不会越界 —— 所以本工具要求
`sh_size >= 目标 size`。

用法
----
    # 应用（就地改写，节大小不变，纯 r_offset 搬移 ⇒ 不会挪动任何其它节）
    python layout-patch.py utest.ko usb_uac2.ko

    # 只校验不改（CI 门禁用）
    python layout-patch.py --check utest.ko

    # 手上还有原厂 .ko 时，顺手复核契约文件没被改坏
    python layout-patch.py utest.ko --ref /path/to/hci_uart.ko

不传 --ref 时使用仓库内的契约文件 device-abi.json（推荐；CI 就是这么跑的）。
--ref <原厂.ko> 会拿真模块现场反推，并**交叉校验**契约文件没被改坏。
"""
import importlib.util
import os
import re
import struct
import sys

R_AARCH64_ABS64 = 257

# 基准值（与 tools/uac2-kmod/ref-abi.txt 必须一致 —— 两边任一漂移都由 CI 硬失败拦下）
DEF_SIZE = 704
DEF_NAME_OFF = 24
DEF_INIT = 368
DEF_EXIT = 680

HERE = os.path.dirname(os.path.abspath(__file__))


def _load_layout():
    """复用 kmod-layout.py 的 ELF 解析，避免两份实现漂移。"""
    path = os.path.join(HERE, 'kmod-layout.py')
    spec = importlib.util.spec_from_file_location('kmod_layout', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


KL = _load_layout()

SELF = '.gnu.linkonce.this_module'
RELA = '.rela.gnu.linkonce.this_module'

# 判据来源：仓库内的契约文件 device-abi.json（由原厂 hci_uart.ko / 8723ds.ko 的
# 重定位表反推，md5 与复现命令都写在里面）。**不在代码里硬编码**，避免两处漂移。
# ⚠️ 原厂 .ko 不在本仓库（hci_uart.ko + 8723ds.ko 共 ~1.6MB），所以 CI 的
#    checkout 里根本看不到它们 —— 这就是为什么判据必须落成仓库内的契约文件。
ABI_TXT = os.path.join(HERE, 'ref-abi.txt')


def load_contract(path=None):
    """读设备 ABI 基准 → (size, name_off, init, exit, 描述)

    基准文件是 tools/uac2-kmod/ref-abi.txt（仓库内契约；里面写了它是怎么从原厂
    hci_uart.ko / 8723ds.ko 的重定位表读出来的，以及 md5 与复核命令）。
    读到的值必须与内置 DEF_* 一致，否则**直接报错** —— 不允许两个真相源静默漂移。
    """
    p = path or ABI_TXT
    if not os.path.exists(p):
        print('⚠️  找不到基准文件 %s，回退到内置值 size=%d name=%d init=%d exit=%d'
              % (p, DEF_SIZE, DEF_NAME_OFF, DEF_INIT, DEF_EXIT))
        return (DEF_SIZE, DEF_NAME_OFF, DEF_INIT, DEF_EXIT,
                '内置基准(基准文件缺失)')

    txt = open(p, encoding='utf-8').read()
    got = {k: int(v) for k, v in re.findall(r'^(size|align|name|init|exit)\s*=\s*(\d+)',
                                            txt, re.M)}
    builtin = dict(size=DEF_SIZE, name=DEF_NAME_OFF, init=DEF_INIT, exit=DEF_EXIT)
    bad = [k for k, v in builtin.items() if got.get(k) != v]
    if bad:
        raise SystemExit('✗ %s 与 layout-patch.py 内置基准不一致：%s —— 先查清哪边对，'
                         '不要静默用错偏移' % (p, ', '.join(bad)))
    if got.get('align') not in (None, 64):
        raise SystemExit('✗ %s 里 align=%s，应为 64（L1_CACHE_BYTES=64）' % (p, got.get('align')))
    return (DEF_SIZE, DEF_NAME_OFF, DEF_INIT, DEF_EXIT,
            'ref-abi.txt（与内置基准对账一致）')


def _find(shs, name):
    for sh in shs:
        if sh['sname'] == name:
            return sh
    return None


def probe(path):
    """读取一个 .ko 的 this_module 指纹，返回 dict。"""
    d, shs = KL.load(path)
    # KL.load 返回只读 bytes；本工具要就地改重定位，统一转成 bytearray
    d = bytearray(d)
    syms = KL.symbols(d, shs)
    tm = _find(shs, SELF)
    rela = _find(shs, RELA)
    out = dict(path=path, size=None, name_off=None, init=None, exit=None,
               align=None, relocs=[], body=None, tm=None, rela=None,
               d=d, shs=shs, syms=syms)
    if tm is None:
        return out
    out['size'] = tm['size']
    out['align'] = tm['align']
    out['tm'] = tm
    out['body'] = KL.section_bytes(d, tm)
    body = out['body']

    # 模块名：节里唯一的一段非零字节
    i = 0
    while i < len(body) and body[i] == 0:
        i += 1
    if i < len(body):
        j = body.find(b'\0', i)
        if j > i:
            out['name_off'] = i
            out['name'] = body[i:j].decode('utf-8', 'replace')

    if rela is None:
        return out
    out['rela'] = rela
    for r_offset, sidx, addend in KL.relocs(d, shs, rela):
        sname = syms[sidx][0] if sidx < len(syms) else '?'
        out['relocs'].append((r_offset, sidx, addend, sname))
    for r_offset, _sidx, _addend, sname in out['relocs']:
        if sname == 'init_module':
            out['init'] = r_offset
        elif sname == 'cleanup_module':
            out['exit'] = r_offset
    return out


def target_from_ref(ref, contract):
    """从真模块现场反推布局，并要求它与契约文件逐项一致（不一致就报错）。

    这是"契约没被改坏"的证明：只要手上还有原厂 .ko，就能一条命令复核。
    """
    r = probe(ref)
    if r['size'] is None or r['init'] is None or r['exit'] is None:
        raise SystemExit('✗ --ref %s 读不到完整的 this_module 指纹' % ref)
    got = (r['size'], r['name_off'], r['init'], r['exit'])
    if got != contract:
        raise SystemExit(
            '✗ --ref %s 实测 %s，与契约文件 %s 不一致 —— '
            '契约被改坏了（或设备换了内核），先查清再改' % (ref, got, contract))
    print('  ✅ --ref %s 现场实测与契约文件逐项一致 %s' % (ref, got))
    return r


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)

    check_only = '--check' in args
    args = [a for a in args if a != '--check']

    ref = None
    if '--ref' in args:
        i = args.index('--ref')
        ref = args[i + 1]
        del args[i:i + 2]

    abi = None
    if '--abi' in args:
        i = args.index('--abi')
        abi = args[i + 1]
        del args[i:i + 2]

    if not args:
        raise SystemExit(__doc__)

    t_size, t_name_off, t_init, t_exit, src = load_contract(abi)
    print('目标布局（来自 %s）: size=%d name@%d init@%d exit@%d'
          % (src, t_size, t_name_off, t_init, t_exit))
    if ref:
        target_from_ref(ref, (t_size, t_name_off, t_init, t_exit))

    rc = 0
    for path in args:
        print('-' * 78)
        print('PATCH: %s' % path)
        info = probe(path)
        if info['size'] is None:
            print('  ✗ 没有 %s 节' % SELF)
            rc = 1
            continue

        size = info['size']
        body = info['body']
        name_off = info['name_off']

        ok = True
        # ---- 校验 1：节要够大（内核会按自己的偏移往里写，越界就是踩内存） ----
        if size < t_size:
            print('  ✗ sh_size=%d < 目标 %d ⇒ 内核会写到本节之外' % (size, t_size))
            ok = False
        else:
            print('  ✅ sh_size=%d (>= %d)，sh_addralign=%d' % (size, t_size, info['align']))

        # ---- 校验 2：节内容除模块名外必须全 0（语义与原厂模块等价） ----
        if name_off != t_name_off:
            print('  ✗ 模块名在偏移 %s，目标要求 %d' % (name_off, t_name_off))
            ok = False
        else:
            end = body.index(b'\0', name_off)
            leak = [(k, body[k]) for k in range(len(body)) if body[k] and not (name_off <= k <= end)]
            if leak:
                print('  ✗ 模块名之外还有 %d 个非零字节，前几个：%s' % (
                    len(leak), ['%d:%#x' % x for x in leak[:8]]))
                ok = False
            else:
                print('  ✅ 节内容 = 模块名 %r + 全 0（与原厂模块语义一致）'
                      % body[name_off:end].decode('utf-8', 'replace'))
                if end > t_name_off + 56:
                    print('  ✗ 模块名超出 name[MODULE_NAME_LEN=56] 的范围')
                    ok = False

        # ---- 校验 3：重定位必须恰好两条，且是我们预期的符号 ----
        wanted = {'init_module': (info['init'], t_init),
                  'cleanup_module': (info['exit'], t_exit)}
        names = [r[3] for r in info['relocs']]
        if sorted(names) != sorted(wanted):
            print('  ✗ 重定位符号为 %s，期望 %s' % (names, sorted(wanted)))
            ok = False

        for k, (r_offset, _sidx, addend, sname) in enumerate(info['relocs']):
            d, shs, rela = info['d'], info['shs'], info['rela']
            _, r_info, _ = struct.unpack_from('<QQq', d, rela['off'] + k * 24)
            typ = r_info & 0xffffffff
            if typ != R_AARCH64_ABS64:
                print('  ✗ %s 的重定位类型是 %d，期望 R_AARCH64_ABS64(%d)'
                      % (sname, typ, R_AARCH64_ABS64))
                ok = False
            if addend != 0:
                print('  ✗ %s 的 addend=%d，期望 0' % (sname, addend))
                ok = False

        # ---- 应用 ----
        if ok and not check_only:
            for k, (r_offset, _sidx, _addend, sname) in enumerate(info['relocs']):
                want = wanted.get(sname)
                if want is None:
                    continue
                _, tgt = want
                if r_offset == tgt:
                    print('  · %s 已在 %d，无需移动' % (sname, r_offset))
                    continue
                off = info['rela']['off'] + k * 24
                struct.pack_into('<Q', info['d'], off, tgt)
                print('  → %s: r_offset %d → %d' % (sname, r_offset, tgt))
            with open(path, 'r+b') as fp:
                fp.seek(0)
                fp.write(info['d'])
                fp.truncate(len(info['d']))

        # ---- 复验 ----
        after = probe(path)
        fp = KL.fingerprint(path)
        print('  最终指纹: %s' % fp)
        good = (after['size'] >= t_size and after['init'] == t_init
                and after['exit'] == t_exit and after['name_off'] == t_name_off)
        if good:
            print('  ✅ PASS —— 与设备内核布局一致')
        else:
            print('  ❌ FAIL —— size=%s name@%s init=%s exit=%s，目标 size>=%d name@%d init=%d exit=%d'
                  % (after['size'], after['name_off'], after['init'], after['exit'],
                     t_size, t_name_off, t_init, t_exit))
            rc = 1

    return rc


if __name__ == '__main__':
    sys.exit(main())
