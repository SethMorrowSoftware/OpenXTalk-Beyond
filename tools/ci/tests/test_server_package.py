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

"""tools/oxt/package_server.py, which writes the server zips, and the parts
of tools/ci/server_check.py that need no engine, on made-up build outputs.
The engine itself is checked by server_check.py in the build workflows.

  python3 -m unittest discover -s tools/ci/tests
"""

import io
import os
import shutil
import stat
import sys
import tarfile
import tempfile
import time
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import package_server  # noqa: E402
import server_check  # noqa: E402

VERSION = '1.2.3-rc.4'


def quiet(*args):
    pass


def pe(machine):
    head = bytearray(0x80)
    head[0:2] = b'MZ'
    head[0x3c:0x40] = (0x40).to_bytes(4, 'little')
    head[0x40:0x44] = b'PE\0\0'
    head[0x44:0x46] = machine.to_bytes(2, 'little')
    return bytes(head)


def elf(machine):
    head = bytearray(64)
    head[0:4] = b'\x7fELF'
    head[18:20] = machine.to_bytes(2, 'little')
    return bytes(head)


def fat(*cpus):
    out = b'\xca\xfe\xba\xbe' + len(cpus).to_bytes(4, 'big')
    for cpu in cpus:
        out += cpu.to_bytes(4, 'big') + bytes(16)
    return out


ENGINES = {
    'win-x86_64': pe(0x8664),
    'win-x86': pe(0x14c),
    'linux-x86_64': elf(62),
    'linux-arm64': elf(183),
    'mac-universal': fat(0x01000007, 0x0100000c),
}


class PackageServerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.out = os.path.join(self.tmp, 'dist')

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def build_output(self, platform, skip=(), desktop_only=False, engine=None):
        """A build output folder with what the build makes for the server."""
        p = package_server.PLATFORMS[platform]
        folder = os.path.join(self.tmp, 'bin-' + platform)
        os.makedirs(folder)
        exe = '.exe' if p.family == 'windows' else ''
        lib = package_server.LIB_SUFFIX[p.family]
        files = {'server-community' + exe: engine or ENGINES[platform],
                 'LiveCode-Community' + exe: b'the IDE engine, not for the zip'}
        for name in package_server.EXTERNALS + package_server.DRIVERS:
            if p.family == 'windows' and desktop_only:
                files[name + lib] = ('desktop ' + name).encode()
            else:
                files['server-' + name + lib] = ('server ' + name).encode()
                files[name + lib] = ('desktop ' + name).encode()
        for name, data in files.items():
            if name in skip:
                continue
            with open(os.path.join(folder, name), 'wb') as f:
                f.write(data)
            os.chmod(os.path.join(folder, name), 0o755)
        return folder

    def package(self, platform, source, **kw):
        return package_server.package(platform, source, self.out, version=VERSION, log=quiet, **kw)

    def entries(self, path):
        with zipfile.ZipFile(path) as z:
            return {zi.filename: (z.read(zi), (zi.external_attr >> 16)) for zi in z.infolist()}

    def test_the_layout_of_livecodes_server_zip(self):
        for platform in ('linux-x86_64', 'mac-universal', 'win-x86_64'):
            with self.subTest(platform=platform):
                p = package_server.PLATFORMS[platform]
                path = self.package(platform, package_server.Source(self.build_output(platform), 'dir'))
                self.assertEqual(os.path.basename(path), 'OXT-Beyond-%s-%s-server.zip' % (VERSION, platform))
                got = self.entries(path)
                exe = '.exe' if p.family == 'windows' else ''
                lib = package_server.LIB_SUFFIX[p.family]
                want = {'livecode-community-server' + exe, 'externals/', 'drivers/', 'README.txt', 'LICENSE',
                        'LICENSE-EXCEPTION.md', 'THIRD-PARTY-NOTICES.md', 'Open Source Licenses.txt'}
                want |= {'externals/%s%s' % (n, lib) for n in ('revdb', 'revxml', 'revzip')}
                want |= {'drivers/%s%s' % (n, lib) for n in ('dbsqlite', 'dbmysql', 'dbpostgresql', 'dbodbc')}
                self.assertEqual(set(got), want)
                self.assertEqual(got['livecode-community-server' + exe][0], ENGINES[platform])
                # the server's own builds of the externals, not the desktop's
                self.assertEqual(got['externals/revdb' + lib][0], b'server revdb')
                self.assertEqual(stat.S_IMODE(got['livecode-community-server' + exe][1]), 0o755)
                self.assertEqual(stat.S_IMODE(got['README.txt'][1]), 0o644)
                self.assertTrue(stat.S_ISDIR(got['drivers/'][1]))
                os.remove(path)

    def test_windows_takes_the_desktop_dlls_the_build_has_no_server_copy_of(self):
        path = self.package('win-x86_64', package_server.Source(
            self.build_output('win-x86_64', desktop_only=True), 'dir'))
        got = self.entries(path)
        self.assertEqual(got['drivers/dbsqlite.dll'][0], b'desktop dbsqlite')
        self.assertEqual(got['externals/revxml.dll'][0], b'desktop revxml')

    def test_linux_never_takes_a_desktop_library(self):
        folder = self.build_output('linux-x86_64', skip=('server-dbodbc.so',))
        with self.assertRaisesRegex(package_server.ServerPackageError, 'server-dbodbc.so'):
            self.package('linux-x86_64', package_server.Source(folder, 'dir'))
        self.assertFalse(os.path.exists(self.out) and os.listdir(self.out))

    def test_a_missing_engine_writes_nothing(self):
        folder = self.build_output('mac-universal', skip=('server-community',))
        with self.assertRaisesRegex(package_server.ServerPackageError, 'server-community'):
            self.package('mac-universal', package_server.Source(folder, 'dir'))

    def test_an_engine_of_another_platform_is_refused(self):
        cases = (('linux-arm64', elf(62), 'not arm64'), ('win-x86_64', pe(0x14c), 'not x86_64'),
                 ('mac-universal', fat(0x0100000c), 'arm64, not universal'),
                 ('linux-x86_64', pe(0x8664), 'not an ELF file'))
        for platform, engine, message in cases:
            with self.subTest(platform=platform):
                folder = self.build_output(platform, engine=engine)
                with self.assertRaisesRegex(package_server.ServerPackageError, message):
                    self.package(platform, package_server.Source(folder, 'dir'))
                shutil.rmtree(folder)

    def test_from_a_ci_bin_tarball(self):
        folder = self.build_output('linux-arm64')
        tar = os.path.join(self.tmp, 'OXT-Beyond-linux-arm64-bin.tar.xz')
        with tarfile.open(tar, 'w:xz') as tf:
            tf.add(folder, arcname='linux-arm64-bin')
            # a debug file and macOS tar's AppleDouble file are ignored
            data = b'not a library'
            for name in ('linux-arm64-bin/._server-revdb.so', 'linux-arm64-bin/sub/server-revdb.so'):
                ti = tarfile.TarInfo(name)
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
        got = self.entries(self.package('linux-arm64', package_server.Source(tar, 'tar')))
        self.assertEqual(got['externals/revdb.so'][0], b'server revdb')
        self.assertEqual(got['livecode-community-server'][0], ENGINES['linux-arm64'])

    def test_from_the_windows_binaries_zip(self):
        folder = self.build_output('win-x86_64')
        zpath = os.path.join(self.tmp, 'OXT-Beyond-9-win-x86_64-binaries.zip')
        with zipfile.ZipFile(zpath, 'w') as z:
            for name in os.listdir(folder):
                z.write(os.path.join(folder, name), 'win-x86_64-bin/' + name)
            z.writestr('LICENSE', 'licence at the top, not in the build output')
        got = self.entries(self.package('win-x86_64', package_server.Source(zpath, 'zip')))
        self.assertEqual(got['livecode-community-server.exe'][0], ENGINES['win-x86_64'])

    def test_the_readme_is_filled_in(self):
        path = self.package('win-x86_64', package_server.Source(self.build_output('win-x86_64'), 'dir'))
        text = self.entries(path)['README.txt'][0].decode('utf-8')
        self.assertIn('OXT-Beyond Server %s (win-x86_64)' % VERSION, text)
        self.assertIn('livecode-community-server.exe', text)
        self.assertNotRegex(text, r'\{[a-z]+\}')
        self.assertIn('\r\n', text)
        self.assertNotIn('\r\r', text)

    def test_sums_line_added_once(self):
        os.makedirs(self.out)
        with open(os.path.join(self.out, 'SHA256SUMS'), 'w') as f:
            f.write('%s  other.zip\n%s  OXT-Beyond-%s-linux-x86_64-server.zip\n' % ('0' * 64, '1' * 64, VERSION))
        path = self.package('linux-x86_64', package_server.Source(self.build_output('linux-x86_64'), 'dir'),
                            sums=True)
        with open(os.path.join(self.out, 'SHA256SUMS')) as f:
            lines = f.read().splitlines()
        self.assertEqual(lines[0], '%s  other.zip' % ('0' * 64))
        self.assertEqual(lines[1], '%s  %s' % (package_server.sha256(path), os.path.basename(path)))
        self.assertEqual(len(lines), 2)

    def test_source_date_epoch_makes_the_same_zip(self):
        folder = self.build_output('linux-x86_64')
        old = os.environ.get('SOURCE_DATE_EPOCH')
        os.environ['SOURCE_DATE_EPOCH'] = '1700000000'
        try:
            a = package_server.sha256(self.package('linux-x86_64', package_server.Source(folder, 'dir')))
            os.utime(os.path.join(folder, 'server-community'), (time.time(), time.time() - 86400))
            b = package_server.sha256(self.package('linux-x86_64', package_server.Source(folder, 'dir')))
        finally:
            if old is None:
                del os.environ['SOURCE_DATE_EPOCH']
            else:
                os.environ['SOURCE_DATE_EPOCH'] = old
        self.assertEqual(a, b)

    def test_main_reports_a_failure_with_status_1(self):
        folder = self.build_output('linux-x86_64', skip=('server-revzip.so',))
        stderr = sys.stderr
        sys.stderr = io.StringIO()
        try:
            status = package_server.main(['--platform', 'linux-x86_64', '--bin', folder, '--out', self.out])
        finally:
            sys.stderr = stderr
        self.assertEqual(status, 1)


class ServerCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_cgi_output_with_either_line_end(self):
        for eol in (b'\n', b'\r\n'):
            r = server_check.parse_cgi(b'Status: 404 Not Found' + eol + b'Content-Type: text/plain' + eol +
                                       b'Set-Cookie: a=1; Path=/' + eol + eol + b'name=x y;' + eol + b'gone')
            self.assertEqual(r.status, 404)
            self.assertEqual(r.header('content-type'), 'text/plain')
            self.assertEqual(r.cookie('a'), 'a=1; Path=/')
            self.assertEqual(r.field('name'), 'x y')
            self.assertIsNone(r.field('gone'))

    def test_no_headers_is_no_status(self):
        r = server_check.parse_cgi(b'')
        self.assertIsNone(r.status)

    def test_fields_keep_their_bytes(self):
        r = server_check.Response(200, [], b'data=a\x00\xff\nb;\nnext=1;\n')
        self.assertEqual(r.field_bytes('data'), b'a\x00\xff\nb')
        self.assertEqual(r.field('next'), '1')

    def test_fields_on_every_platforms_line_ends(self):
        # The engine writes return as LF on Linux, CR LF on Windows and CR
        # on macOS; the first CI runs on Windows and macOS met the last two.
        for end in (b'\n', b'\r\n', b'\r'):
            body = b'name=a b;' + end + b'zip=inside.txt' + end + b';' + end + b'last=1;' + end
            r = server_check.Response(200, [], body)
            self.assertEqual(r.field('name'), 'a b', end)
            self.assertEqual(server_check.line_ends(r.field('zip')), 'inside.txt\n', end)
            self.assertEqual(r.field('last'), '1', end)
            self.assertIsNone(r.field('b'), end)

    def test_extract_keeps_modes_and_refuses_paths_out(self):
        good = os.path.join(self.tmp, 'good.zip')
        with zipfile.ZipFile(good, 'w') as z:
            zi = zipfile.ZipInfo('livecode-community-server')
            zi.external_attr = (stat.S_IFREG | 0o755) << 16
            z.writestr(zi, b'x')
            z.writestr('externals/revdb.so', b'y')
        dest = os.path.join(self.tmp, 'out')
        os.makedirs(dest)
        server_check.extract(good, dest)
        if os.name != 'nt':
            self.assertTrue(os.access(os.path.join(dest, 'livecode-community-server'), os.X_OK))
        self.assertTrue(os.path.isfile(os.path.join(dest, 'externals', 'revdb.so')))
        bad = os.path.join(self.tmp, 'bad.zip')
        with zipfile.ZipFile(bad, 'w') as z:
            z.writestr('../escape', b'x')
        with self.assertRaises(server_check.CheckError):
            server_check.extract(bad, dest)

    def test_the_layout_check_wants_exactly_the_packaged_files(self):
        dest = os.path.join(self.tmp, 'server')
        p = package_server.PLATFORMS['linux-x86_64']
        names = [n for n, _ in package_server.wanted(p)] + [n for _, n in package_server.LICENCES] + ['README.txt']
        for name in names:
            path = os.path.join(dest, *name.split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as f:
                f.write(b'x')
            os.chmod(path, 0o755)
        results = server_check.Results(quiet)
        server_check.check_layout(p, dest, results)
        self.assertEqual(results.failed, 0)
        os.remove(os.path.join(dest, 'drivers', 'dbodbc.so'))
        results = server_check.Results(quiet)
        server_check.check_layout(p, dest, results)
        self.assertEqual(results.failed, 1)

    def test_the_apache_check_uses_the_readmes_lines(self):
        # The check's Apache set-up is the one the README tells users to
        # make, so that a passing check says the README's set-up works
        with open(os.path.join(REPO, *package_server.README.split('/')), encoding='utf-8') as f:
            readme = f.read()
        with open(os.path.join(REPO, 'tools', 'ci', 'server_check.py'), encoding='utf-8') as f:
            check = f.read()
        for line in ('AddHandler livecode-script .lc', 'Action livecode-script /livecode-cgi/{engine}',
                     'Options +ExecCGI'):
            self.assertIn(line, readme)
            self.assertIn(line, check)

    def test_every_case_names_a_page(self):
        for name, req, checks in server_check.CASES:
            self.assertIn(req.page, server_check.PAGES, name)
            self.assertTrue(checks, name)

    def test_engine_version_is_major_minor_point(self):
        self.assertRegex(server_check.engine_version(REPO), r'^\d+\.\d+\.\d+$')


if __name__ == '__main__':
    unittest.main()
