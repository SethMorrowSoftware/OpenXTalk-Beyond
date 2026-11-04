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

"""Write the server zip of one platform: the server engine of a build
output with its externals and database drivers, in the layout of
LiveCode Community's server zips, so that a web server set up for
LiveCode Server runs it unchanged.

  python3 tools/oxt/package_server.py --platform P
      (--bin DIR | --bin-tar FILE | --bin-zip FILE) --out DIR
      [--repo DIR] [--version V] [--sums] [--zip-level N]

P is win-x86_64, win-x86, linux-x86_64, linux-arm64, linux-x86,
mac-universal, mac-arm64 or mac-x86_64. The build output is a folder
(win-x86_64-bin, linux-<arch>-bin, or on macOS the Release folder of
_build/mac), a CI bin tarball of one (OXT-Beyond-<platform>-bin.tar.xz),
or a release's binaries zip or tarball (--bin-zip for the Windows zip,
--bin-tar for the others). Only the server's own files are read from it.

Written to --out: OXT-Beyond-<version>-<platform>-server.zip, which holds,
at its top as LiveCode's server builder (builder/server_builder.
livecodescript) wrote them:

  livecode-community-server[.exe]  the build's server-community[.exe], the
                                   name LiveCode Community's server zips
                                   gave it, so that an Apache "Action" or
                                   an IIS handler set up for one finds it
  externals/revdb, revxml, revzip  the build's server-<name> libraries;
                                   on Windows, where the build makes no
                                   server-revdb etc. of its own for some,
                                   the desktop one, as LiveCode's builder
                                   took it (the server engine loads every
                                   file of this folder when it starts)
  drivers/dbsqlite, dbmysql,       revDB's database drivers, the same way
          dbpostgresql, dbodbc     (revdb looks in ./drivers)
  README.txt                       how to set it up (tools/oxt/server-readme.txt)
  LICENSE, LICENSE-EXCEPTION.md,   the licence files, and the licence texts
  THIRD-PARTY-NOTICES.md,          of the third-party code the engine and
  Open Source Licenses.txt         drivers link (ide/Open Source Licenses.txt)

Every one of those files must be there: a build output without one of
them, or whose engine is not an executable of the platform (PE, ELF of
the architecture, a universal Mach-O for mac-universal), writes nothing.
Entries are sorted, the programs' Unix modes are kept (0755; 0644 for
the rest) so that unzip and macOS's Archive Utility give an executable
engine, and every date is SOURCE_DATE_EPOCH when it is set, else the
engine's.

--sums adds the zip's line to --out's SHA256SUMS ("<sha256>  <name>",
replacing an older line for the same name), as the packaging jobs keep
one SHA256SUMS per artifact.

The version is ide/.version of --repo (default: this checkout) unless
--version gives one. Under GitHub Actions it writes the step outputs zip
(the path) and name.

Only the Python 3 standard library is used.
"""

import argparse
import collections
import hashlib
import os
import re
import stat
import sys
import tarfile
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))

PRODUCT = 'OXT-Beyond'
ENGINE = 'livecode-community-server'
EXTERNALS = ('revdb', 'revxml', 'revzip')
DRIVERS = ('dbsqlite', 'dbmysql', 'dbpostgresql', 'dbodbc')
LICENCES = (('LICENSE', 'LICENSE'), ('LICENSE-EXCEPTION.md', 'LICENSE-EXCEPTION.md'),
            ('THIRD-PARTY-NOTICES.md', 'THIRD-PARTY-NOTICES.md'),
            ('ide/Open Source Licenses.txt', 'Open Source Licenses.txt'))
README = 'tools/oxt/server-readme.txt'

# (family, architecture as the engine's file header gives it)
Platform = collections.namedtuple('Platform', 'name family arch')
PLATFORMS = collections.OrderedDict((p.name, p) for p in (
    Platform('win-x86_64', 'windows', 'x86_64'),
    Platform('win-x86', 'windows', 'x86'),
    Platform('linux-x86_64', 'linux', 'x86_64'),
    Platform('linux-arm64', 'linux', 'arm64'),
    Platform('linux-x86', 'linux', 'x86'),
    Platform('mac-universal', 'mac', 'universal'),
    Platform('mac-arm64', 'mac', 'arm64'),
    Platform('mac-x86_64', 'mac', 'x86_64'),
))

LIB_SUFFIX = {'windows': '.dll', 'linux': '.so', 'mac': '.dylib'}
ELF_MACHINE = {'x86_64': 62, 'arm64': 183, 'x86': 3}
MACHO_CPU = {'x86_64': 0x01000007, 'arm64': 0x0100000c}


class ServerPackageError(Exception):
    pass


def zip_name(version, platform):
    return '%s-%s-%s-server.zip' % (PRODUCT, version, platform)


def read_version(repo):
    path = os.path.join(repo, 'ide', '.version')
    try:
        with open(path, encoding='utf-8') as f:
            version = f.read().strip()
    except OSError:
        raise ServerPackageError('%s is missing' % path)
    if not re.match(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$', version):
        raise ServerPackageError('%s holds %r, which is not usable as a version' % (path, version))
    return version


def wanted(p):
    """[(name in the zip, [names in the build output, first found wins])]."""
    exe = '.exe' if p.family == 'windows' else ''
    lib = LIB_SUFFIX[p.family]
    out = [(ENGINE + exe, ['server-community' + exe])]
    for folder, names in (('externals', EXTERNALS), ('drivers', DRIVERS)):
        for name in names:
            sources = ['server-%s%s' % (name, lib)]
            if p.family == 'windows':
                # LiveCode's builder did the same: Windows builds have no
                # server copy of these, or need none (the desktop DLLs do
                # not depend on the engine they are loaded into)
                sources.append(name + lib)
            out.append(('%s/%s%s' % (folder, name, lib), sources))
    return out


class Source(object):
    """The files at the top of a build output, from a folder, a tarball
    or a zip (whose one top-level folder is the build output)."""

    def __init__(self, path, kind):
        self.path, self.kind = path, kind
        self._members = None

    def _index(self):
        if self._members is not None:
            return self._members
        members = {}
        if self.kind == 'tar':
            # Read as a stream, once: keep the top-level files only, which is
            # all a server zip takes (the engine alone is about 20 MB)
            with tarfile.open(self.path, 'r|*') as tf:
                for m in tf:
                    parts = m.name.lstrip('./').split('/')
                    if len(parts) == 2 and m.isfile() and not parts[1].startswith('._'):
                        f = tf.extractfile(m)
                        members[parts[1]] = (f.read(), m.mode & 0o777, m.mtime)
        elif self.kind == 'zip':
            with zipfile.ZipFile(self.path) as z:
                for zi in z.infolist():
                    parts = zi.filename.split('/')
                    if len(parts) == 2 and parts[1] and not zi.is_dir():
                        mode = (zi.external_attr >> 16) & 0o777
                        members[parts[1]] = (z.read(zi), mode, time.mktime(zi.date_time + (0, 0, -1)))
        self._members = members
        return members

    def get(self, name):
        """(bytes, mode, mtime) or None."""
        if self.kind == 'dir':
            path = os.path.join(self.path, name)
            if not os.path.isfile(path):
                return None
            with open(path, 'rb') as f:
                data = f.read()
            st = os.stat(path)
            return data, st.st_mode & 0o777, st.st_mtime
        return self._index().get(name)


def check_engine(p, data):
    """None, or what is wrong with the engine's file format for p."""
    if p.family == 'windows':
        if data[:2] != b'MZ' or len(data) < 0x40:
            return 'not a Windows program (no MZ header)'
        pe = int.from_bytes(data[0x3c:0x40], 'little')
        if data[pe:pe + 4] != b'PE\0\0':
            return 'not a Windows program (no PE header)'
        machine = int.from_bytes(data[pe + 4:pe + 6], 'little')
        want = {'x86_64': 0x8664, 'x86': 0x14c}[p.arch]
        if machine != want:
            return 'a Windows program for machine 0x%x, not %s' % (machine, p.arch)
        return None
    if p.family == 'linux':
        if data[:4] != b'\x7fELF':
            return 'not an ELF file'
        machine = int.from_bytes(data[18:20], 'little')
        if machine != ELF_MACHINE[p.arch]:
            return 'an ELF file for machine %d, not %s' % (machine, p.arch)
        return None
    magic = data[:4]
    if magic == b'\xca\xfe\xba\xbe':
        count = int.from_bytes(data[4:8], 'big')
        cpus = {int.from_bytes(data[8 + 20 * i:12 + 20 * i], 'big') for i in range(count)}
    elif magic == b'\xcf\xfa\xed\xfe':
        cpus = {int.from_bytes(data[4:8], 'little')}
    else:
        return 'not a Mach-O file'
    want = set(MACHO_CPU.values()) if p.arch == 'universal' else {MACHO_CPU[p.arch]}
    if not want <= cpus:
        names = sorted(k for k, v in MACHO_CPU.items() if v in cpus) or ['none']
        return 'a Mach-O file for %s, not %s' % (', '.join(names), p.arch)
    return None


def readme_text(repo, version, p):
    with open(os.path.join(repo, *README.split('/')), encoding='utf-8') as f:
        text = f.read()
    exe = '.exe' if p.family == 'windows' else ''
    text = text.replace('{version}', version).replace('{platform}', p.name).replace('{engine}', ENGINE + exe)
    left = re.search(r'\{[a-z]+\}', text)
    if left:
        raise ServerPackageError('%s has an unknown placeholder %s' % (README, left.group(0)))
    if p.family == 'windows':
        text = text.replace('\r\n', '\n').replace('\n', '\r\n')
    return text.encode('utf-8')


def plan(p, source, repo, version):
    """[(name, bytes, mode)], sorted by name; the engine's mtime."""
    entries, missing, mtime = [], [], None
    for name, sources in wanted(p):
        found = None
        for s in sources:
            found = source.get(s)
            if found is not None:
                break
        if found is None:
            missing.append(' or '.join(sources))
            continue
        data, mode, file_mtime = found
        if name.startswith(ENGINE):
            problem = check_engine(p, data)
            if problem:
                raise ServerPackageError('%s: %s is %s' % (source.path, sources[0], problem))
            mtime = file_mtime
        entries.append((name, data))
    if missing:
        raise ServerPackageError('%s has no %s' % (source.path, ', '.join(missing)))
    out = []
    for name, data in entries:
        # The engine and the libraries 0755, as the build output has them
        out.append((name, data, 0o755))
    for src, name in LICENCES:
        path = os.path.join(repo, *src.split('/'))
        if not os.path.isfile(path):
            raise ServerPackageError('%s is missing' % path)
        with open(path, 'rb') as f:
            out.append((name, f.read(), 0o644))
    out.append(('README.txt', readme_text(repo, version, p), 0o644))
    out.sort(key=lambda e: (e[0].lower(), e[0]))
    return out, mtime


def zip_date(mtime):
    epoch = os.environ.get('SOURCE_DATE_EPOCH', '').strip()
    if re.match(r'^[0-9]+$', epoch):
        mtime = int(epoch)
    elif mtime is None:
        mtime = time.time()
    # zip dates start in 1980 and are local time, as unzip reads them
    return time.localtime(max(int(mtime), 315532800))[:6]


def write_zip(path, entries, date, level):
    folders = sorted({e[0].split('/')[0] + '/' for e in entries if '/' in e[0]})
    tmp = path + '.part'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED, allowZip64=True) as z:
        for name in folders:
            zi = zipfile.ZipInfo(name, date)
            zi.create_system = 3
            zi.external_attr = ((stat.S_IFDIR | 0o755) << 16) | 0x10
            z.writestr(zi, b'')
        for name, data, mode in entries:
            zi = zipfile.ZipInfo(name, date)
            zi.create_system = 3
            zi.external_attr = (stat.S_IFREG | mode) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            try:
                zi.compress_level = level
            except AttributeError:
                zi._compresslevel = level
            z.writestr(zi, data)
    os.replace(tmp, path)
    return len(folders) + len(entries)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def add_to_sums(out, name):
    """Adds (or replaces) name's line in out/SHA256SUMS."""
    sums = os.path.join(out, 'SHA256SUMS')
    lines = []
    if os.path.isfile(sums):
        with open(sums, 'rb') as f:
            for line in f.read().decode('utf-8').splitlines():
                if line.strip() and line.split('  ', 1)[-1].lstrip('*') != name:
                    lines.append(line)
    lines.append('%s  %s' % (sha256(os.path.join(out, name)), name))
    with open(sums, 'wb') as f:
        f.write(('\n'.join(lines) + '\n').encode('utf-8'))


def package(platform, source, out, repo=REPO, version=None, level=9, sums=False, log=print):
    p = PLATFORMS[platform]
    version = version or read_version(repo)
    entries, mtime = plan(p, source, repo, version)
    os.makedirs(out, exist_ok=True)
    name = zip_name(version, platform)
    path = os.path.join(out, name)
    count = write_zip(path, entries, zip_date(mtime), level)
    log('Server zip   : %s (%d entries, %d bytes)' % (path, count, os.path.getsize(path)))
    for entry, data, mode in entries:
        log('  %-36s %10d  %o' % (entry, len(data), mode))
    if sums:
        add_to_sums(out, name)
        log('SHA256SUMS   : %s added' % name)
    return path


def github_output(**values):
    path = os.environ.get('GITHUB_OUTPUT')
    if path:
        with open(path, 'a', encoding='utf-8') as f:
            for k, v in values.items():
                f.write('%s=%s\n' % (k, v))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--platform', required=True, choices=list(PLATFORMS))
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument('--bin', help='the build output folder')
    src.add_argument('--bin-tar', help='a tarball of the build output (CI bin artifact or release binaries)')
    src.add_argument('--bin-zip', help='a zip of the build output (the Windows binaries zip)')
    ap.add_argument('--out', required=True, help='folder to write the zip to')
    ap.add_argument('--repo', default=REPO, help='the checkout (version, licence files, README)')
    ap.add_argument('--version', help='the version in the zip\'s name (default: ide/.version)')
    ap.add_argument('--sums', action='store_true', help='add the zip to --out\'s SHA256SUMS')
    ap.add_argument('--zip-level', type=int, default=9, choices=range(0, 10), metavar='N')
    args = ap.parse_args(argv)
    if args.bin:
        source = Source(args.bin, 'dir')
    elif args.bin_tar:
        source = Source(args.bin_tar, 'tar')
    else:
        source = Source(args.bin_zip, 'zip')
    try:
        path = package(args.platform, source, args.out, repo=args.repo, version=args.version,
                       level=args.zip_level, sums=args.sums)
    except (ServerPackageError, OSError, tarfile.TarError, zipfile.BadZipFile) as e:
        msg = str(e)
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error title=Server zip::%s' % msg)
        print('package_server.py: %s' % msg, file=sys.stderr)
        return 1
    github_output(zip=path, name=os.path.basename(path))
    return 0


if __name__ == '__main__':
    sys.exit(main())
