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
      [--preview TAG --preview-assets FILE]
      [--suite-release TAG --suite-assets FILE [--suite-packages FOLDER]]
      [--release-built-in JSON] [--preview-built-in JSON]

  DIR/index.html     the front page (tools/pages/index.html)
  DIR/brand/         the logo it shows (tools/pages/brand)
  DIR/ide/           OXT-Beyond-<version>-web-ide.zip's site (tools/web-ide)
  DIR/player/        OXT-Beyond-<version>-web-player.zip's site
                     (tools/web-player)
  DIR/play/          the bare player: the zip's play/index.html (the
                     stack and nothing else, tools/web-player/play.html),
                     a site of its own beside the player, on the player's
                     engine and stack (left out for a zip without it)
  DIR/games/         the web stacks gallery (tools/pages/games), on the
                     player's engine: the big ones on pages of their own,
                     and a card and a page for each of the player's samples
                     with a picture; a sample in OWN_PAGES (Nova Rescue, Wobble Forts,
                     Puzzle Almanac)
                     has a big one's page instead, which plays it in the
                     bare player, and only when the site has both
  DIR/dictionary/    the Dictionary that the IDE's Help > Dictionary Online
                     opens, made from the web IDE's own html_viewer and
                     dictionary data (tools/pages/build_dictionary.py), so
                     it is the IDE's of the same release; left out, with a
                     note, when the web IDE has none (one before 0.2.7)
  DIR/lessons/       the lessons, from the first line of xTalk to
                     extensions in xTalk Builder: a page a lesson, with a
                     search (tools/pages/build_lessons.py, from
                     tools/pages/lessons); they link the web IDE and the
                     Dictionary when the site has them
  DIR/extensions/    a card for every xTalk Suite extension, each with its
                     .lce packages for the IDEs built on LiveCode
                     Community 9: the files of the suite release
                     --suite-release (FILE lists its file names), or a
                     link to the suite's releases without one. An
                     extension the page's table (EXTENSIONS) does not
                     name has a card made from its packages, read from
                     FOLDER (the release's .lce files and SHA256SUMS); each
                     card says which release it is built into, of the
                     two the front page offers, from that release's
                     tools/oxt/xtalk-extensions.json (--release-built-in,
                     --preview-built-in), and says nothing of it without
                     them (tools/pages/extensions/index.html)
  DIR/welcome/       the pages for people coming from LiveCode
                     (tools/pages/welcome): a front page, a guide, the GPL
                     for in-house tools, and a stack checker that reads a
                     stack in the visitor's browser; written by hand, made
                     by its own src/build.py, and copied as they are,
                     without the builder, tests and README beside them
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

With --preview as well, the section offers two releases, each under its
own heading with its own files: the stable release (--release) first,
then the preview of the next version (--preview: a developer preview or
a release candidate), so that a visitor can choose. pick_releases.py
chooses the two from the project's releases, and pages.yml gives them.
Either may be given without the other; a release with none of the files
is left out, and the other keeps its place.

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
import hashlib
import html
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_dictionary  # noqa: E402
import build_lessons  # noqa: E402
import family  # noqa: E402
import seo  # noqa: E402

# The parts of the site, each with its card on the front page, and the
# Downloads section (from a release's files, not a folder of the site)
PARTS = ('IDE', 'DICTIONARY', 'LESSONS', 'PLAYER', 'GAMES', 'MAP', 'DOWNLOADS', 'EXTENSIONS')
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
# What a release is, by the pre-release part of its version (channel()):
# its heading in the Downloads section and what the page says of it
CHANNELS = {
    'stable': ('Stable release', 'The finished version, and the one to use for your own work.'),
    'dp': ('Developer preview',
           'The next version while it is being made: the newest features and fixes, less tested than '
           'the stable release, so keep copies of your stacks.'),
    'rc': ('Release candidate',
           'The next version, nearly done: it becomes the stable release when no serious bug turns up. '
           'It is less tested than the stable release, so keep copies of your stacks.'),
    'preview': ('Preview',
                'A build of the next version, less tested than the stable release, so keep copies of '
                'your stacks.'),
}
LIMIT = 100 * 1000 * 1000

# The extensions page (extensions/, from tools/pages/extensions/index.html):
# a card for every xTalk Suite extension, each with a link to its .lce
# packages for the IDEs built on LiveCode Community 9 and, when the build
# is told which extensions the OXT-Beyond releases it offers have built in,
# the release it comes with. The packages are the suite's release files
# (xtalk-suite/.github/workflows/lce-packages.yml), named
# <package>-<version>.lce, so the page links the files of the suite's
# newest release that has them (pages.yml lists it; --suite-release and
# --suite-assets) and is as new as the last time the site was built. A
# package belongs to the member its name starts with (curlxt-tsnet is
# curlxt's), and every member in the release has a card: the table below
# writes the ones it names, and a member it does not name, one that joined
# the suite after the table was written, gets a card made from its own
# packages, from what their manifest.xml and api.lcdoc say
# (--suite-packages, suite_package_facts). So a package the suite adds is
# never left off the page, and never only a bare link. A release with none
# of them, or none given, leaves every card with a link to the suite's
# releases instead of a file.
SUITE = 'https://github.com/SethMorrowSoftware/xtalk-suite'
SUITE_PACKAGE = re.compile(r'^(?P<package>[a-z0-9][a-z0-9-]*?)-(?P<version>[0-9][0-9A-Za-z.+-]*)\.lce$')
SUITE_TAG = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')
# (member, name, what it is built on, what it does, what it needs or None,
#  its repository, its icon's SVG paths, [(package, label)] in load order),
# in the order the page shows them: cryptography, networking, physics and
# 3D, game controllers and sound, show control, then documents and pictures
EXTENSIONS = (
    ('sodiumxt', 'SodiumXT', 'Native library · libsodium',
     'Modern cryptography made easy: authenticated encryption with a passphrase or a key, '
     'signatures, key exchange, hashing and password hashing.',
     None, 'https://github.com/SethMorrowSoftware/SodiumXT',
     '<rect x="5" y="10.5" width="14" height="10" rx="2.2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5M12 14.5v2.5"/>',
     (('sodiumxt', 'SodiumXT'),)),
    ('coinxt', 'CoinXT', 'Native library · trezor-crypto and libsecp256k1',
     'Bitcoin and Ethereum cryptography: hashes, keys, addresses, HD wallets and transaction '
     'signing, with a script layer on top.',
     None, 'https://github.com/SethMorrowSoftware/CoinXT',
     '<circle cx="12" cy="12" r="8.5"/><path d="M10 7.5h3a2 2 0 0 1 0 4h-3zM10 11.5h3.5a2 2 0 0 1 0 4H10zM10 6v12"/>',
     (('coinxt', 'CoinXT'), ('coinxt-script', 'Script layer'))),
    ('nostrxt', 'NostrXT', 'Script library · Nostr',
     'The client side of Nostr: signed events, bech32 names, encrypted messages and a relay client, '
     'in plain script over the suite\'s own cryptography.',
     'CoinXT and SodiumXT', 'https://github.com/SethMorrowSoftware/NostrXT',
     '<circle cx="12" cy="12" r="2.2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4'
     'M4.9 4.9a10 10 0 0 0 0 14.2M19.1 4.9a10 10 0 0 1 0 14.2"/>',
     (('nostrxt', 'NostrXT'), ('nostrxt-relay', 'Relay client'))),
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
    ('curlxt', 'curlxt', 'Native library · libcurl',
     'The internet from plain script: HTTP and HTTPS, FTP and FTPS, SFTP and SCP, SMTP mail and '
     'WebSockets, waiting for the answer or in the background. Its tsNet calls run stacks written '
     'for LiveCode\'s tsNet unchanged.',
     None, 'https://github.com/SethMorrowSoftware/curlXT',
     '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.5 3.6 5.3 3.6 8.5s-1.2 6-3.6 8.5'
     'c-2.4-2.5-3.6-5.3-3.6-8.5s1.2-6 3.6-8.5z"/>',
     (('curlxt', 'curlxt'), ('curlxt-helpers', 'Helpers'), ('curlxt-tsnet', 'tsNet calls'))),
    ('onionxt', 'OnionXT', 'Script library · Tor',
     'Tor for any connection and v3 onion services, by talking to Tor running on the computer, '
     'with a small web server to put a site on an onion address.',
     'Tor running on the computer', 'https://github.com/SethMorrowSoftware/OnionXT',
     '<path d="M12 3c4 4 7 7 7 11a7 7 0 0 1-14 0c0-4 3-7 7-11z"/><path d="M12 7c2 2.5 3.5 4.5 3.5 7a3.5 3.5 0 0 1-7 0'
     'c0-2.5 1.5-4.5 3.5-7z"/>',
     (('onionxt', 'OnionXT'), ('onionxt-httpd', 'Web server'))),
    ('box2dxt', 'Box2Dxt', 'Native library · Box2D v3',
     'Real 2D physics: your controls fall, roll, bounce, hinge and collide. The Kit binds bodies to '
     'the controls on a card in a few lines.',
     None, 'https://github.com/SethMorrowSoftware/Box2Dxt',
     '<rect x="3.5" y="13" width="7" height="7" rx="1"/><rect x="11" y="4" width="7" height="7" rx="1" '
     'transform="rotate(15 14.5 7.5)"/><circle cx="17" cy="17" r="3"/><path d="M2.5 21.5h19"/>',
     (('box2dxt', 'Box2Dxt'), ('box2dxt-kit', 'Kit'))),
    ('box3dxt', 'box3dxt', 'Native library · Box3D',
     'Real 3D physics by Erin Catto, the author of Box2D: bodies fall, collide, stack and hang on '
     'joints, and a renderer inside draws the world into an image. The Kit adds the camera, the '
     'keyboard and a player.',
     None, 'https://github.com/SethMorrowSoftware/box3dxt',
     '<path d="M10 8.5 16 12v6.5L10 22l-6-3.5V12z"/><path d="M4 12l6 3.5 6-3.5M10 15.5V22"/>'
     '<circle cx="18" cy="5" r="2.6"/>',
     (('box3dxt', 'box3dxt'), ('box3dxt-kit', 'Kit'))),
    ('render3dxt', 'render3dxt', 'Native library · software 3D renderer',
     'Textured, lit 3D drawn into an ordinary image: boxes, spheres and OBJ models with colours, '
     'textures and shine, under lights and a camera, thousands of triangles in a few milliseconds. '
     'box3dxt\'s Kit draws with it when it is installed.',
     None, 'https://github.com/SethMorrowSoftware/render3dxt',
     '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="12" cy="12" r="4.5"/>'
     '<path d="M9.3 10.7a3 3 0 0 1 2.5-1.9"/>',
     (('render3dxt', 'render3dxt'),)),
    ('gamepadxt', 'gamepadxt', 'Native library · SDL 3',
     'Game controllers: Xbox, PlayStation, Switch and most other pads with one button layout, '
     'plugged in and out while the stack runs, with rumble and lights.',
     None, 'https://github.com/SethMorrowSoftware/gamepadxt',
     '<path d="M7 7.5h10a4.5 4.5 0 0 1 4.4 5.4l-.8 4a2.6 2.6 0 0 1-4.6 1.1L14.5 16h-5L8 18a2.6 2.6 0 0 1-4.6-1.1'
     'l-.8-4A4.5 4.5 0 0 1 7 7.5z"/><path d="M8 10.3v3.4M6.3 12h3.4M15.5 10.5h.01M17.5 13h.01"/>',
     (('gamepadxt', 'gamepadxt'),)),
    ('audioxt', 'audioxt', 'Native library · miniaudio',
     'Sound for games and apps: many sounds mixed at once with low delay, music streamed from disk, '
     'tones, sound placed in 3D and the microphone. The engine\'s own play command keeps working '
     'beside it.',
     None, 'https://github.com/SethMorrowSoftware/audioxt',
     '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11"/>',
     (('audioxt', 'audioxt'),)),
    ('midixt', 'midixt', 'Native library · RtMidi',
     'MIDI in and out: list the computer\'s MIDI ports, send notes, controllers, program changes and '
     'SysEx, and read what arrives with its timing, from keyboards, synthesizers, lighting desks and '
     'music software.',
     None, 'https://github.com/SethMorrowSoftware/midixt',
     '<rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="M12 5v14M7.5 12.5V19M16.5 12.5V19"/>'
     '<path fill="currentColor" d="M6.3 5h2.4v7.5H6.3zM15.3 5h2.4v7.5h-2.4z"/>',
     (('midixt', 'midixt'),)),
    ('oscxt', 'oscxt', 'Native library · tinyosc',
     'Open Sound Control, the network language of control surfaces, lighting desks, media servers '
     'and music software: build and read OSC messages and bundles, sent over the engine\'s own '
     'sockets.',
     None, 'https://github.com/SethMorrowSoftware/oscxt',
     '<path d="M6 4v9M6 16v4M12 4v3M12 10v10M18 4v7M18 14v6"/><rect x="4" y="13" width="4" height="3" rx="1"/>'
     '<rect x="10" y="7" width="4" height="3" rx="1"/><rect x="16" y="11" width="4" height="3" rx="1"/>',
     (('oscxt', 'oscxt'),)),
    ('artnetxt', 'artnetxt', 'xTalk Builder library · Art-Net',
     'Stage lighting over a network: DMX512 levels for dimmers, LED fixtures and moving lights, and '
     'the Art-Net nodes on the network found. It is plain xTalk Builder, with no native library.',
     None, 'https://github.com/SethMorrowSoftware/artnetxt',
     '<rect x="8.5" y="2.5" width="7" height="4.5" rx="1.2"/><path d="M9.5 7 6 17M14.5 7 18 17"/>'
     '<ellipse cx="12" cy="19" rx="7" ry="2.2"/>',
     (('artnetxt', 'artnetxt'),)),
    ('pdfxt', 'pdfxt', 'Native library · PDFium',
     'PDF files in a stack: draw their pages into an image, read and search their text, and follow '
     'their outline and links, with PDFium, the PDF engine of Chromium. It reads PDFs; it does not '
     'make or change them.',
     'macOS 13 or later on a Mac', 'https://github.com/SethMorrowSoftware/pdfxt',
     '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M8.5 12.5h7M8.5 16h7"/>',
     (('pdfxt', 'pdfxt'),)),
    ('xlsxt', 'xlsxt', 'Native library · libxlsxwriter, zlib and Expat',
     'Excel workbooks from script: write a real .xlsx with formats, formulas and charts, and read one '
     'back, made by Excel, LibreOffice, Numbers or Google Sheets, with no copy of Excel needed.',
     None, 'https://github.com/SethMorrowSoftware/xlsxt',
     '<rect x="3.5" y="4" width="17" height="16" rx="2"/><path d="M3.5 9h17M3.5 14.5h17M9.5 4v16M15 4v16"/>',
     (('xlsxt', 'xlsxt'),)),
    ('webpxt', 'webpxt', 'Native library · libwebp',
     'WebP pictures, the format most of the web\'s images are in: read and write them, still and '
     'animated, lossy or lossless, straight to and from an image object.',
     None, 'https://github.com/SethMorrowSoftware/webpxt',
     '<rect x="3" y="4.5" width="18" height="15" rx="2"/><circle cx="8.5" cy="9.5" r="1.8"/>'
     '<path d="M3 17l5-5 4 4 3-3 6 6"/>',
     (('webpxt', 'webpxt'),)),
    ('barcodext', 'barcodext', 'Native library · zxing-cpp',
     'QR codes and barcodes: read them out of a picture, even a photo from a camera, and make new ones '
     'as a picture or as SVG. QR, Data Matrix, Aztec, PDF417, EAN, UPC, Code 128 and more.',
     None, 'https://github.com/SethMorrowSoftware/barcodext',
     '<rect x="3.5" y="3.5" width="6.5" height="6.5" rx="1"/><rect x="14" y="3.5" width="6.5" height="6.5" rx="1"/>'
     '<rect x="3.5" y="14" width="6.5" height="6.5" rx="1"/><path d="M14 14h2.5v2.5H14zM18 18h2.5v2.5H18zM14 20.5h2'
     'M20.5 14v2"/>',
     (('barcodext', 'barcodext'),)),
)
# A member the table does not name gets a card made from its packages
# (suite_package_facts): this icon, a parcel; the kind of library its first
# package is, by what it holds; and, when its packages could not be read,
# this for what it does
SUITE_ICON = ('<path d="M12 2.8 20.5 7.4v9.2L12 21.2l-8.5-4.6V7.4z"/>'
              '<path d="M3.5 7.4 12 12l8.5-4.6M12 12v9.2M7.8 5.1l8.5 4.6"/>')
SUITE_KINDS = {'native': 'Native library', 'lcb': 'xTalk Builder library', 'script': 'Script library'}
SUITE_UNREAD = 'New in the xTalk Suite: its guide says what it does and how to start.'
# What the page reads of a package: its manifest.xml and api.lcdoc, each
# no bigger than this, from a package whose SHA-256 is the one the
# release's SHA256SUMS gives; and no more of what it does than this many
# characters, cut at the end of a sentence
SUITE_PART_LIMIT = 4 * 1024 * 1024
SUITE_ABOUT_LIMIT = 320
# The keys an api.lcdoc entry is made of, as xtalk-suite's
# tools/build-extensions-site.py reads them: only a line that starts with
# one of these ends a field, so a line of a description such as
# "Note: ..." is part of it
LCDOC_KEYS = frozenset(('library', 'type', 'title', 'author', 'description', 'summary', 'tags', 'name',
                        'syntax', 'returns', 'parameters', 'references', 'example', 'examples', 'version',
                        'os', 'platforms', 'associations', 'introduced', 'changes', 'related'))
LOCAL_ONLY = {'serve.py', 'Start Web IDE.bat', 'README.txt'}


class BuildError(Exception):
    pass


def downloads_html(tag, assets):
    """A release's platforms in the Downloads section, for the release
    tag whose files are assets (their names): a link for each file it has."""
    if not re.match(r'^v[0-9][0-9A-Za-z.+-]*$', tag):
        raise BuildError('%r is not a release tag (v<version>)' % tag)
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
            out.append('<div class="platform"><h4>%s</h4><p>%s</p><div class="files">%s</div></div>'
                       % (html.escape(platform), html.escape(needs), ''.join(links)))
    return '\n'.join(out)


def channel(tag, preview=False):
    """Which of CHANNELS a release is, from its tag: v0.2.7 is 'stable',
    v0.2.8-dp.1 is 'dp', v0.2.8-rc.1 is 'rc', and a version with any other
    pre-release part is 'preview'. preview: it is a pre-release whatever
    its version says (GitHub marks it as one), so never 'stable'."""
    pre = tag.partition('+')[0].partition('-')[2]
    if not pre:
        return 'preview' if preview else 'stable'
    word = re.match(r'[A-Za-z]*', pre).group(0).lower()
    return word if word in ('dp', 'rc') else 'preview'


def downloads_channels(release, preview=None):
    """The Downloads section's releases, each (tag, assets) or None: the
    release first, then the preview of the next version. Returns
    [(tag, its block)] for those that have files to link, so [] when the
    page should have no Downloads section. The blocks have ids to link
    (downloads-stable, downloads-preview), so two previews are refused."""
    blocks = []
    for given, is_preview in ((release, False), (preview, True)):
        if not given:
            continue
        tag, assets = given
        if is_preview and release and channel(release[0]) != 'stable':
            raise BuildError('--preview %s with --release %s, which is a preview itself: give one of them'
                             % (tag, release[0]))
        listed = downloads_html(tag, assets)
        kind = channel(tag, is_preview)
        if not listed:
            print('no downloads of %s: it has none of the files the page links' % tag)
            continue
        name, what = CHANNELS[kind]
        blocks.append((tag,
                       '    <div class="channel%s" id="downloads-%s">\n'
                       '      <div class="channel-head">\n'
                       '        <h3>%s</h3>\n'
                       '        <span class="release">%s</span>\n'
                       '        <p>%s</p>\n'
                       '      </div>\n'
                       '      <div class="platforms">\n%s\n      </div>\n'
                       '      <p class="more"><a href="%s/releases/tag/%s">Every file, install notes and '
                       'checksums of %s</a></p>\n'
                       '    </div>'
                       % ('' if kind == 'stable' else ' next', 'stable' if kind == 'stable' else 'preview',
                          html.escape(name), html.escape(tag), html.escape(what), listed,
                          REPOSITORY, urllib.parse.quote(tag), html.escape(tag))))
    return blocks


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


def suite_family(package):
    """The member a package belongs to: curlxt-tsnet is curlxt's."""
    return package.split('-', 1)[0]


def lcdoc_about(text):
    """What an extension does, from its api.lcdoc: the first paragraph of
    the library entry (a script library's Description, an xTalk Builder
    library's Summary) as plain text, no longer than SUITE_ABOUT_LIMIT,
    or ''."""
    entry = re.split(r'\n(?=Name:)', text.replace('\r\n', '\n').replace('\r', '\n'))[0]
    fields, key = {}, None
    for line in entry.split('\n'):
        m = re.match(r'^([A-Za-z][A-Za-z ]*):(?:\s+(.*))?$', line)
        if m and m.group(1).lower() in LCDOC_KEYS:
            key = m.group(1).lower()
            fields.setdefault(key, [])
            if m.group(2) and m.group(2).strip():
                fields[key].append(m.group(2).strip())
        elif key is not None:
            fields[key].append(line.strip())
    first = []
    for line in fields.get('description') or fields.get('summary') or []:
        if line:
            first.append(line)
        elif first:
            break
    # <handlerName> is a link into the Dictionary and `this` is code: in
    # plain words both are the name
    about = re.sub(r'<([A-Za-z][A-Za-z0-9_.]*)>', r'\1', ' '.join(first)).replace('`', '')
    about = re.sub(r'\s+', ' ', about).strip()
    if len(about) <= SUITE_ABOUT_LIMIT:
        return about
    cut = about[:SUITE_ABOUT_LIMIT]
    end = cut.rfind('. ')
    if end > SUITE_ABOUT_LIMIT // 2:
        return cut[:end + 1]
    return cut[:cut.rfind(' ')].rstrip(',;:') + ' ...'


def read_suite_package(path):
    """What a card may say of one package (suite_package_facts), from its
    manifest.xml and api.lcdoc; ValueError, KeyError, zipfile.BadZipFile or
    ET.ParseError when it cannot be read."""
    with zipfile.ZipFile(path) as z:
        names = set(z.namelist())

        def part(name):
            info = z.getinfo(name)
            if info.file_size > SUITE_PART_LIMIT:
                raise ValueError('its %s is %d bytes' % (name, info.file_size))
            with z.open(info) as f:
                data = f.read(SUITE_PART_LIMIT + 1)
            if len(data) > SUITE_PART_LIMIT:
                raise ValueError('its %s is more than %d bytes' % (name, SUITE_PART_LIMIT))
            return data

        manifest = ET.fromstring(part('manifest.xml'))
        about = lcdoc_about(part('api.lcdoc').decode('utf-8', 'replace')) if 'api.lcdoc' in names else ''

    def field(tag):
        found = manifest.find(tag)
        return re.sub(r'\s+', ' ', found.text or '').strip() if found is not None else ''

    if not field('name'):
        raise ValueError('its manifest.xml names no id')
    if any(n.startswith('code/') and n.count('/') >= 2 for n in names):
        kind = 'native'
    elif 'module.lcm' in names:
        kind = 'lcb'
    else:
        kind = 'script'
    # (com.livecode.* are the engine's own modules, there in every IDE)
    requires = [r.get('name').strip() for r in manifest.findall('requires')
                if (r.get('name') or '').strip() and not r.get('name').strip().startswith('com.livecode.')]
    return {'id': field('name'), 'title': field('title'), 'requires': requires, 'kind': kind, 'about': about}


def suite_package_facts(folder, files):
    """What the cards may say of the packages in folder (a suite release's
    files, as pages.yml downloads them): {file: {'id', 'title', 'requires',
    'kind', 'about'}} for each of files whose SHA-256 is the one the
    release's SHA256SUMS gives, read from its manifest.xml and the library
    entry of its api.lcdoc. A package that is not listed there, is not the
    file listed or cannot be read is left out with a note, and its card
    says less; without SHA256SUMS none is read. Nothing in a package is
    run."""
    facts = {}
    sums_path = os.path.join(folder, 'SHA256SUMS')
    if not os.path.isfile(sums_path):
        print('extension packages: %s has no SHA256SUMS, so none of them is read' % folder)
        return facts
    sums = {}
    with open(sums_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = re.match(r'^([0-9a-fA-F]{64}) [ *]?(\S.*?)\s*$', line)
            if m:
                sums[m.group(2)] = m.group(1).lower()
    for name in sorted(files):
        if not SUITE_PACKAGE.match(name):
            continue
        path = os.path.join(folder, name)
        why = None
        if name not in sums:
            why = 'not in SHA256SUMS'
        elif not os.path.isfile(path):
            why = 'not downloaded'
        else:
            digest = hashlib.sha256()
            with open(path, 'rb') as f:
                for block in iter(lambda: f.read(1 << 20), b''):
                    digest.update(block)
            if digest.hexdigest() != sums[name]:
                why = 'not the file SHA256SUMS lists'
        if why is None:
            try:
                facts[name] = read_suite_package(path)
            except (ValueError, KeyError, zipfile.BadZipFile, ET.ParseError, OSError) as e:
                why = 'not readable (%s)' % e
        if why:
            print('extension packages: %s is %s, so its card says less' % (name, why))
    return facts


def suite_title(family, title):
    """A package's title without its member's name and the suite's usual
    ending: "render3dxt: 3D Renderer for OpenXTalk" is "3D Renderer",
    "TorrentXT helpers" is "helpers", "tsNet calls (curlxt)" is "tsNet
    calls", and "CoinXT" is ""."""
    title = re.sub(r'\(\s*%s\s*\)' % re.escape(family), ' ', title, flags=re.I)
    title = re.sub(r'^\s*%s(?![A-Za-z0-9])' % re.escape(family), '', title, flags=re.I)
    title = re.sub(r'\s+for OpenXTalk\s*$', '', title, flags=re.I)
    return re.sub(r'\s+', ' ', title).strip(' :-')


def suite_label(family, package, facts):
    """The button of a package the table does not name: its title without
    its member's name ("Helpers", "tsNet calls"), or the end of its own
    name ("box3dxt-kit" is "Kit")."""
    label = suite_title(family, (facts or {}).get('title', ''))
    if not label:
        label = package[len(family):].strip('-').replace('-', ' ') or package
    # (a first word in lower case starts with a capital, as the table's
    # do; a name such as tsNet keeps its own)
    if label.split(' ', 1)[0].islower():
        label = label[0].upper() + label[1:]
    return label


def built_line(member, built_in):
    """A card's line on OXT-Beyond itself, from built_in: [(version,
    {member, ...})] of the releases the site offers whose built-in xTalk
    Suite extensions are known, the stable release first. The first of
    them that has it, or that the newest of them does not; nothing when
    none is known."""
    if not built_in:
        return ''
    for version, members in built_in:
        if member in members:
            return '        <p class="built">Built into OXT-Beyond %s</p>\n' % html.escape(version)
    return ('        <p class="built no">Not built into OXT-Beyond %s: install its package there too</p>\n'
            % html.escape(built_in[-1][0]))


def extension_card(ident, icon, name, kind, what, needs, built, files_html, source):
    return ('      <article class="ext" id="%s">\n'
            '        <div class="ext-head">\n'
            '          <div class="icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg></div>\n'
            '          <div><h3>%s</h3><p class="kind">%s</p></div>\n'
            '        </div>\n'
            '        <p class="what">%s</p>\n'
            '%s'
            '%s'
            '        %s\n'
            '        <a class="source" href="%s">Guide and source</a>\n'
            '      </article>'
            % (html.escape(ident), icon, html.escape(name), html.escape(kind), html.escape(what),
               ('        <p class="needs">Needs %s</p>\n' % html.escape(needs)) if needs else '',
               built, files_html, html.escape(source)))


def suite_file_link(tag, name, label, version, primary):
    return ('<a class="file%s" href="%s/releases/download/%s/%s" download>'
            '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>'
            '%s <small>%s</small></a>'
            % ('' if primary else ' ghost', SUITE, urllib.parse.quote(tag), urllib.parse.quote(name),
               html.escape(label), html.escape(version)))


def files_html(links):
    if links:
        return '<div class="files">%s</div>' % ''.join(links)
    return ('<p class="soon">The .lce packages are on '
            '<a href="%s/releases">the xTalk Suite\'s releases</a>.</p>' % SUITE)


def suite_order(family, own, known):
    """A member's packages (own; known: what each one's manifest says, or
    None) in the order they install: the one named after the member first,
    then each before any that needs it."""
    ids = {facts['id']: package for package, facts in known.items() if facts}

    def depth(package, seen=()):
        needs = [ids[r] for r in (known.get(package) or {}).get('requires', ())
                 if r in ids and ids[r] != package and ids[r] not in seen]
        return 1 + max([depth(n, seen + (package,)) for n in needs] or [0])

    return sorted(own, key=lambda p: (p != family, depth(p), p))


def extensions_html(tag, assets, facts=None, built_in=(), taken=()):
    """The extensions page's cards: one for each member of the table, and
    after them one for each member of the release tag that the table does
    not name, made from its packages. Each card links the packages the
    release has (assets, its file names), a package of its member that the
    table does not name after the ones it does; with no tag, or none of a
    card's packages, the card links the suite's releases instead. facts:
    suite_package_facts(), by file; built_in: as built_line() takes it;
    taken: the ids the page has already, which a card made from a package
    does not take."""
    if tag is not None and not SUITE_TAG.match(tag):
        raise BuildError('--suite-release %r is not a tag name' % tag)
    facts = facts or {}
    packages = suite_packages(assets) if tag else {}
    families = {}
    for package in sorted(packages):
        families.setdefault(suite_family(package), []).append(package)
    names = {row[0]: row[1] for row in EXTENSIONS}
    cards = []
    for member, name, kind, what, needs, repo, icon, files in EXTENSIONS:
        links = []
        named = [package for package, _ in files]
        for i, (package, label) in enumerate(files):
            if package in packages:
                version, file = packages[package]
                links.append(suite_file_link(tag, file, label, version, i == 0))
        for package in families.get(member, []):
            if package not in named:
                version, file = packages[package]
                links.append(suite_file_link(tag, file, suite_label(member, package, facts.get(file)), version,
                                             False))
        cards.append(extension_card(member, icon, name, kind, what, needs, built_line(member, built_in),
                                    files_html(links), repo))
    # A member the table does not name: a card made from its packages,
    # which links them in the order they install (suite_order)
    unnamed = {}
    for family in sorted(f for f in families if f not in names):
        known = {p: facts.get(packages[p][1]) for p in families[family]}
        order = suite_order(family, families[family], known)
        title = (known[order[0]] or {}).get('title', '')
        unnamed[family] = (order, known, title if title.lower() == family else family)
    shown = dict(names)
    shown.update((family, member[2]) for family, member in unnamed.items())
    # (a package's id: its member, for what a member needs of another)
    owner = {}
    for package, (version, file) in packages.items():
        if facts.get(file):
            owner[facts[file]['id']] = suite_family(package)
    taken = set(taken) | set(names)
    for family, (order, known, name) in unnamed.items():
        first = known[order[0]] or {}
        kind = SUITE_KINDS.get(first.get('kind'), 'xTalk Suite extension')
        if suite_title(family, first.get('title', '')):
            kind += ' · ' + suite_title(family, first.get('title', ''))
        needs = []
        for package in order:
            for wanted in (known[package] or {}).get('requires', ()):
                other = owner.get(wanted)
                if other == family:
                    continue
                needed = shown.get(other, other) if other else wanted
                if needed not in needs:
                    needs.append(needed)
        links = [suite_file_link(tag, packages[p][1], name if i == 0 else suite_label(family, p, known[p]),
                                 packages[p][0], i == 0) for i, p in enumerate(order)]
        ident = family if family not in taken else 'suite-' + family
        taken.add(ident)
        cards.append(extension_card(ident, SUITE_ICON, name, kind, first.get('about') or SUITE_UNREAD,
                                    ' and '.join(needs) if needs else None, built_line(family, built_in),
                                    files_html(links), '%s/tree/%s/%s' % (SUITE, urllib.parse.quote(tag), family)))
    return '\n'.join(cards)


def built_in_members(path):
    """The xTalk Suite extensions an OXT-Beyond release has built in, from
    its tools/oxt/xtalk-extensions.json (pages.yml takes the release's own
    with git show), as their members' names in lower case: a member's name
    and the last part of its repository's ("SodiumXT",
    "SethMorrowSoftware/SodiumXT": sodiumxt). None, with a note, when the
    file cannot be read: the cards then say nothing of that release."""
    try:
        with open(path, encoding='utf-8') as f:
            members = json.load(f)['members']
        found = set()
        for member in members:
            for value in (member.get('name'), (member.get('repository') or '').rsplit('/', 1)[-1]):
                if isinstance(value, str) and value.strip():
                    found.add(value.strip().lower())
        return found
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as e:
        print('built-in extensions: %s is not an xtalk-extensions.json (%s), so the cards say nothing of it'
              % (path, e))
        return None


def extensions_page(source, target, tag=None, assets=(), beyond_tag=None, beyond_assets=(), facts=None,
                    built_in=()):
    """Writes the extensions page (tools/pages/extensions/index.html) to
    target/index.html: the cards (extensions_html: facts and built_in are
    as it takes them), the release's own block (its name and its
    checksums) or, without a release with packages, the block that says
    where they will be, and what the page says of OXT-Beyond's built-in
    extensions only when built_in says which they are."""
    with open(os.path.join(source, 'index.html'), encoding='utf-8') as f:
        page = f.read()
    cards = extensions_html(tag, assets, facts, built_in, set(re.findall(r'\bid="([^"]*)"', page)) |
                            {row[0] for row in PLUGINS})
    has = bool(tag) and bool(suite_packages(assets))
    blocks = {'SUITE_RELEASE': has, 'SUITE_NONE': not has, 'SUITE_SUMS': has and 'SHA256SUMS' in assets,
              'BUILT_IN': bool(built_in)}
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


# The bare player's page names the player's folder in this meta, relative
# to itself: "../" in the player's zip (play/index.html), "../player/" at
# <site>/play/
BARE_BASE = '<meta name="oxt-player-base" content="../">'


def bare_player(out):
    """Moves the player's play/index.html (tools/web-player/play.html) to
    <out>/play/, a site of its own, its engine, stack and samples still the
    player's. False for a player without it (one before 0.2.7-rc.6.15)."""
    page = os.path.join(out, 'player', 'play', 'index.html')
    if not os.path.isfile(page):
        return False
    with open(page, encoding='utf-8') as f:
        text = f.read()
    if text.count(BARE_BASE) != 1:
        raise BuildError('player/play/index.html does not have %s once' % BARE_BASE)
    os.makedirs(os.path.join(out, 'play'))
    with open(os.path.join(out, 'play', 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text.replace(BARE_BASE, BARE_BASE.replace('"../"', '"../player/"')))
    shutil.rmtree(os.path.join(out, 'player', 'play'))
    return True


# The forum's "Try it in the browser" (seth, 2026-11-19): a stack attached
# to a post on openxtalk.org/forum plays at <site>/try/ (tools/pages/forum/
# index.html), in a copy of the bare player at try/box/ that a frame boxes
# in. Not on the forum's own site: its login cookies are there, and a
# stack would run beside them. Here the frame's sandbox has no
# allow-same-origin, so the stack is a stranger to this site (the web IDE
# keeps people's stacks here) as well as to the forum; the box's page,
# opened anywhere but in such a frame, goes back to try/ instead of
# playing (FORUM_GUARD, as the OXT Community Stacks gallery does it); and
# it takes a stack from the forum's stack files alone, which the forum's
# oxt/stacktools extension serves to anyone, with no login, only when a
# guest may download them.
FORUM_SANDBOX = 'allow-scripts allow-downloads allow-popups allow-popups-to-escape-sandbox allow-pointer-lock'
FORUM_GUARD = ('<script data-cfasync="false">if(self.origin!=="null"||self===top)'
               '{location.replace("../")}</script>')
# (no Referer to the forum; and neither try/ nor its box is for search
# engines: tools/pages/seo.py leaves a noindex page out and unchanged)
FORUM_BOX_HEAD = '<meta name="referrer" content="no-referrer">\n<meta name="robots" content="noindex">'
FORUM_FILES = 'https://openxtalk.org/forum/app.php/oxtstack/file/'
# The bare player's own rule (play.html, sameSite): this site's files only
SAME_SITE = "if (url.origin !== location.origin || !/^https?:$/.test(url.protocol)) return null;"
FORUM_ONLY = ("if (url.protocol !== 'https:' || url.href.indexOf('%s') !== 0"
              " || url.search || url.hash) return null;" % FORUM_FILES)


def forum_player(out):
    """Puts the forum's try page at <out>/try/ and its boxed player at
    <out>/try/box/, made from the bare player at <out>/play/ (bare_player,
    which must have run). Refuses a bare player whose page has changed so
    that the box could not be put on it."""
    with open(os.path.join(out, 'play', 'index.html'), encoding='utf-8') as f:
        text = f.read()
    based = BARE_BASE.replace('"../"', '"../player/"')
    for part, what in (('<head>', 'a single <head>'), (based, 'its base'), (SAME_SITE, 'its rule for stacks')):
        if text.count(part) != 1:
            raise BuildError('the bare player has changed: the forum\'s box needs %s in it' % what)
    text = text.replace('<head>', '<head>\n' + FORUM_GUARD + '\n' + FORUM_BOX_HEAD, 1)
    text = text.replace(based, BARE_BASE.replace('"../"', '"../../player/"'), 1)
    text = text.replace(SAME_SITE, FORUM_ONLY, 1)
    text = text.replace("'The stack must be on this site: '", "'The stack must be a forum stack: '", 1)
    with open(os.path.join(HERE, 'forum', 'index.html'), encoding='utf-8') as f:
        page = f.read()
    for hole in ('@SANDBOX@', '@FORUM_FILES@'):
        if page.count(hole) != 1:
            raise BuildError('tools/pages/forum/index.html does not have %s once' % hole)
    page = page.replace('@SANDBOX@', FORUM_SANDBOX).replace('@FORUM_FILES@', FORUM_FILES)
    os.makedirs(os.path.join(out, 'try', 'box'))
    with open(os.path.join(out, 'try', 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    with open(os.path.join(out, 'try', 'box', 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


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

# The Stack Player's samples with a page of their own in the gallery, as
# the big ones have (title: its folder, tools/pages/games/<folder>/). The
# page plays the sample in the bare player (play/?play=<title>), so it
# goes up only with a player that lists the sample and a site that has
# the bare player; then the sample gets no small card and no page from
# stack-page.html, and its card is the one in games/index.html between
# <!-- @OWN_PAGE:<folder>@ --> and <!-- /@OWN_PAGE:<folder>@ -->, on
# lines of their own. Without them (a site built from a player before
# the sample), the page and its card are left out, so no page on the site
# plays a stack its player lacks.
OWN_PAGES = {'Nova Rescue': 'nova-rescue', 'Wobble Forts': 'wobble-forts', 'Puzzle Almanac': 'puzzle-almanac'}


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


def sample_pages(template, target, player, own=()):
    """Writes a page of its own for each sample the gallery shows, from
    games/stack-page.html: games/<slug>/index.html, which runs the sample in
    the Stack Player in a frame (?play=<title>). The titles in own have a
    page of their own already (own_pages)."""
    with open(template, encoding='utf-8') as f:
        page = f.read()
    for s in player_samples(player, False) + player_samples(player, True):
        if s['title'] in own:
            continue
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


def gallery(page, player, own=()):
    """Fills the web stacks page's blocks with a card for each of the Stack
    Player's samples, each opening its own page (sample_pages):
    PLAYER_SAMPLES (the first one large) and PLAYER_LESSONS (its featured
    stacks), but those in own, whose card is with the big ones (own_pages).
    A block with no samples is left out; a page without the blocks (an
    older one) is left as it is."""
    if not os.path.isfile(page):
        return
    with open(page, encoding='utf-8') as f:
        text = f.read()
    for key, featured in (('PLAYER_SAMPLES', False), ('PLAYER_LESSONS', True)):
        start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
        if start not in text or end not in text:
            continue
        cards = [sample_card(s, spot=(i == 0 and not featured))
                 for i, s in enumerate(t for t in player_samples(player, featured) if t['title'] not in own)]
        at, stop = text.index(start), text.index(end) + len(end)
        block = ''
        if cards:
            block = text[at:stop].replace('@%s_LIST@' % key, '\n'.join(cards)).replace(start, '').replace(end, '')
        text = text[:at] + block + text[stop:]
    with open(page, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def own_pages(target, player, bare):
    """Keeps or takes out each page of OWN_PAGES in the copied gallery
    <target>, and its card: kept when bare (the site has the bare player)
    and the player lists the sample with its picture, as the gallery shows
    its samples. A gallery with neither the page nor its card (one a test
    makes) is left as it is; one with only one of them is a mistake.
    Returns the titles kept."""
    index = os.path.join(target, 'index.html')
    text = ''
    if os.path.isfile(index):
        with open(index, encoding='utf-8') as f:
            text = f.read()
    listed = {s['title'] for s in player_samples(player, False) + player_samples(player, True)}
    kept = set()
    for title, folder in sorted(OWN_PAGES.items()):
        start, end = '<!-- @OWN_PAGE:%s@ -->' % folder, '<!-- /@OWN_PAGE:%s@ -->' % folder
        page = os.path.isfile(os.path.join(target, folder, 'index.html'))
        card = text.count(start) == 1 and text.count(end) == 1 and text.index(start) < text.index(end)
        if not page and start not in text and end not in text:
            continue
        if not page or not card:
            raise BuildError('the gallery has %s for %r: it needs games/%s/index.html and its card in '
                             'games/index.html between %s and %s'
                             % ('a card and no page' if not page else 'a page and no card', title, folder, start, end))
        # the marker lines, from the first one's start to the end of the last
        at = text.rfind('\n', 0, text.index(start)) + 1
        stop = text.find('\n', text.index(end))
        stop = len(text) if stop < 0 else stop + 1
        first = text.find('\n', text.index(start))
        last = text.rfind('\n', 0, text.index(end)) + 1
        if bare and title in listed:
            kept.add(title)
            text = text[:at] + text[first + 1:last] + text[stop:]
        else:
            text = text[:at] + text[stop:]
            shutil.rmtree(os.path.join(target, folder))
            print('no %s page: %s' % (folder, 'the site has no bare player' if not bare else
                                      'the Stack Player has no sample %r with a picture' % title))
    if text:
        with open(index, 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)
    return kept


def games(source, target, player, bare=False):
    """Copies tools/pages/games, each page told the engine's file in the
    player; bare says the site has the bare player (play/), which the pages
    of OWN_PAGES need."""
    if not os.path.isdir(source):
        return False
    engines = sorted(n for n in os.listdir(player) if re.fullmatch(r'standalone-.*\.js', n))
    if not engines:
        print('no games: the Stack Player has no engine for them')
        return False
    shutil.copytree(source, target)
    own = own_pages(target, player, bare)
    gallery(os.path.join(target, 'index.html'), player, own)
    template = os.path.join(target, 'stack-page.html')
    if os.path.isfile(template):
        sample_pages(template, target, player, own)
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


# The welcome section's own tools, which stay in the repository: how its
# pages and pictures are made (src/), its tests and its README
WELCOME_LEFT_OUT = ('src', 'tests', 'README.md')


def welcome(source, target):
    """Copies the welcome section (tools/pages/welcome) beside the front
    page, without WELCOME_LEFT_OUT. Its pages name the logo files of the
    site's brand/ (../brand/), which brand() writes."""
    if not os.path.isfile(os.path.join(source, 'index.html')):
        raise BuildError('tools/pages/welcome has no index.html')
    shutil.copytree(source, target, ignore=lambda d, names:
                    [n for n in names if d == source and n in WELCOME_LEFT_OUT])
    return sorted(n for n in os.listdir(target) if n.endswith('.html'))


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
    # The lessons go up with every site: they are written here, in
    # tools/pages/lessons, not taken from a release
    try:
        count, shown = build_lessons.build(os.path.join(out, 'lessons'),
                                           [p for p in build_lessons.PARTS if p in parts])
    except build_lessons.BuildError as e:
        raise BuildError('the lessons: %s' % e)
    parts['LESSONS'] = '%d lessons · %d examples' % (count, shown)
    if args.player:
        unpack(args.player, os.path.join(out, 'player'))
        parts['PLAYER'] = args.player_version or ''
        bare = bare_player(out)
        if bare:
            print('bare player: play/')
            forum_player(out)
            print('forum stacks: try/')
        # The games run on the Stack Player's engine, so they go up with it
        if games(os.path.join(HERE, 'games'), os.path.join(out, 'games'), os.path.join(out, 'player'), bare):
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
    def listed_release(option):
        tag, listing = getattr(args, option, None), getattr(args, option + '_assets', None)
        if not tag:
            return None
        if not listing:
            raise BuildError('--%s needs --%s-assets' % (option, option))
        with open(listing, encoding='utf-8') as f:
            return tag, {line.strip() for line in f if line.strip()}

    stable, preview = listed_release('release'), listed_release('preview')
    blocks = downloads_channels(stable, preview)
    if blocks:
        parts['DOWNLOADS'] = ' and '.join(tag for tag, _ in blocks)
        parts['DOWNLOADS_LIST'] = '\n'.join(block for _, block in blocks)
    # the extensions page's plugins are the stable release's, or the
    # preview's while there is no stable release
    release, assets = stable or preview or (None, ())
    # Which xTalk Suite extensions those releases have built in, for the
    # line on each extension's card: each release's own
    # tools/oxt/xtalk-extensions.json (pages.yml takes it from the
    # release's tag), the stable release first
    built_in = []
    for given, option in ((stable, 'release'), (preview, 'preview')):
        path = getattr(args, option + '_built_in', None)
        if not path:
            continue
        if not given:
            raise BuildError('--%s-built-in needs --%s' % (option, option))
        members = built_in_members(path)
        if members is not None:
            built_in.append((given[0][1:], members))
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
    # the release's packages themselves, for the card of a member the
    # page's table does not name
    facts = {}
    folder = getattr(args, 'suite_packages', None)
    if folder:
        if not suite:
            raise BuildError('--suite-packages needs --suite-release')
        facts = suite_package_facts(folder, [file for _, file in suite_packages(listed).values()])
        print('extension packages read: %d' % len(facts))
    shown = extensions_page(os.path.join(HERE, 'extensions'), os.path.join(out, 'extensions'), suite, listed,
                            release if release else None, assets if release else (), facts, built_in)
    if suite and not shown:
        print('no extension packages: %s has no .lce files' % suite)
    parts['EXTENSIONS'] = 'xTalk Suite %s' % shown if shown else 'xTalk Suite'
    # The welcome section goes up with every site: it is written here, in
    # tools/pages/welcome, and asks nothing of a release
    print('welcome: %s' % ', '.join(welcome(os.path.join(HERE, 'welcome'), os.path.join(out, 'welcome'))))
    front_page(out, parts)
    brand(os.path.join(HERE, 'brand'), os.path.join(out, 'brand'))
    # The OpenXTalk family bar, the same strip of links on this site, the
    # xTalk Suite's extensions page and the community stacks gallery, on
    # every page here that is read rather than played (tools/pages/family.py)
    print('family bar: %d pages' % len(family.finish(out)))
    # Last, over everything written: each page's one address and the
    # sitemap (tools/pages/seo.py), for search engines
    print('sitemap: %d pages' % len(seo.finish(out)))
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
    ap.add_argument('--preview', metavar='TAG',
                    help='the preview of the next version, which the Downloads section links after the release')
    ap.add_argument('--preview-assets', metavar='FILE', help="that preview's file names, one a line")
    ap.add_argument('--suite-release', metavar='TAG',
                    help="the xTalk Suite release whose .lce packages the extensions page links")
    ap.add_argument('--suite-assets', metavar='FILE', help="that release's file names, one a line")
    ap.add_argument('--suite-packages', metavar='FOLDER',
                    help="that release's .lce files and SHA256SUMS, downloaded: the card of an extension the "
                         "page's table does not name is made from them")
    ap.add_argument('--release-built-in', metavar='JSON',
                    help="the --release's tools/oxt/xtalk-extensions.json: the extensions it has built in")
    ap.add_argument('--preview-built-in', metavar='JSON',
                    help="the --preview's tools/oxt/xtalk-extensions.json: the extensions it has built in")
    args = ap.parse_args()
    try:
        build(args)
    except (BuildError, zipfile.BadZipFile, OSError) as e:
        print('build_pages.py: %s' % e, file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
