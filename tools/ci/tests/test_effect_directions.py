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

"""The visual effects that move one way (wipe, push, reveal and scroll), given
no direction or one that is not a side: the forum's report on 0.2.8-dp.1
(richmond62, 2026-11-19) that wipe, reveal, push and scroll crash the IDE.

Their steps in engine/src/stacke.cpp switch on the direction with an
unreachable default, which a release build compiles as __builtin_unreachable.
"visual effect wipe" alone reached it: clang's code (macOS, iOS, Android, the
web) jumped off and the engine crashed, and GCC's (Linux) fell into a case.
The steps now take a side first (effectside): the one GCC's code played, so
Linux plays these as before and every build plays them the same way.

These tests take the four steps and effectside out of stacke.cpp as they are,
with the Visual_effects enum of parsedef.h, compile them with a stand-in
surface that prints what each step draws, with the unreachable default made a
trap (so that any compiler stops there, not only clang), and run them with
every direction the parser gives.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
STACKE = os.path.join(ROOT, 'engine', 'src', 'stacke.cpp')
PARSEDEF = os.path.join(ROOT, 'engine', 'src', 'parsedef.h')

STEPS = ('pusheffect_step', 'revealeffect_step', 'scrolleffect_step', 'wipeeffect_step')

# what the parser takes as a direction (engine/src/visual.cpp,
# MCVisualEffect::parse), and none
DIRECTIONS = ('VE_UNDEFINED', 'VE_CLOSE', 'VE_OPEN', 'VE_IN', 'VE_OUT', 'VE_DOWN', 'VE_LEFT',
              'VE_RIGHT', 'VE_UP', 'VE_BOTTOM', 'VE_CENTER', 'VE_TOP')
SIDES = ('VE_DOWN', 'VE_LEFT', 'VE_RIGHT', 'VE_UP')

# the side each step plays for a direction that is not one: what the GCC
# build of Linux played (none, close, open, in and out come before the sides
# in Visual_effects; bottom, center and top after them)
NOT_A_SIDE = {
    'pusheffect_step': ('VE_DOWN', 'VE_UP'),
    'revealeffect_step': ('VE_DOWN', 'VE_UP'),
    'scrolleffect_step': ('VE_LEFT', 'VE_UP'),
    'wipeeffect_step': ('VE_DOWN', 'VE_UP'),
}
AFTER_THE_SIDES = ('VE_BOTTOM', 'VE_CENTER', 'VE_TOP')

PRELUDE = r'''
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
typedef float MCGFloat;
typedef uint32_t uint4;
typedef uint16_t uint2;
typedef int16_t int2;
typedef int Boolean;
enum { False, True };
%(enum)s
struct MCRectangle { int16_t x, y; uint16_t width, height; };
struct MCGPoint { MCGFloat x, y; };
struct MCGSize { MCGFloat width, height; };
struct MCGRectangle { MCGPoint origin; MCGSize size; };
typedef const void *MCGImageRef;
enum { kMCGBlendModeCopy };
static inline MCGRectangle MCGRectangleMake(MCGFloat x, MCGFloat y, MCGFloat w, MCGFloat h)
{ MCGRectangle r; r.origin.x = x; r.origin.y = y; r.size.width = w; r.size.height = h; return r; }
static inline MCGRectangle MCGRectangleTranslate(MCGRectangle r, MCGFloat dx, MCGFloat dy)
{ r.origin.x += dx; r.origin.y += dy; return r; }
static inline MCGRectangle MCRectangleToMCGRectangle(const MCRectangle &r)
{ return MCGRectangleMake(r.x, r.y, r.width, r.height); }
static const char kStart[] = "start", kEnd[] = "end";
struct MCStackSurface
{
	__attribute__((noinline)) void Composite(MCGRectangle d, MCGImageRef p_image, MCGRectangle s, float, int)
	{
		printf(" %%s %%g,%%g,%%g,%%g from %%g,%%g,%%g,%%g", (const char *)p_image,
			d.origin.x, d.origin.y, d.size.width, d.size.height,
			s.origin.x, s.origin.y, s.size.width, s.size.height);
	}
};
#define MCUnreachable() __builtin_trap()
'''

MAIN = r'''
typedef Boolean (*Step)(const MCRectangle &, MCStackSurface *, MCGImageRef, MCGImageRef, Visual_effects, uint4, uint4);
int main(int argc, char **argv)
{
	static const Step kSteps[] = { %(steps)s };
	static const char *kStepNames[] = { %(step_names)s };
	static const Visual_effects kDirections[] = { %(directions)s };
	static const char *kDirectionNames[] = { %(direction_names)s };
	MCStackSurface t_surface;
	MCRectangle t_rect = { 10, 20, 400, 300 };
	for (size_t i = 0; i < sizeof(kSteps) / sizeof(kSteps[0]); i++)
		for (size_t j = 0; j < sizeof(kDirections) / sizeof(kDirections[0]); j++)
			for (uint4 t_delta = 0; t_delta <= 100; t_delta += 25)
			{
				printf("%%s %%s %%u:", kStepNames[i], kDirectionNames[j], t_delta);
				fflush(stdout);
				kSteps[i](t_rect, &t_surface, kStart, kEnd, kDirections[j], t_delta, 100);
				printf("\n");
				fflush(stdout);
			}
	printf("DONE\n");
	return 0;
}
'''


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def function(text, name, kind='Boolean'):
    """A function's definition, from its first line to its closing brace."""
    # the definition, not the declarations at the top of the file
    m = re.search(r'^(?:static )?%s %s\([^;{]*\)\n\{.*?^\}\n' % (kind, name), text, re.S | re.M)
    return m.group(0) if m else None


def compilers():
    """The C++ compilers here, clang first (whose code crashed)."""
    found = []
    for name in ('clang++', 'g++', 'c++'):
        path = shutil.which(name)
        if path and os.path.realpath(path) not in [os.path.realpath(p) for p in found]:
            found.append(path)
    return found


def build_and_run(compiler, source, folder):
    """Compile the steps at -O2 and run them: (exit status, output)."""
    src = os.path.join(folder, 'steps.cpp')
    exe = os.path.join(folder, 'steps')
    with open(src, 'w', encoding='utf-8') as f:
        f.write(source)
    built = subprocess.run([compiler, '-O2', '-w', '-o', exe, src], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=300)
    if built.returncode != 0:
        raise AssertionError('%s could not compile the steps:\n%s' % (compiler, built.stdout.decode('utf-8', 'replace')))
    ran = subprocess.run([exe], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    return ran.returncode, ran.stdout.decode('utf-8', 'replace')


def steps_source():
    text = read(STACKE)
    enum = re.search(r'^enum Visual_effects \{.*?^\};\n', read(PARSEDEF), re.S | re.M)
    if enum is None:
        raise AssertionError('no enum Visual_effects in parsedef.h')
    parts = [PRELUDE % {'enum': enum.group(0)}]
    side = function(text, 'effectside', 'Visual_effects')
    if side:
        parts.append(side)
    for name in STEPS:
        body = function(text, name)
        if body is None:
            raise AssertionError('no %s in stacke.cpp' % name)
        parts.append('__attribute__((noinline)) ' + body)
    parts.append(MAIN % {
        'steps': ', '.join(STEPS),
        'step_names': ', '.join('"%s"' % s for s in STEPS),
        'directions': ', '.join(DIRECTIONS),
        'direction_names': ', '.join('"%s"' % d for d in DIRECTIONS),
    })
    return '\n'.join(parts)


def drawn(output):
    """{(step, direction, delta): what it drew}"""
    out = {}
    for line in output.splitlines():
        head, sep, rest = line.partition(':')
        fields = head.split()
        if sep and len(fields) == 3:
            out[tuple(fields)] = rest.strip()
    return out


@unittest.skipIf(os.name == 'nt', "the engine's Windows build is MSVC's: these run the steps as clang and GCC "
                 "build them, in the Linux and macOS checks")
class EveryDirection(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.source = steps_source()
        cls.runs = {}
        found = compilers()
        if not found:
            raise AssertionError('no C++ compiler (clang++, g++ or c++) on the PATH')
        for compiler in found:
            folder = tempfile.mkdtemp(prefix='oxt-effect-steps-')
            try:
                cls.runs[compiler] = build_and_run(compiler, cls.source, folder)
            finally:
                shutil.rmtree(folder, ignore_errors=True)

    def test_no_direction_reaches_the_unreachable_default(self):
        # before the fix the first step with no direction stops at the trap
        for compiler, (status, output) in self.runs.items():
            last = output.strip().splitlines()[-1:] or ['(nothing)']
            self.assertEqual(status, 0, '%s: the steps stopped at %s' % (compiler, last[0]))
            self.assertTrue(output.rstrip().endswith('DONE'), compiler)

    def test_a_direction_that_is_not_a_side_plays_as_linux_played_it(self):
        for compiler, (status, output) in self.runs.items():
            got = drawn(output)
            for step in STEPS:
                before, after = NOT_A_SIDE[step]
                for direction in DIRECTIONS:
                    if direction in SIDES:
                        continue
                    side = after if direction in AFTER_THE_SIDES else before
                    for delta in ('0', '25', '50', '75', '100'):
                        key = (step, direction, delta)
                        self.assertIn(key, got, '%s: %s' % (compiler, ' '.join(key)))
                        self.assertEqual(got[key], got[(step, side, delta)],
                                         '%s: %s %s at %s should play %s' % (compiler, step, direction, delta, side))

    def test_the_four_sides_play_as_they_did(self):
        # what a side draws, whole: the start card moves (push, reveal) or
        # stays (wipe, scroll) and the end card comes in from that side
        for compiler, (status, output) in self.runs.items():
            got = drawn(output)
            self.assertEqual(got.get(('wipeeffect_step', 'VE_LEFT', '50')),
                             'start 10,20,200,300 from 0,0,200,300 end 210,20,200,300 from 200,0,200,300', compiler)
            self.assertEqual(got.get(('wipeeffect_step', 'VE_DOWN', '50')),
                             'start 10,170,400,150 from 0,150,400,150 end 10,20,400,150 from 0,0,400,150', compiler)
            self.assertEqual(got.get(('pusheffect_step', 'VE_RIGHT', '25')),
                             'start 110,20,400,300 from 0,0,400,300 end -290,20,400,300 from 0,0,400,300', compiler)
            self.assertEqual(got.get(('pusheffect_step', 'VE_UP', '50')),
                             'start 10,-130,400,300 from 0,0,400,300 end 10,170,400,300 from 0,0,400,300', compiler)
            self.assertEqual(got.get(('revealeffect_step', 'VE_DOWN', '50')),
                             'start 10,170,400,300 from 0,0,400,300 end 10,20,400,150 from 0,0,400,150', compiler)
            self.assertEqual(got.get(('scrolleffect_step', 'VE_LEFT', '50')),
                             'start 10,20,400,300 from 0,0,400,300 end 210,20,400,300 from 0,0,400,300', compiler)
            self.assertEqual(got.get(('scrolleffect_step', 'VE_UP', '25')),
                             'start 10,20,400,300 from 0,0,400,300 end 10,245,400,300 from 0,0,400,300', compiler)


class TheSource(unittest.TestCase):

    def test_every_step_takes_a_side_before_its_switch(self):
        text = read(STACKE)
        for step, (none, _) in NOT_A_SIDE.items():
            body = re.sub(r'//[^\n]*', '', function(text, step))
            side = body.find('dir = effectside(dir, %s);' % none)
            self.assertGreater(side, 0, step)
            self.assertLess(side, body.index('switch (dir)'), step)
            self.assertLess(side, body.index('dir == ') if 'dir == ' in body else len(body), step)

    def test_effectside_keeps_the_four_sides_and_maps_the_rest(self):
        body = function(read(STACKE), 'effectside', 'Visual_effects')
        self.assertIsNotNone(body)
        self.assertRegex(body, r'case VE_LEFT:\s*case VE_RIGHT:\s*case VE_UP:\s*case VE_DOWN:\s*return p_direction;')
        self.assertRegex(body, r'case VE_BOTTOM:\s*case VE_CENTER:\s*case VE_TOP:\s*return VE_UP;')
        self.assertRegex(body, r'default:\s*return p_none;')

    def test_the_parser_still_lets_a_missing_direction_through(self):
        # what the fix is for: the parser sets no direction by default
        text = read(os.path.join(ROOT, 'engine', 'src', 'visual.cpp'))
        self.assertIn('direction = VE_UNDEFINED;', text)


if __name__ == '__main__':
    unittest.main()
