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

"""Check the standalone runtimes of an installed OXT-Beyond, and build and
run a standalone from its own runtime.

  python tools/ci/standalone_check.py --install DIR [--platform P]
      [--log FILE] [--timeout SECONDS]
  python tools/ci/standalone_check.py --engine FILE --runtime PATH
      [--platform P] [--log FILE] [--timeout SECONDS]

--install is an installed layout, as for tools/ci/run_livecode_check.py
(the folder that holds OXT-Beyond.app on macOS), tested from a neutral
path. --engine and --runtime name a development engine and a standalone
engine (or, on macOS, a Standalone*.app) directly, to try the deploy step
elsewhere (for example with a Linux build in WSL).

1. The runtimes (macOS): each folder of the layout's runtime table
   (tools/oxt/package.py MAC_RUNTIMES, where the IDE's standalone builder
   looks: revsblibrary revEngineCheck and revSBEnginePath) holds its
   Standalone*.app with Contents/MacOS/Standalone-Community (the name
   revSBEnginePath builds from the edition) holding every architecture of
   the layout, an Info.plist whose LSMinimumSystemVersion is the lowest
   minimum macOS of that engine (the builder copies it into every
   standalone), the icons the builder copies into every Mac standalone
   (x86-32: Standalone.icns and StandaloneDoc.icns), its Support files,
   and Externals whose Externals.txt and Database Drivers.txt name only
   bundles that are there; each Standalone*.app passes
   "codesign --verify --strict" when codesign exists.

2. A standalone from the runtime the IDE uses for its Mac target
   (Runtime/Mac OS X/x64-ARM64/Standalone-blank.app, the universal engine;
   on Linux Runtime/Linux/x86-64/Standalone): the layout's development
   engine runs tools/ci/standalone-deploy.livecodescript, which saves a
   one-handler stack and attaches it to a copy of the runtime with
   "_internal deploy", the command revStandaloneDeployWithParams uses. The
   Mac deployer accepts only the load commands it knows how to move (no
   LC_RPATH, no chained fixups), so this is where a runtime that no
   standalone can be made from fails. On macOS the copy is then signed as
   the IDE signs it (codesign --deep --force --sign -, performAdHocCodesign)
   and must pass "codesign --verify --deep --strict". The standalone runs
   with -ui and must report the engine's version, this machine's
   processor (the slice that ran), its platform and the environment
   "command line" (what a standalone reports without a user interface;
   the development engine says "development command line").

What this does not do is run the IDE's builder itself
(revSaveAsStandalone), which also copies the externals and database
drivers the stack needs from Runtime/Mac OS X/arm64/Externals and warns
when one is missing; that needs the IDE's libraries loaded in a headless
engine, and is left for later (see tools/oxt/README.md).

Exit status 0 when everything passes, 1 otherwise. Under GitHub Actions
it writes annotations and a job summary. Only the Python 3 standard
library is used (3.8 or later).
"""

import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import binfmt  # noqa: E402
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402

DEPLOY_SCRIPT = os.path.join(HERE, 'standalone-deploy.livecodescript')
# the runtime the IDE deploys for its Mac target (the "IntelArmUniversal"
# button selects MacOSX x64-ARM64) and its Linux x86-64 target
DEPLOY_RUNTIME = {'mac': 'Runtime/Mac OS X/x64-ARM64/Standalone-blank.app',
                  'linux': 'Runtime/Linux/x86-64/Standalone'}
MAC_EXE = 'Contents/MacOS/Standalone-Community'


def log(msg=''):
    rlc.log(msg)


def gha():
    return os.environ.get('GITHUB_ACTIONS') == 'true'


def run(cmd, timeout=120):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, '(did not finish within %d seconds)' % timeout
    except OSError as e:
        return None, str(e)
    return r.returncode, r.stdout.decode('utf-8', 'replace').strip()


def _version(v):
    parts = [int(x) for x in re.findall(r'[0-9]+', str(v))] if not isinstance(v, tuple) else list(v)
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def slice_floors(path):
    data = binfmt.read_file(path)
    return [binfmt.parse_macho(data[o:o + n]).floors.get('macOS') for _, o, n in binfmt.macho_slices(data)]


def check_mac_runtimes(tools, p):
    """Problems of the macOS runtime folders (see the module notes), and
    lines describing what was checked."""
    problems, lines = [], []
    codesign = shutil.which('codesign') if sys.platform == 'darwin' else None
    for r in p.runtimes:
        folder = os.path.join(tools, *r['folder'].split('/'))
        if not os.path.isdir(folder):
            problems.append('%s is missing' % r['folder'])
            continue
        if r['standalone']:
            app = os.path.join(folder, r['standalone'][1])
            exe = os.path.join(app, *MAC_EXE.split('/'))
            where = '%s/%s' % (r['folder'], r['standalone'][1])
            if not os.path.isfile(exe):
                problems.append('%s has no %s (revSBEnginePath\'s engine)' % (where, MAC_EXE))
                continue
            archs = binfmt.macho_archs(exe) or []
            if sorted(archs) != sorted(p.mac_archs):
                problems.append('%s/%s holds %s, not %s' % (where, MAC_EXE, ' '.join(archs) or 'nothing',
                                                            ' and '.join(p.mac_archs)))
            try:
                with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
                    info = plistlib.load(f)
            except (OSError, ValueError, plistlib.InvalidFileException) as e:
                problems.append('%s/Contents/Info.plist: %s' % (where, e))
                info = {}
            floors = [f for f in slice_floors(exe) if f]
            declared = info.get('LSMinimumSystemVersion')
            if info.get('CFBundleExecutable') != 'Standalone-Community':
                problems.append('%s/Contents/Info.plist: CFBundleExecutable is %r' % (where,
                                                                                    info.get('CFBundleExecutable')))
            if floors and (not declared or _version(declared) != _version(min(floors))):
                problems.append('%s/Contents/Info.plist declares LSMinimumSystemVersion %s; its engine runs from '
                                'macOS %s' % (where, declared, binfmt.version_text(min(floors))))
            for icon in ('Standalone.icns', 'StandaloneDoc.icns'):
                if not os.path.isfile(os.path.join(app, 'Contents', 'Resources', icon)):
                    problems.append('%s has no Contents/Resources/%s (the builder copies it into every Mac '
                                    'standalone)' % (where, icon))
            if codesign:
                code, out = run(['codesign', '--verify', '--strict', app])
                if code != 0:
                    problems.append('codesign --verify --strict %s: %s' % (where, out))
            lines.append('%s: %s, macOS %s and later, %s' % (
                where, ' '.join(archs), declared, 'signature verified' if codesign else 'signature not checked here'))
        for name in r['support']:
            if not os.path.exists(os.path.join(folder, 'Support', name)):
                problems.append('%s/Support/%s is missing' % (r['folder'], name))
        if r['externals']:
            for lst, sub in (('Externals.txt', ''), ('Database Drivers.txt', 'Database Drivers')):
                path = os.path.join(folder, 'Externals', sub, lst) if sub else os.path.join(folder, 'Externals', lst)
                try:
                    with open(path, 'rb') as f:
                        entries = [x for x in f.read().decode('utf-8').split('\n') if x]
                except OSError as e:
                    problems.append('%s: %s' % (os.path.relpath(path, tools), e))
                    continue
                for e in entries:
                    name = e.split(',', 1)[-1]
                    if '\r' in e or not os.path.isdir(os.path.join(os.path.dirname(path), name)):
                        problems.append('%s names %r, which is not a bundle next to it'
                                        % (os.path.relpath(path, tools), e))
            lines.append('%s/Externals: %s' % (r['folder'], 'externals and database drivers listed and present'))
    return problems, lines


def deploy_and_run(engine, runtime, family, work, timeout, expect_version):
    """Build the probe standalone from runtime with engine and run it.
    Returns (problems, lines)."""
    problems, lines = [], []
    stack = os.path.join(work, 'OXTStandaloneProbe.livecode')
    if family == 'mac':
        app = os.path.join(work, 'OXTProbe.app')
        # a copy of the runtime bundle, whose executable the deploy
        # replaces, as revSaveAsMacStandalone copies the runtime's app
        shutil.copytree(runtime, app, symlinks=True)
        runtime_exe = os.path.join(runtime, *MAC_EXE.split('/'))
        output = os.path.join(app, *MAC_EXE.split('/'))
        os.remove(output)
        platform = 'macosx'
    else:
        app, runtime_exe, output, platform = None, runtime, os.path.join(work, 'OXTProbe'), 'linux'
    env = dict(OXT_DEPLOY_PLATFORM=platform, OXT_DEPLOY_ENGINE=runtime_exe, OXT_DEPLOY_OUTPUT=output,
               OXT_DEPLOY_STACK=stack, OXT_DEPLOY_ARCHS=None)
    code, out, err = rlc.run_engine(engine, DEPLOY_SCRIPT, env, work, timeout)
    for line in out + err:
        log('  deploy: ' + line)
    if code != 0 or not any(x.startswith('DEPLOY OK') for x in out):
        why = next((x for x in out if x.startswith('DEPLOY FAILED')), None) or \
            ('the engine did not finish within %d seconds' % timeout if code is None else
             'exit status %s, no DEPLOY line' % code)
        problems.append('building the standalone failed: %s' % why)
        return problems, lines
    lines.append('built %s from %s' % (os.path.relpath(app or output, work), runtime_exe))
    if family == 'mac':
        # the deploy keeps every slice of the runtime (no "architectures")
        if sorted(binfmt.macho_archs(output) or []) != sorted(binfmt.macho_archs(runtime_exe) or []):
            problems.append('the standalone holds %s, the runtime %s' % (
                ' '.join(binfmt.macho_archs(output) or ['nothing']), ' '.join(binfmt.macho_archs(runtime_exe) or [])))
            return problems, lines
        # what the IDE does after building (performAdHocCodesign): the
        # deploy changed the executable, so its signature no longer holds
        for cmd in (['xattr', '-cr', app], ['codesign', '--force', '--deep', '--sign', '-', app],
                    ['codesign', '--verify', '--deep', '--strict', '--verbose=2', app]):
            c, text = run(cmd)
            log('  %s: %s' % (' '.join(cmd[:4]), text or 'ok'))
            if c != 0:
                problems.append('%s failed: %s' % (' '.join(cmd[:-1]), text))
                return problems, lines
        lines.append('signed ad hoc as the IDE signs a standalone, and verified')
    archs = binfmt.macho_archs(output) or [binfmt.elf_arch(output) or '?']
    processor = rlc.engine_processor(output)
    try:
        r = subprocess.run([output, '-ui'], cwd=work, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        code, out, err = r.returncode, r.stdout.decode('utf-8', 'replace').splitlines(), \
            r.stderr.decode('utf-8', 'replace').splitlines()
    except subprocess.TimeoutExpired:
        code, out, err = None, [], []
    except OSError as e:
        problems.append('cannot run the standalone %s: %s' % (output, e))
        return problems, lines
    for line in out + err:
        log('  standalone: ' + line)
    probe = next((m for m in (re.match(r'^PROBE version=(\S*) processor=(\S*) platform=(\S*) environment=(.*)$', x)
                              for x in out) if m), None)
    if code is None:
        problems.append('the standalone did not finish within %d seconds' % timeout)
    elif probe is None:
        problems.append('the standalone wrote no PROBE line (exit status %s)%s' % (code, rlc._missing_library_hint(err)))
    else:
        version, got, plat, environment = probe.groups()
        # without a user interface a standalone's environment is "command
        # line" (a development engine's "development command line")
        expected = {'version': (version, expect_version), 'processor': (got, processor),
                    'platform': (plat, 'MacOS' if family == 'mac' else 'Linux'),
                    'environment': (environment.strip(), 'command line')}
        for key, (have, want) in expected.items():
            if have != want:
                problems.append('the standalone reports %s %r, expected %r' % (key, have, want))
        if code != 0:
            problems.append('the standalone exited with status %s' % code)
        lines.append('ran it (%s; this machine ran the %s slice): %s' % (' '.join(archs), got, probe.group(0)))
    return problems, lines


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the standalone runtimes of an installed OXT-Beyond and build '
                                             'and run a standalone from its own runtime.')
    ap.add_argument('--install', metavar='DIR', help='installed layout (the folder that holds OXT-Beyond.app)')
    ap.add_argument('--package', metavar='FILE', help=argparse.SUPPRESS)
    ap.add_argument('--engine', metavar='FILE', help='development engine (with --runtime, instead of --install)')
    ap.add_argument('--runtime', metavar='PATH', help='standalone engine, or on macOS a Standalone*.app')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='layout names (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--log', metavar='FILE', help='write the output here too')
    ap.add_argument('--timeout', type=int, default=180, help='seconds per engine run (default: %(default)s)')
    args = ap.parse_args(argv)
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if p.family not in DEPLOY_RUNTIME:
        ap.error('%s: only the macOS and Linux layouts are checked here' % p.name)
    if bool(args.install) == bool(args.engine or args.runtime) or bool(args.engine) != bool(args.runtime):
        ap.error('pass --install, or --engine with --runtime')

    problems, lines, temp_dirs = [], [], []
    try:
        expect_version, _ = rlc.read_expectations(rlc.REPO)
        if args.install:
            args.bin_dir = None
            lay = rlc.find_layout(args, p, temp_dirs)
            engine, tools = lay.engine, lay.tools
            runtime = os.path.join(tools, *DEPLOY_RUNTIME[p.family].split('/'))
            log('Layout  : %s' % lay.root)
            if p.family == 'mac':
                found, what = check_mac_runtimes(tools, p)
                problems += found
                for line in what:
                    log('Runtime : ' + line)
        else:
            engine, runtime = os.path.abspath(args.engine), os.path.abspath(args.runtime)
        log('Engine  : %s' % engine)
        log('Runtime : %s (for the standalone)' % runtime)
        if not os.path.exists(runtime):
            raise rlc.CheckError('no runtime at %s' % runtime)
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-standalone-', dir=base)
        temp_dirs.append(work)
        trap = package.repository_mode_trap(work, p)
        if trap:
            raise rlc.CheckError('the work folder %s has a folder named %s in its path' % (work, trap))
        found, what = deploy_and_run(engine, runtime, p.family, work, args.timeout, expect_version)
        problems += found
        lines += what
    except (rlc.CheckError, OSError, binfmt.FormatError) as e:
        problems.append(str(e))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    log('')
    for line in lines:
        log('Standalone: ' + line)
    for msg in problems:
        log('::error title=Standalone check::%s' % msg if gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    log('Standalone check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Standalone check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + x for x in lines + ['problem: ' + m for m in problems]), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
