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

"""Writes the four pages of the welcome section (tools/pages/welcome, the
site's welcome/ for people coming from LiveCode) from src/pages/*.html,
putting in the parts every page shares: the head with its link-preview
tags, the bar at the top, the sky and the footer. The pages it writes,
beside this folder, are plain HTML that need no build step to serve; this
script only keeps the shared parts identical, so a change to one of them
is made once, here.

  python3 -I tools/pages/welcome/src/build.py           write the pages
  python3 -I tools/pages/welcome/src/build.py --check   say which differ

A page's own script, if it has one, goes in src/pages/<page>.tail.
tools/ci/tests/test_pages_welcome.py runs --check, so a page edited by
hand, or a source changed without writing the pages again, fails there."""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent

GH = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'
PLAYER = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/player/'
IDE = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/ide/'
SITE = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/'
# Where these pages are on the site: build_pages.py copies this folder to
# welcome/. Link previews need the full address of each page and picture.
BASE = SITE + 'welcome/'
# The pictures link previews show (share/*.jpg, drawn by src/share.js
# from src/share.html): the size Facebook, LinkedIn, X, Mastodon,
# Discord and Slack all show large
SHARE_W, SHARE_H = 1200, 630
FORUM = 'https://openxtalk.org/forum/'
ISSUE = GH + '/issues/new?template=bug_report.yml'

TM = ('LiveCode is a trademark of LiveCode Ltd. OXT-Beyond is not affiliated with, sponsored by or endorsed by '
      'LiveCode Ltd, and is an independent continuation of OpenXTalk Lite.')

PAGES = {
    'index.html': dict(
        current='home',
        comment='OXT-Beyond, for people coming from LiveCode: the front page.\n'
                '     A static page: it asks no other host for anything, and works without\n'
                '     its script. Facts are from the OpenXTalk-Beyond repository and its\n'
                '     releases as of 2026-11-21; README.md beside this page lists the\n'
                '     sources, and what to change with each release.',
        title='OXT-Beyond: another road for your stacks',
        desc="For LiveCode users: LiveCode Community's GPL code lives on as OXT-Beyond, free and open source. "
             "Check your stack in your browser, play it with nothing to install, and build in-house tools at no cost.",
        og_title='OXT-Beyond: another road for your stacks',
        og_desc="LiveCode Community's GPL code lives on, and it's still free. Check your stack in your browser.",
        share='share/home.jpg',
        share_alt="OXT-Beyond, for LiveCode users. There's another road for your stacks: LiveCode Community's GPL "
                  'code lives on as OXT-Beyond, free, open source and still moving. Free and open source, nothing '
                  'to install to try it, on Windows, macOS, Linux and the web.',
        legal=TM + ' Feature facts as of 21 November 2026, from the project&rsquo;s README, changelog and releases.',
        scripts=['assets/stackcheck.js', 'assets/site.js'],
    ),
    'guide.html': dict(
        current='guide',
        comment='OXT-Beyond, for people coming from LiveCode: the guide. What opens,\n'
                '     where things live, where each library went, what differs, and where\n'
                '     every feature stands, with the release each fact is in. Facts are\n'
                '     from the OpenXTalk-Beyond README, CHANGELOG, Dictionary and releases\n'
                '     as of 2026-11-21; README.md beside this page lists them.',
        title='Coming from LiveCode: a guide to OXT-Beyond',
        desc="For LiveCode users: what opens in OXT-Beyond, how it sits beside LiveCode, where tsNet, mergJSON and "
             "revDB went, what differs, and where every feature stands: ready, in preview, or not there yet.",
        og_title='Coming from LiveCode: a guide to OXT-Beyond',
        og_desc="What opens, what differs, where your libraries went, and where every feature stands.",
        share='share/guide.jpg',
        share_alt='OXT-Beyond, for LiveCode users. Coming from LiveCode: the IDE you know, carried on. Where '
                  'everything stands: ready today, in the preview, experimental, not available, not tested yet.',
        legal=TM + ' Feature facts as of 21 November 2026, from the project&rsquo;s README, changelog, Dictionary and releases.',
        scripts=['assets/site.js'],
    ),
    'in-house.html': dict(
        current='inhouse',
        comment='OXT-Beyond, for people coming from LiveCode: what the GPLv3 asks of a\n'
                '     tool that stays inside an organisation. Every quotation of the licence\n'
                '     is copied from the LICENSE file in the OpenXTalk-Beyond repository;\n'
                '     the FSF FAQ links point at entries checked on 2026-11-21. It is not\n'
                '     legal advice.',
        title='Free for in-house tools: OXT-Beyond and the GPL',
        desc="OXT-Beyond is GPLv3. A tool that stays inside your organisation owes nothing: no fee, no royalty and "
             "no source to publish. Who gets a copy decides the rest, in plain words, with the licence's own text.",
        og_title='Free for your in-house tools: OXT-Beyond and the GPL',
        og_desc="Under the GPL, a tool your own team uses costs nothing, and nothing has to be published. Here is where the line is.",
        share='share/in-house.jpg',
        share_alt='OXT-Beyond, for LiveCode users. Tools for your own team cost nothing. Using it: never '
                  'restricted. Keeping it inside: nothing owed. Giving it to others: they get the source.',
        legal='This page explains the GNU GPL in plain words; it is not legal advice, and where it and the licence '
              'differ, the licence wins. ' + TM,
        scripts=['assets/site.js'],
    ),
    'check.html': dict(
        current='check',
        comment='OXT-Beyond, for people coming from LiveCode: the stack checker.\n'
                '     It reads a stack file in the page (assets/stackcheck.js) and draws a\n'
                '     report (assets/check-ui.js). The file is never uploaded, and nothing\n'
                '     in it runs: the page asks no server for anything once it has loaded.',
        title='Stack checker: will your stack open in OXT-Beyond?',
        desc="Drop a LiveCode stack on this page and see whether it opens in OXT-Beyond: its format, widgets, libraries "
             "and platforms, what works, what differs and what to do next. Read in your browser; nothing is uploaded.",
        og_title='Will your stack open in OXT-Beyond?',
        og_desc='Drop a LiveCode stack on the page. It is read in your browser, and nothing is uploaded.',
        share='share/check.jpg',
        share_alt='OXT-Beyond, for LiveCode users. Will it open? Ask the file. The stack checker: drop a stack on '
                  'the page. It is read in your browser, nothing is uploaded, and nothing in the stack runs.',
        legal='The sample stacks are LiveCode Community&rsquo;s own, under the GPLv3. ' + TM,
        scripts=['assets/sample-stacks.js', 'assets/stackcheck.js', 'assets/site.js', 'assets/check-ui.js'],
        skip=('#reports-title', 'Skip to the report'),
    ),
}

ICON_SUN = ('<svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">'
            '<circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.2M12 19.3v2.2M4.6 4.6l1.6 1.6M17.8 17.8l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.6 19.4l1.6-1.6M17.8 6.2l1.6-1.6"/></svg>')
ICON_MOON = ('<svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
             '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/></svg>')
ICON_DOWN = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
             '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>')


def attr(text):
    """text for a double-quoted attribute (an apostrophe stays one)."""
    return text.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;')


def address(name):
    """A page's one address, as tools/pages/seo.py writes it: index.html
    as the folder, so seo.py finds its canonical link here and adds none."""
    return BASE if name == 'index.html' else BASE + name


def head(name, p):
    url, image = address(name), BASE + p['share']
    return f'''<!DOCTYPE html>
<!-- {p["comment"]} -->
<html lang="en" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{p["title"]}</title>
<meta name="description" content="{attr(p["desc"])}">
<meta name="theme-color" content="#070b14">
<link rel="icon" type="image/svg+xml" href="../brand/icon.svg">
<link rel="canonical" href="{url}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="OXT-Beyond">
<meta property="og:locale" content="en_US">
<meta property="og:url" content="{url}">
<meta property="og:title" content="{attr(p["og_title"])}">
<meta property="og:description" content="{attr(p["og_desc"])}">
<meta property="og:image" content="{image}">
<meta property="og:image:type" content="image/jpeg">
<meta property="og:image:width" content="{SHARE_W}">
<meta property="og:image:height" content="{SHARE_H}">
<meta property="og:image:alt" content="{attr(p["share_alt"])}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{attr(p["og_title"])}">
<meta name="twitter:description" content="{attr(p["og_desc"])}">
<meta name="twitter:image" content="{image}">
<meta name="twitter:image:alt" content="{attr(p["share_alt"])}">
<script>(function(d){{d.className=d.className.replace('no-js','js');try{{var t=localStorage.getItem('oxtb-theme');if(t==='light'||t==='dark')d.setAttribute('data-theme',t);}}catch(e){{}}setTimeout(function(){{if(!window.OXTB)d.classList.add('reveal-all');}},2500);}})(document.documentElement);</script>
<link rel="preload" href="assets/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="assets/fonts/bricolage-grotesque.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="assets/site.css">
</head>
<body>
'''


def topbar(current):
    dl = '#download' if current == 'home' else 'index.html#download'

    def cur(name):
        return ' aria-current="page"' if current == name else ''
    return f'''<a class="skip" href="{{SKIP}}">{{SKIPLABEL}}</a>

<header class="topbar">
  <div class="wrap">
    <a class="brand" href="index.html"><img class="brand-mark" src="../brand/icon.svg" alt="" width="34" height="34"><span>OXT-<b>Beyond</b></span><small>for LiveCode users</small></a>
    <nav class="nav" aria-label="Site">
      <a href="guide.html"{cur("guide")}>Coming from LiveCode</a>
      <a href="in-house.html"{cur("inhouse")}>In-house tools</a>
      <a href="check.html"{cur("check")}>Stack checker</a>
    </nav>
    <div class="topbar-actions">
      <button class="theme" type="button" aria-label="Switch between light and dark">
        {ICON_SUN}
        {ICON_MOON}
      </button>
      <a class="nav-cta" href="{dl}">{ICON_DOWN}Download</a>
      <details class="menu">
        <summary aria-label="Menu"><span></span></summary>
        <nav class="menu-panel" aria-label="Site, on a small screen">
          <a href="index.html"{cur("home")}>Home</a>
          <a href="guide.html"{cur("guide")}>Coming from LiveCode</a>
          <a href="in-house.html"{cur("inhouse")}>In-house tools and the GPL</a>
          <a href="check.html"{cur("check")}>Stack checker</a>
          <a class="menu-cta" href="{dl}">{ICON_DOWN}Download OXT-Beyond</a>
        </nav>
      </details>
    </div>
  </div>
  <span class="progress" aria-hidden="true"></span>
</header>
'''


ROAD = '''  <svg class="road" viewBox="0 0 1000 150" preserveAspectRatio="none" aria-hidden="true" focusable="false">
    <defs>
      <radialGradient id="road-glow" cx="500" cy="0" r="160" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#ffd08a" stop-opacity=".9"/>
        <stop offset=".35" stop-color="#ff7a00" stop-opacity=".35"/>
        <stop offset="1" stop-color="#ff7a00" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="road-fade" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#fff"/>
        <stop offset=".55" stop-color="#fff" stop-opacity=".7"/>
        <stop offset="1" stop-color="#fff" stop-opacity="0"/>
      </linearGradient>
      <mask id="road-mask" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="150">
        <rect x="0" y="0" width="1000" height="150" fill="url(#road-fade)"/>
      </mask>
    </defs>
    <g mask="url(#road-mask)">
      <path class="surface" d="M497 0 L503 0 L860 150 L140 150 Z"/>
      <path class="edge" d="M497 0 L140 150"/>
      <path class="edge" d="M503 0 L860 150"/>
      <path class="lane" d="M500 6 L500 10 M500 18 L500 27 M500 37 L500 52 M500 64 L500 86 M500 101 L500 136"/>
    </g>
    <ellipse class="glow" cx="500" cy="0" rx="170" ry="34"/>
  </svg>
'''


def sky(cls):
    return (f'<div class="sky{(" " + cls) if cls else ""}">\n'
            '  <div class="stars" aria-hidden="true"></div>\n'
            '  <div class="horizon" aria-hidden="true"></div>\n'
            + ROAD +
            '  <div class="wrap">\n')


def footer(p):
    dl = '#download' if p['current'] == 'home' else 'index.html#download'
    return f'''<footer class="site">
  <div class="wrap">
    <div class="foot-grid">
      <div class="foot-brand">
        <a class="brand" href="index.html"><img class="brand-mark" src="../brand/icon.svg" alt="" width="34" height="34"><span>OXT-<b>Beyond</b></span></a>
        <p>LiveCode Community&rsquo;s GPL code, carried on in the open. Free and open source, under the GPLv3.</p>
        <a class="button" href="check.html">Check a stack</a>
      </div>
      <div class="foot-col">
        <h2>This site</h2>
        <ul>
          <li><a href="index.html">Home</a></li>
          <li><a href="guide.html">Coming from LiveCode</a></li>
          <li><a href="in-house.html">In-house tools and the GPL</a></li>
          <li><a href="check.html">Stack checker</a></li>
          <li><a href="{dl}">Download</a></li>
        </ul>
      </div>
      <div class="foot-col">
        <h2>The project</h2>
        <ul>
          <li><a href="{GH}">Source on GitHub</a></li>
          <li><a href="{SITE}">The OXT-Beyond website</a></li>
          <li><a href="{GH}/releases">Releases</a></li>
          <li><a href="{GH}/blob/main/CHANGELOG.md">Changelog</a></li>
        </ul>
      </div>
      <div class="foot-col">
        <h2>Help and more</h2>
        <ul>
          <li><a href="{FORUM}">OpenXTalk forum</a></li>
          <li><a href="{ISSUE}">Report a bug</a></li>
          <li><a href="{PLAYER}">Stack Player</a></li>
          <li><a href="{IDE}">Web IDE</a></li>
        </ul>
      </div>
    </div>
    <p class="legal">{p["legal"]}</p>
  </div>
  <div class="wordmark" aria-hidden="true">OXT-Beyond</div>
</footer>
'''


def build(name, p):
    """The page's text, as it should be beside this folder."""
    src = (HERE / 'pages' / name).read_text(encoding='utf-8')
    body = src
    body = re.sub(r'<!--@sky ?([a-z -]*)-->\n', lambda m: sky(m.group(1).strip()), body)
    body = body.replace('<!--@/sky-->\n', '  </div>\n</div>\n')
    for k, v in {'GH': GH, 'PLAYER': PLAYER, 'IDE': IDE, 'FORUM': FORUM, 'ISSUE': ISSUE, 'SITE': SITE}.items():
        body = body.replace('{{' + k + '}}', v)
    skip, skiplabel = p.get('skip', ('#main', 'Skip to the page'))
    out = head(name, p) + topbar(p['current']).replace('{SKIP}', skip).replace('{SKIPLABEL}', skiplabel) + '\n' + body
    out += '\n' + footer(p) + '\n'
    out += ''.join(f'<script src="{s}"></script>\n' for s in p['scripts'])
    tail = (HERE / 'pages' / (name + '.tail')) if (HERE / 'pages' / (name + '.tail')).exists() else None
    if tail:
        out += tail.read_text(encoding='utf-8')
    out += '</body>\n</html>\n'
    left = re.findall(r'\{\{[A-Z]+\}\}|<!--@', out)
    if left:
        raise SystemExit(f'{name}: unexpanded markers {left}')
    return out


def main(argv):
    check = argv[1:] == ['--check']
    if argv[1:] and not check:
        raise SystemExit('usage: build.py [--check]')
    stale = []
    for name, p in PAGES.items():
        text = build(name, p)
        page = OUT / name
        if check:
            if not page.is_file() or page.read_text(encoding='utf-8') != text:
                stale.append(name)
        else:
            with open(page, 'w', encoding='utf-8', newline='\n') as f:
                f.write(text)
            print('wrote', name, len(text), 'bytes')
    if stale:
        print('not what src/build.py writes: %s (run it, and commit the pages it writes)' % ', '.join(stale))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
