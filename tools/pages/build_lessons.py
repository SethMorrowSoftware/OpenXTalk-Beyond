#!/usr/bin/env python3
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

"""Make the lessons of the GitHub Pages site (lessons/): a course in xTalk
from the first line to extensions in xTalk Builder, a page a lesson, with
a page that lists them all and a search of every word on every page.

  python3 tools/pages/build_lessons.py --out DIR [--with-ide] [--with-dictionary]

  DIR/index.html          the lessons' own front page (lessons/index.html):
                          the levels, a card for each lesson, the search
  DIR/<slug>/index.html   a lesson (lessons/src/NN-<slug>.html in
                          lessons/lesson.html)
  DIR/lessons.css         the pages' look, and lessons.js what they do
  DIR/search-index.js     every section of every lesson, as text, for the
                          search, which a page loads when its search box
                          is first used
  DIR/shots/<id>.png      the pictures of the stage (lessons/shots)

A lesson is a fragment of HTML in lessons/src, named NN-<slug>.html (NN
puts them in order), that begins with a comment of its own with a line for
each of title, level (beginner, intermediate, advanced or expert, in that
order through the files), minutes, summary and words (the xTalk words it
teaches, comma-separated):

  <!--
  title: Variables
  level: beginner
  minutes: 8
  summary: Give values names, and change them.
  words: put, into, add
  -->

Each <h2> has an id, which the page's contents and the search link to.
An example is a <figure class="example"> with its code in
<pre class="code"><code> and what it puts in <pre class="out">, as text
(examples() below says what one needs); this script colours the code and
adds the bar with its Copy button, so the source stays the code as it
runs. tools/ci/lessons_check.py runs every example with the xTalk
Academy's runner on an engine and compares what it puts with the page.

An example that makes something to see (a button, a field, a drawing)
can show the stage under it, the window the playground shows what the
code made in: data-shot on its figure says what the picture shows, for a
reader who cannot see it, and the picture is lessons/shots/<its id>.png,
which the engine took when it ran the example (lessons_check.py
--update-shots) and the check compares with what the engine draws each
time. The build refuses an example with no picture, and a picture with
no example.

A card the reader builds. A beginner draws controls with the Tools
palette and names them in the Property Inspector, so a lesson about
controls says how to build the card, in a <div class="build" id="build-...">
of steps, and its examples work on that card (data-card="build-..."):
lines for the Message Box (data-in="message"), or the script of one of
its controls (data-script='button "Go"') that the reader clicks in Run
mode (data-click, the controls clicked in order, separated by ";"). The
build box also has, in <pre class="setup">, the xTalk that makes the same
card, as the palette makes it: the check runs it before the example (and
installs the script and clicks), and the page leaves it out. Such an
example's Output is what the Message Box shows after each line or click.

build_pages.py makes the lessons with every site; the Web IDE and the
Dictionary are linked only when the site has them (the IDE and DICTIONARY
blocks of the templates, as on the front page).
"""

import argparse
import html
import html.parser
import json
import os
import re
import shutil
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, 'lessons')
# The pictures of the stage: shots/<example id>.png beside src/, each taken
# by the engine (tools/ci/lessons_check.py --update-shots) at twice the
# stage's size, and shown at its size
SHOTS = 'shots'

# The levels, in their order: (key, name, title, what it covers)
LEVELS = (
    ('beginner', 'Beginner', 'First steps',
     'Values, variables, decisions, loops, text and your own handlers: everything a first program needs.'),
    ('intermediate', 'Intermediate', 'Stacks, objects and data',
     'Cards, buttons and fields, the events they send and the message path, lists, arrays and dates.'),
    ('advanced', 'Advanced', 'Bigger programs',
     'Errors and debugging, patterns and Unicode, files, timers, behaviors, libraries and algorithms.'),
    ('expert', 'Expert', 'Beyond',
     'Code that runs code, binary data, JSON, the internet and databases, speed, and extensions of your own.'),
)
LEVEL_KEYS = [lv[0] for lv in LEVELS]
HEADER_KEYS = ('title', 'level', 'minutes', 'summary', 'words')
SLUG = re.compile(r'^[0-9]{2}-([a-z0-9]+(?:-[a-z0-9]+)*)\.html$')
# The parts a template may leave out, with what each one links
PARTS = ('IDE', 'DICTIONARY')
MODES = ('output', 'runs', 'error', 'compile', 'builder')
# The externals the IDE loads as it starts (Externals/Externals.txt), which
# an example may need as "external:<name>"
EXTERNALS = {'revdb', 'revxml', 'revzip'}
# The ids lesson.html gives its own elements, which a lesson cannot use
RESERVED = {'lesson', 'words', 'search-results'}
# A card the reader builds with the Tools palette, and the xTalk that
# makes it the same way for the check (left out of the page)
BUILD = re.compile(r'<div class="build" id="([^"]*)">(.*?)</div>', re.S)
SETUP = re.compile(r'\s*<pre class="setup">(.*?)</pre>', re.S)
# What a palette example names: a control or the card, as a script does
OBJECT = re.compile(r'^(button|field|graphic|image|scrollbar|player|group) "[^"]+"$|^this card$')
# A line that does not stand alone in the Message Box's single line
BLOCK_LINE = re.compile(r'^\s*(on|end|repeat|else|function|command|switch|case|default|try|catch|finally)\b'
                        r'|\bthen\s*$|\\\s*$')
# A link in a lesson goes to another lesson (../<slug>/, with #<id> for a
# place in it), to a place in the same lesson (#<id>), or out (https:).
# The build checks that each lesson and id it names is there, so a lesson
# renamed or a heading's id changed cannot leave a link going nowhere.
LINK = re.compile(r'<a\s[^>]*?href="([^"]*)"')
LESSON_LINK = re.compile(r'^\.\./([a-z0-9]+(?:-[a-z0-9]+)*)/(?:#([A-Za-z0-9_-]+))?$')


class BuildError(Exception):
    pass


################################################################################
#
# The examples
#

class Examples(html.parser.HTMLParser):
    """A page's examples: each <figure class="example">, with its
    attributes, its code (the text of <pre class="code">) and its output
    (the text of <pre class="out">). Markup inside either is an error: a
    lesson has its code there as text (this script colours it)."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found, self.problems = [], []
        self.figure = None   # the example being read
        self.depth = 0       # figures open inside it
        self.into = None     # 'code' or 'out' while inside that <pre>
        self.pre_depth = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = (attrs.get('class') or '').split()
        if self.into:
            if tag != 'code' or self.into != 'code' or self.pre_depth > 1:
                self.problems.append('%s: <%s> inside its %s' % (self.figure['id'], tag, self.into))
            self.pre_depth += 1
            return
        if tag == 'figure' and 'example' in classes:
            if self.figure is not None:
                self.problems.append('%s: an example inside an example' % self.figure['id'])
                return
            self.figure = {'id': attrs.get('id') or '', 'run': attrs.get('data-run') or '',
                           'line': attrs.get('data-line') or '', 'wait': attrs.get('data-wait') or '',
                           'needs': (attrs.get('data-needs') or '').split(), 'code': None, 'out': None,
                           'shot': attrs.get('data-shot'), 'at': self.getpos()[0],
                           'card': attrs.get('data-card') or '', 'script': attrs.get('data-script') or '',
                           'click': [c.strip() for c in (attrs.get('data-click') or '').split(';') if c.strip()],
                           'in': attrs.get('data-in') or ''}
            self.depth = 1
            return
        if self.figure is not None:
            if tag == 'figure':
                self.depth += 1
            elif tag == 'pre' and ('code' in classes or 'out' in classes):
                self.into = 'code' if 'code' in classes else 'out'
                if self.figure[self.into] is not None:
                    self.problems.append('%s: two <pre class="%s">' % (self.figure['id'], self.into))
                self.figure[self.into] = ''
                self.pre_depth = 1

    def handle_endtag(self, tag):
        if self.into:
            self.pre_depth -= 1
            if self.pre_depth == 0:
                self.into = None
            return
        if self.figure is not None and tag == 'figure':
            self.depth -= 1
            if self.depth == 0:
                self.found.append(self.figure)
                self.figure = None

    def handle_data(self, data):
        if self.into:
            self.figure[self.into] += data


def pre_text(text):
    """A <pre>'s text as the reader sees it: a newline straight after
    <pre> is not shown, nor the one before </pre>."""
    if text.startswith('\n'):
        text = text[1:]
    if text.endswith('\n'):
        text = text[:-1]
    return text


def builds(text):
    """The cards a page's reader builds: {id: the xTalk that makes it},
    and the problems with them. Each is a <div class="build"> with an id
    of build- and words, the steps as a list, and one <pre class="setup">."""
    found, problems = {}, []
    for ident, inner in BUILD.findall(text):
        if not re.match(r'^build-[a-z0-9]+(-[a-z0-9]+)*$', ident):
            problems.append('%s: a build\'s id is build- and lower-case words with "-"' % (ident or 'a build'))
        if ident in found:
            problems.append('%s: the id is used twice' % ident)
        setups = SETUP.findall(inner)
        if len(setups) != 1 or not pre_text(html.unescape(setups[0])).strip():
            problems.append('%s: a build has one <pre class="setup">, the xTalk that makes its card' % ident)
        if '<ol>' not in inner:
            problems.append('%s: a build has its steps as a list (<ol>)' % ident)
        found[ident] = pre_text(html.unescape(setups[0])) if setups else ''
    if text.count('<div class="build"') != len(BUILD.findall(text)):
        problems.append('a <div class="build"> with no id, or with another <div> inside it')
    return found, problems


def examples(text, builders=None, cards=None):
    """The examples of a page's text, checked for what each needs: a list
    of dicts (id, run, line, wait, needs, code, out), in the page's order.
    builders: the ids of the xTalk Builder examples an example may need
    (those of this text, with None). Raises BuildError with every problem
    found.

    cards: the cards the page's reader builds ({id: setup}, builds());
    those of text when None. An example with data-card has the card's
    setup as its 'setup'.

    data-run is how the example is checked (tools/ci/lessons_check.py):
      output   it runs to its end, and what it puts is exactly its Output
      runs     it runs to its end, and puts as many lines as its Output
               (values that differ from run to run: a random number)
      error    it stops with an error (on line data-line, if given)
      compile  handlers only, which compile as an object's script and are
               not run (a dialog, a click, the internet)
      builder  an xTalk Builder module, which lc-compile compiles
    data-wait is the seconds to wait after the run for what a timer puts,
    and data-needs the extensions it uses ("builder:<id>" for a module of
    the lessons'). data-shot, on an example that runs, says that its page
    shows the stage as the run left it, a picture the engine takes (and
    the check compares), and is the picture's words for a reader who
    cannot see it. An external the IDE loads as it starts, such as revdb
    for the database commands, is "external:<name>" in data-needs."""
    parser = Examples()
    parser.feed(text)
    parser.close()
    problems = list(parser.problems)
    found = parser.found
    if builders is None:
        builders = {e['id'] for e in found if e['run'] == 'builder'}
    if cards is None:
        cards, more = builds(text)
        problems += more
    seen = set()
    for e in found:
        where = e['id'] or 'the example at line %d' % e['at']
        if not re.match(r'^ex-[a-z0-9]+(-[a-z0-9]+)*$', e['id']):
            problems.append('%s: an example\'s id is ex- and lower-case words with "-"' % where)
        if e['id'] in seen:
            problems.append('%s: the id is used twice' % where)
        seen.add(e['id'])
        if e['run'] not in MODES:
            problems.append('%s: data-run is %r, not one of %s' % (where, e['run'], ', '.join(MODES)))
        if e['code'] is None or not pre_text(e['code']).strip():
            problems.append('%s: no <pre class="code">' % where)
        else:
            e['code'] = pre_text(e['code'])
            if '\t' in e['code']:
                problems.append('%s: a tab in its code (indent with three spaces)' % where)
        if e['out'] is not None:
            e['out'] = pre_text(e['out'])
        if e['run'] in ('output', 'runs') and e['out'] is None:
            problems.append('%s: data-run="%s" and no <pre class="out">' % (where, e['run']))
        if e['run'] in ('compile', 'builder', 'error') and e['out'] is not None:
            problems.append('%s: data-run="%s" shows no output' % (where, e['run']))
        if e['line'] and (e['run'] != 'error' or not e['line'].isdigit()):
            problems.append('%s: data-line is a line number, for data-run="error"' % where)
        if e['wait']:
            try:
                ok = 0 < float(e['wait']) <= 10
            except ValueError:
                ok = False
            if not ok or e['run'] not in ('output', 'runs'):
                problems.append('%s: data-wait is seconds (up to 10) for an example that runs' % where)
        if e['shot'] is not None:
            if e['run'] not in ('output', 'runs', 'error'):
                problems.append('%s: data-shot is for an example that runs' % where)
            if len(e['shot'].split()) < 3:
                problems.append('%s: data-shot says what the picture shows, in a few words' % where)
        for need in e['needs']:
            if need.startswith('builder:'):
                if need[len('builder:'):] not in builders:
                    problems.append('%s: needs %s, which is not an xTalk Builder example' % (where, need))
            elif need.startswith('external:'):
                if need[len('external:'):] not in EXTERNALS:
                    problems.append('%s: needs %s, which is not one of the externals the IDE loads (%s)'
                                    % (where, need, ', '.join(sorted(EXTERNALS))))
            elif not re.match(r'^[a-z0-9]+(\.[a-z0-9-]+)+$', need):
                problems.append('%s: needs %r, which is not an extension\'s id' % (where, need))
        problems += palette_problems(e, where, cards)
    if problems:
        raise BuildError('\n'.join(problems))
    return found


def palette_problems(e, where, cards):
    """What is wrong with how example e uses a card the reader builds
    (and its 'setup', the card's xTalk, is set)."""
    problems = []
    e['setup'] = ''
    if e['card']:
        if e['card'] not in cards:
            problems.append('%s: data-card %s is not a build of this page' % (where, e['card']))
        else:
            e['setup'] = cards[e['card']]
    for name in ([e['script']] if e['script'] else []) + e['click']:
        if not OBJECT.match(name):
            problems.append('%s: %r is not a control of the card (such as button "Go") or this card' % (where, name))
    if (e['script'] or e['click']) and not e['card']:
        problems.append('%s: data-script and data-click are for a card the reader builds (data-card)' % where)
    if e['in'] not in ('', 'message'):
        problems.append('%s: data-in is "message" (lines for the Message Box) or nothing' % where)
    if e['in'] and e['script']:
        problems.append('%s: an example is lines for the Message Box or an object\'s script, not both' % where)
    if e['script'] and e['run'] not in ('output', 'runs', 'compile'):
        problems.append('%s: an object\'s script is checked by what a click puts (output, runs) or compiles' % where)
    if e['in'] and e['run'] not in ('output', 'runs', 'error'):
        problems.append('%s: lines for the Message Box run (output, runs or error)' % where)
    if e['card'] and e['run'] == 'error' and not e['in']:
        problems.append('%s: a mistake on a card the reader builds is lines for the Message Box' % where)
    if e['in'] and e['code']:
        for n, line in enumerate(e['code'].split('\n'), 1):
            if BLOCK_LINE.search(line):
                problems.append('%s: line %d does not stand alone in the Message Box: make it a script' % (where, n))
    # the Message Box shows one value at a time: what the last put put
    # after each click
    if e['script'] and e['run'] == 'output' and e['out'] is not None:
        if len(e['out'].split('\n')) > max(1, len(e['click'])):
            problems.append('%s: the Message Box shows one value a click: an Output of at most %d line(s)'
                            % (where, max(1, len(e['click']))))
    if e['script'] and e['run'] in ('output', 'runs') and not e['click']:
        problems.append('%s: an object\'s script that runs needs data-click, the controls the reader clicks' % where)
    return problems


################################################################################
#
# Colouring code
#

# The words coloured as xTalk's own: its control structures and commands
# (k), and the words that name values, properties and chunks (b). A word
# not here is left plain: colouring is a help to the eye, never a claim
# about the language, and the Dictionary is the reference.
KEYWORDS = set('''
on end if then else repeat with for each while until forever times exit next return function command
private local global constant switch case break default try catch finally throw pass send to in of
dispatch call do put into after before set get add subtract multiply divide from by delete create
go answer ask sort filter split combine replace start stop using wait messages cancel open close read
write accept connections socket file folder url load post visual effect lock unlock show hide move
getprop setprop insert script back front and or not is among contains begins ends there a an as
numeric descending ascending text items lines without matching regex pattern union intersect
recursively library handler variable metadata public returns use optional out inout'''.split())
BUILTINS = set('''
the me it target empty true false return quote space tab comma cr lf colon slash backslash eof pi
char chars word words item items line lines key keys element elements byte bytes codepoint codepoints
number short long name id result params paramcount param this card cards stack stacks button buttons
field fields graphic graphics image images group groups control controls value length offset
itemdelimiter linedelimiter casesensitive date time seconds milliseconds ticks random round trunc abs sqrt
max min sum average format merge toupper tolower numtochar chartonum numtocodepoint codepointtonum
textencode textdecode base64encode base64decode binaryencode binarydecode messagedigest matchtext
matchchunk replacetext urlencode urldecode specialfolderpath files folders defaultfolder platform
environment version label rect loc width height top left bottom right visible backgroundcolor
textcolor textstyle textsize textfont htmltext styledtext hilite behavior pendingmessages
string number boolean list array data any nothing pointer'''.split())
DECLARES = {'on', 'command', 'function', 'getprop', 'setprop', 'before', 'after', 'handler'}
TOKEN = re.compile(r'''
    (?P<blk>/\*.*?\*/)
  | (?P<str>"[^"\n]*"?)
  | (?P<cmt>--[^\n]*|//[^\n]*|\#[^\n]*)
  | (?P<num>(?<![\w.])\d+(?:\.\d+)?(?![\w.]))
  | (?P<word>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<other>.|\n)''', re.S | re.X)


def highlight(code):
    """The code as HTML, its parts in spans: c a comment, s a string, n a
    number, k one of xTalk's words, b a built-in value, h the name a
    handler is given. Without the spans it is exactly the code, escaped."""
    out = []
    declared = False   # the last word began a handler (or ended one)
    for m in TOKEN.finditer(code):
        kind, text = m.lastgroup, m.group()
        esc = html.escape(text, quote=False)
        if kind == 'word':
            low = text.lower()
            if declared:
                out.append('<span class="h">%s</span>' % esc)
                declared = False
                continue
            if low in KEYWORDS:
                out.append('<span class="k">%s</span>' % esc)
                # "on mouseUp", "end mouseUp", "private function f"
                if low in DECLARES or low == 'end':
                    declared = True
                continue
            out.append('<span class="b">%s</span>' % esc if low in BUILTINS else esc)
            continue
        if kind == 'other':
            if text not in ' \t':
                declared = False
            out.append(esc)
            continue
        declared = False
        cls = {'blk': 'c', 'cmt': 'c', 'str': 's', 'num': 'n'}[kind]
        out.append('<span class="%s">%s</span>' % (cls, esc))
    return ''.join(out)


################################################################################
#
# The lessons
#

def read_header(text, where):
    m = re.match(r'\s*<!--\n(.*?)\n-->\n', text, re.S)
    if not m:
        raise BuildError('%s: no header (a comment with title, level, minutes, summary, words)' % where)
    header = {}
    for line in m.group(1).split('\n'):
        key, sep, value = line.partition(':')
        key = key.strip()
        if not sep or key not in HEADER_KEYS:
            raise BuildError('%s: the header line %r is not one of %s' % (where, line, ', '.join(HEADER_KEYS)))
        if key in header:
            raise BuildError('%s: %s twice in the header' % (where, key))
        header[key] = value.strip()
    missing = [k for k in HEADER_KEYS if not header.get(k)]
    if missing:
        raise BuildError('%s: the header has no %s' % (where, ', '.join(missing)))
    if header['level'] not in LEVEL_KEYS:
        raise BuildError('%s: the level %r is not one of %s' % (where, header['level'], ', '.join(LEVEL_KEYS)))
    if not header['minutes'].isdigit():
        raise BuildError('%s: minutes is a number' % where)
    return header, text[m.end():]


class Headings(html.parser.HTMLParser):
    """The <h2>s of a lesson (id and text), every id in it, and its text."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.headings, self.ids, self.problems = [], [], []
        self.sections = [['', []]]   # [heading id, [text]] for the search
        self.in_h2 = None
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get('id'):
            self.ids.append(attrs['id'])
        if tag == 'h2':
            if not attrs.get('id'):
                self.problems.append('an <h2> without an id')
            self.in_h2 = [attrs.get('id') or '', '']
        elif tag in ('h1', 'script', 'style'):
            self.problems.append('a <%s> (a lesson has its title from its header, and no script or style)' % tag)

    def handle_endtag(self, tag):
        if tag == 'h2' and self.in_h2 is not None:
            self.headings.append((self.in_h2[0], ' '.join(self.in_h2[1].split())))
            self.sections.append([self.in_h2[0], []])   # the heading is the row's h
            self.in_h2 = None

    def handle_data(self, data):
        if self.in_h2 is not None:
            self.in_h2[1] += data
        else:
            self.sections[-1][1].append(data)


def png_size(path):
    """The width and height of the PNG file path, or None when it is not
    one."""
    with open(path, 'rb') as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        return None
    return struct.unpack('>II', head[16:24])


def read_lessons(source=os.path.join(SOURCE, 'src'), every_level=True):
    """The lessons, in order: dicts with slug, file, number, the header's
    fields, words (a list), body, headings [(id, text)], examples and
    sections [(heading id, heading, text)] for the search. An example
    with a shot has shot_file, the path of its picture (beside source, in
    shots/; it may not be there yet), and shot_size, the picture's size
    when it is a PNG, else None. every_level False lets a level have no
    lessons (while a level is being written)."""
    names = sorted(n for n in os.listdir(source) if n.endswith('.html'))
    lessons, slugs, problems = [], set(), []
    every_example = {}
    builders = set()
    for name in names:
        m = SLUG.match(name)
        if not m:
            problems.append('%s: a lesson is named NN-<slug>.html' % name)
            continue
        with open(os.path.join(source, name), encoding='utf-8') as f:
            text = f.read()
        try:
            header, body = read_header(text, name)
        except BuildError as e:
            problems.append(str(e))
            continue
        cards, more = builds(body)
        problems += ['%s: %s' % (name, p) for p in more]
        body = SETUP.sub('', body)
        lesson = dict(header)
        lesson.update(slug=m.group(1), file=name, number=len(lessons) + 1, body=body, cards=cards,
                      words=[w.strip() for w in header['words'].split(',') if w.strip()])
        if lesson['slug'] in slugs:
            problems.append('%s: the slug %s is used twice' % (name, lesson['slug']))
        slugs.add(lesson['slug'])
        h = Headings()
        h.feed(body)
        h.close()
        problems += ['%s: %s' % (name, p) for p in h.problems]
        taken = sorted(set(h.ids) & RESERVED)
        if taken:
            problems.append('%s: the ids %s are the page\'s own' % (name, ', '.join(taken)))
        dup = sorted(set(i for i in h.ids if h.ids.count(i) > 1))
        if dup:
            problems.append('%s: the ids %s are used twice' % (name, ', '.join(dup)))
        lesson['headings'] = h.headings
        lesson['ids'] = set(h.ids)
        titles = dict(h.headings)
        lesson['sections'] = [(sid, titles.get(sid, ''), ' '.join(' '.join(parts).split()))
                              for sid, parts in h.sections]
        lessons.append(lesson)
        for e in Examples_all(body):
            if e.get('run') == 'builder':
                builders.add(e.get('id'))
    for lesson in lessons:
        try:
            lesson['examples'] = examples(lesson['body'], builders, lesson['cards'])
        except BuildError as e:
            problems += ['%s: %s' % (lesson['file'], p) for p in str(e).split('\n')]
            lesson['examples'] = []
        for e in lesson['examples']:
            if e['shot'] is not None:
                e['shot_file'] = os.path.join(os.path.dirname(os.path.abspath(source)), SHOTS, e['id'] + '.png')
                e['shot_size'] = png_size(e['shot_file']) if os.path.isfile(e['shot_file']) else None
            if e['id'] in every_example:
                problems.append('%s: the example id %s is also in %s' % (lesson['file'], e['id'],
                                                                         every_example[e['id']]))
            every_example[e['id']] = lesson['file']
    problems += links(lessons)
    order = [LEVEL_KEYS.index(lesson['level']) for lesson in lessons]
    if order != sorted(order):
        problems.append('the lessons are not in the order of their levels (%s)' % ', '.join(LEVEL_KEYS))
    for key in (LEVEL_KEYS if every_level else ()):
        if lessons and not any(lesson['level'] == key for lesson in lessons):
            problems.append('no lesson at the level %s' % key)
    if not lessons and not problems:
        problems.append('no lessons in %s' % source)
    if problems:
        raise BuildError('\n'.join(problems))
    return lessons


def links(lessons):
    """The problems with the lessons' links: each must name a lesson that
    is there and, after #, an id that is in that lesson."""
    by_slug = {lesson['slug']: lesson for lesson in lessons}
    problems = []
    for lesson in lessons:
        for href in LINK.findall(lesson['body']):
            href = html.unescape(href)
            where = '%s: the link %s' % (lesson['file'], href)
            if href.startswith('https://'):
                continue
            if href.startswith('#'):
                if href[1:] not in lesson['ids']:
                    problems.append('%s goes to no id of this lesson' % where)
                continue
            m = LESSON_LINK.match(href)
            if not m:
                problems.append('%s is not ../<slug>/, ../<slug>/#<id>, #<id> or https:' % where)
            elif m.group(1) == lesson['slug']:
                problems.append('%s is to this lesson (link #<id> instead)' % where)
            elif m.group(1) not in by_slug:
                problems.append('%s goes to no lesson' % where)
            elif m.group(2) and m.group(2) not in by_slug[m.group(1)]['ids']:
                problems.append('%s goes to no id of %s' % (where, by_slug[m.group(1)]['file']))
    return problems


def Examples_all(body):
    p = Examples()
    p.feed(body)
    p.close()
    return p.found


################################################################################
#
# The pages
#

EXAMPLE = re.compile(r'(<figure class="example"[^>]*>)(.*?)(</figure>)', re.S)
BAR_LABEL = {
    'output': ('Example', 'Run it in the playground'),
    'runs': ('Example', 'Run it in the playground'),
    'error': ('A mistake', 'It stops with an error'),
    'compile': ('Script', 'Put it in an object\'s script'),
    'builder': ('xTalk Builder', 'A module: Tools &gt; Extension Builder'),
}
OUT_LABEL = {
    'output': 'Output',
    'runs': 'Output <small>(yours will differ: it changes from run to run)</small>',
}
COPY = ('<button class="copy" type="button" aria-label="Copy the code"><svg viewBox="0 0 24 24" aria-hidden="true">'
        '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 '
        '2 2h2"/></svg><span>Copy</span></button>')


def decorate(body, lesson):
    """The lesson's body with its examples ready to read: each code block
    coloured, under a bar with what it is and a Copy button, and its
    output labelled."""
    by_id = {e['id']: e for e in lesson['examples']}

    def one(m):
        head, inner, tail = m.groups()
        ident = re.search(r'\bid="([^"]+)"', head).group(1)
        e = by_id[ident]
        kind, note = BAR_LABEL[e['run']]
        if e['run'] == 'error' and e['line']:
            note = 'It stops with an error on line %s' % e['line']
        if e['in'] == 'message':
            kind, note = 'Message Box', 'Type each line in the Message Box and press Return'
            if e['run'] == 'error':
                note = 'It stops with an error'
        elif e['script']:
            kind = 'Script'
            note = 'The script of %s' % html.escape(e['script'])
            if e['click']:
                clicked = []
                for name in e['click']:
                    if clicked and clicked[-1][0] == name:
                        clicked[-1][1] += 1
                    else:
                        clicked.append([name, 1])
                note += ', then in Run mode click %s' % ', then '.join(
                    ('it' if n == e['script'] else html.escape(n)) + {1: '', 2: ' twice'}.get(k, ' %d times' % k)
                    for n, k in clicked)
        bar = ('<div class="ex-bar"><span class="ex-kind">%s</span><span class="ex-note">%s</span>%s</div>'
               % (kind, note, COPY))
        code = re.search(r'<pre class="code"><code>.*?</code></pre>', inner, re.S)
        inner = (inner[:code.start()] + bar + '<pre class="code"><code>%s</code></pre>' % highlight(e['code'])
                 + inner[code.end():])
        if e['out'] is not None:
            label = OUT_LABEL[e['run']]
            if e['card'] or e['in']:
                label = ('Message Box <small>(%s)</small>' % ('after each click' if len(e['click']) > 1 else
                                                               'what it shows' if e['script'] else
                                                               'what each line shows'))
            inner = inner.replace('<pre class="out">', '<div class="out-bar">%s</div><pre class="out">'
                                  % label, 1)
        if e['shot'] is not None:
            inner += stage_html(e)
        cls = 'example run-%s' % e['run']
        head = head.replace('class="example"', 'class="%s"' % cls, 1)
        return head + inner + tail

    def build(m):
        return ('<div class="build" id="%s"><div class="build-bar"><svg viewBox="0 0 24 24" aria-hidden="true">'
                '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z"/>'
                '</svg>Build it <small>with the Tools palette and the Property Inspector</small></div>%s</div>'
                % m.groups())

    return BUILD.sub(build, EXAMPLE.sub(one, body))


def stage_html(e):
    """The picture of the stage under an example: the window the
    playground shows what the code made in (its title is the Academy's),
    or the card the reader built, as the engine drew it when the check
    ran the example."""
    width, height = e['shot_size']
    if e['card']:
        bar, title = 'Your card <small>as the OXT-Beyond engine draws it</small>', 'My Stack'
    else:
        bar, title = 'Stage <small>what the code made, as the OXT-Beyond engine draws it</small>', \
            'Stage: what your code made'
    return ('<div class="stage-bar">%s</div>'
            '<div class="stage"><div class="window"><div class="titlebar" aria-hidden="true"><i></i><i></i><i></i>'
            '<span>%s</span></div>'
            '<img src="../%s/%s.png" alt="%s" width="%d" height="%d" loading="lazy" decoding="async"></div></div>'
            % (bar, title, SHOTS, e['id'], html.escape(e['shot'], quote=True), width // 2, height // 2))


def shots(lessons, source):
    """The pictures the lessons show, [(example id, file)]; a BuildError
    for one that is missing or not a PNG, and for a picture no example
    shows."""
    wanted, problems = [], []
    for lesson in lessons:
        for e in lesson['examples']:
            if e['shot'] is None:
                continue
            if not os.path.isfile(e['shot_file']):
                problems.append('%s: %s has no picture %s/%s.png (take it with tools/ci/lessons_check.py '
                                '--update-shots)' % (lesson['file'], e['id'], SHOTS, e['id']))
            elif e['shot_size'] is None:
                problems.append('%s: %s/%s.png is not a PNG' % (lesson['file'], SHOTS, e['id']))
            else:
                wanted.append((e['id'], e['shot_file']))
    folder = os.path.join(source, SHOTS)
    names = {i + '.png' for i, _ in wanted} | {e['id'] + '.png' for x in lessons for e in x['examples']
                                               if e['shot'] is not None}
    for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if name not in names:
            problems.append('%s/%s is a picture no example shows' % (SHOTS, name))
    if problems:
        raise BuildError('\n'.join(problems))
    return wanted


def keep_parts(page, parts, where):
    """The page without the blocks of the parts the site does not have."""
    for key in PARTS:
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        while start in page:
            at = page.index(start)
            if end not in page[at:]:
                raise BuildError('%s has a %s with no %s after it' % (where, start, end))
            stop = page.index(end, at)
            if key in parts:
                page = page[:at] + page[at + len(start):stop] + page[stop + len(end):]
            else:
                page = page[:at] + page[stop + len(end):]
    return page


def level_of(key):
    return LEVELS[LEVEL_KEYS.index(key)]


def sidebar(lessons, current):
    """Every lesson by level, the current one open at its sections."""
    out = []
    for key, name, title, _ in LEVELS:
        items = []
        for lesson in lessons:
            if lesson['level'] != key:
                continue
            here = lesson is current
            items.append('<li%s><a href="../%s/"%s><span class="num">%d</span>%s</a>%s</li>' % (
                ' class="here"' if here else '', lesson['slug'], ' aria-current="page"' if here else '',
                lesson['number'], html.escape(lesson['title']),
                ('<ol class="toc">%s</ol>' % ''.join('<li><a href="#%s">%s</a></li>' % (sid, html.escape(text))
                                                     for sid, text in lesson['headings'])) if here else ''))
        open_attr = ' open' if current['level'] == key else ''
        out.append('<details class="lv lv-%s"%s><summary><span class="dot"></span>%s <small>%s</small></summary>'
                   '<ol>%s</ol></details>' % (key, open_attr, name, html.escape(title), ''.join(items)))
    return '\n'.join(out)


def neighbour(lesson, rel):
    if lesson is None:
        return '<span></span>'
    return ('<a class="step %s" href="../%s/"><small>%s · Lesson %d</small><b>%s</b></a>'
            % (rel, lesson['slug'], 'Next' if rel == 'next' else 'Previous', lesson['number'],
               html.escape(lesson['title'])))


def words_html(lesson):
    return ''.join('<a class="word" href="../?q=%s"><code>%s</code></a>'
                   % (html.escape(w, quote=True), html.escape(w)) for w in lesson['words'])


def fill(page, values, where):
    for key, value in values.items():
        token = '@%s@' % key
        if token not in page:
            raise BuildError('%s has no %s' % (where, token))
        page = page.replace(token, value)
    left = re.findall(r'@[A-Z_]+@', page)
    if left:
        raise BuildError('%s: nothing fills %s' % (where, ', '.join(sorted(set(left)))))
    return page


def lesson_page(template, lessons, lesson, parts):
    i = lessons.index(lesson)
    key, name, title, _ = level_of(lesson['level'])
    page = keep_parts(template, parts, 'lessons/lesson.html')
    return fill(page, {
        'TITLE': html.escape(lesson['title']),
        'SUMMARY': html.escape(lesson['summary']),
        'LEVEL': key,
        'LEVEL_NAME': name,
        'LEVEL_TITLE': html.escape(title),
        'NUMBER': str(lesson['number']),
        'COUNT': str(len(lessons)),
        'MINUTES': lesson['minutes'],
        'EXAMPLES': '%d example%s' % (len(lesson['examples']), '' if len(lesson['examples']) == 1 else 's'),
        'SIDEBAR': sidebar(lessons, lesson),
        'BODY': decorate(lesson['body'], lesson),
        'WORDS': words_html(lesson),
        'PREV': neighbour(lessons[i - 1] if i > 0 else None, 'prev'),
        'NEXT': neighbour(lessons[i + 1] if i + 1 < len(lessons) else None, 'next'),
    }, 'lessons/lesson.html')


def hub_page(template, lessons, parts):
    groups = []
    for n, (key, name, title, blurb) in enumerate(LEVELS):
        cards = []
        for lesson in (x for x in lessons if x['level'] == key):
            count = len(lesson['examples'])
            cards.append(
                '<a class="lesson-card" href="%s/" data-level="%s">'
                '<span class="num">%d</span>'
                '<span class="body"><b>%s</b><span class="sum">%s</span>'
                '<span class="meta">%s min · %d example%s</span></span></a>'
                % (lesson['slug'], key, lesson['number'], html.escape(lesson['title']),
                   html.escape(lesson['summary']), lesson['minutes'], count, '' if count == 1 else 's'))
        groups.append(
            '<section class="level lv-%s" id="%s" data-level="%s">\n'
            '  <header class="level-head"><span class="badge">Level %d</span>'
            '<h2>%s <small>%s</small></h2><p>%s</p></header>\n'
            '  <div class="lesson-grid">\n    %s\n  </div>\n</section>'
            % (key, key, key, n + 1, name, html.escape(title), html.escape(blurb), '\n    '.join(cards)))
    page = keep_parts(template, parts, 'lessons/index.html')
    return fill(page, {
        'LESSON_COUNT': str(len(lessons)),
        'EXAMPLE_COUNT': str(sum(len(x['examples']) for x in lessons)),
        'LEVEL_LIST': '\n'.join(groups),
        'FIRST': lessons[0]['slug'],
    }, 'lessons/index.html')


def search_index(lessons):
    """Every section of every lesson, for the search: a script that sets
    window.OXT_LESSONS to [{u: its address from the lessons' folder,
    t: the lesson's title, h: the section's heading, l: the level,
    n: the lesson's number, w: its words, s: its summary, x: its text}]."""
    rows = []
    for lesson in lessons:
        for sid, heading, text in lesson['sections']:
            if not text and not heading:
                continue
            rows.append({'u': '%s/%s' % (lesson['slug'], ('#' + sid) if sid else ''), 't': lesson['title'],
                         'h': heading, 'l': lesson['level'], 'n': lesson['number'],
                         'w': ' '.join(lesson['words']) if not sid else '', 's': lesson['summary'] if not sid else '',
                         'x': text})
    data = json.dumps(rows, ensure_ascii=True, separators=(',', ':'))
    # (</ in a string could end a <script> that held it; this one is a
    # file, but the same text is safe anywhere)
    data = data.replace('</', '<\\/')
    return '/* The lessons\' search: tools/pages/build_lessons.py */\nwindow.OXT_LESSONS=%s;\n' % data


def build(target, parts=(), source=SOURCE):
    """Writes the lessons to target (new or empty). parts: the parts of
    the site there to link (IDE, DICTIONARY). Returns (lessons, examples)."""
    unknown = set(parts) - set(PARTS)
    if unknown:
        raise BuildError('unknown parts %s' % ', '.join(sorted(unknown)))
    lessons = read_lessons(os.path.join(source, 'src'))
    pictures = shots(lessons, source)
    if os.path.exists(target) and os.listdir(target):
        raise BuildError('%s is not empty' % target)
    os.makedirs(target, exist_ok=True)
    with open(os.path.join(source, 'lesson.html'), encoding='utf-8') as f:
        template = f.read()
    with open(os.path.join(source, 'index.html'), encoding='utf-8') as f:
        hub = f.read()
    for lesson in lessons:
        os.makedirs(os.path.join(target, lesson['slug']))
        with open(os.path.join(target, lesson['slug'], 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(lesson_page(template, lessons, lesson, set(parts)))
    with open(os.path.join(target, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(hub_page(hub, lessons, set(parts)))
    for name in ('lessons.css', 'lessons.js'):
        shutil.copyfile(os.path.join(source, name), os.path.join(target, name))
    if pictures:
        os.makedirs(os.path.join(target, SHOTS))
    for ident, path in pictures:
        shutil.copyfile(path, os.path.join(target, SHOTS, ident + '.png'))
    with open(os.path.join(target, 'search-index.js'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(search_index(lessons))
    return len(lessons), sum(len(x['examples']) for x in lessons)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--out', required=True, help='the folder to write (new or empty)')
    ap.add_argument('--with-ide', action='store_true', help='link the Web IDE (../ide/)')
    ap.add_argument('--with-dictionary', action='store_true', help='link the Dictionary (../dictionary/)')
    args = ap.parse_args()
    parts = [p for p, on in (('IDE', args.with_ide), ('DICTIONARY', args.with_dictionary)) if on]
    try:
        count, shown = build(os.path.abspath(args.out), parts)
    except (BuildError, OSError) as e:
        print('build_lessons.py: %s' % e, file=sys.stderr)
        sys.exit(1)
    print('lessons: %d, with %d examples: %s' % (count, shown, args.out))


if __name__ == '__main__':
    main()
