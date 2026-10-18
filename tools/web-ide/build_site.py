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
      [--repo DIR] [--source-url URL]

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
Resource Center, the tutorials and the 23 MB "All Guides" stack.

--repo DIR copies a source checkout's script-only IDE stacks
(ide/**/*.livecodescript, and ide-support's into Toolset/libraries) over
the installed ones, to try IDE script changes without packaging them, and
puts the examples of Learn's gallery that are not in the install yet
where packaging does: the remastered examples (ide/Resources/Examples/
Remastered, which tools/examples builds) and the Stack Player's stacks
(tools/web-player/stacks, in Resources/Examples/Showcase).

--source-url is the address of the source the site was built from, for
the page's "Source" link (GPL); by default the repository's.

Needs Python 3.8 or later, standard library only.
"""

import argparse
import glob
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
    # The Resource Center and the tutorials, which the menu bar hides
    'Toolset/palettes/revresourcecenter.rev',
    'Toolset/palettes/tutorial',
)
# Files that are never wanted: native libraries, and what the desktop's
# file managers leave behind
NATIVE = re.compile(r'\.(so|dll|dylib|bundle|exe|lib|a)$', re.I)
JUNK = ('.DS_Store', 'Thumbs.db', 'desktop.ini')

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
    stacks = sorted(glob.glob(os.path.join(showcase, '*.oxtstack')))
    for path in stacks:
        scripts['Resources/Examples/Showcase/' + os.path.basename(path)] = path
    if stacks:
        log('  %d Stack Player stacks from %s' % (len(stacks), showcase))
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
    args = ap.parse_args(argv)

    try:
        install = os.path.abspath(args.install)
        out = os.path.abspath(args.out)
        if os.path.exists(out) and os.listdir(out):
            raise BuildError('%s exists and is not empty' % out)
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
        for key, value in (('@ENGINE@', base), ('@VERSION@', version or engine_version),
                           ('@SOURCE_URL@', args.source_url)):
            if key not in page:
                raise BuildError('%s has no %s' % (PAGE, key))
            page = page.replace(key, value)
        with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(page)
        wasm = os.path.getsize(os.path.join(out, base + '.wasm'))
        log('  %s.wasm: %.1f MB' % (base, wasm / 1e6))
        log('Site: %s (%.1f MB)' % (out, (zipped + wasm) / 1e6))
    except (BuildError, OSError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
