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

"""Build the data behind the OXT-Beyond codebase map (map-data.json) and
the page itself (index.html for any web host, codebase-map.html for a
claude.ai Artifact), both from template.html. The GitHub Pages workflow
(.github/workflows/pages.yml) runs it and puts index.html at <site>/map/.

  python3 tools/codebase-map/build_map.py --beyond . --suite xtalk-suite \
      --dumps DUMPDIR --d3 package/dist/d3.min.js --out OUTDIR

DUMPDIR holds text dumps of the binary IDE stacks, one per stack, made by
make_dumps.sh with a released engine (tools/oxt/ide-stack-dump.livecodescript).
Without it the binary stacks' scripts are left out and the page says so.

Everything here is read-only and lexical: it reads files and git history
and never builds or runs the code it maps. Where a number is an
approximation the page says how it was counted.
"""

import argparse
import ast
import collections
import datetime
import glob
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lcs  # noqa: E402

try:
    import yaml
except ImportError:  # the CI section is skipped without PyYAML
    yaml = None

# ---------------------------------------------------------------------------
# Areas: the boxes of the overview. Rules are matched in order on the path
# relative to the repository root; the first match wins.

AREAS = [
    # id, title, layer, description
    ('engine', 'Engine (C++)', 'engine', 'engine/src: the script interpreter, objects, stack file format, rendering, platform layers and the development/standalone/server/installer modes.'),
    ('engine-lcb', 'Engine LCB modules', 'engine', 'engine/src/*.lcb: the builder modules compiled into the engine (canvas, engine, widget, browser, emscripten).'),
    ('libfoundation', 'libfoundation', 'libs', 'Values, strings, arrays, Unicode, FFI: everything else is built on it.'),
    ('libgraphics', 'libgraphics', 'libs', '2D graphics over Skia.'),
    ('libscript', 'libscript (LCB VM)', 'libs', 'The LiveCode Builder virtual machine and its standard library modules.'),
    ('libcore', 'libcore / libexternal', 'libs', 'Support code for externals (the revdb, revxml, revzip ... plugins).'),
    ('libbrowser', 'libbrowser (CEF)', 'libs', 'The browser widget\'s native layer (Chromium Embedded Framework).'),
    ('toolchain', 'Toolchain (lc-compile)', 'build', 'lc-compile, lc-run, lcidlc: build tools that compile LCB and external interfaces.'),
    ('externals', 'Externals', 'libs', 'revdb (+ database drivers), revxml, revzip, revbrowser, revpdfprinter, revspeech, revvideograbber, mergJSON, revmobile.'),
    ('thirdparty', 'Third-party & prebuilt', 'libs', 'thirdparty/ (vendored) and prebuilt/ (fetched): ICU, Skia, OpenSSL, CEF, SQLite, libxml ...'),
    ('lcb-ext', 'LCB extensions', 'ext', 'extensions/widgets, libraries, modules: the widgets and libraries shipped with the IDE.'),
    ('lcs-ext', 'Script-library extensions', 'ext', 'extensions/script-libraries: httpd, oauth2, mime, qr, diff ... shipped as script-only stacks.'),
    ('ide-boot', 'IDE start-up (home)', 'ide', 'ide/Toolset/home.livecodescript: the stack the engine opens first in development mode; it loads every library in a fixed order.'),
    ('ide-lib', 'IDE libraries', 'ide', 'ide/Toolset/libraries and ide-support: script libraries in the message path (front, back and "start using").'),
    ('ide-palette', 'IDE palettes & dialogs', 'ide', 'ide/Toolset/palettes: script editor, inspector, message box, project browser, menubar, tools, dictionary ...'),
    ('ide-ext', 'IDE plugins & extensions', 'ide', 'ide/Extensions and ide/Plugins: MCP bridge, xTalk assistant, OXT Lite functions, widgets shipped prebuilt.'),
    ('ide-resources', 'IDE resources & examples', 'ide', 'ide/Resources, ide/examples, ide/Documentation stacks: samples and help stacks.'),
    ('docs', 'Docs & dictionary', 'docs', 'docs/: dictionary entries, guides, release notes. The IDE builds its dictionary from them.'),
    ('tests', 'Tests', 'qa', 'tests/ (engine + LCB + LCS suites) and ide/tests.'),
    ('ci', 'CI checks', 'build', 'tools/ci and .github/workflows: builds, smoke test, IDE compile check, engine tests, screenshots.'),
    ('packaging', 'Packaging & build scripts', 'build', 'tools/oxt, builder/, Installer/, config/, gyp, Makefiles: packages, stack patches, installers.'),
    ('web', 'Web IDE & web player', 'web', 'tools/web-ide, tools/web-player and the Emscripten engine (engine/src/em-*).'),
    ('suite', 'xTalk Suite (pinned)', 'suite', 'Extensions built from the xtalk-suite member repositories at pinned commits (tools/oxt/xtalk-extensions.json).'),
    ('other', 'Other', 'other', 'Everything else (root docs, util, ...).'),
]
AREA_IDS = [a[0] for a in AREAS]

RULES = [
    (r'^engine/src/em-', 'web'),
    (r'^engine/src/.*\.lcb$', 'engine-lcb'),
    (r'^engine/', 'engine'),
    (r'^libfoundation/', 'libfoundation'),
    (r'^libgraphics/', 'libgraphics'),
    (r'^libscript/', 'libscript'),
    (r'^(libcore|libexternal|libexternalv1)/', 'libcore'),
    (r'^libbrowser/', 'libbrowser'),
    (r'^(toolchain|lcidlc)/', 'toolchain'),
    (r'^(revdb|revxml|revzip|revbrowser|revpdfprinter|revspeech|revvideograbber|mergjson|revmobile)/', 'externals'),
    (r'^(thirdparty|prebuilt)/', 'thirdparty'),
    (r'^extensions/script-libraries/', 'lcs-ext'),
    (r'^extensions/', 'lcb-ext'),
    (r'^ide/Toolset/home\.livecodescript$', 'ide-boot'),
    (r'^ide/Toolset/libraries/', 'ide-lib'),
    (r'^ide-support/', 'ide-lib'),
    (r'^ide/Toolset/', 'ide-palette'),
    (r'^ide/(Extensions|Plugins)/', 'ide-ext'),
    (r'^ide/tests/', 'tests'),
    (r'^ide/', 'ide-resources'),
    (r'^docs/', 'docs'),
    (r'^tests/', 'tests'),
    (r'^tools/(web-ide|web-player)/', 'web'),
    (r'^tools/ci/', 'ci'),
    (r'^\.github/', 'ci'),
    (r'^(tools|builder|Installer|config|gyp|util)/', 'packaging'),
    (r'^(Makefile|config\.|configure|make\.cmd|livecode\.gyp|common\.gypi|version)', 'packaging'),
]
RULES = [(re.compile(p), a) for p, a in RULES]


def area_of(rel):
    for r, a in RULES:
        if r.search(rel):
            return a
    return 'other'


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), check=True,
                          capture_output=True, text=True, errors='replace').stdout


def tracked_files(repo):
    return [l for l in git(repo, 'ls-files').splitlines() if l]


# ---------------------------------------------------------------------------
# Build graph (gyp)

def walk_deps(node, acc):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == 'dependencies' and isinstance(v, list):
                acc.update(x for x in v if isinstance(x, str))
            else:
                walk_deps(v, acc)
    elif isinstance(node, list):
        for x in node:
            walk_deps(x, acc)


def gyp_graph(root, files):
    targets = {}
    for rel in files:
        if not rel.endswith('.gyp') or rel.startswith(('gyp/', 'thirdparty/')):
            continue
        try:
            d = ast.literal_eval(open(os.path.join(root, rel)).read())
        except Exception:
            continue
        for t in d.get('targets', []):
            acc = set()
            walk_deps(t, acc)
            tid = rel + ':' + t['target_name']
            targets[tid] = dict(id=tid, name=t['target_name'], file=rel, area=area_of(rel),
                                type=t.get('type', ''), deps=sorted(acc))
    # resolve "../x/y.gyp:name#host" relative to the declaring file
    edges = []
    for tid, t in list(targets.items()):
        base = os.path.dirname(t['file'])
        for dep in t['deps']:
            if dep.startswith('<'):
                continue
            dep = dep.split('#')[0]
            if ':' in dep:
                f, n = dep.rsplit(':', 1)
                f = os.path.normpath(os.path.join(base, f))
            else:
                f, n = t['file'], dep
            did = f + ':' + n
            if did not in targets:
                # thirdparty / prebuilt targets: keep them as leaves
                targets.setdefault(did, dict(id=did, name=n, file=f, area=area_of(f), type='', deps=[]))
            edges.append((tid, did))
    for t in targets.values():
        t.pop('deps', None)
    return list(targets.values()), sorted(set(edges))


# ---------------------------------------------------------------------------
# Engine C++: subsystems, header fan-in, globals, messages

ENGINE_SUBSYS = [
    ('platform-win', r'^(w32|dskw32|sysw32|native-layer-win32|windows-theme)'),
    ('platform-mac', r'^(mac|osx|dskmac|sysosx|syscf|cgimage|tilecachecg|build_macarm)|\.mm$'),
    ('platform-linux', r'^(lnx|dsklnx|syslnx|linux-theme|native-layer-x11)'),
    ('platform-mobile', r'^(mbl|native-layer-android|java)'),
    ('platform-web', r'^em-'),
    ('server', r'^(srv|mode_server|native-layer-srv|player-srv)'),
    ('modes', r'^(mode_|dskmain|main\.|dummystartup|internal|license|securemode|test\.)'),
    ('deploy', r'^(deploy|bsdiff|capsule|minizip)'),
    ('stackfile', r'^(stackfileformat|objectstream|stack3|stacke|pickle|dump_stack|stacksecurity|stackcache|ide\.|hc)'),
    ('interpreter', r'^(exec|cmds|funcs|handler|hndlrlst|express|operator|property|variable|scriptpt|keywords|lextable|statemnt|literal|chunk|param|parentscript|debug|mcerror|combiners|newobj|dispatch|fiber|eventqueue)'),
    ('lcb-bridge', r'^(module-|widget|legacy_spec|foundation-legacy|jsobject|external)'),
    ('text-fields', r'^(field|paragra|block|text|styledtext|rtf|segment|line\.|font|fonttable|customfont|freetype|skiatypeface|unicode)'),
    ('objects', r'^(object|button|card|stack|group|control|image|graphic|player|scrol|aclip|vclip|eps|magnify|tooltip|cardlst|stacklst|cdata|undolst|sellst|edittool|imagelist|objptr|cpalette|stackview|stacktile|respring|notify|visual|menuparse|platform-player|player)'),
    ('graphics', r'^(context|graphics|metacontext|redraw|tilecache|surface|region|path|gradient|bitmapeffect|color|rgb|idraw|i[a-z]+\.cpp|image_rep|imagebitmap|imageloader|iquant|itransform|iutil|glcontext|resolution|uidc|platform)'),
    ('os-services', r'^(sys|socket|opensslsocket|mcssl|mcio|filepath|clipboard|raw-clipboard|desktop|printer|customprinter|ports|prefix|date|util|mcutility|md5|sha|uuid|mcmessagedigest|regex|patternmatcher|mcstring|globals|mctheme|quicktime|dllst)'),
]
ENGINE_SUBSYS = [(n, re.compile(p)) for n, p in ENGINE_SUBSYS]


def engine_subsys(name):
    for n, r in ENGINE_SUBSYS:
        if r.search(name):
            return n
    return 'misc'


INCLUDE_RE = re.compile(r'^\s*#\s*include\s+"([^"]+)"', re.M)


def engine_analysis(root):
    src = os.path.join(root, 'engine', 'src')
    files = sorted(f for f in os.listdir(src) if f.endswith(('.cpp', '.mm', '.h', '.c')))
    texts = {}
    for f in files:
        with open(os.path.join(src, f), encoding='utf-8', errors='replace') as fh:
            texts[f] = fh.read()
    headers = set(f for f in files if f.endswith('.h'))
    include_fanin = collections.Counter()
    includes = {}
    for f, t in texts.items():
        inc = set(os.path.basename(i) for i in INCLUDE_RE.findall(t))
        inc &= headers
        includes[f] = inc
        for h in inc:
            include_fanin[h] += 1
    # transitive reach of each header: how many source files see it at all
    rev = collections.defaultdict(set)
    for f, inc in includes.items():
        for h in inc:
            rev[h].add(f)
    reach = {}
    for h in headers:
        seen, stack = set(), [h]
        while stack:
            x = stack.pop()
            for y in rev.get(x, ()):
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        reach[h] = sum(1 for y in seen if not y.endswith('.h'))
    sources = [f for f in files if not f.endswith('.h')]
    tokens = {f: set(re.findall(r'\bMC\w+', texts[f])) for f in files}
    # subsystem graph by includes (a source's subsystem -> the header's)
    sub_edges = collections.Counter()
    sub_files = collections.Counter()
    sub_lines = collections.Counter()
    for f in sources:
        s = engine_subsys(f)
        sub_files[s] += 1
        sub_lines[s] += texts[f].count('\n')
        for h in includes[f]:
            hs = engine_subsys(h)
            if hs != s:
                sub_edges[(s, hs)] += 1
    # globals declared extern in globals.h and how many sources use each
    gdecl = re.findall(r'^extern\s+[^;()]*?\b(MC\w+)\s*(?:\[[^\]]*\])?\s*;', texts.get('globals.h', ''), re.M)
    gl = []
    for g in sorted(set(gdecl)):
        users = [f for f in sources if g in tokens[f]]
        gl.append(dict(name=g, files=len(users),
                       subsystems=sorted(set(engine_subsys(u) for u in users))))
    gl.sort(key=lambda x: (-x['files'], x['name']))
    # engine messages (MCM_*) and which sources send each
    msgs = re.findall(r'\{\s*"([^"]+)"\s*,\s*&(MCM_\w+)\s*\}', texts.get('mcstring.cpp', ''))
    messages = []
    for text, sym in msgs:
        users = [f for f in sources if f != 'mcstring.cpp' and sym in tokens[f]]
        messages.append(dict(name=text, symbol=sym, senders=len(users),
                             sender_files=users[:12]))
    # development-mode-only properties (the IDE relies on them)
    # IDE-facing properties: the rev* and _* properties of the lexer table
    # (revAvailableHandlers, _ideOverride, ...), which exist for the IDE.
    lex = open(os.path.join(src, 'lextable.cpp'), encoding='utf-8', errors='replace').read()
    devprop_names = re.findall(r'\{\s*"((?:rev|_)[a-z_]+)"\s*,\s*TT_PROPERTY', lex)
    top_headers = sorted(headers, key=lambda h: (-reach[h], h))[:40]
    return dict(
        files=len(sources), headers=len(headers),
        lines=sum(texts[f].count('\n') for f in files),
        subsystems=[dict(id=s, files=sub_files[s], lines=sub_lines[s]) for s in sorted(sub_files, key=lambda s: (-sub_lines[s], s))],
        subsystem_edges=[dict(src=a, dst=b, n=n) for (a, b), n in sorted(sub_edges.items(), key=lambda e: (-e[1], e[0]))],
        headers_top=[dict(name=h, direct=include_fanin[h], reach=reach[h], subsystem=engine_subsys(h)) for h in top_headers],
        globals_top=gl[:60], globals_count=len(gl),
        messages=messages, devprops=sorted(set(devprop_names)),
    )


# ---------------------------------------------------------------------------
# LCB modules

def lcb_analysis(root, files):
    mods = []
    for rel in files:
        if not rel.endswith('.lcb') or rel.startswith(('thirdparty/', 'tests/')):
            continue
        try:
            t = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        t2 = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
        t2 = re.sub(r'(--|//).*', '', t2)
        m = re.search(r'^\s*(module|library|widget)\s+([\w.]+)', t2, re.M)
        if not m:
            continue
        uses = sorted(set(re.findall(r'^\s*use\s+([\w.]+)\s*$', t2, re.M)))
        binds = len(re.findall(r'\bbinds\s+to\b', t2))
        mods.append(dict(name=m.group(2), kind=m.group(1), file=rel, area=area_of(rel),
                         uses=uses, foreign=binds, lines=t.count('\n')))
    names = set(x['name'] for x in mods)
    fanin = collections.Counter(u for x in mods for u in x['uses'])
    for x in mods:
        x['used_by'] = fanin.get(x['name'], 0)
    # modules used but not defined in this repo (engine-provided or stdlib)
    ext = sorted((u, n) for u, n in fanin.items() if u not in names)
    return dict(modules=mods, external_uses=[dict(name=u, used_by=n) for u, n in ext])


# ---------------------------------------------------------------------------
# Scripts

def script_units(root, files, dumps):
    units = []
    for rel in files:
        if rel.endswith('.livecodescript') and not rel.startswith('thirdparty/'):
            units.append(lcs.scan_lcs(os.path.join(root, rel), rel))
    binaries = [rel for rel in files if rel.endswith(('.livecode', '.rev', '.oxtstack'))
                and rel.startswith(('ide/', 'ide-support/'))]
    missing = []
    for rel in binaries:
        d = os.path.join(dumps, rel.replace('/', '_').replace(' ', '_') + '.txt') if dumps else None
        if d and os.path.exists(d):
            units.append(lcs.scan_dump(d, rel))
        else:
            missing.append(rel)
    return units, missing


def boot_order(root):
    """The library load order in home.livecodescript (revInternal__InitialiseLibraries)."""
    t = open(os.path.join(root, 'ide/Toolset/home.livecodescript'), encoding='utf-8', errors='replace').read()
    load = re.findall(r'put\s+(?:return\s*&\s*)?"([^"]+)"\s+(?:into|after)\s+tLoadList', t)
    back = re.findall(r'put\s+(?:return\s*&\s*)?"([^"]+)"\s+(?:into|after)\s+tBackList', t)
    first = re.findall(r'insert script of stack "([^"]+)" into back', t)
    return dict(load=load, back=back, first_back=first)


def analyse_scripts(units, engine_messages, devprops):
    by_stack = {}
    for i, u in enumerate(units):
        u.id = i
        u.area = area_of(u.path)
        for s in u.stack_names:
            by_stack.setdefault(s.lower(), i)
    engine_msg = set(m['name'].lower() for m in engine_messages)

    # public handler definers (tests and examples excluded from "providers")
    def is_product(u):
        return u.area not in ('tests', 'ide-resources', 'ci', 'web', 'packaging', 'docs', 'other')
    definers = collections.defaultdict(list)
    for u in units:
        for k, d in u.defs.items():
            if not d['private']:
                definers[k].append(u.id)

    # edges unit -> unit
    edges = collections.Counter()
    callers_of = collections.defaultdict(lambda: collections.defaultdict(int))  # handler -> unit -> n
    for u in units:
        for k, n in list(u.calls.items()) + list(u.sends.items()):
            ds = definers.get(k)
            if not ds or k in engine_msg:
                continue
            if u.id in ds:
                continue  # resolves locally first
            if len(ds) > 4:
                continue  # a polymorphic message, not a call to one library
            # Old help and example stacks carry copies of library handlers;
            # a call resolves to the product's own definition when there is one.
            prod = [d for d in ds if is_product(units[d])]
            if prod:
                ds = prod
            callers_of[k][u.id] += n
            for d in ds:
                edges[(u.id, d, 'call')] += n
        for s, n in u.stackrefs.items():
            t = by_stack.get(s)
            if t is not None and t != u.id:
                edges[(u.id, t, 'stack')] += n
        for s in u.behaviors:
            t = by_stack.get(s.lower())
            if t is not None and t != u.id:
                edges[(u.id, t, 'behavior')] += 1

    # globals
    glob_users = collections.defaultdict(set)
    for u in units:
        for g in u.globals:
            glob_users[g.lower()].add(u.id)
    glob_names = {}
    for u in units:
        for g in sorted(u.globals):  # a set: sorted, so a run's spelling is the next run's
            glob_names.setdefault(g.lower(), g)

    # IDE bus
    pubs = collections.defaultdict(set)
    subs = collections.defaultdict(set)
    for u in units:
        for p in u.publishes:
            pubs[p].add(u.id)
        for s in u.subscribes:
            subs[s].add(u.id)

    # front/back script inserts
    inserts = collections.defaultdict(set)
    for u in units:
        for s, where in u.inserts:
            inserts[(s.lower(), where)].add(u.id)
        for s in u.using:
            inserts[(s.lower(), 'using')].add(u.id)
        if u.kind == 'lcs' and u.stack_names:
            for where in u.self_inserts:
                inserts[(u.stack_names[0].lower(), where)].add(u.id)

    return dict(by_stack=by_stack, definers=definers, edges=edges, callers_of=callers_of,
                glob_users=glob_users, glob_names=glob_names, pubs=pubs, subs=subs,
                inserts=inserts, engine_msg=engine_msg, is_product=is_product)


# ---------------------------------------------------------------------------
# CI

PATH_TOKEN = re.compile(r'(?<![\w/.-])((?:tools|engine|ide|ide-support|extensions|docs|tests|builder|Installer|config|prebuilt|thirdparty|libfoundation|libscript|libgraphics|toolchain)/[\w./ -]*[\w])')


def ci_analysis(root, files):
    out = []
    if yaml is None:
        return out
    for rel in sorted(f for f in files if f.startswith('.github/workflows/') and f.endswith(('.yml', '.yaml'))):
        text = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read()
        try:
            y = yaml.safe_load(text)
        except Exception:
            continue
        on = y.get(True) or y.get('on') or {}
        triggers = []
        paths = []
        if isinstance(on, dict):
            for k, v in on.items():
                triggers.append(k)
                if isinstance(v, dict):
                    paths += v.get('paths', []) or []
        elif isinstance(on, list):
            triggers = on
        elif isinstance(on, str):
            triggers = [on]
        jobs = []
        for jid, j in (y.get('jobs') or {}).items():
            if not isinstance(j, dict):
                continue
            uses = j.get('uses')
            jobs.append(dict(id=jid, name=str(j.get('name', jid)), needs=j.get('needs') if isinstance(j.get('needs'), list) else ([j['needs']] if j.get('needs') else []),
                             calls=uses or ''))
        scripts = sorted(set(m.strip() for m in PATH_TOKEN.findall(text) if not m.endswith(('.txt', '.log'))))
        scripts = [s for s in scripts if any(s == f or f.startswith(s + '/') for f in files[:0]) or os.path.exists(os.path.join(root, s))]
        out.append(dict(file=rel, name=str(y.get('name', rel)), triggers=[str(t) for t in triggers],
                        paths=paths, jobs=jobs, scripts=scripts))
    return out


# ---------------------------------------------------------------------------
# History

FIX_RE = re.compile(r'\b(fix|fixes|fixed|crash|regress|broke|broken|restore|revert)', re.I)


def history(repo, since):
    log = git(repo, 'log', '--no-merges', '--since', since, '--name-only', '--format=@@%H%x09%cd%x09%s', '--date=short', 'HEAD')
    commits = []
    cur = None
    for line in log.splitlines():
        if line.startswith('@@'):
            h, d, s = (line[2:].split('\t', 2) + ['', ''])[:3]
            cur = dict(h=h, d=d, s=s, files=[])
            commits.append(cur)
        elif line.strip() and cur is not None:
            cur['files'].append(line.strip())
    # In a shallow clone the oldest commit has no parent to compare with, so
    # git lists every file of the tree as changed by it, one more change for
    # each file in the churn. Its own changes are not known: drop its files.
    shallow = git(repo, 'rev-parse', '--git-path', 'shallow').strip()
    if not os.path.isabs(shallow):
        shallow = os.path.join(repo, shallow)
    if os.path.exists(shallow):
        cut = set(open(shallow).read().split())
        for c in commits:
            if c['h'] in cut:
                print('history: %s is a shallow clone\'s oldest commit; its files are left out' % c['h'][:10])
                c['files'] = []
    churn = collections.Counter()
    fixes = collections.Counter()
    pairs = collections.Counter()
    for c in commits:
        fs = [f for f in c['files'] if not f.startswith(('thirdparty/', 'changelog/', 'docs/notes/')) and not f.endswith(('.png', '.md'))]
        isfix = bool(FIX_RE.search(c['s']))
        for f in fs:
            churn[f] += 1
            if isfix:
                fixes[f] += 1
        if 1 < len(fs) <= 12:
            for i in range(len(fs)):
                for j in range(i + 1, len(fs)):
                    a, b = sorted((fs[i], fs[j]))
                    pairs[(a, b)] += 1
    first = min((c['d'] for c in commits), default=since)
    days = collections.defaultdict(lambda: collections.Counter())
    daycommits = collections.Counter()
    for c in commits:
        daycommits[c['d']] += 1
        for ar in set(area_of(f) for f in c['files']):
            days[c['d']][ar] += 1  # commits that touched the area that day
    daily = [dict(d=d, commits=daycommits[d], areas=dict(days[d])) for d in sorted(daycommits)]
    return dict(commits=len(commits), since=first, churn=churn, fixes=fixes, pairs=pairs, daily=daily)


MONTHS = {m: i + 1 for i, m in enumerate('jan feb mar apr may jun jul aug sep oct nov dec'.split())}


def parse_hist_date(text):
    """'25-27 Sep 2023' -> ('2023-09-25', False); 'Nov 2023 (approx.)' -> ('2023-11-15', True)."""
    m = re.search(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b', text, re.I)
    y = re.search(r'\b(20\d\d)\b', text)
    if not m or not y:
        return None, True
    before = text[:m.start()]
    d = re.match(r'\s*(\d{1,2})\b', before)
    approx = d is None or 'approx' in text
    day = int(d.group(1)) if d else 15
    return '%s-%02d-%02d' % (y.group(1), MONTHS[m.group(1).lower()[:3]], day), approx


def lineage(root):
    """The OpenXTalk Lite versions table of HISTORY.md, as dated points."""
    t = open(os.path.join(root, 'HISTORY.md'), encoding='utf-8').read()
    rows = []
    sec = t[t.index('### Versions'):t.index('### Engines')]
    for line in sec.splitlines():
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) != 5 or cells[0] in ('Version', '---'):
            continue
        iso, approx = parse_hist_date(cells[1])
        if iso:
            text = re.sub(r'[`*]', '', cells[4])
            rows.append(dict(v=cells[0], date=cells[1], iso=iso, approx=approx, text=text))
    return rows


def releases(repo):
    out = git(repo, 'tag', '--sort=creatordate', '--format=%(refname:short) %(creatordate:short)')
    rel = []
    for line in out.splitlines():
        name, _, d = line.partition(' ')
        if name.startswith('v'):
            rel.append(dict(tag=name, d=d, rc='-rc' in name))
    return rel


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--beyond', required=True)
    ap.add_argument('--suite')
    ap.add_argument('--dumps')
    ap.add_argument('--out', required=True)
    ap.add_argument('--since', default='2026-05-01')
    ap.add_argument('--d3', help='d3 7.9.0 dist/d3.min.js to inline into index.html (npm pack d3@7.9.0); '
                    'without it index.html loads d3 from cdnjs')
    ap.add_argument('--d3-license', help="d3's LICENSE, put above the inlined copy (ISC asks for its notice); "
                    'default: the LICENSE of the npm package that holds --d3')
    ap.add_argument('--template', default=os.path.join(HERE, 'template.html'))
    a = ap.parse_args()
    root = a.beyond
    files = tracked_files(root)
    head = git(root, 'log', '-1', '--format=%h %ad %s', '--date=short').strip()

    # file inventory per area
    inv = collections.defaultdict(lambda: dict(files=0, bytes=0, ext=collections.Counter()))
    for rel in files:
        ar = area_of(rel)
        try:
            sz = os.path.getsize(os.path.join(root, rel))
        except OSError:
            sz = 0
        inv[ar]['files'] += 1
        inv[ar]['bytes'] += sz
        inv[ar]['ext'][os.path.splitext(rel)[1].lower() or '(none)'] += 1

    targets, gedges = gyp_graph(root, files)
    eng = engine_analysis(root)
    lcb = lcb_analysis(root, files)
    units, missing = script_units(root, files, a.dumps)
    S = analyse_scripts(units, eng['messages'], eng['devprops'])
    boot = boot_order(root)
    ci = ci_analysis(root, files)
    hist = history(root, a.since)

    # ---- script units for the page
    uid_churn = {}
    U = []
    fanin_units = collections.defaultdict(set)
    fanout_units = collections.defaultdict(set)
    for (s, d, kind), n in S['edges'].items():
        if units[s].area == 'tests':
            continue
        fanin_units[d].add(s)
        fanout_units[s].add(d)
    test_refs = collections.defaultdict(set)
    for (s, d, kind), n in S['edges'].items():
        if units[s].area == 'tests' or units[s].path.startswith('tools/ci/'):
            test_refs[d].add(s)

    loaded = {}
    for i, n in enumerate(boot['first_back']):
        loaded[n.lower()] = 'back (first)'
    for n in boot['load']:
        loaded.setdefault(n.lower(), 'library (start using)')
    for n in boot['back']:
        loaded.setdefault(n.lower(), 'backscript')
    for (s, where), us in S['inserts'].items():
        if not any(units[x].area.startswith('ide') for x in us):
            continue  # a CI or test script putting itself in the path
        if where == 'front':
            loaded[s] = 'frontscript'
        else:
            loaded.setdefault(s, {'back': 'backscript', 'using': 'library (start using)'}[where])

    # libraries some script unloads at run time (revInternal__UnloadLibrary):
    # Suppress Messages, the reshape and rulers tools ...
    unloaded = set()
    for u in units:
        unloaded |= u.unloads
    for u in units:
        pub = [d for d in u.defs.values() if not d['private']]
        role = ''
        for s in u.stack_names:
            if s.lower() in loaded:
                role = loaded[s.lower()]
                break
        if role == 'frontscript' and (u.transient_front or any(s.lower() in unloaded for s in u.stack_names)):
            role = 'frontscript (while active)'
        U.append(dict(
            id=u.id, path=u.path, area=u.area, kind=u.kind, stacks=u.stack_names[:8],
            nstacks=len(u.stack_names), lines=u.lines, objects=u.objects,
            handlers=len(u.defs), public=len(pub),
            globals=sorted(u.globals), role=role,
            fanin=len(fanin_units[u.id]), fanout=len(fanout_units[u.id]),
            tests=len(test_refs[u.id]), test_ids=sorted(test_refs[u.id])[:30],
            churn=hist['churn'].get(u.path, 0), fixes=hist['fixes'].get(u.path, 0),
            pubs=sorted(u.publishes), subs=sorted(u.subscribes),
        ))

    E = [dict(s=s, d=d, k=k, n=n) for (s, d, k), n in sorted(S['edges'].items())
         if units[s].area != 'tests']

    # ---- handler index (public handlers of product units, with callers)
    H = []
    for k, ds in S['definers'].items():
        prod = [d for d in ds if S['is_product'](units[d])]
        if not prod:
            continue
        callers = S['callers_of'].get(k, {})
        cu = [c for c in callers if units[c].area != 'tests']
        tu = [c for c in callers if units[c].area == 'tests']
        d0 = units[prod[0]].defs[k]
        H.append(dict(name=d0['name'], kind=d0['kind'], defs=prod, callers=sorted(cu)[:60],
                      ncallers=len(cu), tests=len(tu), engine=k in S['engine_msg']))
    H.sort(key=lambda h: (-h['ncallers'], h['name'].lower()))

    # ---- duplicate public handlers among message-path libraries
    # Search order of the message path after the user's stack, from the engine:
    # frontscripts first (before the target), then libraries newest first
    # (MCDispatch::handle walks MCusing from the end; start using appends),
    # then backscripts newest first (insert script puts the new one at the head,
    # MCDLlist::insertto). Lower rank is searched earlier.
    load_idx = {n.lower(): i for i, n in enumerate(boot['load'])}
    back_seq = [n.lower() for n in boot['first_back'] + boot['back']]

    def path_rank(u):
        names = [s.lower() for s in u['stacks']]
        r = u['role']
        if r.startswith('front'):
            return 0
        if r.startswith('library'):
            for n in names:
                if n in load_idx:
                    return 1000 - load_idx[n]
            return 900  # started later (plugins, on demand): searched before boot libraries
        if r.startswith('back'):
            for n in names:
                if n in back_seq:
                    return 2000 + (len(back_seq) - back_seq.index(n))
            return 1999
        return 3000
    bus_names = set(x.lower() for x in list(S['pubs']) + list(S['subs']))
    path_units = [u for u in U if u['role']]
    path_ids = set(u['id'] for u in path_units)
    dups = []
    for k, ds in S['definers'].items():
        inpath = [d for d in ds if d in path_ids]
        if (len(inpath) >= 2 and k not in S['engine_msg'] and k not in bus_names
                and k not in ('extensioninitialize', 'extensionfinalize')):
            ranks = sorted((path_rank(U[d]), d) for d in inpath)
            winner = ranks[0][1] if ranks[0][0] < 0 or ranks[0][0] != ranks[1][0] else None
            if ranks[0][0] < 1000 and ranks[1][0] < 1000 and U[ranks[0][1]]['role'].startswith('front'):
                winner = None  # frontscript order is decided at run time
            dups.append(dict(name=units[inpath[0]].defs[k]['name'], units=inpath, winner=winner))
    dups.sort(key=lambda x: (-len(x['units']), x['name'].lower()))

    # ---- engine messages handled in the message path (front/back scripts)
    intercepts = []
    for m in eng['messages']:
        k = m['name'].lower()
        hs = [d for d in S['definers'].get(k, []) if d in path_ids]
        if hs:
            nopass = []
            for d in hs:
                if not _passes(units[d], k):
                    nopass.append(d)
            intercepts.append(dict(name=m['name'], senders=m['senders'], units=hs,
                                   sender_subsys=sorted(set(engine_subsys(f) for f in m['sender_files'])),
                                   front=[d for d in hs if U[d]['role'].startswith('frontscript')],
                                   nopass=nopass))
    intercepts.sort(key=lambda x: (-len(x['front']), -len(x['units']), x['name'].lower()))

    devprop_use = []
    for p in eng['devprops']:
        r = re.compile(r'\b' + re.escape(p) + r'\b', re.I)
        us = [u.id for u in units if p.lower() in u.props]
        devprop_use.append(dict(name=p, units=us))

    # ---- globals table
    G = []
    for k, us in S['glob_users'].items():
        us = sorted(us)
        prod = [x for x in us if units[x].area not in ('tests',)]
        G.append(dict(name=S['glob_names'][k], units=prod, n=len(prod)))
    G.sort(key=lambda g: (-g['n'], g['name'].lower()))

    # ---- IDE bus
    B = []
    for m in sorted(set(S['pubs']) | set(S['subs']), key=str.lower):
        B.append(dict(name=m, pubs=sorted(S['pubs'].get(m, ())), subs=sorted(S['subs'].get(m, ()))))

    # ---- areas and area edges
    area_edges = collections.Counter()
    for t, d in gedges:
        ta = next((x['area'] for x in targets if x['id'] == t), None)
    tarea = {x['id']: x['area'] for x in targets}
    for t, d in gedges:
        if tarea[t] != tarea[d]:
            area_edges[(tarea[t], tarea[d], 'build')] += 1
    for e in E:
        sa, da = U[e['s']]['area'], U[e['d']]['area']
        if sa != da:
            area_edges[(sa, da, 'script')] += e['n']
    for m in lcb['modules']:
        for us in m['uses']:
            tgt = next((x for x in lcb['modules'] if x['name'] == us), None)
            da = tgt['area'] if tgt else ('engine-lcb' if us.startswith('com.livecode.') else None)
            if da and da != m['area']:
                area_edges[(m['area'], da, 'lcb')] += 1
    # hand-known edges that no scanner sees (each with its evidence)
    KNOWN = [
        ('engine', 'ide-boot', 'boot', 'In development mode the engine opens home.livecodescript (engine/src/mode_development.cpp, revInternal__ handlers in home).'),
        ('ide-boot', 'ide-lib', 'boot', 'home loads every library in a fixed order (revInternal__InitialiseLibraries).'),
        ('ide-lib', 'engine', 'boundary', 'The IDE reads development-only engine properties (revAvailableHandlers, ideOverride, ...) and handles engine messages in its front/back scripts.'),
        ('ide-lib', 'docs', 'build', 'The dictionary is built from docs/ at start-up (revInternal__BuildDictionary, revdocsparser).'),
        ('packaging', 'ide-palette', 'patch', 'tools/oxt/ide-stack-patch.sh applies tools/oxt/ide-stack-patches/* to binary stacks; CI checks every patch is applied.'),
        ('packaging', 'suite', 'pin', 'tools/oxt/xtalk_extensions.py fetches and builds the pinned suite extensions.'),
        ('web', 'engine', 'build', 'The web IDE runs the Emscripten build of the engine (engine/src/em-*, tools/ci/build-web-ide.sh).'),
        ('web', 'suite', 'pin', 'tools/web-ide/xtalk_web_libraries.py links the suite\'s wasm archives into the web engine (engine/src/em-xtalk-web.cpp).'),
        ('ci', 'ide-lib', 'check', 'The IDE compile check compiles every script, including those inside binary stacks (tools/ci/ide-compile-check.livecodescript).'),
        ('ci', 'engine', 'check', 'Engine tests (tools/ci/run_engine_tests.py) run tests/ against each build with per-platform baselines.'),
        ('lcb-ext', 'toolchain', 'build', 'Every .lcb is compiled with lc-compile.'),
        ('ide-ext', 'ide-lib', 'script', 'Plugins call IDE library handlers and subscribe to IDE messages.'),
    ]
    for s, d, k, why in KNOWN:
        area_edges[(s, d, k)] += 0

    areas = []
    for aid, title, layer, desc in AREAS:
        iv = inv.get(aid, dict(files=0, bytes=0, ext=collections.Counter()))
        su = [u for u in U if u['area'] == aid]
        areas.append(dict(id=aid, title=title, layer=layer, desc=desc, files=iv['files'], bytes=iv['bytes'],
                          ext=iv['ext'].most_common(6), units=len(su),
                          churn=sum(hist['churn'].get(f, 0) for f in files if area_of(f) == aid)))

    # ---- hot spots
    hot = []
    maxc = max([u['churn'] for u in U] + [1])
    for u in U:
        if u['area'] in ('tests', 'ide-resources', 'docs'):
            continue
        dup_n = sum(1 for d in dups if u['id'] in d['units'])
        glob_n = sum(1 for g in G if u['id'] in g['units'] and g['n'] >= 5)
        nopass = sum(1 for i in intercepts if u['id'] in i['nopass'] and u['role'] == 'frontscript')  # permanent ones only
        score = (u['fanin'] * 3 + min(u['churn'], 60) + dup_n * 2 + glob_n
                 + (25 if u['role'] else 0) + nopass * 5 + (u['lines'] // 2000))
        reasons = []
        if u['fanin']:
            reasons.append('%d scripts call into it' % u['fanin'])
        if u['role']:
            reasons.append('in the message path (%s): every stack\'s messages can reach it' % u['role'])
        if u['churn']:
            reasons.append('changed in %d commits since %s' % (u['churn'], hist['since']))
        if dup_n:
            reasons.append('%d handler names also defined by another message-path library' % dup_n)
        if glob_n:
            reasons.append('shares %d globals used by 5+ scripts' % glob_n)
        if nopass:
            reasons.append('%d engine messages caught in a frontscript without pass' % nopass)
        if u['tests'] == 0 and u['fanin']:
            reasons.append('no test or CI script references it')
        hot.append(dict(kind='script', id=u['id'], name=u['path'], area=u['area'], score=score, reasons=reasons))
    for h in eng['headers_top'][:25]:
        ch = hist['churn'].get('engine/src/' + h['name'], 0)
        hot.append(dict(kind='header', name='engine/src/' + h['name'], area='engine',
                        score=h['reach'] // 8 + ch * 3,
                        reasons=['seen by %d engine sources (directly by %d)' % (h['reach'], h['direct'])]
                        + (['changed in %d commits' % ch] if ch else [])))
    for t in targets:
        pass
    # most-changed engine sources (no static fan-in signal; churn + fixes)
    for f, n in hist['churn'].most_common(400):
        if f.startswith('engine/src/') and not f.endswith('.h'):
            hot.append(dict(kind='source', name=f, area=area_of(f), score=n * 2,
                            reasons=['changed in %d commits since %s' % (n, hist['since'])]))
    hot.sort(key=lambda h: -h['score'])

    # ---- co-change pairs that cross areas (hidden coupling)
    cochange = []
    for (a1, b1), n in hist['pairs'].most_common(3000):
        if n < 3:
            break
        noise = ('.github/ISSUE_TEMPLATE', 'ide/.version', 'ide/.codename', 'tests/', 'tools/ci/tests/', 'CHANGELOG', 'README')
        if area_of(a1) != area_of(b1) and not a1.startswith(noise) and not b1.startswith(noise):
            cochange.append(dict(a=a1, b=b1, n=n, aa=area_of(a1), ba=area_of(b1)))
        if len(cochange) >= 60:
            break

    # ---- suite
    suite = {}
    xj = json.load(open(os.path.join(root, 'tools/oxt/xtalk-extensions.json')))
    suite['members'] = [dict(name=m['name'], repository=m['repository'], commit=m['commit'][:10],
                             version=m.get('version', ''), files=[f['path'] for f in m['files'] if not f['path'].startswith('src/code/')],
                             natives=sum(1 for f in m['files'] if f['path'].startswith('src/code/')),
                             extensions=[(e.get('id') or e.get('name'), e.get('kind') or e.get('type')) for e in m.get('extensions', [])])
                        for m in xj['members']]
    wl = xj.get('web_libraries')
    wl = (wl or {}).get('libraries', []) if isinstance(wl, dict) else (wl or [])
    suite['web_libraries'] = [dict(name=v.get('name', ''), repository=v.get('repository', ''), commit=str(v.get('commit', ''))[:10], path=v.get('path', '')) for v in wl if isinstance(v, dict)]
    if a.suite and os.path.isdir(a.suite):
        sh = git(a.suite, 'log', '-1', '--format=%h %ad', '--date=short').strip()
        refs = []
        for rel in tracked_files(a.suite):
            if rel.startswith(('tools/', 'docs/')) and rel.endswith(('.py', '.md', '.sh', '.yml')):
                try:
                    t = open(os.path.join(a.suite, rel), encoding='utf-8', errors='replace').read()
                except OSError:
                    continue
                n = len(re.findall(r'OXT-Beyond|OpenXTalk-Beyond', t))
                if n:
                    refs.append(dict(file=rel, n=n))
        refs.sort(key=lambda r: -r['n'])
        suite['head'] = sh
        suite['refs'] = refs[:20]
        reg = os.path.join(a.suite, 'tools/member-registry.py')
        suite['registry'] = os.path.exists(reg)

    data = dict(
        generated=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        head=head, files=len(files),
        areas=areas,
        area_edges=[dict(s=s, d=d, k=k, n=n) for (s, d, k), n in area_edges.items()],
        known_edges=[dict(s=s, d=d, k=k, why=why) for s, d, k, why in KNOWN],
        gyp=dict(targets=targets, edges=[[s, d] for s, d in gedges]),
        engine=eng, lcb=lcb,
        units=U, edges=E, handlers=H, handlers_total=len(H),
        dups=dups, intercepts=intercepts, globals=G, bus=B, boot=boot,
        devprops=devprop_use,
        lineage=lineage(root), releases=releases(root),
        ci=ci, history=dict(commits=hist['commits'], since=hist['since'], daily=hist['daily'],
                            top=[dict(f=f, n=n, fixes=hist['fixes'][f], area=area_of(f)) for f, n in hist['churn'].most_common(60)]),
        cochange=cochange, hot=hot[:80], suite=suite,
        pairs=[[x, y, n] for (x, y), n in hist['pairs'].most_common(4000) if n >= 2],
        missing_dumps=missing,
    )
    os.makedirs(a.out, exist_ok=True)
    js = json.dumps(data, separators=(',', ':'))
    with open(os.path.join(a.out, 'map-data.json'), 'w') as f:
        f.write(js)
    if os.path.exists(a.template):
        tpl = open(a.template, encoding='utf-8').read()
        page = tpl.replace('/*MAP_DATA*/null', js.replace('</', '<\\/'))
        with open(os.path.join(a.out, 'codebase-map.html'), 'w', encoding='utf-8') as f:
            f.write(page)
        # The same page as a complete document for any static web host
        # (cPanel and the like): doctype, head, a theme switch, a favicon.
        lic = a.d3_license
        if a.d3 and not lic:
            guess = os.path.join(os.path.dirname(os.path.abspath(a.d3)), os.pardir, 'LICENSE')
            lic = guess if os.path.exists(guess) else None
        with open(os.path.join(a.out, 'index.html'), 'w', encoding='utf-8') as f:
            f.write(standalone(page, data['head'], a.d3, lic))
        print('index.html: d3 %s' % ('inlined from %s%s' % (a.d3, ' with its LICENSE' if lic else ', NO LICENSE found')
                                    if a.d3 else 'from cdnjs'))
    print('units', len(U), 'edges', len(E), 'handlers', len(H), 'dups', len(dups),
          'intercepts', len(intercepts), 'globals', len(G), 'bus', len(B), 'json', len(js))


FAVICON = ("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Crect width='32' height='32' rx='6' fill='%231f6aa5'/%3E"
           "%3Cpath d='M8 10h7v5H8zM17 17h7v5h-7zM8 22h7v-5' fill='none' stroke='white' stroke-width='2'/%3E"
           "%3Cpath d='M15 12.5h5.5V17' fill='none' stroke='white' stroke-width='2'/%3E%3C/svg%3E")


D3_CDN = '<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"></script>'


def standalone(page, head, d3_path=None, d3_license=None):
    """Wrap the artifact body in a full HTML document for static hosting.
    With d3_path (d3 7.9.0's dist/d3.min.js), d3 is inlined so the page
    needs no other host at all; ISC asks for its copyright and permission
    notice with every copy, so d3_license (its LICENSE) goes above it."""
    if d3_path:
        d3 = open(d3_path, encoding='utf-8').read().replace('</script', '<\\/script')
        notice = ''
        if d3_license:
            text = open(d3_license, encoding='utf-8').read().strip().replace('*/', '* /')
            notice = '/*\n' + text + '\n*/\n'
        page = page.replace(D3_CDN, '<script>\n' + notice + d3 + '\n</script>', 1)
    title_end = page.index('</title>') + len('</title>')
    top, rest = page[:title_end], page[title_end:]
    style_end = rest.index('</style>') + len('</style>')
    styles, body = rest[:style_end], rest[style_end:]
    top = top.replace('<meta charset="utf-8">\n', '')
    desc = ('Interactive map of the OXT-Beyond codebase: components, dependencies, the IDE message path, '
            'the engine-IDE boundary, CI coverage and risk hot spots. Built from main @ %s.' % head.split(' ')[0])
    extra_css = """
<style>
:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0;-webkit-font-smoothing:antialiased}
img{max-width:100%}
.theme-btn{font:600 .78rem var(--f-body);color:var(--muted);background:var(--soft);border:1px solid var(--line);border-radius:999px;padding:5px 12px;cursor:pointer}
.theme-btn:hover{color:var(--ink)}
footer.site{border-top:1px solid var(--line);background:var(--panel)}
footer.site .wrap{padding-block:16px;font-size:.8rem;color:var(--muted);display:flex;flex-wrap:wrap;gap:6px 18px;justify-content:space-between}
footer.site a{color:var(--accent)}
</style>"""
    theme_js = """
<script>
(function(){
  var KEY='oxt-map-theme', root=document.documentElement;
  try{var t=localStorage.getItem(KEY);if(t==='dark'||t==='light')root.setAttribute('data-theme',t)}catch(e){}
  function current(){var t=root.getAttribute('data-theme');if(t)return t;return window.matchMedia&&matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'}
  var btn=document.createElement('button');btn.className='theme-btn';btn.type='button';
  function label(){btn.textContent=current()==='dark'?'Light theme':'Dark theme'}
  btn.addEventListener('click',function(){var n=current()==='dark'?'light':'dark';root.setAttribute('data-theme',n);try{localStorage.setItem(KEY,n)}catch(e){}label()});
  label();var top=document.querySelector('header.top .wrap');if(top){var box=document.createElement('div');box.style.cssText='display:flex;gap:14px;align-items:center;flex-wrap:wrap';var st=document.getElementById('stamp');top.appendChild(box);if(st)box.appendChild(st);box.appendChild(btn)}
  var f=document.createElement('footer');f.className='site';
  f.innerHTML='<div class="wrap"><span>Generated from the OXT-Beyond and xTalk Suite repositories. Links are found by reading the code as text; see How it was made.</span>'+
    '<a href="https://github.com/SethMorrowSoftware/OpenXTalk-Beyond" rel="noopener">OXT-Beyond on GitHub</a></div>';
  document.body.appendChild(f);
})();
</script>"""
    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<meta name="description" content="%s">\n'
            '<meta property="og:title" content="OXT-Beyond Codebase Map">\n'
            '<meta property="og:description" content="%s">\n'
            '<link rel="icon" href="%s">\n' % (desc, desc, FAVICON)
            + top + '\n' + styles + extra_css + '\n</head>\n<body>\n' + body + theme_js + '\n</body>\n</html>\n')


def _passes(unit, key):
    return key in unit.passes


if __name__ == '__main__':
    main()
