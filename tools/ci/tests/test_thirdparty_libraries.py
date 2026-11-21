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

- sqlite_text.c runs sqlite_values.txt on a connection set up as revDB's
  driver sets it up and prints the text of every value: the text a script
  gets. The answers, sqlite_values.expected, are SQLite 3.51.3's
  (0.2.8-dp.1); 0.2.8-dp.2's 3.54.1 must give them too, and so must the
  connection with the math and REGEXP functions that the driver adds to
  it since 0.2.8-dp.3 (thirdparty/libsqlite/src/sqlitefunctions.c).
  Those must answer as SQLite's built-in math functions do (sqlite_text
  built with SQLITE_ENABLE_MATH_FUNCTIONS instead), REGEXP as SQLite's
  regexp extension does, and a loaded extension (sqlite_extension.c)
  that defines functions of the same names must take their place, as it
  did when there were none.
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
import fnmatch
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
SQLITE_FUNCTIONS = os.path.join(THIRDPARTY, 'libsqlite', 'src', 'sqlitefunctions.c')

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


def build_program(work, name, source, includes, archives, libs=(), defines=()):
    program = os.path.join(work, name)
    subprocess.run([compiler(), '-O1', '-w'] + ['-I' + d for d in includes]
                   + ['-D' + d for d in defines]
                   + [os.path.join(FIXTURES, source)] + archives + list(libs)
                   + ['-o', program], check=True)
    return program


def run(program, *args, stdin=None):
    return subprocess.run([program] + list(args), input=stdin,
                          stdout=subprocess.PIPE, check=True).stdout


def libsqlite_build(root):
    """The C files that libsqlite.gyp compiles on Linux (gethostuuid.c is
    the Mac's; the C++ files are the driver's glue, not SQLite) and the
    defines it compiles them with."""
    data = ast.literal_eval(read(os.path.join(root, 'libsqlite.gyp')))
    target = data['targets'][0]['conditions'][0][1]
    sources = [s for s in target['sources']
               if s.endswith('.c') and s != 'src/gethostuuid.c']
    return sources, target['defines']


def build_sqlite(work, thirdparty, builtin_math=False):
    """sqlite_text, with the SQLite of thirdparty/libsqlite as the build
    compiles it: sqlite3.c, and where the tree has them the functions the
    driver adds to each connection (sqlitefunctions.c), which sqlite_text
    then adds as the driver does. With builtin_math, SQLite as it would be
    with SQLITE_ENABLE_MATH_FUNCTIONS instead: sqlite3.c alone, with its
    own math functions built in."""
    root = os.path.join(thirdparty, 'libsqlite')
    sources, defines = libsqlite_build(root)
    name, program_defines = 'sqlite', []
    if builtin_math:
        name = 'sqlite_builtin_math'
        sources, defines = ['src/sqlite3.c'], defines + ['SQLITE_ENABLE_MATH_FUNCTIONS']
    elif 'src/sqlitefunctions.c' in sources:
        program_defines = ['OXT_SQLITE_FUNCTIONS']
    archive = build_archive(work, name, root, sources, ['include'], defines)
    return build_program(work, name + '_text', 'sqlite_text.c',
                         [os.path.join(root, 'include')], [archive],
                         ['-lm', '-lpthread', '-ldl'], program_defines)


def build_sqlite_extension(work, thirdparty):
    """sqlite_extension.c as a loadable extension (a shared library)."""
    path = os.path.join(work, 'sqlite_extension.so')
    subprocess.run([compiler(), '-O1', '-w', '-shared', '-fPIC',
                    '-I' + os.path.join(thirdparty, 'libsqlite', 'include'),
                    os.path.join(FIXTURES, 'sqlite_extension.c'), '-o', path, '-lm'],
                   check=True)
    return path


def sqlite_answers(program, queries, *args):
    """What sqlite_text prints for each query (one line of SQL each): a
    list of its lines, "<type> <text>" for each value (1 integer, 2 real,
    3 text, 5 NULL) or "ERR <message>"."""
    out = run(program, *args, stdin=''.join(q + '\n' for q in queries).encode('utf-8'))
    answers = []
    for line in out.decode('utf-8').splitlines():
        if line.startswith('> '):
            answers.append([])
        else:
            answers[-1].append(line.strip())
    return answers


# The functions that sqlitefunctions.c adds, as SQLite's table of built-in
# functions has them (under SQLITE_ENABLE_MATH_FUNCTIONS): those of one
# argument, and of two (log() has both)
MATH_ONE = ['ceil', 'ceiling', 'floor', 'trunc', 'ln', 'log', 'log10', 'log2', 'exp',
            'acos', 'asin', 'atan', 'cos', 'sin', 'tan', 'cosh', 'sinh', 'tanh',
            'acosh', 'asinh', 'atanh', 'sqrt', 'radians', 'degrees']
MATH_TWO = ['log', 'pow', 'power', 'mod', 'atan2']
# What a script may hand them: integers, reals, the extremes, text that is
# a number and text that is not, NULL, a blob, the infinities
MATH_VALUES = ['0', '1', '-1', '2', '10', '0.5', '-0.5', '3.75', '-3.75', '100', '1e10',
               '1e-10', '1e308', '-1e308', '9007199254740993', '-9223372036854775808',
               "'4'", "'2.5'", "' 16 '", "'abc'", "''", 'NULL', "x'3136'", '1e999', '-1e999']
MATH_PAIRS = ['0', '1', '-1', '2', '10', '0.5', '-2.5', "'3'", "'x'", 'NULL', '1e999']


def math_queries():
    """Queries on every math function, each line one statement or more."""
    queries = ['SELECT %s' % ', '.join('%s(%s)' % (f, v) for v in MATH_VALUES)
               for f in MATH_ONE]
    queries += ['SELECT %s' % ', '.join('%s(%s, %s)' % (f, a, b) for b in MATH_PAIRS)
                for f in MATH_TWO for a in MATH_PAIRS]
    queries += [
        'SELECT pi(), pi() * 2, round(pi(), 4), typeof(pi())',
        'SELECT SQRT(16), Pi(), LOG(2, 8), Mod(7, 3)',
        # the wrong number of arguments: SQLite names a built-in function
        # as the query writes it, sqlitefunctions.c in lower case, so these
        # are written in lower case
        'SELECT sqrt()', 'SELECT sqrt(1, 2)', 'SELECT pi(1)', 'SELECT log()',
        'SELECT log(1, 2, 3)', 'SELECT pow(2)', 'SELECT mod(1, 2, 3)',
        'CREATE TABLE m(x); INSERT INTO m VALUES (1), (4), (9.5), (16), (-1), (NULL), (\'a\')',
        'SELECT x, sqrt(x), log(x), floor(x) FROM m WHERE sqrt(x) > 1 ORDER BY log(x) DESC',
        'SELECT sum(sqrt(x)), max(ln(x)), group_concat(ceil(x), \',\') FROM m',
        'SELECT x FROM m ORDER BY mod(x, 3), x',
        # in a view, a generated column, a CHECK constraint and an index
        'CREATE VIEW v AS SELECT x, power(x, 2) AS p FROM m; SELECT * FROM v WHERE p > 10',
        'CREATE TABLE g(x, y AS (sqrt(x)), CHECK (x IS NULL OR abs(x) < pi() * 100))',
        'INSERT INTO g(x) VALUES (16), (2); SELECT x, y FROM g',
        'INSERT INTO g(x) VALUES (1000)',
        'CREATE INDEX gi ON g(log2(x)); SELECT x FROM g WHERE log2(x) = 4',
    ]
    return queries


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
        corpus = read(os.path.join(FIXTURES, 'sqlite_values.txt'))
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

    def test_regexp_is_the_releases(self):
        # The release's file, unchanged: its SHA3-256 (with the line ends
        # it was released with) is the one ORIGIN gives
        regexp = read(os.path.join(THIRDPARTY, 'libsqlite', 'ext', 'misc', 'regexp.c'))
        digest = hashlib.sha3_256(regexp.encode('utf-8')).hexdigest()
        self.assertIn(digest, read(os.path.join(THIRDPARTY, 'libsqlite', 'ORIGIN')))

    def test_the_math_functions_are_sqlites_code(self):
        # sqlitefunctions.c carries SQLite's math functions as sqlite3.c has
        # them (from its constants to the end of what
        # SQLITE_ENABLE_MATH_FUNCTIONS builds in), so they answer as
        # SQLite's would; an update of SQLite that changes them fails here
        sqlite = read(os.path.join(THIRDPARTY, 'libsqlite', 'src', 'sqlite3.c'))
        start = sqlite.index('/* Mathematical Constants */\n')
        end_marker = '#endif /* SQLITE_ENABLE_MATH_FUNCTIONS */\n'
        end = sqlite.index(end_marker, start) + len(end_marker)
        self.assertIn(sqlite[start:end], read(SQLITE_FUNCTIONS))

    def test_the_functions_are_those_of_sqlites_table(self):
        # Every math function in SQLite's table of built-in functions, for
        # the same numbers of arguments, implementation and user data (a
        # C function, or a number for logFunc, which log(B,X) does not
        # read), and regexp() and regexpi() as sqlite3_regexp_init() adds
        # them (its user data: whether to ignore case)
        sqlite = read(os.path.join(THIRDPARTY, 'libsqlite', 'src', 'sqlite3.c'))
        blocks = re.findall(r'#ifdef SQLITE_ENABLE_MATH_FUNCTIONS\n(.*?)'
                            r'#endif /\* SQLITE_ENABLE_MATH_FUNCTIONS \*/', sqlite, re.S)
        table = [b for b in blocks if 'MFUNCTION(' in b]
        self.assertEqual(len(table), 1)
        expected = {}
        for name, count, data, impl in re.findall(
                r'\bMFUNCTION\((\w+),\s*(\d+),\s*(\w+),\s*(\w+)\s*\)', table[0]):
            expected[(name, int(count))] = (impl, data)
        for name, count, data, _, impl in re.findall(
                r'(?<!M)FUNCTION\((\w+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\w+)\s*\)', table[0]):
            expected[(name, int(count))] = (impl, data)
        expected[('regexp', 2)] = ('re_sql_func', '0')
        expected[('regexpi', 2)] = ('re_sql_func', 'db')
        regexp = read(os.path.join(THIRDPARTY, 'libsqlite', 'ext', 'misc', 'regexp.c'))
        self.assertRegex(regexp, r'sqlite3_create_function\(db, "regexp", 2,[^;]*\b0, re_sql_func')
        self.assertRegex(regexp, r'sqlite3_create_function\(db, "regexpi", 2,[^;]*'
                                 r'\(void\*\)db, re_sql_func')

        ours = read(SQLITE_FUNCTIONS)
        data = {name: re.sub(r'^SQLITE_INT_TO_PTR\((\d+)\)$', r'\1', value.strip())
                .replace('NULL', '0')
                for name, value in re.findall(r'^\s*OXT_ADD_SQL_FUNCTION\((\w+), ([^;\n]+)\);$',
                                         ours, re.M)}
        actual = {}
        for name, low, high, impl in re.findall(
                r'^OXT_SQL_FUNCTION\((\w+), (\d+), (\d+), (\w+)\)$', ours, re.M):
            for count in range(int(low), int(high) + 1):
                actual[(name, count)] = (impl, data.pop(name, None) if count == int(high)
                                         else data.get(name))
        self.assertEqual(data, {}, 'added, but with no oxt_sql_ function')
        for key in expected:
            if expected[key][0] == 'logFunc' and key[1] == 2:
                expected[key] = (expected[key][0], actual.get(key, (None, None))[1])
        self.assertEqual(actual, expected)

    def test_they_are_added_for_any_number_of_arguments(self):
        # So that an extension a stack loads can add its own with a fixed
        # number while a statement runs (sqlitefunctions.c says why); the
        # compiled tests load one
        ours = read(SQLITE_FUNCTIONS)
        self.assertEqual(len(re.findall(r'sqlite3_create_function\(', ours)), 1)
        self.assertIn('rc = sqlite3_create_function(db, #zName, -1, kFlags,', ours)
        self.assertNotRegex(ours, r'sqlite3_regexp_init\(\s*\w')

    def test_the_driver_adds_them_to_every_connection(self):
        driver = read(os.path.join(THIRDPARTY, 'libsqlite', 'src', 'sqlitedataset.cpp'))
        connect = driver.split('int SqliteDatabase::connect(', 1)[1].split('\n};', 1)[0]
        self.assertRegex(connect, r'\n\s*oxt_sqlite_add_functions\(conn\);')
        # in libsqlite, which every platform builds (the web and Android
        # with it), and with SQLite's own math functions left out
        sources, defines = libsqlite_build(os.path.join(THIRDPARTY, 'libsqlite'))
        self.assertIn('src/sqlitefunctions.c', sources)
        self.assertNotIn('ext/misc/regexp.c', read(os.path.join(THIRDPARTY, 'libsqlite',
                                                                 'libsqlite.gyp')).split("'sources'")[1])
        self.assertNotIn('SQLITE_ENABLE_MATH_FUNCTIONS', defines)

    def test_asyncify_leaves_them_alone(self):
        # In the web engine they run no script, as lpad() runs none, but
        # every function that calls through a pointer, and SQLite's code
        # that calls it, is instrumented by Asyncify unless its name is in
        # the list (a larger, slower engine): the math functions call
        # libm's, and REGEXP's compiler and matcher a next-character
        # function (regexp.c names its matcher sqlite3re_match)
        tree = ast.parse(read(os.path.join(REPO, 'util', 'emscripten-javascriptify.py')))
        lists = [ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                 and any(getattr(t, 'id', None) == 'asyncify_remove' for t in n.targets)]
        self.assertEqual(len(lists), 1)
        ours = read(SQLITE_FUNCTIONS)
        regexp = read(os.path.join(THIRDPARTY, 'libsqlite', 'ext', 'misc', 'regexp.c'))
        names = {'oxt_sql_' + name for name in
                 re.findall(r'^OXT_SQL_FUNCTION\((\w+),', ours, re.M)}
        names.update(['ceilingFunc', 'logFunc', 'math1Func', 'math2Func'])
        self.assertIn('#define re_match   sqlite3re_match', regexp)
        callers = set()
        for name, body in re.findall(r'^static [^;{(]*?\b(\w+)\([^)]*\)\s*\{(.*?)^\}',
                                     regexp, re.M | re.S):
            if 'xNextChar(' in body:
                callers.add(name)
        self.assertEqual(callers, {'re_match', 're_subcompile_string'})
        names.update(['sqlite3re_match', 're_subcompile_string', 're_subcompile_re'])
        for name in sorted(names):
            with self.subTest(name=name):
                self.assertTrue(any(fnmatch.fnmatchcase(name, p) for p in lists[0]))

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
        cls.built = {}

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work)

    @classmethod
    def sqlite(cls, builtin_math=False):
        """sqlite_text (build_sqlite), built once for the class."""
        key = 'sqlite-builtin-math' if builtin_math else 'sqlite'
        if key not in cls.built:
            cls.built[key] = build_sqlite(cls.work, THIRDPARTY, builtin_math)
        return cls.built[key]

    def test_sqlite_gives_scripts_the_text_it_gave(self):
        # (on a connection with the functions the driver adds, which none
        # of these queries names)
        program = self.sqlite()
        corpus = read(os.path.join(FIXTURES, 'sqlite_values.txt'))
        actual = run(program, stdin=corpus.encode('utf-8')).decode('utf-8')
        expected = read(os.path.join(FIXTURES, 'sqlite_values.expected'))
        self.assertEqual(actual.splitlines(), expected.splitlines())

    def test_math_functions_answer_as_sqlites_own(self):
        # As SQLite's built-in math functions answer, value for value and
        # error for error, with every kind of argument, in WHERE, ORDER BY,
        # aggregates, views, generated columns, CHECK constraints and indexes
        queries = math_queries()
        ours = sqlite_answers(self.sqlite(), queries)
        sqlites = sqlite_answers(self.sqlite(builtin_math=True), queries)
        self.assertEqual(len(ours), len(queries))
        for query, mine, theirs in zip(queries, ours, sqlites):
            with self.subTest(query=query):
                self.assertEqual(mine, theirs)
        # (and the queries do reach them: a few answers by hand)
        answers = dict(zip(queries, ours))
        self.assertEqual(answers['SELECT pi(), pi() * 2, round(pi(), 4), typeof(pi())'],
                         ['2 3.14159265358979', '2 6.28318530717959', '2 3.1416', '3 real'])
        self.assertEqual(answers['SELECT SQRT(16), Pi(), LOG(2, 8), Mod(7, 3)'],
                         ['2 4.0', '2 3.14159265358979', '2 3.0', '2 1.0'])
        self.assertEqual(answers['SELECT sqrt(1, 2)'],
                         ['ERR wrong number of arguments to function sqrt()'])

    def test_regexp_answers_as_sqlites_extension(self):
        # X REGEXP Y is regexp(Y, X): Y anywhere in X, unless anchored
        cases = [
            ("'abc' REGEXP 'b'", '1 1'),
            ("'abc' REGEXP '^b'", '1 0'),
            ("'abc' REGEXP '^a.c$'", '1 1'),
            ("'abc' NOT REGEXP 'z'", '1 1'),
            ("regexp('b', 'abc')", '1 1'),
            ("'ABC' REGEXP 'b'", '1 0'),
            ("regexpi('b', 'ABC')", '1 1'),
            ("'x' REGEXP 'a|x'", '1 1'),
            ("'a1b22c333' REGEXP '^([a-z][0-9]+)+$'", '1 1'),
            (r"'2026-11-21' REGEXP '^\d{4}-\d{2}-\d{2}$'", '1 1'),
            (r"'hello world' REGEXP '\bworld\b'", '1 1'),
            (r"'helloworld' REGEXP '\bworld'", '1 0'),
            ("'colour' REGEXP '^colou?r$'", '1 1'),
            ("'caf\u00e9' REGEXP '^caf.$'", '1 1'),
            ("123 REGEXP '^12'", '1 1'),
            ("NULL REGEXP 'a'", '5 NULL'),
            ("'a' REGEXP NULL", '5 NULL'),
            # a pattern that backtracking matchers take years over: an
            # automaton, its time is the pattern's size times the text's
            ("'" + 'a' * 5000 + "!' REGEXP '^(a+)+$'", '1 0'),
            ("'abc' REGEXP '('", "ERR unmatched '('"),
            ("regexp('a')", 'ERR wrong number of arguments to function regexp()'),
        ]
        answers = sqlite_answers(self.sqlite(), ['SELECT %s' % e for e, _ in cases])
        for (expression, expected), answer in zip(cases, answers):
            with self.subTest(expression=expression[:60]):
                self.assertEqual(answer, [expected])

    def test_regexp_in_a_where_clause(self):
        answers = sqlite_answers(self.sqlite(), [
            "CREATE TABLE names(n TEXT); INSERT INTO names VALUES ('Ada'), ('bob'), "
            "('Carol'), ('Dave'), ('ann'), (NULL), ('Bea')",
            "SELECT n FROM names WHERE n REGEXP '^[A-C]' ORDER BY n",
            "SELECT count(*) FROM names WHERE regexpi('^a', n)",
            "SELECT n FROM names WHERE n NOT REGEXP 'a' ORDER BY n",
        ])
        self.assertEqual(answers, [[], ['3 Ada', '3 Bea', '3 Carol'], ['1 2'], ['3 bob']])

    def test_a_loaded_extension_keeps_its_own_functions(self):
        # A stack that loads its own log(), ceil() or REGEXP gets its own,
        # as it did before the driver added any: the extension adds them
        # while SELECT load_extension() runs, which SQLite allows because
        # the driver's take any number of arguments. sqrt(), which the
        # extension does not define, is still the driver's.
        extension = build_sqlite_extension(self.work, THIRDPARTY)
        queries = [
            "SELECT log(100), ceil(1.5), 'abc' REGEXP 'a.c', sqrt(16)",
            "SELECT load_extension('%s', 'sqlite3_sqliteextension_init')" % extension,
            "SELECT log(100), ceil(1.5), 'abc' REGEXP 'a.c', 'xa.cx' REGEXP 'a.c', sqrt(16), log(2, 8)",
            "CREATE TABLE t(s); INSERT INTO t VALUES ('abc'), ('a.c'); SELECT s FROM t WHERE s REGEXP 'a.c'",
        ]
        self.assertEqual(sqlite_answers(self.sqlite(), queries, 'extensions'), [
            ['2 2.0', '2 2.0', '1 1', '2 4.0'],
            ['5 NULL'],
            ['2 4.60517018598809', '1 2', '1 0', '1 1', '2 4.0', '2 3.0'],
            ['3 a.c'],
        ])

    def test_built_in_math_functions_would_refuse_the_extension(self):
        # Why sqlitefunctions.c adds the math functions to each connection
        # rather than building SQLite with SQLITE_ENABLE_MATH_FUNCTIONS: a
        # built-in log() has one argument, as the extension's has, and
        # SQLite refuses to replace it while the statement that loads the
        # extension runs. If this fails, a newer SQLite allows it, and the
        # reason sqlitefunctions.c gives no longer holds for built-in ones.
        extension = build_sqlite_extension(self.work, THIRDPARTY)
        answers = sqlite_answers(self.sqlite(builtin_math=True), [
            "SELECT load_extension('%s', 'sqlite3_sqliteextension_init')" % extension,
            'SELECT log(100)',
        ], 'extensions')
        self.assertEqual(answers, [
            ['ERR error during initialization: unable to delete/modify user-function '
             'due to active statements'],
            ['2 2.0'],
        ])

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
