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

"""The OpenXTalk family bar: one slim strip across the top of every page
of the project's three web sites, so a visitor always sees the same way
between them and where they are:

  OXT-Beyond's site    sethmorrowsoftware.github.io/OpenXTalk-Beyond/
                       (this repository: tools/pages)
  the extensions page  sethmorrowsoftware.github.io/xtalk-suite/
                       (the xTalk Suite's tools/build-extensions-site.py)
  the gallery          oxt-stacks.github.io/oxt-community-stacks/
                       (the OXT Community Stacks' tools/build_site.py)

Each site carries its own copy of the bar, inline in the page: its look is
in the one <style> beside it, its mark is drawn in SVG, and it asks no host
for anything, so a page that asks no other host (the front page) still
asks none. The other two repositories hold the same FAMILY, FAMILY_CSS, MARK and family_bar
as copies of this file's; change all three together.

  python3 tools/pages/family.py --site DIR

tools/pages/build_pages.py runs it over the site it has written, before
the sitemap (tools/pages/seo.py). It puts the bar on the pages written
here that are read rather than played: the front page, the extensions
page, the web stacks gallery and its samples' pages, the lessons and the
welcome pages. The web IDE, the Stack Player, the bare player, the
forum's player, the codebase map, the Dictionary (a page of the IDE's
Help) and the big games' own pages (each sized to the window) are left
as they are. The bar links a part of this site only when the site has
it, as the front page does (tools/ci/tests/test_pages_front.py).
"""

import argparse
import html
import os
import re
import sys

BEYOND = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/'
GALLERY = 'https://oxt-stacks.github.io/oxt-community-stacks/'
FORUM = 'https://openxtalk.org/forum/'
OPENXTALK = 'https://openxtalk.org/'

# (key, words, address): the bar's links, in their order, the same on
# every site. A site gives its own pages by key (relative, so a preview
# or a fork links itself) and leaves out a key it maps to None.
FAMILY = (
    ('beyond', 'OXT-Beyond', BEYOND),
    ('ide', 'Web IDE', BEYOND + 'ide/'),
    ('lessons', 'Lessons', BEYOND + 'lessons/'),
    ('extensions', 'Extensions', BEYOND + 'extensions/'),
    ('stacks', 'Community stacks', GALLERY),
    ('forum', 'Forum', FORUM),
)

# The bar's look, whole: every rule is under .oxt-family, and it resets
# what a page's own rules for nav, ul, li and a could give it, so it looks
# the same on every page of every site, light or dark.
FAMILY_CSS = (
    '.oxt-family{position:relative;display:flex;align-items:center;gap:0 10px;margin:0;'
    'padding:0 max(16px,env(safe-area-inset-right)) 0 max(16px,env(safe-area-inset-left));'
    'min-height:40px;background:#0a0f1a;border-bottom:1px solid rgba(255,255,255,.09);color:#c3cddc;'
    'font:500 13.5px/1.2 system-ui,-apple-system,"Segoe UI",Roboto,Ubuntu,sans-serif;letter-spacing:0;'
    'text-align:left;white-space:nowrap;overflow-x:auto;scrollbar-width:none;-webkit-font-smoothing:antialiased;'
    # a row longer than a phone scrolls sideways; its right edge fades to
    # say so (on a wide window the edge is empty, and the fade unseen)
    '-webkit-mask-image:linear-gradient(90deg,#000 calc(100% - 28px),transparent);'
    'mask-image:linear-gradient(90deg,#000 calc(100% - 28px),transparent)}'
    '.oxt-family::-webkit-scrollbar{display:none}'
    '.oxt-family a{color:inherit;font:inherit;letter-spacing:inherit;text-transform:none;text-decoration:none;'
    'background:none;box-shadow:none;border:0;border-radius:0;margin:0;min-height:0}'
    '.oxt-family .oxt-family-home{display:inline-flex;flex:none;align-items:center;gap:8px;padding:8px 6px 8px 0;'
    'color:#eef3ff;font-weight:700}'
    '.oxt-family .oxt-family-home svg{display:block;width:22px;height:22px;flex:none}'
    '.oxt-family ul{display:flex;flex:none;gap:0;margin:0;padding:0;list-style:none;background:none}'
    '.oxt-family li{margin:0;padding:0;list-style:none}'
    '.oxt-family li::before{content:none}'
    '.oxt-family li a{display:block;padding:12px 9px 10px;border-bottom:2px solid transparent}'
    '.oxt-family li:last-child a{margin-right:20px}'
    '.oxt-family li a:hover{color:#fff;border-bottom-color:rgba(255,179,71,.55)}'
    '.oxt-family li a[aria-current="page"]{color:#fff;border-bottom-color:#ff7a00}'
    '.oxt-family a:focus-visible{outline:2px solid #ffb347;outline-offset:-3px;border-radius:4px}'
    '@media (max-width:640px){.oxt-family .oxt-family-home span{display:none}}'
    '@media print{.oxt-family{display:none}}'
)

# The family's mark: a small tile in OXT-Beyond's fire, with its bolt
MARK = ('<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">'
        '<defs><linearGradient id="oxt-family-fire" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#ffc24d"/><stop offset=".55" stop-color="#ff7700"/>'
        '<stop offset="1" stop-color="#ff3d00"/></linearGradient></defs>'
        '<rect x="1" y="1" width="22" height="22" rx="6" fill="url(#oxt-family-fire)"/>'
        '<path d="M13.6 4.5 7.5 13.2h4.1l-1.3 6.3 6.2-8.8h-4.1z" fill="#1a1206"/></svg>')


SHOW_CURRENT = ('<script>(function (n) {'
                'var c = n && n.querySelector(\'[aria-current="page"]\');'
                'if (c && n.scrollWidth > n.clientWidth) n.scrollLeft = c.offsetLeft - 48;'
                '})(document.currentScript && document.currentScript.previousElementSibling);</script>')


def family_bar(current=None, links=None):
    """The bar, as HTML: its <style> and its <nav>. `current` is the key
    of the part the page is in, which the bar marks for the eye and for
    screen readers; `links` maps a key to this site's own address for it,
    or to None to leave it out."""
    links = links or {}
    items = []
    for key, words, href in FAMILY:
        href = links.get(key, href)
        if href is None:
            continue
        items.append('<li><a href="%s"%s>%s</a></li>' % (
            html.escape(href, quote=True), ' aria-current="page"' if key == current else '', html.escape(words)))
    # On a phone the row scrolls sideways: the one line of script after it
    # scrolls it so that the part the page is in shows, not only the first
    return ('<style>%s</style>\n<nav class="oxt-family" aria-label="OpenXTalk sites">'
            '<a class="oxt-family-home" href="%s">%s<span>OpenXTalk</span></a><ul>%s</ul></nav>\n%s\n'
            % (FAMILY_CSS, OPENXTALK, MARK, ''.join(items), SHOW_CURRENT))


_BODY = re.compile(r'<body\b[^>]*>')
# a page's "skip to the content" link stays the first thing Tab reaches
_SKIP = re.compile(r'\s*<a\b[^>]*\bclass="skip"[^>]*>.*?</a>', re.S)


def insert(page, bar):
    """`page` with `bar` at the top of its body, after its skip link if
    it starts with one. A page that has the bar already is given back as
    it is."""
    if 'class="oxt-family"' in page:
        return page
    body = _BODY.search(page)
    if not body:
        raise ValueError('the page has no <body>')
    at = body.end()
    skip = _SKIP.match(page, at)
    if skip:
        at = skip.end()
    return page[:at] + '\n' + bar + page[at:]


# The folders of this site whose pages are read, and which part of the
# bar each is; '' is the front page
READ = (('', 'beyond'), ('extensions', 'extensions'), ('games', 'beyond'), ('lessons', 'lessons'),
        ('welcome', 'beyond'))
# The folders of this site that the bar may link, by key
OWN = (('ide', 'ide/'), ('lessons', 'lessons/'), ('extensions', 'extensions/'))


def pages_of(site):
    """The pages that get the bar: (path, part) for each."""
    found = []
    for folder, part in READ:
        where = os.path.join(site, folder)
        if not os.path.isdir(where):
            continue
        if folder == '':
            found.append((os.path.join(site, 'index.html'), part))
            continue
        for name in sorted(os.listdir(where)):
            path = os.path.join(where, name)
            if name.endswith('.html') and os.path.isfile(path):
                found.append((path, part))
            elif folder == 'games' and os.path.isfile(os.path.join(path, 'index.html')) \
                    and not os.path.isdir(os.path.join(HERE_GAMES, name)):
                # a sample's page, written from games/stack-page.html; the
                # big ones (tools/pages/games/<name>/) are sized to the window
                found.append((os.path.join(path, 'index.html'), part))
            elif folder == 'lessons' and os.path.isdir(path):
                for inner in sorted(os.listdir(path)):
                    if inner.endswith('.html'):
                        found.append((os.path.join(path, inner), part))
    return [(p, part) for p, part in found if os.path.isfile(p)]


HERE_GAMES = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'games')


def finish(site):
    """Put the bar on every read page of `site`; gives back their paths."""
    site = os.path.abspath(site)
    done = []
    for path, part in pages_of(site):
        up = os.path.relpath(site, os.path.dirname(path)).replace(os.sep, '/')
        up = '' if up == '.' else up + '/'
        links = {'beyond': up or './'}
        for key, folder in OWN:
            links[key] = up + folder if os.path.isdir(os.path.join(site, folder)) else None
        if not links['ide']:
            # no web IDE on this site: the bar does not send people to
            # another site's
            links['ide'] = None
        with open(path, encoding='utf-8') as f:
            page = f.read()
        page = insert(page, family_bar(part, links))
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(page)
        done.append(path)
    return done


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--site', required=True, help='the site folder build_pages.py wrote')
    args = ap.parse_args()
    print('family bar: %d pages' % len(finish(args.site)))


if __name__ == '__main__':
    sys.exit(main())
