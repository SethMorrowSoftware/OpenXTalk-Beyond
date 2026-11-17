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

"""The browser where the desktop's session is Wayland. The engine is an X11
program there too (on Xwayland) and tells Chromium X11, which would take
Wayland for its own windows by the session's name (the switch itself is
held in test_libcef_stubs.py). Here: the media check's --session
(tools/ci/media_check.py), which runs the browser with the session's name
alone and in a Wayland session of its own, where it looks for Chromium's X
window in the stack's, and the Linux build's steps that run both.

  python3 -m unittest discover -s tools/ci/tests

The session itself (a headless Weston with Xwayland) is started here only
where both are installed; the checks with a browser run in the Linux
build (build-linux.yml).
"""

import os
import re
import shutil
import socket
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)
sys.path.insert(0, os.path.join(os.path.dirname(CI), 'oxt'))

import media_check  # noqa: E402
import run_livecode_check as rlc  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))

# xwininfo -root -tree while the browser widget of the check showed its
# page, with main's build at c77e5264 (CEF 156, before the engine told
# Chromium its platform), in run 44167685958: under Xvfb, where Chromium is
# on X11, ...
XVFB_TREE = '''xwininfo: Window id: 0x21f (the root window) (has no name)
  Root window id: 0x21f (the root window) (has no name)
  Parent window id: 0x0 (none)
     10 children:
     0x600005 (has no name): ()  1x1+0+0  +0+0
     0x40012b (has no name): ()  1x1+-100+-100  +-100+-100
     0x600000 "Chromium clipboard": ()  10x10+-100+-100  +-100+-100
     0x40011f "MediaCheck *": ("OXTMediaCheck" "OXTMediaCheck")  640x480+100+100  +100+100
        2 children:
        0x400120 (has no name): ()  1x1+-1+-1  +99+99
        0x20003a "Standalone": ("Standalone" "Standalone")  640x400+0+0  +100+100
           1 child:
           0x20003d (has no name): ()  640x400+0+0  +100+100
              1 child:
              0x600002 (has no name): ()  640x400+0+0  +100+100
                 1 child:
                 0x600003 (has no name): ()  640x400+0+0  +100+100
     0x400123 (has no name): ()  1x1+-1+-1  +-1+-1
     0x200020 "Standalone": ("Standalone" "Standalone")  200x200+0+0  +0+0
        1 child:
        0x200021 (has no name): ()  1x1+-1+-1  +-1+-1
     0x200003 "Standalone": ("Standalone" "Standalone")  200x200+0+0  +0+0
        1 child:
        0x200004 (has no name): ()  1x1+-1+-1  +-1+-1
     0x400006 "Standalone": ()  8x8+8+8  +8+8
        1 child:
        0x400007 (has no name): ()  1x1+-1+-1  +7+7
     0x400001 "Standalone": ("Standalone" "")  10x10+10+10  +10+10
        1 child:
        0x400002 (has no name): ()  1x1+-1+-1  +9+9
     0x200001 "Standalone": ("Standalone" "")  10x10+10+10  +10+10
        1 child:
        0x200002 (has no name): ()  1x1+-1+-1  +9+9
'''

# ... and in a Weston session (XDG_SESSION_TYPE=wayland), where Chromium had
# taken Wayland: CEF's window (0x800001) has nothing in it, and Chromium's
# clipboard window is not there
WESTON_TREE = '''xwininfo: Window id: 0x237 (the root window) (has no name)
  Root window id: 0x237 (the root window) (has no name)
  Parent window id: 0x0 (none)
     11 children:
     0x600132 (has no name): ()  1x1+-100+-100  +-100+-100
     0x600127 (has no name): ()  1x1+-1+-1  +-1+-1
     0x200028 (has no name): ()  716x577+0+0  +0+0
        1 child:
        0x600123 "MediaCheck *": ("OXTMediaCheck" "OXTMediaCheck")  640x480+38+59  +38+59
           2 children:
           0x600124 (has no name): ()  1x1+-1+-1  +37+58
           0x40003b "Standalone": ("Standalone" "Standalone")  640x400+0+0  +38+59
              1 child:
              0x40003e (has no name): ()  640x400+0+0  +38+59
                 1 child:
                 0x800001 (has no name): ()  640x400+0+0  +38+59
     0x400020 "Standalone": ("Standalone" "Standalone")  200x200+0+0  +0+0
        1 child:
        0x400021 (has no name): ()  1x1+-1+-1  +-1+-1
     0x400003 "Standalone": ("Standalone" "Standalone")  200x200+0+0  +0+0
        1 child:
        0x400004 (has no name): ()  1x1+-1+-1  +-1+-1
     0x600009 "Standalone": ()  8x8+8+8  +8+8
        1 child:
        0x60000a (has no name): ()  1x1+-1+-1  +7+7
     0x600001 "Standalone": ("Standalone" "")  10x10+10+10  +10+10
        1 child:
        0x600002 (has no name): ()  1x1+-1+-1  +9+9
     0x400001 "Standalone": ("Standalone" "")  10x10+10+10  +10+10
        1 child:
        0x400002 (has no name): ()  1x1+-1+-1  +9+9
     0x200027 "Weston WM": ()  10x10+0+0  +0+0
     0x200002 (has no name): ()  8192x8192+0+0  +0+0
     0x200001 (has no name): ()  10x10+0+0  +0+0
'''

# The same in a headless Mutter session (GNOME's compositor, 46.2) in run
# 44173064029, down to the end of the stack's frame: Mutter's frame window
# carries the stack's title, and the stack's own window is inside it. With
# XDG_SESSION_TYPE=wayland, CEF's window (0xa00001) is the last ...
MUTTER_TREE = '''xwininfo: Window id: 0x238 (the root window) (has no name)
  Root window id: 0x238 (the root window) (has no name)
  Parent window id: 0x0 (none)
     19 children:
     0x200004 "MediaCheck *": ("mutter-x11-frames" "mutter-x11-frames")  668x546+86+51  +86+51
        2 children:
        0x800123 "MediaCheck *": ("OXTMediaCheck" "OXTMediaCheck")  640x480+14+49  +100+100
           2 children:
           0x800124 (has no name): ()  1x1+-1+-1  +99+99
           0x60003b "Standalone": ("Standalone" "Standalone")  640x400+0+0  +100+100
              1 child:
              0x60003e (has no name): ()  640x400+0+0  +100+100
                 1 child:
                 0xa00001 (has no name): ()  640x400+0+0  +100+100
        0x200005 (has no name): ()  1x1+-1+-1  +85+50
'''

# ... and with the session named x11 Chromium's (0xa00004) is in it
MUTTER_X11_TREE = '''xwininfo: Window id: 0x238 (the root window) (has no name)
  Root window id: 0x238 (the root window) (has no name)
  Parent window id: 0x0 (none)
     21 children:
     0xa00006 (has no name): ()  1x1+0+0  +0+0
     0x800131 (has no name): ()  1x1+-100+-100  +-100+-100
     0xa00000 "Chromium clipboard": ()  10x10+-100+-100  +-100+-100
     0x400009 (has no name): ()  1x1+-1+-1  +-1+-1
     0x400004 "MediaCheck *": ("mutter-x11-frames" "mutter-x11-frames")  668x546+86+51  +86+51
        2 children:
        0x800123 "MediaCheck *": ("OXTMediaCheck" "OXTMediaCheck")  640x480+14+49  +100+100
           2 children:
           0x800124 (has no name): ()  1x1+-1+-1  +99+99
           0x60003b "Standalone": ("Standalone" "Standalone")  640x400+0+0  +100+100
              1 child:
              0x60003e (has no name): ()  640x400+0+0  +100+100
                 1 child:
                 0xa00003 (has no name): ()  640x400+0+0  +100+100
                    1 child:
                    0xa00004 (has no name): ()  640x400+0+0  +100+100
        0x400005 (has no name): ()  1x1+-1+-1  +85+50
'''


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class TheWindowTree(unittest.TestCase):
    def test_with_chromium_on_x11_the_stacks_window_goes_four_deep(self):
        # the engine's window for the card, its window for the widget,
        # CEF's, and Chromium's in CEF's
        self.assertEqual(media_check.windows_deep(XVFB_TREE, media_check.CHECK_STACK), 4)
        self.assertEqual(media_check.CHROMIUM_WINDOW_DEPTH, 4)

    def test_with_chromium_on_wayland_cefs_window_is_the_last(self):
        self.assertEqual(media_check.windows_deep(WESTON_TREE, media_check.CHECK_STACK), 3)
        # (under the window manager's frame there, which is not counted)
        self.assertIn('     0x200028 (has no name): ()  716x577+0+0  +0+0\n        1 child:\n'
                      '        0x600123 "MediaCheck *"', WESTON_TREE)

    def test_under_a_frame_of_the_same_name_the_stacks_own_window_is_counted(self):
        # Mutter's frame is named as the window it frames
        for tree in (MUTTER_TREE, MUTTER_X11_TREE):
            self.assertRegex(tree, r'     0x[24]00004 "MediaCheck \*": \("mutter-x11-frames" "mutter-x11-frames"\)')
            self.assertIn('        0x800123 "MediaCheck *": ("OXTMediaCheck" "OXTMediaCheck")', tree)
        self.assertEqual(media_check.windows_deep(MUTTER_TREE, media_check.CHECK_STACK), 3)
        self.assertEqual(media_check.windows_deep(MUTTER_X11_TREE, media_check.CHECK_STACK), 4)
        self.assertNotIn('Chromium clipboard', MUTTER_TREE)
        self.assertIn('"Chromium clipboard"', MUTTER_X11_TREE)

    def test_a_window_with_nothing_in_it_and_one_that_is_not_there(self):
        self.assertEqual(media_check.windows_deep(XVFB_TREE, 'Chromium clipboard'), 0)
        self.assertIsNone(media_check.windows_deep(WESTON_TREE, 'Chromium clipboard'))
        self.assertIsNone(media_check.windows_deep('', media_check.CHECK_STACK))
        self.assertIsNone(media_check.windows_deep('xwininfo: error: unable to open display ":7"\n', 'MediaCheck'))

    def test_the_count_ends_with_the_windows_inside(self):
        # a deeper window further down the tree is another window's
        tree = ('     0x1 "MediaCheck": ()  1x1+0+0  +0+0\n'
                '        1 child:\n'
                '        0x2 (has no name): ()  1x1+0+0  +0+0\n'
                '     0x3 "Other": ()  1x1+0+0  +0+0\n'
                '        1 child:\n'
                '        0x4 (has no name): ()  1x1+0+0  +0+0\n'
                '           1 child:\n'
                '           0x5 (has no name): ()  1x1+0+0  +0+0\n')
        self.assertEqual(media_check.windows_deep(tree, 'MediaCheck'), 1)
        self.assertEqual(media_check.windows_deep(tree, 'Other'), 2)

    def test_the_stack_is_the_one_the_script_makes_its_browsers_in(self):
        script = read('tools', 'ci', 'media-check.livecodescript')
        self.assertIn('create stack "%s"' % media_check.CHECK_STACK, script)
        self.assertIn('create widget "Browser" as "com.livecode.widget.browser" in card 1 of stack "%s"'
                      % media_check.CHECK_STACK, script)

    def test_the_result_is_a_failure_unless_chromiums_window_was_seen(self):
        for depth in (4, 5):
            self.assertTrue(media_check.chromium_window_result(depth).startswith('PASS browser widget: '), depth)
        for depth in (None, 0, 3):
            line = media_check.chromium_window_result(depth)
            # (main() counts a line that begins with FAIL as a problem)
            self.assertTrue(line.startswith('FAIL browser widget: '), depth)
            self.assertIn('Chromium made no X window inside the stack\'s', line)
        self.assertIn('goes 3 windows deep, and 4 with', media_check.chromium_window_result(3))
        self.assertIn('was not seen', media_check.chromium_window_result(None))


class TheSampler(unittest.TestCase):
    def test_it_keeps_the_sample_in_which_the_stack_goes_deepest(self):
        # the browser's windows are there for a part of the run only
        trees = iter(['', WESTON_TREE, XVFB_TREE, WESTON_TREE])
        last = []

        def tree(env):
            last.append(env)
            return next(trees, '')

        with mock.patch.object(media_check, 'x_window_tree', tree):
            sampler = media_check.TreeSampler({'DISPLAY': ':7'}, media_check.CHECK_STACK, every=0.01)
            sampler.start()
            for _ in range(500):
                if len(last) >= 5:
                    break
                sampler.done.wait(0.01)
            self.assertEqual(sampler.stop(), 4)
        self.assertEqual(sampler.tree, XVFB_TREE)
        self.assertEqual(last[0], {'DISPLAY': ':7'})
        self.assertFalse(sampler.is_alive())

    def test_a_window_never_seen_is_none(self):
        with mock.patch.object(media_check, 'x_window_tree', lambda env: ''):
            sampler = media_check.TreeSampler({}, media_check.CHECK_STACK, every=0.01)
            sampler.start()
            self.assertIsNone(sampler.stop())

    def test_no_xwininfo_is_no_tree(self):
        with mock.patch.object(media_check.subprocess, 'run', side_effect=OSError('no xwininfo')):
            self.assertEqual(media_check.x_window_tree({}), '')


class TheSession(unittest.TestCase):
    def test_it_says_which_packages_it_needs(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        with mock.patch.object(media_check.shutil, 'which', return_value=None):
            with self.assertRaises(rlc.CheckError) as c:
                media_check.wayland_session(work)
        self.assertIn('the packages weston and xwayland', str(c.exception))
        self.assertFalse(os.path.exists(os.path.join(work, 'xdg-runtime')))

    @unittest.skipUnless(sys.platform.startswith('linux') and shutil.which('weston') and shutil.which('Xwayland'),
                         'needs weston and Xwayland')
    def test_a_session_of_its_own_with_xwayland(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        proc, env, about = media_check.wayland_session(work)
        try:
            self.assertEqual(sorted(env), ['DISPLAY', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR', 'XDG_SESSION_TYPE'])
            self.assertEqual(env['XDG_SESSION_TYPE'], 'wayland')
            self.assertEqual(env['WAYLAND_DISPLAY'], media_check.WAYLAND_SOCKET)
            self.assertRegex(env['DISPLAY'], r'^:\d+$')
            self.assertEqual(os.stat(env['XDG_RUNTIME_DIR']).st_mode & 0o777, 0o700)
            self.assertRegex(about, r'^Weston \S+, headless, with Xwayland on :\d+$')
            # the compositor takes a client, and Xwayland's socket is there
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.addCleanup(s.close)
            s.connect(os.path.join(env['XDG_RUNTIME_DIR'], env['WAYLAND_DISPLAY']))
            self.assertTrue(os.path.exists('/tmp/.X11-unix/X' + env['DISPLAY'][1:]))
            self.assertIsNone(proc.poll())
        finally:
            media_check.end_session(proc)
        self.assertIsNotNone(proc.poll())


class TheCheck(unittest.TestCase):
    """main()'s own use of the session, read in its source: the checks with
    a browser run in the Linux build."""

    def setUp(self):
        self.source = read('tools', 'ci', 'media_check.py')

    def test_the_options(self):
        self.assertIn("ap.add_argument('--session', choices=('own', 'wayland', 'wayland-name'), default='own',",
                      self.source)
        self.assertIn("if args.session != 'own' and p.family != 'linux':", self.source)

    def test_the_name_alone_has_no_compositor_to_name(self):
        m = re.search(r"if args\.session == 'wayland-name':\n(.*?)\n                if not env\.get\('DISPLAY'\):",
                      self.source, re.S)
        self.assertIsNotNone(m)
        self.assertIn("env['XDG_SESSION_TYPE'] = 'wayland'", m.group(1))
        self.assertIn("for name in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET'):\n                        env.pop(name, None)",
                      m.group(1))

    def test_the_tree_is_sampled_for_the_widget_through_cef_in_the_session(self):
        self.assertIn("sample_tree = 'widget' in what and args.browser_backend == 'cef'", self.source)
        self.assertIn("sampler = TreeSampler(env, CHECK_STACK) if sample_tree and part == 'widget' else None",
                      self.source)
        # with the session's own display, and counted only for an engine that finished
        self.assertLess(self.source.index('env.update(session_env)'), self.source.index('sampler = TreeSampler('))
        self.assertIn('if sampler and finished:\n', self.source)
        self.assertIn('results.append(chromium_window_result(depth))', self.source)
        # the sampling ends with the engine, however it ended
        self.assertRegex(self.source, r"finally:\n\s+depth = sampler\.stop\(\) if sampler else None")
        self.assertIn("raise rlc.CheckError('--session wayland needs xwininfo (the package x11-utils)')", self.source)

    def test_the_session_ends_with_the_check(self):
        self.assertRegex(self.source, r"finally:\n        if session:\n            end_session\(session\)")


class TheLinuxBuild(unittest.TestCase):
    def setUp(self):
        self.text = read('.github', 'workflows', 'build-linux.yml')

    def step(self, name):
        m = re.search(r'\n      - name: %s\n(.*?)(?=\n      (?:- name:|#)|\n\n)' % re.escape(name), self.text, re.S)
        self.assertIsNotNone(m, name)
        return m.group(1)

    def test_the_package_job_runs_the_browser_with_the_name_alone_and_in_a_session(self):
        for name, session, log in (
                ('Browser check (the session named Wayland)', 'wayland-name', 'media-check-wayland-name.log'),
                ('Browser check (a Wayland session)', 'wayland', 'media-check-wayland.log')):
            step = self.step(name)
            # the only Linux build with CEF
            self.assertIn("if: ${{ !cancelled() && env.OXT_ROOT != '' && matrix.arch == 'x86_64' }}", step, name)
            self.assertIn('python3 tools/ci/media_check.py --install "$OXT_ROOT" --platform "linux-$ARCH" '
                          '--what widget,revbrowser \\\n', step, name)
            self.assertIn('--browser-backend cef --session %s --log "$RUNNER_TEMP/logs/%s"' % (session, log),
                          step, name)

    def test_the_job_installs_the_session(self):
        m = re.search(r'\n          pkgs=\((.*?)\)\n', self.text, re.S)
        self.assertIsNotNone(m)
        pkgs = m.group(1).split()
        for name in ('weston', 'xwayland', 'x11-utils', 'xvfb'):
            self.assertIn(name, pkgs)


if __name__ == '__main__':
    unittest.main()
