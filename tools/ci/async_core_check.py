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

"""Check the engine's background jobs on their own, without the engine.

  python3 tools/ci/async_core_check.py [--sanitize address|thread]
      [--compiler CXX] [--wine] [--group NAME] [--log FILE]

engine/src/async-core.cpp (the threads behind the Background Jobs library:
files read, written, copied and listed, and processes run, off the engine's
main thread) is built with tools/ci/async-core-check.cpp by the system's
C++ compiler and run in a folder of its own: every kind of job, its errors,
cancelling, many at once, no threads at all (as in a browser), and stopping
with jobs still running. The same checks run on Linux, macOS and Windows:
the processes they start are the check itself.

--sanitize address builds with AddressSanitizer and
UndefinedBehaviorSanitizer (and looks for leaks where the system can);
--sanitize thread builds with ThreadSanitizer, which is the one that sees
two threads at the same memory. --wine builds for Windows with MinGW-w64
and runs under Wine, for a Linux machine without Windows; on Windows itself
the compiler is MinGW-w64's g++ as well.

It needs only a C++11 compiler (g++ or clang++; CXX or --compiler names
another). Exit status 0 when every check passed, 1 otherwise. Only the
Python 3 standard library is used (3.8 or later).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SOURCES = (os.path.join(REPO, 'engine', 'src', 'async-core.cpp'), os.path.join(HERE, 'async-core-check.cpp'))
MINGW = 'x86_64-w64-mingw32-g++'
SANITIZERS = {
    'address': ['-fsanitize=address,undefined', '-fno-sanitize-recover=undefined'],
    'thread': ['-fsanitize=thread'],
}
# What ThreadSanitizer says, and stops, where the kernel places a program's
# memory more randomly than the sanitizer's runtime knows of
TSAN_MAPPING = 'unexpected memory mapping'


def find_compiler(wine=False, environ=None):
    """The C++ compiler to build with, or None if there is none."""
    environ = os.environ if environ is None else environ
    if wine:
        return shutil.which(MINGW)
    names = [environ['CXX']] if environ.get('CXX') else []
    names += ['g++', 'clang++', 'c++']
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    return None


def build_command(output, compiler, sanitize=None, windows=False):
    """The compiler's command line that builds the check into output."""
    cmd = [compiler, '-std=c++11', '-Wall', '-Wextra', '-Werror', '-O1', '-g',
           '-I' + os.path.join(REPO, 'engine', 'src')]
    if sanitize:
        cmd += SANITIZERS[sanitize]
    cmd += list(SOURCES)
    # Windows: MinGW-w64's runtime inside the program, which is then run
    # from a folder that has none of its libraries
    cmd += ['-static'] if windows else ['-pthread']
    return cmd + ['-o', output]


def wine_environment(prefix):
    """The environment Wine is run with: nothing of this session's (a
    variable of some sessions makes Wine end at once), and a locale that
    can name a file with other than ASCII."""
    return {'HOME': os.environ.get('HOME', '/tmp'), 'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
            'LC_ALL': 'C.UTF-8', 'WINEPREFIX': prefix, 'WINEDEBUG': '-all'}


def run_command(binary, folder, group=None, wine=False):
    """The command line that runs the check in folder."""
    cmd = (['wine'] if wine else []) + [binary, folder]
    return cmd + ([group] if group else [])


def summarise(output):
    """(passes, failures) from the check's output lines."""
    lines = output.splitlines()
    return ([x for x in lines if x.startswith('PASS ')], [x for x in lines if x.startswith('FAIL ')])


def sanitizer_reports(output):
    """The lines with which a sanitizer starts a report."""
    return [x for x in output.splitlines()
            if x.startswith('WARNING: ThreadSanitizer') or 'ERROR: AddressSanitizer' in x
            or 'ERROR: LeakSanitizer' in x or 'runtime error:' in x]


def _run(cmd, env, timeout):
    try:
        run = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             universal_newlines=True, errors='replace', timeout=timeout)
        return run.returncode, run.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ''
        if isinstance(out, bytes):
            out = out.decode('utf-8', 'replace')
        return 1, out + '\nFAIL timed out after %d seconds\n' % timeout


def check(sanitize=None, compiler=None, wine=False, group=None, timeout=600):
    """Build and run the check. Returns (status, output), where status is
    'passed', 'failed' or 'skipped' (the sanitizer cannot run here)."""
    windows = wine or sys.platform == 'win32'
    compiler = compiler or find_compiler(wine)
    if not compiler:
        return 'failed', 'FAIL no C++ compiler found (g++, clang++, or CXX)\n'

    work = tempfile.mkdtemp(prefix='oxt-async-check-')
    try:
        binary = os.path.join(work, 'async-core-check' + ('.exe' if windows else ''))
        code, output = _run(build_command(binary, compiler, sanitize, windows), None, 600)
        if code != 0:
            return 'failed', output + '\nFAIL the check did not build\n'

        folder = os.path.join(work, 'files')
        os.mkdir(folder)
        env = wine_environment(os.path.join(work, 'wine')) if wine else dict(os.environ)
        # A report is a failure, and the first is enough
        env.setdefault('TSAN_OPTIONS', 'halt_on_error=1 exitcode=66')
        cmd = run_command(binary, folder, group, wine)
        if wine:
            code, where = _run(['winepath', '-w', folder], env, 300)
            cmd = run_command(binary, where.strip().splitlines()[-1] if code == 0 and where.strip() else folder,
                              group, wine)
        code, run_output = _run(cmd, env, timeout)
        if sanitize == 'thread' and TSAN_MAPPING in run_output:
            # Once more with the memory where the sanitizer expects it
            setarch = shutil.which('setarch')
            if setarch:
                code, run_output = _run([setarch, os.uname().machine, '-R'] + cmd, env, timeout)
            if TSAN_MAPPING in run_output or 'setarch:' in run_output:
                return 'skipped', output + run_output
        output += run_output
    finally:
        shutil.rmtree(work, ignore_errors=True)

    passes, failures = summarise(output)
    ok = code == 0 and not failures and passes and not sanitizer_reports(output)
    return ('passed' if ok else 'failed'), output


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the engine\'s background jobs on their own.')
    ap.add_argument('--sanitize', choices=sorted(SANITIZERS), help='build with these sanitizers')
    ap.add_argument('--compiler', metavar='CXX', help='the C++ compiler (default: CXX, g++, clang++)')
    ap.add_argument('--wine', action='store_true', help='build for Windows with MinGW-w64 and run under Wine')
    ap.add_argument('--group', metavar='NAME', help='run only this group of checks')
    ap.add_argument('--log', metavar='FILE', help='write the output here too')
    ap.add_argument('--timeout', type=int, default=600, help='seconds for the run (default: %(default)s)')
    args = ap.parse_args(argv)

    status, output = check(args.sanitize, args.compiler, args.wine, args.group, args.timeout)

    sys.stdout.write(output)
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write(output)
    passes, failures = summarise(output)
    if os.environ.get('GITHUB_ACTIONS'):
        for x in failures:
            print('::error title=Background jobs check::%s' % x[5:])
        for x in sanitizer_reports(output):
            print('::error title=Background jobs check::%s' % x.strip())
        if status == 'failed' and not failures:
            print('::error title=Background jobs check::it did not run to its end (see the log)')
        if status == 'skipped':
            print('::warning title=Background jobs check::ThreadSanitizer cannot run on this machine')
    print('Background jobs check %s (%d passed, %d failed).'
          % ({'passed': 'passed', 'failed': 'FAILED', 'skipped': 'SKIPPED'}[status], len(passes), len(failures)))
    return 1 if status == 'failed' else 0


if __name__ == '__main__':
    sys.exit(main())
