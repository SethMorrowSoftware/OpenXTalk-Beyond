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

"""Make the web IDE's site: the IDE of an installed OXT-Beyond, run in a web
page by the web IDE's engine.

  python3 tools/web-ide/build_site.py --install DIR --engine DIR --out DIR
      [--repo DIR] [--source-url URL] [--zip FILE]

--install is an installed (or extracted) Linux OXT-Beyond: its Toolset,
Plugins, Extensions, Resources and documentation go into the site.
--engine is the folder with the web IDE's engine,
development-community-<version>.js and .wasm (build-emscripten's
out/Release, which tools/ci/build-web-ide.sh builds). --out is the site's
folder, which must be new or empty.

The site is static files that any web server can serve (a browser loads
no WebAssembly from a file: address):

  index.html                              the page (tools/web-ide/index.html)
  development-community-<version>.js      the engine
  development-community-<version>.wasm
  ide.zip                                 the IDE, which the engine unpacks
                                          into /boot when the page opens

The engine (engine/src/mode_development.cpp) loads the IDE's home stack
from /boot/Toolset/home.livecodescript. /boot is the web engine's own
folder (specialFolderPath("engine")), so the IDE finds its folders beside
it as an installed Linux IDE does beside its engine. The zip also has the
fonts every web standalone has (engine/rsrc/emscripten-standalone-template),
in /boot/standalone.

Left out of the zip, because a browser cannot use them or the web IDE
does not offer them: the engines and runtimes, the externals (the web
engine has its own linked in), the native libraries of extensions (code/
folders), the user guides except the dictionary and the PDF guides, the
Resource Center, the tutorials, the 23 MB "All Guides" stack, the
Source Code Pro font files (the web engine cannot load them) and an
unused archive of the Linux theme.

--repo DIR copies a source checkout's script-only IDE stacks
(ide/**/*.livecodescript, the xTalk Academy's course files, and
ide-support's scripts into Toolset/libraries) over
the installed ones, to try IDE script changes without packaging them, and
puts the examples of Learn's gallery that are not in the install yet
where packaging does: the remastered examples (ide/Resources/Examples/
Remastered, which tools/examples builds) and the Stack Player's stacks
(tools/web-player/stacks, in Resources/Examples/Showcase); and the
checkout's CHANGELOG.md, HISTORY.md and README.md, which the Release Notes
window shows, in Toolset/palettes/updates/notes.

--source-url is the address of the source the site was built from, for
the page's "Source" link (GPL); by default the repository's.

--zip FILE also writes the site as a zip to download and run (the
release's OXT-Beyond-<version>-web-ide.zip): one folder, named after
the zip, with the site's files and three more that only the zip has:

  serve.py                                a web server for this computer
                                          (tools/web-ide/serve.py)
  Start Web IDE.bat                       starts serve.py on Windows
  README.txt                              how to run it, and how to put
                                          it on a web server

The site's folder (--out) is left as it is, without them.

Needs Python 3.8 or later, standard library only.
"""

import argparse
import glob
import hashlib
import os
import re
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TEMPLATE = os.path.join(REPO, 'engine', 'rsrc', 'emscripten-standalone-template')
PAGE = os.path.join(HERE, 'index.html')
DEFAULT_SOURCE = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'

# The folders of the IDE that go into the zip, from the installed layout
FOLDERS = ('Toolset', 'Plugins', 'Extensions', 'Resources',
           # The Dictionary (Help > Dictionary and the toolbar's button):
           # the page's template, styles, scripts and fonts, its SQLite
           # database and entries, and the dictionary stack that shows
           # them when the preferences ask for it
           'Documentation/html_viewer',
           # Help > User Guide PDF and Data Grid Guide PDF
           'Documentation/PDF')
# Files of the layout's top folder: the IDE reads its version from them,
# and the licences go with the code
FILES = ('.version', '.buildnumber', '.codename', 'about.dat', 'edition.txt',
         'LICENSE', 'LICENSE-EXCEPTION.md', 'License Agreement.txt',
         'Open Source Licenses.txt', 'THIRD-PARTY-NOTICES.md')
# Left out (paths relative to the layout, and their contents)
LEAVE_OUT = (
    # Help > Guides, 23 MB (revWebIDEMenu leaves the item out)
    'Toolset/palettes/userguides/allguides.oxtstack',
    # The Resource Center and the tutorials, which the menu bar hides (the
    # tutorials are not installed since 0.2.7-rc.6.12: an older layout's)
    'Toolset/palettes/revresourcecenter.rev',
    'Toolset/palettes/tutorial',
    # A copy, carried from OpenXTalk Lite 1.15, of the Linux theme's folder
    # beside it, which nothing reads (bwmilby, openxtalk.org p=25582)
    'Toolset/resources/supporting_files/themes/com.livecode.theme.linux.tar.xz',
)
# The Stack Player's stacks that Learn's gallery leaves out (the player's
# own course and its tour, which are Home's Academy and Home's tour):
# the same as tools/oxt/package.py SHOWCASE_LEFT_OUT, which a test holds
SHOWCASE_LEFT_OUT = ('Learn xTalk.oxtstack', 'OXT-Beyond on the Web.oxtstack')
# Files left out by name pattern (paths relative to the layout): the
# Script Editor's font, Source Code Pro, whose files the web engine cannot
# load ("can't load font file", every one of them, in the web IDE of
# 0.2.7-rc.6.9), so the web IDE shows code in Droid Sans Mono, which the
# Dictionary carries (OpenXTalkPaul, p=25579; seth's decision 13,
# 2026-10-31). The IDE's other two fonts, FontAwesome and its icons
# (lcideicons), load and are used, and stay; so does the fonts' licence.
LEAVE_OUT_PATTERN = re.compile(
    r'^Toolset/resources/supporting_files/fonts/SourceCodePro-[A-Za-z]+\.ttf$')
# Files that are never wanted: native libraries, and what the desktop's
# file managers leave behind
NATIVE = re.compile(r'\.(so|dll|dylib|bundle|exe|lib|a)$', re.I)
JUNK = ('.DS_Store', 'Thumbs.db', 'desktop.ini')

# What --zip adds beside the site's files (see the module comment), and
# the ones Windows wants with CRLF line ends
ZIP_EXTRAS = ('serve.py', 'Start Web IDE.bat', 'README.txt')
CRLF = ('Start Web IDE.bat', 'README.txt')

# Text compresses well in the zip; images and media are stored as they are
STORED = re.compile(r'\.(png|jpe?g|gif|webp|mp3|mp4|m4a|ogg|webm|zip|gz|xz|woff2?)$', re.I)


class BuildError(Exception):
    pass


def log(text):
    print(text, flush=True)


def leave_out(rel):
    """True for a path (relative to the layout, with "/") the zip leaves
    out."""
    parts = rel.split('/')
    if parts[-1] in JUNK or NATIVE.search(rel):
        return True
    # An extension's native libraries
    if parts[0] == 'Extensions' and 'code' in parts[1:-1]:
        return True
    if LEAVE_OUT_PATTERN.match(rel):
        return True
    return any(rel == x or rel.startswith(x + '/') for x in LEAVE_OUT)


def ide_files(install, repo):
    """{path in /boot: source file} for the IDE."""
    files = {}
    for name in FILES:
        path = os.path.join(install, name)
        if os.path.isfile(path):
            files[name] = path
    for top in FOLDERS:
        base = os.path.join(install, *top.split('/'))
        if not os.path.isdir(base):
            if top in ('Toolset', 'Extensions'):
                raise BuildError('%s has no %s folder: is it an installed OXT-Beyond?' % (install, top))
            log('  (no %s in %s)' % (top, install))
            continue
        for root, dirs, names in os.walk(base):
            dirs.sort()
            for name in sorted(names):
                path = os.path.join(root, name)
                rel = os.path.relpath(path, install).replace(os.sep, '/')
                if not leave_out(rel) and os.path.isfile(path):
                    files[rel] = path
    if repo:
        files.update(repo_scripts(repo, install))
    if 'Toolset/home.livecodescript' not in files:
        raise BuildError('%s has no Toolset/home.livecodescript' % install)
    return files


def repo_scripts(repo, install):
    """The script-only IDE stacks of a source checkout, where an installed
    layout has them (tools/oxt/layout.py: ide/ is the layout's top folder,
    and ide-support's scripts are in Toolset/libraries)."""
    scripts = {}
    ide = os.path.join(repo, 'ide')
    for path in glob.glob(os.path.join(ide, '**', '*.livecodescript'), recursive=True):
        rel = os.path.relpath(path, ide).replace(os.sep, '/')
        # Only where the installed IDE has its scripts
        if rel.split('/')[0] in ('Toolset', 'Plugins') and not leave_out(rel):
            scripts[rel] = path
    for path in glob.glob(os.path.join(repo, 'ide-support', '*.livecodescript')):
        scripts['Toolset/libraries/' + os.path.basename(path)] = path
    # The script libraries of extensions/script-libraries, which packaging
    # puts in Extensions/com.livecode.library.<name>
    for path in glob.glob(os.path.join(repo, 'extensions', 'script-libraries', '*', '*.livecodescript')):
        name = os.path.basename(os.path.dirname(path))
        rel = 'Extensions/com.livecode.library.%s/%s' % (name, os.path.basename(path))
        if os.path.isfile(os.path.join(install, *rel.split('/'))):
            scripts[rel] = path
    # The xTalk Academy's courses, text files beside its stack
    for path in glob.glob(os.path.join(ide, 'Toolset', 'palettes', 'academy', 'courses', '*.txt')):
        scripts['Toolset/palettes/academy/courses/' + os.path.basename(path)] = path
    log('  %d script-only stacks from %s' % (len(scripts), repo))
    # The remastered examples, for Learn's examples gallery
    remastered = os.path.join(ide, 'Resources', 'Examples', 'Remastered')
    stacks = sorted(glob.glob(os.path.join(remastered, '*.oxtstack')))
    for path in stacks:
        scripts['Resources/Examples/Remastered/' + os.path.basename(path)] = path
    if stacks:
        log('  %d remastered examples from %s' % (len(stacks), remastered))
    # The Stack Player's stacks, for Learn's examples gallery, where
    # tools/oxt/package.py installs them (SHOWCASE)
    showcase = os.path.join(repo, 'tools', 'web-player', 'stacks')
    stacks = sorted(path for path in glob.glob(os.path.join(showcase, '*.oxtstack'))
                    if os.path.basename(path) not in SHOWCASE_LEFT_OUT)
    for path in stacks:
        scripts['Resources/Examples/Showcase/' + os.path.basename(path)] = path
    if stacks:
        log('  %d Stack Player stacks from %s' % (len(stacks), showcase))
    # The changelog, history and README the Release Notes window shows,
    # where tools/oxt/package.py installs them (RELEASE_NOTES), so that
    # they match the checkout's scripts
    for name in ('CHANGELOG.md', 'HISTORY.md', 'README.md'):
        path = os.path.join(repo, name)
        if os.path.isfile(path):
            scripts['Toolset/palettes/updates/notes/' + name] = path
    return scripts


def write_zip(path, files):
    """The zip that the engine unpacks at "/": the IDE in boot/, and the
    web standalone's fonts (boot/standalone)."""
    total = 0
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for root, dirs, names in os.walk(TEMPLATE):
            dirs.sort()
            for name in sorted(names):
                if name.startswith('.'):
                    continue
                source = os.path.join(root, name)
                z.write(source, os.path.relpath(source, TEMPLATE).replace(os.sep, '/'),
                        compress_type=zipfile.ZIP_STORED)
        for rel in sorted(files):
            source = files[rel]
            total += os.path.getsize(source)
            kind = zipfile.ZIP_STORED if STORED.search(rel) else zipfile.ZIP_DEFLATED
            z.write(source, 'boot/' + rel, compress_type=kind)
    return total


def find_engine(folder):
    """(base name, version) of the web IDE's engine in folder."""
    found = sorted(glob.glob(os.path.join(folder, 'development-community-*.wasm')))
    if len(found) != 1:
        raise BuildError('%s should have one development-community-<version>.wasm, not %d'
                         % (folder, len(found)))
    base = os.path.basename(found[0])[:-len('.wasm')]
    if not os.path.isfile(os.path.join(folder, base + '.js')):
        raise BuildError('%s has %s.wasm but no %s.js' % (folder, base, base))
    return base, base[len('development-community-'):]


def site_stamp(out, names):
    """A digest of the site's files of names, short: the page asks for
    each with it, so that a cached copy of another version's is not used"""
    digest = hashlib.sha256()
    for name in names:
        with open(os.path.join(out, name), 'rb') as f:
            for block in iter(lambda: f.read(1 << 20), b''):
                digest.update(block)
    return digest.hexdigest()[:16]


def inside(path, folder):
    """True when path is folder or anywhere below it (links resolved)"""
    path, folder = os.path.realpath(path), os.path.realpath(folder)
    return os.path.commonpath([path, folder]) == folder


def write_download_zip(path, out, version, source_url):
    """The site of out and ZIP_EXTRAS in one folder, named after path, of
    a new zip at path. Returns the number of files."""
    top = os.path.basename(path)
    if top.lower().endswith('.zip'):
        top = top[:-4]
    if not top:
        raise BuildError('--zip %s: the zip needs a name' % path)
    if inside(path, out):
        raise BuildError('--zip %s is in the site\'s folder; write it somewhere else' % path)
    entries = []
    for name in sorted(os.listdir(out)):
        source = os.path.join(out, name)
        if not os.path.isfile(source):
            raise BuildError('%s is not a file: the site is files only' % source)
        if name in ZIP_EXTRAS:
            raise BuildError('the site has its own %s, which --zip would replace' % name)
        entries.append((name, source, None))
    for name in ZIP_EXTRAS:
        with open(os.path.join(HERE, name), encoding='utf-8') as f:
            text = f.read().replace('\r\n', '\n')
        text = text.replace('@VERSION@', version).replace('@SOURCE_URL@', source_url)
        if re.search(r'@[A-Z_]+@', text):
            raise BuildError('%s has a placeholder that is not filled in' % name)
        if name in CRLF:
            text = text.replace('\n', '\r\n')
        entries.append((name, None, text.encode('utf-8')))
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    with zipfile.ZipFile(path + '.tmp', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, source, data in entries:
            arcname = top + '/' + name
            if data is not None:
                info = zipfile.ZipInfo(arcname, date_time=(2026, 1, 1, 0, 0, 0))
                info.external_attr = (0o755 if name.endswith('.py') else 0o644) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(info, data)
            else:
                kind = zipfile.ZIP_STORED if STORED.search(name) else zipfile.ZIP_DEFLATED
                z.write(source, arcname, compress_type=kind)
    os.replace(path + '.tmp', path)
    return len(entries)


def ide_version(install):
    path = os.path.join(install, '.version')
    if os.path.isfile(path):
        with open(path, encoding='utf-8') as f:
            return f.read().strip()
    return ''


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--install', required=True, metavar='DIR', help='an installed Linux OXT-Beyond')
    ap.add_argument('--engine', required=True, metavar='DIR',
                    help='the folder with development-community-<version>.js and .wasm')
    ap.add_argument('--out', required=True, metavar='DIR', help='the site folder (new or empty)')
    ap.add_argument('--repo', metavar='DIR', help='a checkout whose script-only IDE stacks to use')
    ap.add_argument('--source-url', default=DEFAULT_SOURCE, metavar='URL',
                    help='the address of the source code, for the page\'s link')
    ap.add_argument('--zip', metavar='FILE',
                    help='also write the site, with serve.py and a README, as this zip')
    args = ap.parse_args(argv)

    try:
        install = os.path.abspath(args.install)
        out = os.path.abspath(args.out)
        if os.path.exists(out) and os.listdir(out):
            raise BuildError('%s exists and is not empty' % out)
        # Before anything is built: the zip never goes into the site
        if args.zip and inside(os.path.abspath(args.zip), out):
            raise BuildError('--zip %s is in the site\'s folder; write it somewhere else' % args.zip)
        os.makedirs(out, exist_ok=True)

        base, engine_version = find_engine(args.engine)
        version = ide_version(install)
        log('Web IDE %s, engine %s' % (version or '(no .version)', engine_version))

        files = ide_files(install, args.repo and os.path.abspath(args.repo))
        size = write_zip(os.path.join(out, 'ide.zip'), files)
        zipped = os.path.getsize(os.path.join(out, 'ide.zip'))
        log('  ide.zip: %d files, %.1f MB, %.1f MB zipped' % (len(files), size / 1e6, zipped / 1e6))

        for ext in ('.js', '.wasm'):
            shutil.copyfile(os.path.join(args.engine, base + ext), os.path.join(out, base + ext))
        with open(PAGE, encoding='utf-8') as f:
            page = f.read()
        stamp = site_stamp(out, (base + '.js', base + '.wasm', 'ide.zip'))
        # The sizes the page's progress bar counts to: a server that
        # compresses tells the browser the compressed size, and the page
        # counts the bytes unpacked
        wasm = os.path.getsize(os.path.join(out, base + '.wasm'))
        for key, value in (('@ENGINE@', base), ('@VERSION@', version or engine_version),
                           ('@STAMP@', stamp), ('@SOURCE_URL@', args.source_url),
                           ('@ENGINE_BYTES@', str(wasm)), ('@IDE_BYTES@', str(zipped))):
            if key not in page:
                raise BuildError('%s has no %s' % (PAGE, key))
            page = page.replace(key, value)
        with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(page)
        log('  %s.wasm: %.1f MB' % (base, wasm / 1e6))
        log('Site: %s (%.1f MB)' % (out, (zipped + wasm) / 1e6))
        if args.zip:
            count = write_download_zip(os.path.abspath(args.zip), out, version or engine_version,
                                       args.source_url)
            log('Zip: %s (%d files, %.1f MB)' % (args.zip, count, os.path.getsize(args.zip) / 1e6))
    except (BuildError, OSError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
