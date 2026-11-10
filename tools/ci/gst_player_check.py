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

"""Check the Linux player's GStreamer half on its own, without the engine.

  python3 tools/ci/gst_player_check.py [--x11] [--sanitize] [--log FILE]

engine/src/lnxgstplayer.cpp (which plays a player's movie through
GStreamer when mplayer is not installed) is built with
tools/ci/gst-player-check.cpp by the system's C++ compiler, and run on the
files of tools/ci/media: each opens paused at its start with its duration,
plays, pauses, seeks, steps a frame, ends once (and GLib's main loop, as
the engine's event loop runs it, hears of the end), loops, plays at a rate
of 2 and keeps its loudness; a file that is not there does not open. With
--x11 the video is drawn into an X window (under xvfb-run when there is no
DISPLAY), as the engine's player draws it; --sanitize builds with
AddressSanitizer and UndefinedBehaviorSanitizer.

It needs g++ and GStreamer 1.x with the base, good and libav plugins and
the X sinks (Debian and Ubuntu: gstreamer1.0-plugins-base,
gstreamer1.0-plugins-good, gstreamer1.0-libav, gstreamer1.0-x); no
development package, since the player loads GStreamer with dlopen. The
engine's own player, through this code, is checked by media_check.py
--player-backend gstreamer.

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
SOURCES = (os.path.join(REPO, 'engine', 'src', 'lnxgstplayer.cpp'), os.path.join(HERE, 'gst-player-check.cpp'))
MEDIA = os.path.join(HERE, 'media')
FILES = ('oxt-check.mp4', 'oxt-check-silent.mp4', 'oxt-check.avi', 'oxt-check-silent.avi')


def build_command(output, sanitize=False, compiler='g++'):
    """The compiler's command line that builds the check into output."""
    cmd = [compiler, '-std=c++11', '-Wall', '-Wextra', '-Werror', '-O1', '-g',
           '-I' + os.path.join(REPO, 'engine', 'src')]
    if sanitize:
        cmd += ['-fsanitize=address,undefined', '-fno-sanitize-recover=undefined']
    return cmd + list(SOURCES) + ['-ldl', '-o', output]


def run_command(binary, x11=False, display=None):
    """The command line that runs the check on the media files."""
    cmd = [binary] + (['--x11'] if x11 else []) + [os.path.join(MEDIA, f) for f in FILES]
    if x11 and not display:
        xvfb = shutil.which('xvfb-run')
        if not xvfb:
            raise RuntimeError('--x11 with no DISPLAY needs xvfb-run')
        cmd = [xvfb, '-a', '-s', '-screen 0 1024x768x24'] + cmd
    return cmd


def summarise(output):
    """(passes, failures) from the check's output lines."""
    lines = output.splitlines()
    return ([x for x in lines if x.startswith('PASS ')], [x for x in lines if x.startswith('FAIL ')])


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the Linux player\'s GStreamer half on its own.')
    ap.add_argument('--x11', action='store_true', help='draw the video into an X window')
    ap.add_argument('--sanitize', action='store_true', help='build with ASan and UBSan')
    ap.add_argument('--log', metavar='FILE', help='write the output here too')
    ap.add_argument('--timeout', type=int, default=180, help='seconds for the run (default: %(default)s)')
    args = ap.parse_args(argv)

    work = tempfile.mkdtemp(prefix='oxt-gst-check-')
    try:
        binary = os.path.join(work, 'gst-player-check')
        build = subprocess.run(build_command(binary, args.sanitize), stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, universal_newlines=True)
        output = build.stdout
        code = build.returncode
        if code == 0:
            env = dict(os.environ)
            # The check's player and GStreamer's own threads leak nothing the
            # check owns; GStreamer's registry and plugins keep what they load
            env.setdefault('ASAN_OPTIONS', 'detect_leaks=0')
            try:
                run = subprocess.run(run_command(binary, args.x11, env.get('DISPLAY')), env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     universal_newlines=True, timeout=args.timeout)
                output += run.stdout
                code = run.returncode
            except subprocess.TimeoutExpired as e:
                output += (e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
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
            print('::error title=GStreamer player check::%s' % x[5:])
        if not ok and not failures:
            print('::error title=GStreamer player check::exit status %s (see the log)' % code)
    print('GStreamer player check %s (%d passed, %d failed).'
          % ('passed' if ok else 'FAILED', len(passes), len(failures)))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
