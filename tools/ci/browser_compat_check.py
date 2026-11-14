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

"""Check that what a script sees of the browser's htmlText and url is what
it saw in the release before.

  python tools/ci/browser_compat_check.py (--install DIR | --package FILE)
      [--platform P] [--what widget,revbrowser] [--expected FILE]
      [--record FILE] [--log FILE] [--timeout SECONDS]

The browser widget and revBrowser are built on CEF. When CEF changes (74
to 156), htmlText and url must not: CEF 156 has no CefFrame::LoadString,
which htmlText used, and a page loaded another way could report another
URL, resolve its relative links against another base, or have another
origin (and so other storage). tools/ci/browser-compat-check.livecodescript
sets them in the ways a script does and writes down, one OBS line each,
what the script then gets back: the url and htmlText properties, the
messages the browser sends, and what the page's own JavaScript reports
about where it is (location, baseURI, origin, a relative link, storage).

The layout is one of run_livecode_check.py's (--install, or --package to
extract first); its standalone runtime is copied to a folder of its own as
media_check.py does, and the two pages are served on 127.0.0.1. The lines
are compared with --expected (default tools/ci/browser-compat/<platform>.txt,
recorded from the release before with --record): a line that differs fails
the check. Lines matching an entry of ALLOWED do not count, each with its
reason.

Exit status 0 when every line matches, 1 otherwise. Only the Python 3
standard library is used (3.8 or later).
"""

import argparse
import difflib
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import media_check  # noqa: E402
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402
import standalone_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'browser-compat-check.livecodescript')
EXPECTED_DIR = os.path.join(HERE, 'browser-compat')

PAGES = {
    'page1.html': '<!DOCTYPE html><html><head><meta charset="utf-8"><title>compat page 1</title></head>'
                  '<body><p>page one</p></body></html>\n',
    'page2.html': '<!DOCTYPE html><html><head><meta charset="utf-8"><title>compat page 2</title></head>'
                  '<body><p>page two</p></body></html>\n',
}

# Lines whose value may differ from the expected one, as (step and what,
# regular expression the value must then match, reason)
ALLOWED = [
    # CEF 74 itself names either page in the messages after a failed load:
    # Chromium's error page, or the URL that failed (three runs of
    # 0.2.8-dp.1 gave both)
    ('w10 relative link: messages',
     r'browserDocumentLoadFailed: http://libbrowser_dummy_url/page2\.html\?x=1#y ERR_NAME_NOT_RESOLVED ; '
     r'browserNavigateFailed: http://libbrowser_dummy_url/page2\.html\?x=1#y ERR_NAME_NOT_RESOLVED ; '
     r'browserDocumentLoadComplete: (chrome-error://chromewebdata/|http://libbrowser_dummy_url/page2\.html\?x=1#y)  ; '
     r'browserNavigateComplete: (chrome-error://chromewebdata/|http://libbrowser_dummy_url/page2\.html\?x=1#y) ',
     'CEF 74 names either page after a failed load'),
]


def observations(lines):
    """The OBS lines of a run, without the prefix."""
    return [x[4:] for x in lines if x.startswith('OBS ')]


def allowed(line):
    for where, pattern, _reason in ALLOWED:
        head, _, value = line.partition(' = ')
        if head == where and re.fullmatch(pattern, value):
            return True
    return False


def compare(expected, actual):
    """The problems of actual against expected (lists of OBS lines)."""
    problems = []
    exp = {x.partition(' = ')[0]: x for x in expected}
    act = {x.partition(' = ')[0]: x for x in actual}
    for key in exp:
        if key not in act:
            problems.append('missing: %s' % exp[key])
        elif act[key] != exp[key] and not allowed(act[key]):
            problems.append('changed: %s\n   was: %s' % (act[key], exp[key]))
    for key in act:
        if key not in exp:
            problems.append('new: %s' % act[key])
    return problems


# The libcef entry points whose calls the trace lists, the last one before
# the crash saying which step of starting CEF or a browser it was in
TRACED_CEF_CALLS = ('cef_api_hash', 'cef_execute_process', 'cef_initialize', 'cef_do_message_loop_work',
                    'cef_browser_host_create_browser', 'cef_browser_host_create_browser_sync', 'cef_shutdown')


def cef_symbols(cwd):
    """A folder for gdb's debug-file-directory with libcef's symbols under
    its build id, from Spotify's release symbols of the CEF in
    prebuilt/versions (downloaded once into cwd); None when they cannot be
    had. The distribution's libcef.so has none of its own."""
    folder = os.path.join(cwd, 'cef-symbols')
    if os.path.isdir(folder):
        return folder
    try:
        import tarfile
        import urllib.request

        def version(name):
            with open(os.path.join(REPO, 'prebuilt', 'versions', name), encoding='utf-8') as f:
                return f.read().strip()
        name = 'cef_binary_%s+%s+chromium-%s_linux64_release_symbols.tar.bz2' % (
            version('cef'), version('cef_buildrevision'), version('cefchromium'))
        url = 'https://cef-builds.spotifycdn.com/' + name.replace('+', '%2B')
        rlc.log('Fetching libcef\'s symbols: %s' % url)
        with urllib.request.urlopen(url, timeout=120) as response, \
                tarfile.open(fileobj=response, mode='r|bz2') as tar:
            for member in tar:
                if member.isfile() and os.path.basename(member.name) == 'libcef.so.dbg':
                    data = tar.extractfile(member)
                    os.makedirs(folder)
                    target = os.path.join(folder, 'libcef.so.dbg')
                    with open(target, 'wb') as out:
                        shutil.copyfileobj(data, out, 1 << 20)
                    break
        if not os.path.isdir(folder):
            rlc.log('  (no libcef.so.dbg in %s)' % name)
            return None
        # gdb finds a library's symbols by its build id
        notes = subprocess.run(['readelf', '-n', target], stdout=subprocess.PIPE,
                               universal_newlines=True).stdout
        m = re.search(r'Build ID: ([0-9a-f]+)', notes)
        if m:
            build_id = m.group(1)
            os.makedirs(os.path.join(folder, '.build-id', build_id[:2]))
            os.symlink(target, os.path.join(folder, '.build-id', build_id[:2], build_id[2:] + '.debug'))
        return folder
    except Exception as e:  # the trace goes on without them
        rlc.log('  (libcef\'s symbols could not be had: %s)' % e)
        return None


def crash_trace(screen, cmd, cwd, env, timeout):
    """The engine's stack where it crashed, from a second run under gdb
    (the engine itself, inside xvfb-run when there is no screen), as
    run_engine_tests.py traces a test that crashes: with the libcef calls
    made before it, the instructions at the crash and where libcef was
    loaded (its own symbols are not in the distribution)."""
    if not shutil.which('gdb'):
        return ['  (no gdb to trace the crash with)']
    full = screen + ['gdb', '-batch', '-q', '-nx', '-ex', 'set pagination off']
    symbols = cef_symbols(cwd) if os.environ.get('OXT_COMPAT_CEF_SYMBOLS') == '1' else None
    if symbols:
        full += ['-ex', 'set debug-file-directory %s:/usr/lib/debug' % symbols]
    full += ['-ex', 'set breakpoint pending on',
                     '-ex', 'handle SIGPIPE SIGUSR1 SIGUSR2 nostop noprint pass']
    for name in TRACED_CEF_CALLS:
        full += ['-ex', 'dprintf %s,"CALL %s\\n"' % (name, name)]
    full += ['-ex', 'run', '-ex', 'bt 40', '-ex', 'x/4i $pc', '-ex', 'info registers rip rsp rdi rsi',
             '-ex', 'info sharedlibrary libcef', '--args'] + cmd
    try:
        out = subprocess.run(full, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=timeout + 60).stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or b''
    keep, calls = [], []
    for x in out.decode('utf-8', 'replace').splitlines():
        x = x.rstrip()
        if x.startswith('CALL '):
            # a run of one call (the message loop's) is one line
            if calls and calls[-1][0] == x:
                calls[-1][1] += 1
            else:
                calls.append([x, 1])
        elif re.match(r'\s*(#\d+ |Thread \d+ .* received|Program received|Program terminated|=> |'
                      r'(rip|rsp|rdi|rsi) +0x|0x[0-9a-f]+ +0x[0-9a-f]+ .*libcef)', x):
            keep.append(x)
    lines = ['%s%s' % (c, ' (x%d)' % n if n > 1 else '') for c, n in calls[-12:]] + keep
    return ['  ' + x for x in lines] or ['  (the crash did not happen again under gdb)']


def run(args, p, what):
    """Run the probe for each of what; (OBS and INFO lines, problems)."""
    lines, problems, temp_dirs, server = [], [], [], None
    try:
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-compat-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        rlc.log('Layout  : %s' % lay.root)
        engine, revbrowser = media_check.stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)
        site = os.path.join(work, 'site')
        os.makedirs(site)
        for name, text in PAGES.items():
            with open(os.path.join(site, name), 'w', encoding='utf-8', newline='\n') as f:
                f.write(text)
        server, port = media_check.serve(site)
        env = dict(os.environ)
        env.update({
            'OXT_COMPAT_BASE': 'http://127.0.0.1:%d/' % port,
            'OXT_COMPAT_EXTENSIONS': os.path.join(lay.tools, 'Extensions').replace('\\', '/'),
            'OXT_COMPAT_REVBROWSER': revbrowser.replace('\\', '/'),
        })
        cmd = [engine, SCRIPT]
        screen = []
        if p.family == 'linux' and not env.get('DISPLAY'):
            xvfb = shutil.which('xvfb-run')
            if not xvfb:
                raise rlc.CheckError('no DISPLAY and no xvfb-run')
            screen = [xvfb, '-a', '-s', '-screen 0 1280x1024x24']
        cmd = screen + cmd
        for part in what:
            result_log = os.path.join(work, 'compat-%s.log' % part)
            env['OXT_COMPAT_LOG'] = result_log
            env['OXT_COMPAT_WHAT'] = part
            try:
                proc = subprocess.run(cmd, cwd=work, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                      timeout=args.timeout)
                code, output = proc.returncode, proc.stdout
            except subprocess.TimeoutExpired as e:
                code, output = None, e.stdout or b''
            results = []
            if os.path.exists(result_log):
                with open(result_log, encoding='utf-8', errors='replace') as f:
                    results = [x.rstrip('\r\n') for x in f if x.strip()]
            if not any(x == 'DONE' for x in results):
                problems.append('%s: the engine did not finish (%s)'
                                % (part, 'timed out after %d seconds' % args.timeout if code is None
                                   else 'exit status %s' % code))
                for x in output.decode('utf-8', 'replace').splitlines()[-30:]:
                    rlc.log('  ' + x)
                if code is not None and (code < 0 or code > 128) and p.family == 'linux':
                    problems[-1] += '\n' + '\n'.join(crash_trace(screen, [engine, SCRIPT], work, env,
                                                                  args.timeout))
            lines += [x for x in results if x != 'DONE']
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        if server:
            server.shutdown()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    return lines, problems


def main(argv=None):
    ap = argparse.ArgumentParser(description='Compare what a script sees of the browser\'s htmlText and url '
                                             'with the release before.')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--what', default='widget,revbrowser', help='comma-separated: widget, revbrowser')
    ap.add_argument('--expected', metavar='FILE', help='the lines to compare with '
                                                       '(default: tools/ci/browser-compat/<platform>.txt)')
    ap.add_argument('--record', metavar='FILE', help='write the OBS lines here instead of comparing')
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--timeout', type=int, default=240, help='seconds for each engine run (default: %(default)s)')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if standalone_check.own_target(p) not in standalone_check.RUNTIMES:
        ap.error('%s has no standalone runtime of its own' % p.name)
    what = [w.strip() for w in args.what.split(',') if w.strip()]

    lines, problems = run(args, p, what)
    obs = observations(lines)
    for x in lines:
        rlc.log(x)
    if args.record:
        if not problems:
            version = next((x.split('version=', 1)[1].split()[0] for x in lines if 'version=' in x), 'unknown')
            with open(args.record, 'w', encoding='utf-8', newline='\n') as f:
                f.write('# What tools/ci/browser_compat_check.py saw of the browser\'s htmlText and url\n'
                        '# in %s (engine %s), recorded with --record. Lines starting with # are\n'
                        '# not compared.\n' % (p.name, version))
                f.write('\n'.join(obs) + '\n')
            rlc.log('Recorded %d lines to %s' % (len(obs), args.record))
    else:
        expected_file = args.expected or os.path.join(EXPECTED_DIR, '%s.txt' % p.name)
        with open(expected_file, encoding='utf-8') as f:
            expected = [x.rstrip('\n') for x in f if x.strip() and not x.startswith('#')]
        problems += compare(expected, obs)
        if problems:
            rlc.log('Diff against %s:' % expected_file)
            for x in difflib.unified_diff(expected, obs, 'expected', 'this build', lineterm='', n=0):
                rlc.log('  ' + x)
    for msg in problems:
        rlc.log('::error title=Browser compatibility check::%s' % msg.splitlines()[0]
                if media_check.gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Browser compatibility check %s.' % result)
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
