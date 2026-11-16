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

"""The "Modified from LiveCode Community" notice in every source file that
OXT-Beyond changed from LiveCode Community.

  python3 tools/ci/modification_notices.py check
  python3 tools/ci/modification_notices.py write
  python3 tools/ci/modification_notices.py list

GPLv3 section 5(a) asks that a modified work carry prominent notices
saying it was modified, with a relevant date. A file that OXT-Beyond took
from LiveCode and changed says so in a comment of its own, under the file's
LiveCode header, naming who made the changes and in which years (from git:
the authors of the commits that changed it, their Co-authored-by trailers,
and the few commits that brought in someone else's work under another
name; CREDIT_REPLACE and CREDIT_ADD), so that a fork taking one file
as it is takes the credit with it. Files that cannot hold a comment
(stacks, dictionary entries, guides, images) are covered by
NOTICE-OF-MODIFICATIONS.md.

A file is in scope when it was in the LiveCode tree OXT-Beyond started
from and is no longer the same: UPSTREAM (LiveCode Community's develop
branch as it was left in July 2021, with the thirdparty submodule vendored)
or, for ide/, IDE_BASE (the commit that vendored the ide submodule).
Renames since IDE_BASE are followed. Only files of a kind with a comment
syntax count (COMMENT_STYLES), and not thirdparty/ (other projects'
libraries, whose changes their ORIGIN files and "OXT-Beyond" markers
record) except LiveCode's own gyp files there, nor docs/ or prebuilt/,
nor a file a script writes (GENERATED).

check (CI checks, with the whole history): fails on a file in scope with
no notice, so the first change to a LiveCode file brings its notice.
write: adds the notice to every such file. A file that has one already is
left alone, so a notice written by hand (revzip/src/revzip.cpp) stays.
list: every file in scope, and whether it has its notice.

Where the notice goes, so nothing a script or a compiler sees moves
in meaning: in C, C++, Objective-C, Java, JavaScript and LCB, after the
leading /* */ licence block when there is one, else at the top; in a
script-only stack (.livecodescript), after its `script "..."` line; in
Python, shell and gyp, after the #! line and the leading # comments; in
a batch file, after `@echo off` (REM) or at the top (@rem, so it is not
echoed). A byte order mark and CRLF line endings are kept. Only the
Python 3 standard library is used.
"""

import argparse
import os
import re
import subprocess
import sys
import textwrap

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# LiveCode Community's develop branch (July 2021) with the thirdparty
# submodule vendored: the tree OXT-Beyond started from.
UPSTREAM = '4c9715a778d869d376183d4a1d8947cca37512f6'
# The commit that vendored the ide submodule; ide/ files start here.
IDE_BASE = '8ef95bac0526566b5c7f0bb029f7c9854f41f0a7'
# Commits that only vendored a submodule changed nothing of LiveCode's.
NOT_CHANGES = {UPSTREAM, IDE_BASE}

URL = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'
MARKER = 'Modified from LiveCode Community'

# Every name OXT-Beyond's own commits are written under.
OWN_NAMES = {'Seth Morrow', 'SethMorrowSoftware', 'seth',
             'sethmorrowsoftware', 'Claude', 'x', 'Some Guy'}
OWN = 'Seth Morrow'
IGNORED_NAMES = {'dependabot[bot]'}
# Spellings of one person.
NAMES = {
    'Emily-Elizabath Howard': 'Emily-Elizabeth Howard',
    'BerndN': 'Bernd Niggemann',
}
# Commits written under OXT-Beyond's name that brought in another's work:
# REPLACE credits only them, ADD credits them beside OXT-Beyond.
CREDIT_REPLACE = {
    # macOS: Tom Perry's macOS engine work (his Apple Silicon working copy)
    '65564e060': ['Tom Perry'],
}
CREDIT_ADD = {
    # macOS: Tom Perry's dark menus
    '15dc73ef4': ['Tom Perry'],
    # fixes found in Tom Perry's OpenXTalk Lite 7 engine source
    'be963d6b0': ['Tom Perry'],
    '95be3ca52': ['Tom Perry'],
    '11c32b854': ['Tom Perry'],
    # fixes from Paul McClernan's OpenXTalk DPE
    'b1faba01f': ['Paul McClernan'],
}

COMMENT_STYLES = {
    'c': 'c', 'cpp': 'c', 'cc': 'c', 'h': 'c', 'hpp': 'c', 'mm': 'c',
    'm': 'c', 'java': 'c', 'js': 'c', 'inc': 'c',
    'lcb': 'lcb',
    'livecodescript': 'lcs',
    'py': 'hash', 'sh': 'hash', 'gyp': 'hash', 'gypi': 'hash',
    'bat': 'batch', 'cmd': 'batch',
    'rc': 'slash',
}
EXCLUDED_PREFIXES = ('docs/', 'prebuilt/', 'stack-scripts/')
# Files a script writes, which a notice in them would make stale: a
# test holds each to its generator's output.
GENERATED = {
    # thirdparty/libcef/gen_libcef_paths.py (test_libcef_stubs)
    'thirdparty/libcef/libcef.gypi',
}
WIDTH = 76
NBSP = '\x00'  # holds a name together while the text is wrapped


def git(repo, *args):
    return subprocess.run(['git', '-C', repo, '-c', 'core.quotePath=false']
                          + list(args), check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE).stdout.decode('utf-8')


def style_of(path):
    ext = path.rsplit('.', 1)[-1].lower() if '.' in path else ''
    return COMMENT_STYLES.get(ext)


def path_in_scope(path):
    if style_of(path) is None or path.startswith(EXCLUDED_PREFIXES) \
            or path in GENERATED:
        return False
    if path.startswith('thirdparty/'):
        # LiveCode's build files for the libraries, not the libraries
        return re.fullmatch(r'thirdparty/[^/]+/[^/]+\.gypi?', path) is not None
    return True


def tree(repo, rev):
    """{path: blob} of rev."""
    out = {}
    for line in git(repo, 'ls-tree', '-r', '-z', rev).split('\0'):
        if line:
            meta, path = line.split('\t', 1)
            out[path] = meta.split()[2]
    return out


def renames(repo, upstream, ide_base):
    """{path now: path in the start tree} for files renamed since then."""
    out = {}
    for base in (upstream, ide_base):
        text = git(repo, '-c', 'diff.renameLimit=20000', 'diff', '-M',
                   '--name-status', '-z', '--diff-filter=R', base, 'HEAD')
        parts = text.split('\0')
        i = 0
        while i + 2 < len(parts):
            if parts[i].startswith('R'):
                out.setdefault(parts[i + 2], parts[i + 1])
            i += 3
    return out


def changed_files(repo, upstream=UPSTREAM, ide_base=IDE_BASE):
    """[(path, origin path)] of the files in scope: in the start tree, of a
    kind that takes a comment, and changed since (or changed in the working
    tree)."""
    head = tree(repo, 'HEAD')
    up = tree(repo, upstream)
    ide = tree(repo, ide_base)
    moved = renames(repo, upstream, ide_base)
    dirty = set(p for p in git(repo, 'diff', '--name-only', '-z', 'HEAD')
                .split('\0') if p)
    out = []
    for path in sorted(head):
        if not path_in_scope(path):
            continue
        origin = moved.get(path, path)
        start = up.get(origin, ide.get(origin))
        if start is None:
            continue  # OXT-Beyond's own file
        if start != head[path] or path in dirty:
            out.append((path, origin))
    return out


def credits(repo, path, origin, upstream=UPSTREAM):
    """[(name, first year, last year)] of the changes to path since
    upstream, OXT-Beyond's name first, the others in the order they came;
    None when no commit changed it."""
    paths = [path] if origin == path else [path, origin]
    text = git(repo, 'log', '--no-merges', '--reverse', '--date=format:%Y',
               '--format=%H%x1f%an%x1f%ad%x1f%B%x1e',
               upstream + '..HEAD', '--', *paths)
    years = {}  # name: [years], in the order the names came
    for record in text.split('\x1e'):
        record = record.strip('\n')
        if not record:
            continue
        sha, author, year, body = record.split('\x1f', 3)
        if sha in NOT_CHANGES:
            continue
        found = []
        replaced = [v for k, v in CREDIT_REPLACE.items() if sha.startswith(k)]
        if replaced:
            found.extend(replaced[0])
        else:
            found.append(author)
            for line in body.splitlines():
                m = re.match(r'\s*co-authored-by:\s*(.*?)\s*<([^>]*)>', line,
                             re.I)
                if m and 'anthropic' not in m.group(2).lower() \
                        and not m.group(1).startswith('Claude'):
                    found.append(m.group(1))
            for k, v in CREDIT_ADD.items():
                if sha.startswith(k):
                    found.extend(v)
        for name in found:
            if name in IGNORED_NAMES:
                continue
            name = OWN if name in OWN_NAMES else NAMES.get(name, name)
            years.setdefault(name, []).append(int(year))
    if not years:
        return None
    names = sorted(years, key=lambda n: n != OWN)  # stable: OWN first
    return [(n, min(years[n]), max(years[n])) for n in names]


def notice_text(people):
    """people: [(name, first year, last year)]."""
    who = []
    for name, first, last in people:
        when = str(first) if first == last else '%d-%d' % (first, last)
        # a name is never split over two lines, so a search for it finds it
        who.append('%s (%s)' % (name, when))
    return ("%s. This copy, OpenXTalk-Beyond's (%s), has changes by %s; "
            'its Git history and CHANGELOG.md say what changed.'
            % (MARKER, URL, join([w.replace(' ', NBSP) for w in who])))


def join(names):
    if len(names) <= 2:
        return ' and '.join(names)
    return ', '.join(names[:-1]) + ' and ' + names[-1]


def comment_lines(style, text, top=True):
    if style == 'c':
        body = wrap(text, WIDTH - 3)
        lines = ['/* ' + body[0]] + ['   ' + b for b in body[1:]]
        lines[-1] += ' */'
        return lines
    prefix = {'lcb': '-- ', 'lcs': '-- ', 'hash': '# ', 'slash': '// ',
              'batch': 'REM ' if not top else '@rem '}[style]
    return [prefix + b for b in wrap(text, WIDTH - len(prefix))]


def wrap(text, width):
    return [line.replace(NBSP, ' ') for line in textwrap.wrap(
        text, width, break_long_words=False, break_on_hyphens=False)]


def insert_notice(data, style, text):
    """data (bytes) with the notice put in its place."""
    bom = b''
    if data.startswith(b'\xef\xbb\xbf'):
        bom, data = data[:3], data[3:]
    s = data.decode('latin-1')
    eol = '\r\n' if '\r\n' in s else '\n'
    lines = s.split(eol)
    at = 0  # the notice goes before lines[at]
    top = True
    if style in ('c', 'lcb'):
        if lines and lines[0].lstrip().startswith('/*'):
            for i, line in enumerate(lines):
                end = line.find('*/', 2 if i == 0 else 0)
                if end >= 0:
                    if line[end + 2:].strip() == '':
                        at = i + 1
                    break
    elif style == 'lcs':
        if lines and re.match(r'\s*script\s', lines[0], re.I):
            at = 1
    elif style == 'hash':
        while at < len(lines) and lines[at].startswith('#'):
            at += 1
    elif style == 'batch':
        if lines and lines[0].strip().lower() == '@echo off':
            at, top = 1, False
    notice = comment_lines(style, text, top)
    before = [''] if at > 0 and lines[at - 1].strip() != '' \
        and style not in ('lcs', 'batch') else []
    after = [''] if at < len(lines) and lines[at].strip() != '' else []
    lines[at:at] = before + notice + after
    return bom + eol.join(lines).encode('latin-1')


def has_notice(data):
    return MARKER.encode('ascii') in data


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('command', choices=['check', 'write', 'list'])
    ap.add_argument('--repo', default=REPO)
    ap.add_argument('--upstream', default=UPSTREAM)
    ap.add_argument('--ide-base', default=IDE_BASE)
    args = ap.parse_args(argv)
    repo = args.repo
    try:
        files = changed_files(repo, args.upstream, args.ide_base)
    except subprocess.CalledProcessError as e:
        # fail closed: without the start tree nothing can be checked
        sys.stderr.write('modification_notices: git failed (%s); the check '
                         'needs the whole history (fetch-depth: 0)\n%s'
                         % (' '.join(e.cmd[3:]), e.stderr.decode('utf-8',
                                                                 'replace')))
        return 2
    missing, written = [], 0
    for path, origin in files:
        full = os.path.join(repo, path)
        with open(full, 'rb') as f:
            data = f.read()
        present = has_notice(data)
        if args.command == 'list':
            print('%s %s' % ('ok     ' if present else 'MISSING', path))
        elif not present:
            if args.command == 'check':
                missing.append(path)
            else:
                found = credits(repo, path, origin, args.upstream)
                if found is None:
                    # changed in the working tree only: the change is ours
                    import datetime
                    y = datetime.date.today().year
                    found = [(OWN, y, y)]
                text = notice_text(found)
                with open(full, 'wb') as f:
                    f.write(insert_notice(data, style_of(path), text))
                written += 1
    if args.command == 'check':
        if missing:
            print('%d file(s) changed from LiveCode have no "%s" notice '
                  '(GPLv3 5a). Add it with\n  python3 tools/ci/'
                  'modification_notices.py write\n' % (len(missing), MARKER))
            for p in missing:
                print('  ' + p)
            return 1
        print('modification notices: all %d changed LiveCode files have one'
              % len(files))
    elif args.command == 'write':
        print('modification notices: %d added, %d files in scope'
              % (written, len(files)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
