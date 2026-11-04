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
      [--suite-release TAG --suite-assets FILE]

  DIR/index.html     the front page (tools/pages/index.html)
  DIR/brand/         the logo it shows (tools/pages/brand)
  DIR/ide/           OXT-Beyond-<version>-web-ide.zip's site (tools/web-ide)
  DIR/player/        OXT-Beyond-<version>-web-player.zip's site
                     (tools/web-player)
  DIR/dictionary/    the Dictionary that the IDE's Help > Dictionary Online
                     opens, made from the web IDE's own html_viewer and
                     dictionary data (tools/pages/build_dictionary.py), so
                     it is the IDE's of the same release; left out, with a
                     note, when the web IDE has none (one before 0.2.7)
  DIR/extensions/    the xTalk Suite's extensions, built into OXT-Beyond,
                     each with its .lce package for the other IDEs built
                     on LiveCode Community 9: the files of the suite
                     release --suite-release (FILE lists its file names),
                     or a link to the suite's releases without one
                     (tools/pages/extensions/index.html)
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
import json
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
PARTS = ('IDE', 'DICTIONARY', 'PLAYER', 'GAMES', 'MAP', 'DOWNLOADS', 'EXTENSIONS')
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

# The extensions page (extensions/, from tools/pages/extensions/index.html):
# the xTalk Suite's extensions, which OXT-Beyond ships built in, with a
# link to each one's .lce package for the other IDEs built on LiveCode
# Community 9. The packages are the suite's release files
# (xtalk-suite/.github/workflows/lce-packages.yml), named
# <package>-<version>.lce, so the page links the files of the suite's
# newest release that has them (pages.yml lists it; --suite-release and
# --suite-assets) and is as new as the last time the site was built. A
# package this table does not name is still linked, under "More from the
# suite", so a package the suite adds is never left off; a release with
# none of them, or none given, leaves every card with a link to the
# suite's releases instead of a file.
SUITE = 'https://github.com/SethMorrowSoftware/xtalk-suite'
SUITE_PACKAGE = re.compile(r'^(?P<package>[a-z0-9][a-z0-9-]*?)-(?P<version>[0-9][0-9A-Za-z.+-]*)\.lce$')
SUITE_TAG = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')
# (member, name, what it is built on, what it does, what it needs or None,
#  its repository, its icon's SVG paths, [(package, label)] in load order)
EXTENSIONS = (
    ('sodiumxt', 'SodiumXT', 'Native library · libsodium',
     'Modern cryptography made easy: authenticated encryption with a passphrase or a key, '
     'signatures, key exchange, hashing and password hashing.',
     None, 'https://github.com/SethMorrowSoftware/SodiumXT',
     '<rect x="5" y="10.5" width="14" height="10" rx="2.2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5M12 14.5v2.5"/>',
     (('sodiumxt', 'SodiumXT'),)),
    ('torrentxt', 'TorrentXT', 'Native library · libtorrent',
     'The full BitTorrent protocol from plain script: add, seed and inspect torrents, with magnets, '
     'the DHT, uTP and BitTorrent v2.',
     None, 'https://github.com/SethMorrowSoftware/TorrentXT',
     '<path d="M12 3v11M7.5 9.5 12 14l4.5-4.5"/><circle cx="5" cy="19" r="2"/><circle cx="12" cy="19.5" r="2"/>'
     '<circle cx="19" cy="19" r="2"/>',
     (('torrentxt', 'TorrentXT'), ('torrentxt-helpers', 'Helpers'))),
    ('enetxt', 'enetxt', 'Native library · ENet',
     'Reliable UDP for real-time games and apps: many peers, channels, and reliable or fast '
     'delivery, with one broadcast to reach every peer.',
     None, 'https://github.com/SethMorrowSoftware/enetxt',
     '<path d="M13 2.5 5 13.5h6l-1 8 8-11h-6z"/>',
     (('enetxt', 'enetxt'), ('enetxt-helpers', 'Helpers'))),
    ('datachannelxt', 'DataChannelXT', 'Native library · libdatachannel',
     'WebRTC data channels: peer-to-peer messages that cross home routers and talk to web browsers.',
     None, 'https://github.com/SethMorrowSoftware/dataChannelXT',
     '<circle cx="6" cy="12" r="3"/><circle cx="18" cy="12" r="3"/><path d="M9 10.5h6M9 13.5h6"/>',
     (('datachannelxt', 'DataChannelXT'), ('datachannelxt-helpers', 'Helpers'))),
    ('box2dxt', 'Box2Dxt', 'Native library · Box2D v3',
     'Real 2D physics: your controls fall, roll, bounce, hinge and collide. The Kit binds bodies to '
     'the controls on a card in a few lines.',
     None, 'https://github.com/SethMorrowSoftware/Box2Dxt',
     '<rect x="3.5" y="13" width="7" height="7" rx="1"/><rect x="11" y="4" width="7" height="7" rx="1" '
     'transform="rotate(15 14.5 7.5)"/><circle cx="17" cy="17" r="3"/><path d="M2.5 21.5h19"/>',
     (('box2dxt', 'Box2Dxt'), ('box2dxt-kit', 'Kit'))),
    ('coinxt', 'CoinXT', 'Native library · trezor-crypto and libsecp256k1',
     'Bitcoin and Ethereum cryptography: hashes, keys, addresses, HD wallets and transaction '
     'signing, with a script layer on top.',
     None, 'https://github.com/SethMorrowSoftware/CoinXT',
     '<circle cx="12" cy="12" r="8.5"/><path d="M10 7.5h3a2 2 0 0 1 0 4h-3zM10 11.5h3.5a2 2 0 0 1 0 4H10zM10 6v12"/>',
     (('coinxt', 'CoinXT'), ('coinxt-script', 'Script layer'))),
    ('onionxt', 'OnionXT', 'Script library · Tor',
     'Tor for any connection and v3 onion services, by talking to Tor running on the computer, '
     'with a small web server to put a site on an onion address.',
     'Tor running on the computer', 'https://github.com/SethMorrowSoftware/OnionXT',
     '<path d="M12 3c4 4 7 7 7 11a7 7 0 0 1-14 0c0-4 3-7 7-11z"/><path d="M12 7c2 2.5 3.5 4.5 3.5 7a3.5 3.5 0 0 1-7 0'
     'c0-2.5 1.5-4.5 3.5-7z"/>',
     (('onionxt', 'OnionXT'), ('onionxt-httpd', 'Web server'))),
    ('nostrxt', 'NostrXT', 'Script library · Nostr',
     'The client side of Nostr: signed events, bech32 names, encrypted messages and a relay client, '
     'in plain script over the suite\'s own cryptography.',
     'CoinXT and SodiumXT', 'https://github.com/SethMorrowSoftware/NostrXT',
     '<circle cx="12" cy="12" r="2.2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4'
     'M4.9 4.9a10 10 0 0 0 0 14.2M19.1 4.9a10 10 0 0 1 0 14.2"/>',
     (('nostrxt', 'NostrXT'), ('nostrxt-relay', 'Relay client'))),
)
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


# The two plugins OXT-Beyond ships built in and also releases as .lce
# packages for the other xTalks (tools/plugins), which the extensions page
# lists after the suite's extensions: (id, name, what it is, what it does,
# what it needs, the file suffix in an OXT-Beyond release, as DOWNLOADS
# names them). They link the files of the release the front page's
# Downloads links (--release), or OXT-Beyond's releases without one.
PLUGINS = (
    ('xtalk-assistant', 'xTalk Assistant', 'IDE plugin · AI helper',
     'An AI helper in a window beside your stacks: ask it about xTalk, and it writes, runs and debugs '
     'scripts with you, using the AI service and key you choose. Off until you turn it on.',
     'your own key for an AI service', 'xtalk-assistant-plugin.lce'),
    ('mcp-bridge', 'xTalk MCP Bridge', 'IDE plugin · Claude',
     'Lets Claude, in the Claude desktop app or Claude Code with your own Claude plan, read your open '
     'stacks and build in them: cards, controls, scripts, runs and saves, asking before each step. '
     'Off until you turn it on.',
     'the Claude desktop app or Claude Code, and Node.js', 'mcp-bridge-plugin.lce'),
)
PLUGIN_ICONS = {
    'xtalk-assistant': '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8a2.5 2.5 0 0 1-2.5 2.5H11l-4.5 4v-4h0A2.5 2.5 0 0 1 4 13.5z"/>'
                       '<path d="M12 6.5l1 2.3 2.3 1-2.3 1-1 2.3-1-2.3-2.3-1 2.3-1z"/>',
    'mcp-bridge': '<path d="M3 17h18M5 17c0-5 3-8 7-8s7 3 7 8M9 17v-4M15 17v-4M12 17V9"/>',
}


def plugins_html(tag, assets):
    """The extensions page's cards for OXT-Beyond's own plugins: each
    links its .lce in the OXT-Beyond release tag when that release has it
    (assets, its file names), or OXT-Beyond's releases."""
    if tag is not None and not re.match(r'^v[0-9][0-9A-Za-z.+-]*$', tag):
        raise BuildError('--release %r is not a release tag (v<version>)' % tag)
    cards = []
    for ident, name, kind, what, needs, suffix in PLUGINS:
        file = 'OXT-Beyond-%s-%s' % (tag[1:], suffix) if tag else None
        if file and file in assets:
            files_html = ('<div class="files"><a class="file" href="%s/releases/download/%s/%s" download>'
                          '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>'
                          '%s <small>%s</small></a></div>'
                          % (REPOSITORY, urllib.parse.quote(tag), urllib.parse.quote(file), html.escape(name),
                             html.escape(tag[1:])))
        else:
            files_html = ('<p class="soon">Its .lce package is on '
                          '<a href="%s/releases">OXT-Beyond\'s releases</a>.</p>' % REPOSITORY)
        cards.append(
            '      <article class="ext" id="%s">\n'
            '        <div class="ext-head">\n'
            '          <div class="icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg></div>\n'
            '          <div><h3>%s</h3><p class="kind">%s</p></div>\n'
            '        </div>\n'
            '        <p class="what">%s</p>\n'
            '        <p class="needs">Needs %s</p>\n'
            '        %s\n'
            '        <a class="source" href="%s/tree/main/tools/plugins">Guide and source</a>\n'
            '      </article>'
            % (html.escape(ident), PLUGIN_ICONS[ident], html.escape(name), html.escape(kind), html.escape(what),
               html.escape(needs), files_html, REPOSITORY))
    return '\n'.join(cards)


def suite_packages(assets):
    """The .lce packages among a suite release's files, as {package:
    (version, file)}: the newest version of each when there are two."""
    found = {}
    for name in sorted(assets):
        m = SUITE_PACKAGE.match(name)
        if not m:
            continue
        key = tuple(int(n) if n.isdigit() else n for n in re.split(r'[.+-]', m.group('version')))
        old = found.get(m.group('package'))
        if old is None or key > old[0]:
            found[m.group('package')] = (key, m.group('version'), name)
    return {k: (v[1], v[2]) for k, v in found.items()}


def suite_file_link(tag, name, label, version, primary):
    return ('<a class="file%s" href="%s/releases/download/%s/%s" download>'
            '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>'
            '%s <small>%s</small></a>'
            % ('' if primary else ' ghost', SUITE, urllib.parse.quote(tag), urllib.parse.quote(name),
               html.escape(label), html.escape(version)))


def extensions_html(tag, assets):
    """The extensions page's cards and its "More from the suite" list,
    as (cards, more): each card links the packages the release tag has
    (assets, its file names); with no tag, or none of a card's packages,
    the card links the suite's releases instead."""
    if tag is not None and not SUITE_TAG.match(tag):
        raise BuildError('--suite-release %r is not a tag name' % tag)
    packages = suite_packages(assets) if tag else {}
    named = set()
    cards = []
    for member, name, kind, what, needs, repo, icon, files in EXTENSIONS:
        links = []
        for i, (package, label) in enumerate(files):
            named.add(package)
            if package in packages:
                version, file = packages[package]
                links.append(suite_file_link(tag, file, label, version, i == 0))
        if links:
            files_html = '<div class="files">%s</div>' % ''.join(links)
        else:
            files_html = ('<p class="soon">The .lce packages are on '
                          '<a href="%s/releases">the xTalk Suite\'s releases</a>.</p>' % SUITE)
        cards.append(
            '      <article class="ext" id="%s">\n'
            '        <div class="ext-head">\n'
            '          <div class="icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg></div>\n'
            '          <div><h3>%s</h3><p class="kind">%s</p></div>\n'
            '        </div>\n'
            '        <p class="what">%s</p>\n'
            '%s'
            '        %s\n'
            '        <a class="source" href="%s">Guide and source</a>\n'
            '      </article>'
            % (html.escape(member), icon, html.escape(name), html.escape(kind), html.escape(what),
               ('        <p class="needs">Needs %s</p>\n' % html.escape(needs)) if needs else '',
               files_html, html.escape(repo)))
    more = [suite_file_link(tag, file, package, version, False)
            for package, (version, file) in sorted(packages.items()) if package not in named]
    return '\n'.join(cards), ''.join(more)


def extensions_page(source, target, tag=None, assets=(), beyond_tag=None, beyond_assets=()):
    """Writes the extensions page (tools/pages/extensions/index.html) to
    target/index.html: the cards, and the release's own block (its name,
    its checksums and any package the cards do not name) or, without a
    release with packages, the block that says where they will be."""
    with open(os.path.join(source, 'index.html'), encoding='utf-8') as f:
        page = f.read()
    cards, more = extensions_html(tag, assets)
    has = bool(tag) and bool(suite_packages(assets))
    blocks = {'SUITE_RELEASE': has, 'SUITE_NONE': not has, 'SUITE_MORE': has and bool(more),
              'SUITE_SUMS': has and 'SHA256SUMS' in assets}
    # (every marker is looked for first: a block may sit inside another
    # that goes before it is reached)
    for key in blocks:
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        if start not in page or end not in page:
            raise BuildError('tools/pages/extensions/index.html has no %s ... %s' % (start, end))
    for key, keep in blocks.items():
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        while start in page:
            at = page.index(start)
            stop = page.index(end, at) + len(end)
            page = page[:at] + (page[at + len(start):stop - len(end)] if keep else '') + page[stop:]
    page = page.replace('@EXTENSIONS_LIST@', cards)
    page = page.replace('@PLUGINS_LIST@', plugins_html(beyond_tag, set(beyond_assets)))
    if has:
        page = page.replace('@SUITE_MORE_LIST@', more)
        page = page.replace('@SUITE_TAG@', html.escape(tag))
        page = page.replace('@SUITE_TAG_URL@', '%s/releases/tag/%s' % (SUITE, urllib.parse.quote(tag)))
        page = page.replace('@SUITE_SUMS_URL@', '%s/releases/download/%s/SHA256SUMS' % (SUITE, urllib.parse.quote(tag)))
    os.makedirs(target)
    with open(os.path.join(target, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    return tag if has else None


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


PLAY_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 4.5v15l12.5-7.5z"/></svg>'


# The samples the gallery shows first, the first of them large
SPOTLIGHT = ('Beat Box', 'Fireworks', 'Live Weather')


def player_samples(player, featured=False):
    """The Stack Player's sample stacks that have a picture, as its
    samples/samples.json lists them: its featured lessons, or (featured
    False) the rest, those named in SPOTLIGHT first; [] when it has none,
    or none it can show."""
    try:
        with open(os.path.join(player, 'samples', 'samples.json'), encoding='utf-8') as f:
            listed = json.load(f)
    except (OSError, ValueError):
        return []
    if not isinstance(listed, list):
        return []
    shown = [s for s in listed
             if isinstance(s, dict) and isinstance(s.get('title'), str) and isinstance(s.get('image'), str)
             and bool(s.get('featured')) == featured
             and os.path.isfile(os.path.join(player, 'samples', s['image']))]
    first = [t for t in SPOTLIGHT if any(s['title'] == t for s in shown)]
    return ([s for t in first for s in shown if s['title'] == t]
            + [s for s in shown if s['title'] not in first])


def sample_slug(title):
    """The folder of a sample's page: games/<slug>/."""
    return re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')


def sample_tags(s):
    return ''.join('<span class="tag">%s</span>' % html.escape(t) for t in s.get('tags') or [] if isinstance(t, str))


def sample_card(s, spot=False):
    tags = sample_tags(s)
    return ('      <a class="stack%s" href="%s/">\n'
            '        <div class="shot">\n'
            '          <img src="../player/samples/%s" alt="">\n'
            '          <span class="play">%sPlay</span>\n'
            '        </div>\n'
            '        <div class="words"><h3>%s</h3><p>%s</p><div class="tags">%s</div></div>\n'
            '      </a>' % (' spot' if spot else '', html.escape(sample_slug(s['title'])),
                             html.escape(urllib.parse.quote(s['image'])), PLAY_ICON, html.escape(s['title']),
                             html.escape(str(s.get('description', ''))), tags))


def sample_pages(template, target, player):
    """Writes a page of its own for each sample the gallery shows, from
    games/stack-page.html: games/<slug>/index.html, which runs the sample in
    the Stack Player in a frame (?play=<title>)."""
    with open(template, encoding='utf-8') as f:
        page = f.read()
    for s in player_samples(player, False) + player_samples(player, True):
        folder = os.path.join(target, sample_slug(s['title']))
        if not sample_slug(s['title']) or os.path.exists(folder):
            raise BuildError('the sample %r has no folder of its own under games/' % s['title'])
        os.makedirs(folder)
        text = page
        for key, value in (('TITLE', html.escape(s['title'])),
                           ('DESCRIPTION', html.escape(str(s.get('description', '')))),
                           ('TAGS', sample_tags(s)), ('PLAY', html.escape(urllib.parse.quote(s['title']))),
                           ('IMAGE', html.escape(urllib.parse.quote(s['image'])))):
            text = text.replace('@%s@' % key, value)
        with open(os.path.join(folder, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)


def gallery(page, player):
    """Fills the web stacks page's blocks with a card for each of the Stack
    Player's samples, each opening its own page (sample_pages):
    PLAYER_SAMPLES (the first one large) and PLAYER_LESSONS (its featured
    stacks). A block with no samples is left out; a page without the
    blocks (an older one) is left as it is."""
    if not os.path.isfile(page):
        return
    with open(page, encoding='utf-8') as f:
        text = f.read()
    for key, featured in (('PLAYER_SAMPLES', False), ('PLAYER_LESSONS', True)):
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        if start not in text or end not in text:
            continue
        cards = [sample_card(s, spot=(i == 0 and not featured))
                 for i, s in enumerate(player_samples(player, featured))]
        at, stop = text.index(start), text.index(end) + len(end)
        block = ''
        if cards:
            block = text[at:stop].replace('@%s_LIST@' % key, '\n'.join(cards)).replace(start, '').replace(end, '')
        text = text[:at] + block + text[stop:]
    with open(page, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def games(source, target, player):
    """Copies tools/pages/games, each page told the engine's file in the player."""
    if not os.path.isdir(source):
        return False
    engines = sorted(n for n in os.listdir(player) if re.fullmatch(r'standalone-.*\.js', n))
    if not engines:
        print('no games: the Stack Player has no engine for them')
        return False
    shutil.copytree(source, target)
    gallery(os.path.join(target, 'index.html'), player)
    template = os.path.join(target, 'stack-page.html')
    if os.path.isfile(template):
        sample_pages(template, target, player)
        os.remove(template)
    for root, _, names in os.walk(target):
        for name in names:
            if name == 'index.html':
                path = os.path.join(root, name)
                with open(path, encoding='utf-8') as f:
                    page = f.read()
                with open(path, 'w', encoding='utf-8', newline='\n') as f:
                    f.write(page.replace('@ENGINE_JS@', engines[0]))
    return True


# The logo the front page and the web stacks' page show (tools/pages/brand,
# written by Installer/oxt-beyond/branding/draw_branding.py): its still and
# moving SVG, the small icon (the favicon and the header's mark) and the
# banner the page names for link previews (og:image)
BRAND = ('icon.svg', 'logo.svg', 'logo-animated.svg', 'social.png')


def brand(source, target):
    """Copies the logo files beside the front page."""
    missing = [n for n in BRAND if not os.path.isfile(os.path.join(source, n))]
    if missing:
        raise BuildError('tools/pages/brand has no %s: run Installer/oxt-beyond/branding/draw_branding.py'
                         % ', '.join(missing))
    os.makedirs(target)
    for name in BRAND:
        shutil.copyfile(os.path.join(source, name), os.path.join(target, name))


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
    # The extensions page goes up with every site: the extensions are
    # OXT-Beyond's own, and without a suite release its cards link the
    # suite's releases
    suite, suite_assets = getattr(args, 'suite_release', None), getattr(args, 'suite_assets', None)
    if suite and not suite_assets:
        raise BuildError('--suite-release needs --suite-assets')
    listed = set()
    if suite_assets:
        with open(suite_assets, encoding='utf-8') as f:
            listed = {line.strip() for line in f if line.strip()}
    shown = extensions_page(os.path.join(HERE, 'extensions'), os.path.join(out, 'extensions'), suite, listed,
                            release if release else None, assets if release else ())
    if suite and not shown:
        print('no extension packages: %s has no .lce files' % suite)
    parts['EXTENSIONS'] = 'xTalk Suite %s' % shown if shown else 'xTalk Suite'
    front_page(out, parts)
    brand(os.path.join(HERE, 'brand'), os.path.join(out, 'brand'))
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
    ap.add_argument('--suite-release', metavar='TAG',
                    help="the xTalk Suite release whose .lce packages the extensions page links")
    ap.add_argument('--suite-assets', metavar='FILE', help="that release's file names, one a line")
    args = ap.parse_args()
    try:
        build(args)
    except (BuildError, zipfile.BadZipFile, OSError) as e:
        print('build_pages.py: %s' % e, file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
