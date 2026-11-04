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
"""The Mobile Web library's phone check (tools/ci/mobile_web_check.py)
held to the pieces it works with, without a browser or an engine:

- every handler the check calls in the page is one that the check's
  stack (mobile-web-check.livecodescript) has, and one that the
  standalone's startup script (mobile-web-deploy.livecodescript) lets the
  page call
- the one attribute that lets a page keep its own layout
  (data-mobile-web-fill="no") is the one the library reads, and the
  Stack Player's page has it
- the library ships: built (extensions.gyp), laid out
  (tools/oxt/layout.py) and installed (Installer/package.txt) with the
  other script libraries
- the Phone Starter is offered: in the Stack Player's samples, with its
  picture, and in Home's gallery
- the workflow runs the check in Chromium and WebKit, and not in Firefox,
  which has no touch screen for Playwright to emulate
- the check's small helpers

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import mobile_web_check  # noqa: E402

LIBRARY = os.path.join(REPO, 'extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
PLAYER = os.path.join(REPO, 'tools', 'web-player')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class PageHandlers(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_allowed(self):
        check = read('tools', 'ci', 'mobile_web_check.py')
        stack = read('tools', 'ci', 'mobile-web-check.livecodescript')
        deploy = read('tools', 'ci', 'mobile-web-deploy.livecodescript')
        called = set(re.findall(r"findStackWithName\('MobileWebCheck'\)\.(\w+)\(", check))
        called |= set(re.findall(r"h\.(mwc\w+)\(", check))
        self.assertIn('mwcState', called)
        self.assertGreaterEqual(len(called), 4, called)
        defined = set(re.findall(r'^(?:function|command) (mwc\w+)', stack, re.M))
        allowed = set(re.findall(r'quote & "(mwc\w+)" & quote', deploy))
        for name in sorted(called):
            self.assertIn(name, defined, 'mobile-web-check.livecodescript has no %s' % name)
            self.assertIn(name, allowed, 'the startup script does not let the page call %s' % name)

    def test_the_library_is_called_by_the_name_it_has(self):
        check = read('tools', 'ci', 'mobile_web_check.py')
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        self.assertIn('script "com.livecode.library.mobileweb"', library)
        self.assertIn("findStackWithName('com.livecode.library.mobileweb')", check)
        # its one javascriptHandler, which the check calls to tell it of a
        # keyboard
        self.assertIn('mwFromBrowser', library)
        self.assertIn('lib.mwFromBrowser(', check)


class KeepItsOwnLayout(unittest.TestCase):

    def test_the_library_and_the_player_name_the_one_attribute(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        self.assertIn("getAttribute('data-mobile-web-fill') === 'no'", library)
        page = read('tools', 'web-player', 'index.html')
        self.assertRegex(page, r'<body[^>]*\sdata-mobile-web-fill="no"')

    def test_mwstop_takes_the_fill_away(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        stop = re.search(r'^command mwStop\n(.*?)^end mwStop', library, re.M | re.S)
        self.assertIsNotNone(stop)
        self.assertIn('unfillPage()', stop.group(1))
        self.assertIn('unfillPage: function', library)


class Ships(unittest.TestCase):

    def test_built_laid_out_and_installed(self):
        self.assertIn("'script-libraries/mobileweb/mobileweb.livecodescript',", read('extensions', 'extensions.gyp'))
        self.assertIn("'com.livecode.library.mobileweb',", read('tools', 'oxt', 'layout.py'))
        self.assertIn('packaged_extensions/com.livecode.library.mobileweb', read('Installer', 'package.txt'))

    def test_the_library_has_its_tests(self):
        tests = read('extensions', 'script-libraries', 'mobileweb', 'tests', 'mobileweb.livecodescript')
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        public = set(re.findall(r'^(?:command|function) (mw\w+)', library, re.M))
        self.assertIn('mwStart', public)
        for name in sorted(public):
            self.assertRegex(tests, r'\b%s\b' % name, 'the tests never call %s' % name)


class FitsAnIPhonesStack(unittest.TestCase):
    """Safari on an iPhone or an iPad gives a page's script far less stack
    than a desktop's WebKit. A Phone Starter ran out of it as it opened (a
    blank page): the library's browser script was one "put" of every line
    joined with "&", an expression as deep as the script is long. Long
    statements are kept out of what a phone runs, and the check's WebKit
    runs with an iPhone's stack."""

    LONGEST = 30

    def longest_statement(self, text):
        longest = run = 0
        for line in text.split('\n'):
            run = run + 1 if line.rstrip().endswith('\\') else 0
            longest = max(longest, run)
        return longest

    def test_no_statement_is_too_long(self):
        for path in (LIBRARY, os.path.join(PLAYER, 'phone-starter-stack.livecodescript'),
                     os.path.join(PLAYER, 'phone-starter.livecodescript'),
                     os.path.join(PLAYER, 'stack-player.livecodescript')):
            with open(path, encoding='utf-8') as f:
                text = f.read()
            self.assertLessEqual(self.longest_statement(text), self.LONGEST,
                                 '%s has a statement continued over %d lines' % (os.path.basename(path), self.LONGEST))

    def test_the_measure_sees_a_long_statement(self):
        long_put = 'put "a" & return & \\\n' * 40 + '"z" into t\n'
        self.assertEqual(self.longest_statement(long_put), 40)
        self.assertEqual(self.longest_statement('put 1 into t\nput 2 into u\n'), 0)

    def test_the_browser_script_is_put_a_line_at_a_time(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        body = library[library.index('private function mwBrowserScript'):library.index('end mwBrowserScript')]
        self.assertGreater(body.count(' after tScript'), 100)

    def test_webkit_runs_with_an_iphones_stack(self):
        self.assertEqual(mobile_web_check.launch_options('chromium'), {})
        env = mobile_web_check.launch_options('webkit')['env']
        self.assertEqual(env['JSC_maxPerThreadStackUsage'], str(mobile_web_check.IPHONE_STACK))
        self.assertLessEqual(mobile_web_check.IPHONE_STACK, 512 * 1024)
        self.assertEqual(env.get('PATH'), os.environ.get('PATH'))


class PhoneStarterOffered(unittest.TestCase):

    def test_in_the_players_samples_with_its_picture(self):
        player = read('tools', 'web-player', 'build_player.py')
        self.assertIn("'files': ['Phone Starter.oxtstack'], 'image': 'Phone Starter.webp'", player)
        for name in ('Phone Starter.oxtstack', 'Phone Starter.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)

    def test_in_homes_gallery(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        self.assertRegex(learn, r'"Markdown Notes,UI Gallery,Photo Lab,Phone Starter"')
        self.assertIn('case "Phone Starter"', learn)

    def test_the_check_finds_its_files(self):
        for path in (mobile_web_check.STARTER, mobile_web_check.STARTER_BUILDER, mobile_web_check.STARTER_SCRIPT,
                     mobile_web_check.LIBRARY, mobile_web_check.CHECK_STACK, mobile_web_check.DEPLOY_SCRIPT):
            self.assertTrue(os.path.isfile(path), path)


class Workflow(unittest.TestCase):

    def test_chromium_and_webkit_not_firefox(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Check the Mobile Web library on phones.*?(?=\n      - name:)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/mobile_web_check.py', step.group(0))
        self.assertNotIn('--rebuild', step.group(0))
        self.assertEqual(sorted(mobile_web_check.DEFAULT_DEVICES), ['chromium', 'webkit'])


class Helpers(unittest.TestCase):

    def test_rect(self):
        self.assertEqual(mobile_web_check.rect('0,0,390,664'), [0, 0, 390, 664])
        self.assertEqual(mobile_web_check.rect('-4,10,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(mobile_web_check.rect(''))
        self.assertIsNone(mobile_web_check.rect('a,b'))

    def test_middle(self):
        self.assertEqual(mobile_web_check.middle('20,100,370,148'), (195, 124))
        with self.assertRaises(mobile_web_check.CheckError):
            mobile_web_check.middle('')
        with self.assertRaises(mobile_web_check.CheckError):
            mobile_web_check.middle('1,2,3')


if __name__ == '__main__':
    unittest.main()
