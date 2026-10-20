#!/usr/bin/env python3
# EXPERIMENT (not for merging): what Asyncify instruments in the web engine.
#
#   python3 tools/ci/asyncify_report.py --wasm FILE [--advise LOG]
#
# --wasm is an engine built with --profiling-funcs (function names kept);
# --advise the build's output with ASYNCIFY_ADVISE=1. Prints the
# instrumented functions (those that read Asyncify's state global) by
# library and by family, with their bytes, the largest of them, and the
# reasons Asyncify gave.

import argparse
import collections
import re


def leb(d, i):
    r = s = 0
    while True:
        b = d[i]
        i += 1
        r |= (b & 0x7f) << s
        s += 7
        if b < 0x80:
            return r, i


def read(path):
    d = open(path, 'rb').read()
    i = 8
    imports = 0
    bodies = []
    names = {}
    globals_ = {}
    while i < len(d):
        sid = d[i]
        i += 1
        size, i = leb(d, i)
        end = i + size
        if sid == 2:
            n, j = leb(d, i)
            for _ in range(n):
                l, j = leb(d, j)
                j += l
                l, j = leb(d, j)
                j += l
                k = d[j]
                j += 1
                if k == 0:
                    _, j = leb(d, j)
                    imports += 1
                elif k == 1:
                    j += 1
                    f = d[j]
                    j += 1
                    _, j = leb(d, j)
                    if f & 1:
                        _, j = leb(d, j)
                elif k == 2:
                    f = d[j]
                    j += 1
                    _, j = leb(d, j)
                    if f & 1:
                        _, j = leb(d, j)
                elif k == 3:
                    j += 2
        elif sid == 10:
            n, j = leb(d, i)
            for _ in range(n):
                s, j = leb(d, j)
                bodies.append((j, s))
                j += s
        elif sid == 0:
            l, j = leb(d, i)
            if d[j:j + l] == b'name':
                j += l
                while j < end:
                    sub = d[j]
                    j += 1
                    ssize, j = leb(d, j)
                    send = j + ssize
                    if sub in (1, 7):
                        n, k = leb(d, j)
                        for _ in range(n):
                            idx, k = leb(d, k)
                            l2, k = leb(d, k)
                            (names if sub == 1 else globals_)[idx] = d[k:k + l2].decode('utf-8', 'replace')
                            k += l2
                    j = send
        i = end
    return d, imports, bodies, names, globals_


def library(name):
    n = name.lstrip('_')
    rules = [
        (r'^(Sk|sk|Gr|SkSL|SkRaster|SkOpts|portable|hsw|sse|neon)', 'skia'),
        (r'^hb_|^OT::|^AAT::|^CFF::|^graph::', 'harfbuzz'),
        (r'^(FT_|ft_|tt_|TT_|cff_|ps_|af_|T1_|t1_|sfnt|pfr_|pcf_|bdf_|gray_|psh_|tt_face|FTC_)', 'freetype'),
        (r'^(icu_|u_|ucnv|ubrk|uloc|ures|utext|uprv|ucol|ucase|uhash|uenum|ustr|unorm|uscript|uset|utrie|ucptrie|umutable|ubidi|ushape|uiter|udata|ulist|uvector)', 'icu'),
        (r'^sqlite3|^sqlite', 'sqlite'),
        (r'^(xml|html|xmlXPath|xslt|xmlSchema)', 'libxml2'),
        (r'^png_', 'libpng'),
        (r'^(jpeg_|jinit|jdiv|jcopy|jzero)', 'libjpeg'),
        (r'^(inflate|deflate|crc32|adler32|zcalloc|zcfree|_tr_|gz)', 'zlib'),
        (r'^pcre', 'pcre'),
        (r'^(MCScript|MCHandler|MCScriptExecute)', 'libscript'),
        (r'^(MC(Value|String|Name|Data|Array|Proper|TypeInfo|Foreign|Record|List|Number|Boolean|Error|Memory|Stream|Set|Span|Initialize|Finalize|Native|Unicode|Hash|Locale|Pickle|Big|Format|Range|Java|ObjC|Handler))', 'foundation'),
        (r'^MC|^X_|^MCS_', 'engine'),
        (r'^(std::|__cxx|__cxa|__gxx|__dynamic_cast|__libcpp|__ubsan|operator new|operator delete)', 'libc++'),
        (r'^(dl|malloc|free|realloc|calloc|memcpy|memset|memmove|str|mem|printf|vfprintf|fmt_|__)', 'libc'),
    ]
    for pattern, lib in rules:
        if re.match(pattern, n):
            return lib
    return 'other'


def family(name):
    n = name.lstrip('_')
    m = re.match(r'([A-Za-z0-9_]+?)(::|\(|$)', n)
    head = m.group(1) if m else n[:24]
    if '_' in head and not head.startswith('MC'):
        head = head.split('_')[0] + '_'
    return head


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wasm', required=True)
    ap.add_argument('--advise')
    ap.add_argument('--top', type=int, default=40)
    args = ap.parse_args()

    d, imports, bodies, names, globals_ = read(args.wasm)
    state = [i for i, n in globals_.items() if 'asyncify_state' in n]
    print('functions: %d (+%d imports); names: %d; asyncify state global: %s'
          % (len(bodies), imports, len(names), state))
    if not state:
        return 1
    g = state[0]
    out = bytearray([0x23])
    v = g
    while True:
        b = v & 0x7f
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            break
    pattern = bytes(out)

    inst = []
    plain = []
    for k, (st, size) in enumerate(bodies):
        name = names.get(k + imports, '#%d' % (k + imports))
        (inst if pattern in d[st:st + size] else plain).append((size, name))
    total = sum(s for s, _ in inst) + sum(s for s, _ in plain)
    print('instrumented: %d functions, %.2f MB of %.2f MB' % (len(inst), sum(s for s, _ in inst) / 1e6, total / 1e6))

    by_lib = collections.defaultdict(lambda: [0, 0, 0, 0])
    for s, n in inst:
        e = by_lib[library(n)]
        e[0] += 1
        e[1] += s
    for s, n in plain:
        e = by_lib[library(n)]
        e[2] += 1
        e[3] += s
    print('\nBy library: instrumented (functions, KB) / plain (functions, KB)')
    for lib, e in sorted(by_lib.items(), key=lambda x: -x[1][1]):
        print('  %-12s %6d %8.0f   / %6d %8.0f' % (lib, e[0], e[1] / 1024, e[2], e[3] / 1024))

    by_fam = collections.defaultdict(lambda: [0, 0])
    for s, n in inst:
        e = by_fam[(library(n), family(n))]
        e[0] += 1
        e[1] += s
    print('\nInstrumented, by family (top %d)' % (args.top * 2))
    for (lib, fam), e in sorted(by_fam.items(), key=lambda x: -x[1][1])[:args.top * 2]:
        print('  %-11s %-40s %6d %8.0f KB' % (lib, fam[:40], e[0], e[1] / 1024))

    print('\nLargest instrumented functions')
    for s, n in sorted(inst, reverse=True)[:args.top]:
        print('  %7.1f KB  %s' % (s / 1024, n[:150]))

    if args.advise:
        reasons = collections.Counter()
        initial = collections.Counter()
        for line in open(args.advise, encoding='utf-8', errors='replace'):
            m = re.search(r'\[asyncify\] (.*) can change the state due to (.*)$', line.strip())
            if not m:
                continue
            fn, why = m.group(1), m.group(2)
            if why == 'initial scan':
                initial[library(fn)] += 1
            else:
                reasons['calls %s' % library(why)] += 1
        print('\nAsyncify advice: initial scan (direct import call or indirect call), by library')
        for k, v in initial.most_common():
            print('  %-12s %6d' % (k, v))
        print('Asyncify advice: propagated, by the library of the callee')
        for k, v in reasons.most_common(20):
            print('  %-24s %6d' % (k, v))
        sample = [l.rstrip() for l in open(args.advise, encoding='utf-8', errors='replace')
                  if '[asyncify]' in l and 'initial scan' in l][:60]
        print('\nFirst initial-scan lines')
        for l in sample:
            print('  ' + l[:200])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
