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

import base64
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

    EVENTS = 'echo "I/am_kill (  590): [0,3475,org.openxtalk.check.androidprobe,0,lmk]"'

    def device(self, pidof, timeout='10', power='true', events=EVENTS, cases='', argv=()):
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
                    '  "shell dumpsys power") %s ;;\n'
                    '  "logcat -d -b events -v brief") %s ;;\n'
                    '  "shell dumpsys activity exit-info"*) printf "  ApplicationExitInfo #0:\\n    pid=3612 reason=3 (LOW_MEMORY)\\n" ;;\n'
                    '  "shell cat /proc/meminfo") printf "MemTotal: 2000000 kB\\nMemFree: 1 kB\\nMemAvailable: 90000 kB\\n" ;;\n'
                    '  "shell dumpsys window") printf "  mCurrentFocus=Window{1f u0 Application Not Responding: '
                    'com.android.systemui}\\n  mFocusedApp=ActivityRecord{2e u0 '
                    'org.openxtalk.check.androidprobe/.mblandroid t9}\\n" ;;\n'
                    '%s'
                    'esac\n' % (d, pidof, d, power, events, cases))
        os.chmod(adb, 0o755)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = ac.main(['device', '--apk', self.apk, '--serial', 'emulator-5554', '--sdk', d,
                              '--timeout', timeout] + list(argv))
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
                  timeout='10'):
        """device on a running, green probe whose dialog is in front from
        the dialog_from'th look until Allow is tapped; after is what
        dumpsys package says once it is. Every command the check sends to
        the stand-in that is about the permission is kept in calls."""
        d = self.tmp.name
        for name in ('calls', 'tapped'):
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
                 '    if [ -f "%(d)s/tapped" ] || [ $(grep -c activities "%(d)s/calls") -lt %(from)d ]; then\n'
                 '      cat "%(d)s/probe.txt"; else cat "%(d)s/activities.txt"; fi ;;\n'
                 '  "shell uiautomator dump /sdcard/oxt-ui.xml") echo "$*" >> "%(d)s/calls";'
                 ' echo "UI hierchary dumped to: /sdcard/oxt-ui.xml" ;;\n'
                 '  "shell cat /sdcard/oxt-ui.xml") echo "$*" >> "%(d)s/calls"; cat "%(d)s/ui.xml" ;;\n'
                 '  "shell input tap "*) echo "$*" >> "%(d)s/calls"; echo "$*" > "%(d)s/tapped" ;;\n'
                 '  "shell dumpsys package org.openxtalk.check.androidprobe") echo "$*" >> "%(d)s/calls"\n'
                 '    if [ -f "%(d)s/tapped" ]; then cat "%(d)s/package-after.txt"; else cat "%(d)s/package.txt"; fi ;;\n'
                 % {'d': d, 'from': dialog_from})
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
        # once allowed, the check looks for the dialog no more
        self.assertEqual(calls.count('shell dumpsys activity activities'), 1)

    def test_green_before_the_dialog_does_not_end_the_wait(self):
        # the probe turns green at once, and the dialog comes after: the
        # wait goes on until it has been answered
        status, out, calls = self.run_probe(dialog_from=2)
        self.assertEqual(status, 0, out)
        self.assertEqual(calls.count('shell dumpsys activity activities'), 2)
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
        self.assertEqual(len(lines), 4, lines)
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

    def run_probe(self, pictures=SharedPictures.QUERY, said='', picture=True, colour=ac.RUN_COLOR):
        d = self.tmp.name
        with open(os.path.join(d, 'logcat.txt'), 'w') as f:
            f.write(Device.LOG.split('I/lowmemorykiller')[0] + said)
        with open(os.path.join(d, 'pictures.txt'), 'w') as f:
            f.write(pictures)
        with open(os.path.join(d, 'screen.raw'), 'wb') as f:
            f.write(struct.pack('<IIII', 4, 4, 1, 0) + bytes(list(colour) + [255]) * 16)
        cases = ('  "shell content query "*) echo "$*" >> "%(d)s/calls"; cat "%(d)s/pictures.txt" ;;\n' % {'d': d})
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
                      "the package's own (it owns no shared picture)", out)
        self.assertIn('Shared pictures the package owns: none', out)

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
        # the stack's name is said once, there: every use goes through it,
        # bar the two that ask probeName() which probe this is (its script,
        # and its build's notification permission)
        self.assertEqual(script.count('"AndroidProbe"'), 1)
        self.assertEqual(script.count('"AndroidJavaProbe"'), 3)
        self.assertEqual(script.count('if probeName() is "AndroidJavaProbe" then'), 2)

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
        self.assertTrue(body.rstrip().endswith('"end openStack" after tScript\n   return tScript'))
        self.assertIn('set the script of stack tProbe to probeScript()', script)

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
                      '      put true into tSettings["android,application permissions"]["WRITE_EXTERNAL_STORAGE"]\n'
                      '   end if\n', body)
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


if __name__ == '__main__':
    unittest.main()
