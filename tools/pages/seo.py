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

"""What search engines read on the GitHub Pages site: a sitemap.xml of its
pages, and each page's one address (<link rel="canonical">, and og:url
where it has link-preview tags), so a page reached as .../lessons/ and as
.../lessons/index.html, or with ?play=... on the end, counts once.

  python3 tools/pages/seo.py --site DIR [--base URL]

tools/pages/build_pages.py runs it last, over the site it has written.
Only the pages written here get the tags: the web IDE, the Stack Player,
the bare player and the codebase map come as they were built (a release's
files, which are not changed), and are only listed in the sitemap by their
front pages. A page that asks not to be indexed (meta robots noindex) is
left out. A robots.txt would do nothing here: search engines read only the
one at the root of sethmorrowsoftware.github.io, which this repository
does not make, so the sitemap is given to them through Search Console.
"""

import argparse
import html
import os
import re
import sys

BASE = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/'

# Folders whose files are a release's: listed by their front page only, and never changed
AS_BUILT = ('ide', 'player', 'play', 'map')
NOINDEX = re.compile(r'<meta\s+name=["\']robots["\']\s+content=["\'][^"\']*noindex', re.I)
CANONICAL = re.compile(r'<link\s[^>]*rel=["\']canonical["\']', re.I)


def address(base, rel):
    """The page's full address: a folder's index.html as the folder."""
    rel = rel.replace(os.sep, '/')
    if rel == 'index.html':
        return base
    if rel.endswith('/index.html'):
        return base + rel[:-len('index.html')]
    return base + rel


def pages(site):
    """The site's pages, as paths relative to it (sorted), each with whether it may be changed."""
    found = []
    for folder, dirs, files in os.walk(site):
        dirs.sort()
        rel_dir = os.path.relpath(folder, site)
        top = '' if rel_dir == '.' else rel_dir.replace(os.sep, '/').split('/')[0]
        for name in sorted(files):
            if not name.endswith('.html'):
                continue
            rel = os.path.normpath(os.path.join(rel_dir, name)).replace(os.sep, '/')
            if top in AS_BUILT:
                if rel == top + '/index.html':
                    found.append((rel, False))
                continue
            found.append((rel, True))
    return sorted(found)


def tag(page, url):
    """page with its address in its head, once; unchanged without a <head>, or with one there already."""
    end = page.find('</head>')
    if end < 0 or CANONICAL.search(page[:end]):
        return page
    add = '<link rel="canonical" href="%s">\n' % html.escape(url, quote=True)
    if re.search(r'<meta\s+property=["\']og:title["\']', page[:end], re.I) and 'og:url' not in page[:end]:
        add += '<meta property="og:url" content="%s">\n' % html.escape(url, quote=True)
    return page[:end] + add + page[end:]


def finish(site, base=BASE):
    """Tag the site's own pages and write its sitemap.xml. Returns the addresses listed."""
    base = base.rstrip('/') + '/'
    listed = []
    for rel, ours in pages(site):
        path = os.path.join(site, rel)
        with open(path, encoding='utf-8', errors='surrogateescape') as f:
            text = f.read()
        head = text[:max(text.find('</head>'), 0)]
        if NOINDEX.search(head) or '</head>' not in text:
            continue
        url = address(base, rel)
        if ours:
            new = tag(text, url)
            if new != text:
                with open(path, 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
                    f.write(new)
        listed.append(url)
    with open(os.path.join(site, 'sitemap.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        for url in listed:
            f.write('  <url><loc>%s</loc></url>\n' % html.escape(url, quote=False))
        f.write('</urlset>\n')
    return listed


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the built site folder')
    ap.add_argument('--base', default=BASE, help='its address (default %(default)s)')
    args = ap.parse_args()
    if not os.path.isdir(args.site):
        print('seo.py: %s is not a folder' % args.site, file=sys.stderr)
        sys.exit(1)
    print('sitemap: %d pages' % len(finish(args.site, args.base)))


if __name__ == '__main__':
    main()
