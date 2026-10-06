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

"""A page to look through the IDE screenshots of a build, light and dark
side by side.

  python tools/ci/ui_tour_page.py DIR [--title TEXT]
  python tools/ci/ui_tour_page.py DIR --summary [--url URL] [--title TEXT]

DIR holds the folders tools/ci/ui_tour.py wrote with --out DIR/light and
--out DIR/dark (either may be missing): each has the snapshots in shots/
and the script's lines in tour.txt. The first form writes DIR/index.html:
for each snapshot, the light one and the dark one side by side, each a link
to the full-size file; at the top, the steps that failed and the script
errors in the IDE's windows of each appearance. The page refers to the
snapshots where they are (light/shots/<file>), so it works from a folder
or an unzipped artifact, and needs nothing from the network.

--summary writes nothing in DIR. It adds a few lines to the job summary
(GITHUB_STEP_SUMMARY, or prints them without one): how many snapshots
each appearance has, how many steps failed, and URL as the link to download
them (the artifact-url output of actions/upload-artifact).

Exit status 0, also without snapshots: the tour's own steps fail the job
when the tour fails. Standard library only; Python 3.8 or later.
"""

import argparse
import datetime
import html
import os
import sys

APPEARANCES = ('light', 'dark')

STYLE = '''
:root { color-scheme: light dark; --bg: #f2f2f2; --fg: #1a1a1a; --muted: #5c5c5c;
  --card: #ffffff; --line: #d0d0d0; --bad: #b3261e; --shot: #8a8a8a; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #1c1c1e; --fg: #ececec; --muted: #a8a8a8; --card: #2a2a2c;
    --line: #444; --bad: #ff8a80; --shot: #5a5a5a; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Ubuntu, sans-serif; }
header { position: sticky; top: 0; z-index: 1; background: var(--card);
  border-bottom: 1px solid var(--line); padding: 10px 16px; }
h1 { font-size: 18px; margin: 0 0 4px; }
.meta { color: var(--muted); font-size: 13px; }
.bar { margin-top: 8px; display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.bar button { font: inherit; padding: 3px 10px; border: 1px solid var(--line);
  background: var(--bg); color: var(--fg); border-radius: 6px; cursor: pointer; }
.bar button[aria-pressed="true"] { background: var(--fg); color: var(--bg); }
.bar select { font: inherit; padding: 3px 6px; max-width: 100%; }
main { padding: 12px 16px 40px; }
.status { background: var(--card); border: 1px solid var(--line); border-radius: 8px;
  padding: 10px 14px; margin-bottom: 14px; }
.status p { margin: 4px 0; }
.bad { color: var(--bad); }
section { background: var(--card); border: 1px solid var(--line); border-radius: 8px;
  margin: 0 0 14px; padding: 10px 12px; }
section h2 { font-size: 15px; margin: 0 0 8px; font-family: ui-monospace, Menlo, Consolas, monospace; }
section h2 a { color: inherit; text-decoration: none; }
.pair { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
body.only-light .pair, body.only-dark .pair { grid-template-columns: 1fr; }
body.only-light .dark, body.only-dark .light { display: none; }
figure { margin: 0; min-width: 0; }
figcaption { color: var(--muted); font-size: 12px; margin-bottom: 4px; }
.frame { background: var(--shot); padding: 6px; border-radius: 4px; text-align: center; }
.frame img { max-width: 100%; height: auto; image-rendering: auto; vertical-align: middle; }
.missing { color: var(--muted); font-style: italic; padding: 24px 6px; }
@media (max-width: 700px) { .pair { grid-template-columns: 1fr; } }
'''

SCRIPT = '''
(function () {
  var buttons = document.querySelectorAll('.bar button[data-view]');
  function show(view) {
    document.body.className = view === 'both' ? '' : 'only-' + view;
    buttons.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.view === view)); });
    try { localStorage.setItem('oxt-shots-view', view); } catch (e) {}
  }
  buttons.forEach(function (b) { b.addEventListener('click', function () { show(b.dataset.view); }); });
  var saved = null;
  try { saved = localStorage.getItem('oxt-shots-view'); } catch (e) {}
  show(saved === 'light' || saved === 'dark' ? saved : 'both');
  var jump = document.getElementById('jump');
  if (jump) jump.addEventListener('change', function () { if (jump.value) location.hash = jump.value; });
})();
'''


def read_lines(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            return [line.rstrip('\r\n') for line in f]
    except OSError:
        return []


def tour(folder, appearance):
    """What the tour of one appearance left: its snapshots (file names), the
    steps that failed, the script errors, and whether it got to the end."""
    shots = os.path.join(folder, appearance, 'shots')
    lines = read_lines(os.path.join(folder, appearance, 'tour.txt'))
    names = sorted(n for n in os.listdir(shots) if n.lower().endswith('.png')) if os.path.isdir(shots) else []
    return {
        'ran': os.path.isdir(os.path.join(folder, appearance)),
        'shots': names,
        'failed': [x[5:] for x in lines if x.startswith('STEP ') and ' FAILED' in x],
        'errors': [x[6:] for x in lines if x.startswith('ERROR ')],
        'steps': sum(1 for x in lines if x.startswith('STEP ')),
        'done': any(x.startswith('DONE') for x in lines),
    }


def describe(appearance, t):
    if not t['ran']:
        return '%s: not run' % appearance
    text = '%s: %d snapshot(s), %d step(s)' % (appearance, len(t['shots']), t['steps'])
    problems = []
    if t['failed']:
        problems.append('%d failed' % len(t['failed']))
    if t['errors']:
        problems.append('%d script error(s)' % len(t['errors']))
    if not t['done']:
        problems.append('did not get to the end')
    return text + (', ' + ', '.join(problems) if problems else ', every step done')


def run_link():
    server, repo, run = (os.environ.get(k, '') for k in ('GITHUB_SERVER_URL', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID'))
    if server and repo and run:
        return '%s/%s/actions/runs/%s' % (server, repo, run)
    return ''


def write_page(folder, title, tours):
    esc = html.escape
    names = sorted(set(tours['light']['shots']) | set(tours['dark']['shots']))
    sha = os.environ.get('GITHUB_SHA', '')[:8]
    ref = os.environ.get('GITHUB_REF_NAME', '')
    meta = [datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC')]
    if ref:
        meta.append(esc(ref))
    if sha:
        meta.append('commit ' + esc(sha))
    link = run_link()
    if link:
        meta.append('<a href="%s">the run</a>' % esc(link))

    out = ['<!doctype html>', '<html lang="en">', '<head>', '<meta charset="utf-8">',
           '<meta name="viewport" content="width=device-width, initial-scale=1">',
           '<title>IDE screenshots: %s</title>' % esc(title), '<style>%s</style>' % STYLE, '</head>', '<body>',
           '<header>', '<h1>IDE screenshots: %s</h1>' % esc(title),
           '<div class="meta">%s</div>' % ' · '.join(meta),
           '<div class="bar">',
           '<button type="button" data-view="both" aria-pressed="true">Light and dark</button>',
           '<button type="button" data-view="light" aria-pressed="false">Light</button>',
           '<button type="button" data-view="dark" aria-pressed="false">Dark</button>']
    if names:
        out.append('<select id="jump" aria-label="Go to a snapshot"><option value="">Go to…</option>%s</select>' % ''.join(
            '<option value="#%s">%s</option>' % (esc(n[:-4]), esc(n[:-4])) for n in names))
    out += ['</div>', '</header>', '<main>', '<div class="status">']
    for appearance in APPEARANCES:
        t = tours[appearance]
        bad = t['failed'] or t['errors'] or (t['ran'] and not t['done'])
        out.append('<p%s>%s</p>' % (' class="bad"' if bad else '', esc(describe(appearance, t))))
        for item in t['failed']:
            out.append('<p class="bad">%s: step %s</p>' % (esc(appearance), esc(item)))
        for item in t['errors']:
            out.append('<p class="bad">%s: script error: %s</p>' % (esc(appearance), esc(item)))
    if not names:
        out.append('<p>No snapshots.</p>')
    out.append('</div>')
    for name in names:
        anchor = name[:-4]
        out += ['<section id="%s">' % esc(anchor), '<h2><a href="#%s">%s</a></h2>' % (esc(anchor), esc(anchor)),
                '<div class="pair">']
        for appearance in APPEARANCES:
            out.append('<figure class="%s"><figcaption>%s</figcaption>' % (appearance, appearance))
            if name in tours[appearance]['shots']:
                src = '%s/shots/%s' % (appearance, name)
                out.append('<div class="frame"><a href="%s"><img src="%s" alt="%s, %s" loading="lazy"></a></div>'
                           % (esc(src), esc(src), esc(anchor), appearance))
            else:
                out.append('<div class="frame missing">no snapshot</div>')
            out.append('</figure>')
        out += ['</div>', '</section>']
    out += ['</main>', '<script>%s</script>' % SCRIPT, '</body>', '</html>', '']
    path = os.path.join(folder, 'index.html')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out))
    return path, len(names)


def write_summary(title, tours, url):
    lines = ['### IDE screenshots: %s' % title, '']
    for appearance in APPEARANCES:
        lines.append('- %s' % describe(appearance, tours[appearance]))
    lines.append('')
    if url:
        lines.append('[Download them](%s), unzip, and open `index.html`: each window light and dark side by side.' % url)
    else:
        lines.append('No download: the snapshots were not uploaded.')
    lines.append('')
    text = '\n'.join(lines) + '\n'
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write(text)
    print(text, end='')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('folder', help='the folder with light/ and dark/ (ui_tour.py --out DIR/light, DIR/dark)')
    parser.add_argument('--title', default='', help='what the page is of, e.g. the platform (default: the folder\'s name)')
    parser.add_argument('--summary', action='store_true', help='add to the job summary instead of writing the page')
    parser.add_argument('--url', default='', help='with --summary: the link to download the snapshots')
    args = parser.parse_args(argv)

    folder = os.path.abspath(args.folder)
    title = args.title or os.path.basename(folder)
    tours = {a: tour(folder, a) for a in APPEARANCES}
    if args.summary:
        write_summary(title, tours, args.url)
        return 0
    if not os.path.isdir(folder):
        print('%s: no such folder, no page written' % folder)
        return 0
    path, count = write_page(folder, title, tours)
    print('wrote %s: %d snapshot(s); %s; %s' % (path, count, describe('light', tours['light']),
                                                 describe('dark', tours['dark'])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
