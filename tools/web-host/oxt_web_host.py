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

"""OXT-Beyond web host: the web IDE and the Stack Player on your own server.

    python3 oxt_web_host.py --ide IDE [--player PLAYER] [--data DIR]
        [--host 127.0.0.1] [--port 8000] [--player-port PORT]
        [--password PW] [--no-storage]

--ide      the release's OXT-Beyond-<version>-web-ide.zip, or a web IDE
           folder (index.html, the engine's .js and .wasm, and ide.zip, or
           ide.zip.part0, part1, ... with ide.zip.md5)
--player   the release's OXT-Beyond-<version>-web-player.zip, or its
           StackPlayer folder (optional)
--data     where the server keeps the prepared sites and the stacks users
           save (default ./oxt-data)
--host     127.0.0.1 (this computer only, the default) or 0.0.0.0 (the
           network)
--port     the IDE's port; the Player gets the next one unless --player-port
--password asks for it (HTTP Basic, any user name) on the IDE and its
           storage; OXT_PASSWORD in the environment does the same. Put the
           server behind HTTPS (Caddy, nginx, a tunnel) before it faces the
           internet: Basic sends the password in the clear.
--sites    serves sites prepared before (DIR/ide, DIR/player) as they are;
           --prepare-only prepares them and stops (the Docker image does
           both, one while it is built and one when it runs)

This is tier 2 of the self-hosted web (README.md). Python 3.8 or later and
its standard library; the brotli module is used when it is installed. What
it does that a plain static server does not:

1. The IDE and the Player are served on DIFFERENT ORIGINS (two ports, or two
   host names behind a proxy). Both engines keep the user's home folder in
   the browser's IndexedDB under the same name, so on one origin a stack
   opened in the Player could read and overwrite the stacks saved in the IDE.
2. Compressed copies (.br, .gz) of the big files are made once, when the
   sites are prepared, and each browser is handed the best one it accepts,
   with its real Content-Length.
3. ETag and If-None-Match: a repeat visit gets 304s, and a new release is
   picked up at once (Cache-Control: no-cache, as the web IDE's serve.py
   does).
4. The IDE's ~/Documents is kept on the server too (/_host/api/files/...),
   so the user's stacks follow them to any browser. The page's half is
   /_host/sync.js, added to the IDE's index.html as it is served; neither
   the IDE nor the engine is changed, and the browser's own copy stays, so
   with the server down the IDE works as it does on any static site. One
   space per server: everyone with the password sees the same Documents.

Nothing here changes the web IDE, the Stack Player or the plain static site:
the same release files are served as they are.
"""
import argparse
import base64
import email.utils
import glob
import gzip
import hashlib
import hmac
import http.server
import json
import os
import re
import shutil
import sys
import threading
import urllib.parse
import zipfile

try:
    import brotli
except ImportError:  # optional: gzip alone is served without it
    brotli = None

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = '1'

# Worth compressing ahead of time: the big text and WebAssembly files. The
# IDE's ide.zip and the Player's standalone.zip are zips whose text entries
# are deflated already, but Brotli still takes a sixth off them
PRECOMPRESS = ('.wasm', '.zip', '.js', '.html', '.css', '.svg', '.json', '.txt')
PRECOMPRESS_MIN = 4096
TYPES = {
    '.wasm': 'application/wasm', '.js': 'text/javascript', '.mjs': 'text/javascript',
    '.html': 'text/html; charset=utf-8', '.htm': 'text/html; charset=utf-8',
    '.zip': 'application/zip', '.css': 'text/css', '.svg': 'image/svg+xml',
    '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.webp': 'image/webp', '.ico': 'image/x-icon',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
    '.txt': 'text/plain; charset=utf-8', '.md5': 'text/plain; charset=utf-8',
    '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.mp4': 'video/mp4',
    '.webmanifest': 'application/manifest+json',
}
# What a release's web IDE zip adds for running it on one's own computer,
# which a server does not serve
IDE_LOCAL_ONLY = ('serve.py', 'Start Web IDE.bat', 'README.txt')
MAX_UPLOAD = 200 * 1024 * 1024
TMP_SUFFIX = '.oxt-tmp'
SYNC_TAG = b'<script src="/_host/sync.js" data-cfasync="false"></script>\n'


def log(text):
    print(text, flush=True)


class HostError(Exception):
    pass


# ---------------------------------------------------------------------------
# Preparing the sites: once, at start (or while an image is built)

def md5_of(path):
    digest = hashlib.md5()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def is_compressed_copy(name):
    return name.endswith(('.br', '.gz'))


class Source:
    """A folder or a zip of one, as {relative path: opener}, the zip's one
    top folder (OXT-Beyond-<version>-web-ide/, StackPlayer/) left out."""

    def __init__(self, path):
        self.path = path
        self.zip = None
        self.entries = {}
        if os.path.isdir(path):
            for folder, dirs, names in os.walk(path):
                dirs.sort()
                for name in sorted(names):
                    full = os.path.join(folder, name)
                    if os.path.islink(full) or not os.path.isfile(full):
                        continue
                    rel = os.path.relpath(full, path).replace(os.sep, '/')
                    self.entries[rel] = full
        elif zipfile.is_zipfile(path):
            self.zip = zipfile.ZipFile(path)
            names = [n for n in self.zip.namelist() if not n.endswith('/')]
            tops = {n.split('/', 1)[0] for n in names}
            strip = ''
            if len(tops) == 1 and all('/' in n for n in names):
                strip = tops.pop() + '/'
            for name in names:
                rel = name[len(strip):]
                parts = rel.split('/')
                if (not rel or name.startswith('/') or '\\' in name or
                        any(p in ('', '.', '..') for p in parts) or ':' in parts[0]):
                    raise HostError('%s has a file outside its folder: %s' % (path, name))
                self.entries[rel] = name
        else:
            raise HostError('%s is neither a folder nor a zip' % path)

    def open(self, rel):
        if self.zip:
            return self.zip.open(self.entries[rel])
        return open(self.entries[rel], 'rb')

    def size(self, rel):
        if self.zip:
            return self.zip.getinfo(self.entries[rel]).file_size
        return os.path.getsize(self.entries[rel])

    def close(self):
        if self.zip:
            self.zip.close()


def _write(source, rel, target_path):
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    with source.open(rel) as f, open(target_path + TMP_SUFFIX, 'wb') as g:
        shutil.copyfileobj(f, g, 1 << 20)
    os.replace(target_path + TMP_SUFFIX, target_path)


def _same_bytes(source, rel, target_path):
    """True when target_path has rel's bytes already (so its compressed
    copies, made from it, stay good)."""
    if not os.path.isfile(target_path) or os.path.getsize(target_path) != source.size(rel):
        return False
    a, b = hashlib.sha256(), hashlib.sha256()
    with source.open(rel) as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            a.update(block)
    with open(target_path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            b.update(block)
    return a.digest() == b.digest()


def _mirror(source, wanted, target):
    """target holds exactly wanted ({rel: rel in source}) afterwards, plus
    the .br/.gz copies of its files that a source brought or an earlier
    start made; a file whose bytes are already there is left as it is."""
    os.makedirs(target, exist_ok=True)
    real_target = os.path.realpath(target)
    keep = set()
    for rel, src in sorted(wanted.items()):
        out = os.path.realpath(os.path.join(target, rel))
        if not out.startswith(real_target + os.sep):
            raise HostError('a file outside the site: %s' % rel)
        keep.add(os.path.relpath(out, real_target).replace(os.sep, '/'))
        if not _same_bytes(source, src, out):
            _write(source, src, out)
            # A copy of the older file is not this one's
            for ext in ('.br', '.gz'):
                if (rel + ext) not in wanted and os.path.exists(out + ext):
                    os.remove(out + ext)
    for folder, dirs, names in os.walk(real_target, topdown=False):
        for name in names:
            full = os.path.join(folder, name)
            rel = os.path.relpath(full, real_target).replace(os.sep, '/')
            base = rel[:-3] if is_compressed_copy(rel) else None
            if rel in keep or (base and base in keep):
                continue
            os.remove(full)
        if folder != real_target and not os.listdir(folder):
            os.rmdir(folder)


def prepare_ide(source_path, target):
    """The web IDE's site in target, from a release zip or a folder:
    ide.zip joined from its parts if need be (and checked against
    ide.zip.md5), without what only running it on one's own computer
    needs (serve.py, the .bat, README.txt)."""
    source = Source(source_path)
    try:
        wanted = {}
        parts = []
        for rel in source.entries:
            name = rel.rsplit('/', 1)[-1]
            if '/' not in rel and re.match(r'^ide\.zip\.part\d+$', name):
                parts.append(rel)
                continue
            if '/' not in rel and (name in IDE_LOCAL_ONLY or name == 'ide.zip.md5'):
                continue
            if name.endswith(('.py', '.pyc', '.bat')) or '__pycache__' in rel.split('/'):
                continue
            wanted[rel] = rel
        if 'index.html' not in wanted:
            raise HostError('%s has no index.html: is it the web IDE?' % source_path)
        if parts:
            if 'ide.zip.md5' not in source.entries:
                raise HostError('%s has ide.zip.part* but no ide.zip.md5' % source_path)
            with source.open('ide.zip.md5') as f:
                expected = f.read().decode('ascii', 'replace').split()[0].lower()
            parts.sort(key=lambda p: int(p.rsplit('part', 1)[1]))
            joined = os.path.join(target, 'ide.zip')
            if not (os.path.isfile(joined) and md5_of(joined) == expected):
                log('Joining ide.zip from %d parts' % len(parts))
                os.makedirs(target, exist_ok=True)
                with open(joined + TMP_SUFFIX, 'wb') as out:
                    for part in parts:
                        with source.open(part) as f:
                            shutil.copyfileobj(f, out, 1 << 20)
                if md5_of(joined + TMP_SUFFIX) != expected:
                    os.remove(joined + TMP_SUFFIX)
                    raise HostError('ide.zip, joined from its parts, does not match ide.zip.md5')
                os.replace(joined + TMP_SUFFIX, joined)
                for ext in ('.br', '.gz'):
                    if os.path.exists(joined + ext):
                        os.remove(joined + ext)
            # Kept by _mirror as it is
            wanted.pop('ide.zip', None)
            _mirror_keep_extra(source, wanted, target, extra={'ide.zip'})
        else:
            if 'ide.zip' not in wanted:
                raise HostError('%s has no ide.zip (or ide.zip.part0, ...)' % source_path)
            _mirror(source, wanted, target)
        if not glob.glob(os.path.join(target, '*.wasm')):
            raise HostError('%s has no engine (.wasm)' % source_path)
    finally:
        source.close()


def _mirror_keep_extra(source, wanted, target, extra):
    """_mirror, keeping the files named in extra (made here) too."""
    keep_paths = {}
    for rel in extra:
        path = os.path.join(target, rel)
        if os.path.isfile(path):
            keep_paths[rel] = path

    class WithExtra:
        entries = dict(source.entries, **keep_paths)

        def open(self, rel):
            if rel in keep_paths:
                return open(keep_paths[rel], 'rb')
            return source.open(rel)

        def size(self, rel):
            if rel in keep_paths:
                return os.path.getsize(keep_paths[rel])
            return source.size(rel)

    _mirror(WithExtra(), dict(wanted, **{rel: rel for rel in keep_paths}), target)


def prepare_player(source_path, target):
    """The Stack Player's site in target, from the release zip or its
    folder."""
    source = Source(source_path)
    try:
        wanted = {rel: rel for rel in source.entries
                  if not rel.rsplit('/', 1)[-1].endswith(('.py', '.pyc'))}
        if 'index.html' not in wanted:
            raise HostError('%s has no index.html: is it the Stack Player?' % source_path)
        _mirror(source, wanted, target)
    finally:
        source.close()


def precompress(root, use_brotli=True, quiet=False):
    """FILE.gz and FILE.br beside each big file of root, made again when
    FILE is newer. Returns the number made."""
    made = 0
    for folder, dirs, names in os.walk(root):
        dirs.sort()
        for name in sorted(names):
            path = os.path.join(folder, name)
            if (not name.endswith(PRECOMPRESS) or os.path.islink(path) or
                    os.path.getsize(path) < PRECOMPRESS_MIN):
                continue
            for ext, enabled in (('.gz', True), ('.br', use_brotli and brotli is not None)):
                copy = path + ext
                if not enabled:
                    continue
                if os.path.exists(copy) and os.path.getmtime(copy) >= os.path.getmtime(path):
                    continue
                if not quiet:
                    log('Compressing %s (%s)' % (os.path.relpath(path, root), ext[1:]))
                with open(path, 'rb') as f:
                    data = f.read()
                if ext == '.gz':
                    # mtime=0: the same file gives the same bytes
                    packed = gzip.compress(data, 9, mtime=0)
                else:
                    packed = brotli.compress(data, quality=11)
                with open(copy + TMP_SUFFIX, 'wb') as f:
                    f.write(packed)
                os.replace(copy + TMP_SUFFIX, copy)
                # Never older than the file it was made from
                st = os.stat(path)
                os.utime(copy, (st.st_atime, max(st.st_mtime, os.path.getmtime(copy))))
                made += 1
    return made


def inject_sync(page):
    """The IDE's page with sync.js added before its last </body> (or at the
    end of a page without one): after the page's own script, which sets
    window.Module, and before the engine, which the page loads later."""
    at = page.lower().rfind(b'</body>')
    if at < 0:
        return page + b'\n' + SYNC_TAG
    return page[:at] + SYNC_TAG + page[at:]


# ---------------------------------------------------------------------------
# Serving

class Site:
    def __init__(self, name, root, files=None, password=None):
        self.name = name
        self.root = os.path.realpath(root)
        self.files = files and os.path.realpath(files)    # the storage, or None
        self.password = password
        self.lock = threading.Lock()


def make_handler(site):
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        server_version = 'oxt-web-host/' + VERSION
        sys_version = ''

        def log_message(self, *args):
            pass

        # -- helpers -------------------------------------------------------

        def common_headers(self):
            # Nothing is sniffed, the page is not framed by other sites, and
            # no address leaks to the sites a stack links to. No COOP/COEP:
            # the engines use no SharedArrayBuffer
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('X-Frame-Options', 'SAMEORIGIN')
            self.send_header('Referrer-Policy', 'no-referrer')

        def send_body(self, code, body, ctype, extra=()):
            self.send_response(code)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(len(body)))
            for k, v in extra:
                self.send_header(k, v)
            self.common_headers()
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(body)

        def send_plain(self, code, text, extra=()):
            self.send_body(code, (text + '\n').encode(), 'text/plain; charset=utf-8', extra)

        def send_json(self, value, code=200):
            self.send_body(code, json.dumps(value, sort_keys=True).encode(), 'application/json',
                           [('Cache-Control', 'no-store')])

        def authorised(self):
            if not site.password:
                return True
            value = self.headers.get('Authorization', '')
            if value[:6].lower() == 'basic ':
                try:
                    _, _, given = base64.b64decode(value[6:].strip()).decode('utf-8').partition(':')
                except Exception:
                    given = ''
                if hmac.compare_digest(given.encode('utf-8'), site.password.encode('utf-8')):
                    return True
            self.send_plain(401, 'This OXT-Beyond needs its password.',
                            [('WWW-Authenticate', 'Basic realm="OXT-Beyond", charset="UTF-8"')])
            return False

        def request_path(self):
            """The request's path, decoded, or None when it is not one."""
            raw = urllib.parse.urlsplit(self.path).path
            if not raw.startswith('/'):
                return None
            path = urllib.parse.unquote(raw)
            if '\x00' in path or '\\' in path:
                return None
            return path

        # -- GET and HEAD --------------------------------------------------

        def do_HEAD(self):
            self.do_GET()

        def do_GET(self):
            path = self.request_path()
            if path is None:
                return self.send_plain(400, 'Bad path')
            # For a container's health check: says nothing worth a password
            if path == '/_host/health':
                return self.send_json({'ok': True, 'site': site.name})
            if not self.authorised():
                return
            if path.startswith('/_host/'):
                return self.host_get(path[len('/_host/'):])
            if path.endswith('/'):
                path += 'index.html'
            parts = path.lstrip('/').split('/')
            if any(p in ('.', '..') or p.endswith(TMP_SUFFIX) for p in parts):
                return self.send_plain(404, 'Not found')
            full = os.path.realpath(os.path.join(site.root, *parts))
            if not full.startswith(site.root + os.sep) or not os.path.isfile(full):
                if os.path.isdir(full) and full.startswith(site.root):
                    # A folder without its slash: to the folder, as static
                    # servers do, so its page's relative links work
                    query = urllib.parse.urlsplit(self.path).query
                    location = urllib.parse.quote(path) + '/' + ('?' + query if query else '')
                    return self.send_plain(301, 'Moved', [('Location', location)])
                return self.send_plain(404, 'Not found')
            self.send_file(full)

        def send_file(self, full, inject=False):
            ext = os.path.splitext(full)[1].lower()
            ctype = TYPES.get(ext, 'application/octet-stream')
            accept = self.accepted()
            encoding, chosen = None, full
            if is_compressed_copy(full):
                # The copy asked for by its own name (a loader that unpacks
                # it itself): sent as the bytes it is
                ctype = 'application/gzip' if full.endswith('.gz') else 'application/octet-stream'
            elif not inject:
                for enc, suffix in (('br', '.br'), ('gzip', '.gz')):
                    if enc in accept and os.path.isfile(full + suffix):
                        encoding, chosen = enc, full + suffix
                        break
            body = None
            if inject:
                with open(full, 'rb') as f:
                    body = inject_sync(f.read())
            st = os.stat(chosen)
            tag = '%x-%x-%s%s' % (int(st.st_mtime), st.st_size, encoding or 'id', '-s' if inject else '')
            etag = '"%s"' % tag
            match = self.headers.get('If-None-Match', '')
            if etag in [m.strip() for m in match.split(',')] or match.strip() == '*':
                self.send_response(304)
                self.send_header('ETag', etag)
                self.send_header('Cache-Control', 'no-cache')
                self.send_header('Vary', 'Accept-Encoding')
                self.common_headers()
                self.end_headers()
                return
            self.send_response(200)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(len(body) if body is not None else st.st_size))
            self.send_header('ETag', etag)
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Last-Modified', email.utils.formatdate(st.st_mtime, usegmt=True))
            self.send_header('Vary', 'Accept-Encoding')
            if encoding:
                self.send_header('Content-Encoding', encoding)
            self.common_headers()
            self.end_headers()
            if self.command == 'HEAD':
                return
            if body is not None:
                self.wfile.write(body)
                return
            with open(chosen, 'rb') as f:
                shutil.copyfileobj(f, self.wfile, 1 << 20)

        def accepted(self):
            """The content codings the request accepts (q=0 left out)."""
            out = set()
            for item in self.headers.get('Accept-Encoding', '').split(','):
                name, _, params = item.strip().partition(';')
                q = re.search(r'q\s*=\s*([0-9.]+)', params)
                if name and not (q and float(q.group(1) or 0) == 0):
                    out.add(name.strip().lower())
            return out

        # -- the storage ---------------------------------------------------
        #
        # GET    /_host/sync.js            the page's half
        # GET    /_host/api/files          {"files": {"rel/path": [size, mtime]}}
        # GET    /_host/api/files/<path>   the file (X-Mtime: its date)
        # PUT    /_host/api/files/<path>   body = the file, X-Mtime = seconds
        # DELETE /_host/api/files/<path>

        def storage_path(self, rel):
            if not site.files or not rel:
                return None
            parts = rel.split('/')
            if any(p in ('', '.', '..') or p.endswith(TMP_SUFFIX) for p in parts):
                return None
            full = os.path.realpath(os.path.join(site.files, *parts))
            if not full.startswith(site.files + os.sep):
                return None
            return full

        def host_get(self, rest):
            if rest == 'sync.js' and site.files:
                return self.send_file(os.path.join(HERE, 'sync.js'))
            if rest == 'api/files' and site.files:
                listing = {}
                for folder, dirs, names in os.walk(site.files):
                    dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(folder, d))]
                    for name in names:
                        full = os.path.join(folder, name)
                        if name.endswith(TMP_SUFFIX) or os.path.islink(full):
                            continue
                        st = os.stat(full)
                        rel = os.path.relpath(full, site.files).replace(os.sep, '/')
                        listing[rel] = [st.st_size, int(st.st_mtime)]
                return self.send_json({'files': listing})
            if rest.startswith('api/files/'):
                full = self.storage_path(rest[len('api/files/'):])
                if full and os.path.isfile(full) and not os.path.islink(full):
                    with open(full, 'rb') as f:
                        body = f.read()
                    return self.send_body(200, body, 'application/octet-stream',
                                          [('Cache-Control', 'no-store'),
                                           ('X-Mtime', str(int(os.path.getmtime(full))))])
            self.send_plain(404, 'Not found')

        def write_check(self):
            """The storage path a PUT or DELETE writes, or None (answered)."""
            if not self.authorised():
                return None
            # Writes come only from the IDE's own page: a page of another
            # site (the Player's origin among them) is refused, whatever it
            # knows
            origin = self.headers.get('Origin')
            if origin is not None and urllib.parse.urlsplit(origin).netloc.lower() != \
                    (self.headers.get('Host') or '').lower():
                self.send_plain(403, 'Not from this site')
                return None
            if self.headers.get('Sec-Fetch-Site', 'same-origin') not in ('same-origin', 'none'):
                self.send_plain(403, 'Not from this site')
                return None
            path = self.request_path()
            if path is None or not path.startswith('/_host/api/files/') or not site.files:
                self.send_plain(404, 'Not found')
                return None
            full = self.storage_path(path[len('/_host/api/files/'):])
            if not full:
                self.send_plain(400, 'Bad path')
            return full

        def do_PUT(self):
            full = self.write_check()
            if not full:
                return self.discard_body()
            try:
                length = int(self.headers.get('Content-Length') or -1)
            except ValueError:
                length = -1
            if length < 0 or length > MAX_UPLOAD:
                self.close_connection = True
                return self.send_plain(413 if length > MAX_UPLOAD else 411,
                                       'Too big' if length > MAX_UPLOAD else 'No length')
            if os.path.isdir(full):
                self.discard_body()
                return self.send_plain(409, 'A folder of that name is there')
            tmp = '%s.%d%s' % (full, threading.get_ident(), TMP_SUFFIX)
            try:
                os.makedirs(os.path.dirname(full), exist_ok=True)
                left = length
                with open(tmp, 'wb') as f:
                    while left:
                        block = self.rfile.read(min(left, 1 << 20))
                        if not block:
                            raise HostError('the upload stopped')
                        f.write(block)
                        left -= len(block)
                with site.lock:
                    os.replace(tmp, full)
                    mtime = self.headers.get('X-Mtime', '')
                    if mtime.isdigit():
                        os.utime(full, (int(mtime), int(mtime)))
            except (OSError, HostError) as e:
                self.close_connection = True
                if os.path.exists(tmp):
                    os.remove(tmp)
                return self.send_plain(500, 'Not kept: %s' % e)
            self.send_plain(200, 'Kept')

        def do_DELETE(self):
            full = self.write_check()
            if not full:
                return self.discard_body()
            with site.lock:
                if os.path.isfile(full) and not os.path.islink(full):
                    os.remove(full)
                    # Folders it leaves empty go too
                    folder = os.path.dirname(full)
                    while folder != site.files and folder.startswith(site.files + os.sep):
                        try:
                            os.rmdir(folder)
                        except OSError:
                            break
                        folder = os.path.dirname(folder)
            self.send_plain(200, 'Removed')

        def discard_body(self):
            # An answered request's body is not read: the connection closes
            if self.headers.get('Content-Length', '0') not in ('', '0'):
                self.close_connection = True

        def do_POST(self):
            self.discard_body()
            self.send_plain(405, 'Not allowed', [('Allow', 'GET, HEAD, PUT, DELETE')])

        do_PATCH = do_POST

    class IdeHandler(Handler):
        def send_file(self, full, inject=False):
            # The IDE's own page (index.html at the top) gets the storage's
            # script; no other page and no other file is changed
            if (site.files and not inject and
                    os.path.normcase(full) == os.path.normcase(os.path.join(site.root, 'index.html'))):
                inject = True
            return Handler.send_file(self, full, inject)

    return IdeHandler


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    # On Windows, reusing the address lets a second server take a port
    # another still serves (as tools/web-ide/serve.py says)
    allow_reuse_address = os.name != 'nt'


def make_servers(sites, host='127.0.0.1', port=8000, player_port=None, files=None, password=None):
    """[(server, label)] for the prepared sites folder (sites/ide and,
    when it is there, sites/player)."""
    servers = [(Server((host, port), make_handler(
        Site('ide', os.path.join(sites, 'ide'), files, password))), 'web IDE')]
    if os.path.isfile(os.path.join(sites, 'player', 'index.html')):
        if player_port is None:
            player_port = servers[0][0].server_address[1] + 1 if port else 0
        # No storage and no password on the Player: it runs any stack it is
        # given, so it holds nothing worth taking
        servers.append((Server((host, player_port), make_handler(
            Site('player', os.path.join(sites, 'player')))), 'Stack Player'))
    return servers


def prepare(ide, player, sites, use_brotli=True):
    prepare_ide(ide, os.path.join(sites, 'ide'))
    if player:
        prepare_player(player, os.path.join(sites, 'player'))
    elif os.path.isdir(os.path.join(sites, 'player')):
        shutil.rmtree(os.path.join(sites, 'player'))
    precompress(sites, use_brotli)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--ide', help="the release's web IDE zip, or a web IDE folder")
    p.add_argument('--player', help="the release's Stack Player zip, or its folder")
    p.add_argument('--sites', help='serve sites prepared before (DIR/ide, DIR/player) as they are')
    p.add_argument('--prepare-only', action='store_true',
                   help='prepare the sites (in --sites, or DATA/sites) and stop')
    p.add_argument('--data', default='oxt-data')
    p.add_argument('--host', default='127.0.0.1')
    p.add_argument('--port', type=int, default=8000)
    p.add_argument('--player-port', type=int)
    p.add_argument('--password', default=os.environ.get('OXT_PASSWORD') or None)
    p.add_argument('--no-storage', action='store_true',
                   help="keep stacks only in each browser, as the plain site does")
    p.add_argument('--no-brotli', action='store_true', help='make gzip copies only')
    p.add_argument('--version', action='version', version='oxt-web-host ' + VERSION)
    a = p.parse_args(argv)

    data = os.path.abspath(a.data)
    try:
        if a.ide:
            sites = os.path.abspath(a.sites) if a.sites else os.path.join(data, 'sites')
            prepare(a.ide, a.player, sites, not a.no_brotli)
        elif a.sites:
            sites = os.path.abspath(a.sites)
            if not os.path.isfile(os.path.join(sites, 'ide', 'index.html')):
                raise HostError('%s has no ide/index.html: prepare it with --ide first' % sites)
        else:
            raise HostError('--ide (or --sites) is needed')
    except HostError as e:
        sys.exit('oxt-web-host: %s' % e)
    if a.prepare_only:
        return 0
    if a.host not in ('127.0.0.1', 'localhost', '::1') and not a.password:
        log('Note: anyone who can reach this computer can use the IDE and its stacks; '
            '--password asks for one')
    files = None if a.no_storage else os.path.join(data, 'files')
    if files:
        os.makedirs(files, exist_ok=True)
    try:
        servers = make_servers(sites, a.host, a.port, a.player_port, files, a.password)
    except OSError as e:
        sys.exit('oxt-web-host: a port is in use (%s); --port and --player-port choose others'
                 % (e.strerror or e))
    shown = 'localhost' if a.host in ('127.0.0.1', '0.0.0.0', '::', '::1') else a.host
    for server, label in servers:
        log('%-12s http://%s:%d/' % (label, shown, server.server_address[1]))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    if files:
        log("Stacks saved in the IDE's Documents are kept in %s" % files)
    log('Ctrl+C stops it.')
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
