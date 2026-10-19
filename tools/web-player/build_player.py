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

Screenshots go into <work>/check.
"""

import argparse
import functools
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
        if problems:
            raise CheckError('; '.join(problems))
        log('The IDE built the player in %.0f s' % (time.time() - started))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    put_page(out)
    put_samples(out, samples)
    return out, samples


def put_page(site):
    """index.html in place of the builder's page."""
    engines = [x for x in os.listdir(site) if re.match(r'^standalone-community-.+\.js$', x)]
    if len(engines) != 1 or 'standalone.zip' not in os.listdir(site):
        raise CheckError('%s does not hold a web standalone: %s' % (site, ', '.join(sorted(os.listdir(site)))))
    with open(PAGE, encoding='utf-8') as f:
        page = f.read()
    with open(os.path.join(site, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page.replace('@ENGINE_JS@', engines[0]))
    built = os.path.join(site, BUILT_PAGE)
    if os.path.exists(built):
        os.remove(built)
    # the page's logo, fonts and pictures
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


def check(site, samples, work):
    from playwright.sync_api import sync_playwright
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
        page.on('pageerror', lambda e: problems.append('page error: %s' % e))
        page.on('download', lambda d: downloads.append(d.suggested_filename))

        started = time.time()
        page.goto(url)
        if wait_for(page, lambda: seen('PLAYER ready'), 'the player starting', 180):
            expect('start', True, '%.1f s' % (time.time() - started))
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
        before = len(third_lines)
        third.click('#home')
        wait_for(third, lambda: any(x.startswith('PLAYER library') for x in third_lines[before:]), 'going home', 15)
        expect('hyper-home', not any(x.startswith('PLAYER script error') for x in third_lines[before:]),
               ' | '.join(third_lines[before:][-3:]))
        third_context.close()
        browser.close()
    server.shutdown()
    with open(os.path.join(shots, 'console.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    return passed, problems


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
