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

"""The Mac's text input, where macOS asks a focused field to commit.

The view's unmarkText (engine/src/mac-window.mm) commits by sending no
characters at all: a nil buffer and a count of 0. The engine's handler,
MCPlatformHandleTextInputInsertText (engine/src/desktop.cpp), read the first
character of every insert before it looked at the count, so on a commit it
read address 0 and the engine crashed, with a field focused and marked text
or none. It was found while tracing tperry2x's crash on Apply after typing
with the on-screen Accessibility Keyboard (forum, p=25871), whose cause was
another (a view left pointing at a destroyed window, fixed in rc.6.12, #308);
no report of this one is known, and no CI machine can make macOS commit.
These checks hold the source: the commit is handled before anything reads a
character, it keeps the text, and nil stays unmarkText's alone, so an empty
string typed or marked goes on as before. On the source of 0.2.7-rc.6.12
test_the_commit_is_handled_first and test_a_commit_keeps_the_text fail.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding="utf-8") as f:
        return f.read()


def body(text, header):
    """The text of the function or method that starts at header, to its
    closing brace in column 0."""
    start = text.index(header)
    end = text.index("\n}", start)
    return text[start:end + 2]


def code(text):
    """text without its // comments, so that a comment naming p_chars is
    not taken for a read of it."""
    return re.sub(r"//[^\n]*", "", text)


class TheCommit(unittest.TestCase):
    HANDLER = "void MCPlatformHandleTextInputInsertText("

    def handler(self):
        """The handler's body, from its opening brace: its parameter list
        names unichar_t *p_chars, which is not a read."""
        text = code(body(read("engine", "src", "desktop.cpp"), self.HANDLER))
        return text[text.index("{"):]

    def test_the_commit_is_handled_first(self):
        text = self.handler()
        guard = re.search(r"if \(p_chars == nil\)\s*\{\s*MCactivefield -> stopcomposition\(False, False\);\s*return;\s*\}", text)
        self.assertIsNotNone(guard, "the handler does not end a commit (no characters, p_chars nil) before it reads one")
        # Every read of the characters comes after it.
        reads = [m.start() for m in re.finditer(r"MCUnicodeMapToNative\(p_chars|\*p_chars|p_chars\[", text)]
        self.assertTrue(reads, "the handler no longer reads p_chars: this check needs a new look")
        self.assertLess(guard.start(), min(reads),
                        "the handler reads a character before it looks for a commit with none")
        # It comes after the check for a focused field, which it needs.
        self.assertLess(text.index("if (!MCactivefield)"), guard.start())

    def test_a_commit_keeps_the_text(self):
        # stopcomposition(True, ...) would delete the marked text; a
        # commit accepts it (NSTextInputClient, unmarkText).
        text = self.handler()
        self.assertIn("if (p_chars == nil)", text)
        guard = text[text.index("if (p_chars == nil)"):]
        guard = guard[:guard.index("}")]
        self.assertIn("stopcomposition(False, False)", guard)
        self.assertNotIn("stopcomposition(True", guard)

    def test_nil_is_only_unmarktext(self):
        # An empty string from insertText or setMarkedText is a zero-length
        # array, never nil, and must still go through the handler as before.
        mm = code(read("engine", "src", "mac-window.mm"))
        calls = re.findall(r"MCPlatformCallbackSendTextInputInsertText\(\s*t_window,\s*([^,]+),", mm)
        self.assertEqual(len(calls), 3, calls)
        self.assertEqual(sorted(c.strip() for c in calls), ["nil", "t_chars", "t_chars"])
        unmark = body(mm, "- (void)unmarkText")
        self.assertRegex(unmark, r"MCPlatformCallbackSendTextInputInsertText\(t_window, nil, 0,")
        for header in ("- (void)insertText:", "- (void)setMarkedText:"):
            method = body(mm, header)
            self.assertIn("t_chars = new unichar_t[t_length];", method, header)


if __name__ == "__main__":
    unittest.main()
