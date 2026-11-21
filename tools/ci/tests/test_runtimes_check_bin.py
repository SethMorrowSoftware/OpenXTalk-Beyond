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

"""One platform's build, checked for what the runtimes asset takes from it
(make_runtimes_asset.py --check-bin), in that platform's own CI build.

The runtimes asset (oxt-runtimes-<label>) is made from four builds
(win-x86, win-x86_64, linux-x86, linux-x86_64) by runtimes.yml, run by
hand before a release. Before this check, a file the asset wants that a
build had stopped making was found only then, the day of the release, not
the day the build changed (the follow-up of 0.2.8-dp.2). --check-bin plans
and checks each build given as --builds does (plan_build_parts,
check_build) and writes nothing, and build-windows.yml and build-linux.yml
run it on the archive of each of the four builds, the one runtimes.yml
takes.

These build made-up build outputs from what the real planner asks for:
every file it names, binaries with an ELF or PE header of the build's
architecture, and a Standalone that carries this tree's engine version.
No build, download or engine is needed.

  python3 -m unittest discover -s tools/ci/tests -p test_runtimes_check_bin.py
"""

import contextlib
import io
import os
import re
import shutil
import struct
import sys
import tarfile
import tempfile
import unittest
import zipfile
from unittest import mock

TESTS = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(TESTS)
REPO = os.path.dirname(os.path.dirname(CI))
OXT = os.path.join(REPO, 'tools', 'oxt')
for p in (TESTS, CI, OXT):
    if p not in sys.path:
        sys.path.insert(0, p)

import make_runtimes_asset as mra  # noqa: E402
import package  # noqa: E402

WORKFLOWS = os.path.join(REPO, '.github', 'workflows')
VERSION = mra.engine_version(REPO)
ELF = {'x86': 3, 'x86_64': 62}
PE = {'x86': 0x14c, 'x86_64': 0x8664}
MISSING = re.compile(r'^build output (folder )?missing: (.+) \(for (.+)\)$')
# the one file a made-up folder that the asset takes holds
IN_FOLDER = {'locales': 'en-US.pak', 'resources': 'zoneinfo.txt'}


def binary(fmt, arch, extra=b''):
    """A file the format and architecture checks read as fmt (elf or pe)
    and arch, with extra after the header."""
    if fmt == 'elf':
        head = b'\x7fELF' + bytes([2 if arch == 'x86_64' else 1, 1, 1])
        head = head.ljust(18, b'\0') + struct.pack('<H', ELF[arch])
    else:
        head = b'MZ'.ljust(0x3c, b'\0') + struct.pack('<I', 0x40)
        head += b'PE\0\0' + struct.pack('<H', PE[arch])
    return head.ljust(64, b'\0') + extra


def make_build(name, folder, arch=None, version=VERSION):
    """A made-up build output folder of the build name, with every file
    plan_build_parts asks for: binaries of arch (the build's by default),
    a Standalone carrying version. Returns folder."""
    _, fmt, own = mra.BUILDS[name]
    arch = arch or own
    os.makedirs(folder, exist_ok=True)
    for _ in range(3):
        _, problems = mra.plan_build_parts(name, folder)
        if not problems:
            return folder
        for line in problems:
            m = MISSING.match(line)
            if not m:
                raise AssertionError('not a missing file: %s' % line)
            is_folder, rel, target = m.group(1), m.group(2), m.group(3)
            path = os.path.join(folder, *rel.split('/'))
            if is_folder:
                os.makedirs(path, exist_ok=True)
                last = rel.rsplit('/', 1)[-1]
                # a timezone code folder holds the library, of the build's kind
                inner = IN_FOLDER.get(last, 'tz.dll' if fmt == 'pe' else 'libtz.so')
                path = os.path.join(path, inner)
                target = target + '/' + inner
            os.makedirs(os.path.dirname(path), exist_ok=True)
            if target.endswith('/Standalone'):
                data = binary(fmt, arch, b'\0engine ' + version.encode('ascii') + b'\0')
            elif mra.BINARY_NAMES.search(target):
                data = binary(fmt, arch)
            else:
                data = ('%s of %s\n' % (rel, name)).encode('ascii')
            with open(path, 'wb') as f:
                f.write(data)
    raise AssertionError('%s: the planner still asks for %s' % (name, problems))


def run(*argv):
    """(exit code, output) of make_runtimes_asset.py with argv."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = mra.main(list(argv))
    return code, buf.getvalue()


def tar_of(folder, path):
    """The CI's tarball of a build output folder: that folder alone, by its
    name (build-linux.yml's "Package the bin folder" step)."""
    with tarfile.open(path, 'w:xz') as tf:
        tf.add(folder, arcname=os.path.basename(folder))
    return path


def zip_of(folder, path, beside=()):
    """The CI's zip of a build output folder: that folder by its name, and
    the files beside it that the binaries zip has (the licence files)."""
    top = os.path.basename(folder)
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(folder):
            for f in files:
                full = os.path.join(root, f)
                z.write(full, top + '/' + os.path.relpath(full, folder).replace(os.sep, '/'))
        for name in beside:
            z.writestr(name, 'licence\n')
    return path


class Temp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        # the tool's own work folder goes here, to see that it is removed
        self.work = os.path.join(self.tmp, 'work')
        os.makedirs(self.work)
        p = mock.patch.object(tempfile, 'tempdir', self.work)
        p.start()
        self.addCleanup(p.stop)

    def build(self, name, **kw):
        return make_build(name, os.path.join(self.tmp, 'builds', name, package.PLATFORMS[name].bin_default), **kw)


# ---------------------------------------------------------------------------
# The check

class CheckBin(Temp):
    def test_each_complete_build_passes_and_nothing_is_written(self):
        for name in mra.BUILDS:
            with self.subTest(name):
                folder = self.build(name)
                before = sorted(os.walk(folder))
                code, out = run('--check-bin', '%s=%s' % (name, folder))
                self.assertEqual(code, 0, out)
                self.assertIn('%s: every file the runtimes asset takes is there' % name, out)
                self.assertIn(VERSION, out)
                self.assertNotIn('error:', out)
                self.assertEqual(sorted(os.walk(folder)), before)
                self.assertEqual(os.listdir(self.work), [], 'the work folder is left behind')

    def test_a_file_the_asset_wants_that_the_build_did_not_make(self):
        for name, rel in (('win-x86', 'revzip.dll'), ('win-x86_64', 'Externals/CEF/libcef.dll'),
                          ('linux-x86', 'revpdfprinter.so'), ('linux-x86_64', 'standalone-community')):
            with self.subTest(name):
                folder = self.build(name)
                os.remove(os.path.join(folder, *rel.split('/')))
                code, out = run('--check-bin', '%s=%s' % (name, folder))
                self.assertEqual(code, 1, out)
                self.assertRegex(out, r'error: %s: build output missing: %s \(for Runtime/'
                                 % (re.escape(name), re.escape(rel)))
                self.assertIn('could not be made from this build', out)
                self.assertNotIn('every file the runtimes asset takes is there', out)

    def test_a_folder_the_asset_wants_that_the_build_did_not_make(self):
        folder = self.build('linux-x86_64')
        shutil.rmtree(os.path.join(folder, 'packaged_extensions', 'com.livecode.library.timezone', 'resources'))
        code, out = run('--check-bin', 'linux-x86_64=%s' % folder)
        self.assertEqual(code, 1, out)
        self.assertIn('error: linux-x86_64: build output folder missing: '
                      'packaged_extensions/com.livecode.library.timezone/resources', out)

    def test_a_binary_of_another_architecture(self):
        folder = self.build('linux-x86_64')
        with open(os.path.join(folder, 'revxml.so'), 'wb') as f:
            f.write(binary('elf', 'x86'))
        code, out = run('--check-bin', 'linux-x86_64=%s' % folder)
        self.assertEqual(code, 1, out)
        self.assertIn('error: Runtime/Linux/x86-64/Externals/revxml.so (from linux-x86_64) is ELF x86, '
                      'expected ELF x86_64', out)

    def test_a_build_of_another_platform(self):
        # the 64-bit Windows build given as the 32-bit one: every binary is
        # named, of the wrong architecture
        folder = self.build('win-x86', arch='x86_64')
        code, out = run('--check-bin', 'win-x86=%s' % folder)
        self.assertEqual(code, 1, out)
        self.assertIn('error: Runtime/Windows/x86-32/Standalone (from win-x86) is PE x86_64, expected PE x86', out)
        self.assertIn('error: Runtime/Windows/x86-32/Externals/revzip.dll (from win-x86) is PE x86_64, '
                      'expected PE x86', out)

    def test_a_standalone_without_this_trees_engine_version(self):
        folder = self.build('win-x86_64', version='9.6.3')
        code, out = run('--check-bin', 'win-x86_64=%s' % folder)
        self.assertEqual(code, 1, out)
        self.assertIn('error: Runtime/Windows/x86-64/Standalone (from win-x86_64) does not carry the engine '
                      'version %s (found: 9.6.3)' % VERSION, out)

    def test_several_builds_each_named(self):
        good = self.build('linux-x86')
        bad = self.build('linux-x86_64')
        os.remove(os.path.join(bad, 'revdb.so'))
        code, out = run('--check-bin', 'linux-x86=%s' % good, '--check-bin', 'linux-x86_64=%s' % bad)
        self.assertEqual(code, 1, out)
        self.assertIn('linux-x86: ', out)
        self.assertIn('error: linux-x86_64: build output missing: revdb.so', out)
        self.assertNotIn('error: linux-x86:', out)
        self.assertIn('error: 1 problems:', out)


class Archives(Temp):
    """The archives the CI uploads, which runtimes.yml takes"""

    def test_the_linux_tarball(self):
        folder = self.build('linux-x86_64')
        tar = tar_of(folder, os.path.join(self.tmp, 'OXT-Beyond-linux-x86_64-bin.tar.xz'))
        code, out = run('--check-bin', 'linux-x86_64=%s' % tar)
        self.assertEqual(code, 0, out)
        self.assertIn('linux-x86_64: extracting', out)
        self.assertEqual(os.listdir(self.work), [], 'the extracted build is left behind')

    def test_a_linux_tarball_without_a_file(self):
        folder = self.build('linux-x86')
        os.remove(os.path.join(folder, 'dbsqlite.so'))
        tar = tar_of(folder, os.path.join(self.tmp, 'OXT-Beyond-linux-x86-bin.tar.xz'))
        code, out = run('--check-bin', 'linux-x86=%s' % tar)
        self.assertEqual(code, 1, out)
        self.assertIn('error: linux-x86: build output missing: dbsqlite.so', out)
        self.assertEqual(os.listdir(self.work), [], 'the extracted build is left behind')

    def test_the_windows_zips(self):
        # the win-x86 job's bin zip, and the win-x86_64 job's binaries zip,
        # which has the licence files beside the folder
        for name, beside in (('win-x86', ()), ('win-x86_64', ('LICENSE', 'THIRD-PARTY-NOTICES.md'))):
            with self.subTest(name):
                folder = self.build(name)
                z = zip_of(folder, os.path.join(self.tmp, '%s.zip' % name), beside)
                code, out = run('--check-bin', '%s=%s' % (name, z))
                self.assertEqual(code, 0, out)
                os.remove(os.path.join(folder, 'revsecurity.dll'))
                z = zip_of(folder, os.path.join(self.tmp, '%s-less.zip' % name), beside)
                code, out = run('--check-bin', '%s=%s' % (name, z))
                self.assertEqual(code, 1, out)
                self.assertIn('error: %s: build output missing: revsecurity.dll' % name, out)
                self.assertEqual(os.listdir(self.work), [], 'the extracted build is left behind')


class Options(Temp):
    def refused(self, *argv):
        err = io.StringIO()
        with contextlib.redirect_stderr(err), self.assertRaises(SystemExit) as cm:
            run(*argv)
        return cm.exception.code, err.getvalue()

    def test_no_other_option(self):
        folder = self.build('linux-x86')
        for extra in (('--out', self.tmp), ('--builds',), ('--label', 'x'), ('--bin', 'linux-x86=%s' % folder)):
            with self.subTest(extra):
                code, err = self.refused('--check-bin', 'linux-x86=%s' % folder, *extra)
                self.assertEqual(code, 2)
                self.assertIn('--check-bin takes no other option', err)

    def test_a_build_the_asset_does_not_take(self):
        with self.assertRaises(SystemExit) as cm:
            run('--check-bin', 'linux-arm64=%s' % self.tmp)
        self.assertIn('linux-arm64 is not one of win-x86, win-x86_64, linux-x86, linux-x86_64', str(cm.exception.code))

    def test_no_such_build(self):
        with self.assertRaises(SystemExit) as cm:
            run('--check-bin', 'linux-x86=%s' % os.path.join(self.tmp, 'nothing'))
        self.assertIn('no such folder or file', str(cm.exception.code))

    def test_out_is_still_needed_to_make_an_asset(self):
        code, err = self.refused('--builds', '--label', 'x')
        self.assertEqual(code, 2)
        self.assertIn('--out is needed', err)


# ---------------------------------------------------------------------------
# The workflows

def workflow(name):
    import yaml
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        return yaml.safe_load(f)


def check_steps(job):
    """The steps of a job that run --check-bin, with their command lines
    (continuations joined)"""
    found = []
    for s in job.get('steps', []):
        text = re.sub(r'\\\n\s*', '', s.get('run', ''))
        lines = [' '.join(x.split()) for x in text.splitlines()
                 if re.match(r'\s*python3? tools/oxt/make_runtimes_asset\.py ', x)]
        if any('--check-bin' in x for x in lines):
            found.append((s, lines))
    return found


class Workflows(unittest.TestCase):
    """Each of the four builds checks itself, on the archive that
    runtimes.yml takes from it, once that archive is made"""

    @classmethod
    def setUpClass(cls):
        try:
            import yaml  # noqa: F401
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.windows = workflow('build-windows.yml')['jobs']
        cls.linux = workflow('build-linux.yml')['jobs']
        with open(os.path.join(WORKFLOWS, 'runtimes.yml'), encoding='utf-8') as f:
            cls.runtimes = f.read()

    def one(self, job):
        found = check_steps(job)
        self.assertEqual(len(found), 1, [s.get('name') for s, _ in found])
        step, lines = found[0]
        self.assertEqual(len(lines), 1, lines)
        names = [s.get('name') for s in job['steps']]
        return step, lines[0], names.index(step['name']), names

    def after(self, names, at, step_name):
        self.assertIn(step_name, names)
        self.assertGreater(at, names.index(step_name), 'the check runs before "%s"' % step_name)

    def test_win_x86(self):
        step, line, at, names = self.one(self.windows['build-x86'])
        self.assertIn('--check-bin "win-x86=OXT-Beyond-win-x86-bin.zip"', line)
        self.assertIn('$LASTEXITCODE', step['run'])
        self.after(names, at, 'Upload the bin folder')
        self.after(names, at, 'Standalone check (build output)')
        self.assertNotIn('if', step)
        self.assertIn('OXT-Beyond-win-x86-bin.zip', self.runtimes)

    def test_win_x86_64(self):
        step, line, at, names = self.one(self.windows['build'])
        self.assertIn('--check-bin "win-x86_64=$zip"', line)
        self.assertIn('$zip = "dist/OXT-Beyond-$env:VERSION-win-x86_64-binaries.zip"', step['run'])
        self.assertIn('$LASTEXITCODE', step['run'])
        self.assertEqual(step['env']['VERSION'], '${{ steps.product.outputs.version }}')
        self.after(names, at, 'Package')
        self.after(names, at, 'Upload packages')
        self.assertNotIn('if', step)
        self.assertIn('OXT-Beyond-*-win-x86_64-binaries.zip', self.runtimes)
        # and the failure diagnostics name it
        diag = next(s for s in self.windows['build']['steps'] if s.get('name') == 'Report failure diagnostics')
        self.assertEqual(diag['env']['RUNTIMES_CHECK_OUTCOME'], '${{ steps.%s.outcome }}' % step['id'])
        self.assertIn("'Runtimes asset check' = $env:RUNTIMES_CHECK_OUTCOME", diag['run'])

    def test_linux_x86_64(self):
        job = self.linux['build']
        step, line, at, names = self.one(job)
        self.assertIn('--check-bin "linux-$ARCH=OXT-Beyond-linux-$ARCH-bin.tar.xz"', line)
        self.assertTrue(line.startswith('python3 '), line)
        # the asset takes nothing from arm64
        self.assertEqual(step['if'], "matrix.arch == 'x86_64'")
        self.assertEqual([m['arch'] for m in job['strategy']['matrix']['include']], ['x86_64', 'arm64'])
        self.after(names, at, 'Upload the bin folder')
        # before the leg records that it is built, which the package job needs
        self.assertLess(at, names.index('Record the finished build'))
        self.assertIn('OXT-Beyond-linux-x86_64-bin.tar.xz', self.runtimes)

    def test_linux_x86(self):
        step, line, at, names = self.one(self.linux['build-x86'])
        self.assertIn('--check-bin "linux-x86=OXT-Beyond-linux-x86-bin.tar.xz"', line)
        # on the runner, not in the i386 container
        self.assertTrue(line.startswith('python3 '), line)
        self.assertNotIn('i386-container.sh', step['run'])
        self.after(names, at, 'Upload the bin folder')
        self.after(names, at, 'Standalone check (build output)')
        self.assertIn('OXT-Beyond-linux-x86-bin.tar.xz', self.runtimes)

    def test_every_build_the_asset_takes_is_checked(self):
        checked = set()
        for jobs in (self.windows, self.linux):
            for job in jobs.values():
                for _, lines in check_steps(job):
                    for line in lines:
                        checked.update(m.group(1) for m in re.finditer(r'--check-bin "([a-z0-9_-]+|linux-\$ARCH)=',
                                                                         line))
        checked = {'linux-x86_64' if c == 'linux-$ARCH' else c for c in checked}
        self.assertEqual(checked, set(mra.BUILDS))


if __name__ == '__main__':
    unittest.main()
