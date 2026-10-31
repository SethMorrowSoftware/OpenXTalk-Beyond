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

"""Screenshots of the web IDE: opens a site that tools/web-ide/build_site.py
made in headless Chromium and walks through the IDE's windows.

  python3 tools/ci/web_ide_tour.py --site DIR --out DIR [--browser NAME]
      [--timeout SECONDS] [--only STEPS] [--keep-serving]
      [--tour FILE] [--add FILE]... [--replace PATH=FILE]... [--relay]
      [--size WIDTHxHEIGHT]

--site is the web IDE's site (index.html, the engine and ide.zip). The
script copies it into <out>/site, adds tools/ci/web-ide-tour.livecodescript
to the copy's ide.zip as the script library extension oxtwebidetour (the
IDE loads it as it starts, as every extension), serves the copy on
127.0.0.1 and opens it at 1400 x 900 (or the --size given: a page
smaller than Home, 800x500 or 640x480, is how OpenXTalkPaul's Firefox
window once kept the IDE on its loading screen, openxtalk.org p=25583).
The site itself is not changed.

Once the IDE has opened (the page hides its loading screen), the script
takes a screenshot of the page as a first visit shows it (00-first-visit,
with the page's note about where stacks are kept), closes the note and
tells the tour to go. The tour (web-ide-tour.livecodescript says what it
opens) hands the page lines through window.oxtTour; this script writes
them to <out>/tour.txt, and does what each ACT line asks: a screenshot of
the page (<out>/shots/<file>.png), a click, a key, or a new size of the
page. What the browser's console says goes to <out>/console.txt.

The check fails when the IDE does not open, the page reports an error of
its own (a JavaScript error, or the engine stopping), the tour records a
script error of the IDE or a step that failed, or it does not finish
within --timeout seconds (default 600). <out>/index.html shows the
screenshots, for a person to look through. Under GitHub Actions it writes
annotations and a job summary.

--keep-serving keeps the server running after the tour (Ctrl-C ends it),
to open the copy in a browser by hand.

--tour FILE runs another tour, written as web-ide-tour.livecodescript is
(the same lines): it goes in as the extension its script line names.
tools/ci/web-ide-xtalk.livecodescript is one (the xTalk Suite's libraries
in the web IDE, EXPERIMENTAL). --add FILE puts FILE into the tour's
extension folder (in its folder files), for the tour to open; --replace PATH=FILE
puts FILE into the copy's ide.zip at PATH in place of what is there (an
extension of the release replaced by the one under test). --relay runs a
Nostr relay of tools/ci/nostr_test_relay.py on 127.0.0.1 for the tour,
whose ws:// address the page gives it as window.oxtTour.relay.

Exit status 0 when the tour passes, 1 otherwise. Needs Python 3.8 or later
and the Python package playwright with its Chromium
(python3 -m playwright install chromium).
"""

import argparse
import functools
import html
import http.server
import os
import shutil
import sys
import threading
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOUR = os.path.join(HERE, 'web-ide-tour.livecodescript')

# The extension a tour goes into the IDE as is the name its script line
# gives it (tour_extension), the manifest's too
MANIFEST = '''<package version="0.0">
  <name>%s</name>
  <title>Web IDE tour (CI)</title>
  <author>OXT-Beyond contributors</author>
  <version>1.0.0</version>
  <type>library</type>
  <license>community</license>
</package>
'''

# The page's side of the tour (web-ide-tour.livecodescript, "Lines"),
# there before the IDE starts
PAGE_SCRIPT = '''
window.oxtTour = {
  go: false,
  only: '',
  relay: '',
  done: 0,
  lines: [],
  record: function(line) { this.lines.push(String(line)); },
  take: function() { var lines = this.lines; this.lines = []; return lines; }
};
'''

WIDTH, HEIGHT = 1400, 900


def page_size(text):
    """(width, height) of --size's WIDTHxHEIGHT."""
    width, sep, height = text.lower().partition('x')
    if not (sep and width.isdigit() and height.isdigit() and int(width) >= 200 and int(height) >= 200):
        raise argparse.ArgumentTypeError('%r is not WIDTHxHEIGHT, each 200 or more' % text)
    return int(width), int(height)

# What the page shows while the IDE loads, and when it fails
# (tools/web-ide/index.html)
OPENED = "document.getElementById('loading').style.display === 'none'"
FAILED = "document.getElementById('error').style.display === 'block'"


def log(text):
    print(text, flush=True)


def annotate(kind, text):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        print('::%s title=Web IDE tour::%s' % (kind, text.replace('\n', ' ')), flush=True)


def tour_extension(tour):
    """The name the tour's script line gives it."""
    with open(tour, encoding='utf-8') as f:
        first = f.readline().strip()
    if not (first.startswith('script "') and first.endswith('"')):
        raise SystemExit('error: %s does not begin with a script "<name>" line' % tour)
    return first[len('script "'):-1]


def make_site(site, out, tour=TOUR, add=(), replace=()):
    """A copy of the site whose ide.zip has the tour as an extension (with
    the files of add beside it), and the files of replace, (path in the zip,
    file) pairs, in place of the zip's."""
    copy = os.path.join(out, 'site')
    shutil.copytree(site, copy)
    zip_path = os.path.join(copy, 'ide.zip')
    if not os.path.isfile(zip_path):
        raise SystemExit('error: %s has no ide.zip: is it a web IDE site?' % site)
    if replace:
        # A zip cannot replace a member: the copy's is written again
        with zipfile.ZipFile(zip_path) as z:
            names = z.namelist()
            for path, _ in replace:
                if path not in names:
                    raise SystemExit('error: %s has no %s to replace' % (zip_path, path))
            entries = [(i, z.read(i.filename)) for i in z.infolist()
                       if i.filename not in dict(replace)]
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
            for info, data in entries:
                z.writestr(info, data)
            for path, src in replace:
                z.write(src, path)
    extension = tour_extension(tour)
    folder = 'boot/Extensions/%s/' % extension
    with zipfile.ZipFile(zip_path, 'a', zipfile.ZIP_DEFLATED) as z:
        if any(n.startswith(folder) for n in z.namelist()):
            raise SystemExit('error: %s already has %s' % (zip_path, folder))
        z.writestr(folder + 'manifest.xml', MANIFEST % extension)
        z.write(tour, folder + extension + '.livecodescript')
        # (in a folder of their own: the IDE takes an extension's first
        # script file as the extension)
        for src in add:
            z.write(src, folder + 'files/' + os.path.basename(src))
    return copy


def serve(folder):
    class Handler(http.server.SimpleHTTPRequestHandler):
        extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map,
                              **{'.wasm': 'application/wasm', '.js': 'text/javascript'})

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0),
                                             functools.partial(Handler, directory=folder))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def write_page(out, shots, lines):
    """<out>/index.html: each screenshot under its name, and the tour's lines."""
    parts = ['<!DOCTYPE html><html><head><meta charset="utf-8">',
             '<title>Web IDE screenshots</title><style>',
             'body{font:14px system-ui,sans-serif;margin:24px;background:#f4f6f8;color:#17202a}',
             'figure{margin:0 0 32px}figcaption{font-weight:600;margin:0 0 8px}',
             'img{max-width:100%;border:1px solid #d3d9e0;box-shadow:0 1px 4px #0002}',
             'pre{white-space:pre-wrap;background:#fff;border:1px solid #d3d9e0;padding:12px}',
             '</style></head><body><h1>Web IDE screenshots</h1>']
    for name in shots:
        parts.append('<figure><figcaption>%s</figcaption><img src="shots/%s.png" alt="%s"></figure>'
                     % (html.escape(name), html.escape(name), html.escape(name)))
    parts.append('<h2>The tour</h2><pre>%s</pre></body></html>' % html.escape('\n'.join(lines)))
    with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(parts))


def summary(problems, shots, finished):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if not path:
        return
    with open(path, 'a', encoding='utf-8') as f:
        f.write('### Web IDE screenshots\n\n')
        f.write('%s: %d screenshots.\n\n' % ('Passed' if not problems else 'Failed', len(shots)))
        if not finished:
            f.write('The tour did not finish.\n\n')
        for p in problems:
            f.write('- %s\n' % p.replace('\n', ' '))
        if problems:
            f.write('\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the web IDE site (build_site.py --out)')
    ap.add_argument('--out', required=True, help='the folder for the screenshots and logs (replaced)')
    ap.add_argument('--browser', default='chromium', choices=['chromium', 'firefox', 'webkit'],
                    help='the browser (Playwright\'s build)')
    ap.add_argument('--timeout', type=float, default=600, help='seconds for the whole tour')
    ap.add_argument('--only', default='', metavar='STEPS',
                    help='comma-separated steps of the tour to run (default: all)')
    ap.add_argument('--keep-serving', action='store_true', help='keep serving after the tour')
    ap.add_argument('--tour', default=TOUR, help='the tour (default: web-ide-tour.livecodescript)')
    ap.add_argument('--add', action='append', default=[], metavar='FILE',
                    help='a file to put in the tour\'s extension folder, in files/')
    ap.add_argument('--replace', action='append', default=[], metavar='PATH=FILE',
                    help='a file of the copy\'s ide.zip to replace')
    ap.add_argument('--relay', action='store_true', help='run a local Nostr relay for the tour')
    ap.add_argument('--size', type=page_size, default=(WIDTH, HEIGHT), metavar='WIDTHxHEIGHT',
                    help='the page\'s size as it opens (default %dx%d)' % (WIDTH, HEIGHT))
    args = ap.parse_args(argv)
    replace = []
    for item in args.replace:
        path, sep, src = item.partition('=')
        if not sep or not os.path.isfile(src):
            raise SystemExit('error: --replace %s: not PATH=FILE of a file' % item)
        replace.append((path, src))

    from playwright.sync_api import sync_playwright

    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    shots_dir = os.path.join(out, 'shots')
    os.makedirs(shots_dir)
    site = make_site(os.path.abspath(args.site), out, os.path.abspath(args.tour),
                     [os.path.abspath(a) for a in args.add], replace)
    server = serve(site)
    url = 'http://127.0.0.1:%d/' % server.server_address[1]
    log('Site  : %s (a copy of %s, with the tour)' % (site, args.site))
    log('Page  : %s at %dx%d' % (url, args.size[0], args.size[1]))
    relay_url = ''
    if args.relay:
        sys.path.insert(0, HERE)
        import nostr_test_relay
        relay = nostr_test_relay.serve(os.path.join(out, 'relay.txt'))
        relay_url = 'ws://127.0.0.1:%d/' % relay.server_address[1]
        log('Relay : %s' % relay_url)

    lines, shots, problems = [], [], []
    finished = False
    started = time.time()
    console = open(os.path.join(out, 'console.txt'), 'w', encoding='utf-8')

    def stamp():
        return '%7.1f' % (time.time() - started)

    with sync_playwright() as p:
        browser = getattr(p, args.browser).launch()
        page = browser.new_page(viewport={'width': args.size[0], 'height': args.size[1]})
        page.on('console', lambda m: console.write('%s %s %s\n' % (stamp(), m.type, m.text)))

        def page_error(error):
            console.write('%s PAGE ERROR %s\n' % (stamp(), error))
            problems.append('page error: %s' % error)
        page.on('pageerror', page_error)
        page.add_init_script(PAGE_SCRIPT)
        try:
            page.goto(url)
            page.wait_for_function('%s || %s' % (OPENED, FAILED), timeout=args.timeout * 1000 / 2)
            if page.evaluate(FAILED):
                status = page.evaluate("document.getElementById('error').textContent")
                raise RuntimeError('the IDE did not open: %s' % status)
            log('%s the IDE opened' % stamp())
            page.wait_for_timeout(3000)

            # The page as a first visit shows it, with its note; then the
            # note closed, as a user closes it
            page.screenshot(path=os.path.join(shots_dir, '00-first-visit.png'))
            shots.append('00-first-visit')
            note = page.locator('#note button')
            if note.is_visible():
                note.click()
            page.evaluate('a => { window.oxtTour.only = a[0]; window.oxtTour.relay = a[1]; '
                          'window.oxtTour.go = true; }', [args.only, relay_url])

            while time.time() - started < args.timeout:
                new = page.evaluate('window.oxtTour.take()')
                if not new:
                    page.wait_for_timeout(200)
                    continue
                for line in new:
                    lines.append(line)
                    log('%s %s' % (stamp(), line))
                    words = line.split()
                    if words[0] == 'ACT' and len(words) >= 3:
                        act(page, words, shots_dir, shots, problems)
                        page.evaluate('n => { window.oxtTour.done = n; }', int(words[1]))
                    elif words[0] == 'DONE':
                        finished = True
                if finished:
                    break
            if not finished:
                problems.append('the tour did not finish within %d s' % args.timeout)
            if args.keep_serving:
                log('Serving %s; Ctrl-C ends it' % url)
                try:
                    while True:
                        time.sleep(1)
                except KeyboardInterrupt:
                    pass
        except Exception as e:  # noqa: BLE001 - every failure is reported
            problems.append('%s: %s' % (type(e).__name__, str(e).splitlines()[0] if str(e) else ''))
            try:
                page.screenshot(path=os.path.join(shots_dir, 'zz-failure.png'))
                shots.append('zz-failure')
            except Exception:  # noqa: BLE001
                pass
        finally:
            browser.close()
            server.shutdown()
            console.close()

    problems += ['script error: %s' % x[6:] for x in lines if x.startswith('ERROR ')]
    problems += ['step failed: %s' % x[5:] for x in lines if x.startswith('STEP ') and ' FAILED' in x]
    with open(os.path.join(out, 'tour.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    write_page(out, shots, lines)
    shutil.rmtree(site, ignore_errors=True)

    summary(problems, shots, finished)
    log('Screenshots: %d in %s' % (len(shots), shots_dir))
    for problem in problems:
        log('FAILED: %s' % problem)
        annotate('error', problem)
    if not problems:
        log('Passed')
    return 1 if problems else 0


def tap(page, x, y):
    """A finger's tap at x, y: touchstart, a moment, touchend, as a person's
    finger gives them (Chromium's DevTools protocol, with the page's touch
    screen on only for the tap, so the rest of the tour has a mouse)."""
    session = page.context.new_cdp_session(page)
    try:
        session.send('Emulation.setTouchEmulationEnabled', {'enabled': True, 'maxTouchPoints': 1})
        session.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [{'x': x, 'y': y}]})
        time.sleep(0.15)
        session.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
        session.send('Emulation.setTouchEmulationEnabled', {'enabled': False})
    finally:
        session.detach()


def act(page, words, shots_dir, shots, problems):
    """Does what an ACT line asks (web-ide-tour.livecodescript, "Lines")."""
    verb, rest = words[2], words[3:]
    try:
        if verb == 'shot' and len(rest) == 1:
            page.screenshot(path=os.path.join(shots_dir, rest[0] + '.png'))
            shots.append(rest[0])
        elif verb == 'click' and len(rest) == 2:
            page.mouse.click(float(rest[0]), float(rest[1]))
        elif verb == 'move' and len(rest) == 2:
            page.mouse.move(float(rest[0]), float(rest[1]))
        elif verb == 'tap' and len(rest) == 2:
            tap(page, float(rest[0]), float(rest[1]))
        elif verb == 'key' and len(rest) == 1:
            page.keyboard.press(rest[0])
        elif verb == 'dialog' and not rest:
            page.click('.oxt-dialog-default', timeout=5000)
        elif verb == 'size' and len(rest) == 2:
            page.set_viewport_size({'width': int(rest[0]), 'height': int(rest[1])})
        else:
            problems.append('the tour asked for what the page cannot do: %s' % ' '.join(words))
    except Exception as e:  # noqa: BLE001
        problems.append('%s failed: %s' % (' '.join(words), e))


if __name__ == '__main__':
    sys.exit(main())
