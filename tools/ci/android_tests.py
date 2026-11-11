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

"""Run the LiveCode Script tests of tests/lcs in an Android standalone, on
an Android device or emulator, and compare the failures with a baseline of
known ones, one for each engine.

  python3 tools/ci/android_tests.py prepare --work DIR --ide DIR [--filter REGEX]
  python3 tools/ci/android_check.py ide --install DIR --work DIR --sdk SDK --jdk JDK \\
      --no-units --builds debug --probe tests [--android-engine beyond]
  python3 tools/ci/android_tests.py run --work DIR --serial SERIAL --sdk SDK --engine NAME \\
      [--timeout SECONDS] [--baseline FILE] [--update-baseline] [--results FILE]
  python3 tools/ci/android_tests.py compare --old FILE --new FILE

prepare puts into --work what the standalone is built from, beside the
stack file that android_check.py ide --probe tests makes there
(StandaloneTestRunnerMainstack.livecode): the stack's script,
android-tests.livecodescript (from tools/ci, whose header says how it runs
the tests and what it writes to the device's log), and its copy files,
two folders:

  oxt-tests/            the checkout's tests/ folder; _tests/_build/, the
                        LiveCode Builder modules of tests/ compiled by the
                        lc-compile of the IDE of --ide (its Toolchain), as
                        tools/ci/run_engine_tests.py compiles them; the
                        engine's lists of errors and the files of the
                        checkout that tests read (TestGetEngineRepositoryPath()
                        & "/<path>", TestGetIDERepositoryPath() &
                        "/<path>"), as tools/ci/web_tests.py finds them;
                        android-tests.txt, the tests to run, and files.txt,
                        every file of the folder
  packaged_extensions/  the extensions that the tests load
                        (TestLoadExtension), from the IDE's Extensions
                        folder

The tests are the "on Test..." handlers of tests/lcs, as run_engine_tests.py
finds them (--filter: only those whose "lcs: <test>" matches), and prepare
writes their names to android-tests.json in --work for run.

run installs the package that ide built (--apk, default
<work>/out/debug.apk) on the device, starts it, and reads its lines in the
device's log, where each test has its result as in web_tests.py: its worst
TAP result, and FAIL when it does not end within --timeout seconds (the
app is stopped), stops the app (a crash, or a quit the runner could not
cancel), or never begins. The app is then started again, and goes on with
the test after the last one that began (its progress file), at most
--restarts times in all. --engine names the engine the package was built
with (9.6.3 or beyond: android_check.py ide --android-engine), and with it
the baseline, tools/ci/android-tests-baseline-<engine>.txt (lines as
run_engine_tests.py's baselines have them: "lcs: <test>", "? " before one
that fails only sometimes, comments after " #"). A failure not in it fails
the check; baseline entries that passed are reported, so that they can be
removed, and --update-baseline rewrites the baseline with the failures,
keeping the comments of the entries that it had. The results go to
--results (default <work>/android-tests-<engine>.json), the log of every
failed test's output and what the device said as the app stopped to --log
(default <work>/android-tests-<engine>.log), and under GitHub Actions a
summary to the job summary.

compare reads two runs' results (LiveCode 9.6.3's engine and OXT-Beyond's,
say) and says which tests fail with the second engine and not with the
first, and which pass with the second and fail with the first: what a
stack would see differently were it built with the other engine. It
decides nothing (exit status 0), unless --strict, when a test that passes
with the first engine and fails with the second fails it.

Exit status: 0 when no test failed that is not in the baseline, 1 when one
did, 2 when the tests could not be run. Needs Python 3.8 or later, and the
Android SDK's adb for run.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import run_engine_tests  # noqa: E402
from android_check import CheckError, adb_path, annotate, log, run  # noqa: E402
from run_engine_tests import RESULT_ORDER, analyse_tap, outcome_of  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
RUNNER_SCRIPT = os.path.join(HERE, 'android-tests.livecodescript')
# What prepare writes into --work (android-check.livecodescript's
# kTestsScript and kTestsFiles name the first three)
SCRIPT_NAME = 'android-tests.livecodescript'
TESTS_FOLDER = 'oxt-tests'
EXTENSIONS_FOLDER = 'packaged_extensions'
TESTS_JSON = 'android-tests.json'
# The app (kTestsIdentifier in android-check.livecodescript) and its
# activity, as the builder names it
IDENTIFIER = 'org.openxtalk.check.androidtests'
ACTIVITY = IDENTIFIER + '/.mblandroid'
ENGINES = ('9.6.3', 'beyond')
# The engine's lists of errors, from which the test library names the
# errors that a test expects (TestBuildErrorMap)
ERROR_FILES = ('engine/src/executionerrors.h', 'engine/src/parseerrors.h')

# A line of the runner in the device's log: a put with no container, the
# engine's log line, tag LiveCode (as the probes' lines, PROBE_SAYS in
# android_check.py)
SAYS = re.compile(r'^[VDIWEF]/LiveCode\(\s*\d+\): OXTTESTS (.*?)\s*$')
# The time the app is given to start and copy its tests (the first start
# after an install copies every file into its documents folder), and how
# often the check asks whether its process is still there
START_TIMEOUT = 300
POLL = 0.5
ALIVE_EVERY = 5
# The device's log buffer for the app's lines (logcat -G): several
# thousand lines a run, read as they come
LOG_BUFFER = '16M'

BASELINE_HEADER = (
    '# Android test suite (tools/ci/android_tests.py): LiveCode Script tests known\n'
    '# to fail in an Android standalone built with the %s engine, run on an\n'
    '# Android emulator. One "lcs: <test>" per line; "? " before it: fails only\n'
    '# sometimes; text after " #" is a comment. A test that needs what a\n'
    '# standalone cannot have (the IDE, the documentation, the LiveCode Builder\n'
    '# compiler) skips there, through the test library\'s requirements\n'
    '# (tests/_testlib.livecodescript), and is not here.\n')


def baseline_path(engine):
    return os.path.join(HERE, 'android-tests-baseline-%s.txt' % engine)


# ---------------------------------------------------------------------------
# prepare

def tree_files(folder, prefix):
    """(path under the copy files, file) of every file under folder, but
    those whose names, or the names of whose folders, start with "."."""
    found = []
    for root, dirs, files in os.walk(folder):
        dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
        for name in sorted(files):
            if not name.startswith('.'):
                path = os.path.join(root, name)
                found.append((prefix + os.path.relpath(path, folder).replace(os.sep, '/'), path))
    return found


def tests_text(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
        for name in sorted(files):
            if name.endswith('.livecodescript'):
                with open(os.path.join(folder, name), encoding='utf-8-sig', errors='replace') as f:
                    yield f.read()


def find_ide_tools(ide):
    """{'lc-compile', 'modules', 'extensions'} of an installed IDE: its
    Toolchain's lc-compile and modules/lci, and its Extensions folder (each
    None when it has none)."""
    found = {'lc-compile': None, 'modules': None, 'extensions': None}
    for root, dirs, files in os.walk(ide):
        dirs.sort()
        base = os.path.basename(root)
        if base == 'Toolchain':
            for name in ('lc-compile', 'lc-compile.exe'):
                if name in files and not found['lc-compile']:
                    found['lc-compile'] = os.path.join(root, name)
            lci = os.path.join(root, 'modules', 'lci')
            if os.path.isdir(lci) and not found['modules']:
                found['modules'] = lci
        if base == 'Extensions' and not found['extensions'] and \
                any(os.path.isfile(os.path.join(root, d, 'module.lcm')) for d in dirs):
            found['extensions'] = root
    return found


def copy_files(repo, extensions_folder):
    """(files, extensions, missing, repo files): the copy files, as (path
    under --work, source) pairs, the names of the extensions among them, of
    those that the tests load and the IDE does not have (the tests that load
    them fail: a package does not install com.livecode.library.ini, for
    one), and of the checkout's files among them."""
    files = tree_files(os.path.join(repo, 'tests'), TESTS_FOLDER + '/tests/')
    files += tree_files(os.path.join(repo, '_tests', '_build'), TESTS_FOLDER + '/_tests/_build/')
    texts = list(tests_text(os.path.join(repo, 'tests', 'lcs')))
    repo_files = set(ERROR_FILES)
    for text in texts:
        for path in re.findall(r'TestGetEngineRepositoryPath\(\)\s*&\s*"/([^"]+)"', text):
            if os.path.isfile(os.path.join(repo, path)):
                repo_files.add(path)
    for path in sorted(repo_files):
        files.append((TESTS_FOLDER + '/' + path, os.path.join(repo, path)))
    # what tests read from the IDE's folder of the checkout (the plugins
    # whose scripts they test): a folder whole
    for path in sorted(set(p for text in texts
                           for p in re.findall(r'TestGetIDERepositoryPath\(\)\s*&\s*"/([^"]+)"', text))):
        source = os.path.join(repo, 'ide', path)
        if os.path.isdir(source):
            files += tree_files(source, '%s/ide/%s/' % (TESTS_FOLDER, path))
            repo_files.add('ide/%s/' % path)
        elif os.path.isfile(source):
            files.append(('%s/ide/%s' % (TESTS_FOLDER, path), source))
            repo_files.add('ide/' + path)
    # once each: a file in a folder that is also there whole
    files = list(dict(files).items())
    extensions = set()
    for text in texts:
        extensions.update(re.findall(r'TestLoadExtension\s+"([^"]+)"', text))
    missing = []
    for name in sorted(extensions):
        folder = os.path.join(extensions_folder or '', name)
        if not extensions_folder or not os.path.isfile(os.path.join(folder, 'module.lcm')):
            missing.append(name)
            continue
        files += tree_files(folder, '%s/%s/' % (EXTENSIONS_FOLDER, name))
    return files, sorted(set(extensions) - set(missing)), missing, sorted(repo_files)


def listing(repo, tests):
    """android-tests.txt: a test file (a path in oxt-tests), a tab and its
    test command, a line each."""
    tests_dir = os.path.join(repo, 'tests')
    return ''.join('tests/%s\t%s\n' % (os.path.relpath(path, tests_dir).replace(os.sep, '/'), name)
                   for path, name, _ in tests)


def prepare(args):
    repo = os.path.abspath(args.repo)
    work = os.path.abspath(args.work)
    os.makedirs(work, exist_ok=True)
    tests = run_engine_tests.lcs_tests(os.path.join(repo, 'tests', 'lcs'), args.filter)
    if not tests:
        raise CheckError('no test matches')
    tools = find_ide_tools(os.path.abspath(args.ide))
    log_lines = []
    if tools['lc-compile'] and tools['modules']:
        failed = run_engine_tests.compile_test_modules(tools, repo, log_lines)
        log('Compiled the test modules with %s to %s%s' % (
            tools['lc-compile'], os.path.join(repo, '_tests', '_build'),
            '' if not failed else '; %d did not compile: %s' % (len(failed), ', '.join(failed))))
        for line in log_lines:
            log('  %s' % line)
    else:
        log('NOTE: the IDE has no Toolchain lc-compile and modules: the tests that load a module of '
            'tests/ fail')
    files, extensions, missing, repo_files = copy_files(repo, tools['extensions'])
    if missing:
        log('NOTE: the tests load extensions that the IDE does not have (%s), so the tests that load them '
            'fail: %s' % (tools['extensions'] or 'no Extensions folder', ', '.join(missing)))
    for folder in (TESTS_FOLDER, EXTENSIONS_FOLDER):
        shutil.rmtree(os.path.join(work, folder), ignore_errors=True)
    for dest, source in files:
        target = os.path.join(work, *dest.split('/'))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(source, target)
    folder = os.path.join(work, TESTS_FOLDER)
    with open(os.path.join(folder, 'android-tests.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(listing(repo, tests))
    names = sorted(d[len(TESTS_FOLDER) + 1:] for d, _ in files if d.startswith(TESTS_FOLDER + '/'))
    names.append('android-tests.txt')
    with open(os.path.join(folder, 'files.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(names) + '\n')
    shutil.copyfile(RUNNER_SCRIPT, os.path.join(work, SCRIPT_NAME))
    with open(os.path.join(work, TESTS_JSON), 'w', encoding='utf-8') as f:
        json.dump([ident for _, _, ident in tests], f, indent=0)
    log('Prepared %d tests in %s: %d files in %s (from the checkout: %s), the extensions %s' % (
        len(tests), work, len(names), TESTS_FOLDER, ', '.join(repo_files), ', '.join(extensions) or 'none'))
    return []


# ---------------------------------------------------------------------------
# run: the app's lines

class Run:
    """What the app said in the device's log, line by line (see the header
    of android-tests.livecodescript), over every start of it."""

    def __init__(self):
        self.count = None
        self.current = None      # the line of the test that began and has not ended
        self.began = None        # when (time.monotonic())
        self.tap = {}            # line: [TAP line]
        self.details = {}        # line: [what else is known of it]
        self.done = set()
        self.quit = set()
        self.started = set()     # every line that began, over every start
        self.resumed = []        # the RESUME lines
        self.ended = False
        self.error = None
        self.last = time.monotonic()

    def said(self, text, now=None):
        """Takes one of the app's lines (without "OXTTESTS ")."""
        now = time.monotonic() if now is None else now
        self.last = now
        words = text.split(' ', 3)
        kind = words[0]
        number = int(words[1]) if len(words) > 1 and words[1].isdigit() else None
        if kind == 'COUNT' and number is not None:
            self.count = number
        elif kind == 'RESUME' and number is not None:
            self.resumed.append(number)
        elif kind == 'BEGIN' and number is not None:
            self.current = number
            self.began = now
            self.started.add(number)
            self.tap.setdefault(number, [])
        elif kind == 'TAP' and number is not None:
            # TAP <line> <n> <TAP line>: n, the line's place in the test's
            # output, keeps two lines that are the same apart (the log
            # folds lines it takes as the same)
            self.tap.setdefault(number, []).append(words[3] if len(words) > 3 else '')
        elif kind == 'QUIT':
            self.quit.add(number if number is not None else self.current)
        elif kind == 'DONE' and number is not None:
            self.done.add(number)
            if self.current == number:
                self.current = None
        elif kind == 'END':
            self.ended = True
        elif kind == 'ERROR':
            self.error = text[len('ERROR '):]

    def stopped(self, why):
        """The app stopped, or was stopped (why), during the current test."""
        if self.current is not None:
            self.details.setdefault(self.current, []).append(why)
            self.current = None


def says(line):
    """The app's line of a device log line (without "OXTTESTS "), or None."""
    m = SAYS.match(line.rstrip('\r\n'))
    return m.group(1) if m else None


def result_of(run_, line):
    """(outcome, counts, TAP text, details, failure lines) of the test on
    line: as web_tests.py's."""
    text = '\n'.join(run_.tap.get(line, []))
    counts, failures = analyse_tap(text)
    details = list(run_.details.get(line, []))
    if line in run_.done:
        outcome = outcome_of(counts, text)
    else:
        outcome = 'fail'
        if line not in run_.started:
            details.insert(0, 'the test did not begin')
        elif not details:
            details.insert(0, 'the test did not end')
    if line in run_.quit:
        outcome = 'fail'
        details.insert(0, 'the test quit (the runner cancelled the quit)')
    return outcome, counts, text, details, failures


# ---------------------------------------------------------------------------
# run: the device

class Device:
    """The app on a device through adb: what run_tests asks of it (a stand-in
    in the tests)."""

    def __init__(self, adb, serial):
        self.adb = adb
        self.serial = serial
        self.reader = None
        self.lines = []
        self.lock = threading.Lock()

    def a(self, *cmd, timeout=180):
        return run([self.adb, '-s', self.serial] + list(cmd), timeout=timeout)

    def install(self, apk):
        self.a('uninstall', IDENTIFIER)
        status, out = self.a('install', '-r', apk, timeout=900)
        if 'Success' not in out:
            raise CheckError('%s does not install on %s: %s' % (os.path.basename(apk), self.serial,
                                                                out.strip()[-800:]))

    def listen(self):
        """Clears the device's log and reads the app's lines from now on."""
        self.a('logcat', '-G', LOG_BUFFER)
        self.a('logcat', '-c')
        proc = subprocess.Popen([self.adb, '-s', self.serial, 'logcat', '-v', 'brief', 'LiveCode:V', '*:S'],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

        def read():
            for raw in proc.stdout:
                with self.lock:
                    self.lines.append(raw.decode('utf-8', 'replace'))
        threading.Thread(target=read, daemon=True).start()
        self.reader = proc

    def take(self):
        with self.lock:
            lines, self.lines = self.lines, []
        return lines

    def start(self):
        _, out = self.a('shell', 'am', 'start', '-n', ACTIVITY)
        if 'Error' in out:
            raise CheckError('the app does not start: %s' % out.strip()[-500:])

    def pid(self):
        _, out = self.a('shell', 'pidof', IDENTIFIER, timeout=60)
        return out.strip() if re.match(r'^\d+(\s+\d+)*$', out.strip()) else ''

    def stop(self):
        self.a('shell', 'am', 'force-stop', IDENTIFIER)

    def last_words(self, pid):
        """The lines of the device's log that say why the app's process pid
        ended (its crash, the signal, Android's account of its death)."""
        _, out = self.a('logcat', '-d', '-v', 'brief', '-t', '400', '*:W', timeout=120)
        keep = []
        for line in out.splitlines():
            if (pid and '(%s)' % pid in line.replace(' ', '') and re.match(r'^[EFA]/', line)) or \
                    re.search(r'\b(DEBUG|libc|AndroidRuntime)\s*\(', line) or \
                    (IDENTIFIER in line and re.search(r'died|crash|ANR|has died|Killing', line)):
                keep.append(line.rstrip())
        return keep[-40:]

    def close(self):
        if self.reader:
            self.reader.kill()


def run_tests(device, count, timeout, restarts, start_timeout=START_TIMEOUT, clock=time.monotonic,
              sleep=time.sleep, report=None):
    """Starts the app and follows it until it has said END, starting it
    again after each stop (a crash, a quit, or a test that did not end
    within timeout seconds, when it is stopped), at most restarts times
    after the first. count: the number of tests. Returns the Run, with
    elapsed (seconds) and starts; report is called with each test's line
    and result as it ends."""
    r = Run()
    started_at = clock()
    starts = 0
    idle_starts = 0
    reported = set()

    def finish(line):
        if line not in reported:
            reported.add(line)
            if report:
                report(line, result_of(r, line))

    def drain():
        """Takes the app's new lines; True when one began a test."""
        began = False
        for raw in device.take():
            text = says(raw)
            if text is None:
                continue
            before = set(r.done)
            r.said(text, clock())
            began = began or text.startswith('BEGIN ')
            for line in sorted(r.done - before):
                finish(line)
        return began

    while True:
        device.start()
        starts += 1
        start = r.last = alive_at = clock()
        log('Started the app (%d)' % starts)
        pid = ''
        began = False
        why = None
        while why is None and not r.ended:
            sleep(POLL)
            began = drain() or began
            if r.ended:
                break
            if r.error:
                raise CheckError('the app says: %s' % r.error)
            now = clock()
            if r.current is not None:
                if now - r.began > timeout:
                    why = 'did not end within %d seconds (the app was stopped)' % timeout
            elif now - r.last > (timeout if began else start_timeout):
                why = 'the app said nothing for %d seconds%s' % (
                    now - r.last, '' if began else ' after it started')
            if why is None and now - alive_at >= ALIVE_EVERY:
                alive_at = now
                current = device.pid()
                if current:
                    pid = current
                elif now - start >= ALIVE_EVERY:
                    # its last lines may still be on their way
                    began = drain() or began
                    if not r.ended:
                        why = 'the app stopped'
        if r.ended:
            break
        stopped_test = r.current
        details = [why]
        if why == 'the app stopped':
            # (its process, when the check saw it: a crash in the first
            # seconds has none, and the crash's own lines are kept anyway)
            details += ["the device's log as it stopped:"] + ['  ' + x for x in device.last_words(pid)]
        device.stop()
        r.stopped('\n'.join(details))
        if stopped_test is not None:
            log('  test %d: %s' % (stopped_test, why))
            finish(stopped_test)
        else:
            log('  between tests: %s' % why)
        idle_starts = 0 if began else idle_starts + 1
        if idle_starts >= 2:
            raise CheckError('the app began no test in two starts in a row (%s)' % why)
        if count and r.started and max(r.started) >= count and stopped_test is None:
            # the last test ended, and the app stopped before its END
            break
        if starts > restarts:
            log('Gave up after %d starts' % starts)
            break
    r.elapsed = clock() - started_at
    r.starts = starts
    return r


# ---------------------------------------------------------------------------
# run: the results

def write_baseline(path, engine, failing, previous):
    """Rewrite the baseline: the failures, and the entries marked "?" (may
    pass) that it had, with their comments."""
    lines = (BASELINE_HEADER % engine).splitlines() + ['']
    keep = set(failing) | set(k for k, v in previous.items() if v[0])
    for ident in sorted(keep):
        sometimes, comment = previous.get(ident, (False, None))
        lines.append(('? ' if sometimes else '') + ident + ('  # ' + comment if comment else ''))
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def judge(results, known):
    """(failing, new, fixed) of a run's results ({ident: outcome}) against a
    baseline ({ident: may pass})."""
    failing = sorted(k for k, v in results.items() if v == 'fail')
    new = [k for k in failing if k not in known]
    passed = set(k for k, v in results.items() if v in ('pass', 'xpass', 'xfail'))
    fixed = sorted(k for k, sometimes in known.items() if k in passed and not sometimes)
    return failing, new, fixed


def run_command(args):
    work = os.path.abspath(args.work)
    engine = args.engine
    baseline = args.baseline or baseline_path(engine)
    apk = os.path.abspath(args.apk or os.path.join(work, 'out', 'debug.apk'))
    log_path = os.path.abspath(args.log or os.path.join(work, 'android-tests-%s.log' % engine))
    results_path = os.path.abspath(args.results or os.path.join(work, 'android-tests-%s.json' % engine))
    with open(os.path.join(work, TESTS_JSON), encoding='utf-8') as f:
        idents = json.load(f)
    known = run_engine_tests.read_baseline(baseline)
    adb = adb_path(args.sdk)
    if not adb:
        raise CheckError('no adb')
    if not os.path.isfile(apk):
        raise CheckError('no package %s (android_check.py ide --probe tests builds it)' % apk)
    # the engine built here, when the package is said to have it: as
    # android_check.py verify --engine checks the probes, so that the
    # setting picked it
    if args.check_engine:
        import android_check
        problems, said = android_check.verify_engine(os.path.basename(apk), apk, os.path.abspath(args.check_engine))
        if problems:
            raise CheckError('; '.join(problems))
        log('The package has %s' % ', '.join(said))
    device = Device(adb, args.serial)
    try:
        device.install(apk)
        log('Installed %s on %s (the %s engine); %d tests' % (os.path.basename(apk), args.serial, engine,
                                                               len(idents)))
        device.listen()

        def report(line, result):
            ident = 'lcs: ' + idents[line - 1] if 0 < line <= len(idents) else 'line %d' % line
            log('%-5s %s%s' % (result[0].upper(), ident[len('lcs: '):],
                               ' (in the baseline)' if result[0] == 'fail' and ident in known else ''))
        r = run_tests(device, len(idents), args.timeout, args.restarts, report=report)
    finally:
        device.close()
    if r.count is not None and r.count != len(idents):
        raise CheckError('the app has %d tests, %s %d' % (r.count, TESTS_JSON, len(idents)))

    rows = []
    outcomes = {}
    for line, name in enumerate(idents, 1):
        outcome, counts, text, details, failures = result_of(r, line)
        ident = 'lcs: ' + name
        outcomes[ident] = outcome
        rows.append((ident, outcome, text, details, failures))
    failing, new, fixed = judge(outcomes, known)
    totals = dict((k, sum(1 for v in outcomes.values() if v == k)) for k in RESULT_ORDER)
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump({'engine': engine, 'results': outcomes}, f, indent=0, sort_keys=True)
    with open(log_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('Engine: %s\nPackage: %s\nDevice: %s\nBaseline: %s\nStarts: %d\n' % (
            engine, apk, args.serial, os.path.abspath(baseline), r.starts))
        for ident, outcome, text, details, failures in rows:
            if outcome in ('fail', 'xpass') or args.log_all:
                f.write('\n### %s %s%s\n' % (outcome.upper(), ident, ' (in the baseline)' if ident in known else ''))
                for line in details:
                    f.write(line + '\n')
                if text:
                    f.write(text.rstrip() + '\n')
        f.write('\n%s\n' % ', '.join('%d %s' % (totals[k], k) for k in RESULT_ORDER))

    line = ', '.join('%d %s' % (totals[k], k) for k in RESULT_ORDER)
    log('')
    log('%d tests with the %s engine in %.0f s, the app started %d time(s): %s' % (
        len(rows), engine, r.elapsed, r.starts, line))
    log('Failures: %d in the baseline, %d new' % (len(failing) - len(new), len(new)))
    by_ident = dict((x[0], x) for x in rows)
    for ident in new:
        log('  NEW   %s' % ident)
        for x in by_ident[ident][4][:10] + by_ident[ident][3][:20]:
            log('        %s' % x)
    if fixed:
        log('Baseline entries that passed (remove them from the baseline):')
        for ident in fixed:
            log('  FIXED %s' % ident)
    log('Results: %s' % results_path)
    log('Log: %s' % log_path)
    if args.update_baseline:
        write_baseline(baseline, engine, failing, run_engine_tests.baseline_entries(baseline))
        log('Wrote %s' % baseline)
    md = ['### Android script tests (the %s engine)' % engine, '',
          '%d LiveCode Script tests in an Android standalone in %.0f s: %s.' % (len(rows), r.elapsed, line),
          '%d failure(s) in the baseline, **%d new**.' % (len(failing) - len(new), len(new))]
    if new:
        md += ['', 'New failures:', '', '```text']
        for ident in new:
            md.append(ident)
            md += ['    ' + x for x in (by_ident[ident][4][:5] + by_ident[ident][3][:8])]
        md.append('```')
    if fixed:
        md += ['', 'Baseline entries that passed (remove them from the baseline):', '', '```text'] + fixed + ['```']
    run_engine_tests.append_summary('\n'.join(md))
    if new and not args.update_baseline:
        annotate('error', '%d new failure(s) of the script tests with the %s engine: %s' % (
            len(new), engine, ', '.join(new[:10])))
        return ['%d new failure(s)' % len(new)]
    return []


# ---------------------------------------------------------------------------
# compare

def differences(old, new):
    """(worse, better): the tests that fail with new and not with old, and
    those that fail with old and pass with new (a skip is neither)."""
    worse = sorted(k for k, v in new.items() if v == 'fail' and old.get(k) in ('pass', 'xfail', 'xpass'))
    better = sorted(k for k, v in new.items() if v in ('pass', 'xfail', 'xpass') and old.get(k) == 'fail')
    return worse, better


def compare(args):
    with open(args.old, encoding='utf-8') as f:
        old = json.load(f)
    with open(args.new, encoding='utf-8') as f:
        new = json.load(f)
    worse, better = differences(old['results'], new['results'])
    only = sorted(set(old['results']) ^ set(new['results']))
    a, b = old.get('engine', 'old'), new.get('engine', 'new')
    log('The %s engine against the %s engine:' % (b, a))
    log('  %d test(s) fail with %s and pass with %s' % (len(worse), b, a))
    for ident in worse:
        log('    %s' % ident)
    log('  %d test(s) pass with %s and fail with %s' % (len(better), b, a))
    for ident in better:
        log('    %s' % ident)
    if only:
        log('  %d test(s) ran with one engine only' % len(only))
    md = ['### Android script tests: the %s engine against the %s engine' % (b, a), '',
          '%d test(s) fail with %s and pass with %s; %d pass with %s and fail with %s.' % (
              len(worse), b, a, len(better), b, a)]
    for title, idents in (('Fail with %s, pass with %s:' % (b, a), worse),
                          ('Pass with %s, fail with %s:' % (b, a), better)):
        if idents:
            md += ['', title, '', '```text'] + idents + ['```']
    run_engine_tests.append_summary('\n'.join(md))
    if args.strict and worse:
        return ['%d test(s) fail with the %s engine and pass with the %s engine' % (len(worse), b, a)]
    return []


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    p = sub.add_parser('prepare')
    p.add_argument('--work', required=True)
    p.add_argument('--ide', required=True, help='the installed IDE whose builder builds the standalone')
    p.add_argument('--repo', default=REPO)
    p.add_argument('--filter', metavar='REGEX', help='only the tests whose "lcs: <test>" matches')
    r = sub.add_parser('run')
    r.add_argument('--work', required=True)
    r.add_argument('--serial', required=True)
    r.add_argument('--sdk', required=True)
    r.add_argument('--engine', required=True, choices=ENGINES)
    r.add_argument('--apk')
    r.add_argument('--timeout', type=int, default=120, metavar='SECONDS', help='time limit of one test')
    r.add_argument('--restarts', type=int, default=40, help='starts of the app after the first, at most')
    r.add_argument('--baseline', help='default: tools/ci/android-tests-baseline-<engine>.txt')
    r.add_argument('--update-baseline', action='store_true')
    r.add_argument('--results')
    r.add_argument('--log')
    r.add_argument('--log-all', action='store_true', help='log the output of every test, not only the failed')
    r.add_argument('--check-engine', metavar='DIR',
                   help='the runtime of the engine built here (as android_check.py verify --engine): the '
                        'package must have its engine')
    c = sub.add_parser('compare')
    c.add_argument('--old', required=True)
    c.add_argument('--new', required=True)
    c.add_argument('--strict', action='store_true')
    args = ap.parse_args(argv)
    try:
        problems = {'prepare': prepare, 'run': run_command, 'compare': compare}[args.command](args)
    except CheckError as e:
        log('error: %s' % e)
        annotate('error', str(e))
        run_engine_tests.append_summary('### Android script tests\n\nThe tests could not be run: %s\n' % e)
        return 2
    for problem in problems:
        log('PROBLEM: %s' % problem)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
