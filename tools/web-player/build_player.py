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

"""Build the Stack Player, a web standalone that opens any stack, with an
OXT-Beyond's IDE, and optionally check it in a headless browser.

  python3 tools/web-player/build_player.py (--install DIR | --package FILE | --bin DIR)
      [--platform P] [--work DIR] [--out DIR] [--zip FILE] [--check] [--timeout SECONDS]

The IDE of the layout starts (on an Xvfb screen on Linux without a
DISPLAY, as tools/ci/web_check.py starts it) with build-player.livecodescript
named on its command line, which makes the player's stack and builds it
with the IDE's web builder, with every script library and extension the
web engine has (see that script). This script then puts the player's own
page, index.html (this folder's, with the bar above the stack), in place of
the one the builder wrote, and with --zip packs the folder: the files to
put on any web server.

With --check, the player is served on 127.0.0.1 and opened in headless
Chromium (Playwright), and given the sample stacks that the build also
made, as a user gives them, through the bar's Open button:

  Tour   cards, a widget, a palette substack, and a script error, which
         the player must report in a dialog; then the bar's Download copy
         (a download of the stack) and Home
  Grid   a data grid: the Data Grid library must be in the player
  Data   revXML, SQLite through revDB, and a file given with the stack,
         which its relative path must find

A second page then opens the player again, which must list the three in
its library: the browser keeps them between visits. A third opens each
stack the home page offers, then

  Hyper  dynamicPaths true, as a stack imported from HyperCard has it,
         and an openCard that calls an XCMD it does not have: the player
         must say it opened, report that error, and go home again

and two HyperCard files from tests/lcs-input-files/hypercard: Surf, a
stack file with no extension, which the player must import with its
scripts fixed as File > Import Stack fixes them, and Stacks.dc42, a
DiskCopy 4.2 image, whose stacks it must list and open the one chosen.

Then the bare player (play/, check_bare): a sample by ?play= in the middle
of the page with no bar or window around it, a stack of the site by
?stack=, another site's refused, and the Phone Starter filling an iPhone's
window (Chromium, and WebKit where it is installed).

Then a tablet (check_tablet: Playwright's iPad Mini, portrait and
landscape, in the player's page and the bare player): the Responsive
Starter, made with the Mobile Web library, has the whole screen and is
drawn to its corners; 2048, which is not, opens exactly as it did before
there was a rule for a tablet (the same rect and canvas as on the same
iPad with the page's touch test answering no), at its own size.

The first page also has other scripts' errors raised while the player
starts and once it has (tools/ci/stray_errors.py: a browser extension's
script in the page, another site's): the player must start and say
nothing of them (its loading card's error stays hidden). A last page has
an error of its own page raised while the engine starts: that one must
show on the loading card.

Screenshots go into <work>/check.
"""

import argparse
import functools
import glob
import hashlib
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
CI = os.path.join(REPO, 'tools', 'ci')
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, CI)
import ui_tour  # noqa: E402

BUILD_SCRIPT = os.path.join(HERE, 'build-player.livecodescript')
PLAYER_SCRIPT = os.path.join(HERE, 'stack-player.livecodescript')
PAGE = os.path.join(HERE, 'index.html')
# The bare player (play.html): the stack and nothing else, beside the
# player as play/index.html, on the same engine and player stack
BARE_PAGE = os.path.join(HERE, 'play.html')
BARE = 'play'
BUILT_PAGE = 'StackPlayer.html'


def log(msg=''):
    print(msg, flush=True)


class CheckError(Exception):
    pass


# ---------------------------------------------------------------------------
# 1. The build

def build(args, work):
    """Builds the player into <out> with the IDE (see the header)."""
    package, rlc = ui_tour.package, ui_tour.rlc
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    out = os.path.abspath(args.out or os.path.join(work, 'site'))
    samples = os.path.join(work, 'samples')
    shutil.rmtree(out, ignore_errors=True)
    shutil.rmtree(samples, ignore_errors=True)
    results = os.path.join(work, 'build.txt')
    if os.path.exists(results):
        os.remove(results)
    document = os.path.join(work, 'oxt_build_player.livecodescript')
    shutil.copyfile(BUILD_SCRIPT, document)
    temp_dirs = []
    try:
        args.engine = None
        try:
            lay = rlc.find_layout(args, p, temp_dirs)
        except rlc.CheckError as e:
            raise CheckError(str(e))
        log('Layout : %s' % lay.root)

        def path(x):
            return x.replace('\\', '/')
        env = dict(os.environ)
        env.update(OXT_PLAYER_SCRIPT=path(PLAYER_SCRIPT), OXT_PLAYER_OUTPUT=path(out),
                   OXT_PLAYER_LOG=path(results), OXT_PLAYER_SAMPLES=path(samples))
        cmd = [lay.engine, document]
        if p.family == 'linux':
            cef = os.path.join(lay.root, 'Externals') if lay.kind == 'development' else lay.externals
            if 'LIVECODE_USE_CEF' not in env and not os.path.isfile(os.path.join(cef, 'CEF', 'libcef.so')):
                env['LIVECODE_USE_CEF'] = '0'
            if not env.get('DISPLAY'):
                xvfb = shutil.which('xvfb-run')
                if not xvfb:
                    raise CheckError('no DISPLAY and no xvfb-run')
                cmd = [xvfb, '-a', '-s', '-screen 0 1440x900x24'] + cmd
        log('Running: %s' % ' '.join(cmd))
        started = time.time()
        status = 'did not finish within %d seconds' % args.timeout
        with open(os.path.join(work, 'ide-output.txt'), 'wb') as engine_log:
            kw = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else \
                {'start_new_session': True}
            proc = subprocess.Popen(cmd, cwd=work, env=env, stdout=engine_log, stderr=subprocess.STDOUT, **kw)
            try:
                while time.time() - started < args.timeout:
                    if any(x.startswith('DONE') for x in ui_tour.read_lines(results)):
                        status = None
                        break
                    if proc.poll() is not None:
                        status = 'the IDE ended with exit status %s' % proc.returncode
                        break
                    time.sleep(0.5)
            finally:
                ui_tour.stop(proc)
        problems = []
        for line in ui_tour.read_lines(results):
            log('  ide: %s' % line)
            if line.startswith('BUILD FAILED') or line.startswith('ERROR'):
                problems.append(line)
        if status:
            problems.append('the IDE\'s build %s' % status)
            for line in ui_tour.read_lines(os.path.join(work, 'ide-output.txt'))[-40:]:
                log('  ide output: %s' % line)
        if not problems:
            problems += full_engine(lay.root, out)
        if problems:
            raise CheckError('; '.join(problems))
        log('The IDE built the player in %.0f s' % (time.time() - started))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    put_page(out)
    put_samples(out, samples)
    return out, samples


def full_engine(root, site):
    """Problems if the player did not get the web engine with the xTalk
    Suite's libraries: the builder gives the others the lean one of the
    runtime's lean/ (getEngineFiles in
    ide-support/revsaveasemscriptenstandalone.livecodescript), and the
    player asks for this one (build-player.livecodescript)."""
    for wasm in glob.glob(os.path.join(glob.escape(site), 'standalone-community-*.wasm')):
        name = os.path.basename(wasm)
        for lean in glob.glob(os.path.join(glob.escape(root), '**', 'Emscripten', 'js', 'lean', name),
                              recursive=True):
            full = os.path.join(os.path.dirname(os.path.dirname(lean)), name)
            with open(wasm, 'rb') as a, open(full, 'rb') as b:
                if a.read() != b.read():
                    return ['the player\'s %s is not the engine with the xTalk Suite libraries (%s)' % (name, full)]
            log('The player has the engine with the xTalk Suite libraries (%.1f MB; %.1f MB without)' % (
                os.path.getsize(full) / 1e6, os.path.getsize(lean) / 1e6))
    return []


def put_page(site):
    """index.html in place of the builder's page."""
    engines = [x for x in os.listdir(site) if re.match(r'^standalone-community-.+\.js$', x)]
    if len(engines) != 1 or 'standalone.zip' not in os.listdir(site):
        raise CheckError('%s does not hold a web standalone: %s' % (site, ', '.join(sorted(os.listdir(site)))))
    # (a digest of the engine and the stack it opens: see locateFile in
    # the page)
    digest = hashlib.sha256()
    for name in (engines[0], engines[0][:-len('.js')] + '.wasm', 'standalone.zip'):
        if not os.path.isfile(os.path.join(site, name)):
            continue
        with open(os.path.join(site, name), 'rb') as f:
            for block in iter(lambda: f.read(1 << 20), b''):
                digest.update(block)
    stamp = digest.hexdigest()[:16]
    with open(PAGE, encoding='utf-8') as f:
        page = f.read()
    with open(os.path.join(site, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page.replace('@ENGINE_JS@', engines[0]).replace('@STAMP@', stamp))
    # the bare player, one folder down: its meta oxt-player-base ("../")
    # finds the engine, standalone.zip, the samples and the assets
    with open(BARE_PAGE, encoding='utf-8') as f:
        page = f.read()
    bare = os.path.join(site, BARE)
    shutil.rmtree(bare, ignore_errors=True)
    os.makedirs(bare)
    with open(os.path.join(bare, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page.replace('@ENGINE_JS@', engines[0]).replace('@STAMP@', stamp))
    built = os.path.join(site, BUILT_PAGE)
    if os.path.exists(built):
        os.remove(built)
    # the page's logo and pictures
    assets = os.path.join(site, 'assets')
    shutil.rmtree(assets, ignore_errors=True)
    shutil.copytree(os.path.join(HERE, 'assets'), assets)


# The stacks the home page offers (index.html reads samples/samples.json).
# The featured ones, and the small samples with a picture, are kept in
# stacks/ beside this script, each with a picture of its first card; the
# rest are the small samples the build made. The check opens every one.
STACKS = os.path.join(HERE, 'stacks')
SAMPLES = [
    {'title': 'OXT-Beyond on the Web', 'featured': True,
     'files': ['OXT-Beyond on the Web.oxtstack'], 'image': 'OXT-Beyond on the Web.webp',
     'description': 'A live tour of what a stack can do in a web page: dialogs, files, '
                    'the internet, JavaScript, sound and speech, drawing, SQLite and encryption.',
     'tags': ['10 cards', 'Tour', 'Web']},
    {'title': 'Learn xTalk', 'featured': True,
     'files': ['Learn xTalk.oxtstack'], 'image': 'Learn xTalk.webp',
     'description': 'A playful first course: ten lessons with code you run and change, '
                    'a challenge on each, and stars kept in your browser.',
     'tags': ['11 cards', 'Lessons', 'Beginners']},
    {'title': 'xTalk Primer', 'featured': True,
     'files': ['xTalk Primer.oxtstack'], 'image': 'xTalk Primer.webp',
     'description': 'A home stack of examples: buttons and menus, fields and text, '
                    'graphics and timers, lists and data, each with a short script to read.',
     'tags': ['6 cards', 'Examples', 'Scripts']},
    {'title': 'Fireworks', 'source': 'stacks',
     'files': ['Fireworks.oxtstack'], 'image': 'Fireworks.webp',
     'description': 'Click the sky: hundreds of sparks, each a graphic moved by script, '
                    'sixty times a second.',
     'tags': ['Animation', 'Graphics']},
    {'title': 'Live Weather', 'source': 'stacks',
     'files': ['Live Weather.oxtstack'], 'image': 'Live Weather.webp',
     'description': 'Today and the week ahead for any place, fetched from open-meteo.com '
                    'with put url and drawn as a chart.',
     'tags': ['Internet', 'JSON', 'Chart']},
    {'title': 'Web Audio Piano', 'source': 'stacks',
     'files': ['Web Audio Piano.oxtstack'], 'image': 'Web Audio Piano.webp',
     'description': 'Two octaves to play with the mouse or the keyboard; each note is made '
                    'by the browser, through do ... as JavaScript.',
     'tags': ['JavaScript', 'Sound']},
    {'title': 'Neon Snake', 'source': 'stacks',
     'files': ['Neon Snake.oxtstack'], 'image': 'Neon Snake.webp',
     'description': 'The classic game on a timer loop: steer with the keys or a swipe, '
                    'and your best scores are kept in the browser.',
     'tags': ['Game', 'Keyboard', 'Storage']},
    {'title': 'QR Studio', 'source': 'stacks',
     'files': ['QR Studio.oxtstack'], 'image': 'QR Studio.webp',
     'description': 'Type a link, a Wi-Fi network or a contact and get a QR code your phone '
                    'can scan, then download it as a PNG.',
     'tags': ['QR code', 'Download']},
    {'title': 'Talking Robot', 'source': 'stacks',
     'files': ['Talking Robot.oxtstack'], 'image': 'Talking Robot.webp',
     'description': 'A robot that says what you type in the browser\'s own voices, lights '
                    'up each word as it speaks, and watches your mouse.',
     'tags': ['Speech', 'JavaScript']},
    {'title': '2048', 'source': 'stacks',
     'files': ['2048.oxtstack'], 'image': '2048.webp',
     'description': 'Slide and join the tiles to reach 2048, with animated moves, an undo, '
                    'and your best score kept in the browser.',
     'tags': ['Game', 'Animation']},
    {'title': 'Quake Map', 'source': 'stacks',
     'files': ['Quake Map.oxtstack'], 'image': 'Quake Map.webp',
     'description': 'The world\'s earthquakes, live from the USGS: fetched with put url, '
                    'read by the browser and drawn on a map you can explore.',
     'tags': ['Live data', 'Map', 'JSON']},
    {'title': 'Beat Box', 'source': 'stacks',
     'files': ['Beat Box.oxtstack'], 'image': 'Beat Box.webp',
     'description': 'A 16-step drum machine: drums made by Web Audio, kept in time by the '
                    'browser, and your beat saved for next time.',
     'tags': ['Music', 'Web Audio']},
    {'title': 'Kanban Board', 'source': 'stacks',
     'files': ['Kanban Board.oxtstack'], 'image': 'Kanban Board.webp',
     'description': 'Drag cards between three columns while the others slide out of the way; '
                    'add, tag, edit and bin them, and the board is kept in the browser.',
     'tags': ['Drag and drop', 'Animation', 'Storage']},
    {'title': 'Markdown Notes', 'source': 'stacks',
     'files': ['Markdown Notes.oxtstack'], 'image': 'Markdown Notes.webp',
     'description': 'Write Markdown on the left and see it styled on the right as you type, '
                    'tick boxes in the preview, and download a note as Markdown or a web page.',
     'tags': ['Text', 'htmlText', 'Download']},
    {'title': 'UI Gallery', 'source': 'stacks',
     'files': ['UI Gallery.oxtstack'], 'image': 'UI Gallery.webp',
     'description': 'Modern controls drawn with graphics and a little script: switches, sliders, '
                    'a segmented control, a progress ring, toasts, a sheet and a dark theme.',
     'tags': ['Modern UI', 'Animation', 'Themes']},
    {'title': 'Photo Lab', 'source': 'stacks',
     'files': ['Photo Lab.oxtstack'], 'image': 'Photo Lab.webp',
     'description': 'Open a photo of your own, pick a look, adjust it and download it at full '
                    'size; the browser does the pixel work and the photo never leaves your computer.',
     'tags': ['Images', 'JavaScript', 'Files']},
    {'title': 'Phone Starter', 'source': 'stacks',
     'files': ['Phone Starter.oxtstack'], 'image': 'Phone Starter.webp',
     'description': 'A stack to copy for phones, made with the Mobile Web library: tabs for a '
                    'thumb, swipes, pinches and every finger, a list that scrolls with a finger, a '
                    'form above the keyboard, and the camera, location, tilt and share sheet.',
     'tags': ['Phones', 'Touch', 'Starter']},
    {'title': 'Responsive Starter', 'source': 'stacks',
     'files': ['Responsive Starter.oxtstack'], 'image': 'Responsive Starter.webp',
     'description': 'One stack for every screen, made with the Mobile Web library: a tab bar on a '
                    'phone, a rail on a tablet and a sidebar on a desktop, a grid that reflows, '
                    'details in a sheet or a pane, and a dark look. Make the window narrower to see it.',
     'tags': ['Responsive', 'Layout', 'Starter']},
    {'title': 'Tour', 'files': ['Tour.livecode'],
     'description': 'Cards, a widget, a palette window and a script error, caught and shown.',
     'tags': ['Cards', 'Widget', 'Palette']},
    {'title': 'Data Grid', 'files': ['Grid.livecode'],
     'description': 'A Data Grid that fills itself with rows as it opens.',
     'tags': ['Data Grid']},
    {'title': 'Files and data', 'files': ['Data.livecode', 'note.txt'],
     'description': 'XML, an SQLite database and a text file that came with the stack.',
     'tags': ['XML', 'SQLite', 'Files']},
]


def put_samples(site, samples):
    target = os.path.join(site, 'samples')
    os.makedirs(target, exist_ok=True)
    for sample in SAMPLES:
        source = STACKS if sample.get('featured') or sample.get('source') == 'stacks' else samples
        for name in sample['files'] + ([sample['image']] if 'image' in sample else []):
            shutil.copyfile(os.path.join(source, name), os.path.join(target, name))
    with open(os.path.join(target, 'samples.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(SAMPLES, f, indent=1)
        f.write('\n')


def make_zip(site, target):
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, dirs, names in os.walk(site):
            dirs.sort()
            for name in sorted(names):
                path = os.path.join(root, name)
                z.write(path, 'StackPlayer/' + os.path.relpath(path, site).replace(os.sep, '/'))
    log('Packed %s' % target)


# ---------------------------------------------------------------------------
# 2. The check

def serve(site):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=site)
    handler.func.extensions_map['.wasm'] = 'application/wasm'
    handler.func.log_message = lambda *a: None
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def png_pixel(data, x, y):
    """The (r, g, b) of pixel x, y of a PNG (8 bits a channel, RGB or RGBA,
    not interlaced: what the browser's screenshots are)."""
    import struct
    import zlib
    pos, idat, width, channels = 8, b'', 0, 4
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width = struct.unpack('>I', chunk[:4])[0]
            channels = {2: 3, 6: 4}[chunk[9]]
        elif kind == b'IDAT':
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    prev = bytearray(stride)
    for row in range(y + 1):
        start = row * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
    return tuple(prev[x * channels:x * channels + 3])


def check(site, samples, work):
    from playwright.sync_api import sync_playwright
    sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))
    import stray_errors
    shots = os.path.join(work, 'check')
    shutil.rmtree(shots, ignore_errors=True)
    os.makedirs(shots)
    server = serve(site)
    url = 'http://127.0.0.1:%d/index.html' % server.server_address[1]
    lines, problems, passed = [], [], []

    def wait_for(page, pred, what, seconds):
        end = time.time() + seconds
        while time.time() < end:
            if pred():
                return True
            page.wait_for_timeout(100)
        problems.append('%s: not within %d s' % (what, seconds))
        return False

    def seen(prefix):
        return any(x.startswith(prefix) for x in lines)

    def expect(name, ok, detail=''):
        (passed if ok else problems).append(name + (': ' + detail if detail else ''))
        log('  %s %s %s' % ('PASS' if ok else 'FAIL', name, detail))

    def open_files(page, files, what, out=None):
        out = lines if out is None else out
        before = len(out)
        for attempt in range(3):
            try:
                with page.expect_file_chooser(timeout=10000) as fc:
                    page.click('#open')
                fc.value.set_files(files)
                break
            except Exception:
                log('  the file chooser did not open (attempt %d)' % (attempt + 1))
        wait_for(page, lambda: any(x.startswith('PLAYER opened') or x.startswith('PLAYER status Could')
                                   for x in out[before:]), 'opening ' + what, 60)
        page.wait_for_timeout(1500)
        return [x for x in out[before:]]

    def canvas_click(page, x, y):
        box = page.locator('#canvas').bounding_box()
        page.mouse.click(box['x'] + x, box['y'] + y)

    executable = os.environ.get('OXT_CHROMIUM') or None
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=executable)
        context = browser.new_context(viewport={'width': 1000, 'height': 700}, accept_downloads=True)
        page = context.new_page()
        downloads = []
        page.on('console', lambda m: lines.append(m.text))

        def page_error(error):
            # (the other scripts' errors this check raises are not the page's)
            if stray_errors.STRAY_MARK not in str(error):
                problems.append('page error: %s' % error)
        page.on('pageerror', page_error)
        page.on('download', lambda d: downloads.append(d.suggested_filename))
        # Other scripts' errors while the player starts, as a browser
        # extension's script in the page raises them
        page.add_init_script(stray_errors.STRAY_ERRORS)

        started = time.time()
        page.goto(url)
        if wait_for(page, lambda: seen('PLAYER ready'), 'the player starting', 180):
            expect('start', True, '%.1f s' % (time.time() - started))
        # ... and once it has: neither says the engine could not start
        page.evaluate(stray_errors.STRAY_NOW)
        page.wait_for_timeout(500)
        expect('stray-errors', page.evaluate("document.getElementById('loading-error').hidden") is True,
               page.evaluate("document.getElementById('loading-error').textContent"))
        wait_for(page, lambda: page.locator('#library-empty').is_visible(), 'the empty library', 20)
        page.wait_for_timeout(800)
        page.screenshot(path=os.path.join(shots, '1-player.png'), full_page=True)

        # The About panel
        page.click('#about-open')
        page.click('#about button[data-pane="pane-works"]')
        about = page.locator('#about')
        expect('about', about.is_visible() and 'Data Grid' in about.inner_text(), '')
        page.screenshot(path=os.path.join(shots, '1b-about.png'))
        page.click('#about-close')

        # Tour: cards, a widget, a palette, a script error
        got = open_files(page, [os.path.join(samples, 'Tour.livecode')], 'Tour')
        expect('tour-opens', any(x.startswith('PLAYER opened Tour') for x in got), ' | '.join(got[-3:]))
        if problems:
            return passed, problems
        expect('tour-openStack', any(x == 'SAMPLE tour-openStack' for x in got))
        page.screenshot(path=os.path.join(shots, '2-tour.png'))
        before = len(lines)
        canvas_click(page, 235, 95)
        wait_for(page, lambda: any(x.startswith('SAMPLE palette') for x in lines[before:]), 'the palette', 10)
        expect('tour-palette', any(x.startswith('SAMPLE palette ') and x != 'SAMPLE palette 0' for x in lines[before:]),
               ' | '.join(lines[before:]))
        page.wait_for_timeout(500)
        page.screenshot(path=os.path.join(shots, '3-tour-palette.png'))
        before = len(lines)
        canvas_click(page, 385, 95)
        wait_for(page, lambda: any(x.startswith('PLAYER script error') for x in lines[before:]),
                 'the script error report', 10)
        page.wait_for_timeout(800)
        page.screenshot(path=os.path.join(shots, '4-tour-error.png'))
        dialog = page.locator('[class^="oxt-dialog"]')
        expect('tour-error-dialog', dialog.count() > 0 and 'script error' in (dialog.first.inner_text() or ''),
               (dialog.first.inner_text() if dialog.count() else 'no dialog')[:200].replace('\n', ' '))
        page.keyboard.press('Enter')
        page.wait_for_timeout(500)
        canvas_click(page, 85, 95)
        page.wait_for_timeout(800)
        page.screenshot(path=os.path.join(shots, '5-tour-card-2.png'))
        page.click('#download')
        wait_for(page, lambda: downloads, 'the download', 15)
        expect('download', downloads == ['Tour.livecode'], ', '.join(downloads))
        before = len(lines)
        page.click('#home')
        wait_for(page, lambda: any(x.startswith('PLAYER library') for x in lines[before:]), 'going home', 15)
        page.wait_for_timeout(500)
        page.screenshot(path=os.path.join(shots, '6-home.png'))

        cards = page.locator('#library .product h3').all_inner_texts()
        expect('library-cards', cards == ['Tour'], ', '.join(cards))

        # Grid: the Data Grid library, from the page's sample card
        before = len(lines)
        page.locator('#samples .product', has_text='Data Grid').click()
        wait_for(page, lambda: any(x.startswith('PLAYER opened') or x.startswith('PLAYER status Could')
                                   for x in lines[before:]), 'opening the Data Grid sample', 60)
        page.wait_for_timeout(1500)
        got = lines[before:]
        grid = [x for x in got if x.startswith('SAMPLE grid')]
        expect('grid', grid == ['SAMPLE grid 3,Grace,2'], ' | '.join(grid or got[-3:]))
        page.screenshot(path=os.path.join(shots, '7-grid.png'))

        # Data: revXML, SQLite, and a file given with the stack, read by a
        # relative path and from specialFolderPath("resources")
        got = open_files(page, [os.path.join(samples, 'Data.livecode'), os.path.join(samples, 'note.txt')], 'Data')
        data = [x for x in got if x.startswith('SAMPLE data')]
        expect('data', data == ['SAMPLE data xml ok,sql ok,beside the stack,beside the stack'], ' | '.join(data or got[-3:]))
        page.screenshot(path=os.path.join(shots, '8-data.png'))

        # A second visit lists them
        second = context.new_page()
        second_lines = []
        second.on('console', lambda m: second_lines.append(m.text))
        second.goto(url)
        wait_for(second, lambda: any(x.startswith('PLAYER library') for x in second_lines), 'the second visit', 120)
        library = [x for x in second_lines if x.startswith('PLAYER library')]
        expect('library-kept', bool(library) and all(n in library[-1] for n in ('Tour', 'Grid', 'Data')),
               library[-1] if library else '')
        second.wait_for_timeout(800)
        second.screenshot(path=os.path.join(shots, '9-second-visit.png'), full_page=True)

        # Remove one from the library, through the page's own dialog
        before = len(second_lines)
        second.locator('#library .product', has_text='Data').hover()
        second.locator('#library .product', has_text='Data').locator('.more').click()
        second.click('#confirm-yes')
        wait_for(second, lambda: any(x.startswith('PLAYER library') for x in second_lines[before:]), 'removing', 15)
        second.wait_for_timeout(500)
        cards = second.locator('#library .product h3').all_inner_texts()
        expect('remove', sorted(cards) == ['Grid', 'Tour'], ', '.join(cards))

        # The stacks with a picture, featured or small, each from its card,
        # in a browser of its own
        third_context = browser.new_context(viewport={'width': 1280, 'height': 860})
        third = third_context.new_page()
        third_lines = []
        third.on('console', lambda m: third_lines.append(m.text))
        third.on('pageerror', lambda e: problems.append('page error: %s' % e))
        third.goto(url)
        wait_for(third, lambda: any(x.startswith('PLAYER ready') for x in third_lines), 'the third visit', 180)
        third.wait_for_timeout(800)
        third.screenshot(path=os.path.join(shots, '10-featured.png'), full_page=True)
        for n, sample in enumerate(x for x in SAMPLES if 'image' in x):
            before = len(third_lines)
            third.locator('.feature', has_text=sample['title']).click()
            wait_for(third, lambda: any(x.startswith('PLAYER opened') or x.startswith('PLAYER status Could')
                                        for x in third_lines[before:]), 'opening ' + sample['title'], 60)
            third.wait_for_timeout(2500)
            got = third_lines[before:]
            errors = [x for x in got if x.startswith('PLAYER script error') or x.startswith('PLAYER status Could')]
            expect(('featured-' if sample.get('featured') else 'sample-') + sample['title'].lower().replace(' ', '-'),
                   any(x.startswith('PLAYER opened') for x in got) and not errors, ' | '.join(errors or got[-2:]))
            third.screenshot(path=os.path.join(shots, '11-featured-%d.png' % (n + 1)))
            third.click('#home')
            wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)

        # Hyper: dynamicPaths true, as every stack imported from HyperCard
        # has it, so that until the engine's turn ends a public handler of
        # the player's is looked for in that stack's message path. The
        # player must still say it opened, and go home again.
        # Its first card's openCard calls an XCMD it does not have, as many
        # HyperCard stacks do: it opens all the same, and the player
        # reports that error (and only that one) in a dialog.
        got = open_files(third, [os.path.join(samples, 'Hyper.livecode')], 'Hyper', third_lines)
        errors = [x for x in got if x.startswith('PLAYER script error') or x.startswith('PLAYER status Could')]
        expect('hyper-opens', any(x.startswith('PLAYER opened Hyper') for x in got)
               and len(errors) == 1 and 'hyperMissingXCMD' in errors[0],
               ' | '.join(errors or got[-3:]))
        expect('hyper-openStack', 'SAMPLE hyper true' in got, ' | '.join(x for x in got if x.startswith('SAMPLE')))
        third.wait_for_timeout(500)
        dialog = third.locator('[class^="oxt-dialog"]')
        expect('hyper-error-dialog', dialog.count() > 0 and 'hyperMissingXCMD' in (dialog.first.inner_text() or ''),
               (dialog.first.inner_text() if dialog.count() else 'no dialog')[:200].replace('\n', ' '))
        third.screenshot(path=os.path.join(shots, '12-hyper.png'))
        third.keyboard.press('Enter')
        third.wait_for_timeout(500)

        # The same stack, from another file, opened while it plays (a newer
        # copy of a stack being made): it is the file's, and it is still
        # there once the one it replaced is forgotten
        got = open_files(third, [os.path.join(samples, 'Hyper.livecode')], 'Hyper again', third_lines)
        third.wait_for_timeout(500)
        if third.locator('[class^="oxt-dialog"]').count():
            third.keyboard.press('Enter')
            third.wait_for_timeout(500)
        there = third.evaluate("!!(document.liveCode && document.liveCode.findStackWithName('Hyper'))")
        expect('reopen-while-playing', any(x.startswith('PLAYER opened Hyper') for x in got) and there,
               'stack there: %s | %s' % (there, ' | '.join(got[-3:])))
        before = len(third_lines)
        third.click('#home')
        wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)
        expect('hyper-home', not any(x.startswith('PLAYER script error') for x in third_lines[before:]),
               ' | '.join(third_lines[before:][-3:]))
        # the same file opened twice is one stack in the library, not
        # "Hyper" and "Hyper 2"
        library = [x for x in third_lines[before:] if x.startswith('PLAYER library')]
        expect('reopen-no-duplicate', bool(library) and 'Hyper' in library[-1] and 'Hyper 2' not in library[-1],
               library[-1] if library else '')

        # HyperCard: a stack file with no extension, imported and its
        # scripts fixed (revHyperCardFixScripts), and a disk image whose
        # stacks the player lists, one of them then copied out and opened
        hc_dir = os.path.join(work, 'hypercard')
        shutil.rmtree(hc_dir, ignore_errors=True)
        os.makedirs(hc_dir)
        hc_input = os.path.join(REPO, 'tests', 'lcs-input-files', 'hypercard')
        shutil.copyfile(os.path.join(hc_input, 'games', 'Surf.stack'), os.path.join(hc_dir, 'Surf'))
        shutil.copyfile(os.path.join(hc_input, 'forks', 'Stacks.dc42'), os.path.join(hc_dir, 'Stacks.dc42'))
        got = open_files(third, [os.path.join(hc_dir, 'Surf')], 'Surf', third_lines)
        # (the player's "hypercard-mace" line follows the summary: the
        # space keeps it out of the summary's lines)
        fixed = [x for x in got if x.startswith('PLAYER hypercard ')]
        mace = [x for x in got if x.startswith('PLAYER hypercard-mace')]
        expect('hypercard-opens', any(x.startswith('PLAYER opened Surf') for x in got), ' | '.join(got[-3:]))
        expect('hypercard-fixed', len(fixed) == 1 and 'HyperCard scripts:' in fixed[0], ' | '.join(fixed or got[-3:]))
        expect('hypercard-mace', len(mace) == 1 and not mace[0].startswith('PLAYER hypercard-mace-failed'),
               ' | '.join(mace or got[-3:]))
        third.wait_for_timeout(500)
        if third.locator('[class^="oxt-dialog"]').count():
            third.keyboard.press('Enter')
            third.wait_for_timeout(500)
        third.screenshot(path=os.path.join(shots, '13-hypercard.png'))
        before = len(third_lines)
        third.click('#home')
        wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)
        library = [x for x in third_lines[before:] if x.startswith('PLAYER library')]
        expect('hypercard-library', bool(library) and 'Surf' in library[-1], library[-1] if library else '')

        before = len(third_lines)
        for attempt in range(3):
            try:
                with third.expect_file_chooser(timeout=10000) as fc:
                    third.click('#open')
                fc.value.set_files([os.path.join(hc_dir, 'Stacks.dc42')])
                break
            except Exception:
                log('  the file chooser did not open (attempt %d)' % (attempt + 1))
        wait_for(third, lambda: third.locator('#choose').is_visible(), 'the disk image\'s stacks', 60)
        choices = third.locator('#choose-list button').all_inner_texts()
        expect('disk-image-list', 'Old Disk:Stacks:Synthetic Stack' in choices, ', '.join(choices))
        third.screenshot(path=os.path.join(shots, '14-disk-image.png'))
        third.locator('#choose-list button', has_text='Synthetic Stack').click()
        wait_for(third, lambda: any(x.startswith('PLAYER opened') or x.startswith('PLAYER status Could')
                                    for x in third_lines[before:]), 'opening the disk image\'s stack', 60)
        got = third_lines[before:]
        expect('disk-image-opens', any(x.startswith('PLAYER opened Synthetic Stack') for x in got), ' | '.join(got[-3:]))
        third.wait_for_timeout(800)
        if third.locator('[class^="oxt-dialog"]').count():
            third.keyboard.press('Enter')
            third.wait_for_timeout(500)
        third.screenshot(path=os.path.join(shots, '15-disk-image-stack.png'))
        before = len(third_lines)
        third.click('#home')
        wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)

        # Mover: a stack that sizes and centres its own window as it opens
        # (as the box2dxt platformer does) shows itself in the page's
        # window, not the player's card. Its colour is #CC3366.
        got = open_files(third, [os.path.join(samples, 'Mover.livecode')], 'Mover', third_lines)
        third.wait_for_timeout(2500)
        report = [x for x in third_lines if x.startswith('SAMPLE mover')]
        box = third.locator('#canvas').bounding_box()
        shot = third.screenshot(clip=box)
        with open(os.path.join(shots, '16-mover.png'), 'wb') as f:
            f.write(shot)
        points = [(20, 80), (box['width'] // 2, box['height'] // 3), (20, box['height'] - 20)]
        colours = [png_pixel(shot, int(x), int(y)) for x, y in points]
        log('  mover canvas %s: %s | %s' % (box, ', '.join('%s=#%02X%02X%02X' % ((p,) + c) for p, c in zip(points, colours)),
                                           ' | '.join(report)))
        expect('mover-shows-itself', any(x.startswith('PLAYER opened Mover') for x in got)
               and all(abs(c[0] - 0xCC) < 24 and abs(c[1] - 0x33) < 24 and abs(c[2] - 0x66) < 24 for c in colours),
               ' | '.join(report + ['#%02X%02X%02X' % c for c in colours]))
        # The up and down arrows that a stack passes go back and forth
        # through the cards it has shown, and the card before its first is
        # the player's: the box2dxt platformer's ladder (UP climbs) took the
        # player back to its library
        before = len(third_lines)
        third.mouse.click(box['x'] + box['width'] // 2, box['y'] + box['height'] // 2)
        for key in ('ArrowUp', 'ArrowDown', 'ArrowUp'):
            third.keyboard.press(key)
            third.wait_for_timeout(400)
        third.wait_for_timeout(1000)
        shot = third.screenshot(clip=box)
        colour = png_pixel(shot, int(box['width'] // 2), int(box['height'] // 3))
        came_back = [x for x in third_lines[before:] if x.startswith('PLAYER library')]
        expect('arrows-stay-in-stack', not came_back
               and abs(colour[0] - 0xCC) < 24 and abs(colour[1] - 0x33) < 24 and abs(colour[2] - 0x66) < 24,
               ' | '.join(came_back + ['#%02X%02X%02X' % colour]))
        before = len(third_lines)
        third.click('#home')
        wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)

        third_context.close()

        # The bare player (play/): the stack and nothing else
        check_bare(p, browser, url.replace('index.html', BARE + '/'), shots, expect, wait_for)

        # A tablet: a Mobile Web stack has the screen, any other is as it was
        check_tablet(p, browser, url, shots, expect, wait_for)

        # An error of the page's own while the engine starts still shows
        own_context = browser.new_context(viewport={'width': 1000, 'height': 700})
        own = own_context.new_page()
        own.add_init_script(stray_errors.OWN_ERROR)
        own.goto(url)
        shown = wait_for(own, lambda: own.evaluate(
            "!document.getElementById('loading-error').hidden"), 'the own error showing', 60)
        text = own.evaluate("document.getElementById('loading-error').textContent")
        expect('own-error', shown and 'could not start' in text, text)
        own.screenshot(path=os.path.join(shots, '9-own-error.png'))
        own_context.close()
        browser.close()
    server.shutdown()
    with open(os.path.join(shots, 'console.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    return passed, problems


def check_bare(p, browser, url, shots, expect, wait_for):
    """The bare player (play.html, LittleNemo's p=26036): a sample by
    ?play= in the middle of the window, at its own size, with no bar,
    frame or library around it; a stack of the site by ?stack=; another
    site's refused; and on a phone (Playwright's iPhone 13 in Chromium,
    and in WebKit when it is installed) the Phone Starter fills the window.

    What is measured is the stack as it is drawn, not only the canvas: the
    canvas filled the window on a desktop when the player took every
    browser for a phone (#348), while the stack was scaled up into it, and
    on rc.6.15's player the canvas filled an iPhone's window while the
    Phone Starter was drawn scaled down inside it, a strip of page at each
    side. So: the canvas is the size the player says the stack is, the
    page's colour is just outside it and the stack's just inside it; and on
    the phone, the stack's header and tab bar are the same colour at the
    window's left edge, its middle and its right edge."""
    import stray_errors

    def visit(context, query, what, shot, stray=False):
        page = context.new_page()
        lines = []
        page.on('console', lambda m: lines.append(m.text))
        if stray:
            # other scripts' errors while it starts, as the player's own
            # page is given them: they are not the bare player's
            page.add_init_script(stray_errors.STRAY_ERRORS)
        page.goto(url + query)
        wait_for(page, lambda: any(x.startswith('PLAYER opened') for x in lines)
                 or page.evaluate("!document.getElementById('note').hidden"), what, 120)
        page.wait_for_timeout(2500)
        state = page.evaluate("""() => {
            const c = document.getElementById('canvas').getBoundingClientRect();
            return {playing: document.body.classList.contains('playing'), title: document.title,
                    note: document.getElementById('note').hidden ? '' : document.getElementById('note').textContent,
                    chrome: document.querySelectorAll('.menubar, .window, #toasts, .desk').length,
                    fill: document.body.getAttribute('data-mobile-web-fill'),
                    canvas: [c.left, c.top, c.width, c.height], view: [innerWidth, innerHeight],
                    ratio: window.devicePixelRatio,
                    loadingError: document.getElementById('loading-error').hidden ? '' :
                        document.getElementById('loading-error').textContent,
                    scrollWidth: document.documentElement.scrollWidth}; }""")
        png = page.screenshot(path=os.path.join(shots, shot))
        # the stack's own size, as the player read it from its file
        opened = [x for x in lines if x.startswith('PLAYER opened')]
        m = re.search(r'rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)', opened[-1]) if opened else None
        state['stack'] = [int(m.group(3)) - int(m.group(1)), int(m.group(4)) - int(m.group(2))] if m else None
        log('  bare %s: %s' % (query, state))
        return page, lines, state, png

    def pixel(png, st, x, y):
        r = st['ratio'] or 1
        return png_pixel(png, int(x * r), int(y * r))

    def near(a, b, tolerance=24):
        return all(abs(i - j) <= tolerance for i, j in zip(a, b))

    page_colour = (0, 0, 0)
    desk = browser.new_context(viewport={'width': 1000, 'height': 700})
    page, lines, st, png = visit(desk, '?play=2048', 'the bare player opening 2048', '20-bare-2048.png', stray=True)
    left, top, width, height = st['canvas']
    expect('bare-opens', st['playing'] and st['title'] == '2048'
           and any(x.startswith('PLAYER opened 2048') for x in lines), str(st))
    # a desktop browser is not a phone: the stack keeps its size
    expect('bare-no-chrome', st['chrome'] == 0 and st['fill'] == 'no', str(st))
    expect('bare-stray-errors', st['loadingError'] == '', st['loadingError'])
    expect('bare-own-size', st['stack'] is not None and [round(width), round(height)] == st['stack'],
           'canvas %s, stack %s' % (st['canvas'], st['stack']))
    expect('bare-centred', width > 0 and abs(left - (1000 - width) / 2) <= 1 and abs(top - (700 - height) / 2) <= 1,
           str(st['canvas']))
    if width > 0 and left >= 4 and top >= 4:
        mid = top + height / 2
        outside, inside = pixel(png, st, left - 3, mid), pixel(png, st, left + 3, mid)
        below, above = pixel(png, st, left + width / 2, top + height + 3), pixel(png, st, left + width / 2, top + height - 3)
        expect('bare-drawn-in-its-place', near(outside, page_colour) and near(below, page_colour)
               and not near(inside, page_colour, 6) and not near(above, page_colour, 6),
               'outside %s, inside %s, below %s, above %s' % (outside, inside, below, above))
    else:
        expect('bare-drawn-in-its-place', False, 'the stack fills the window: %s' % st['canvas'])
    page.close()
    page, lines, st, png = visit(desk, '?stack=../samples/Tour.livecode&align=top-left', 'the bare player opening Tour',
                                 '21-bare-tour.png')
    expect('bare-stack-of-the-site', st['playing'] and st['canvas'][:2] == [0, 0]
           and st['stack'] is not None and [round(v) for v in st['canvas'][2:]] == st['stack']
           and any(x.startswith('PLAYER opened Tour') for x in lines), str(st))
    page.close()
    page, lines, st, png = visit(desk, '?stack=https://example.com/x.livecode', 'the bare player refusing',
                                 '22-bare-other-site.png')
    expect('bare-other-site-refused', not st['playing'] and 'must be on this site' in st['note'], str(st))
    page.close()
    desk.close()

    def phone(engine, kind):
        context = engine.new_context(**p.devices['iPhone 13'])
        page, lines, st, png = visit(context, '?play=Phone%20Starter', 'the Phone Starter in ' + kind,
                                     '23-bare-phone-%s.png' % kind)
        vw, vh = st['view']
        width, height = st['canvas'][2:]
        expect('bare-phone-fills-' + kind, st['playing'] and st['fill'] is None and abs(width - vw) <= 1
               and abs(height - vh) <= 1 and st['scrollWidth'] <= vw, str(st))
        # the header (its top) and the tab bar (its bottom) are drawn from
        # edge to edge: the same colour at the left edge, in the middle and
        # at the right edge, and not the page's
        rows = []
        for y in (8, vh - 6):
            row = [pixel(png, st, x, y) for x in (1, vw / 2, vw - 2)]
            rows.append(row)
        expect('bare-phone-edge-to-edge-' + kind,
               all(near(r[0], r[1], 8) and near(r[2], r[1], 8) and not near(r[1], page_colour, 6) for r in rows),
               ' | '.join(' '.join('#%02X%02X%02X' % c for c in r) for r in rows))
        page.close()
        context.close()

    phone(browser, 'chromium')
    # WebKit, Safari's engine, where Playwright's is installed
    try:
        webkit = p.webkit.launch()
    except Exception as e:
        log('  bare: no WebKit to check the phone in (%s)' % str(e).splitlines()[0][:120])
        return
    try:
        phone(webkit, 'webkit')
    finally:
        webkit.close()


# A page whose touch test answers no, as the page's own was before it had
# a rule for a tablet: what a stack that is not made with the Mobile Web
# library must look like on a tablet still
NOT_TOUCH = """(() => { const was = window.matchMedia.bind(window);
  window.matchMedia = q => q === '(pointer: coarse)' ? {matches: false, media: q, onchange: null,
    addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {}} : was(q); })();"""


def check_tablet(p, browser, url, shots, expect, wait_for):
    """A tablet (Playwright's iPad Mini, a touch screen whose short side
    is not a phone's), portrait and landscape, in the player's page and the
    bare player. The page's body has data-mobile-web-fill="touch".

    The Responsive Starter calls mwStart: the player gives it the window,
    the library fills the page, and it is drawn to the window's four
    corners (its own light backgrounds there, not the page's), in the
    player's page with the bar out of the way (phone-play). Before, it
    opened at its own 1240x780 and was cut off at the right.

    2048 does not: it must open as it did before (the same rect, as the
    player logs it, and the same canvas as on the same iPad with the
    page's touch test answering no), at its own size, never fitted."""
    def visit(device, page_url, query, shot, not_touch=False):
        context = browser.new_context(**p.devices[device])
        if not_touch:
            context.add_init_script(NOT_TOUCH)
        page = context.new_page()
        lines = []
        page.on('console', lambda m: lines.append(m.text))
        page.goto(page_url + query)
        wait_for(page, lambda: any(x.startswith('PLAYER opened') for x in lines), 'a stack on a tablet', 120)
        page.wait_for_timeout(2500)
        state = page.evaluate("""() => {
            const c = document.getElementById('canvas').getBoundingClientRect();
            return {fill: document.body.getAttribute('data-mobile-web-fill'),
                    phonePlay: document.body.classList.contains('phone-play'),
                    canvas: [c.left, c.top, c.width, c.height].map(Math.round),
                    view: [innerWidth, innerHeight], ratio: window.devicePixelRatio}; }""")
        png = page.screenshot(path=os.path.join(shots, shot))
        opened = [x for x in lines if x.startswith('PLAYER opened')][-1]
        state['opened'] = opened
        state['filled'] = any(x.startswith('PLAYER fills the screen') for x in lines)
        state['fitted'] = any(x.startswith('PLAYER fitted') for x in lines)
        log('  tablet %s%s%s: %s' % (page_url.rsplit('/', 2)[-2:], query, ' (not touch)' if not_touch else '', state))
        context.close()
        return state, png

    def bright(png, st, x, y):
        r = st['ratio'] or 1
        return sum(png_pixel(png, int(x * r), int(y * r))) / 3 > 170

    pages = (('player', url), ('bare', url.replace('index.html', BARE + '/')))
    for device, turn in (('iPad Mini', 'portrait'), ('iPad Mini landscape', 'landscape')):
        for kind, page_url in pages:
            st, png = visit(device, page_url, '?play=Responsive%20Starter', '24-tablet-responsive-%s-%s.png' % (kind, turn))
            vw, vh = st['view']
            corners = [(2, 2), (vw - 3, 2), (2, vh - 3), (vw - 3, vh - 3)]
            expect('tablet-mobile-web-fills-%s-%s' % (kind, turn),
                   st['fill'] == 'touch' and st['filled'] and not st['fitted']
                   and st['canvas'] == [0, 0, vw, vh] and st['opened'].endswith('rect=0,0,%d,%d' % (vw, vh))
                   and (kind == 'bare' or st['phonePlay'])
                   and all(bright(png, st, x, y) for x, y in corners), str(st))
            st, png = visit(device, page_url, '?play=2048', '25-tablet-2048-%s-%s.png' % (kind, turn))
            was, _ = visit(device, page_url, '?play=2048', '25-tablet-2048-%s-%s-was.png' % (kind, turn), True)
            m = re.search(r'rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)', st['opened'])
            own = [int(m.group(3)) - int(m.group(1)), int(m.group(4)) - int(m.group(2))] if m else None
            expect('tablet-other-stack-as-before-%s-%s' % (kind, turn),
                   st['fill'] == 'touch' and was['fill'] == 'no' and not st['filled'] and not st['fitted']
                   and not st['phonePlay'] and st['opened'] == was['opened'] and st['canvas'] == was['canvas']
                   and own == st['canvas'][2:], 'now %s, was %s' % (st, was))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--bin', dest='bin_dir', metavar='DIR', help='build output (development layout)')
    ap.add_argument('--install', metavar='DIR', help='staged or installed OXT-Beyond-<version> folder')
    ap.add_argument('--package', metavar='FILE', help='package to extract and build with')
    ap.add_argument('--platform', choices=list(ui_tour.package.PLATFORMS))
    ap.add_argument('--work', metavar='DIR', default='web-player-work')
    ap.add_argument('--out', metavar='DIR', help='the player\'s folder (default: <work>/site)')
    ap.add_argument('--zip', metavar='FILE', help='also pack the folder into this zip')
    ap.add_argument('--check', action='store_true', help='open the player in headless Chromium and check it')
    ap.add_argument('--timeout', type=int, default=900, help='seconds for the IDE (default: %(default)s)')
    args = ap.parse_args(argv)
    work = os.path.abspath(args.work)
    os.makedirs(work, exist_ok=True)
    try:
        site, samples = build(args, work)
        if args.zip:
            make_zip(site, os.path.abspath(args.zip))
        if args.check:
            passed, problems = check(site, samples, work)
            log('%d passed, %d failed' % (len(passed), len(problems)))
            if problems:
                raise CheckError('; '.join(problems))
    except CheckError as e:
        log('FAILED: %s' % e)
        return 1
    log('OK: %s' % site)
    return 0


if __name__ == '__main__':
    sys.exit(main())
