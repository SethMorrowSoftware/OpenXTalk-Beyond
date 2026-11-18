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

"""The Android Stack Player's build and device check
(tools/android-player/build_player.py): what it reads from the IDE's lines,
from aapt2 and from the device, on made-up answers, and that the player's
scripts, the build script and the check agree on the names they share."""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PLAYER = os.path.join(REPO, 'tools', 'android-player')
sys.path.insert(0, PLAYER)

import build_player as bp  # noqa: E402


def text(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


BADGING = """package: name='org.openxtalk.stackplayer' versionCode='1' versionName='1.0.0'
sdkVersion:'21'
targetSdkVersion:'36'
uses-permission: name='android.permission.INTERNET'
uses-permission: name='org.openxtalk.stackplayer.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
application-label:'OXT Stack Player'
"""

FILTER = """      E: activity (line=24)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="org.openxtalk.stackplayer.mblandroid" (Raw: "x")
          E: intent-filter (line=32)
            E: action (line=33)
              A: http://schemas.android.com/apk/res/android:name(0x01010003)="android.intent.action.MAIN" (Raw: "x")
          E: intent-filter (line=37)
            E: action (line=37)
              A: http://schemas.android.com/apk/res/android:name(0x01010003)="android.intent.action.VIEW" (Raw: "x")
            E: data (line=37)
              A: http://schemas.android.com/apk/res/android:scheme(0x01010027)="content" (Raw: "content")
            E: data (line=37)
              A: http://schemas.android.com/apk/res/android:mimeType(0x01010026)="application/octet-stream" (Raw: "x")
      E: provider (line=40)
"""


class BuildLines(unittest.TestCase):
    def test_a_build_that_worked(self):
        r = bp.build_results(['INFO version 9.7.1 1', 'INFO warnings ', 'BUILD OK /w/OXT-Stack-Player.apk', 'DONE'])
        self.assertEqual(r['ok'], '/w/OXT-Stack-Player.apk')
        self.assertIsNone(r['failed'])
        self.assertTrue(r['done'])
        self.assertEqual(r['info']['version'], '9.7.1 1')

    def test_a_build_that_failed(self):
        r = bp.build_results(['ERROR 219,3,1', 'BUILD FAILED no SDK', 'DONE'])
        self.assertIsNone(r['ok'])
        self.assertEqual(r['failed'], 'no SDK')
        self.assertEqual(r['errors'], ['219,3,1'])

    def test_an_ide_that_stopped(self):
        r = bp.build_results(['INFO version 9.7.1 1'])
        self.assertFalse(r['done'])
        self.assertIsNone(r['ok'])


class Package(unittest.TestCase):
    def test_the_internet_alone(self):
        self.assertEqual(bp.badging_problems(BADGING), [])

    def test_another_permission_is_a_problem(self):
        for more in ('android.permission.CAMERA', 'android.permission.READ_EXTERNAL_STORAGE',
                     'android.permission.READ_CONTACTS'):
            with self.subTest(more):
                problems = bp.badging_problems(BADGING + "uses-permission: name='%s'\n" % more)
                self.assertEqual(len(problems), 1)
                self.assertIn(more, problems[0])

    def test_a_permission_only_below_an_api_is_a_problem_too(self):
        problems = bp.badging_problems(
            BADGING + "uses-permission-sdk-23: name='android.permission.ACCESS_FINE_LOCATION'\n")
        self.assertEqual(len(problems), 1)

    def test_no_internet_is_a_problem(self):
        problems = bp.badging_problems(BADGING.replace("uses-permission: name='android.permission.INTERNET'\n", ''))
        self.assertEqual(len(problems), 1)
        self.assertIn('no permission', problems[0])

    def test_another_name_is_a_problem(self):
        problems = bp.badging_problems(BADGING.replace("name='org.openxtalk.stackplayer' v", "name='com.example' v"))
        self.assertTrue(any('com.example' in x for x in problems))

    def test_the_document_filter(self):
        self.assertEqual(bp.document_filter_problems(FILTER), [])

    def test_no_document_filter_is_a_problem(self):
        for gone in ('android.intent.action.VIEW', '="content"', '="application/octet-stream"'):
            with self.subTest(gone):
                self.assertEqual(len(bp.document_filter_problems(FILTER.replace(gone, '="other"'))), 1)

    def test_a_filter_of_another_component_does_not_count(self):
        # the VIEW action in one filter, the content scheme in the next
        split = FILTER.replace('            E: data (line=37)\n              A: http://schemas.android.com/apk/res/android:scheme',
                               '          E: intent-filter (line=38)\n              A: http://schemas.android.com/apk/res/android:scheme')
        self.assertEqual(len(bp.document_filter_problems(split)), 1)


class DeviceLines(unittest.TestCase):
    LOGCAT = """11-18 22:00:01.000  4242  4260 I revandroid: OXT Stack Player: ready 9.7.1 android
11-18 22:00:01.100  4242  4260 I revandroid: OXT Stack Player: open button at 540,470 scale 2.75 stack 0,0,393,851 screen 0,0,393,851
11-18 22:00:05.000  4242  4260 I revandroid: OXT Stack Player sample: opened in /data/user/0/org.openxtalk.stackplayer/files/Stack Player/PlayerSample
11-18 22:00:05.100  4242  4260 I revandroid: OXT Stack Player: opened Player Sample\r
11-18 22:00:06.000  1000  1000 I other: nothing of the player
"""

    def test_what_the_player_said(self):
        self.assertEqual(bp.said(self.LOGCAT), [
            'ready 9.7.1 android', 'open button at 540,470 scale 2.75 stack 0,0,393,851 screen 0,0,393,851',
            'opened Player Sample'])

    def test_what_the_sample_said(self):
        self.assertEqual(bp.said(self.LOGCAT, bp.SAMPLE_SAYS), [
            'opened in /data/user/0/org.openxtalk.stackplayer/files/Stack Player/PlayerSample'])

    def test_a_node_by_its_text(self):
        xml = ('UI hierchary dumped to: /sdcard/x.xml\n<?xml version="1.0"?><hierarchy rotation="0">'
               '<node text="" bounds="[0,0][1080,2340]"><node text="Downloads" bounds="[0,200][400,300]"/>'
               '<node text="PlayerSample.oxtstack" bounds="[100,600][500,700]"/></node></hierarchy>')
        self.assertEqual(bp.node_centre(xml, 'PlayerSample.oxtstack'), (300, 650))
        self.assertEqual(bp.node_centre(xml, 'Downloads'), (200, 250))
        self.assertIsNone(bp.node_centre(xml, 'Missing.oxtstack'))
        self.assertIsNone(bp.node_centre('ERROR: could not get idle state.', 'Downloads'))

    def test_the_documents_address(self):
        self.assertEqual(bp.document_address('PlayerSample.oxtstack'),
                         'content://com.android.externalstorage.documents/document/primary%3ADownload%2FPlayerSample.oxtstack')


class SharedNames(unittest.TestCase):
    """The player's two scripts, its build script and its check are four
    files that must say the same names."""

    def setUp(self):
        self.player = text('tools', 'android-player', 'stack-player.livecodescript')
        self.back = text('tools', 'android-player', 'stack-player-back.livecodescript')
        self.build = text('tools', 'android-player', 'build-player.livecodescript')

    def constant(self, source, name):
        m = re.search(r'^constant %s = "([^"]*)"' % name, source, re.M)
        self.assertIsNotNone(m, name)
        return m.group(1)

    def test_the_stack_name(self):
        names = {self.constant(x, 'kPlayerName') for x in (self.player, self.back, self.build)}
        self.assertEqual(names, {'OXT Stack Player'})

    def test_the_identifier(self):
        self.assertEqual(self.constant(self.build, 'kIdentifier'), bp.IDENTIFIER)

    def test_the_log_prefix(self):
        says = self.constant(self.player, 'kSays')
        self.assertIsNotNone(bp.SAYS.search(says + ' ready'))
        self.assertIn('"OXT Stack Player sample: ', self.build)

    def test_the_sample(self):
        self.assertIn('"%s", "%s"' % (bp.SAMPLE_STACK, bp.SAMPLE), self.build)

    def test_the_document_types_are_what_verify_looks_for(self):
        self.assertIn('application/octet-stream', self.constant(self.build, 'kDocumentTypes'))

    def test_the_app_asks_for_the_internet_alone(self):
        asked = re.findall(r'pSettings\["android,application permissions"\]\["([A-Z_]+)"\]', self.build)
        self.assertEqual(asked, ['INTERNET'])
        self.assertIn('delete variable pSettings["android,application permissions"]', self.build)

    def test_the_back_script_handles_what_the_player_leaves_to_it(self):
        for handler in ('backKey', 'urlWakeUp', 'errorDialog'):
            self.assertRegex(self.back, r'(?m)^on %s\b' % handler)
            self.assertNotRegex(self.player, r'(?m)^on %s\b' % handler)

    def test_the_handlers_the_back_script_and_the_check_name_are_there(self):
        for handler in ('playerCurrent', 'playerSay', 'playerHome', 'playerTakeAddress', 'playerScriptError',
                        'playerMake'):
            self.assertRegex(self.player, r'(?m)^(command|function) %s\b' % handler)
        for line in ('"ready"', '"library"', '"open button at"', '"opened"', '"home from"', '"imported"',
                     '"problem"', '"chose nothing"', '"taking"'):
            self.assertIn('playerSay ' + line, self.player)

    def test_the_log_never_has_an_address(self):
        # what is taken in is said by its kind, never by its address
        self.assertIn('playerSay "taking" && playerAddressKind(pAddress)', self.player)
        self.assertNotRegex(self.player, r'playerSay[^\n]*&& pAddress')

    def test_the_workflow_runs_each_step(self):
        workflow = text('.github', 'workflows', 'android-player.yml')
        for command in ('library', 'build', 'verify', 'device'):
            self.assertIn('build_player.py %s ' % command, workflow)


if __name__ == '__main__':
    unittest.main()
