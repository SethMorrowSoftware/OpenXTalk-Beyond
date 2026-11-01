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

"""Make the GitHub Pages site (.github/workflows/pages.yml) from a release's
web zips: the web IDE and the Stack Player, each in a folder of its own,
with a front page that links to both, and to the codebase map when one is
given.

  python3 tools/pages/build_pages.py --out DIR
      [--ide ZIP --ide-version V] [--player ZIP --player-version V]
      [--map HTML --map-version V]
      [--release TAG --release-assets FILE]

  DIR/index.html     the front page (tools/pages/index.html)
  DIR/ide/           OXT-Beyond-<version>-web-ide.zip's site (tools/web-ide)
  DIR/player/        OXT-Beyond-<version>-web-player.zip's site
                     (tools/web-player)
  DIR/dictionary/    the Dictionary that the IDE's Help > Dictionary Online
                     opens, made from the web IDE's own html_viewer and
                     dictionary data (tools/pages/build_dictionary.py), so
                     it is the IDE's of the same release; left out, with a
                     note, when the web IDE has none (one before 0.2.7)
  DIR/map/           the codebase map: the one self-contained page that
                     tools/codebase-map/build_map.py writes (index.html),
                     and beside it, when build_map.py wrote them next to
                     the page, the binary stacks' scripts as files
                     (stack-scripts/ and stack-scripts.zip)

With --release, the front page has a Downloads section: the desktop
packages, the web zips and the plugins of that release, each linked
straight to its file on GitHub, as the forum posts link them. FILE lists
the release's file names, one a line (gh release view TAG --json assets
--jq '.assets[].name'), and a file the release does not have gets no
link, so no link on the page leads to a missing file; a platform with
none of its files is left out, and the section too when it has none.

Each zip holds its site in one folder (StackPlayer/, or the web IDE's
folder named after its zip); the folder with index.html is the one taken.
The web IDE zip's local server and its notes (serve.py, Start Web IDE.bat,
README.txt) are for running it on a computer, so they are left out. The
sites are copied as they are: both ask for their engine with relative
addresses and their own ?v= stamp, so they run from any folder, and the
web engine uses no threads, so GitHub Pages needs no special headers.

A part that is not given is left out, and the front page leaves out its
card. GitHub Pages refuses a file over 100 MB, so a bigger one stops the
build here, where the message says which file it is.
"""

import argparse
import html
import os
import re
import shutil
import sys
import tempfile
import urllib.parse
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_dictionary  # noqa: E402

# The parts of the site, each with its card on the front page, and the
# Downloads section (from a release's files, not a folder of the site)
PARTS = ('IDE', 'DICTIONARY', 'PLAYER', 'GAMES', 'MAP', 'DOWNLOADS')
REPOSITORY = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'
# The Downloads section: (platform, what it needs, [(link, file suffix)]);
# a file is OXT-Beyond-<version>-<suffix>, as release.yml names them
DOWNLOADS = (
    ('Windows', '64-bit Windows 10 or later',
     (('Installer', 'win-x86_64-setup.exe'), ('Portable zip', 'win-x86_64-portable.zip'))),
    ('macOS', 'Apple Silicon and Intel, one universal app',
     (('Disk image', 'mac-universal.dmg'), ('Zip', 'mac-universal.zip'))),
    ('Linux', 'x86-64 and 64-bit ARM, glibc 2.31 or later',
     (('x86-64', 'linux-x86_64.tar.xz'), ('64-bit ARM', 'linux-arm64.tar.xz'))),
    ('Web, on your own server', 'The web IDE and the Stack Player as folders to serve',
     (('Web IDE zip', 'web-ide.zip'), ('Stack Player zip', 'web-player.zip'))),
    ('Plugins for other xTalks', 'For LiveCode Community 9, HyperXTalk and OpenXTalk',
     (('xTalk Assistant', 'xtalk-assistant-plugin.lce'), ('MCP Bridge', 'mcp-bridge-plugin.lce'))),
)
LIMIT = 100 * 1000 * 1000
LOCAL_ONLY = {'serve.py', 'Start Web IDE.bat', 'README.txt'}


class BuildError(Exception):
    pass


def downloads_html(tag, assets):
    """The Downloads section's platforms, for the release tag whose files
    are assets (their names): a link for each file it has."""
    if not re.match(r'^v[0-9][0-9A-Za-z.+-]*$', tag):
        raise BuildError('--release %r is not a release tag (v<version>)' % tag)
    version = tag[1:]
    base = '%s/releases/download/%s/' % (REPOSITORY, urllib.parse.quote(tag))
    out = []
    for platform, needs, files in DOWNLOADS:
        links = []
        for label, suffix in files:
            name = 'OXT-Beyond-%s-%s' % (version, suffix)
            if name in assets:
                links.append('<a class="file" href="%s%s">%s</a>'
                             % (base, urllib.parse.quote(name), html.escape(label)))
        if links:
            out.append('<div class="platform"><h3>%s</h3><p>%s</p><div class="files">%s</div></div>'
                       % (html.escape(platform), html.escape(needs), ''.join(links)))
    return '\n'.join(out)


def site_root(folder):
    """The shallowest folder under folder that has index.html."""
    found = []
    for root, dirs, names in os.walk(folder):
        if 'index.html' in names:
            found.append(root)
    if not found:
        raise BuildError('no index.html in the zip')
    found.sort(key=lambda p: (p.count(os.sep), p))
    return found[0]


def unpack(zip_path, target, drop=()):
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(zip_path) as z:
            for info in z.infolist():
                name = info.filename
                if name.startswith('/') or '..' in name.replace('\\', '/').split('/'):
                    raise BuildError('%s: unsafe name %r' % (zip_path, name))
            z.extractall(tmp)
        root = site_root(tmp)
        shutil.copytree(root, target, ignore=lambda d, names:
                        [n for n in names if d == root and n in drop])


def check_sizes(folder):
    for root, dirs, names in os.walk(folder):
        for name in names:
            path = os.path.join(root, name)
            if os.path.getsize(path) > LIMIT:
                raise BuildError('%s is %d bytes; GitHub Pages takes no file over 100 MB'
                                 % (os.path.relpath(path, folder), os.path.getsize(path)))


def games(source, target, player):
    """Copies tools/pages/games, each page told the engine's file in the player."""
    if not os.path.isdir(source):
        return False
    engines = sorted(n for n in os.listdir(player) if re.fullmatch(r'standalone-.*\.js', n))
    if not engines:
        print('no games: the Stack Player has no engine for them')
        return False
    shutil.copytree(source, target)
    for root, _, names in os.walk(target):
        for name in names:
            if name == 'index.html':
                path = os.path.join(root, name)
                with open(path, encoding='utf-8') as f:
                    page = f.read()
                with open(path, 'w', encoding='utf-8', newline='\n') as f:
                    f.write(page.replace('@ENGINE_JS@', engines[0]))
    return True


def front_page(out, parts):
    with open(os.path.join(HERE, 'index.html'), encoding='utf-8') as f:
        page = f.read()
    for key in PARTS:
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        if start not in page or end not in page:
            raise BuildError('tools/pages/index.html has no %s ... %s' % (start, end))
        version = parts.get(key)
        if version is None:
            # Every block of the part: a part may have more than one (its
            # card, and its button in the page's header)
            while start in page:
                at = page.index(start)
                if end not in page[at:]:
                    raise BuildError('tools/pages/index.html has a %s with no %s after it' % (start, end))
                page = page[:at] + page[page.index(end, at) + len(end):]
        else:
            page = page.replace('@%s_VERSION@' % key, html.escape(version))
            if key == 'DOWNLOADS':
                page = page.replace('@DOWNLOADS_URL@', '%s/releases/tag/%s'
                                    % (REPOSITORY, urllib.parse.quote(version)))
                page = page.replace('@DOWNLOADS_LIST@', parts['DOWNLOADS_LIST'])
    for key in PARTS:
        page = page.replace('<!-- @%s@ -->' % key, '').replace('<!-- /@%s@ -->' % key, '')
    with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)


def build(args):
    # The map alone is not a site: it is there beside the web IDE and the
    # Stack Player, and a run that has neither should fail as it always has
    if not args.ide and not args.player:
        raise BuildError('nothing to put on the site: give --ide, --player or both')
    out = os.path.abspath(args.out)
    if os.path.exists(out) and os.listdir(out):
        raise BuildError('%s is not empty' % out)
    os.makedirs(out, exist_ok=True)
    parts = {}
    if args.ide:
        unpack(args.ide, os.path.join(out, 'ide'), drop=LOCAL_ONLY)
        parts['IDE'] = args.ide_version or ''
        try:
            counts = build_dictionary.build_from_ide_site(os.path.join(out, 'ide'), os.path.join(out, 'dictionary'),
                                                          args.ide_version)
            parts['DICTIONARY'] = args.ide_version or ''
            print('dictionary entries: %s' % ', '.join('%s %d' % (t, counts[t]) for t, _ in build_dictionary.APIS))
        except build_dictionary.NoViewer as e:
            print('no dictionary: %s' % e)
        except build_dictionary.DictionaryError as e:
            raise BuildError('the dictionary: %s' % e)
    if args.player:
        unpack(args.player, os.path.join(out, 'player'))
        parts['PLAYER'] = args.player_version or ''
        # The games run on the Stack Player's engine, so they go up with it
        if games(os.path.join(HERE, 'games'), os.path.join(out, 'games'), os.path.join(out, 'player')):
            parts['GAMES'] = ''
    if args.map:
        os.makedirs(os.path.join(out, 'map'))
        shutil.copyfile(args.map, os.path.join(out, 'map', 'index.html'))
        here = os.path.dirname(os.path.abspath(args.map))
        if os.path.isdir(os.path.join(here, 'stack-scripts')):
            shutil.copytree(os.path.join(here, 'stack-scripts'), os.path.join(out, 'map', 'stack-scripts'))
        if os.path.isfile(os.path.join(here, 'stack-scripts.zip')):
            shutil.copyfile(os.path.join(here, 'stack-scripts.zip'), os.path.join(out, 'map', 'stack-scripts.zip'))
        parts['MAP'] = args.map_version or ''
    # (getattr: callers that build an argparse.Namespace by hand, such as
    # the tests, may not give these)
    release, release_assets = getattr(args, 'release', None), getattr(args, 'release_assets', None)
    if release:
        if not release_assets:
            raise BuildError('--release needs --release-assets')
        with open(release_assets, encoding='utf-8') as f:
            assets = {line.strip() for line in f if line.strip()}
        listed = downloads_html(release, assets)
        if listed:
            parts['DOWNLOADS'] = release
            parts['DOWNLOADS_LIST'] = listed
        else:
            print('no downloads: %s has none of the files the page links' % release)
    front_page(out, parts)
    check_sizes(out)
    for key, version in sorted((k, v) for k, v in parts.items() if k in PARTS):
        print('%s: %s' % (key.lower(), version or '(no version given)'))
    print('Site: %s' % out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--out', required=True, help='the site folder (new or empty)')
    ap.add_argument('--ide', metavar='ZIP', help='OXT-Beyond-<version>-web-ide.zip')
    ap.add_argument('--ide-version', metavar='V', help='shown on the front page')
    ap.add_argument('--player', metavar='ZIP', help='OXT-Beyond-<version>-web-player.zip')
    ap.add_argument('--player-version', metavar='V', help='shown on the front page')
    ap.add_argument('--map', metavar='HTML', help="the codebase map's index.html (tools/codebase-map)")
    ap.add_argument('--map-version', metavar='V', help='shown on the front page')
    ap.add_argument('--release', metavar='TAG', help='the release whose files the Downloads section links')
    ap.add_argument('--release-assets', metavar='FILE', help="that release's file names, one a line")
    args = ap.parse_args()
    try:
        build(args)
    except (BuildError, zipfile.BadZipFile, OSError) as e:
        print('build_pages.py: %s' % e, file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
