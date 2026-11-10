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

"""The Linux player through GStreamer (engine/src/lnxgstplayer.cpp): the
check that runs it on its own (tools/ci/gst_player_check.py), the media
check's --player-backend, the engine's choice between GStreamer and
mplayer, and the Linux workflow that runs both checks.

  python3 -m unittest discover -s tools/ci/tests

The check itself, which needs GStreamer and its plugins, runs in the Linux
build (build-linux.yml); here it runs only with OXT_GST_CHECK=1.
"""

import os
import re
import subprocess
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import gst_player_check  # noqa: E402
import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class CheckScript(unittest.TestCase):
    def test_builds_the_player_with_the_check(self):
        cmd = gst_player_check.build_command('/tmp/x')
        self.assertIn(os.path.join(REPO, 'engine', 'src', 'lnxgstplayer.cpp'), cmd)
        self.assertIn(os.path.join(CI, 'gst-player-check.cpp'), cmd)
        self.assertIn('-ldl', cmd)
        self.assertIn('-Werror', cmd)
        self.assertNotIn('-fsanitize=address,undefined', cmd)
        self.assertIn('-fsanitize=address,undefined', gst_player_check.build_command('/tmp/x', sanitize=True))

    def test_every_file_it_plays_is_there(self):
        for name in gst_player_check.FILES:
            self.assertTrue(os.path.isfile(os.path.join(gst_player_check.MEDIA, name)), name)
        # the same files as the media check's player
        self.assertEqual(set(gst_player_check.FILES), set(media_check.VIDEOS))

    def test_runs_under_xvfb_without_a_display(self):
        cmd = gst_player_check.run_command('/bin/check', x11=False, display=None)
        self.assertEqual(cmd[0], '/bin/check')
        self.assertNotIn('--x11', cmd)
        cmd = gst_player_check.run_command('/bin/check', x11=True, display=':5')
        self.assertEqual(cmd[:2], ['/bin/check', '--x11'])

    def test_counts_passes_and_failures(self):
        passes, failures = gst_player_check.summarise('PASS a: opens (0)\nFAIL a: ends (0)\nnoise\nPASS b: x (1)\n')
        self.assertEqual(len(passes), 2)
        self.assertEqual(failures, ['FAIL a: ends (0)'])

    @unittest.skipUnless(os.environ.get('OXT_GST_CHECK') == '1', 'needs GStreamer and its plugins (OXT_GST_CHECK=1)')
    def test_the_check_passes(self):
        proc = subprocess.run([sys.executable, os.path.join(CI, 'gst_player_check.py')],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(proc.returncode, 0, proc.stdout[-3000:])


class CheckSource(unittest.TestCase):
    """What the check asks of the player: every behaviour a script sees."""

    def test_the_check_covers_what_a_script_sees(self):
        source = read('tools', 'ci', 'gst-player-check.cpp')
        for what in ('duration is 3 seconds', 'opens paused', 'time moves on while it plays',
                     'time stands still while paused', 'currentTime seeks', 'steps one frame',
                     'the event loop hears of the end', 'ends once', 'looping, it does not end',
                     'a rate of 2 plays twice as fast', 'the loudness is kept',
                     'a file that is not there does not open'):
            self.assertIn('"%s"' % what, source)


class EngineChoice(unittest.TestCase):
    """mplayer plays a movie when it is installed, as before; GStreamer when
    it is not; OXT_PLAYER_BACKEND names one."""

    def setUp(self):
        self.source = read('engine', 'src', 'lnxmplayer.cpp')

    def test_backend_names(self):
        self.assertIn('getenv("OXT_PLAYER_BACKEND")', self.source)
        self.assertRegex(self.source, r'strcasecmp\(t_choice, "gstreamer"\) == 0\)\s*return kMCPlayerBackendGStreamer')
        self.assertRegex(self.source, r'strcasecmp\(t_choice, "mplayer"\) == 0\)\s*return kMCPlayerBackendMPlayer')

    def test_mplayer_first_when_installed(self):
        body = self.source[self.source.index('MCPlayerBackendChoice t_choice;'):]
        body = body[:body.index('if ( !t_launched )')]
        # GStreamer only when it is asked for, or mplayer is not there
        self.assertRegex(body, r't_choice == kMCPlayerBackendAuto && access\(C_PLAYER_CMD, X_OK\) != 0')
        # mplayer still, unless GStreamer alone was asked for: a machine with
        # neither ends the movie as before
        self.assertIn('if (!t_launched && t_choice != kMCPlayerBackendGStreamer)\n\t\tt_launched = launch_player();', body)

    def test_gstreamer_is_loaded_at_run_time(self):
        gst = read('engine', 'src', 'lnxgstplayer.cpp')
        self.assertIn('dlopen("libgstreamer-1.0.so.0"', gst)
        self.assertIn('dlopen("libgstvideo-1.0.so.0"', gst)
        # no GStreamer or GLib header: it builds without their dev packages
        self.assertNotRegex(gst + read('engine', 'src', 'lnxgstplayer.h'), r'#include\s*<(gst|glib)')

    def test_the_end_reaches_the_event_loop(self):
        dsk = read('engine', 'src', 'dsklnx.cpp')
        self.assertIn('MCGstPlayer::TakeAnyEnded()', dsk)
        self.assertIn('t_player -> takeended()', dsk)

    def test_built_into_the_desktop_engine(self):
        gypi = read('engine', 'engine-sources.gypi')
        self.assertIn("'src/lnxgstplayer.cpp',", gypi)
        self.assertIn("'src/lnxgstplayer.h',", gypi)


class MediaCheckBackend(unittest.TestCase):
    def test_option(self):
        source = read('tools', 'ci', 'media_check.py')
        self.assertIn("'--player-backend', choices=('auto', 'gstreamer', 'mplayer')", source)
        self.assertIn("env['OXT_PLAYER_BACKEND'] = args.player_backend", source)


class Workflow(unittest.TestCase):
    def setUp(self):
        self.workflow = read('.github', 'workflows', 'build-linux.yml')

    def test_installs_gstreamer(self):
        for pkg in ('gstreamer1.0-plugins-base', 'gstreamer1.0-plugins-good', 'gstreamer1.0-libav',
                    'gstreamer1.0-x'):
            self.assertRegex(self.workflow, r'pkgs=\([^)]*\b%s\b' % re.escape(pkg))

    def test_checks_each_backend(self):
        self.assertIn('--player-backend mplayer', self.workflow)
        self.assertRegex(self.workflow, r'media_check\.py [^\n]*--what player[^\n]*--player-backend gstreamer')
        self.assertIn('python3 tools/ci/gst_player_check.py --x11 --sanitize', self.workflow)


if __name__ == '__main__':
    unittest.main()
