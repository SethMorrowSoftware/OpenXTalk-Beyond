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

"""Stage the installed layout of OXT-Beyond for Windows x86-64.

  python tools/oxt/package.py --repo <repo> --bin <repo>/win-x86_64-bin
      --out <stage-parent> [--build-number N] [--assets-cache DIR]
      [--no-external-assets] [--eol lf|crlf|keep] [--summary-json FILE]
      [--compare <reference install or TSV> [--report FILE]]

writes <stage-parent>/OXT-Beyond-<version>/, where <version> is the content
of ide/.version. An existing folder of that name is replaced. The folder is
what the portable zip contains and what the installer installs. It is put
together from:

  IDE          tools/oxt/layout.py assemble: ide/Toolset, Plugins, Resources,
               Documentation, Extensions, the ide/ root files and the 11
               ide-support scripts, plus the Sample Icons in
               Runtime/Windows/<arch>/Support. Text files get LF line endings
               (--eol) so that the result does not depend on git's
               core.autocrlf.
  build        the files of --bin (win-x86_64-bin) that Installer/package.txt
               installs on Windows x86-64, at its installed paths (see
               plan_build); LiveCode-Community.exe becomes OXT-Beyond.exe.
               NOT_INSTALLED lists the build outputs that are left out.
  generated    edition.txt ("community"), Externals/Externals.txt and
               Externals/Database Drivers/Database Drivers.txt (at the root
               and under Runtime/Windows/x86-64), .buildnumber (the build
               number) and two empty dictionary folders (EMPTY_DIRS).
  licences     LICENSE, LICENSE-EXCEPTION.md and THIRD-PARTY-NOTICES.md from
               the repository root (CRLF line endings).
  assets       the archives in tools/oxt/external-assets.json (see
               fetch_assets.py), unless --no-external-assets.

The build number is --build-number, else the environment variable
OXT_BUILD_NUMBER, else the current UTC time as YYYYMMDDHHMM. ide/.buildnumber
in the repository is a placeholder.

--compare checks the staged tree against a reference install (for example
OpenXTalk Lite 1.15) or a TSV from "layout.py classify" (also a part of
one, such as only its build rows): every IDE, build and external path of
the reference must be staged (the engine under its new name) unless an
intended difference (INTENDED_MISSING) says why not, and every staged path
of the classes the reference lists must be in it unless it is an intended
addition (licence files, asset notices). With a folder, external asset
files must be byte-identical and empty folders must match. IDE changes
since the reference are listed but are not errors.

Exit status: 0 success, 1 unexplained differences (--compare), 2 errors
(missing build outputs, conflicts, asset download or checksum failures;
nothing is written when the plan has problems).

Only the Python 3 standard library is used.
"""

import argparse
import calendar
import collections
import datetime
import json
import os
import re
import shutil
import stat
import sys
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout  # noqa: E402
import fetch_assets  # noqa: E402

PRODUCT = 'OXT-Beyond'
EXE_NAME = PRODUCT + '.exe'
EDITION = 'community'
DEV_ENGINE = 'LiveCode-Community.exe'
STANDALONE_ENGINE = 'standalone-community.exe'
BUILD_NUMBER_ENV = 'OXT_BUILD_NUMBER'

LICENCE_FILES = ('LICENSE', 'LICENSE-EXCEPTION.md', 'THIRD-PARTY-NOTICES.md')

# Folders that must exist although git cannot store them: the dictionary
# (Documentation/oxt_dictionary.oxtstack) writes exports into them.
EMPTY_DIRS = (
    'Documentation/html_viewer/resources/data/api/exports/builder/plugins',
    'Documentation/html_viewer/resources/data/api/exports/datagrid/plugins',
)

# ---------------------------------------------------------------------------
# Build output -> installed path, from Installer/package.txt with
# TargetPlatform Windows, TargetArchitecture x86_64, TargetEdition Community
# and TargetFolder = SupportFolder = ToolsFolder = the install root.

# component Externals.Windows (declare external lines in this order)
EXTERNALS = (('Speech', 'revspeech.dll'), ('XML', 'revxml.dll'),
             ('Browser', 'revbrowser.dll'), ('Revolution Zip', 'revzip.dll'))
# component Databases.Windows
DATABASE_EXTERNAL = ('Database', 'revdb.dll')
DB_DRIVERS = (('MySQL', 'dbmysql.dll'), ('ODBC', 'dbodbc.dll'),
              ('PostgreSQL', 'dbpostgresql.dll'), ('SqLite', 'dbsqlite.dll'))
# component Externals.CEF.Windows: from the build root ...
CEF_FROM_ROOT = ('libbrowser-cefprocess.exe', 'revbrowser-cefprocess.exe')
# ... and from win-x86_64:Externals/CEF
CEF_FILES = ('libcef.dll', 'd3dcompiler_47.dll', 'libEGL.dll', 'libGLESv2.dll',
             'chrome_elf.dll', 'cef.pak', 'cef_100_percent.pak',
             'cef_200_percent.pak', 'cef_extensions.pak', 'icudtl.dat',
             'natives_blob.bin', 'snapshot_blob.bin', 'v8_context_snapshot.bin',
             'swiftshader/libEGL.dll', 'swiftshader/libGLESv2.dll')
CEF_TREES = ('locales',)
# component Toolchain.Windows
TOOLCHAIN_FILES = ('lc-compile.exe', 'lc-run.exe', 'lc-compile-ffi-java.exe')
TOOLCHAIN_TREES = (('modules', 'Toolchain/modules'),)
# component Runtime.Windows
RUNTIME_TEMPLATES = ('w32-manifest-template.xml',
                     'w32-manifest-template-dpiaware.xml',
                     'w32-manifest-template-trustinfo.xml')
# components Extensions and TimeZone: the same 42 ids layout.py knows
PACKAGED_EXTENSIONS = layout.REPO_BUILT_EXTENSIONS

RUNTIME_X64 = 'Runtime/Windows/x86-64'

# Build outputs that are deliberately not installed (pattern, reason).
NOT_INSTALLED = (
    ('*.pdb', 'debug symbols; they go into the -symbols.zip'),
    ('installer.exe', 'LiveCode\'s installer engine; OXT-Beyond is installed by Inno Setup'),
    ('server-*', 'LiveCode Server engine and its externals; package.txt installs no server'),
    ('Externals/CEF/devtools_resources.pak', 'not in package.txt Externals.CEF.Windows'),
    ('Externals/CEF/libbrowser-cefprocess.exe',
     'package.txt takes the identical copy at the root of the build'),
    ('Externals/CEF/revbrowser-cefprocess.exe',
     'package.txt takes the identical copy at the root of the build'),
    ('packaged_extensions/com.livecode.library.canvas/**',
     'not in package.txt Extensions (not shipped by LiveCode 9.6.3 or OpenXTalk Lite 1.15)'),
    ('packaged_extensions/com.livecode.library.ini/**',
     'not in package.txt Extensions (not shipped by LiveCode 9.6.3 or OpenXTalk Lite 1.15)'),
)

# Paths of a reference install (layout.py class build) that packaging does
# not produce on purpose (pattern, reason). Used by --compare.
_COMMERCIAL_LCI = ('com.livecode.library.native.android.barcode',
                   'com.livecode.library.native.android.barcodesupport',
                   'com.livecode.library.native.speech',
                   'com.livecode.library.securekey',
                   'com.livecode.widget.native.android.barcodescanner',
                   'com.livecode.widget.native.map',
                   'com.livecode.widget.pdf',
                   'com.livecode.widget.pdf.pdfium',
                   'com.livecode.widget.signature')
INTENDED_MISSING = tuple(
    [('Toolchain/modules/lci/%s.lci' % m,
      'interface of a LiveCode commercial-edition module; OpenXTalk Lite 1.15 ships '
      'the stock LiveCode 9.6.3 Toolchain, which has it, but the module is not in this '
      'repository and nothing in the IDE uses it') for m in _COMMERCIAL_LCI] +
    [('Toolchain/modules/lci/com.livecode.commercial.license.lci',
      'from the stock LiveCode 9.6.3 Toolchain; this repository compiles '
      'engine/src/license.lcb into lc-compile instead (engine_syntax_only_lcb_files) '
      'and writes no .lci for it'),
     ('Ext/**', 'the mergExt collection is not redistributed (licence unclear)')])


class PackageError(Exception):
    pass


class Item(object):
    """One file of the staged tree."""
    __slots__ = ('target', 'origin', 'source', 'data', 'member', 'asset', 'note')

    def __init__(self, target, origin, source=None, data=None, member=None, asset=None, note=''):
        self.target = target      # installed path, "/" separators
        self.origin = origin      # ide, build, generated, licence, asset
        self.source = source      # file on disk (ide, build, licence)
        self.data = data          # bytes (generated)
        self.member = member      # zip member name (asset)
        self.asset = asset        # asset dict (asset)
        self.note = note


# ---------------------------------------------------------------------------
# Plan

def read_version(repo):
    path = os.path.join(repo, 'ide', '.version')
    try:
        with open(path, encoding='utf-8') as f:
            version = f.read().strip()
    except OSError:
        raise PackageError('%s is missing' % path)
    if not re.match(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$', version):
        raise PackageError('%s holds %r, which is not usable as a version' % (path, version))
    return version


def engine_version(repo):
    try:
        with open(os.path.join(repo, 'version'), encoding='utf-8') as f:
            for line in f:
                m = re.match(r'^\s*BUILD_SHORT_VERSION\s*=\s*(\S+)\s*$', line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return ''


def default_build_number(explicit=None):
    value = explicit or os.environ.get(BUILD_NUMBER_ENV) or \
        datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M')
    value = str(value).strip()
    if not re.match(r'^[0-9]{1,20}$', value):
        raise PackageError('build number %r must be digits only' % value)
    return value


def _crlf_lines(pairs):
    return ''.join('%s,%s\r\n' % p for p in pairs).encode('ascii')


def externals_component(folder, bin_dir, add, problems):
    """package.txt component Externals (Windows) into <folder>/Externals."""
    ext = folder + '/Externals' if folder else 'Externals'
    for _, name in EXTERNALS + (DATABASE_EXTERNAL,):
        add_build(ext + '/' + name, name, bin_dir, add, problems, 'Externals.Windows / Databases.Windows')
    for _, name in DB_DRIVERS:
        add_build(ext + '/Database Drivers/' + name, name, bin_dir, add, problems, 'Databases.Windows')
    for name in CEF_FROM_ROOT:
        add_build(ext + '/CEF/' + name, name, bin_dir, add, problems, 'Externals.CEF.Windows')
    for name in CEF_FILES:
        add_build(ext + '/CEF/' + name, 'Externals/CEF/' + name, bin_dir, add, problems, 'Externals.CEF.Windows')
    for tree in CEF_TREES:
        add_tree(ext + '/CEF/' + tree, 'Externals/CEF/' + tree, bin_dir, add, problems, 'Externals.CEF.Windows')
    add(Item(ext + '/Externals.txt', 'generated',
             data=_crlf_lines(EXTERNALS + (DATABASE_EXTERNAL,)),
             note='package.txt Externals: emit externals'))
    add(Item(ext + '/Database Drivers/Database Drivers.txt', 'generated',
             data=_crlf_lines(DB_DRIVERS), note='package.txt Externals: emit dbdrivers'))


def add_build(target, rel, bin_dir, add, problems, note):
    path = layout.native(bin_dir, rel)
    if not os.path.isfile(path):
        problems.append('build output missing: %s (for %s)' % (rel, target))
        return
    add(Item(target, 'build', source=path, note='package.txt ' + note + ': ' + rel))


def add_tree(target, rel, bin_dir, add, problems, note):
    base = layout.native(bin_dir, rel)
    if not os.path.isdir(base):
        problems.append('build output folder missing: %s (for %s)' % (rel, target))
        return
    files = [p for p in layout.walk_files(base)
             if not any(part.startswith('.') for part in p.split('/'))]
    if not files:
        problems.append('build output folder is empty: %s' % rel)
    for p in files:
        add(Item(target + '/' + p, 'build', source=layout.native(base, p),
                 note='package.txt ' + note + ': ' + rel + '/'))


def plan_build(bin_dir, add, problems):
    # Engine.Windows
    add_build(EXE_NAME, DEV_ENGINE, bin_dir, add, problems, 'Engine.Windows (renamed)')
    add_build('revpdfprinter.dll', 'revpdfprinter.dll', bin_dir, add, problems, 'Engine.Windows')
    add_build('revsecurity.dll', 'revsecurity.dll', bin_dir, add, problems, 'Engine.Windows')
    # Toolset: emit variable TargetEdition
    add(Item('edition.txt', 'generated', data=EDITION.encode('ascii'),
             note='package.txt Toolset: emit variable TargetEdition'))
    # Externals (ToolsFolder) and Mobile.Windows
    externals_component('', bin_dir, add, problems)
    add_build('Externals/revandroid.dll', 'revandroid.dll', bin_dir, add, problems, 'Mobile.Windows')
    # Toolchain.Windows
    for name in TOOLCHAIN_FILES:
        add_build('Toolchain/' + name, name, bin_dir, add, problems, 'Toolchain.Windows')
    for rel, target in TOOLCHAIN_TREES:
        add_tree(target, rel, bin_dir, add, problems, 'Toolchain.Windows')
    # Runtime.Windows x86-64 (Sample Icons come from the IDE part)
    add_build(RUNTIME_X64 + '/Standalone', STANDALONE_ENGINE, bin_dir, add, problems,
              'Runtime.Windows (standalone<edition>.exe as Standalone)')
    for name in RUNTIME_TEMPLATES:
        add_build(RUNTIME_X64 + '/' + name, name, bin_dir, add, problems, 'Runtime.Windows')
    for name in ('revpdfprinter.dll', 'revsecurity.dll'):
        add_build(RUNTIME_X64 + '/Support/' + name, name, bin_dir, add, problems, 'Runtime.Windows')
    externals_component(RUNTIME_X64, bin_dir, add, problems)
    # Extensions and TimeZone
    for ext in PACKAGED_EXTENSIONS:
        add_tree('Extensions/' + ext, 'packaged_extensions/' + ext, bin_dir, add, problems,
                 'Extensions' if ext != 'com.livecode.library.timezone' else 'TimeZone')


def unused_build_outputs(bin_dir, used):
    """[(path, reason or None)] for build outputs that are not installed."""
    out = []
    for p in layout.walk_files(bin_dir):
        if os.path.normcase(layout.native(bin_dir, p)) in used:
            continue
        reason = next((why for pat, why in NOT_INSTALLED if layout._glob_match(pat, p)), None)
        out.append((p, reason))
    return out


def plan(repo, bin_dir, build_number, assets):
    """Return (items, folders, problems); folders are installed paths of
    folders to create even if empty."""
    items, problems = [], []
    folders = list(EMPTY_DIRS)
    add = items.append

    # IDE
    pairs, ide_problems = layout.plan_assemble(repo)
    problems.extend('IDE: ' + p for p in ide_problems)
    for target, repo_path in pairs:
        if target == '.buildnumber':
            continue
        add(Item(target, 'ide', source=layout.native(repo, repo_path), note=repo_path))
    add(Item('.buildnumber', 'generated', data=(build_number + '\n').encode('ascii'),
             note='build number (ide/.buildnumber is a placeholder)'))

    # Build outputs
    plan_build(bin_dir, add, problems)

    # Licence files
    for name in LICENCE_FILES:
        path = os.path.join(repo, name)
        if not os.path.isfile(path):
            problems.append('licence file missing: %s' % path)
            continue
        with open(path, 'rb') as f:
            data = layout._normalise(f.read()).replace(b'\n', b'\r\n')
        add(Item(name, 'licence', data=data, note=name + ' (CRLF line endings)'))

    # External assets
    for asset, archive in assets:
        files, dirs = fetch_assets.plan_members(asset, archive)
        for target, member in files:
            add(Item(target, 'asset', source=archive, member=member, asset=asset,
                     note='asset %s: %s' % (asset['id'], member)))
        folders.extend(dirs)

    # Conflicts (case-insensitive, as on Windows)
    seen = {}
    for it in items:
        key = it.target.lower()
        if key in seen:
            other = seen[key]
            problems.append('%s comes from both %s (%s) and %s (%s)'
                            % (it.target, other.origin, other.note, it.origin, it.note))
        else:
            seen[key] = it
    items.sort(key=lambda i: i.target)
    return items, sorted(set(folders)), problems


# ---------------------------------------------------------------------------
# Write

def _on_rm_error(func, path, exc_info):
    try:
        os.chmod(path, stat.S_IWRITE)
        func(path)
    except OSError:
        raise exc_info[1]


def remove_tree(path):
    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=lambda f, p, e: _on_rm_error(f, p, (None, e, None)))
    else:
        shutil.rmtree(path, onerror=_on_rm_error)


def write_stage(stage, items, folders, eol, log):
    if os.path.isdir(stage) and not os.path.islink(stage):
        log('removing the previous %s' % stage)
        remove_tree(stage)
    elif os.path.lexists(stage):
        os.remove(stage)
    os.makedirs(stage)
    archives = {}
    try:
        made = set()
        for it in items:
            dst = layout.native(stage, it.target)
            parent = os.path.dirname(dst)
            if parent not in made:
                os.makedirs(parent, exist_ok=True)
                made.add(parent)
            if it.origin == 'ide':
                if eol != 'keep' and layout.is_text(it.target):
                    with open(it.source, 'rb') as f:
                        data = layout._normalise(f.read())
                    if eol == 'crlf':
                        data = data.replace(b'\n', b'\r\n')
                    with open(dst, 'wb') as f:
                        f.write(data)
                else:
                    shutil.copyfile(it.source, dst)
            elif it.origin == 'build':
                shutil.copy2(it.source, dst)
            elif it.origin in ('generated', 'licence'):
                with open(dst, 'wb') as f:
                    f.write(it.data)
            elif it.origin == 'asset':
                z = archives.get(it.source)
                if z is None:
                    z = archives[it.source] = zipfile.ZipFile(it.source)
                info = z.getinfo(it.member)
                with z.open(info) as src, open(dst, 'wb') as out:
                    shutil.copyfileobj(src, out, 1 << 20)
                # make_runtimes_asset.py stores UTC times
                ts = calendar.timegm(info.date_time + (0, 0, -1))
                os.utime(dst, (ts, ts))
            else:
                raise PackageError('unknown origin %s' % it.origin)
        for d in folders:
            os.makedirs(layout.native(stage, d), exist_ok=True)
    finally:
        for z in archives.values():
            z.close()


# ---------------------------------------------------------------------------
# Compare with a reference install

def load_reference(ref):
    """Return (root or None, paths, empty folders, classes listed). For a
    TSV from "layout.py classify" the classes are those of its first
    column; otherwise None."""
    if os.path.isdir(ref):
        return ref, layout.walk_files(ref), layout.empty_dirs(ref), None
    paths, classes = set(), set()
    with open(ref, encoding='utf-8') as f:
        for line in f:
            cols = line.rstrip('\r\n').split('\t')
            if not line.strip():
                continue
            if cols[0] == 'class':
                continue
            if cols[0] in layout.CLASS_ORDER and len(cols) > 1:
                paths.add(cols[1])
                classes.add(cols[0])
            else:
                paths.add(cols[0])
    return None, sorted(paths), [], classes or None


def reference_engine(paths):
    exes = [p for p in paths if '/' not in p and p.lower().endswith('.exe') and not p.startswith('.')]
    return exes[0] if len(exes) == 1 else None


def compare(stage, items, ref, no_assets, report=None):
    """Print the comparison; return the number of unexplained differences."""
    root, ref_paths, ref_empty, listed_classes = load_reference(ref)
    by_target = {it.target: it for it in items}
    by_lower = {it.target.lower(): it for it in items}
    engine = reference_engine(ref_paths)
    rows = []            # (status, reference path, staged path, class, detail)
    matched = set()
    problems = 0
    counts = collections.Counter()

    for p in ref_paths:
        cls, _, _ = layout.classify_path(p)
        q = EXE_NAME if p == engine else p
        it = by_target.get(q) or by_lower.get(q.lower())
        why = next((w for pat, w in INTENDED_MISSING if layout._glob_match(pat, p)), None)
        if cls in (layout.JUNK, layout.EXCLUDED):
            if it is not None:
                rows.append(('ERROR shipped', p, it.target, cls, 'class %s must not be packaged' % cls))
                problems += 1
                matched.add(it.target)
            else:
                rows.append(('not packaged', p, '', cls, 'class %s' % cls))
            counts[(cls, 'left out as intended')] += 1
            continue
        if it is None:
            if why:
                rows.append(('intended missing', p, '', cls, why))
                counts[(cls, 'intended missing')] += 1
            elif cls == layout.EXTERNAL and no_assets:
                rows.append(('intended missing', p, '', cls, '--no-external-assets'))
                counts[(cls, 'intended missing')] += 1
            elif cls == layout.IDE:
                rows.append(('IDE change: removed', p, '', cls, 'not in the repository\'s IDE'))
                counts[(cls, 'not in the IDE any more')] += 1
            else:
                rows.append(('ERROR missing', p, '', cls, 'not staged'))
                counts[(cls, 'MISSING')] += 1
                problems += 1
            continue
        matched.add(it.target)
        detail = ''
        status = 'present'
        if q != p:
            detail = 'renamed from %s' % p
        if root is not None:
            ref_file = layout.native(root, p)
            staged = layout.native(stage, it.target)
            if it.origin == 'generated':
                status = 'present (generated)'
                if _same_bytes(ref_file, staged):
                    status = 'present (generated, identical)'
            elif cls == layout.IDE:
                if not layout.same_content(p, ref_file, staged):
                    status = 'IDE change: modified'
            elif cls == layout.EXTERNAL:
                if not _same_bytes(ref_file, staged):
                    status = 'ERROR content'
                    detail = 'external asset file differs from the reference'
                    problems += 1
            elif cls == layout.BUILD:
                status = 'present (identical)' if _same_bytes(ref_file, staged) else 'present (rebuilt)'
        rows.append((status, p, it.target, cls, detail))
        counts[(cls, status)] += 1

    # A TSV reference may list only some classes (for example only the
    # build files); staged files of other classes are then not compared.
    ref_classes = listed_classes or {layout.classify_path(p)[0] for p in ref_paths}
    for it in items:
        if it.target in matched:
            continue
        cls, _, _ = layout.classify_path(it.target)
        if root is None and cls not in ref_classes:
            counts[('(staged only)', 'class not in the list')] += 1
            continue
        if it.origin == 'licence':
            status, why = 'intended addition', 'OXT-Beyond licence file'
        elif it.origin == 'asset' and _asset_rel(it) in it.asset.get('rename', {}):
            status, why = 'intended addition', 'notice file of an external asset (%s)' % it.note
        elif it.origin == 'ide':
            status, why = 'IDE change: added', it.note
        else:
            status, why = 'ERROR extra', '%s: %s' % (it.origin, it.note)
            problems += 1
        rows.append((status, '', it.target, cls, why))
        counts[('(staged only)', status)] += 1

    # Empty folders (a TSV reference has none to compare)
    staged_empty = set(layout.empty_dirs(stage)) if root is not None else set()
    for d in ref_empty:
        cls, _, _ = layout.classify_path(d + '/x')
        if d in staged_empty:
            rows.append(('present', d + '/', d + '/', 'folder', 'empty folder'))
            counts[('(empty folders)', 'present')] += 1
        elif cls == layout.EXTERNAL and (no_assets or d.startswith('Ext/')):
            rows.append(('intended missing', d + '/', '', 'folder', 'empty folder of an asset left out'))
            counts[('(empty folders)', 'intended missing')] += 1
        else:
            rows.append(('ERROR missing', d + '/', '', 'folder', 'empty folder of the reference'))
            counts[('(empty folders)', 'MISSING')] += 1
            problems += 1
    for d in sorted(staged_empty - set(ref_empty)):
        rows.append(('ERROR extra', '', d + '/', 'folder', 'empty folder not in the reference'))
        counts[('(empty folders)', 'extra')] += 1
        problems += 1

    print('')
    print('Comparison with %s' % ref)
    if engine:
        print('  engine %s is staged as %s' % (engine, EXE_NAME))
    print('  %-10s %-26s %7s' % ('class', 'status', 'files'))
    for (cls, status) in sorted(counts, key=lambda k: (str(k[0]), k[1])):
        print('  %-10s %-26s %7d' % (cls, status, counts[(cls, status)]))
    for title in ('ERROR', 'intended missing', 'intended addition'):
        chosen = [r for r in rows if r[0].startswith(title)]
        if not chosen:
            continue
        print('')
        print('%s (%d):' % (title if title != 'ERROR' else 'Unexplained differences', len(chosen)))
        groups = collections.OrderedDict()
        for r in chosen:
            groups.setdefault((r[0], r[4]), []).append(r[1] or r[2])
        for (status, why), paths in groups.items():
            print('  [%s] %s' % (status, why))
            for pth in paths[:12]:
                print('      ' + pth)
            if len(paths) > 12:
                print('      ... and %d more' % (len(paths) - 12))
    ide_changes = [r for r in rows if r[0].startswith('IDE change')]
    if ide_changes:
        print('')
        print('IDE changes since the reference (not errors): %d' % len(ide_changes))
        for r in ide_changes[:40]:
            print('  [%s] %s' % (r[0][len('IDE change: '):], r[1] or r[2]))
        if len(ide_changes) > 40:
            print('  ... and %d more (see the report)' % (len(ide_changes) - 40))
    if report:
        with open(report, 'w', encoding='utf-8', newline='\n') as f:
            f.write('status\treference_path\tstaged_path\tclass\tdetail\n')
            for r in rows:
                f.write('\t'.join(r) + '\n')
        print('')
        print('report: %s' % report)
    print('')
    print('COMPARE %s (%d unexplained differences)' % ('FAILED' if problems else 'PASSED', problems))
    return problems


def _asset_rel(item):
    """Archive path of an asset item after strip."""
    return '/'.join(item.member.split('/')[item.asset['strip']:])


def _same_bytes(a, b):
    if os.path.getsize(a) != os.path.getsize(b):
        return False
    with open(a, 'rb') as fa, open(b, 'rb') as fb:
        while True:
            x = fa.read(1 << 20)
            y = fb.read(1 << 20)
            if x != y:
                return False
            if not x:
                return True


# ---------------------------------------------------------------------------
# Command line

def summarise(items, stage, bin_dir, used, log):
    by_origin = collections.Counter()
    size_origin = collections.Counter()
    by_group = collections.Counter()
    size_group = collections.Counter()
    for it in items:
        size = os.path.getsize(layout.native(stage, it.target))
        by_origin[it.origin] += 1
        size_origin[it.origin] += size
        g = layout.group_of(it.target)
        by_group[g] += 1
        size_group[g] += size
    log('')
    log('Staged %d files, %s bytes, in %s' % (len(items), '{:,}'.format(sum(size_origin.values())), stage))
    for o in ('ide', 'build', 'generated', 'licence', 'asset'):
        if by_origin[o]:
            log('  %-10s %6d files %15s bytes' % (o, by_origin[o], '{:,}'.format(size_origin[o])))
    empty = layout.empty_dirs(stage)
    log('  empty folders: %d (%s)' % (len(empty), ', '.join(empty)))
    log('')
    log('By folder:')
    for g in sorted(by_group):
        log('  %6d %15s  %s' % (by_group[g], '{:,}'.format(size_group[g]), g))
    unused = unused_build_outputs(bin_dir, used)
    if unused:
        log('')
        log('Build outputs not installed: %d' % len(unused))
        grouped = collections.OrderedDict()
        for p, why in unused:
            grouped.setdefault(why, []).append(p)
        for why, paths in grouped.items():
            shown = ', '.join(paths[:6]) + (' ... (%d files)' % len(paths) if len(paths) > 6 else '')
            log('  %s: %s' % (why or 'WARNING: no rule in package.py; not installed', shown))
    return by_origin, size_origin


def main(argv=None):
    p = argparse.ArgumentParser(description='Stage the installed layout of OXT-Beyond for Windows x86-64.')
    p.add_argument('--repo', default=os.path.dirname(os.path.dirname(HERE)),
                   help='repository root (default: two levels above this script)')
    p.add_argument('--bin', dest='bin_dir', help='build output (default: <repo>/win-x86_64-bin)')
    p.add_argument('--out', required=True, help='folder to create OXT-Beyond-<version> in')
    p.add_argument('--build-number', help='default: $%s, else the UTC time as YYYYMMDDHHMM' % BUILD_NUMBER_ENV)
    p.add_argument('--assets-cache', metavar='DIR',
                   help='asset cache (default: $%s, else <repo>/prebuilt/fetched-assets)' % fetch_assets.CACHE_ENV)
    p.add_argument('--manifest', default=fetch_assets.DEFAULT_MANIFEST, help='asset manifest (default: %(default)s)')
    p.add_argument('--no-external-assets', action='store_true', help='leave the external assets out')
    p.add_argument('--offline', action='store_true', help='use cached assets only, never download')
    p.add_argument('--eol', choices=('lf', 'crlf', 'keep'), default='lf',
                   help='line endings of IDE text files (default: lf, as git stores them)')
    p.add_argument('--summary-json', metavar='FILE', help='write a JSON summary here')
    p.add_argument('--compare', metavar='REF', help='installed folder or classify TSV to compare with')
    p.add_argument('--report', metavar='FILE', help='with --compare: write every path\'s status as TSV')
    args = p.parse_args(argv)

    log = print
    try:
        repo = os.path.abspath(args.repo)
        if not os.path.isdir(os.path.join(repo, 'ide')):
            raise PackageError('%s has no ide/ folder (not the repository root?)' % repo)
        bin_dir = os.path.abspath(args.bin_dir or os.path.join(repo, 'win-x86_64-bin'))
        if not os.path.isfile(os.path.join(bin_dir, DEV_ENGINE)):
            raise PackageError('no build in %s (%s is missing)' % (bin_dir, DEV_ENGINE))
        version = read_version(repo)
        build_number = default_build_number(args.build_number)
        out = os.path.abspath(args.out)
        package_root = '%s-%s' % (PRODUCT, version)
        stage = os.path.join(out, package_root)
        for inside in (repo, bin_dir):
            if os.path.normcase(stage) == os.path.normcase(inside) or \
                    os.path.normcase(inside).startswith(os.path.normcase(stage) + os.sep):
                raise PackageError('the stage folder %s would contain %s' % (stage, inside))

        log('Product      : %s %s (build %s)' % (PRODUCT, version, build_number))
        log('Engine       : %s' % (engine_version(repo) or '?'))
        log('Repository   : %s' % repo)
        log('Build output : %s' % bin_dir)
        log('Stage        : %s' % stage)

        assets = []
        if args.no_external_assets:
            log('External assets: left out (--no-external-assets)')
        else:
            cache = fetch_assets.cache_dir(repo, args.assets_cache)
            log('Asset cache  : %s' % cache)
            for a in fetch_assets.load_manifest(args.manifest):
                assets.append((a, fetch_assets.fetch(a, cache, args.offline, log)))

        items, folders, problems = plan(repo, bin_dir, build_number, assets)
        if problems:
            for msg in problems:
                sys.stderr.write('error: %s\n' % msg)
            raise PackageError('%d problem(s); nothing was written' % len(problems))

        t0 = time.time()
        write_stage(stage, items, folders, args.eol, log)
        log('written in %.0f s' % (time.time() - t0))
        used = {os.path.normcase(it.source) for it in items if it.origin == 'build'}
        by_origin, size_origin = summarise(items, stage, bin_dir, used, log)

        if args.summary_json:
            summary = collections.OrderedDict([
                ('product', PRODUCT),
                ('version', version),
                ('build_number', build_number),
                ('engine_version', engine_version(repo)),
                ('package_root', package_root),
                ('stage_dir', stage),
                ('exe', EXE_NAME),
                ('files', len(items)),
                ('bytes', sum(size_origin.values())),
                ('by_origin', collections.OrderedDict((o, by_origin[o]) for o in sorted(by_origin))),
                ('empty_dirs', layout.empty_dirs(stage)),
                ('external_assets', [collections.OrderedDict([('id', a['id']), ('sha256', a['sha256']),
                                                               ('url', a['url'])]) for a, _ in assets]),
            ])
            with open(args.summary_json, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(summary, f, indent=2)
                f.write('\n')

        if args.compare:
            if compare(stage, items, args.compare, args.no_external_assets, args.report):
                return 1
    except (PackageError, fetch_assets.AssetError) as e:
        sys.stderr.write('error: %s\n' % e)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
