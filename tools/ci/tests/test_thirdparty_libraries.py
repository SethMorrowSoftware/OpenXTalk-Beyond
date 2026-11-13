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

"""SQLite, expat and FreeType from thirdparty/ give what the versions
before them gave, with no build of the engine.

  python3 -m unittest discover -s tools/ci/tests

Each library is compiled from thirdparty/ with the host's C compiler into a
static archive, as the build makes it (the sources of its .gyp file), and
linked with a small program from tools/ci/tests/thirdparty/:

- sqlite_text.c runs sqlite_values.sql on a connection set up as revDB's
  driver sets it up and prints the text of every value: the text a script
  gets. The answers, sqlite_values.expected, are SQLite 3.51.3's
  (0.2.8-dp.1); 0.2.8-dp.2's 3.54.1 must give them too.
- expat_events.c prints the events expat reports for the documents of
  expat/, as Skia's parsers read them. The answers are expat 2.2.0's;
  2.10.0 refuses the entity expansion of expat/amplification.xml, the one
  difference, as it should.
- freetype_metrics.c prints, for every font in the repository, what the web
  and Android engines lay text out with: face and size metrics, every
  glyph's unhinted advance (HarfBuzz measures text with them) and kerning.
  freetype.expected holds a SHA-256 of each font's output from FreeType
  2.10.4; 2.14.3 must give the same, so no measured text width moves.

The answers were written with

  python3 tools/ci/tests/test_thirdparty_libraries.py --pin <thirdparty>

where <thirdparty> was the thirdparty/ folder of main before the update
(git archive). The compiled tests run on Linux when a C compiler is found
(cc, gcc or clang; tens of seconds), and are skipped elsewhere; the checks
of the sources run everywhere.
"""

import ast
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, 'thirdparty')
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
THIRDPARTY = os.path.join(REPO, 'thirdparty')

SQLITE_DEFINES = ['SQLITE_ENABLE_FTS3', 'SQLITE_ENABLE_FTS3_PARENTHESIS',
                  'SQLITE_ENABLE_FTS4', 'SQLITE_ENABLE_FTS5',
                  'SQLITE_ENABLE_RTREE', 'SQLITE_ENABLE_JSON1']

# The documents of expat/ whose events must not change; amplification.xml
# is tested on its own
EXPAT_DOCUMENTS = ['fonts.xml', 'ents.xml', 'latin1.xml', 'bom.xml',
                   'utf16.xml', 'bad.xml']


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def compiler():
    for name in ('cc', 'gcc', 'clang'):
        path = shutil.which(name)
        if path:
            return path
    return None


CAN_COMPILE = sys.platform.startswith('linux') and compiler() is not None
WHY_NOT = 'compiles C with the host compiler: Linux with cc, gcc or clang only'


def gyp_c_sources(gyp_path):
    """The .c files a .gyp file compiles (the build's list)."""
    data = ast.literal_eval(read(gyp_path))
    sources = data['targets'][0]['sources']
    return [s for s in sources if s.endswith('.c')]


def build_archive(work, name, root, sources, includes, defines=()):
    """Compiles the sources into lib<name>.a, as the build does."""
    objdir = os.path.join(work, name)
    os.makedirs(objdir, exist_ok=True)
    objects = []
    for i, source in enumerate(sources):
        obj = os.path.join(objdir, '%03d.o' % i)
        subprocess.run([compiler(), '-c', '-O1', '-w']
                       + ['-I' + os.path.join(root, d) for d in includes]
                       + ['-D' + d for d in defines]
                       + [os.path.join(root, source), '-o', obj],
                       check=True)
        objects.append(obj)
    archive = os.path.join(work, 'lib%s.a' % name)
    subprocess.run(['ar', 'rcs', archive] + objects, check=True)
    return archive


def build_program(work, name, source, includes, archives, libs=()):
    program = os.path.join(work, name)
    subprocess.run([compiler(), '-O1', '-w'] + ['-I' + d for d in includes]
                   + [os.path.join(FIXTURES, source)] + archives + list(libs)
                   + ['-o', program], check=True)
    return program


def run(program, *args, stdin=None):
    return subprocess.run([program] + list(args), input=stdin,
                          stdout=subprocess.PIPE, check=True).stdout


def build_sqlite(work, thirdparty):
    root = os.path.join(thirdparty, 'libsqlite')
    # sqlite3.c alone: the rest of libsqlite is the C++ driver glue
    archive = build_archive(work, 'sqlite', root, ['src/sqlite3.c'],
                            ['include'], SQLITE_DEFINES)
    return build_program(work, 'sqlite_text', 'sqlite_text.c',
                         [os.path.join(root, 'include')], [archive],
                         ['-lm', '-lpthread', '-ldl'])


def build_expat(work, thirdparty):
    root = os.path.join(thirdparty, 'libexpat')
    archive = build_archive(work, 'expat', root,
                            gyp_c_sources(os.path.join(root, 'libexpat.gyp')),
                            ['.', 'lib'], ['HAVE_EXPAT_CONFIG_H'])
    return build_program(work, 'expat_events', 'expat_events.c',
                         [os.path.join(root, 'lib')], [archive])


def build_freetype(work, thirdparty):
    root = os.path.join(thirdparty, 'libfreetype')
    archive = build_archive(work, 'freetype', root,
                            gyp_c_sources(os.path.join(root, 'libfreetype.gyp')),
                            ['include', 'src'], ['FT2_BUILD_LIBRARY'])
    return build_program(work, 'freetype_metrics', 'freetype_metrics.c',
                         [os.path.join(root, 'include')], [archive],
                         ['-lz', '-lm'])


def font_files():
    """Every font file in the repository, as paths from its root."""
    fonts = []
    for top, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d != '.git']
        for name in files:
            if name.lower().endswith(('.ttf', '.otf', '.ttc')):
                path = os.path.join(top, name)
                fonts.append(os.path.relpath(path, REPO).replace(os.sep, '/'))
    return sorted(fonts)


def freetype_digests(program):
    digests = {}
    for font in font_files():
        output = run(program, os.path.join(REPO, font))
        digests[font] = hashlib.sha256(output).hexdigest()
    return digests


def expat_events(program, document, namespaces=True):
    args = [os.path.join(FIXTURES, 'expat', document)]
    if not namespaces:
        args.append('plain')
    return run(program, *args).decode('utf-8')


def pin(thirdparty):
    """Writes the answers from the libraries of another thirdparty/."""
    work = tempfile.mkdtemp()
    try:
        sqlite = build_sqlite(work, thirdparty)
        corpus = read(os.path.join(FIXTURES, 'sqlite_values.sql'))
        with open(os.path.join(FIXTURES, 'sqlite_values.expected'), 'wb') as f:
            f.write(run(sqlite, stdin=corpus.encode('utf-8')))
        expat = build_expat(work, thirdparty)
        for document in EXPAT_DOCUMENTS:
            for namespaces in (True, False):
                name = document + ('.ns' if namespaces else '.plain') + '.expected'
                with open(os.path.join(FIXTURES, 'expat', name), 'w',
                          encoding='utf-8', newline='\n') as f:
                    f.write(expat_events(expat, document, namespaces))
        freetype = build_freetype(work, thirdparty)
        with open(os.path.join(FIXTURES, 'freetype.expected'), 'w',
                  encoding='utf-8', newline='\n') as f:
            json.dump(freetype_digests(freetype), f, indent=1, sort_keys=True)
            f.write('\n')
    finally:
        shutil.rmtree(work)


class Sources(unittest.TestCase):
    """What the updates must keep in the sources (every platform)."""

    def test_versions_agree_with_their_origin_files(self):
        sqlite = read(os.path.join(THIRDPARTY, 'libsqlite', 'include', 'sqlite3.h'))
        version = re.search(r'#\s*define SQLITE_VERSION\s+"([^"]+)"', sqlite).group(1)
        self.assertIn('sqlite-%s' % version,
                      read(os.path.join(THIRDPARTY, 'libsqlite', 'ORIGIN')))
        expat = read(os.path.join(THIRDPARTY, 'libexpat', 'lib', 'expat.h'))
        version = '.'.join(re.search(r'#\s*define XML_%s_VERSION\s+(\d+)' % part,
                                     expat).group(1)
                           for part in ('MAJOR', 'MINOR', 'MICRO'))
        self.assertIn('expat-%s' % version,
                      read(os.path.join(THIRDPARTY, 'libexpat', 'ORIGIN')))
        self.assertIn('"expat %s"' % version,
                      read(os.path.join(THIRDPARTY, 'libexpat', 'expat_config.h')))
        freetype = read(os.path.join(THIRDPARTY, 'libfreetype', 'include',
                                     'freetype', 'freetype.h'))
        version = '.'.join(re.search(r'#\s*define FREETYPE_%s\s+(\d+)' % part,
                                     freetype).group(1)
                           for part in ('MAJOR', 'MINOR', 'PATCH'))
        self.assertIn('FreeType %s' % version,
                      read(os.path.join(THIRDPARTY, 'libfreetype', 'ORIGIN')))

    def test_the_driver_keeps_fifteen_digits(self):
        # SQLite 3.53 and later write 17 digits unless told otherwise
        driver = read(os.path.join(THIRDPARTY, 'libsqlite', 'src',
                                   'sqlitedataset.cpp'))
        self.assertRegex(driver, r'sqlite3_db_config\(conn, SQLITE_DBCONFIG_FP_DIGITS, 15,')

    def test_quote_and_json_follow_the_setting(self):
        sqlite = read(os.path.join(THIRDPARTY, 'libsqlite', 'src', 'sqlite3.c'))
        self.assertEqual(sqlite.count('nFpDigit==15'), 2,
                         "OXT-Beyond's change to quote() and the JSON "
                         "functions (thirdparty/libsqlite/ORIGIN)")

    def test_freetype_has_the_modules_it_had(self):
        modules = read(os.path.join(THIRDPARTY, 'libfreetype', 'include',
                                    'freetype', 'config', 'ftmodule.h'))
        self.assertNotIn('sdf_renderer', modules)
        self.assertNotIn('svg_renderer', modules)
        gyp = gyp_c_sources(os.path.join(THIRDPARTY, 'libfreetype',
                                         'libfreetype.gyp'))
        for source in gyp:
            self.assertTrue(os.path.exists(os.path.join(
                THIRDPARTY, 'libfreetype', source)), source)

    def test_expat_sources_exist(self):
        for source in gyp_c_sources(os.path.join(THIRDPARTY, 'libexpat',
                                                 'libexpat.gyp')):
            self.assertTrue(os.path.exists(os.path.join(
                THIRDPARTY, 'libexpat', source)), source)


@unittest.skipUnless(CAN_COMPILE, WHY_NOT)
class Compiled(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work)

    def test_sqlite_gives_scripts_the_text_it_gave(self):
        program = build_sqlite(self.work, THIRDPARTY)
        corpus = read(os.path.join(FIXTURES, 'sqlite_values.sql'))
        actual = run(program, stdin=corpus.encode('utf-8')).decode('utf-8')
        expected = read(os.path.join(FIXTURES, 'sqlite_values.expected'))
        self.assertEqual(actual.splitlines(), expected.splitlines())

    def test_expat_reports_the_events_it_reported(self):
        program = build_expat(self.work, THIRDPARTY)
        for document in EXPAT_DOCUMENTS:
            for namespaces in (True, False):
                name = document + ('.ns' if namespaces else '.plain') + '.expected'
                with self.subTest(document=document, namespaces=namespaces):
                    self.assertEqual(
                        expat_events(program, document, namespaces),
                        read(os.path.join(FIXTURES, 'expat', name)))

    def test_expat_refuses_entity_amplification(self):
        # A few hundred bytes that expand to about ten megabytes: expat
        # 2.2.0 expanded them, 2.4.0 and later refuse them
        program = build_expat(self.work, THIRDPARTY)
        events = expat_events(program, 'amplification.xml')
        self.assertIn('ERROR limit on input amplification factor', events)

    def test_freetype_lays_text_out_as_it_did(self):
        program = build_freetype(self.work, THIRDPARTY)
        expected = json.loads(read(os.path.join(FIXTURES, 'freetype.expected')))
        actual = freetype_digests(program)
        for font, digest in sorted(expected.items()):
            with self.subTest(font=font):
                self.assertIn(font, actual, 'the font is no longer there')
                self.assertEqual(actual[font], digest)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--pin':
        pin(os.path.abspath(sys.argv[2]))
    else:
        unittest.main()
