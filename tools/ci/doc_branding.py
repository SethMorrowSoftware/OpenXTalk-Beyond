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

"""Keep the LiveCode name out of the documentation, so that it does not
creep back after the debranding of 0.2.8 (Markdown and .lcdoc files only:
this reads no code, and changes nothing).

  python3 tools/ci/doc_branding.py check      # in CI checks
  python3 tools/ci/doc_branding.py baseline   # after removing mentions

The docs call the languages xTalk Script and xTalk Builder and the program
OXT-Beyond. LiveCode is still named where that is the truth: the licence
and its notices, the project's history and credits ("LiveCode Ltd"),
compatibility ("opens LiveCode Community stacks", "as in LiveCode 9.6.3")
and what upstream did or still does. So the check has two rules:

1. "LiveCode Script" and "LiveCode Builder" are never written in a doc in
   scope: those are xTalk Script and xTalk Builder.
2. Every other mention of the name in prose is counted per file and may
   not grow past the count in doc-branding-baseline.txt (a ratchet, as the
   suite's coverage gate is). A count that went down must be written down
   (run baseline), so the ratchet only ever tightens.

Not counted, because they are not branding but facts or code: text in
backquotes, fenced or indented code, URLs and link targets, identifiers
(com.livecode.*, livecode.com, .livecode files, livecode_script), and the
name followed by Ltd, Limited, Community or a version number.

EXEMPT names the files read as they are: the licence and its notices, the
history, the changelog (CHANGELOG.md and the fragments of changelog/
that a release folds into it: a record of what changed, which may have to
name what was changed from), the glossary entry for the name itself, the guides the xTalk
Assistant and the MCP Bridge give the language model (they tell it what
the user's LiveCode knowledge is worth here), and vendored code.
"""

import argparse
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASELINE = os.path.join('tools', 'ci', 'doc-branding-baseline.txt')

DOC_SUFFIXES = ('.md', '.lcdoc')

EXEMPT = (
    'LICENSE-EXCEPTION.md',
    'NOTICE-OF-MODIFICATIONS.md',
    'THIRD-PARTY-NOTICES.md',
    'HISTORY.md',
    'CHANGELOG.md',
    'docs/glossary/l/LiveCode.lcdoc',
    'ide/Extensions/org.openxtalk.plugin.xtalkassistant/xtalk-guide.md',
    'ide/Extensions/org.openxtalk.plugin.mcpbridge/bridge-guide.md',
)
EXEMPT_DIRS = ('thirdparty/', 'prebuilt/', 'node_modules/', 'changelog/')

# Spans that are code, addresses or identifiers, not prose
PROTECTED = re.compile(
    r"(?m:^(?:\t|    )(?![-*] |\d+\. ).*$)"      # indented code (not a list)
    r"|```.*?```"                                # fenced code
    r"|`[^`\n]*`"                                # inline code
    r"|\]\([^)]*\)"                              # link target
    r"|<https?://[^>]*>"
    r"|https?://[^\s)\]>\"']+"
    r"|\[[^\]]*\]:\s*\S+"                        # reference link
    r"|[\w.-]*livecode[\w.-]*\.(?:com|org|net)\S*"
    r"|com\.livecode[\w.]*"
    r"|<[a-zA-Z][^<>\n]*>",                      # HTML tags, lcdoc <links>
    re.S)

NAME = re.compile(r"\bLive\s?[Cc]ode\b|\bLIVECODE\b")
LANGUAGE = re.compile(r"\b(?i:live\s?code\s+(?:script|builder))\b(?! tool)")
ALLOWED_AFTER = re.compile(r"('s)?\s+(Ltd|Limited|Community|\d)")


def in_scope(path):
    if not path.endswith(DOC_SUFFIXES):
        return False
    if path in EXEMPT or path.startswith(EXEMPT_DIRS):
        return False
    return True


def prose(text):
    """The text with every protected span blanked (newlines kept, so that
    line numbers stay right)."""
    return PROTECTED.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)


def lcdoc_prose(text):
    """An .lcdoc file's prose: its Example sections and its fields of names
    (name, synonyms, references, syntax) are code or identifiers."""
    out = []
    example = False
    field = False
    for line in text.splitlines(keepends=True):
        if re.match(r'^[A-Z][A-Za-z ]*:', line):
            example = line.startswith('Example:')
            # (a field may go on over several lines: synonyms are what
            # people search for, LiveCode's names included)
            field = re.match(r'^(Name|Associations|Synonyms|References|Type|Syntax|Signature|Tags):', line)
        if example or field:
            line = '\n' if line.endswith('\n') else ''
        out.append(line)
    return prose(''.join(out))


def findings(path, text):
    """(language, counted): the lines naming a language as LiveCode's, and
    the lines with a counted mention of the name, as (line, text) pairs,
    one per mention."""
    body = lcdoc_prose(text) if path.endswith('.lcdoc') else prose(text)
    lines = text.splitlines()

    def at(offset):
        number = body.count('\n', 0, offset) + 1
        return number, lines[number - 1].strip() if number <= len(lines) else ''

    language, counted = [], []
    for m in LANGUAGE.finditer(body):
        language.append(at(m.start()))
    for m in NAME.finditer(body):
        if LANGUAGE.match(body, m.start()) or ALLOWED_AFTER.match(body, m.end()):
            continue
        counted.append(at(m.start()))
    return language, counted


def tracked_docs(root):
    out = subprocess.run(['git', 'ls-files', '-z'], cwd=root, capture_output=True, check=True).stdout
    return sorted(p for p in out.decode('utf-8').split('\0') if p and in_scope(p))


def read_baseline(root):
    counts = {}
    path = os.path.join(root, BASELINE)
    if not os.path.exists(path):
        return counts
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#'):
                continue
            count, _, name = line.partition('\t')
            counts[name] = int(count)
    return counts


def measure(root, files):
    result = {}
    for path in files:
        with open(os.path.join(root, path), encoding='utf-8', errors='replace') as f:
            text = f.read()
        result[path] = findings(path, text)
    return result


def check(root, files, baseline):
    """The problems, as lines of text; none means the docs pass."""
    problems = []
    measured = measure(root, files)
    for path in files:
        language, counted = measured[path]
        for number, shown in language:
            problems.append('%s:%d: say xTalk Script or xTalk Builder: %s' % (path, number, shown))
        allowed = baseline.get(path, 0)
        if len(counted) > allowed:
            problems.append('%s: %d mentions of LiveCode, %d allowed (say OXT-Beyond, the engine '
                            'or the IDE; or, where LiveCode is meant, run baseline):'
                            % (path, len(counted), allowed))
            problems.extend('  %s:%d: %s' % (path, n, s) for n, s in counted)
        elif len(counted) < allowed:
            problems.append('%s: %d mentions of LiveCode, the baseline says %d: run '
                            'python3 tools/ci/doc_branding.py baseline' % (path, len(counted), allowed))
    for path in sorted(set(baseline) - set(files)):
        problems.append('%s: in the baseline but not a doc in scope: run baseline' % path)
    return problems


def write_baseline(root, files):
    measured = measure(root, files)
    lines = ['# Mentions of LiveCode that each doc may keep (tools/ci/doc_branding.py).',
             '# Written by: python3 tools/ci/doc_branding.py baseline',
             '# Each is history, compatibility or what upstream did; the count may',
             '# only go down.']
    for path in files:
        n = len(measured[path][1])
        if n:
            lines.append('%d\t%s' % (n, path))
    with open(os.path.join(root, BASELINE), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('action', choices=('check', 'baseline'))
    ap.add_argument('--root', default=REPO)
    args = ap.parse_args(argv)
    files = tracked_docs(args.root)
    if args.action == 'baseline':
        write_baseline(args.root, files)
        print('Wrote %s' % BASELINE)
        return 0
    problems = check(args.root, files, read_baseline(args.root))
    for p in problems:
        print(p)
    if problems:
        print('::error title=Doc branding::%d problem(s); see tools/ci/doc_branding.py' % len(problems))
        return 1
    print('Doc branding: %d docs checked, no new LiveCode mentions' % len(files))
    return 0


if __name__ == '__main__':
    sys.exit(main())
