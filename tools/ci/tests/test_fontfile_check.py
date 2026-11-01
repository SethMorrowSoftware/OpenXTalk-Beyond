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

"""tools/ci/fontfile_check.py: what passes and what fails, from the lines
the engine logs; that the check script, the Python and the workflow agree;
and that the engine empties its text measure cache when it frees its fonts.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import fontfile_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))

# The widths 0.2.7-rc.6.11's standalone engine measured on Xvfb with the
# DejaVu fonts (DejaVu Sans, Serif and Sans Mono; plain, bold and italic;
# 11, 13 and 16)
BASE = '340,405,495,390,460,564,340,405,495,350,409,503,385,456,565,350,409,503,427,488,610,427,488,610,427,488,610'


def run(rounds=fontfile_check.ROUNDS, widths=None, result=''):
    lines = ['INFO platform=Linux version=9.7.1-BeyondEngine processor=x86_64', 'BASE ' + BASE,
             'INFO font file /x/fontawesome.ttf exists=true']
    for n in range(1, rounds + 1):
        for step in ('LOADED', 'UNLOADED'):
            got = (widths or {}).get((step, n), BASE)
            lines.append(('%s %d %s %s' % (step, n, got, result)).rstrip() if result else '%s %d %s ' % (step, n, got))
    lines.append('QUIT 12345')
    return lines


def failures(result):
    return [name for name, ok, _ in fontfile_check.evaluate(result) if not ok]


def details(result):
    return [detail for _, ok, detail in fontfile_check.evaluate(result) if not ok]


class Evaluate(unittest.TestCase):
    def test_a_good_run_passes(self):
        self.assertEqual(failures(run()), [])

    def test_the_old_engine_fails(self):
        # Round 3 as 0.2.7-rc.6.11 measured it: DejaVu Sans plain 16 found
        # DejaVu Sans Mono's width, and bold 16 DejaVu Serif's
        stale = BASE.split(',')
        stale[2], stale[5] = '610', '503'
        result = run(widths={('LOADED', 3): ','.join(stale)})
        self.assertEqual(failures(result), ['round 3, the font file loaded: every width as before'])
        self.assertEqual(details(result), [
            '2 of 27 differ: DejaVu Sans plain 16: 495 -> 610; DejaVu Sans bold 16: 564 -> 503'])

    def test_an_unload_that_measures_differently_fails(self):
        stale = BASE.split(',')
        stale[0] = '350'
        result = run(widths={('UNLOADED', 9): ','.join(stale)})
        self.assertEqual(failures(result), ['round 9, the font file unloaded: every width as before'])

    def test_a_font_file_that_does_not_load_fails(self):
        # The engine loads its fonts again only when the file loads: a check
        # whose file never loaded proves nothing
        failed = failures(run(result="can't load font file"))
        self.assertIn('round 1, the font file loaded without an error', failed)
        self.assertIn('round 10, the font file unloaded without an error', failed)

    def test_one_fallback_font_for_all_fails(self):
        # No DejaVu fonts: every family is one fallback, plain and bold alike
        flat = ','.join(['400'] * 27)
        result = [x.replace(BASE, flat) for x in run()]
        self.assertEqual(failures(result), ['the plain and bold fonts measure apart (the DejaVu fonts are there)'])

    def test_a_monospaced_bold_as_wide_as_plain_passes(self):
        # DejaVu Sans Mono keeps its advance in bold, as monospaced fonts do
        self.assertEqual(BASE.split(',')[18:21], BASE.split(',')[21:24])
        self.assertEqual(failures(run()), [])

    def test_a_missing_round_fails(self):
        result = [x for x in run() if not x.startswith('UNLOADED 10 ')]
        self.assertEqual(failures(result), ['round 10, the font file unloaded: measured'])

    def test_fewer_rounds_fail(self):
        failed = failures(run(rounds=fontfile_check.ROUNDS - 1))
        self.assertIn('round %d, the font file loaded: measured' % fontfile_check.ROUNDS, failed)

    def test_widths_that_do_not_parse_fail(self):
        result = [x.replace(BASE, BASE + ',1') if x.startswith('LOADED 2 ') else x for x in run()]
        self.assertEqual(failures(result), ['round 2, the font file loaded: every width as before'])

    def test_an_error_fails(self):
        result = run()[:2] + ['ERROR 219,0,0: font file error', 'QUIT 1']
        failed = failures(result)
        self.assertIn('the script ran without an error', failed)
        self.assertIn('round 1, the font file loaded: measured', failed)

    def test_no_output_fails(self):
        failed = failures([])
        self.assertIn('the line was measured before any font file', failed)
        self.assertIn('the engine quit when it was done', failed)


class TheScript(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(CI, 'fontfile-check.livecodescript'), encoding='utf-8') as f:
            self.script = f.read()

    def constant(self, name):
        m = re.search(r'^constant %s = (.+)$' % name, self.script, re.M)
        self.assertIsNotNone(m, name)
        return m.group(1).strip().strip('"')

    def test_the_script_and_the_python_agree(self):
        self.assertEqual(int(self.constant('kRounds')), fontfile_check.ROUNDS)
        self.assertEqual(tuple(self.constant('kFonts').split(',')), fontfile_check.FONTS)
        self.assertEqual(tuple(self.constant('kStyles').split(',')), fontfile_check.STYLES)
        self.assertEqual(tuple(self.constant('kSizes').split(',')), fontfile_check.SIZES)
        self.assertEqual(len(fontfile_check.labels()), len(BASE.split(',')))

    def test_it_loads_and_unloads_each_round(self):
        loop = self.script[self.script.index('repeat with tRound'):]
        loop = loop[:loop.index('end repeat')]
        self.assertLess(loop.index('start using font file tFile'), loop.index('"LOADED"'))
        self.assertLess(loop.index('"LOADED"'), loop.index('stop using font file tFile'))
        self.assertLess(loop.index('stop using font file tFile'), loop.index('"UNLOADED"'))

    def test_the_font_file_is_in_the_repository(self):
        self.assertTrue(os.path.isfile(fontfile_check.FONT), fontfile_check.FONT)


class TheEngine(unittest.TestCase):
    def test_freeing_the_fonts_empties_the_measure_cache(self):
        # The cache keeps each width under the font's handle, which the next
        # font may be given once the old one is freed
        with open(os.path.join(REPO, 'engine', 'src', 'dispatch.cpp'), encoding='utf-8') as f:
            src = f.read()
        body = src[src.index('void MCDispatch::flushfonts(void)'):]
        body = body[:body.index('\n}\n')]
        self.assertLess(body.index('delete fonts;'), body.index('MCGraphicsCompact();'))
        with open(os.path.join(REPO, 'libgraphics', 'src', 'utils.cpp'), encoding='utf-8') as f:
            utils = f.read()
        compact = utils[utils.index('void MCGraphicsCompact(void)'):]
        self.assertIn('MCGTextMeasureCacheCompact();', compact[:compact.index('}')])

    def test_remapping_frees_the_fonts_through_flushfonts(self):
        with open(os.path.join(REPO, 'engine', 'src', 'font.cpp'), encoding='utf-8') as f:
            src = f.read()
        body = src[src.index('void MCFontRemap(void)'):]
        body = body[:body.index('\n}\n')]
        self.assertIn('MCdispatcher -> flushfonts();', body)
        self.assertLess(body.index('flushfonts'), body.index('loadfont'))


class TheWorkflow(unittest.TestCase):
    def test_the_linux_package_job_runs_it(self):
        with open(os.path.join(REPO, '.github', 'workflows', 'build-linux.yml'), encoding='utf-8') as f:
            wf = f.read()
        step = wf[wf.index('- name: Font file check'):]
        step = step[:step.index('\n      - name:')] if '\n      - name:' in step else step
        self.assertIn('timeout-minutes:', step)
        self.assertIn("env.OXT_ROOT != ''", step)
        self.assertIn('tools/ci/fontfile_check.py --engine "$OXT_ROOT/Runtime/Linux/$folder/Standalone"', step)
        # It needs Xvfb and the DejaVu fonts, which the job installs
        self.assertIn('fonts-dejavu-core', wf)
        self.assertIn(' xvfb ', wf)


if __name__ == '__main__':
    unittest.main()
