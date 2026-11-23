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

"""The Linux helpers of the browser (libbrowser-cefprocess and
revbrowser-cefprocess) do not return from main.

Chromium's zygote is the helper itself, forked for each renderer and
utility process, and it gives every child a new stack canary
(--change-stack-guard-on-fork=enable). The child comes back out of
CefExecuteProcess into main's frame, which holds the zygote's canary: a
return from main then fails the stack protector's check, and with
0.2.8-dp.2 every such child ended with "*** stack smashing detected ***:
terminated" (SIGABRT), twice for each page of the Dictionary or of a
browser widget (seen on Ubuntu 24.04). The helpers end with exit(), which
checks nothing; the browser checks of the Linux build
(tools/ci/media_check.py) fail when the engine's output has that line.

    python3 -m unittest discover -s tools/ci/tests -p 'test_cef_helper_stack_guard.py'
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
HELPERS = ('libbrowser/src/libbrowser_cefprocess_lnx.cpp', 'revbrowser/src/cefprocess_lnx.cpp')


def read(path):
    with open(os.path.join(REPO, *path.split('/')), encoding='utf-8') as f:
        return f.read()


def code(text):
    """The source without its comments."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line for line in text.split('\n') if not line.strip().startswith('//'))


class Helpers(unittest.TestCase):
    def test_main_does_not_return_from_the_browsers_process(self):
        for path in HELPERS:
            main = re.search(r'^int main\(int argc, char \*argv\[\]\)\n\{.*?^\}', code(read(path)), re.M | re.S)
            self.assertIsNotNone(main, path)
            self.assertIn('exit(CefExecuteProcess(t_args, t_app, NULL));', main.group(0), path)
            self.assertNotIn('return CefExecuteProcess', main.group(0), path)
            # exit, not _exit: what main's return ran at the end still runs
            self.assertNotIn('_exit(', main.group(0), path)
            self.assertIn('#include <stdlib.h>', read(path), path)

    def test_the_browser_checks_fail_on_a_smashed_stack(self):
        self.assertEqual(media_check.STACK_SMASHED, 'stack smashing detected')
        text = read('tools/ci/media_check.py')
        self.assertIn("smashed = output.decode('utf-8', 'replace').count(STACK_SMASHED)", text)
        self.assertIn('if smashed:\n                problems.append(', text)
        # glibc's own words (debug/fortify_fail.c through __stack_chk_fail)
        self.assertIn(media_check.STACK_SMASHED, '*** stack smashing detected ***: terminated')


if __name__ == '__main__':
    unittest.main()
