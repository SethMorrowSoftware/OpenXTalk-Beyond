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
  python3 tools/ci/android_check.py overlay --root DIR [--classes FILE]
  python3 tools/ci/android_check.py ide (--install DIR | --package FILE | --bin DIR)
      --work DIR [--sdk DIR] [--jdk DIR] [--platform P] [--device SERIAL]
      [--stack FILE] [--builds NAMES] [--no-units] [--probe java] [--timeout SECONDS]
  python3 tools/ci/android_check.py verify --work DIR --sdk DIR
  python3 tools/ci/android_check.py compare --old DIR --new DIR --sdk DIR
  python3 tools/ci/android_check.py device --apk FILE --serial SERIAL --sdk DIR
      [--out FILE] [--abi ABI] [--timeout SECONDS]

extract unpacks a package as tools/ci/run_livecode_check.py does (modes and
symbolic links kept) and prints the folder to give --install, and with
--env NAME also writes NAME=<folder> to $GITHUB_ENV.

overlay puts this checkout's Android builder (OVERLAY) into an installed
OXT-Beyond (a released one), over the files of the same names, so that the
release's IDE runs the changed builder, and the comparison is of the
builders alone, with the same engine and runtimes. --classes also puts a
Java layer (tools/ci/android_java.py build) in place of the release's
Runtime/Android/Classes.

ide starts the IDE as a user starts it (as tools/ci/web_check.py does, under
xvfb-run on Linux without a DISPLAY) with tools/ci/android-check.livecodescript
named on its command line. That script runs the units of the builder's new
handlers, which need no Android SDK, and with --sdk builds the probe stack
four times with the builder (see BUILDS) into <work>/out/<name>.apk; with
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
package name and target API, and the builder's warnings.

compare checks that two sets of packages (the released builder's and the
changed one's, of the same probe stack) hold the same files with the same
bytes, apart from what the change meant to change: the signatures (see
EXPECTED_SIGNING) and, in the debug build, the push receiver's
android:exported (see EXPECTED_MANIFEST). Every difference is printed.

device installs a package on a device or emulator with adb, starts it and
waits until the screen is the probe's green (kRunColor in
android-check.livecodescript), which only the probe's openStack makes: the
engine loaded, opened the stack and ran its script. The Java layer's
probe's FAIL_COLOR ends the wait too, as a failure: its script ran and a
call into the Java layer failed. The screen is saved as
a PNG (--out), and the probe's own lines in the device's log are searched
for its crash (the engine's caught attempt at an SSL library the package
does not hold is expected, and only then: crash_lines). When it is not
running, crashed or was started more than once, it prints the logs'
account of its processes, how each ended (dumpsys activity exit-info) and
the memory left.

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

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later), with the Android SDK's adb,
apksigner, aapt and zipalign.
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
# The probes (--probe): the stack file each is saved as
PROBES = {'app': 'AndroidProbe.livecode', 'java': 'AndroidJavaProbe.livecode'}
# Where a release's Java layer is (overlay --classes)
CLASSES = ('Runtime', 'Android', 'Classes')
TARGET_SDK = '33'
KEY_ALIAS = 'oxtcheck'
KEY_PASSWORD = 'oxtcheck-pass'
KEY_DNAME = 'CN=OXT Android Check, O=OXT-Beyond, C=US'
DEBUG_DNAME = 'CN=Android Debug, O=Android, C=US'
SIG_BLOCK_MAGIC = b'APK Sig Block 42'
PAGE_16K = 16384

# What each build of android-check.livecodescript is: its architectures,
# who signs it (None: nobody), whether it has the push receiver, and the
# warnings the builder must give (each a piece of one warning line)
BUILDS = {
    'debug': {'abis': {'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'}, 'signer': DEBUG_DNAME, 'push': True,
              'warnings': []},
    'release': {'abis': {'arm64-v8a', 'x86_64'}, 'signer': KEY_DNAME, 'push': False, 'warnings': []},
    'unsigned': {'abis': {'arm64-v8a'}, 'signer': None, 'push': False, 'warnings': []},
    'legacy': {'abis': {'armeabi-v7a'}, 'signer': None, 'push': False,
               'warnings': ['built for armv7 and not arm64']},
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
}
# compare: the manifest lines (aapt's xmltree, without line numbers) the
# change added, per build. A line the old package already has is not
# expected to differ: that release's builder carries the change (0.2.7-
# rc.6.16 and later carry this one)
EXPECTED_MANIFEST = {
    'debug': ['receiver PushReceiver: android:exported=true'],
}


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


def ide_results(lines):
    """From the IDE's lines: units (name -> None or why it failed), builds
    (name -> apk or the failure), warnings and questions (name -> text),
    test (None, True or the failure), errors, and done."""
    r = {'units': {}, 'builds': {}, 'warnings': {}, 'asked': {}, 'test': None, 'errors': [], 'done': False}
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
    if args.classes:
        places = [x for x in found.get(CLASSES[-1], [])
                  if tuple(os.path.normpath(x).split(os.sep)[-len(CLASSES):]) == CLASSES]
        if len(places) != 1:
            problems.append('%s: %d files %s, not one' % (root, len(places), '/'.join(CLASSES)))
        else:
            shutil.copyfile(args.classes, places[0])
            log('%s -> %s' % (args.classes, os.path.relpath(places[0], root)))
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
                   OXT_ANDROID_PROBE='java' if args.probe == 'java' else '')
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
        log('Running: %s' % ' '.join(cmd))
        started = progress = time.time()
        status = 'did not finish within %d seconds' % args.timeout
        with open(os.path.join(work, 'ide-output.txt'), 'wb') as engine_log:
            kw = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else \
                {'start_new_session': True}
            proc = subprocess.Popen(cmd, cwd=work, env=env, stdout=engine_log, stderr=subprocess.STDOUT, **kw)
            try:
                while time.time() - started < args.timeout:
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
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    lines = read_lines(results)
    for line in lines:
        log('  ide: %s' % line)
    r = ide_results(lines)
    if status:
        problems.append('the IDE %s' % status)
        for line in read_lines(os.path.join(work, 'ide-output.txt'))[-40:]:
            log('  ide output: %s' % line)
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


def verify_apk(name, apk, spec, tools, warnings):
    """The problems of one package, and lines saying what was checked."""
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
        if "targetSdkVersion:'%s'" % TARGET_SDK not in badging:
            problems.append('%s does not target API %s' % (name, TARGET_SDK))
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


def find_tools(sdk):
    tools = {'apksigner': build_tool(sdk, 'apksigner'), 'aapt': build_tool(sdk, 'aapt'),
             'zipalign': build_tool(sdk, 'zipalign')}
    if not tools['apksigner']:
        raise CheckError('no apksigner in %s/build-tools' % sdk)
    return tools


def verify(args):
    work = os.path.abspath(args.work)
    tools = find_tools(args.sdk)
    r = ide_results(read_lines(os.path.join(work, LOG_NAME)))
    problems = []
    names = (args.builds or ','.join(BUILDS)).split(',')
    for name in names:
        apk = os.path.join(work, 'out', name + '.apk')
        if not os.path.isfile(apk):
            problems.append('there is no %s' % apk)
            continue
        p, notes = verify_apk(name, apk, BUILDS[name], tools, r['warnings'])
        log('%s.apk (%.1f MB): %s' % (name, os.path.getsize(apk) / 1e6, '; '.join(notes)))
        for x in p:
            log('  PROBLEM: %s' % x)
        problems += p
    leftovers = [x for x in os.listdir(os.path.join(work, 'out')) if not x.endswith('.apk')]
    if leftovers:
        problems.append('the builder left other files beside the packages: %s' % ', '.join(sorted(leftovers)))
    return problems


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

def device(args):
    adb = adb_path(args.sdk)
    if not adb:
        raise CheckError('no adb')
    problems = []

    def a(*cmd, timeout=180):
        return run([adb, '-s', args.serial] + list(cmd), timeout=timeout)
    _, props = a('shell', 'getprop', 'ro.build.version.sdk')
    _, page = a('shell', 'getconf', 'PAGE_SIZE')
    _, abi = a('shell', 'getprop', 'ro.product.cpu.abi')
    log('Device %s: API %s, %s, pages of %s bytes' % (args.serial, props.strip(), abi.strip(), page.strip()))
    a('uninstall', IDENTIFIER)
    status, out = a('install', '-r', args.apk, timeout=600)
    if 'Success' not in out:
        return ['%s does not install on %s: %s' % (os.path.basename(args.apk), args.serial, out.strip()[-800:])]
    log('Installed %s' % os.path.basename(args.apk))
    a('logcat', '-c')
    status, out = a('shell', 'am', 'start', '-W', '-n', IDENTIFIER + '/.mblandroid')
    log('Started: %s' % ' | '.join(x.strip() for x in out.splitlines() if x.strip()))
    if 'Error' in out:
        problems.append('the app does not start: %s' % out.strip()[-500:])
    started = time.time()
    share = saved = failed = 0.0
    w = h = 0
    rgba = b''
    while time.time() - started < args.timeout:
        time.sleep(3)
        try:
            proc = subprocess.run([adb, '-s', args.serial, 'exec-out', 'screencap'], stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, timeout=60)
            w, h, rgba = screen_from_raw(proc.stdout)
        except (CheckError, subprocess.TimeoutExpired) as e:
            log('  screencap: %s' % e)
            continue
        share, saved = colour_share(rgba, RUN_COLOR), colour_share(rgba, SAVED_COLOR)
        failed = colour_share(rgba, FAIL_COLOR)
        if share >= 0.25 or failed >= 0.25:
            break
    _, pid = a('shell', 'pidof', IDENTIFIER)
    _, logcat = a('logcat', '-d', '-v', 'brief')
    pids = probe_pids(logcat, pid)
    with zipfile.ZipFile(args.apk) as z:
        crash, expected, others = crash_lines(logcat, z.namelist(), pids)
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
    if failed >= 0.25:
        problems.append('the probe\'s script ran, and a call it makes into the Java layer failed (the screen '
                        'is its fail colour, %.0f%%)' % (failed * 100))
    elif share < 0.25:
        problems.append('the screen never turned the probe\'s green (%.0f%% green, %.0f%% red: %s)' % (
            share * 100, saved * 100, 'the stack showed and its script did not run' if saved >= 0.25 else
            'the stack never showed'))
    if not pid.strip():
        problems.append('the app is not running')
    if crash:
        problems.append('the device\'s log: %s' % ' | '.join(crash[:8]))
    if problems or len(pids) > 1:
        # why, before anything is changed: the logs' account of the probe's
        # processes, how each one ended (ApplicationExitInfo, Android 11 and
        # newer) and the memory left
        if len(pids) > 1:
            log('NOTE: the probe was started %d times (processes %s)' % (len(pids), ', '.join(sorted(pids))))
        _, events = a('logcat', '-d', '-b', 'events', '-v', 'brief')
        for heading, lines in probe_story(logcat, events, pids):
            log('%s:%s' % (heading, '' if lines else ' none'))
            for line in lines:
                log('  ' + line)
        _, exits = a('shell', 'dumpsys', 'activity', 'exit-info', IDENTIFIER)
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
    return problems


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
    o.add_argument('--classes', help='a Java layer to put in place of the release\'s Runtime/Android/Classes')
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
    i.add_argument('--probe', choices=sorted(PROBES), default='app',
                   help='java: the Java layer\'s probe (AndroidJavaProbe)')
    i.add_argument('--timeout', type=int, default=1500)
    v = sub.add_parser('verify')
    v.add_argument('--work', required=True)
    v.add_argument('--sdk', required=True)
    v.add_argument('--builds')
    c = sub.add_parser('compare')
    c.add_argument('--old', required=True)
    c.add_argument('--new', required=True)
    c.add_argument('--sdk')
    c.add_argument('--builds')
    d = sub.add_parser('device')
    d.add_argument('--apk', required=True)
    d.add_argument('--serial', required=True)
    d.add_argument('--sdk', required=True)
    d.add_argument('--out')
    d.add_argument('--log-out')
    d.add_argument('--timeout', type=int, default=90)
    b = sub.add_parser('boot')
    b.add_argument('--serial', required=True)
    b.add_argument('--sdk', required=True)
    b.add_argument('--log', help="the emulator's own log, whose end is printed when it does not boot")
    b.add_argument('--minutes', type=float, default=10)
    b.add_argument('--interval', type=float, default=5)
    b.add_argument('--settle', action='store_true',
                   help="then wait for the first minute's work of a fresh image (settle)")
    b.add_argument('--settle-minutes', type=float, default=5)
    b.add_argument('--settle-polls', type=int, default=3)
    args = ap.parse_args(argv)
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
