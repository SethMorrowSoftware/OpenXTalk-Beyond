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

"""Write the entries of Tom Perry's text dictionary from the dictionary data
that LiveCode's docs builder makes.

  python3 tools/oxt/text_dictionary.py [--data DIR] [--out DIR]
                                       [--extensions DIR]
  python3 tools/oxt/text_dictionary.py --list-extensions DIR

The text dictionary (Documentation/html_viewer/resources/data/api/
oxt_dictionary.oxtstack, "OpenXTalk Lite Dictionary"; Preferences > Dictionary
chooses it instead of LiveCode's Dictionary) shows one plain-text file per
entry. It lists the files of exports/<section>/resaved and plugins, where
<section> is xtalk (LiveCode Script), builder (LiveCode Builder) or datagrid
(the Data Grid). This writes those folders from the JSON data of the docs
builder in --data (default ide/Documentation/html_viewer/resources/data):

  xtalk     api_livecode_script/*.js except dg.js
  datagrid  api_livecode_script/dg.js
  builder   api_livecode_builder/*.js

and, with --extensions, from the JSON files in that folder of what
extensions.txt lists there (<id>.js, one library each in the same format):
a "module" goes into builder and the others into xtalk, as LiveCode's
Dictionary shows them. --list-extensions writes that extensions.txt: one line
for each extension OXT-Beyond installs that can have docs, and one for the
IDE library, with its id, kind, source file, title and author separated by
tabs; tools/ci/extension_docs.livecodescript then writes the JSON files. For
each section it replaces every file of resaved/ and writes index.txt (the
entry files, one per line; the dictionary no longer reads it) and
substitutions.txt. The plugins folders hold entries written by hand and are
left alone.

An entry file is named "<name> <type>.txt". A name that is not a file name on
every system becomes a word of substitutions.txt (tab separated: the name, the
word), which the dictionary turns back into the name in its list: "&&" is
DOUBLEAND, "<=" ANGLELEFTBRACKETEQUALS and so on. "/" becomes "slash", "$"
"DOLLAR" (the dictionary shows "DOLLAR_" as "$_") and ":" "_", as in the
entries of OpenXTalk Lite 1.15. Two entries with the same file name (letter
case aside) are told apart by the next word of their syntax ("popup widget"),
else by the end of the id of what they belong to ("backColor (headerbar)",
"enabled (android.button)"), else a number.

The text of an entry, in the layout the dictionary reads (OpenXTalk Lite
1.15's entries; it finds each part by its heading line):

  <name>
  (<type>)
  <summary, one line>
                            (empty line)
  Syntax:
  <each syntax, its parameters in braces>
  ----
                            (an empty line, when there was a syntax)
  Synonyms:
  <the synonyms, comma separated, when there are any>
                            (empty line)
  Params:
  <bullet, tab><name> (<type> ): <its description, one line>
                            (empty line)
  Examples:
  <each example>
  ----
                            (an empty line, when there was an example)
  Description:
  <paragraphs, separated by empty lines>
                            (empty line)
  Values:
  <what the entry returns or holds, one line>
                            (empty line)
  OS:
  <the systems, comma separated>

A link of the data (<target>, or <target|text shown>) is written as target, or
target|text shown, which the dictionary shows as a link. The description is
Markdown: a paragraph becomes one line, an item of a list one line each, the
lines of code (indented) stay as they are, and a note (">") loses its ">".
The files are UTF-8 with LF line ends, without a line end after the last line.

Only the Python 3 standard library is used.
"""

import argparse
import ast
import collections
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DEFAULT_DATA = os.path.join(REPO, 'ide', 'Documentation', 'html_viewer', 'resources', 'data')

SECTIONS = ('xtalk', 'builder', 'datagrid')

# Names that are whole words of substitutions.txt, in the order the
# dictionary turns them back: a word that ends with another comes first
# (ANGLELEFTBRACKETEQUALS before EQUALS). The first thirteen are those of
# OpenXTalk Lite 1.15; the last three name what it had no entry file for.
SUBSTITUTIONS = (
    ('&', 'SINGLEAND'),
    ('&&', 'DOUBLEAND'),
    ('()', 'BRACKETS'),
    ('--', 'DOUBLEDASH'),
    ('-', 'SINGLEDASH'),
    ('<=', 'ANGLELEFTBRACKETEQUALS'),
    ('>=', 'ANGLERIGHTBRACKETEQUALS'),
    ('=', 'EQUALS'),
    ('^', 'CARET'),
    ('\\', 'BACKSLASH'),
    ('@', 'ATCHARACTER'),
    ('*', 'ASTERISK'),
    ('$', 'DOLLAR'),
    ('<>', 'LESSGREATER'),
    ('<', 'LESSTHAN'),
    ('>', 'GREATERTHAN'),
)

# Characters that Windows does not allow in a file name, and what they
# become inside a longer name
NAME_CHARACTERS = (('/', 'slash'), ('$', 'DOLLAR'), (':', '_'), ('\\', '_'), ('*', '_'),
                   ('?', '_'), ('"', '_'), ('<', '_'), ('>', '_'), ('|', '_'))

LINK = re.compile(r'<([^<>|]*)\|([^<>]*)>|<([^<>]*)>')
PARAMETER = re.compile(r'<([^<>]*)>')
BULLET = re.compile(r'^\s*(?:[-*+]|\d+[.)])\s+')
ENTITIES = (('&lt;', '<'), ('&gt;', '>'), ('&quot;', '"'), ('&#39;', "'"), ('&amp;', '&'))


class TextDictionaryError(Exception):
    pass


def load_json(path):
    """The entries of a JSON file of the docs builder: the entries of one
    library, separated by commas, without the brackets of an array."""
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read().strip()
    if text.startswith('\ufeff'):
        text = text[1:]
    if text.endswith(','):
        text = text[:-1]
    if not text:
        return []
    try:
        entries = json.loads('[' + text + ']')
    except ValueError as err:
        raise TextDictionaryError('%s: %s' % (path, err))
    for e in entries:
        if not isinstance(e, dict) or not e.get('name'):
            raise TextDictionaryError('%s: an entry without a name' % path)
    # an entry without a type (com.livecode.language, which documents
    # nothing) has no entry file
    return [e for e in entries if e.get('type')]


def decode(text):
    for entity, char in ENTITIES:
        text = text.replace(entity, char)
    return text


def links(text):
    """<target> as target and <target|shown> as target|shown."""
    def link(m):
        if m.group(3) is not None:
            return m.group(3)
        return m.group(1) + '|' + m.group(2)
    return LINK.sub(link, text)


def lines_of(text):
    return (text or '').replace('\r\n', '\n').replace('\r', '\n').split('\n')


def one_line(text):
    """Text as one line: its lines (a note's ">" removed) joined with a
    space, its links as the dictionary writes them."""
    parts = []
    for line in lines_of(text):
        if line.startswith('>'):
            line = line[1:]
        if line.strip():
            parts.append(line.strip())
    return decode(links(' '.join(parts)))


def _blocks(text):
    block = []
    for line in lines_of(text):
        if line.strip():
            block.append(line.rstrip())
        elif block:
            yield block
            block = []
    if block:
        yield block


def _is_code(line):
    return line.startswith('\t') or line.startswith('    ')


def paragraphs(text):
    """The lines of a description, its paragraphs separated by an empty
    line: a paragraph as one line, a list as one line for each item, a
    table as one line for each row, code as it is."""
    out = []
    for block in _blocks(text):
        if out:
            out.append('')
        if all(_is_code(line) for line in block):
            out.extend(decode(line) for line in block)
            continue
        current, row = None, False
        for line in block:
            if line.startswith('>'):
                line = line[1:]
            if current is None or row or BULLET.match(line) or line.lstrip().startswith('|'):
                if current is not None:
                    out.append(current)
                current = line.strip() if not BULLET.match(line) else line.lstrip()
                row = current.startswith('|')
            else:
                current += ' ' + line.strip()
        out.append(current)
    return [decode(links(line)).rstrip() if not _is_code(line) else line for line in out]


def _table_row(line):
    # a Markdown table row: its bars would read as links
    if line.lstrip().startswith('|'):
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if all(set(c) <= set('-: ') for c in cells):
            return None
        return ' - '.join(cells)
    return line


def entry_text(e):
    out = [decode(e.get('display name') or e['name']), '(%s)' % e['type']]
    if e.get('summary'):
        out.append(one_line(e['summary']))
    out += ['', 'Syntax:']
    syntax = [s for s in e.get('syntax') or [] if isinstance(s, str) and s.strip()]
    for s in syntax:
        out += [decode(PARAMETER.sub(r'{\1}', s.strip('\n'))), '----']
    if syntax:
        out.append('')
    out.append('Synonyms:')
    if e.get('synonyms'):
        out.append(', '.join(decode(s) for s in e['synonyms']))
    out += ['', 'Params:']
    for p in e.get('parameters') or []:
        out.append('•\t%s (%s ): %s' % (p.get('name') or '', p.get('type') or '',
                                             one_line(p.get('description'))))
    out += ['', 'Examples:']
    examples = [x.get('script') or '' for x in e.get('examples') or []]
    examples = [x.strip('\n') for x in examples if x.strip()]
    for x in examples:
        out += [decode(line.rstrip()) for line in lines_of(x)] + ['----']
    if examples:
        out.append('')
    out.append('Description:')
    for line in paragraphs(e.get('description')):
        row = _table_row(line)
        if row is not None:
            out.append(row)
    out += ['', 'Values:']
    values = [one_line(v.get('description')) for v in e.get('value') or []]
    values = ' '.join(v for v in values if v)
    if values:
        out.append(values)
    out += ['', 'OS:']
    if e.get('OS'):
        out.append(','.join(e['OS']))
    return '\n'.join(out)


def file_stem(name):
    """The name as the first part of an entry file's name."""
    name = decode(name)
    for chars, word in SUBSTITUTIONS:
        if name == chars:
            return word
    for chars, replacement in NAME_CHARACTERS:
        name = name.replace(chars, replacement)
    return name.strip() or '_'


def _syntax_word(e):
    """The word after the name in the entry's first syntax ("widget" of
    "popup widget <kind>"), or None."""
    syntax = e.get('syntax') or []
    words = syntax[0].split() if syntax and isinstance(syntax[0], str) else []
    name = decode(e.get('display name') or e['name'])
    if len(words) > 1 and words[0].lower() == name.lower() and re.match(r'^[A-Za-z][A-Za-z0-9]*$', words[1]):
        return words[1]
    return None


def _associations(e):
    """The ids of what the entry belongs to, each as its parts (com,
    livecode, widget, headerbar)."""
    return [[part for part in a.strip().split('.') if part]
            for a in e.get('associations') or [] if isinstance(a, str) and a.strip()]


def _owner(e, others):
    """The fewest last parts of an id of what the entry belongs to that no
    id of what the others belong to ends with: "headerbar" of
    com.livecode.widget.headerbar, "android.button" of
    com.livecode.widget.native.android.button when one of the others
    belongs to com.livecode.widget.native.mac.button. None when there is no
    such part."""
    theirs = [ident for other in others for ident in _associations(other)]
    for parts in _associations(e):
        for n in range(1, len(parts) + 1):
            if not any(ident[-n:] == parts[-n:] for ident in theirs):
                return file_stem('.'.join(parts[-n:]))
    return None


def file_names(entries):
    """[(file name, entry)], sorted, with no two names the same, letter case
    aside. Of entries with the same name the first whose syntax has no word
    after the name keeps it (else the first); the others get that word
    ("popup widget command.txt"), what they belong to in parentheses
    ("backColor (headerbar) property.txt", "enabled (android.button)
    property.txt") or a number."""
    groups = collections.OrderedDict()
    for e in entries:
        key = '%s %s.txt' % (file_stem(e.get('display name') or e['name']), e['type'])
        groups.setdefault(key.lower(), []).append((key, e))
    taken = set(groups)
    out = []
    for members in groups.values():
        keeper = next((m for m in members if _syntax_word(m[1]) is None), members[0])
        out.append(keeper)
        for name, e in members:
            if (name, e) is keeper or e is keeper[1]:
                continue
            stem = file_stem(e.get('display name') or e['name'])
            word = _syntax_word(e)
            owner = _owner(e, [m[1] for m in members if m[1] is not e])
            candidates = []
            if word:
                candidates.append('%s %s %s.txt' % (stem, word, e['type']))
            if owner:
                candidates.append('%s (%s) %s.txt' % (stem, owner, e['type']))
            candidates += ['%s (%d) %s.txt' % (stem, n, e['type']) for n in range(2, len(entries) + 2)]
            for candidate in candidates:
                if candidate.lower() not in taken:
                    taken.add(candidate.lower())
                    out.append((candidate, e))
                    break
    return sorted(out, key=lambda m: m[0])


EXTENSION_LIST = 'extensions.txt'
DECLARATION = re.compile(r'^\s*(library|widget|module)\s+([A-Za-z][A-Za-z0-9_.-]*)\s*$', re.M)
# The title and author of an extension, as its manifest has them: the
# metadata of a .lcb file, the library docs of a .livecodescript file
LCB_METADATA = re.compile(r'^\s*metadata\s+(title|author)\s+is\s+"([^"]*)"', re.M)
LCS_METADATA = re.compile(r'^(Title|Author):[ \t]*(.*?)[ \t]*$', re.M)

# The IDE library's handlers, whose docs LiveCode's Dictionary shows only in
# an IDE run from the repository ("LiveCode IDE"), and the text dictionary of
# OpenXTalk Lite 1.15 with LiveCode Script
IDE_LIBRARY = ('revidelibrary', 'ide', ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript'),
               'IDE Library', 'LiveCode')


def _metadata(pattern, path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        text = f.read()
    found = {}
    for key, value in pattern.findall(text):
        found.setdefault(key.lower(), value.strip())
    return text, found.get('title', ''), found.get('author', '')


def _manifest(path):
    root = ET.parse(path).getroot()
    return {tag: (root.findtext(tag) or '').strip() for tag in ('name', 'type', 'title', 'author')}


def extension_sources(repo=REPO):
    """[(id, kind, source, title, author)] of the extensions OXT-Beyond
    installs that can have docs: those built from extensions/ (the sources
    of extensions/extensions.gyp) that tools/oxt/layout.py installs, with
    their .lcb or .livecodescript file, and those of ide/Extensions with an
    api.lcdoc; then the IDE library. The xTalk Suite extensions document
    their handlers in their own repositories only."""
    sys.path.insert(0, os.path.join(repo, 'tools', 'oxt'))
    import layout  # noqa: E402
    installed = set(layout.REPO_BUILT_EXTENSIONS)
    gyp = os.path.join(repo, 'extensions', 'extensions.gyp')
    with open(gyp, 'r', encoding='utf-8') as f:
        targets = ast.literal_eval(f.read())['targets']
    out = []
    for target in targets:
        for source in target.get('sources', []):
            path = os.path.join(repo, 'extensions', *source.split('/'))
            if source.endswith('.lcb'):
                text, title, author = _metadata(LCB_METADATA, path)
                m = DECLARATION.search(text)
                if not m:
                    raise TextDictionaryError('%s declares no library, widget or module' % path)
                kind, ident = m.group(1), m.group(2)
            elif source.endswith('.livecodescript'):
                # the build packages it as com.livecode.library.<name>
                text, title, author = _metadata(LCS_METADATA, path)
                kind, ident = 'library', 'com.livecode.library.' + os.path.splitext(os.path.basename(source))[0]
            else:
                continue
            if ident in installed:
                out.append((ident, kind, path, title, author))
    ide = os.path.join(repo, 'ide', 'Extensions')
    for folder in sorted(os.listdir(ide)):
        api = os.path.join(ide, folder, 'api.lcdoc')
        manifest = os.path.join(ide, folder, 'manifest.xml')
        if os.path.isfile(api) and os.path.isfile(manifest):
            m = _manifest(manifest)
            out.append((m['name'] or folder, m['type'], api, m['title'], m['author']))
    missing = installed - {x[0] for x in out}
    if missing:
        raise TextDictionaryError('no source in extensions/extensions.gyp for %s' % ', '.join(sorted(missing)))
    ident, kind, path, title, author = IDE_LIBRARY
    out.append((ident, kind, os.path.join(repo, *path), title, author))
    for x in out:
        if any('\t' in field or '\n' in field for field in x):
            raise TextDictionaryError('%s: a tab or line end in %r' % (x[2], x))
    return out


def collect(data, extensions=None):
    """{section: [entries]} from the docs builder's data folder and the
    extensions' JSON files (<id>.js of the extensions in
    extensions/extensions.txt)."""
    sections = collections.OrderedDict((s, []) for s in SECTIONS)
    sources = []
    script = os.path.join(data, 'api_livecode_script')
    builder = os.path.join(data, 'api_livecode_builder')
    for folder, default in ((script, 'xtalk'), (builder, 'builder')):
        if not os.path.isdir(folder):
            raise TextDictionaryError('no folder %s: run the docs builder first' % folder)
        for name in sorted(os.listdir(folder)):
            if name.endswith('.js'):
                section = 'datagrid' if (folder == script and name == 'dg.js') else default
                sources.append((os.path.join(folder, name), section))
    if extensions:
        listing = os.path.join(extensions, EXTENSION_LIST)
        if not os.path.isfile(listing):
            raise TextDictionaryError('no %s' % listing)
        with open(listing, 'r', encoding='utf-8') as f:
            for line in f.read().splitlines():
                if not line.strip():
                    continue
                ident, kind = line.split('\t')[:2]
                path = os.path.join(extensions, ident + '.js')
                if os.path.isfile(path):
                    # as in the IDE (__TypeToAPI): a module documents
                    # LiveCode Builder, the others (and the IDE library)
                    # LiveCode Script
                    sources.append((path, 'builder' if kind == 'module' else 'xtalk'))
    for path, section in sources:
        sections[section].extend(load_json(path))
    for section in ('xtalk', 'builder'):
        if not sections[section]:
            raise TextDictionaryError('no %s entries in %s' % (section, data))
    return sections


def write_section(folder, entries):
    """Replace the entry files of folder/resaved and write index.txt and
    substitutions.txt. Returns the file names."""
    pages = os.path.join(folder, 'resaved')
    os.makedirs(pages, exist_ok=True)
    for name in os.listdir(pages):
        path = os.path.join(pages, name)
        if os.path.isfile(path):
            os.remove(path)
    names = []
    for name, e in file_names(entries):
        with open(os.path.join(pages, name), 'w', encoding='utf-8', newline='\n') as f:
            f.write(entry_text(e))
        names.append(name)
    with open(os.path.join(folder, 'index.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(names) + '\n')
    with open(os.path.join(folder, 'substitutions.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(''.join('%s\t%s\n' % s for s in SUBSTITUTIONS))
    return names


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--data', default=DEFAULT_DATA,
                    help='the docs builder\'s data folder (default: %(default)s)')
    ap.add_argument('--out', help='the exports folder (default: <data>/api/exports)')
    ap.add_argument('--extensions', metavar='DIR',
                    help='add the extensions\' JSON files of DIR (tools/ci/extension_docs.livecodescript)')
    ap.add_argument('--list-extensions', metavar='DIR',
                    help='only write DIR/extensions.txt, the extensions whose docs to add')
    args = ap.parse_args(argv)
    try:
        if args.list_extensions:
            os.makedirs(args.list_extensions, exist_ok=True)
            found = extension_sources()
            with open(os.path.join(args.list_extensions, EXTENSION_LIST), 'w', encoding='utf-8',
                      newline='\n') as f:
                f.write(''.join('\t'.join(x) + '\n' for x in found))
            print('%d sources of docs' % len(found))
            return 0
        out = args.out or os.path.join(args.data, 'api', 'exports')
        sections = collect(args.data, args.extensions)
        for section, entries in sections.items():
            names = write_section(os.path.join(out, section), entries)
            print('%s: %d entries, %d files' % (section, len(entries), len(names)))
    except (TextDictionaryError, OSError, ValueError, SyntaxError, ET.ParseError) as err:
        print('text_dictionary.py: %s' % err, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
