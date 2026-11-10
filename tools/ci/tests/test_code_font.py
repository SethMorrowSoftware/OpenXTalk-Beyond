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

"""The IDE's code font, Source Code Pro, and the fonts a stack loads.

The IDE loads every font file in its fonts folder as it starts, and the
Script Editor shows code in Source Code Pro when it is among the
fontNames. Up to 0.2.7-rc.6.18:

  - on Windows the collection of loaded fonts could be an old one.
    DirectWrite keeps each custom collection under the bytes of its key,
    which was the address of the list of font files; each load or unload
    makes a new list and frees the old, so a new list at a freed one's
    address was given that list's collection
    (libgraphics/src/directwrite-skia.cpp). The key now carries a serial;
  - on Linux no font a stack loaded was listed or drawn (engine/src/lnxdc.cpp
    and libgraphics/src/lnxtext.cpp; tools/ci/tests/test_fontfile_check.py
    holds that source, and tools/ci/fontfile_check.py measures it).

The IDE tour's code-font step (tools/ci/ui-tour.livecodescript) measures
both on every platform's build: Source Code Pro among the fontNames and
measuring as a monospaced face, then two font files of the repository
loaded and unloaded three times over, each adding its family and taking it
away, and every other font staying. This test reads the source, so that
every platform's checks hold the step and the Windows key.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import ui_tour  # noqa: E402


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class TheTourStep(unittest.TestCase):

    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')
        self.step = self.tour[self.tour.index('\non tour_code_font\n'):self.tour.index('\nend tour_code_font\n')]

    def handler(self, kind, name):
        start = self.tour.index('\n%s %s' % (kind, name))
        return self.tour[start:self.tour.index('\nend %s\n' % name, start)]

    def test_it_is_a_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('code-font', steps)
        # late, before the check of the IDE's own stacks
        # (test_ui_tour.IDEStacks) and the last screen shot; the background
        # step stays last
        self.assertEqual(steps[-4:], ['code-font', 'ide-stacks', 'screen-end', 'background-default'])

    def test_source_code_pro_is_listed_and_measures(self):
        self.assertIn('if "Source Code Pro" is not among the lines of the fontNames then', self.step)
        self.assertIn("throw \"Source Code Pro, the IDE's code font, is not among the fontNames\"", self.step)
        # measured as the IDE starts, and again after the loads
        self.assertIn('tourCodeMeasure "as the IDE starts"', self.step)
        self.assertIn('tourCodeMeasure "after the font files were loaded and unloaded three times"', self.step)
        self.assertLess(self.step.index('tourCodeMeasure "as the IDE starts"'), self.step.index('start using font file'))
        self.assertGreater(self.step.index('tourCodeMeasure "after'), self.step.rindex('stop using font file'))
        measure = self.handler('command', 'tourCodeMeasure')
        self.assertIn('tourCodeWidths("Source Code Pro", "plain")', measure)
        self.assertIn('tourCodeWidths("Source Code Pro", "bold")', measure)
        # the probe can tell: the fallback face is not monospaced
        self.assertIn('tourCodeWidths(kCodeFontNone, "plain")', measure)
        self.assertIn('if item 1 of tNone is item 2 of tNone then', measure)
        self.assertIn('if item 1 of tPlain is not item 2 of tPlain or item 1 of tBold is not item 2 of tBold then',
                      measure)
        self.assertIn('set the text of it to "iiiiiiiiii" & return & "MMMMMMMMMM"', self.step)
        widths = self.handler('function', 'tourCodeWidths')
        self.assertIn('the formattedWidth of line 1 of field "Code" of stack kCodeFontStack', widths)
        self.assertIn('the formattedWidth of line 2 of field "Code" of stack kCodeFontStack', widths)

    def test_loads_and_unloads_keep_the_fonts_listed(self):
        self.assertIn('put $OXT_TOUR_FONT_FILES into tFiles', self.step)
        self.assertIn('repeat with tRound = 1 to 3', self.step)
        load = self.step[self.step.index('start using font file tFile'):self.step.index('stop using font file tFile')]
        # each load takes nothing away and adds a family
        self.assertIn('put tourCodeAdded(tNow, tBefore) into tGone', load)
        self.assertIn('put tourCodeAdded(tBefore, tNow) into tFamily[tIndex]', load)
        self.assertIn('loaded and added no family to the fontNames', load)
        unload = self.step[self.step.index('stop using font file tFile'):]
        # each unload takes away its own family and nothing else, adds none
        self.assertIn('if tGone is not tFamily[tIndex] then', unload)
        self.assertIn('if tourCodeAdded(tBefore, tNow) is not empty then', unload)
        self.assertIn('Source Code Pro is no longer among the fontNames', self.step)
        self.assertIn('throw "the fonts loaded are not the fonts listed:"', self.step)
        added = self.handler('function', 'tourCodeAdded')
        self.assertIn('if tLine is not among the lines of pBefore then', added)
        # the stack goes, failed or not
        self.assertEqual(self.step.count('delete stack kCodeFontStack'), 3)
        self.assertIn('tourShotStack kCodeFontStack, "98-code-font"', self.step)

    def test_declared_before_use(self):
        self.assertLess(self.tour.index('constant kCodeFontStack'), self.tour.index('function tourCodeWidths'))
        self.assertLess(self.tour.index('constant kCodeFontNone'), self.tour.index('command tourCodeMeasure'))

    def test_the_tour_is_given_two_font_files(self):
        self.assertEqual(len(ui_tour.TOUR_FONT_FILES), 2)
        for path in ui_tour.TOUR_FONT_FILES:
            self.assertTrue(os.path.isfile(path), path)
            self.assertTrue(path.endswith('.ttf'), path)
        src = read('tools', 'ci', 'ui_tour.py')
        self.assertIn("'OXT_TOUR_FONT_FILES': '|'.join(", src)
        self.assertIn('replace "|" with return in tFiles', self.step)

    def test_every_sparse_checkout_that_runs_the_tour_has_the_font_files(self):
        # #420's Mac test jobs checked out tools/ and not the IDE's
        # html_viewer fonts, so the step failed with "no font file at"
        repo = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
        files = [os.path.relpath(os.path.normpath(f), repo).replace(os.sep, '/') for f in ui_tour.TOUR_FONT_FILES]
        seen = 0
        workflows = os.path.join(repo, '.github', 'workflows')
        for name in sorted(os.listdir(workflows)):
            if not name.endswith('.yml'):
                continue
            with open(os.path.join(workflows, name), encoding='utf-8') as f:
                text = f.read()
            # each job: the text from one "runs-on:" to the next
            for job in re.split(r'\n    runs-on:', text)[1:]:
                if 'tools/ci/ui_tour.py' not in job or 'sparse-checkout: |' not in job:
                    continue
                block = job.split('sparse-checkout: |', 1)[1].split('\n\n', 1)[0]
                entries = [line.strip() for line in block.splitlines() if line.strip()]
                for rel in files:
                    self.assertTrue(any(rel == e or rel.startswith(e.rstrip('/') + '/') for e in entries),
                                    '%s: a job runs ui_tour.py with a sparse checkout of %s, without %s'
                                    % (name, ', '.join(entries), rel))
                seen += 1
        # the Mac test job (both architectures) and the macOS 26 tour
        self.assertGreaterEqual(seen, 2)


class TheWindowsCollectionKey(unittest.TestCase):

    def setUp(self):
        self.src = read('libgraphics', 'src', 'directwrite-skia.cpp')

    def test_every_key_is_new(self):
        self.assertIn('struct MCGDWFontCollectionKey\n{\n\tuint64_t serial;\n\tMCProperListRef files;\n};', self.src)
        start = self.src.index('bool MCGDWSetFontFiles(MCProperListRef p_files)')
        body = self.src[start:self.src.index('\n}\n', start)]
        self.assertIn('MCMemoryClear(&t_key, sizeof(t_key));', body)
        self.assertIn('t_key.serial = ++s_collection_serial;', body)
        self.assertIn('CreateCustomFontCollection(s_DWFontCollectionLoader, &t_key, sizeof(t_key), &t_new_collection)',
                      body)
        # never the address of the list alone
        self.assertNotIn('&p_files, sizeof(MCProperListRef)', self.src)

    def test_the_loader_reads_the_key(self):
        start = self.src.index('STDMETHODIMP MCGDWFontCollectionLoader::CreateEnumeratorFromKey(')
        body = self.src[start:self.src.index('\n}\n', start)]
        self.assertIn('collectionKeySize != sizeof(MCGDWFontCollectionKey)', body)
        self.assertIn('return E_INVALIDARG;', body)
        self.assertIn('static_cast<MCGDWFontCollectionKey const*>(collectionKey)->files', body)


if __name__ == '__main__':
    unittest.main()
