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

"""docs/dictionary/control_st/return.lcdoc, the Dictionary entry for
`return`.

Its syntax line once read `return <value> [ for { value | error } ]`, the
same word as the placeholder and as one of the keywords after `for`, which
made the line hard to read (Brian Milby's report, 2026-11-26). These tests
keep the placeholder distinct from the keywords, keep it documented under
Parameters, and keep the six examples (function or command, by each of the
three forms) saying what the engine does. The engine side of those six is
tested by tests/lcs/core/engine/return.livecodescript; this file holds the
page to the same answers.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
ENTRY = os.path.join(REPO, 'docs', 'dictionary', 'control_st', 'return.lcdoc')
ENGINE_TEST = os.path.join(REPO, 'tests', 'lcs', 'core', 'engine',
                           'return.livecodescript')

SECTION = re.compile(r'^([A-Z][A-Za-z ]*):[ \t]*(.*)$')


def sections(text):
    """The entry's sections in order, as (name, body) pairs; Example may
    repeat."""
    out = []
    for line in text.splitlines():
        m = SECTION.match(line)
        if m and not line.startswith(' '):
            out.append([m.group(1), m.group(2) + '\n'])
        elif out:
            out[-1][1] += line + '\n'
    return [(n, b.strip('\n')) for n, b in out]


def read_entry():
    with open(ENTRY, encoding='utf-8') as f:
        return f.read()


# What each example's caller sees, as the engine test asserts it:
# (handler kind, form) -> the comment the example must carry.
EXPECTED = {
    ('function', ''): '-- tVar contains 1, the result contains 1',
    ('function', 'value'): '-- tVar contains 1, the result contains empty',
    ('function', 'error'): '-- tVar contains empty, the result contains 1',
    ('command', ''): '-- the result contains 1',
    ('command', 'value'): '-- it contains 1, the result contains empty',
    ('command', 'error'): '-- it contains empty, the result contains 1',
}


class ReturnEntry(unittest.TestCase):

    def setUp(self):
        self.text = read_entry()
        self.sections = sections(self.text)

    def syntax(self):
        found = [b for n, b in self.sections if n == 'Syntax']
        self.assertEqual(len(found), 1)
        return found[0]

    def test_placeholder_is_not_a_keyword_of_the_line(self):
        line = self.syntax()
        self.assertEqual(line, 'return <returnValue> [ for { value | error } ]')
        placeholders = {p.lower() for p in re.findall(r'<(\w+)>', line)}
        bare = {w.lower() for w in
                re.findall(r'[A-Za-z]\w*', re.sub(r'<[^>]*>', ' ', line))}
        self.assertFalse(placeholders & bare,
                         'a placeholder shares a name with a keyword: %s'
                         % sorted(placeholders & bare))

    def test_placeholder_is_the_documented_parameter(self):
        params = [b for n, b in self.sections if n == 'Parameters']
        self.assertEqual(len(params), 1)
        self.assertRegex(params[0], r'(?m)^returnValue:$')
        self.assertNotRegex(params[0], r'(?m)^value:$')

    def test_no_old_placeholder_left_in_the_prose(self):
        # <value> in a description links to `value (function)`, which is in
        # the References; the parameter is <returnValue> everywhere now.
        body = self.text.split('\nReferences:', 1)[0]
        self.assertNotIn('<value>', body)

    def test_six_examples_one_per_case_with_the_engine_answers(self):
        examples = [b for n, b in self.sections if n == 'Example']
        self.assertEqual(len(examples), 6)
        seen = {}
        for ex in examples:
            kind = re.search(r'^\s*(function|command) ', ex, re.M).group(1)
            ret = re.search(r'^\s*return 1(?: for (value|error))?\s*$', ex, re.M)
            self.assertIsNotNone(ret, ex)
            key = (kind, ret.group(1) or '')
            self.assertNotIn(key, seen, 'two examples for %s' % (key,))
            comment = re.search(r'^\s*(--.*)$', ex, re.M).group(1).strip()
            seen[key] = comment
        self.assertEqual(seen, EXPECTED)

    def test_engine_test_still_asserts_those_answers(self):
        # The examples are only as true as the engine test behind them; if
        # it is renamed or loses a form, this page's claims lose their proof.
        with open(ENGINE_TEST, encoding='utf-8') as f:
            engine = f.read()
        for handler in ('TestReturn', 'TestReturnValue', 'TestReturnError'):
            self.assertRegex(engine, r'(?m)^on %s$' % handler)
        for form in ('return pValue for value', 'return pValue for error'):
            self.assertEqual(engine.count(form), 2, form)


class SectionsParser(unittest.TestCase):
    """The small parser above, on an entry shaped like the real one."""

    def test_repeated_examples_and_indented_code(self):
        text = ('Name: x\n\nSyntax: x <a>\n\nExample:\n    on t\n'
                '       -- Note: not a section\n    end t\n\nExample:\n'
                '    put 1\n\nParameters:\na:\nThe a.\n')
        got = sections(text)
        self.assertEqual([n for n, _ in got],
                         ['Name', 'Syntax', 'Example', 'Example', 'Parameters'])
        self.assertIn('-- Note: not a section', got[2][1])


if __name__ == '__main__':
    unittest.main()
