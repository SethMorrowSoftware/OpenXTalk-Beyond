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

import argparse
import base64
import contextlib
import io
import os
import re
import shutil
import struct
import sys
import tempfile
import time
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

    def test_manifest_properties(self):
        # aapt's form (a boolean's true is 0xffffffff), as a build at
        # target 36 has it, and aapt2's; another element's name and value
        # are not a property's
        prop = ('      E: property (line=11)\n'
                '        A: android:name(0x01010003)="%s" (Raw: "%s")\n'
                '        A: android:value(0x01010024)=(type 0x12)0xffffffff\n' % ((ac.LARGE_SCREEN_PROPERTY,) * 2))
        tree = AAPT1_TREE.replace('      E: service (line=9)\n', prop + '      E: service (line=9)\n')
        self.assertEqual(ac.manifest_properties(tree), {ac.LARGE_SCREEN_PROPERTY: '0xffffffff'})
        self.assertEqual(ac.manifest_properties(AAPT1_TREE), {})
        tree2 = AAPT2_TREE + ('      E: property (line=40)\n'
                              '        A: http://schemas.android.com/apk/res/android:name(0x01010003)="p.q" (Raw: "p.q")\n'
                              '        A: http://schemas.android.com/apk/res/android:value(0x01010024)=true\n'
                              '      E: property (line=41)\n'
                              '        A: http://schemas.android.com/apk/res/android:name(0x01010003)="p.s" (Raw: "p.s")\n'
                              '        A: http://schemas.android.com/apk/res/android:value(0x01010024)="text" (Raw: "text")\n'
                              '      E: meta-data (line=42)\n'
                              '        A: http://schemas.android.com/apk/res/android:name(0x01010003)="m" (Raw: "m")\n'
                              '        A: http://schemas.android.com/apk/res/android:value(0x01010024)="v" (Raw: "v")\n')
        self.assertEqual(ac.manifest_properties(tree2), {'p.q': 'true', 'p.s': 'text'})
        # the attributes of an element inside a property are not its own
        nested = ('      E: property (line=1)\n'
                  '        E: other (line=2)\n'
                  '          A: android:name(0x01010003)="x" (Raw: "x")\n'
                  '          A: android:value(0x01010024)="y" (Raw: "y")\n')
        self.assertEqual(ac.manifest_properties(nested), {})

    def test_manifest_lines_drop_line_numbers(self):
        self.assertEqual(ac.manifest_lines('  E: activity (line=9)\n\n    A: x="y"\n'),
                         ['  E: activity', '    A: x="y"'])


class SignerDN(unittest.TestCase):
    """apksigner verify --print-certs, as two apksigner versions print it"""
    VERIFIED = ('Verifies\nVerified using v1 scheme (JAR signing): true\n'
                'Verified using v2 scheme (APK Signature Scheme v2): true\n'
                'Verified using v3 scheme (APK Signature Scheme v3): true\nNumber of signers: 1\n')

    def test_numbered_signer(self):
        # Ubuntu's apksigner, and the SDK's for a v1 and v2 signature
        out = self.VERIFIED + ('Signer #1 certificate DN: CN=Android Debug, O=Android, C=US\n'
                               'Signer #1 certificate SHA-256 digest: 00ff\n')
        self.assertEqual(ac.signer_dn(out), 'CN=Android Debug, O=Android, C=US')

    def test_signer_with_sdk_range(self):
        # the SDK's newer build-tools, for the signers of a v3 block
        out = self.VERIFIED + (
            'Signer (minSdkVersion=24, maxSdkVersion=2147483647) certificate DN: CN=OXT Android Check, '
            'O=OXT-Beyond, C=US\r\n'
            'Signer (minSdkVersion=24, maxSdkVersion=2147483647) certificate SHA-256 digest: 00ff\r\n')
        self.assertEqual(ac.signer_dn(out), 'CN=OXT Android Check, O=OXT-Beyond, C=US')
        # a v3.1 signer for a development release of Android
        out = 'Signer (minSdkVersion=34 (dev release=true), maxSdkVersion=2147483647) certificate DN: CN=A\n'
        self.assertEqual(ac.signer_dn(out), 'CN=A')

    def test_v3_signer_label(self):
        # the SDK's build-tools on GitHub's Windows runner print only this
        out = self.VERIFIED + ('V3.0 Signer: certificate DN: CN=Android Debug, O=Android, C=US\r\n'
                               'V3.0 Signer: certificate SHA-256 digest: 00ff\r\n')
        self.assertEqual(ac.signer_dn(out), 'CN=Android Debug, O=Android, C=US')

    def test_stamp_and_lineage_are_other_keys(self):
        out = ('Signer #1 certificate DN: CN=A, C=US\n'
               'Source Stamp Signer certificate DN: CN=Stamp\n'
               'Signer #1 in lineage certificate DN: CN=Old\n')
        self.assertEqual(ac.signer_dn(out), 'CN=A, C=US')

    def test_one_key_named_twice(self):
        out = ('Signer #1 certificate DN: CN=A, C=US\n'
               'Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate DN: CN=A, C=US\n')
        self.assertEqual(ac.signer_dn(out), 'CN=A, C=US')

    def test_two_keys(self):
        out = ('Signer (minSdkVersion=24, maxSdkVersion=32) certificate DN: CN=A, C=US\n'
               'Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate DN: CN=B, C=US\n')
        self.assertEqual(ac.signer_dn(out), 'CN=A, C=US | CN=B, C=US')

    def test_none(self):
        self.assertIsNone(ac.signer_dn(self.VERIFIED))
        # a key's DN mentioned elsewhere is not the signer's
        self.assertIsNone(ac.signer_dn('WARNING: the certificate DN: CN=X is old\n'))


class CrashLines(unittest.TestCase):
    """The device's log: only the probe's processes, and the engine's
    caught attempt at SSL expected only in a package without
    librevsecurity.so"""

    NO_SSL = 'I/revandroid( 7092): java.lang.UnsatisfiedLinkError: dlopen failed: library "librevsecurity.so" not found'
    NO_SSL_OLD = ('I/revandroid( 7092): java.lang.UnsatisfiedLinkError: dalvik.system.PathClassLoader'
                  '[DexPathList[[zip file "/data/app/x.apk"]]] couldn\'t find "librevsecurity.so"')
    # API 35, the same miss as the system's class loader sees it
    NO_SSL_35 = ('D/nativeloader( 7092): Load librevsecurity.so using ns clns-7 from class loader (caller=/data/app/'
                 '~~agU2hcVAStTVQscibh91ig==/org.openxtalk.check.androidprobe-tIAu8CJc7PpLUa6OtXSyAw==/base.apk): '
                 'dlopen failed: library "librevsecurity.so" not found')
    PLAIN = ['AndroidManifest.xml', 'classes.dex', 'lib/arm64-v8a/librevandroid.so', 'lib/x86_64/librevandroid.so']
    WITH_SSL = PLAIN + ['lib/arm64-v8a/librevsecurity.so', 'lib/x86_64/librevsecurity.so']
    # other processes, as the API 35 image logs them while the probe starts
    SYSTEM = ('D/nativeloader( 3398): Load libtextclassifier3_jni_agsa.so using ns product-clns-7 from class loader '
              '(caller=/product/priv-app/DevicePersonalizationPrebuiltPixel2021-aiai_20240329.00_RC16/'
              'DevicePersonalizationPrebuiltPixel2021-aiai_20240329.00_RC16.apk!classes2.dex): dlopen failed: library '
              '"libtextclassifier3_jni_agsa.so" not found',
              'I/NearbySharing( 2676): Fast Initiation Scanning has stopped [CONTEXT service_id=194 ]')

    def log(self, *lines):
        return '\n'.join(('I/ActivityManager(  500): Start proc 7092:org.openxtalk.check.androidprobe/u0a190 for '
                          'next-top-activity {org.openxtalk.check.androidprobe/org.openxtalk.check.androidprobe.mblandroid}',)
                         + lines + ('D/revandroid( 7092): done',))

    def lines(self, log, names=None, pidof='7092'):
        return ac.crash_lines(log, self.PLAIN if names is None else names, ac.probe_pids(log, pidof))

    def test_expected_without_ssl(self):
        for line in (self.NO_SSL, self.NO_SSL_OLD, self.NO_SSL_35):
            self.assertEqual(self.lines(self.log(line)), ([], [line], 0))
        self.assertEqual(self.lines(self.log(self.NO_SSL_35, self.NO_SSL)), ([], [self.NO_SSL_35, self.NO_SSL], 0))

    def test_a_problem_with_ssl(self):
        # the package holds it and the engine could not load it
        for line in (self.NO_SSL, self.NO_SSL_35):
            self.assertEqual(self.lines(self.log(line), self.WITH_SSL), ([line], [], 0))
        bad = ('I/revandroid( 7092): java.lang.UnsatisfiedLinkError: dlopen failed: "/data/app/lib/x86_64/'
               'librevsecurity.so" program alignment (4096) cannot be smaller than system page size (16384)')
        self.assertEqual(self.lines(self.log(bad), self.WITH_SSL), ([bad], [], 0))
        self.assertEqual(self.lines(self.log(bad)), ([bad], [], 0))

    def test_other_libraries_and_levels_still_count(self):
        for line in ('I/revandroid( 7092): java.lang.UnsatisfiedLinkError: dlopen failed: library "librevdb.so" not found',
                     'D/nativeloader( 7092): Load librevdb.so using ns clns-7 from class loader (caller=/data/app/'
                     'x/base.apk): dlopen failed: library "librevdb.so" not found',
                     'E/revandroid( 7092): java.lang.UnsatisfiedLinkError: dlopen failed: library "librevsecurity.so" not found',
                     'E/AndroidRuntime( 7092): java.lang.UnsatisfiedLinkError: dlopen failed: library '
                     '"librevsecurity.so" not found',
                     'E/AndroidRuntime( 7092): FATAL EXCEPTION: main',
                     'F/libc    ( 7092): Fatal signal 11 (SIGSEGV), code 1'):
            self.assertEqual(self.lines(self.log(line)), ([line], [], 0), line)

    def test_other_processes_left_out(self):
        self.assertEqual(self.lines(self.log(self.NO_SSL_35, *self.SYSTEM)), ([], [self.NO_SSL_35], 2))
        # even a librevsecurity miss of another app's
        other = self.NO_SSL.replace('7092', '3398')
        self.assertEqual(self.lines(self.log(other)), ([], [], 1))

    def test_the_system_naming_the_probe_counts(self):
        anr = 'E/ActivityManager(  500): ANR in org.openxtalk.check.androidprobe (org.openxtalk.check.androidprobe/.mblandroid)'
        self.assertEqual(self.lines(self.log(anr, *self.SYSTEM)), ([anr], [], 2))

    def test_a_probe_started_again(self):
        # crashed in 7092, started again as 7311: both are the probe's
        log = self.log('E/AndroidRuntime( 7092): FATAL EXCEPTION: main',
                       'I/ActivityManager(  500): Start proc 7311:org.openxtalk.check.androidprobe/u0a190 for activity',
                       'F/libc    ( 7311): Fatal signal 6 (SIGABRT), code -1')
        self.assertEqual(ac.probe_pids(log, '7311\n'), {'7092', '7311'})
        crash, _, others = self.lines(log, pidof='7311')
        self.assertEqual(len(crash), 2)
        self.assertEqual(others, 0)

    def test_no_pid_known_reads_every_line(self):
        log = '\n'.join(self.SYSTEM + (self.NO_SSL,))
        self.assertEqual(ac.probe_pids(log, ''), set())
        crash, expected, others = ac.crash_lines(log, self.PLAIN, set())
        self.assertEqual((crash, expected, others), (list(self.SYSTEM), [self.NO_SSL], 0))

    def test_pids(self):
        self.assertEqual(ac.log_pid('F/libc    ( 7092): Fatal signal 11'), '7092')
        self.assertEqual(ac.log_pid('I/ActivityManager(  500): Start proc'), '500')
        self.assertIsNone(ac.log_pid('--------- beginning of main'))
        # a process of another app whose name begins with the probe's is not the probe
        log = 'I/ActivityManager(  500): Start proc 4000:org.openxtalk.check.androidprobe2/u0a191 for activity'
        self.assertEqual(ac.probe_pids(log), set())
        log = 'I/ActivityManager(  500): Start proc 4001:org.openxtalk.check.androidprobe:remote/u0a190 for service'
        self.assertEqual(ac.probe_pids(log), {'4001'})

    def test_a_quiet_log(self):
        self.assertEqual(self.lines(self.log()), ([], [], 0))


class ProbeStory(unittest.TestCase):
    """What is printed when the probe is not running, crashed or was
    started again: its own lines, the system's about it, the events
    buffer's and any line about page sizes"""

    LOG = '\n'.join((
        'I/ActivityManager(  590): Start proc 3475:org.openxtalk.check.androidprobe/u0a190 for next-top-activity',
        'D/revandroid( 3475): engine started',
        'I/NearbySharing( 2676): Fast Initiation Scanning has stopped',
        'I/lowmemorykiller(  301): Kill \'org.openxtalk.check.androidprobe\' (3475), uid 10190, oom_score_adj 0',
        'I/libprocessgroup(  590): Successfully killed process cgroup uid 10190 pid 3475 in 5ms',
        'I/libprocessgroup(  590): Successfully killed process cgroup uid 10111 pid 2676 in 3ms',
        'W/PackageManager(  590): org.openxtalk.check.androidprobe: 16 KB page size compat mode',
        'I/ActivityManager(  590): Start proc 3612:org.openxtalk.check.androidprobe/u0a190 for activity',
        'V/revandroid( 3612): surface created',
        '',
    ))
    EVENTS = '\n'.join((
        'I/am_proc_start(  590): [0,3475,10190,org.openxtalk.check.androidprobe,next-top-activity,{x}]',
        'I/am_kill (  590): [0,3475,org.openxtalk.check.androidprobe,0,lmk]',
        'I/am_proc_died(  590): [0,3612,10190,0,0]',
        'I/am_proc_died(  590): [0,2676,10111,0,0]',
        'I/am_pss  (  590): [3612,10190,org.openxtalk.check.androidprobe,1,2,3]',
        'I/sysui_multi_action(  800): [757,804,799,3612]',
    ))

    def story(self, pids=('3475', '3612')):
        return dict(ac.probe_story(self.LOG, self.EVENTS, set(pids)))

    def test_sections(self):
        story = self.story()
        self.assertEqual(story["the probe's own lines (every level)"],
                         ['D/revandroid( 3475): engine started', 'V/revandroid( 3612): surface created'])
        self.assertEqual(story['the system on the probe'], [
            'I/ActivityManager(  590): Start proc 3475:org.openxtalk.check.androidprobe/u0a190 for next-top-activity',
            "I/lowmemorykiller(  301): Kill 'org.openxtalk.check.androidprobe' (3475), uid 10190, oom_score_adj 0",
            'I/libprocessgroup(  590): Successfully killed process cgroup uid 10190 pid 3475 in 5ms',
            'W/PackageManager(  590): org.openxtalk.check.androidprobe: 16 KB page size compat mode',
            'I/ActivityManager(  590): Start proc 3612:org.openxtalk.check.androidprobe/u0a190 for activity'])
        # the probe named, or one of its pids in an am_ event; not another
        # process's death, nor a number that is not an am_ event's
        self.assertEqual(story['the events buffer on the probe'], [
            'I/am_proc_start(  590): [0,3475,10190,org.openxtalk.check.androidprobe,next-top-activity,{x}]',
            'I/am_kill (  590): [0,3475,org.openxtalk.check.androidprobe,0,lmk]',
            'I/am_proc_died(  590): [0,3612,10190,0,0]',
            'I/am_pss  (  590): [3612,10190,org.openxtalk.check.androidprobe,1,2,3]'])
        self.assertEqual(story['lines about page sizes'],
                         ['W/PackageManager(  590): org.openxtalk.check.androidprobe: 16 KB page size compat mode'])

    def test_no_pid_known(self):
        story = self.story(())
        self.assertEqual(story["the probe's own lines (every level)"], [])
        self.assertIn("I/lowmemorykiller(  301): Kill 'org.openxtalk.check.androidprobe' (3475), uid 10190, "
                      "oom_score_adj 0", story['the system on the probe'])

    def test_keeps_the_last(self):
        log = '\n'.join('D/revandroid( 3475): line %d' % i for i in range(100))
        own = dict(ac.probe_story(log, '', {'3475'}, keep=5))["the probe's own lines (every level)"]
        self.assertEqual(own, ['D/revandroid( 3475): line %d' % i for i in range(95, 100)])


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class Device(unittest.TestCase):
    """device with a stand-in adb: the probe drew its green, and then its
    process is gone, or was started twice: the check fails as before (or
    passes), and first prints the logs' account of the probe"""

    LOG = ('I/ActivityManager(  590): Start proc 3475:org.openxtalk.check.androidprobe/u0a190 for activity\n'
           'I/revandroid( 3475): java.lang.UnsatisfiedLinkError: dlopen failed: library "librevsecurity.so" not found\n'
           'I/lowmemorykiller(  301): Kill \'org.openxtalk.check.androidprobe\' (3475), uid 10190\n'
           'I/ActivityManager(  590): Start proc 3612:org.openxtalk.check.androidprobe/u0a190 for activity\n')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = self.tmp.name
        os.makedirs(os.path.join(d, 'platform-tools'))
        self.apk = os.path.join(d, 'debug.apk')
        with zipfile.ZipFile(self.apk, 'w') as z:
            z.writestr('lib/x86_64/librevandroid.so', b'')
        with open(os.path.join(d, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(ac.RUN_COLOR) + [255]) * 16)
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(self.LOG)

    def tearDown(self):
        self.tmp.cleanup()

    EVENTS = 'echo "I/am_kill (  590): [0,3475,org.openxtalk.check.androidprobe,0,lmk]"'

    WINDOW = ('printf "  mCurrentFocus=Window{1f u0 Application Not Responding: '
              'com.android.systemui}\\n  mFocusedApp=ActivityRecord{2e u0 '
              'org.openxtalk.check.androidprobe/.mblandroid t9}\\n"')

    def device(self, pidof, timeout='10', power='true', events=EVENTS, cases='', argv=(), screencap='',
               window=WINDOW):
        d = self.tmp.name
        adb = os.path.join(d, 'platform-tools', 'adb')
        with open(adb, 'w') as f:
            f.write('#!/bin/sh\n'
                    'shift 2\n'
                    'echo "$*" >> "$(dirname "$0")/calls"\n'
                    'case "$*" in\n'
                    '  "shell getprop ro.build.version.sdk") echo 35 ;;\n'
                    '  "shell getconf PAGE_SIZE") echo 16384 ;;\n'
                    '  "shell getprop ro.product.cpu.abi") echo x86_64 ;;\n'
                    '  install*) echo Success ;;\n'
                    '  "shell am start"*) echo "Status: ok" ;;\n'
                    '  "exec-out screencap") %scat "%s/screen.raw" ;;\n'
                    '  "shell pidof"*) %s ;;\n'
                    '  "logcat -d -v brief") cat "%s/logcat.txt" ;;\n'
                    '  "shell dumpsys power") %s ;;\n'
                    '  "logcat -d -b events -v brief") %s ;;\n'
                    '  "shell dumpsys activity exit-info"*) printf "  ApplicationExitInfo #0:\\n    pid=3612 reason=3 (LOW_MEMORY)\\n" ;;\n'
                    '  "shell cat /proc/meminfo") printf "MemTotal: 2000000 kB\\nMemFree: 1 kB\\nMemAvailable: 90000 kB\\n" ;;\n'
                    '  "shell dumpsys window") %s ;;\n'
                    '%s'
                    'esac\n' % (screencap, d, pidof, d, power, events, window, cases))
        os.chmod(adb, 0o755)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = ac.main(['device', '--apk', self.apk, '--serial', 'emulator-5554', '--sdk', d,
                              '--timeout', timeout] + list(argv))
        return status, out.getvalue()

    def calls(self):
        with open(os.path.join(self.tmp.name, 'platform-tools', 'calls')) as f:
            return f.read().splitlines()

    def test_starts_once_the_install_is_taken(self):
        # run 42324548829: lmkd killed the probe that started while the
        # system's apps were taking its install; it starts once the
        # broadcasts are delivered and the package manager is idle
        status, out = self.device('echo 3475', cases=(
            '  "shell am wait-for-broadcast-idle") echo "All broadcast queues are idle!" ;;\n'
            '  "shell pm wait-for-handler --timeout 120000") echo Success ;;\n'))
        self.assertEqual(status, 0, out)
        calls = self.calls()
        steps = [next(i for i, c in enumerate(calls) if c.startswith(x))
                 for x in ('install', 'shell am wait-for-broadcast-idle', 'shell pm wait-for-handler --timeout 120000',
                           'logcat -c', 'shell am start')]
        self.assertEqual(steps, sorted(steps), calls)
        self.assertEqual(steps[1:], list(range(steps[1], steps[1] + 4)), calls)
        self.assertIn("Before it starts: the broadcast queues are idle after 0 s (am wait-for-broadcast-idle); "
                      "the package manager's handler is idle after 0 s (pm wait-for-handler)\n", out)
        self.assertLess(out.index('Installed debug.apk'), out.index('Before it starts:'))
        self.assertLess(out.index('Before it starts:'), out.index('Started:'))

    def test_a_wait_that_cannot_say_decides_nothing(self):
        status, out = self.device('echo 3475', cases=(
            '  "shell am wait-for-broadcast-idle") echo "it ended this way"; exit 3 ;;\n'
            '  "shell pm wait-for-handler"*) echo "cmd: Can\'t find service: package" ;;\n'))
        self.assertEqual(status, 0, out)
        self.assertIn('Before it starts: the broadcast queues are idle: am wait-for-broadcast-idle cannot say '
                      '(exit status 3: it ended this way); the package manager\'s handler '
                      'is idle: pm wait-for-handler cannot say (exit status 0: cmd: Can\'t find service: package)',
                      out)

    def test_a_wait_that_does_not_end(self):
        said = []

        def a(*cmd, timeout=180):
            said.append((cmd, timeout))
            if 'wait-for-broadcast-idle' in cmd:
                raise ac.CheckError('adb: timed out')
            return 0, 'Success\n'

        def older(*cmd, timeout=180):
            return 0, 'Unknown command: %s\n' % cmd[2]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            got = ac.quiet_after_install(older)
        self.assertEqual(got, ['the broadcast queues are idle: am wait-for-broadcast-idle cannot say (exit status 0: '
                               'Unknown command: wait-for-broadcast-idle)',
                               "the package manager's handler is idle: pm wait-for-handler cannot say (exit status 0: "
                               'Unknown command: wait-for-handler)'])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            got = ac.quiet_after_install(a, seconds=7)
        self.assertEqual(got, ['the broadcast queues are idle: not in 7 s (am wait-for-broadcast-idle)',
                               "the package manager's handler is idle after 0 s (pm wait-for-handler)"])
        # each wait has its own time, a little longer than the device's
        self.assertEqual(said, [(('shell', 'am', 'wait-for-broadcast-idle'), 17),
                                (('shell', 'pm', 'wait-for-handler', '--timeout', '7000'), 17)])
        self.assertIn('Before it starts: the broadcast queues are idle: not in 7 s', out.getvalue())
        self.assertEqual(ac.QUIET_SECONDS, 120)

    def test_gone_after_drawing(self):
        status, out = self.device('true')
        self.assertEqual(status, 1, out)
        self.assertIn('the app is not running', out)
        self.assertIn('NOTE: the probe was started 2 times (processes 3475, 3612)', out)
        for part in ("the probe's own lines (every level):\n  I/revandroid( 3475)",
                     "the system on the probe:\n  I/ActivityManager(  590): Start proc 3475",
                     "  I/lowmemorykiller(  301): Kill 'org.openxtalk.check.androidprobe' (3475)",
                     'the events buffer on the probe:\n  I/am_kill (  590): [0,3475,',
                     'lines about page sizes: none',
                     'how its processes ended (dumpsys activity exit-info):\n    ApplicationExitInfo #0:',
                     '\n      pid=3612 reason=3 (LOW_MEMORY)',
                     'memory: MemTotal: 2000000 kB, MemAvailable: 90000 kB'):
            self.assertIn(part, out)

    def test_started_twice_and_running_passes_with_the_account(self):
        status, out = self.device('echo 3612')
        self.assertEqual(status, 0, out)
        self.assertIn('NOTE: the probe was started 2 times', out)
        self.assertIn('reason=3 (LOW_MEMORY)', out)

    def test_once_and_running_prints_no_account(self):
        with open(os.path.join(self.tmp.name, 'logcat.txt'), 'w') as f:
            f.write(self.LOG.split('I/lowmemorykiller')[0])
        status, out = self.device('echo 3475')
        self.assertEqual(status, 0, out)
        self.assertNotIn('exit-info', out)
        self.assertNotIn('NOTE:', out)


    def test_not_green_says_what_stood_in_front(self):
        # the probe's green dimmed under another app's dialog: the check
        # fails as before, and says what was in front and what showed
        dim = tuple(c * 2 // 5 for c in ac.RUN_COLOR)
        with open(os.path.join(self.tmp.name, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(dim) + [255]) * 12 +
                    bytes([255, 255, 255, 255]) * 4)
        with open(os.path.join(self.tmp.name, 'logcat.txt'), 'w') as f:
            f.write(self.LOG.split('I/lowmemorykiller')[0] +
                    'E/ActivityManager(  590): ANR in com.android.systemui\n'
                    'I/ActivityManager(  590): Killing 1234:com.android.chrome/u0a50 (adj 900): empty\n')
        status, out = self.device('echo 3475', timeout='1')
        self.assertEqual(status, 1, out)
        for part in ("the screen never turned the probe's green (0% green, 0% red: the stack never showed)",
                     'in front (dumpsys window): mCurrentFocus=Window{1f u0 Application Not Responding: '
                     'com.android.systemui}; mFocusedApp=ActivityRecord{2e u0 org.openxtalk.check.androidprobe/'
                     '.mblandroid t9}',
                     'dialogs in the log (any process):\n  E/ActivityManager(  590): ANR in com.android.systemui\n',
                     "the screen's commonest colours: #0c3f24 "):
            self.assertIn(part, out)
        self.assertNotIn('Killing 1234', out)

    def test_green_says_nothing_of_what_was_in_front(self):
        status, out = self.device('true')
        self.assertNotIn('in front', out)
        self.assertNotIn('commonest colours', out)

    def test_the_fail_colour_is_a_failure_and_ends_the_wait(self):
        # the Java layer's probe turns kFailColor when a call it makes into
        # the Java layer answers nothing: the wait ends there (well inside
        # its time), and the check fails saying so, even with the app running
        with open(os.path.join(self.tmp.name, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(ac.FAIL_COLOR) + [255]) * 16)
        with open(os.path.join(self.tmp.name, 'logcat.txt'), 'w') as f:
            f.write(self.LOG.split('I/lowmemorykiller')[0])
        started = time.time()
        status, out = self.device('echo 3475', timeout='60')
        self.assertLess(time.time() - started, 30)
        self.assertEqual(status, 1, out)
        self.assertIn("the probe's script ran, and a call it makes into the Java layer failed (the screen is its "
                      "fail colour, 100%)", out)
        self.assertNotIn('never turned the probe', out)

    # run 42218720113, on the 16 KB image: the Java layer's probe drew its
    # green, the screen went off, SystemUI's theme overlays changed its
    # ApplicationInfo, and its activity was relaunched and aborted
    RELAUNCH_LOG = (
        'I/ActivityThread( 3612): ApplicationInfo updating for org.openxtalk.check.androidprobe, new timestamp: 109828\n'
        'I/ActivityThread( 3612): assets removed: []\n'
        'I/ActivityThread( 3612): assets added: [/data/resource-cache/com.android.systemui-neutral-gcz6.frro, '
        '/data/resource-cache/com.android.systemui-accent-78hb.frro]\n'
        'F/libc    ( 3612): fdsan: failed to exchange ownership of file descriptor: fd 0 is owned by FILE* '
        '0x7396e1675888, was expected to be unowned\n')
    RELAUNCH_EVENTS = (
        "printf '%s\\n' "
        "'I/wm_pause_activity(  576): [0,259587643,org.openxtalk.check.androidprobe/.mblandroid,"
        "userLeaving=false,sleep]' "
        "'I/wm_relaunch_resume_activity(  576): [0,259587643,9,org.openxtalk.check.androidprobe/.mblandroid,"
        "80000000]' "
        "'I/wm_pause_activity(  576): [0,259587643,org.openxtalk.check.androidprobe/.mblandroid,"
        "userLeaving=false,finish]'")

    def test_says_what_android_did_to_the_probe(self):
        with open(os.path.join(self.tmp.name, 'logcat.txt'), 'w') as f:
            f.write(self.LOG + self.RELAUNCH_LOG)
        status, out = self.device('true', events=self.RELAUNCH_EVENTS)
        self.assertEqual(status, 1, out)
        notes = ["NOTE: Android paused the probe's activity for sleep (wm_pause_activity: the screen was off or "
                 "locked)",
                 "NOTE: the probe's ApplicationInfo changed while it ran (assets added: "
                 "[/data/resource-cache/com.android.systemui-neutral-gcz6.frro, "
                 "/data/resource-cache/com.android.systemui-accent-78hb.frro])",
                 "NOTE: Android relaunched the probe's activity (wm_relaunch_resume_activity), which the carried "
                 "runtime does not survive"]
        for note in notes:
            self.assertIn(note, out)
        # in that order, before the logs' account
        at = [out.index(x) for x in notes]
        self.assertEqual(at, sorted(at))
        self.assertLess(at[-1], out.index("the probe's own lines (every level):"))

    def test_nothing_done_to_the_probe_says_nothing(self):
        status, out = self.device('true')
        self.assertEqual(status, 1, out)
        for part in ('for sleep', 'ApplicationInfo', 'relaunched'):
            self.assertNotIn(part, out)

    def test_says_when_the_device_is_asleep(self):
        status, out = self.device('echo 3475', power='echo "  mWakefulness=Asleep"')
        self.assertIn('NOTE: the device is Asleep (dumpsys power): Android pauses an activity started now '
                      '(see boot --awake)', out)
        for power in ('echo "  mWakefulness=Awake"', 'true'):
            status, out = self.device('echo 3475', power=power)
            self.assertNotIn('the device is', out)

    def test_a_little_of_the_fail_colour_is_not_a_failure(self):
        # a green screen with a strip of the fail colour (an icon, a bar)
        # is the probe's green: 2 of the 10 pixels read are that colour
        with open(os.path.join(self.tmp.name, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 8, 8, 1, 0) + bytes(list(ac.RUN_COLOR) + [255]) * 56 +
                    bytes(list(ac.FAIL_COLOR) + [255]) * 8)
        status, out = self.device('true')
        self.assertIn("80% of the screen is the probe's green", out)
        self.assertNotIn('Java layer failed', out)
        self.assertIn('the app is not running', out)


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DevicePermission(unittest.TestCase):
    """device --allow with a stand-in adb: the Java layer's probe declares
    POST_NOTIFICATIONS, and on Android 13 and newer scheduling its
    notification makes Android ask the user to allow it. The check waits
    for that dialog, taps its Allow button and checks that the package
    holds the permission; each way that can go wrong is a failure that says
    which"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    LOG = Device.LOG
    EVENTS = Device.EVENTS
    PERMISSION = 'android.permission.POST_NOTIFICATIONS'

    # as an Android 13 Google APIs image says them
    ACTIVITIES = ('ACTIVITY MANAGER ACTIVITIES (dumpsys activity activities)\n'
                  'Display #0 (activities from top to bottom):\n'
                  '  * Task{d1 #9 type=standard A=10190:org.openxtalk.check.androidprobe}\n'
                  '    * Hist  #1: ActivityRecord{5b1 u0 com.google.android.permissioncontroller/'
                  'com.android.permissioncontroller.permission.ui.GrantPermissionsActivity t9}\n'
                  '    * Hist  #0: ActivityRecord{2e u0 org.openxtalk.check.androidprobe/.mblandroid t9}\n'
                  '  ResumedActivity: ActivityRecord{5b1 u0 com.google.android.permissioncontroller/'
                  'com.android.permissioncontroller.permission.ui.GrantPermissionsActivity t9}\n'
                  '  topResumedActivity=ActivityRecord{5b1 u0 com.google.android.permissioncontroller/'
                  'com.android.permissioncontroller.permission.ui.GrantPermissionsActivity t9}\n')
    PROBE_IN_FRONT = ('  * Task{d1 #9 type=standard A=10190:org.openxtalk.check.androidprobe}\n'
                      '    * Hist  #0: ActivityRecord{2e u0 org.openxtalk.check.androidprobe/.mblandroid t9}\n'
                      '  topResumedActivity=ActivityRecord{2e u0 org.openxtalk.check.androidprobe/.mblandroid t9}\n')
    UI = ("<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation=\"0\">"
          '<node index="0" text="Allow" resource-id="com.android.permissioncontroller:id/permission_allow_button" '
          'class="android.widget.Button" package="com.google.android.permissioncontroller" clickable="true" '
          'bounds="[84,1424][996,1556]" />'
          '<node index="1" text="Don&apos;t allow" '
          'resource-id="com.android.permissioncontroller:id/permission_deny_button" class="android.widget.Button" '
          'package="com.google.android.permissioncontroller" clickable="true" bounds="[84,1556][996,1688]" />'
          '</hierarchy>')
    PACKAGE = ('Packages:\n'
               '  Package [org.openxtalk.check.androidprobe] (5d2a1f0):\n'
               '    requested permissions:\n'
               '      android.permission.POST_NOTIFICATIONS\n'
               '    install permissions:\n'
               '      android.permission.INTERNET: granted=true\n'
               '    User 0: ceDataInode=2201 installed=true hidden=false\n'
               '      runtime permissions:\n'
               '        android.permission.POST_NOTIFICATIONS: granted=%s, flags=[ USER_SET|'
               'USER_SENSITIVE_WHEN_GRANTED|USER_SENSITIVE_WHEN_DENIED]\n')

    def run_probe(self, activities=ACTIVITIES, ui=UI, after=PACKAGE % 'true', dialog_from=1, allow=True,
                  timeout='10', lost=0, closing=0):
        """device on a running, green probe whose dialog is in front from
        the dialog_from'th look until Allow is tapped; after is what
        dumpsys package says once it is. The first `lost` taps are lost
        (the dialog stays), and the dialog stays `closing` more looks
        after the tap it takes. Every command the check sends to the
        stand-in that is about the permission is kept in calls."""
        d = self.tmp.name
        for name in ('calls', 'tapped', 'looked'):
            if os.path.exists(os.path.join(d, name)):
                os.remove(os.path.join(d, name))
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(self.LOG.split('I/lowmemorykiller')[0])
        for name, text in (('activities.txt', activities), ('ui.xml', ui), ('package.txt', self.PACKAGE % 'false'),
                           ('package-after.txt', after)):
            with open(os.path.join(d, name), 'w') as f:
                f.write(text)
        with open(os.path.join(d, 'probe.txt'), 'w') as f:
            f.write(self.PROBE_IN_FRONT)
        cases = ('  "shell dumpsys activity activities") echo "$*" >> "%(d)s/calls"\n'
                 '    [ -f "%(d)s/tapped" ] && echo >> "%(d)s/looked"\n'
                 '    if { [ -f "%(d)s/tapped" ] && [ $(wc -l < "%(d)s/looked") -gt %(closing)d ]; } || '
                 '[ $(grep -c activities "%(d)s/calls") -lt %(from)d ]; then\n'
                 '      cat "%(d)s/probe.txt"; else cat "%(d)s/activities.txt"; fi ;;\n'
                 '  "shell uiautomator dump /sdcard/oxt-ui.xml") echo "$*" >> "%(d)s/calls";'
                 ' echo "UI hierchary dumped to: /sdcard/oxt-ui.xml" ;;\n'
                 '  "shell cat /sdcard/oxt-ui.xml") echo "$*" >> "%(d)s/calls"; cat "%(d)s/ui.xml" ;;\n'
                 '  "shell input tap "*) echo "$*" >> "%(d)s/calls"\n'
                 '    if [ $(grep -c "input tap" "%(d)s/calls") -gt %(lost)d ]; then echo "$*" > "%(d)s/tapped"; fi ;;\n'
                 '  "shell dumpsys package org.openxtalk.check.androidprobe") echo "$*" >> "%(d)s/calls"\n'
                 '    if [ -f "%(d)s/tapped" ]; then cat "%(d)s/package-after.txt"; else cat "%(d)s/package.txt"; fi ;;\n'
                 % {'d': d, 'from': dialog_from, 'lost': lost, 'closing': closing})
        status, out = self.device('echo 3475', timeout=timeout, cases=cases,
                                  argv=('--allow', self.PERMISSION) if allow else ())
        return status, out, self.calls()

    def calls(self):
        try:
            with open(os.path.join(self.tmp.name, 'calls')) as f:
                return f.read().splitlines()
        except FileNotFoundError:
            return []

    def test_asked_allowed_and_held_passes(self):
        status, out, calls = self.run_probe()
        self.assertEqual(status, 0, out)
        for part in ('Android asks the user to allow android.permission.POST_NOTIFICATIONS',
                     'tapped Allow at 540,1490', 'android.permission.POST_NOTIFICATIONS: granted',
                     'Android device: passed'):
            self.assertIn(part, out)
        # the dialog's own button, found in the dump, tapped once
        self.assertEqual([c for c in calls if 'input tap' in c], ['shell input tap 540 1490'])
        self.assertLess(calls.index('shell uiautomator dump /sdcard/oxt-ui.xml'),
                        calls.index('shell cat /sdcard/oxt-ui.xml'))
        self.assertLess(calls.index('shell input tap 540 1490'),
                        calls.index('shell dumpsys package org.openxtalk.check.androidprobe'))
        # once allowed, the check looks for the dialog once more: gone
        self.assertEqual(calls.count('shell dumpsys activity activities'), 2)
        self.assertNotIn(' again', out)

    def test_a_lost_tap_on_allow_is_given_again(self):
        # run 42568140662: another app's "isn't responding" dialog took
        # the tap, and the permission dialog stayed in front
        saved = ac.ALLOW_AGAIN
        ac.ALLOW_AGAIN = 2
        try:
            status, out, calls = self.run_probe(lost=1, timeout='30')
        finally:
            ac.ALLOW_AGAIN = saved
        self.assertEqual(status, 0, out)
        self.assertEqual([c for c in calls if 'input tap' in c], ['shell input tap 540 1490'] * 2)
        self.assertRegex(out, r'  tapped Allow at 540,1490 again: the dialog was still in front \d+ s after the '
                              r'last tap\n')
        self.assertIn('android.permission.POST_NOTIFICATIONS: granted', out)

    def test_a_dialog_still_closing_is_not_tapped_again(self):
        # still in front one look (3 s) after the tap, within ALLOW_AGAIN:
        # left to close, and then gone
        status, out, calls = self.run_probe(closing=1, timeout='30')
        self.assertEqual(status, 0, out)
        self.assertEqual([c for c in calls if 'input tap' in c], ['shell input tap 540 1490'])
        self.assertEqual(calls.count('shell uiautomator dump /sdcard/oxt-ui.xml'), 1)
        self.assertEqual(calls.count('shell dumpsys activity activities'), 3)

    def test_allow_is_tapped_at_most_allow_taps_times(self):
        saved = ac.ALLOW_AGAIN
        ac.ALLOW_AGAIN = 0
        try:
            status, out, calls = self.run_probe(lost=99, timeout='30')
        finally:
            ac.ALLOW_AGAIN = saved
        self.assertEqual(status, 1, out)
        self.assertEqual([c for c in calls if 'input tap' in c], ['shell input tap 540 1490'] * ac.ALLOW_TAPS)
        self.assertIn("PROBLEM: android.permission.POST_NOTIFICATIONS was allowed in Android's dialog, and the "
                      "package does not hold it (not granted)", out)

    def test_green_before_the_dialog_does_not_end_the_wait(self):
        # the probe turns green at once, and the dialog comes after: the
        # wait goes on until it has been answered
        status, out, calls = self.run_probe(dialog_from=2)
        self.assertEqual(status, 0, out)
        # (and once more after the tap: gone)
        self.assertEqual(calls.count('shell dumpsys activity activities'), 3)
        self.assertIn('shell input tap 540 1490', calls)

    def test_never_asked_fails(self):
        status, out, calls = self.run_probe(activities=self.PROBE_IN_FRONT, timeout='4')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: the probe never asked the user to allow android.permission.POST_NOTIFICATIONS',
                      out)
        self.assertNotIn('tapped Allow', out)
        self.assertFalse([c for c in calls if 'input tap' in c])
        # it still says what the package holds
        self.assertIn('android.permission.POST_NOTIFICATIONS: not granted', out)

    def test_no_allow_button_fails(self):
        ui = self.UI.replace(':id/permission_allow_button', ':id/permission_allow_foreground_only_button')
        status, out, calls = self.run_probe(ui=ui, timeout='4')
        self.assertEqual(status, 1, out)
        self.assertIn('no Allow button in the dialog yet', out)
        self.assertIn('PROBLEM: Android asked the user to allow android.permission.POST_NOTIFICATIONS, and its '
                      'dialog had no Allow button to tap', out)
        self.assertFalse([c for c in calls if 'input tap' in c])
        self.assertNotIn('never asked', out)

    def test_allowed_and_not_held_fails(self):
        status, out, _ = self.run_probe(after=self.PACKAGE % 'false')
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: android.permission.POST_NOTIFICATIONS was allowed in Android's dialog, and the "
                      "package does not hold it (not granted)", out)
        status, out, _ = self.run_probe(after='Packages:\n  Package [org.openxtalk.check.androidprobe] (5d2a1f0):\n')
        self.assertEqual(status, 1, out)
        self.assertIn('android.permission.POST_NOTIFICATIONS: the package does not ask for it', out)
        self.assertIn('and the package does not hold it (it does not ask for it)', out)

    def test_the_fail_colour_still_ends_the_wait(self):
        with open(os.path.join(self.tmp.name, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(ac.FAIL_COLOR) + [255]) * 16)
        started = time.time()
        status, out, _ = self.run_probe(activities=self.PROBE_IN_FRONT, timeout='60')
        self.assertLess(time.time() - started, 30)
        self.assertEqual(status, 1, out)
        self.assertIn('a call it makes into the Java layer failed', out)
        self.assertIn('never asked the user to allow', out)

    def test_without_allow_nothing_is_asked_of_it(self):
        status, out, calls = self.run_probe(allow=False)
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, [])
        self.assertNotIn('allow', out.lower())



class PermissionReaders(unittest.TestCase):
    """What device --allow reads: the activity in front, the dialog's Allow
    button, and what the package holds"""

    def test_asking_for_permission(self):
        self.assertTrue(ac.asking_for_permission(DevicePermission.ACTIVITIES))
        # an AOSP image's permission controller, and Android 10's line
        aosp = ('  mResumedActivity: ActivityRecord{7 u0 com.android.permissioncontroller/'
                '.permission.ui.GrantPermissionsActivity t4}\n')
        self.assertTrue(ac.asking_for_permission(aosp))
        self.assertFalse(ac.asking_for_permission(DevicePermission.PROBE_IN_FRONT))
        self.assertFalse(ac.asking_for_permission(''))
        # the dialog in the task's history and not in front is not asking
        history = DevicePermission.ACTIVITIES.split('  ResumedActivity')[0] + (
            '  topResumedActivity=ActivityRecord{2e u0 org.openxtalk.check.androidprobe/.mblandroid t9}\n')
        self.assertFalse(ac.asking_for_permission(history))
        # another app's activity of the same name is not Android's
        self.assertFalse(ac.asking_for_permission(
            '  topResumedActivity=ActivityRecord{1 u0 org.example/.GrantPermissionsActivity t2}\n'))

    def test_allow_button(self):
        self.assertEqual(ac.allow_button(DevicePermission.UI), (540, 1490))
        # its attributes in another order
        self.assertEqual(ac.allow_button('<node bounds="[0,10][100,30]" text="Allow" '
                                         'resource-id="com.android.permissioncontroller:id/permission_allow_button"/>'),
                         (50, 20))
        for other in ('permission_deny_button', 'permission_allow_foreground_only_button',
                      'permission_allow_one_time_button'):
            self.assertIsNone(ac.allow_button(DevicePermission.UI.replace(':id/permission_allow_button',
                                                                          ':id/' + other)))
        self.assertIsNone(ac.allow_button(''))
        self.assertIsNone(ac.allow_button('<node resource-id="com.android.permissioncontroller:id/'
                                          'permission_allow_button" />'))

    # Android's "isn't responding" dialog, as uiautomator dumps it
    ANR_UI = ('<hierarchy><node resource-id="android:id/alertTitle" text="Pixel Launcher isn\'t responding" '
              'bounds="[90,980][990,1050]"/>'
              '<node resource-id="android:id/aerr_close" text="Close app" bounds="[90,1100][990,1220]"/>'
              '<node resource-id="android:id/aerr_wait" text="Wait" bounds="[90,1220][990,1340]"/></hierarchy>')

    def test_other_anr(self):
        # run 42354758286's 16 KB image: the launcher's dialog in front
        window = ('  mCurrentFocus=Window{22bc663 u0 Application Not Responding: '
                  'com.google.android.apps.nexuslauncher}\n'
                  '  mFocusedApp=ActivityRecord{67638321 u0 org.openxtalk.check.androidprobe/.mblandroid t8}\n')
        self.assertEqual(ac.other_anr(window), 'com.google.android.apps.nexuslauncher')
        # the probe's own is never answered: it is a failure
        self.assertIsNone(ac.other_anr(window.replace('com.google.android.apps.nexuslauncher', ac.IDENTIFIER)))
        self.assertIsNone(ac.other_anr('  mCurrentFocus=Window{2 u0 org.openxtalk.check.androidprobe/'
                                       'org.openxtalk.check.androidprobe.mblandroid}\n'))
        self.assertIsNone(ac.other_anr(''))

    def test_wait_button(self):
        self.assertEqual(ac.button_centre(self.ANR_UI, ac.WAIT_BUTTON), (540, 1280))
        self.assertIsNone(ac.button_centre(self.ANR_UI.replace('aerr_wait', 'aerr_mute'), ac.WAIT_BUTTON))
        self.assertEqual(ac.button_centre(DevicePermission.UI, ac.ALLOW_BUTTON), ac.allow_button(DevicePermission.UI))

    def test_permission_granted(self):
        package = DevicePermission.PACKAGE
        name = 'android.permission.POST_NOTIFICATIONS'
        self.assertIs(ac.permission_granted(package % 'true', name), True)
        self.assertIs(ac.permission_granted(package % 'false', name), False)
        self.assertIsNone(ac.permission_granted(package % 'true', 'android.permission.CAMERA'))
        # the requested list names it with no grant: that says nothing
        self.assertIsNone(ac.permission_granted('    requested permissions:\n      %s\n' % name, name))
        # a longer name is not this one
        self.assertIsNone(ac.permission_granted('        %s_X: granted=true\n' % name, name))
        self.assertIs(ac.permission_granted(package % 'true', 'android.permission.INTERNET'), True)
        # a second user's line after the probe's (user 0's) changes nothing
        two = (package % 'true') + ('    User 10: ceDataInode=0 installed=true hidden=false\n'
                                    '      runtime permissions:\n'
                                    '        %s: granted=false, flags=[ ]\n' % name)
        self.assertIs(ac.permission_granted(two, name), True)


class BundleReaders(unittest.TestCase):
    """The App Bundle's readers: protocol buffer fields, bundletool's
    BundleConfig.pb, where a package's file is in the base module, which
    files aapt2 convert rewrites, a jar's signers and pm path's APKs"""

    # BundleConfig.pb of an App Bundle the builder made (bundletool 1.18.3,
    # with androidBundleConfig's settings)
    CONFIG = bytes.fromhex('0a081206312e31382e33120212001a0b0a096173736574732f2a2a')

    def test_proto_fields(self):
        data = (b'\x08\x96\x01'            # 1: varint 150
                b'\x12\x03abc'             # 2: bytes
                b'\x1d\x01\x02\x03\x04'    # 3: fixed32
                b'\x21' + b'\0' * 8)       # 4: fixed64
        self.assertEqual(ac.proto_fields(data), [(1, 150), (2, b'abc'), (3, b'\x01\x02\x03\x04'), (4, b'\0' * 8)])
        self.assertEqual(ac.proto_fields(b''), [])
        self.assertEqual(ac.varint(b'\xac\x02', 0), (300, 2))
        for cut in (b'\x08', b'\x08\x96', b'\x12\x05ab'):
            with self.assertRaises(ac.CheckError):
                ac.proto_fields(cut)
        # a group (wire type 3) is not read
        with self.assertRaisesRegex(ac.CheckError, 'wire type 3'):
            ac.proto_fields(b'\x0b')

    def test_the_builders_config(self):
        self.assertEqual(ac.bundle_config(self.CONFIG), {
            'version': '1.18.3', 'uncompress_native_libraries': False, 'uncompressed_glob': ['assets/**']})

    def test_other_configs(self):
        # nothing said: bundletool's defaults (native libraries uncompressed)
        self.assertEqual(ac.bundle_config(b''), {
            'version': None, 'uncompress_native_libraries': None, 'uncompressed_glob': []})
        # enabled
        on = b'\x12\x04\x12\x02\x08\x01'
        self.assertIs(ac.bundle_config(on)['uncompress_native_libraries'], True)
        # an optimizations message that does not say
        self.assertIsNone(ac.bundle_config(b'\x12\x00')['uncompress_native_libraries'])
        # two globs, in order
        globs = b'\x1a\x0e\x0a\x05a/b/*\x0a\x05c/**/'
        self.assertEqual(ac.bundle_config(globs)['uncompressed_glob'], ['a/b/*', 'c/**/'])
        with self.assertRaises(ac.CheckError):
            ac.bundle_config(self.CONFIG[:-3])

    def test_bundle_place_is_the_builders(self):
        # the builder's androidBundleModulePath, by its unit's table in
        # android-check.livecodescript: the same answer for each path (the
        # builder reads the converted package, whose resources.arsc is
        # resources.pb)
        script = read('tools', 'ci', 'android-check.livecodescript')
        table = re.findall(r'"([^"=]+)=([^"]*)" & return & \\|"([^"=]+)=([^"]*)" into tWanted', script)
        pairs = [(a or c, b if a else d) for a, b, c, d in table]
        self.assertEqual(len(pairs), 12, pairs)
        for path, want in pairs:
            got = ac.bundle_place('resources.arsc' if path == 'resources.pb' else path)
            self.assertEqual(got, want or None, path)
        # what the bundle leaves out: the signature, folders
        for path in ('META-INF/MANIFEST.MF', 'META-INF/CERT.RSA', 'res/', 'lib/x86/'):
            self.assertIsNone(ac.bundle_place(path), path)
        self.assertEqual(ac.bundle_place('classes10.dex'), 'dex/classes10.dex')
        self.assertEqual(ac.bundle_place('stamp-cert-sha256'), 'root/stamp-cert-sha256')

    def test_bundle_converted(self):
        for place in ('manifest/AndroidManifest.xml', 'resources.pb', 'res/layout/livecode_inputcontrol.xml',
                      'res/xml/nfc_tech_filter.xml'):
            self.assertTrue(ac.bundle_converted(place), place)
        for place in ('res/drawable/notify_icon.png', 'assets/oxt-probe.txt', 'assets/x.xml', 'dex/classes.dex',
                      'lib/x86_64/librevandroid.so', 'root/a.xml'):
            self.assertFalse(ac.bundle_converted(place), place)

    def test_jar_signers(self):
        # keytool -printcert -jarfile, in English
        out = ('Signer #1:\n\nCertificate #1:\nOwner: CN=OXT Android Check, O=OXT-Beyond, C=US\n'
               'Issuer: CN=OXT Android Check, O=OXT-Beyond, C=US\nSerial number: de61670a3606b9f3\n')
        self.assertEqual(ac.jar_signers(out), 'CN=OXT Android Check, O=OXT-Beyond, C=US')
        self.assertEqual(ac.jar_signers(out + '\nSigner #2:\n\nCertificate #1:\nOwner: CN=Other\n' + out),
                         'CN=OXT Android Check, O=OXT-Beyond, C=US | CN=Other')
        self.assertIsNone(ac.jar_signers('Not a signed jar file\n'))
        # an empty owner is no owner, and does not take the next line
        self.assertIsNone(ac.jar_signers('Owner: \nIssuer: CN=x\n'))
        self.assertEqual(ac.jar_signers('Owner: CN=A\r\nIssuer: CN=x\r\n'), 'CN=A')
        self.assertIsNone(ac.jar_signers(''))

    def test_installed_apks(self):
        out = ('package:/data/app/~~a1/org.openxtalk.check.androidprobe-b2/base.apk\r\n'
               'package:/data/app/~~a1/org.openxtalk.check.androidprobe-b2/split_config.x86_64.apk\r\n'
               'package:/data/app/~~a1/org.openxtalk.check.androidprobe-b2/split_config.xxhdpi.apk\n')
        self.assertEqual(ac.installed_apks(out), ['base.apk', 'split_config.x86_64.apk', 'split_config.xxhdpi.apk'])
        self.assertEqual(ac.installed_apks('package:/data/app/x/base.apk\n'), ['base.apk'])
        self.assertEqual(ac.installed_apks(''), [])
        self.assertEqual(ac.installed_apks('Error: package not found\n'), [])


class ProbeSaid(unittest.TestCase):
    """What the Java layer's probe says in the device's log, a line a step"""

    def test_its_lines_in_order(self):
        log = ('I/ActivityManager(  590): Start proc 3475:org.openxtalk.check.androidprobe/u0a190 for activity\n'
               'I/LiveCode( 3475): OXT-Beyond probe: local notification 1\n'
               'I/revandroid( 3475): exportToAlbum called: oxt-beyond-probe .png\n'
               'I/LiveCode( 3475): OXT-Beyond probe: external documents   \n'
               'I/LiveCode( 3475): OXT-Beyond probe: export to album export failed\n')
        self.assertEqual(ac.probe_said(log, {'3475'}), ['local notification 1', 'external documents',
                                                        'export to album export failed'])
        # with no process known, every such line
        self.assertEqual(len(ac.probe_said(log)), 3)

    def test_only_the_engines_lines_of_the_probe(self):
        log = ('I/LiveCode(   99): OXT-Beyond probe: another process\n'
               'I/revandroid( 3475): OXT-Beyond probe: not the engine\'s line\n'
               'I/LiveCode( 3475): the engine, about something else\n'
               'I/LiveCode( 3475): said: OXT-Beyond probe: not at the start\n')
        self.assertEqual(ac.probe_said(log, {'3475'}), [])
        self.assertEqual(ac.probe_said(log), ['another process'])
        self.assertEqual(ac.probe_said(''), [])

    def test_the_probe_says_what_it_reads(self):
        # the probe's put lines begin as PROBE_SAYS reads them
        script = read('tools', 'ci', 'android-check.livecodescript')
        lines = re.findall(r'quote & "(OXT-Beyond probe: [^"]*)" & quote && "&& t\w+"', script)
        self.assertEqual(len(lines), 5, lines)
        for line in lines:
            self.assertEqual(ac.probe_said('I/LiveCode( 1): %s x\n' % line), [line[len('OXT-Beyond probe: '):]
                                                                              + ' x'])


class SharedPictures(unittest.TestCase):
    """device --picture's reading of MediaStore's shared pictures"""

    # as an Android 13 image's content query says them
    QUERY = ('Row: 0 _display_name=PXL_20260101.jpg, relative_path=DCIM/Camera/, owner_package_name=NULL\n'
             'Row: 1 _display_name=oxt-beyond-probe.png, relative_path=Pictures/, '
             'owner_package_name=org.openxtalk.check.androidprobe\n'
             'Row: 2 _display_name=a, b.png, relative_path=Pictures/, owner_package_name=org.example\n')

    def test_rows(self):
        rows = ac.shared_pictures(self.QUERY)
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0], {'_display_name': 'PXL_20260101.jpg', 'relative_path': 'DCIM/Camera/',
                                   'owner_package_name': 'NULL'})
        # a comma in a name is the name's
        self.assertEqual(rows[2]['_display_name'], 'a, b.png')
        self.assertEqual(ac.shared_pictures('No result found.\n'), [])
        self.assertEqual(ac.shared_pictures(''), [])

    def test_the_probes_picture(self):
        rows = ac.shared_pictures(self.QUERY)
        self.assertEqual(ac.probe_picture(rows, 'oxt-beyond-probe.png', ac.IDENTIFIER), rows[1])
        self.assertIsNone(ac.probe_picture(rows, 'oxt-beyond-probe.png', 'org.example'))
        self.assertIsNone(ac.probe_picture(rows, 'other.png', ac.IDENTIFIER))

    def test_named_apart_is_found(self):
        # the name a picture there has already (one the package added
        # before it was installed again): Android adds " (1)"
        row = {'_display_name': 'oxt-beyond-probe (1).png', 'relative_path': 'Pictures/',
               'owner_package_name': ac.IDENTIFIER}
        self.assertEqual(ac.probe_picture([row], 'oxt-beyond-probe.png', ac.IDENTIFIER), row)

    def test_what_is_not_it(self):
        mine = {'relative_path': 'Pictures/', 'owner_package_name': ac.IDENTIFIER}
        for name in ('oxt-beyond-probe.jpg', 'oxt-beyond-probe-2.png', 'xoxt-beyond-probe.png',
                     'oxt-beyond-probe (x).png', 'oxt-beyond-probe.png.png', 'oxt-beyond-probe (1) .png'):
            self.assertIsNone(ac.probe_picture([dict(mine, _display_name=name)], 'oxt-beyond-probe.png',
                                               ac.IDENTIFIER), name)
        # another folder, or no owner (the package's picture before it was
        # installed again)
        for other in ({'relative_path': 'DCIM/'}, {'relative_path': 'Pictures/x/'},
                      {'owner_package_name': 'NULL'}, {'owner_package_name': ac.IDENTIFIER + '.x'}):
            row = dict(mine, _display_name='oxt-beyond-probe.png', **other)
            self.assertIsNone(ac.probe_picture([row], 'oxt-beyond-probe.png', ac.IDENTIFIER), other)
        # a name's dot is a dot
        self.assertIsNone(ac.probe_picture([dict(mine, _display_name='oxt-beyond-probeXpng')],
                                           'oxt-beyond-probe.png', ac.IDENTIFIER))


class RemovalTaken(unittest.TestCase):
    """device --picture's wait, after the uninstall, for MediaProvider's
    lines of the package's removal"""

    def wait(self, answers, seconds=60):
        calls = []

        def a(*cmd, timeout=180):
            calls.append(cmd)
            return 0, answers[min(len(calls), len(answers)) - 1]
        out = io.StringIO()
        saved = ac.time.sleep
        ac.time.sleep = lambda x: None
        try:
            with contextlib.redirect_stdout(out):
                said = ac.removal_taken(a, seconds)
        finally:
            ac.time.sleep = saved
        return said, calls, out.getvalue()

    def test_said_at_once(self):
        said, calls, out = self.wait([DevicePicture.TAKEN])
        self.assertEqual(said, 'Before it is installed: MediaProvider took the removal of the package after 0 s '
                               '(deleted 0; orphaned 1)')
        self.assertEqual(calls, [('logcat', '-d', '-s', 'MediaProvider')])
        self.assertEqual(out, said + '\n')

    def test_said_later(self):
        older = 'D/MediaProvider( 1735): Orphaned 2 items belonging to org.openxtalk.check.androidprobe on x.db\n'
        said, calls, _ = self.wait(['', 'D/MediaProvider( 1735): Scanning\n', older])
        self.assertEqual(len(calls), 3)
        self.assertTrue(said.endswith('(orphaned 2)'), said)

    def test_another_package_is_not_it(self):
        other = ('D/MediaProvider( 1735): Orphaned 1 items belonging to org.openxtalk.check.androidprobe2 on x\n'
                 'D/MediaProvider( 1735): Orphaned 1 items belonging to org.openxtalk.check.androidprobe.x on x\n'
                 'D/MediaProvider( 1735): Orphaned 1 items belonging to com.example on x\n')
        said, calls, _ = self.wait([other], seconds=0)
        self.assertTrue(said.startswith('NOTE: MediaProvider has not said in 0 s'), said)
        self.assertEqual(len(calls), 1)


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DevicePicture(unittest.TestCase):
    """device --picture with a stand-in adb: the Java layer's probe exports
    a picture to the album, which must then be among the shared pictures
    (MediaStore) as the package's own; and what the probe said in the log
    is printed, and kept in the failure when it turns its fail colour"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    LOG = Device.LOG
    EVENTS = Device.EVENTS
    QUERY_CALL = ('shell content query --uri content://media/external/images/media '
                  '--projection _display_name:relative_path:owner_package_name')
    SAID = ('I/LiveCode( 3475): OXT-Beyond probe: local notification 1\n'
            'I/LiveCode( 3475): OXT-Beyond probe: external documents /storage/emulated/0/Android/data/x/files\n'
            'I/LiveCode( 3475): OXT-Beyond probe: has WRITE_EXTERNAL_STORAGE true\n'
            'I/LiveCode( 3475): OXT-Beyond probe: export to album\n')

    calls_of_adb = Device.calls

    # MediaProvider's lines for the removal of the package, as the 16 KB
    # Android 16 image says them (run 42359925885)
    TAKEN = ('D/MediaProvider( 1735): Deleted 0 Android/media items belonging to '
             'org.openxtalk.check.androidprobe on /data/user/0/com.google.android.providers.media.module/'
             'databases/external.db\n'
             'D/MediaProvider( 1735): Orphaned 1 items belonging to org.openxtalk.check.androidprobe on '
             '/data/user/0/com.google.android.providers.media.module/databases/external.db\n')

    def run_probe(self, pictures=SharedPictures.QUERY, said='', picture=True, colour=ac.RUN_COLOR,
                  uninstall='Success', taken=TAKEN):
        d = self.tmp.name
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0] + said)
        with open(os.path.join(d, 'pictures.txt'), 'w') as f:
            f.write(pictures)
        with open(os.path.join(d, 'taken.txt'), 'w') as f:
            f.write(taken)
        with open(os.path.join(d, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(colour) + [255]) * 16)
        cases = ('  "shell content query "*) echo "$*" >> "%(d)s/calls"; cat "%(d)s/pictures.txt" ;;\n'
                 '  "uninstall "*) echo "%(uninstall)s" ;;\n'
                 '  "logcat -d -s MediaProvider") cat "%(d)s/taken.txt" ;;\n' % {'d': d, 'uninstall': uninstall})
        status, out = self.device('echo 3475', timeout='10', cases=cases,
                                  argv=('--picture', 'oxt-beyond-probe.png') if picture else ())
        try:
            with open(os.path.join(d, 'calls')) as f:
                calls = f.read().splitlines()
        except FileNotFoundError:
            calls = []
        return status, out, calls

    def test_the_packages_picture_passes(self):
        status, out, calls = self.run_probe(said=self.SAID)
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, [self.QUERY_CALL])
        self.assertIn('Shared pictures the package owns: Pictures/oxt-beyond-probe.png', out)
        # what it said, each line in order
        at = [out.index('The probe said: ' + x) for x in (
            'local notification 1', 'external documents /storage/emulated/0/Android/data/x/files',
            'has WRITE_EXTERNAL_STORAGE true', 'export to album')]
        self.assertEqual(at, sorted(at))

    def test_no_picture_of_its_own_fails(self):
        query = SharedPictures.QUERY.replace('owner_package_name=org.openxtalk.check.androidprobe',
                                             'owner_package_name=NULL')
        status, out, _ = self.run_probe(query)
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: the probe's picture oxt-beyond-probe.png is not in the shared Pictures folder as "
                      "the package's own (it owns no shared picture; Pictures/oxt-beyond-probe.png there has no "
                      "owner)", out)
        self.assertIn('Shared pictures the package owns: none', out)
        # none of its name at all
        query = SharedPictures.QUERY.replace('_display_name=oxt-beyond-probe.png, relative_path=Pictures/, '
                                             'owner_package_name=org.openxtalk.check.androidprobe',
                                             '_display_name=x.png, relative_path=Pictures/, owner_package_name=NULL')
        status, out, _ = self.run_probe(query)
        self.assertIn("as the package's own (it owns no shared picture)\n", out)

    def test_waits_for_mediaprovider_to_take_the_removal(self):
        # run 42359925885: MediaProvider took the removal of the package
        # after it was installed again and had exported its picture, and
        # orphaned that; with --picture, device waits for it in between
        status, out, _ = self.run_probe(said=self.SAID)
        self.assertEqual(status, 0, out)
        calls = self.calls_of_adb()
        steps = [calls.index(x) for x in ('logcat -c', 'uninstall org.openxtalk.check.androidprobe',
                                          'logcat -d -s MediaProvider')]
        steps.append(next(i for i, c in enumerate(calls) if c.startswith('install')))
        self.assertEqual(steps, list(range(steps[0], steps[0] + 4)), calls)
        self.assertIn('Before it is installed: MediaProvider took the removal of the package after 0 s '
                      '(deleted 0; orphaned 1)', out)
        self.assertLess(out.index('Before it is installed:'), out.index('Installed debug.apk'))

    def test_no_wait_without_picture_or_without_a_removal(self):
        adb_calls = os.path.join(self.tmp.name, 'platform-tools', 'calls')
        for picture, uninstall in ((False, 'Success'), (True, 'Failure [DELETE_FAILED_INTERNAL_ERROR]')):
            if os.path.exists(adb_calls):
                os.remove(adb_calls)
            status, out, _ = self.run_probe(said=self.SAID, picture=picture, uninstall=uninstall)
            self.assertEqual(status, 0, out)
            calls = self.calls_of_adb()
            self.assertIn('uninstall org.openxtalk.check.androidprobe', calls)
            self.assertNotIn('logcat -d -s MediaProvider', calls)
            self.assertNotIn('MediaProvider', out)
            # the log is cleared before the uninstall only for the wait
            self.assertEqual(calls.index('logcat -c') < calls.index('uninstall org.openxtalk.check.androidprobe'),
                             picture, calls)

    def test_a_wait_that_ends_without_it_decides_nothing(self):
        saved = ac.REMOVAL_WAIT
        ac.REMOVAL_WAIT = 0
        try:
            status, out, _ = self.run_probe(said=self.SAID, taken='')
        finally:
            ac.REMOVAL_WAIT = saved
        self.assertEqual(status, 0, out)
        self.assertIn('NOTE: MediaProvider has not said in 0 s that it took the removal of the package; '
                      'a picture the probe exports may lose its owner when it does', out)

    def test_another_picture_of_its_own_is_named(self):
        query = SharedPictures.QUERY.replace('_display_name=oxt-beyond-probe.png', '_display_name=I1a2b3c4.png')
        status, out, _ = self.run_probe(query)
        self.assertEqual(status, 1, out)
        self.assertIn("as the package's own (it owns Pictures/I1a2b3c4.png)", out)

    def test_no_pictures_listed_says_what_it_answered(self):
        status, out, _ = self.run_probe('No result found.\n')
        self.assertEqual(status, 1, out)
        self.assertIn("as the package's own (MediaStore listed no picture: No result found.)", out)
        status, out, _ = self.run_probe('')
        self.assertIn('(MediaStore listed no picture: no answer)', out)

    def test_without_picture_mediastore_is_not_asked(self):
        status, out, calls = self.run_probe('', said=self.SAID, picture=False)
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, [])
        self.assertNotIn('Shared pictures', out)
        self.assertIn('The probe said: export to album', out)

    def test_the_fail_colour_keeps_what_it_said(self):
        said = self.SAID.replace('export to album\n', 'export to album export failed\n')
        status, out, _ = self.run_probe(said=said, colour=ac.FAIL_COLOR)
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: the probe's script ran, and a call it makes into the Java layer failed (the screen "
                      "is its fail colour, 100%; it said: local notification 1 | external documents "
                      "/storage/emulated/0/Android/data/x/files | has WRITE_EXTERNAL_STORAGE true | export to album "
                      "export failed)", out)


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DeviceBackAndBars(unittest.TestCase):
    """device --within-bars and --back with a stand-in adb: once green, the
    screen's first and last rows must not be the probe's green (the stack
    is not drawn under the system bars), and the back key must reach the
    probe's backKey, which turns it its back colour"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    LOG = Device.LOG
    EVENTS = Device.EVENTS

    @staticmethod
    def screen(rows):
        """a raw screencap 4 pixels wide, a row of each colour"""
        return struct.pack('<IIII', 4, len(rows), 1, 0) + b''.join(bytes(list(c) + [255]) * 4 for c in rows)

    def run_probe(self, before, after=None, gone=False, argv=('--back', '--within-bars'), out=False, then=None):
        """the probe shows before, and after once the back key is pressed
        (unchanged when None); gone: its process ends with the key; then:
        what it shows from the second screen on (the bars drawn late)"""
        d = self.tmp.name
        for name in ('calls', 'gone', 'shots'):
            if os.path.exists(os.path.join(d, name)):
                os.remove(os.path.join(d, name))
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0])
        with open(os.path.join(d, 'screen.raw'), 'wb') as f:
            f.write(self.screen(before))
        later = ''
        if then is not None:
            with open(os.path.join(d, 'then.raw'), 'wb') as f:
                f.write(self.screen(then))
            later = ('[ "$(grep -c shot "%(d)s/shots")" = 2 ] && cp "%(d)s/then.raw" "%(d)s/screen.raw"; '
                     % {'d': d})
        with open(os.path.join(d, 'back.raw'), 'wb') as f:
            f.write(self.screen(after if after is not None else before))
        cases = ('  "shell input keyevent KEYCODE_BACK") echo "$*" >> "%(d)s/calls"; echo key >> "%(d)s/shots"; '
                 'cp "%(d)s/back.raw" "%(d)s/screen.raw"; %(gone)s ;;\n'
                 % {'d': d, 'gone': 'touch "%s/gone"' % d if gone else 'true'})
        pidof = '[ -f "%s/gone" ] || echo 3475' % d
        extra = list(argv) + (['--out', os.path.join(d, 'screen.png')] if out else [])
        saved = ac.BACK_WAIT, ac.BARS_WAIT, ac.BARS_INTERVAL
        ac.BACK_WAIT, ac.BARS_WAIT, ac.BARS_INTERVAL = 3, 2, 0.3
        try:
            status, text = self.device(pidof, timeout='10', cases=cases, argv=extra,
                                       screencap='echo shot >> "%s/shots"; %s' % (d, later))
        finally:
            ac.BACK_WAIT, ac.BARS_WAIT, ac.BARS_INTERVAL = saved
        try:
            with open(os.path.join(d, 'calls')) as f:
                calls = f.read().splitlines()
        except FileNotFoundError:
            calls = []
        with open(os.path.join(d, 'shots')) as f:
            self.shots = f.read().splitlines()
        return status, text, calls

    G, K, B, F = ac.RUN_COLOR, (0, 0, 0), ac.BACK_COLOR, ac.FAIL_COLOR
    INSIDE = (K, G, G, K)

    def test_inside_the_bars_and_back_passes(self):
        status, out, calls = self.run_probe(self.INSIDE, (self.K, self.B, self.B, self.K), out=True)
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, ['shell input keyevent KEYCODE_BACK'])
        self.assertIn('The bars: the stack is inside them (the first and last rows are not its green)', out)
        self.assertRegex(out, r"After the back key: [1-9]\d*% of the screen is the probe's back colour; process 3475")
        # the first screen after the key that shows it ends the wait
        self.assertEqual(self.shots[self.shots.index('key'):], ['key', 'shot'])
        # the screen after the key, beside the first
        back = os.path.join(self.tmp.name, 'screen-back.png')
        self.assertIn('Screen after the back key: %s' % back, out)
        with open(back, 'rb') as f:
            self.assertEqual(f.read(8), b'\x89PNG\r\n\x1a\n')

    def test_drawn_under_the_bars_fails(self):
        status, out, _ = self.run_probe((self.G,) * 4, (self.B,) * 4)
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: the stack is drawn under the system bars (its green in the screen's top 100% and "
                      "bottom 100% row)", out)
        status, out, _ = self.run_probe((self.G, self.G, self.G, self.K), (self.B,) * 4)
        self.assertIn("(its green in the screen's top 100% row)", out)

    def test_drawn_under_the_bars_looks_again(self):
        # the screen is taken again until BARS_WAIT (2 s here) has passed,
        # and the failure says so
        status, out, _ = self.run_probe((self.G,) * 4, argv=('--within-bars',))
        self.assertEqual(status, 1, out)
        self.assertIn("The bars: the first green screen has the stack's green in its top 100% and bottom 100% row; "
                      "the screen again for up to 2 s", out)
        self.assertRegex(out, r"The bars: [4-7] more screen\(s\) in 2 s; the stack's green is still where the "
                              r"bars are")
        self.assertGreaterEqual(self.shots.count('shot'), 5)

    def test_bars_drawn_late_pass(self):
        # the first green screen is green where the bars are, the next has
        # them over it: the stack is inside them
        status, out, calls = self.run_probe((self.G,) * 4, argv=('--within-bars',), then=self.INSIDE)
        self.assertEqual(status, 0, out)
        self.assertIn('The bars: 1 more screen(s) in 0 s; the bars are drawn over the stack in the last', out)
        self.assertIn('The bars: the stack is inside them (the first and last rows are not its green)', out)
        self.assertEqual(self.shots, ['shot', 'shot'])

    def test_a_screen_that_is_not_the_probe_says_nothing_of_the_bars(self):
        # a black screen (a dialog, the probe gone) next: still under them
        status, out, _ = self.run_probe((self.G,) * 4, argv=('--within-bars',), then=(self.K,) * 4)
        self.assertEqual(status, 1, out)
        self.assertIn("the stack's green is still where the bars are", out)

    def test_inside_the_bars_takes_no_more_screens(self):
        status, out, _ = self.run_probe(self.INSIDE, argv=('--within-bars',))
        self.assertEqual(status, 0, out)
        self.assertEqual(self.shots, ['shot'])
        self.assertNotIn('the screen again', out)

    def test_back_not_reaching_backkey_fails(self):
        status, out, calls = self.run_probe(self.INSIDE)
        self.assertEqual(status, 1, out)
        self.assertEqual(calls, ['shell input keyevent KEYCODE_BACK'])
        self.assertIn("PROBLEM: the back key did not reach the stack's backKey (0% of the screen its back colour; "
                      "the app is running)", out)
        # it looked again until BACK_WAIT (3 s here) had passed
        self.assertEqual(self.shots[self.shots.index('key'):], ['key', 'shot', 'shot'])

    def test_back_ending_the_app_fails(self):
        # an unhandled back key ends the app: the stack never got it
        status, out, _ = self.run_probe(self.INSIDE, (self.K,) * 4, gone=True)
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: the back key did not reach the stack's backKey (0% of the screen its back colour; "
                      "the app is gone)", out)
        self.assertIn("process not running", out)

    def test_neither_unless_asked(self):
        status, out, calls = self.run_probe((self.G,) * 4, argv=())
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, [])
        self.assertNotIn('The bars:', out)
        self.assertNotIn('back key', out)

    def test_not_green_is_not_asked_more(self):
        # the fail colour fails as before, and neither check runs
        status, out, calls = self.run_probe((self.F,) * 4)
        self.assertEqual(status, 1, out)
        self.assertEqual(calls, [])
        self.assertNotIn('The bars:', out)
        self.assertIn("a call it makes into the Java layer failed", out)

    def test_each_alone(self):
        status, out, calls = self.run_probe((self.G,) * 4, (self.B,) * 4, argv=('--back',))
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, ['shell input keyevent KEYCODE_BACK'])
        status, out, calls = self.run_probe(self.INSIDE, argv=('--within-bars',))
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, [])


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DeviceAnotherAppsAnr(unittest.TestCase):
    """device with another app's "isn't responding" dialog in front of the
    probe (run 42354758286: the launcher's, its scrim dimming the probe's
    green): it taps the dialog's Wait, and the probe's green ends the wait;
    a dialog that stays is answered at most ANR_TAPS times"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    calls = Device.calls
    LOG = Device.LOG
    EVENTS = Device.EVENTS

    def run_probe(self, wait_closes=True, package='com.google.android.apps.nexuslauncher'):
        d = self.tmp.name
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0])
        # the probe's green under the dialog's scrim, and then without it
        dim = tuple(c * 2 // 5 for c in ac.RUN_COLOR)
        with open(os.path.join(d, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(dim) + [255]) * 16)
        with open(os.path.join(d, 'green.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(ac.RUN_COLOR) + [255]) * 16)
        with open(os.path.join(d, 'ui.xml'), 'w') as f:
            f.write(PermissionReaders.ANR_UI)
        # the dialog has the focus until Wait is tapped (when it closes)
        anr = ('[ -f "%s/answered" ] || printf "  mCurrentFocus=Window{22bc663 u0 Application Not Responding: '
               '%s}\\n"' % (d, package))
        tap = ('cp "%(d)s/green.raw" "%(d)s/screen.raw"; touch "%(d)s/answered"' % {'d': d}) if wait_closes else 'true'
        cases = ('  "shell uiautomator dump /sdcard/oxt-ui.xml") true ;;\n'
                 '  "shell cat /sdcard/oxt-ui.xml") cat "%(d)s/ui.xml" ;;\n'
                 '  "shell input tap 540 1280") %(tap)s ;;\n' % {'d': d, 'tap': tap})
        status, out = self.device('echo 3475', timeout='20', cases=cases, window=anr)
        return status, out, [c for c in self.calls() if c.startswith(('shell uiautomator', 'shell input'))]

    def test_wait_is_tapped_and_the_probe_passes(self):
        status, out, calls = self.run_probe()
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, ['shell uiautomator dump /sdcard/oxt-ui.xml', 'shell input tap 540 1280'])
        self.assertIn("  com.google.android.apps.nexuslauncher isn't responding, its dialog in front of the probe: "
                      "tapped Wait at 540,1280", out)
        self.assertRegex(out, r"After \d+ s: 100% of the screen is the probe's green")

    def test_a_dialog_that_stays_is_answered_three_times(self):
        status, out, calls = self.run_probe(wait_closes=False)
        self.assertEqual(status, 1, out)
        self.assertEqual(calls.count('shell input tap 540 1280'), ac.ANR_TAPS)
        self.assertIn("PROBLEM: the screen never turned the probe's green", out)

    def test_the_probes_own_is_not_answered(self):
        status, out, calls = self.run_probe(package=ac.IDENTIFIER)
        self.assertEqual(status, 1, out)
        self.assertEqual(calls, [])


class PidNow(unittest.TestCase):
    """The probe's process ids, with adb's own failures asked again"""

    def ask(self, answers, tries=None, fails=False):
        calls = []

        def a(*cmd, timeout=180):
            calls.append(cmd)
            if cmd[0] == 'wait-for-device':
                if fails:
                    raise ac.CheckError('adb wait-for-device: timed out')
                return 0, ''
            return 0, answers[min(sum(c[0] == 'shell' for c in calls), len(answers)) - 1]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            got = ac.pid_now(a, tries)
        return got, calls, out.getvalue()

    def test_process_ids_and_none(self):
        for answer, want in (('3475\n', '3475'), ('3475 3612\n', '3475 3612'), ('', ''), ('\n', '')):
            got, calls, out = self.ask([answer])
            self.assertEqual(got, want)
            self.assertEqual(calls, [('shell', 'pidof', ac.IDENTIFIER)])
            self.assertEqual(out, '')

    def test_device_offline_for_a_moment(self):
        got, calls, out = self.ask(['adb: device offline\n', '5450\n'])
        self.assertEqual(got, '5450')
        self.assertEqual(calls, [('shell', 'pidof', ac.IDENTIFIER), ('wait-for-device',),
                                 ('shell', 'pidof', ac.IDENTIFIER)])
        self.assertEqual(out, '  pidof: adb: device offline; waiting for the device\n')

    def test_offline_throughout_gives_adbs_answer(self):
        got, calls, out = self.ask(['error: device \'emulator-5554\' not found\n'], tries=2, fails=True)
        self.assertEqual(got, "error: device 'emulator-5554' not found")
        self.assertEqual([c[0] for c in calls], ['shell', 'wait-for-device', 'shell', 'wait-for-device'])
        self.assertIn('  wait-for-device: adb wait-for-device: timed out\n', out)


class GreenAgain(unittest.TestCase):
    """green_again, the wait of --font-scale, --density and --relaunch for
    the probe's green, answers another app's "isn't responding" dialog in
    front of it, as device's first wait does, at most ANR_TAPS times"""

    BLACK = (1, 1, bytes([0, 0, 0, 255]))
    GREEN = (1, 1, bytes(list(ac.RUN_COLOR) + [255]))

    def wait(self, shots, answer, seconds=5):
        answered = []
        saved = ac.screen_now, ac.answer_other_anr, ac.time.sleep
        ac.screen_now = lambda adb, serial: shots.pop(0) if len(shots) > 1 else shots[0]
        ac.answer_other_anr = lambda a: answered.append(a) or answer
        ac.time.sleep = lambda seconds: None
        try:
            got = ac.green_again('adb', 'emulator-5554', lambda *cmd: (0, '4242\n'), seconds)
        finally:
            ac.screen_now, ac.answer_other_anr, ac.time.sleep = saved
        return got, len(answered)

    def test_the_dialog_answered_then_green(self):
        (share, pid, shot), answered = self.wait([self.BLACK, self.GREEN],
                                                 'com.google.android.apps.nexuslauncher')
        self.assertEqual((share, pid, shot), (1.0, '4242', self.GREEN))
        self.assertEqual(answered, 1)

    def test_a_dialog_that_stays_is_answered_at_most_anr_taps_times(self):
        (share, _, _), answered = self.wait([self.BLACK], 'com.google.android.apps.nexuslauncher', seconds=0.2)
        self.assertEqual(share, 0.0)
        self.assertEqual(answered, ac.ANR_TAPS)

    def test_no_dialog_no_tap(self):
        # asked on every screen that is not green, and nothing counted
        (share, _, _), answered = self.wait([self.BLACK, self.BLACK, self.GREEN], None)
        self.assertEqual(share, 1.0)
        self.assertEqual(answered, 2)

    def test_green_asks_nothing(self):
        (share, _, _), answered = self.wait([self.GREEN], 'x')
        self.assertEqual((share, answered), (1.0, 0))


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DeviceOnceInAProcess(unittest.TestCase):
    """device --font-scale, --density and --relaunch with a stand-in adb
    whose probe process is a file: the engine runs once in a process, so
    the app goes on through a font size change in its process, starts again
    in a new one for a density change, and once its stack quits (the back
    key) its process ends and the app opened again starts in a new one; a
    second start in a process is stopped (fdsan) and fails each"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    calls = Device.calls
    LOG = Device.LOG
    EVENTS = Device.EVENTS

    FDSAN = ('F/libc    ( %s): fdsan: attempted to close file descriptor 0, expected to be unowned, actually owned '
             'by FILE* 0x7b1c\n'
             'F/libc    ( %s): Fatal signal 6 (SIGABRT), code -1 (SI_QUEUE) in tid %s (androidprobe)\n')

    # what Android logs when the app crashes in Java (run 42430696858's,
    # the activity made again with no engine given a configuration change)
    NPE = ('E/AndroidRuntime( %s): FATAL EXCEPTION: main\n'
           "E/AndroidRuntime( %s): java.lang.NullPointerException: Attempt to invoke virtual method 'void "
           'com.runrev.android.Engine.onConfigurationChanged(android.content.res.Configuration)\' on a null object '
           'reference\n')

    def run_probe(self, argv, font='same', density='new', back='ends', again='new', font_before='1.0',
                  offline_at=None, tap='waits', reset='new', cleared=False):
        """What the stand-in device's probe does: for a font size change
        (same: goes on in its process; crash: the second start stopped,
        and no process), a density change (new: started again in a new
        process, green, and again for the reset; crash; hang: its process
        stays, the screen as it was; old-crash: as new, and the process
        before it crashes in Java), the density's reset (new: started again
        in a new process; crash: as new, and the process before it crashes
        in Java), the back key (ends: its process ends;
        stays), the second am start (new: a new process where none is left;
        crash: none) and a tap at the 4 x 4 screen's middle (waits: the
        screen turns the wait colour, as the probe's mouseUp turns it;
        nothing); adb answers pidof's call number offline_at with "adb:
        device offline" (on its output, exit status 1), as it did for a
        moment on the 16 KB image; cleared: the log holds nothing of the
        probe's start, as a device's does once the check has cleared it"""
        d = self.tmp.name
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write('' if cleared else Device.LOG.split('I/lowmemorykiller')[0])
        with open(os.path.join(d, 'pid'), 'w') as f:
            f.write('3475\n')
        for name, colour in (('green.raw', ac.RUN_COLOR), ('wait.raw', ac.WAIT_COLOR)):
            with open(os.path.join(d, name), 'wb') as f:
                f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(colour) + [255]) * 16)
        crash = 'p=$(cat "%(d)s/pid"); : > "%(d)s/pid"; printf "%(fdsan)s" $p $p $p >> "%(d)s/logcat.txt"' % {
            'd': d, 'fdsan': self.FDSAN.replace('\n', '\\n')}
        new = lambda pid: 'echo %s > "%s/pid"' % (pid, d)
        # the process before it crashes in Java as the app starts again
        npe = 'p=$(cat "%(d)s/pid"); printf "%(npe)s" $p $p >> "%(d)s/logcat.txt"; ' % {
            'd': d, 'npe': self.NPE.replace('\n', '\\n').replace("'", "'\\''")}
        cases = (
            '  "shell settings get system font_scale") echo %(before)s ;;\n'
            '  "shell settings put system font_scale %(scale)s") %(font)s ;;\n'
            '  "shell wm density") printf "Physical density: 420\\n" ;;\n'
            '  "shell wm density reset") [ -s "%(d)s/pid" ] && %(reset)s ;;\n'
            '  "shell wm density 357") %(density)s ;;\n'
            '  "shell input keyevent KEYCODE_BACK") %(back)s ;;\n'
            '  "shell input tap 2 2") %(tap)s ;;\n'
            % {'d': d, 'before': font_before, 'scale': ac.FONT_SCALE,
               'reset': {'new': new(4100), 'crash': '{ ' + npe + new(4100) + '; }'}[reset],
               'font': {'same': 'true', 'crash': crash}[font],
               'density': {'new': new(4000) + '; cp "%(d)s/green.raw" "%(d)s/screen.raw"' % {'d': d},
                           'old-crash': npe + new(4000) + '; cp "%(d)s/green.raw" "%(d)s/screen.raw"' % {'d': d},
                           'crash': crash, 'hang': 'true'}[density],
               'back': {'ends': ': > "%s/pid"' % d, 'stays': 'true'}[back],
               'tap': {'waits': 'cp "%(d)s/wait.raw" "%(d)s/screen.raw"' % {'d': d}, 'nothing': 'true'}[tap]})
        # the second am start: a new process where the first has ended
        started = 'grep -c "^shell am start" "%s/platform-tools/calls"' % d
        second = {'new': '[ -s "%(d)s/pid" ] || { [ $(%(n)s) -ge 2 ] && echo 5000 > "%(d)s/pid"; }',
                  'crash': '[ -s "%(d)s/pid" ] || { [ $(%(n)s) -ge 2 ] && [ ! -f "%(d)s/again" ] && '
                           'touch "%(d)s/again" && printf "%(s)s%(f)s" 5000 5000 5000 5000 >> "%(d)s/logcat.txt"; }'}[again]
        pidof = (second + '; cat "%(d)s/pid"') % {'d': d, 'n': started,
                                                   'f': self.FDSAN.replace('\n', '\\n'),
                                                   's': Device.LOG.splitlines()[0].replace('3475', '%s') + '\\n'}
        if offline_at:
            asked = 'grep -c "^shell pidof" "%s/platform-tools/calls"' % d
            pidof = ('if [ $(%s) -eq %d ]; then echo "adb: device offline"; exit 1; fi; ' % (asked, offline_at)
                     + pidof)
        saved = ac.RETURN_WAIT, ac.END_WAIT, ac.FONT_SETTLE, ac.WAIT_SEEN
        ac.RETURN_WAIT, ac.END_WAIT, ac.FONT_SETTLE, ac.WAIT_SEEN = 6, 3, 0, 3
        try:
            status, out = self.device(pidof, timeout='10', cases=cases,
                                      argv=list(argv) + ['--out', os.path.join(d, 'screen.png')])
        finally:
            ac.RETURN_WAIT, ac.END_WAIT, ac.FONT_SETTLE, ac.WAIT_SEEN = saved
        return status, out, [c for c in self.calls() if c.startswith(('shell settings', 'shell wm',
                                                                             'shell input', 'shell am start'))]

    def png(self, suffix):
        with open(os.path.join(self.tmp.name, 'screen-%s.png' % suffix), 'rb') as f:
            return f.read(8) == b'\x89PNG\r\n\x1a\n'

    def test_through_a_font_size_change(self):
        status, out, calls = self.run_probe(['--font-scale'])
        self.assertEqual(status, 0, out)
        self.assertEqual(calls[1:], ['shell settings get system font_scale',
                                     'shell settings put system font_scale %s' % ac.FONT_SCALE,
                                     'shell settings put system font_scale 1.0'])
        self.assertIn("After a font size change (font_scale 1.3, then 1.0 again): 100% of the screen is the probe's "
                      "green; process 3475 (before it: 3475)", out)
        self.assertTrue(self.png('font-scale'))

    def test_a_font_scale_never_set_is_deleted_again(self):
        status, out, calls = self.run_probe(['--font-scale'], font_before='null')
        self.assertEqual(status, 0, out)
        self.assertEqual(calls[-1], 'shell settings delete system font_scale')
        self.assertIn('(font_scale 1.3, then unset again)', out)

    def test_adb_offline_for_a_moment_is_not_the_probes_process(self):
        # run 42360582880: pidof, just before the font size change, answered
        # "adb: device offline", taken for the probe's process; it waits for
        # the device and asks again
        status, out, _ = self.run_probe(['--font-scale'], offline_at=2)
        self.assertEqual(status, 0, out)
        self.assertIn('  pidof: adb: device offline; waiting for the device\n', out)
        self.assertIn("process 3475 (before it: 3475)", out)
        calls = self.calls()
        at = [i for i, c in enumerate(calls) if c.startswith('shell pidof')]
        self.assertEqual(calls[at[1] + 1], 'wait-for-device', calls)
        self.assertEqual(calls[at[1] + 2], calls[at[1]], calls)

    def test_stopped_by_a_font_size_change(self):
        # the released builder's manifest: Android made the activity again,
        # and the engine's second start in the process was stopped
        status, out, calls = self.run_probe(['--font-scale'], font='crash')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: the app did not go on through a font size change in its process (3475 before it, '
                      'none after)', out)
        self.assertIn("PROBLEM: the device's log across the font size change: F/libc    ( 3475): Fatal signal 6", out)
        self.assertIn('fdsan: attempted to close file descriptor 0', out)
        # the font size is put back all the same
        self.assertEqual(calls[-1], 'shell settings put system font_scale 1.0')

    def test_started_again_for_a_density_change(self):
        status, out, calls = self.run_probe(['--density'])
        self.assertEqual(status, 0, out)
        self.assertEqual(calls[1:], ['shell wm density', 'shell wm density 357', 'shell wm density reset'])
        self.assertIn("After a density change (357, from 420): 100% of the screen is the probe's green; process "
                      "4000 (before it: 3475)", out)
        self.assertTrue(self.png('density'))

    def test_stopped_by_a_density_change(self):
        status, out, calls = self.run_probe(['--density'], density='crash')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: after a density change the app did not start again in a new process (3475 before '
                      'it, none after)', out)
        self.assertIn("PROBLEM: the device's log across the density change: F/libc    ( 3475): Fatal signal 6", out)
        self.assertIn('| F/libc    ( 3475): fdsan: attempted to close file descriptor 0', out)
        # the density is put back all the same
        self.assertEqual(calls[-1], 'shell wm density reset')

    def test_a_crash_in_the_process_before_a_density_change(self):
        # run 42430696858: the activity made again in the process whose
        # engine ran starts the app again in a new one, and crashed there
        # in Java (onConfigurationChanged with no engine); the log, cleared
        # before the change, says nothing of that process's start, and its
        # crash was taken for another app's
        status, out, calls = self.run_probe(['--density'], density='old-crash', cleared=True)
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: the device's log across the density change: E/AndroidRuntime( 3475): FATAL "
                      "EXCEPTION: main", out)
        self.assertIn("process 4000 (before it: 3475); its processes in the log: 3475, 4000", out)
        self.assertEqual(calls[-1], 'shell wm density reset')

    def test_a_crash_at_the_return_to_the_screens_own_density(self):
        # the density's reset makes the activity again too: a crash there
        # was not looked for, and its dialog took the back key of
        # --relaunch (run 42430696858)
        status, out, calls = self.run_probe(['--density', '--relaunch'], reset='crash', cleared=True)
        self.assertEqual(status, 1, out)
        self.assertIn("Back at the screen's own density: 100% of the screen is the probe's green; process 4100 "
                      "(before it: 4000); its processes in the log: 4000, 4100", out)
        self.assertIn("PROBLEM: the device's log across the return to the screen's own density after the density "
                      "change: E/AndroidRuntime( 4000): FATAL EXCEPTION: main", out)
        # the first problem ends them
        self.assertNotIn('KEYCODE_BACK', ' '.join(calls))

    def test_back_at_the_screens_own_density(self):
        status, out, _ = self.run_probe(['--density'], cleared=True)
        self.assertEqual(status, 0, out)
        self.assertIn("Back at the screen's own density: 100% of the screen is the probe's green; process 4100 "
                      "(before it: 4000)", out)

    def test_started_again_for_a_density_change_while_its_script_waits(self):
        # the probe's mouseUp turns its wait colour and waits; the density
        # is changed while it waits, and the app starts again in a new
        # process once the wait is over (the engine built here)
        status, out, calls = self.run_probe(['--density-in-wait'])
        self.assertEqual(status, 0, out)
        self.assertEqual(calls[1:], ['shell input tap 2 2', 'shell wm density', 'shell wm density 357',
                                     'shell wm density reset'])
        self.assertIn('After a tap on the probe: 100%% of the screen is its wait colour, 1 s after the tap (it waits '
                      '%d s)' % ac.PROBE_WAIT, out)
        self.assertIn("After a density change while the probe's script waited (357, from 420): 100% of the screen "
                      "is the probe's green; process 4000 (before it: 3475)", out)
        self.assertTrue(self.png('density-in-wait'))

    def test_hung_by_a_density_change_while_its_script_waits(self):
        # 9.6.3's engine, and this tree's before its doDestroy finished the
        # engine: the process stays, hung, the screen its wait colour
        status, out, calls = self.run_probe(['--density-in-wait'], density='hang')
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: after a density change while the probe's script waited the app did not start again "
                      "in a new process (3475 before it, 3475 after)", out)
        self.assertIn("After a density change while the probe's script waited (357, from 420): 0% of the screen is "
                      "the probe's green; process 3475 (before it: 3475)", out)
        # the density is put back all the same
        self.assertEqual(calls[-1], 'shell wm density reset')

    def test_a_tap_that_reaches_no_mouse_up(self):
        # a probe without the mouseUp (a stack saved before it): the screen
        # stays green, and the density is not changed, so a pass would say
        # nothing about a script that waits
        status, out, calls = self.run_probe(['--density-in-wait'], tap='nothing')
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: a tap did not reach the probe's mouseUp: the screen did not turn its wait colour in "
                      "3 s (0%)", out)
        self.assertEqual(calls[1:], ['shell input tap 2 2'])

    def test_the_wait_colour_seen_too_late(self):
        # the screen taken slowly: the wait colour seen after WAIT_SEEN may
        # be the last of the wait, so the density is not changed
        saved = ac.screen_now

        def slow(adb, serial):
            got = saved(adb, serial)
            if got and ac.colour_share(got[2], ac.WAIT_COLOR) >= 0.25:
                time.sleep(3)
            return got
        ac.screen_now = slow
        try:
            status, out, calls = self.run_probe(['--density-in-wait'])
        finally:
            ac.screen_now = saved
        self.assertEqual(status, 1, out)
        self.assertRegex(out, r"PROBLEM: the probe's wait colour was seen \d s after the tap, too late to change the "
                              r"density while its script surely waits \(at most 3 s\)")
        self.assertEqual(calls[1:], ['shell input tap 2 2'])

    def test_the_tap_is_the_screens_middle(self):
        # wherever the screen is: the probe's stack fills it (exactFit),
        # and its field is at its top
        said = []

        def a(*cmd, timeout=180):
            said.append(cmd)
            return 0, ''
        saved = ac.screen_now, ac.WAIT_SEEN
        ac.screen_now = lambda adb, serial: (1080, 2340, b'') if not said else None
        ac.WAIT_SEEN = 0
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                got = ac.starts_again_for_density_in_wait(argparse.Namespace(serial='emulator-5554', out=None),
                                                           'adb', a, '3475', [])
        finally:
            ac.screen_now, ac.WAIT_SEEN = saved
        self.assertEqual(said, [('shell', 'input', 'tap', '540', '1170')])
        self.assertEqual(len(got), 1)

    def test_no_screen_no_tap(self):
        saved = ac.screen_now
        ac.screen_now = lambda adb, serial: None
        said = []
        try:
            got = ac.starts_again_for_density_in_wait(argparse.Namespace(serial='emulator-5554', out=None),
                                                       'adb', lambda *cmd, timeout=180: said.append(cmd), '3475', [])
        finally:
            ac.screen_now = saved
        self.assertEqual(got, ['no screen of the probe to find where to tap it'])
        self.assertEqual(said, [])

    def test_opened_again_after_its_stack_quit(self):
        status, out, calls = self.run_probe(['--relaunch'])
        self.assertEqual(status, 0, out)
        self.assertEqual(calls[1:], ['shell input keyevent KEYCODE_BACK',
                                     'shell am start -W -n %s/.mblandroid' % ac.IDENTIFIER])
        self.assertIn('After the back key: process none: it ended', out)
        self.assertIn("Opened again after its stack quit: 100% of the screen is the probe's green; process 5000 "
                      "(the first: 3475)", out)
        self.assertTrue(self.png('again'))

    def test_a_process_left_after_its_stack_quit(self):
        # the release's Java layer: the process stays, and the app opened
        # again starts its engine in it a second time
        status, out, _ = self.run_probe(['--relaunch'], back='stays')
        self.assertEqual(status, 1, out)
        self.assertIn('After the back key: process 3475, still there after 3 s', out)
        self.assertIn("PROBLEM: the app's process was still there 3 s after its stack quit (the back key)", out)

    def test_stopped_when_opened_again(self):
        status, out, _ = self.run_probe(['--relaunch'], again='crash')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: opened again after its stack quit, the app did not show its green (100%; process '
                      'none)', out)
        self.assertIn("PROBLEM: the device's log, opened again after its stack quit: F/libc    ( 5000): Fatal "
                      "signal 6", out)
        self.assertIn('| F/libc    ( 5000): fdsan: attempted to close file descriptor 0', out)

    def test_all_three_in_order(self):
        status, out, calls = self.run_probe(['--font-scale', '--density', '--relaunch'])
        self.assertEqual(status, 0, out)
        self.assertEqual([c.split()[1] for c in calls[1:]], ['settings'] * 3 + ['wm'] * 3 + ['input', 'am'])
        # each takes the process the one before left: 4100 after the
        # density's reset
        self.assertIn('Opened again after its stack quit: 100% of the screen is the probe\'s green; process 5000 '
                      '(the first: 4100)', out)

    def test_all_four_in_order(self):
        # the density changed while the script waits after the plain one,
        # each in the process the one before left
        status, out, calls = self.run_probe(['--font-scale', '--density', '--density-in-wait', '--relaunch'])
        self.assertEqual(status, 0, out)
        self.assertEqual([c.split()[1] for c in calls[1:]],
                         ['settings'] * 3 + ['wm'] * 3 + ['input'] + ['wm'] * 3 + ['input', 'am'])
        self.assertEqual(calls[7], 'shell input tap 2 2')
        self.assertIn("After a density change while the probe's script waited (357, from 420): 100% of the screen "
                      "is the probe's green; process 4000 (before it: 4100)", out)
        self.assertIn('Opened again after its stack quit: 100% of the screen is the probe\'s green; process 5000 '
                      '(the first: 4100)', out)

    def test_the_first_problem_ends_them(self):
        status, out, calls = self.run_probe(['--font-scale', '--density', '--relaunch'], font='crash')
        self.assertEqual(status, 1, out)
        self.assertEqual([c.split()[1] for c in calls[1:]], ['settings'] * 3)
        self.assertNotIn('After a density change', out)

    def test_none_unless_asked(self):
        status, out, calls = self.run_probe([])
        self.assertEqual(status, 0, out)
        self.assertEqual(calls, ['shell am start -W -n %s/.mblandroid' % ac.IDENTIFIER])


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class DevicePermissionUnderAnr(unittest.TestCase):
    """device --allow with another app's "isn't responding" dialog over
    Android's permission dialog (run 42376416337: System UI's, on Android
    13, the whole wait, so the Allow button was never in the dump): it taps
    the other dialog's Wait, then Allow, and passes; a dialog that stays is
    answered at most ANR_TAPS times, and the probe's own never"""

    setUp = Device.setUp
    tearDown = Device.tearDown
    device = Device.device
    calls = Device.calls
    LOG = Device.LOG
    EVENTS = Device.EVENTS
    PERMISSION = DevicePermission.PERMISSION

    def run_probe(self, wait_closes=True, package='com.android.systemui'):
        d = self.tmp.name
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0])
        for name, text in (('activities.txt', DevicePermission.ACTIVITIES),
                           ('probe.txt', DevicePermission.PROBE_IN_FRONT),
                           ('anr.xml', PermissionReaders.ANR_UI), ('ui.xml', DevicePermission.UI),
                           ('package.txt', DevicePermission.PACKAGE % 'false'),
                           ('package-after.txt', DevicePermission.PACKAGE % 'true')):
            with open(os.path.join(d, name), 'w') as f:
                f.write(text)
        # the other dialog has the focus, and is all a dump shows, until its
        # Wait is tapped (when it closes)
        window = ('[ -f "%s/answered" ] || printf "  mCurrentFocus=Window{e076711 u0 Application Not Responding: '
                  '%s}\\n"' % (d, package))
        answer = 'touch "%s/answered"' % d if wait_closes else 'true'
        cases = ('  "shell dumpsys activity activities")\n'
                 '    if [ -f "%(d)s/allowed" ]; then cat "%(d)s/probe.txt"; else cat "%(d)s/activities.txt"; fi ;;\n'
                 '  "shell uiautomator dump /sdcard/oxt-ui.xml") true ;;\n'
                 '  "shell cat /sdcard/oxt-ui.xml")\n'
                 '    if [ -f "%(d)s/answered" ]; then cat "%(d)s/ui.xml"; else cat "%(d)s/anr.xml"; fi ;;\n'
                 '  "shell input tap 540 1280") %(answer)s ;;\n'
                 '  "shell input tap 540 1490") touch "%(d)s/allowed" ;;\n'
                 '  "shell dumpsys package org.openxtalk.check.androidprobe")\n'
                 '    if [ -f "%(d)s/allowed" ]; then cat "%(d)s/package-after.txt"; '
                 'else cat "%(d)s/package.txt"; fi ;;\n' % {'d': d, 'answer': answer})
        status, out = self.device('echo 3475', timeout='20', cases=cases, window=window,
                                  argv=('--allow', self.PERMISSION))
        return status, out, [c for c in self.calls() if c.startswith('shell input')]

    def test_wait_then_allow(self):
        status, out, taps = self.run_probe()
        self.assertEqual(status, 0, out)
        self.assertEqual(taps, ['shell input tap 540 1280', 'shell input tap 540 1490'])
        self.assertIn("  com.android.systemui isn't responding, its dialog in front of the probe: tapped Wait at "
                      "540,1280", out)
        self.assertIn('tapped Allow at 540,1490', out)
        self.assertIn('Android device: passed', out)

    def test_a_dialog_that_stays_is_answered_three_times(self):
        status, out, taps = self.run_probe(wait_closes=False)
        self.assertEqual(status, 1, out)
        self.assertEqual(taps, ['shell input tap 540 1280'] * ac.ANR_TAPS)
        self.assertIn('dialog had no Allow button to tap', out)

    def test_the_probes_own_is_not_answered(self):
        status, out, taps = self.run_probe(package=ac.IDENTIFIER)
        self.assertEqual(status, 1, out)
        self.assertEqual(taps, [])


@unittest.skipIf(os.name == 'nt', 'the stand-in adb and JDK are scripts')
class DeviceBundle(unittest.TestCase):
    """device with an App Bundle, a stand-in adb and a stand-in JDK whose
    java runs a stand-in bundletool: it is installed as Google Play
    installs it (bundletool's split APKs for the device, signed with a key
    made here), and must be installed as more than one APK"""

    PM_PATH = ('package:/data/app/~~a1/org.openxtalk.check.androidprobe-b2/base.apk\n'
               'package:/data/app/~~a1/org.openxtalk.check.androidprobe-b2/split_config.x86_64.apk\n')

    def setUp(self):
        Device.setUp(self)
        d = self.tmp.name
        self.apk = os.path.join(d, 'bundle.aab')
        with zipfile.ZipFile(self.apk, 'w') as z:
            z.writestr('BundleConfig.pb', BundleReaders.CONFIG)
            z.writestr('base/lib/x86_64/librevandroid.so', b'')
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0])
        with open(os.path.join(d, 'pm.txt'), 'w') as f:
            f.write(self.PM_PATH)
        self.jdk = os.path.join(d, 'jdk')
        os.makedirs(os.path.join(self.jdk, 'bin'))
        self.jar = os.path.join(d, 'bundletool.jar')
        with open(self.jar, 'wb') as f:
            f.write(b'')
        # java: the stand-in bundletool, saying each call; build-apks makes
        # a .apks with two of the device's APKs, unless told to fail
        with open(os.path.join(self.jdk, 'bin', 'java'), 'w') as f:
            f.write('#!%s\n'
                    'import os, sys, zipfile\n'
                    'd = %r\n'
                    'args = sys.argv[1:]\n'
                    'with open(os.path.join(d, "java-calls"), "a") as f:\n'
                    '    f.write(" ".join(args) + "\\n")\n'
                    'fail = open(os.path.join(d, "fail")).read() if os.path.exists(os.path.join(d, "fail")) else ""\n'
                    'if args[2] == "build-apks":\n'
                    '    if fail == "build":\n'
                    '        print("[BT:1.18.3] Error: no connected device matches"); sys.exit(1)\n'
                    '    with zipfile.ZipFile(args[args.index("--output") + 1], "w") as z:\n'
                    '        z.writestr("toc.pb", b"")\n'
                    '        z.writestr("splits/base-master.apk", b"m")\n'
                    '        z.writestr("splits/base-x86_64.apk", b"x")\n'
                    'elif args[2] == "install-apks":\n'
                    '    if fail == "install":\n'
                    '        print("[BT:1.18.3] Error: INSTALL_FAILED_NO_MATCHING_ABIS"); sys.exit(1)\n'
                    'else:\n'
                    '    sys.exit(2)\n' % (sys.executable, d))
        # keytool: makes the keystore it is asked for
        with open(os.path.join(self.jdk, 'bin', 'keytool'), 'w') as f:
            f.write('#!%s\n'
                    'import sys\n'
                    'open(sys.argv[sys.argv.index("-keystore") + 1], "w").write("ks")\n' % sys.executable)
        for tool in ('java', 'keytool'):
            os.chmod(os.path.join(self.jdk, 'bin', tool), 0o755)

    tearDown = Device.tearDown
    device = Device.device
    LOG = Device.LOG
    EVENTS = Device.EVENTS

    def run_bundle(self, argv=None, fail=''):
        d = self.tmp.name
        if fail:
            with open(os.path.join(d, 'fail'), 'w') as f:
                f.write(fail)
        cases = ('  "shell pm path %s") cat "%s/pm.txt" ;;\n' % (ac.IDENTIFIER, d))
        status, out = self.device('echo 3475', cases=cases,
                                  argv=['--bundletool', self.jar, '--jdk', self.jdk] if argv is None else argv)
        try:
            with open(os.path.join(d, 'java-calls')) as f:
                calls = [x.split(' ') for x in f.read().splitlines()]
        except FileNotFoundError:
            calls = []
        return status, out, calls

    def test_installed_as_split_apks(self):
        status, out, calls = self.run_bundle()
        self.assertEqual(status, 0, out)
        adb = os.path.join(self.tmp.name, 'platform-tools', 'adb')
        self.assertEqual(len(calls), 2, calls)
        build, install = calls
        self.assertEqual(build[:4], ['-jar', self.jar, 'build-apks', '--bundle'])
        self.assertEqual(build[4], self.apk)
        for flag, value in (('--connected-device', None), ('--device-id', 'emulator-5554'), ('--adb', adb),
                            ('--ks-pass', 'pass:' + ac.KEY_PASSWORD), ('--ks-key-alias', ac.KEY_ALIAS),
                            ('--key-pass', 'pass:' + ac.KEY_PASSWORD)):
            self.assertIn(flag, build)
            if value:
                self.assertEqual(build[build.index(flag) + 1], value, flag)
        apks = build[build.index('--output') + 1]
        self.assertEqual(install[:3], ['-jar', self.jar, 'install-apks'])
        self.assertEqual(install[install.index('--apks') + 1], apks)
        self.assertEqual(install[install.index('--device-id') + 1], 'emulator-5554')
        self.assertEqual(install[install.index('--adb') + 1], adb)
        # the key made for it, and its .apks, are gone
        self.assertFalse(os.path.exists(os.path.dirname(apks)))
        self.assertIn('bundletool made 2 APKs of bundle.aab for the device: base-master.apk, base-x86_64.apk', out)
        self.assertIn('Installed bundle.aab as 2 APKs: base.apk, split_config.x86_64.apk', out)
        self.assertNotIn('Installed bundle.aab\n', out)
        # and it starts, as a package does, once the install is taken
        self.assertLess(out.index('Installed bundle.aab as 2 APKs'), out.index('Before it starts: '))
        self.assertLess(out.index('Before it starts: '), out.index('Started: '))

    def test_one_apk_is_not_as_google_play_installs_it(self):
        with open(os.path.join(self.tmp.name, 'pm.txt'), 'w') as f:
            f.write(self.PM_PATH.splitlines()[0] + '\n')
        status, out, _ = self.run_bundle()
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: bundle.aab is installed as base.apk, not as split APKs as Google Play installs it',
                      out)

    def test_bundletool_refusing(self):
        status, out, calls = self.run_bundle(fail='build')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: bundletool makes no APKs of bundle.aab for emulator-5554: [BT:1.18.3] Error: no '
                      'connected device matches', out)
        self.assertEqual([c[2] for c in calls], ['build-apks'])
        status, out, calls = self.run_bundle(fail='install')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: bundle.aab does not install on emulator-5554: [BT:1.18.3] Error: '
                      'INSTALL_FAILED_NO_MATCHING_ABIS', out)

    def test_no_bundletool_or_java(self):
        status, out, calls = self.run_bundle(argv=['--jdk', self.jdk])
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: bundle.aab is an App Bundle, and there is no bundletool to install it '
                      '(--bundletool: not given)', out)
        self.assertEqual(calls, [])
        status, out, _ = self.run_bundle(argv=['--bundletool', self.jar + '.none', '--jdk', self.jdk])
        self.assertIn('(--bundletool: %s.none)' % self.jar, out)
        saved = ac.jdk_tool
        ac.jdk_tool = lambda jdk, name: None
        try:
            status, out, _ = self.run_bundle()
        finally:
            ac.jdk_tool = saved
        self.assertEqual(status, 1, out)
        self.assertIn("PROBLEM: bundle.aab is an App Bundle, and there is no java (the JDK's, --jdk) to run "
                      "bundletool", out)

    def test_its_libraries_are_the_packages(self):
        # the crash lines read the bundle's files as the package's: with
        # librevsecurity.so in the base module, its loading failing is a
        # crash, not the expected line of a package without it
        status, out, _ = self.run_bundle()
        self.assertEqual(status, 0, out)
        self.assertIn('Expected (the package has no SSL library, and the engine runs on without it): '
                      'I/revandroid( 3475): java.lang.UnsatisfiedLinkError', out)
        with zipfile.ZipFile(self.apk, 'a') as z:
            z.writestr('base/lib/x86_64/librevsecurity.so', b'')
        status, out, _ = self.run_bundle()
        self.assertEqual(status, 1, out)
        self.assertNotIn('Expected (', out)
        self.assertIn('librevsecurity.so', out[out.index('PROBLEM'):])


class Overlay(unittest.TestCase):
    """overlay puts this checkout's builder over a release's, and with
    --classes a Java layer over the release's Runtime/Android/Classes"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'release')
        for rel in ac.OVERLAY:
            path = os.path.join(self.root, 'Tools', 'x', os.path.basename(rel))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write('old')
        self.classes = os.path.join(self.root, 'Runtime', 'Android', 'Classes')
        os.makedirs(os.path.dirname(self.classes))
        with open(self.classes, 'wb') as f:
            f.write(b'old jar')
        self.new = os.path.join(self.tmp.name, 'Classes')
        with open(self.new, 'wb') as f:
            f.write(b'new jar')

    def tearDown(self):
        self.tmp.cleanup()

    def overlay(self, classes=None):
        import argparse
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            problems = ac.overlay(argparse.Namespace(root=self.root, classes=classes, engine=None, beyond=None))
        return problems, out.getvalue()

    def jar(self):
        with open(self.classes, 'rb') as f:
            return f.read()

    def test_builder_only(self):
        problems, _ = self.overlay()
        self.assertEqual(problems, [])
        self.assertEqual(self.jar(), b'old jar')
        for rel in ac.OVERLAY:
            with open(os.path.join(self.root, 'Tools', 'x', os.path.basename(rel)), encoding='utf-8') as f:
                self.assertEqual(f.read(), read(*rel.split('/')))

    def test_classes(self):
        problems, out = self.overlay(self.new)
        self.assertEqual(problems, [])
        self.assertEqual(self.jar(), b'new jar')
        self.assertIn('-> %s' % os.path.join('Runtime', 'Android', 'Classes'), out)

    def test_another_file_named_classes_is_left_alone(self):
        other = os.path.join(self.root, 'Runtime', 'Other', 'Classes')
        os.makedirs(os.path.dirname(other))
        with open(other, 'wb') as f:
            f.write(b'other')
        problems, _ = self.overlay(self.new)
        self.assertEqual(problems, [])
        self.assertEqual(self.jar(), b'new jar')
        with open(other, 'rb') as f:
            self.assertEqual(f.read(), b'other')

    def test_two_java_layers_is_a_problem(self):
        second = os.path.join(self.root, 'more', 'Runtime', 'Android', 'Classes')
        os.makedirs(os.path.dirname(second))
        with open(second, 'wb') as f:
            f.write(b'second')
        problems, _ = self.overlay(self.new)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('2 files Runtime/Android/Classes, not one', problems[0])
        self.assertEqual(self.jar(), b'old jar')

    def test_no_java_layer_is_a_problem(self):
        os.remove(self.classes)
        problems, _ = self.overlay(self.new)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('0 files Runtime/Android/Classes, not one', problems[0])


def text_elf(code, project=b'#!project'):
    """A 64-bit ELF file with sections only: .text (CODE) and .project
    (PROJECT) after it, as an engine library's code and the stack the
    builder's deploy writes into it"""
    names = b'\0.text\0.project\0.shstrtab\0'
    text_at = 64
    project_at = text_at + len(code)
    names_at = project_at + len(project)
    shoff = (names_at + len(names) + 7) & ~7
    out = bytearray(shoff + 4 * 64)
    out[0:16] = b'\x7fELF' + bytes([2, 1, 1]) + b'\0' * 9
    struct.pack_into('<HHIQQQIHHHHHH', out, 16, 3, 62, 1, 0, 0, shoff, 0, 64, 56, 0, 64, 4, 3)
    out[text_at:project_at] = code
    out[project_at:names_at] = project
    out[names_at:names_at + len(names)] = names
    for i, (name, sh_type, at, size) in enumerate(((0, 0, 0, 0), (1, 1, text_at, len(code)),
                                                   (7, 1, project_at, len(project)),
                                                   (16, 3, names_at, len(names)))):
        struct.pack_into('<IIQQQQIIQQ', out, shoff + i * 64, name, sh_type, 0, at, at, size, 0, 0, 1, 0)
    return bytes(out)


class OverlayEngine(unittest.TestCase):
    """overlay --engine puts a runtime folder that build-android.sh wrote in
    place of the release's Runtime/Android: every architecture's engine and
    externals, and the files beside them, or nothing when one is missing"""

    def setUp(self):
        import android_engine as ae
        self.ae = ae
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'release')
        for rel in ac.OVERLAY:
            path = os.path.join(self.root, 'Tools', 'x', os.path.basename(rel))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write('old')
        self.android = os.path.join(self.root, 'Runtime', 'Android')
        self.engine = os.path.join(self.tmp.name, 'android-runtime')
        for folder, what in ((self.android, b'old'), (self.engine, b'new')):
            for rel in self.names():
                path = os.path.join(folder, rel)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'wb') as f:
                    f.write(what + b' ' + rel.encode())
        # build-android.sh's unstripped copies, which stay out
        os.makedirs(os.path.join(self.engine, 'debug', 'x86_64'))
        with open(os.path.join(self.engine, 'debug', 'x86_64', 'Standalone'), 'wb') as f:
            f.write(b'unstripped')

    def tearDown(self):
        self.tmp.cleanup()

    def names(self):
        out = list(self.ae.TOP_FILES)
        for abi in sorted(self.ae.ABIS):
            out += [abi + '/' + x for x in (self.ae.ENGINE,) + self.ae.EXTERNALS]
        return out

    def overlay(self):
        import argparse
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            problems = ac.overlay(argparse.Namespace(root=self.root, classes=None, engine=self.engine, beyond=None))
        return problems, out.getvalue()

    def release(self):
        out = {}
        for folder, _, names in os.walk(self.android):
            for n in names:
                with open(os.path.join(folder, n), 'rb') as f:
                    out[os.path.relpath(os.path.join(folder, n), self.android).replace(os.sep, '/')] = f.read()
        return out

    def test_every_file(self):
        problems, out = self.overlay()
        self.assertEqual(problems, [])
        files = self.release()
        self.assertEqual(sorted(files), sorted(self.names()))
        for rel, data in files.items():
            self.assertEqual(data, b'new ' + rel.encode(), rel)
        self.assertEqual(len(self.names()), 4 * 8 + 6)
        self.assertIn('-> %s' % os.path.join('Runtime', 'Android', 'x86_64', 'Standalone'), out)
        self.assertIn('-> %s' % os.path.join('Runtime', 'Android', 'Classes'), out)
        # and the builder too
        with open(os.path.join(self.root, 'Tools', 'x', os.path.basename(ac.OVERLAY[0])), encoding='utf-8') as f:
            self.assertEqual(f.read(), read(*ac.OVERLAY[0].split('/')))

    def test_a_missing_architecture_changes_nothing(self):
        shutil.rmtree(os.path.join(self.engine, 'armeabi-v7a'))
        problems, _ = self.overlay()
        self.assertEqual(len(problems), 8, problems)
        self.assertIn('%s has no armeabi-v7a/Standalone' % self.engine, problems)
        for rel, data in self.release().items():
            self.assertEqual(data, b'old ' + rel.encode(), rel)

    def test_a_missing_external_or_java_layer(self):
        os.remove(os.path.join(self.engine, 'x86', 'RevZip'))
        os.remove(os.path.join(self.engine, 'Classes'))
        problems, _ = self.overlay()
        self.assertEqual(problems, ['%s has no x86/RevZip' % self.engine, '%s has no Classes' % self.engine])
        self.assertEqual(self.release()['x86_64/Standalone'], b'old x86_64/Standalone')

    def test_the_release_without_an_architecture_or_file(self):
        shutil.rmtree(os.path.join(self.android, 'x86'))
        os.remove(os.path.join(self.android, 'arm64-v8a', 'RevPdfPrinter'))
        problems, _ = self.overlay()
        self.assertEqual(problems, [
            '%s has no x86 folder' % os.path.join('Runtime', 'Android'),
            '%s has no arm64-v8a/RevPdfPrinter to put it in place of' % os.path.join('Runtime', 'Android')])
        self.assertEqual(self.release()['arm64-v8a/Standalone'], b'old arm64-v8a/Standalone')

    def test_not_with_classes(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                ac.main(['overlay', '--root', self.root, '--engine', self.engine, '--classes', 'x'])

    def test_by_its_command_line(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ac.main(['overlay', '--root', self.root, '--engine', self.engine]), 0)
        self.assertEqual(self.release()['x86/Standalone'], b'new x86/Standalone')


class OverlayBeyond(unittest.TestCase):
    """overlay --beyond puts a runtime folder that build-android.sh wrote
    beside the release's Runtime/Android, as Runtime/Android/Beyond (where
    the builder takes it for a stack whose "android,engine" is "beyond"):
    every architecture's engine and externals, and the files beside them,
    the release's own runtime left as it was; or nothing when a file is
    missing or a Beyond folder is there already"""

    def setUp(self):
        import android_engine as ae
        self.ae = ae
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'release')
        for rel in ac.OVERLAY:
            path = os.path.join(self.root, 'Tools', 'x', os.path.basename(rel))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write('old')
        self.android = os.path.join(self.root, 'Runtime', 'Android')
        self.beyond = os.path.join(self.android, ac.BEYOND)
        self.engine = os.path.join(self.tmp.name, 'android-runtime')
        for folder, what in ((self.android, b'old'), (self.engine, b'new')):
            for rel in self.names():
                path = os.path.join(folder, rel)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'wb') as f:
                    f.write(what + b' ' + rel.encode())
        # build-android.sh's unstripped copies, which stay out
        os.makedirs(os.path.join(self.engine, 'debug', 'x86_64'))
        with open(os.path.join(self.engine, 'debug', 'x86_64', 'Standalone'), 'wb') as f:
            f.write(b'unstripped')

    def tearDown(self):
        self.tmp.cleanup()

    def names(self):
        out = list(self.ae.TOP_FILES)
        for abi in sorted(self.ae.ABIS):
            out += [abi + '/' + x for x in (self.ae.ENGINE,) + self.ae.EXTERNALS]
        return out

    def overlay(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            problems = ac.overlay(argparse.Namespace(root=self.root, classes=None, engine=None, beyond=self.engine))
        return problems, out.getvalue()

    def files(self, top):
        out = {}
        for folder, _, names in os.walk(top):
            for n in names:
                with open(os.path.join(folder, n), 'rb') as f:
                    out[os.path.relpath(os.path.join(folder, n), top).replace(os.sep, '/')] = f.read()
        return out

    def test_beside_the_release(self):
        problems, out = self.overlay()
        self.assertEqual(problems, [])
        # the release's runtime as it was, with the Beyond folder beside
        files = self.files(self.android)
        release = {k: v for k, v in files.items() if not k.startswith(ac.BEYOND + '/')}
        self.assertEqual(sorted(release), sorted(self.names()))
        for rel, data in release.items():
            self.assertEqual(data, b'old ' + rel.encode(), rel)
        # and in it, every file of the runtime built here, and only those
        beyond = self.files(self.beyond)
        self.assertEqual(sorted(beyond), sorted(self.names()))
        for rel, data in beyond.items():
            self.assertEqual(data, b'new ' + rel.encode(), rel)
        self.assertEqual(len(beyond), 4 * 8 + 6)
        self.assertIn('-> %s' % os.path.join('Runtime', 'Android', 'Beyond', 'x86_64', 'Standalone'), out)
        self.assertIn('-> %s' % os.path.join('Runtime', 'Android', 'Beyond', 'Classes'), out)
        # and the builder too
        with open(os.path.join(self.root, 'Tools', 'x', os.path.basename(ac.OVERLAY[0])), encoding='utf-8') as f:
            self.assertEqual(f.read(), read(*ac.OVERLAY[0].split('/')))

    def test_its_java_layer_is_not_a_second_one(self):
        # the release's Java layer is still the one Runtime/Android/Classes
        # (overlay finds it by that name): a second overlay is refused for
        # the Beyond folder, not for two Java layers
        self.assertEqual(self.overlay()[0], [])
        problems, _ = self.overlay()
        self.assertEqual(problems, ['%s is there already' % '/'.join(('Runtime', 'Android', ac.BEYOND))])

    def test_a_missing_architecture_or_file_changes_nothing(self):
        shutil.rmtree(os.path.join(self.engine, 'armeabi-v7a'))
        os.remove(os.path.join(self.engine, 'x86', 'RevZip'))
        os.remove(os.path.join(self.engine, 'Classes'))
        problems, _ = self.overlay()
        self.assertEqual(len(problems), 10, problems)
        for missing in ('armeabi-v7a/Standalone', 'armeabi-v7a/RevDb', 'x86/RevZip', 'Classes'):
            self.assertIn('%s has no %s' % (self.engine, missing), problems)
        self.assertFalse(os.path.exists(self.beyond))
        for rel, data in self.files(self.android).items():
            self.assertEqual(data, b'old ' + rel.encode(), rel)

    def test_a_beyond_folder_there_already(self):
        os.makedirs(self.beyond)
        with open(os.path.join(self.beyond, 'Classes'), 'wb') as f:
            f.write(b'someone else\'s')
        problems, _ = self.overlay()
        self.assertEqual(problems, ['%s is there already' % '/'.join(('Runtime', 'Android', ac.BEYOND))])
        self.assertEqual(self.files(self.beyond), {'Classes': b'someone else\'s'})

    def test_the_release_needs_no_architecture_of_its_own(self):
        # the runtime beside it is a whole one: the release's architectures
        # are its own business
        shutil.rmtree(os.path.join(self.android, 'x86'))
        problems, _ = self.overlay()
        self.assertEqual(problems, [])
        self.assertEqual(self.files(self.beyond)['x86/Standalone'], b'new x86/Standalone')
        self.assertFalse(os.path.exists(os.path.join(self.android, 'x86')))

    def test_one_engine_at_a_time(self):
        for other in (['--engine', self.engine], ['--classes', 'x']):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    ac.main(['overlay', '--root', self.root, '--beyond', self.engine] + other)
        self.assertFalse(os.path.exists(self.beyond))

    def test_by_its_command_line(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ac.main(['overlay', '--root', self.root, '--beyond', self.engine]), 0)
        self.assertEqual(self.files(self.beyond)['x86/Standalone'], b'new x86/Standalone')
        self.assertEqual(self.files(self.android)['x86/Standalone'], b'old x86/Standalone')
        # and a second time, it says why it stops
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertNotEqual(ac.main(['overlay', '--root', self.root, '--beyond', self.engine]), 0)


class VerifyEngine(unittest.TestCase):
    """verify --engine: each package's engine is the one built in the
    runtime folder (the same .text), whatever stack the builder wrote"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.engine = os.path.join(self.tmp.name, 'android-runtime')
        for abi in ('arm64-v8a', 'x86_64'):
            os.makedirs(os.path.join(self.engine, abi))
            with open(os.path.join(self.engine, abi, 'Standalone'), 'wb') as f:
                f.write(text_elf(b'code of ' + abi.encode(), b'#!project'))

    def tearDown(self):
        self.tmp.cleanup()

    def apk(self, libs):
        path = os.path.join(self.tmp.name, 'debug.apk')
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('classes.dex', b'dex')
            for name, data in libs:
                z.writestr(name, data)
        return path

    def test_the_engine_built_here(self):
        # the builder wrote a stack into it: .project differs, .text not
        apk = self.apk([('lib/%s/librevandroid.so' % abi, text_elf(b'code of ' + abi.encode(), b'#!stack' * 40))
                        for abi in ('arm64-v8a', 'x86_64')] + [('lib/x86_64/librevzip.so', b'external')])
        self.assertEqual(ac.verify_engine('debug', apk, self.engine),
                         ([], ['the engine built here (arm64-v8a, x86_64)']))

    def test_another_engine(self):
        apk = self.apk([('lib/arm64-v8a/librevandroid.so', text_elf(b'code of arm64-v8a')),
                        ('lib/x86_64/librevandroid.so', text_elf(b'LiveCode 9.6.3'))])
        problems, notes = ac.verify_engine('debug', apk, self.engine)
        self.assertEqual(problems, ['debug: lib/x86_64/librevandroid.so is not the engine built in %s (its code '
                                    'is not x86_64/Standalone\'s)' % self.engine])
        self.assertEqual(notes, [])

    def test_an_architecture_not_built(self):
        apk = self.apk([('lib/x86/librevandroid.so', text_elf(b'code'))])
        problems, _ = ac.verify_engine('debug', apk, self.engine)
        self.assertEqual(len(problems), 1, problems)
        self.assertTrue(problems[0].startswith('debug: lib/x86/librevandroid.so against %s: '
                                               % os.path.join(self.engine, 'x86', 'Standalone')), problems)

    def test_not_an_engine(self):
        apk = self.apk([('lib/x86_64/librevandroid.so', b'not ELF')])
        self.assertEqual(ac.verify_engine('debug', apk, self.engine)[0], [
            'debug: lib/x86_64/librevandroid.so against %s: not an ELF file'
            % os.path.join(self.engine, 'x86_64', 'Standalone')])

    def test_no_engine(self):
        apk = self.apk([('lib/x86_64/librevzip.so', b'external')])
        self.assertEqual(ac.verify_engine('debug', apk, self.engine),
                         (['debug has no engine (lib/<abi>/librevandroid.so)'], []))

    def test_engine_code(self):
        self.assertEqual(ac.engine_code(text_elf(b'abc', b'x' * 100)), b'abc')
        import android_engine as ae
        with self.assertRaises(ae.ElfError):
            ac.engine_code(text_elf(b'abc').replace(b'.text\0', b'.txet\0'))

    def test_verify_asks_it_with_engine(self):
        work = os.path.join(self.tmp.name, 'work')
        os.makedirs(os.path.join(work, 'out'))
        with open(os.path.join(work, ac.LOG_NAME), 'w') as f:
            f.write('')
        apk = self.apk([('lib/x86_64/librevandroid.so', text_elf(b'something else'))])
        shutil.copyfile(apk, os.path.join(work, 'out', 'debug.apk'))
        saved = ac.find_tools, ac.verify_apk
        ac.find_tools = lambda sdk: {}
        ac.verify_apk = lambda name, apk, spec, tools, warnings, target=None: ([], ['checked'])
        try:
            for extra, status in (((), 0), (('--engine', self.engine), 1)):
                out = io.StringIO()
                with contextlib.redirect_stdout(out):
                    self.assertEqual(ac.main(['verify', '--work', work, '--sdk', self.tmp.name, '--builds', 'debug']
                                             + list(extra)), status)
            self.assertIn('is not the engine built in', out.getvalue())
        finally:
            ac.find_tools, ac.verify_apk = saved


class Screen(unittest.TestCase):
    def test_screen_colours(self):
        rgba = bytes([1, 2, 3, 255]) * 3 + bytes([9, 9, 9, 255])
        self.assertEqual(ac.screen_colours(rgba, step=1), [((1, 2, 3), 0.75), ((9, 9, 9), 0.25)])
        self.assertEqual(ac.screen_colours(b''), [])

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

    def test_bars_drawn_over(self):
        # a 4x4 screen: green but for its first and last rows (the bars
        # drawn as before), all green (drawn under them), green to the top
        # (under the status bar alone), and a top row half green
        green, black = bytes(list(ac.RUN_COLOR) + [255]), bytes([0, 0, 0, 255])
        row = lambda c, n=4: c * n
        inside = row(black) + row(green) * 2 + row(black)
        self.assertEqual(ac.bars_drawn_over(inside, 4, 4), [])
        self.assertEqual(ac.bars_drawn_over(row(green) * 4, 4, 4), ['top 100%', 'bottom 100%'])
        self.assertEqual(ac.bars_drawn_over(row(green) * 3 + row(black), 4, 4), ['top 100%'])
        self.assertEqual(ac.bars_drawn_over(row(green, 2) + row(black, 2) + row(green) * 3, 4, 4),
                         ['top 50%', 'bottom 100%'])
        self.assertEqual(ac.bars_drawn_over(row(green, 1) + row(black, 3) + row(green) * 2 + row(black), 4, 4), [])
        self.assertEqual(ac.bars_drawn_over(b'', 0, 0), [])
        # a colour of one's own
        self.assertEqual(ac.bars_drawn_over(row(black) * 4, 4, 4, (0, 0, 0)), ['top 100%', 'bottom 100%'])
        self.assertAlmostEqual(ac.row_share(row(green, 3) + row(black, 1) + row(black), 4, 0, ac.RUN_COLOR), 0.75)
        self.assertEqual(ac.row_share(row(green, 3) + row(black, 1) + row(black), 4, 1, ac.RUN_COLOR), 0.0)

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
            'INFO bundletool /home/u/.oxt-beyond/cache/Android/bundletool-all-1.18.3.jar',
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
        self.assertEqual(r['bundletool'], '/home/u/.oxt-beyond/cache/Android/bundletool-all-1.18.3.jar')
        self.assertNotIn('bundletool', r['warnings'])
        # a path with spaces is the path's
        r = ac.ide_results(['INFO bundletool C:/Users/A B/AppData/x/bundletool-all-1.18.3.jar  '])
        self.assertEqual(r['bundletool'], 'C:/Users/A B/AppData/x/bundletool-all-1.18.3.jar')
        self.assertIsNone(ac.ide_results(['DONE'])['bundletool'])


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

    def with_trees(self, trees):
        """compare_apks with an aapt that answers trees[path of the apk]"""
        saved = ac.run

        def fake(cmd, timeout=300, check=False):
            self.assertEqual(cmd[1:3], ['dump', 'xmltree'])
            return 0, trees[cmd[3]]
        ac.run = fake
        self.addCleanup(setattr, ac, 'run', saved)

    PUSH_EXPORTED = AAPT1_TREE.replace(
        '        A: android:permission(0x01010006)="com.google.android.c2dm.permission.SEND" (Raw: "x")\n',
        '        A: android:exported(0x01010010)=(type 0x12)0xffffffff\n'
        '        A: android:permission(0x01010006)="com.google.android.c2dm.permission.SEND" (Raw: "x")\n')

    def test_the_change_against_a_release_without_it(self):
        # the released builder's manifest has no android:exported on the
        # push receiver, this one's says true: the expected difference
        self.assertNotEqual(self.PUSH_EXPORTED, AAPT1_TREE)
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'exported')] + self.BASE[1:])
        self.with_trees({old: AAPT1_TREE, new: self.PUSH_EXPORTED})
        problems, notes = ac.compare_apks('debug', old, new, aapt='aapt')
        self.assertEqual(problems, [])
        self.assertIn('manifest: - receiver PushReceiver: android:exported=(not set); '
                      '+ receiver PushReceiver: android:exported=true', notes)

    def test_a_release_that_carries_the_change(self):
        # 0.2.7-rc.6.16 and later: the released builder makes the same
        # manifest, which already says it; nothing is expected to differ
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', self.BASE)
        self.with_trees({old: self.PUSH_EXPORTED, new: self.PUSH_EXPORTED})
        problems, notes = ac.compare_apks('debug', old, new, aapt='aapt')
        self.assertEqual(problems, [])
        self.assertIn('manifest: the same, and the old one has receiver PushReceiver: android:exported=true already '
                      '(its builder carries the change)', notes)

    def test_the_same_manifest_without_the_change_is_a_problem(self):
        # neither builder says it: the change is gone
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', self.BASE)
        self.with_trees({old: AAPT1_TREE, new: AAPT1_TREE})
        problems, _ = ac.compare_apks('debug', old, new, aapt='aapt')
        self.assertEqual(problems, ["debug: the manifest is the same, and should have "
                                    "['receiver PushReceiver: android:exported=true']"])

    def test_against_a_release_that_carries_the_change_any_change_is_a_problem(self):
        # the release has the line already, so this builder must not change
        # the manifest's components at all
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'other')] + self.BASE[1:])
        changed = self.PUSH_EXPORTED.replace('"AppReceiver" (Raw: "AppReceiver")\n'
                                             '        A: android:exported(0x01010010)=(type 0x12)0x0',
                                             '"AppReceiver" (Raw: "AppReceiver")\n'
                                             '        A: android:exported(0x01010010)=(type 0x12)0xffffffff')
        self.assertNotEqual(changed, self.PUSH_EXPORTED)
        self.with_trees({old: self.PUSH_EXPORTED, new: changed})
        problems, _ = ac.compare_apks('debug', old, new, aapt='aapt')
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('debug: the manifest changed: - receiver AppReceiver: android:exported=false; '
                      '+ receiver AppReceiver: android:exported=true', problems[0])

    CONFIG = '        A: android:configChanges(0x0101001f)=(type 0x11)%s\n'

    def config_tree(self, value):
        return AAPT1_TREE.replace('".mblandroid" (Raw: ".mblandroid")\n',
                                  '".mblandroid" (Raw: ".mblandroid")\n' + self.CONFIG % value, 1)

    def test_config_changes_against_a_release_without_them(self):
        # the released builder's four (0x6a0), this one's sixteen: the
        # expected difference, in every build
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'config')] + self.BASE[1:])
        self.with_trees({old: self.config_tree('0x6a0'), new: self.config_tree('0x50006fff')})
        for build in ('release', 'unsigned', 'legacy'):
            problems, notes = ac.compare_apks(build, old, new, aapt='aapt')
            self.assertEqual(problems, [], build)
            self.assertIn('manifest: android:configChanges 0x50006fff, was 0x6a0', notes)

    def test_other_config_changes_are_a_problem(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'config')] + self.BASE[1:])
        # the density too (0x1000): the engine reads it as it starts
        self.with_trees({old: self.config_tree('0x6a0'), new: self.config_tree('0x50007fff')})
        problems, _ = ac.compare_apks('release', old, new, aapt='aapt')
        self.assertEqual(problems, ['release: android:configChanges is 0x50007fff in the new package (the old: '
                                    '0x6a0), not 0x50006fff'])

    def test_config_changes_and_another_change(self):
        # the expected value explains its own line, and no other
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'config')] + self.BASE[1:])
        other = self.config_tree('0x50006fff').replace('".mblandroidservice" (Raw: ".mblandroidservice")',
                                                       '".other" (Raw: ".other")')
        self.with_trees({old: self.config_tree('0x6a0'), new: other})
        problems, notes = ac.compare_apks('release', old, new, aapt='aapt')
        self.assertEqual(len(problems), 2, problems)
        self.assertIn('release: the manifest changed: - service .mblandroidservice', problems[0])
        self.assertIn('release: other manifest lines changed: - A: android:name(0x01010003)=".mblandroidservice"',
                      problems[1])
        self.assertNotIn('configChanges', problems[1])
        self.assertIn('manifest: android:configChanges 0x50006fff, was 0x6a0', notes)

    def test_config_changes_where_the_old_had_none(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'config')] + self.BASE[1:])
        self.with_trees({old: AAPT1_TREE, new: self.config_tree('0x50006fff')})
        problems, notes = ac.compare_apks('release', old, new, aapt='aapt')
        self.assertEqual(problems, [])
        self.assertIn('manifest: android:configChanges 0x50006fff, was not set', notes)

    def test_expected_manifest(self):
        self.assertEqual(ac.expected_manifest('debug', []), ['receiver PushReceiver: android:exported=true'])
        self.assertEqual(ac.expected_manifest('debug', ['receiver PushReceiver: android:exported=true']), [])
        self.assertEqual(ac.expected_manifest('release', []), [])

    def test_manifest_change_needs_aapt(self):
        old = self.apk('old.apk', self.BASE)
        new = self.apk('new.apk', [('AndroidManifest.xml', b'other')] + self.BASE[1:])
        problems, _ = ac.compare_apks('unsigned', old, new)
        self.assertEqual(problems, ['unsigned: the manifest differs (no aapt to say how)'])


class Relaunch(unittest.TestCase):
    """The engine runs once in a process: the manifest's configuration
    changes are the builder's, and the activity that starts the app again
    in a new process is declared, in a process of its own and not exported,
    where the package's Java layer has it, and only there; read from
    aapt's and aapt2's xmltree"""

    AAPT1 = AAPT1_TREE.replace(
        '".mblandroid" (Raw: ".mblandroid")\n',
        '".mblandroid" (Raw: ".mblandroid")\n'
        '        A: android:configChanges(0x0101001f)=(type 0x11)0x50006fff\n', 1) + (
        '      E: activity (line=9)\n'
        '        A: android:theme(0x01010000)=@0x01030010\n'
        '        A: android:name(0x01010003)="com.runrev.android.RelaunchActivity" (Raw: "com.runrev.android.Relau'
        'nchActivity")\n'
        '        A: android:exported(0x01010010)=(type 0x12)0x0\n'
        '        A: android:process(0x01010011)=":relaunch" (Raw: ":relaunch")\n'
        '        A: android:excludeFromRecents(0x01010017)=(type 0x12)0xffffffff\n'
        '        A: android:noHistory(0x0101022d)=(type 0x12)0xffffffff\n')
    NS = 'http://schemas.android.com/apk/res/android:'
    AAPT2 = AAPT2_TREE.replace(
        '".mblandroid" (Raw: ".mblandroid")\n',
        '".mblandroid" (Raw: ".mblandroid")\n'
        '        A: %sconfigChanges(0x0101001f)=0x50006fff\n' % NS, 1) + (
        '      E: activity (line=40)\n'
        '        A: %stheme(0x01010000)=@0x01030010\n'
        '        A: %sname(0x01010003)="com.runrev.android.RelaunchActivity" (Raw: "x")\n'
        '        A: %sexported(0x01010010)=false\n'
        '        A: %sprocess(0x01010011)=":relaunch" (Raw: ":relaunch")\n' % ((NS,) * 4))
    DEX = [b'dex\n035\x00 Lcom/runrev/android/LiveCodeActivity; Lcom/runrev/android/RelaunchActivity; ']
    OLD_DEX = [b'dex\n035\x00 Lcom/runrev/android/LiveCodeActivity; ']

    def test_manifest_value(self):
        self.assertEqual(ac.manifest_value('        A: android:configChanges(0x0101001f)=(type 0x11)0x6a0'),
                         ('configChanges', '0x6a0'))
        self.assertEqual(ac.manifest_value('  A: %sconfigChanges(0x0101001f)=0x50006fff' % self.NS),
                         ('configChanges', '0x50006fff'))
        self.assertIsNone(ac.manifest_value('        A: android:exported(0x01010010)=(type 0x12)0x0'))
        self.assertIsNone(ac.manifest_value('      E: activity (line=9)'))

    def test_manifest_element(self):
        want = {'theme': '@0x01030010', 'name': ac.RELAUNCH_ACTIVITY, 'exported': '0x0', 'process': ':relaunch',
                'excludeFromRecents': '0xffffffff', 'noHistory': '0xffffffff'}
        self.assertEqual(ac.manifest_element(self.AAPT1, 'activity', ac.RELAUNCH_ACTIVITY), want)
        self.assertEqual(ac.manifest_element(self.AAPT2, 'activity', ac.RELAUNCH_ACTIVITY),
                         {'theme': '@0x01030010', 'name': ac.RELAUNCH_ACTIVITY, 'exported': 'false',
                          'process': ':relaunch'})
        # an element before the last, without its children's attributes
        main = ac.manifest_element(self.AAPT1, 'activity', '.mblandroid')
        self.assertEqual(main, {'name': '.mblandroid', 'exported': '0xffffffff', 'configChanges': '0x50006fff'})
        self.assertIsNone(ac.manifest_element(AAPT1_TREE, 'activity', ac.RELAUNCH_ACTIVITY))
        self.assertIsNone(ac.manifest_element(self.AAPT1, 'service', ac.RELAUNCH_ACTIVITY))

    def test_declared_with_the_java_layer_that_has_it(self):
        self.assertEqual(ac.relaunch_problems('debug', self.AAPT1, self.DEX), [])
        self.assertEqual(ac.relaunch_problems('debug', self.AAPT2, self.DEX), [])
        # in the second dex of two
        self.assertEqual(ac.relaunch_problems('debug', self.AAPT1, self.OLD_DEX + self.DEX), [])

    def test_not_declared_with_the_java_layer_that_has_not(self):
        # the release's Java layer (LiveCode Community 9.6.3's): no activity
        old = self.AAPT1.split('      E: activity (line=9)\n        A: android:theme')[0]
        self.assertEqual(ac.relaunch_problems('debug', old, self.OLD_DEX), [])
        self.assertEqual(ac.relaunch_problems('debug', self.AAPT1, self.OLD_DEX), [
            'debug: the manifest declares %s, which its Java layer does not have' % ac.RELAUNCH_ACTIVITY])
        self.assertEqual(ac.relaunch_problems('debug', old, self.DEX), [
            'debug: its Java layer has %s, and the manifest does not declare it (the app would start its engine '
            'twice in a process)' % ac.RELAUNCH_ACTIVITY])

    def test_its_process_and_exported(self):
        shared = self.AAPT1.replace('        A: android:process(0x01010011)=":relaunch" (Raw: ":relaunch")\n', '')
        self.assertEqual(ac.relaunch_problems('debug', shared, self.DEX), [
            'debug: %s is not in a process of its own (android:process is not set)' % ac.RELAUNCH_ACTIVITY])
        exported = self.AAPT2.replace('exported(0x01010010)=false\n        A: %sprocess' % self.NS,
                                      'exported(0x01010010)=true\n        A: %sprocess' % self.NS)
        self.assertNotEqual(exported, self.AAPT2)
        self.assertEqual(ac.relaunch_problems('debug', exported, self.DEX), [
            'debug: %s does not say android:exported="false"' % ac.RELAUNCH_ACTIVITY])

    def test_the_config_changes(self):
        self.assertEqual(ac.EXPECTED_VALUES, {'configChanges': '0x50006fff'})
        # LiveCode's four, as the released builder had them
        self.assertEqual(int(ac.EXPECTED_VALUES['configChanges'], 16) & 0x6a0, 0x6a0)
        # not the density (0x1000)
        self.assertEqual(int(ac.EXPECTED_VALUES['configChanges'], 16) & 0x1000, 0)
        four = self.AAPT1.replace('(type 0x11)0x50006fff', '(type 0x11)0x6a0')
        self.assertEqual(ac.relaunch_problems('debug', four, self.DEX), [
            'debug: android:configChanges is 0x6a0, not 0x50006fff'])
        none = self.AAPT1.replace('        A: android:configChanges(0x0101001f)=(type 0x11)0x50006fff\n', '')
        self.assertEqual(ac.relaunch_problems('debug', none, self.DEX), [
            'debug: android:configChanges is not set, not 0x50006fff'])


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


class VerifyTarget(unittest.TestCase):
    """verify_apk with an aapt that answers a badging and a manifest: the
    API the package targets is the one asked for (33 unless --target says
    otherwise), and at 36, and only there, the manifest keeps the stack's
    orientation on large screens"""

    SPEC = VerifyWithoutTools.SPEC
    # a manifest without the push receiver (SPEC has no push)
    TREE = AAPT1_TREE.split('      E: receiver (line=9)\n        A: android:name(0x01010003)="PushReceiver"')[0] + \
        '      E: service (line=9)\n        A: android:name(0x01010003)=".mblandroidservice" (Raw: "x")\n'
    # the builder's configuration changes (EXPECTED_VALUES)
    TREE = TREE.replace('".mblandroid" (Raw: ".mblandroid")\n',
                        '".mblandroid" (Raw: ".mblandroid")\n'
                        '        A: android:configChanges(0x0101001f)=(type 0x11)0x50006fff\n', 1)
    PROPERTY = ('      E: property (line=11)\n'
                '        A: android:name(0x01010003)="%s" (Raw: "x")\n'
                '        A: android:value(0x01010024)=(type 0x12)%%s\n' % ac.LARGE_SCREEN_PROPERTY)

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.apk = os.path.join(self.dir, 'p.apk')
        with open(self.apk, 'wb') as f:
            f.write(zip_bytes([('AndroidManifest.xml', b'm'), ('classes.dex', b'd'), ('resources.arsc', b'r'),
                               ('lib/arm64-v8a/librevandroid.so', elf64([0x10000]))], stored=('resources.arsc',)))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.dir, ignore_errors=True)

    def check(self, targets, value=None, *target):
        """verify_apk of a package that targets targets, with the large
        screen property of value (none when None)"""
        tree = self.TREE + (self.PROPERTY % value if value is not None else '')
        saved = ac.run

        def fake(cmd, timeout=300, check=False):
            if cmd[1:3] == ['dump', 'badging']:
                return 0, ("package: name='%s' versionCode='1'\nsdkVersion:'21'\ntargetSdkVersion:'%s'\n"
                           % (ac.IDENTIFIER, targets))
            self.assertEqual(cmd[1:3], ['dump', 'xmltree'])
            return 0, tree
        ac.run = fake
        try:
            return ac.verify_apk('unsigned', self.apk, self.SPEC, {'aapt': 'aapt'}, {}, *target)[0]
        finally:
            ac.run = saved

    def test_33_as_before(self):
        self.assertEqual(ac.TARGET_SDK, '33')
        self.assertEqual(self.check('33'), [])
        self.assertEqual(self.check('33', None, '33'), [])
        self.assertEqual(self.check('36'), ['unsigned does not target API 33'])

    def test_36_with_the_property(self):
        self.assertEqual(ac.NEWEST_TARGET_SDK, '36')
        self.assertEqual(self.check('36', '0xffffffff', '36'), [])
        self.assertEqual(self.check('33', None, '36'), [
            'unsigned does not target API 36',
            "unsigned targets API 36, and its manifest does not keep the stack's orientation on large screens "
            "(%s is not there)" % ac.LARGE_SCREEN_PROPERTY])

    def test_36_without_the_property_or_false(self):
        self.assertEqual(self.check('36', None, '36'), [
            "unsigned targets API 36, and its manifest does not keep the stack's orientation on large screens "
            "(%s is not there)" % ac.LARGE_SCREEN_PROPERTY])
        self.assertEqual(self.check('36', '0x0', '36'), [
            "unsigned targets API 36, and its manifest does not keep the stack's orientation on large screens "
            "(%s is 0x0)" % ac.LARGE_SCREEN_PROPERTY])

    def test_the_relaunch_activity(self):
        # verify_apk asks relaunch_problems, with the package's dex: this
        # one's Java layer has no RelaunchActivity, so none may be declared
        saved = self.TREE
        try:
            self.TREE = saved.replace('(type 0x11)0x50006fff', '(type 0x11)0x6a0')
            self.assertEqual(self.check('33'), ['unsigned: android:configChanges is 0x6a0, not 0x50006fff'])
            self.TREE = saved + Relaunch.AAPT1.split('".mblandroidservice" (Raw: ".mblandroidservice")\n')[1]
            self.assertEqual(self.check('33'), [
                'unsigned: the manifest declares %s, which its Java layer does not have' % ac.RELAUNCH_ACTIVITY])
        finally:
            self.TREE = saved

    def test_the_property_below_36(self):
        self.assertEqual(self.check('33', '0xffffffff'), [
            'unsigned: the manifest has %s, which is for a package that targets API 36 or newer (this one must '
            'target 33)' % ac.LARGE_SCREEN_PROPERTY])

    def test_verify_takes_the_target(self):
        # verify's --target reaches verify_apk; without it, 33
        work = os.path.join(self.dir, 'work')
        os.makedirs(os.path.join(work, 'out'))
        with open(os.path.join(work, ac.LOG_NAME), 'w') as f:
            f.write('')
        with open(os.path.join(work, 'out', 'debug.apk'), 'wb') as f:
            f.write(b'apk')
        seen = []
        saved = ac.find_tools, ac.verify_apk
        ac.find_tools = lambda sdk: {}
        ac.verify_apk = lambda name, apk, spec, tools, warnings, target=None: (seen.append(target) or ([], []))
        try:
            for extra, want in (((), '33'), (('--target', '36'), '36')):
                with contextlib.redirect_stdout(io.StringIO()):
                    status = ac.main(['verify', '--work', work, '--sdk', self.dir, '--builds', 'debug'] + list(extra))
                self.assertEqual(status, 0)
                self.assertEqual(seen.pop(), want)
        finally:
            ac.find_tools, ac.verify_apk = saved


class VerifyTargetFor(unittest.TestCase):
    """verify --target-for: the packages must target the API the builder
    picks for an installed IDE's runtime, as androidTargetAPI does for a
    stack that pins none: the newest when the runtime's Java layer has the
    classes the builder looks for, 33 when it has not (9.6.3's)"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'OXT-Beyond-0.2.7-rc.6.18')
        self.classes = os.path.join(self.root, 'Runtime', 'Android', 'Classes')
        os.makedirs(os.path.dirname(self.classes))

    def tearDown(self):
        self.tmp.cleanup()

    def layer(self, names, path=None):
        # a jar holding NAMES, as a Java layer does
        with zipfile.ZipFile(path or self.classes, 'w') as z:
            for n in names:
                z.writestr(n, b'class')

    def test_the_builders_classes(self):
        # the classes the builder looks for (kJavaLayerReady), in its order
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        names = re.search(r'^constant kJavaLayerReady = "([^"]+)"$', builder, re.M).group(1)
        self.assertEqual(tuple(names.split(',')), ac.JAVA_LAYER_READY)

    def test_a_ready_layer_targets_the_newest(self):
        self.layer(('com/runrev/android/LiveCodeActivity.class',) + ac.JAVA_LAYER_READY)
        target, why, problems = ac.builder_target(self.root)
        self.assertEqual((target, problems), (ac.NEWEST_TARGET_SDK, []))
        self.assertIn('LiveCodeActivity$BackCallback.class', why)

    def test_9_6_3s_layer_targets_33(self):
        # LiveCode 9.6.3's has neither class; one alone is not enough
        self.layer(('com/runrev/android/LiveCodeActivity.class',))
        target, why, problems = ac.builder_target(self.root)
        self.assertEqual((target, problems), (ac.TARGET_SDK, []))
        self.assertEqual(why, '%s has no %s' % (self.classes, ', '.join(ac.JAVA_LAYER_READY)))
        self.layer(('com/runrev/android/LiveCodeActivity.class', ac.JAVA_LAYER_READY[0]))
        target, why, problems = ac.builder_target(self.root)
        self.assertEqual((target, problems), (ac.TARGET_SDK, []))
        self.assertEqual(why, '%s has no %s' % (self.classes, ac.JAVA_LAYER_READY[1]))

    def test_one_java_layer_or_none(self):
        # no Classes, or two Runtime/Android/Classes, is a problem; a
        # Classes elsewhere (a runtime of its own beside, such as
        # Runtime/Android/Beyond) is not the release's
        other = os.path.join(self.root, 'Runtime', 'Android', 'Beyond', 'Classes')
        os.makedirs(os.path.dirname(other))
        self.layer(ac.JAVA_LAYER_READY, other)
        self.assertEqual(ac.builder_target(self.root)[2],
                         ['%s: 0 files Runtime/Android/Classes, not one' % self.root])
        self.layer(ac.JAVA_LAYER_READY)
        self.assertEqual(ac.builder_target(self.root)[0], ac.NEWEST_TARGET_SDK)
        second = os.path.join(self.root, 'Copy', 'Runtime', 'Android', 'Classes')
        os.makedirs(os.path.dirname(second))
        self.layer((), second)
        self.assertEqual(ac.builder_target(self.root)[2],
                         ['%s: 2 files Runtime/Android/Classes, not one' % self.root])

    def verify(self, *extra):
        work = os.path.join(self.tmp.name, 'work')
        os.makedirs(os.path.join(work, 'out'), exist_ok=True)
        with open(os.path.join(work, ac.LOG_NAME), 'w') as f:
            f.write('')
        with open(os.path.join(work, 'out', 'debug.apk'), 'wb') as f:
            f.write(b'apk')
        seen = []
        saved = ac.find_tools, ac.verify_apk
        ac.find_tools = lambda sdk: {}
        ac.verify_apk = lambda name, apk, spec, tools, warnings, target=None: (seen.append(target) or ([], []))
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                status = ac.main(['verify', '--work', work, '--sdk', self.tmp.name, '--builds', 'debug']
                                 + list(extra))
        finally:
            ac.find_tools, ac.verify_apk = saved
        return status, seen, out.getvalue()

    def test_verify_takes_the_runtimes_target(self):
        self.layer(ac.JAVA_LAYER_READY)
        status, seen, out = self.verify('--target-for', self.root)
        self.assertEqual((status, seen), (0, [ac.NEWEST_TARGET_SDK]))
        self.assertIn('The builder targets API %s with that runtime' % ac.NEWEST_TARGET_SDK, out)
        self.layer(())
        status, seen, out = self.verify('--target-for', self.root)
        self.assertEqual((status, seen), (0, [ac.TARGET_SDK]))
        self.assertIn('The builder targets API %s with that runtime' % ac.TARGET_SDK, out)

    def test_verify_without_a_java_layer_checks_nothing(self):
        # the problem, and no package checked against a target guessed
        status, seen, out = self.verify('--target-for', self.root)
        self.assertEqual((status, seen), (1, []))
        self.assertIn('0 files Runtime/Android/Classes, not one', out)

    def test_one_or_the_other(self):
        self.layer(ac.JAVA_LAYER_READY)
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self.verify('--target', '36', '--target-for', self.root)


class VerifyBundle(unittest.TestCase):
    """verify_bundle on made-up packages and App Bundles, with stand-in
    answers from jarsigner, keytool and bundletool: what the bundle holds
    against its package, bundletool's settings, the signature and the
    manifest"""

    SPEC = ac.BUILDS['bundle']
    LIB = elf64([0x4000])
    # the package's files: (name, bytes)
    APK = [('AndroidManifest.xml', b'binary manifest'), ('classes.dex', b'dex'), ('resources.arsc', b'arsc'),
           ('res/layout/livecode_inputcontrol.xml', b'binary layout'), ('res/drawable/notify_icon.png', b'png'),
           ('assets/oxt-probe.txt', b'OXT-Beyond probe copy file'),
           ('lib/arm64-v8a/librevandroid.so', LIB), ('lib/x86_64/librevandroid.so', LIB),
           ('lib/1.jar', b'jar'), ('META-INF/OXTCHECK.SF', b'sf'), ('META-INF/OXTCHECK.RSA', b'rsa'),
           ('META-INF/MANIFEST.MF', b'mf')]
    # its App Bundle: the converted files differ, the rest are the same
    AAB = [('BundleConfig.pb', BundleReaders.CONFIG), ('base/manifest/AndroidManifest.xml', b'proto manifest'),
           ('base/dex/classes.dex', b'dex'), ('base/resources.pb', b'proto table'),
           ('base/res/layout/livecode_inputcontrol.xml', b'proto layout'),
           ('base/res/drawable/notify_icon.png', b'png'), ('base/assets/oxt-probe.txt', b'OXT-Beyond probe copy file'),
           ('base/lib/arm64-v8a/librevandroid.so', LIB), ('base/lib/x86_64/librevandroid.so', LIB),
           ('base/assets.pb', b''), ('base/native.pb', b''),
           ('META-INF/MANIFEST.MF', b'mf'), ('META-INF/OXTCHECK.SF', b'sf'), ('META-INF/OXTCHECK.RSA', b'rsa')]
    MANIFEST = ('<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:versionCode="1" '
                'package="%s">\n  <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="%%s"/>\n'
                '  <application android:label="Android Probe">\n%%s  </application>\n</manifest>\n' % ac.IDENTIFIER)
    PROPERTY = '    <property android:name="%s" android:value="%%s"/>\n' % ac.LARGE_SCREEN_PROPERTY
    TOOLS = {'jarsigner': 'jarsigner', 'keytool': 'keytool', 'java': 'java', 'bundletool': 'bundletool.jar'}

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.answers = {'verify': (0, 'jar verified.\n\nThis jar contains entries whose signer certificate is '
                                      'self-signed.\n'),
                        'owner': ac.KEY_DNAME, 'validate': (0, ''), 'manifest': (0, self.MANIFEST % (
                            '36', self.PROPERTY % 'true'))}
        self.calls = []

    def tearDown(self):
        import shutil
        shutil.rmtree(self.dir, ignore_errors=True)

    def check(self, aab=None, apk=None, spec=None, tools=None, target='36'):
        """verify_bundle's problems and notes"""
        paths = []
        for name, entries in (('bundle.apk', apk or self.APK), ('bundle.aab', self.AAB if aab is None else aab)):
            paths.append(os.path.join(self.dir, name))
            with open(paths[-1], 'wb') as f:
                f.write(zip_bytes(entries))
        saved = ac.run

        def fake(cmd, timeout=300, check=False):
            self.calls.append(cmd)
            if cmd[0] == 'jarsigner':
                self.assertEqual(cmd[1:], ['-J-Duser.language=en', '-verify', paths[1]])
                return self.answers['verify']
            if cmd[0] == 'keytool':
                self.assertEqual(cmd[1:], ['-J-Duser.language=en', '-printcert', '-jarfile', paths[1]])
                if self.answers['owner'] is None:
                    return 0, 'Not a signed jar file\n'
                return 0, 'Signer #1:\n\nCertificate #1:\nOwner: %s\nIssuer: x\n' % self.answers['owner']
            self.assertEqual(cmd[:3], ['java', '-jar', 'bundletool.jar'])
            if cmd[3] == 'validate':
                self.assertEqual(cmd[4:], ['--bundle', paths[1]])
                return self.answers['validate']
            self.assertEqual(cmd[3:], ['dump', 'manifest', '--bundle', paths[1]])
            return self.answers['manifest']
        ac.run = fake
        try:
            return ac.verify_bundle('bundle', paths[1], paths[0], spec or self.SPEC,
                                    self.TOOLS if tools is None else tools, target)
        finally:
            ac.run = saved

    def without(self, name):
        return [x for x in self.AAB if x[0] != name]

    def test_good(self):
        problems, notes = self.check()
        self.assertEqual(problems, [])
        self.assertEqual(notes, [
            'it holds the 8 files of bundle.apk',
            'bundletool 1.18.3, native libraries compressed, assets stored',
            'signed by %s (jarsigner verifies it)' % ac.KEY_DNAME,
            'bundletool takes it; its manifest names the package and targets API 36'])

    def test_files_missing_differing_and_extra(self):
        aab = [x for x in self.AAB if x[0] != 'base/assets/oxt-probe.txt']
        aab = [(n, b'other' if n == 'base/lib/x86_64/librevandroid.so' else d) for n, d in aab]
        aab += [('base/root/extra.txt', b'x'), ('base/lib/1.jar', b'jar')]
        problems, notes = self.check(aab)
        self.assertEqual(problems, [
            'bundle.aab does not hold these files of bundle.apk: base/assets/oxt-probe.txt',
            "bundle.aab: these differ from bundle.apk's: base/lib/x86_64/librevandroid.so",
            "bundle.aab holds files bundle.apk does not: base/lib/1.jar, base/root/extra.txt"])
        self.assertNotIn('it holds', ' '.join(notes))

    def test_converted_files_may_differ(self):
        # the manifest, the table and the resources' XML are aapt2's
        # protocol buffers in the bundle; a picture is not converted
        aab = [(n, b'changed' if n == 'base/res/drawable/notify_icon.png' else d) for n, d in self.AAB]
        problems, _ = self.check(aab)
        self.assertEqual(problems, ["bundle.aab: these differ from bundle.apk's: base/res/drawable/notify_icon.png"])

    def test_required(self):
        for name in ('BundleConfig.pb', 'base/manifest/AndroidManifest.xml', 'base/resources.pb',
                     'base/dex/classes.dex'):
            problems, _ = self.check(self.without(name))
            self.assertIn('bundle.aab has no %s' % name, problems)

    def test_abis(self):
        aab = self.without('base/lib/x86_64/librevandroid.so')
        apk = [x for x in self.APK if x[0] != 'lib/x86_64/librevandroid.so']
        problems, _ = self.check(aab, apk)
        self.assertEqual(problems, ['bundle.aab has native code for arm64-v8a, not arm64-v8a, x86_64'])

    def config(self, data):
        return [(n, data if n == 'BundleConfig.pb' else d) for n, d in self.AAB]

    def test_native_libraries_uncompressed(self):
        problems, notes = self.check(self.config(BundleReaders.CONFIG.replace(b'\x12\x02\x12\x00',
                                                                              b'\x12\x04\x12\x02\x08\x01')))
        self.assertEqual(problems, [
            "bundle.aab: the device's packages would hold the native libraries uncompressed, where Android does "
            "not extract them and the engine does not load them (BundleConfig.pb: uncompressNativeLibraries is "
            "enabled)"])
        self.assertNotIn('native libraries compressed', ' '.join(notes))
        problems, _ = self.check(self.config(BundleReaders.CONFIG.replace(b'\x12\x02\x12\x00', b'')))
        self.assertIn('uncompressNativeLibraries is not said', problems[0])

    def test_assets_compressed(self):
        problems, _ = self.check(self.config(BundleReaders.CONFIG.replace(b'\x1a\x0b\x0a\x09assets/**', b'')))
        self.assertEqual(problems, [
            "bundle.aab: the device's packages would compress the assets, which the engine opens at their place in "
            "the package (BundleConfig.pb: uncompressedGlob not said)"])
        problems, _ = self.check(self.config(BundleReaders.CONFIG.replace(b'\x1a\x0b\x0a\x09assets/**',
                                                                          b'\x1a\x0b\x0a\x09assets/*.')))
        self.assertIn("uncompressedGlob ['assets/*.']", problems[0])

    def test_another_bundletool(self):
        problems, _ = self.check(self.config(BundleReaders.CONFIG.replace(b'1.18.3', b'1.17.0')))
        self.assertEqual(problems, ['bundle.aab was made by bundletool 1.17.0, not 1.18.3'])

    def test_not_signed_or_by_another(self):
        unsigned = [x for x in self.AAB if not x[0].startswith('META-INF/')]
        self.answers['verify'] = (0, 'jar is unsigned.\n')
        self.answers['owner'] = None
        problems, _ = self.check(unsigned)
        self.assertEqual(problems, ['bundle.aab is not signed',
                                    'bundle.aab: jarsigner does not verify it: jar is unsigned.',
                                    'bundle.aab is signed by None, not %s' % ac.KEY_DNAME])
        self.answers['verify'] = (0, 'jar verified.\n')
        self.answers['owner'] = 'CN=Android Debug, O=Android, C=US'
        problems, notes = self.check()
        self.assertEqual(problems, ['bundle.aab is signed by CN=Android Debug, O=Android, C=US, not %s'
                                    % ac.KEY_DNAME])
        self.assertNotIn('signed by', ' '.join(notes))
        # jarsigner's status alone is not enough, and its words alone not
        self.answers['owner'] = ac.KEY_DNAME
        self.answers['verify'] = (1, 'jar verified.\n')
        self.assertIn('bundle.aab: jarsigner does not verify it: jar verified.', self.check()[0])

    def test_unsigned_build_and_no_jdk(self):
        spec = dict(self.SPEC, signer=None)
        problems, _ = self.check(spec=spec)
        self.assertEqual(problems, ['bundle.aab is signed, and should not be (META-INF/OXTCHECK.RSA, '
                                    'META-INF/OXTCHECK.SF)'])
        unsigned = [x for x in self.AAB if not x[0].startswith('META-INF/')]
        self.assertEqual(self.check(unsigned, spec=spec)[0], [])
        problems, _ = self.check(tools={'java': 'java', 'bundletool': 'bundletool.jar'})
        self.assertEqual(problems, ["bundle.aab: no jarsigner and keytool (the JDK's, --jdk) to check its signature"])

    def test_the_manifest(self):
        self.answers['manifest'] = (0, self.MANIFEST % ('33', ''))
        self.assertEqual(self.check(target='33')[0], [])
        problems, notes = self.check()
        self.assertEqual(problems, [
            'bundle.aab does not target API 36',
            "bundle.aab targets API 36, and its manifest does not keep the stack's orientation on large screens"])
        self.assertNotIn('bundletool takes it', ' '.join(notes))
        self.answers['manifest'] = (0, self.MANIFEST % ('36', self.PROPERTY % 'false'))
        self.assertEqual(self.check()[0], [
            "bundle.aab targets API 36, and its manifest does not keep the stack's orientation on large screens"])
        self.answers['manifest'] = (0, self.MANIFEST % ('33', self.PROPERTY % 'true'))
        self.assertEqual(self.check(target='33')[0], [
            'bundle.aab: the manifest has %s, which is for API 36 and newer' % ac.LARGE_SCREEN_PROPERTY])
        self.answers['manifest'] = (0, (self.MANIFEST % ('36', self.PROPERTY % 'true')).replace(
            ac.IDENTIFIER, 'org.example'))
        self.assertEqual(self.check()[0], ['bundle.aab: its manifest does not name the package %s' % ac.IDENTIFIER])

    def test_bundletool_refuses_or_is_not_there(self):
        self.answers['validate'] = (1, '[BT:1.18.3] Error: the bundle has no base module\n')
        self.answers['manifest'] = (1, '[BT:1.18.3] Error: no manifest\n')
        problems, notes = self.check()
        self.assertEqual(problems, [
            'bundle.aab: bundletool does not take it: [BT:1.18.3] Error: the bundle has no base module',
            'bundle.aab: bundletool cannot read its manifest: [BT:1.18.3] Error: no manifest'])
        self.assertNotIn('bundletool takes it', ' '.join(notes))
        self.calls = []
        problems, _ = self.check(tools={'jarsigner': 'jarsigner', 'keytool': 'keytool'})
        self.assertEqual(problems, ['bundle.aab: no bundletool (bundletool.jar) and java to read its manifest'])
        self.assertEqual([c[0] for c in self.calls], ['jarsigner', 'keytool'])


class VerifyBundles(unittest.TestCase):
    """verify's App Bundles: only for the builds that make one, checked
    with the JDK's tools and the bundletool the builder kept, while it is
    the one the builder pins; no other build may leave one"""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.work = os.path.join(self.dir, 'work')
        os.makedirs(os.path.join(self.work, 'out'))
        with open(os.path.join(self.work, ac.LOG_NAME), 'w') as f:
            f.write('')
        for name in ('debug.apk', 'bundle.apk', 'bundle.aab'):
            with open(os.path.join(self.work, 'out', name), 'wb') as f:
                f.write(b'x')
        self.jdk = os.path.join(self.dir, 'jdk')
        os.makedirs(os.path.join(self.jdk, 'bin'))
        for tool in ('jarsigner', 'keytool', 'java'):
            path = os.path.join(self.jdk, 'bin', tool + ('.exe' if os.name == 'nt' else ''))
            with open(path, 'w') as f:
                f.write('')
        self.jar = os.path.join(self.work, ac.BUNDLETOOL_JAR)
        with open(self.jar, 'wb') as f:
            f.write(b'a stand-in bundletool')
        self.seen = []

    def tearDown(self):
        import shutil
        shutil.rmtree(self.dir, ignore_errors=True)

    def verify(self, *argv, sha=None):
        saved = ac.find_tools, ac.verify_apk, ac.verify_bundle, ac.BUNDLETOOL_SHA256
        ac.find_tools = lambda sdk: {}
        ac.verify_apk = lambda name, apk, spec, tools, warnings, target=None: ([], [])

        def bundle(name, aab, apk, spec, tools, target=None):
            self.seen.append((name, os.path.basename(aab), os.path.basename(apk), dict(tools), target))
            return [], ['ok']
        ac.verify_bundle = bundle
        if sha is not None:
            ac.BUNDLETOOL_SHA256 = sha
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                status = ac.main(['verify', '--work', self.work, '--sdk', self.dir] + list(argv))
        finally:
            ac.find_tools, ac.verify_apk, ac.verify_bundle, ac.BUNDLETOOL_SHA256 = saved
        return status, out.getvalue()

    def test_the_pinned_bundletool(self):
        import hashlib
        self.assertEqual(ac.sha256_file(self.jar), hashlib.sha256(b'a stand-in bundletool').hexdigest())
        status, out = self.verify('--builds', 'debug,bundle', '--jdk', self.jdk, '--target', '36',
                                  sha=ac.sha256_file(self.jar))
        self.assertEqual(status, 0, out)
        self.assertEqual(len(self.seen), 1)
        name, aab, apk, tools, target = self.seen[0]
        self.assertEqual((name, aab, apk, target), ('bundle', 'bundle.aab', 'bundle.apk', '36'))
        self.assertEqual(tools['bundletool'], self.jar)
        for tool in ('jarsigner', 'keytool', 'java'):
            self.assertEqual(os.path.dirname(tools[tool]), os.path.join(self.jdk, 'bin'), tool)
        self.assertIn("The builder's bundletool: 1.18.3, SHA-256 ", out)
        self.assertIn('bundle.aab (0.0 MB): ok', out)

    def test_another_bundletool_is_refused(self):
        status, out = self.verify('--builds', 'bundle', '--jdk', self.jdk)
        self.assertEqual(status, 1, out)
        self.assertIn('the builder kept a bundletool that is not the one it pins (SHA-256 %s, not %s)'
                      % (ac.sha256_file(self.jar), ac.BUNDLETOOL_SHA256), out)
        # and is not run
        self.assertNotIn('bundletool', self.seen[0][3])

    def test_no_bundle(self):
        os.remove(os.path.join(self.work, 'out', 'bundle.aab'))
        status, out = self.verify('--builds', 'bundle', sha=ac.sha256_file(self.jar))
        self.assertEqual(status, 1, out)
        self.assertIn('there is no %s (the build asked for an App Bundle)'
                      % os.path.join(self.work, 'out', 'bundle.aab'), out)
        self.assertEqual(self.seen, [])

    def test_only_a_bundle_build_has_one(self):
        # a build that did not ask leaves none; nor is one checked
        status, out = self.verify('--builds', 'debug', sha=ac.sha256_file(self.jar))
        self.assertEqual(status, 1, out)
        self.assertIn('the builder left other files beside the packages: bundle.aab', out)
        self.assertEqual(self.seen, [])
        with open(os.path.join(self.work, 'out', 'debug.aab'), 'wb') as f:
            f.write(b'x')
        status, out = self.verify('--builds', 'debug,bundle', sha=ac.sha256_file(self.jar))
        self.assertIn('the builder left other files beside the packages: debug.aab', out)
        self.assertEqual([x[0] for x in self.seen], ['bundle'])
        # a signed build is not a bundle build either
        os.remove(os.path.join(self.work, 'out', 'debug.aab'))
        for name in ('release.apk', 'release.aab'):
            with open(os.path.join(self.work, 'out', name), 'wb') as f:
                f.write(b'x')
        self.seen = []
        status, out = self.verify('--builds', 'release,bundle', sha=ac.sha256_file(self.jar))
        self.assertIn('the builder left other files beside the packages: release.aab', out)
        self.assertEqual([x[0] for x in self.seen], ['bundle'])
        # and with no bundle build, no JDK tool or bundletool is looked for
        os.remove(os.path.join(self.work, 'out', 'release.aab'))
        os.remove(os.path.join(self.work, 'out', 'bundle.aab'))
        status, out = self.verify('--builds', 'release', '--jdk', self.jdk)
        self.assertEqual(status, 0, out)
        self.assertNotIn('bundletool', out)

    def test_jdk_tool(self):
        self.assertEqual(ac.jdk_tool(self.jdk, 'java'),
                         os.path.join(self.jdk, 'bin', 'java' + ('.exe' if os.name == 'nt' else '')))
        import shutil
        self.assertEqual(ac.jdk_tool(self.jdk, 'no-such-tool'), shutil.which('no-such-tool'))
        self.assertEqual(ac.jdk_tool(None, 'sh'), shutil.which('sh'))


class StepClock:
    """The check's clock in the Boot tests (in place of the time module):
    it moves only by the check's own sleeps, so the seconds the check
    prints ("settled after 0 s") and the deadlines it keeps are the same
    however long the stand-in adb takes to start. On real time, a busy
    macOS runner took over a second for one settle of a few calls, and
    "after 0 s" read "after 1 s" (CI checks on main's 782a01d0f)."""

    def __init__(self):
        self.now = 1000.0

    def monotonic(self):
        return self.now

    def time(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


@unittest.skipIf(os.name == 'nt', 'the stand-in adb is a shell script')
class Boot(unittest.TestCase):
    """boot with a stand-in adb: done once the emulator has booted, and
    when it never does, a problem and the lines that may say why"""

    BOOTED = ('case "$*" in\n'
              '  *get-state*) echo device ;;\n'
              '  *getprop*) echo 1 ;;\n'
              'esac\n')
    ABSENT = ('case "$*" in\n'
              '  *get-state*) echo "error: device \'emulator-5554\' not found"; exit 1 ;;\n'
              '  *devices*) printf "List of devices attached\\n" ;;\n'
              'esac\n')
    BOOTING = ('case "$*" in\n'
               '  *get-state*) echo device ;;\n'
               '  *getprop*) echo ;;\n'
               '  *devices*) printf "List of devices attached\\nemulator-5554 device\\n" ;;\n'
               'esac\n')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.sdk = self.tmp.name
        os.makedirs(os.path.join(self.sdk, 'platform-tools'))

    def tearDown(self):
        self.tmp.cleanup()

    def boot(self, script, *extra, running=True, minutes='0.002'):
        """running: what emulator_processes answers (True: one emulator
        line, False: none, None: ps could not be run)"""
        adb = os.path.join(self.sdk, 'platform-tools', 'adb')
        with open(adb, 'w') as f:
            f.write('#!/bin/sh\n' + script)
        os.chmod(adb, 0o755)
        procs = {True: ['4242 01:00 /sdk/emulator/emulator -avd api33'], False: [], None: None}[running]
        saved = ac.emulator_processes
        saved_time = ac.time
        ac.emulator_processes = lambda: procs
        self.clock = ac.time = StepClock()
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                status = ac.main(['boot', '--serial', 'emulator-5554', '--sdk', self.sdk, '--minutes', minutes,
                                  '--interval', '0.05'] + list(extra))
        finally:
            ac.emulator_processes = saved
            ac.time = saved_time
        return status, out.getvalue()

    def test_booted(self):
        status, out = self.boot(self.BOOTED)
        self.assertEqual(status, 0, out)
        self.assertIn('emulator-5554 booted', out)

    def test_not_there(self):
        log = os.path.join(self.sdk, 'emulator.log')
        with open(log, 'w') as f:
            f.write('INFO | starting\nERROR | x86_64 emulation currently requires hardware acceleration!\n')
        status, out = self.boot(self.ABSENT, '--log', log)
        self.assertEqual(status, 1)
        self.assertIn("did not boot in 0.002 minutes (adb says error: device 'emulator-5554' not found", out)
        # what may say why: the processes, /dev/kvm, adb, the disk, the log
        for part in ('emulator processes:', '/dev/kvm:', 'adb devices: List of devices attached',
                     'free disk at', 'the end of %s:' % log, 'requires hardware acceleration'):
            self.assertIn(part, out)

    def test_still_booting(self):
        status, out = self.boot(self.BOOTING)
        self.assertEqual(status, 1)
        self.assertIn('adb says device, sys.boot_completed is not there', out)
        self.assertIn('waiting for emulator-5554', out)

    def test_emulator_gone_gives_up_early(self):
        # the AVD the emulator could not find: it exits at once, and the
        # wait ends in seconds, not at --minutes
        log = os.path.join(self.sdk, 'emulator.log')
        with open(log, 'w') as f:
            f.write('ERROR | Unknown AVD name [api33], use -list-avds to see valid list.\n')
        started = time.monotonic()
        status, out = self.boot(self.ABSENT, '--log', log, running=False, minutes='5')
        self.assertLess(time.monotonic() - started, 30)
        self.assertEqual(status, 1)
        self.assertIn("emulator-5554 will not boot: no emulator is running (adb says error: device "
                      "'emulator-5554' not found", out)
        self.assertIn('emulator processes: none (it is not running)', out)
        self.assertIn('Unknown AVD name [api33]', out)

    def test_emulator_there_but_not_on_adb_yet_is_waited_for(self):
        status, out = self.boot(self.ABSENT, running=True)
        self.assertIn('did not boot in 0.002 minutes', out)
        self.assertNotIn('will not boot', out)

    def test_no_ps_is_not_taken_for_no_emulator(self):
        status, out = self.boot(self.ABSENT, running=None)
        self.assertIn('did not boot in 0.002 minutes', out)
        self.assertIn('emulator processes: ps could not be run', out)

    def test_a_device_on_a_cable_has_no_process(self):
        adb = os.path.join(self.sdk, 'platform-tools', 'adb')
        with open(adb, 'w') as f:
            f.write('#!/bin/sh\n' + self.ABSENT)
        os.chmod(adb, 0o755)
        saved = ac.emulator_processes
        ac.emulator_processes = lambda: []
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                ac.main(['boot', '--serial', 'R58M12345', '--sdk', self.sdk, '--minutes', '0.002',
                         '--interval', '0.05'])
        finally:
            ac.emulator_processes = saved
        self.assertIn('R58M12345 did not boot in 0.002 minutes', out.getvalue())

    def test_emulator_processes_names_programs_not_arguments(self):
        ps = ('    PID     ELAPSED COMMAND\n'
              '   4960       10:00 python3 tools/ci/android_check.py boot --log /w/emulator-api33.log\n'
              '   5001       09:58 /sdk/emulator/emulator -avd api33 -no-window\n'
              '   5002       09:57 /sdk/emulator/qemu/linux-x86_64/qemu-system-x86_64-headless -avd api33\n'
              '   5003       09:57 /sdk/emulator/crashpad_handler --database=/tmp\n'
              '   %d       00:01 /sdk/emulator/emulator (this process)\n' % os.getpid())
        saved = ac.run
        ac.run = lambda cmd, timeout=300, check=False: (0, ps)
        try:
            procs = ac.emulator_processes()
        finally:
            ac.run = saved
        self.assertEqual([p.split()[0] for p in procs], ['5001', '5002'])

    def test_emulator_processes_without_ps(self):
        def no_ps(cmd, timeout=300, check=False):
            raise ac.CheckError('ps: not found')
        saved = ac.run
        ac.run = no_ps
        try:
            self.assertIsNone(ac.emulator_processes())
        finally:
            ac.run = saved

    # booted, and settling: the overlays change once, then hold
    SETTLING = ('echo "$*" >> "$(dirname "$0")/calls"\n'
                'case "$*" in\n'
                '  *get-state*) echo device ;;\n'
                '  *getprop*) echo 1 ;;\n'
                '  *wait-for-broadcast-idle*) echo "All broadcast queues are idle!" ;;\n'
                '  *wait-for-handler*) echo Success ;;\n'
                '  *"overlay list"*)\n'
                '    n=$(grep -c "overlay list" "$(dirname "$0")/calls")\n'
                '    echo "android"\n'
                '    echo "[x] com.android.internal.display.cutout.emulation.corner"\n'
                '    if [ "$n" -ge 2 ]; then echo "[x] com.android.internal.systemui.navbar.gestural"; '
                'else echo "[ ] com.android.internal.systemui.navbar.gestural"; fi ;;\n'
                'esac\n')

    def calls(self):
        with open(os.path.join(self.sdk, 'platform-tools', 'calls')) as f:
            return [x.split(' ', 2)[2] for x in f.read().splitlines()]

    def test_settles_after_booting(self):
        status, out = self.boot(self.SETTLING, '--settle', '--settle-polls', '3')
        self.assertEqual(status, 0, out)
        calls = self.calls()
        # booted first, then the system server's process, each condition
        # in turn, and the system server's process again
        first = calls.index('shell am wait-for-broadcast-idle')
        self.assertTrue(all('getprop' in x or 'get-state' in x for x in calls[:first - 1]))
        self.assertEqual(calls[first - 1], 'shell pidof system_server')
        self.assertTrue(calls[first + 1].startswith('shell pm wait-for-handler --timeout '))
        self.assertEqual(calls[first + 2:], ['shell cmd overlay list'] * 4 + ['shell pidof system_server'])
        for part in ('emulator-5554 booted after',
                     'settling: the broadcast queues are idle after 0 s (am wait-for-broadcast-idle: '
                     'All broadcast queues are idle!)',
                     "settling: the package manager's handler is idle after 0 s (pm wait-for-handler: Success)",
                     'settling: the enabled overlays changed: +com.android.internal.systemui.navbar.gestural',
                     'settling: the enabled overlays are unchanged over 3 polls 0.05 s apart after 0 s (2 enabled)',
                     'emulator-5554 settled after 0 s: the broadcast queues are idle (am wait-for-broadcast-idle, '
                     "0 s); the package manager's handler is idle (pm wait-for-handler, 0 s); the enabled "
                     'overlays are unchanged over 3 polls 0.05 s apart (cmd overlay list, 2 enabled, 0 s)'):
            self.assertIn(part, out)
        self.assertNotIn('not:', out)

    def test_no_settling_unless_asked(self):
        status, out = self.boot(self.SETTLING)
        self.assertEqual(status, 0, out)
        self.assertNotIn('settl', out)
        self.assertFalse([x for x in self.calls() if 'wait-for' in x or 'overlay' in x])

    def test_settling_never_fails_the_boot(self):
        # an image without the commands, whose overlays never hold still
        script = ('n_file="$(dirname "$0")/n"\n'
                  'case "$*" in\n'
                  '  *get-state*) echo device ;;\n'
                  '  *getprop*) echo 1 ;;\n'
                  '  *wait-for*) echo "Unknown command: wait-for"; exit 255 ;;\n'
                  '  *"overlay list"*) echo x >> "$n_file"; echo "[x] overlay$(wc -l < "$n_file")" ;;\n'
                  'esac\n')
        status, out = self.boot(script, '--settle', '--settle-minutes', '0.003')
        self.assertEqual(status, 0, out)
        self.assertIn('settling: the broadcast queues are idle: am wait-for-broadcast-idle cannot say on this image',
                      out)
        self.assertIn('settling: the enabled overlays are unchanged over 3 polls 0.05 s apart: not in 0.003 minutes',
                      out)
        self.assertIn('; not: the enabled overlays are unchanged', out)

    # booted, then the system server restarts: two answers from no one,
    # then the same answers as ever, and a new system server process
    RESTARTING = ('echo "$*" >> "$(dirname "$0")/calls"\n'
                  'c() { grep -c "$1" "$(dirname "$0")/calls"; }\n'
                  'case "$*" in\n'
                  '  *get-state*) echo device ;;\n'
                  '  *getprop*) echo 1 ;;\n'
                  '  *"pidof system_server"*) if [ "$(c "pidof system_server")" -ge 2 ]; then echo 1234; '
                  'else echo 574; fi ;;\n'
                  '  *wait-for-broadcast-idle*) if [ "$(c wait-for-broadcast-idle)" -ge 3 ]; then '
                  'echo "All broadcast queues are idle!"; else echo "cmd: Can\'t find service: activity"; '
                  'exit 20; fi ;;\n'
                  '  *wait-for-handler*) echo Success ;;\n'
                  '  *"overlay list"*) if [ "$(c "overlay list")" -ge 3 ]; then echo android; '
                  'echo "[x] com.android.internal.systemui.navbar.gestural"; '
                  'else echo "cmd: Can\'t find service: overlay"; exit 20; fi ;;\n'
                  'esac\n')

    def test_settling_waits_for_the_system_server(self):
        status, out = self.boot(self.RESTARTING, '--settle', '--settle-polls', '3')
        self.assertEqual(status, 0, out)
        calls = self.calls()
        # each condition asked again until the system server answered
        self.assertEqual(calls.count('shell am wait-for-broadcast-idle'), 3)
        # the two listings it did not give counted for nothing: three more
        self.assertEqual(calls.count('shell cmd overlay list'), 5)
        self.assertEqual(out.count('the system server is not serving'), 1)
        self.assertEqual(out.count('gave no answer'), 1)
        for part in ("settling: the broadcast queues are idle: the system server is not serving "
                     "(am wait-for-broadcast-idle: cmd: Can't find service: activity); waiting for it",
                     'settling: the broadcast queues are idle after 0 s (am wait-for-broadcast-idle: '
                     'All broadcast queues are idle!)',
                     "settling: cmd overlay list gave no answer (cmd: Can't find service: overlay); waiting",
                     'settling: the enabled overlays are unchanged over 3 polls 0.05 s apart after 0 s (1 enabled)',
                     'settling: the system server restarted while settling (process 574, then 1234)'):
            self.assertIn(part, out)
        # a listing of no one is not a change to report
        self.assertNotIn('the enabled overlays changed', out)
        self.assertNotIn('not:', out)

    def test_settling_says_when_the_system_server_never_answers(self):
        script = ('case "$*" in\n'
                  '  *get-state*) echo device ;;\n'
                  '  *getprop*) echo 1 ;;\n'
                  '  *pidof*) echo 574 ;;\n'
                  '  *) echo "cmd: Failure calling service activity: Broken pipe (32)"; exit 20 ;;\n'
                  'esac\n')
        status, out = self.boot(script, '--settle', '--settle-minutes', '0.003')
        self.assertEqual(status, 0, out)
        self.assertIn('settling: the broadcast queues are idle: not in 0.003 minutes: the system server was not '
                      'serving (am wait-for-broadcast-idle: cmd: Failure calling service activity: Broken pipe (32))',
                      out)
        self.assertIn('settling: the enabled overlays are unchanged over 3 polls 0.05 s apart: not in 0.003 minutes',
                      out)
        self.assertIn('settled after 0 s: nothing held; not: the broadcast queues are idle; ', out)
        self.assertNotIn('restarted', out)

    def test_cannot_say_shows_how_the_command_ended(self):
        # a waiting command prints progress, then how it ended: the end is kept
        progress = 'Test idle failed due to 8adc4b0 runnable at -1s243ms because CONTAINS_MANIFEST. ' * 8
        script = ('case "$*" in\n'
                  '  *get-state*) echo device ;;\n'
                  '  *getprop*) echo 1 ;;\n'
                  '  *wait-for-broadcast-idle*) echo "%s"; echo "it ended this way"; exit 3 ;;\n'
                  '  *wait-for-handler*) echo Success ;;\n'
                  '  *"overlay list"*) echo "[x] com.a" ;;\n'
                  'esac\n' % progress)
        status, out = self.boot(script, '--settle', '--settle-polls', '2')
        self.assertEqual(status, 0, out)
        line = [x for x in out.splitlines() if 'cannot say' in x][0]
        self.assertIn('am wait-for-broadcast-idle cannot say on this image (exit status 3: ...', line)
        self.assertTrue(line.endswith('because CONTAINS_MANIFEST. it ended this way)'), line)
        self.assertLess(len(line), 450)

    # booted, and awake: the keys put it to sleep and wake it, and dumpsys
    # power says which
    AWAKE = ('d="$(dirname "$0")"\n'
             'echo "$*" >> "$d/calls"\n'
             'case "$*" in\n'
             '  *get-state*) echo device ;;\n'
             '  *getprop*) echo 1 ;;\n'
             '  *"keyevent KEYCODE_SLEEP"*) echo Asleep > "$d/state" ;;\n'
             '  *"keyevent KEYCODE_WAKEUP"*) echo Awake > "$d/state" ;;\n'
             '  *"dumpsys power"*) echo "Power Manager State:"; '
             'echo "  mWakefulness=$(cat "$d/state" 2>/dev/null || echo Awake)" ;;\n'
             '  *wait-for-broadcast-idle*) echo "All broadcast queues are idle!" ;;\n'
             '  *wait-for-handler*) echo Success ;;\n'
             '  *"overlay list"*) echo "[x] com.a" ;;\n'
             'esac\n')

    def test_awake_sleeps_once_then_keeps_it_awake_before_settling(self):
        status, out = self.boot(self.AWAKE, '--awake', '--settle', '--settle-polls', '2')
        self.assertEqual(status, 0, out)
        calls = self.calls()
        order = ['shell input keyevent KEYCODE_SLEEP', 'shell input keyevent KEYCODE_WAKEUP',
                 'shell wm dismiss-keyguard', 'shell input keyevent 82', 'shell svc power stayon true',
                 'shell settings put system screen_off_timeout 1800000', 'shell am wait-for-broadcast-idle']
        at = [calls.index(x) for x in order]
        self.assertEqual(at, sorted(at))
        for x in order[:-1]:
            self.assertEqual(calls.count(x), 1, x)
        # it was asked whether the device slept before it was woken, and
        # whether it woke before the keyguard
        self.assertIn('shell dumpsys power', calls[at[0]:at[1]])
        self.assertIn('shell dumpsys power', calls[at[1]:at[2]])
        self.assertIn('emulator-5554 awake after 0 s: slept (Asleep after 0 s); woke (Awake after 0 s); the '
                      'keyguard dismissed; it stays on while powered; its screen times out after 30 minutes '
                      'without a touch (Awake before)', out)
        self.assertLess(out.index('awake after'), out.index('settling:'))

    def test_awake_leaves_it_asleep_a_while_before_waking_it(self):
        # what Android keeps until the screen is off runs once it is off:
        # the wake comes an --interval after the device said it slept, by
        # the check's own clock (StepClock: only the check's sleeps move
        # it), and not only once the wait for sleep ran out (4 intervals)
        at = {}
        saved = ac.run

        def run(cmd, *args, **kwargs):
            for key in ('KEYCODE_SLEEP', 'KEYCODE_WAKEUP'):
                if key in cmd:
                    at[key] = self.clock.now
            return saved(cmd, *args, **kwargs)
        ac.run = run
        self.addCleanup(setattr, ac, 'run', saved)
        status, out = self.boot(self.AWAKE, '--awake', '--interval', '0.5')
        self.assertEqual(status, 0, out)
        self.assertEqual(sorted(at), ['KEYCODE_SLEEP', 'KEYCODE_WAKEUP'])
        self.assertGreaterEqual(at['KEYCODE_WAKEUP'] - at['KEYCODE_SLEEP'], 0.5)
        self.assertLess(at['KEYCODE_WAKEUP'] - at['KEYCODE_SLEEP'], 2.0)

    def test_no_awake_unless_asked(self):
        status, out = self.boot(self.AWAKE, '--settle', '--settle-polls', '2')
        self.assertEqual(status, 0, out)
        self.assertNotIn('awake', out)
        self.assertFalse([x for x in self.calls() if 'keyevent' in x or 'stayon' in x or 'power' in x])

    def test_awake_never_fails_the_boot(self):
        # an image that says nothing of its wakefulness and has none of the
        # commands: each is said, and the boot passes
        script = ('case "$*" in\n'
                  '  *get-state*) echo device ;;\n'
                  '  *getprop*) echo 1 ;;\n'
                  '  *"dumpsys power"*) echo "Power Manager State:" ;;\n'
                  '  *keyevent*) ;;\n'
                  '  *) echo "Unknown command"; exit 255 ;;\n'
                  'esac\n')
        started = time.monotonic()
        status, out = self.boot(script, '--awake')
        self.assertLess(time.monotonic() - started, 10)
        self.assertEqual(status, 0, out)
        for part in ('awake: dumpsys power does not say whether emulator-5554 is awake; waking it all the same',
                     'did not sleep in 0.2 s (dumpsys power does not say)',
                     'did not wake in 0.2 s (dumpsys power does not say)',
                     'wm dismiss-keyguard cannot say (Unknown command)',
                     'svc power stayon cannot say (Unknown command)',
                     'settings put system screen_off_timeout cannot say (Unknown command)',
                     '(not said before)'):
            self.assertIn(part, out)

    def test_wakefulness(self):
        self.assertEqual(ac.wakefulness('POWER MANAGER\n  mWakefulness=Asleep\n  mWakefulnessChanging=false'),
                         'Asleep')
        self.assertEqual(ac.wakefulness('  mWakefulness=Awake\n'), 'Awake')
        self.assertEqual(ac.wakefulness('cmd: Can\'t find service: power'), '')

    def test_answer(self):
        self.assertEqual(ac.answer(' a\n b  '), 'a b')
        self.assertEqual(ac.answer('x' * 10 + 'end', keep=5), '...xxend')

    def test_enabled_overlays(self):
        listing = ('android\n[x] com.a\n[ ] com.b\n---- \ncom.android.systemui\n[x] com.c\n')
        self.assertEqual(ac.enabled_overlays(listing), ['com.a', 'com.c'])

    def test_tail(self):
        log = os.path.join(self.sdk, 'long.log')
        with open(log, 'w') as f:
            f.write('\n'.join(str(i) for i in range(100)))
        self.assertEqual(ac.tail(log, 3), '97\n98\n99')
        self.assertTrue(ac.tail(os.path.join(self.sdk, 'none.log')).startswith('(no log:'))


class OneSystem(unittest.TestCase):
    """The check, its IDE script and the workflow agree"""

    def test_colours_and_identifier(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('constant kRunColor = "%d,%d,%d"' % ac.RUN_COLOR, script)
        self.assertIn('constant kSavedColor = "%d,%d,%d"' % ac.SAVED_COLOR, script)
        self.assertIn('constant kFailColor = "%d,%d,%d"' % ac.FAIL_COLOR, script)
        self.assertIn('constant kBackColor = "%d,%d,%d"' % ac.BACK_COLOR, script)
        self.assertIn('constant kWaitColor = "%d,%d,%d"' % ac.WAIT_COLOR, script)
        self.assertIn('constant kProbeWait = %d' % ac.PROBE_WAIT, script)
        self.assertIn('constant kIdentifier = "%s"' % ac.IDENTIFIER, script)
        # five colours the screen tells apart: none within another's
        # tolerance of colour_share
        colours = (ac.RUN_COLOR, ac.SAVED_COLOR, ac.FAIL_COLOR, ac.BACK_COLOR, ac.WAIT_COLOR)
        self.assertEqual(len(set(colours)), 5)
        for a in colours:
            for b in colours:
                if a != b:
                    self.assertEqual(ac.colour_share(bytes(list(a) + [255]), b, step=1), 0.0, (a, b))

    def test_probes(self):
        # the stack ide --probe names is the one the script makes: its file
        # is the stack's name, and OXT_ANDROID_PROBE picks it
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertEqual(ac.PROBES, {'app': 'AndroidProbe.livecode', 'java': 'AndroidJavaProbe.livecode'})
        name = re.search(r'(?s)private function probeName\n(.*?)\nend probeName', script).group(1)
        self.assertIn('if $OXT_ANDROID_PROBE is "java" then\n      return "AndroidJavaProbe"', name)
        self.assertIn('return "AndroidProbe"', name)
        self.assertIn("OXT_ANDROID_PROBE='java' if args.probe == 'java' else ''", read('tools', 'ci', 'android_check.py'))
        # the stack's name is said once, there: every use goes through it,
        # bar the three that ask probeName() which probe this is (its
        # openStack, its backKey, and its build's permissions)
        self.assertEqual(script.count('"AndroidProbe"'), 1)
        self.assertEqual(script.count('"AndroidJavaProbe"'), 4)
        self.assertEqual(script.count('if probeName() is "AndroidJavaProbe" then'), 3)

    def test_android_engine(self):
        # ide --android-engine beyond builds the probe as a stack whose
        # "android,engine" is beyond (the script reads OXT_ANDROID_ENGINE);
        # without it, as a stack that names none. beyond is the one it takes
        src = read('tools', 'ci', 'android_check.py')
        self.assertIn("OXT_ANDROID_ENGINE=args.android_engine or ''", src)
        self.assertIn("i.add_argument('--android-engine', choices=('beyond',),", src)
        with tempfile.TemporaryDirectory() as work:
            for name in ('9.6.3', 'Beyond', ''):
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        ac.main(['ide', '--work', work, '--android-engine', name])
            self.assertEqual(os.listdir(work), [])
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('--    OXT_ANDROID_ENGINE    the probe\'s "android,engine" setting', script)
        settings = re.search(r'(?s)private function buildSettings pName\n(.*?)\nend buildSettings', script).group(1)
        self.assertIn('   if $OXT_ANDROID_ENGINE is not empty then\n'
                      '      put $OXT_ANDROID_ENGINE into tSettings["android,engine"]\n'
                      '   end if\n', settings)
        # android.yml builds with the release's engine, 9.6.3's: no
        # runtime beside it, and no probe asks for one
        workflow = read('.github', 'workflows', 'android.yml')
        self.assertNotIn('--android-engine', workflow)
        self.assertNotIn('--beyond', workflow)

    def test_java_probe_script(self):
        # the Java layer's probe takes every step, each answer checked and
        # said in the log, and turns its fail colour when any failed, else
        # green: a notification an hour away (the alarm's PendingIntent),
        # cancelled; the app's external folder (WRITE_EXTERNAL_STORAGE
        # first) and androidHasPermission of it; a picture exported to the
        # album. The plain probe turns green at once, as before
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function probeScript\n(.*?)\nend probeScript', script).group(1)
        java = body.split('end if\n   put "   set the backgroundColor of me to"')[0]
        steps = ['put false into tFailed',
                 'mobileCreateLocalNotification', 'the seconds + 3600, false, 0',
                 'put the result into tId', '"OXT-Beyond probe: local notification" & quote && "&& tId"',
                 'tId is not an integer or tId < 1', 'put true into tFailed', 'mobileCancelLocalNotification tId',
                 'put specialFolderPath(" & quote & "external documents" & quote & ") into tFolder',
                 '"OXT-Beyond probe: external documents" & quote && "&& tFolder"',
                 'if tFolder is empty then put true into tFailed',
                 'put androidHasPermission(" & quote & "android.permission.WRITE_EXTERNAL_STORAGE" & quote',
                 '"OXT-Beyond probe: has WRITE_EXTERNAL_STORAGE" & quote && "&& tHas"',
                 'if tHas is not true then put true into tFailed',
                 'mobileExportImageToAlbum base64Decode(" & quote & kProbePicture & quote & "),"',
                 'put the result into tExport', '"OXT-Beyond probe: export to album" & quote && "&& tExport"',
                 'if tExport is not empty then put true into tFailed',
                 'if tFailed then', 'kFailColor', 'exit openStack']
        at = [java.index(x) for x in steps]
        self.assertEqual(at, sorted(at), steps)
        # the result is read once, at once, before anything can change it
        self.assertEqual(java.count('put the result into'), 2)
        # only the end decides: no step leaves early
        self.assertEqual(java.count('exit openStack'), 1)
        self.assertIn('if probeName() is "AndroidJavaProbe" then', body)
        self.assertTrue(body.rstrip().endswith('"end backKey" after tScript\n   end if\n   return tScript'))
        self.assertIn('set the script of stack tProbe to probeScript()', script)

    def test_java_probe_back_key(self):
        # the Java layer's probe, and only it, handles backKey after its
        # openStack: it turns its back colour (device --back) and does not
        # pass the message, so the app stays
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function probeScript\n(.*?)\nend probeScript', script).group(1)
        tail = body.split('"end openStack" after tScript')[1]
        tail = tail.split('"end mouseUp" after tScript')[1]
        self.assertEqual(tail,
                         '\n   if probeName() is "AndroidJavaProbe" then\n'
                         '      -- the back key, not passed (see the header)\n'
                         '      put return & "on backKey" & return & \\\n'
                         '            "   set the backgroundColor of me to" && quote & kBackColor & quote & return & '
                         '\\\n'
                         '            "end backKey" after tScript\n'
                         '   end if\n'
                         '   return tScript')
        self.assertNotIn('pass backKey', tail)
        # in code, the constant and its one use
        uses = [x.strip() for x in script.splitlines() if 'kBackColor' in x and not x.lstrip().startswith('--')]
        self.assertEqual(len(uses), 2, uses)
        self.assertTrue(uses[0].startswith('constant kBackColor = '), uses)

    def test_probe_mouse_up(self):
        # both probes, after openStack: a tap turns the stack its wait
        # colour, waits kProbeWait seconds with messages and turns it green
        # again (device --density-in-wait changes the density meanwhile)
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function probeScript\n(.*?)\nend probeScript', script).group(1)
        tail = body.split('"end openStack" after tScript')[1]
        self.assertTrue(tail.startswith(
            '\n   -- a tap: a script waiting (kWaitColor), then green again\n'
            '   put return & "on mouseUp" & return & \\\n'
            '         "   set the backgroundColor of me to" && quote & kWaitColor & quote & return & \\\n'
            '         "   wait" && kProbeWait && "seconds with messages" & return & \\\n'
            '         "   set the backgroundColor of me to" && quote & kRunColor & quote & return & \\\n'
            '         "end mouseUp" after tScript\n'
            '   if probeName() is "AndroidJavaProbe" then\n'), tail)
        # in code, each constant and its one use
        for name in ('kWaitColor', 'kProbeWait'):
            uses = [x.strip() for x in script.splitlines() if name in x and not x.lstrip().startswith('--')]
            self.assertEqual(len(uses), 2, uses)
            self.assertTrue(uses[0].startswith('constant %s = ' % name), uses)
        # the device check waits for the colour well within the wait, and
        # gives the app, after the density change, the rest of the wait and
        # its start in a new process
        self.assertLess(ac.WAIT_SEEN * 2, ac.PROBE_WAIT + 1)
        self.assertLess(ac.PROBE_WAIT * 2, ac.RETURN_WAIT + 1)

    def test_java_probe_picture(self):
        # the probe's picture is a real PNG (what the engine sends to the
        # Java layer as ".png"): one pixel
        script = read('tools', 'ci', 'android-check.livecodescript')
        data = base64.b64decode(re.search(r'(?m)^constant kProbePicture = "([^"]+)"$', script).group(1))
        self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(data[12:16], b'IHDR')
        self.assertEqual(struct.unpack('>II', data[16:24]), (1, 1))
        self.assertEqual(data[-8:-4], b'IEND')

    def test_builds_take_the_probes_name(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        for part in ('put revSBGetSettings(probeName(), true) into tSettings',
                     'put probeName() into tSettings["name"]',
                     'probeName(), tApk, "Build", buildSettings(tName)',
                     'revSBSetSettings probeName(), buildSettings("debug")',
                     'with probeName(), "Android" && tSerial'):
            self.assertIn(part, script)

    def test_builds(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('put "%s" into tBuilds' % ','.join(ac.BUILDS), script)
        for name in ac.BUILDS:
            self.assertIn('case "%s"' % name, script)

    def test_overlay_files_exist(self):
        for rel in ac.OVERLAY:
            self.assertTrue(os.path.isfile(os.path.join(REPO, *rel.split('/'))), rel)

    def test_16k_step_settles_before_the_probe_starts(self):
        # the 16 KB step is for loading with 16 KB pages: the probe starts
        # only after boot --settle, never on a just-booted image
        workflow = read('.github', 'workflows', 'android.yml')
        step = re.search(r'(?s)- name: Run the package with 16 KB pages\n(.*?)\n      - name:', workflow).group(1)
        boot = re.search(r'android_check\.py boot [^\n]*\\\n[^\n]*', step)
        self.assertTrue(boot, 'the 16 KB step waits for the emulator')
        self.assertIn('--settle', boot.group(0))
        self.assertLess(boot.start(), step.index('android_check.py device'))

    def test_16k_image_has_3_gb(self):
        # run 42312203693: with the 1536 MB avdmanager gives a Pixel 5,
        # Android 16 ran short of memory and killed the Java layer's probe
        # (LOW_MEMORY) behind its permission dialog. The AVD gets 3 GB, as
        # its one hw.ramSize line, before the emulator starts
        workflow = read('.github', 'workflows', 'android.yml')
        step = re.search(r'(?s)- name: Run the package with 16 KB pages\n(.*?)\n      - name:', workflow).group(1)
        config = '"$ANDROID_AVD_HOME/pages16k.avd/config.ini"'
        drop = step.index("sed -i '/^hw.ramSize=/d' " + config)
        add = step.index("echo 'hw.ramSize=3072M' >> " + config)
        self.assertLess(step.index('avdmanager" create avd -n pages16k'), drop)
        self.assertLess(drop, add)
        self.assertLess(add, step.index('"$SDK/emulator/emulator" -avd pages16k'))
        self.assertNotIn('-memory', step)

    def test_every_emulator_stays_awake_under_its_probes(self):
        # run 42218720113: the 16 KB image's screen went off as the Java
        # layer's probe started, SystemUI's theme overlays relaunched it,
        # and it aborted. Each image sleeps once and is kept awake (boot
        # --awake) before any probe starts on it
        workflow = read('.github', 'workflows', 'android.yml')
        boots = re.findall(r'android_check\.py boot [^\n]*\\\n[^\n]*', workflow)
        self.assertEqual(len(boots), 2, boots)
        for boot in boots:
            self.assertIn('--awake', boot)
            self.assertIn('--settle', boot)
        for name in ('Wait for the emulator', 'Run the package with 16 KB pages'):
            step = re.search(r'(?s)- name: %s\n(.*?)\n      - name:' % re.escape(name), workflow).group(1)
            self.assertIn('--awake', step, name)

    def test_android_13_settles_before_any_probe_starts(self):
        # the Android 13 image boots while the IDE builds; every probe on it
        # (the IDE's Test, the packages, the Java layer's probe) starts only
        # after boot --settle, never while it still enables its overlays
        workflow = read('.github', 'workflows', 'android.yml')
        step = re.search(r'(?s)- name: Wait for the emulator\n(.*?)\n      - name:', workflow)
        self.assertTrue(step, 'the workflow waits for the Android 13 emulator')
        boot = re.search(r'android_check\.py boot [^\n]*\\\n[^\n]*', step.group(1))
        self.assertTrue(boot)
        self.assertIn('--settle', boot.group(0))
        self.assertIn('emulator-api33.log', boot.group(0))
        # its step timeout leaves room for the boot's 10 minutes and the
        # settling's 5, so the check's own account comes first
        self.assertGreaterEqual(int(re.search(r'timeout-minutes: (\d+)', step.group(1)).group(1)), 16)
        wait = workflow.index('- name: Wait for the emulator')
        before = workflow[:wait]
        start = before.index('- name: Start an Android 13 emulator')
        for use in ('android_check.py device', '--device emulator-5554'):
            self.assertNotIn(use, before[start:], use)
        self.assertIn('--device emulator-5554', workflow[wait:])

    def test_workflow_runs_on_a_change_to_the_builder(self):
        workflow = read('.github', 'workflows', 'android.yml')
        paths = re.search(r'(?s)paths: &android-paths\n(.*?)\n  push:', workflow).group(1)
        for rel in ac.OVERLAY + ('tools/ci/android_check.py', 'tools/ci/android-check.livecodescript',
                                 '.github/workflows/android.yml'):
            self.assertIn(rel, paths)

    def test_java_probe_asks_to_post_notifications(self):
        # the Java layer's probe, and only it, declares POST_NOTIFICATIONS
        # (as the Android card's "Post Notifications" does), so Android 13
        # asks the user for it as the probe schedules its notification
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function buildSettings pName\n(.*?)\nend buildSettings', script).group(1)
        self.assertIn('   if probeName() is "AndroidJavaProbe" then\n'
                      '      put true into tSettings["android,application permissions"]["POST_NOTIFICATIONS"]\n'
                      '      put true into tSettings["android,application permissions"]["WRITE_EXTERNAL_STORAGE"]\n', body)
        self.assertEqual(script.count('POST_NOTIFICATIONS"]'), 1)
        self.assertEqual(script.count('WRITE_EXTERNAL_STORAGE"]'), 1)
        # every run of this checkout's Java layer on a device allows it,
        # and no other: the plain probe never asks, and the release's
        # Java layer throws before it could
        workflow = read('.github', 'workflows', 'android.yml')
        runs = re.findall(r'android_check\.py device(?:[^\n]*\\\n)*[^\n]*', workflow)
        java_new = [r for r in runs if '/java-new/' in r]
        self.assertEqual(len(java_new), 2, runs)
        for run in runs:
            self.assertEqual('--allow android.permission.POST_NOTIFICATIONS' in run, run in java_new, run)

    def test_java_probe_reads_its_copy_file(self):
        # the Java layer's probe, and only it, carries a copy file (the
        # standalone settings' "files"), which the engine reads from the
        # package's assets by their offsets: so a package that compressed
        # its assets (an App Bundle without "assets/**" stored) fails here
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('constant kProbeCopyName = "oxt-probe.txt"\n', script)
        self.assertIn('constant kProbeCopy = "OXT-Beyond probe copy file"\n', script)
        body = re.search(r'(?s)private function buildSettings pName\n(.*?)\nend buildSettings', script).group(1)
        java = re.search(r'(?s)   if probeName\(\) is "AndroidJavaProbe" then\n(.*?)\n   end if\n', body).group(1)
        self.assertIn('      put kProbeCopy into url ("binfile:" & item 1 to -2 of $OXT_ANDROID_STACK & slash '
                      '& kProbeCopyName)\n', java)
        self.assertIn('      put kProbeCopyName into tSettings["files"]', java)
        self.assertEqual(body.count('tSettings["files"]'), 1)
        # the probe reads it from the engine's folder, says what it read,
        # and fails if it is not the text written
        read_line = ('"   put url (" & quote & "binfile:" & quote && "& specialFolderPath(" & quote & "engine" & quote '
                     '& ") &" && \\\n            quote & "/" & kProbeCopyName & quote & ") into tCopy" & return')
        said = script.index('"   put" && quote & "OXT-Beyond probe: copy file" & quote && "&& tCopy" & return')
        failed = script.index('"   if tCopy is not" && quote & kProbeCopy & quote && "then put true into tFailed"')
        self.assertLess(script.index(read_line), said)
        self.assertLess(said, failed)
        # inside the Java layer's probe's steps, which only it runs
        steps = script.index('"   local tFailed, tId, tFolder, tHas, tExport, tCopy" & return')
        self.assertLess(steps, script.index(read_line))
        self.assertLess(failed, script.index('"      exit openStack" & return', steps))

    def test_java_probe_picture_is_looked_for(self):
        # every run of this checkout's Java layer looks for the picture the
        # probe exports, by the name it exports it as; no other run does
        # (the release's Java layer is refused WRITE_EXTERNAL_STORAGE on
        # Android 13 before it exports)
        script = read('tools', 'ci', 'android-check.livecodescript')
        name = re.search(r'mobileExportImageToAlbum base64Decode\(" & quote & kProbePicture & quote & "\)," && \\\n'
                         r'\s*quote & "([^"]+)" & quote', script).group(1)
        workflow = read('.github', 'workflows', 'android.yml')
        runs = re.findall(r'android_check\.py device(?:[^\n]*\\\n)*[^\n]*', workflow)
        for run in runs:
            self.assertEqual('--picture %s.png' % name in run, '/java-new/' in run, run)
            self.assertEqual(run.count('--picture'), 1 if '/java-new/' in run else 0, run)

    def test_target_api(self):
        lib = read('ide-support', 'revdeploylibraryandroid.livecodescript')
        self.assertIn('constant kDeployAndroidTargetSDK = "%s"' % ac.TARGET_SDK, lib)
        self.assertIn('constant kDeployAndroidNewestTargetSDK = "%s"' % ac.NEWEST_TARGET_SDK, lib)
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        self.assertIn('constant kRestrictedResizability = "%s"' % ac.LARGE_SCREEN_PROPERTY, builder)

    def test_back_and_bars_runs(self):
        # every run of this checkout's Java layer's probe (which targets 36)
        # presses the back key and checks the bars; the app probe with that
        # layer and the builder's other packages (which target 33) check
        # the bars alone; the release's Java layer, only recorded, neither
        workflow = read('.github', 'workflows', 'android.yml')
        runs = self.device_runs(workflow)
        self.assertEqual(sum(work == 'java-new' for _, work, _, _ in runs), 2, runs)
        self.assertEqual(sum(work == 'java-app' for _, work, _, _ in runs), 2, runs)
        recorded = [cmd for name, work, _, cmd in runs if name.startswith("The release's Java layer")]
        self.assertEqual(len(recorded), 1, runs)
        self.assertEqual(sum(work == 'changed' for _, work, _, _ in runs), 3, runs)
        for name, work, _, cmd in runs:
            self.assertEqual('--back' in cmd, work == 'java-new', cmd)
            self.assertEqual('--within-bars' in cmd, work != 'java-old' and cmd not in recorded, cmd)

    def test_once_in_a_process_runs(self):
        # the engine runs once in a process: the app probe with this Java
        # layer (which has RelaunchActivity) through a font size change, a
        # density change and opened again after its stack quits, on both
        # emulators; the release's Java layer through a font size change
        # (the manifest lists it), once, and for the record (no
        # annotations, never failing the job) across the other two
        workflow = read('.github', 'workflows', 'android.yml')
        runs = self.device_runs(workflow)
        app = [(name, cmd) for name, work, _, cmd in runs if work == 'java-app']
        self.assertEqual([name for name, _ in app], ['Run the app probe with this Java layer on Android 13',
                                                     'Run the package with 16 KB pages'])
        for _, cmd in app:
            self.assertTrue(cmd.endswith('--within-bars --font-scale --density --relaunch'), cmd)
        # --relaunch only where the probe passes the back key (the app
        # probe): the Java layer's probe handles backKey and goes on
        for name, work, pkgs, cmd in runs:
            if '--relaunch' in cmd or '--density' in cmd:
                self.assertIn(work, ('java-app', 'changed'), cmd)
                self.assertEqual(pkgs, ['debug.apk'], cmd)
        font = [(name, pkgs, cmd) for name, work, pkgs, cmd in runs if work == 'changed' and '--font-scale' in cmd]
        self.assertEqual(len(font), 1, runs)
        self.assertEqual(font[0][0], 'Run the packages on Android 13')
        self.assertIn('$([ "$pkg" = debug.apk ] && echo --font-scale)', font[0][2])
        step = re.search(r"(?s)- name: The release's Java layer across a density change and opened again, on "
                         r"Android 13\n(.*?)\n      - name:", workflow).group(1)
        self.assertIn('for check in density relaunch; do', step)
        self.assertIn('env -u GITHUB_ACTIONS -u GITHUB_STEP_SUMMARY "$PY" tools/ci/android_check.py device', step)
        self.assertIn('--apk "$WORK/changed/out/debug.apk"', step)
        self.assertIn('"--$check" 2>&1)', step)
        self.assertTrue(step.rstrip().endswith('exit 0'), step)
        self.assertNotIn('continue-on-error', step)
        # no step changes the font size or the density by hand any more:
        # device's checks put them back
        self.assertNotIn('settings put system font_scale', workflow)
        self.assertNotIn('wm density', workflow)
        # nor the density while the probe's script waits: 9.6.3's engine
        # hangs there (android-engine.yml checks the engine built here)
        self.assertNotIn('--density-in-wait', workflow)
        # the app probe is built with this Java layer, from the plain
        # probe's stack, and verified at the newest target
        ides = [re.sub(r'\\\n\s*', '', x) for x in
                re.findall(r'android_check\.py ide(?:[^\n]*\\\n)*[^\n]*', workflow)]
        built = [x for x in ides if '--work "$WORK/java-app"' in x]
        self.assertEqual(built, ['android_check.py ide --install "$JAVA_IDE" --platform "$PLATFORM" '
                                 '--work "$WORK/java-app" --sdk "$SDK" --jdk "$JDK" --no-units --builds debug '
                                 '--stack "$WORK/changed/AndroidProbe.livecode"'])

    def test_java_probe_verified_at_the_newest_target(self):
        # the Java layer's probe and the app probe are built with a Java
        # layer ready for 36, so they target 36; the other packages, built
        # with the release's runtime, target what the builder picks for it
        # (33 with 9.6.3's Java layer, 36 with one built here)
        workflow = read('.github', 'workflows', 'android.yml')
        verifies = [re.sub(r'\\\n\s*', '', v) for v in
                    re.findall(r'android_check\.py verify(?:[^\n]*\\\n)*[^\n]*', workflow)]
        self.assertEqual(len(verifies), 3, verifies)
        for v in verifies:
            if '/java-new"' in v or '/java-app"' in v:
                self.assertTrue(v.endswith('--target %s' % ac.NEWEST_TARGET_SDK), v)
            else:
                self.assertEqual(v, 'android_check.py verify --work "$WORK/changed" --sdk "$SDK" --jdk "$JDK" '
                                    '--target-for "$CHANGED"')

    def test_bundletool_pins_agree(self):
        # the bundletool the builder downloads is the one verify takes
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        version = re.search(r'^constant kBundletoolVersion = "([^"]+)"$', builder, re.M).group(1)
        sha = re.search(r'^constant kBundletoolSHA256 = "([0-9a-f]{64})"$', builder, re.M).group(1)
        url = re.search(r'^constant kBundletoolURL = "([^"]+)"$', builder, re.M).group(1)
        self.assertEqual(version, ac.BUNDLETOOL_VERSION)
        self.assertEqual(sha, ac.BUNDLETOOL_SHA256)
        self.assertEqual(url, 'https://github.com/google/bundletool/releases/download/%s/bundletool-all-%s.jar'
                         % (version, version))
        # the check's unit names the same cache file
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('revEnvironmentUserCachePath() & "/Android/bundletool-all-%s.jar"' % version, script)

    def test_the_bundle_build(self):
        # its settings are BUILDS["bundle"]'s, and only it asks for a bundle
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function buildSettings pName\n(.*?)\nend buildSettings', script).group(1)
        case = re.search(r'(?s)      case "bundle"\n(.*?)\n         break', body).group(1)
        self.assertEqual(case.splitlines(), [
            '         put "Sign with my key" into tSettings["android,signing"]',
            '         put $OXT_ANDROID_KEYSTORE into tSettings["android,key"]',
            '         put true into tSettings["android,arm64"]',
            '         put true into tSettings["android,x86_64"]',
            '         put true into tSettings["android,app bundle"]'])
        self.assertEqual(body.count('"android,app bundle"'), 1)
        self.assertEqual(ac.BUILDS['bundle']['abis'], {'arm64-v8a', 'x86_64'})
        self.assertEqual(ac.BUILDS['bundle']['signer'], ac.KEY_DNAME)
        # its questions are answered as the release build's
        self.assertIn('if tName is "release" or tName is "bundle" then', script)

    def device_runs(self, workflow):
        """Each device run of android.yml: (its step, the work folder of
        its package, the packages it runs (a loop's, or its one), its
        command with the continuation lines joined)"""
        runs = []
        for step in re.split(r'\n      - name: ', workflow)[1:]:
            name = step.split('\n', 1)[0]
            for loop in re.finditer(r'(?s)for pkg in ([^;]+); do\n(.*?)\n\s*done', step):
                for cmd in re.findall(r'android_check\.py device(?:[^\n]*\\\n)*[^\n]*', loop.group(2)):
                    runs.append((name, cmd, loop.group(1).split()))
            outside = re.sub(r'(?s)for pkg in [^;]+; do\n.*?\n\s*done', '', step)
            for cmd in re.findall(r'android_check\.py device(?:[^\n]*\\\n)*[^\n]*', outside):
                runs.append((name, cmd, None))
        out = []
        for name, cmd, pkgs in runs:
            cmd = re.sub(r'\\\n\s*', '', cmd)
            m = re.search(r'--apk "\$WORK/([^/]+)/out/([^"]+)"', cmd)
            self.assertTrue(m, cmd)
            if pkgs is None:
                self.assertNotIn('$pkg', m.group(2), cmd)
                pkgs = [m.group(2)]
            else:
                self.assertEqual(m.group(2), '$pkg', cmd)
            out.append((name, m.group(1), pkgs, cmd))
        return out

    def test_app_bundle_runs(self):
        # the bundle build is among the builds of this builder's run (no
        # --builds) and of the Java layer's probe, both checked with the
        # JDK's tools; each of their App Bundles is installed as Google
        # Play installs it, with the bundletool its builder downloaded
        self.assertTrue(ac.BUILDS['bundle']['bundle'])
        self.assertEqual([n for n in ac.BUILDS if ac.BUILDS[n].get('bundle')], ['bundle'])
        workflow = read('.github', 'workflows', 'android.yml')
        ides = [re.sub(r'\\\n\s*', '', x) for x in
                re.findall(r'android_check\.py ide(?:[^\n]*\\\n)*[^\n]*', workflow)]
        changed = [x for x in ides if '--work "$WORK/changed"' in x]
        self.assertEqual(len(changed), 1, ides)
        self.assertNotIn('--builds', changed[0])
        java = [x for x in ides if '--work "$WORK/java-new"' in x]
        self.assertEqual(len(java), 1, ides)
        self.assertIn('--builds debug,bundle --probe java', java[0])
        verifies = [re.sub(r'\\\n\s*', '', v) for v in
                    re.findall(r'android_check\.py verify(?:[^\n]*\\\n)*[^\n]*', workflow)]
        for v in verifies:
            self.assertIn('--jdk "$JDK"', v)
            # each verify checks the builds its ide made: all, or those it
            # names
            work = re.search(r'--work "([^"]+)"', v).group(1)
            ide = [x for x in ides if '--work "%s"' % work in x]
            self.assertEqual(len(ide), 1, (v, ides))
            self.assertEqual(re.findall(r'--builds (\S+)', v), re.findall(r'--builds (\S+)', ide[0]), v)
        runs = self.device_runs(workflow)
        bundles = sorted((name, work) for name, work, pkgs, _ in runs if 'bundle.aab' in pkgs)
        self.assertEqual(bundles, [('Run the Java layer\'s probe on Android 13', 'java-new'),
                                   ('Run the package with 16 KB pages', 'java-new'),
                                   ('Run the packages on Android 13', 'changed')])
        for name, work, pkgs, cmd in runs:
            if any(p.endswith('.aab') for p in pkgs):
                self.assertIn('--bundletool "$WORK/%s/%s" --jdk "$JDK"' % (work, ac.BUNDLETOOL_JAR), cmd)
                # each package of the loop, with its own screen and log
                self.assertIn('${pkg%.*}.png', cmd)
                self.assertIn('${pkg%.*}.txt', cmd)
            else:
                self.assertNotIn('--bundletool', cmd)
            for p in pkgs:
                self.assertTrue(p.endswith(('.apk', '.aab')), p)
        # the Java layer's probe runs as a package and as a bundle with the
        # same checks
        java_runs = [(pkgs, cmd) for _, work, pkgs, cmd in runs if work == 'java-new']
        self.assertEqual([pkgs for pkgs, _ in java_runs], [['debug.apk', 'bundle.aab']] * 2)
        self.assertIn('${{ env.WORK }}/*/out/*.aab', workflow)

    def test_java_probe_runs_on_both_emulators(self):
        # the step names device_runs reads are the workflow's
        workflow = read('.github', 'workflows', 'android.yml')
        names = [n for n, _, _, _ in self.device_runs(workflow)]
        self.assertEqual(len(names), len(re.findall(r'android_check\.py device', workflow)))
        self.assertIn("Run the Java layer's probe on Android 13", names)

    def test_16k_image_at_the_newest_target(self):
        # the 16 KB image is the first at API 36 or newer (Android 16),
        # where the back key of an app that targets 36 goes only to its
        # back callback
        workflow = read('.github', 'workflows', 'android.yml')
        pick = re.search(r'(?s)img16=\$\((.*?)\)\n', workflow).group(1)
        self.assertIn("if (v + 0 >= %s) print" % ac.NEWEST_TARGET_SDK, pick)
        self.assertTrue(pick.rstrip().endswith('head -n 1'), pick)


if __name__ == '__main__':
    unittest.main()
