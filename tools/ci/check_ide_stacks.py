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

"""Check that the binary IDE stacks carry the script patches of
tools/oxt/ide-stack-patches.

  python tools/ci/check_ide_stacks.py [--repo DIR]

Binary stacks (ide/**/*.livecode) are changed only by
tools/oxt/ide-stack-patch.livecodescript, which needs a LiveCode engine. This
check needs none: a stack file of format 7.0 or later stores each script as
one UTF-8 string, with LF line ends, so an applied patch can be seen in the
file's bytes. For every patch definition it checks that the replacement
text occurs exactly once in the stack file and the replaced text does not
occur.

It also checks what the patches are for, so that a stack saved from the IDE
cannot bring the old code back unnoticed:
  - the dataView behaviour in Toolset/palettes/revCore.8.livecode paints row
    backgrounds with _GetEffectiveColor("row color") and
    _GetEffectiveColor("alternate row color") (the colours each list sets
    from revIDEColor), and _HiliteControl sets no literal grey;
  - ideColorGet in revCore's stack script, the copy the IDE runs, is the
    same as in the script-only copy
    Toolset/palettes/behaviors/revcorestackbehavior.livecodescript.

Exit status 1 when a check fails. Under GitHub Actions failures become
error annotations. Needs Python 3.8 or later, standard library only.
"""

import argparse
import os
import re
import sys

PATCH_DIR = os.path.join('tools', 'oxt', 'ide-stack-patches')
REVCORE = os.path.join('ide', 'Toolset', 'palettes', 'revCore.8.livecode')
COPY = os.path.join('ide', 'Toolset', 'palettes', 'behaviors', 'revcorestackbehavior.livecodescript')


def read_patch(path):
    """(file, object, old text, new text) of a patch definition."""
    fields = {}
    sections = {'old': [], 'new': []}
    section = None
    with open(path, 'r', encoding='utf-8') as f:
        for number, line in enumerate(f.read().splitlines(), 1):
            if section is None and (not line or line.startswith('#')):
                continue
            if line.startswith('file:'):
                fields['file'] = line[5:].strip()
            elif line.startswith('object:'):
                fields['object'] = line[7:].strip()
            elif line == 'replace:':
                section = 'old'
            elif line == 'with:':
                section = 'new'
            elif section and len(line) >= 2 and line.startswith('|') and line.endswith('|'):
                sections[section].append(line[1:-1])
            elif not line:
                continue
            else:
                raise ValueError('%s line %d: not a patch line: %s' % (path, number, line))
    if not fields.get('file') or not fields.get('object') or not sections['old'] or not sections['new']:
        raise ValueError('%s: needs file:, object:, replace: and with:' % path)
    # As in the patch tool, each text ends with the line end of its last line
    old = '\n'.join(sections['old']) + '\n'
    new = '\n'.join(sections['new']) + '\n'
    return fields['file'], fields['object'], old.encode('utf-8'), new.encode('utf-8')


def handler_span(data, start, end):
    """The bytes of the one handler from `start` to `end` (both bytes)."""
    first = data.find(start)
    if first < 0 or data.find(start, first + 1) >= 0:
        return None
    last = data.find(end, first)
    if last < 0:
        return None
    return data[first:last + len(end)]


def check_patches(repo, failures):
    folder = os.path.join(repo, PATCH_DIR)
    names = sorted(n for n in os.listdir(folder) if n.endswith('.txt'))
    if not names:
        failures.append((PATCH_DIR, 'no patch definitions'))
    for name in names:
        rel_patch = PATCH_DIR.replace(os.sep, '/') + '/' + name
        try:
            stack, obj, old, new = read_patch(os.path.join(folder, name))
        except (OSError, ValueError) as e:
            failures.append((rel_patch, str(e)))
            continue
        rel_stack = 'ide/' + stack
        path = os.path.join(repo, 'ide', *stack.split('/'))
        if not os.path.isfile(path):
            failures.append((rel_patch, 'stack file not found: %s' % rel_stack))
            continue
        with open(path, 'rb') as f:
            data = f.read()
        new_count = data.count(new)
        old_count = data.count(old)
        if new_count == 1 and old_count == 0:
            print('ok      %s: applied to %s, %s' % (name, rel_stack, obj))
        else:
            failures.append((rel_stack, '%s is not applied to %s (replacement found %d time(s), replaced text %d time(s)); '
                             'run tools/oxt/ide-stack-patch.sh' % (name, obj, new_count, old_count)))


def check_dataview(repo, failures):
    with open(os.path.join(repo, REVCORE), 'rb') as f:
        data = f.read()
    rel = REVCORE.replace(os.sep, '/')
    span = handler_span(data, b'private command _HiliteControl pControl, pBoolean\n', b'\nend _HiliteControl')
    if span is None:
        failures.append((rel, 'the dataView behaviour has not exactly one _HiliteControl handler'))
        return
    literal = re.search(rb'set the backgroundColor of control "Background" of pControl to\s+"?\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}', span)
    if literal:
        failures.append((rel, '_HiliteControl sets a literal row colour: %s' % literal.group(0).decode('utf-8', 'replace')))
    for call in (b'_GetEffectiveColor("alternate row color")', b'_GetEffectiveColor("row color")'):
        if call not in span:
            failures.append((rel, '_HiliteControl does not paint rows with %s' % call.decode('ascii')))
    if not any(r == rel for r, _ in failures):
        print('ok      %s: _HiliteControl paints rows with the lists\' row colours' % rel)


def check_idecolorget(repo, failures):
    """revCore's stack script (the backscript the IDE uses) and the
    script-only copy revcorestackbehavior.livecodescript must have the same
    ideColorGet, so that the copy can be read and reviewed as text."""
    rel = REVCORE.replace(os.sep, '/')
    copy = COPY.replace(os.sep, '/')
    with open(os.path.join(repo, REVCORE), 'rb') as f:
        live = handler_span(f.read(), b'function ideColorGet pTag\n', b'\nend ideColorGet')
    with open(os.path.join(repo, COPY), 'rb') as f:
        text = f.read()
    if text.startswith(b'\xef\xbb\xbf'):
        text = text[3:]
    text = text.replace(b'\r\n', b'\n')
    reference = handler_span(text, b'function ideColorGet pTag\n', b'\nend ideColorGet')
    if live is None or reference is None:
        failures.append((rel, 'ideColorGet is not exactly once in %s and in %s' % (rel, copy)))
    elif live != reference:
        failures.append((rel, 'ideColorGet differs from the one in %s; change both (the stack through '
                              'tools/oxt/ide-stack-patches)' % copy))
    else:
        print('ok      %s: ideColorGet is the same as in %s' % (rel, copy))


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    args = parser.parse_args(argv)

    failures = []
    check_patches(args.repo, failures)
    check_dataview(args.repo, failures)
    check_idecolorget(args.repo, failures)

    for rel, message in failures:
        print('FAILED  %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=IDE stacks::%s' % (rel, message))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('### IDE stacks\n\n%s\n\n' % ('All script patches of `tools/oxt/ide-stack-patches` are applied.'
                                                 if not failures else '\n'.join('- `%s`: %s' % item for item in failures)))
    print('IDE stacks: %s' % ('passed' if not failures else 'FAILED (%d problem(s))' % len(failures)))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
