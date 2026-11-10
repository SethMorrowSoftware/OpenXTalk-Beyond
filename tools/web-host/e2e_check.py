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

"""Checks the self-hosted web end to end in headless Chromium (Playwright),
against a release's real web IDE and Stack Player.

    python3 e2e_check.py --host-ide URL --host-player URL --data DIR
        [--static-ide URL --static-player URL] [--password PW] --out DIR

--host-*    oxt_web_host.py serving the release (tier 2), with --data DIR
--static-*  the web bundle on a plain web server (tier 1: Apache with its
            .htaccess, nginx with its snippet), checked as a browser sees it

Tier 2:
1. Headers: Brotli, gzip and plain copies of the engine with their lengths,
   304 on a repeat, the Player on its own origin without the storage, no
   file outside the site, a write from the Player's origin refused, the
   password asked for when there is one.
2. Browser A (a fresh profile) opens the IDE; a stack written into the
   engine's ~/Documents (as the engine's own save writes it, then
   LiveCodeStorage.changed(), which the engine calls after a save) reaches
   the server's files folder.
3. Browser B (another fresh profile: nothing in its IndexedDB) opens the
   IDE: the stack is in its ~/Documents, the same bytes, before the IDE
   has started.
4. A deletes it: the server's copy goes; B, reopened, no longer has it.
5. The Player opens on its own origin, without the storage script.

Tier 1: the IDE and the Player open from the static server, and the engine
arrives compressed (Content-Encoding br or gzip) with type application/wasm.

Screenshots and each page's console go to --out. Exits 1 on any failure.
"""
import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

OPENED = "document.getElementById('loading').style.display === 'none'"
FAILED = "document.getElementById('error').style.display === 'block'"
PLAYER_READY = "document.getElementById('open') && !document.getElementById('open').disabled"
STACK = 'Hosted Test.oxtstack'
# A stand-in for a saved stack: bytes, not text, so a change in transit shows
STACK_BYTES = bytes(range(256)) * 64 + b'OXT-Beyond web host check'

failures = []


def check(ok, text):
    print(('PASS ' if ok else 'FAIL ') + text, flush=True)
    if not ok:
        failures.append(text)


def request(url, method='HEAD', enc=None, etag=None, password=None, origin=None, data=None):
    req = urllib.request.Request(url, method=method, data=data)
    req.add_header('Accept-Encoding', enc or 'identity')
    if etag:
        req.add_header('If-None-Match', etag)
    if password:
        req.add_header('Authorization', 'Basic ' + base64.b64encode(b'u:' + password.encode()).decode())
    if origin:
        req.add_header('Origin', origin)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.headers, (r.read() if method != 'HEAD' else b'')
    except urllib.error.HTTPError as e:
        return e.code, e.headers, b''


def engine_name(base, password=None):
    """The engine's .wasm, as the page names it."""
    _, _, page = request(base + '/', 'GET', password=password)
    text = page.decode('utf-8', 'replace')
    import re
    m = re.search(r"""['"]([\w.-]+-community-[\w.-]+)['"]""", text)
    if not m:
        m = re.search(r'([\w.-]+-community-[\w.-]+?)\.(?:js|wasm)', text)
    return (m.group(1) if m else 'development-community') + '.wasm'


def headers_tier2(a):
    pw = a.password
    wasm = a.host_ide + '/' + engine_name(a.host_ide, pw)
    for enc, want in (('br, gzip', 'br'), ('gzip', 'gzip'), (None, None)):
        status, h, _ = request(wasm, enc=enc, password=pw)
        if want == 'br' and a.no_brotli:
            want = 'gzip'
        check(status == 200 and h.get('Content-Encoding') == want and int(h.get('Content-Length') or 0) > 0
              and h.get('Content-Type') == 'application/wasm',
              'the engine with Accept-Encoding %s: %s, %s, %s, %s bytes'
              % (enc, status, h.get('Content-Type'), h.get('Content-Encoding'), h.get('Content-Length')))
    status, h, _ = request(wasm, enc='br, gzip', password=pw)
    status2, _, _ = request(wasm, enc='br, gzip', etag=h.get('ETag'), password=pw)
    check(status2 == 304, 'a repeat visit gets 304 (%s)' % status2)
    _, _, page = request(a.host_ide + '/', 'GET', password=pw)
    check(b'/_host/sync.js' in page, 'the IDE page carries the storage script')
    _, _, ppage = request(a.host_player + '/', 'GET')
    check(ppage and b'/_host/sync.js' not in ppage, 'the Player page does not')
    check(request(a.host_player + '/_host/api/files')[0] == 404, 'the Player has no storage')
    check(request(a.host_ide + '/..%2f..%2f..%2fetc/passwd', password=pw)[0] in (400, 404),
          'no file outside the site')
    status = request(a.host_ide + '/_host/api/files/x.txt', 'PUT', password=pw, origin=a.host_player,
                     data=b'x')[0]
    check(status == 403, "a write from the Player's origin is refused (%s)" % status)
    if pw:
        check(request(a.host_ide + '/')[0] == 401, 'the IDE asks for its password')
        check(request(a.host_ide + '/', password=pw + 'x')[0] == 401, 'a wrong password is refused')
        check(request(a.host_player + '/')[0] == 200, 'the Player asks for none')


def open_ide(browser, url, tag, out, password=None, timeout=300):
    options = {'viewport': {'width': 1400, 'height': 900}}
    if password:
        options['http_credentials'] = {'username': 'oxt', 'password': password}
    ctx = browser.new_context(**options)
    pg = ctx.new_page()
    log = open(os.path.join(out, '%s-console.txt' % tag), 'w', encoding='utf-8')
    t0 = time.time()
    pg.on('console', lambda m: (log.write('%.1f %s\n' % (time.time() - t0, m.text)), log.flush()))
    pg.on('pageerror', lambda e: (log.write('%.1f PAGE ERROR %s\n' % (time.time() - t0, e)), log.flush()))
    pg.goto(url + '/')
    pg.wait_for_function('%s || %s' % (OPENED, FAILED), timeout=timeout * 1000)
    if pg.evaluate(FAILED):
        text = pg.evaluate("document.getElementById('error').textContent")
        check(False, '%s: the IDE opens (%s)' % (tag, text.strip()))
        return ctx, pg, False
    print('  %s: the IDE opened after %.0f s' % (tag, time.time() - t0), flush=True)
    return ctx, pg, True


def wait_sync(pg):
    pg.wait_for_function('window.oxtHostSync && window.oxtHostSync.ready', timeout=60000)


def documents(pg):
    return pg.evaluate("""() => { try { return FS.readdir(window.oxtHostSync.folder)
        .filter(n => n !== '.' && n !== '..'); } catch (e) { return []; } }""")


def file_digest(pg, name):
    return pg.evaluate("""name => { try {
        const data = FS.readFile(window.oxtHostSync.folder + '/' + name);
        return Array.from(data).length + ':' + Array.from(data.slice(-26)).join(','); }
        catch (e) { return ''; } }""", name)


def wait_for(condition, seconds=20):
    end = time.time() + seconds
    while time.time() < end:
        if condition():
            return True
        time.sleep(0.25)
    return condition()


def sync_tier2(browser, a):
    files = os.path.join(a.data, 'files')
    on_server = os.path.join(files, STACK)
    if os.path.exists(on_server):
        os.remove(on_server)
    expected = '%d:%s' % (len(STACK_BYTES), ','.join(str(b) for b in STACK_BYTES[-26:]))

    # ---- 2. A saves a stack -------------------------------------------------
    ctx_a, pa, ok = open_ide(browser, a.host_ide, 'tier2-A', a.out, a.password)
    if not ok:
        return
    wait_sync(pa)
    folder = pa.evaluate('window.oxtHostSync.folder')
    check(folder.endswith('/Documents'), "A: the IDE's Documents folder is %s" % folder)
    pa.evaluate("""bytes => {
        FS.writeFile(window.oxtHostSync.folder + '/%s', new Uint8Array(bytes));
        LiveCodeStorage.changed(); }""" % STACK, list(STACK_BYTES))
    check(wait_for(lambda: os.path.isfile(on_server) and os.path.getsize(on_server) == len(STACK_BYTES)),
          'A: the server has the stack (%s bytes)'
          % (os.path.getsize(on_server) if os.path.isfile(on_server) else '-'))
    if os.path.isfile(on_server):
        with open(on_server, 'rb') as f:
            check(hashlib.sha256(f.read()).digest() == hashlib.sha256(STACK_BYTES).digest(),
                  "A: the server's copy is the same bytes")
    pa.screenshot(path=os.path.join(a.out, 'tier2-A-saved.png'))

    # ---- 2b. A again, with the server's listing failing --------------------
    # This browser's copy loads, the listing does not: nothing is deleted
    # on the server because of a folder it could not compare
    pa2 = ctx_a.new_page()
    pa2.route('**/_host/api/files', lambda route: route.abort())
    pa2.goto(a.host_ide + '/')
    pa2.wait_for_function(OPENED, timeout=300000)
    wait_sync(pa2)
    pa2.evaluate('window.oxtHostSync.push()')
    pa2.wait_for_timeout(3000)
    check(os.path.isfile(on_server) and pa2.evaluate('window.oxtHostSync.errors') >= 1,
          'A, with the listing failing: the server keeps the stack')
    pa2.close()

    # ---- 3. B, a fresh browser, gets it -------------------------------------
    ctx_b, pb, ok = open_ide(browser, a.host_ide, 'tier2-B', a.out, a.password)
    if not ok:
        return
    wait_sync(pb)
    check(STACK in documents(pb), 'B: the stack is in the Documents of a fresh browser (%s)' % documents(pb))
    check(file_digest(pb, STACK) == expected, 'B: the same bytes')
    pulled = pb.evaluate('window.oxtHostSync.pulled')
    check(pulled >= 1, 'B: it came in before the IDE started (%s pulled)' % pulled)
    pb.screenshot(path=os.path.join(a.out, 'tier2-B-opened.png'))

    # ---- 4. A deletes it ----------------------------------------------------
    pa.evaluate("""() => { FS.unlink(window.oxtHostSync.folder + '/%s'); LiveCodeStorage.changed(); }""" % STACK)
    check(wait_for(lambda: not os.path.exists(on_server)), "A deleted it: the server's copy is gone")
    ctx_a.close()
    # B comes back with the same profile: the stack is still in its
    # IndexedDB, unchanged since the last sync, so the delete reaches it
    pb.wait_for_timeout(1500)
    pb.close()
    pb = ctx_b.new_page()
    pb.goto(a.host_ide + '/')
    pb.wait_for_function(OPENED, timeout=300000)
    wait_sync(pb)
    check(STACK not in documents(pb), 'B, back after the delete, no longer has it (%s)' % documents(pb))
    ctx_b.close()

    # ---- 5. the Player, on its own origin -----------------------------------
    ctx = browser.new_context(viewport={'width': 1200, 'height': 800})
    pg = ctx.new_page()
    pg.goto(a.host_player + '/')
    pg.wait_for_function(PLAYER_READY, timeout=180000)
    check(pg.evaluate('typeof window.oxtHostSync') == 'undefined', 'the Player runs without the storage script')
    pg.screenshot(path=os.path.join(a.out, 'tier2-player.png'))
    ctx.close()


def static_tier1(browser, a):
    wasm = a.static_ide + '/' + engine_name(a.static_ide)
    status, h, _ = request(wasm, enc='br, gzip')
    check(status == 200 and h.get('Content-Type') == 'application/wasm' and
          h.get('Content-Encoding') in ('br', 'gzip'),
          'tier 1: the engine arrives compressed (%s, %s, %s, %s bytes)'
          % (status, h.get('Content-Type'), h.get('Content-Encoding'), h.get('Content-Length')))
    status, h, _ = request(wasm)
    check(status == 200 and h.get('Content-Type') == 'application/wasm' and not h.get('Content-Encoding'),
          'tier 1: and plain to a browser that asks for it plain (%s, %s)' % (status, h.get('Content-Encoding')))
    ctx, pg, ok = open_ide(browser, a.static_ide, 'tier1-ide', a.out)
    if ok:
        check(pg.evaluate('typeof window.oxtHostSync') == 'undefined', 'tier 1: the IDE opens, as the release has it')
        pg.screenshot(path=os.path.join(a.out, 'tier1-ide.png'))
    ctx.close()
    if a.static_player:
        ctx = browser.new_context(viewport={'width': 1200, 'height': 800})
        pg = ctx.new_page()
        pg.goto(a.static_player + '/')
        try:
            pg.wait_for_function(PLAYER_READY, timeout=180000)
            check(True, 'tier 1: the Player opens')
        except Exception as e:  # noqa: BLE001 - reported as a failure
            check(False, 'tier 1: the Player opens (%s)' % e)
        pg.screenshot(path=os.path.join(a.out, 'tier1-player.png'))
        ctx.close()


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--host-ide')
    p.add_argument('--host-player')
    p.add_argument('--data')
    p.add_argument('--password')
    p.add_argument('--no-brotli', action='store_true', help='the host made gzip copies only')
    p.add_argument('--static-ide')
    p.add_argument('--static-player')
    p.add_argument('--out', default='web-host-check')
    p.add_argument('--chromium', help="a Chromium to run instead of Playwright's own")
    a = p.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        browser = pw.chromium.launch(**({'executable_path': a.chromium} if a.chromium else {}))
        if a.host_ide:
            headers_tier2(a)
            sync_tier2(browser, a)
        if a.static_ide:
            static_tier1(browser, a)
        browser.close()
    with open(os.path.join(a.out, 'result.json'), 'w') as f:
        json.dump({'failures': failures}, f, indent=1)
    print('\n%d failure(s)' % len(failures))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
