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

"""tools/ci/android_check.py's readers of a package, of the device's screen
and of the IDE's lines, and the comparison of two builders' packages, on
made-up inputs; and that the check, its IDE script and android.yml name the
same builds, colours and files. No Android SDK or engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import io
import os
import re
import struct
import sys
import tempfile
import unittest
import zipfile
import zlib

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_check as ac  # noqa: E402


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def zip_bytes(entries, stored=()):
    """A zip file's bytes: entries is a list of (name, data)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        for name, data in entries:
            z.writestr(name, data, zipfile.ZIP_STORED if name in stored else zipfile.ZIP_DEFLATED)
    return buf.getvalue()


def with_signing_block(data):
    """data with a (made-up) APK Signing Block before its central
    directory, and the end record's offset moved past it"""
    end = data.rfind(b'PK\x05\x06')
    cd = struct.unpack('<I', data[end + 16:end + 20])[0]
    body = struct.pack('<Q', 8) + struct.pack('<I', 0x7109871a) + b'\0' * 4
    block = struct.pack('<Q', len(body) + 24) + body + struct.pack('<Q', len(body) + 24) + ac.SIG_BLOCK_MAGIC
    out = data[:cd] + block + data[cd:end + 16] + struct.pack('<I', cd + len(block)) + data[end + 20:]
    return out


def elf64(aligns):
    """A little-endian 64-bit ELF header with PT_LOAD segments of these
    alignments (and one PT_DYNAMIC, which does not count)"""
    phnum = len(aligns) + 1
    header = b'\x7fELF' + bytes([2, 1, 1]) + b'\0' * 9
    header += struct.pack('<HHIQQQIHHHHHH', 3, 0xb7, 1, 0, 64, 0, 0, 64, 56, phnum, 0, 0, 0)
    phs = b''
    for a in aligns:
        phs += struct.pack('<IIQQQQQQ', 1, 5, 0, 0, 0, 0x1000, 0x1000, a)
    phs += struct.pack('<IIQQQQQQ', 2, 6, 0, 0, 0, 0x100, 0x100, 8)
    return header + phs


def elf32(aligns):
    header = b'\x7fELF' + bytes([1, 1, 1]) + b'\0' * 9
    header += struct.pack('<HHIIIIIHHHHHH', 3, 40, 1, 0, 52, 0, 0, 52, 32, len(aligns), 0, 0, 0)
    phs = b''.join(struct.pack('<IIIIIIII', 1, 0, 0, 0, 0x1000, 0x1000, 5, a) for a in aligns)
    return header + phs


# aapt's (build-tools' aapt) form of a manifest, cut down
AAPT1_TREE = '''N: android=http://schemas.android.com/apk/res/android
  E: manifest (line=2)
    A: package="org.openxtalk.check.androidprobe" (Raw: "org.openxtalk.check.androidprobe")
    E: application (line=9)
      E: activity (line=9)
        A: android:name(0x01010003)=".mblandroid" (Raw: ".mblandroid")
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        E: intent-filter (line=9)
          E: action (line=9)
            A: android:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
      E: provider (line=9)
        A: android:name(0x01010003)="x.AppProvider" (Raw: "x.AppProvider")
        A: android:exported(0x01010010)=(type 0x12)0x0
      E: receiver (line=9)
        A: android:name(0x01010003)="AppReceiver" (Raw: "AppReceiver")
        A: android:exported(0x01010010)=(type 0x12)0x0
      E: receiver (line=9)
        A: android:name(0x01010003)="PushReceiver" (Raw: "PushReceiver")
        A: android:permission(0x01010006)="com.google.android.c2dm.permission.SEND" (Raw: "x")
        E: intent-filter (line=9)
          E: action (line=9)
            A: android:name(0x01010003)="com.google.android.c2dm.intent.RECEIVE" (Raw: "x")
      E: service (line=9)
        A: android:name(0x01010003)=".mblandroidservice" (Raw: ".mblandroidservice")
'''

# aapt2's form of the same kind of manifest
AAPT2_TREE = '''N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    E: application (line=9)
      E: activity (line=10)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)=".mblandroid" (Raw: ".mblandroid")
        A: http://schemas.android.com/apk/res/android:exported(0x01010010)=true
        E: intent-filter (line=11)
      E: service (line=20)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="S" (Raw: "S")
        E: intent-filter (line=21)
      E: activity-alias (line=30)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="AA" (Raw: "AA")
        A: http://schemas.android.com/apk/res/android:exported(0x01010010)=false
        E: intent-filter (line=31)
'''


class PackageReaders(unittest.TestCase):
    def test_signing_block(self):
        data = zip_bytes([('AndroidManifest.xml', b'x'), ('classes.dex', b'dex')])
        self.assertFalse(ac.has_signing_block(data))
        signed = with_signing_block(data)
        self.assertTrue(ac.has_signing_block(signed))
        # still a zip file whose entries read back
        self.assertEqual(zipfile.ZipFile(io.BytesIO(signed)).read('classes.dex'), b'dex')
        with self.assertRaises(ac.CheckError):
            ac.has_signing_block(b'not a zip')

    def test_data_offset(self):
        data = zip_bytes([('a.txt', b'hello'), ('resources.arsc', b'ARSC' * 10)], stored=('resources.arsc',))
        z = zipfile.ZipFile(io.BytesIO(data))
        info = z.getinfo('resources.arsc')
        off = ac.data_offset(data, info)
        self.assertEqual(data[off:off + 8], b'ARSCARSC')

    def test_elf_alignments(self):
        self.assertEqual(ac.elf_load_alignments(elf64([0x10000, 0x10000])), [0x10000, 0x10000])
        self.assertEqual(ac.elf_load_alignments(elf64([0x1000])), [0x1000])
        self.assertEqual(ac.elf_load_alignments(elf32([0x1000, 0x1000])), [0x1000, 0x1000])
        with self.assertRaises(ac.CheckError):
            ac.elf_load_alignments(b'MZ not an elf')

    def test_manifest_aapt1(self):
        comps = {(c['kind'], c['name']): c for c in ac.manifest_components(AAPT1_TREE)}
        self.assertEqual(set(comps), {('activity', '.mblandroid'), ('provider', 'x.AppProvider'),
                                      ('receiver', 'AppReceiver'), ('receiver', 'PushReceiver'),
                                      ('service', '.mblandroidservice')})
        self.assertIs(comps[('activity', '.mblandroid')]['exported'], True)
        self.assertTrue(comps[('activity', '.mblandroid')]['filter'])
        self.assertIs(comps[('provider', 'x.AppProvider')]['exported'], False)
        self.assertIs(comps[('receiver', 'PushReceiver')]['exported'], None)
        self.assertTrue(comps[('receiver', 'PushReceiver')]['filter'])
        self.assertFalse(comps[('receiver', 'AppReceiver')]['filter'])
        self.assertFalse(comps[('service', '.mblandroidservice')]['filter'])
        self.assertIn('receiver PushReceiver: android:exported=(not set)', ac.manifest_summary(AAPT1_TREE))

    def test_manifest_aapt2(self):
        comps = {(c['kind'], c['name']): c for c in ac.manifest_components(AAPT2_TREE)}
        self.assertIs(comps[('activity', '.mblandroid')]['exported'], True)
        self.assertIs(comps[('service', 'S')]['exported'], None)
        self.assertTrue(comps[('service', 'S')]['filter'])
        self.assertIs(comps[('activity-alias', 'AA')]['exported'], False)

    def test_manifest_lines_drop_line_numbers(self):
        self.assertEqual(ac.manifest_lines('  E: activity (line=9)\n\n    A: x="y"\n'),
                         ['  E: activity', '    A: x="y"'])


class Screen(unittest.TestCase):
    def raw(self, w, h, colour, header=16):
        head = struct.pack('<III', w, h, 1) + (struct.pack('<I', 0) if header == 16 else b'')
        return head + bytes(list(colour) + [255]) * (w * h)

    def test_raw_screencap(self):
        for header in (12, 16):
            w, h, rgba = ac.screen_from_raw(self.raw(4, 3, ac.RUN_COLOR, header))
            self.assertEqual((w, h, len(rgba)), (4, 3, 48))
            self.assertEqual(ac.colour_share(rgba, ac.RUN_COLOR, step=1), 1.0)
            self.assertEqual(ac.colour_share(rgba, ac.SAVED_COLOR, step=1), 0.0)
        with self.assertRaises(ac.CheckError):
            ac.screen_from_raw(b'\x01\x00')
        with self.assertRaises(ac.CheckError):
            ac.screen_from_raw(self.raw(4, 3, ac.RUN_COLOR)[:-5])

    def test_share_of_a_half_green_screen(self):
        rgba = bytes(list(ac.RUN_COLOR) + [255]) * 50 + bytes([0, 0, 0, 255]) * 50
        self.assertAlmostEqual(ac.colour_share(rgba, ac.RUN_COLOR, step=1), 0.5)

    def test_png(self):
        png = ac.png_from_rgba(2, 2, bytes([1, 2, 3, 255]) * 4)
        self.assertTrue(png.startswith(b'\x89PNG\r\n\x1a\n'))
        w, h = struct.unpack('>II', png[16:24])
        self.assertEqual((w, h), (2, 2))
        idat = png.index(b'IDAT')
        length = struct.unpack('>I', png[idat - 4:idat])[0]
        self.assertEqual(zlib.decompress(png[idat + 4:idat + 4 + length]), (b'\0' + bytes([1, 2, 3, 255]) * 2) * 2)


class IdeLines(unittest.TestCase):
    def test_results(self):
        r = ac.ide_results([
            'INFO version 9.7.1-BeyondEngine 25923',
            'UNIT OK sdk-complete',
            'UNIT FAILED sdk-valid: false',
            'INFO debug warnings ',
            'INFO debug asked ',
            'BUILT debug /w/out/debug.apk',
            'INFO legacy warnings Android: the app is built for armv7 and not arm64, and ... | ',
            'BUILD FAILED legacy could not compile service support class',
            'INFO release asked Please provide the keystore alias to use;',
            'TEST FAILED Installation of app failed: x',
            'ERROR 219,1,1',
            'DONE'])
        self.assertEqual(r['units'], {'sdk-complete': None, 'sdk-valid': 'false'})
        self.assertEqual(r['builds'], {'debug': ('ok', '/w/out/debug.apk'),
                                       'legacy': ('failed', 'could not compile service support class')})
        self.assertIn('built for armv7 and not arm64', r['warnings']['legacy'])
        self.assertEqual(r['warnings']['debug'], '')
        self.assertIn('alias', r['asked']['release'])
        self.assertEqual(r['test'], 'Installation of app failed: x')
        self.assertEqual(r['errors'], ['ERROR 219,1,1'])
        self.assertTrue(r['done'])


class Compare(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.dir, ignore_errors=True)

    def apk(self, name, entries, signed=False):
        path = os.path.join(self.dir, name)
        data = zip_bytes(entries, stored=('resources.arsc',))
        if signed:
            data = with_signing_block(data)
        with open(path, 'wb') as f:
            f.write(data)
        return path

    BASE = [('AndroidManifest.xml', b'manifest'), ('resources.arsc', b'arsc'), ('classes.dex', b'dex'),
            ('lib/arm64-v8a/librevandroid.so', b'engine')]

    def test_same(self):
        old = self.apk('old.apk', self.BASE + [('lib/', b'')])
        new = self.apk('new.apk', self.BASE)
        problems, notes = ac.compare_apks('unsigned', old, new)
        self.assertEqual(problems, [])
        self.assertIn('4 of 4 files the same', notes)

    def test_a_different_library_is_a_problem(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', self.BASE[:3] + [('lib/arm64-v8a/librevandroid.so', b'engine2')])
        problems, _ = ac.compare_apks('unsigned', old, new)
        self.assertEqual(problems, ['unsigned: lib/arm64-v8a/librevandroid.so differs'])

    def test_a_new_file_is_a_problem(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', self.BASE + [('assets/extra', b'x')])
        problems, _ = ac.compare_apks('legacy', old, new)
        self.assertEqual(problems, ['legacy: only the new package has assets/extra'])

    def test_signature_expected_only_where_meant(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', self.BASE + [('META-INF/KEY.SF', b'sf')], signed=True)
        problems, notes = ac.compare_apks('release', old, new)
        self.assertEqual(problems, [])
        self.assertTrue(any(ac.EXPECTED_SIGNING['release'] in x for x in notes))
        problems, _ = ac.compare_apks('unsigned', old, new)
        self.assertTrue(problems and 'the signature changed' in problems[0])
        # the debug build must also have its manifest changed (the push
        # receiver's android:exported)
        problems, _ = ac.compare_apks('debug', old, new)
        self.assertEqual(problems, ["debug: the manifest is the same, and should have "
                                    "['receiver PushReceiver: android:exported=true']"])

    def test_manifest_change_needs_aapt(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'other')] + self.BASE[1:])
        problems, _ = ac.compare_apks('unsigned', old, new)
        self.assertEqual(problems, ['unsigned: the manifest differs (no aapt to say how)'])


class VerifyWithoutTools(unittest.TestCase):
    """verify_apk's own checks (no apksigner, aapt or zipalign given)"""

    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.dir, ignore_errors=True)

    def check(self, entries, spec, stored=('resources.arsc',), warnings=None):
        path = os.path.join(self.dir, 'p.apk')
        with open(path, 'wb') as f:
            f.write(zip_bytes(entries, stored=stored))
        return ac.verify_apk('unsigned', path, spec, {}, warnings or {})

    SPEC = {'abis': {'arm64-v8a'}, 'signer': None, 'push': False, 'warnings': []}

    def test_good(self):
        problems, notes = self.check([('AndroidManifest.xml', b'm'), ('classes.dex', b'd'),
                                      ('resources.arsc', b'r'),
                                      ('lib/arm64-v8a/librevandroid.so', elf64([0x10000]))], self.SPEC)
        self.assertEqual(problems, [])
        self.assertIn('not signed', notes)

    def test_problems(self):
        problems, _ = self.check([('AndroidManifest.xml', b'm'), ('resources.arsc', b'r'),
                                  ('lib/arm64-v8a/librevandroid.so', elf64([0x1000])),
                                  ('lib/x86/librevandroid.so', elf32([0x1000]))], self.SPEC, stored=(),
                                 warnings={'unsigned': 'Android: something | '})
        text = '\n'.join(problems)
        self.assertIn('has no classes.dex', text)
        self.assertIn('resources.arsc is compressed', text)
        self.assertIn('native code for arm64-v8a, x86, not arm64-v8a', text)
        self.assertIn('under 16 KB', text)
        self.assertIn('the builder warned: Android: something', text)

    def test_missing_warning(self):
        spec = dict(self.SPEC, warnings=['built for armv7 and not arm64'], abis={'armeabi-v7a'})
        problems, _ = self.check([('AndroidManifest.xml', b'm'), ('classes.dex', b'd'), ('resources.arsc', b'r'),
                                  ('lib/armeabi-v7a/librevandroid.so', elf32([0x1000]))], spec)
        self.assertEqual(len(problems), 1)
        self.assertIn('did not warn "built for armv7 and not arm64"', problems[0])


class OneSystem(unittest.TestCase):
    """The check, its IDE script and the workflow agree"""

    def test_colours_and_identifier(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('constant kRunColor = "%d,%d,%d"' % ac.RUN_COLOR, script)
        self.assertIn('constant kSavedColor = "%d,%d,%d"' % ac.SAVED_COLOR, script)
        self.assertIn('constant kIdentifier = "%s"' % ac.IDENTIFIER, script)

    def test_builds(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('put "%s" into tBuilds' % ','.join(ac.BUILDS), script)
        for name in ac.BUILDS:
            self.assertIn('case "%s"' % name, script)

    def test_overlay_files_exist(self):
        for rel in ac.OVERLAY:
            self.assertTrue(os.path.isfile(os.path.join(REPO, *rel.split('/'))), rel)

    def test_workflow_runs_on_a_change_to_the_builder(self):
        workflow = read('.github', 'workflows', 'android.yml')
        paths = re.search(r'(?s)paths: &android-paths\n(.*?)\n  push:', workflow).group(1)
        for rel in ac.OVERLAY + ('tools/ci/android_check.py', 'tools/ci/android-check.livecodescript',
                                 '.github/workflows/android.yml'):
            self.assertIn(rel, paths)

    def test_target_api(self):
        lib = read('ide-support', 'revdeploylibraryandroid.livecodescript')
        self.assertIn('constant kDeployAndroidTargetSDK = "%s"' % ac.TARGET_SDK, lib)


if __name__ == '__main__':
    unittest.main()
