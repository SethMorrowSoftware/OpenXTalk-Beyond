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

"""Make the Dictionary that the IDE's Help > Dictionary Online opens
(seth's choice 12A of 2026-10-31): OXT-Beyond's own dictionary, as one
folder of static files for the GitHub Pages site, instead of a copy of
LiveCode's that called itself the LiveCode Dictionary (richmond62).

  python3 tools/pages/build_dictionary.py --out DIR
      (--viewer DIR | --ide-site DIR) [--version V]

It is the page the IDE once made for its browser Dictionary
(revIDEGenerateDictionaryHTML and revIDERegenerateBuiltAPIs in
ide/Toolset/libraries/revidelibrary.8.livecodescript), from the same
files: the viewer's api.html.template, its css/, js/ and fonts/, and the
dictionary data that tools/ci/build_docs.sh writes (resources/data/
api_livecode_script/*.js and api_livecode_builder/*.js), joined into one
built_api.js as the IDE joined them, with the APIs named as the IDE's
Dictionary names them (xTalk Script, xTalk Builder).

--viewer is a folder like ide/Documentation/html_viewer with its data;
--ide-site is the web IDE's site (OXT-Beyond-<version>-web-ide.zip's
folder), whose ide.zip carries the IDE's html_viewer under
boot/Documentation (tools/pages/build_pages.py gives it the site's web
IDE, so the Dictionary is the released IDE's). It writes:

  DIR/index.html     the page, titled "OXT-Beyond Dictionary"
  DIR/built_api.js   the data (var dictionary_data = {"docs": [...]})
  DIR/css/, js/, fonts/, resources/media/

Exit status 0 when it is written, 1 when it cannot be (no viewer, a
template hole left, data that is not JSON, an API with no entries), 3
with --ide-site when the web IDE has no html_viewer (an older one), so
that a site can go up without the Dictionary rather than not at all.
Only the Python 3 standard library is used.
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile

# The APIs, as the IDE's Dictionary names them (kAPIs in
# revidelibrary.8.livecodescript; the IDE's own, livecode_ide, is left out
# of an installed IDE, as it is there)
APIS = (('xTalk Script', 'livecode_script'), ('xTalk Builder', 'livecode_builder'))

TITLE = 'OXT-Beyond Dictionary'

# The template's holes (merge() in revIDEGenerateDictionaryHTML) and what
# the static page has for each: no library or entry to open first
HOLES = {
    '[[tDocsCSSFolder]]': 'css',
    '[[tDocsJSFolder]]': 'js',
    '[[tDataPath]]': 'built_api.js',
    '[[ the editionType]]': 'community',
    '[[tLibraryName]]': '',
    '[[tEntryName]]': '',
    '[[tEntryType]]': '',
}

# What the page loads besides its data
COPIED = ('css', 'js', 'fonts', os.path.join('resources', 'media'))

IDE_ZIP_PREFIX = 'boot/Documentation/html_viewer/'

# The extensions' data beside LiveCode's (text_dictionary.EXPORT_FOLDER)
EXTENSIONS_FOLDER = 'api_extensions'


class DictionaryError(Exception):
    pass


class NoViewer(DictionaryError):
    pass


def page_text(template):
    """The page from the text of api.html.template."""
    if '<title>Dictionary</title>' not in template:
        raise DictionaryError('api.html.template has no <title>Dictionary</title>')
    text = template.replace('<title>Dictionary</title>', '<title>%s</title>' % TITLE, 1)
    for hole, value in HOLES.items():
        if hole not in text and hole not in ('[[tLibraryName]]', '[[tEntryName]]', '[[tEntryType]]'):
            raise DictionaryError('api.html.template has no %s' % hole)
        text = text.replace(hole, value)
    left = re.findall(r'\[\[[^\]]*\]\]', text)
    if left:
        raise DictionaryError('api.html.template has holes this page does not fill: %s'
                              % ', '.join(sorted(set(left))))
    return text


def _js_texts(folder):
    """The texts of the folder's .js files, in name order, those with
    nothing in them left out."""
    texts = []
    for file in sorted(os.listdir(folder)):
        if file.endswith('.js'):
            with open(os.path.join(folder, file), encoding='utf-8') as f:
                text = f.read().strip()
            if text.startswith('\ufeff'):
                text = text[1:].strip()
            if text.endswith(','):
                text = text[:-1].rstrip()
            if text:
                texts.append(text)
    return texts


def api_entries(viewer, name):
    """The text of an API's entries: its .js files in resources/data/
    api_<name>/, in name order, joined with commas, as
    revIDEGetBaseDocsData joins them; then, as revIDEGetDocsAPIData adds
    the docs of the extensions the IDE loads (revIDEGetExtensionDocsData),
    the extensions' files in resources/data/api_extensions/<name>/, which
    tools/ci/build_docs.sh puts there (text_dictionary.py
    --export-extensions), so that the page has every entry the IDE's
    dictionaries have, the xTalk Suite's among them. An IDE made before
    that folder has none, and its page has LiveCode's entries alone, as
    before."""
    folder = os.path.join(viewer, 'resources', 'data', 'api_' + name)
    if not os.path.isdir(folder):
        raise DictionaryError('%s is not there: make the docs first (tools/ci/build_docs.sh)' % folder)
    texts = _js_texts(folder)
    if not texts:
        raise DictionaryError('%s has no entries' % folder)
    extensions = os.path.join(viewer, 'resources', 'data', EXTENSIONS_FOLDER, name)
    if os.path.isdir(extensions):
        texts += _js_texts(extensions)
    return ','.join(texts)


def data_text(viewer):
    """built_api.js, as revIDERegenerateBuiltAPIs writes it (each API as
    revDocsCreateAPIJSON writes it). Returns (text, {api name: entries})."""
    apis = []
    for title, name in APIS:
        apis.append('{\n\t\t%s:%s,\n\t\t%s:%s,\n\t\t"doc":[%s]\n\t}' % (
            json.dumps('display name'), json.dumps(title), json.dumps('name'), json.dumps(name),
            api_entries(viewer, name)))
    text = 'var dictionary_data =\n{\n\t"docs":[' + ','.join(apis) + '\n\t]\n}\n'
    counts = check_data(text)
    return text, counts


def check_data(text):
    """That built_api.js is the data the page reads: JSON after its
    "var dictionary_data =", with entries in every API. Returns
    {api name: entries}."""
    prefix = 'var dictionary_data ='
    if not text.startswith(prefix):
        raise DictionaryError('built_api.js does not start with %r' % prefix)
    try:
        data = json.loads(text[len(prefix):])
    except ValueError as e:
        raise DictionaryError('built_api.js is not JSON: %s' % e)
    counts = {}
    for api in data.get('docs', []):
        entries = [e for e in api.get('doc', []) if isinstance(e, dict) and e.get('name')]
        counts[api.get('display name')] = len(entries)
    for title, _ in APIS:
        if not counts.get(title):
            raise DictionaryError('built_api.js has no entries for %s' % title)
    return counts


def linked_css(page):
    """The style sheets the page links, relative to it."""
    return re.findall(r'<link href="(css/[^"]+\.css)" rel="stylesheet">', page)


def without_missing_images(css, css_path, root):
    """The style sheet's text without the declarations content: url(X) whose
    X is not in root (the Dictionary's folder): lcdoc.css draws an
    edition's badge before an entry from LiveCode's commercial IDE skins,
    ../../../Toolset/resources/<edition>/ideSkin/bubble.png, which no
    OXT-Beyond IDE has, so the badge's other rule (a glyph) stands, as it
    does where the image is missing in the IDE. Returns (text, the names
    taken out); DictionaryError for any other url() that is not there."""
    taken = []

    def missing(target):
        if target.startswith('data:') or '://' in target:
            return False
        path = os.path.normpath(os.path.join(os.path.dirname(css_path), target.split('#')[0].split('?')[0]))
        inside = os.path.commonpath([os.path.abspath(path), os.path.abspath(root)]) == os.path.abspath(root)
        return not inside or not os.path.exists(path)

    def drop(m):
        if missing(m.group(2)):
            taken.append(m.group(2))
            return ''
        return m.group(0)
    text = re.sub(r'content:\s*url\(([\'"]?)([^\'")]+)\1\)\s*;', drop, css)
    for m in re.finditer(r'url\(([\'"]?)([^\'")]+)\1\)', text):
        if missing(m.group(2)):
            raise DictionaryError('%s refers to %s, which the Dictionary does not have'
                                  % (os.path.relpath(css_path, root), m.group(2)))
    return text, taken


def build(viewer, out, version=None):
    """Writes the Dictionary from the viewer folder into out (new or
    empty). Returns {api name: entries}."""
    template = os.path.join(viewer, 'api.html.template')
    if not os.path.isfile(template):
        raise NoViewer('%s has no api.html.template' % viewer)
    with open(template, encoding='utf-8') as f:
        page = page_text(f.read())
    if version:
        page = page.replace('<title>%s</title>' % TITLE, '<title>%s %s</title>' % (TITLE, version), 1)
    data, counts = data_text(viewer)
    if os.path.exists(out) and os.listdir(out):
        raise DictionaryError('%s is not empty' % out)
    os.makedirs(out, exist_ok=True)
    for part in COPIED:
        src = os.path.join(viewer, part)
        if not os.path.isdir(src):
            raise DictionaryError('%s is not there' % src)
        shutil.copytree(src, os.path.join(out, part))
    for ref in re.findall(r'(?:src|href)="((?:css|js)/[^"]+)"', page):
        if not os.path.isfile(os.path.join(out, *ref.split('/'))):
            raise DictionaryError('the page loads %s, which the viewer does not have' % ref)
    for sheet in linked_css(page):
        path = os.path.join(out, *sheet.split('/'))
        if not os.path.isfile(path):
            raise DictionaryError('the page links %s, which the viewer does not have' % sheet)
        with open(path, encoding='utf-8') as f:
            css, taken = without_missing_images(f.read(), path, out)
        if taken:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(css)
    with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    with open(os.path.join(out, 'built_api.js'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(data)
    return counts


def viewer_from_ide_site(site, work):
    """Extracts the html_viewer of the web IDE site's ide.zip into work and
    returns its folder; NoViewer if the IDE has none."""
    ide_zip = os.path.join(site, 'ide.zip')
    if not os.path.isfile(ide_zip):
        raise NoViewer('%s has no ide.zip' % site)
    with zipfile.ZipFile(ide_zip) as z:
        names = [n for n in z.namelist() if n.startswith(IDE_ZIP_PREFIX) and not n.endswith('/')]
        if IDE_ZIP_PREFIX + 'api.html.template' not in names:
            raise NoViewer('the web IDE\'s ide.zip has no %sapi.html.template' % IDE_ZIP_PREFIX)
        for name in names:
            rel = name[len(IDE_ZIP_PREFIX):]
            if rel.startswith('/') or '..' in rel.split('/'):
                raise DictionaryError('ide.zip: unsafe name %r' % name)
            # the data the page needs, not the IDE's database and stacks
            if rel.startswith('resources/data/') and not (
                    rel.startswith('resources/data/api_livecode_') or
                    rel.startswith('resources/data/%s/' % EXTENSIONS_FOLDER)):
                continue
            target = os.path.join(work, *rel.split('/'))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(name) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
    return work


def build_from_ide_site(site, out, version=None):
    with tempfile.TemporaryDirectory() as work:
        return build(viewer_from_ide_site(site, work), out, version)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--out', required=True, help='the Dictionary\'s folder (new or empty)')
    source = ap.add_mutually_exclusive_group(required=True)
    source.add_argument('--viewer', metavar='DIR', help='a folder like ide/Documentation/html_viewer, with its data')
    source.add_argument('--ide-site', metavar='DIR', help='the web IDE\'s site, with ide.zip')
    ap.add_argument('--version', metavar='V', help='in the page\'s title')
    args = ap.parse_args(argv)
    try:
        if args.viewer:
            counts = build(os.path.abspath(args.viewer), os.path.abspath(args.out), args.version)
        else:
            counts = build_from_ide_site(os.path.abspath(args.ide_site), os.path.abspath(args.out), args.version)
    except NoViewer as e:
        print('build_dictionary.py: %s' % e, file=sys.stderr)
        return 3
    except (DictionaryError, zipfile.BadZipFile, OSError) as e:
        print('build_dictionary.py: %s' % e, file=sys.stderr)
        return 1
    for title, _ in APIS:
        print('%s: %d entries' % (title, counts[title]))
    print('Dictionary: %s' % os.path.abspath(args.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
