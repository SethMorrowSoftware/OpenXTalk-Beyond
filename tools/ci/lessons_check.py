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

"""Check the examples of the website's lessons (tools/pages/lessons/src,
which tools/pages/build_lessons.py makes into the site's lessons/): run
each one as a reader would, in the xTalk Academy's playground, and compare
what it puts with the Output its page shows under it.

  python3 tools/ci/lessons_check.py (--engine FILE | --bin DIR)
      [--toolset DIR] [--extensions DIR] [--externals DIR] [--toolchain DIR]
      [--source DIR]
      [--only ID|SLUG] [--partial] [--update-shots] [--shots-out DIR]
      [--log FILE] [--timeout SECONDS]

An example is a <figure class="example"> with an id, its code in
<pre class="code"><code>, and how it is checked in data-run
(build_lessons.examples() reads them, and says what each needs):

  output   it runs to its end, and what it puts is exactly the text of
           the figure's <pre class="out"> (a line a value, as the
           playground's Output shows it)
  runs     it runs to its end, and puts as many lines as its Output shows
           (an example whose values differ from run to run: a random
           number, the time)
  error    it stops with an error, on the line data-line says when it
           says one (an example of what a mistake looks like)
  compile  it compiles as an object's script, and is not run: handlers
           that open a dialog, wait for a click or need the internet
  builder  an xTalk Builder module, compiled with lc-compile; an example
           whose data-needs names "builder:<its id>" loads it

data-wait gives seconds to wait after the run, with messages, for what a
timer the example started puts; data-shot, that the page shows the stage
under the example (see "The stage" below); data-needs names the extensions the
example uses (each a folder of --extensions with its module.lcm) and the
externals ("external:revdb", from --externals), as the IDE loads them
when it starts. The examples run with the Academy's own
runner (tools/ci/lessons-check.livecodescript runs them with revAcademyRun
of --toolset, by default this checkout's ide/Toolset) on the engine
--engine without the IDE (-ui), or the development engine of a build
output (--bin). The extensions, the externals and lc-compile are looked
for beside the engine (an installed IDE's Extensions, Externals and
Toolchain, or a build output's packaged_extensions, and the externals and
lc-compile beside its engine) unless given.

The stage. The playground shows what the code makes (a button, a field,
a drawing) in a window of its own, the stage, and a lesson can show it
under an example: lessons/shots/<id>.png, a picture of the stage's card
as the run left it, which the engine takes (at twice the stage's size,
so that it is sharp on a screen of high density) and this check takes
again each time and compares with the page's. --update-shots writes the
engine's pictures as the page's instead (for a new example, or a change
you have looked at), and --shots-out keeps the engine's pictures, with a
picture of what changed beside each one that differs, for a look after a
failure (CI uploads them). On Linux the engine draws its text with
fontconfig, which this check points at fonts of the checkout (Droid Sans,
the Web IDE's, for every font, and Source Code Pro for the fixed-width
ones), so that a picture does not depend on the fonts of the machine; a
small difference in how the text is drawn passes (SHOT_BLOCK and
SHOT_MEAN below), a change of what the stage shows does not. Elsewhere
the fonts are the system's, so the pictures are taken and kept but not
compared.

Exit status 0 when every example did what its page says, 1 otherwise.
Under GitHub Actions a failure is an annotation and the failures go into
the job summary.
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SCRIPT = os.path.join(HERE, 'lessons-check.livecodescript')
PAGES = os.path.join(REPO, 'tools', 'pages')
DEV = {'win32': 'LiveCode-Community.exe',
       'darwin': 'LiveCode-Community.app/Contents/MacOS/LiveCode-Community'}

# The fonts the engine draws a picture's text with on Linux: (the family
# fontconfig knows it by, its files in the checkout)
SANS = ('Droid Sans', ['engine/rsrc/emscripten-standalone-template/boot/standalone/DroidSansCombined.ttf',
                       'engine/rsrc/emscripten-standalone-template/boot/standalone/DroidSansCombined-Bold.ttf'])
MONO = ('Source Code Pro', ['ide/Toolset/resources/supporting_files/fonts/SourceCodePro-Regular.ttf',
                            'ide/Toolset/resources/supporting_files/fonts/SourceCodePro-Bold.ttf'])
# The fixed-width families a script may ask for, which get MONO; every
# other family gets SANS
MONO_NAMES = ('monospace', 'Courier', 'Courier New', 'Source Code Pro', 'Menlo', 'Monaco', 'Consolas',
              'Lucida Console', 'DejaVu Sans Mono', 'Liberation Mono', 'Droid Sans Mono')
# How far a picture may be from the page's and still pass, by the most a
# pixel's colour differs (in any of red, green and blue, 0 to 255):
# SHOT_BLOCK, the most it may differ on average over a square of 8 by 8
# pixels (4 by 4 of the stage), and SHOT_MEAN over the whole picture. Text
# drawn without hinting moves the edges of letters by up to 18; a control
# moved by one point, a border gone, a letter of a label changed or a
# fill of another colour change some square by 37 or more (measured with
# the engine of 0.2.7-rc.6.15, 2026-11-05). A difference of SHOT_MARK
# or more is red in the picture of the difference.
SHOT_BLOCK = 28
SHOT_MEAN = 3
SHOT_MARK = 32

sys.path.insert(0, PAGES)
import build_lessons  # noqa: E402


# A click as the engine makes one in Run mode, for an example on a card
# the reader builds (see palette_code): a check box changes its hilite
# first, and a radio button its group's choice, as autoHilite does; then
# mouseDown and mouseUp, dispatched, so that one no handler takes is not
# an error, as a click is not (send would be: "mouseDown" is no command)
CLICK = r"""
on oxtLessonClick pObject
   if word 1 of pObject is "button" and the autoHilite of pObject then
      if the style of pObject is "checkbox" then
         set the hilite of pObject to not the hilite of pObject
      else if the style of pObject is "radioButton" then
         if word 1 of the long id of the owner of pObject is "group" and the radioBehavior of the owner of pObject then
            set the hilitedButtonId of the owner of pObject to the short id of pObject
         else
            set the hilite of pObject to true
         end if
      end if
   end if
   dispatch "mouseDown" to pObject with 1
   dispatch "mouseUp" to pObject with 1
end oxtLessonClick"""


# What the IDE does between two lines typed into the Message Box: it
# handles the messages that came in meanwhile (a widget posts its
# hiliteChanged, so that it comes once the line that changed it is done)
# and draws the card again (a widget works out what it shows as it draws:
# the Tree View's rows, which its hilitedElement needs). The check's stage
# is never on a screen, so a snapshot draws it. After each line of an
# example for the Message Box, on the same line, so that an error's line
# is still the line's (see palette_code)
IDLE = r"""
on oxtLessonIdle
   local tPicture
   wait 0 milliseconds with messages
   export snapshot from this card of stack "revAcademyStage" to tPicture as PNG
end oxtLessonIdle"""


def typed(line):
    """A line for the Message Box as the check runs it: then what the IDE
    does before the reader types the next (IDLE). A line that is all
    comment, or empty, is left as it is."""
    if not line.strip() or line.lstrip().startswith(('--', '#', '//')):
        return line
    return line + '; oxtLessonIdle'


def xt_text(text):
    """text as an xTalk expression, a line of code: its lines joined with
    return, and each quote as quote."""
    return ' & return & '.join(' & quote & '.join('"%s"' % piece for piece in line.split('"'))
                               for line in text.split('\n'))


# Between two values the Message Box showed, in an example's .msg file
SHOWN = '\x1e'


# After a script is put into an object: it must compile
COMPILED = 'if the result is not empty then throw "the script of %s does not compile:" && the result'


def palette_code(e, shown=None):
    """What the check runs for an example on a card the reader builds
    (build_lessons.py: data-card): the xTalk that makes the card as the
    Tools palette and the Property Inspector do, then the example's lines
    for the Message Box, each followed by what the IDE does before the
    next is typed (IDLE), or its script put into its object; then the
    clicks the reader makes in Run mode. Its second value is how many
    lines come before the example's own, for the line of an error. The
    scripts the reader put in before it (data-after) go in after the
    card's setup.

    After each click it keeps what the Message Box shows (msg: a put
    replaces the one before), and writes them to the file shown, each
    followed by SHOWN: that, not every put, is what the page's Output
    says a click shows."""
    # the card is built, and the scripts put in, with messages locked: as
    # the reader builds it before the scripts that would answer them are
    # there (a new card's openCard to the stack's script, say)
    lines = ['lock messages'] + e['setup'].split('\n')
    # the stack's script: the check's card is the playground's stage, whose
    # script the Academy makes from the handlers of the code it runs (and
    # its own, which keep what the code puts), so the stack's handlers go
    # at the end of the code, where the Academy takes them from
    stack = []
    for name, script in e.get('scripts', []):
        if name == 'this stack':
            stack.append(script)
        else:
            lines.append('set the script of %s to %s' % (name, xt_text(script)))
            lines.append(COMPILED % name.replace('"', "'"))
    if e['script'] == 'this stack':
        stack.append(e['code'])
    elif e['script']:
        lines.append('set the script of %s to %s' % (e['script'], xt_text(e['code'])))
        lines.append(COMPILED % e['script'].replace('"', "'"))
    lines.append('unlock messages')
    before = len(lines)
    message = e.get('in') == 'message'
    if not e['script']:
        lines += [typed(line) if message else line for line in e['code'].split('\n')]
    if e['click']:
        lines.append('put empty into msg')
        lines.append('put empty into tOxtShown')
        for name in e['click']:
            lines.append('oxtLessonClick the long id of %s' % name)
            lines.append('put msg & numToChar(%d) after tOxtShown' % ord(SHOWN))
        if shown:
            lines.append('put textEncode(tOxtShown, "UTF-8") into URL %s' % xt_text('binfile:' + shown))
    return '\n'.join(lines + [CLICK.strip('\n')] + ([IDLE.strip('\n')] if message else []) + stack), before


def compare(example, res, out):
    """What is wrong with what example did: res is the lines of its .res
    ("ok", or "error", the title, the words and the line), out what it
    put. An empty list when it did what the page says."""
    ok = bool(res) and res[0] == 'ok'
    why = '' if ok else ' (%s)' % ': '.join(x for x in res[1:3] if x) if res else ' (no result)'
    run = example['run']
    if run == 'error':
        if ok:
            return ['it was meant to stop with an error, and ran to its end']
        line = example['line']
        if line and example.get('before'):
            line = str(int(line) + example['before'])
        if line and (len(res) < 4 or res[3] != line):
            got = res[3] if len(res) > 3 else '?'
            if example.get('before') and got.isdigit():
                got = str(int(got) - example['before'])
            return ['it stopped on line %s, not on line %s%s' % (got, example['line'], why)]
        return []
    if not ok:
        return ['it stopped with an error%s' % why]
    if run == 'output' and out != example['out']:
        return ['%s\n%s\nnot\n%s' % ('after each click the Message Box showed' if example.get('click') else 'it put',
                                      indent(out), indent(example['out']))]
    if run == 'runs' and len(out.split('\n')) != len(example['out'].split('\n')):
        return ['it put %d lines, not %d as its Output shows:\n%s'
                % (len(out.split('\n')), len(example['out'].split('\n')), indent(out))]
    return []


def read_png(path):
    """(width, height, pixels) of a PNG file, pixels as bytes of RGB, row
    by row (an alpha is dropped). The engine writes 8-bit RGB, or a
    palette when the picture has few colours; grey is read too. A
    ValueError for an interlaced PNG, or 16 bits a sample."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    at, chunks, head, palette = 8, [], None, b''
    while at + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[at:at + 8])
        body = data[at + 8:at + 8 + length]
        if kind == b'IHDR':
            head = struct.unpack('>IIBBBBB', body)
        elif kind == b'PLTE':
            palette = body
        elif kind == b'IDAT':
            chunks.append(body)
        elif kind == b'IEND':
            break
        at += 12 + length
    if not head:
        raise ValueError('no IHDR')
    width, height, depth, colour, _, _, interlace = head
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if channels is None or interlace or depth > 8 or (depth < 8 and colour not in (0, 3)):
        raise ValueError('a PNG of depth %d, colour type %d, interlace %d' % (depth, colour, interlace))
    step = max(1, channels * depth // 8)
    stride = (width * channels * depth + 7) // 8
    raw = zlib.decompress(b''.join(chunks))
    rows, prev = [], bytearray(stride)
    for y in range(height):
        kind = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        if kind == 1:
            for i in range(step, stride):
                line[i] = (line[i] + line[i - step]) & 255
        elif kind == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif kind == 3:
            for i in range(stride):
                line[i] = (line[i] + ((line[i - step] if i >= step else 0) + prev[i]) // 2) & 255
        elif kind == 4:
            for i in range(stride):
                a = line[i - step] if i >= step else 0
                b = prev[i]
                c = prev[i - step] if i >= step else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        elif kind != 0:
            raise ValueError('filter %d' % kind)
        prev = line
        if colour == 2:
            rows.append(bytes(line))
        elif colour == 6:
            rows.append(bytes(b for i, b in enumerate(line) if i % 4 != 3))
        elif colour == 4:
            rows.append(bytes(line[i] for i in range(0, len(line), 2) for _ in range(3)))
        else:
            if depth == 8:
                samples = line
            else:
                per = 8 // depth
                mask = (1 << depth) - 1
                samples = [(line[x // per] >> (8 - depth * (x % per + 1))) & mask for x in range(width)]
            if colour == 3:
                rows.append(b''.join(palette[v * 3:v * 3 + 3] for v in samples[:width]))
            else:
                scale = 255 // ((1 << depth) - 1)
                rows.append(bytes(v * scale for v in samples[:width] for _ in range(3)))
    return width, height, b''.join(rows)


def write_png(path, width, height, pixels):
    """pixels (bytes of RGB, row by row) as a PNG file."""
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    stride = width * 3
    raw = b''.join(b'\x00' + pixels[y * stride:(y + 1) * stride] for y in range(height))
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def compare_shot(new, old):
    """How the picture new (the engine's) differs from old (the page's):
    (what is wrong, or '' when it passes; the worst square's difference;
    a picture of the difference, new faded with what differs in red, as
    (width, height, pixels), or None when there is none)."""
    nw, nh, npx = read_png(new)
    ow, oh, opx = read_png(old)
    if (nw, nh) != (ow, oh):
        return ('the stage is %d by %d, and the page\'s picture %d by %d' % (nw // 2, nh // 2, ow // 2, oh // 2),
                255, None)
    if npx == opx:
        return '', 0, None
    level = [max(abs(npx[i] - opx[i]), abs(npx[i + 1] - opx[i + 1]), abs(npx[i + 2] - opx[i + 2]))
             for i in range(0, len(npx), 3)]
    worst = 0
    for by in range(0, nh, 8):
        for bx in range(0, nw, 8):
            total = count = 0
            for y in range(by, min(by + 8, nh)):
                row = level[y * nw + bx:y * nw + min(bx + 8, nw)]
                total += sum(row)
                count += len(row)
            worst = max(worst, total // count)
    mean = sum(level) / float(len(level))
    picture = bytearray()
    for i, v in enumerate(level):
        picture += b'\xe0\x10\x10' if v >= SHOT_MARK else bytes(255 - (255 - c) // 4 for c in npx[i * 3:i * 3 + 3])
    wrong = []
    if worst > SHOT_BLOCK:
        wrong.append('a part of it differs by %d (at most %d may)' % (worst, SHOT_BLOCK))
    if mean > SHOT_MEAN:
        wrong.append('the whole differs by %.1f on average (at most %d may)' % (mean, SHOT_MEAN))
    return ' and '.join(wrong), worst, (nw, nh, bytes(picture))


def fonts_conf(work):
    """A fontconfig file in work that knows only SANS and MONO (copied
    into work/fonts), and gives one of them for every family a script
    asks for. None when a font is not in the checkout."""
    folder = os.path.join(work, 'fonts')
    os.makedirs(folder)
    for _, files in (SANS, MONO):
        for name in files:
            path = os.path.join(REPO, *name.split('/'))
            if not os.path.isfile(path):
                return None
            shutil.copyfile(path, os.path.join(folder, os.path.basename(path)))
    rules = ''.join('  <match target="pattern"><test qual="first" name="family"><string>%s</string></test>'
                    '<edit name="family" mode="assign_replace" binding="strong"><string>%s</string></edit></match>\n'
                    % (name, MONO[0]) for name in MONO_NAMES)
    rules += ('  <match target="pattern"><test qual="first" name="family" compare="not_eq"><string>%s</string></test>'
              '<edit name="family" mode="assign_replace" binding="strong"><string>%s</string></edit></match>\n'
              % (MONO[0], SANS[0]))
    # (Droid Sans has no italic: fontconfig slants the upright one, as a
    # system's own configuration does, and the engine draws it so)
    rules += ('  <match target="font"><test name="slant" compare="eq"><const>roman</const></test>'
              '<test target="pattern" name="slant" compare="not_eq"><const>roman</const></test>'
              '<edit name="matrix" mode="assign"><times><name>matrix</name><matrix><double>1</double>'
              '<double>0.2</double><double>0</double><double>1</double></matrix></times></edit>'
              '<edit name="slant" mode="assign"><const>oblique</const></edit></match>\n')
    path = os.path.join(work, 'fonts.conf')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n'
                '  <dir>%s</dir>\n  <cachedir>%s</cachedir>\n%s</fontconfig>\n'
                % (folder, os.path.join(work, 'fontcache'), rules))
    return path


def indent(text):
    return '\n'.join('    | ' + line for line in text.split('\n'))


def log(msg=''):
    print(msg, flush=True)


def summary(text):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if path:
        with open(path, 'a', encoding='utf-8', newline='\n') as f:
            f.write(text)


def find_toolchain(given, engine):
    """lc-compile and its modules folder: --toolchain, or an installed
    IDE's Toolchain beside the engine, or a build output's own."""
    exe = 'lc-compile.exe' if sys.platform == 'win32' else 'lc-compile'
    here = os.path.dirname(os.path.abspath(engine))
    for folder in ([given] if given else [os.path.join(here, 'Toolchain'), here]):
        if os.path.isfile(os.path.join(folder, exe)) and os.path.isdir(os.path.join(folder, 'modules', 'lci')):
            return os.path.join(folder, exe), os.path.join(folder, 'modules', 'lci')
    return None, None


def find_extensions(given, engine):
    """The extensions' folder: --extensions, or an installed IDE's
    Extensions beside the engine, or a build output's packaged_extensions."""
    if given:
        return given
    here = os.path.dirname(os.path.abspath(engine))
    for name in ('Extensions', 'packaged_extensions'):
        if os.path.isdir(os.path.join(here, name)):
            return os.path.join(here, name)
    return None


def find_externals(given, engine):
    """The externals' folder: --externals, or an installed IDE's Externals
    beside the engine, or the engine's own folder when revdb is there (a
    build output)."""
    if given:
        return given
    here = os.path.dirname(os.path.abspath(engine))
    revdb = {'win32': 'revdb.dll', 'darwin': 'revdb.bundle'}.get(sys.platform, 'revdb.so')
    for folder in (os.path.join(here, 'Externals'), here):
        if os.path.exists(os.path.join(folder, revdb)):
            return folder
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the examples of the website\'s lessons.')
    given = ap.add_mutually_exclusive_group(required=True)
    given.add_argument('--engine', metavar='FILE', help='the engine to run')
    given.add_argument('--bin', dest='bin_dir', metavar='DIR', help='a build output, whose development engine runs')
    ap.add_argument('--toolset', metavar='DIR', default=os.path.join(REPO, 'ide', 'Toolset'),
                    help='the Toolset whose Academy runs the examples (default: %(default)s)')
    ap.add_argument('--extensions', metavar='DIR', help='the extensions an example may need (default: beside the engine)')
    ap.add_argument('--externals', metavar='DIR', help='the externals an example may need, such as revdb (default: beside the engine)')
    ap.add_argument('--toolchain', metavar='DIR', help='lc-compile and modules/lci (default: beside the engine)')
    ap.add_argument('--source', metavar='DIR', default=os.path.join(PAGES, 'lessons'),
                    help='the lessons\' folder, with src/ (default: %(default)s)')
    ap.add_argument('--only', metavar='ID', action='append',
                    help='check only this example, or every example of the lesson with this slug (more than once for more)')
    ap.add_argument('--partial', action='store_true', help='let a level have no lessons yet (while writing them)')
    ap.add_argument('--update-shots', action='store_true',
                    help='write the engine\'s pictures of the stage as the page\'s, instead of comparing them')
    ap.add_argument('--shots-out', metavar='DIR',
                    help='keep the engine\'s pictures here, with a picture of the difference beside each that differs')
    ap.add_argument('--log', metavar='FILE', help='write the engine\'s output here')
    ap.add_argument('--timeout', type=int, default=600, help='seconds (default: %(default)s)')
    args = ap.parse_args(argv)

    engine = args.engine or os.path.join(args.bin_dir, *DEV.get(sys.platform, 'LiveCode-Community').split('/'))
    toolset = os.path.abspath(args.toolset)
    if not os.path.isfile(engine):
        log('ERROR engine not found: %s' % engine)
        return 1
    if not os.path.isfile(os.path.join(toolset, 'palettes', 'academy', 'revacademy.livecodescript')):
        log('ERROR no Academy in %s' % toolset)
        return 1
    try:
        lessons = build_lessons.read_lessons(os.path.join(args.source, 'src'), every_level=not args.partial)
    except (build_lessons.BuildError, OSError) as e:
        log('ERROR the lessons:\n%s' % e)
        return 1
    found = [e for lesson in lessons for e in lesson['examples']]
    if args.only:
        slugs = {lesson['slug']: [e['id'] for e in lesson['examples']] for lesson in lessons}
        missing = set(args.only) - {e['id'] for e in found} - set(slugs)
        if missing:
            log('ERROR no example or lesson called %s' % ', '.join(sorted(missing)))
            return 1
        asked = {i for name in args.only for i in slugs.get(name, [name])}
        wanted = set(asked)
        for e in found:
            wanted |= {n[len('builder:'):] for n in e['needs'] if e['id'] in asked and n.startswith('builder:')}
        found = [e for e in found if e['id'] in wanted]
    extensions = find_extensions(args.extensions, engine)
    args.externals = find_externals(args.externals, engine)
    log('Engine     : %s' % engine)
    log('Toolset    : %s' % toolset)
    log('Extensions : %s' % (extensions or '(none)'))
    log('Externals  : %s' % (args.externals or '(none)'))
    log('Lessons    : %s (%d lessons, %d examples)' % (args.source, len(lessons), len(found)))
    log('')

    work = tempfile.mkdtemp(prefix='oxt-lessons-')
    problems = []
    try:
        problems = run(found, engine, toolset, extensions, args, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    gha = os.environ.get('GITHUB_ACTIONS') == 'true'
    if not problems:
        log('')
        log('Lessons check: passed (%d examples).' % len(found))
        return 0
    log('')
    log('Lessons check: FAILED: %d example(s)' % len(problems))
    if gha:
        log('::error title=Lessons check::%d example(s) of the lessons did not do what their page says'
            % len(problems))
        summary('### Lessons check failed\n\n' +
                ''.join('- `%s`: %s\n' % (i, p.split('\n')[0]) for i, p in problems[:50]) + '\n')
    return 1


def check_shot(e, taken, pinned, args, failed):
    """What is wrong with the picture of e's stage that the engine took
    (the file taken, if it took one): [] when it passes. It is compared
    with the page's only when the fonts were pinned; --update-shots makes
    it the page's, unless the example failed (what it drew may be wrong
    too), and --shots-out keeps it."""
    if not os.path.isfile(taken):
        return ['the example made no stage to take a picture of']
    if args.shots_out:
        os.makedirs(args.shots_out, exist_ok=True)
        shutil.copyfile(taken, os.path.join(args.shots_out, e['id'] + '.png'))
    if args.update_shots:
        if failed:
            return []
        os.makedirs(os.path.dirname(e['shot_file']), exist_ok=True)
        same = os.path.isfile(e['shot_file']) and pinned and not compare_shot(taken, e['shot_file'])[0]
        if not same:
            shutil.copyfile(taken, e['shot_file'])
            log('SHOT %s: the engine\'s picture is now the page\'s (%s)' % (e['id'], os.path.relpath(e['shot_file'], REPO)))
        return []
    if not os.path.isfile(e['shot_file']):
        return ['the page has no picture of its stage (%s): take it with --update-shots'
                % os.path.relpath(e['shot_file'], REPO)]
    if not pinned:
        return []
    try:
        wrong, worst, picture = compare_shot(taken, e['shot_file'])
    except ValueError as x:
        return ['its picture could not be read: %s' % x]
    if wrong and picture and args.shots_out:
        write_png(os.path.join(args.shots_out, e['id'] + '-difference.png'), *picture)
    if wrong:
        return ['the stage does not look like the page\'s picture: %s%s' % (
            wrong, ' (see %s-difference.png in %s)' % (e['id'], args.shots_out) if picture and args.shots_out else '')]
    if picture:
        log('NOTE %s: the stage differs a little from the page\'s picture (%d at worst)' % (e['id'], worst))
    return []


def run(found, engine, toolset, extensions, args, work):
    """Runs the examples in work, and returns [(id, problem)]."""
    problems = []
    lcm = {}
    builders = [e for e in found if e['run'] == 'builder']
    if builders:
        compiler, modules = find_toolchain(args.toolchain, engine)
        for e in builders:
            if not compiler:
                problems.append((e['id'], 'no lc-compile to compile it with (give --toolchain)'))
                continue
            source = os.path.join(work, e['id'] + '.lcb')
            with open(source, 'w', encoding='utf-8', newline='\n') as f:
                f.write(e['code'] + '\n')
            folder = os.path.join(work, e['id'])
            os.makedirs(folder)
            proc = subprocess.run([compiler, '--modulepath', modules, '--manifest', os.path.join(folder, 'manifest.xml'),
                                   '--output', os.path.join(folder, 'module.lcm'), source],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            if proc.returncode != 0:
                problems.append((e['id'], 'lc-compile stopped:\n%s' % indent(proc.stdout.decode('utf-8', 'replace'))))
            else:
                lcm[e['id']] = os.path.join(folder, 'module.lcm').replace('\\', '/')
                log('PASS %s: compiles with lc-compile' % e['id'])
    names = {}
    for n, e in enumerate(x for x in found if x['run'] != 'builder'):
        name = '%03d' % (n + 1)
        names[name] = e
        needs = []
        for need in e['needs']:
            if need.startswith('builder:'):
                needs.append(lcm.get(need[len('builder:'):], os.path.join(work, 'missing', need[8:], 'module.lcm')))
            else:
                needs.append(need)
        code = e['code']
        if e.get('card') and e['run'] != 'compile':
            code, e['before'] = palette_code(e, os.path.join(work, name + '.msg').replace('\\', '/'))
        with open(os.path.join(work, name + '.xt'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(code)
        with open(os.path.join(work, name + '.how'), 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(['run' if e['run'] != 'compile' else 'compile', e['wait'] or '0',
                               'shot' if e['shot'] is not None else ''] + needs) + '\n')
    env = dict(os.environ, OXT_LESSONS_TOOLSET=toolset.replace('\\', '/'), OXT_LESSONS_DIR=work.replace('\\', '/'))
    pinned = None
    if any(e['shot'] is not None for e in names.values()) and sys.platform.startswith('linux'):
        pinned = fonts_conf(work)
        if pinned:
            env['FONTCONFIG_FILE'] = pinned
        else:
            log('NOTE the fonts for the pictures are not in this checkout: the pictures are not compared')
    if extensions:
        env['OXT_LESSONS_EXTENSIONS'] = os.path.abspath(extensions).replace('\\', '/')
    if args.externals:
        env['OXT_LESSONS_EXTERNALS'] = os.path.abspath(args.externals).replace('\\', '/')
    try:
        proc = subprocess.run([engine, '-ui', SCRIPT], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=args.timeout)
        code = proc.returncode
        out = proc.stdout.decode('utf-8', 'replace').splitlines()
        err = [x for x in proc.stderr.decode('utf-8', 'replace').splitlines() if x.strip()]
    except subprocess.TimeoutExpired as e:
        code = None
        out = (e.stdout or b'').decode('utf-8', 'replace').splitlines()
        err = (e.stderr or b'').decode('utf-8', 'replace').splitlines()
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(out + err) + '\n')
    if code != 0 or not any(x.startswith('DONE ') for x in out):
        problems.append(('(the run)', 'the engine stopped (exit status %s) before the end:\n%s'
                         % (code, indent('\n'.join(out[-20:] + err[-20:])))))
    for name in sorted(names):
        e = names[name]
        res_file = os.path.join(work, name + '.res')
        if not os.path.isfile(res_file):
            problems.append((e['id'], 'it was not run'))
            continue
        # (the engine ends its lines with a return, which is \n on every
        # platform, but a \r\n is read as one end of line too)
        with open(res_file, encoding='utf-8', newline='') as f:
            res = f.read().replace('\r\n', '\n').split('\n')
        with open(os.path.join(work, name + '.out'), encoding='utf-8', newline='') as f:
            put = f.read().replace('\r\n', '\n')
        # an example the reader clicks: what the Message Box showed after
        # each click (palette_code)
        shown = os.path.join(work, name + '.msg')
        if e.get('click') and e['run'] != 'compile' and os.path.isfile(shown):
            with open(shown, encoding='utf-8', newline='') as f:
                put = '\n'.join(f.read().replace('\r\n', '\n').split(SHOWN)[:-1])
        found_problems = compare(e, res, put)
        if e.get('click') and e['run'] != 'compile' and res[:1] == ['ok'] and not os.path.isfile(shown):
            found_problems.append('the check kept no record of what the Message Box showed after each click')
        if e['shot'] is not None:
            found_problems += check_shot(e, os.path.join(work, name + '.png'), pinned, args, bool(found_problems))
        if found_problems:
            for p in found_problems:
                problems.append((e['id'], p))
                log('FAIL %s: %s' % (e['id'], p))
        else:
            log('PASS %s: %s%s' % (e['id'], {'output': 'puts what the page shows', 'runs': 'runs',
                                               'error': 'stops with an error, as the page says',
                                               'compile': 'compiles'}[e['run']],
                                   '' if e['shot'] is None or args.update_shots or not pinned
                                   else ', and its stage looks like the page\'s picture'))
    if err:
        log('')
        log('Engine stderr:')
        for line in err:
            log('  ' + line)
    return problems


if __name__ == '__main__':
    sys.exit(main())
