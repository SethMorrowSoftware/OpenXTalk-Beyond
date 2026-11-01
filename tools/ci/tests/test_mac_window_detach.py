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

"""engine/src/mac-window.mm: a window's views never point at a deleted
platform window.

The macOS text input services (the Accessibility Keyboard's suggestions,
the text cursor indicator of macOS 14) keep the view of the last text input
client and call its NSTextInputClient methods later, from a delayed
perform, after the engine may have destroyed the window. The view kept a
raw pointer to its MCMacPlatformWindow, so those calls took a death grip on
freed memory and the grip's release deleted it a second time: OXT-Beyond
crashed in ~MCPlatformWindow (MCGRegionDestroy) when Apply was pressed in
the script editor after typing with the Accessibility Keyboard (tperry2x,
rc.6.11 on macOS 14.8.1).

The crash needs the system's input services, which no CI runner drives, so
this checks the source for what the fix rests on:

- the destructor detaches both views before anything else (anything after
  could call back into them);
- the view stops being a text input client once detached (inputContext is
  nil);
- every method of the view that reads its platform window checks it for nil
  before using it, since a detached view's methods can still be called.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SOURCE = os.path.join(REPO, 'engine', 'src', 'mac-window.mm')


def read_source():
    with open(SOURCE, encoding='utf-8') as f:
        return f.read()


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def block_after(text, start):
    """The text of the brace block that opens at or after start."""
    i = text.index('{', start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    raise ValueError('unbalanced block')


def implementation(text, name):
    m = re.search(r'@implementation\s+%s\b(.*?)@end' % re.escape(name), text, re.S)
    if m is None:
        raise AssertionError('no @implementation %s' % name)
    return m.group(1)


def methods(impl):
    """(selector line, body) of each method of an @implementation."""
    out = []
    for m in re.finditer(r'^[-+]\s*\([^)]*\)[^{\n]*', impl, re.M):
        out.append((m.group(0).strip(), block_after(impl, m.end())))
    return out


# A use of the platform window that dereferences it or hands it to the
# engine, which takes a death grip on it.
USE = re.compile(r't_window\s*->|m_window\s*->|MCPlatformCallbackSend\w*\s*\(\s*(t_window|m_window|\[self platformWindow\])')
CHECK = re.compile(r'(t_window|m_window|\[self platformWindow\])\s*[!=]=\s*nil')


def unchecked_uses(body):
    """Whether the body uses the platform window before checking it."""
    first_use = USE.search(body)
    if first_use is None:
        return False
    check = CHECK.search(body)
    return check is None or check.start() > first_use.start()


class MacWindowDetachTest(unittest.TestCase):

    def setUp(self):
        self.text = strip_comments(read_source())

    def test_destructor_detaches_views_first(self):
        start = self.text.index('MCMacPlatformWindow::~MCMacPlatformWindow(void)')
        body = block_after(self.text, start)
        statements = [s.strip() for s in body.split(';') if s.strip()]
        self.assertGreaterEqual(len(statements), 2, body)
        self.assertEqual(
            sorted(statements[:2]),
            ['[m_container_view detachPlatformWindow]', '[m_view detachPlatformWindow]'],
            'the destructor must detach both views before anything else:\n' + body)

    def test_view_detach_clears_window(self):
        for cls in ('com_runrev_livecode_MCWindowView', 'com_runrev_livecode_MCWindowContainerView'):
            impl = implementation(self.text, cls)
            bodies = {sel: body for sel, body in methods(impl)}
            detach = [b for s, b in bodies.items() if 'detachPlatformWindow' in s]
            self.assertEqual(len(detach), 1, cls)
            self.assertRegex(detach[0], r'm_window\s*=\s*nil', cls)

    def test_detached_view_is_not_a_text_input_client(self):
        impl = implementation(self.text, 'com_runrev_livecode_MCWindowView')
        bodies = [b for s, b in methods(impl) if re.search(r'\)\s*inputContext$', s)]
        self.assertEqual(len(bodies), 1, 'the view must override inputContext')
        body = bodies[0]
        self.assertRegex(body, r'if\s*\(\s*m_window\s*==\s*nil\s*\)\s*return\s+nil')

    def test_view_methods_check_the_window(self):
        impl = implementation(self.text, 'com_runrev_livecode_MCWindowView')
        found = methods(impl)
        self.assertGreater(len(found), 40, 'methods() found too few methods to trust')
        bad = [sel for sel, body in found if unchecked_uses(body)]
        self.assertEqual(bad, [], 'these view methods use the platform window '
                         'before checking it for nil')

    def test_checker_sees_an_unchecked_use(self):
        # Fixture: the check must flag the bug it guards against.
        self.assertTrue(unchecked_uses('t_window = [self platformWindow];\n t_window -> HandleDragLeave();'))
        self.assertTrue(unchecked_uses('MCPlatformCallbackSendRawKeyDown([self platformWindow], 1, 2, 3);'))
        self.assertFalse(unchecked_uses('t_window = [self platformWindow];\nif (t_window == nil) return;\nt_window -> X();'))
        self.assertFalse(unchecked_uses('if ([self platformWindow] == nil) return;\n'
                                        'MCPlatformCallbackSendRawKeyDown([self platformWindow], 1, 2, 3);'))


if __name__ == '__main__':
    unittest.main()
