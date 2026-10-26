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

"""LiveCode Script scanning for the codebase map.

Reads script-only stacks (.livecodescript) directly and binary stacks
through text dumps made by tools/oxt/ide-stack-dump.livecodescript (one
"| " line per script line, "== <path>" per object, "prop behavior: ..."
for behaviors). Everything is a lexical approximation: it finds handler
definitions, the names a script calls, literal stack references, globals
and the IDE's own publish/subscribe messages. It never runs a script.
"""

import os
import re

DEF_RE = re.compile(r'^\s*(private\s+)?(on|command|function|getprop|setprop|before|after)\s+([A-Za-z_][\w.]*)', re.I)
END_RE = re.compile(r'^\s*end\s+([A-Za-z_][\w.]*)\s*$', re.I)
GLOBAL_RE = re.compile(r'^\s*global\s+(.+)$', re.I)
STACKREF_RE = re.compile(r'\bstack\s+"([^"\n]+)"', re.I)
USING_RE = re.compile(r'\bstart\s+using\s+stack\s+"([^"\n]+)"', re.I)
INSERT_RE = re.compile(r'\binsert\s+(?:the\s+)?script\s+of\s+(?:\w+\s+)*?stack\s+"([^"\n]+)"\s+into\s+(front|back)', re.I)
SEND_RE = re.compile(r'\b(?:send|call)\s+"([A-Za-z_]\w*)', re.I)
DISPATCH_RE = re.compile(r'\bdispatch\s+(?:function\s+)?"([A-Za-z_]\w*)"', re.I)
PUBLISH_RE = re.compile(r'\bideMessageSend(?:WithParameters|WithTrigger)?(?:"\s*&&\s*"|\s+"?)\s*(ide[A-Za-z]+)', re.I)
SELF_INSERT_RE = re.compile(r'\binsert\s+(?:the\s+)?script\s+of\s+me\s+into\s+(front|back)', re.I)
CONST_INSERT_RE = re.compile(r'\binsert\s+(?:the\s+)?script\s+of\s+stack\s+([A-Za-z_]\w*)\s+into\s+(front|back)', re.I)
REMOVE_SELF_RE = re.compile(r'\bremove\s+(?:the\s+)?script\s+of\s+me\s+from\s+front', re.I)
# handlers in which taking oneself out of the path is just unloading
UNLOAD_HANDLERS = {'extensionfinalize', 'releasestack', 'revunloadlibrary', 'closestack'}
UNLOAD_RE = re.compile(r'\brevInternal__UnloadLibrary\s+"([^"]+)"', re.I)
CONST_RE = re.compile(r'^\s*constant\s+([A-Za-z_]\w*)\s*=\s*"([^"]+)"', re.I)
SUBSCRIBE_RE = re.compile(r'\brevIDESubscribe\s+"(ide\w+)"', re.I)
FUNC_RE = re.compile(r'\b([A-Za-z_]\w*)\s*\(')
WORD_RE = re.compile(r'[A-Za-z_][\w.]*')

# Words that begin statements or are operators/control structure; they are
# never handler calls. Anything else that is not defined by some script in
# the corpus is simply not resolved, so this list only trims noise.
KEYWORDS = set('''
if then else end repeat for each while until with next exit pass return
put into after before get set the to of in is not and or local global
constant try catch finally throw switch case default break do send call
dispatch function command on private wait lock unlock answer ask go
create delete hide show open close start stop insert remove move click
type select copy paste cut add subtract multiply divide sort filter
replace split combine read write import export save quit beep play
choose drag find mark unmark print reset revert enter push pop
'''.split())


def strip_comments(lines):
    """Blank out comments and string contents? No: keep strings (send
    targets live in them), drop comments. Handles -- # // and /* */."""
    out = []
    in_block = False
    for line in lines:
        res = []
        i = 0
        in_str = False
        n = len(line)
        while i < n:
            c = line[i]
            if in_block:
                if line.startswith('*/', i):
                    in_block = False
                    i += 2
                    continue
                i += 1
                continue
            if in_str:
                res.append(c)
                if c == '"':
                    in_str = False
                i += 1
                continue
            if c == '"':
                in_str = True
                res.append(c)
                i += 1
                continue
            if line.startswith('/*', i):
                in_block = True
                i += 2
                continue
            if line.startswith('--', i) or line.startswith('//', i) or c == '#':
                break
            res.append(c)
            i += 1
        out.append(''.join(res))
    return out


def blank_strings(s):
    return re.sub(r'"[^"\n]*"', '""', s)


class Unit(object):
    """One script-bearing file: a script-only stack or a binary stack."""

    def __init__(self, path, kind):
        self.path = path
        self.kind = kind            # 'lcs' or 'binary'
        self.stack_names = []       # main stack first, then substacks
        self.defs = {}              # lower name -> dict(name, kind, private, lines, count)
        self.calls = {}             # lower name -> count (statement + function calls)
        self.sends = {}             # lower name -> count (send/dispatch/call literals)
        self.globals = set()
        self.stackrefs = {}         # lower stack name -> count
        self.using = set()
        self.inserts = set()        # (stack, front|back)
        self.behaviors = set()      # stack names used as behaviours (binary dumps)
        self.publishes = set()
        self.subscribes = set()
        self.constants = {}
        self.self_inserts = set()   # 'front' / 'back': the script puts itself in the path
        self.transient_front = False  # removes itself from the front outside unloading
        self.unloads = set()        # libraries this script takes out of the path at run time
        self.passes = set()         # handlers whose body passes their own message
        self.props = set()          # lower words after "the" (property reads/writes)
        self.lines = 0
        self.objects = 0
        self.scripted_objects = 0

    def scan_script(self, raw_lines):
        self.lines += len(raw_lines)
        lines = strip_comments(raw_lines)
        cur = None
        joined = []
        buf = ''
        for line in lines:
            if line.rstrip().endswith('\\'):
                buf += line.rstrip()[:-1] + ' '
                continue
            joined.append(buf + line)
            buf = ''
        if buf:
            joined.append(buf)
        for line in joined:
            m = DEF_RE.match(line)
            if m:
                name = m.group(3)
                key = name.lower()
                d = self.defs.setdefault(key, dict(name=name, kind=m.group(2).lower(),
                                                   private=bool(m.group(1)), lines=0, count=0))
                d['count'] += 1
                cur = key
                continue
            m = END_RE.match(line)
            if m and cur and m.group(1).lower() == cur:
                cur = None
                continue
            if cur:
                self.defs[cur]['lines'] += 1
                pm = re.search(r'\bpass\s+([A-Za-z_]\w*)', line, re.I)
                if pm and pm.group(1).lower() == cur:
                    self.passes.add(cur)
            for pr in re.findall(r'\bthe\s+([A-Za-z_]\w*)', line, re.I):
                self.props.add(pr.lower())
            m = GLOBAL_RE.match(line)
            if m:
                for g in m.group(1).split(','):
                    g = g.strip()
                    if re.match(r'^[A-Za-z_]\w*$', g):
                        self.globals.add(g)
                continue
            for r in STACKREF_RE.findall(line):
                k = r.lower()
                self.stackrefs[k] = self.stackrefs.get(k, 0) + 1
            for r in USING_RE.findall(line):
                self.using.add(r)
            for r, where in INSERT_RE.findall(line):
                self.inserts.add((r, where.lower()))
            for r in UNLOAD_RE.findall(line):
                self.unloads.add(r.lower())
            if REMOVE_SELF_RE.search(line) and cur and cur not in UNLOAD_HANDLERS:
                self.transient_front = True
            for where in SELF_INSERT_RE.findall(line):
                self.self_inserts.add(where.lower())
            cm = CONST_RE.match(line)
            if cm:
                self.constants[cm.group(1).lower()] = cm.group(2)
            for c, where in CONST_INSERT_RE.findall(line):
                if c.lower() in self.constants:
                    self.inserts.add((self.constants[c.lower()], where.lower()))
            for r in SEND_RE.findall(line) + DISPATCH_RE.findall(line):
                k = r.lower()
                self.sends[k] = self.sends.get(k, 0) + 1
            for r in PUBLISH_RE.findall(line):
                self.publishes.add(r)
            for r in SUBSCRIBE_RE.findall(line):
                self.subscribes.add(r)
            code = blank_strings(line)
            for r in FUNC_RE.findall(code):
                k = r.lower()
                if k not in KEYWORDS:
                    self.calls[k] = self.calls.get(k, 0) + 1
            # statement-position words: start of line, after then/else
            for stmt in re.split(r'\b(?:then|else)\b', code, flags=re.I):
                w = WORD_RE.match(stmt.strip())
                if w:
                    k = w.group(0).lower()
                    if k not in KEYWORDS:
                        self.calls[k] = self.calls.get(k, 0) + 1


def scan_lcs(path, rel):
    with open(path, encoding='utf-8-sig', errors='replace') as f:
        raw = f.read().splitlines()
    u = Unit(rel, 'lcs')
    if raw:
        m = re.match(r'^\s*script\s+"([^"]+)"', raw[0], re.I)
        if m:
            u.stack_names.append(m.group(1))
    u.objects = 1
    u.scripted_objects = 1
    u.scan_script(raw)
    return u


OBJ_RE = re.compile(r'^== (.*)$')
ESC_RE = re.compile(r'\\(.)')
ESCAPES = {'\\': '\\', 'r': '\r', 'n': '\n', 't': '\t'}


def unescape(value):
    """Undo ide-stack-dump.livecodescript's escapeValue, which writes a
    backslash, CR, LF and tab as \\\\, \\r, \\n and \\t: a tab-indented line
    must reach the scanner with its tabs, or its first word is not seen."""
    return ESC_RE.sub(lambda m: ESCAPES.get(m.group(1), m.group(0)), value)


def scan_dump(dump_path, rel):
    u = Unit(rel, 'binary')
    cur_script = []
    with open(dump_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('| '):
                cur_script.append(unescape(line[2:]))
                continue
            if line == '|':
                cur_script.append('')
                continue
            if cur_script:
                u.scan_script(cur_script)
                u.scripted_objects += 1
                cur_script = []
            m = OBJ_RE.match(line)
            if m:
                u.objects += 1
                p = m.group(1)
                # the dump labels a substack 'stack "Main" > substack "Sub"'
                sm = re.match(r'^stack "([^"]*)"(?: > (?:sub)?stack "([^"]*)")?$', p)
                if sm:
                    name = sm.group(2) or sm.group(1)
                    if name not in u.stack_names:
                        u.stack_names.append(name)
                continue
            if line.startswith('prop behavior: ') and len(line) > 15:
                for r in STACKREF_RE.findall(line):
                    u.behaviors.add(r)
    if cur_script:
        u.scan_script(cur_script)
        u.scripted_objects += 1
    return u
