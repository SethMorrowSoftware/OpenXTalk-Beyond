#!/usr/bin/env python3
# EXPERIMENT (not for merging): a JSC_omgAllowlist file for the web engine.
#
#   python3 tools/ci/omg_allowlist.py --wasm FILE --out FILE --over BYTES
#       [--only instrumented|plain] [--names PATTERN ...]
#
# Lists every function (by index, imports not counted, as JSC counts them)
# except the ones denied: those over BYTES, narrowed to the instrumented or
# the plain ones with --only, and to names matching a pattern (* wildcards)
# with --names. Prints what it denies.

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asyncify_report as report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wasm', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--over', type=int, default=10000)
    ap.add_argument('--only', choices=['instrumented', 'plain'])
    ap.add_argument('--names', nargs='*', default=[])
    args = ap.parse_args()

    d, imports, bodies, names, globals_ = report.read(args.wasm)
    pattern = bytes([0x23, 0x82, 0x01])  # global.get 130, Asyncify's state
    rxs = [re.compile('^' + '.*'.join(re.escape(x) for x in p.split('*')) + '$') for p in args.names]
    allowed, denied = [], []
    for k, (st, size) in enumerate(bodies):
        name = names.get(k + imports, '#%d' % (k + imports))
        inst = pattern in d[st:st + size]
        deny = size > args.over
        if deny and args.only:
            deny = inst == (args.only == 'instrumented')
        if deny and rxs:
            deny = any(rx.match(name) for rx in rxs)
        (denied if deny else allowed).append((k, size, inst, name))
    with open(args.out, 'w') as f:
        f.write(''.join('%d\n' % k for k, _, _, _ in allowed))
    print('OMG allowed for %d functions, denied for %d:' % (len(allowed), len(denied)))
    for k, size, inst, name in sorted(denied, key=lambda x: -x[1]):
        print('  %6d %6.1f KB %s %s' % (k, size / 1024, 'I' if inst else 'p', name[:100]))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
