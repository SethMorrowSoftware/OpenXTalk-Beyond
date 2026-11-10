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

"""Build Android packages with the IDE's own Android builder, check them,
compare them with what another builder made, and run them on a device.

  python3 tools/ci/android_check.py extract --package FILE --dest DIR [--platform P] [--env NAME]
  python3 tools/ci/android_check.py overlay --root DIR [--classes FILE | --engine DIR]
  python3 tools/ci/android_check.py ide (--install DIR | --package FILE | --bin DIR)
      --work DIR [--sdk DIR] [--jdk DIR] [--platform P] [--device SERIAL]
      [--stack FILE] [--builds NAMES] [--no-units] [--probe java] [--timeout SECONDS]
  python3 tools/ci/android_check.py verify --work DIR --sdk DIR [--jdk DIR] [--builds NAMES]
      [--target API | --target-for DIR] [--engine DIR]
  python3 tools/ci/android_check.py compare --old DIR --new DIR --sdk DIR
  python3 tools/ci/android_check.py device --apk FILE --serial SERIAL --sdk DIR
      [--out FILE] [--abi ABI] [--timeout SECONDS] [--allow PERMISSION]
      [--bundletool JAR --jdk DIR]
  python3 tools/ci/android_check.py boot --serial SERIAL --sdk DIR [--log FILE]
      [--minutes M] [--awake] [--settle]

extract unpacks a package as tools/ci/run_livecode_check.py does (modes and
symbolic links kept) and prints the folder to give --install, and with
--env NAME also writes NAME=<folder> to $GITHUB_ENV.

overlay puts this checkout's Android builder (OVERLAY) into an installed
OXT-Beyond (a released one), over the files of the same names, so that the
release's IDE runs the changed builder, and the comparison is of the
builders alone, with the same engine and runtimes. --classes also puts a
Java layer (tools/ci/android_java.py build) in place of the release's
Runtime/Android/Classes. --engine puts a runtime folder that
tools/ci/build-android.sh wrote (the engine built here with a current NDK)
in place of the release's Android runtime: each architecture's engine and
externals over the release's, which must all be there, so that no package
mixes the two engines, and the Java layer built with them and the files
beside it.

ide starts the IDE as a user starts it (as tools/ci/web_check.py does, under
xvfb-run on Linux without a DISPLAY) with tools/ci/android-check.livecodescript
named on its command line. That script runs the units of the builder's new
handlers, which need no Android SDK, and with --sdk builds the probe stack
five times with the builder (see BUILDS) into <work>/out/<name>.apk, and the
bundle build's App Bundle beside it (<name>.aab), for which the builder
downloads bundletool once (the jar it keeps is copied to <work>/
bundletool.jar, for verify and device); with
--device it also does what the IDE's Test does for that device. Its lines go
to <work>/android-check.txt, which this prints. The release build is signed
with a keystore made here with the JDK's keytool (<work>/check.keystore).
--stack gives a probe stack file saved by an earlier run, so that two
builders build the same stack (the stack goes into the engine library).
--no-units is for a released builder, which has none of the units'
handlers. --probe java builds the Java layer's probe instead
(AndroidJavaProbe.livecode: it schedules and cancels a local notification
before it turns green, and turns FAIL_COLOR when the call answers none).

verify checks each package in <work>/out against BUILDS and the lines the
IDE wrote: the architectures it has, the signature (apksigner, and the APK
Signing Block that v2 and v3 signatures live in), zipalign, resources.arsc
stored and aligned (Android 11 and newer refuse it compressed for apps that
target API 30 and newer), every activity, service and receiver with an
intent-filter saying android:exported (Android 12 and newer refuse the app
otherwise), the 64-bit engine libraries aligned for 16 KB pages, the
package name and target API, and the builder's warnings. A bundle build's
App Bundle (verify_bundle) must hold what its package holds, keep the
native libraries compressed and the assets stored in the device's
packages, be signed by the package's signer (the JDK's jarsigner and
keytool: --jdk, or those on the PATH), and with <work>/bundletool.jar
(which must be the version the builder pins) say the package name and
target API in its manifest; no other build may leave an App Bundle.
The target API is --target's (33 when it is not given), or with
--target-for DIR the one the builder picks for the runtime of the IDE
installed in DIR (androidTargetAPI): the newest (36) when that runtime's
Java layer is ready for it (JAVA_LAYER_READY), 33 when it is not, as for
LiveCode 9.6.3's, which the runtimes carried until they carried one built
from this repository's sources (BUILDING.md, "Android Java layer").
With --engine DIR (the folder overlay --engine took), each package's
engine must be the one built there for its architecture: the same code
(the .text section, which the builder's deploy leaves as it is when it
writes the stack into the .project section).

compare checks that two sets of packages (the released builder's and the
changed one's, of the same probe stack) hold the same files with the same
bytes, apart from what the change meant to change: the signatures (see
EXPECTED_SIGNING) and, in the debug build, the push receiver's
android:exported (see EXPECTED_MANIFEST). Every difference is printed.

device installs a package on a device or emulator with adb (an App Bundle,
<name>.aab, as Google Play does: the device's split APKs that bundletool,
--bundletool, makes of it with the JDK's java, --jdk, and installs), starts it and
waits until the screen is the probe's green (kRunColor in
android-check.livecodescript), which only the probe's openStack makes: the
engine loaded, opened the stack and ran its script. The Java layer's
probe's FAIL_COLOR ends the wait too, as a failure: its script ran and a
call into the Java layer failed. With --allow PERMISSION the probe must
ask for that runtime permission: the wait goes on past its green until
Android's dialog asking for it is in front (dumpsys activity), its Allow
button is tapped (found in a uiautomator dump), and afterwards the package
must hold the permission (dumpsys package). Another app's "isn't
responding" dialog over the probe, or over that dialog, is answered with
its Wait button (at most ANR_TAPS times). The screen is saved as
a PNG (--out), and the probe's own lines in the device's log are searched
for its crash (the engine's caught attempt at an SSL library the package
does not hold is expected, and only then: crash_lines). When it is not
running, crashed or was started more than once, it prints the logs'
account of its processes, what Android did to it that the carried runtime
does not survive (paused for sleep, a changed ApplicationInfo, a relaunch),
how each process ended (dumpsys activity exit-info) and the memory left.
When that says Android's low memory killer ended one of the probe's
processes (exit-info LOW_MEMORY), none of them crashed by exit-info's
account, and each of its problems is one such a kill explains (it never
turned green, it is not running, and before its green it never asked
for --allow's permission or never exported --picture's picture: no
crash in its log, no fail colour, nothing from the checks of its green
screen), the whole run is made once more, after LOW_MEMORY_PAUSE s, and
that run decides (low_memory_kills).

boot waits until an emulator has booted (adb sees it and
sys.boot_completed is 1), saying where it is every minute. It gives up
at --minutes, or within seconds once no emulator runs and adb has no such
device, and then prints what might say why: whether the emulator still
runs, /dev/kvm, adb's devices, the free disk and the end of the emulator's
log (--log), which otherwise only reaches the workflow's artifact. With
--settle it then waits, and says for what, until a fresh image's first
minute's work is done (settle): broadcast queues idle, the package
manager idle, the enabled overlays unchanged, each waiting through a
system server that is not serving, and says if that server restarted.
With --awake, first, it puts the device to sleep once, so that what
Android keeps until the screen is off is done, wakes it, dismisses the
keyguard and keeps it awake (awake).

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later), with the Android SDK's adb,
apksigner, aapt and zipalign, and for an App Bundle the JDK's java,
jarsigner and keytool, and bundletool.
"""

import argparse
import collections
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

REPO = os.path.dirname(os.path.dirname(HERE))
CHECK_SCRIPT = os.path.join(HERE, 'android-check.livecodescript')
# The Android builder's files, which overlay copies into an installed IDE
OVERLAY = ('ide-support/revsaveasandroidstandalone.livecodescript',
           'ide-support/revdeploylibraryandroid.livecodescript',
           'ide/Toolset/palettes/standalone settings/revstandalonesettingsandroidbehavior.livecodescript')
LOG_NAME = 'android-check.txt'
IDENTIFIER = 'org.openxtalk.check.androidprobe'
# kRunColor and kSavedColor of android-check.livecodescript
RUN_COLOR = (31, 158, 90)
# A dialog that may stand in front of the probe, in any process's lines:
# another app's or the system's "isn't responding" or "keeps stopping"
DIALOGS = r"ANR in |isn't responding|keeps stopping|Showing crash dialog|Application Not Responding"
SAVED_COLOR = (204, 34, 0)
# kFailColor: the Java layer's probe ran, and a call into the Java layer
# failed
FAIL_COLOR = (230, 160, 0)
# kBackColor: the Java layer's probe got backKey (device --back), which
# it must show within BACK_WAIT seconds of the key
BACK_COLOR = (40, 90, 200)
BACK_WAIT = 20
# kWaitColor and kProbeWait: a probe's mouseUp (a tap) turns its screen
# WAIT_COLOR and waits PROBE_WAIT seconds with messages, then is green
# again (device --density-in-wait). The density is changed once that
# colour is seen, which must be within WAIT_SEEN seconds of the tap, so
# that the script is still waiting when Android makes the activity again
WAIT_COLOR = (120, 60, 160)
PROBE_WAIT = 20
WAIT_SEEN = 10
# --density-in-wait: how long the tap waits for the probe's window to have
# the focus (FOCUS_WAIT), and how many taps it is given (TAP_TRIES): a tap
# is given again only when something stood between it and the probe's
# mouseUp. In run 42558963714 (attempt 2) the API 33 image's System UI was
# not responding, three times, and Android paused the probe's activity for
# sleep just as it was tapped: the tap was lost, and the screen stayed
# green. HELD_LIMIT: how long the process the probe's script waits in may
# hold Android's thread as Android makes its activity again, from its
# activity's stop to the activity made again (wm_on_stop_called to
# wm_on_create_called): Android calls an app that does not answer a touch
# for 5 s not responding, and the engine built here once waited out the
# script's wait there (attempt 1 of that run: an ANR). SCREEN_TRIES: how
# many times the screen that says where to tap is taken, SCREEN_AGAIN s
# apart: in run 42578112540 the 16 KB image's screencap, just after the
# probe started again at the screen's own density, came back cut short
# (7116368 of its 10108816 bytes), and the step failed on it
FOCUS_WAIT = 10
TAP_TRIES = 2
HELD_LIMIT = 5
SCREEN_TRIES = 3
SCREEN_AGAIN = 1
# device --within-bars: how long the screen is taken again, every
# BARS_INTERVAL seconds, when the first green screen has the probe's green
# where a system bar is, before that is a failure. On the 16 KB Android 16
# image the same package that targets API 33 passed in other runs, and in
# run 42354758286 (attempt 2) its first green screen, 4 s after a cold
# start, was green in its bottom row: a screen taken before the bar was
# drawn over the window is not where the window is
BARS_WAIT = 8
BARS_INTERVAL = 1
# device --edge-to-edge: how long after the edge probe's green the log is
# read again for the rects it says once its window has its insets
# (kEdgeWait in android-check.livecodescript, 1 s, and time to spare)
EDGE_WAIT = 4
# The engine runs once in a process (RelaunchActivity in the Java layer
# says why): device --font-scale, --density, --density-in-wait and
# --relaunch. How long the probe is given after a change to show its green
# again (in the same process, or in a new one; a font size change first has
# FONT_SETTLE to reach it, so that the green before it is not taken for the
# green after), and how long its process to end once its stack quits; the
# font scale and the density each check sets
RETURN_WAIT = 60
FONT_SETTLE = 5
END_WAIT = 20
FONT_SCALE = '1.3'
DENSITY_SHARE = 0.85
# The probes (--probe): the stack file each is saved as
PROBES = {'app': 'AndroidProbe.livecode', 'java': 'AndroidJavaProbe.livecode', 'busy': 'AndroidBusyProbe.livecode',
          'edge': 'AndroidEdgeProbe.livecode'}
# Where a release's Java layer is (overlay --classes)
CLASSES = ('Runtime', 'Android', 'Classes')
# The name the builder gives the engine (a runtime's <abi>/Standalone) in a
# package (verify --engine)
PACKAGE_ENGINE = 'librevandroid.so'
# The API the builder targets with a runtime whose Java layer is not ready
# for newer (as before), and the newest, which it targets when it is
# (androidTargetAPI); at 36 the manifest keeps the stack's orientation on
# large screens (LARGE_SCREEN_PROPERTY)
TARGET_SDK = '33'
NEWEST_TARGET_SDK = '36'
LARGE_SCREEN_PROPERTY = 'android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY'
# What makes a runtime's Java layer ready for the newest target: the
# builder's kJavaLayerReady, the classes it looks for in the runtime's
# Classes jar (androidJavaLayerHas), byte for byte (verify --target-for)
JAVA_LAYER_READY = ('com/runrev/android/LiveCodeActivity$BackCallback.class',
                    'com/runrev/android/LiveCodeActivity$SystemBarsPadding.class')
# The App Bundle: the bundletool the builder downloads (its
# kBundletoolVersion and kBundletoolSHA256), and the name ide gives the
# jar the builder keeps, in the work folder
BUNDLETOOL_VERSION = '1.18.3'
BUNDLETOOL_SHA256 = 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29'
BUNDLETOOL_JAR = 'bundletool.jar'
# ide --bundletool-fallback: when GitHub itself answered the builder's
# download of bundletool from the release's web address with an HTTP 5xx,
# for every downloader the failure names (libURL's and the JDK's), the
# pinned jar is downloaded with gh, through GitHub's API, put where the
# builder keeps its download (the file its failure names), and the App
# Bundle built again, once. On 9 November 2026 that address answered "504
# Gateway Time-out" to the runners on and off for hours (the macOS builder
# in run 42571371034, twice, and in run 42582158750), while gh downloaded
# releases through the API on the same runners. The builder's own download
# is still tried first on every run, and a failure of any other kind (a
# stall, the wrong file) stays a failure
BUNDLETOOL_REPO = 'google/bundletool'
BUNDLETOOL_GH = 'bundletool-gh'
BUNDLE_AGAIN_LOG = 'android-check-bundle.txt'
BUNDLE_AGAIN_OUTPUT = 'ide-output-bundle.txt'
KEY_ALIAS = 'oxtcheck'
KEY_PASSWORD = 'oxtcheck-pass'
KEY_DNAME = 'CN=OXT Android Check, O=OXT-Beyond, C=US'
DEBUG_DNAME = 'CN=Android Debug, O=Android, C=US'
SIG_BLOCK_MAGIC = b'APK Sig Block 42'
PAGE_16K = 16384

# What each build of android-check.livecodescript is: its architectures,
# who signs it (None: nobody), whether it has the push receiver, the
# warnings the builder must give (each a piece of one warning line), and
# whether an App Bundle comes with it (signed as the package is)
BUILDS = {
    'debug': {'abis': {'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'}, 'signer': DEBUG_DNAME, 'push': True,
              'warnings': []},
    'release': {'abis': {'arm64-v8a', 'x86_64'}, 'signer': KEY_DNAME, 'push': False, 'warnings': []},
    'unsigned': {'abis': {'arm64-v8a'}, 'signer': None, 'push': False, 'warnings': []},
    'legacy': {'abis': {'armeabi-v7a'}, 'signer': None, 'push': False,
               'warnings': ['built for armv7 and not arm64']},
    'bundle': {'abis': {'arm64-v8a', 'x86_64'}, 'signer': KEY_DNAME, 'push': False, 'warnings': [],
               'bundle': True},
}
ABIS_64 = ('arm64-v8a', 'x86_64')

# compare: what the change made different on purpose, per build. The
# released builder left "Sign for development only" builds unsigned (its
# ApkBuilder replacement signed nothing), and signed with the user's key
# before zipalign, which took the v2 and v3 signatures off again.
EXPECTED_SIGNING = {
    'debug': 'the released builder did not sign it; now the debug key signs it',
    'release': 'the signature is made again (a new signing time); the released builder\'s lost its v2 and v3 '
               'signatures to zipalign',
    'bundle': 'the signature is made again (a new signing time); the released builder\'s lost its v2 and v3 '
              'signatures to zipalign',
}
# compare: the manifest lines (aapt's xmltree, without line numbers) the
# change added, per build. A line the old package already has is not
# expected to differ: that release's builder carries the change (0.2.7-
# rc.6.16 and later carry this one)
EXPECTED_MANIFEST = {
    'debug': ['receiver PushReceiver: android:exported=true'],
}


# compare: the manifest attributes whose value the change made different on
# purpose, in every build, and the value the new builder's has (as aapt
# prints it). The configuration changes the app goes on through
# (androidConfigChanges): LiveCode's four as before (0x6a0), and those the
# engine runs through rather than starting again in its process, which
# Android 11 and newer stop (RelaunchActivity in the Java layer says why)
EXPECTED_VALUES = {
    'configChanges': '0x50006fff',
}


def manifest_value(line):
    """(attribute, value) of an attribute line of aapt's xmltree (aapt's or
    aapt2's form) whose attribute is one of EXPECTED_VALUES, else None."""
    m = re.match(r'^\s*A: (?:\S*:)?(\w+)\(0x[0-9a-f]+\)=(?:\(type 0x[0-9a-f]+\))?(\S+)', line)
    if m and m.group(1) in EXPECTED_VALUES:
        return m.group(1), m.group(2)
    return None


def expected_values(name, gone, extra):
    """(problems, notes, gone, extra) of the manifest lines one build's two
    packages differ by (manifest_lines): a line of an attribute of
    EXPECTED_VALUES whose new value is the expected one is expected, with
    the old package's line of that attribute; any other value is a
    problem. gone and extra come back without the lines explained."""
    problems, notes = [], []
    for line in list(extra):
        got = manifest_value(line)
        if not got:
            continue
        attr, value = got
        extra.remove(line)
        old = [x for x in gone if (manifest_value(x) or ('',))[0] == attr]
        for x in old[:1]:
            gone.remove(x)
        was = manifest_value(old[0])[1] if old else 'not set'
        if value.lower() != EXPECTED_VALUES[attr]:
            problems.append('%s: android:%s is %s in the new package (the old: %s), not %s' % (
                name, attr, value, was, EXPECTED_VALUES[attr]))
        else:
            notes.append('manifest: android:%s %s, was %s' % (attr, value, was))
    return problems, notes, gone, extra


def expected_manifest(name, old_summary):
    """The lines of EXPECTED_MANIFEST that the change adds to this build's
    manifest: those the old package's manifest (manifest_summary) lacks."""
    return [x for x in EXPECTED_MANIFEST.get(name, []) if x not in old_summary]


def log(msg=''):
    print(msg, flush=True)


def gha():
    return os.environ.get('GITHUB_ACTIONS') == 'true'


def annotate(kind, msg):
    if gha():
        log('::%s::%s' % (kind, msg.replace('%', '%25').replace('\r', '').replace('\n', '%0A')))


def summary(text):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if path:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(text + '\n')


class CheckError(Exception):
    pass


def read_lines(path):
    if not os.path.isfile(path):
        return []
    with open(path, encoding='utf-8', errors='replace') as f:
        return [x.rstrip('\r\n') for x in f if x.strip()]


# ---------------------------------------------------------------------------
# The Android SDK's tools

def exe(name):
    if os.name == 'nt':
        return name + ('.bat' if name in ('apksigner', 'd8') else '.exe')
    return name


def version_key(name):
    return [int(x) if x.isdigit() else -1 for x in re.split(r'[.-]', name)]


def build_tool(sdk, name):
    """The newest build-tools' <name>, or None."""
    folder = os.path.join(sdk, 'build-tools')
    if not os.path.isdir(folder):
        return None
    for version in sorted(os.listdir(folder), key=version_key, reverse=True):
        path = os.path.join(folder, version, exe(name))
        if os.path.isfile(path):
            return path
    return None


def adb_path(sdk):
    path = os.path.join(sdk, 'platform-tools', exe('adb'))
    return path if os.path.isfile(path) else shutil.which('adb')


def run(cmd, timeout=300, check=False):
    """(exit status, stdout and stderr together as text)."""
    env = dict(os.environ)
    # the JDK's notice of this variable goes to stderr, in the output
    env.pop('JAVA_TOOL_OPTIONS', None)
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout, env=env)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise CheckError('%s: %s' % (' '.join(cmd), e))
    out = proc.stdout.decode('utf-8', 'replace')
    if check and proc.returncode != 0:
        raise CheckError('%s: exit status %d: %s' % (' '.join(cmd), proc.returncode, out.strip()[-2000:]))
    return proc.returncode, out


# ---------------------------------------------------------------------------
# Reading a package (pure functions, tested by tests/test_android_check.py)

def has_signing_block(data):
    """Whether a zip file's bytes hold an APK Signing Block: the v2, v3 and
    v4 signatures' container, just before the central directory, which
    ends with SIG_BLOCK_MAGIC."""
    end = data.rfind(b'PK\x05\x06', max(0, len(data) - 65557))
    if end < 0:
        raise CheckError('not a zip file (no end of central directory)')
    cd_offset = struct.unpack('<I', data[end + 16:end + 20])[0]
    return cd_offset >= 16 and data[cd_offset - 16:cd_offset] == SIG_BLOCK_MAGIC


def data_offset(data, info):
    """Where a zip entry's data starts in the file: after its local header,
    whose name and extra field can differ from the central directory's."""
    off = info.header_offset
    if data[off:off + 4] != b'PK\x03\x04':
        raise CheckError('%s: no local header at %d' % (info.filename, off))
    name_len, extra_len = struct.unpack('<HH', data[off + 26:off + 30])
    return off + 30 + name_len + extra_len


def varint(data, i):
    """(the protocol buffer varint at data[i], where the next field
    starts)"""
    value = shift = 0
    while True:
        if i >= len(data):
            raise CheckError('a protocol buffer cut short in a varint')
        b = data[i]
        i += 1
        value |= (b & 0x7f) << shift
        if not b & 0x80:
            return value, i
        shift += 7


def proto_fields(data):
    """A protocol buffer message's fields, in order, as (number, value): a
    varint's value as an int, a length-delimited field's bytes, a fixed
    one's bytes."""
    fields, i = [], 0
    while i < len(data):
        key, i = varint(data, i)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, i = varint(data, i)
        elif wire == 2:
            n, i = varint(data, i)
            if i + n > len(data):
                raise CheckError('a protocol buffer cut short in field %d' % number)
            value, i = data[i:i + n], i + n
        elif wire in (1, 5):
            n = 8 if wire == 1 else 4
            value, i = data[i:i + n], i + n
        else:
            raise CheckError('a protocol buffer with wire type %d (field %d)' % (wire, number))
        fields.append((number, value))
    return fields


def bundle_config(data):
    """What an App Bundle's BundleConfig.pb (bundletool's config.proto)
    says: the bundletool that made it (bundletool = 1, its version = 2),
    whether the device's packages hold the native libraries uncompressed
    (optimizations = 2, uncompress_native_libraries = 2, enabled = 1:
    None when not said, which is bundletool's default, uncompressed), and
    the files kept stored (compression = 3, uncompressed_glob = 1)."""
    r = {'version': None, 'uncompress_native_libraries': None, 'uncompressed_glob': []}
    for number, value in proto_fields(data):
        if number == 1 and isinstance(value, bytes):
            for n, v in proto_fields(value):
                if n == 2 and isinstance(v, bytes):
                    r['version'] = v.decode('utf-8', 'replace')
        elif number == 2 and isinstance(value, bytes):
            for n, v in proto_fields(value):
                if n == 2 and isinstance(v, bytes):
                    enabled = [x for k, x in proto_fields(v) if k == 1]
                    r['uncompress_native_libraries'] = bool(enabled[-1]) if enabled else False
        elif number == 3 and isinstance(value, bytes):
            r['uncompressed_glob'] += [v.decode('utf-8', 'replace') for n, v in proto_fields(value)
                                       if n == 1 and isinstance(v, bytes)]
    return r


def bundle_place(name):
    """Where a file of a package is in its App Bundle's base module (the
    builder's androidBundleModulePath, after aapt2 convert has made
    resources.arsc resources.pb), or None for one the bundle leaves out
    (the signature's files, and the jar files at the top of lib/)."""
    if name.startswith('META-INF/') or name.endswith('/'):
        return None
    if name == 'AndroidManifest.xml':
        return 'manifest/AndroidManifest.xml'
    if name == 'resources.arsc':
        return 'resources.pb'
    if name.startswith(('res/', 'assets/')):
        return name
    if name.startswith('lib/'):
        return name if name.count('/') >= 2 else None
    if '/' not in name and re.match(r'^classes\d*\.dex$', name):
        return 'dex/' + name
    return 'root/' + name


def bundle_converted(place):
    """Whether aapt2 convert rewrites a file of the base module (the
    manifest, the resource table and the resources' XML, from aapt's
    binary form to protocol buffers), so its bytes differ from the
    package's."""
    return place in ('manifest/AndroidManifest.xml', 'resources.pb') or \
        (place.startswith('res/') and place.endswith('.xml'))


def jar_signers(printcert):
    """The owners of the certificates that signed a jar, in keytool
    -printcert -jarfile's output (in English), joined by " | ", or None"""
    owners = []
    for m in re.finditer(r'(?m)^Owner:[ \t]*(.*?)[ \t\r]*$', printcert):
        if m.group(1) and m.group(1) not in owners:
            owners.append(m.group(1))
    return ' | '.join(owners) if owners else None


def installed_apks(pm_path):
    """The file names of an installed app's APKs, in pm path's output
    (package:/data/app/.../base.apk, and one line for each split)"""
    return [os.path.basename(x.strip()[8:]) for x in pm_path.splitlines() if x.strip().startswith('package:')]


def elf_load_alignments(data):
    """The p_align of each PT_LOAD segment of an ELF file."""
    if data[:4] != b'\x7fELF':
        raise CheckError('not an ELF file')
    is64 = data[4] == 2
    end = '<' if data[5] == 1 else '>'
    if is64:
        phoff, = struct.unpack(end + 'Q', data[32:40])
        phentsize, phnum = struct.unpack(end + 'HH', data[54:58])
    else:
        phoff, = struct.unpack(end + 'I', data[28:32])
        phentsize, phnum = struct.unpack(end + 'HH', data[42:46])
    aligns = []
    for i in range(phnum):
        h = data[phoff + i * phentsize:phoff + (i + 1) * phentsize]
        p_type, = struct.unpack(end + 'I', h[:4])
        if p_type != 1:
            continue
        aligns.append(struct.unpack(end + 'Q', h[48:56])[0] if is64 else struct.unpack(end + 'I', h[28:32])[0])
    return aligns


def manifest_components(xmltree):
    """The activities, activity-aliases, services, receivers and providers
    of `aapt dump xmltree <apk> AndroidManifest.xml` (aapt's or aapt2's
    form): a list of dicts with kind, name, exported (True, False or None
    when the manifest does not say) and filter (whether it has an
    intent-filter)."""
    components, stack = [], []
    for line in xmltree.splitlines():
        m = re.match(r'^(\s*)(E|A): (.*)$', line)
        if not m:
            continue
        depth, kind, rest = len(m.group(1)), m.group(2), m.group(3)
        if kind == 'E':
            name = rest.split()[0]
            while stack and stack[-1][0] >= depth:
                stack.pop()
            node = {'kind': name, 'name': None, 'exported': None, 'filter': False, 'depth': depth}
            stack.append((depth, node))
            if name in ('activity', 'activity-alias', 'service', 'receiver', 'provider') and \
                    any(x[1]['kind'] == 'application' for x in stack[:-1]):
                components.append(node)
            if name == 'intent-filter':
                for _, parent in reversed(stack[:-1]):
                    if parent in components:
                        parent['filter'] = True
                        break
            continue
        # an attribute of the element on top
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if not stack:
            continue
        node = stack[-1][1]
        a = re.match(r'^(?:\S*:)?(name|exported)\(0x[0-9a-f]+\)=(.*)$', rest)
        if not a:
            continue
        value = a.group(2).strip()
        if a.group(1) == 'name':
            q = re.match(r'^"([^"]*)"', value)
            node['name'] = q.group(1) if q else value
        else:
            low = value.lower()
            node['exported'] = low.endswith('0xffffffff') or low == 'true'
    for c in components:
        c.pop('depth', None)
    return components


def manifest_element(xmltree, kind, name):
    """The attributes of the element `kind` whose android:name is `name` in
    aapt's xmltree (aapt's or aapt2's form), attribute to value as aapt
    prints it (a string unquoted, without its Raw), or None when there is
    no such element."""
    found, node = None, None
    for line in xmltree.splitlines():
        m = re.match(r'^(\s*)(E|A): (.*)$', line)
        if not m:
            continue
        depth, what, rest = len(m.group(1)), m.group(2), m.group(3)
        if what == 'E':
            if node is not None and node.get('name') == name and found is None:
                found = node
            node = {'depth': depth} if rest.split()[0] == kind else (
                node if node is not None and depth > node['depth'] else None)
            continue
        if node is None or depth != node['depth'] + 2:
            continue
        a = re.match(r'^(?:\S*:)?(\w+)\(0x[0-9a-f]+\)=(?:\(type 0x[0-9a-f]+\))?(.*?)(?: \(Raw: .*\))?$', rest)
        if a:
            q = re.match(r'^"([^"]*)"$', a.group(2))
            node[a.group(1)] = q.group(1) if q else a.group(2)
    if found is None and node is not None and node.get('name') == name:
        found = node
    if found is not None:
        found = dict(found)
        found.pop('depth')
    return found


def manifest_properties(xmltree):
    """The <property> elements in aapt's xmltree (aapt's or aapt2's form),
    name to value as aapt prints it: a boolean's true is 0xffffffff or
    true, a string's value is unquoted."""
    props, prop = {}, None
    for line in xmltree.splitlines():
        m = re.match(r'^(\s*)(E|A): (.*)$', line)
        if not m:
            continue
        depth, kind, rest = len(m.group(1)), m.group(2), m.group(3)
        if kind == 'E':
            # the attributes that follow are this element's
            prop = {'depth': depth} if rest.split()[0] == 'property' else None
            continue
        if prop is None or depth <= prop['depth']:
            continue
        a = re.match(r'^(?:\S*:)?(name|value)\(0x[0-9a-f]+\)=(?:\(type 0x[0-9a-f]+\))?(.*?)(?: \(Raw: .*\))?$', rest)
        if a:
            q = re.match(r'^"([^"]*)"$', a.group(2))
            prop[a.group(1)] = q.group(1) if q else a.group(2)
            if 'name' in prop and 'value' in prop:
                props[prop['name']] = prop['value']
    return props


def manifest_lines(xmltree):
    """aapt's xmltree with the line numbers taken out, which move when a
    line of the manifest template moves"""
    return [re.sub(r' \(line=\d+\)', '', x).rstrip() for x in xmltree.splitlines() if x.strip()]


def screen_from_raw(data):
    """(width, height, RGBA bytes) of `adb exec-out screencap` without -p:
    width, height and format as 32-bit little-endian numbers, from Android
    9 a colour space too, then the pixels."""
    if len(data) < 12:
        raise CheckError('screencap gave %d bytes' % len(data))
    w, h, fmt = struct.unpack('<III', data[:12])
    pixels = w * h * 4
    header = len(data) - pixels
    if w == 0 or h == 0 or header not in (12, 16) or fmt not in (1, 2):
        raise CheckError('screencap: unexpected header (width %d, height %d, format %d, %d bytes)'
                         % (w, h, fmt, len(data)))
    return w, h, data[header:]


def colour_share(rgba, colour, tolerance=24, step=7):
    """The share of the pixels (every step-th) within tolerance of colour."""
    total = hits = 0
    r0, g0, b0 = colour
    for i in range(0, len(rgba) - 3, 4 * step):
        total += 1
        if abs(rgba[i] - r0) <= tolerance and abs(rgba[i + 1] - g0) <= tolerance and \
                abs(rgba[i + 2] - b0) <= tolerance:
            hits += 1
    return hits / total if total else 0.0


def row_share(rgba, width, y, colour, tolerance=24):
    """The share of the pixels of row y within tolerance of colour."""
    row = rgba[y * width * 4:(y + 1) * width * 4]
    return colour_share(row, colour, tolerance, step=1)


def bars_drawn_over(rgba, width, height, colour=RUN_COLOR):
    """Where the stack's colour shows in the screen's first or last row
    (where the status and navigation bars are): a list of 'top' and
    'bottom', each with its share, empty when neither row is mostly the
    stack's."""
    over = []
    for where, y in (('top', 0), ('bottom', height - 1)):
        part = row_share(rgba, width, y, colour) if height else 0.0
        if part >= 0.5:
            over.append('%s %.0f%%' % (where, part * 100))
    return over


def edge_rects(said):
    """The edge probe's last screenRect and effective working screenRect
    (what it said, probe_said), each as (left, top, right, bottom), or None
    when it said none."""
    rects = {'screenRect': None, 'effective working screenRect': None}
    for line in said:
        m = re.match(r'(screenRect|effective working screenRect) (-?\d+),(-?\d+),(-?\d+),(-?\d+)$', line)
        if m:
            rects[m.group(1)] = tuple(int(x) for x in m.groups()[1:])
    return rects['screenRect'], rects['effective working screenRect']


def edge_problems(screen, effective, top):
    """device --edge-to-edge: what is wrong with the edge probe's screen,
    given its screenRect and effective working screenRect (edge_rects) and
    the share of the screen's first row (the status bar's) that is its
    green: drawn edge to edge, its green shows under the see-through status
    bar, and its effective working screenRect, inside its screenRect,
    leaves the status bar out."""
    problems = []
    if top < 0.5:
        problems.append('the stack is not drawn under the status bar (%.0f%% of the screen\'s first row is its '
                        'green)' % (top * 100))
    if screen is None or effective is None:
        problems.append('the edge probe did not say its screenRect and its effective working screenRect')
        return problems
    sl, st, sr, sb = screen
    el, et, er, eb = effective
    if not (sl <= el < er <= sr and st <= et < eb <= sb):
        problems.append('its effective working screenRect (%s) is not inside its screenRect (%s)' % (
            ','.join(map(str, effective)), ','.join(map(str, screen))))
    elif et <= st:
        problems.append('its effective working screenRect (%s) does not leave the status bar out of its '
                        'screenRect (%s)' % (','.join(map(str, effective)), ','.join(map(str, screen))))
    return problems


def bars_again(adb, serial, over, seconds=None):
    """device --within-bars, when the first green screen had the stack's
    green where a bar is (over): the screen taken again every BARS_INTERVAL
    seconds, up to BARS_WAIT, until one that is the probe's green has the
    bars over it. (what bars_drawn_over says of the last such screen, how
    many screens were taken, the seconds waited)"""
    seconds = BARS_WAIT if seconds is None else seconds
    started, shots = time.time(), 0
    while over and time.time() - started < seconds:
        time.sleep(BARS_INTERVAL)
        got = screen_now(adb, serial)
        if not got:
            continue
        shots += 1
        w, h, rgba = got
        # another screen (a dialog, the probe gone) says nothing of the bars
        if colour_share(rgba, RUN_COLOR) >= 0.25:
            over = bars_drawn_over(rgba, w, h)
    return over, shots, time.time() - started


def screen_colours(rgba, top=4, step=7):
    """The screen's commonest colours (every step-th pixel), most common
    first, as [((r, g, b), share)]: what the screen showed when it was not
    the probe's green (its green dimmed under a dialog, black, white)."""
    counts = collections.Counter()
    total = 0
    for i in range(0, len(rgba) - 3, 4 * step):
        counts[(rgba[i], rgba[i + 1], rgba[i + 2])] += 1
        total += 1
    return [(c, n / total) for c, n in counts.most_common(top)] if total else []


def png_from_rgba(w, h, rgba):
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    raw = b''.join(b'\x00' + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


# What in the device's log says the app crashed or could not load its code
CRASH = r'FATAL EXCEPTION|UnsatisfiedLinkError|dlopen failed|Fatal signal|has stopped|ANR in ' + re.escape(IDENTIFIER)

# Every Android standalone asks for SSL as it starts (mblmain.cpp's
# revandroid_loadExternalLibrary("revsecurity"), LiveCode's since 2014);
# Engine.loadExternalLibrary catches the UnsatisfiedLinkError, logs it at
# info level and the engine runs on without SSL. A package built without
# SSL ("android,include revsecurity" false: the probe's) has no
# librevsecurity.so, so the miss is expected there and only there: in a
# package that holds one, a failure to load it is a problem. It is logged
# twice on newer Android (API 35): the engine's line, and before it the
# system's nativeloader at debug level.
NO_SSL = (r'^I/revandroid\(\s*\d+\): java\.lang\.UnsatisfiedLinkError: '
          r'(?:dlopen failed: library "librevsecurity\.so" not found|.*couldn\'t find "librevsecurity\.so")\s*$',
          r'^D/nativeloader\(\s*\d+\): Load librevsecurity\.so using .*: '
          r'dlopen failed: library "librevsecurity\.so" not found\s*$')


def log_pid(line):
    """The process id of a device log line in logcat's brief form
    (P/tag( pid): text), or None."""
    m = re.match(r'[VDIWEFS]/[^\n]*?\(\s*(\d+)\):', line)
    return m.group(1) if m else None


def probe_pids(logcat, pidof=''):
    """The probe's processes: the ids pidof gave, and every one the system
    started for it in this log (a crashed app may be started again)."""
    pids = set(pidof.split())
    pids.update(re.findall(r'Start proc (\d+):' + re.escape(IDENTIFIER) + r'(?=[/:\s]|$)', logcat))
    return pids


def crash_lines(logcat, apk_names, pids):
    """(the device's log lines that say the probe crashed or could not load
    its code, the lines left out as expected, how many matching lines of
    other processes were left out), for a package whose zip entries are
    apk_names. A line is the probe's when its process is one of pids or it
    names the probe (the system's "ANR in ..."); with no pid known, every
    line is (the stricter reading)."""
    has_ssl = any(n.startswith('lib/') and n.endswith('/librevsecurity.so') for n in apk_names)
    crash, expected = [], []
    others = 0
    for line in logcat.splitlines():
        if not re.search(CRASH, line):
            continue
        if pids and log_pid(line) not in pids and IDENTIFIER not in line:
            others += 1
        elif not has_ssl and any(re.search(x, line) for x in NO_SSL):
            expected.append(line.strip())
        else:
            crash.append(line.strip())
    return crash, expected, others


def probe_story(logcat, events, pids, keep=60):
    """What the device's logs say happened to the probe's processes, as
    (heading, lines) pairs, for when it is not running, crashed or was
    started more than once: its own lines at every level, the system's
    lines about it (the probe named, or "pid N" of one of its processes:
    lowmemorykiller, libprocessgroup, ActivityManager, a tombstone), the
    events buffer's (am_proc_start, am_proc_died, am_kill, am_crash, ...),
    and any line about page sizes (Android 15's 16 KB compatibility)."""
    own, system, pages = [], [], []
    pid_word = re.compile(r'\bpid[:=]?\s*(\d+)')
    for line in logcat.splitlines():
        line = line.rstrip()
        if not line:
            continue
        if pids and log_pid(line) in pids:
            own.append(line)
        elif IDENTIFIER in line or any(m in pids for m in pid_word.findall(line)):
            system.append(line)
        if re.search(r'(?i)16 ?kb|page.?size', line):
            pages.append(line)
    ev = []
    for line in events.splitlines():
        line = line.rstrip()
        fields = set(re.findall(r'(?<=[\[,])\s*(\d+)\s*(?=[,\]])', line))
        if IDENTIFIER in line or (re.match(r'[VDIWEFS]/am_', line) and fields & set(pids)):
            ev.append(line)
    return [("the probe's own lines (every level)", own[-keep:]),
            ('the system on the probe', system[-keep:]),
            ('the events buffer on the probe', ev[-keep:]),
            ('lines about page sizes', pages[-20:])]


def disturbances(logcat, events):
    """What Android did to a running probe that the carried runtime does not
    survive (it aborts on a second start in one process), each said once:
    its activity paused for sleep (the screen off or locked), its
    ApplicationInfo changed (overlays added: what relaunches it), and the
    activity relaunched. Run 42218720113 showed all three."""
    notes = []
    ev = [x for x in events.splitlines() if IDENTIFIER in x]
    if any(re.search(r'wm_pause_activity\b.*,sleep\]', x) for x in ev):
        notes.append('Android paused the probe\'s activity for sleep (wm_pause_activity: the screen was off '
                     'or locked)')
    lines = logcat.splitlines()
    for i, line in enumerate(lines):
        if re.search(r'ApplicationInfo updating for %s\b' % re.escape(IDENTIFIER), line):
            pid = log_pid(line)
            added = next((x.split('assets added:', 1)[1].strip() for x in lines[i + 1:i + 6]
                          if 'assets added:' in x and log_pid(x) == pid), '')
            notes.append('the probe\'s ApplicationInfo changed while it ran (%s)' % (
                'assets added: ' + added if added else 'ActivityThread'))
            break
    if any(re.search(r'wm_relaunch(_resume)?_activity\b', x) for x in ev):
        notes.append('Android relaunched the probe\'s activity (wm_relaunch_resume_activity), which the carried '
                     'runtime does not survive')
    return notes


# Android's dialog that asks the user for a runtime permission (the
# permission controller's GrantPermissionsActivity, which an app's
# requestPermissions starts) and its Allow button, as uiautomator dumps it
GRANT_ACTIVITY = re.compile(r'\bpermissioncontroller/\S*GrantPermissionsActivity\b')
ALLOW_BUTTON = ':id/permission_allow_button'


def asking_for_permission(activities):
    """Whether the activity in front (dumpsys activity activities: its
    topResumedActivity or mResumedActivity line) is Android's dialog that
    asks for a runtime permission."""
    return any(GRANT_ACTIVITY.search(x) for x in activities.splitlines()
               if re.search(r'\b(topResumedActivity|mResumedActivity|ResumedActivity)\b', x))


def button_centre(xml, resource_id):
    """The centre (x, y) of the first node in a uiautomator dump whose
    resource-id ends with resource_id, or None."""
    for m in re.finditer(r'<node\b[^>]*>', xml):
        node = m.group(0)
        rid = re.search(r'resource-id="([^"]*)"', node)
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
        if rid and rid.group(1).endswith(resource_id) and bounds:
            x1, y1, x2, y2 = (int(v) for v in bounds.groups())
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def allow_button(xml):
    """The centre (x, y) of the permission dialog's Allow button in a
    uiautomator dump, or None."""
    return button_centre(xml, ALLOW_BUTTON)


# Android's "isn't responding" dialog (AppNotRespondingDialog) for another
# app, in front of the probe: in run 42354758286 the 16 KB image showed
# the launcher's over the probe's green, which its scrim dimmed, and the
# probe was failed for a screen that never turned green. Its Wait button
# lets that app go on and closes the dialog; the probe's own is a failure
# (CRASH), never answered. At most ANR_TAPS times in a wait
ANR_WINDOW = re.compile(r'mCurrentFocus=Window\{[^}]*\bApplication Not Responding: ([\w.]+)\}')
WAIT_BUTTON = 'android:id/aerr_wait'
ANR_TAPS = 3
# device --allow: a tap on the dialog's Allow that the dialog did not take
# (it is still in front ALLOW_AGAIN s after the tap) is given again, at
# most ALLOW_TAPS taps in all. In run 42568140662 (attempt 1) the 16 KB
# image's launcher was not responding: its dialog was answered, the Allow
# tapped 3 s later was lost, the permission dialog stayed in front for the
# 90 s that were left, and the probe failed. A tap that was taken is not
# given again: once the dialog has gone, Allow is not looked for
ALLOW_TAPS = 3
ALLOW_AGAIN = 6


def other_anr(window):
    """The package whose "isn't responding" dialog has the focus, in
    `dumpsys window`, when it is not the probe; else None."""
    m = ANR_WINDOW.search(window)
    return m.group(1) if m and m.group(1) != IDENTIFIER else None


def answer_other_anr(a):
    """Taps Wait on another app's "isn't responding" dialog when it has the
    focus: that app's package, or None when there is no such dialog."""
    package = other_anr(a('shell', 'dumpsys', 'window')[1])
    if not package:
        return None
    a('shell', 'uiautomator', 'dump', '/sdcard/oxt-ui.xml')
    _, xml = a('shell', 'cat', '/sdcard/oxt-ui.xml')
    where = button_centre(xml, WAIT_BUTTON)
    if where:
        a('shell', 'input', 'tap', str(where[0]), str(where[1]))
        log('  %s isn\'t responding, its dialog in front of the probe: tapped Wait at %d,%d' % ((package,) + where))
    else:
        log('  %s isn\'t responding, its dialog in front of the probe, which has no Wait button yet' % package)
    return package


def permission_granted(package_dump, permission):
    """True, False, or None when the package does not ask for it at all:
    what dumpsys package says of one of its runtime permissions."""
    found = None
    for line in package_dump.splitlines():
        m = re.match(r'\s*%s: granted=(true|false)\b' % re.escape(permission), line)
        if m:
            found = found or m.group(1) == 'true'
    return found


# What the Java layer's probe says it did, one line a step: a put with no
# container is the engine's own log line on Android (tag LiveCode, at info
# level: engine/src/mblandroid.cpp, MCAndroidSystem::Debug)
PROBE_SAYS = re.compile(r'^[VDIWEF]/LiveCode\(\s*\d+\): OXT-Beyond probe: (.*?)\s*$')


def probe_said(logcat, pids=()):
    """What the probe said in the log, in order: the lines of its processes
    (pids), or every such line when no pid is known."""
    said = []
    for line in logcat.splitlines():
        m = PROBE_SAYS.match(line)
        if m and (not pids or log_pid(line) in pids):
            said.append(m.group(1))
    return said


# The shared pictures, as MediaStore lists them to the shell (content
# query): the columns asked for, and the folder an app's pictures go to
PICTURE_COLUMNS = ('_display_name', 'relative_path', 'owner_package_name')
PICTURES = 'Pictures/'


def shared_pictures(query):
    """The rows of content query's answer ("Row: N col=value, col=value"),
    each a dict of PICTURE_COLUMNS (NULL as it says it)."""
    rows = []
    for line in query.splitlines():
        m = re.match(r'\s*Row: \d+ (.*?)\s*$', line)
        if not m:
            continue
        row = {}
        for part in re.split(r', (?=(?:%s)=)' % '|'.join(PICTURE_COLUMNS), m.group(1)):
            key, _, value = part.partition('=')
            row[key] = value
        rows.append(row)
    return rows


def probe_picture(rows, name, package):
    """The row of the picture name in the shared Pictures folder that
    package owns, or None. A name that a picture there has already (one
    the package added before it was installed again, which Android no
    longer counts as its own) is named apart by Android: "name (1).png"."""
    stem, ext = os.path.splitext(name)
    pattern = re.compile(r'%s(?: \(\d+\))?%s$' % (re.escape(stem), re.escape(ext)))
    for row in rows:
        if (pattern.match(row.get('_display_name', '')) and row.get('relative_path') == PICTURES and
                row.get('owner_package_name') == package):
            return row
    return None


def ide_results(lines):
    """From the IDE's lines: units (name -> None or why it failed), builds
    (name -> apk or the failure), warnings and questions (name -> text),
    test (None, True or the failure), errors, done, and the bundletool jar
    the builder keeps (None when it did not say)."""
    r = {'units': {}, 'builds': {}, 'warnings': {}, 'asked': {}, 'test': None, 'errors': [], 'done': False,
         'bundletool': None}
    for line in lines:
        if line.startswith('UNIT OK '):
            r['units'][line[8:].strip()] = None
        elif line.startswith('UNIT FAILED '):
            name, _, why = line[12:].partition(':')
            r['units'][name.strip()] = why.strip() or 'failed'
        elif line.startswith('BUILT '):
            parts = line.split(' ', 2)
            r['builds'][parts[1]] = ('ok', parts[2] if len(parts) > 2 else '')
        elif line.startswith('BUILD FAILED '):
            parts = line.split(' ', 3)
            r['builds'][parts[2]] = ('failed', parts[3] if len(parts) > 3 else '')
        elif line.startswith('INFO bundletool '):
            r['bundletool'] = line[16:].strip()
        elif line.startswith('INFO ') and len(line.split(' ')) >= 3 and line.split(' ')[2] in ('warnings', 'asked'):
            parts = line.split(' ', 3)
            r[parts[2]][parts[1]] = parts[3] if len(parts) > 3 else ''
        elif line.startswith('TEST OK'):
            r['test'] = True
        elif line.startswith('TEST FAILED'):
            r['test'] = line[12:].strip() or 'failed'
        elif line.startswith('ERROR'):
            r['errors'].append(line)
        elif line.startswith('DONE'):
            r['done'] = True
    return r


def bundletool_refused_by_host(failure):
    """Where the builder keeps bundletool (the file its failure says to put
    it at), when the App Bundle's failure is its download of bundletool,
    and every downloader the failure names got an HTTP 5xx, GitHub's own
    error (libURL's "error 504 ...", the JDK's "Error:
    java.io.IOException: 504 ..."); None otherwise."""
    m = re.match(r'could not download bundletool, which makes the App Bundle, from \S+?: (.+) \(tried \d+ times\)\. '
                 r'Download that file and put it at (.+?), or name a bundletool jar in the ', failure or '')
    if not m:
        return None
    for error in m.group(1).split('; and the JDK could not download it: '):
        if not re.match(r'(?:error |Error: java\.io\.IOException: )5\d\d\b', error):
            return None
    return m.group(2)


def bundletool_with_gh(work):
    """The pinned bundletool (BUNDLETOOL_VERSION), downloaded with gh
    through GitHub's API into work/BUNDLETOOL_GH and checked against
    BUNDLETOOL_SHA256: (its path, None), or (None, why there is none)."""
    name = 'bundletool-all-%s.jar' % BUNDLETOOL_VERSION
    gh = shutil.which('gh')
    if not gh:
        return None, 'there is no gh'
    folder = os.path.join(work, BUNDLETOOL_GH)
    os.makedirs(folder, exist_ok=True)
    try:
        status, out = run([gh, 'release', 'download', BUNDLETOOL_VERSION, '--repo', BUNDLETOOL_REPO,
                           '--pattern', name, '--dir', folder, '--clobber'])
    except CheckError as e:
        return None, str(e)
    jar = os.path.join(folder, name)
    if status != 0 or not os.path.isfile(jar):
        return None, 'gh release download: exit status %d: %s' % (status, out.strip()[-500:])
    digest = sha256_file(jar)
    if digest != BUNDLETOOL_SHA256:
        return None, 'gh downloaded a %s whose SHA-256 is %s, not %s' % (name, digest, BUNDLETOOL_SHA256)
    return jar, None


def is_bundle_line(line):
    """Whether one of the IDE's lines is the App Bundle's (its build, what
    it warned and asked, the bundletool it kept)."""
    words = line.split(' ')
    return words[:2] in (['INFO', 'bundle'], ['BUILT', 'bundle'], ['INFO', 'bundletool']) or \
        words[:3] == ['BUILD', 'FAILED', 'bundle']


# ---------------------------------------------------------------------------
# extract and overlay

def extract(args):
    import run_livecode_check as rlc
    import ui_tour
    p = ui_tour.package.PLATFORMS[args.platform or rlc.default_platform()]
    dest = os.path.abspath(args.dest)
    os.makedirs(dest, exist_ok=True)
    try:
        top = rlc.extract_package(os.path.abspath(args.package), dest)
    except rlc.CheckError as e:
        raise CheckError(str(e))
    # as find_layout: the macOS zip holds the app itself
    root = dest if top == p.engine else os.path.join(dest, top)
    log(root)
    env = os.environ.get('GITHUB_ENV')
    if args.env and env:
        with open(env, 'a', encoding='utf-8') as f:
            f.write('%s=%s\n' % (args.env, root))
    return []


def overlay(args):
    root = os.path.abspath(args.root)
    found = {}
    for folder, _, names in os.walk(root):
        for n in names:
            found.setdefault(n, []).append(os.path.join(folder, n))
    problems = []
    for rel in OVERLAY:
        name = os.path.basename(rel)
        places = found.get(name, [])
        if len(places) != 1:
            problems.append('%s: %d files named %s, not one' % (root, len(places), name))
            continue
        shutil.copyfile(os.path.join(REPO, *rel.split('/')), places[0])
        log('%s -> %s' % (rel, os.path.relpath(places[0], root)))
    if args.classes or args.engine or args.beyond:
        places = [x for x in found.get(CLASSES[-1], [])
                  if tuple(os.path.normpath(x).split(os.sep)[-len(CLASSES):]) == CLASSES]
        if len(places) != 1:
            problems.append('%s: %d files %s, not one' % (root, len(places), '/'.join(CLASSES)))
        elif args.engine:
            problems += overlay_engine(os.path.abspath(args.engine), os.path.dirname(places[0]), root)
        elif args.beyond:
            problems += beside_engine(os.path.abspath(args.beyond), os.path.dirname(places[0]), root)
        else:
            shutil.copyfile(args.classes, places[0])
            log('%s -> %s' % (args.classes, os.path.relpath(places[0], root)))
    return problems


def overlay_engine(engine, android, root):
    """Puts the runtime folder ENGINE (tools/ci/build-android.sh's) in place
    of the release's Runtime/Android (ANDROID): every architecture's engine
    and externals, each over the release's file of that name, and the files
    beside them (the Java layer among them). Every architecture of the
    release must be in ENGINE, and every file there: a package would
    otherwise mix the two engines, or the runtime built here would lack what
    the release has."""
    import android_engine as ae
    problems, copies = [], []
    for abi in sorted(ae.ABIS):
        names = [os.path.join(abi, x) for x in (ae.ENGINE,) + ae.EXTERNALS]
        if not os.path.isdir(os.path.join(android, abi)):
            problems.append('%s has no %s folder' % (os.path.relpath(android, root), abi))
            continue
        copies += names
    copies += list(ae.TOP_FILES)
    for rel in copies:
        src, dst = os.path.join(engine, rel), os.path.join(android, rel)
        if not os.path.isfile(src):
            problems.append('%s has no %s' % (engine, rel.replace(os.sep, '/')))
        elif not os.path.isfile(dst):
            problems.append('%s has no %s to put it in place of' % (os.path.relpath(android, root),
                                                                   rel.replace(os.sep, '/')))
    if problems:
        return problems
    for rel in copies:
        shutil.copyfile(os.path.join(engine, rel), os.path.join(android, rel))
        log('%s -> %s' % (os.path.join(engine, rel), os.path.relpath(os.path.join(android, rel), root)))
    return problems


# Where the runtimes carry OXT-Beyond's own Android engine, in the
# release's Runtime/Android (the builder's androidRuntimeFolder)
BEYOND = 'Beyond'


def beside_engine(engine, android, root):
    """Puts the runtime folder ENGINE (tools/ci/build-android.sh's) beside
    the release's Runtime/Android (ANDROID), as ANDROID/BEYOND: every
    architecture's engine and externals, and the files beside them (the
    Java layer among them), the release's own runtime left as it is. A
    stack whose "android,engine" is "beyond" is built from it. Every
    architecture and file must be in ENGINE, or nothing changes: a runtime
    short of a file would build an app that the check did not mean. A
    BEYOND folder that ANDROID has already (a release's own, as the
    runtimes carry it from 0.2.7-rc.6.19 on) is taken away as a whole
    first, so that the app is built from this checkout's engine and from
    none of the release's files, never from the two mixed; a BEYOND that
    is a link or a file, not a folder of its own, is refused."""
    import android_engine as ae
    beyond = os.path.join(android, BEYOND)
    shown = os.path.relpath(beyond, root).replace(os.sep, '/')
    copies = [os.path.join(abi, x) for abi in sorted(ae.ABIS) for x in (ae.ENGINE,) + ae.EXTERNALS]
    copies += list(ae.TOP_FILES)
    problems = ['%s has no %s' % (engine, rel.replace(os.sep, '/')) for rel in copies
                if not os.path.isfile(os.path.join(engine, rel))]
    if os.path.islink(beyond) or (os.path.exists(beyond) and not os.path.isdir(beyond)):
        problems.append('%s is there already, and is not a folder' % shown)
    if problems:
        return problems
    if os.path.isdir(beyond):
        count = sum(len(names) for _, _, names in os.walk(beyond))
        shutil.rmtree(beyond)
        log('%s: the release\'s (%d files) taken away, for the one built here' % (shown, count))
    for rel in copies:
        os.makedirs(os.path.dirname(os.path.join(beyond, rel)) or beyond, exist_ok=True)
        shutil.copyfile(os.path.join(engine, rel), os.path.join(beyond, rel))
        log('%s -> %s' % (os.path.join(engine, rel), os.path.relpath(os.path.join(beyond, rel), root)))
    return problems


# ---------------------------------------------------------------------------
# ide

def make_keystore(jdk, path):
    keytool = os.path.join(jdk, 'bin', 'keytool.exe' if os.name == 'nt' else 'keytool') if jdk else None
    if not keytool or not os.path.isfile(keytool):
        keytool = shutil.which('keytool')
    if not keytool:
        raise CheckError('no keytool (the JDK\'s) to make the release build\'s keystore')
    if os.path.exists(path):
        os.remove(path)
    run([keytool, '-genkeypair', '-keystore', path, '-storetype', 'PKCS12', '-storepass', KEY_PASSWORD,
         '-keypass', KEY_PASSWORD, '-alias', KEY_ALIAS, '-keyalg', 'RSA', '-keysize', '2048', '-validity', '3650',
         '-dname', KEY_DNAME.replace(', ', ',')], check=True)


def run_ide(cmd, work, env, results, timeout, output):
    """Runs the IDE (cmd, in work, with env) until its lines (results) say
    DONE: None, or what went wrong. Its output goes to work/output."""
    import ui_tour
    if os.path.exists(results):
        os.remove(results)
    log('Running: %s' % ' '.join(cmd))
    started = progress = time.time()
    status = 'did not finish within %d seconds' % timeout
    with open(os.path.join(work, output), 'wb') as engine_log:
        kw = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else \
            {'start_new_session': True}
        proc = subprocess.Popen(cmd, cwd=work, env=env, stdout=engine_log, stderr=subprocess.STDOUT, **kw)
        try:
            while time.time() - started < timeout:
                done = read_lines(results)
                if any(x.startswith('DONE') for x in done):
                    status = None
                    break
                if proc.poll() is not None:
                    status = 'the IDE ended with exit status %s after %.0f s' % (
                        proc.returncode, time.time() - started)
                    break
                if time.time() - progress >= 15:
                    progress = time.time()
                    log('  after %.0f s: %s' % (progress - started, done[-1] if done else '(no lines yet)'))
                time.sleep(0.5)
        finally:
            ui_tour.stop(proc)
    return status


def bundle_again(cmd, work, env, results, timeout, cache, lines):
    """ide --bundletool-fallback, when GitHub's release host refused the
    builder's download of bundletool (bundletool_refused_by_host): the jar
    gh downloads is put at cache, where the builder keeps its download, and
    the IDE builds the App Bundle again, alone, with no units and no Test.
    Its lines then take the place of the first run's App Bundle lines in
    results (the IDE's lines, android-check.txt), so that ide's own count,
    and verify and device after it, read the App Bundle that was made; its
    own lines stay in work/BUNDLE_AGAIN_LOG. The problems of the run again
    (none when the IDE finished it; whether the App Bundle was built is
    for ide to say, from the lines)."""
    jar, why = bundletool_with_gh(work)
    if not jar:
        return ['GitHub\'s release host refused the builder\'s download of bundletool, and there is none to '
                'build the App Bundle again with: %s' % why]
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    shutil.copyfile(jar, cache)
    note = ('GitHub\'s release host answered the builder\'s download of bundletool with an HTTP 5xx, so gh '
            'downloaded it through GitHub\'s API (%s, SHA-256 checked), it was put at %s, where the builder '
            'keeps its download, and the App Bundle was built again' % (BUNDLETOOL_VERSION, cache))
    log('NOTE: %s' % note)
    annotate('warning', note)
    again = os.path.join(work, BUNDLE_AGAIN_LOG)
    # the App Bundle alone: no units, and no Test on a device (the first
    # run's lines say how those went)
    status = run_ide(cmd, work, dict(env, OXT_ANDROID_LOG=again.replace('\\', '/'), OXT_ANDROID_BUILDS='bundle',
                                      OXT_ANDROID_UNITS='skip', OXT_ANDROID_DEVICE=''),
                     again, timeout, BUNDLE_AGAIN_OUTPUT)
    more = read_lines(again)
    for line in more:
        log('  ide (the App Bundle again): %s' % line)
    kept = [x for x in lines if not is_bundle_line(x) and not x.startswith('DONE')]
    made = [x for x in more if is_bundle_line(x)] or \
        ['BUILD FAILED bundle the IDE did not get to it when it was built again']
    with open(results, 'w', encoding='utf-8') as f:
        f.write('\n'.join(kept + made + ['DONE']) + '\n')
    problems = ['the IDE: %s' % x for x in ide_results(more)['errors']]
    if status:
        problems.append('the IDE, building the App Bundle again, %s' % status)
        for line in read_lines(os.path.join(work, BUNDLE_AGAIN_OUTPUT))[-40:]:
            log('  ide output: %s' % line)
    return problems


def ide(args):
    import ui_tour
    package, rlc = ui_tour.package, ui_tour.rlc
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    work = os.path.abspath(args.work)
    out = os.path.join(work, 'out')
    os.makedirs(out, exist_ok=True)
    results = os.path.join(work, LOG_NAME)
    if os.path.exists(results):
        os.remove(results)
    # the document the IDE opens: a copy, as web_check.py opens its script
    document = os.path.join(work, 'oxt_android_check.livecodescript')
    shutil.copyfile(CHECK_SCRIPT, document)
    stack = os.path.join(work, PROBES[args.probe])
    if args.stack:
        if os.path.abspath(args.stack) != stack:
            shutil.copyfile(args.stack, stack)
    elif os.path.exists(stack):
        os.remove(stack)
    keystore = os.path.join(work, 'check.keystore')
    if args.sdk:
        make_keystore(args.jdk, keystore)

    def path(x):
        return x.replace('\\', '/') if x else ''
    temp_dirs, problems = [], []
    try:
        args.engine = None
        try:
            lay = rlc.find_layout(args, p, temp_dirs)
        except rlc.CheckError as e:
            raise CheckError(str(e))
        log('Layout : %s' % lay.root)
        log('Engine : %s' % lay.engine)
        env = dict(os.environ)
        env.pop('JAVA_TOOL_OPTIONS', None)
        env.update(OXT_ANDROID_LOG=path(results), OXT_ANDROID_SDK=path(args.sdk), OXT_ANDROID_JDK=path(args.jdk),
                   OXT_ANDROID_STACK=path(stack), OXT_ANDROID_OUTPUT=path(out),
                   OXT_ANDROID_BUILDS=args.builds or '', OXT_ANDROID_KEYSTORE=path(keystore),
                   OXT_ANDROID_ALIAS=KEY_ALIAS, OXT_ANDROID_PASSWORD=KEY_PASSWORD,
                   OXT_ANDROID_DEVICE=args.device or '', OXT_ANDROID_WORK=path(os.path.join(work, 'units')),
                   OXT_ANDROID_UNITS='skip' if args.no_units else '',
                   OXT_ANDROID_PROBE='' if args.probe == 'app' else args.probe,
                   OXT_ANDROID_ENGINE=args.android_engine or '')
        cmd = [lay.engine, document]
        if p.family == 'linux':
            cef = os.path.join(lay.root, 'Externals') if lay.kind == 'development' else lay.externals
            if 'LIVECODE_USE_CEF' not in env and not os.path.isfile(os.path.join(cef, 'CEF', 'libcef.so')):
                env['LIVECODE_USE_CEF'] = '0'
            if not env.get('DISPLAY'):
                xvfb = shutil.which('xvfb-run')
                if not xvfb:
                    raise CheckError('no DISPLAY and no xvfb-run')
                cmd = [xvfb, '-a', '-s', '-screen 0 1440x900x24'] + cmd
        status = run_ide(cmd, work, env, results, args.timeout, 'ide-output.txt')
        lines = read_lines(results)
        for line in lines:
            log('  ide: %s' % line)
        r = ide_results(lines)
        if status:
            problems.append('the IDE %s' % status)
            for line in read_lines(os.path.join(work, 'ide-output.txt'))[-40:]:
                log('  ide output: %s' % line)
        bundle = r['builds'].get('bundle')
        cache = bundletool_refused_by_host(bundle[1]) if args.bundletool_fallback and bundle and \
            bundle[0] != 'ok' else None
        if cache:
            problems += bundle_again(cmd, work, env, results, args.timeout, cache, lines)
            r = ide_results(read_lines(results))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    problems += ['the IDE: %s' % x for x in r['errors']]
    failed = {k: v for k, v in r['units'].items() if v}
    if not args.no_units:
        if not r['units']:
            problems.append('no units ran')
        problems += ['unit %s: %s' % (k, v) for k, v in sorted(failed.items())]
    if args.sdk:
        wanted = (args.builds or ','.join(BUILDS)).split(',')
        for name in wanted:
            state = r['builds'].get(name)
            if not state:
                problems.append('build %s: the IDE did not get to it' % name)
            elif state[0] != 'ok':
                problems.append('build %s failed: %s' % (name, state[1]))
    if args.device and r['test'] is not True:
        problems.append('Test on %s: %s' % (args.device, r['test'] or 'the IDE did not get to it'))
    # the bundletool the builder downloaded for the App Bundle, for verify
    # and device
    jar = os.path.join(work, BUNDLETOOL_JAR)
    if os.path.exists(jar):
        os.remove(jar)
    if r['bundletool'] and os.path.isfile(r['bundletool']):
        shutil.copyfile(r['bundletool'], jar)
        log('The builder\'s bundletool: %s -> %s' % (r['bundletool'], jar))
    log()
    log('Units: %d passed, %d failed' % (len(r['units']) - len(failed), len(failed)))
    log('Builds: %s' % ', '.join('%s %s' % (k, v[0]) for k, v in sorted(r['builds'].items())) or 'none')
    if args.device:
        log('Test on %s: %s' % (args.device, 'passed' if r['test'] is True else r['test']))
    return problems


# ---------------------------------------------------------------------------
# verify

def signer_dn(out):
    """The signer's DN in apksigner verify --print-certs output, or None.
    apksigner labels the line differently from one version to the next:
    "Signer #1 certificate DN: ..." (Ubuntu's, and the SDK's older ones),
    "Signer (minSdkVersion=24, maxSdkVersion=...) certificate DN: ..."
    (for v3.1 signers), and "V3.0 Signer: certificate DN: ..." (the SDK's
    build-tools on GitHub's Windows runner). Any line whose label names a
    signer counts, bar a source stamp's or a lineage's (another key's). A
    package signed with one key has one DN however many lines name it; two
    different DNs give both, joined by " | ", which no expected signer
    matches."""
    dns = []
    for m in re.finditer(r'(?mi)^([^\n]*?)\s*certificate DN:\s*(.*?)\s*$', out):
        label = m.group(1).lower()
        if not re.search(r'\bsigner\b', label) or 'stamp' in label or 'lineage' in label:
            continue
        if m.group(2) not in dns:
            dns.append(m.group(2))
    return ' | '.join(dns) if dns else None


def signing(apksigner, apk):
    """(verified, schemes verified, signer DN) by apksigner."""
    status, out = run([apksigner, 'verify', '--verbose', '--print-certs', apk])
    schemes = sorted(set(re.findall(r'Verified using (v\d) scheme[^:]*: true', out)))
    return status == 0, schemes, signer_dn(out), out


def zipalign_supports_pages(zipalign):
    _, out = run([zipalign])
    return '-P' in out


# The activity that starts the app again in a new process (the engine runs
# once in a process), and its name in a package's dex where the Java layer
# has it
RELAUNCH_ACTIVITY = 'com.runrev.android.RelaunchActivity'
RELAUNCH_DEX = b'Lcom/runrev/android/RelaunchActivity;'


def relaunch_problems(name, tree, dexes):
    """The problems of a package's manifest (aapt's xmltree) about the
    engine's one start in a process: the configuration changes the app
    goes on through are the builder's (EXPECTED_VALUES); and the activity
    that starts it again in a new process is declared, in a process of its
    own and not exported, where the package's Java layer (its dex files)
    has it, and only there."""
    problems = []
    values = dict(v for v in map(manifest_value, tree.splitlines()) if v)
    for attr, want in sorted(EXPECTED_VALUES.items()):
        if values.get(attr, '').lower() != want:
            problems.append('%s: android:%s is %s, not %s' % (name, attr, values.get(attr) or 'not set', want))
    has = any(RELAUNCH_DEX in d for d in dexes)
    declared = manifest_element(tree, 'activity', RELAUNCH_ACTIVITY)
    if has and declared is None:
        problems.append('%s: its Java layer has %s, and the manifest does not declare it (the app would start '
                        'its engine twice in a process)' % (name, RELAUNCH_ACTIVITY))
    elif declared is not None and not has:
        problems.append('%s: the manifest declares %s, which its Java layer does not have' % (name, RELAUNCH_ACTIVITY))
    elif declared is not None:
        if declared.get('process') != ':relaunch':
            problems.append('%s: %s is not in a process of its own (android:process is %s)'
                            % (name, RELAUNCH_ACTIVITY, declared.get('process') or 'not set'))
        if declared.get('exported', '').lower() not in ('0x0', 'false'):
            problems.append('%s: %s does not say android:exported="false"' % (name, RELAUNCH_ACTIVITY))
    return problems


def verify_apk(name, apk, spec, tools, warnings, target=TARGET_SDK):
    """The problems of one package, and lines saying what was checked:
    target is the API it must target."""
    problems, notes = [], []
    with open(apk, 'rb') as f:
        data = f.read()
    z = zipfile.ZipFile(apk)
    infos = {i.filename: i for i in z.infolist()}
    for required in ('AndroidManifest.xml', 'classes.dex', 'resources.arsc'):
        if required not in infos:
            problems.append('%s has no %s' % (name, required))
    arsc = infos.get('resources.arsc')
    if arsc:
        if arsc.compress_type != zipfile.ZIP_STORED:
            problems.append('%s: resources.arsc is compressed; Android 11 and newer refuse that for an app that '
                            'targets API 30 or newer' % name)
        elif data_offset(data, arsc) % 4:
            problems.append('%s: resources.arsc is not aligned to 4 bytes' % name)
        else:
            notes.append('resources.arsc stored and aligned')
    libs = {}
    for n in infos:
        m = re.match(r'^lib/([^/]+)/([^/]+\.so)$', n)
        if m:
            libs.setdefault(m.group(1), []).append(m.group(2))
    abis = set(libs)
    if abis != spec['abis']:
        problems.append('%s has native code for %s, not %s' % (name, ', '.join(sorted(abis)) or 'nothing',
                                                             ', '.join(sorted(spec['abis']))))
    for abi in sorted(abis):
        if 'librevandroid.so' not in libs[abi]:
            problems.append('%s has no lib/%s/librevandroid.so' % (name, abi))
    for abi in ABIS_64:
        for lib in libs.get(abi, []):
            n = 'lib/%s/%s' % (abi, lib)
            small = [a for a in elf_load_alignments(z.read(n)) if a < PAGE_16K]
            if small:
                problems.append('%s: %s has LOAD segments aligned to %s, under 16 KB: Android with 16 KB pages '
                                'cannot load it' % (name, n, ', '.join(str(x) for x in small)))
            info = infos[n]
            if info.compress_type == zipfile.ZIP_STORED and data_offset(data, info) % PAGE_16K:
                problems.append('%s: %s is stored and not aligned to 16 KB' % (name, n))
    if any(abi in libs for abi in ABIS_64):
        notes.append('the 64-bit engine libraries are aligned for 16 KB pages')
    # zipalign: 4 bytes, and 16 KB pages for stored libraries when it can
    za = tools.get('zipalign')
    if za:
        cmd = [za, '-c'] + (['-P', '16'] if zipalign_supports_pages(za) else []) + ['4', apk]
        status, out = run(cmd)
        if status != 0:
            problems.append('%s: %s says it is not aligned: %s' % (name, ' '.join(cmd[:-1]), out.strip()[-500:]))
        else:
            notes.append('zipalign -c%s 4' % (' -P 16' if '-P' in cmd else ''))
    # the signature
    block = has_signing_block(data)
    meta = [n for n in infos if re.match(r'^META-INF/[^/]+\.(SF|RSA|DSA|EC)$', n)]
    if spec['signer']:
        if not block:
            problems.append('%s has no APK Signing Block (no v2 or v3 signature)' % name)
        ok, schemes, dn, out = signing(tools['apksigner'], apk)
        if not ok:
            problems.append('%s: apksigner does not verify it: %s' % (name, out.strip()[-800:]))
        if 'v2' not in schemes and 'v3' not in schemes:
            problems.append('%s: no v2 or v3 signature verifies (verified: %s)' % (name, ', '.join(schemes)))
        if dn is None:
            # what apksigner said of the signer, for a format not read yet
            said = [x.strip() for x in out.splitlines() if 'DN' in x or x.lower().startswith('signer')]
            problems.append('%s: no signer DN in apksigner\'s output (its signer lines: %s)'
                            % (name, ' / '.join(said[:6]) or 'none'))
        elif dn != spec['signer']:
            problems.append('%s is signed by %s, not %s' % (name, dn, spec['signer']))
        if ok:
            notes.append('signed by %s (%s)' % (dn, ', '.join(schemes)))
    else:
        if block or meta:
            problems.append('%s is signed, and should not be (%s)' % (name, 'signing block' if block else meta))
        else:
            notes.append('not signed')
    # the manifest
    aapt = tools.get('aapt')
    if aapt:
        status, badging = run([aapt, 'dump', 'badging', apk])
        if "package: name='%s'" % IDENTIFIER not in badging:
            problems.append('%s: aapt does not name the package %s' % (name, IDENTIFIER))
        if "targetSdkVersion:'%s'" % target not in badging:
            problems.append('%s does not target API %s' % (name, target))
        status, tree = run([aapt, 'dump', 'xmltree', apk, 'AndroidManifest.xml'])
        if status != 0:
            problems.append('%s: aapt cannot read the manifest: %s' % (name, tree.strip()[-300:]))
        else:
            comps = manifest_components(tree)
            missing = ['%s %s' % (c['kind'], c['name']) for c in comps
                       if c['filter'] and c['exported'] is None and c['kind'] != 'provider']
            if missing:
                problems.append('%s: Android 12 and newer refuse it, these have an intent-filter and no '
                                'android:exported: %s' % (name, ', '.join(missing)))
            push = [c for c in comps if c['kind'] == 'receiver' and c['name'] == 'PushReceiver']
            if spec['push'] and not (push and push[0]['exported'] is True):
                problems.append('%s: the push receiver is not there with android:exported="true"' % name)
            if not spec['push'] and push:
                problems.append('%s has a push receiver' % name)
            notes.append('%d components, every one with an intent-filter says android:exported' % len(comps))
            # the stack's orientation kept on large screens at 36, and only there
            large = manifest_properties(tree).get(LARGE_SCREEN_PROPERTY)
            if int(target) >= 36 and large not in ('0xffffffff', 'true'):
                problems.append('%s targets API %s, and its manifest does not keep the stack\'s orientation on large '
                                'screens (%s is %s)' % (name, target, LARGE_SCREEN_PROPERTY, large or 'not there'))
            elif int(target) < 36 and large is not None:
                problems.append('%s: the manifest has %s, which is for a package that targets API 36 or newer '
                                '(this one must target %s)' % (name, LARGE_SCREEN_PROPERTY, target))
            said = relaunch_problems(name, tree, [z.read(n) for n in infos if re.match(r'^classes\d*\.dex$', n)])
            problems += said
            if not said:
                notes.append('the configuration changes it goes on through (android:configChanges %s), and %s'
                             % (EXPECTED_VALUES['configChanges'],
                                'the activity that starts it again in a new process' if
                                manifest_element(tree, 'activity', RELAUNCH_ACTIVITY) else
                                'no activity to start it again (its Java layer has none)'))
    # the builder's warnings
    said = warnings.get(name, '')
    for w in spec['warnings']:
        if w not in said:
            problems.append('%s: the builder did not warn "%s" (it said: %s)' % (name, w, said or 'nothing'))
    android = [x.strip() for x in said.split(' | ') if x.strip().startswith('Android:')]
    unexpected = [x for x in android if not any(w in x for w in spec['warnings'])]
    if unexpected:
        problems.append('%s: the builder warned: %s' % (name, ' | '.join(unexpected)))
    return problems, notes


def verify_bundle(name, aab, apk, spec, tools, target=TARGET_SDK):
    """The problems of one build's App Bundle (aab, beside its package apk),
    and lines saying what was checked. tools may name the JDK's jarsigner,
    keytool and java, and bundletool (the jar)."""
    problems, notes = [], []
    zb, za = zipfile.ZipFile(aab), zipfile.ZipFile(apk)
    held = {i.filename for i in zb.infolist() if not i.filename.endswith('/')}
    for required in ('BundleConfig.pb', 'base/manifest/AndroidManifest.xml', 'base/resources.pb',
                     'base/dex/classes.dex'):
        if required not in held:
            problems.append('%s.aab has no %s' % (name, required))
    # what the package holds, in the base module: the same bytes, bar what
    # aapt2 converts
    wanted = {}
    for n in za.namelist():
        place = bundle_place(n)
        if place:
            wanted['base/' + place] = n
    missing = sorted(x for x in wanted if x not in held)
    if missing:
        problems.append('%s.aab does not hold these files of %s.apk: %s' % (name, name, ', '.join(missing)))
    differ = sorted(x for x in wanted if x in held and not bundle_converted(x[5:]) and zb.read(x) != za.read(wanted[x]))
    if differ:
        problems.append('%s.aab: these differ from %s.apk\'s: %s' % (name, name, ', '.join(differ)))
    extra = sorted(x for x in held if x.startswith('base/') and x not in wanted and
                   x not in ('base/assets.pb', 'base/native.pb'))
    if extra:
        problems.append('%s.aab holds files %s.apk does not: %s' % (name, name, ', '.join(extra)))
    if not (missing or differ or extra):
        notes.append('it holds the %d files of %s.apk' % (len(wanted), name))
    abis = {x.split('/')[2] for x in held if re.match(r'^base/lib/[^/]+/[^/]+\.so$', x)}
    if abis != spec['abis']:
        problems.append('%s.aab has native code for %s, not %s' % (name, ', '.join(sorted(abis)) or 'nothing',
                                                                 ', '.join(sorted(spec['abis']))))
    # bundletool's settings for the device's packages
    if 'BundleConfig.pb' in held:
        config = bundle_config(zb.read('BundleConfig.pb'))
        before = len(problems)
        if config['uncompress_native_libraries'] is not False:
            problems.append('%s.aab: the device\'s packages would hold the native libraries uncompressed, where '
                            'Android does not extract them and the engine does not load them (BundleConfig.pb: '
                            'uncompressNativeLibraries is %s)' % (name, {None: 'not said', True: 'enabled'}[
                                config['uncompress_native_libraries']]))
        if 'assets/**' not in config['uncompressed_glob']:
            problems.append('%s.aab: the device\'s packages would compress the assets, which the engine opens at '
                            'their place in the package (BundleConfig.pb: uncompressedGlob %s)'
                            % (name, config['uncompressed_glob'] or 'not said'))
        if config['version'] != BUNDLETOOL_VERSION:
            problems.append('%s.aab was made by bundletool %s, not %s' % (name, config['version'],
                                                                         BUNDLETOOL_VERSION))
        if len(problems) == before:
            notes.append('bundletool %s, native libraries compressed, assets stored' % config['version'])
    # the signature
    meta = [n for n in held if re.match(r'^META-INF/[^/]+\.(SF|RSA|DSA|EC)$', n)]
    if spec['signer']:
        if not meta:
            problems.append('%s.aab is not signed' % name)
        if not (tools.get('jarsigner') and tools.get('keytool')):
            problems.append('%s.aab: no jarsigner and keytool (the JDK\'s, --jdk) to check its signature' % name)
        else:
            status, out = run([tools['jarsigner'], '-J-Duser.language=en', '-verify', aab])
            # jarsigner answers 0 for a jar with no signature too
            verified = status == 0 and 'jar verified' in out
            if not verified:
                problems.append('%s.aab: jarsigner does not verify it: %s' % (name, out.strip()[-500:]))
            _, printcert = run([tools['keytool'], '-J-Duser.language=en', '-printcert', '-jarfile', aab])
            signer = jar_signers(printcert)
            if signer != spec['signer']:
                problems.append('%s.aab is signed by %s, not %s' % (name, signer, spec['signer']))
            elif verified:
                notes.append('signed by %s (jarsigner verifies it)' % signer)
    elif meta:
        problems.append('%s.aab is signed, and should not be (%s)' % (name, ', '.join(sorted(meta))))
    # the manifest, by bundletool
    if tools.get('bundletool') and tools.get('java'):
        before = len(problems)
        status, out = run([tools['java'], '-jar', tools['bundletool'], 'validate', '--bundle', aab])
        if status != 0:
            problems.append('%s.aab: bundletool does not take it: %s' % (name, out.strip()[-500:]))
        status, manifest = run([tools['java'], '-jar', tools['bundletool'], 'dump', 'manifest', '--bundle', aab])
        if status != 0:
            problems.append('%s.aab: bundletool cannot read its manifest: %s' % (name, manifest.strip()[-500:]))
        else:
            if 'package="%s"' % IDENTIFIER not in manifest:
                problems.append('%s.aab: its manifest does not name the package %s' % (name, IDENTIFIER))
            if 'android:targetSdkVersion="%s"' % target not in manifest:
                problems.append('%s.aab does not target API %s' % (name, target))
            large = re.search(r'<property android:name="%s" android:value="([^"]*)"' %
                              re.escape(LARGE_SCREEN_PROPERTY), manifest)
            if int(target) >= 36 and not (large and large.group(1) == 'true'):
                problems.append('%s.aab targets API %s, and its manifest does not keep the stack\'s orientation on '
                                'large screens' % (name, target))
            elif int(target) < 36 and large:
                problems.append('%s.aab: the manifest has %s, which is for API 36 and newer' % (
                    name, LARGE_SCREEN_PROPERTY))
        if len(problems) == before:
            notes.append('bundletool takes it; its manifest names the package and targets API %s' % target)
    else:
        problems.append('%s.aab: no bundletool (%s) and java to read its manifest' % (name, BUNDLETOOL_JAR))
    return problems, notes


def jdk_tool(jdk, name):
    """The JDK's tool name (in jdk/bin, or on the PATH), or None"""
    if jdk:
        path = os.path.join(jdk, 'bin', name + ('.exe' if os.name == 'nt' else ''))
        if os.path.isfile(path):
            return path
    return shutil.which(name)


def find_tools(sdk):
    tools = {'apksigner': build_tool(sdk, 'apksigner'), 'aapt': build_tool(sdk, 'aapt'),
             'zipalign': build_tool(sdk, 'zipalign')}
    if not tools['apksigner']:
        raise CheckError('no apksigner in %s/build-tools' % sdk)
    return tools


def sha256_file(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def release_classes(root):
    """The Java layer (CLASSES) of the IDE installed in ROOT, and the
    problems if there is not exactly one"""
    places = []
    for folder, _, names in os.walk(root):
        if CLASSES[-1] in names:
            place = os.path.join(folder, CLASSES[-1])
            if tuple(os.path.normpath(place).split(os.sep)[-len(CLASSES):]) == CLASSES:
                places.append(place)
    if len(places) != 1:
        return None, ['%s: %d files %s, not one' % (root, len(places), '/'.join(CLASSES))]
    return places[0], []


def builder_target(root):
    """The API the builder targets with the runtime of the IDE installed
    in ROOT, as androidTargetAPI picks it for a stack that pins none: the
    newest when the runtime's Java layer has every class of
    JAVA_LAYER_READY (looked for in the jar's bytes, as
    androidJavaLayerHas does), 33 when it has not. Returns (target, what
    decided it, problems)"""
    classes, problems = release_classes(os.path.abspath(root))
    if problems:
        return None, None, problems
    with open(classes, 'rb') as f:
        jar = f.read()
    missing = [x for x in JAVA_LAYER_READY if x.encode('utf-8') not in jar]
    if missing:
        return TARGET_SDK, '%s has no %s' % (classes, ', '.join(missing)), []
    return NEWEST_TARGET_SDK, '%s has %s' % (classes, ', '.join(JAVA_LAYER_READY)), []


def verify(args):
    work = os.path.abspath(args.work)
    if args.target_for:
        target, why, problems = builder_target(args.target_for)
        if problems:
            return problems
        log('The builder targets API %s with that runtime: %s' % (target, why))
        args.target = target
    tools = find_tools(args.sdk)
    r = ide_results(read_lines(os.path.join(work, LOG_NAME)))
    problems = []
    names = (args.builds or ','.join(BUILDS)).split(',')
    bundles = [n for n in names if BUILDS[n].get('bundle')]
    if bundles:
        # the JDK's tools, and the bundletool the builder kept (ide copied
        # it): the version it pins
        for tool in ('jarsigner', 'keytool', 'java'):
            tools[tool] = jdk_tool(args.jdk, tool)
        jar = os.path.join(work, BUNDLETOOL_JAR)
        if os.path.isfile(jar):
            digest = sha256_file(jar)
            if digest != BUNDLETOOL_SHA256:
                problems.append('the builder kept a bundletool that is not the one it pins (SHA-256 %s, not %s)'
                                % (digest, BUNDLETOOL_SHA256))
            else:
                log('The builder\'s bundletool: %s, SHA-256 %s' % (BUNDLETOOL_VERSION, digest))
                tools['bundletool'] = jar
    for name in names:
        apk = os.path.join(work, 'out', name + '.apk')
        if not os.path.isfile(apk):
            problems.append('there is no %s' % apk)
            continue
        p, notes = verify_apk(name, apk, BUILDS[name], tools, r['warnings'], args.target)
        if args.engine:
            more, said = verify_engine(name, apk, os.path.abspath(args.engine))
            p, notes = p + more, notes + said
        log('%s.apk (%.1f MB): %s' % (name, os.path.getsize(apk) / 1e6, '; '.join(notes)))
        for x in p:
            log('  PROBLEM: %s' % x)
        problems += p
        if name in bundles:
            aab = os.path.join(work, 'out', name + '.aab')
            if not os.path.isfile(aab):
                problems.append('there is no %s (the build asked for an App Bundle)' % aab)
                continue
            p, notes = verify_bundle(name, aab, apk, BUILDS[name], tools, args.target)
            log('%s.aab (%.1f MB): %s' % (name, os.path.getsize(aab) / 1e6, '; '.join(notes)))
            for x in p:
                log('  PROBLEM: %s' % x)
            problems += p
    # an App Bundle only where a build asked for one
    leftovers = [x for x in os.listdir(os.path.join(work, 'out'))
                 if not x.endswith('.apk') and not (x.endswith('.aab') and x[:-4] in bundles)]
    if leftovers:
        problems.append('the builder left other files beside the packages: %s' % ', '.join(sorted(leftovers)))
    return problems


def engine_code(data):
    """An engine library's code: its .text section, which the builder's
    deploy (MCDeployToELF) writes out as it was, since it changes only what
    comes from the .project section on"""
    import android_engine as ae
    elf = ae.Elf(data)
    for s in elf.sections:
        if s['name'] == '.text' and s['type'] != ae.SHT_NOBITS:
            if s['offset'] + s['size'] > len(data):
                raise ae.ElfError('.text runs past the end of the file')
            return data[s['offset']:s['offset'] + s['size']]
    raise ae.ElfError('no .text section')


def verify_engine(name, apk, engine):
    """The problems of a package whose engine is not, for each of its
    architectures, the one in the runtime folder ENGINE (overlay --engine),
    and a line saying what was checked."""
    import android_engine as ae
    problems, abis = [], []
    with zipfile.ZipFile(apk) as z:
        for n in sorted(z.namelist()):
            m = re.match(r'^lib/([^/]+)/%s$' % re.escape(PACKAGE_ENGINE), n)
            if not m:
                continue
            abi = m.group(1)
            built = os.path.join(engine, abi, ae.ENGINE)
            try:
                with open(built, 'rb') as f:
                    want = engine_code(f.read())
                have = engine_code(z.read(n))
            except (OSError, ae.ElfError) as e:
                problems.append('%s: %s against %s: %s' % (name, n, built, e))
                continue
            if have != want:
                problems.append('%s: %s is not the engine built in %s (its code is not %s/%s\'s)'
                                % (name, n, engine, abi, ae.ENGINE))
            else:
                abis.append(abi)
    if not abis and not problems:
        problems.append('%s has no engine (lib/<abi>/%s)' % (name, PACKAGE_ENGINE))
    return problems, (['the engine built here (%s)' % ', '.join(abis)] if abis and not problems else [])


# ---------------------------------------------------------------------------
# compare

def manifest_summary(xmltree):
    """'<kind> <name>: android:exported=<value>' for every component, for
    the comparison"""
    return ['%s %s: android:exported=%s' % (c['kind'], c['name'],
                                           {True: 'true', False: 'false', None: '(not set)'}[c['exported']])
            for c in manifest_components(xmltree)]


def compare_apks(name, old, new, aapt=None):
    """(problems, notes) of one build's two packages."""
    problems, notes = [], []
    zo, zn = zipfile.ZipFile(old), zipfile.ZipFile(new)

    def files(z):
        # zip's directory entries (the released builder's shell zip wrote
        # them) and the signature's files are left out
        return {i.filename for i in z.infolist() if not i.filename.endswith('/') and
                not re.match(r'^META-INF/', i.filename)}
    fo, fn = files(zo), files(zn)
    if fo - fn:
        problems.append('%s: only the old package has %s' % (name, ', '.join(sorted(fo - fn))))
    if fn - fo:
        problems.append('%s: only the new package has %s' % (name, ', '.join(sorted(fn - fo))))
    same = []
    for n in sorted(fo & fn):
        if zo.read(n) == zn.read(n):
            same.append(n)
        elif n != 'AndroidManifest.xml':
            problems.append('%s: %s differs' % (name, n))
    notes.append('%d of %d files the same' % (len(same), len(fo | fn)))
    if 'AndroidManifest.xml' in fo & fn and 'AndroidManifest.xml' not in same:
        if not aapt:
            problems.append('%s: the manifest differs (no aapt to say how)' % name)
        else:
            mo = manifest_summary(run([aapt, 'dump', 'xmltree', old, 'AndroidManifest.xml'], check=True)[1])
            mn = manifest_summary(run([aapt, 'dump', 'xmltree', new, 'AndroidManifest.xml'], check=True)[1])
            added = [x for x in mn if x not in mo]
            removed = [x for x in mo if x not in mn]
            expected = expected_manifest(name, mo)
            if sorted(added) != sorted(expected) or len(removed) != len(added):
                problems.append('%s: the manifest changed: %s' % (
                    name, '; '.join(['- ' + x for x in removed] + ['+ ' + x for x in added]) or
                    'outside the components'))
            else:
                notes.append('manifest: %s' % '; '.join(['- ' + x for x in removed] + ['+ ' + x for x in added]))
            # anything else in the manifest must be the same
            to = manifest_lines(run([aapt, 'dump', 'xmltree', old, 'AndroidManifest.xml'], check=True)[1])
            tn = manifest_lines(run([aapt, 'dump', 'xmltree', new, 'AndroidManifest.xml'], check=True)[1])
            extra = [x for x in tn if x not in to and 'exported' not in x]
            gone = [x for x in to if x not in tn]
            said, told, gone, extra = expected_values(name, gone, extra)
            problems += said
            notes += told
            if extra or gone:
                problems.append('%s: other manifest lines changed: %s' % (
                    name, '; '.join(['- ' + x.strip() for x in gone] + ['+ ' + x.strip() for x in extra])))
    elif name in EXPECTED_MANIFEST:
        if not aapt:
            problems.append('%s: the manifest is the same, and should have %s' % (name, EXPECTED_MANIFEST[name]))
        else:
            mo = manifest_summary(run([aapt, 'dump', 'xmltree', old, 'AndroidManifest.xml'], check=True)[1])
            missing = expected_manifest(name, mo)
            if missing:
                problems.append('%s: the manifest is the same, and should have %s' % (name, missing))
            else:
                notes.append('manifest: the same, and the old one has %s already (its builder carries the '
                             'change)' % '; '.join(EXPECTED_MANIFEST[name]))
    so = {i.filename for i in zo.infolist() if i.filename.startswith('META-INF/')}
    sn = {i.filename for i in zn.infolist() if i.filename.startswith('META-INF/')}
    sig_same = so == sn and all(zo.read(x) == zn.read(x) for x in so)
    with open(old, 'rb') as f:
        bo = has_signing_block(f.read())
    with open(new, 'rb') as f:
        bn = has_signing_block(f.read())
    if sig_same and bo == bn:
        if name in EXPECTED_SIGNING and BUILDS.get(name, {}).get('signer'):
            notes.append('the signatures are the same')
    elif name in EXPECTED_SIGNING:
        notes.append('signature: %s' % EXPECTED_SIGNING[name])
    else:
        problems.append('%s: the signature changed (old: %s, signing block %s; new: %s, signing block %s)' % (
            name, ', '.join(sorted(so)) or 'none', bo, ', '.join(sorted(sn)) or 'none', bn))
    return problems, notes


def compare(args):
    problems = []
    aapt = build_tool(args.sdk, 'aapt') if args.sdk else None
    apksigner = build_tool(args.sdk, 'apksigner') if args.sdk else None
    names = (args.builds or ','.join(BUILDS)).split(',')
    for name in names:
        old = os.path.join(args.old, 'out', name + '.apk')
        new = os.path.join(args.new, 'out', name + '.apk')
        if not (os.path.isfile(old) and os.path.isfile(new)):
            problems.append('%s: missing %s' % (name, old if not os.path.isfile(old) else new))
            continue
        p, notes = compare_apks(name, old, new, aapt)
        if apksigner:
            for label, apk in (('old', old), ('new', new)):
                ok, schemes, dn, _ = signing(apksigner, apk)
                notes.append('%s: %s' % (label, 'verifies, %s, %s' % (', '.join(schemes), dn) if ok
                                         else 'does not verify (Android will not install it)'))
        log('%s: %s' % (name, '; '.join(notes)))
        for x in p:
            log('  PROBLEM: %s' % x)
        problems += p
    return problems


# ---------------------------------------------------------------------------
# device

def install_bundle(args, adb, a):
    """Installs the App Bundle args.apk as Google Play does: bundletool
    makes the device's split APKs of it (build-apks --connected-device,
    signed with a key made here) and installs them (install-apks). Returns
    the problems, none when it is installed as more than one APK."""
    name = os.path.basename(args.apk)
    java = jdk_tool(args.jdk, 'java')
    if not (args.bundletool and os.path.isfile(args.bundletool)):
        return ['%s is an App Bundle, and there is no bundletool to install it (--bundletool: %s)'
                % (name, args.bundletool or 'not given')]
    if not java:
        return ['%s is an App Bundle, and there is no java (the JDK\'s, --jdk) to run bundletool' % name]
    import tempfile
    tmp = tempfile.mkdtemp(prefix='oxt-apks-')
    try:
        keystore = os.path.join(tmp, 'apks.keystore')
        make_keystore(args.jdk, keystore)
        apks = os.path.join(tmp, 'bundle.apks')
        status, out = run([java, '-jar', args.bundletool, 'build-apks', '--bundle', args.apk, '--output', apks,
                           '--connected-device', '--device-id', args.serial, '--adb', adb,
                           '--ks', keystore, '--ks-pass', 'pass:' + KEY_PASSWORD, '--ks-key-alias', KEY_ALIAS,
                           '--key-pass', 'pass:' + KEY_PASSWORD], timeout=600)
        if status != 0 or not os.path.isfile(apks):
            return ['bundletool makes no APKs of %s for %s: %s' % (name, args.serial, out.strip()[-800:])]
        with zipfile.ZipFile(apks) as z:
            made = sorted(os.path.basename(n) for n in z.namelist() if n.endswith('.apk'))
        log('bundletool made %d APKs of %s for the device: %s' % (len(made), name, ', '.join(made)))
        status, out = run([java, '-jar', args.bundletool, 'install-apks', '--apks', apks,
                           '--device-id', args.serial, '--adb', adb], timeout=600)
        if status != 0:
            return ['%s does not install on %s: %s' % (name, args.serial, out.strip()[-800:])]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    _, paths = a('shell', 'pm', 'path', IDENTIFIER)
    installed = installed_apks(paths)
    log('Installed %s as %d APKs: %s' % (name, len(installed), ', '.join(installed) or 'none'))
    if len(installed) < 2:
        return ['%s is installed as %s, not as split APKs as Google Play installs it (pm path: %s)'
                % (name, ', '.join(installed) or 'nothing', paths.strip()[-300:] or 'no answer')]
    return []


# How long device waits, after installing the probe, for each of: the
# broadcasts the install set off, and the package manager's handler
QUIET_SECONDS = 120


def quiet_after_install(a, seconds=QUIET_SECONDS):
    """After the probe is installed and before it starts: until the
    broadcast queues are idle (am wait-for-broadcast-idle) and the package
    manager's handler is idle (pm wait-for-handler), at most `seconds` each,
    as boot --settle waits after booting. An install wakes many of the
    system's apps (its PACKAGE_ADDED receivers), and each holds a
    foreground priority while its receiver runs. In run 42324548829 the
    Java layer's probe on the 16 KB image at API 36 started into that (the
    launcher, MediaProvider, the IMS resolver, Blockstore and the app
    indexer were taking the install), behind its notification permission
    dialog, so visible but not in front (oom_score_adj 101), and lmkd killed
    it, with 3 GB on the device and 1.7 GB available a second later ("min
    watermark is breached even after kill"; exit-info LOW_MEMORY); run
    42312203693, at 1536 MB, the same. A wait that does not end, or a
    command that cannot say, is said, and the run goes on: this decides
    nothing. `a` runs adb on the device."""
    said = []
    for what, cmd in (('the broadcast queues are idle', ('am', 'wait-for-broadcast-idle')),
                      ("the package manager's handler is idle",
                       ('pm', 'wait-for-handler', '--timeout', str(seconds * 1000)))):
        name = ' '.join(cmd[:2])
        start = time.monotonic()
        try:
            status, out = a('shell', *cmd, timeout=seconds + 10)
        except CheckError:
            said.append('%s: not in %d s (%s)' % (what, seconds, name))
            continue
        if status != 0 or re.search(NOT_SERVING, out) or re.search(r'(?i)unknown (command|option)|error', out):
            said.append('%s: %s cannot say (exit status %d: %s)' % (what, name, status, answer(out) or 'nothing'))
        else:
            said.append('%s after %d s (%s)' % (what, time.monotonic() - start, name))
    log('Before it starts: %s' % '; '.join(said))
    return said


# MediaProvider's account, in the device's log, of the probe's package
# removed: it orphans the package's shared media (their owner is cleared),
# found by the package's name, in a job of its own (onPackageOrphaned, which
# says "Deleted N Android/media items belonging to <package>" and "Orphaned
# N items belonging to <package>"; an older one may say a line only when
# N is not 0, and the wait then ends at its limit)
REMOVAL_TAKEN = r'(Deleted|Orphaned) (\d+) (?:Android/media )?items belonging to %s(?=\s|$)'
REMOVAL_WAIT = 60
REMOVAL_INTERVAL = 2


def removal_taken(a, seconds=None):
    """With device --picture, after the probe is uninstalled and before it
    is installed again: until MediaProvider has taken the removal (it says
    so in the log, which was cleared before the uninstall: REMOVAL_TAKEN),
    at most `seconds` (REMOVAL_WAIT). Its job may run after the probe is
    installed again, and orphans by the package's name what the new install
    exported too: in run 42359925885 the Java layer's probe on the 16 KB
    image exported its picture, MediaProvider took the plain probe's
    removal only after that (the log, cleared after the install, has its
    "Orphaned 1 items belonging to org.openxtalk.check.androidprobe"), and
    the package owned no picture. A wait that ends without it is said, and
    the run goes on: this decides nothing. `a` runs adb on the device.
    Returns what it logged."""
    seconds = REMOVAL_WAIT if seconds is None else seconds
    pattern = REMOVAL_TAKEN % re.escape(IDENTIFIER)
    started = time.monotonic()
    while True:
        _, out = a('logcat', '-d', '-s', 'MediaProvider')
        found = re.findall(pattern, out)
        took = time.monotonic() - started
        if found:
            said = ('Before it is installed: MediaProvider took the removal of the package after %d s (%s)'
                    % (took, '; '.join('%s %s' % (kind.lower(), n) for kind, n in found)))
            break
        if took >= seconds:
            said = ('NOTE: MediaProvider has not said in %d s that it took the removal of the package; '
                    'a picture the probe exports may lose its owner when it does' % seconds)
            break
        time.sleep(REMOVAL_INTERVAL)
    log(said)
    return said


def screen_now(adb, serial):
    """(width, height, rgba) of the device's screen now, or None when
    screencap gives none."""
    try:
        proc = subprocess.run([adb, '-s', serial, 'exec-out', 'screencap'], stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, timeout=60)
        return screen_from_raw(proc.stdout)
    except (CheckError, subprocess.TimeoutExpired) as e:
        log('  screencap: %s' % e)
        return None


# How often pid_now asks again when adb itself fails, and how long it
# waits for the device each time
PID_TRIES = 3
DEVICE_WAIT = 60


# The shell's answer where it has no pidof: Android 5's toolbox (toybox,
# which has one, came with Android 6)
NO_PIDOF = r'\bpidof: (?:inaccessible or )?not found'


def pids_in_ps(out, name=IDENTIFIER):
    """The process ids of `name` in a listing of ps (Android 5's toolbox:
    USER PID PPID VSIZE RSS WCHAN PC NAME, the name last), as pidof gives
    them: '' when it is not running."""
    pids = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) > 2 and parts[-1] == name and parts[1].isdigit():
            pids.append(parts[1])
    return ' '.join(pids)


def pid_now(a, tries=None):
    """The probe's process ids now, as pidof gives them ('' when it is not
    running). An answer that is not process ids is adb's own failure, not
    the probe's: in run 42360582880 the 16 KB image's pidof, just before
    the font size change, answered "adb: device offline", which the check
    then took for the probe's process. So it waits for the device (adb
    wait-for-device, at most DEVICE_WAIT s) and asks again, at most
    `tries` times (PID_TRIES), and then gives adb's answer, which no process
    id equals. On a shell with no pidof (NO_PIDOF: Android 5), ps says
    (pids_in_ps). `a` runs adb on the device."""
    tries = PID_TRIES if tries is None else tries
    out = ''
    for _ in range(tries):
        out = a('shell', 'pidof', IDENTIFIER)[1].strip()
        if re.search(NO_PIDOF, out):
            # Android 5's shell has no pidof: its ps says
            return pids_in_ps(a('shell', 'ps')[1])
        if re.fullmatch(r'[\d\s]*', out):
            return out
        log('  pidof: %s; waiting for the device' % answer(out))
        try:
            a('wait-for-device', timeout=DEVICE_WAIT)
        except CheckError as e:
            log('  wait-for-device: %s' % e)
    return out


def green_again(adb, serial, a, seconds, other_than=''):
    """Waits at most `seconds` for the probe's green, in a process other
    than other_than when one is given (the probe started again): (the share
    of the screen that is its green, its process, the screen as width,
    height, rgba)."""
    started = time.time()
    share, pid, shot = 0.0, '', None
    anr_taps = 0
    while time.time() - started < seconds:
        time.sleep(2)
        pid = pid_now(a)
        if other_than and pid == other_than:
            continue
        got = screen_now(adb, serial)
        if not got:
            continue
        shot = got
        share = colour_share(got[2], RUN_COLOR)
        if share >= 0.25 and pid:
            break
        if share < 0.25 and anr_taps < ANR_TAPS and answer_other_anr(a):
            anr_taps += 1
    return share, pid, shot


def save_screen(path, shot, what):
    if path and shot:
        with open(path, 'wb') as f:
            f.write(png_from_rgba(*shot))
        log('Screen %s: %s' % (what, path))


def new_crashes(a, names, before=''):
    """The probe's crash lines in the device's log since it was last
    cleared (crash_lines), and its processes there. before: the probe's
    process before the change, whose lines are the probe's too: it started
    before the log was cleared, so no "Start proc" line names it, and when
    Android makes the activity again there and the app starts again in a
    new process, a crash there was taken for another app's (run
    42430696858's onConfigurationChanged, unseen until the back key of
    --relaunch closed its dialog)"""
    _, logcat = a('logcat', '-d', '-v', 'brief')
    pids = probe_pids(logcat, ' '.join((pid_now(a), before)))
    crash, _, _ = crash_lines(logcat, names, pids)
    fdsan = [x.strip() for x in logcat.splitlines() if 'fdsan:' in x and (log_pid(x) in pids or not pids)]
    return crash + [x for x in fdsan if x not in crash], pids


# The Java layer's line when, as the activity went, it let the engine
# finish showing what it drew (Engine.finishDrawing)
FINISHED_DRAWING = 'finishDrawing:'


def drawing_finished(a, pid):
    """The Java layer's FINISHED_DRAWING lines of process pid in the
    device's log: the engine was in the middle of showing what it drew as
    Android made pid's activity again, and finished it first (where LiveCode
    9.6.3's engine hung, its screen black)."""
    _, logcat = a('logcat', '-d', '-v', 'brief')
    return [x.strip() for x in logcat.splitlines() if FINISHED_DRAWING in x and log_pid(x) == pid]


def stays_through_font_scale(args, adb, a, pid, names):
    """--font-scale: the probe goes on through a font size change, in its
    process, still showing its green (the manifest's configChanges lists
    fontScale; before, Android made the activity again, and the engine's
    second start in the process was stopped)."""
    _, before = a('shell', 'settings', 'get', 'system', 'font_scale')
    before = before.strip()
    a('logcat', '-c')
    a('shell', 'settings', 'put', 'system', 'font_scale', FONT_SCALE)
    try:
        time.sleep(FONT_SETTLE)
        share, after, shot = green_again(adb, args.serial, a, RETURN_WAIT)
    finally:
        if re.fullmatch(r'\d+(\.\d+)?', before):
            a('shell', 'settings', 'put', 'system', 'font_scale', before)
        else:
            a('shell', 'settings', 'delete', 'system', 'font_scale')
    crash, _ = new_crashes(a, names, pid)
    save_screen(args.out and os.path.splitext(args.out)[0] + '-font-scale.png', shot, 'after the font size change')
    log('After a font size change (font_scale %s, then %s again): %.0f%% of the screen is the probe\'s green; '
        'process %s (before it: %s)' % (FONT_SCALE, before if re.fullmatch(r'\d+(\.\d+)?', before) else 'unset',
                                         share * 100, after or 'not running', pid))
    problems = []
    if after != pid:
        problems.append('the app did not go on through a font size change in its process (%s before it, %s after)'
                        % (pid, after or 'none'))
    elif share < 0.25:
        problems.append('after a font size change the screen is not the probe\'s green (%.0f%%)' % (share * 100))
    if crash:
        problems.append('the device\'s log across the font size change: %s' % ' | '.join(crash[:6]))
    return problems


def starts_again_for_density(args, adb, a, pid, names, what='density change', suffix='density'):
    """--density: a change the manifest does not list (the screen's
    density, the display size setting), for which Android makes the
    activity again in its process: the app must start again in a new
    process (RelaunchActivity) and show its green there, without a crash.
    what and suffix: the change, as the log and the problems name it ("a
    density change"), and the end of its screen's file name"""
    _, out = a('shell', 'wm', 'density')
    m = re.search(r'Physical density:\s*(\d+)', out)
    if not m:
        return ['wm density gave no physical density: %s' % (out.strip()[-200:] or 'no answer')]
    density = str(int(int(m.group(1)) * DENSITY_SHARE))
    a('logcat', '-c')
    a('shell', 'wm', 'density', density)
    try:
        share, after, shot = green_again(adb, args.serial, a, RETURN_WAIT, other_than=pid)
        crash, pids = new_crashes(a, names, pid)
        finished = drawing_finished(a, pid)
    finally:
        a('shell', 'wm', 'density', 'reset')
    save_screen(args.out and os.path.splitext(args.out)[0] + '-%s.png' % suffix, shot, 'after the %s' % what)
    log('After a %s (%s, from %s): %.0f%% of the screen is the probe\'s green; process %s (before it: '
        '%s); its processes in the log: %s' % (what, density, m.group(1), share * 100, after or 'not running', pid,
                                               ', '.join(sorted(pids)) or 'none'))
    if finished:
        log('  The engine finished what it drew first: %s' % ' | '.join(finished))
    problems = []
    if not after or after == pid:
        problems.append('after a %s the app did not start again in a new process (%s before it, %s '
                        'after)' % (what, pid, after or 'none'))
    elif share < 0.25:
        problems.append('after a %s the screen is not the probe\'s green (%.0f%%)' % (what, share * 100))
    if crash:
        problems.append('the device\'s log across the %s: %s' % (what, ' | '.join(crash[:6])))
    if not problems:
        # back to the screen's own density, which makes the activity again
        # too, before anything else is asked of the app: the app starts
        # again in a new process for it as well, and without a crash (the
        # log holds the change's lines too, which had none)
        back, again, _ = green_again(adb, args.serial, a, RETURN_WAIT, other_than=after)
        crash, pids = new_crashes(a, names, after)
        log('Back at the screen\'s own density: %.0f%% of the screen is the probe\'s green; process %s (before it: '
            '%s); its processes in the log: %s' % (back * 100, again or 'not running', after,
                                                   ', '.join(sorted(pids)) or 'none'))
        finished = drawing_finished(a, after)
        if finished:
            log('  The engine finished what it drew first: %s' % ' | '.join(finished))
        # and it must come back: an app that hung as Android made the
        # activity again keeps its process, its screen black (LiveCode
        # 9.6.3's engine destroyed while it drew, runs 42558963677 and
        # 42593463112), which nothing after this would have asked about
        # when it was the last change
        if not again or again == after:
            problems.append('at the return to the screen\'s own density after the %s the app did not start again '
                            'in a new process (%s before it, %s after)' % (what, after, again or 'none'))
        elif back < 0.25:
            problems.append('at the return to the screen\'s own density after the %s the screen is not the '
                            'probe\'s green (%.0f%%)' % (what, back * 100))
        if crash:
            problems.append('the device\'s log across the return to the screen\'s own density after the %s: %s'
                            % (what, ' | '.join(crash[:6])))
    return problems


def starts_again_for_densities(args, adb, a, pid, names):
    """--density, --density-times times over (starts_again_for_density):
    each change, and each return to the screen's own density, makes the
    activity again, and the app must start again in a new process for
    each. Each time after the first is named in the log and the problems
    ("density change 2 of 3"), and has a screen of its own; the first
    problem ends them."""
    times = args.density_times
    for n in range(times):
        if n:
            pid = pid_now(a)
            if not pid:
                return ['the app is not running before density change %d of %d' % (n + 1, times)]
        what = 'density change' if not n else 'density change %d of %d' % (n + 1, times)
        problems = starts_again_for_density(args, adb, a, pid, names, what,
                                            'density' if not n else 'density-%d' % (n + 1))
        if problems:
            return problems
    return []


def probe_focus(a):
    """Whether the probe's window has the focus, by `dumpsys window`'s
    mCurrentFocus (None when it does not say), and that line."""
    _, window = a('shell', 'dumpsys', 'window')
    m = re.search(r'mCurrentFocus=.*', window or '')
    if not m:
        return None, ''
    line = ' '.join(m.group(0).split())
    return IDENTIFIER in line, line


def probe_pauses(a):
    """How many of the events buffer's lines say that Android paused the
    probe's activity (wm_pause_activity), for whatever reason."""
    _, events = a('logcat', '-d', '-b', 'events', '-v', 'brief')
    return sum(1 for x in (events or '').splitlines()
               if IDENTIFIER in x and re.search(r'\bwm_pause_activity\b', x))


# A line of the events buffer as `logcat -v epoch` gives it: the time in
# seconds, the process and thread, the level, the tag, and its values
EPOCH_EVENT = re.compile(r'\s*(\d+(?:\.\d+)?)\s+(\d+)\s+\d+\s+[VDIWEFS]\s+(\w+)\s*:\s*\[(.*)\]\s*$')


def destroy_held(events, pid):
    """How long, in seconds, the probe's process `pid` held Android's
    thread as Android made its activity again, by the events buffer as
    `logcat -d -b events -v epoch` gives it: from its activity's last stop
    for that (wm_on_stop_called, handleRelaunchActivity), which comes before
    its onDestroy (doDestroy), to the activity made again in it
    (wm_on_create_called, after the old one's onDestroy has returned in the
    same turn of Android's thread), or when the buffer has no such line, to
    the system's word that the process died (am_proc_died). None when the
    buffer does not say. The reason is the third value: Android 14 and
    newer add a fourth, the callback's time in ms (run 42564614783's
    Android 16 image said nothing with the reason taken as the last)."""
    lines = []
    for line in (events or '').splitlines():
        m = EPOCH_EVENT.match(line)
        if m:
            when, proc, tag, values = m.groups()
            lines.append((float(when), proc, tag, [v.strip() for v in values.split(',')]))
    stops = [i for i, (_, proc, tag, values) in enumerate(lines)
             if proc == pid and tag == 'wm_on_stop_called' and values[2:3] == ['handleRelaunchActivity']]
    if not stops:
        return None
    start = lines[stops[-1]][0]
    for when, proc, tag, values in lines[stops[-1] + 1:]:
        if (proc == pid and tag == 'wm_on_create_called') or (tag == 'am_proc_died' and pid in values[1:2]):
            return when - start
    return None


def starts_again_for_density_in_wait(args, adb, a, pid, names):
    """--density-in-wait: --density's change while the probe's script
    waits. A tap on the probe: its mouseUp turns the screen WAIT_COLOR and
    waits PROBE_WAIT seconds with messages, and the density is changed once
    that colour is seen. As Android destroys the activity, the engine, let
    go on to finish (doDestroy in engine/src/mblandroiddc.cpp), yields to
    Android's thread again inside the wait: before, that thread then went
    on to join the engine thread, which was waiting for its turn, and the
    app hung there for good (on Android 16 in run 42416576870, where the
    engine yielded in the middle of drawing). The app must start again in
    a new process, as for --density, and the wait must end as the activity
    goes (MCScreenDC::wait), not be waited out while Android's thread waits
    for the engine: the process may hold it for HELD_LIMIT s (destroy_held).

    The tap waits FOCUS_WAIT s at most for the probe's window to have the
    focus, after another app's "isn't responding" dialog in front of it is
    answered. A tap that turns no wait colour is given again (TAP_TRIES in
    all) only when something stood in its way: the probe's window did not
    have the focus, Android paused its activity, or another app's dialog
    came in front of it; else it is a failure at once. The screen that
    says where to tap is taken again when screencap gives none (SCREEN_TRIES
    times in all)."""
    got = None
    for shot in range(SCREEN_TRIES):
        if shot:
            time.sleep(SCREEN_AGAIN)
        got = screen_now(adb, args.serial)
        if got:
            break
    if not got:
        return ['no screen of the probe to find where to tap it (screencap gave none, %d times)' % SCREEN_TRIES]
    x, y = str(got[0] // 2), str(got[1] // 2)
    for tap in range(1, TAP_TRIES + 1):
        answer_other_anr(a)
        focused, focus = probe_focus(a)
        asked = time.time()
        while focused is False and time.time() - asked < FOCUS_WAIT:
            time.sleep(1)
            focused, focus = probe_focus(a)
        pauses = probe_pauses(a)
        a('shell', 'input', 'tap', x, y)
        tapped = time.time()
        share = 0.0
        while time.time() - tapped < WAIT_SEEN:
            time.sleep(1)
            got = screen_now(adb, args.serial)
            if got:
                share = colour_share(got[2], WAIT_COLOR)
                if share >= 0.25:
                    break
        seen = time.time() - tapped
        log('After a tap on the probe: %.0f%% of the screen is its wait colour, %.0f s after the tap (it waits %d s)'
            % (share * 100, seen, PROBE_WAIT))
        if share >= 0.25:
            break
        # what stood between the tap and the probe's mouseUp
        why = []
        if focused is False:
            why.append('the probe\'s window did not have the focus (%s)' % focus)
        if probe_pauses(a) > pauses:
            why.append('Android paused the probe\'s activity')
        other = answer_other_anr(a)
        if other:
            why.append('%s was not responding, its dialog in front of the probe' % other)
        if not why or tap == TAP_TRIES:
            return ['a tap did not reach the probe\'s mouseUp: the screen did not turn its wait colour in %d s '
                    '(%.0f%%)%s' % (WAIT_SEEN, share * 100, '; %s' % '; '.join(why) if why else '')]
        log('  The tap did not reach the probe\'s mouseUp, as %s: tapping again' % '; '.join(why))
    if seen > WAIT_SEEN:
        return ['the probe\'s wait colour was seen %.0f s after the tap, too late to change the density while its '
                'script surely waits (at most %d s)' % (seen, WAIT_SEEN)]
    problems = starts_again_for_density(args, adb, a, pid, names, 'density change while the probe\'s script waited',
                                        'density-in-wait')
    if problems:
        return problems
    _, events = a('logcat', '-d', '-b', 'events', '-v', 'epoch')
    held = destroy_held(events, pid)
    if held is None:
        log('NOTE: the events buffer does not say how long process %s held Android\'s thread as its activity, '
            'whose script waited, was made again' % pid)
        # what it does say of that process's activities, so that a format
        # this cannot read shows itself
        own = [x.strip() for x in (events or '').splitlines()
               if re.search(r'\bwm_on_\w+_called\b', x) and re.search(r'\s%s\s' % re.escape(pid), x)]
        for line in own[-6:]:
            log('  ' + line)
    else:
        log('Process %s held Android\'s thread for %.1f s as its activity, whose script waited, was made again '
            '(wm_on_stop_called to the activity made again)' % (pid, held))
        if held > HELD_LIMIT:
            problems.append('as the activity whose script waited was made again, its process held Android\'s thread '
                            'for %.0f s (at most %d s), so the engine waited out the script\'s wait (Android calls an '
                            'app that does not answer a touch for 5 s not responding)' % (held, HELD_LIMIT))
    return problems


def opens_again_after_quit(args, adb, a, pid, names):
    """--relaunch: the back key, which the app probe passes, quits its stack
    (MCQuit), and the activity finishes; its process must then end
    (LiveCodeActivity.onDestroy), and the app opened again must show its
    green in a new process, without a crash. Opened again in the process
    its engine ran in, the engine's second start was stopped on Android 11
    and newer."""
    a('logcat', '-c')
    a('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    ended = time.time()
    left = pid
    while time.time() - ended < END_WAIT:
        time.sleep(1)
        left = pid_now(a)
        if left != pid:
            break
    log('After the back key: process %s' % ('%s, still there after %d s' % (pid, END_WAIT) if left == pid
                                            else left or 'none: it ended'))
    status, out = a('shell', 'am', 'start', '-W', '-n', IDENTIFIER + '/.mblandroid')
    log('Opened again: %s' % ' | '.join(x.strip() for x in out.splitlines() if x.strip()))
    share, after, shot = green_again(adb, args.serial, a, RETURN_WAIT)
    crash, pids = new_crashes(a, names, pid)
    save_screen(args.out and os.path.splitext(args.out)[0] + '-again.png', shot, 'opened again')
    log('Opened again after its stack quit: %.0f%% of the screen is the probe\'s green; process %s (the first: '
        '%s); its processes in the log: %s' % (share * 100, after or 'not running', pid,
                                               ', '.join(sorted(pids)) or 'none'))
    problems = []
    if left == pid:
        problems.append('the app\'s process was still there %d s after its stack quit (the back key)' % END_WAIT)
    if not after or share < 0.25:
        problems.append('opened again after its stack quit, the app did not show its green (%.0f%%; process %s)'
                        % (share * 100, after or 'none'))
    if crash:
        problems.append('the device\'s log, opened again after its stack quit: %s' % ' | '.join(crash[:6]))
    return problems


# exit-info's reason for a process the low memory killer ended
LOW_MEMORY = 3
# exit-info's reasons for a process that failed of itself
# (ApplicationExitInfo.REASON_CRASH, REASON_CRASH_NATIVE, REASON_ANR and
# REASON_INITIALIZATION_FAILURE): one of them for any of a run's
# processes is the run's failure, whatever the log kept of it
FAILED_EXITS = {4: 'CRASH', 5: 'CRASH_NATIVE', 6: 'ANR', 7: 'INITIALIZATION_FAILURE'}
# How long device waits before it makes the run once more after such a
# kill, for the device's memory to settle
LOW_MEMORY_PAUSE = 30


def low_memory_kills(exits, pids):
    """The processes of pids that dumpsys activity exit-info says the low
    memory killer ended (reason=3 (LOW_MEMORY)), each of its
    ApplicationExitInfo blocks giving the pid on one line and the reason on
    another. exit-info keeps the package's earlier processes too (another
    run's on the same emulator), and only pids, this run's, count. None
    when another of them crashed, did not answer or did not start
    (FAILED_EXITS): the low memory killer is then not the run's story, even
    where the log has lost that process's crash."""
    killed = set()
    for block in re.split(r'ApplicationExitInfo #\d+:', exits)[1:]:
        pid = re.search(r'\bpid=(\d+)', block)
        reason = re.search(r'\breason=(\d+)', block)
        if not (pid and reason and pid.group(1) in pids):
            continue
        if int(reason.group(1)) in FAILED_EXITS:
            return []
        if int(reason.group(1)) == LOW_MEMORY:
            killed.add(pid.group(1))
    return sorted(killed)


def device(args):
    """The run of device_once, made once more when its probe was ended by
    the low memory killer and nothing else says it failed. The Java layer's
    probe on the 16 KB image at API 36 was killed so behind its
    notification permission dialog (oom_score_adj 101, "min watermark is
    breached even after kill", 1.7 GB available a second later) in runs
    42312203693 and 42324548829, and again in 42714271161 after
    quiet_after_install found the device idle at once: the emulator's
    memory, not the engine, whose fault would be a crash (a linker refusal
    or a native signal, exit-info CRASH or CRASH_NATIVE). A second kill,
    or any other problem in the second run, fails as before."""
    problems, killed = device_once(args)
    if problems and killed:
        log('NOTE: Android\'s low memory killer ended the probe (process %s, exit-info LOW_MEMORY), and its '
            'log has no crash: the run once more, after %d s' % (', '.join(killed), LOW_MEMORY_PAUSE))
        for x in problems:
            log('  the first run\'s problem: %s' % x)
        log()
        time.sleep(LOW_MEMORY_PAUSE)
        problems, _ = device_once(args)
    return problems


def device_once(args):
    """(the problems, the processes of the probe that the low memory killer
    ended where nothing else says it failed: each problem one that such a
    kill explains, unfinished's)"""
    adb = adb_path(args.sdk)
    if not adb:
        raise CheckError('no adb')
    problems = []
    killed = []
    # the problems a probe that the low memory killer ended before it was
    # done would have, and only those: it never turned green, it is not
    # running, and before its green it never asked for a permission or
    # never exported its picture (the Java probe does both first). Any
    # other problem (a crash, the fail colour, a failed check of its green
    # screen, a picture missing once it was green) is the probe's own, and
    # no second run hides it
    unfinished = []

    def a(*cmd, timeout=180):
        return run([adb, '-s', args.serial] + list(cmd), timeout=timeout)
    _, props = a('shell', 'getprop', 'ro.build.version.sdk')
    _, page = a('shell', 'getconf', 'PAGE_SIZE')
    _, abi = a('shell', 'getprop', 'ro.product.cpu.abi')
    log('Device %s: API %s, %s, %s' % (args.serial, props.strip(), abi.strip(),
                                        'pages of %s bytes' % page.strip() if page.strip().isdigit() else
                                        'its page size not said (getconf: %s)' % answer(page, 120)))
    state = wakefulness(a('shell', 'dumpsys', 'power')[1])
    if state and state != 'Awake':
        log('NOTE: the device is %s (dumpsys power): Android pauses an activity started now (see boot --awake)'
            % state)
    if args.picture:
        a('logcat', '-c')
    _, out = a('uninstall', IDENTIFIER)
    if args.picture and 'Success' in out:
        removal_taken(a)
    if args.apk.endswith('.aab'):
        refused = install_bundle(args, adb, a)
        if refused:
            return refused, []
    else:
        status, out = a('install', '-r', args.apk, timeout=600)
        if 'Success' not in out:
            return ['%s does not install on %s: %s' % (os.path.basename(args.apk), args.serial,
                                                       out.strip()[-800:])], []
        log('Installed %s' % os.path.basename(args.apk))
    quiet_after_install(a)
    a('logcat', '-c')
    status, out = a('shell', 'am', 'start', '-W', '-n', IDENTIFIER + '/.mblandroid')
    log('Started: %s' % ' | '.join(x.strip() for x in out.splitlines() if x.strip()))
    if 'Error' in out:
        problems.append('the app does not start: %s' % out.strip()[-500:])
    started = time.time()
    share = saved = failed = 0.0
    w = h = 0
    rgba = b''
    # --allow: the probe must ask for the permission (Android's dialog in
    # front of it), which is allowed with the dialog's own button; until
    # then its green does not end the wait. Once Allow is tapped the check
    # looks for the dialog until it has gone, and a dialog still in front
    # ALLOW_AGAIN s after the tap has its Allow tapped again (ALLOW_TAPS)
    asked = allowed = False
    allow_taps = 0
    tapped_at = 0.0
    anr_taps = 0
    while time.time() - started < args.timeout:
        time.sleep(3)
        if args.allow and allow_taps < ALLOW_TAPS:
            _, activities = a('shell', 'dumpsys', 'activity', 'activities')
            if asking_for_permission(activities):
                if not asked:
                    log('After %.0f s: Android asks the user to allow %s' % (time.time() - started, args.allow))
                asked = True
                if allowed and time.time() - tapped_at < ALLOW_AGAIN:
                    # the tap may still be closing it
                    continue
                a('shell', 'uiautomator', 'dump', '/sdcard/oxt-ui.xml')
                _, xml = a('shell', 'cat', '/sdcard/oxt-ui.xml')
                where = allow_button(xml)
                if where:
                    a('shell', 'input', 'tap', str(where[0]), str(where[1]))
                    log('  tapped Allow at %d,%d%s' % (where + (
                        ' again: the dialog was still in front %.0f s after the last tap' % (
                            time.time() - tapped_at) if allowed else '',)))
                    allowed = True
                    allow_taps += 1
                    tapped_at = time.time()
                else:
                    log('  no Allow button in the dialog yet')
                    # another app's "isn't responding" dialog can stand
                    # over it: System UI's on Android 13 in run
                    # 42376416337, for 90 s, and the probe failed
                    if anr_taps < ANR_TAPS and answer_other_anr(a):
                        anr_taps += 1
                continue
        try:
            proc = subprocess.run([adb, '-s', args.serial, 'exec-out', 'screencap'], stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, timeout=60)
            w, h, rgba = screen_from_raw(proc.stdout)
        except (CheckError, subprocess.TimeoutExpired) as e:
            log('  screencap: %s' % e)
            continue
        share, saved = colour_share(rgba, RUN_COLOR), colour_share(rgba, SAVED_COLOR)
        failed = colour_share(rgba, FAIL_COLOR)
        if failed >= 0.25 or (share >= 0.25 and (allowed or not args.allow)):
            break
        if share < 0.25 and failed < 0.25 and anr_taps < ANR_TAPS and answer_other_anr(a):
            anr_taps += 1
    pid = pid_now(a)
    _, logcat = a('logcat', '-d', '-v', 'brief')
    pids = probe_pids(logcat, pid)
    with zipfile.ZipFile(args.apk) as z:
        # an App Bundle's files are in its base module
        names = [n[5:] if n.startswith('base/') else n for n in z.namelist()]
        crash, expected, others = crash_lines(logcat, names, pids)
    log('The probe\'s processes in the log: %s' % (', '.join(sorted(pids)) or
                                                  'none known, so every line is read as its'))
    for line in expected:
        log('Expected (the package has no SSL library, and the engine runs on without it): %s' % line)
    if others:
        log('Left out: %d such line(s) of other processes (the full log: --log-out)' % others)
    if args.out and rgba:
        with open(args.out, 'wb') as f:
            f.write(png_from_rgba(w, h, rgba))
        log('Screen: %s (%dx%d)' % (args.out, w, h))
    if args.log_out:
        with open(args.log_out, 'w', encoding='utf-8') as f:
            f.write(logcat)
    log('After %.0f s: %.0f%% of the screen is the probe\'s green, %.0f%% its saved red; process %s' % (
        time.time() - started, share * 100, saved * 100, pid.strip() or 'not running'))
    said = probe_said(logcat, pids)
    for line in said:
        log('The probe said: %s' % line)
    if failed >= 0.25:
        problems.append('the probe\'s script ran, and a call it makes into the Java layer failed (the screen '
                        'is its fail colour, %.0f%%%s)' % (failed * 100, '; it said: %s' % ' | '.join(said)
                                                         if said else ''))
    elif share < 0.25:
        problems.append('the screen never turned the probe\'s green (%.0f%% green, %.0f%% red: %s)' % (
            share * 100, saved * 100, 'the stack showed and its script did not run' if saved >= 0.25 else
            'the stack never showed'))
        unfinished.append(problems[-1])
    green = failed < 0.25 and share >= 0.25
    if args.within_bars and green:
        # the stack inside the system bars: the screen's first and last
        # rows are not its green (Android 15 and newer draw an app that
        # targets API 35 edge to edge, and the Java layer pads the stack)
        over = bars_drawn_over(rgba, w, h)
        if over:
            log('The bars: the first green screen has the stack\'s green in its %s row; the screen again for up '
                'to %g s' % (' and '.join(over), BARS_WAIT))
            over, shots, waited = bars_again(adb, args.serial, over)
            log('The bars: %d more screen(s) in %.0f s; %s' % (
                shots, waited, 'the bars are drawn over the stack in the last' if not over else
                'the stack\'s green is still where the bars are'))
        log('The bars: %s' % ('the stack is drawn under them (%s)' % ', '.join(over) if over else
                              'the stack is inside them (the first and last rows are not its green)'))
        if over:
            problems.append('the stack is drawn under the system bars (its green in the screen\'s %s row)'
                            % ' and '.join(over))
    if args.edge_to_edge and green:
        # the stack drawn edge to edge (the edge probe): its green under
        # the see-through status bar, and its effective working screenRect
        # leaving the bars out (the rects it says kEdgeWait after its green)
        time.sleep(EDGE_WAIT)
        _, later = a('logcat', '-d', '-v', 'brief')
        screen, effective = edge_rects(probe_said(later, pids))
        top = row_share(rgba, w, 0, RUN_COLOR) if h else 0.0
        bottom = row_share(rgba, w, h - 1, RUN_COLOR) if h else 0.0
        if top < 0.5:
            got = screen_now(adb, args.serial)
            if got and colour_share(got[2], RUN_COLOR) >= 0.25:
                top = row_share(got[2], got[0], 0, RUN_COLOR)
        log('Edge to edge: %.0f%% of the screen\'s first row (the status bar) and %.0f%% of its last (the '
            'navigation bar) are the stack\'s green; its screenRect %s, its effective working screenRect %s' % (
                top * 100, bottom * 100, ','.join(map(str, screen)) if screen else 'not said',
                ','.join(map(str, effective)) if effective else 'not said'))
        problems.extend(edge_problems(screen, effective, top))
    if args.back and green and pid.strip():
        # the back key: the probe's backKey turns the screen its back colour
        # (Android 16 sends it to the window's back callback for an app that
        # targets API 36, older Android to onBackPressed)
        a('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        back = 0.0
        brgba = b''
        pressed = time.time()
        while time.time() - pressed < BACK_WAIT:
            time.sleep(2)
            try:
                proc = subprocess.run([adb, '-s', args.serial, 'exec-out', 'screencap'], stdout=subprocess.PIPE,
                                      stderr=subprocess.DEVNULL, timeout=60)
                bw, bh, brgba = screen_from_raw(proc.stdout)
            except (CheckError, subprocess.TimeoutExpired) as e:
                log('  screencap: %s' % e)
                continue
            back = colour_share(brgba, BACK_COLOR)
            if back >= 0.25:
                break
        after = pid_now(a)
        if args.out and brgba:
            # the screen after the back key, beside the first
            path = os.path.splitext(args.out)[0] + '-back.png'
            with open(path, 'wb') as f:
                f.write(png_from_rgba(bw, bh, brgba))
            log('Screen after the back key: %s' % path)
        log('After the back key: %.0f%% of the screen is the probe\'s back colour; process %s' % (
            back * 100, after.strip() or 'not running'))
        if back < 0.25:
            problems.append('the back key did not reach the stack\'s backKey (%.0f%% of the screen its back colour; '
                            'the app is %s)' % (back * 100, 'running' if after.strip() else 'gone'))
    # The engine runs once in a process: the app goes on through a change
    # the manifest lists, starts again in a new process for one it does
    # not (also while its script waits), and opened again after its stack
    # quit starts in a new process
    for wanted, check in ((args.font_scale, stays_through_font_scale), (args.density, starts_again_for_densities),
                          (args.density_in_wait, starts_again_for_density_in_wait),
                          (args.relaunch, opens_again_after_quit)):
        if wanted and green and pid.strip():
            found = check(args, adb, a, pid_now(a), names)
            problems += found
            if found:
                break
    if not pid.strip():
        problems.append('the app is not running')
        unfinished.append(problems[-1])
    if args.allow:
        _, package = a('shell', 'dumpsys', 'package', IDENTIFIER)
        granted = permission_granted(package, args.allow)
        log('%s: %s' % (args.allow, {None: 'the package does not ask for it', True: 'granted',
                                     False: 'not granted'}[granted]))
        if not asked:
            problems.append('the probe never asked the user to allow %s' % args.allow)
            if not green:
                unfinished.append(problems[-1])
        elif not allowed:
            problems.append('Android asked the user to allow %s, and its dialog had no Allow button to tap'
                            % args.allow)
        elif granted is not True:
            problems.append('%s was allowed in Android\'s dialog, and the package does not hold it (%s)'
                            % (args.allow, 'it does not ask for it' if granted is None else 'not granted'))
    if args.picture:
        # the picture the probe exported, where Android keeps the shared
        # ones (MediaStore), as the package's own
        _, query = a('shell', 'content', 'query', '--uri', 'content://media/external/images/media',
                     '--projection', ':'.join(PICTURE_COLUMNS))
        rows = shared_pictures(query)
        own = ['%s%s' % (r.get('relative_path', ''), r.get('_display_name', '')) for r in rows
               if r.get('owner_package_name') == IDENTIFIER]
        log('Shared pictures the package owns: %s' % (', '.join(own) or 'none'))
        if not probe_picture(rows, args.picture, IDENTIFIER):
            # one of its name with no owner: MediaProvider orphaned it
            # (REMOVAL_TAKEN), or it is an earlier install's
            unowned = probe_picture(rows, args.picture, 'NULL')
            problems.append('the probe\'s picture %s is not in the shared %s folder as the package\'s own (%s%s)'
                            % (args.picture, PICTURES.rstrip('/'), 'it owns ' + ', '.join(own) if own else
                               'it owns no shared picture' if rows else
                               'MediaStore listed no picture: %s' % (query.strip()[-300:] or 'no answer'),
                               '; %s%s there has no owner' % (PICTURES, unowned['_display_name'])
                               if unowned else ''))
            if not green:
                unfinished.append(problems[-1])
    if crash:
        problems.append('the device\'s log: %s' % ' | '.join(crash[:8]))
    if problems or len(pids) > 1:
        # why, before anything is changed: the logs' account of the probe's
        # processes, how each one ended (ApplicationExitInfo, Android 11 and
        # newer) and the memory left
        if len(pids) > 1:
            log('NOTE: the probe was started %d times (processes %s)' % (len(pids), ', '.join(sorted(pids))))
        _, events = a('logcat', '-d', '-b', 'events', '-v', 'brief')
        for note in disturbances(logcat, events):
            log('NOTE: %s' % note)
        for heading, lines in probe_story(logcat, events, pids):
            log('%s:%s' % (heading, '' if lines else ' none'))
            for line in lines:
                log('  ' + line)
        _, exits = a('shell', 'dumpsys', 'activity', 'exit-info', IDENTIFIER)
        if all(x in unfinished for x in problems):
            killed = low_memory_kills(exits, pids)
        exits = [x.rstrip() for x in exits.splitlines() if x.strip()]
        log('how its processes ended (dumpsys activity exit-info):%s' % ('' if exits else ' none'))
        for line in exits[:60]:
            log('  ' + line)
        _, mem = a('shell', 'cat', '/proc/meminfo')
        log('memory: %s' % ', '.join(' '.join(x.split()) for x in mem.splitlines()
                                     if x.split(':')[0] in ('MemTotal', 'MemAvailable', 'SwapFree')))
        if share < 0.25:
            # not green: what stood in front of the probe (the focused
            # window: a dialog names itself), any process's dialogs in the
            # log, and what the screen showed instead
            _, windows = a('shell', 'dumpsys', 'window')
            front = [' '.join(x.split()) for x in windows.splitlines()
                     if re.search(r'\bm(CurrentFocus|FocusedApp)=', x)]
            log('in front (dumpsys window): %s' % ('; '.join(front[:4]) or 'it did not say'))
            dialogs = [x for x in logcat.splitlines() if re.search(DIALOGS, x)]
            log('dialogs in the log (any process):%s' % ('' if dialogs else ' none'))
            for line in dialogs[:12]:
                log('  ' + line)
            if rgba:
                log("the screen's commonest colours: %s" % ', '.join(
                    '#%02x%02x%02x %.0f%%' % (c + (part * 100,)) for c, part in screen_colours(rgba)))
    return problems, killed


# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# boot

def tail(path, lines=60):
    """The last lines of a text file, or why there are none."""
    try:
        with open(path, 'rb') as f:
            text = f.read().decode('utf-8', 'replace')
    except OSError as e:
        return '(no log: %s)' % e
    return '\n'.join(text.splitlines()[-lines:]) or '(the log is empty)'


def boot_state(adb, serial):
    """(adb's state of the device, its sys.boot_completed), each '' when
    adb gives none."""
    try:
        _, state = run([adb, '-s', serial, 'get-state'], timeout=30)
    except CheckError:
        return '', ''
    state = state.strip().splitlines()[-1].strip() if state.strip() else ''
    if state != 'device':
        return state, ''
    try:
        _, booted = run([adb, '-s', serial, 'shell', 'getprop', 'sys.boot_completed'], timeout=30)
    except CheckError:
        return state, ''
    return state, booted.strip()


def emulator_processes():
    """The running emulator's processes as ps lines (pid, elapsed time,
    command), or None when ps cannot be run. Only a program named emulator
    or qemu-system-*: a command that merely names one (this check's own,
    with --log .../emulator-api33.log) is not one."""
    try:
        _, ps = run(['ps', '-eo', 'pid,etime,args'], timeout=30)
    except CheckError:
        return None
    out = []
    for line in ps.splitlines():
        parts = line.split(None, 3)
        if len(parts) < 3 or not parts[0].isdigit() or int(parts[0]) == os.getpid():
            continue
        program = os.path.basename(parts[2])
        if program == 'emulator' or program.startswith('qemu-system'):
            out.append(line.strip()[:300])
    return out


def boot_diagnostics(adb, sdk, log_path):
    """What may say why an emulator did not boot, as lines."""
    out = []
    procs = emulator_processes()
    out.append('emulator processes: %s' % ('ps could not be run' if procs is None
                                           else '; '.join(procs) or 'none (it is not running)'))
    try:
        st = os.stat('/dev/kvm')
        out.append('/dev/kvm: mode %o, %s' % (st.st_mode & 0o777,
                                            'readable and writable' if os.access('/dev/kvm', os.R_OK | os.W_OK)
                                            else 'NOT readable and writable by this user'))
    except OSError as e:
        out.append('/dev/kvm: %s' % e)
    try:
        _, devices = run([adb, 'devices', '-l'], timeout=30)
        out.append('adb devices: %s' % ' / '.join(x.strip() for x in devices.splitlines() if x.strip()))
    except CheckError as e:
        out.append('adb devices: %s' % e)
    for path in (sdk, os.path.dirname(os.path.abspath(log_path)) if log_path else None):
        if path and os.path.isdir(path):
            du = shutil.disk_usage(path)
            out.append('free disk at %s: %.1f GB of %.1f GB' % (path, du.free / 1e9, du.total / 1e9))
    if log_path:
        out.append('the end of %s:' % log_path)
        out.append(tail(log_path))
    return out


def enabled_overlays(listing):
    """The enabled overlays in `cmd overlay list`'s output ([x] lines)."""
    return sorted(x.split(']', 1)[1].strip() for x in listing.splitlines() if x.strip().startswith('[x]'))


# What a command says while the system server is not serving (it is
# restarting, or not yet up): `cmd` cannot find the service, or the call
# died with it. An answer from no one, which settling waits through
# rather than reads.
NOT_SERVING = r"Can't find service|Failure calling service|DeadObjectException|DeadSystemException"


def answer(out, keep=300):
    """A command's answer on one line, cut to its END if long: a waiting
    command prints progress first and says how it ended last."""
    said = ' '.join(out.split())
    return said if len(said) <= keep else '...' + said[-keep:]


def settle(adb, serial, minutes, interval, polls=3):
    """After boot, wait for what Android does once in a fresh image's first
    minute (the BOOT_COMPLETED receivers; the package manager's queue; the
    overlays the device and gesture navigation enable, which change every
    app's ApplicationInfo and so recreate a running activity): until the
    broadcast queues are idle (am wait-for-broadcast-idle), the package
    manager's handler is idle (pm wait-for-handler), and the enabled
    overlays have not changed over `polls` polls `interval` seconds apart.
    While the system server is not serving (NOT_SERVING: on an API 35
    image, 24 s after sys.boot_completed, `pm` could not find the package
    service and `cmd overlay list` listed nothing), a condition waits for
    it, and a listing it did not give counts for nothing. The system
    server's process is read before and after, so a restart is said.
    Prints each condition and when it held, and how a command that cannot
    say ended. A condition that does not hold in `minutes` is said, and
    the run goes on: this decides nothing."""
    start = time.monotonic()
    deadline = start + minutes * 60

    def left():
        return max(1, int(deadline - time.monotonic()))

    def shell(*cmd):
        return run([adb, '-s', serial, 'shell'] + list(cmd), timeout=left())

    def system_server():
        try:
            out = shell('pidof', 'system_server')[1].strip()
        except CheckError:
            return ''
        return out if re.fullmatch(r'\d+', out) else ''

    server = system_server()
    held, missed = [], []
    for what, cmd, extra in (('the broadcast queues are idle', ('am', 'wait-for-broadcast-idle'), lambda: ()),
                             ("the package manager's handler is idle", ('pm', 'wait-for-handler'),
                              lambda: ('--timeout', str(left() * 1000)))):
        name = ' '.join(cmd)
        said_waiting = False
        try:
            while True:
                status, out = shell(*(cmd + extra()))
                if not re.search(NOT_SERVING, out) or time.monotonic() >= deadline:
                    break
                if not said_waiting:
                    log('settling: %s: the system server is not serving (%s: %s); waiting for it' % (
                        what, name, answer(out, 120)))
                    said_waiting = True
                time.sleep(interval)
        except CheckError:
            missed.append(what)
            log('settling: %s: not in %g minutes (%s)' % (what, minutes, name))
            continue
        if re.search(NOT_SERVING, out):
            missed.append(what)
            log('settling: %s: not in %g minutes: the system server was not serving (%s: %s)' % (
                what, minutes, name, answer(out, 120)))
        elif status != 0 or re.search(r'(?i)unknown (command|option)|error', out):
            log('settling: %s: %s cannot say on this image (exit status %d: %s)' % (
                what, name, status, answer(out) or 'nothing'))
        else:
            held.append('%s (%s, %d s)' % (what, name, time.monotonic() - start))
            log('settling: %s after %d s (%s%s)' % (what, time.monotonic() - start, name,
                                                    ': ' + answer(out) if out.strip() else ''))
    last = None
    same = 0
    silent = False
    while True:
        try:
            status, listing = shell('cmd', 'overlay', 'list')
        except CheckError as e:
            status, listing = None, str(e)
        if status != 0 or re.search(NOT_SERVING, listing):
            # no answer: not a list of none, and not a poll that held
            if not silent:
                log('settling: cmd overlay list gave no answer (%s); waiting' % (
                    answer(listing, 120) or 'exit status %s' % status))
                silent = True
            same = 0
        else:
            silent = False
            now = enabled_overlays(listing)
            if now == last:
                same += 1
            else:
                if last is not None:
                    log('settling: the enabled overlays changed: %s' % '; '.join(
                        ['+' + x for x in now if x not in last] + ['-' + x for x in last if x not in now]))
                same = 1
            last = now
        if same >= polls or time.monotonic() >= deadline:
            break
        time.sleep(interval)
    what = 'the enabled overlays are unchanged over %d polls %g s apart' % (polls, interval)
    if same >= polls:
        held.append('%s (cmd overlay list, %d enabled, %d s)' % (what, len(last), time.monotonic() - start))
        log('settling: %s after %d s (%d enabled)' % (what, time.monotonic() - start, len(last)))
    else:
        missed.append(what)
        log('settling: %s: not in %g minutes' % (what, minutes))
    after = system_server()
    if server and after and server != after:
        log('settling: the system server restarted while settling (process %s, then %s)' % (server, after))
    log('%s settled after %d s: %s%s' % (serial, time.monotonic() - start, '; '.join(held) or 'nothing held',
                                         ('; not: ' + '; '.join(missed)) if missed else ''))
    return held, missed


def wakefulness(out):
    """What `dumpsys power` says of the device (mWakefulness=): Awake,
    Asleep, Dozing or Dreaming; '' when it does not say."""
    m = re.search(r'\bmWakefulness=(\w+)', out)
    return m.group(1) if m else ''


# How long the screen stays on without a touch once awake() has run, in
# minutes: longer than the workflow's probes take, so it does not time out
# under one
AWAKE_MINUTES = 30


def awake(adb, serial, interval):
    """Put the device to sleep once and wake it, then keep it awake, before
    a probe runs on it. In run 42218720113 the 16 KB image's screen went
    off about a minute after it booted, just as the Java layer's probe
    started: Android paused the probe's activity for sleep, SystemUI added
    its wallpaper colours' theme overlays (com.android.systemui-neutral,
    -accent and -dynamic .frro; AOSP's ThemeOverlayController keeps a
    change of colours until the screen is off), every app's ApplicationInfo
    changed, and when the probe resumed Android relaunched its activity,
    which the carried runtime does not survive (an fdsan abort). One sleep
    here does that deferred work before settling and the probes; then the
    screen is woken (KEYCODE_WAKEUP), the keyguard dismissed (wm
    dismiss-keyguard, and MENU, which the workflow sent before), and it
    stays on (svc power stayon true; a screen-off timeout of AWAKE_MINUTES).
    Each step that cannot say is said, and the run goes on: this decides
    nothing."""
    start = time.monotonic()
    step = max(interval / 5, 0.01)
    wait = interval * 4

    def shell(*cmd):
        try:
            return run([adb, '-s', serial, 'shell'] + list(cmd), timeout=60)
        except CheckError as e:
            return None, str(e)

    def power():
        return wakefulness(shell('dumpsys', 'power')[1])

    def until(want, then):
        """Poll until want(wakefulness) or `wait` seconds; (state, seconds)."""
        while True:
            now = power()
            if want(now) or time.monotonic() - then >= wait:
                return now, time.monotonic() - then
            time.sleep(step)

    said = []
    before = power()
    if not before:
        log('awake: dumpsys power does not say whether %s is awake; waking it all the same' % serial)
    shell('input', 'keyevent', 'KEYCODE_SLEEP')
    asleep, took = until(lambda w: w and w != 'Awake', time.monotonic())
    if asleep and asleep != 'Awake':
        said.append('slept (%s after %d s)' % (asleep, took))
        # what Android keeps until the screen is off runs now
        time.sleep(interval)
    else:
        said.append('did not sleep in %g s (%s)' % (wait, asleep or 'dumpsys power does not say'))
    shell('input', 'keyevent', 'KEYCODE_WAKEUP')
    woke, took = until(lambda w: w == 'Awake', time.monotonic())
    said.append('woke (Awake after %d s)' % took if woke == 'Awake' else
                'did not wake in %g s (%s)' % (wait, woke or 'dumpsys power does not say'))
    status, out = shell('wm', 'dismiss-keyguard')
    said.append('the keyguard dismissed' if status == 0 else
                'wm dismiss-keyguard cannot say (%s)' % (answer(out, 120) or 'exit status %s' % status))
    shell('input', 'keyevent', '82')
    status, out = shell('svc', 'power', 'stayon', 'true')
    said.append('it stays on while powered' if status == 0 else
                'svc power stayon cannot say (%s)' % (answer(out, 120) or 'exit status %s' % status))
    status, out = shell('settings', 'put', 'system', 'screen_off_timeout', str(AWAKE_MINUTES * 60000))
    said.append('its screen times out after %d minutes without a touch' % AWAKE_MINUTES if status == 0 else
                'settings put system screen_off_timeout cannot say (%s)' % (
                    answer(out, 120) or 'exit status %s' % status))
    log('%s awake after %d s: %s (%s before)' % (serial, time.monotonic() - start, '; '.join(said),
                                                before or 'not said'))
    return said


def boot(args):
    adb = adb_path(args.sdk)
    if not adb:
        raise CheckError('no adb')
    start = time.monotonic()
    deadline = start + args.minutes * 60
    report = start
    state = booted = ''
    # An emulator that has exited will not boot: once adb has no such
    # device and no emulator runs, three polls running, say so then, not
    # at the deadline (an AVD the emulator could not find once cost 10
    # minutes of waiting). Only for an emulator's serial: a device on a
    # cable has no process here.
    gone = 0
    while True:
        state, booted = boot_state(adb, args.serial)
        now = time.monotonic()
        if booted == '1':
            log('%s booted after %d s' % (args.serial, now - start))
            if args.awake:
                awake(adb, args.serial, args.interval)
            if args.settle:
                settle(adb, args.serial, args.settle_minutes, args.interval, args.settle_polls)
            return []
        if args.serial.startswith('emulator-') and state != 'device' and emulator_processes() == []:
            gone += 1
        else:
            gone = 0
        if now >= report:
            log('waiting for %s (%d s): adb says %s, sys.boot_completed is %s' % (
                args.serial, now - start, state or 'nothing', booted or 'not there'))
            report = now + 60
        if gone >= 3 or now >= deadline:
            break
        time.sleep(args.interval)
    for line in boot_diagnostics(adb, args.sdk, args.log):
        log(line)
    if gone >= 3:
        return ['%s will not boot: no emulator is running (adb says %s); see the lines above' % (
            args.serial, state or 'nothing')]
    return ['%s did not boot in %g minutes (adb says %s, sys.boot_completed is %s); see the lines above' % (
        args.serial, args.minutes, state or 'nothing', booted or 'not there')]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    e = sub.add_parser('extract')
    e.add_argument('--package', required=True)
    e.add_argument('--dest', required=True)
    e.add_argument('--platform')
    e.add_argument('--env')
    o = sub.add_parser('overlay')
    o.add_argument('--root', required=True)
    what = o.add_mutually_exclusive_group()
    what.add_argument('--classes', help='a Java layer to put in place of the release\'s Runtime/Android/Classes')
    what.add_argument('--engine', help='a runtime folder that tools/ci/build-android.sh wrote, to put in place '
                                       'of the release\'s Runtime/Android')
    what.add_argument('--beyond', help='a runtime folder that tools/ci/build-android.sh wrote, to put beside the '
                                       'release\'s Runtime/Android as Runtime/Android/Beyond, where a stack whose '
                                       '"android,engine" is "beyond" is built from (in place of a Beyond folder '
                                       'the release has)')
    i = sub.add_parser('ide')
    i.add_argument('--bin', dest='bin_dir')
    i.add_argument('--install')
    i.add_argument('--package')
    i.add_argument('--platform')
    i.add_argument('--work', required=True)
    i.add_argument('--sdk')
    i.add_argument('--jdk')
    i.add_argument('--device')
    i.add_argument('--stack')
    i.add_argument('--builds')
    i.add_argument('--no-units', action='store_true')
    i.add_argument('--android-engine', choices=('beyond',),
                   help='build the probe with this "android,engine" setting: beyond, OXT-Beyond\'s own engine, '
                        'which overlay --beyond puts beside the release\'s (9.6.3\'s otherwise)')
    i.add_argument('--probe', choices=sorted(PROBES), default='app',
                   help='java: the Java layer\'s probe (AndroidJavaProbe); busy: the app probe drawing all the '
                        'time it runs (AndroidBusyProbe); edge: the app probe drawn edge to edge, which says its '
                        'screen\'s rects (AndroidEdgeProbe)')
    i.add_argument('--timeout', type=int, default=1500)
    i.add_argument('--bundletool-fallback', action='store_true',
                   help='when GitHub\'s release host answers the builder\'s download of bundletool with an HTTP '
                        '5xx, download it with gh through GitHub\'s API and build the App Bundle again')
    v = sub.add_parser('verify')
    v.add_argument('--work', required=True)
    v.add_argument('--sdk', required=True)
    v.add_argument('--builds')
    v.add_argument('--jdk', help='the JDK whose jarsigner, keytool and java check an App Bundle')
    which = v.add_mutually_exclusive_group()
    which.add_argument('--target', default=TARGET_SDK,
                       help='the API the packages must target (%s with a runtime whose Java layer is not ready for '
                            'newer, %s when it is)' % (TARGET_SDK, NEWEST_TARGET_SDK))
    which.add_argument('--target-for', metavar='DIR',
                       help='an installed IDE: the packages must target the API its builder picks for its runtime')
    v.add_argument('--engine', help='the runtime folder that overlay --engine took: each package\'s engine must be '
                                    'the one built there')
    c = sub.add_parser('compare')
    c.add_argument('--old', required=True)
    c.add_argument('--new', required=True)
    c.add_argument('--sdk')
    c.add_argument('--builds')
    d = sub.add_parser('device')
    d.add_argument('--apk', required=True, help='a package, or an App Bundle (.aab)')
    d.add_argument('--bundletool', help='the bundletool jar that installs an App Bundle')
    d.add_argument('--jdk', help='the JDK whose java runs bundletool')
    d.add_argument('--serial', required=True)
    d.add_argument('--sdk', required=True)
    d.add_argument('--out')
    d.add_argument('--log-out')
    d.add_argument('--timeout', type=int, default=90)
    d.add_argument('--allow', metavar='PERMISSION',
                   help='the probe must ask for this runtime permission; allow it in Android\'s dialog, and '
                        'check that the package holds it')
    d.add_argument('--back', action='store_true',
                   help='once green, press the back key: the probe\'s backKey must turn the screen its back colour')
    d.add_argument('--within-bars', action='store_true',
                   help='once green, the screen\'s first and last rows (the system bars) must not be the stack\'s')
    d.add_argument('--edge-to-edge', action='store_true',
                   help='once green, the edge probe must be drawn under the status bar, and its effective working '
                        'screenRect leave the bars out')
    d.add_argument('--font-scale', action='store_true',
                   help='once green, change the font size: the app must go on in its process, still green')
    d.add_argument('--density', action='store_true',
                   help='once green, change the screen\'s density: the app must start again in a new process '
                        'and show its green there')
    d.add_argument('--density-times', type=int, default=1, metavar='N',
                   help='--density: change the density and back N times, the app starting again in a new process '
                        'each time')
    d.add_argument('--density-in-wait', action='store_true',
                   help='once green, tap the probe, whose mouseUp waits %d s with messages, and change the '
                        'density while it waits: the app must start again in a new process and show its green '
                        'there (the engine built here; 9.6.3\'s hangs)' % PROBE_WAIT)
    d.add_argument('--relaunch', action='store_true',
                   help='once green, press the back key, which the app probe passes, so its stack quits: its '
                        'process must end, and the app opened again must show its green in a new one')
    d.add_argument('--picture', metavar='NAME',
                   help='the probe exports a picture of this file name: it must be in the shared Pictures '
                        'folder as the package\'s own (MediaStore)')
    b = sub.add_parser('boot')
    b.add_argument('--serial', required=True)
    b.add_argument('--sdk', required=True)
    b.add_argument('--log', help="the emulator's own log, whose end is printed when it does not boot")
    b.add_argument('--minutes', type=float, default=10)
    b.add_argument('--interval', type=float, default=5)
    b.add_argument('--settle', action='store_true',
                   help="then wait for the first minute's work of a fresh image (settle)")
    b.add_argument('--settle-minutes', type=float, default=5)
    b.add_argument('--awake', action='store_true',
                   help='first put it to sleep once, wake it and keep it awake (awake)')
    b.add_argument('--settle-polls', type=int, default=3)
    args = ap.parse_args(argv)
    # --density-times counts --density's changes: from 1, and only with it
    if args.command == 'device' and (args.density_times < 1 or (args.density_times != 1 and not args.density)):
        d.error('--density-times takes a count from 1 up, and --density with it')
    # a stack inside the bars, or drawn under them: not both
    if args.command == 'device' and args.within_bars and args.edge_to_edge:
        d.error('--within-bars and --edge-to-edge ask for opposite screens: one or the other')
    try:
        problems = {'extract': extract, 'overlay': overlay, 'ide': ide, 'verify': verify, 'compare': compare,
                    'device': device, 'boot': boot}[args.command](args)
    except CheckError as e:
        problems = [str(e)]
    log()
    if problems:
        for x in problems:
            log('PROBLEM: %s' % x)
            annotate('error', 'Android %s: %s' % (args.command, x))
        summary('**Android %s**: %d problem(s)\n\n%s' % (args.command, len(problems),
                                                         '\n'.join('- ' + x for x in problems)))
        log('Android %s: failed' % args.command)
        return 1
    summary('**Android %s**: passed' % args.command)
    log('Android %s: passed' % args.command)
    return 0


if __name__ == '__main__':
    sys.exit(main())
