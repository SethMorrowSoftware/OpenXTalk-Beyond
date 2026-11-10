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


# The CODE lines 0.2.7-rc.6.17's standalone engine logged on Xvfb (Pango
# 1.52, fontconfig 2.15): no font it loaded was listed or measured
CODE_OLD = ['CODE before false,false,30,120,40,120'] + \
    ['CODE %s false,false,30,120,40,120 ' % state for state, _, _ in fontfile_check.CODE_STEPS[1:]]

# A run that loads what it is given: Source Code Pro's advance is 600 of
# 1000 units, so ten of any letter at 13 point are 78 pixels (made up from
# the font, not logged by an engine)
CODE_GOOD = [
    'CODE before false,false,30,120,40,120',
    'CODE regular true,false,78,78,78,78 ',
    'CODE bold true,false,78,78,78,78 ',
    'CODE icons true,true,78,78,78,78 ',
    'CODE no-regular true,true,78,78,78,78 ',
    'CODE no-bold false,true,30,120,40,120 ',
    'CODE after false,false,30,120,40,120 ',
]


def run(rounds=fontfile_check.ROUNDS, widths=None, result='', code=None):
    lines = ['INFO platform=Linux version=9.7.1-BeyondEngine processor=x86_64', 'BASE ' + BASE,
             'INFO font file /x/fontawesome.ttf exists=true']
    for n in range(1, rounds + 1):
        for step in ('LOADED', 'UNLOADED'):
            got = (widths or {}).get((step, n), BASE)
            lines.append(('%s %d %s %s' % (step, n, got, result)).rstrip() if result else '%s %d %s ' % (step, n, got))
    lines.append('INFO code font folder /x/fonts exists=true icons=fontawesome')
    lines += CODE_GOOD if code is None else code
    lines.append('QUIT 12345')
    return lines


def with_code(state, line):
    """The good CODE lines, with the one for state replaced."""
    return [('CODE %s %s' % (state, line)) if x.split(' ')[1] == state else x for x in CODE_GOOD]


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


class TheFontsItLoads(unittest.TestCase):
    """The CODE lines: a font loaded is listed and measures (0.2.7-rc.6.18's
    Linux engine listed and drew none, Source Code Pro included)."""

    def test_the_old_engine_fails(self):
        failed = failures(run(code=CODE_OLD))
        self.assertEqual(failed, [
            'with the code font Regular loaded: Source Code Pro is among the fontNames',
            'with the code font Regular loaded: Source Code Pro is what measures plain text (monospaced)',
            'with the code font Regular and Bold loaded: Source Code Pro is among the fontNames',
            'with the code font Regular and Bold loaded: Source Code Pro is what measures plain text (monospaced)',
            'with the code font Regular and Bold loaded: Source Code Pro is what measures bold text (monospaced)',
            'with the code font Regular and Bold, and the font file loaded: Source Code Pro is among the fontNames',
            "with the code font Regular and Bold, and the font file loaded: the font file's family is among the fontNames",
            'with the code font Regular and Bold, and the font file loaded: '
            'Source Code Pro is what measures plain text (monospaced)',
            'with the code font Regular and Bold, and the font file loaded: '
            'Source Code Pro is what measures bold text (monospaced)',
            'with the code font Bold and the font file loaded: Source Code Pro is among the fontNames',
            "with the code font Bold and the font file loaded: the font file's family is among the fontNames",
            'with the code font Bold and the font file loaded: Source Code Pro is what measures bold text (monospaced)',
            "with the font file loaded: the font file's family is among the fontNames",
        ])

    def test_a_load_that_drops_the_one_before_fails(self):
        # Each load made a configuration of that one file: the icon font
        # loaded after the code font took it away
        failed = failures(run(code=with_code('icons', 'false,true,30,120,40,120 ')))
        self.assertEqual(failed, [
            'with the code font Regular and Bold, and the font file loaded: Source Code Pro is among the fontNames',
            'with the code font Regular and Bold, and the font file loaded: '
            'Source Code Pro is what measures plain text (monospaced)',
            'with the code font Regular and Bold, and the font file loaded: '
            'Source Code Pro is what measures bold text (monospaced)',
        ])

    def test_listed_but_not_measured_fails(self):
        # The engine's font map told, libgraphics' (which draws) not
        failed = failures(run(code=with_code('regular', 'true,false,30,120,40,120 ')))
        self.assertEqual(failed, ['with the code font Regular loaded: '
                                  'Source Code Pro is what measures plain text (monospaced)'])

    def test_an_unload_that_leaves_the_font_fails(self):
        failed = failures(run(code=with_code('no-bold', 'true,true,78,78,78,78 ')))
        self.assertIn('with the font file loaded: Source Code Pro is not among the fontNames', failed)
        self.assertIn('with the font file loaded: the fallback face measures plain text again (proportional)', failed)

    def test_measuring_otherwise_after_fails(self):
        failed = failures(run(code=with_code('after', 'false,false,30,121,40,120 ')))
        self.assertEqual(failed, ['with nothing loaded: Source Code Pro measures as before any was loaded'])

    def test_fonts_installed_on_the_machine_fail(self):
        # Listed before any load, the fonts would pass blind
        failed = failures(run(code=with_code('before', 'true,false,78,78,78,78')))
        self.assertIn('with nothing loaded: Source Code Pro is not among the fontNames', failed)
        self.assertIn('with nothing loaded: the fallback face is proportional (the probe can tell a monospaced one)',
                      failed)
        self.assertIn('installed on this machine', ' '.join(details(run(code=with_code('before', 'true,false,78,78,78,78')))))
        failed = failures(run(code=with_code('before', 'false,true,30,120,40,120')))
        self.assertEqual(failed, ["with nothing loaded: the font file's family is not among the fontNames"])

    def test_a_load_with_an_error_fails(self):
        failed = failures(run(code=with_code('bold', "true,false,78,78,78,78 can't load font file")))
        self.assertEqual(failed, ['with the code font Regular and Bold loaded: the font file loaded without an error'])

    def test_a_missing_or_unreadable_line_fails(self):
        failed = failures(run(code=[x for x in CODE_GOOD if not x.startswith('CODE no-regular ')]))
        self.assertEqual(failed, ['with the code font Bold and the font file loaded: listed and measured'])
        failed = failures(run(code=with_code('regular', 'true,false,78,78 ')))
        self.assertEqual(failed, ['with the code font Regular loaded: listed and measured'])

    def test_parse_code(self):
        self.assertEqual(fontfile_check.parse_code("true,false,1,2,3,4 can't load font file"),
                         (True, False, (1, 2), (3, 4), "can't load font file"))
        self.assertEqual(fontfile_check.parse_code('false,true,1,2,3,4'), (False, True, (1, 2), (3, 4), ''))
        self.assertIsNone(fontfile_check.parse_code('yes,false,1,2,3,4'))
        self.assertIsNone(fontfile_check.parse_code('true,false,1,2,3,x'))


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
        for name in fontfile_check.CODE_FILES:
            self.assertTrue(os.path.isfile(os.path.join(fontfile_check.FONTS_DIR, name)), name)

    def test_the_code_steps_agree(self):
        self.assertEqual(tuple(self.constant('kCodeFiles').split(',')), fontfile_check.CODE_FILES)
        self.assertEqual(self.constant('kCodeFont'), 'Source Code Pro')
        steps = re.findall(r'^\s*codeStep "([^"]+)", "(load|unload)", (\S+)', self.script, re.M)
        self.assertEqual([(state, action) for state, action, _ in steps],
                         [(state, action) for state, action, _ in fontfile_check.CODE_STEPS[1:]])
        # Regular, Bold, then the icon font; unloaded in the same order
        self.assertEqual([what for _, _, what in steps], [
            'tCode', 'tCode', 'tFile,', 'tCode', 'tCode', 'tFile,'])
        self.assertIn('codeStep "regular", "load", tCode & slash & item 1 of kCodeFiles', self.script)
        self.assertIn('codeStep "no-bold", "unload", tCode & slash & item 2 of kCodeFiles', self.script)
        self.assertIn('logLine "CODE before" && codeProbe(tIcons)', self.script)
        # after the rounds, which must measure as they always did
        self.assertGreater(self.script.index('codeStep "regular"'), self.script.index('"UNLOADED" && tRound'))
        # ten i and ten M, plain and bold
        self.assertIn('"iiiiiiiiii" & return & "MMMMMMMMMM"', self.script)
        probe = self.script[self.script.index('function codeProbe'):self.script.index('end codeProbe')]
        self.assertIn('repeat for each item tStyle in "plain,bold"', probe)
        self.assertIn('put the fontNames into tFonts', probe)
        # the result of the load, read before anything else sets it
        step = self.script[self.script.index('command codeStep'):self.script.index('end codeStep')]
        self.assertLess(step.index('put the result into tResult'), step.index('codeProbe(pIcons)'))

    def test_the_python_passes_the_folder_and_family(self):
        with open(os.path.join(CI, 'fontfile_check.py'), encoding='utf-8') as f:
            src = f.read()
        self.assertIn("'OXT_FONTFILE_CODE': os.path.abspath(args.code_fonts)", src)
        self.assertIn("'OXT_FONTFILE_ICONS': args.font_family", src)
        self.assertIn('put $OXT_FONTFILE_CODE into tCode', self.script)
        self.assertIn('put $OXT_FONTFILE_ICONS into tIcons', self.script)


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


class TheLinuxFonts(unittest.TestCase):
    """What the CODE lines measure on the built engine, held in the source
    too: every load keeps the fonts loaded before it, and both of Pango's
    font maps (the engine's, which lists, and libgraphics', which measures
    and draws) take the configuration the load makes current."""

    def setUp(self):
        with open(os.path.join(REPO, 'engine', 'src', 'lnxdc.cpp'), encoding='utf-8') as f:
            self.dc = f.read()
        with open(os.path.join(REPO, 'libgraphics', 'src', 'lnxtext.cpp'), encoding='utf-8') as f:
            self.text = f.read()

    def body(self, src, head):
        start = src.index(head)
        return src[start:src.index('\n}\n', start)]

    def test_load_and_unload_make_one_configuration(self):
        load = self.body(self.dc, 'bool MCScreenDC::loadfont(')
        self.assertIn('MCLinuxFontConfigLoad(p_path, nil)', load)
        unload = self.body(self.dc, 'bool MCScreenDC::unloadfont(')
        self.assertIn('return MCLinuxFontConfigLoad(nil, p_path);', unload)
        # nothing else makes a configuration of its own
        self.assertEqual(self.dc.count('FcInitLoadConfigAndFonts()'), 1)

    def test_the_configuration_keeps_every_loaded_font(self):
        build = self.body(self.dc, 'static bool MCLinuxFontConfigLoad(')
        self.assertIn('MCFontListLoaded(t_count, t_loaded)', build)
        # the one unloading is left out, the one loading must load
        self.assertIn('MCStringIsEqualTo(t_files[i], p_removing, kMCStringOptionCompareCaseless)', build)
        adding = build[build.index('if (p_adding != nil)'):]
        self.assertIn('if (FcFalse == FcConfigAppFontAddFile(t_config, (FcChar8*)*t_file))\n            return false;',
                      adding)
        self.assertLess(build.index('FcConfigSetCurrent(t_config)'), build.index('FcConfigBuildFonts(t_config)'))
        # then the engine's font map (the fontNames) takes it
        self.assertLess(build.index('FcConfigBuildFonts(t_config)'), build.index('pango_cairo_font_map_get_default()'))
        self.assertIn('pango_fc_font_map_set_config_ptr((PangoFcFontMap *)t_font_map, t_config);', build)
        self.assertIn('if (pango_fc_font_map_set_config_ptr != nil)', build)

    def test_libgraphics_follows_the_current_configuration(self):
        follow = self.body(self.text, 'static void lnx_pango_follow_font_config(void)')
        self.assertIn('t_current = FcConfigGetCurrent();', follow)
        self.assertIn('t_current == s_font_config', follow)
        self.assertIn('pango_fc_font_map_set_config_ptr((PangoFcFontMap *) s_font_map, t_current);', follow)
        # before it draws, measures or measures the image bounds
        for head in ('void MCGContextDrawPlatformText(', 'MCGFloat __MCGContextMeasurePlatformText(',
                     'bool MCGContextMeasurePlatformTextImageBounds('):
            body = self.body(self.text, head)
            self.assertIn('lnx_pango_follow_font_config();', body, head)
            self.assertLess(body.index('lnx_pango_follow_font_config();'), body.index('pango_layout_set_text'), head)

    def test_set_config_is_weak_linked_as_optional(self):
        # Pango 1.38's: an older Pango must still start the engine
        with open(os.path.join(REPO, 'engine', 'src', 'linux.stubs'), encoding='utf-8') as f:
            stubs = f.read()
        module = stubs[stubs.index('pangoft2 libpangoft2-1.0.so.0'):]
        module = module[:module.index('\n\n')]
        self.assertIn('\t? pango_fc_font_map_set_config: (pointer, pointer) -> ()', module)


class TheMeasureCache(unittest.TestCase):
    """libgraphics/src/cachetable.cpp compiled as it is and run: emptied, the
    table must take and give back new widths. Until MCDispatch::flushfonts
    nothing called MCGCacheTableCompact, which counted every bucket it
    passed, empty or not, as one fewer in use: the count wrapped, and the
    next width put in the table looked for ever for a pair to discard. The
    web IDE hung as it opened, on the first font file it loaded."""

    # What cachetable.cpp takes from libfoundation, as plain C; its own
    # declarations come from graphics-internal.h, so the test follows them
    FOUNDATION = r'''
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
typedef uint32_t uindex_t;
typedef uint32_t hash_t;
#define MCAssert(x) assert(x)
template <typename T> inline bool MCMemoryNew(T *&r) { r = (T *) calloc(1, sizeof(T)); return r != NULL; }
template <typename T> inline bool MCMemoryNewArray(uindex_t n, T *&r) { r = (T *) calloc(n, sizeof(T)); return r != NULL; }
inline void MCMemoryDelete(void *p) { free(p); }
inline void MCMemoryDeleteArray(void *p) { free(p); }
inline bool MCMemoryEqual(const void *a, const void *b, size_t n) { return memcmp(a, b, n) == 0; }
inline void MCMemoryCopy(void *d, const void *s, size_t n) { memcpy(d, s, n); }
'''

    # The sizes context.cpp gives the text measure cache (the desktop's)
    HARNESS = r'''
#include <cstdio>
#include "graphics-internal.h"

static void *key(unsigned n) { unsigned *k = (unsigned *) malloc(sizeof n); *k = n; return k; }

static bool put(MCGCacheTableRef t, unsigned n, float w)
{
	MCGCacheTableSet(t, key(n), sizeof n, &w, sizeof w);
	float *got = (float *) MCGCacheTableGet(t, &n, sizeof n);
	return got != NULL && *got == w;
}

int main(void)
{
	MCGCacheTableRef t = NULL;
	if (!MCGCacheTableCreate(16384, 8192, 16384 * 256, t)) { puts("no table"); return 1; }
	for (unsigned n = 1; n <= 100; n++)
		if (!put(t, n, n)) { printf("width %u not kept\n", n); return 1; }
	MCGCacheTableCompact(t);
	for (unsigned n = 1; n <= 100; n++)
		if (MCGCacheTableGet(t, &n, sizeof n) != NULL) { printf("width %u kept after emptying\n", n); return 1; }
	puts("emptied");
	fflush(stdout);
	// More than the table holds, so it discards pairs of its own, then
	// emptied twice over
	for (unsigned n = 1; n <= 20000; n++)
		put(t, n, n + 0.5f);
	MCGCacheTableCompact(t);
	MCGCacheTableCompact(t);
	if (!put(t, 7, 3.25f)) { puts("width lost after emptying a full table"); return 1; }
	unsigned m = 8;
	if (MCGCacheTableGet(t, &m, sizeof m) != NULL) { puts("width kept after emptying a full table"); return 1; }
	MCGCacheTableDestroy(t);
	puts("OK");
	return 0;
}
'''

    def test_emptied_it_takes_new_widths(self):
        import shutil
        import subprocess
        import tempfile
        cxx = shutil.which('c++') or shutil.which('g++') or shutil.which('clang++')
        if not cxx:
            self.skipTest('no C++ compiler')
        src = os.path.join(REPO, 'libgraphics', 'src')
        with open(os.path.join(src, 'graphics-internal.h'), encoding='utf-8') as f:
            internal = f.read()
        start = internal.index('typedef struct __MCGCacheTable *MCGCacheTableRef;')
        decls = internal[start:internal.index('\n', internal.index('MCGCacheTableGet(', start))]
        with tempfile.TemporaryDirectory() as work:
            # The copy, so that its #include "graphics-internal.h" finds
            # this one and not libgraphics' own (Skia's headers)
            shutil.copy(os.path.join(src, 'cachetable.cpp'), work)
            with open(os.path.join(work, 'graphics.h'), 'w') as f:
                f.write('')
            with open(os.path.join(work, 'graphics-internal.h'), 'w') as f:
                f.write(self.FOUNDATION + decls + '\n')
            with open(os.path.join(work, 'harness.cpp'), 'w') as f:
                f.write(self.HARNESS)
            exe = os.path.join(work, 'harness.exe' if os.name == 'nt' else 'harness')
            built = subprocess.run([cxx, '-std=c++11', '-O1', '-w', '-I', work, '-o', exe,
                                    os.path.join(work, 'cachetable.cpp'), os.path.join(work, 'harness.cpp')],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            self.assertEqual(built.returncode, 0, built.stdout.decode('utf-8', 'replace'))
            try:
                ran = subprocess.run([exe], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            except subprocess.TimeoutExpired as e:
                self.fail('the table never returned after it was emptied (%s)'
                          % (e.stdout or b'').decode('utf-8', 'replace').strip())
            out = ran.stdout.decode('utf-8', 'replace')
            self.assertEqual((ran.returncode, out.split()[-1:]), (0, ['OK']), out)


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
