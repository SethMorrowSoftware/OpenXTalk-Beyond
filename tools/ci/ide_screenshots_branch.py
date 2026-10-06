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

"""The IDE screenshots of the latest builds of main, for the branch
ide-screenshots, where GitHub shows each platform's windows light and dark
side by side.

  python3 tools/ci/ide_screenshots_branch.py download DIR [--branch main] [--event push]
  python3 tools/ci/ide_screenshots_branch.py pages DIR OUT [--message FILE]

download looks through the newest finished runs of the three build
workflows on a branch (by default the pushes to main; a pull request's
branch with --event pull_request) and downloads, for each platform, the
newest ide-screenshots-<platform> artifact that has not expired into
DIR/<platform>, with the run it came from in DIR/<platform>/run.json. It
uses the gh command line, with GH_TOKEN, and the repository from --repo,
GH_REPO or GITHUB_REPOSITORY.

pages writes what the branch holds into OUT, emptied first: a folder for
each platform with the snapshots as the artifact has them (light/shots/,
dark/shots/, each appearance's tour.txt, and index.html, the page of the
download) and a README.md showing each window light and dark side by side
(GitHub shows a folder's README.md under its files); and a README.md at
the top with a line for each platform: its snapshots, how many steps
failed and script errors each appearance had, and the build they came
from. It adds that table to the job summary (GITHUB_STEP_SUMMARY), and
--message FILE writes a commit message for them. A platform without
snapshots is left out; with none at all, OUT stays empty.

Exit status 0; 1 when gh fails or DIR is missing. Standard library only;
Python 3.8 or later.
"""

import argparse
import datetime
import html
import json
import os
import shutil
import subprocess
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ui_tour_page  # noqa: E402

WORKFLOWS = ('build-windows.yml', 'build-linux.yml', 'build-macos.yml')
PREFIX = 'ide-screenshots-'
APPEARANCES = ui_tour_page.APPEARANCES
RUNS = 10  # finished runs of each workflow to look through, newest first
PROBLEMS = 20  # failed steps and script errors a platform's page lists

# the platforms (artifact names without the prefix) in the order the top
# page lists them, with their titles; others follow by name
TITLES = (
    ('win-x86_64', 'Windows x86_64'),
    ('linux-x86_64', 'Linux x86_64'),
    ('linux-arm64', 'Linux arm64'),
    ('mac-universal-arm64', 'macOS, Apple silicon'),
    ('mac-universal-x86_64', 'macOS, Intel'),
)


class Failure(Exception):
    pass


def gh(args, binary=False):
    proc = subprocess.run(['gh'] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Failure('gh %s: %s' % (' '.join(args), proc.stderr.decode('utf-8', 'replace').strip()))
    return proc.stdout if binary else proc.stdout.decode('utf-8')


def gh_api(path):
    return json.loads(gh(['api', '-H', 'Accept: application/vnd.github+json', path]))


def download(folder, repo, branch, event):
    """The newest ide-screenshots-<platform> artifact of each platform, from
    the newest finished runs of the build workflows on branch."""
    chosen = {}
    for workflow in WORKFLOWS:
        query = urllib.parse.urlencode({'branch': branch, 'event': event, 'status': 'completed', 'per_page': RUNS})
        runs = gh_api('repos/%s/actions/workflows/%s/runs?%s' % (repo, workflow, query)).get('workflow_runs', [])
        for run in runs:
            artifacts = gh_api('repos/%s/actions/runs/%d/artifacts?per_page=100' % (repo, run['id'])).get('artifacts', [])
            for artifact in artifacts:
                name = artifact.get('name', '')
                platform = name[len(PREFIX):]
                if name.startswith(PREFIX) and platform and not artifact.get('expired') and platform not in chosen:
                    chosen[platform] = (workflow, run, artifact)
    os.makedirs(folder, exist_ok=True)
    for platform, (workflow, run, artifact) in sorted(chosen.items()):
        dest = os.path.join(folder, platform)
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        gh(['run', 'download', str(run['id']), '--repo', repo, '--name', artifact['name'], '--dir', dest])
        info = {
            'artifact': artifact['name'],
            'workflow': run.get('name') or workflow,
            'run_url': run.get('html_url', ''),
            'run_number': run.get('run_number'),
            'head_sha': run.get('head_sha', ''),
            'head_branch': run.get('head_branch', ''),
            'event': run.get('event', ''),
            'conclusion': run.get('conclusion', ''),
            'started_at': run.get('run_started_at') or run.get('created_at', ''),
        }
        with open(os.path.join(dest, 'run.json'), 'w', encoding='utf-8') as f:
            json.dump(info, f, indent=2)
        print('%s: %s of run %s (%s, commit %s, %s)' % (platform, artifact['name'], run['id'], info['workflow'],
                                                       info['head_sha'][:8], info['conclusion']))
    if not chosen:
        print('No %s* artifact in the last %d finished runs of %s on %s (%s).' % (
            PREFIX, RUNS, ', '.join(WORKFLOWS), branch, event))
    return 0


def find_root(folder):
    """The folder of a download with light/shots or dark/shots in it."""
    for root, dirs, _ in os.walk(folder):
        if any(os.path.isdir(os.path.join(root, a, 'shots')) for a in APPEARANCES):
            return root
        if root[len(folder):].count(os.sep) >= 3:
            dirs[:] = []
    return None


def copy_platform(src, dst):
    """Only what the page needs: index.html, and each appearance's PNG
    snapshots and tour.txt."""
    os.makedirs(dst)
    page = os.path.join(src, 'index.html')
    if os.path.isfile(page):
        shutil.copyfile(page, os.path.join(dst, 'index.html'))
    for appearance in APPEARANCES:
        shots = os.path.join(src, appearance, 'shots')
        if not os.path.isdir(shots):
            continue
        os.makedirs(os.path.join(dst, appearance, 'shots'))
        for name in sorted(os.listdir(shots)):
            if name.lower().endswith('.png') and os.path.isfile(os.path.join(shots, name)):
                shutil.copyfile(os.path.join(shots, name), os.path.join(dst, appearance, 'shots', name))
        log = os.path.join(src, appearance, 'tour.txt')
        if os.path.isfile(log):
            shutil.copyfile(log, os.path.join(dst, appearance, 'tour.txt'))


def has_log(folder, appearance):
    return os.path.isfile(os.path.join(folder, appearance, 'tour.txt'))


def describe(folder, appearance, t):
    """As the download's page says it, or only the snapshots for an
    artifact without the tour's lines."""
    if has_log(folder, appearance) or not t['ran']:
        return ui_tour_page.describe(appearance, t)
    return '%s: %d snapshot(s)' % (appearance, len(t['shots']))


def cell(folder, appearance, t):
    if not t['ran']:
        return 'not run'
    text = '%d snapshots' % len(t['shots'])
    if not has_log(folder, appearance):
        return text
    problems = []
    if t['failed']:
        problems.append('%d step(s) failed' % len(t['failed']))
    if t['errors']:
        problems.append('%d script error(s)' % len(t['errors']))
    if not t['done']:
        problems.append('did not get to the end')
    return text + ', ' + (', '.join(problems) if problems else 'every step done')


def when(stamp):
    try:
        return datetime.datetime.strptime(stamp, '%Y-%m-%dT%H:%M:%SZ').strftime('%Y-%m-%d %H:%M UTC')
    except (TypeError, ValueError):
        return stamp or ''


def source(info, repo, server):
    """Where a platform's snapshots came from, in Markdown."""
    sha = info.get('head_sha', '')
    parts = []
    if sha:
        commit = '`%s`' % sha[:8]
        if repo:
            commit = '[%s](%s/%s/commit/%s)' % (commit, server, repo, sha)
        parts.append('commit %s' % commit)
    if info.get('run_url'):
        run = 'the build'
        if info.get('conclusion'):
            run += ', %s' % info['conclusion']
        parts.append('[%s](%s)' % (run, info['run_url']))
    if info.get('started_at'):
        parts.append(when(info['started_at']))
    return ' · '.join(parts) if parts else 'unknown build'


def write_platform(folder, title, info, tours, repo, server):
    esc = html.escape
    names = sorted(set(tours['light']['shots']) | set(tours['dark']['shots']))
    out = ['# IDE screenshots: %s' % title, '',
           '[Every platform](../README.md) · %s' % source(info, repo, server), '']
    for appearance in APPEARANCES:
        out.append('- %s' % describe(folder, appearance, tours[appearance]))
    out.append('')
    for appearance in APPEARANCES:
        t = tours[appearance]
        problems = ['step %s' % x for x in t['failed']] + ['script error: %s' % x for x in t['errors']]
        if problems:
            out += ['What went wrong (%s):' % appearance, '', '```'] + problems[:PROBLEMS] + ['```', '']
            if len(problems) > PROBLEMS:
                out += ['And %d more: [%s/tour.txt](%s/tour.txt) has them all.' % (
                    len(problems) - PROBLEMS, appearance, appearance), '']
    out += ['Each window light, then dark; click one for the full size. A clone of this branch has the same',
            'page as the build\'s download in `index.html`.', '']
    for name in names:
        anchor = name[:-4]
        out += ['### %s' % anchor, '']
        row = []
        for appearance in APPEARANCES:
            if name in tours[appearance]['shots']:
                src = esc('%s/shots/%s' % (appearance, name))
                row.append('<a href="%s"><img src="%s" width="49%%" alt="%s, %s"></a>'
                           % (src, src, esc(anchor), appearance))
            else:
                row.append('<em>no %s snapshot</em>' % appearance)
        out += [' '.join(row), '']
    with open(os.path.join(folder, 'README.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out))
    return len(names)


def pages(src, out, message, repo, server):
    if not os.path.isdir(src):
        print('%s: no such folder' % src)
        return 1
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    titles = dict(TITLES)
    order = [p for p, _ in TITLES]
    platforms = sorted((p for p in os.listdir(src) if os.path.isdir(os.path.join(src, p))),
                       key=lambda p: (order.index(p) if p in order else len(order), p))
    rows, commits = [], []
    for platform in platforms:
        root = find_root(os.path.join(src, platform))
        if root is None:
            print('%s: no snapshots, left out' % platform)
            continue
        try:
            with open(os.path.join(src, platform, 'run.json'), 'r', encoding='utf-8') as f:
                info = json.load(f)
        except (OSError, ValueError):
            info = {}
        dest = os.path.join(out, platform)
        copy_platform(root, dest)
        tours = {a: ui_tour_page.tour(dest, a) for a in APPEARANCES}
        title = titles.get(platform, platform)
        count = write_platform(dest, title, info, tours, repo, server)
        rows.append('| [%s](%s/README.md) | %s | %s | %s |' % (
            title, platform, cell(dest, 'light', tours['light']), cell(dest, 'dark', tours['dark']),
            source(info, repo, server)))
        commits.append('%s %s' % (platform, info.get('head_sha', '')[:8] or 'unknown'))
        print('%s: %d window(s); %s; %s' % (platform, count, describe(dest, 'light', tours['light']),
                                            describe(dest, 'dark', tours['dark'])))
    if not rows:
        print('No platform has snapshots: nothing written.')
        return 0
    how = 'BUILDING.md'
    if repo:
        how = '[BUILDING.md](%s/%s/blob/main/BUILDING.md#ide-screenshots)' % (server, repo)
    table = ['| Platform | Light | Dark | From |', '| --- | --- | --- | --- |'] + rows
    top = ['# IDE screenshots', '',
           'The IDE\'s own windows (the palettes, every section of the Inspector, the editors, every pane of',
           'Preferences and card of the Standalone Settings, dialogs and tooltips), light and dark, as the',
           'latest build of `main` on each platform saw them. Each build of main replaces them, and only the',
           'latest are kept, so this branch does not grow. A pull request\'s build has its own as a download',
           'in its summary. How they are made: %s.' % how, ''] + table + ['']
    with open(os.path.join(out, 'README.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(top))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('\n'.join(['### IDE screenshots', ''] + table + ['', '']))
    if message:
        shas = set(c.split(' ', 1)[1] for c in commits)
        subject = 'IDE screenshots of main at %s' % shas.pop() if len(shas) == 1 else 'IDE screenshots of main'
        with open(message, 'w', encoding='utf-8', newline='\n') as f:
            f.write('%s\n\n%s\n' % (subject, '\n'.join(commits)))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    commands = parser.add_subparsers(dest='command')
    get = commands.add_parser('download', help='download the newest screenshots of each platform')
    get.add_argument('folder', help='where to put them (a folder for each platform)')
    get.add_argument('--branch', default='main', help='the branch whose runs to look through (default: main)')
    get.add_argument('--event', default='push', help='the event of those runs (default: push)')
    get.add_argument('--repo', default='', help='owner/name (default: GH_REPO or GITHUB_REPOSITORY)')
    write = commands.add_parser('pages', help='write what the branch holds')
    write.add_argument('folder', help='the folder download wrote')
    write.add_argument('out', help='the folder for the branch (emptied first)')
    write.add_argument('--message', default='', help='a file for the commit message')
    write.add_argument('--repo', default='', help='owner/name, for the links (default: GH_REPO or GITHUB_REPOSITORY)')
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 2
    repo = args.repo or os.environ.get('GH_REPO') or os.environ.get('GITHUB_REPOSITORY', '')
    server = os.environ.get('GITHUB_SERVER_URL') or 'https://github.com'
    try:
        if args.command == 'download':
            if not repo:
                raise Failure('no repository: give --repo or set GH_REPO')
            return download(os.path.abspath(args.folder), repo, args.branch, args.event)
        return pages(os.path.abspath(args.folder), os.path.abspath(args.out), args.message, repo, server)
    except Failure as e:
        print('error: %s' % e)
        return 1


if __name__ == '__main__':
    sys.exit(main())
