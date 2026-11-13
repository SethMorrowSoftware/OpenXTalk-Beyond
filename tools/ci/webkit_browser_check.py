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

"""Check the Linux browser's WebKitGTK half on its own, without the engine.

  python3 tools/ci/webkit_browser_check.py [--sanitize] [--helper PATH] [--log FILE]

The browser widget and revBrowser use CEF 74 on Linux x86-64. Where CEF
cannot load (no Externals/CEF/libcef.so, a library it needs is missing, or
an architecture CEF has no build for), libbrowser now falls back to
WebKitGTK, run in a helper process of its own (libbrowser-webkitprocess,
libbrowser/src/libbrowser_webkitprocess_lnx.cpp), because the engine is a
GTK 2 program and WebKitGTK needs GTK 3, and the two cannot share one
process.

This builds libbrowser's own sources and libcore with
tools/ci/webkit-browser-check.cpp by the system's C++ compiler, and the
helper the same way (unless --helper names a built one, such as the
build's linux-<arch>-bin/libbrowser-webkitprocess), and runs the check
under xvfb-run when there is no DISPLAY: the wire format between the two
processes, the conversion of a page's values for the javascriptHandlers,
the choice of the browser (CEF first; WebKitGTK when CEF cannot load;
OXT_BROWSER_BACKEND), and a browser through the helper (htmlText, pages
and their messages, history, JavaScript, javascriptHandlers, the user
agent, a page that fails, a URL scheme the browser does not know, the
helper ending with the browser). Then a missing helper gives no browser
and no crash.

It needs g++, the X11 development files (libx11-dev) and WebKitGTK
(libwebkit2gtk-4.1-0 or libwebkit2gtk-4.0-37); no WebKitGTK development
package, since the helper loads WebKitGTK with dlopen. --sanitize builds
the check with AddressSanitizer and UndefinedBehaviorSanitizer.

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
LIBBROWSER = os.path.join(REPO, 'libbrowser')

CHECK_SOURCES = [os.path.join(HERE, 'webkit-browser-check.cpp'),
                 os.path.join(REPO, 'libcore', 'src', 'core.cpp')] + \
    [os.path.join(LIBBROWSER, 'src', f) for f in (
        'libbrowser.cpp', 'libbrowser_memory.cpp', 'libbrowser_value.cpp', 'libbrowser_json.cpp',
        'libbrowser_webkitgtk.cpp', 'libbrowser_webkitgtk_protocol.cpp')]
HELPER_SOURCES = [os.path.join(LIBBROWSER, 'src', f) for f in (
    'libbrowser_webkitprocess_lnx.cpp', 'libbrowser_webkitgtk_protocol.cpp')]

FLAGS = ['-std=c++11', '-Wall', '-Wno-unused-parameter', '-O1', '-g',
         '-DTARGET_PLATFORM_LINUX', '-D_LINUX', '-D_GNU_SOURCE',
         '-I' + os.path.join(LIBBROWSER, 'include'), '-I' + os.path.join(LIBBROWSER, 'src'),
         '-I' + os.path.join(REPO, 'libcore', 'include')]
SANITIZE = ['-fsanitize=address,undefined', '-fno-sanitize-recover=undefined']


def build_commands(work, sanitize=False, compiler='g++', helper=None):
    """The compiler's command lines: the check, and the helper unless one
    was given."""
    extra = SANITIZE if sanitize else []
    check = os.path.join(work, 'webkit-browser-check')
    cmds = [[compiler] + FLAGS + extra + CHECK_SOURCES + ['-lX11', '-ldl', '-lpthread', '-o', check]]
    if helper is None:
        # The helper as the build makes it: no sanitizer (WebKitGTK's own
        # threads and allocations are not the check's), its own name
        helper = os.path.join(work, 'libbrowser-webkitprocess')
        cmds.append([compiler] + FLAGS + HELPER_SOURCES + ['-ldl', '-o', helper])
    return cmds, check, helper


def run_commands(check, helper, work, display=None):
    """The command lines that run the check in each of its modes."""
    prefix = []
    if not display:
        xvfb = shutil.which('xvfb-run')
        if not xvfb:
            raise RuntimeError('no DISPLAY, and no xvfb-run')
        prefix = [xvfb, '-a', '-s', '-screen 0 1024x768x24']
    return [prefix + [check, '--helper', helper, '--work', work, mode]
            for mode in ('all', 'missing-helper', 'backend-cef')]


def summarise(output):
    """(passes, failures) from the check's output lines."""
    lines = output.splitlines()
    return ([x for x in lines if x.startswith('PASS ')], [x for x in lines if x.startswith('FAIL ')])


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the Linux browser\'s WebKitGTK half on its own.')
    ap.add_argument('--sanitize', action='store_true', help='build the check with ASan and UBSan')
    ap.add_argument('--helper', metavar='PATH', help='a built libbrowser-webkitprocess to use')
    ap.add_argument('--log', metavar='FILE', help='write the output here too')
    ap.add_argument('--timeout', type=int, default=240, help='seconds for each run (default: %(default)s)')
    args = ap.parse_args(argv)

    work = tempfile.mkdtemp(prefix='oxt-webkit-check-')
    output = ''
    code = 0
    try:
        cmds, check, helper = build_commands(work, args.sanitize,
                                             helper=os.path.abspath(args.helper) if args.helper else None)
        for cmd in cmds:
            build = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
            output += build.stdout
            if build.returncode != 0:
                output += 'FAIL build: %s exited with %d\n' % (os.path.basename(cmd[-1]), build.returncode)
                code = build.returncode
                break
        if code == 0:
            env = dict(os.environ)
            # WebKitGTK's own allocations, kept until the process ends, are
            # not the check's
            env.setdefault('ASAN_OPTIONS', 'detect_leaks=0')
            for cmd in run_commands(check, helper, work, env.get('DISPLAY')):
                try:
                    run = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                         universal_newlines=True, timeout=args.timeout)
                    output += run.stdout
                    code = code or run.returncode
                except subprocess.TimeoutExpired as e:
                    out = e.stdout or ''
                    output += out.decode('utf-8', 'replace') if isinstance(out, bytes) else out
                    output += '\nFAIL timed out after %d seconds\n' % args.timeout
                    code = 1
    finally:
        shutil.rmtree(work, ignore_errors=True)

    sys.stdout.write(output)
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write(output)
    passes, failures = summarise(output)
    ok = code == 0 and not failures and passes
    if os.environ.get('GITHUB_ACTIONS'):
        for x in failures:
            print('::error title=WebKitGTK browser check::%s' % x[5:])
        if not ok and not failures:
            print('::error title=WebKitGTK browser check::exit status %s (see the log)' % code)
    print('WebKitGTK browser check %s (%d passed, %d failed).'
          % ('passed' if ok else 'FAILED', len(passes), len(failures)))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
