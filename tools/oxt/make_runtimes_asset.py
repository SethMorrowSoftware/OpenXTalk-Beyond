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

"""Build the oxt-runtimes-<version>.zip release asset from an installed
OpenXTalk Lite folder (the contents of openxtalk-lite-1.15-win-noinstaller.7z).

The asset holds the files of the installed layout that this repository's
Windows x86-64 build does not produce but OXT Lite ships, so that OXT-Beyond
packages can offer the same standalone targets:

  Runtime/Windows/x86-32/**      (except Support/Sample Icons, which
                                  package.py takes from ide/Resources)
  Runtime/Linux/**
  Runtime/Android/**
  Extensions/com.livecode.library.timezone/code/<platform>/**
                                 for every platform except x86_64-win32
  Extensions/com.livecode.library.timezone/resources/**
                                 the zoneinfo data (built only on macOS and
                                 Linux, see tools/oxt/layout.py)

Every file is class "external" in layout.py. Ext/ (the mergExt collection)
is not included: its licence does not allow redistribution as far as this
project knows.

The files are stored unchanged under one top folder <name>/ together with a
generated <name>/PROVENANCE.md that lists every file with its size and
SHA-256. With --stock-setup (the .setup.exe of LiveCode Community 9.6.3 for
Windows, only read) each file is also compared with the stock 9.6.3 package
payload, and PROVENANCE.md says which files are identical to it. The zip is
reproducible: entries are sorted, their dates are the files' modification
times (UTC) and PROVENANCE.md gets the newest of them.

  python tools/oxt/make_runtimes_asset.py <installed-root> --out DIR
      [--stock-setup PATH] [--source-archive NAME] [--name NAME]
      [--update-manifest [FILE]]

--update-manifest writes the archive's size and SHA-256 into the asset
entry of the same name in tools/oxt/external-assets.json (creating the entry
if needed). Publishing the zip as a GitHub Release asset is a separate,
manual step for the maintainer.

Only the Python 3 standard library is used.
"""

import argparse
import collections
import datetime
import hashlib
import io
import json
import mmap
import os
import re
import struct
import sys
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout  # noqa: E402

REPO_URL = 'https://github.com/SethMorrowSoftware/winoxt'
RELEASE_TAG_FMT = 'runtimes-{version}'
DEFAULT_MANIFEST = os.path.join(HERE, 'external-assets.json')

# (prefix, group title). Every included file is under one of these and is
# class "external" in layout.py.
INCLUDE = (
    ('Runtime/Windows/x86-32/', 'Runtime/Windows/x86-32'),
    ('Runtime/Linux/x86-32/', 'Runtime/Linux/x86-32'),
    ('Runtime/Linux/x86-64/', 'Runtime/Linux/x86-64'),
    ('Runtime/Linux/', 'Runtime/Linux (other)'),
    ('Runtime/Android/', 'Runtime/Android'),
    ('Extensions/com.livecode.library.timezone/code/', 'timezone library: native code'),
    ('Extensions/com.livecode.library.timezone/resources/', 'timezone library: zoneinfo data'),
)

VERSION_RX = re.compile(rb'(?<![0-9.])(?:9\.[0-9]\.[0-9](?:-(?:dp|rc|gm)-[0-9]+|-OXT)?)(?![0-9.])')


# ---------------------------------------------------------------------------
# Stock LiveCode Community 9.6.3 package payload (read only)

class _Slice(io.RawIOBase):
    def __init__(self, f, start, end):
        self.f, self.start, self.end, self.pos = f, start, end, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, off, whence=0):
        if whence == 0:
            self.pos = off
        elif whence == 1:
            self.pos += off
        else:
            self.pos = (self.end - self.start) + off
        return self.pos

    def tell(self):
        return self.pos

    def readinto(self, b):
        n = min(len(b), (self.end - self.start) - self.pos)
        if n <= 0:
            return 0
        self.f.seek(self.start + self.pos)
        d = self.f.read(n)
        b[:len(d)] = d
        self.pos += len(d)
        return len(d)


def stock_digests(setup_path, wanted):
    """{installed path: sha256} for the wanted paths that the stock package
    installs. The payload is the package compiler's zip appended to the
    installer (builder/package_compiler.livecodescript); its manifest.txt
    lines are "file|executable <TAB> [[installFolder]]/<path> <TAB> <item>
    <TAB> [<base>]"."""
    f = open(setup_path, 'rb')
    try:
        m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            eocd = m.rfind(b'PK\x05\x06')
            if eocd < 0:
                raise SystemExit('error: no zip payload found in %s' % setup_path)
            _, _, _, _, _, cd_size, cd_offset, comment = struct.unpack('<IHHHHIIH', m[eocd:eocd + 22])
        finally:
            m.close()
        start = eocd - cd_size - cd_offset
        end = eocd + 22 + comment
        z = zipfile.ZipFile(io.BufferedReader(_Slice(f, start, end), 1 << 20))
        items = {}
        for line in z.read('manifest.txt').decode('utf-8').splitlines():
            parts = line.split('\t')
            if parts[0] not in ('file', 'executable') or len(parts) < 3:
                continue
            # A fourth field names a base file the item is a binary diff
            # against (iOS engines only); those items are not whole files.
            if len(parts) > 3 and parts[3]:
                continue
            target = parts[1]
            prefix = '[[installFolder]]/'
            if target.startswith(prefix):
                items[target[len(prefix):]] = parts[2]
        cache, out = {}, {}
        for path in wanted:
            item = items.get(path)
            if item is None:
                continue
            if item not in cache:
                h = hashlib.sha256()
                with z.open(item) as src:
                    while True:
                        b = src.read(1 << 20)
                        if not b:
                            break
                        h.update(b)
                cache[item] = h.hexdigest()
            out[path] = cache[item]
        return out
    finally:
        f.close()


# ---------------------------------------------------------------------------
# Selection

def select(root):
    """Return (included paths, empty folders, left-out external paths)."""
    included, left_out = [], []
    for path in layout.walk_files(root):
        cls, _, _ = layout.classify_path(path)
        if cls != layout.EXTERNAL:
            continue
        if any(path.startswith(p) for p, _ in INCLUDE):
            included.append(path)
        else:
            left_out.append(path)
    empty = [d for d in layout.empty_dirs(root)
             if layout.classify_path(d + '/x')[0] == layout.EXTERNAL
             and any((d + '/').startswith(p) for p, _ in INCLUDE)]
    return included, empty, left_out


def group_title(path):
    for prefix, title in INCLUDE:
        if path.startswith(prefix):
            return title
    return '(other)'


def read_text(root, name):
    try:
        with open(os.path.join(root, name), encoding='utf-8') as f:
            return f.read().strip()
    except OSError:
        return ''


def file_info(root, path):
    full = layout.native(root, path)
    h = hashlib.sha256()
    with open(full, 'rb') as f:
        head = f.read(4)
        h.update(head)
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            h.update(b)
    st = os.stat(full)
    return {'path': path, 'size': st.st_size, 'sha256': h.hexdigest(),
            'mtime': int(st.st_mtime), 'elf': head == b'\x7fELF'}


def version_strings(root, path):
    """Engine version strings in a file: the tagged ones (9.7.1-OXT,
    9.6.3-rc-3) if there are any, else plain 9.x.y strings."""
    with open(layout.native(root, path), 'rb') as f:
        data = f.read()
    found = {m.group(0).decode('ascii') for m in VERSION_RX.finditer(data)}
    tagged = {v for v in found if '-' in v}
    return sorted(tagged or found)


# ---------------------------------------------------------------------------
# PROVENANCE.md

def utc(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)


def md_escape(text):
    return text.replace('|', '\\|')


def provenance(name, root, infos, empty, stock, stock_setup, source_archive, left_out):
    version = read_text(root, '.version') or '?'
    build = read_text(root, '.buildnumber') or '?'
    groups = collections.OrderedDict((title, []) for _, title in INCLUDE)
    for i in infos:
        groups.setdefault(group_title(i['path']), []).append(i)
    L = []
    add = L.append
    add('# %s: prebuilt files from OpenXTalk Lite %s' % (name, version))
    add('')
    add('This archive is an external asset of OXT-Beyond (%s). OXT-Beyond\'s' % REPO_URL)
    add('packager (`tools/oxt/package.py`) adds its files to the installed layout at the')
    add('same paths, so that OXT-Beyond offers the standalone targets OpenXTalk Lite')
    add('offers. OXT-Beyond\'s own Windows x86-64 build does not produce these files.')
    add('')
    add('## Source')
    add('')
    src = 'the Windows release of OpenXTalk Lite %s' % version
    if source_archive:
        src += ' (`%s`)' % source_archive
    add('Every file was taken unchanged from %s,' % src)
    add('`.version` %s, `.buildnumber` %s. OpenXTalk Lite was started by Terry Little' % (version, build))
    add('and built and maintained by Tom Perry (tperry2x) up to 1.15, with contributions')
    add('from Paul McClernan (OpenXTalkPaul) and others (https://openxtalk.org).')
    add('')
    add('Not included: `Ext/` (the mergExt collection; OXT-Beyond does not redistribute')
    add('it because its licence is unclear) and `Runtime/Windows/x86-32/Support/Sample')
    add('Icons` (OXT-Beyond installs those from its own `ide/Resources/Sample Icons`).')
    if left_out:
        add('Other files of the release that are not built by OXT-Beyond and are not in')
        add('this archive: %d (%s).' % (len(left_out), ', '.join(sorted({layout.group_of(p) for p in left_out}))))
    add('')
    if stock is not None:
        add('"Stock 9.6.3" below compares each file with the file that the stock LiveCode')
        add('Community 9.6.3 Windows x86-64 installer installs at the same path: **same**')
        add('(byte-identical), **differs**, or **not in 9.6.3**. The comparison read the')
        add('package payload of that installer as kept by an installed copy (`%s`,' % os.path.basename(stock_setup))
        add('%s bytes, SHA-256 `%s`).' % ('{:,}'.format(os.path.getsize(stock_setup)), sha256_file(stock_setup)))
    else:
        add('The files were not compared with the stock LiveCode Community 9.6.3 package.')
    add('')
    add('## Folders')
    add('')
    if stock is not None:
        add('| folder | files | bytes | same as stock 9.6.3 | differs | not in 9.6.3 | newest file (UTC) |')
        add('|---|---:|---:|---:|---:|---:|---|')
    else:
        add('| folder | files | bytes | newest file (UTC) |')
        add('|---|---:|---:|---|')
    for title, items in groups.items():
        if not items:
            continue
        size = sum(i['size'] for i in items)
        newest = utc(max(i['mtime'] for i in items)).strftime('%Y-%m-%d')
        if stock is not None:
            c = collections.Counter(stock_status(i, stock) for i in items)
            add('| `%s` | %d | %s | %d | %d | %d | %s |' % (
                title, len(items), '{:,}'.format(size), c['same'], c['differs'], c['not in 9.6.3'], newest))
        else:
            add('| `%s` | %d | %s | %s |' % (title, len(items), '{:,}'.format(size), newest))
    add('')
    add('## Notes on the folders')
    add('')
    for title, items in groups.items():
        if not items:
            continue
        add('### `%s`' % title)
        add('')
        engines = [i for i in items if i['path'].rsplit('/', 1)[-1] == 'Standalone']
        for e in engines:
            vs = version_strings(root, e['path'])
            add('- `%s` (%s bytes, dated %s UTC): version strings found in the file: %s.' % (
                e['path'], '{:,}'.format(e['size']), utc(e['mtime']).strftime('%Y-%m-%d'),
                ', '.join('`%s`' % v for v in vs) if vs else 'none'))
        if stock is not None:
            c = collections.Counter(stock_status(i, stock) for i in items)
            if c['same'] == len(items):
                add('- All %d files are byte-identical to stock LiveCode Community 9.6.3.' % len(items))
            else:
                if c['same']:
                    add('- %d of %d files are byte-identical to stock LiveCode Community 9.6.3.' % (c['same'], len(items)))
                differ = [i['path'] for i in items if stock_status(i, stock) == 'differs']
                if differ:
                    add('- Different from the stock 9.6.3 file at the same path: %s.' % ', '.join('`%s`' % p for p in differ))
                missing = [i['path'] for i in items if stock_status(i, stock) == 'not in 9.6.3']
                libs = [p for p in missing if '/lib/' in p]
                other = [p for p in missing if '/lib/' not in p]
                if libs:
                    folder = libs[0][:libs[0].index('/lib/') + 4]
                    add('- `%s/` holds %d shared library files of other projects that stock 9.6.3' % (folder, len(libs)))
                    add('  does not install (listed below under Files).')
                if other:
                    add('- Not installed by stock 9.6.3: %s.' % ', '.join('`%s`' % p for p in other))
        add('')
    if stock is not None:
        add('Files that are not identical to stock LiveCode Community 9.6.3 are as Tom Perry')
        add('shipped them in OpenXTalk Lite (engine builds, edited templates, bundled')
        add('libraries). This archive records their bytes; how each one was built is not')
        add('recorded here.')
        add('')
    add('## Corresponding source and licences')
    add('')
    add('- LiveCode Community 9.6.3 (engine, externals, Android templates, timezone')
    add('  library): GNU GPL v3; source at https://github.com/livecode/livecode, tag')
    add('  `9.6.3` (engines reporting `9.6.3-rc-3`: tag `9.6.3-rc-3`). The history of')
    add('  %s contains the LiveCode commits up to `9.6.3-rc-3`.' % REPO_URL)
    add('- Tom Perry\'s OpenXTalk Lite engine (version string `9.7.1-OXT`): GNU GPL v3;')
    add('  his source archives (Windows, macOS and Linux) are published at')
    add('  https://www.openxtalk.net/OXT-lite-source/ . The Windows engine changes are')
    add('  in the history of %s.' % REPO_URL)
    add('- Timezone data (`resources/zoneinfo`): compiled with `zic` from the IANA time')
    add('  zone database, which is in the public domain; the sources are in')
    add('  `extensions/libraries/timezone/tz` of the LiveCode and OXT-Beyond repositories.')
    add('- Shared libraries in `Runtime/Linux/*/lib/`: each under the licence of its own')
    add('  project (for example LGPL for glibc, GLib, GTK and Pango; MIT or BSD-style')
    add('  licences for several X11, compression and codec libraries). Their licence texts')
    add('  and sources are available from those projects; they are not part of this archive.')
    add('')
    add('## Files')
    add('')
    add('Times are the files\' modification times in the release (UTC).')
    add('')
    if stock is not None:
        add('| path | bytes | SHA-256 | modified | stock 9.6.3 |')
        add('|---|---:|---|---|---|')
    else:
        add('| path | bytes | SHA-256 | modified |')
        add('|---|---:|---|---|')
    for i in infos:
        row = '| `%s` | %d | `%s` | %s |' % (md_escape(i['path']), i['size'], i['sha256'],
                                           utc(i['mtime']).strftime('%Y-%m-%d %H:%M'))
        if stock is not None:
            row += ' %s |' % stock_status(i, stock)
        add(row)
    add('')
    add('Total: %d files, %s bytes.' % (len(infos), '{:,}'.format(sum(i['size'] for i in infos))))
    if empty:
        add('')
        add('Empty folders in the release, kept as folder entries: %s.' % ', '.join('`%s`' % d for d in empty))
    add('')
    return '\n'.join(L)


def stock_status(info, stock):
    d = stock.get(info['path'])
    if d is None:
        return 'not in 9.6.3'
    return 'same' if d == info['sha256'] else 'differs'


# ---------------------------------------------------------------------------
# Zip

def zip_info(name, mtime, executable=False):
    t = time.gmtime(max(mtime, 315532800))  # zip dates start in 1980
    zi = zipfile.ZipInfo(name, date_time=t[:6])
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.create_system = 3
    zi.external_attr = ((0o100755 if executable else 0o100644) & 0xFFFF) << 16
    return zi


def write_zip(path, name, root, infos, empty, provenance_text):
    tmp = path + '.tmp'
    newest = max(i['mtime'] for i in infos)
    with zipfile.ZipFile(tmp, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for i in infos:
            zi = zip_info('%s/%s' % (name, i['path']), i['mtime'], i['elf'])
            with open(layout.native(root, i['path']), 'rb') as src, z.open(zi, 'w') as dst:
                while True:
                    b = src.read(1 << 20)
                    if not b:
                        break
                    dst.write(b)
        for d in empty:
            zi = zipfile.ZipInfo('%s/%s/' % (name, d), date_time=time.gmtime(newest)[:6])
            zi.create_system = 3
            zi.external_attr = (0o40755 << 16) | 0x10
            z.writestr(zi, b'')
        z.writestr(zip_info('%s/PROVENANCE.md' % name, newest), provenance_text.encode('utf-8'),
                   compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    os.replace(tmp, path)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Manifest update

def manifest_entry(name, version, sha, size):
    tag = RELEASE_TAG_FMT.format(version=version)
    return collections.OrderedDict([
        ('id', name),
        ('url', '%s/releases/download/%s/%s.zip' % (REPO_URL, tag, name)),
        ('sha256', sha),
        ('size', size),
        ('kind', 'zip'),
        ('strip', 1),
        ('dest', ''),
        ('rename', collections.OrderedDict([('PROVENANCE.md', 'PROVENANCE-%s.md' % name)])),
        ('description', 'Standalone runtimes that the Windows x86-64 build does not produce, '
                        'taken unchanged from OpenXTalk Lite %s: Windows x86-32, Linux and '
                        'Android engines and externals, the timezone library\'s code for other '
                        'platforms and its zoneinfo data. See PROVENANCE.md in the archive.' % version),
        ('licence', 'GPL-3.0 (LiveCode Community and OpenXTalk Lite engine builds); '
                    'IANA tz data: public domain; the shared libraries under '
                    'Runtime/Linux/*/lib keep their own licences (see PROVENANCE.md)'),
        ('source', 'OpenXTalk Lite %s for Windows (openxtalk-lite-%s-win-noinstaller.7z), '
                   'built by Tom Perry; made with tools/oxt/make_runtimes_asset.py' % (version, version)),
    ])


def update_manifest(path, entry):
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            data = json.load(f, object_pairs_hook=collections.OrderedDict)
    else:
        data = collections.OrderedDict([('assets', [])])
    assets = data.setdefault('assets', [])
    for n, a in enumerate(assets):
        if a.get('id') == entry['id']:
            merged = collections.OrderedDict(a)
            merged['sha256'] = entry['sha256']
            merged['size'] = entry['size']
            assets[n] = merged
            break
    else:
        assets.append(entry)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')


# ---------------------------------------------------------------------------

def main(argv=None):
    p = argparse.ArgumentParser(description='Build the oxt-runtimes release asset from an installed OpenXTalk Lite folder.')
    p.add_argument('installed_root')
    p.add_argument('--out', required=True, help='folder for the zip')
    p.add_argument('--name', help='asset name (default: oxt-runtimes-<.version>)')
    p.add_argument('--stock-setup', metavar='PATH',
                   help='.setup.exe of stock LiveCode Community 9.6.3 for Windows, to compare against (read only)')
    p.add_argument('--source-archive', metavar='NAME', help='file name of the release archive, for PROVENANCE.md')
    p.add_argument('--update-manifest', nargs='?', const=DEFAULT_MANIFEST, metavar='FILE',
                   help='write size and SHA-256 into this manifest (default: %s)' % DEFAULT_MANIFEST)
    args = p.parse_args(argv)

    root = args.installed_root
    if not os.path.isdir(root):
        raise SystemExit('error: %s is not a folder' % root)
    version = read_text(root, '.version')
    if not re.match(r'^[0-9A-Za-z][0-9A-Za-z._-]*$', version):
        raise SystemExit('error: %s/.version is missing or unusable' % root)
    name = args.name or 'oxt-runtimes-%s' % version

    included, empty, left_out = select(root)
    if not included:
        raise SystemExit('error: no files to include under %s' % root)
    infos = [file_info(root, pth) for pth in included]
    stock = None
    if args.stock_setup:
        print('comparing with the stock package in %s ...' % args.stock_setup)
        stock = stock_digests(args.stock_setup, set(included))
    text = provenance(name, root, infos, empty, stock, args.stock_setup, args.source_archive, left_out)

    os.makedirs(args.out, exist_ok=True)
    zip_path = os.path.join(args.out, name + '.zip')
    write_zip(zip_path, name, root, infos, empty, text)
    with open(os.path.join(args.out, 'PROVENANCE.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    sha = sha256_file(zip_path)
    size = os.path.getsize(zip_path)

    counts = collections.Counter(group_title(i['path']) for i in infos)
    print('%s: %d files, %s bytes uncompressed' % (zip_path, len(infos), '{:,}'.format(sum(i['size'] for i in infos))))
    for title in counts:
        print('  %5d  %s' % (counts[title], title))
    if left_out:
        print('left out (external, not in this asset): %d files in %s'
              % (len(left_out), ', '.join(sorted({layout.group_of(x) for x in left_out}))))
    print('size   %d' % size)
    print('sha256 %s' % sha)
    if args.update_manifest:
        update_manifest(args.update_manifest, manifest_entry(name, version, sha, size))
        print('updated %s' % args.update_manifest)
    return 0


if __name__ == '__main__':
    sys.exit(main())
