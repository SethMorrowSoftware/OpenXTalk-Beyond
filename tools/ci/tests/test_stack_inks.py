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

"""tools/ci/stack_inks.py's reading of stack dumps, on made-up dumps: which
text colours it fails, a control's own and one it takes from its stack, card
or group, what a background on the control or an owner changes, and that
its list of exceptions cannot outlive what it excuses. No engine is
needed (tools/oxt/stack-scripts.sh runs the check on the real stacks, with
the engine the Linux build made).

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import stack_inks as inks  # noqa: E402

REL = 'ide/Toolset/palettes/x.rev'
HEAD = ('== stack "X"\n'
        'prop name: X\n'
        '== stack "X" > card "Main" (id 1002)\n'
        'prop name: Main\n')


def control(kind, name, ident, props, owner='card "Main" (id 1002)'):
    lines = ['== stack "X" > %s > %s "%s" (id %d)' % (owner, kind, name, ident)]
    lines += ['prop %s: %s' % item for item in props.items()]
    return '\n'.join(lines) + '\n'


class Dumps(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)

    def dump(self, text, rel=REL):
        path = os.path.join(self.dir.name, inks.dump_name(rel))
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
        return path

    def found(self, text):
        return inks.findings(REL, self.dump(text))


class TestColours(unittest.TestCase):
    def test_the_forms_the_stacks_use(self):
        self.assertEqual(inks.colour('0,0,0'), (0, 0, 0))
        self.assertEqual(inks.colour('66, 66,66'), (66, 66, 66))
        self.assertEqual(inks.colour('10,20,30,255'), (10, 20, 30))
        self.assertEqual(inks.colour('black'), (0, 0, 0))
        self.assertEqual(inks.colour('White'), (255, 255, 255))
        self.assertEqual(inks.colour('Gray40'), (102, 102, 102))
        self.assertEqual(inks.colour('grey100'), (255, 255, 255))
        self.assertEqual(inks.colour('#30A0D1'), (48, 160, 209))
        self.assertEqual(inks.colour('Dark Gray'), (169, 169, 169))

    def test_a_colour_it_does_not_know_is_none(self):
        for value in ('PapayaWhip', '300,0,0', '1,2', 'gray101', '#12345'):
            self.assertIsNone(inks.colour(value), value)

    def test_contrast_is_wcags(self):
        self.assertAlmostEqual(inks.contrast((0, 0, 0), (255, 255, 255)), 21.0, places=3)
        self.assertAlmostEqual(inks.contrast((255, 255, 255), (0, 0, 0)), 21.0, places=3)
        self.assertAlmostEqual(inks.contrast((9, 9, 9), (9, 9, 9)), 1.0, places=6)
        # The two cases the review found, against Windows' dark window
        self.assertLess(inks.contrast((0, 0, 0), inks.DARK_WINDOW), 1.5)
        self.assertLess(inks.contrast((66, 66, 66), inks.DARK_WINDOW), inks.MIN_CONTRAST)


class TestFindings(Dumps):
    def test_black_of_its_own_fails_on_the_dark_window(self):
        got = self.found(HEAD + control('button', 'UAC', 7, {'foreColor': '0,0,0'}))
        self.assertEqual(len(got), 1)
        obj, ink, what = got[0]
        self.assertEqual(obj, 'card "Main" (id 1002) > button "UAC" (id 7)')
        self.assertEqual(ink, '0,0,0')
        self.assertIn('on the dark window', what)

    def test_a_named_black_fails_as_well(self):
        got = self.found(HEAD + control('button', 'library chooser', 7, {'foreColor': 'black'}))
        self.assertEqual([what.split(' on the ')[1] for _, _, what in got], ['dark window'])

    def test_the_headers_dark_grey_fails_on_the_dark_window(self):
        got = self.found(HEAD + control('field', 'Required label', 8, {'foreColor': '66,66,66'}))
        self.assertEqual(len(got), 1)
        self.assertIn('on the dark window', got[0][2])

    def test_white_of_its_own_fails_on_the_light_window(self):
        got = self.found(HEAD + control('field', 'note', 9, {'foreColor': '255,255,255'}))
        self.assertEqual(len(got), 1)
        self.assertIn('on the light window', got[0][2])

    def test_a_colour_that_stands_out_from_both_passes(self):
        # A mid grey, and the IDE's selection blue
        for ink in ('128,128,128', '48,160,209'):
            self.assertEqual(self.found(HEAD + control('field', 'note', 9, {'foreColor': ink})), [], ink)

    def test_no_colour_of_its_own_passes(self):
        self.assertEqual(self.found(HEAD + control('button', 'OK', 7, {})), [])
        self.assertEqual(self.found(HEAD + control('button', 'OK', 7, {'foreColor': ''})), [])

    def test_a_background_on_the_control_passes(self):
        for key, value in (('backColor', '255,255,255'), ('backPattern', '1234')):
            got = self.found(HEAD + control('button', 'OK', 7, {'foreColor': 'black', key: value}))
            self.assertEqual(got, [], key)

    def test_a_background_on_an_owner_passes(self):
        group = ('== stack "X" > card "Main" (id 1002) > group "Bar" (id 5)\n'
                 'prop backColor: 240,240,240\n')
        inside = control('button', 'OK', 7, {'foreColor': 'black'}, 'card "Main" (id 1002) > group "Bar" (id 5)')
        self.assertEqual(self.found(HEAD + group + inside), [])
        # the card's, and the stack's
        card = HEAD + 'prop backColor: white\n' + control('button', 'OK', 7, {'foreColor': 'black'})
        self.assertEqual(self.found(card), [])
        stack = ('== stack "X"\nprop backColor: white\n== stack "X" > card "Main" (id 1002)\n'
                 + control('button', 'OK', 7, {'foreColor': 'black'}))
        self.assertEqual(self.found(stack), [])

    def test_a_background_on_another_group_does_not_excuse(self):
        group = ('== stack "X" > card "Main" (id 1002) > group "Bar" (id 5)\n'
                 'prop backColor: 240,240,240\n')
        got = self.found(HEAD + group + control('button', 'OK', 7, {'foreColor': 'black'}))
        self.assertEqual(len(got), 1)

    def test_only_buttons_and_fields_are_read(self):
        for kind in ('graphic', 'group', 'scrollbar', 'image', 'player', 'widget'):
            self.assertEqual(self.found(HEAD + control(kind, 'x', 7, {'foreColor': 'black'})), [], kind)

    def test_a_colour_it_does_not_know_is_reported(self):
        got = self.found(HEAD + control('button', 'OK', 7, {'foreColor': 'PapayaWhip'}))
        self.assertEqual(len(got), 1)
        self.assertIn('NAMES', got[0][2])

    def test_a_substacks_control_is_named_with_its_substack(self):
        text = ('== stack "X"\n== stack "X" > substack "Pop"\n== stack "X" > substack "Pop" > card (id 1002)\n'
                + control('button', 'None', 7, {'foreColor': 'black'}, 'substack "Pop" > card (id 1002)'))
        self.assertEqual([obj for obj, _, _ in self.found(text)],
                         ['substack "Pop" > card (id 1002) > button "None" (id 7)'])

    def test_script_lines_and_other_lines_are_not_properties(self):
        text = (HEAD + '== stack "X" > card "Main" (id 1002) > button "OK" (id 7)\n'
                '| prop foreColor: black\n'
                'script: 3 lines\n'
                'prop label: a: b\n')
        objs = inks.objects(self.dump(text))
        self.assertEqual(objs[-1][1], {'label': 'a: b'})
        self.assertEqual(inks.findings(REL, self.dump(text)), [])


GROUP = 'card "Main" (id 1002) > group "Bar" (id 5)'


def group(props, name='Bar', ident=5):
    lines = ['== stack "X" > card "Main" (id 1002) > group "%s" (id %d)' % (name, ident)]
    lines += ['prop %s: %s' % item for item in props.items()]
    return '\n'.join(lines) + '\n'


class TestOwners(Dumps):
    """A text colour on a stack, card or group, which the buttons and fields
    under it with none of their own are drawn in (Replicate's stack kept
    black, so every word of the dialog was black on the dark window)."""

    STACK = '== stack "X"\nprop foreColor: %s\n== stack "X" > card "Main" (id 1002)\n'

    def test_a_stacks_black_fails_once_with_how_many_take_it(self):
        text = (self.STACK % 'Black' + control('field', 'label rotate', 7, {})
                + control('button', 'OK', 8, {}) + control('button', 'Cancel', 9, {'foreColor': ''}))
        got = self.found(text)
        self.assertEqual(len(got), 1)
        obj, ink, what = got[0]
        self.assertEqual(obj, inks.THE_STACK)
        self.assertEqual(ink, 'Black')
        self.assertIn('taken by 3 button(s) and field(s)', what)
        self.assertIn('the first field "label rotate" (id 7)', what)
        self.assertIn('on the dark window', what)

    def test_a_cards_white_fails_on_the_light_window(self):
        text = ('== stack "X"\n== stack "X" > card "Main" (id 1002)\nprop foreColor: 255,255,255\n'
                + control('field', 'Status', 7, {}))
        got = self.found(text)
        self.assertEqual([(obj, what.split(' on the ')[1]) for obj, _, what in got],
                         [('card "Main" (id 1002)', 'light window')])

    def test_a_groups_black_fails_and_names_the_group(self):
        got = self.found(HEAD + group({'foreColor': 'black'}) + control('button', 'OK', 7, {}, GROUP))
        self.assertEqual([obj for obj, _, _ in got], [GROUP])

    def test_an_owner_no_button_or_field_takes_from_passes(self):
        # nothing under it, only a graphic under it, and controls beside it
        self.assertEqual(self.found(HEAD + group({'foreColor': 'black'})), [])
        self.assertEqual(self.found(HEAD + group({'foreColor': 'black'}) + control('graphic', 'line', 7, {}, GROUP)), [])
        self.assertEqual(self.found(HEAD + group({'foreColor': 'black'}) + control('button', 'OK', 7, {})), [])

    def test_a_control_with_a_colour_of_its_own_does_not_take_its_owners(self):
        # a mid grey of its own under a black stack: neither fails
        text = self.STACK % 'black' + control('button', 'OK', 7, {'foreColor': '128,128,128'})
        self.assertEqual(self.found(text), [])
        # black of its own under a black stack: the control fails, not the stack
        text = self.STACK % 'black' + control('button', 'OK', 7, {'foreColor': '0,0,0'})
        self.assertEqual([obj for obj, _, _ in self.found(text)], ['card "Main" (id 1002) > button "OK" (id 7)'])

    def test_the_nearest_owner_with_a_colour_is_the_one_taken(self):
        inside = control('button', 'OK', 7, {}, GROUP)
        # a group's mid grey under a black stack passes
        self.assertEqual(self.found(self.STACK % 'black' + group({'foreColor': '128,128,128'}) + inside), [])
        # a group's black under a mid grey stack fails, and names the group
        got = self.found(self.STACK % '128,128,128' + group({'foreColor': 'black'}) + inside)
        self.assertEqual([obj for obj, _, _ in got], [GROUP])
        # a group with an empty colour takes the stack's
        got = self.found(self.STACK % 'black' + group({'foreColor': ''}) + inside)
        self.assertEqual([obj for obj, _, _ in got], [inks.THE_STACK])

    def test_a_colour_that_stands_out_from_both_passes(self):
        self.assertEqual(self.found(self.STACK % '128,128,128' + control('button', 'OK', 7, {})), [])

    def test_a_background_anywhere_from_the_control_up_passes(self):
        for key, value in (('backColor', '255,255,255'), ('backPattern', '1234')):
            # on the control, on a group between, and on the owner that has the colour
            self.assertEqual(self.found(self.STACK % 'black' + control('button', 'OK', 7, {key: value})), [], key)
            text = self.STACK % 'black' + group({key: value}) + control('button', 'OK', 7, {}, GROUP)
            self.assertEqual(self.found(text), [], key)
            text = ('== stack "X"\nprop foreColor: black\nprop %s: %s\n== stack "X" > card "Main" (id 1002)\n'
                    % (key, value) + control('button', 'OK', 7, {}))
            self.assertEqual(self.found(text), [], key)

    def test_only_the_controls_with_no_background_are_counted(self):
        text = (self.STACK % 'black' + control('button', 'OK', 7, {'backColor': 'white'})
                + control('button', 'Cancel', 8, {}))
        got = self.found(text)
        self.assertEqual(len(got), 1)
        self.assertIn('taken by 1 button(s) and field(s) under it, the first button "Cancel" (id 8)', got[0][2])

    def test_a_substacks_own_colour_names_the_substack(self):
        text = ('== stack "X"\n== stack "X" > substack "Pop"\nprop foreColor: Black\n'
                '== stack "X" > substack "Pop" > card (id 1002)\n'
                + control('button', 'Pulldown', 7, {}, 'substack "Pop" > card (id 1002)'))
        self.assertEqual([obj for obj, _, _ in self.found(text)], ['substack "Pop"'])

    def test_a_substacks_controls_take_the_main_stacks_colour(self):
        text = ('== stack "X"\nprop foreColor: Black\n== stack "X" > substack "Pop"\n'
                '== stack "X" > substack "Pop" > card (id 1002)\n'
                + control('button', 'Pulldown', 7, {}, 'substack "Pop" > card (id 1002)'))
        self.assertEqual([obj for obj, _, _ in self.found(text)], [inks.THE_STACK])

    def test_an_owners_colour_it_does_not_know_is_reported(self):
        got = self.found(self.STACK % 'PapayaWhip' + control('button', 'OK', 7, {}))
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0][0], inks.THE_STACK)
        self.assertIn('NAMES', got[0][2])

    def test_owners_are_reported_after_the_controls_in_the_dumps_order(self):
        text = (self.STACK % 'black' + group({'foreColor': '0,0,0'}) + control('button', 'In', 7, {}, GROUP)
                + control('button', 'Own', 8, {'foreColor': 'black'}) + control('button', 'Out', 9, {}))
        self.assertEqual([obj for obj, _, _ in self.found(text)],
                         ['card "Main" (id 1002) > button "Own" (id 8)', GROUP, inks.THE_STACK])

    def test_an_exception_excuses_an_owner_and_goes_stale_with_it(self):
        self.dump(self.STACK % 'Black' + control('button', 'ruler', 7, {}))
        key = (REL, inks.THE_STACK)
        failures, stale, excused = inks.check(self.dir.name, [REL], {})
        self.assertEqual((len(failures), stale, excused), (1, [], 0))
        self.assertIn(REL + ': ' + inks.THE_STACK + ': its text colour Black (taken by 1 ', failures[0])
        self.assertEqual(inks.check(self.dir.name, [REL], {key: 'why'}), ([], [], 1))
        self.dump(HEAD + control('button', 'ruler', 7, {}))
        failures, stale, excused = inks.check(self.dir.name, [REL], {key: 'why'})
        self.assertEqual((failures, len(stale), excused), ([], 1, 0))


class TestCheck(Dumps):
    BAD = HEAD + control('button', 'UAC', 7, {'foreColor': '0,0,0'})
    KEY = (REL, 'card "Main" (id 1002) > button "UAC" (id 7)')

    def test_a_failing_control_is_a_failure_that_names_it(self):
        self.dump(self.BAD)
        failures, stale, excused = inks.check(self.dir.name, [REL], {})
        self.assertEqual((len(failures), stale, excused), (1, [], 0))
        self.assertIn(REL, failures[0])
        self.assertIn('button "UAC" (id 7)', failures[0])
        self.assertIn('0,0,0', failures[0])

    def test_an_exception_excuses_its_control_only(self):
        self.dump(self.BAD + control('button', 'Other', 8, {'foreColor': '0,0,0'}))
        failures, stale, excused = inks.check(self.dir.name, [REL], {self.KEY: 'why'})
        self.assertEqual((len(failures), stale, excused), (1, [], 1))
        self.assertIn('button "Other" (id 8)', failures[0])

    def test_an_exception_for_a_control_that_passes_is_stale(self):
        self.dump(HEAD + control('button', 'UAC', 7, {}))
        failures, stale, excused = inks.check(self.dir.name, [REL], {self.KEY: 'why'})
        self.assertEqual((failures, len(stale), excused), ([], 1, 0))
        self.assertIn('button "UAC" (id 7)', stale[0])

    def test_an_exception_for_another_stack_does_not_excuse(self):
        self.dump(self.BAD)
        other = ('ide/Toolset/palettes/y.rev', self.KEY[1])
        failures, stale, excused = inks.check(self.dir.name, [REL], {other: 'why'})
        self.assertEqual((len(failures), len(stale), excused), (1, 1, 0))


class TestMain(Dumps):
    def run_main(self, dumps):
        out, err = io.StringIO(), io.StringIO()
        argv = sys.argv
        sys.argv = ['stack_inks.py', '--dumps', dumps]
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                status = inks.main()
        finally:
            sys.argv = argv
        return status, out.getvalue(), err.getvalue()

    def test_no_dump_is_an_error_of_its_own(self):
        status, out, err = self.run_main(self.dir.name)
        self.assertEqual(status, 2)
        self.assertIn('no dump', err)

    def real(self):
        """A stack of the repository under ide/Toolset, to make a dump for."""
        rel = 'ide/Toolset/palettes/revimagelibrary.rev'
        self.assertTrue(os.path.exists(os.path.join(REPO, rel)), rel)
        return rel

    def test_a_failing_control_fails_the_run(self):
        rel = self.real()
        self.dump(HEAD + control('button', 'library chooser', 7, {'foreColor': 'black'}), rel)
        exceptions = inks.EXCEPTIONS
        inks.EXCEPTIONS = {}
        try:
            status, out, _ = self.run_main(self.dir.name)
        finally:
            inks.EXCEPTIONS = exceptions
        self.assertEqual(status, 1)
        self.assertIn('FAIL ' + rel, out)
        self.assertIn('button "library chooser" (id 7)', out)

    def test_a_stale_exception_fails_the_run(self):
        # With one clean stack's dump only, every listed exception is stale
        self.dump(HEAD + control('button', 'OK', 7, {}), self.real())
        status, out, _ = self.run_main(self.dir.name)
        self.assertEqual(status, 1)
        self.assertEqual(out.count('listed in EXCEPTIONS'), len(inks.EXCEPTIONS))

    def test_clean_stacks_pass(self):
        self.dump(HEAD + control('button', 'OK', 7, {}), self.real())
        exceptions = inks.EXCEPTIONS
        inks.EXCEPTIONS = {}
        try:
            status, out, _ = self.run_main(self.dir.name)
        finally:
            inks.EXCEPTIONS = exceptions
        self.assertEqual(status, 0)
        self.assertIn('1 IDE stacks', out)

    def test_stacks_outside_the_ides_windows_are_not_read(self):
        rel = 'ide/Toolset/palettes/revimagelibrary.rev'
        outside = [r for r in ('ide/Documentation', 'ide/Examples') if os.path.isdir(os.path.join(REPO, r))]
        self.dump(HEAD, rel)
        for folder in outside:
            self.dump(HEAD, folder + '/x.livecode')
        self.assertEqual(inks.stacks(self.dir.name), [rel])


class TestExceptions(unittest.TestCase):
    def test_every_exception_names_a_stack_in_scope_and_says_why(self):
        self.assertTrue(inks.EXCEPTIONS)
        for (rel, obj), why in inks.EXCEPTIONS.items():
            self.assertTrue(rel.startswith(inks.SCOPE), rel)
            self.assertTrue(os.path.exists(os.path.join(REPO, rel)), rel)
            # a button or field, or the owner whose colour its controls take
            if obj != inks.THE_STACK:
                self.assertRegex(obj.split(' > ')[-1],
                                 r'^((button|field) ".*" \(id \d+\)|(card|group)( ".*")? \(id \d+\)|substack ".*")$')
            self.assertFalse(obj.startswith('stack '), obj)
            self.assertGreater(len(why), 30, obj)

    def test_the_stack_scripts_tool_runs_the_check_and_keeps_its_status(self):
        with open(os.path.join(REPO, 'tools', 'oxt', 'stack-scripts.sh'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('python3 "$repo/tools/ci/stack_inks.py" --dumps "$dumps" || status=$?', text)
        self.assertIn('python3 "$here/stack_scripts.py" --dumps "$dumps" ${2:+"$2"} || status=$?', text)
        self.assertTrue(text.rstrip().endswith('exit $status'))

    def test_the_linux_build_runs_the_stack_scripts_tool_with_its_engine(self):
        with open(os.path.join(REPO, '.github', 'workflows', 'build-linux.yml'), encoding='utf-8') as f:
            text = f.read()
        self.assertRegex(text, r'tools/oxt/stack-scripts\.sh\s+\S+.*--check')


if __name__ == '__main__':
    unittest.main()
