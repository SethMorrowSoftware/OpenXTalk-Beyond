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

"""tools/ci/startup_windows.py, the watch for windows that come and go
while the IDE starts ("ghost windows", openxtalk.org p=25967), and the
start check that runs it (tools/ci/linux_ide_start.sh). The watch itself
needs an X screen; what it makes of what it saw does not.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
sys.path.insert(0, CI)

import startup_windows  # noqa: E402


class GhostsTest(unittest.TestCase):

    def test_a_start_with_no_ghost(self):
        # rc.6.16 with the fix, under openbox
        events = [(0.492, '+', 0x80011f, 'revSplash'),
                  (5.498, '+', 0x800167, 'OXT-Beyond 0.2.7-rc.6.16'),
                  (6.894, '-', 0x80011f, ''),
                  (6.901, '+', 0x8001c1, 'Tools')]
        self.assertEqual(startup_windows.ghosts(events), [])

    def test_the_ghosts_of_rc615(self):
        # rc.6.15 under openbox: the Tools palette and the Message Box came
        # up for a moment, and the Tools palette came back once the splash
        # had gone
        events = [(0.504, '+', 0x80011f, 'revSplash'),
                  (6.372, '+', 0x800167, 'OXT-Beyond 0.2.7-rc.6.15'),
                  (6.977, '+', 0x8001c1, 'Tools'),
                  (7.003, '-', 0x8001c1, ''),
                  (7.102, '+', 0x8001cb, 'Message Box (Single Line)'),
                  (7.148, '-', 0x8001cb, ''),
                  (8.012, '-', 0x80011f, ''),
                  (8.018, '+', 0x8001c1, 'Tools')]
        found = startup_windows.ghosts(events)
        self.assertEqual([title for _, title, _, _ in found],
                         ['Tools', 'Message Box (Single Line)'])
        wid, title, came, went = found[0]
        self.assertEqual(wid, 0x8001c1)
        self.assertAlmostEqual(went - came, 0.026, places=3)
        lines = startup_windows.report(events, found)
        self.assertTrue(any(line.startswith('GHOST 0x8001c1 "Tools"') for line in lines))

    def test_the_splash_is_meant_to_go(self):
        events = [(0.5, '+', 1, 'revSplash'), (7.0, '-', 1, '')]
        self.assertEqual(startup_windows.ghosts(events), [])
        self.assertIn('No window came and went (the splash aside)',
                      startup_windows.report(events, []))

    def test_a_window_seen_before_the_watch_began(self):
        # a window already on the screen has no time it came
        events = [(0.0, '+', 7, 'Other'), (3.0, '-', 7, '')]
        found = startup_windows.ghosts(events)
        self.assertEqual(found, [(7, 'Other', 0.0, 3.0)])


S, H, D = (startup_windows.EVENT_OBJECT_SHOW, startup_windows.EVENT_OBJECT_HIDE,
           startup_windows.EVENT_OBJECT_DESTROY)
IDE = 4242


def ide_only(pid):
    return pid == IDE


class Win32EventsTest(unittest.TestCase):
    # what the Windows hook heard: (time, event, hwnd, pid, class, title,
    # top-level)

    def test_a_window_shown_and_hidden_is_a_ghost(self):
        raw = [(0.5, S, 10, IDE, 'MCWinClassW', 'revSplash', True),
               (6.9, S, 11, IDE, 'MCWinClassW', 'Tools', True),
               (7.0, H, 11, IDE, 'MCWinClassW', 'Tools', True),
               (8.0, H, 10, IDE, 'MCWinClassW', 'revSplash', True)]
        events = startup_windows.win32_events(raw, ide_only)
        self.assertEqual(events, [(0.5, '+', 10, 'revSplash', None), (6.9, '+', 11, 'Tools', None),
                                  (7.0, '-', 11, 'Tools', None), (8.0, '-', 10, 'revSplash', None)])
        found = startup_windows.ghosts(events)
        self.assertEqual([title for _, title, _, _ in found], ['Tools'])

    def test_a_window_destroyed_while_shown_went(self):
        # a destroyed window has no title, class or process any more
        raw = [(1.0, S, 12, IDE, 'MCWinClassW', 'Message Box', True),
               (1.1, D, 12, 0, '', '', False)]
        self.assertEqual(startup_windows.win32_events(raw, ide_only),
                         [(1.0, '+', 12, 'Message Box', None), (1.1, '-', 12, 'Message Box', None)])

    def test_what_is_not_a_window_of_the_ides(self):
        raw = [(1.0, S, 20, IDE, 'MCMenuWinClass', 'File', True),
               (1.0, S, 21, IDE, '#32768', '', True),
               (1.0, S, 22, IDE, 'tooltips_class32', '', True),
               (1.0, S, 23, IDE, 'Button', 'OK', False),
               (1.0, S, 24, 99, 'ConsoleWindowClass', 'cmd', True),
               (2.0, H, 20, IDE, 'MCMenuWinClass', 'File', True),
               (2.0, H, 21, IDE, '#32768', '', True),
               (2.0, H, 22, IDE, 'tooltips_class32', '', True),
               (2.0, H, 23, IDE, 'Button', 'OK', False),
               (2.0, H, 24, 99, 'ConsoleWindowClass', 'cmd', True),
               # destroyed, never shown: a window the engine keeps hidden
               (3.0, D, 25, 0, '', '', False)]
        self.assertEqual(startup_windows.win32_events(raw, ide_only), [])

    def test_a_window_shown_twice_came_once(self):
        raw = [(1.0, S, 30, IDE, 'MCWinClassW', 'Untitled 1', True),
               (1.5, S, 30, IDE, 'MCWinClassW', 'Untitled 1', True),
               (2.0, H, 30, IDE, 'MCWinClassW', '', True),
               (2.1, H, 30, IDE, 'MCWinClassW', '', True)]
        self.assertEqual(startup_windows.win32_events(raw, ide_only),
                         [(1.0, '+', 30, 'Untitled 1', None), (2.0, '-', 30, 'Untitled 1', None)])

    def test_a_window_made_again_in_its_place_is_not_a_ghost(self):
        # Windows, rc.6.16 with #369: the Tools palette's window was taken
        # away 33 ms after it was shown and another shown in its place 4
        # ms later (the engine makes a stack's window anew when its
        # decorations change); the place is the window's content
        tools = (1200, 80, 1260, 500)
        raw = [(0.683, S, 0x7301fe, IDE, 'MCWinClassW', 'revSplash', True, (300, 200, 800, 500)),
               (2.452, S, 0x12023c, IDE, 'MCWinClassW', 'OXT-Beyond 0.2.7-rc.6.16', True, (0, 0, 1024, 30)),
               (3.603, H, 0x7301fe, IDE, 'MCWinClassW', 'revSplash', True, (300, 200, 800, 500)),
               (3.606, S, 0x5f00ca, IDE, 'MCWinClassW', 'Tools', True, tools),
               (3.639, D, 0x5f00ca, 0, '', '', False),
               (3.643, S, 0x6000ca, IDE, 'MCWinClassW', 'revTools', True, tools)]
        events = startup_windows.win32_events(raw, ide_only)
        self.assertEqual(startup_windows.ghosts(events), [])
        self.assertEqual(startup_windows.recreations(events), [(0x5f00ca, 0x6000ca, 3.639)])
        lines = startup_windows.report(events, [])
        self.assertIn('RECREATED 0x5f00ca went at 3.639 s and 0x6000ca came in its place', lines)
        self.assertIn('   3.606 + 0x5f00ca Tools at 1200,80,1260,500', lines)

    def test_a_window_in_another_place_or_later_is_a_ghost(self):
        # another place, or the same place too late, or no place known
        for place2, later in (((1200, 80, 1260, 400), 3.643), ((1200, 80, 1260, 500), 3.95)):
            raw = [(3.606, S, 1, IDE, 'MCWinClassW', 'Tools', True, (1200, 80, 1260, 500)),
                   (3.639, H, 1, IDE, 'MCWinClassW', 'Tools', True, (1200, 80, 1260, 500)),
                   (later, S, 2, IDE, 'MCWinClassW', 'revTools', True, place2)]
            events = startup_windows.win32_events(raw, ide_only)
            self.assertEqual([title for _, title, _, _ in startup_windows.ghosts(events)], ['Tools'])
        events = [(3.606, '+', 1, 'Tools'), (3.639, '-', 1, ''), (3.643, '+', 2, 'revTools')]
        self.assertEqual([title for _, title, _, _ in startup_windows.ghosts(events)], ['Tools'])

    def test_one_new_window_stands_in_for_one_that_went(self):
        place = (10, 10, 50, 50)
        events = [(1.0, '+', 1, 'A', place), (1.1, '+', 2, 'B', place),
                  (2.0, '-', 1, 'A', place), (2.0, '-', 2, 'B', place),
                  (2.1, '+', 3, 'C', place)]
        self.assertEqual([title for _, title, _, _ in startup_windows.ghosts(events)], ['B'])

    def test_a_window_made_again_twice_in_its_place_is_not_a_ghost(self):
        # Windows, main after #380 (6b6350253, Build (Windows) run
        # 42241026907): the Tools palette, shown at a blendLevel of 99, went
        # to 0 and the engine showed a new window before it took the old
        # one away (MCStack::setopacity); 123 ms later its decorations
        # changed and the engine took that window away before it showed the
        # next. Looking only after a window went, the watch paired the
        # first with the third and called the second a ghost
        tools = (10, 120, 105, 662)
        raw = [(0.582, S, 0x9301b4, IDE, 'MCWinClassW', 'revSplash', True, (217, 231, 808, 537)),
               (2.106, S, 0x5c01c2, IDE, 'MCWinClassW', 'OXT-Beyond 0.2.7-rc.6.16', True, (0, 0, 850, 75)),
               (3.135, D, 0x9301b4, 0, '', '', False),
               (3.138, S, 0xc101f8, IDE, 'MCWinClassW', 'Tools', True, tools),
               (3.144, S, 0x300222, IDE, 'MCWinClassW', 'Tools', True, tools),
               (3.147, D, 0xc101f8, 0, '', '', False),
               (3.270, D, 0x300222, 0, '', '', False),
               (3.273, S, 0x310222, IDE, 'MCWinClassW', 'Tools', True, tools)]
        events = startup_windows.win32_events(raw, ide_only)
        self.assertEqual(startup_windows.ghosts(events), [])
        self.assertEqual(startup_windows.recreations(events),
                         [(0xc101f8, 0x300222, 3.147), (0x300222, 0x310222, 3.270)])
        lines = startup_windows.report(events, [])
        self.assertIn('RECREATED 0xc101f8 went at 3.147 s and 0x300222 came in its place', lines)
        self.assertIn('RECREATED 0x300222 went at 3.270 s and 0x310222 came in its place', lines)

    def test_a_window_shown_just_before_one_went_stands_in_for_it(self):
        # the engine's other order: the new window first, then the old one
        # taken away (a shown stack's blendLevel crossing 0)
        place = (10, 10, 50, 50)
        events = [(1.0, '+', 1, 'Tools', place), (1.2, '+', 2, 'Tools', place),
                  (1.203, '-', 1, 'Tools', place)]
        self.assertEqual(startup_windows.ghosts(events), [])
        self.assertEqual(startup_windows.recreations(events), [(1, 2, 1.203)])

    def test_a_window_shown_before_is_no_stand_in_for_a_ghost(self):
        place = (10, 10, 50, 50)
        cases = {
            # a window that came over one already in its place, and went
            'came over another': [(1.0, '+', 2, 'Other', place), (1.1, '+', 1, 'Tools', place),
                                  (1.2, '-', 1, 'Tools', place)],
            # the window shown in its place came too long before it went
            'too long before': [(1.0, '+', 1, 'Tools', place), (1.1, '+', 2, 'Other', place),
                                (1.1 + startup_windows.RECREATED_WITHIN + 0.05, '-', 1, 'Tools', place)],
            # the window shown in its place had gone already
            'gone already': [(1.0, '+', 1, 'Tools', place), (1.05, '+', 2, 'Other', place),
                             (1.06, '-', 2, 'Other', place), (1.1, '-', 1, 'Tools', place)],
            # in another place
            'another place': [(1.0, '+', 1, 'Tools', place), (1.1, '+', 2, 'Other', (10, 10, 50, 90)),
                              (1.103, '-', 1, 'Tools', place)],
        }
        for name, events in cases.items():
            with self.subTest(name):
                self.assertIn('Tools', [title for _, title, _, _ in startup_windows.ghosts(events)])
        self.assertEqual([title for _, title, _, _ in startup_windows.ghosts(cases['gone already'])],
                         ['Other', 'Tools'])


class MacChangesTest(unittest.TestCase):

    def test_what_came_and_what_went(self):
        self.assertEqual(startup_windows.mac_changes({1: 'revSplash'}, {1: 'revSplash', 2: 'Tools'}, 6.9),
                         [(6.9, '+', 2, 'Tools')])
        self.assertEqual(startup_windows.mac_changes({1: 'revSplash', 2: 'Tools'}, {1: 'revSplash'}, 7.0),
                         [(7.0, '-', 2, 'Tools')])
        self.assertEqual(startup_windows.mac_changes({}, {}, 1.0), [])

    def test_a_ghost_on_macos(self):
        events = (startup_windows.mac_changes({}, {5: 'revSplash'}, 0.4)
                  + startup_windows.mac_changes({5: 'revSplash'}, {5: 'revSplash', 6: 'Tools'}, 6.9)
                  + startup_windows.mac_changes({5: 'revSplash', 6: 'Tools'}, {5: 'revSplash'}, 7.0)
                  + startup_windows.mac_changes({5: 'revSplash'}, {}, 8.0))
        found = startup_windows.ghosts(events)
        self.assertEqual([title for _, title, _, _ in found], ['Tools'])


class OptionsTest(unittest.TestCase):

    def test_program_names(self):
        self.assertEqual(startup_windows.program_name('OXT-Beyond'), 'oxt-beyond')
        self.assertEqual(startup_windows.program_name(r'C:\a\OXT-Beyond.EXE'), 'oxt-beyond')
        self.assertEqual(startup_windows.program_name('/x/OXT-Beyond.app/Contents/MacOS/OXT-Beyond'),
                         'oxt-beyond')

    def refused(self, platform, argv):
        saved, err = sys.platform, sys.stderr
        sys.platform = platform
        sys.stderr = open(os.devnull, 'w')
        try:
            with self.assertRaises(SystemExit) as e:
                startup_windows.main(argv)
            return e.exception.code
        finally:
            sys.stderr.close()
            sys.platform, sys.stderr = saved, err

    def test_on_windows_the_ide_is_launched(self):
        # every process's windows would count otherwise
        self.assertEqual(self.refused('win32', ['--seconds', '1']), 2)

    def test_on_macos_the_ide_is_named_or_launched(self):
        self.assertEqual(self.refused('darwin', ['--seconds', '1']), 2)


class StartCheckTest(unittest.TestCase):

    def test_the_start_check_runs_the_watch(self):
        with open(os.path.join(CI, 'linux_ide_start.sh')) as f:
            text = f.read()
        self.assertIn('startup_windows.py', text)
        self.assertIn('--ready', text)
        # the IDE starts only once the watch has begun
        self.assertLess(text.index('startup-windows-ready'), text.index('"$root/oxt-beyond"'))
        self.assertIn('Windows came and went while the IDE started', text)

    def test_a_watcher_that_never_began_is_its_own_failure(self):
        # On Raspberry Pi OS the watcher once died on a missing python3-xlib
        # and the check reported an empty list of windows that came and went
        with open(os.path.join(CI, 'linux_ide_start.sh')) as f:
            text = f.read()
        self.assertIn('watching=yes', text)
        self.assertIn('The window watcher (tools/ci/startup_windows.py) did not start', text)
        # and it is decided before the windows that came and went are read
        self.assertLess(text.index('if [ "$watching" != yes ]'),
                        text.index('if [ "$ghost_status" != 0 ]'))

    def test_ghosts_warn_only_for_a_package_the_change_did_not_build(self):
        # The Raspberry Pi OS check on a pull request tests the newest
        # package from main; its ghosts are a warning there, an error
        # everywhere else (the default)
        with open(os.path.join(CI, 'linux_ide_start.sh')) as f:
            text = f.read()
        self.assertIn('"${OXT_GHOST_WINDOWS:-error}" = warn', text)
        with open(os.path.join(CI, 'pi_os_check.sh')) as f:
            self.assertIn('OXT_GHOST_WINDOWS="${OXT_GHOST_WINDOWS:-}"', f.read())
        wf = os.path.join(CI, '..', '..', '.github', 'workflows')
        with open(os.path.join(wf, 'pi-os-check.yml')) as f:
            pi_wf = f.read()
        # every job that runs pi_os_check.sh sets it: the native jobs and
        # the QEMU jobs, which pass it into their container
        runs = pi_wf.count('bash /src/tools/ci/pi_os_check.sh "') + \
            pi_wf.count('bash tools/ci/pi_os_check.sh "$package"')
        self.assertEqual(runs, 2)
        self.assertEqual(pi_wf.count("github.event_name == 'pull_request' && 'warn' || 'error'"), runs)
        self.assertIn('-e OXT_GHOST_WINDOWS="$OXT_GHOST_WINDOWS"', pi_wf)
        for name in ('build-linux.yml', 'build-macos.yml', 'build-windows.yml'):
            with open(os.path.join(wf, name)) as f:
                self.assertNotIn('OXT_GHOST_WINDOWS', f.read(), name)

    def test_every_check_that_runs_it_installs_xlib(self):
        # build-linux.yml installs python3-xlib in its package job; the
        # Raspberry Pi OS check installs its own screen tools
        with open(os.path.join(CI, 'pi_os_check.sh')) as f:
            pi = f.read()
        step = next(line for line in pi.splitlines()
                    if 'install xvfb' in line)
        self.assertIn('python3-xlib', step)
        with open(os.path.join(CI, '..', '..', '.github', 'workflows', 'build-linux.yml')) as f:
            self.assertIn('python3-xlib', f.read())

    def test_the_macos_start_check_runs_the_watch(self):
        with open(os.path.join(CI, 'mac_ide_start.sh')) as f:
            text = f.read()
        self.assertIn('startup_windows.py" --process OXT-Beyond', text)
        self.assertIn('--ready "$out/startup-windows-ready"', text)
        # the IDE starts only once the watch has begun
        self.assertLess(text.index('startup-windows-ready'),
                        text.index('"$app/Contents/MacOS/OXT-Beyond" >'))
        self.assertIn('The window watcher (tools/ci/startup_windows.py) did not start', text)
        self.assertIn('Windows came and went while the IDE started', text)
        # a ghost fails a start that is otherwise fine
        self.assertIn('[ "$windows" = ok ] && exit 0', text)
        with open(os.path.join(CI, '..', '..', '.github', 'workflows', 'build-macos.yml')) as f:
            self.assertIn('tools/ci/mac_ide_start.sh "$APP"', f.read())
        # a published release's ghosts are a warning in the media check
        self.assertIn('"${OXT_GHOST_WINDOWS:-error}" = warn', text)
        with open(os.path.join(CI, '..', '..', '.github', 'workflows', 'media-check.yml')) as f:
            media = f.read()
        step = media[media.index('- name: Start the IDE'):]
        step = step[:step.index('\n      - name:')]
        self.assertIn('OXT_GHOST_WINDOWS: warn', step)
        self.assertIn('tools/ci/mac_ide_start.sh', step)

    def test_the_windows_build_starts_the_ide_under_the_watch(self):
        with open(os.path.join(CI, '..', '..', '.github', 'workflows', 'build-windows.yml')) as f:
            wf = f.read()
        step = wf[wf.index('- name: Start the IDE'):]
        step = step[:step.index('\n      - name:')]
        self.assertIn('python tools/ci/startup_windows.py --seconds 60', step)
        self.assertIn("--launch $exe", step)
        self.assertIn("'OXT-Beyond.exe'", step)
        self.assertIn('Windows came and went while the IDE started', step)
        self.assertIn('exit $status', step)


if __name__ == '__main__':
    unittest.main()
