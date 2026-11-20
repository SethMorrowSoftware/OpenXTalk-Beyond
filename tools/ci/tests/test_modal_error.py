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

"""A script error while a modal stack is showing (openxtalk.org; LiveCode
Community said nothing and the script just stopped): read from the IDE's
debugger library without an engine. The debugger cannot open behind a modal
stack, so traceError passes, and the handler that was to tell the user was
empty. It now hands the error to the Errors window. The IDE's tests cannot
reach this: traceError passes at once in the test environment.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DEBUGGER = os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revdebuggerlibrary.livecodescript')


def handler(text, kind, name):
    m = re.search(r'^%s %s\b.*?^end %s\b' % (kind, re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


class ModalError(unittest.TestCase):
    def setUp(self):
        with open(DEBUGGER, encoding='utf-8') as f:
            self.text = f.read()

    def test_the_warning_shows_the_error(self):
        warning = handler(self.text, 'private command', '__ShowModalWarning')
        self.assertIn('pError, pTarget', warning.splitlines()[0])
        self.assertIn('revIDEErrorDialog pError', warning)
        # nothing for a breakpoint, a suppressed error or the IDE's own stacks
        self.assertIn('if pError is empty or __ErrorsSuppressed() then', warning)
        self.assertIn('revIDEObjectIsOnIDEStack(pTarget)', warning)
        self.assertLess(warning.index('revIDEObjectIsOnIDEStack(pTarget)'), warning.index('revIDEErrorDialog pError'))
        # an error in the error window must not become an error of the debugger
        self.assertLess(warning.index('try'), warning.index('revIDEErrorDialog pError'))

    def test_trace_error_hands_it_the_error_and_still_passes(self):
        trace = handler(self.text, 'on', 'traceError')
        m = re.search(r'if "development" is in the environment and __ModalPresented\(\) then\n'
                      r'\s+__ShowModalWarning pError, tTarget\n\s+pass traceError\n', trace)
        self.assertIsNotNone(m)
        # the target is worked out before it is used
        self.assertLess(trace.index('put __ResolveTarget('), m.start())

    def test_a_breakpoint_under_a_modal_stack_is_as_it_was(self):
        trace = handler(self.text, 'on', 'traceBreak')
        self.assertRegex(trace, r'__ModalPresented\(\) then\n\s+__ShowModalWarning\n\s+pass traceBreak\n')


if __name__ == '__main__':
    unittest.main()
