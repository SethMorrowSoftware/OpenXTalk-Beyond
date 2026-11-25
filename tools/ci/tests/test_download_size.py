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

"""The three ways the release downloads were made smaller without changing
a single installed file (0.2.8-dp.2.1 sizes in brackets):

  * the Linux and macOS tarballs use xz preset 9, not 6 (Linux package
    707 MB -> 638 MB): tools/oxt/package_dist.py XZ_PRESET;
  * the macOS disk image is LZMA (ULMO), not zlib (UDZO) (1,056 MB ->
    about 850 MB), for an app that needs macOS 10.15 or later
    (package_dist.dmg_format), and zlib as before for any other;
  * the Windows installer stores the IDE's CEF folder once, from the
    identical runtime copy (859 MB -> about 725 MB):
    Installer/oxt-beyond/oxt-beyond.iss SharedCefSource, defined by
    tools/ci/build-installer.ps1 only when the folders are identical, and
    checked byte for byte after installing by tools/ci/test-installer.ps1.

The installer itself is built and installed by the Windows CI; here its
[Files] entries are evaluated as Inno Setup evaluates them, on a made-up
stage, to show that both forms install the same files.

  python3 -m unittest discover -s tools/ci/tests
"""

import fnmatch
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import package_dist  # noqa: E402

ISS = os.path.join(REPO, 'Installer', 'oxt-beyond', 'oxt-beyond.iss')
BUILD_INSTALLER = os.path.join(REPO, 'tools', 'ci', 'build-installer.ps1')
TEST_INSTALLER = os.path.join(REPO, 'tools', 'ci', 'test-installer.ps1')
BUILD_MACOS = os.path.join(REPO, '.github', 'workflows', 'build-macos.yml')
RUNTIME_CEF = r'Runtime\Windows\x86-64\Externals\CEF'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class XzPreset(unittest.TestCase):

    def test_default_is_nine(self):
        self.assertEqual(package_dist.XZ_PRESET, 9)
        self.assertIn("default=XZ_PRESET", read(package_dist.__file__))

    def written_dictionary(self, env):
        """The LZMA2 dictionary of a tarball written by UnixTar with the
        default preset, as xz reports it."""
        if not shutil.which('xz'):
            self.skipTest('xz is not installed')
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        src = os.path.join(tmp, 'a.txt')
        with open(src, 'w') as f:
            f.write('OXT-Beyond\n' * 1000)
        out = os.path.join(tmp, 'p.tar.xz')
        old = os.environ.get('OXT_PYTHON_XZ')
        try:
            if env is None:
                os.environ.pop('OXT_PYTHON_XZ', None)
            else:
                os.environ['OXT_PYTHON_XZ'] = env
            t = package_dist.UnixTar(out, package_dist.XZ_PRESET)
            t.add_path(src, 'root/a.txt')
            t.close()
        finally:
            if old is None:
                os.environ.pop('OXT_PYTHON_XZ', None)
            else:
                os.environ['OXT_PYTHON_XZ'] = old
        r = subprocess.run(['xz', '--robot', '-lvv', out], stdout=subprocess.PIPE, universal_newlines=True,
                           check=True)
        dicts = set(re.findall(r'dict=(\d+\w*)', r.stdout))
        listing = subprocess.run(['tar', '-tJf', out], stdout=subprocess.PIPE, universal_newlines=True,
                                 check=True).stdout.split()
        self.assertEqual(listing, ['root/a.txt'])
        return dicts

    def test_xz_program_writes_preset_nine(self):
        # xz -9 means a 64 MiB dictionary (xz -6: 8 MiB)
        self.assertEqual(self.written_dictionary(None), {'64MiB'})

    def test_python_lzma_writes_preset_nine(self):
        self.assertEqual(self.written_dictionary('1'), {'64MiB'})


class DiskImage(unittest.TestCase):

    def app(self, minimum):
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        app = os.path.join(tmp, 'OXT-Beyond.app')
        os.makedirs(os.path.join(app, 'Contents'))
        if minimum is not None:
            info = {'CFBundleExecutable': 'OXT-Beyond'}
            if minimum is not False:
                info['LSMinimumSystemVersion'] = minimum
            with open(os.path.join(app, 'Contents', 'Info.plist'), 'wb') as f:
                plistlib.dump(info, f)
        return app

    def test_lzma_for_an_app_that_needs_10_15_or_later(self):
        for minimum in ('10.15', '11.0', '12', '15.1'):
            self.assertEqual(package_dist.dmg_format(self.app(minimum)), 'ULMO', minimum)

    def test_zlib_as_before_for_anything_else(self):
        for minimum in ('10.9', '10.14.6', '', 'eleven', False, None):
            self.assertEqual(package_dist.dmg_format(self.app(minimum)), 'UDZO', repr(minimum))

    def test_commands(self):
        cmd = package_dist.dmg_create_command('OXT-Beyond 1.0', '/src', '/out.dmg', 'ULMO')
        self.assertEqual(cmd, ['hdiutil', 'create', '-volname', 'OXT-Beyond 1.0', '-srcfolder', '/src',
                               '-fs', 'HFS+', '-format', 'ULMO', '-ov', '/out.dmg'])
        # the zlib image is made exactly as releases up to 0.2.8-dp.2.1 made it
        cmd = package_dist.dmg_create_command('OXT-Beyond 1.0', '/src', '/out.dmg', 'UDZO')
        self.assertEqual(cmd, ['hdiutil', 'create', '-volname', 'OXT-Beyond 1.0', '-srcfolder', '/src',
                               '-fs', 'HFS+', '-format', 'UDZO', '-imagekey', 'zlib-level=9', '-ov', '/out.dmg'])

    def test_write_dmg_chooses_the_format_from_the_app(self):
        src = read(package_dist.__file__)
        body = src[src.index('def write_dmg('):src.index('def licence_entries(')]
        self.assertIn('dmg_format(app)', body)
        self.assertIn('dmg_create_command(volume, src, tmp, fmt)', body)
        self.assertNotIn("'UDZO'", body)

    def test_released_app_gets_lzma(self):
        # The macOS build checks the app's LSMinimumSystemVersion before the
        # disk image is written; that version must take the LZMA image.
        m = re.search(r'check LSMinimumSystemVersion (\S+)', read(BUILD_MACOS))
        self.assertIsNotNone(m)
        self.assertEqual(package_dist.dmg_format(self.app(m.group(1))), 'ULMO')


def iss_files_entries(defines):
    """The [Files] entries of the installer script after the preprocessor's
    #ifdef/#else/#endif and {#Name} with the given defines, as dicts."""
    lines = read(ISS).splitlines()
    start = lines.index('[Files]')
    end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith('['))
    local = dict(defines)
    keep = []
    out = []
    for line in lines[start + 1:end]:
        s = line.strip()
        if s.startswith('#ifdef '):
            keep.append(s.split()[1] in local)
            continue
        if s.startswith('#ifndef '):
            keep.append(s.split()[1] not in local)
            continue
        if s == '#else':
            keep[-1] = not keep[-1]
            continue
        if s == '#endif':
            keep.pop()
            continue
        if not all(keep):
            continue
        m = re.match(r'#define (\w+) "(.*)"$', s)
        if m:
            local[m.group(1)] = m.group(2)
            continue
        if not s or s.startswith(';'):
            continue
        s = re.sub(r'\{#(\w+)\}', lambda m: local[m.group(1)], s)
        entry = {}
        for part in re.findall(r'(\w+): ("[^"]*"|[^;]*)', s):
            entry[part[0]] = part[1].strip().strip('"')
        out.append(entry)
    return out


def inno_install(stage, entries):
    """{installed relative path: source path} for the [Files] entries, as
    Inno Setup evaluates Source wildcards with recursesubdirs and Excludes
    (a pattern starting with a backslash matches from the entry's folder;
    a matching folder is skipped with everything in it)."""
    installed = {}
    for e in entries:
        source = e['Source']
        base, wildcard = source.rsplit('\\', 1)
        flags = [f.strip() for f in e.get('Flags', '').split()]
        excludes = [x for x in e.get('Excludes', '').split(',') if x]
        dest = e['DestDir']
        base_os = os.path.join(stage, *[p for p in base.replace('STAGE', '').split('\\') if p])
        if 'skipifsourcedoesntexist' in flags and not os.path.exists(base_os):
            continue

        def excluded(rel):
            for x in excludes:
                if x.startswith('\\'):
                    if fnmatch.fnmatch(rel.lower(), x[1:].lower()):
                        return True
                elif fnmatch.fnmatch(rel.split('\\')[-1].lower(), x.lower()):
                    return True
            return False

        def walk(sub):
            folder = os.path.join(base_os, *[p for p in sub.split('\\') if p])
            for name in sorted(os.listdir(folder)):
                rel = (sub + '\\' + name) if sub else name
                full = os.path.join(folder, name)
                if os.path.isdir(full):
                    if 'recursesubdirs' in flags and not excluded(rel):
                        walk(rel)
                elif fnmatch.fnmatch(name, wildcard) and not excluded(rel):
                    target = (dest.replace('{app}', '').strip('\\') + '\\' + rel).strip('\\')
                    installed[target.lower()] = base + '\\' + rel
        walk('')
    return installed


class WindowsInstaller(unittest.TestCase):

    def stage(self, same=True):
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        files = {
            'OXT-Beyond.exe': 'exe',
            'Externals/revxml.dll': 'xml',
            'Toolset/palettes/updates/whatsnew.txt': 'w',
            'Toolset/palettes/updates/updatehistory/1.txt': 'h',
            'Runtime/Windows/x86-32/Externals/CEF/libcef.dll': 'cef32',
            'Runtime/Linux/x86-64/Externals/CEF/libcef.so': 'cefso',
        }
        for cef in ('Externals/CEF', 'Runtime/Windows/x86-64/Externals/CEF'):
            files[cef + '/libcef.dll'] = 'cef64'
            files[cef + '/locales/en-US.pak'] = 'en'
        if not same:
            files['Externals/CEF/libcef.dll'] = 'other'
        for rel, text in files.items():
            path = os.path.join(tmp, *rel.split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write(text)
        return tmp, {rel.replace('/', '\\').lower() for rel in files}

    def test_both_forms_install_every_staged_file(self):
        stage, staged = self.stage()
        before = inno_install(stage, iss_files_entries({'StageDir': 'STAGE'}))
        after = inno_install(stage, iss_files_entries({'StageDir': 'STAGE', 'SharedCefSource': RUNTIME_CEF}))
        self.assertEqual(set(before), staged)
        self.assertEqual(set(after), staged)

    def test_shared_form_stores_the_cef_once(self):
        stage, _ = self.stage()
        before = inno_install(stage, iss_files_entries({'StageDir': 'STAGE'}))
        after = inno_install(stage, iss_files_entries({'StageDir': 'STAGE', 'SharedCefSource': RUNTIME_CEF}))
        # Inno Setup compresses each distinct source path once
        # (MergeDuplicateFiles, on by default)
        self.assertEqual(len(set(after.values())), len(set(before.values())) - 2)
        self.assertEqual(after['externals\\cef\\libcef.dll'],
                         'STAGE\\Runtime\\Windows\\x86-64\\Externals\\CEF\\libcef.dll')
        self.assertEqual(after['externals\\cef\\locales\\en-us.pak'],
                         'STAGE\\Runtime\\Windows\\x86-64\\Externals\\CEF\\locales\\en-US.pak')
        self.assertEqual(before['externals\\cef\\libcef.dll'], 'STAGE\\Externals\\CEF\\libcef.dll')

    def test_the_writable_files_keep_their_own_entries(self):
        for defines in ({'StageDir': 'S'}, {'StageDir': 'S', 'SharedCefSource': RUNTIME_CEF}):
            entries = iss_files_entries(defines)
            perms = [e for e in entries if e.get('Permissions') == 'users-modify']
            self.assertEqual(len(perms), 2, defines)
            self.assertIn(r'\Toolset\palettes\updates\whatsnew.txt', entries[0]['Excludes'])

    def test_duplicates_are_merged(self):
        self.assertNotRegex(read(ISS), r'(?im)^\s*MergeDuplicateFiles\s*=\s*(no|false|0)')

    def test_build_installer_defines_it_only_for_identical_folders(self):
        text = read(BUILD_INSTALLER)
        self.assertIn("$runtimeCef = 'Runtime\\Windows\\x86-64\\Externals\\CEF'", text)
        self.assertIn("Test-SameFolder (Join-Path $StageDir 'Externals\\CEF') (Join-Path $StageDir $runtimeCef)",
                      text)
        # sizes, names and SHA-256 hashes all compared
        body = text[text.index('function Test-SameFolder'):text.index('function Get-SharedCefSource')]
        for needed in ('.Length -ne', 'ToLowerInvariant() -ne', "Get-FileHash", "-Algorithm SHA256",
                       '$la.Count -ne $lb.Count'):
            self.assertIn(needed, body)
        self.assertEqual(text.count("$defines['SharedCefSource']"), 1)
        self.assertRegex(text, r"if \(\$sharedCef\) \{\s*\$defines\['SharedCefSource'\] = \$sharedCef")

    def test_installer_test_compares_cef_bytes(self):
        text = read(TEST_INSTALLER)
        self.assertIn("CEF files installed byte for byte", text)
        self.assertIn("@('Externals\\CEF', 'Runtime\\Windows\\x86-64\\Externals\\CEF')", text)


if __name__ == '__main__':
    unittest.main()
