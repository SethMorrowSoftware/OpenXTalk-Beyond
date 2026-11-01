#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""Check that text measures the same after a font file is loaded and
unloaded as before, on Linux.

  python3 tools/ci/fontfile_check.py --engine FILE [--font FILE]
      [--log FILE] [--timeout SECONDS]

`start using font file` and `stop using font file` make the engine load
every font again (MCFontRemap, engine/src/font.cpp): the old fonts are
freed and the new ones made, often at the addresses of other freed ones.
The engine keeps the width of each piece of text it measures in a cache
(libgraphics/src/context.cpp) under the font's address, so up to
0.2.7-rc.6.12 a font could be measured with another font's widths, and
the words of a bold run were drawn against each other on Linux
("Threewindowsforonewelcome" in the IDE's release notes), as the IDE
loads a font file when Home and Learn open. The engine now empties the
cache when it frees its fonts (MCDispatch::flushfonts).

The check starts its own X server (Xvfb) and runs a standalone engine
(the runtime's Standalone) with tools/ci/fontfile-check.livecodescript,
which measures one line of text in three DejaVu fonts, three styles and
three sizes, then loads and unloads the font file ten times, measuring
the line again after each. Every width must be what it was before the
first. On 0.2.7-rc.6.11 most of the twenty measurements differ.

The check fails, rather than passing blind, when the font file does not
load (the engine would not load its fonts again) or when plain and bold
DejaVu Sans or Serif measure alike (the DejaVu fonts are missing, and
every font is the same fallback).

Needs Xvfb and the DejaVu fonts. Exit status 0 when every check passed,
1 otherwise. Under GitHub Actions a failure is an annotation and the
results go into the job summary.
"""

import argparse
import os
import select
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SCRIPT = os.path.join(HERE, 'fontfile-check.livecodescript')
# A font file every checkout has, which no stack in the check uses
FONT = os.path.join(REPO, 'ide', 'Toolset', 'resources', 'supporting_files', 'fonts', 'fontawesome.ttf')

# As kRounds, kFonts, kStyles and kSizes in the script
ROUNDS = 10
FONTS = ('DejaVu Sans', 'DejaVu Serif', 'DejaVu Sans Mono')
STYLES = ('plain', 'bold', 'italic')
SIZES = ('11', '13', '16')
PROPORTIONAL = ('DejaVu Sans', 'DejaVu Serif')


def log(msg=''):
    print(msg, flush=True)


def labels():
    """The name of each width, in the order the script measures them."""
    return ['%s %s %s' % (f, st, sz) for f in FONTS for st in STYLES for sz in SIZES]


def parse_widths(text):
    try:
        widths = [int(x) for x in text.split(',')]
    except ValueError:
        return None
    return widths if len(widths) == len(labels()) else None


def differences(base, widths):
    """'name: before -> now' for each width that is not as before."""
    return ['%s: %d -> %d' % (name, b, w) for name, b, w in zip(labels(), base, widths) if b != w]


def evaluate(result):
    """[(name, ok, detail)] for the engine's log lines."""
    checks = []
    errors = [x for x in result if x.startswith('ERROR')]
    checks.append(('the script ran without an error', not errors, '; '.join(errors)))

    base = None
    rounds = {}
    for line in result:
        words = line.split(' ')
        if words[0] == 'BASE' and len(words) > 1:
            base = parse_widths(words[1])
        elif words[0] in ('LOADED', 'UNLOADED') and len(words) > 2:
            rounds[(words[0], words[1])] = (parse_widths(words[2]), ' '.join(words[3:]).strip())

    checks.append(('the line was measured before any font file', base is not None, ''))
    if base is not None:
        # Bold is wider than plain in the proportional fonts (a monospaced
        # font keeps its advance in bold), so a probe that cannot tell them
        # apart has fallen back to one font and would pass blind
        alike = ['%s %s' % (f, sz) for i, f in enumerate(FONTS) if f in PROPORTIONAL
                 for j, sz in enumerate(SIZES) if base[i * 9 + j] == base[i * 9 + 3 + j]]
        checks.append(('the plain and bold fonts measure apart (the DejaVu fonts are there)', not alike,
                       'alike in ' + ', '.join(alike)))

    for n in range(1, ROUNDS + 1):
        for step, what in (('LOADED', 'loaded'), ('UNLOADED', 'unloaded')):
            got = rounds.get((step, str(n)))
            name = 'round %d, the font file %s' % (n, what)
            if got is None:
                checks.append((name + ': measured', False, 'no %s line' % step))
                continue
            widths, said = got
            checks.append((name + ' without an error', said == '', 'the result was %r' % said))
            if widths is None or base is None:
                checks.append((name + ': every width as before', False, 'no widths to compare'))
            else:
                diff = differences(base, widths)
                checks.append((name + ': every width as before', not diff,
                               '%d of %d differ: %s' % (len(diff), len(base), '; '.join(diff[:6]))))
    checks.append(('the engine quit when it was done', any(x.startswith('QUIT') for x in result), ''))
    return checks


def start_xvfb():
    xvfb = shutil.which('Xvfb')
    if not xvfb:
        raise RuntimeError('Xvfb is not installed')
    r, w = os.pipe()
    proc = subprocess.Popen([xvfb, '-displayfd', str(w), '-screen', '0', '1280x1024x24', '-nolisten', 'tcp'],
                            pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    number = b''
    while not number.endswith(b'\n'):
        ready, _, _ = select.select([r], [], [], 30)
        if not ready:
            proc.kill()
            raise RuntimeError('Xvfb did not start')
        chunk = os.read(r, 16)
        if not chunk:
            raise RuntimeError('Xvfb did not start')
        number += chunk
    os.close(r)
    return proc, ':' + number.decode().strip()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--font', default=FONT, help='the font file to load and unload (default: the IDE\'s fontawesome.ttf)')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--timeout', type=int, default=120, help='seconds the engine may take')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The font file check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)

    lines, problems = [], []
    work = tempfile.mkdtemp(prefix='oxt-fontfile-')
    xvfb = None
    try:
        if not os.path.isfile(args.font):
            raise RuntimeError('the font file %s is not there' % args.font)
        result_log = os.path.join(work, 'engine.log')
        xvfb, display_name = start_xvfb()
        log('X server %s, engine %s, font file %s' % (display_name, engine, args.font))
        env = dict(os.environ)
        env.pop('WAYLAND_DISPLAY', None)
        env.update({'DISPLAY': display_name, 'OXT_FONTFILE_LOG': result_log,
                    'OXT_FONTFILE_FONT': os.path.abspath(args.font)})
        try:
            proc = subprocess.run([engine, SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=args.timeout)
            code, output = proc.returncode, proc.stdout.decode('utf-8', 'replace')
        except subprocess.TimeoutExpired as e:
            code, output = None, (e.stdout or b'').decode('utf-8', 'replace')
        result = []
        if os.path.exists(result_log):
            with open(result_log, encoding='utf-8', errors='replace') as f:
                result = [x.rstrip('\r\n') for x in f if x.strip()]
        lines += ['INFO engine: ' + x for x in result if x.startswith(('INFO', 'BASE', 'ERROR', 'QUIT'))]
        if code is None:
            lines.append('INFO the engine timed out after %d seconds' % args.timeout)
        for name, ok, detail in evaluate(result):
            lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
            if not ok:
                problems.append('%s%s' % (name, (': ' + detail) if detail else ''))
        if problems and output.strip():
            lines.append('INFO engine output: ' + output[-2000:])
    except RuntimeError as e:
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        if xvfb is not None:
            xvfb.kill()
            xvfb.wait()
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=Font file check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Font file check (Linux)\n\n```\n%s\n```\n' % '\n'.join(lines))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
