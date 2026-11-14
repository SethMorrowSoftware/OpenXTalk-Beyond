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

"""tools/ci/check_ide_stacks.py's reading and checking of clone patches (a
copy of a control in a binary IDE stack), on made-up patch files and stack
files, and the Android card's "Post Notifications" box: its patches, and
the card, the builder and the Java layer agreeing on its name. No engine
is needed (tools/oxt/ide-stack-patch.sh --check, in the Linux build, checks
the copy's properties with one).

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import re
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import check_ide_stacks as cis  # noqa: E402

PATCHES = os.path.join(REPO, 'tools', 'oxt', 'ide-stack-patches')
SETTINGS = 'Toolset/palettes/standalone settings/revstandalonesettings.8.rev'
CARD_BOX = 'android-card-post-notifications-1.txt'
CARD_GROUPS = 'android-card-post-notifications-2.txt'
SCRIPTS = os.path.join(REPO, 'stack-scripts', 'ide', 'Toolset', 'palettes', 'standalone settings',
                       'revstandalonesettings.8.rev.bst', 'scripts')

CLONE = ('file: Toolset/x.rev\n'
         'object: button "A" of card 1\n'
         'clone: B\n'
         'unique-id: 1793989825265\n'
         'property: label\n'
         'to: Bee\n'
         'property: rect\n'
         'to: 1,2,3,4\n')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def rect(text):
    return [int(v) for v in text.split(',')]


class ReadClonePatch(unittest.TestCase):
    """read_patch reads a clone patch as the patch tool does, and refuses
    what the patch tool refuses"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def patch(self, text):
        path = os.path.join(self.tmp.name, 'p.txt')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
        return cis.read_patch(path)

    def refused(self, text, says):
        with self.assertRaises(ValueError) as e:
            self.patch(text)
        self.assertIn(says, str(e.exception))

    def test_reads_a_clone_patch(self):
        self.assertEqual(self.patch('# a comment\n\n' + CLONE),
                         ('clone', 'Toolset/x.rev', 'button "A" of card 1', 'B', '1793989825265',
                          [('label', 'Bee'), ('rect', '1,2,3,4')]))
        # no properties: the copy where clone puts it
        self.assertEqual(self.patch(CLONE.split('property:')[0])[5], [])

    def test_the_android_card_patch(self):
        self.assertEqual(cis.read_patch(os.path.join(PATCHES, CARD_BOX)), (
            'clone', SETTINGS,
            'button "AD" of group "permissions" of group "Application Permissions" of group "Android Settings" '
            'of card "Android"',
            'POST_NOTIFICATIONS', '1793989825265',
            [('label', 'Post Notifications'), ('rect', '589,643,728,666')]))

    def test_refusals(self):
        for text, says in (
                (CLONE.replace('unique-id: 1793989825265\n', ''), 'needs file:, object:, clone: and unique-id:'),
                (CLONE.replace('1793989825265', '179398982526'), 'unique-id: (13 digits'),
                (CLONE.replace('1793989825265', '0793989825265'), 'unique-id: (13 digits'),
                (CLONE.replace('file: Toolset/x.rev\n', ''), 'needs file:'),
                (CLONE.replace('clone: B', 'clone: '), 'needs file:, object:, clone:'),
                (CLONE.replace('clone: B', 'clone: "B"'), 'no quote'),
                (CLONE.replace('clone: B', 'clone: A > B'), 'no quote and no " > "'),
                (CLONE.replace('property: label', 'property: name'), 'does not set name'),
                (CLONE.replace('property: label', 'property: Layer'), 'does not set Layer'),
                (CLONE.replace('property: label', 'property: id'), 'does not set id'),
                (CLONE.replace('property: label', 'property: the label'), 'not a property name'),
                (CLONE.replace('property: rect', 'property: label'), 'label is set twice'),
                (CLONE.replace('to: Bee\n', ''), 'the property label of the clone needs to:'),
                (CLONE.replace('property: label\n', ''), 'to: without its property:'),
                (CLONE.replace('to: Bee\n', 'to: Bee\nto: Bea\n'), 'to: without its property:'),
                (CLONE + 'property: width\n', 'the property width of the clone needs to:'),
                (CLONE + 'object: button "C" of card 1\n', 'a clone patch copies one object'),
                (CLONE + 'file: Toolset/y.rev\n', 'a clone patch copies one object'),
                ('file: Toolset/x.rev\nclone: B\nunique-id: 1793989825265\n', 'clone: before object:'),
                ('file: Toolset/x.rev\nobject: button "A" of card 1\nproperty: label\nfrom: a\nto: b\nclone: B\n',
                 'a clone patch is a file of its own'),
                (CLONE + 'from: x\n', 'not a patch line'),
                (CLONE + 'replace:\n|a|\n', 'not a patch line: replace:'),
                (CLONE + 'with:\n|a|\n', 'not a patch line: with:'),
                (CLONE + 'image: x.png\n', 'a patch is a script, a property or an image patch')):
            with self.subTest(says=says, text=text):
                self.refused(text, says)

    def test_other_patches_read_as_before(self):
        self.assertEqual(self.patch('file: Toolset/x.rev\nobject: button "A" of card 1\nproperty: label\n'
                                    'from: a\nto: b\n'),
                         ('property', 'Toolset/x.rev', [('button "A" of card 1', 'label', 'a', 'b')]))
        self.assertEqual(self.patch('file: Toolset/x.rev\nobject: stack\nreplace:\n|on a|\nwith:\n|on b|\n'),
                         ('script', 'Toolset/x.rev', 'stack', b'on a\n', b'on b\n'))

    def test_every_patch_of_the_repository_reads(self):
        kinds = {}
        for name in sorted(os.listdir(PATCHES)):
            if name.endswith('.txt'):
                kind = cis.read_patch(os.path.join(PATCHES, name))[0]
                kinds[kind] = kinds.get(kind, 0) + 1
        self.assertGreaterEqual(kinds.get('clone', 0), 1)
        self.assertGreater(kinds.get('script', 0), 10)


class CheckClonePatches(unittest.TestCase):
    """check_patches finds a clone's name and unique id in its stack file's
    bytes, and says which is missing"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.tmp.name, *cis.PATCH_DIR.split(os.sep)))
        os.makedirs(os.path.join(self.tmp.name, 'ide', 'Toolset'))
        with open(os.path.join(self.tmp.name, cis.PATCH_DIR, 'x-1.txt'), 'w', encoding='utf-8') as f:
            f.write(CLONE)

    def tearDown(self):
        self.tmp.cleanup()

    def check(self, data):
        with open(os.path.join(self.tmp.name, 'ide', 'Toolset', 'x.rev'), 'wb') as f:
            f.write(data)
        failures = []
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cis.check_patches(self.tmp.name, failures)
        return failures, out.getvalue()

    def test_applied(self):
        failures, out = self.check(b'REVO8100\x00\x01B\x00\x0e1793989825265\x00')
        self.assertEqual(failures, [])
        self.assertIn('ok      x-1.txt: B, the copy of button "A" of card 1, is in ide/Toolset/x.rev', out)

    def test_not_applied(self):
        for data, missing in ((b'REVO8100 B', 'the unique id of B, the copy of button "A" of card 1, is not'),
                              (b'REVO8100 1793989825265', 'the name of B, the copy of button "A" of card 1, is not'),
                              (b'REVO8100', 'the name and the unique id of B, the copy of button "A" of card 1, are not')):
            with self.subTest(missing=missing):
                failures, _ = self.check(data)
                self.assertEqual(len(failures), 1)
                self.assertEqual(failures[0][0], 'ide/Toolset/x.rev')
                self.assertIn('x-1.txt is not applied: ' + missing, failures[0][1])
                self.assertIn('run tools/oxt/ide-stack-patch.sh', failures[0][1])

    def test_a_bad_patch_is_a_failure(self):
        with open(os.path.join(self.tmp.name, cis.PATCH_DIR, 'x-1.txt'), 'w', encoding='utf-8') as f:
            f.write(CLONE.replace('1793989825265', '1'))
        failures, _ = self.check(b'B 1793989825265')
        self.assertEqual(len(failures), 1)
        self.assertIn('unique-id: (13 digits', failures[0][1])


class ScriptPatchOfAClone(unittest.TestCase):
    """A script patch of a copy that a clone patch makes (the Card
    Navigator's "Clone Card", "New Card" with one line changed) leaves the
    replaced text in the copy's source: it may stay once for each such
    patch, and not for a patch of an object that is no copy"""

    SCRIPT = ('file: Toolset/x.rev\nobject: button "%s" of card 1\n'
              'replace:\n|   new card|\nwith:\n|   clone this card|\n')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.tmp.name, *cis.PATCH_DIR.split(os.sep)))
        os.makedirs(os.path.join(self.tmp.name, 'ide', 'Toolset'))
        with open(os.path.join(self.tmp.name, cis.PATCH_DIR, 'x-1.txt'), 'w', encoding='utf-8') as f:
            f.write(CLONE)

    def tearDown(self):
        self.tmp.cleanup()

    def check(self, target, data):
        with open(os.path.join(self.tmp.name, cis.PATCH_DIR, 'x-2.txt'), 'w', encoding='utf-8') as f:
            f.write(self.SCRIPT % target)
        with open(os.path.join(self.tmp.name, 'ide', 'Toolset', 'x.rev'), 'wb') as f:
            f.write(data)
        failures = []
        with contextlib.redirect_stdout(io.StringIO()):
            cis.check_patches(self.tmp.name, failures)
        return failures

    def test_the_source_keeps_the_text(self):
        # A ("new card") and its copy B ("clone this card")
        self.assertEqual(self.check('B', b'REVO8100 B 1793989825265 '
                                         b'  new card\n   clone this card\n'), [])

    def test_only_once(self):
        failures = self.check('B', b'REVO8100 B 1793989825265 '
                                   b'\n   new card\n   new card\n   clone this card\n')
        self.assertEqual(len(failures), 1)
        self.assertIn('replaced text 2 time(s)', failures[0][1])

    def test_not_for_an_object_that_is_no_copy(self):
        failures = self.check('A', b'REVO8100 B 1793989825265 '
                                   b'  new card\n   clone this card\n')
        self.assertEqual(len(failures), 1)
        self.assertIn('x-2.txt is not applied to button "A" of card 1', failures[0][1])
        self.assertIn('replaced text 1 time(s)', failures[0][1])

    def test_the_copy_must_be_patched(self):
        failures = self.check('B', b'REVO8100 B 1793989825265   new card\n')
        self.assertEqual(len(failures), 1)
        self.assertIn('replacement found 0 time(s)', failures[0][1])


class AndroidCardBox(unittest.TestCase):
    """The Android card's "Post Notifications" box: the patch makes it in
    the group that stores each box under its name, the builder declares
    that name as android.permission.<name>, and it is the permission the
    Java layer asks for; the groups around it grow to hold it"""

    def test_the_stack_has_it(self):
        failures = []
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cis.check_patches(REPO, failures)
        self.assertEqual(failures, [])
        self.assertIn('ok      %s: POST_NOTIFICATIONS, the copy of button "AD"' % CARD_BOX, out.getvalue())

    def test_it_is_a_permission_box(self):
        _, stack, obj, name, _, props = cis.read_patch(os.path.join(PATCHES, CARD_BOX))
        # a copy of another box of the group "permissions"
        self.assertTrue(obj.startswith('button "AD" of group "permissions" of '), obj)
        # whose mouseUp stores every box by its short name
        group = read(SCRIPTS, 'stack_revStandaloneSettings_group_id_2401.livecodescript')
        self.assertIn('group "permissions" (id 2401)', group)
        for part in ('repeat with i = 1 to the number of buttons of me',
                     'get the short name of button i of me', 'put "true" into tArray[it]',
                     'storeSetting "application permissions", tArray'):
            self.assertIn(part, group)
        # the card sets each box from the stack's settings by its name
        card = read('ide', 'Toolset', 'palettes', 'standalone settings',
                    'revstandalonesettingsandroidbehavior.livecodescript')
        self.assertIn('set the hilite of button i of group "permissions" to '
                      'computeDefault(tSettings["android,application permissions"][it], false)', card)
        # the builder declares every name as android.permission.<name>
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        self.assertIn('repeat for each key tPermission in pSettings["android,application permissions"]', builder)
        self.assertIn('"android.permission."&tPermission&quote', builder)
        # the permission the Java layer asks for, and the one the Java
        # layer's probe declares
        java = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'NotificationModule.java')
        self.assertIn('POST_NOTIFICATIONS = "android.permission.%s";' % name, java)
        probe = read('tools', 'ci', 'android-check.livecodescript')
        self.assertIn('tSettings["android,application permissions"]["%s"]' % name, probe)
        self.assertEqual(dict(props)['label'], 'Post Notifications')
        self.assertEqual(stack, SETTINGS)

    def test_the_docs_name_it(self):
        label = dict(cis.read_patch(os.path.join(PATCHES, CARD_BOX))[5])['label']
        guide = read('ide', 'Documentation', 'guides', 'Deploying Your Application.md')
        rows = [line for line in guide.split('\n') if line.startswith('| **')]
        row = [line for line in rows if line.startswith('| **%s**' % label)]
        self.assertEqual(len(row), 1)
        self.assertIn('Android 13 and newer', row[0])
        # a row of the table as wide as the others, after "Ad Support"
        self.assertEqual(len(row[0]), len([r for r in rows if r.startswith('| **Ad Support**')][0]))
        self.assertEqual(rows.index(row[0]), [i for i, r in enumerate(rows) if r.startswith('| **Ad Support**')][0] + 1)
        entry = read('docs', 'dictionary', 'command', 'mobileCreateLocalNotification.lcdoc')
        self.assertIn('Tick "%s" among the\nApplication Permissions of the Android standalone settings' % label, entry)

    def test_it_lines_up_and_its_groups_hold_it(self):
        box = rect(dict(cis.read_patch(os.path.join(PATCHES, CARD_BOX))[5])['rect'])
        # the right-hand column of the permissions, as the Linux fit patch
        # left "Ad Support" (button id 2854), one row below it
        fit = cis.read_patch(os.path.join(PATCHES, 'standalone-settings-fit-linux.txt'))[2]
        ad = rect([to for obj, prop, _, to in fit if obj == 'button id 2854 of card "Android"' and prop == 'rect'][0])
        self.assertEqual((box[0], box[2]), (ad[0], ad[2]))
        self.assertEqual(box[3] - box[1], ad[3] - ad[1])
        self.assertEqual(box[1], ad[1] + 19)
        # each group's bottom edge is the bottom of what it holds plus its
        # margins of 4; nothing else of a group moves
        _, stack, groups = cis.read_patch(os.path.join(PATCHES, CARD_GROUPS))
        self.assertEqual(stack, SETTINGS)
        self.assertEqual([g[0].split(' of ')[0] for g in groups],
                         ['group "permissions"', 'group "Application Permissions"', 'group "Android Settings"'])
        inner = box[3]
        for obj, prop, old, new in groups:
            self.assertEqual(prop, 'rect')
            old, new = rect(old), rect(new)
            # "Android Settings" is also as wide as the window (754), for
            # the "Target" menu (android-card-target-api-5.txt), as one
            # patch holds each property
            if obj.startswith('group "Android Settings"'):
                self.assertEqual((old[2], new[2]), (740, 754))
                old[2] = new[2]
            self.assertEqual(old[:3], new[:3], obj)
            self.assertEqual(new[3], inner + 4, obj)
            self.assertGreater(new[3], old[3], obj)
            inner = new[3]
        # the box comes first (patches apply in name order)
        self.assertLess(CARD_BOX, CARD_GROUPS)


if __name__ == '__main__':
    unittest.main()
