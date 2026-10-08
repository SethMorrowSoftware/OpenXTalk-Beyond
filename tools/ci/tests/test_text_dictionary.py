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

"""tools/oxt/text_dictionary.py, which writes the entries of the text
dictionary (OpenXTalk Lite's) from the docs builder's data: the layout of an
entry, its links, the names of the entry files and the substitutions that
the dictionary turns back into names, the sections, and the list of
extensions whose docs it adds.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import text_dictionary as td  # noqa: E402
import layout  # noqa: E402


def write_json(path, entries, bom=False):
    """A file as the docs builder writes it: the entries separated by
    commas, without the brackets of an array."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = ',\n'.join(json.dumps(e) for e in entries)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(('﻿' if bom else '') + text + ',\n')


def run(argv):
    """text_dictionary.py's exit code for the arguments, its report kept."""
    with contextlib.redirect_stdout(io.StringIO()):
        return td.main(argv)


def shown_name(file_name, substitutions=td.SUBSTITUTIONS):
    """The name the dictionary shows for an entry file (tRegenerateIndex
    of oxt_dictionary.oxtstack): the substitutions turned back, in their
    order, then "DOLLAR_" as "$_"."""
    name = file_name[:-len('.txt')] + ' '
    for chars, word in substitutions:
        name = name.replace(word + ' ', chars + ' ')
    return name.replace('DOLLAR_', '$_').rstrip()


TRY = {
    'name': 'try', 'display name': 'try', 'type': 'control structure',
    'syntax': ['try\n   <statementList>\ncatch <errorVariable>\nend try'],
    'summary': 'Executes a list of statements, sending any\n<errorMessage|errors> to the catch routine.',
    'parameters': [
        {'name': 'statementList', 'type': '', 'description': 'One or more <statement|statements>.'},
        {'name': 'errorVariable', 'type': 'string', 'description': 'A variable.\nIt holds the error.'},
    ],
    'examples': [{'script': '\ntry\n   open file tFile\ncatch tError\n   answer tError\nend try\n'}],
    'description': ('Use the <try> control structure to execute a series of <statement|statements>\n'
                    'and handle any <error message|error messages> in the <catch> section.\n\n'
                    'Form:\n* the try line\n* the catch line,\n  with its variable\n\n'
                    '    put 1 into x\n    put x\n\n'
                    '>*Note:* The &lt;finally&gt; section is optional.\n\n'
                    '| Error | Meaning |\n|---|---|\n| 1 | none |'),
    'value': [{'name': 'return', 'description': 'Nothing.'}, {'name': 'it', 'description': 'The error.'}],
    'OS': ['mac', 'windows', 'linux'],
}

TRY_TEXT = '\n'.join([
    'try',
    '(control structure)',
    'Executes a list of statements, sending any errorMessage|errors to the catch routine.',
    '',
    'Syntax:',
    'try',
    '   {statementList}',
    'catch {errorVariable}',
    'end try',
    '----',
    '',
    'Synonyms:',
    '',
    'Params:',
    '•\tstatementList ( ): One or more statement|statements.',
    '•\terrorVariable (string ): A variable. It holds the error.',
    '',
    'Examples:',
    'try',
    '   open file tFile',
    'catch tError',
    '   answer tError',
    'end try',
    '----',
    '',
    'Description:',
    'Use the try control structure to execute a series of statement|statements and handle any '
    'error message|error messages in the catch section.',
    '',
    'Form:',
    '* the try line',
    '* the catch line, with its variable',
    '',
    '    put 1 into x',
    '    put x',
    '',
    '*Note:* The <finally> section is optional.',
    '',
    'Error - Meaning',
    '1 - none',
    '',
    'Values:',
    'Nothing. The error.',
    '',
    'OS:',
    'mac,windows,linux',
])


class EntryTextTest(unittest.TestCase):
    def test_layout(self):
        self.assertEqual(td.entry_text(TRY), TRY_TEXT)

    def test_what_the_ui_tour_checks(self):
        # tools/ci/ui-tour.livecodescript (tourDictionaryEntry) reads
        # "try control structure.txt": a bullet, the phrase, and the links
        # of one word and of two in it written whole, as target|shown
        text = td.entry_text(TRY)
        self.assertIn('•\t', text)
        self.assertIn('a series of statement|statements and handle any error message|error messages', text)

    def test_an_empty_entry(self):
        self.assertEqual(td.entry_text({'name': 'x', 'type': 'keyword'}), '\n'.join([
            'x', '(keyword)', '', 'Syntax:', 'Synonyms:', '', 'Params:', '', 'Examples:',
            'Description:', '', 'Values:', '', 'OS:']))

    def test_synonyms_and_display_name(self):
        text = td.entry_text({'name': 'a', 'display name': 'A&amp;B', 'type': 'property',
                              'synonyms': ['ab', 'a&amp;b']})
        self.assertTrue(text.startswith('A&B\n(property)\n'))
        self.assertIn('\nSynonyms:\nab, a&b\n', text)

    def test_links(self):
        self.assertEqual(td.links('<put> and <error message|error messages>'),
                         'put and error message|error messages')
        self.assertEqual(td.one_line('>*Note:* a\n  <b|c>\n\nd'), '*Note:* a b|c d')


class FileNameTest(unittest.TestCase):
    def test_stems(self):
        self.assertEqual(td.file_stem('&&'), 'DOUBLEAND')
        self.assertEqual(td.file_stem('<'), 'LESSTHAN')
        self.assertEqual(td.file_stem('&lt;&gt;'), 'LESSGREATER')
        self.assertEqual(td.file_stem('$_GET'), 'DOLLAR_GET')
        self.assertEqual(td.file_stem('/'), 'slash')
        self.assertEqual(td.file_stem('a:b'), 'a_b')
        self.assertEqual(td.file_stem('what?'), 'what_')

    def test_the_dictionary_shows_the_name(self):
        for chars, _ in td.SUBSTITUTIONS:
            name = '%s operator.txt' % td.file_stem(chars)
            self.assertEqual(shown_name(name), chars + ' operator', name)
        self.assertEqual(shown_name('DOLLAR_GET keyword.txt'), '$_GET keyword')

    def test_substitution_order(self):
        # a word that ends with another word is turned back first
        words = [w for _, w in td.SUBSTITUTIONS]
        self.assertEqual(len(words), len(set(words)))
        for i, w in enumerate(words):
            for later in words[i + 1:]:
                self.assertFalse(later.endswith(w), '%s comes before %s' % (w, later))

    def test_names_that_differ_only_in_case_or_type(self):
        names = [n for n, _ in td.file_names([
            {'name': 'text', 'type': 'property'},
            {'name': 'text', 'type': 'keyword'},
            {'name': 'Text', 'type': 'property', 'associations': ['com.livecode.widget.native.mac.textfield']},
        ])]
        self.assertEqual(names, ['Text (textfield) property.txt', 'text keyword.txt', 'text property.txt'])

    def test_collisions(self):
        engine = {'name': 'enabled', 'type': 'property', 'syntax': ['set the enabled of <object> to true']}
        android = {'name': 'enabled', 'type': 'property',
                   'associations': ['com.livecode.widget.native.android.button']}
        mac = {'name': 'enabled', 'type': 'property', 'associations': ['com.livecode.widget.native.mac.button']}
        field = {'name': 'enabled', 'type': 'property', 'associations': ['com.livecode.widget.native.android.field']}
        same = {'name': 'enabled', 'type': 'property', 'associations': ['com.livecode.widget.native.mac.button']}
        popup = {'name': 'popup', 'type': 'command', 'syntax': ['popup <menu>']}
        widget = {'name': 'popup', 'type': 'command', 'syntax': ['popup widget <kind>']}
        dg1 = {'name': 'column divider color', 'type': 'property',
               'associations': ['datagrid', 'datagrid general properties']}
        dg2 = {'name': 'column divider color', 'type': 'property',
               'associations': ['datagrid', 'datagrid table properties']}
        # the entries of the docs builder come before those of the extensions
        names = dict((id(e), n) for n, e in td.file_names([engine, android, mac, field, same, widget, popup,
                                                           dg1, dg2]))
        self.assertEqual(names[id(engine)], 'enabled property.txt')
        self.assertEqual(names[id(android)], 'enabled (android.button) property.txt')
        self.assertEqual(names[id(field)], 'enabled (field) property.txt')
        self.assertEqual(names[id(mac)], 'enabled (2) property.txt')
        self.assertEqual(names[id(same)], 'enabled (3) property.txt')
        self.assertEqual(names[id(popup)], 'popup command.txt')
        self.assertEqual(names[id(widget)], 'popup widget command.txt')
        self.assertEqual(names[id(dg1)], 'column divider color property.txt')
        self.assertEqual(names[id(dg2)], 'column divider color (datagrid table properties) property.txt')

    def test_no_two_names_the_same(self):
        entries = [{'name': 'a', 'type': 'command'} for _ in range(5)] + [{'name': 'A (2)', 'type': 'command'}]
        names = [n.lower() for n, _ in td.file_names(entries)]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(len(names), 6)


class FilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def data(self):
        data = os.path.join(self.tmp, 'data')
        write_json(os.path.join(data, 'api_livecode_script', 'script.js'),
                   [TRY, {'name': 'com.livecode.language', 'type': ''}], bom=True)
        write_json(os.path.join(data, 'api_livecode_script', 'dg.js'), [{'name': 'dgText', 'type': 'property'}])
        write_json(os.path.join(data, 'api_livecode_builder', 'builder.js'), [{'name': 'Put', 'type': 'statement'}])
        ext = os.path.join(self.tmp, 'ext')
        os.makedirs(ext)
        with open(os.path.join(ext, td.EXTENSION_LIST), 'w', encoding='utf-8') as f:
            f.write('com.x.widget\twidget\t/src/x.lcb\tX\tme\n'
                    'com.x.module\tmodule\t/src/m.lcb\tM\tme\n'
                    'com.x.empty\tplugin\t/src/e.livecodescript\t\t\n')
        write_json(os.path.join(ext, 'com.x.widget.js'), [{'name': 'X', 'type': 'widget'},
                                                          {'name': 'hilite', 'type': 'property'}])
        write_json(os.path.join(ext, 'com.x.module.js'), [{'name': 'M', 'type': 'module'}])
        return data, ext

    def test_sections(self):
        data, ext = self.data()
        sections = td.collect(data, ext)
        self.assertEqual([e['name'] for e in sections['xtalk']], ['try', 'X', 'hilite'])
        self.assertEqual([e['name'] for e in sections['datagrid']], ['dgText'])
        self.assertEqual([e['name'] for e in sections['builder']], ['Put', 'M'])
        self.assertEqual([e['name'] for e in td.collect(data)['xtalk']], ['try'])

    def test_write(self):
        data, ext = self.data()
        out = os.path.join(self.tmp, 'exports')
        self.assertEqual(run(['--data', data, '--out', out, '--extensions', ext]), 0)
        pages = os.path.join(out, 'xtalk', 'resaved')
        self.assertEqual(sorted(os.listdir(pages)),
                         ['X widget.txt', 'hilite property.txt', 'try control structure.txt'])
        with open(os.path.join(pages, 'try control structure.txt'), 'rb') as f:
            self.assertEqual(f.read(), TRY_TEXT.encode('utf-8'))
        with open(os.path.join(out, 'xtalk', 'index.txt'), encoding='utf-8') as f:
            self.assertEqual(f.read(), 'X widget.txt\nhilite property.txt\ntry control structure.txt\n')
        with open(os.path.join(out, 'builder', 'substitutions.txt'), encoding='utf-8') as f:
            lines = f.read().splitlines()
        self.assertEqual(lines[0], '&\tSINGLEAND')
        self.assertEqual(len(lines), len(td.SUBSTITUTIONS))
        # a later run replaces the entries, and leaves plugins alone
        os.makedirs(os.path.join(out, 'xtalk', 'plugins'))
        open(os.path.join(out, 'xtalk', 'plugins', 'mine.txt'), 'w').close()
        open(os.path.join(pages, 'old entry.txt'), 'w').close()
        self.assertEqual(run(['--data', data, '--out', out]), 0)
        self.assertEqual(sorted(os.listdir(pages)), ['try control structure.txt'])
        self.assertEqual(os.listdir(os.path.join(out, 'xtalk', 'plugins')), ['mine.txt'])

    def test_bad_data(self):
        data = os.path.join(self.tmp, 'data')
        write_json(os.path.join(data, 'api_livecode_script', 'script.js'), [{'type': 'command'}])
        write_json(os.path.join(data, 'api_livecode_builder', 'builder.js'), [{'name': 'Put', 'type': 'statement'}])
        with self.assertRaises(td.TextDictionaryError):
            td.collect(data)
        os.makedirs(os.path.join(self.tmp, 'empty'))
        with self.assertRaises(td.TextDictionaryError):
            td.collect(os.path.join(self.tmp, 'empty'))


class ExtensionsTest(unittest.TestCase):
    def test_what_the_build_installs(self):
        found = td.extension_sources()
        ids = [x[0] for x in found]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(set(layout.REPO_BUILT_EXTENSIONS) <= set(ids))
        for ident, kind, source, title, author in found:
            self.assertIn(kind, ('library', 'widget', 'module', 'plugin', 'ide'), ident)
            self.assertTrue(os.path.isfile(source), source)
            if kind == 'widget':
                self.assertTrue(title, ident)
        self.assertEqual(found[-1][:2], ('revidelibrary', 'ide'))
        # the widgets that ide/Extensions installs with their docs
        self.assertIn('com.livecode.widget.calendar', ids)
        self.assertIn('com.livecode.widget.piechart', ids)
        self.assertEqual(dict((x[0], x[3]) for x in found)['com.livecode.widget.headerbar'], 'Header Bar')
        self.assertEqual(dict((x[0], x[3]) for x in found)['com.livecode.library.dropbox'], 'Dropbox Library')

    def test_list(self):
        tmp = tempfile.mkdtemp()
        try:
            self.assertEqual(run(['--list-extensions', tmp]), 0)
            with open(os.path.join(tmp, td.EXTENSION_LIST), encoding='utf-8') as f:
                lines = f.read().splitlines()
            self.assertEqual(len(lines), len(td.extension_sources()))
            self.assertTrue(all(len(line.split('\t')) == 5 for line in lines))
        finally:
            shutil.rmtree(tmp)


if __name__ == '__main__':
    unittest.main()
