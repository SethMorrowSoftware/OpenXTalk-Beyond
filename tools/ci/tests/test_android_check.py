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

import contextlib
import io
import os
import re
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

    def device(self, pidof, timeout='10'):
        d = self.tmp.name
        adb = os.path.join(d, 'platform-tools', 'adb')
        with open(adb, 'w') as f:
            f.write('#!/bin/sh\n'
                    'shift 2\n'
                    'case "$*" in\n'
                    '  "shell getprop ro.build.version.sdk") echo 35 ;;\n'
                    '  "shell getconf PAGE_SIZE") echo 16384 ;;\n'
                    '  "shell getprop ro.product.cpu.abi") echo x86_64 ;;\n'
                    '  install*) echo Success ;;\n'
                    '  "shell am start"*) echo "Status: ok" ;;\n'
                    '  "exec-out screencap") cat "%s/screen.raw" ;;\n'
                    '  "shell pidof"*) %s ;;\n'
                    '  "logcat -d -v brief") cat "%s/logcat.txt" ;;\n'
                    '  "logcat -d -b events -v brief") echo "I/am_kill (  590): [0,3475,org.openxtalk.check.androidprobe,0,lmk]" ;;\n'
                    '  "shell dumpsys activity exit-info"*) printf "  ApplicationExitInfo #0:\\n    pid=3612 reason=3 (LOW_MEMORY)\\n" ;;\n'
                    '  "shell cat /proc/meminfo") printf "MemTotal: 2000000 kB\\nMemFree: 1 kB\\nMemAvailable: 90000 kB\\n" ;;\n'
                    '  "shell dumpsys window") printf "  mCurrentFocus=Window{1f u0 Application Not Responding: '
                    'com.android.systemui}\\n  mFocusedApp=ActivityRecord{2e u0 '
                    'org.openxtalk.check.androidprobe/.mblandroid t9}\\n" ;;\n'
                    'esac\n' % (d, pidof, d))
        os.chmod(adb, 0o755)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = ac.main(['device', '--apk', self.apk, '--serial', 'emulator-5554', '--sdk', d,
                              '--timeout', timeout])
        return status, out.getvalue()

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
            problems = ac.overlay(argparse.Namespace(root=self.root, classes=classes))
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

    def test_expected_manifest(self):
        self.assertEqual(ac.expected_manifest('debug', []), ['receiver PushReceiver: android:exported=true'])
        self.assertEqual(ac.expected_manifest('debug', ['receiver PushReceiver: android:exported=true']), [])
        self.assertEqual(ac.expected_manifest('release', []), [])

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
        ac.emulator_processes = lambda: procs
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                status = ac.main(['boot', '--serial', 'emulator-5554', '--sdk', self.sdk, '--minutes', minutes,
                                  '--interval', '0.05'] + list(extra))
        finally:
            ac.emulator_processes = saved
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
        self.assertIn('constant kIdentifier = "%s"' % ac.IDENTIFIER, script)
        # three colours the screen tells apart
        colours = (ac.RUN_COLOR, ac.SAVED_COLOR, ac.FAIL_COLOR)
        self.assertEqual(len(set(colours)), 3)

    def test_probes(self):
        # the stack ide --probe names is the one the script makes: its file
        # is the stack's name, and OXT_ANDROID_PROBE picks it
        script = read('tools', 'ci', 'android-check.livecodescript')
        self.assertEqual(ac.PROBES, {'app': 'AndroidProbe.livecode', 'java': 'AndroidJavaProbe.livecode'})
        name = re.search(r'(?s)private function probeName\n(.*?)\nend probeName', script).group(1)
        self.assertIn('if $OXT_ANDROID_PROBE is "java" then\n      return "AndroidJavaProbe"', name)
        self.assertIn('return "AndroidProbe"', name)
        self.assertIn("OXT_ANDROID_PROBE='java' if args.probe == 'java' else ''", read('tools', 'ci', 'android_check.py'))
        # the stack's name is said once, there: every use goes through it
        self.assertEqual(script.count('"AndroidProbe"'), 1)
        self.assertEqual(script.count('"AndroidJavaProbe"'), 2)

    def test_java_probe_script(self):
        # the Java layer's probe: a notification an hour away (the alarm's
        # PendingIntent), its id checked, cancelled, and only then green;
        # the plain probe turns green at once, as before
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = re.search(r'(?s)private function probeScript\n(.*?)\nend probeScript', script).group(1)
        java = body.split('end if\n   put "   set the backgroundColor of me to"')[0]
        for part in ('mobileCreateLocalNotification', 'the seconds + 3600, false, 0',
                     'put the result into tId', 'tId is not an integer or tId < 1',
                     'kFailColor', 'exit openStack', 'mobileCancelLocalNotification tId'):
            self.assertIn(part, java)
        self.assertLess(java.index('mobileCreateLocalNotification'), java.index('mobileCancelLocalNotification'))
        self.assertIn('if probeName() is "AndroidJavaProbe" then', body)
        self.assertTrue(body.rstrip().endswith('"end openStack" after tScript\n   return tScript'))
        self.assertIn('set the script of stack tProbe to probeScript()', script)

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
