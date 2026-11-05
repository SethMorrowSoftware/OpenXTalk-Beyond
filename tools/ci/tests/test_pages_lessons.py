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

"""The website's lessons (tools/pages/lessons, made into the site's lessons/
by tools/pages/build_lessons.py) and the parts of their engine check
(tools/ci/lessons_check.py) that need no engine: the lessons themselves
(every level, every example checked, every picture there, every link going
somewhere), the build and its search, the rules an example must keep, how
the check reads and compares the stage's pictures and what an example did,
where it finds the engine's extensions, externals and lc-compile, the
pages at rest and at a phone's width, and that CI runs the check.

The check itself runs every example on a real engine: build-linux.yml's
"Lessons check" with the engine it built, and lessons.yml with the latest
release's when a lesson changes.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import struct
import sys
import tempfile
import unittest
import zlib

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
LESSONS = os.path.join(PAGES, 'lessons')
sys.path.insert(0, PAGES)
sys.path.insert(0, CI)

import build_lessons  # noqa: E402
import lessons_check  # noqa: E402


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def figure(attrs, code='put 1', out='1'):
    """An example's HTML: attrs is the figure's attributes after its class."""
    return ('<figure class="example" %s><pre class="code"><code>%s</code></pre>%s</figure>'
            % (attrs, code, '' if out is None else '<pre class="out">%s</pre>' % out))


def problems(text, builders=None):
    """The problems examples() finds in text, a line each ([] for none)."""
    try:
        build_lessons.examples(text, builders)
    except build_lessons.BuildError as e:
        return str(e).split('\n')
    return []


class TheLessons(unittest.TestCase):
    """The lessons as they are written."""

    @classmethod
    def setUpClass(cls):
        cls.lessons = build_lessons.read_lessons()

    def test_from_beginner_to_expert(self):
        # every level has lessons, in order, and there are many of them
        levels = [lesson['level'] for lesson in self.lessons]
        self.assertEqual(levels, sorted(levels, key=build_lessons.LEVEL_KEYS.index))
        for key in build_lessons.LEVEL_KEYS:
            self.assertGreaterEqual(levels.count(key), 5, key)
        self.assertGreaterEqual(len(self.lessons), 60)
        self.assertEqual(self.lessons[0]['slug'], 'welcome')

    def test_every_lesson_teaches_by_example_and_ends_with_a_try_it(self):
        for lesson in self.lessons:
            self.assertGreaterEqual(len(lesson['examples']), 1, lesson['file'])
            self.assertIn('try-it', lesson['ids'], lesson['file'])
            self.assertEqual(lesson['headings'][-1][0], 'try-it', lesson['file'])
            self.assertTrue(lesson['words'], lesson['file'])
            self.assertTrue(lesson['minutes'].isdigit(), lesson['file'])
        self.assertGreaterEqual(sum(len(x['examples']) for x in self.lessons), 400)

    def test_most_examples_are_checked_by_what_they_put(self):
        # "compile" (not run) is for a dialog, a click or the internet: the
        # rest run, and nearly all are held to exactly what they put
        runs = [e['run'] for x in self.lessons for e in x['examples']]
        self.assertGreater(runs.count('output'), 0.85 * len(runs))
        self.assertLess(runs.count('compile'), 0.08 * len(runs))

    def test_every_picture_is_there_at_twice_the_stage(self):
        shots = [e for x in self.lessons for e in x['examples'] if e['shot'] is not None]
        self.assertGreaterEqual(len(shots), 40)
        for e in shots:
            self.assertEqual(e['shot_size'], (960, 720), e['id'])
            self.assertGreaterEqual(len(e['shot'].split()), 3, e['id'])
        wanted = build_lessons.shots(self.lessons, LESSONS)
        self.assertEqual(sorted(i for i, _ in wanted), sorted(e['id'] for e in shots))
        # and no picture that no example shows
        self.assertEqual(sorted(os.listdir(os.path.join(LESSONS, 'shots'))), sorted(i + '.png' for i, _ in wanted))

    def test_every_link_goes_somewhere(self):
        self.assertEqual(build_lessons.links(self.lessons), [])
        # the lessons link one another a lot: a reader is never at a dead end
        count = sum(len(build_lessons.LINK.findall(x['body'])) for x in self.lessons)
        self.assertGreater(count, 100)

    def test_the_needs_are_ones_the_check_can_load(self):
        for lesson in self.lessons:
            for e in lesson['examples']:
                for need in e['needs']:
                    if need.startswith('external:'):
                        self.assertIn(need[len('external:'):], build_lessons.EXTERNALS)
                    elif not need.startswith('builder:'):
                        # an extension the IDE comes with: its folder in
                        # extensions/ or the xTalk Suite's, by its id
                        self.assertRegex(need, r'^[a-z0-9]+(\.[a-z0-9-]+)+$')


class TheBuild(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-lessons-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def build(self, parts=()):
        out = os.path.join(self.work, 'lessons-' + '-'.join(parts))
        count, shown = build_lessons.build(out, parts)
        return out, count, shown

    def test_a_page_a_lesson_and_the_search(self):
        out, count, shown = self.build()
        lessons = build_lessons.read_lessons()
        self.assertEqual(count, len(lessons))
        self.assertEqual(shown, sum(len(x['examples']) for x in lessons))
        for name in ('index.html', 'lessons.css', 'lessons.js', 'search-index.js'):
            self.assertTrue(os.path.isfile(os.path.join(out, name)), name)
        by_slug = {x['slug']: x for x in lessons}
        for slug in by_slug:
            with open(os.path.join(out, slug, 'index.html'), encoding='utf-8') as f:
                page = f.read()
            self.assertNotIn('<!-- @', page, slug)
            self.assertNotRegex(page, r'@[A-Z_]+@', slug)
            self.assertIn('<title>%s · Lessons · OXT-Beyond</title>' % by_slug[slug]['title'], page)
        for e in (e for x in lessons for e in x['examples'] if e['shot'] is not None):
            self.assertTrue(os.path.isfile(os.path.join(out, 'shots', e['id'] + '.png')), e['id'])
        # the search: a row a section, each going to a page and a place
        # that are there, its text without its heading (the heading is
        # shown above it)
        with open(os.path.join(out, 'search-index.js'), encoding='utf-8') as f:
            script = f.read()
        self.assertNotIn('</', script)
        rows = json.loads(script[script.index('window.OXT_LESSONS=') + len('window.OXT_LESSONS='):].rstrip().rstrip(';'))
        self.assertGreater(len(rows), 300)
        for row in rows:
            slug, _, anchor = row['u'].partition('/')
            self.assertIn(slug, by_slug, row['u'])
            if anchor:
                self.assertTrue(anchor.startswith('#'), row['u'])
                self.assertIn(anchor[1:], by_slug[slug]['ids'], row['u'])
            if row['h']:
                self.assertFalse(row['x'].startswith(row['h']), row['u'])

    def test_the_parts_of_the_site_it_links(self):
        alone, _, _ = self.build()
        whole, _, _ = self.build(('IDE', 'DICTIONARY'))
        for folder, part in ((alone, False), (whole, True)):
            with open(os.path.join(folder, 'welcome', 'index.html'), encoding='utf-8') as f:
                page = f.read()
            self.assertEqual('href="../../ide/"' in page, part)
            self.assertEqual('href="../../dictionary/"' in page, part)
            with open(os.path.join(folder, 'index.html'), encoding='utf-8') as f:
                hub = f.read()
            self.assertEqual('href="../ide/"' in hub, part)

    def test_it_writes_only_into_an_empty_folder(self):
        out = os.path.join(self.work, 'full')
        os.makedirs(out)
        open(os.path.join(out, 'x'), 'w').close()
        with self.assertRaises(build_lessons.BuildError):
            build_lessons.build(out)
        with self.assertRaises(build_lessons.BuildError):
            build_lessons.build(os.path.join(self.work, 'other'), ('PLAYER',))

    def test_the_site_builds_them(self):
        # build_pages.py puts them on every site, with their card
        import build_pages
        self.assertIn('LESSONS', build_pages.PARTS)
        front = read('tools', 'pages', 'index.html')
        self.assertIn('<a class="button" href="lessons/">Open the lessons</a>', front)
        self.assertIn('<a class="optional" href="lessons/">Lessons</a>', front)


class TheExampleRules(unittest.TestCase):
    """What build_lessons.examples() refuses, so that every example says
    how the check holds it."""

    def test_a_good_example(self):
        self.assertEqual(problems(figure('id="ex-good" data-run="output"')), [])
        found = build_lessons.examples(figure('id="ex-good" data-run="output"', 'put 1 &amp; 2', '12'))
        self.assertEqual(found[0]['code'], 'put 1 & 2')
        self.assertEqual(found[0]['out'], '12')

    def test_what_it_refuses(self):
        cases = [
            (figure('id="ex-a" data-run="output"', out=None), 'no <pre class="out">'),
            (figure('id="ex-a" data-run="runs"', out=None), 'no <pre class="out">'),
            (figure('id="ex-a" data-run="compile"'), 'shows no output'),
            (figure('id="ex-a" data-run="maybe"'), 'not one of'),
            (figure('id="Ex_A" data-run="output"'), "an example's id"),
            (figure('id="ex-a" data-run="output" data-line="2"'), 'data-line'),
            (figure('id="ex-a" data-run="error" data-line="two"', out=None), 'data-line'),
            (figure('id="ex-a" data-run="output" data-wait="11"'), 'data-wait'),
            (figure('id="ex-a" data-run="compile" data-wait="1"', out=None), 'data-wait'),
            (figure('id="ex-a" data-run="compile" data-shot="a red square here"', out=None), 'data-shot'),
            (figure('id="ex-a" data-run="output" data-shot="a square"'), 'data-shot'),
            (figure('id="ex-a" data-run="output"', 'put 1\n\tput 2'), 'a tab'),
            (figure('id="ex-a" data-run="output" data-needs="builder:ex-nothing"'), 'not an xTalk Builder'),
            (figure('id="ex-a" data-run="output" data-needs="external:revfoo"'), 'not one of the externals'),
            (figure('id="ex-a" data-run="output" data-needs="Not An Id"'), "not an extension's id"),
            (figure('id="ex-a" data-run="output"') * 2, 'used twice'),
        ]
        for text, says in cases:
            found = problems(text)
            self.assertTrue(found, text)
            self.assertTrue(any(says in p for p in found), '%s: %s' % (text, found))

    def test_what_it_lets_through(self):
        ok = [
            figure('id="ex-a" data-run="error" data-line="2"', out=None),
            figure('id="ex-a" data-run="runs" data-wait="2.5" data-shot="a ball, mid bounce"'),
            figure('id="ex-a" data-run="output" data-needs="com.livecode.library.json external:revdb"'),
            figure('id="ex-m" data-run="builder"', 'library x\nend library', out=None)
            + figure('id="ex-a" data-run="output" data-needs="builder:ex-m"'),
        ]
        for text in ok:
            self.assertEqual(problems(text), [], text)
        # a module of another lesson, when its id is given
        self.assertEqual(problems(figure('id="ex-a" data-run="output" data-needs="builder:ex-m"'), {'ex-m'}), [])


class TheLinks(unittest.TestCase):

    def lessons(self, body):
        return [dict(slug='one', file='01-one.html', ids={'top', 'ex-one'}, body=body),
                dict(slug='two', file='02-two.html', ids={'deep'}, body='')]

    def test_good_links(self):
        body = ('<a href="../two/">Two</a> <a href="../two/#deep">deep</a> <a href="#top">up</a> '
                '<a href="#ex-one">the example</a> <a href="https://example.com/">out</a>')
        self.assertEqual(build_lessons.links(self.lessons(body)), [])

    def test_links_that_go_nowhere(self):
        for href, says in (('../three/', 'goes to no lesson'), ('../two/#shallow', 'goes to no id of 02-two.html'),
                           ('#bottom', 'goes to no id of this lesson'), ('../one/#top', 'is to this lesson'),
                           ('http://example.com/', 'is not'), ('../two/index.html', 'is not'),
                           ('../../ide/', 'is not'), ('two/', 'is not')):
            found = build_lessons.links(self.lessons('<p>See <a class="x" href="%s">this</a>.</p>' % href))
            self.assertEqual(len(found), 1, href)
            self.assertIn(says, found[0], href)
            self.assertTrue(found[0].startswith('01-one.html: the link %s' % href), found[0])


def png(width, height, rows, colour=2, depth=8, palette=b''):
    """A PNG file's bytes: rows are each row's filter type and its bytes."""
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    head = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, depth, colour, 0, 0, 0))
    plte = chunk(b'PLTE', palette) if palette else b''
    return (b'\x89PNG\r\n\x1a\n' + head + plte + chunk(b'IDAT', zlib.compress(b''.join(rows)))
            + chunk(b'IEND', b''))


def filtered(width, height, pixels, kinds):
    """RGB pixels' rows, each filtered with the next of kinds (0 to 4), as a
    PNG encoder does."""
    stride, rows, prev = width * 3, [], bytes(width * 3)
    for y in range(height):
        line, kind = pixels[y * stride:(y + 1) * stride], kinds[y % len(kinds)]
        out = bytearray([kind])
        for i in range(stride):
            a = line[i - 3] if i >= 3 else 0
            b = prev[i]
            c = prev[i - 3] if i >= 3 else 0
            if kind == 0:
                p = 0
            elif kind == 1:
                p = a
            elif kind == 2:
                p = b
            elif kind == 3:
                p = (a + b) // 2
            else:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                p = a if pa <= pb and pa <= pc else b if pb <= pc else c
            out.append((line[i] - p) & 255)
        rows.append(bytes(out))
        prev = line
    return rows


class ThePictures(unittest.TestCase):
    """How the check reads the engine's PNGs and compares the stage's
    picture with the page's (SHOT_BLOCK, SHOT_MEAN)."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-lessons-png-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def path(self, name, data):
        path = os.path.join(self.work, name)
        with open(path, 'wb') as f:
            f.write(data)
        return path

    def picture(self, name, width, height, pixels):
        path = os.path.join(self.work, name)
        lessons_check.write_png(path, width, height, bytes(pixels))
        return path

    def test_every_filter(self):
        width, height = 7, 10
        pixels = bytes((x * 37 + y * 11 + c * 90) % 256 for y in range(height) for x in range(width) for c in range(3))
        for kinds in ([0], [1], [2], [3], [4], [0, 1, 2, 3, 4]):
            path = self.path('f.png', png(width, height, filtered(width, height, pixels, kinds)))
            self.assertEqual(lessons_check.read_png(path), (width, height, pixels), kinds)

    def test_a_palette_grey_and_alpha(self):
        palette = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255])
        path = self.path('p8.png', png(3, 1, [b'\x00\x00\x01\x02'], colour=3, palette=palette))
        self.assertEqual(lessons_check.read_png(path), (3, 1, palette))
        # four bits a pixel: two pixels a byte
        path = self.path('p4.png', png(3, 1, [b'\x00\x01\x20'], colour=3, depth=4, palette=palette))
        self.assertEqual(lessons_check.read_png(path)[2], palette[0:3] + palette[3:6] + palette[6:9])
        path = self.path('g.png', png(2, 1, [b'\x00\x00\xff'], colour=0))
        self.assertEqual(lessons_check.read_png(path)[2], b'\x00\x00\x00\xff\xff\xff')
        path = self.path('a.png', png(1, 1, [b'\x00\x01\x02\x03\x80'], colour=6))
        self.assertEqual(lessons_check.read_png(path)[2], b'\x01\x02\x03')

    def test_what_it_does_not_read(self):
        with self.assertRaises(ValueError):
            lessons_check.read_png(self.path('x.png', b'not a picture'))
        with self.assertRaises(ValueError):
            lessons_check.read_png(self.path('16.png', png(1, 1, [b'\x00' + b'\x00' * 6], depth=16)))

    def test_the_same_picture(self):
        pixels = bytes(range(256)) * 3 * 4
        a = self.picture('a.png', 64, 12, pixels[:64 * 12 * 3])
        b = self.picture('b.png', 64, 12, pixels[:64 * 12 * 3])
        self.assertEqual(lessons_check.compare_shot(a, b), ('', 0, None))

    def test_a_small_difference_in_the_text_passes(self):
        # a pixel or two drawn a little differently, as two machines' text
        width, height = 64, 64
        base = bytearray(b'\xf8\xf9\xfa' * width * height)
        page = self.picture('page.png', width, height, base)
        changed = bytearray(base)
        changed[(10 * width + 10) * 3:(10 * width + 10) * 3 + 3] = b'\x00\x00\x00'
        changed[(40 * width + 33) * 3 + 1] = 0x80
        engine = self.picture('engine.png', width, height, changed)
        wrong, worst, difference = lessons_check.compare_shot(engine, page)
        self.assertEqual(wrong, '')
        self.assertLessEqual(worst, lessons_check.SHOT_BLOCK)
        self.assertIsNotNone(difference)

    def test_a_change_of_what_the_stage_shows_fails(self):
        width, height = 64, 64
        base = bytearray(b'\xf8\xf9\xfa' * width * height)
        page = self.picture('page.png', width, height, base)
        # a 16 by 16 square that is not there on the page
        square = bytearray(base)
        for y in range(20, 36):
            for x in range(20, 36):
                square[(y * width + x) * 3:(y * width + x) * 3 + 3] = b'\x8b\x5c\xf6'
        engine = self.picture('engine.png', width, height, square)
        wrong, worst, difference = lessons_check.compare_shot(engine, page)
        self.assertIn('a part of it differs', wrong)
        self.assertGreater(worst, lessons_check.SHOT_BLOCK)
        # the picture of the difference: what differs in red
        w, h, pixels = difference
        self.assertEqual((w, h), (width, height))
        self.assertEqual(pixels[(25 * width + 25) * 3:(25 * width + 25) * 3 + 3], b'\xe0\x10\x10')
        self.assertNotEqual(pixels[0:3], b'\xe0\x10\x10')
        # everything a little different, as a changed colour
        tinted = bytes(max(0, v - 6) for v in base)
        engine = self.picture('tinted.png', width, height, tinted)
        self.assertIn('the whole differs', lessons_check.compare_shot(engine, page)[0])

    def test_a_stage_of_another_size(self):
        a = self.picture('a.png', 8, 6, b'\x00' * 8 * 6 * 3)
        b = self.picture('b.png', 8, 8, b'\x00' * 8 * 8 * 3)
        wrong, worst, difference = lessons_check.compare_shot(a, b)
        self.assertEqual(wrong, "the stage is 4 by 3, and the page's picture 4 by 4")
        self.assertIsNone(difference)


class WhatAnExampleDid(unittest.TestCase):
    """lessons_check.compare(): what an example did against its page."""

    def example(self, run, out=None, line=None):
        return dict(id='ex-a', run=run, out=out, line=line)

    def test_output(self):
        self.assertEqual(lessons_check.compare(self.example('output', '1\n2'), ['ok'], '1\n2'), [])
        wrong = lessons_check.compare(self.example('output', '1\n2'), ['ok'], '1\n3')
        self.assertTrue(wrong and wrong[0].startswith('it put'))
        wrong = lessons_check.compare(self.example('output', '1'), ['error', 'Line 2: bad', 'no such handler', '2'], '')
        self.assertTrue(wrong and wrong[0].startswith('it stopped with an error'))
        self.assertIn('no such handler', wrong[0])
        self.assertTrue(lessons_check.compare(self.example('output', '1'), [], ''))

    def test_runs_counts_the_lines(self):
        self.assertEqual(lessons_check.compare(self.example('runs', 'That took 21 ms'), ['ok'], 'That took 9 ms'), [])
        wrong = lessons_check.compare(self.example('runs', 'a\nb'), ['ok'], 'a')
        self.assertIn('1 lines, not 2', wrong[0])

    def test_error(self):
        self.assertEqual(lessons_check.compare(self.example('error'), ['error', 'x', 'y', '3'], ''), [])
        self.assertEqual(lessons_check.compare(self.example('error', line='3'), ['error', 'x', 'y', '3'], ''), [])
        wrong = lessons_check.compare(self.example('error', line='2'), ['error', 'x', 'y', '3'], '')
        self.assertIn('on line 3, not on line 2', wrong[0])
        wrong = lessons_check.compare(self.example('error'), ['ok'], '')
        self.assertIn('ran to its end', wrong[0])


class WhereTheCheckLooks(unittest.TestCase):
    """The extensions, externals and lc-compile beside the engine: an
    installed IDE's folders, or a build output's."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-lessons-find-')
        self.engine = os.path.join(self.work, 'oxt-beyond')
        open(self.engine, 'w').close()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def test_the_extensions(self):
        self.assertIsNone(lessons_check.find_extensions(None, self.engine))
        self.assertEqual(lessons_check.find_extensions('/given', self.engine), '/given')
        os.makedirs(os.path.join(self.work, 'packaged_extensions'))
        self.assertEqual(lessons_check.find_extensions(None, self.engine), os.path.join(self.work, 'packaged_extensions'))
        os.makedirs(os.path.join(self.work, 'Extensions'))
        self.assertEqual(lessons_check.find_extensions(None, self.engine), os.path.join(self.work, 'Extensions'))

    def test_the_externals(self):
        revdb = {'win32': 'revdb.dll', 'darwin': 'revdb.bundle'}.get(sys.platform, 'revdb.so')
        self.assertIsNone(lessons_check.find_externals(None, self.engine))
        # a build output: beside the engine
        open(os.path.join(self.work, revdb), 'w').close()
        self.assertEqual(lessons_check.find_externals(None, self.engine), self.work)
        # an installed IDE: its Externals folder
        os.makedirs(os.path.join(self.work, 'Externals'))
        open(os.path.join(self.work, 'Externals', revdb), 'w').close()
        self.assertEqual(lessons_check.find_externals(None, self.engine), os.path.join(self.work, 'Externals'))
        self.assertEqual(lessons_check.find_externals('/given', self.engine), '/given')

    def test_lc_compile(self):
        exe = 'lc-compile.exe' if sys.platform == 'win32' else 'lc-compile'
        self.assertEqual(lessons_check.find_toolchain(None, self.engine), (None, None))
        folder = os.path.join(self.work, 'Toolchain')
        os.makedirs(os.path.join(folder, 'modules', 'lci'))
        open(os.path.join(folder, exe), 'w').close()
        self.assertEqual(lessons_check.find_toolchain(None, self.engine),
                         (os.path.join(folder, exe), os.path.join(folder, 'modules', 'lci')))

    def test_the_engine_script_loads_what_the_ide_loads(self):
        # extensions with their code libraries mapped and their resources,
        # script-library extensions, the externals from a saved stack, the
        # database drivers, and libURL; and a timer's wait in short steps,
        # in which sockets are served
        script = read('tools', 'ci', 'lessons-check.livecodescript')
        for words in ('command mapCodeLibraries', 'the revLibraryMapping', 'with resource path',
                      'function loadExternal', 'revSetDatabaseDriverPath', 'revliburl.livecodescript',
                      'wait 20 milliseconds with messages', 'revAcademyRun',
                      'export snapshot from this card of stack "revAcademyStage"'):
            self.assertIn(words, script)


class ThePagesInABrowser(unittest.TestCase):
    """The lessons' style sheet: still at rest (check_site_rest.py measures
    it), and nothing wider than a phone."""

    def setUp(self):
        self.css = re.sub(r'/\*.*?\*/', '', read('tools', 'pages', 'lessons', 'lessons.css'), flags=re.S)
        self.rules = [(m.group(1).strip(), m.group(2)) for m in re.finditer(r'([^{}]+)\{([^{}]*)\}', self.css)]

    def test_nothing_moves_without_end_at_rest(self):
        endless = [(s, b) for s, b in self.rules if re.search(r'animation:[^;]*\binfinite\b', b)]
        self.assertTrue(endless)
        for selector, body in endless:
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-visible', '%s { %s }' % (selector, body.strip()))
        reduce = self.css[self.css.index('@media (prefers-reduced-motion: reduce)'):]
        self.assertIn('animation: none !important', reduce)

    def test_the_search_results_are_not_cut_off(self):
        # the header's sky is drawn in .art, which clips it; the header
        # itself does not clip, so the results hang over the lesson
        rules = dict(self.rules)
        self.assertNotIn('overflow', rules['.sky'])
        self.assertIn('z-index', rules['.sky'])
        self.assertIn('overflow: hidden', rules['.sky > .art'])
        for name in ('index.html', 'lesson.html'):
            self.assertIn('<div class="art" aria-hidden="true"></div>', read('tools', 'pages', 'lessons', name))

    def test_nothing_wider_than_a_phone(self):
        # one column of at most the screen's width, and long code in the
        # text wraps (it once made six lessons wider than a phone)
        narrow = self.css[self.css.index('@media (max-width: 980px)'):]
        self.assertIn('.layout { grid-template-columns: minmax(0, 1fr);', narrow)
        code = dict(self.rules)[':not(pre) > code']
        self.assertIn('overflow-wrap: anywhere', code)
        self.assertNotIn('nowrap', code)


class TheCheckInCI(unittest.TestCase):

    def test_the_linux_build_checks_its_engine(self):
        workflow = read('.github', 'workflows', 'build-linux.yml')
        step = workflow[workflow.index('      - name: Lessons check\n'):]
        step = step[:step.index('\n\n')]
        self.assertIn('python3 tools/ci/lessons_check.py --engine "$OXT_ROOT/oxt-beyond"', step)
        # the pictures go up with the job's logs
        self.assertIn('--shots-out "$RUNNER_TEMP/logs/lessons-shots"', step)
        self.assertIn("matrix.arch == 'x86_64'", step)

    def test_a_change_to_a_lesson_is_checked(self):
        import yaml
        with open(os.path.join(REPO, '.github', 'workflows', 'lessons.yml'), encoding='utf-8') as f:
            workflow = yaml.safe_load(f)
        on = workflow[True]   # PyYAML reads the key "on" as True
        for event in ('push', 'pull_request'):
            for path in ('tools/pages/lessons/**', 'tools/pages/build_lessons.py', 'tools/ci/lessons_check.py',
                         'tools/ci/lessons-check.livecodescript', '.github/workflows/lessons.yml'):
                self.assertIn(path, on[event]['paths'], (event, path))
        text = read('.github', 'workflows', 'lessons.yml')
        self.assertIn("--pattern '*-linux-x86_64.tar.xz'", text)
        self.assertIn('python3 tools/ci/lessons_check.py --engine "$OXT_ENGINE"', text)
        self.assertIn('--shots-out "$RUNNER_TEMP/lessons/shots"', text)
        self.assertIn('uses: actions/upload-artifact@v7', text)
        # and the site's build, which builds them, when they change
        web = read('.github', 'workflows', 'web-ide.yml')
        self.assertEqual(web.count('      - tools/pages/lessons/**\n'), 2)
        self.assertEqual(web.count('      - tools/pages/build_lessons.py\n'), 2)


if __name__ == '__main__':
    unittest.main()
