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

"""Build the Android Stack Player with the IDE's own Android builder, check
its package, and play stacks in it on a device.

  python3 tools/android-player/build_android_player.py library --ide DIR
  python3 tools/android-player/build_android_player.py build --ide DIR --work DIR --sdk SDK --jdk JDK
      [--platform P] [--version NAME] [--keystore FILE --alias NAME --password WORD]
      [--timeout SECONDS]
  python3 tools/android-player/build_android_player.py verify --work DIR --sdk SDK
  python3 tools/android-player/build_android_player.py device --work DIR --serial SERIAL --sdk SDK
      [--timeout SECONDS] [--no-picker]

library compiles the Android Documents library
(extensions/libraries/androiddocuments) with the lc-compile of the IDE of
--ide (its Toolchain) into that IDE's Extensions folder, for an IDE of a
release that does not carry it yet. An IDE that has it is left as it is.

build starts the IDE of --ide as a user starts it (as
tools/ci/android_check.py ide does, under xvfb-run on Linux without a
DISPLAY) with build-player.livecodescript named on its command line, whose
header says what it makes: <work>/OXT-Stack-Player.apk, and the sample
stacks of the device check in <work>/samples. Its lines go to
<work>/player-build.txt, which this prints.

verify reads the package with the SDK's aapt2: its name
(org.openxtalk.stackplayer), that it asks for the Internet permission and
no other, and that its activity is offered for documents (a VIEW filter
with the content scheme and a kind of document).

device installs the package on a device or emulator and plays the sample
stack in it by each way a stack comes in, reading what the player and the
sample say in the device's log ("OXT Stack Player: ..."):

  file     a file address (file:///data/local/tmp/...), as an old file
           manager gives one
  back     Android's Back while the stack plays: home, and still running
  content  a content address (the documents provider's, for a file in
           Download), as a file manager, a mail app or a browser gives one
  picker   the player's Open button, and the file chosen on Android's
           "Open document" screen (not with --no-picker)
  library  the app stopped and started again: the stacks taken in are
           still in its library, and none was opened by itself
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import android_check as ac  # noqa: E402

IDENTIFIER = 'org.openxtalk.stackplayer'
ACTIVITY = IDENTIFIER + '/.mblandroid'
APK_NAME = 'OXT-Stack-Player.apk'
LOG_NAME = 'player-build.txt'
LIBRARY_ID = 'org.openxtalk.library.androiddocuments'
LIBRARY_SOURCE = os.path.join(REPO, 'extensions', 'libraries', 'androiddocuments', 'androiddocuments.lcb')
SAMPLE = 'PlayerSample.oxtstack'
SAMPLE_STACK = 'Player Sample'
# What the player says in the device's log (kSays), and the sample
SAYS = re.compile(r'OXT Stack Player: (.*?)\s*$')
SAMPLE_SAYS = re.compile(r'OXT Stack Player sample: (.*?)\s*$')
PERMISSIONS = {'android.permission.INTERNET'}

log = ac.log
CheckError = ac.CheckError


def path(x):
    return x.replace('\\', '/') if x else ''


# ----------------------------------------------------------------------
# library
# ----------------------------------------------------------------------

def ide_tools(ide):
    """(lc-compile, the folder of the .lci interface files, the Extensions
    folder) of an installed or unpacked IDE."""
    for root in (ide, os.path.join(ide, 'Contents', 'Tools')):
        toolchain = os.path.join(root, 'Toolchain')
        compiler = os.path.join(toolchain, 'lc-compile' + ('.exe' if os.name == 'nt' else ''))
        if os.path.isfile(compiler):
            return compiler, os.path.join(toolchain, 'modules', 'lci'), os.path.join(root, 'Extensions')
    raise CheckError('no Toolchain/lc-compile in %s' % ide)


def library(args):
    compiler, lci, extensions = ide_tools(os.path.abspath(args.ide))
    dest = os.path.join(extensions, LIBRARY_ID)
    if os.path.isfile(os.path.join(dest, 'module.lcm')) and not args.force:
        log('%s is in the IDE already: %s' % (LIBRARY_ID, dest))
        return 0
    os.makedirs(dest, exist_ok=True)
    source = os.path.join(dest, os.path.basename(LIBRARY_SOURCE))
    shutil.copyfile(LIBRARY_SOURCE, source)
    cmd = [compiler, '--modulepath', lci, '--modulepath', dest, '--manifest', os.path.join(dest, 'manifest.xml'),
           '--output', os.path.join(dest, 'module.lcm'), source]
    status, out = ac.run(cmd, timeout=300)
    if status != 0 or not os.path.isfile(os.path.join(dest, 'module.lcm')):
        log('PROBLEM: lc-compile: %s' % out.strip()[-1500:])
        return 1
    log('Compiled %s into %s' % (LIBRARY_ID, dest))
    return 0


# ----------------------------------------------------------------------
# build
# ----------------------------------------------------------------------

def build_results(lines):
    """From the IDE's lines: {'ok': the package or None, 'failed': why or
    None, 'errors': [...], 'info': {name: value}, 'done': bool}."""
    r = {'ok': None, 'failed': None, 'errors': [], 'info': {}, 'done': False}
    for line in lines:
        if line.startswith('BUILD OK '):
            r['ok'] = line[9:].strip()
        elif line.startswith('BUILD FAILED'):
            r['failed'] = line[12:].strip() or 'failed'
        elif line.startswith('ERROR'):
            r['errors'].append(line[5:].strip())
        elif line.startswith('INFO '):
            name, _, value = line[5:].partition(' ')
            r['info'][name] = value.strip()
        elif line.startswith('DONE'):
            r['done'] = True
    return r


def build(args):
    import ui_tour
    package, rlc = ui_tour.package, ui_tour.rlc
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    work = os.path.abspath(args.work)
    os.makedirs(work, exist_ok=True)
    results = os.path.join(work, LOG_NAME)
    apk = os.path.join(work, APK_NAME)
    samples = os.path.join(work, 'samples')
    shutil.rmtree(samples, ignore_errors=True)
    # the document the IDE opens: a copy, as android_check.py opens its script
    document = os.path.join(work, 'oxt_build_android_player.livecodescript')
    shutil.copyfile(os.path.join(HERE, 'build-player.livecodescript'), document)
    temp_dirs, problems = [], []
    args.install, args.package, args.bin_dir, args.engine = os.path.abspath(args.ide), None, None, None
    try:
        try:
            lay = rlc.find_layout(args, p, temp_dirs)
        except rlc.CheckError as e:
            raise CheckError(str(e))
        log('Layout : %s' % lay.root)
        log('Engine : %s' % lay.engine)
        env = dict(os.environ)
        env.pop('JAVA_TOOL_OPTIONS', None)
        env.update(OXT_APLAYER_SOURCE=path(HERE), OXT_APLAYER_WORK=path(os.path.join(work, 'stack')),
                   OXT_APLAYER_APK=path(apk), OXT_APLAYER_SDK=path(args.sdk), OXT_APLAYER_JDK=path(args.jdk),
                   OXT_APLAYER_KEYSTORE=path(args.keystore or ''), OXT_APLAYER_ALIAS=args.alias or '',
                   OXT_APLAYER_PASSWORD=args.password or '', OXT_APLAYER_VERSION=args.version or '',
                   OXT_APLAYER_SAMPLES=path(samples), OXT_APLAYER_LOG=path(results))
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
        status = ac.run_ide(cmd, work, env, results, args.timeout, 'ide-output.txt')
        lines = ac.read_lines(results)
        for line in lines:
            log('  ide: %s' % line)
        r = build_results(lines)
        if status:
            problems.append('the IDE %s' % status)
            for line in ac.read_lines(os.path.join(work, 'ide-output.txt'))[-40:]:
                log('  ide output: %s' % line)
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    problems += ['the IDE: %s' % x for x in r['errors']]
    if r['failed']:
        problems.append('the build failed: %s' % r['failed'])
    elif not r['ok'] or not os.path.isfile(apk):
        problems.append('no package was built')
    if not args.no_samples and not os.path.isfile(os.path.join(samples, SAMPLE)):
        problems.append('the sample stack %s was not made' % SAMPLE)
    if os.path.isfile(apk):
        log('Package: %s (%.1f MB)' % (apk, os.path.getsize(apk) / 1e6))
    return finish('build', problems)


def finish(name, problems):
    log()
    for x in problems:
        log('PROBLEM: %s' % x)
        ac.annotate('error', 'Android Stack Player %s: %s' % (name, x))
    log('Android Stack Player %s: %s' % (name, 'failed' if problems else 'passed'))
    return 1 if problems else 0


# ----------------------------------------------------------------------
# verify
# ----------------------------------------------------------------------

def badging_problems(badging):
    """What aapt2 dump badging says of the package that it should not."""
    problems = []
    m = re.search(r"^package: name='([^']*)'", badging, re.M)
    if not m or m.group(1) != IDENTIFIER:
        problems.append('the package is named %s, not %s' % (m.group(1) if m else '(nothing)', IDENTIFIER))
    asked = set(re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']*)'", badging, re.M))
    # the engine's own file provider permission is the app's, not the device's
    asked = {x for x in asked if not x.startswith(IDENTIFIER + '.')}
    if asked != PERMISSIONS:
        problems.append('the package asks for %s, not for the Internet alone' % (
            ', '.join(sorted(asked)) or 'no permission'))
    return problems


def document_filter_problems(xmltree):
    """Whether the manifest (aapt2 dump xmltree) has a VIEW filter with the
    content scheme and a kind of document."""
    filters = re.split(r'\n\s*E: intent-filter', xmltree)[1:]
    for f in filters:
        f = re.split(r'\n\s*E: (?:activity|service|receiver|provider|meta-data)\b', f)[0]
        if 'android.intent.action.VIEW' in f and re.search(r'scheme\S*="content"', f) and \
                re.search(r'mimeType\S*="application/octet-stream"', f):
            return []
    return ['the manifest has no filter that offers the app for documents (VIEW, the content scheme, '
            'application/octet-stream)']


def verify(args):
    apk = os.path.join(os.path.abspath(args.work), APK_NAME)
    if not os.path.isfile(apk):
        return finish('verify', ['no package: %s' % apk])
    aapt = ac.build_tool(args.sdk, 'aapt2')
    if not aapt:
        return finish('verify', ['no aapt2 in the SDK'])
    _, badging = ac.run([aapt, 'dump', 'badging', apk])
    _, tree = ac.run([aapt, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk])
    for line in badging.splitlines():
        if line.startswith(('package:', 'uses-permission', 'sdkVersion', 'targetSdkVersion', 'native-code')):
            log('  ' + line.strip())
    problems = badging_problems(badging) + document_filter_problems(tree)
    return finish('verify', problems)


# ----------------------------------------------------------------------
# device
# ----------------------------------------------------------------------

def said(logcat, pattern=SAYS):
    return [m.group(1) for m in (pattern.search(line) for line in logcat.splitlines()) if m]


def refusals(logcat):
    """The lines of a log in which Android refuses to let a document be
    read, without their dates."""
    out = []
    for line in logcat.splitlines():
        if re.search(r'SecurityException|Permission Denial|Uri permission grant|FileNotFoundException', line):
            out.append(re.sub(r'^\S+ +\S+ +\d+ +\d+ +', '', line).strip()[:300])
    return out


def node_centre(xml, text):
    """The centre of the first node of a uiautomator dump whose text is
    text, or None."""
    try:
        root = ET.fromstring(xml[xml.index('<?xml'):] if '<?xml' in xml else xml)
    except (ET.ParseError, ValueError):
        return None
    for node in root.iter('node'):
        if node.get('text') == text:
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
            if m:
                x1, y1, x2, y2 = (int(v) for v in m.groups())
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def document_address(name):
    """The documents provider's address of a file of the device's Download
    folder."""
    return 'content://com.android.externalstorage.documents/document/primary%3ADownload%2F' + name


class Device:
    def __init__(self, sdk, serial):
        self.adb = ac.adb_path(sdk)
        if not self.adb:
            raise CheckError('no adb')
        self.serial = serial

    def __call__(self, *cmd, timeout=180):
        return ac.run([self.adb, '-s', self.serial] + list(cmd), timeout=timeout)

    def logcat(self):
        return self('logcat', '-d', '-v', 'threadtime', timeout=120)[1]

    def wait_for(self, what, timeout, pattern=SAYS, since=0):
        """Waits until the lines said since the since-th hold one that what
        (a function of a line) takes; returns (that line or None, every
        line said so far)."""
        started = time.time()
        lines = []
        while time.time() - started < timeout:
            lines = said(self.logcat(), pattern)
            for line in lines[since:]:
                if what(line):
                    return line, lines
            time.sleep(2)
        return None, lines

    def running(self):
        return bool(self('shell', 'pidof', IDENTIFIER)[1].strip())

    def focus(self):
        """The window that has the focus, as dumpsys names it."""
        m = re.search(r'mCurrentFocus=(.*)', self('shell', 'dumpsys', 'window', 'displays')[1])
        return m.group(1).strip() if m else 'not said'

    def ui(self):
        self('shell', 'uiautomator', 'dump', '/sdcard/oxt-player-ui.xml')
        return self('shell', 'cat', '/sdcard/oxt-player-ui.xml')[1]


def device(args):
    work = os.path.abspath(args.work)
    apk = os.path.join(work, APK_NAME)
    sample = os.path.join(work, 'samples', SAMPLE)
    for f in (apk, sample):
        if not os.path.isfile(f):
            return finish('device', ['no %s' % f])
    d = Device(args.sdk, args.serial)
    problems, passed = [], []
    wait = args.timeout

    def step(name, ok, why=''):
        if ok:
            passed.append(name)
            log('OK      %s' % name)
        else:
            problems.append('%s: %s' % (name, why))
            log('FAILED  %s: %s' % (name, why))
        return ok

    def count():
        return len(said(d.logcat()))

    _, api = d('shell', 'getprop', 'ro.build.version.sdk')
    log('Device %s: API %s' % (args.serial, api.strip()))
    # as the shell, not as root: Android lets the shell lend the app a
    # document with a VIEW intent as a file manager does, and refuses root
    # ("the system cannot issue a Uri permission grant")
    _, who = d('shell', 'id', '-u')
    if who.strip() == '0':
        d('unroot')
        time.sleep(3)
        d('wait-for-device', timeout=60)
        _, who = d('shell', 'id', '-u')
    log('adb shell is user %s' % who.strip())

    d('uninstall', IDENTIFIER)
    status, out = d('install', '-r', apk, timeout=600)
    if 'Success' not in out:
        return finish('device', ['%s does not install: %s' % (APK_NAME, out.strip()[-800:])])
    log('Installed %s' % APK_NAME)
    ac.quiet_after_install(d)
    d('shell', 'rm', '-f', '/data/local/tmp/' + SAMPLE, '/sdcard/Download/' + SAMPLE)
    d('push', sample, '/data/local/tmp/' + SAMPLE)
    d('shell', 'chmod', '644', '/data/local/tmp/' + SAMPLE)
    d('push', sample, '/sdcard/Download/' + SAMPLE)
    d('logcat', '-c')

    try:
        # ---- start
        _, out = d('shell', 'am', 'start', '-W', '-n', ACTIVITY)
        log('Started: %s' % ' | '.join(x.strip() for x in out.splitlines() if x.strip()))
        line, lines = d.wait_for(lambda x: x.startswith('ready'), wait)
        if not step('start', line is not None, 'the player never said it was ready; it said: %s' % lines):
            raise CheckError('the player did not start')
        log('  %s' % line)

        # ---- a file address
        at = count()
        d('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'file:///data/local/tmp/' + SAMPLE,
          '-t', 'application/octet-stream', '-n', ACTIVITY)
        line, lines = d.wait_for(lambda x: x.startswith(('opened ', 'problem ')), wait, since=at)
        if step('file', line == 'opened ' + SAMPLE_STACK, 'the player said: %s' % lines[at:]):
            line, sample_lines = d.wait_for(lambda x: x.startswith('opened in '), 20, SAMPLE_SAYS)
            step('file: the stack runs its own script, in its own folder',
                 line is not None and line.rstrip('/').endswith('/Stack Player/PlayerSample'),
                 'the sample said: %s' % sample_lines)
            size = [x for x in sample_lines if x.startswith('size ')]
            step('file: the stack keeps its size and is shown whole',
                 bool(size) and size[-1] == 'size 800,600 showAll', 'the sample said: %s' % sample_lines)

            # ---- Back
            at = count()
            focus = d.focus()
            d('shell', 'input', 'keyevent', '4')
            line, lines = d.wait_for(lambda x: x.startswith('home from '), 20, since=at)
            why = ''
            if line is None:
                # what a second press does says whether the first was lost
                # on its way or the stack never comes home
                why = 'no answer to Back in 20 s (the window with the focus before it: %s; after: %s)' % (
                    focus, d.focus())
                d('shell', 'input', 'keyevent', '4')
                again, lines = d.wait_for(lambda x: x.startswith('home from '), wait, since=at)
                why += '; a second Back %s' % ('came home' if again else 'did nothing either')
            step('back', line == 'home from ' + SAMPLE_STACK, '%s; the player said: %s' % (why, lines[at:]))
            time.sleep(2)
            step('back: the app is still running', d.running(), 'its process has gone')

        # ---- a content address
        at = count()
        _, out = d('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', document_address(SAMPLE),
                   '-t', 'application/octet-stream', '--grant-read-uri-permission', '-n', ACTIVITY)
        line, lines = d.wait_for(lambda x: x.startswith(('opened ', 'problem ')), wait, since=at)
        ok = step('content', line == 'opened ' + SAMPLE_STACK,
                  'the player said: %s; am start said: %s; the device said: %s' % (
                      lines[at:], ac.answer(out), refusals(d.logcat())[-4:]))
        if ok:
            # the very file the file address gave: the library's copy of it
            step('content: read, and known as the file the library has', 'imported PlayerSample/' + SAMPLE in lines[at:],
                 'the player said: %s' % lines[at:])
            d('shell', 'input', 'keyevent', '4')
            d.wait_for(lambda x: x.startswith('home from '), wait, since=at)

        # ---- the Open button and Android's "Open document" screen
        if not args.no_picker:
            picker(d, step, count, wait)

        # ---- stopped and started again
        d('shell', 'am', 'force-stop', IDENTIFIER)
        time.sleep(2)
        at = count()
        d('shell', 'am', 'start', '-W', '-n', ACTIVITY)
        line, lines = d.wait_for(lambda x: x.startswith('ready'), wait, since=at)
        step('library: the player starts again', line is not None, 'the player said: %s' % lines[at:])
        line, lines = d.wait_for(lambda x: x.startswith('library '), 20, since=at)
        kept = int(line.split()[1]) if line and line.split()[1].isdigit() else 0
        step('library: the stack taken in is still there', kept >= 1, 'the player said: %s' % lines[at:])
        time.sleep(4)
        opened = [x for x in said(d.logcat())[at:] if x.startswith(('opened ', 'taking '))]
        step('library: nothing opens by itself', not opened, 'the player said: %s' % opened)
    except CheckError as e:
        problems.append(str(e))
    finally:
        logcat = d.logcat()
        with open(os.path.join(work, 'player-logcat-%s.txt' % args.serial), 'w', encoding='utf-8',
                  errors='replace') as f:
            f.write(logcat)
        shot = ac.screen_now(d.adb, args.serial)
        if shot:
            ac.save_screen(os.path.join(work, 'player-screen-%s.png' % args.serial), shot, 'the last screen')
        log()
        log('What the player said:')
        for line in said(logcat):
            log('  %s' % line)
        for line in said(logcat, SAMPLE_SAYS):
            log('  (sample) %s' % line)
        crashes = [x for x in logcat.splitlines() if 'FATAL EXCEPTION' in x or
                   ('Fatal signal' in x and 'libc' in x)]
        for line in crashes[:10]:
            log('  crash: %s' % line.strip())
        if problems:
            # the job's log is all a reader of a failed run may have
            pid = d('shell', 'pidof', IDENTIFIER)[1].strip()
            own = [x for x in logcat.splitlines() if (pid and (' %s ' % pid) in x) or 'System.err' in x
                   or 'AndroidRuntime' in x]
            log()
            log('The last of the app\'s own log:')
            for line in own[-80:]:
                log('  %s' % line.strip()[:400])
    ac.summary('- the Android Stack Player on API %s: %d steps passed, %d failed%s' % (
        api.strip(), len(passed), len(problems), ''.join('\n  - ' + x for x in problems)))
    return finish('device', problems)


def picker(d, step, count, wait):
    """The player's Open button, then the sample chosen on Android's "Open
    document" screen."""
    lines = said(d.logcat())
    spot = [x for x in lines if x.startswith('open button at ')]
    m = re.match(r'open button at (\d+),(\d+)', spot[-1]) if spot else None
    if not step('picker: the player says where its Open button is', m is not None, 'it said: %s' % lines):
        return
    at = count()
    d('shell', 'input', 'tap', m.group(1), m.group(2))
    # the screen is Android's own (DocumentsUI): the file is in Download,
    # which the screen may not show first
    where = None
    for attempt in range(12):
        time.sleep(3)
        xml = d.ui()
        where = node_centre(xml, SAMPLE)
        if where:
            break
        if attempt == 3:
            # the roots drawer, then Downloads
            menu = None
            try:
                root = ET.fromstring(xml[xml.index('<?xml'):])
                for node in root.iter('node'):
                    if node.get('content-desc') in ('Show roots', 'Open navigation drawer'):
                        mm = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
                        menu = ((int(mm.group(1)) + int(mm.group(3))) // 2, (int(mm.group(2)) + int(mm.group(4))) // 2)
            except (ET.ParseError, ValueError):
                pass
            if menu:
                d('shell', 'input', 'tap', str(menu[0]), str(menu[1]))
                time.sleep(2)
                downloads = node_centre(d.ui(), 'Downloads')
                if downloads:
                    d('shell', 'input', 'tap', str(downloads[0]), str(downloads[1]))
    if not step('picker: Android shows the file to choose', where is not None,
                'no %s on the "Open document" screen; the player said: %s' % (SAMPLE, said(d.logcat())[at:])):
        d('shell', 'input', 'keyevent', '4')
        return
    d('shell', 'input', 'tap', str(where[0]), str(where[1]))
    line, lines = d.wait_for(lambda x: x.startswith(('opened ', 'problem ', 'chose nothing')), wait, since=at)
    step('picker', line == 'opened ' + SAMPLE_STACK, 'the player said: %s' % lines[at:])
    if line and line.startswith('opened '):
        d('shell', 'input', 'keyevent', '4')
        d.wait_for(lambda x: x.startswith('home from '), wait, since=at)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = parser.add_subparsers(dest='command', required=True)
    c = sub.add_parser('library')
    c.add_argument('--ide', required=True)
    c.add_argument('--force', action='store_true')
    c = sub.add_parser('build')
    c.add_argument('--ide', required=True)
    c.add_argument('--work', required=True)
    c.add_argument('--sdk', required=True)
    c.add_argument('--jdk', required=True)
    c.add_argument('--platform')
    c.add_argument('--version')
    c.add_argument('--keystore')
    c.add_argument('--alias')
    c.add_argument('--password')
    c.add_argument('--no-samples', action='store_true')
    c.add_argument('--timeout', type=int, default=1500)
    c = sub.add_parser('verify')
    c.add_argument('--work', required=True)
    c.add_argument('--sdk', required=True)
    c = sub.add_parser('device')
    c.add_argument('--work', required=True)
    c.add_argument('--serial', required=True)
    c.add_argument('--sdk', required=True)
    c.add_argument('--timeout', type=int, default=90)
    c.add_argument('--no-picker', action='store_true')
    args = parser.parse_args(argv)
    try:
        return {'library': library, 'build': build, 'verify': verify, 'device': device}[args.command](args)
    except CheckError as e:
        log('PROBLEM: %s' % e)
        return 1


if __name__ == '__main__':
    sys.exit(main())
