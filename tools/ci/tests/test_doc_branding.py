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

"""The doc branding check (tools/ci/doc_branding.py): the docs of this
checkout pass it, a doc that names LiveCode again fails it, and what is a
fact or code (the licence, the credits, compatibility, identifiers, code)
is left alone.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import doc_branding  # noqa: E402

REPO = doc_branding.REPO


def counted(path, text):
    return [n for n, _ in doc_branding.findings(path, text)[1]]


def language(path, text):
    return [n for n, _ in doc_branding.findings(path, text)[0]]


class TheCheckout(unittest.TestCase):

    def test_the_docs_pass(self):
        files = doc_branding.tracked_docs(REPO)
        self.assertGreater(len(files), 2000, 'the docs were not found')
        self.assertEqual(doc_branding.check(REPO, files, doc_branding.read_baseline(REPO)), [])

    def test_the_guides_and_the_dictionary_are_in_scope(self):
        files = doc_branding.tracked_docs(REPO)
        for path in ('README.md', 'docs/dictionary/command/put.lcdoc',
                     'ide/Documentation/guides/XTalk Script.md'):
            self.assertIn(path, files)

    def test_the_licence_and_history_are_left_alone(self):
        files = doc_branding.tracked_docs(REPO)
        for path in ('LICENSE-EXCEPTION.md', 'NOTICE-OF-MODIFICATIONS.md',
                     'THIRD-PARTY-NOTICES.md', 'HISTORY.md', 'CHANGELOG.md',
                     'docs/glossary/l/LiveCode.lcdoc', 'changelog/637.md'):
            self.assertNotIn(path, files)

    def test_each_exempt_file_exists(self):
        # an exemption that names nothing would hide a renamed file
        for path in doc_branding.EXEMPT:
            self.assertTrue(os.path.exists(os.path.join(REPO, path)), path)


class TheRules(unittest.TestCase):

    def test_a_bare_mention_is_counted(self):
        self.assertEqual(counted('a.md', 'Open it in LiveCode.\n'), [1])
        self.assertEqual(counted('a.md', 'one\nLiveCode\'s IDE\n'), [2])
        self.assertEqual(counted('a.lcdoc', 'Description:\nLiveCode does it.\n'), [2])

    def test_the_languages_are_refused_even_across_a_line(self):
        self.assertEqual(language('a.md', 'Written in LiveCode Script.\n'), [1])
        self.assertEqual(language('a.md', 'x\nback into LiveCode\nBuilder, an array\n'), [2])
        self.assertEqual(language('a.md', 'a livecode builder module\n'), [1])
        self.assertEqual(counted('a.md', 'Written in LiveCode Script.\n'), [])

    def test_xtalk_names_pass(self):
        text = 'xTalk Script and xTalk Builder in OXT-Beyond.\n'
        self.assertEqual(language('a.md', text), [])
        self.assertEqual(counted('a.md', text), [])

    def test_facts_are_not_counted(self):
        for text in ('Copyright LiveCode Ltd.\n',
                     'It opens LiveCode Community stacks.\n',
                     'as in LiveCode 9.6.3, and in LiveCode 11\n',
                     "LiveCode's 7.0 engine\n",
                     'LiveCode\nCommunity, on two lines\n'):
            self.assertEqual(counted('a.md', text), [], text)

    def test_code_and_addresses_are_not_counted(self):
        for text in ('Run `LiveCode-Community.exe`.\n',
                     '```\nput "LiveCode" into x\n```\n',
                     'Some code:\n\n    put "LiveCode" into tName\n',
                     'See [the page](https://livecode.com/LiveCode).\n',
                     'See <https://example.org/LiveCode>.\n',
                     'the kind com.livecode.widget.navbar\n',
                     'Mail test@livecode.com\n'):
            self.assertEqual(counted('a.md', text), [], text)

    def test_an_indented_list_item_is_prose(self):
        self.assertEqual(counted('a.md', 'Steps:\n\n    - start LiveCode\n'), [3])

    def test_an_lcdoc_example_and_its_fields_are_code(self):
        text = ('Name: LiveCode\n\nSynonyms: livecode\n\nType: glossary\n\n'
                'Example:\nput "LiveCode" into x\n\nDescription:\nSee <LiveCode>.\n\n'
                'References: LiveCode (glossary)\n')
        self.assertEqual(counted('a.lcdoc', text), [])
        self.assertEqual(counted('a.lcdoc', text.replace('See <LiveCode>.', 'Open LiveCode.')), [11])


class TheRatchet(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        os.makedirs(os.path.join(self.root, 'tools', 'ci'))

    def write(self, path, text):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8') as f:
            f.write(text)

    def test_a_new_mention_fails_and_names_its_line(self):
        self.write('a.md', 'Upstream is LiveCode.\n\nThis is LiveCode.\n')
        problems = doc_branding.check(self.root, ['a.md'], {'a.md': 1})
        self.assertTrue(problems)
        self.assertIn('2 mentions of LiveCode, 1 allowed', problems[0])
        self.assertTrue(any('a.md:3: This is LiveCode.' in p for p in problems))

    def test_the_baseline_allows_what_it_counts(self):
        self.write('a.md', 'Upstream is LiveCode.\n')
        self.assertEqual(doc_branding.check(self.root, ['a.md'], {'a.md': 1}), [])

    def test_a_count_that_went_down_must_be_written_down(self):
        self.write('a.md', 'OXT-Beyond.\n')
        problems = doc_branding.check(self.root, ['a.md'], {'a.md': 1})
        self.assertEqual(len(problems), 1)
        self.assertIn('run python3 tools/ci/doc_branding.py baseline', problems[0])

    def test_a_language_name_fails_whatever_the_baseline(self):
        self.write('a.md', 'LiveCode Builder\n')
        problems = doc_branding.check(self.root, ['a.md'], {'a.md': 5})
        self.assertTrue(any('say xTalk Script or xTalk Builder' in p for p in problems))

    def test_a_baseline_entry_for_a_file_out_of_scope_fails(self):
        self.write('a.md', 'OXT-Beyond.\n')
        problems = doc_branding.check(self.root, ['a.md'], {'gone.md': 1})
        self.assertTrue(any('gone.md' in p for p in problems))

    def test_the_baseline_round_trips(self):
        self.write('a.md', 'LiveCode and LiveCode.\n')
        self.write('b.md', 'OXT-Beyond.\n')
        doc_branding.write_baseline(self.root, ['a.md', 'b.md'])
        self.assertEqual(doc_branding.read_baseline(self.root), {'a.md': 2})
        self.assertEqual(doc_branding.check(self.root, ['a.md', 'b.md'],
                                            doc_branding.read_baseline(self.root)), [])

    def test_vendored_code_is_out_of_scope(self):
        self.assertFalse(doc_branding.in_scope('thirdparty/x/README.md'))
        self.assertFalse(doc_branding.in_scope('engine/src/x.cpp'))
        # a changelog fragment is folded into CHANGELOG.md at a release,
        # so both are a record, read as they are
        self.assertFalse(doc_branding.in_scope('changelog/999.md'))
        self.assertTrue(doc_branding.in_scope('docs/notes/x.md'))


if __name__ == '__main__':
    unittest.main()
