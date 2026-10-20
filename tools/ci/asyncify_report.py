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


def skip(d, i):
    while d[i] & 0x80:
        i += 1
    return i + 1


def memarg(d, i):
    a, i = leb(d, i)
    if a & 0x40:
        i = skip(d, i)
    return skip(d, i)


NOIMM = set(range(0x45, 0xc5)) | {0x00, 0x01, 0x05, 0x0b, 0x0f, 0x1a, 0x1b, 0xd1, 0x19}


def calls(d, st, size):
    """(direct callee indices, number of indirect calls) of the body at st"""
    end = st + size
    n, i = leb(d, st)
    for _ in range(n):
        i = skip(d, i)
        i += 1
    direct = []
    indirect = 0
    while i < end:
        op = d[i]
        i += 1
        if op in NOIMM:
            continue
        if op in (0x02, 0x03, 0x04, 0x06):
            b = d[i]
            if b == 0x40 or (b >= 0x6f and b <= 0x7f):
                i += 1
            else:
                i = skip(d, i)
        elif op in (0x0c, 0x0d, 0x07, 0x08, 0x09, 0x18, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0xd2):
            i = skip(d, i)
        elif op == 0x0e:
            k, i = leb(d, i)
            for _ in range(k + 1):
                i = skip(d, i)
        elif op in (0x10, 0x12):
            f, i = leb(d, i)
            direct.append(f)
        elif op in (0x11, 0x13):
            i = skip(d, i)
            i = skip(d, i)
            indirect += 1
        elif op == 0x1c:
            k, i = leb(d, i)
            i += k
        elif 0x28 <= op <= 0x3e:
            i = memarg(d, i)
        elif op in (0x3f, 0x40):
            i += 1
        elif op == 0x41 or op == 0x42:
            i = skip(d, i)
        elif op == 0x43:
            i += 4
        elif op == 0x44:
            i += 8
        elif op == 0xd0:
            i += 1
        elif op == 0xfc:
            sub, i = leb(d, i)
            if sub <= 7:
                pass
            elif sub == 8:
                i = skip(d, i)
                i += 1
            elif sub == 9 or sub == 13 or sub in (15, 16, 17):
                i = skip(d, i)
            elif sub == 10:
                i += 2
            elif sub == 11:
                i += 1
            elif sub in (12, 14):
                i = skip(d, i)
                i = skip(d, i)
            else:
                raise ValueError('0xfc %d at %d' % (sub, i))
        elif op == 0xfd:
            sub, i = leb(d, i)
            if sub <= 11 or sub in (92, 93):
                i = memarg(d, i)
            elif sub in (12, 13):
                i += 16
            elif 21 <= sub <= 34:
                i += 1
            elif 84 <= sub <= 91:
                i = memarg(d, i)
                i += 1
        elif op == 0xfe:
            sub, i = leb(d, i)
            if sub == 3:
                i += 1
            else:
                i = memarg(d, i)
        else:
            raise ValueError('opcode 0x%02x at %d' % (op, i - 1))
    if i != end:
        raise ValueError('body overrun %d != %d' % (i, end))
    return direct, indirect


def read(path):
    d = open(path, 'rb').read()
    i = 8
    imports = 0
    import_names = []
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
                field = d[j:j + l].decode('utf-8', 'replace')
                j += l
                k = d[j]
                j += 1
                if k == 0:
                    _, j = leb(d, j)
                    imports += 1
                    import_names.append(field)
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
    read.import_names = import_names
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
    ap.add_argument('--remove', help='the ASYNCIFY_REMOVE list (JSON) to check against the names')
    ap.add_argument('--callees', action='store_true',
                    help='the calls that most instrumented code makes, and what removing each would leave')
    ap.add_argument('--what-if', nargs='*', default=[],
                    help='patterns to simulate removing as well')
    args = ap.parse_args()

    d, imports, bodies, names, globals_ = read(args.wasm)
    state = [i for i, n in globals_.items() if 'asyncify_state' in n]
    if not state:
        # The global that instrumented code compares with 1 (unwinding)
        # and 2 (rewinding) most often
        counts = collections.Counter(
            m.group(1) for m in re.finditer(rb'\x23([\x00-\x7f]|[\x80-\xff][\x00-\x7f])\x41[\x01\x02]\x46', d, re.S))
        raw = counts.most_common(1)[0][0]
        g = raw[0] if len(raw) == 1 else (raw[0] & 0x7f) | (raw[1] << 7)
        state = [g]
    print('functions: %d (+%d imports); names: %d; asyncify state global: %s'
          % (len(bodies), imports, len(names), state))
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
    for floor in (4000, 10000, 20000):
        bi = [s for s, _ in inst if s > floor]
        bp = [s for s, _ in plain if s > floor]
        print('over %d bytes: %d instrumented (%.2f MB), %d plain (%.2f MB)'
              % (floor, len(bi), sum(bi) / 1e6, len(bp), sum(bp) / 1e6))

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

    if args.remove:
        import json
        state_of = {}
        for s_, n in inst:
            state_of[n] = 'instrumented'
        for s_, n in plain:
            state_of.setdefault(n, 'plain')
        print('\nRemove list: what each pattern matches (functions, still instrumented, examples)')
        for pat in json.load(open(args.remove)):
            rx = re.compile('^' + '.*'.join(re.escape(x) for x in pat.split('*')) + '$')
            hits = [n for n in state_of if rx.match(n)]
            left = [n for n in hits if state_of[n] == 'instrumented']
            print('  %-28s %5d %4d  %s' % (pat, len(hits), len(left), ' | '.join(h[:50] for h in hits[:4])))
            for n in left[:3]:
                print('      still instrumented: %s' % n[:120])

    if args.callees or args.what_if:
        callees_report(d, imports, bodies, names, inst, args)

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


ASYNC_IMPORTS = ['fd_sync', 'invoke_*', 'emscripten_sleep', 'MCEmscriptenAsyncYield', '__asyncjs__*',
                 'emscripten_wget*', 'emscripten_idb_*', 'emscripten_scan_*', 'emscripten_promise_await']


def matcher(patterns):
    rxs = [re.compile('^' + '.*'.join(re.escape(x) for x in p.split('*')) + '$') for p in patterns]
    return lambda n: any(r.match(n) for r in rxs)


def simulate(nfun, imports, direct, indirect, async_import, removed):
    """Asyncify's choice, roughly: a function is instrumented when it is
    not removed and makes an indirect call, calls an import that can
    suspend, or calls an instrumented function"""
    callers = collections.defaultdict(list)
    for k in range(nfun):
        for f in direct[k]:
            callers[f].append(k)
    inst = set()
    work = []
    for k in range(nfun):
        if k in removed:
            continue
        if indirect[k] or any(f < imports and async_import[f] for f in direct[k]):
            inst.add(k)
            work.append(k)
    while work:
        k = work.pop()
        for c in callers[k + imports]:
            if c not in inst and c not in removed:
                inst.add(c)
                work.append(c)
    return inst


def callees_report(d, imports, bodies, names, inst, args):
    nfun = len(bodies)
    direct = []
    indirect = []
    for st, size in bodies:
        dc, ic = calls(d, st, size)
        direct.append(dc)
        indirect.append(ic)
    name = lambda f: names.get(f, '#%d' % f)
    is_async = matcher(ASYNC_IMPORTS)
    async_import = [is_async(name(f)) for f in range(imports)]
    print('\nImports that can suspend: %s' % ', '.join(sorted(set(
        re.sub(r'_[a-z]+$', '_*', name(f)) if name(f).startswith('invoke_') else name(f)
        for f in range(imports) if async_import[f]))))
    actual = set(k for k in range(nfun) if name(k + imports) in set(n for _, n in inst))
    size = [s for _, s in bodies]
    removed_now = set()
    if args.remove:
        import json
        m = matcher(json.load(open(args.remove)))
        removed_now = set(k for k in range(nfun) if m(name(k + imports)))
    sim = simulate(nfun, imports, direct, indirect, async_import, removed_now)
    print('Simulated instrumentation: %d functions (built: %d; %d only simulated, %d only built)'
          % (len(sim), len(actual), len(sim - actual), len(actual - sim)))
    for k in sorted(actual - sim, key=lambda k: -size[k])[:5]:
        print('    built, not simulated: %s' % name(k + imports)[:120])
    for k in sorted(sim - actual, key=lambda k: -size[k])[:5]:
        print('    simulated, not built: %s' % name(k + imports)[:120])

    def summary(label, s):
        big = sorted((size[k] for k in s), reverse=True)
        print('  %-44s %6d functions %6.2f MB; over 4000: %4d, over 10000: %3d'
              % (label[:44], len(s), sum(big) / 1e6, sum(1 for b in big if b > 4000), sum(1 for b in big if b > 10000)))

    sites = collections.Counter()
    for k in actual:
        for f in direct[k]:
            if f < imports and async_import[f] or (f >= imports and (f - imports) in actual):
                sites[f] += 1
    print('\nInstrumented call sites in instrumented functions: %d direct, %d indirect'
          % (sum(sites.values()), sum(indirect[k] for k in actual)))
    print('Callees with the most of them, and what removing each alone would leave (sizes as built)')
    summary('as built', actual)
    for f, n in sites.most_common(args.top):
        if f < imports:
            print('  %6d sites  import %s' % (n, name(f)[:100]))
            continue
        left = simulate(nfun, imports, direct, indirect, async_import, removed_now | {f - imports})
        print('  %6d sites  %6.1f KB %s' % (n, size[f - imports] / 1024, name(f)[:100]))
        summary('    without it', left)

    if args.what_if:
        m = matcher(args.what_if)
        extra = set(k for k in range(nfun) if m(name(k + imports)))
        left = simulate(nfun, imports, direct, indirect, async_import, removed_now | extra)
        print('\nWhat if these were removed as well: %s (%d functions)' % (' '.join(args.what_if), len(extra)))
        summary('simulated', left)
        for k in sorted(left, key=lambda k: -size[k])[:args.top]:
            print('  %7.1f KB  %s' % (size[k] / 1024, name(k + imports)[:150]))


if __name__ == '__main__':
    raise SystemExit(main())
