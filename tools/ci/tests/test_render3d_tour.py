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
"""The Render3D Tour (tools/web-player/stacks/Render3D Tour.oxtstack) held
to the files it is made from, without a browser or an engine:

- the committed stack is built from render3d-tour-stack.livecodescript:
  the stack file holds the script, as it is (a change there that was
  never built fails here), and the builder reads that file
- the stack carries no file: every picture and model is made in script,
  and the PNG it carries as text is a PNG, 32 pixels each way, with
  transparent pixels
- the picture the builder makes is the size the tour draws, and the
  controls the tour's script names are the ones the builder makes
- ten exhibits: a button, a name, a builder and a turn of the switch for
  each
- every render3dxt handler the tour calls is one the suite's binding has,
  when the suite is beside this checkout (XTALK_SUITE, or ../xtalk-suite)
- the tour is offered: in the Stack Player's samples with its picture, in
  Home's gallery with an icon, and in the player's README
- the engine tests drive the tour through the hooks it has, find
  render3dxt as the IDE lays it out, load this platform's library only,
  and CI runs them with the package's render3dxt
- no statement of the tour is too long for an iPhone's Safari

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import os
import re
import struct
import sys
import unittest
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
PLAYER = os.path.join(REPO, 'tools', 'web-player')
STACK = os.path.join(PLAYER, 'stacks', 'Render3D Tour.oxtstack')
TESTS = ('tests', 'lcs', 'webplayer', 'render3d-tour.livecodescript')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def tour_script():
    return read('tools', 'web-player', 'render3d-tour-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'render3d-tour.livecodescript')


def constant(name, text):
    m = re.search(r'^constant %s = (.*)$' % re.escape(name), text, re.M)
    assert m, name
    return m.group(1).strip().strip('"')


def handlers(text):
    return set(re.findall(r'^(?:private )?(?:on|command|function) (\w+)', text, re.M))


def strip_comments(text):
    """The script without its comments and its string literals"""
    out = []
    for line in text.split('\n'):
        line = re.sub(r'"[^"\n]*"', '""', line)
        out.append(line.split('--', 1)[0])
    return '\n'.join(out)


def suite_binding():
    """render3dxt's binding in a checkout of the xTalk Suite, or None"""
    for root in (os.environ.get('XTALK_SUITE'), os.path.join(os.path.dirname(REPO), 'xtalk-suite')):
        if root and os.path.isfile(os.path.join(root, 'render3dxt', 'src', 'render3dxt.lcb')):
            with open(os.path.join(root, 'render3dxt', 'src', 'render3dxt.lcb'), encoding='utf-8') as f:
                return f.read()
    return None


class BuiltFromItsScript(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        with open(STACK, 'rb') as f:
            data = f.read()
        self.assertTrue(data.startswith(b'REVO'))
        script = tour_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), data,
                      'the committed stack is not built from render3d-tour-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/render3d-tour.livecodescript)')

    def test_the_measure_sees_a_stale_stack(self):
        with open(STACK, 'rb') as f:
            data = f.read()
        script = tour_script().split('\n', 1)[1].rstrip('\n')
        self.assertNotIn((script + '\n-- changed').encode('utf-8'), data)

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('"render3d-tour-stack.livecodescript"', text)
        self.assertIn('"stacks/Render3D Tour.oxtstack"', text)
        self.assertIn('$OXT_RENDER3D_TOUR', text)
        # the script is set last, and its first line is not part of it
        body = text[text.index('private command buildStack'):text.index('end buildStack')]
        self.assertLess(body.rindex('create '), body.index('set the script of stack tName'))
        self.assertIn('delete line 1 of tScript', text)
        self.assertEqual(tour_script().split('\n', 1)[0], 'script "Render3D Tour"')

    def test_the_stack_carries_no_file(self):
        script = strip_comments(tour_script())
        for word in ('url', 'specialFolderPath', 'open file', 'r3TextureLoad', 'r3MeshLoadObj', 'shell', 'launch'):
            self.assertNotRegex(script, r'\b%s\b' % word, word)
        self.assertFalse(os.path.isdir(os.path.join(PLAYER, 'render3d-tour')))

    def test_the_png_in_the_script_is_one(self):
        script = tour_script()
        body = script[script.index('function rtLatticePng'):script.index('end rtLatticePng')]
        png = base64.b64decode(''.join(re.findall(r'put "([A-Za-z0-9+/=]+)"', body)))
        self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
        width, height, depth, kind = struct.unpack('>IIBB', png[16:26])
        self.assertEqual((width, height, depth, kind), (32, 32, 8, 6))
        at, idat = 8, b''
        while at < len(png):
            size, name = struct.unpack('>I4s', png[at:at + 8])
            chunk = png[at + 8:at + 8 + size]
            self.assertEqual(struct.unpack('>I', png[at + 8 + size:at + 12 + size])[0],
                             zlib.crc32(name + chunk) & 0xffffffff, name)
            if name == b'IDAT':
                idat += chunk
            at += 12 + size
        rows = zlib.decompress(idat)
        self.assertEqual(len(rows), 32 * (1 + 32 * 4))
        alphas = {rows[y * 129 + 1 + x * 4 + 3] for y in range(32) for x in range(32)}
        # the gaps are clear and the wood is not: a cutout has both
        self.assertEqual(alphas, {0, 255})


class ItsWindow(unittest.TestCase):

    def test_the_image_is_the_pictures_size(self):
        tour, build = tour_script(), builder()
        for name in ('kViewW', 'kViewH', 'kTags'):
            self.assertEqual(constant(name, tour), constant(name, build), name)
        self.assertEqual((constant('kViewW', tour), constant('kViewH', tour)), ('640', '480'))
        self.assertIn('set the rect of image "View" to kViewLeft, kViewTop, kViewLeft + kViewW, kViewTop + kViewH',
                      build)

    def test_every_control_the_tour_names_is_made(self):
        tour, build = tour_script(), builder()
        made = set(re.findall(r'make(?:Label|Text|Button|Tick) "(\w+)"', build))
        made |= set(re.findall(r'create (?:image|graphic) "(\w+)"', build))
        self.assertTrue({'View', 'Missing', 'About', 'Stats', 'Smooth', 'Fog', 'Spin'} <= made, made)
        self.assertIn('makeLabel "Tag" & tIndex', build)
        self.assertIn('makeButton "Ex" & tIndex', build)
        named = set(re.findall(r'(?:field|button|image) "(\w+)"', tour))
        self.assertTrue(named <= made, named - made)
        self.assertTrue({'View', 'Missing', 'About', 'Stats', 'Smooth', 'Fog', 'Spin'} <= named, named)

    def test_ten_exhibits(self):
        tour, build = tour_script(), builder()
        names = constant('kExhibitNames', build).split(',')
        self.assertEqual(len(names), 10)
        self.assertEqual(len(set(names)), 10)
        self.assertEqual(constant('kExhibits', tour), '10')
        go = tour[tour.index('command rtGo'):tour.index('end rtGo')]
        tick = tour[tour.index('command rtTick\n'):tour.index('end rtTick\n')]
        have = handlers(tour)
        for n in range(1, 11):
            for body in (go, tick):
                case = re.search(r'case %d\n\s+(\w+)' % n, body)
                self.assertIsNotNone(case, n)
                self.assertIn(case.group(1), have)
        self.assertEqual(len(set(re.findall(r'case \d+\n\s+(rtBuild\w+)', go))), 10)

    def test_no_statement_is_too_long(self):
        sys.path.insert(0, HERE)
        import test_mobile_web_check
        measure = test_mobile_web_check.FitsAnIPhonesStack().longest_statement
        for text in (tour_script(), builder()):
            self.assertLessEqual(measure(text), 30)


class WhatItCalls(unittest.TestCase):

    def test_every_handler_it_calls_is_in_the_binding(self):
        binding = suite_binding()
        if binding is None:
            self.skipTest('no xTalk Suite checkout beside this one (XTALK_SUITE)')
        public = set(re.findall(r'^public handler (r3\w+)', binding, re.M))
        called = set(re.findall(r'\b(r3[A-Z]\w+)', strip_comments(tour_script())))
        self.assertGreater(len(called), 60)
        self.assertTrue(called <= public, called - public)

    def test_it_asks_before_it_calls(self):
        tour = tour_script()
        have = tour[tour.index('function rtHaveRenderer'):tour.index('end rtHaveRenderer')]
        self.assertIn('try', have)
        self.assertIn('do "put r3LibraryVersion() into tVersion"', have)
        start = tour[tour.index('command rtStart'):tour.index('end rtStart')]
        self.assertLess(start.index('if sHave is not true then'), start.index('r3ThreadCount()'))
        self.assertIn('show field "Missing"', start)
        # what the mouse and the buttons reach does nothing without a scene
        for name in ('rtGo', 'rtClickView', 'rtHoverView', 'rtOrbitBy', 'rtZoom', 'rtDraw', 'rtTestStep',
                     'rtLookChanged', 'rtShowStats', 'rtPlaceTags'):
            body = tour[tour.index('command %s' % name):tour.index('end %s' % name)]
            self.assertRegex(body, r'if (sHave is not true|sScene is empty)', name)

    def test_the_paint_compression_is_put_back(self):
        tour = tour_script()
        show = tour[tour.index('command rtShow '):tour.index('end rtShow\n')]
        self.assertRegex(show, r'put the paintCompression into tWas\n\s+set the paintCompression to "rle"\n'
                               r'\s+set the imageData of image "View" to pPicture\n\s+set the paintCompression to tWas')
        self.assertEqual(tour.count('set the imageData'), 1)


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Render3D Tour']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Render3D Tour.oxtstack'])
        self.assertEqual(sample[0]['image'], 'Render3D Tour.webp')
        self.assertEqual(sample[0]['source'], 'stacks')
        self.assertIn('3D', sample[0]['tags'])
        for name in ('Render3D Tour.oxtstack', 'Render3D Tour.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)
        with open(os.path.join(PLAYER, 'stacks', 'Render3D Tour.webp'), 'rb') as f:
            head = f.read(12)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        case = re.search(r'case "Render3D Tour"\n(.*?)\n      case', learn, re.S)
        self.assertIsNotNone(case)
        self.assertEqual(re.search(r'return "([a-z]+)\|', case.group(0)).group(1), 'small')
        icon, accent = re.search(r'\|([a-z0-9-]+)\|([a-z]+)\|[^|"]+"', case.group(0)).groups()
        self.assertEqual((icon, accent), ('orbit', 'indigo'))
        self.assertIn('case "%s"' % icon, kit)
        self.assertIn('case "%s"' % accent, kit)

    def test_in_the_players_readme(self):
        readme = read('tools', 'web-player', 'README.md')
        self.assertIn('**Render3D Tour**', readme)
        self.assertIn('## The Render3D Tour', readme)
        self.assertIn('`render3d-tour.livecodescript`, `render3d-tour-stack.livecodescript`', readme)


class ItsEngineTests(unittest.TestCase):

    def test_the_tests_use_the_tours_hooks(self):
        tests = read(*TESTS)
        tour = tour_script()
        hooks = set(re.findall(r'"(rt[A-Z]\w+)"', tests))
        self.assertTrue({'rtTestBegin', 'rtTestStep', 'rtClickView', 'rtHoverView', 'rtState', 'rtOrbitBy',
                         'rtZoom'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(tour, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test(?!Setup|Teardown)', tests, re.M)), 14)
        # every key the tests read is one rtState writes
        state = tour[tour.index('function rtState'):tour.index('end rtState')]
        for key in set(re.findall(r'st\("([a-z]+)"\)', tests)):
            self.assertIn('"%s="' % key, state, key)

    def test_the_tests_find_render3dxt(self):
        tests = read(*TESTS)
        self.assertIn('$OXT_RENDER3DXT', tests)
        self.assertIn('constant kExtension = "org.openxtalk.library.renderthreed"', tests)
        for layout in ('",/" & kExtension & ",/Extensions/" & kExtension', '/code'):
            self.assertIn(layout, tests)

    def test_the_tests_load_this_platforms_library_only(self):
        tests = read(*TESTS)
        handler = re.search(r'^private command loadRenderer\b.*?^end loadRenderer', tests, re.S | re.M)
        self.assertIsNotNone(handler)
        loop = re.search(r'repeat for each line (\w+) in folders\(tFolder & "/code"\)\n(.*?)\n\s*end repeat',
                         handler.group(0), re.S)
        self.assertIsNotNone(loop)
        name, body = loop.group(1), loop.group(2)
        self.assertEqual(body.strip().splitlines()[0].strip(), 'if tPlatform is not in %s then next repeat' % name)
        for platform, part in (('MacOS', '"-mac"'), ('Win32', '"-win32"')):
            self.assertRegex(handler.group(0), r'case "%s"\s*\n.*\n\s*put %s into tPlatform' % (platform, part))
        self.assertIn('put "-" & toLower(the platform) into tPlatform', handler.group(0))

    def test_ci_runs_them_with_render3dxt(self):
        linux = read('.github', 'workflows', 'build-linux.yml')
        step = re.search(r"- name: Render3D Tour with render3dxt.*?(?=\n      #|\n      - name:)", linux, re.S)
        self.assertIsNotNone(step)
        self.assertIn('OXT_RENDER3DXT="$OXT_ROOT"', step.group(0))
        self.assertIn("--filter '^lcs: webplayer/render3d-tour:'", step.group(0))
        # every test of the pictures ran: none skipped for want of render3dxt
        self.assertIn("grep -q ' 0 skip$'", step.group(0))


if __name__ == '__main__':
    unittest.main()
