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

"""The self-hosted web (tools/web-host): the web host (tier 2) and the web
bundle (tier 1), on made-up release files, with no browser and no engine.
.github/workflows/web-host.yml checks both against a real release in
Chromium, Apache and nginx (tools/web-host/e2e_check.py).

  python3 -m unittest discover -s tools/ci/tests -p test_web_host.py
"""

import base64
import gzip
import hashlib
import http.client
import io
import json
import os
import re
import shutil
import sys
import tempfile
import threading
import time
import unittest
import zipfile
from unittest import mock

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
HOST_DIR = os.path.join(REPO, 'tools', 'web-host')
sys.path.insert(0, HOST_DIR)

import oxt_web_host as host  # noqa: E402
import make_bundle  # noqa: E402

ENGINE = 'development-community-9.9.9-BeyondEngine'
PAGE = (b'<!DOCTYPE html>\n<html>\n  <body>\n    <div id="loading"></div>\n'
        b'    <script>window.Module = {};</script>\n  </body>\n</html>\n')
# Big enough to be compressed ahead of time (PRECOMPRESS_MIN), and
# compressible
WASM = b'\x00asm\x01\x00\x00\x00' + b'OXT-Beyond engine ' * 2000
IDE_ZIP = b'PK-the-ide ' * 1000


def quiet(*args):
    pass


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)


def read(path):
    with open(path, 'rb') as f:
        return f.read()


def release_ide_zip(path, top='OXT-Beyond-9.9.9-web-ide', extra=()):
    """A web IDE zip as build_site.py --zip writes it."""
    with zipfile.ZipFile(path, 'w') as z:
        for name, data in [('index.html', PAGE), (ENGINE + '.js', b'var x = 1;\n' * 500),
                           (ENGINE + '.wasm', WASM), ('ide.zip', IDE_ZIP),
                           ('serve.py', b'print(1)\n'), ('Start Web IDE.bat', b'@echo off\n'),
                           ('README.txt', b'Run serve.py\n')] + list(extra):
            z.writestr(top + '/' + name, data)
    return path


def release_player_zip(path):
    with zipfile.ZipFile(path, 'w') as z:
        for name, data in [('index.html', PAGE.replace(b'loading', b'player')),
                           ('standalone-community-9.9.9-BeyondEngine.js', b'var p = 1;\n' * 500),
                           ('standalone-community-9.9.9-BeyondEngine.wasm', WASM),
                           ('standalone.zip', b'stack ' * 1000),
                           ('play/index.html', b'<html><body>play</body></html>'),
                           ('samples/2048.oxtstack', b'REVO2700' * 10),
                           ('assets/oxt-beyond-128.png', b'\x89PNG' + b'0' * 100)]:
            z.writestr('StackPlayer/' + name, data)
    return path


class Temp(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='web-host-test-')
        patcher = mock.patch.object(host, 'log', quiet)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(shutil.rmtree, self.work, True)

    def path(self, *parts):
        return os.path.join(self.work, *parts)

    def listing(self, folder):
        out = []
        for root, dirs, files in os.walk(folder):
            for f in files:
                out.append(os.path.relpath(os.path.join(root, f), folder).replace(os.sep, '/'))
        return sorted(out)


class PrepareTests(Temp):
    def test_the_release_zip_without_what_runs_it_locally(self):
        site = self.path('site')
        host.prepare_ide(release_ide_zip(self.path('ide.zip')), site)
        self.assertEqual(self.listing(site), sorted(['index.html', ENGINE + '.js', ENGINE + '.wasm', 'ide.zip']))
        self.assertEqual(read(os.path.join(site, ENGINE + '.wasm')), WASM)

    def test_a_folder_with_ide_zip_in_parts_is_joined_and_checked(self):
        src = self.path('package')
        write(os.path.join(src, 'index.html'), PAGE)
        write(os.path.join(src, ENGINE + '.wasm'), WASM)
        write(os.path.join(src, 'serve.py'), b'x')
        write(os.path.join(src, '__pycache__', 'serve.cpython-313.pyc'), b'x')
        halves = [IDE_ZIP[:3000], IDE_ZIP[3000:7000], IDE_ZIP[7000:]]
        for i, half in enumerate(halves):
            # part10 sorts after part2 as a number, not as text
            write(os.path.join(src, 'ide.zip.part%d' % (i if i < 2 else 10)), half)
        write(os.path.join(src, 'ide.zip.md5'), hashlib.md5(IDE_ZIP).hexdigest().encode() + b'  ide.zip\n')
        site = self.path('site')
        host.prepare_ide(src, site)
        self.assertEqual(read(os.path.join(site, 'ide.zip')), IDE_ZIP)
        self.assertEqual(self.listing(site), sorted(['index.html', ENGINE + '.wasm', 'ide.zip']))
        # Again: the joined file stays
        host.prepare_ide(src, site)
        self.assertEqual(read(os.path.join(site, 'ide.zip')), IDE_ZIP)

    def test_parts_that_do_not_match_their_md5_are_refused(self):
        src = self.path('package')
        write(os.path.join(src, 'index.html'), PAGE)
        write(os.path.join(src, ENGINE + '.wasm'), WASM)
        write(os.path.join(src, 'ide.zip.part0'), IDE_ZIP)
        write(os.path.join(src, 'ide.zip.md5'), b'0' * 32 + b'\n')
        with self.assertRaisesRegex(host.HostError, 'does not match'):
            host.prepare_ide(src, self.path('site'))
        self.assertFalse(os.path.exists(self.path('site', 'ide.zip')))

    def test_what_is_not_the_web_ide_is_refused(self):
        with zipfile.ZipFile(self.path('x.zip'), 'w') as z:
            z.writestr('top/readme.txt', 'x')
        with self.assertRaisesRegex(host.HostError, 'no index.html'):
            host.prepare_ide(self.path('x.zip'), self.path('site'))
        with zipfile.ZipFile(self.path('y.zip'), 'w') as z:
            z.writestr('top/index.html', 'x')
            z.writestr('top/' + ENGINE + '.wasm', 'x')
        with self.assertRaisesRegex(host.HostError, 'no ide.zip'):
            host.prepare_ide(self.path('y.zip'), self.path('site'))
        write(self.path('plain.txt'), b'x')
        with self.assertRaisesRegex(host.HostError, 'neither a folder nor a zip'):
            host.prepare_ide(self.path('plain.txt'), self.path('site'))

    def test_a_zip_with_a_file_outside_its_folder_is_refused(self):
        for bad in ('../evil.html', 'top/../../evil.html', '/abs/evil.html', 'C:/evil.html'):
            path = self.path('bad.zip')
            with zipfile.ZipFile(path, 'w') as z:
                z.writestr('top/index.html', PAGE)
                z.writestr(bad, 'x')
            with self.assertRaises(host.HostError, msg=bad):
                host.prepare_player(path, self.path('site'))
            self.assertFalse(os.path.exists(self.path('evil.html')))

    def test_the_player_zip(self):
        site = self.path('player')
        host.prepare_player(release_player_zip(self.path('p.zip')), site)
        self.assertIn('samples/2048.oxtstack', self.listing(site))
        self.assertIn('play/index.html', self.listing(site))

    def test_a_new_release_replaces_the_old_and_its_compressed_copies(self):
        site = self.path('site')
        host.prepare_ide(release_ide_zip(self.path('a.zip')), site)
        host.precompress(site, use_brotli=False)
        self.assertTrue(os.path.isfile(os.path.join(site, ENGINE + '.wasm.gz')))
        self.assertTrue(os.path.isfile(os.path.join(site, 'ide.zip.gz')))
        gz_before = os.path.getmtime(os.path.join(site, 'ide.zip.gz'))
        # The next release: a new engine name, the same ide.zip
        new_engine = 'development-community-9.9.10-BeyondEngine'
        with zipfile.ZipFile(self.path('b.zip'), 'w') as z:
            for name, data in [('index.html', PAGE), (new_engine + '.wasm', WASM + b'!'), ('ide.zip', IDE_ZIP)]:
                z.writestr('OXT-Beyond-9.9.10-web-ide/' + name, data)
        host.prepare_ide(self.path('b.zip'), site)
        files = self.listing(site)
        self.assertNotIn(ENGINE + '.wasm', files)
        self.assertNotIn(ENGINE + '.wasm.gz', files)
        self.assertIn(new_engine + '.wasm', files)
        # Unchanged bytes keep their copy (no 3-minute Brotli on each start)
        self.assertIn('ide.zip.gz', files)
        self.assertEqual(os.path.getmtime(os.path.join(site, 'ide.zip.gz')), gz_before)
        host.precompress(site, use_brotli=False)
        self.assertEqual(gzip.decompress(read(os.path.join(site, new_engine + '.wasm.gz'))), WASM + b'!')

    def test_a_changed_file_loses_its_old_copies(self):
        site = self.path('site')
        host.prepare_ide(release_ide_zip(self.path('a.zip')), site)
        host.precompress(site, use_brotli=False)
        release_ide_zip(self.path('b.zip'))
        with zipfile.ZipFile(self.path('b.zip'), 'w') as z:
            for name, data in [('index.html', PAGE), (ENGINE + '.wasm', WASM), ('ide.zip', IDE_ZIP + b'new')]:
                z.writestr('top/' + name, data)
        host.prepare_ide(self.path('b.zip'), site)
        self.assertFalse(os.path.exists(os.path.join(site, 'ide.zip.gz')))
        self.assertTrue(os.path.exists(os.path.join(site, ENGINE + '.wasm.gz')))


class PrecompressTests(Temp):
    def test_big_files_get_copies_and_small_ones_do_not(self):
        site = self.path('site')
        write(os.path.join(site, 'big.wasm'), WASM)
        write(os.path.join(site, 'small.js'), b'var x;')
        write(os.path.join(site, 'image.png'), b'\x89PNG' * 5000)
        made = host.precompress(site, use_brotli=False)
        self.assertEqual(made, 1)
        self.assertEqual(gzip.decompress(read(os.path.join(site, 'big.wasm.gz'))), WASM)
        self.assertFalse(os.path.exists(os.path.join(site, 'small.js.gz')))
        self.assertFalse(os.path.exists(os.path.join(site, 'image.png.gz')))
        self.assertFalse(os.path.exists(os.path.join(site, 'big.wasm.br')))
        # Made once: a second pass makes none
        self.assertEqual(host.precompress(site, use_brotli=False), 0)
        # The same bytes each time (mtime 0 in the gzip header)
        first = read(os.path.join(site, 'big.wasm.gz'))
        os.remove(os.path.join(site, 'big.wasm.gz'))
        host.precompress(site, use_brotli=False)
        self.assertEqual(read(os.path.join(site, 'big.wasm.gz')), first)

    def test_brotli_when_it_is_there(self):
        site = self.path('site')
        write(os.path.join(site, 'big.wasm'), WASM)
        fake = mock.Mock()
        fake.compress.side_effect = lambda data, quality: b'BR' + data[:10]
        with mock.patch.object(host, 'brotli', fake):
            host.precompress(site)
        self.assertEqual(read(os.path.join(site, 'big.wasm.br')), b'BR' + WASM[:10])
        fake.compress.assert_called_once()
        self.assertEqual(fake.compress.call_args[1], {'quality': 11})


class InjectTests(unittest.TestCase):
    def test_before_the_last_body_end(self):
        page = b'<html><body><script>a="</body>"</script>\n</BODY></html>'
        out = host.inject_sync(page)
        self.assertEqual(out, b'<html><body><script>a="</body>"</script>\n' + host.SYNC_TAG + b'</BODY></html>')

    def test_a_page_without_one_gets_it_at_the_end(self):
        self.assertEqual(host.inject_sync(b'<p>x'), b'<p>x\n' + host.SYNC_TAG)


class Running(Temp):
    """A web host on two free ports of this computer, on made-up sites."""
    password = None
    storage = True

    def setUp(self):
        super().setUp()
        self.sites = self.path('sites')
        host.prepare(release_ide_zip(self.path('ide.zip')), release_player_zip(self.path('p.zip')),
                     self.sites, use_brotli=False)
        self.files = self.path('files') if self.storage else None
        if self.files:
            os.makedirs(self.files)
        self.servers = host.make_servers(self.sites, '127.0.0.1', 0, 0, self.files, self.password)
        for server, _ in self.servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.addCleanup(server.server_close)
            self.addCleanup(server.shutdown)
        self.ide_port = self.servers[0][0].server_address[1]
        self.player_port = self.servers[1][0].server_address[1]

    def call(self, path, method='GET', body=None, headers=None, port=None, password=None):
        conn = http.client.HTTPConnection('127.0.0.1', port or self.ide_port, timeout=20)
        hdrs = dict(headers or {})
        if password or self.password:
            token = base64.b64encode(('anyone:%s' % (password or self.password)).encode()).decode()
            hdrs.setdefault('Authorization', 'Basic ' + token)
        conn.request(method, path, body=body, headers=hdrs)
        r = conn.getresponse()
        data = r.read()
        conn.close()
        return r.status, r.headers, data


class ServingTests(Running):
    def test_the_ide_page_carries_the_storage_script(self):
        status, h, body = self.call('/')
        self.assertEqual(status, 200)
        self.assertEqual(body, host.inject_sync(PAGE))
        self.assertEqual(int(h['Content-Length']), len(body))
        self.assertIsNone(h['Content-Encoding'])
        self.assertEqual(h['Content-Type'], 'text/html; charset=utf-8')
        # The same as /index.html, and asked for gzip still the injected page
        self.assertEqual(self.call('/index.html', headers={'Accept-Encoding': 'gzip'})[2], body)

    def test_the_player_page_does_not(self):
        status, _, body = self.call('/', port=self.player_port)
        self.assertEqual(status, 200)
        self.assertNotIn(b'/_host/sync.js', body)
        self.assertEqual(self.call('/_host/api/files', port=self.player_port)[0], 404)
        self.assertEqual(self.call('/_host/sync.js', port=self.player_port)[0], 404)

    def test_the_best_copy_the_browser_accepts(self):
        wasm = '/' + ENGINE + '.wasm'
        status, h, body = self.call(wasm, headers={'Accept-Encoding': 'gzip, deflate, br'})
        self.assertEqual((status, h['Content-Encoding'], h['Content-Type']), (200, 'gzip', 'application/wasm'))
        self.assertEqual(gzip.decompress(body), WASM)
        self.assertEqual(int(h['Content-Length']), len(body))
        self.assertEqual(h['Vary'], 'Accept-Encoding')
        for accept in ('identity', 'gzip;q=0', ''):
            status, h, body = self.call(wasm, headers={'Accept-Encoding': accept} if accept else {})
            self.assertEqual((status, h['Content-Encoding'], body), (200, None, WASM), accept)

    def test_brotli_first_when_there_is_a_copy(self):
        wasm = os.path.join(self.sites, 'ide', ENGINE + '.wasm')
        write(wasm + '.br', b'brotli bytes')
        status, h, body = self.call('/' + ENGINE + '.wasm', headers={'Accept-Encoding': 'gzip, br'})
        self.assertEqual((h['Content-Encoding'], body), ('br', b'brotli bytes'))

    def test_a_repeat_visit_gets_304_and_a_new_file_does_not(self):
        wasm = '/' + ENGINE + '.wasm'
        _, h, _ = self.call(wasm, headers={'Accept-Encoding': 'gzip'})
        self.assertEqual(h['Cache-Control'], 'no-cache')
        status, h2, body = self.call(wasm, headers={'Accept-Encoding': 'gzip', 'If-None-Match': h['ETag']})
        self.assertEqual((status, body), (304, b''))
        # Each copy has its own tag
        _, plain, _ = self.call(wasm)
        self.assertNotEqual(plain['ETag'], h['ETag'])
        # A page's tag differs from the file's own (the script was added)
        _, page, _ = self.call('/')
        self.assertTrue(page['ETag'].endswith('-s"'))

    def test_head(self):
        status, h, body = self.call('/' + ENGINE + '.wasm', 'HEAD')
        self.assertEqual((status, body, int(h['Content-Length'])), (200, b'', len(WASM)))

    def test_headers_every_answer_has(self):
        for path in ('/', '/' + ENGINE + '.wasm', '/nothing'):
            h = self.call(path)[1]
            self.assertEqual(h['X-Content-Type-Options'], 'nosniff', path)
            self.assertEqual(h['X-Frame-Options'], 'SAMEORIGIN', path)
            self.assertEqual(h['Referrer-Policy'], 'no-referrer', path)

    def test_nothing_outside_the_site(self):
        secret = self.path('secret.txt')
        write(secret, b'secret')
        for path in ('/../secret.txt', '/..%2fsecret.txt', '/%2e%2e/secret.txt', '/..%5csecret.txt',
                     '/a/../../secret.txt', '/index.html%00.txt', '/ide.zip.oxt-tmp'):
            status, _, body = self.call(path)
            self.assertIn(status, (400, 404), path)
            self.assertNotIn(b'secret', body, path)

    def test_a_folder_without_its_slash(self):
        status, h, _ = self.call('/play?x=1', port=self.player_port)
        self.assertEqual((status, h['Location']), (301, '/play/?x=1'))
        self.assertEqual(self.call('/play/', port=self.player_port)[0], 200)

    def test_health_and_other_methods(self):
        status, _, body = self.call('/_host/health')
        self.assertEqual((status, json.loads(body)), (200, {'ok': True, 'site': 'ide'}))
        self.assertEqual(self.call('/', 'POST', b'x')[0], 405)

    def test_the_storage_script_is_served(self):
        status, h, body = self.call('/_host/sync.js')
        self.assertEqual((status, h['Content-Type']), (200, 'text/javascript'))
        self.assertEqual(body, read(os.path.join(HOST_DIR, 'sync.js')))


class StorageTests(Running):
    def url(self, rel):
        return '/_host/api/files/' + '/'.join(
            __import__('urllib.parse').parse.quote(p, safe='') for p in rel.split('/'))

    def listing_api(self):
        status, h, body = self.call('/_host/api/files')
        self.assertEqual((status, h['Cache-Control']), (200, 'no-store'))
        return json.loads(body)['files']

    def test_put_list_get_delete(self):
        self.assertEqual(self.listing_api(), {})
        rel = 'My Stacks/Hello World.oxtstack'
        status, _, _ = self.call(self.url(rel), 'PUT', b'REVO2700 stack',
                                 {'X-Mtime': '1700000000', 'Origin': 'http://127.0.0.1:%d' % self.ide_port})
        self.assertEqual(status, 200)
        self.assertEqual(read(os.path.join(self.files, 'My Stacks', 'Hello World.oxtstack')), b'REVO2700 stack')
        self.assertEqual(self.listing_api(), {rel: [14, 1700000000]})
        status, h, body = self.call(self.url(rel))
        self.assertEqual((status, body, h['X-Mtime']), (200, b'REVO2700 stack', '1700000000'))
        # Replaced
        self.call(self.url(rel), 'PUT', b'v2', {'X-Mtime': '1700000100'})
        self.assertEqual(self.listing_api(), {rel: [2, 1700000100]})
        status, _, _ = self.call(self.url(rel), 'DELETE')
        self.assertEqual(status, 200)
        self.assertEqual(self.listing_api(), {})
        # The folder it left empty goes too, and the storage itself stays
        self.assertEqual(os.listdir(self.files), [])
        self.assertEqual(self.call(self.url(rel))[0], 404)
        # Deleting what is not there is no error
        self.assertEqual(self.call(self.url(rel), 'DELETE')[0], 200)

    def test_an_older_save_does_not_replace_a_newer_one(self):
        rel = 'Shared.oxtstack'
        self.assertEqual(self.call(self.url(rel), 'PUT', b'newer', {'X-Mtime': '1700000200'})[0], 200)
        status, h, _ = self.call(self.url(rel), 'PUT', b'older!', {'X-Mtime': '1700000100'})
        self.assertEqual((status, h['X-Mtime']), (409, '1700000200'))
        self.assertEqual(read(os.path.join(self.files, rel)), b'newer')
        self.assertEqual(self.listing_api(), {rel: [5, 1700000200]})
        # The same second, or later, replaces it; nothing is left half-written
        self.assertEqual(self.call(self.url(rel), 'PUT', b'same s', {'X-Mtime': '1700000200'})[0], 200)
        self.assertEqual(read(os.path.join(self.files, rel)), b'same s')
        self.assertEqual(os.listdir(self.files), [rel])

    def test_writes_from_another_site_are_refused(self):
        for headers in ({'Origin': 'http://127.0.0.1:%d' % self.player_port},
                        {'Origin': 'https://evil.example'},
                        {'Origin': 'null'},
                        {'Sec-Fetch-Site': 'same-site'},
                        {'Sec-Fetch-Site': 'cross-site'}):
            self.assertEqual(self.call(self.url('x.oxtstack'), 'PUT', b'x', headers)[0], 403, headers)
            self.assertEqual(self.call(self.url('x.oxtstack'), 'DELETE', None, headers)[0], 403, headers)
        self.assertEqual(os.listdir(self.files), [])

    def test_a_refused_write_reads_its_body_before_it_closes(self):
        # A server that closes with a request's body unread resets the
        # connection, and the reset can come before the answer is read:
        # on Windows, http.client failed with WinError 10053/10054 on a
        # refused PUT (#485's CI, windows-latest). Each refusal's answer
        # is followed by a clean end, never a reset
        import socket
        cases = [({'Origin': 'https://evil.example'}, self.url('x.oxtstack'), 403),
                 ({}, '/_host/api/files/../outside.txt', 400),
                 ({}, '/_host/api/files/', 400)]
        os.makedirs(os.path.join(self.files, 'folder'))
        cases.append(({}, self.url('folder'), 409))
        for headers, path, status in cases:
            for attempt in range(20):
                body = b'y' * 4096
                lines = ['PUT %s HTTP/1.1' % path, 'Host: 127.0.0.1:%d' % self.ide_port,
                         'Content-Length: %d' % len(body)]
                lines += ['%s: %s' % kv for kv in headers.items()]
                request = ('\r\n'.join(lines) + '\r\n\r\n').encode() + body
                with socket.create_connection(('127.0.0.1', self.ide_port), timeout=20) as s:
                    s.sendall(request)
                    got = b''
                    try:
                        while True:
                            block = s.recv(65536)
                            if not block:
                                break
                            got += block
                    except ConnectionResetError:
                        self.fail('the connection was reset after %r (%s), attempt %d' % (path, headers, attempt + 1))
                self.assertTrue(got.startswith(b'HTTP/1.0 %d' % status) or got.startswith(b'HTTP/1.1 %d' % status),
                                (path, got[:40]))
        self.assertEqual(os.listdir(self.files), ['folder'])

    def test_an_answer_does_not_wait_for_a_body_that_never_comes(self):
        # A POST, or a PUT onto a folder, is answered at once even when the
        # body it names never comes (as it was before its body was read)
        import socket
        os.makedirs(os.path.join(self.files, 'folder'), exist_ok=True)
        for method, path, status in (('POST', '/', 405), ('PUT', self.url('folder'), 409),
                                     ('PUT', self.url('x.oxtstack'), 403)):
            headers = ['%s %s HTTP/1.1' % (method, path), 'Host: 127.0.0.1:%d' % self.ide_port,
                       'Content-Length: 5']
            if status == 403:
                headers.append('Origin: https://evil.example')
            with socket.create_connection(('127.0.0.1', self.ide_port), timeout=20) as s:
                s.sendall(('\r\n'.join(headers) + '\r\n\r\nx').encode())
                s.settimeout(3)
                try:
                    got = s.recv(65536)
                except socket.timeout:
                    self.fail('no answer in 3 s to %s %s with its body unsent' % (method, path))
                self.assertIn(b' %d ' % status, got.split(b'\r\n', 1)[0], (method, path))

    def test_paths_stay_in_the_storage(self):
        write(self.path('outside.txt'), b'keep')
        for rel in ('../outside.txt', '..%2foutside.txt', 'a/../../outside.txt', '', 'a//b',
                    'x.oxt-tmp', '.', 'a/./b'):
            status = self.call('/_host/api/files/' + rel, 'PUT', b'evil')[0]
            self.assertIn(status, (400, 404), rel)
            self.assertIn(self.call('/_host/api/files/' + rel, 'DELETE')[0], (400, 404), rel)
        self.assertEqual(read(self.path('outside.txt')), b'keep')
        self.assertEqual(os.listdir(self.files), [])

    def test_a_put_needs_its_length_and_has_a_limit(self):
        conn = http.client.HTTPConnection('127.0.0.1', self.ide_port, timeout=20)
        conn.putrequest('PUT', self.url('a.oxtstack'))
        conn.endheaders()
        r = conn.getresponse()
        self.assertEqual(r.status, 411)
        conn.close()
        with mock.patch.object(host, 'MAX_UPLOAD', 10):
            conn = http.client.HTTPConnection('127.0.0.1', self.ide_port, timeout=20)
            conn.putrequest('PUT', self.url('a.oxtstack'))
            conn.putheader('Content-Length', '11')
            conn.endheaders()
            r = conn.getresponse()
            self.assertEqual(r.status, 413)
            conn.close()
        self.assertEqual(os.listdir(self.files), [])

    def test_unfinished_uploads_are_not_listed(self):
        write(os.path.join(self.files, 'half.oxtstack.1.oxt-tmp'), b'x')
        write(os.path.join(self.files, 'whole.oxtstack'), b'xy')
        self.assertEqual(list(self.listing_api()), ['whole.oxtstack'])


class DiscardBodyTests(Temp):
    """A request answered without its body (a refused write, a POST) has
    a small body read and dropped before the connection closes: closing
    with it unread resets the connection, and on Windows the reset can
    land before the client reads the answer (WinError 10053/10054 in
    test_writes_from_another_site_are_refused, #485's windows-latest).
    A body past the cap is left unread, as before; the connection closes
    either way."""

    def handler(self, length, data):
        cls = host.make_handler(host.Site('ide', self.work))
        h = cls.__new__(cls)
        h.headers = http.client.HTTPMessage()
        if length is not None:
            h.headers['Content-Length'] = str(length)
        h.rfile = io.BytesIO(data)
        h.close_connection = False
        return h

    def test_a_small_body_is_read_to_its_end_and_no_further(self):
        h = self.handler(5, b'hello' + b'NEXT REQUEST')
        h.discard_body()
        self.assertEqual(h.rfile.tell(), 5)
        self.assertTrue(h.close_connection)

    def test_a_body_past_the_cap_is_left(self):
        h = self.handler(host.DISCARD_LIMIT + 1, b'y' * (host.DISCARD_LIMIT + 1))
        h.discard_body()
        self.assertEqual(h.rfile.tell(), 0)
        self.assertTrue(h.close_connection)

    def test_a_short_body_ends_the_reading(self):
        h = self.handler(100, b'only this')
        h.discard_body()
        self.assertEqual(h.rfile.tell(), len(b'only this'))
        self.assertTrue(h.close_connection)

    def test_no_body_keeps_the_connection(self):
        for length in (None, 0):
            h = self.handler(length, b'GET / HTTP/1.1')
            h.discard_body()
            self.assertEqual(h.rfile.tell(), 0)
            self.assertFalse(h.close_connection)

    def test_a_body_that_never_comes_is_waited_for_a_bounded_time(self):
        # A client that names a length and sends less, keeping its socket
        # open, must not hold the thread: the reading gives up after
        # DISCARD_SECONDS and the connection closes
        import socket
        a, b = socket.socketpair()
        self.addCleanup(a.close)
        self.addCleanup(b.close)
        h = self.handler(5, b'')
        h.connection = a
        h.rfile = a.makefile('rb')
        b.sendall(b'x')
        with mock.patch.object(host, 'DISCARD_SECONDS', 0.5):
            started = time.monotonic()
            h.discard_body()
            took = time.monotonic() - started
        self.assertLess(took, 3)
        self.assertTrue(h.close_connection)
        self.assertIsNone(a.gettimeout())     # the socket's own timeout comes back

    def test_a_bad_length_reads_nothing_and_closes(self):
        h = self.handler('ten', b'0123456789')
        h.discard_body()
        self.assertEqual(h.rfile.tell(), 0)
        self.assertTrue(h.close_connection)


class PasswordTests(Running):
    password = 'correct horse'

    def test_the_ide_and_its_storage_ask_for_it(self):
        for path in ('/', '/' + ENGINE + '.wasm', '/_host/api/files', '/_host/sync.js'):
            status, h, _ = self.call(path, headers={'Authorization': 'Basic ' + base64.b64encode(
                b'x:wrong').decode()})
            self.assertEqual(status, 401, path)
            self.assertIn('Basic realm="OXT-Beyond"', h['WWW-Authenticate'])
            self.assertEqual(self.call(path, headers={'Authorization': 'Bearer x'})[0], 401, path)
            self.assertEqual(self.call(path)[0], 200, path)
        self.assertEqual(self.call('/_host/api/files/a', 'PUT', b'x',
                                   {'Authorization': 'Basic Og=='})[0], 401)

    def test_the_player_and_health_do_not(self):
        conn = http.client.HTTPConnection('127.0.0.1', self.player_port, timeout=20)
        conn.request('GET', '/')
        self.assertEqual(conn.getresponse().status, 200)
        conn.close()
        conn = http.client.HTTPConnection('127.0.0.1', self.ide_port, timeout=20)
        conn.request('GET', '/_host/health')
        self.assertEqual(conn.getresponse().status, 200)
        conn.close()


class NoStorageTests(Running):
    storage = False

    def test_the_plain_site_as_it_is(self):
        status, _, body = self.call('/')
        self.assertEqual((status, body), (200, PAGE))
        self.assertEqual(self.call('/_host/api/files')[0], 404)
        self.assertEqual(self.call('/_host/sync.js')[0], 404)
        self.assertEqual(self.call('/_host/api/files/a', 'PUT', b'x')[0], 404)


class MainTests(Temp):
    def test_prepare_only(self):
        release_ide_zip(self.path('ide.zip'))
        release_player_zip(self.path('p.zip'))
        code = host.main(['--ide', self.path('ide.zip'), '--player', self.path('p.zip'),
                          '--data', self.path('data'), '--prepare-only', '--no-brotli'])
        self.assertEqual(code, 0)
        sites = self.path('data', 'sites')
        self.assertTrue(os.path.isfile(os.path.join(sites, 'ide', 'index.html')))
        self.assertTrue(os.path.isfile(os.path.join(sites, 'player', 'index.html')))
        self.assertTrue(os.path.isfile(os.path.join(sites, 'ide', ENGINE + '.wasm.gz')))
        # The files folder is made only when it serves
        self.assertFalse(os.path.exists(self.path('data', 'files')))

    def test_errors_are_one_line(self):
        with self.assertRaises(SystemExit) as e:
            host.main(['--data', self.path('data')])
        self.assertIn('--ide', str(e.exception))
        with self.assertRaises(SystemExit) as e:
            host.main(['--sites', self.path('nothing')])
        self.assertIn('prepare it with --ide', str(e.exception))


class BundleTests(Temp):
    def build(self, **kw):
        out = self.path('OXT-Beyond-9.9.9-web-bundle.zip')
        count = make_bundle.build(release_ide_zip(self.path('ide.zip')), release_player_zip(self.path('p.zip')),
                                  '9.9.9', out, 'https://example.org/source/abc123', use_brotli=False,
                                  log=quiet, **kw)
        return out, count

    def test_what_the_bundle_holds(self):
        out, count = self.build()
        with zipfile.ZipFile(out) as z:
            names = z.namelist()
            top = 'OXT-Beyond-9.9.9-web-bundle/'
            self.assertTrue(all(n.startswith(top) for n in names))
            rel = sorted(n[len(top):] for n in names)
            self.assertEqual(len(rel), count)
            for name in ('README.txt', 'ide/.htaccess', 'player/.htaccess', 'apache/.htaccess',
                         'nginx/nginx.conf', 'nginx/nginx-common.conf', 'caddy/Caddyfile',
                         'github-pages/pages.yml', 'ide/index.html', 'ide/ide.zip', 'ide/ide.zip.gz',
                         'ide/%s.wasm' % ENGINE, 'ide/%s.wasm.gz' % ENGINE, 'player/index.html',
                         'player/standalone.zip', 'player/samples/2048.oxtstack'):
                self.assertIn(name, rel)
            for name in ('ide/serve.py', 'ide/Start Web IDE.bat', 'ide/README.txt'):
                self.assertNotIn(name, rel)
            # The sites' files are the release's, byte for byte (no script added)
            self.assertEqual(z.read(top + 'ide/index.html'), PAGE)
            self.assertEqual(z.read(top + 'ide/%s.wasm' % ENGINE), WASM)
            self.assertEqual(gzip.decompress(z.read(top + 'ide/%s.wasm.gz' % ENGINE)), WASM)
            readme = z.read(top + 'README.txt').decode()
            self.assertIn('OXT-Beyond 9.9.9', readme)
            self.assertIn('https://example.org/source/abc123', readme)
            self.assertNotIn('@', readme.replace('@example', ''))
            self.assertEqual(z.read(top + 'ide/.htaccess'),
                             read(os.path.join(HOST_DIR, 'bundle', 'htaccess')))
            # The same bytes from the same input: fixed dates
            self.assertEqual({i.date_time for i in z.infolist()}, {(2026, 1, 1, 0, 0, 0)})

    def test_the_same_bytes_each_time(self):
        out, _ = self.build()
        first = read(out)
        os.remove(out)
        out, _ = self.build()
        self.assertEqual(read(out), first)

    def test_brotli_is_needed_unless_refused(self):
        with mock.patch.object(host, 'brotli', None):
            with self.assertRaisesRegex(host.HostError, 'brotli'):
                make_bundle.build(release_ide_zip(self.path('ide.zip')), release_player_zip(self.path('p.zip')),
                                  '9.9.9', self.path('b.zip'), log=quiet)

    def test_main(self):
        code = make_bundle.main(['--ide', release_ide_zip(self.path('ide.zip')),
                                 '--player', release_player_zip(self.path('p.zip')), '--version', '9.9.9',
                                 '--out', self.path('OXT-Beyond-9.9.9-web-bundle.zip'), '--no-brotli'])
        self.assertEqual(code, 0)
        with self.assertRaises(SystemExit):
            make_bundle.main(['--ide', self.path('ide.zip'), '--player', self.path('p.zip'),
                              '--version', '9.9.9', '--out', self.path('bundle.tar'), '--no-brotli'])


class TemplateTests(unittest.TestCase):
    def text(self, name):
        with open(os.path.join(HOST_DIR, 'bundle', name), encoding='utf-8') as f:
            return f.read()

    def test_htaccess(self):
        text = self.text('htaccess')
        self.assertIn('AddType application/wasm .wasm', text)
        # Every compressed kind the bundle makes has its real type
        for ext in ('wasm', 'js', 'html', 'zip', 'svg', 'json', 'txt', 'css'):
            self.assertRegex(text, r'<FilesMatch "\\\.\(?%s\)?\\\.\(br\|gz\)\$">' % ext, ext)
        self.assertIn('RewriteCond %{REQUEST_FILENAME}.br -f', text)
        self.assertIn('Header set Content-Encoding br', text)
        self.assertIn('Header set Cache-Control "no-cache"', text)
        for ext in host.PRECOMPRESS:
            self.assertIn(ext.lstrip('.'), text)

    def test_nginx(self):
        text = self.text('nginx.conf') + self.text('nginx-common.conf')
        self.assertEqual(text.count('server {'), 2)
        for line in ('gzip_static on;', 'gzip_vary on;', 'default_type application/wasm;',
                     'add_header Cache-Control "no-cache" always;'):
            self.assertIn(line, text)
        self.assertEqual(text.count('{'), text.count('}'))

    def test_caddy(self):
        text = self.text('Caddyfile')
        self.assertIn('precompressed br gzip', text)
        self.assertEqual(text.count('{'), text.count('}'))

    def test_pages_workflow(self):
        try:
            import yaml
        except ImportError:
            self.skipTest('pyyaml')
        flow = yaml.safe_load(self.text('pages-workflow.yml'))
        steps = flow['jobs']['deploy']['steps']
        self.assertIn('actions/deploy-pages@v4', [s.get('uses') for s in steps])
        self.assertIn("--exclude '*.br'", json.dumps(steps))
        self.assertEqual(flow['permissions'], {'contents': 'read', 'pages': 'write', 'id-token': 'write'})


class PageContractTests(unittest.TestCase):
    """What sync.js counts on in the engine and the IDE's page: a rename
    there would stop the syncing silently (the plan's "Script injection"
    risk), so it fails here first."""

    def read(self, *parts):
        with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
            return f.read()

    def test_the_engine_storage_sync_js_uses(self):
        engine = self.read('engine', 'src', 'em-system.js')
        sync = self.read('tools', 'web-host', 'sync.js')
        start = engine.index('$LiveCodeStorage: {')
        storage = engine[start:engine.index('MCEmscriptenStorageChanged__deps')]
        for name in re.findall(r'storage\.(_?[A-Za-z]+)', sync):
            if name == '_oxtHostHooked':
                continue
            self.assertRegex(storage, r'\n\t\t%s: ' % re.escape(name),
                             'sync.js uses LiveCodeStorage.%s, which em-system.js no longer has' % name)
        # The engine calls changed() by name after a save, so a wrapper sees it
        self.assertIn("LiveCodeStorage.changed();", engine[engine.index('MCEmscriptenStorageChanged:'):])
        self.assertIn("preRun.push(LiveCodeStorage._load)", storage)
        self.assertIn("_folder: '/openxtalk'", storage)

    def test_the_ide_page_sets_module_before_it_loads_the_engine(self):
        page = self.read('tools', 'web-ide', 'index.html')
        self.assertEqual(page.lower().count('</body>'), 1)
        module = page.index('window.Module = {')
        engine = page.index("script.src = stamped(ENGINE + '.js')")
        self.assertLess(module, engine)
        # ... and the engine is added by script, after the page has parsed
        # (so after the injected script, which comes before </body>)
        self.assertIn('document.body.appendChild(script)', page[engine:])
        self.assertNotIn('<script src="development-', page)
        # The page's own ids the end-to-end check waits on
        self.assertIn('id="loading"', page)
        self.assertIn('id="error"', page)

    def test_sync_js_deletes_on_the_server_only_after_comparing(self):
        # A failed listing, or a browser copy not loaded, makes the folder
        # look empty: no DELETE may follow from that (review of #451)
        sync = self.read('tools', 'web-host', 'sync.js')
        push = sync[sync.index('function push()'):]
        self.assertIn('if (local[rel] || !state.listed || !state.loaded) {', push)
        pull = sync[sync.index('function pull()'):sync.index('function push()')]
        # The listing's failure is held until the browser's copy has settled
        self.assertIn('Promise.all([listed, copy])', pull)
        self.assertLess(pull.index('state.loaded ='), pull.index('throw done[0].error'))
        self.assertLess(pull.index('throw done[0].error'), pull.index('state.listed = true'))
        # A save the server refused as older takes the server's copy
        self.assertIn('r.status === 409', push)

    def test_sync_js_parses_as_plain_es5(self):
        sync = self.read('tools', 'web-host', 'sync.js')
        self.assertTrue(sync.rstrip().endswith('})();'))
        self.assertNotRegex(sync, r'\b(let|const|class)\s|=>|`')
        self.assertEqual(sync.count('{'), sync.count('}'))
        self.assertEqual(sync.count('('), sync.count(')'))


class DockerfileTests(unittest.TestCase):
    def test_it_copies_what_is_here_and_prepares_while_it_builds(self):
        with open(os.path.join(HOST_DIR, 'Dockerfile'), encoding='utf-8') as f:
            text = f.read()
        for line in re.findall(r'^COPY\s+(.+)$', text, re.M):
            for name in line.split()[:-1]:
                self.assertTrue(os.path.exists(os.path.join(HOST_DIR, name)), name)
        self.assertIn('--prepare-only', text)
        self.assertIn('HEALTHCHECK', text)
        self.assertIn('/_host/health', text)
        self.assertRegex(text, r'(?m)^USER ')


if __name__ == '__main__':
    unittest.main()
