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

"""Makes the web bundle: the web IDE and the Stack Player, ready to drop
onto any web server (tier 1 of the self-hosted web, README.md).

    python3 make_bundle.py --ide OXT-Beyond-<v>-web-ide.zip \\
        --player OXT-Beyond-<v>-web-player.zip --version <v> \\
        --out OXT-Beyond-<v>-web-bundle.zip [--source-url URL] [--no-brotli]

The zip holds one folder, OXT-Beyond-<v>-web-bundle/:

  README.txt            how to put it on shared hosting, nginx, Caddy, Pages
  ide/                  the web IDE's site (as oxt_web_host.py prepares it:
                        without serve.py and the .bat), with .htaccess
  player/               the Stack Player's site, with .htaccess
  apache/.htaccess      the same file, for reference
  nginx/nginx.conf, nginx/nginx-common.conf
  caddy/Caddyfile
  github-pages/pages.yml

and beside each big file of the sites (the engines, ide.zip, the pages)
its .gz and .br copies, made once here so that no host has to. The
sites' files are the release's, byte for byte. Brotli is required unless
--no-brotli is given (a release always has it). Standard library otherwise.
"""
import argparse
import os
import shutil
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import oxt_web_host as host  # noqa: E402

TEMPLATES = os.path.join(HERE, 'bundle')
SOURCE_URL = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'
# Compressed already: stored in the zip as they are
STORED = ('.br', '.gz', '.zip', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.woff2', '.mp3', '.mp4', '.ogg',
          )
# (bundle path, template, mode)
EXTRAS = (
    ('ide/.htaccess', 'htaccess'),
    ('player/.htaccess', 'htaccess'),
    ('apache/.htaccess', 'htaccess'),
    ('nginx/nginx.conf', 'nginx.conf'),
    ('nginx/nginx-common.conf', 'nginx-common.conf'),
    ('caddy/Caddyfile', 'Caddyfile'),
    ('github-pages/pages.yml', 'pages-workflow.yml'),
)


def build(ide, player, version, out, source_url=SOURCE_URL, use_brotli=True, log=None):
    """Writes the bundle zip at out; returns the number of files in it."""
    log = log or host.log
    if use_brotli and host.brotli is None:
        raise host.HostError('the brotli module is needed (pip install brotli), or --no-brotli')
    name = os.path.basename(out)
    if not name.endswith('.zip') or len(name) <= 4:
        raise host.HostError('--out must name a .zip')
    top = name[:-4]
    work = tempfile.mkdtemp(prefix='oxt-web-bundle-')
    try:
        sites = os.path.join(work, 'sites')
        log('Preparing the sites')
        host_log, host.log = host.log, log
        try:
            host.prepare_ide(ide, os.path.join(sites, 'ide'))
            host.prepare_player(player, os.path.join(sites, 'player'))
            made = host.precompress(sites, use_brotli, quiet=True)
        finally:
            host.log = host_log
        log('  %d compressed copies' % made)
        files = []
        for folder, dirs, names in os.walk(sites):
            dirs.sort()
            for n in sorted(names):
                full = os.path.join(folder, n)
                files.append((os.path.relpath(full, sites).replace(os.sep, '/'), full, None))
        with open(os.path.join(TEMPLATES, 'README.txt'), encoding='utf-8') as f:
            readme = f.read()
        readme = readme.replace('@VERSION@', version).replace('@SOURCE@', source_url)
        files.append(('README.txt', None, readme.encode('utf-8')))
        for path, template in EXTRAS:
            with open(os.path.join(TEMPLATES, template), 'rb') as f:
                files.append((path, None, f.read()))
        files.sort(key=lambda f: f[0])
        tmp = out + '.tmp'
        with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for rel, full, data in files:
                info = zipfile.ZipInfo(top + '/' + rel, date_time=(2026, 1, 1, 0, 0, 0))
                info.external_attr = 0o644 << 16
                info.compress_type = (zipfile.ZIP_STORED if rel.lower().endswith(STORED)
                                      else zipfile.ZIP_DEFLATED)
                if data is None:
                    with open(full, 'rb') as f:
                        data = f.read()
                z.writestr(info, data)
        os.replace(tmp, out)
        log('Bundle: %s (%d files, %.1f MB)' % (out, len(files), os.path.getsize(out) / 1e6))
        return len(files)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--ide', required=True, help="the release's web IDE zip, or a web IDE folder")
    p.add_argument('--player', required=True, help="the release's Stack Player zip, or its folder")
    p.add_argument('--version', required=True)
    p.add_argument('--out', required=True, help='the zip to write, OXT-Beyond-<version>-web-bundle.zip')
    p.add_argument('--source-url', default=SOURCE_URL,
                   help='where the source is (README.txt names it; the GPL asks for it)')
    p.add_argument('--no-brotli', action='store_true', help='gzip copies only')
    a = p.parse_args(argv)
    try:
        build(a.ide, a.player, a.version, os.path.abspath(a.out), a.source_url, not a.no_brotli)
    except host.HostError as e:
        sys.exit('make_bundle: %s' % e)
    return 0


if __name__ == '__main__':
    sys.exit(main())
