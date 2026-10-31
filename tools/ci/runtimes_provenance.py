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

"""How far the runtimes asset is behind the engine's source.

    python3 tools/ci/runtimes_provenance.py [--repo DIR] [--assets FILE]
        [--fail-on-stale] [--list N]

A package's standalone runtimes for the platforms other than its own come
from the runtimes asset (tools/oxt/external-assets.json, the asset whose id
begins oxt-runtimes-), which was built from one commit of this repository
(its "source" says which). Every runtime reports the same version and build
number whatever commit it was built from, so a standalone check cannot tell
an old runtime from a new one (modernization report MOD-01). This lists the
commits since the asset's that changed the engine's source (SOURCE_PATHS),
the changes those runtimes do not have.

By default it only reports: the list goes to standard output and, under
GitHub Actions, to the job summary with a warning, and the exit status is 0
however many commits there are (rebuilding the runtimes is seth's
decision, the plan's MOD-D1; failing would make every build red until
then). --fail-on-stale makes it exit 1 when there is any. Exit status 2
when the asset or its commit cannot be found, or the history does not
reach the commit (a shallow clone: check out with fetch-depth 0).

The Android runtime in the asset is carried over from oxt-runtimes-1.15
and is not built from any commit here: the report says so and counts
nothing for it.
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ASSETS = os.path.join(REPO, 'tools', 'oxt', 'external-assets.json')

# The folders whose changes a runtime built from them would carry
SOURCE_PATHS = ('engine', 'libfoundation', 'libgraphics', 'libscript', 'libbrowser', 'revdb', 'thirdparty')

COMMIT_RE = re.compile(r'\bcommit ([0-9a-f]{7,40})\b')


class ProvenanceError(Exception):
    pass


def runtimes_asset(assets_file):
    """(id, commit) of the runtimes asset: the commit its source names."""
    with open(assets_file, encoding='utf-8') as f:
        data = json.load(f)
    found = [a for a in data.get('assets', []) if str(a.get('id', '')).startswith('oxt-runtimes-')]
    if len(found) != 1:
        raise ProvenanceError('%s has %d oxt-runtimes- assets, not one' % (assets_file, len(found)))
    asset = found[0]
    commits = set(COMMIT_RE.findall(asset.get('source', '')))
    if len(commits) != 1:
        raise ProvenanceError('the source of %s names %d commits, not one: %r'
                              % (asset['id'], len(commits), asset.get('source', '')))
    return asset['id'], commits.pop()


def git(repo, *args):
    out = subprocess.run(['git', '-C', repo] + list(args), capture_output=True, text=True)
    if out.returncode != 0:
        raise ProvenanceError('git %s: %s' % (' '.join(args), out.stderr.strip()))
    return out.stdout


def commits_since(repo, commit, paths=SOURCE_PATHS):
    """[(sha, subject)] of the commits after commit, up to HEAD, that change
    paths, newest first."""
    try:
        full = git(repo, 'rev-parse', '--verify', '--quiet', commit + '^{commit}').strip()
    except ProvenanceError:
        raise ProvenanceError('commit %s is not in the history here (a shallow clone? check out with '
                              'fetch-depth 0)' % commit)
    out = git(repo, 'log', '--format=%H %s', '%s..HEAD' % full, '--', *paths)
    return [tuple(line.split(' ', 1)) if ' ' in line else (line, '') for line in out.splitlines() if line]


def report(asset_id, commit, commits, limit):
    lines = ['### Runtimes asset provenance', '',
             '`%s` was built from commit `%s`.' % (asset_id, commit[:12]), '']
    if not commits:
        lines.append('No commit since then changes the engine\'s source (%s): the runtimes are current.'
                     % ', '.join(SOURCE_PATHS))
    else:
        lines.append('**%d commits since then change the engine\'s source** (%s). The Windows and Linux '
                     'runtimes that packages carry for the other platforms do not have them; rebuilding '
                     'the asset is seth\'s decision (plan MOD-D1). Some may change only another platform\'s code '
                     '(the web\'s or the Mac\'s): the list says what changed, not what each runtime '
                     'lacks.' % (len(commits), ', '.join(SOURCE_PATHS)))
        lines.append('')
        for sha, subject in commits[:limit]:
            lines.append('- `%s` %s' % (sha[:10], subject))
        if len(commits) > limit:
            lines.append('- ... and %d more' % (len(commits) - limit))
    lines += ['', 'The Android runtime in the asset is carried over from oxt-runtimes-1.15, not built here: '
              'not checked.']
    return '\n'.join(lines) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--repo', default=REPO, help='the checkout (default: this one)')
    ap.add_argument('--assets', default=ASSETS, help='external-assets.json (default: the checkout\'s)')
    ap.add_argument('--fail-on-stale', action='store_true',
                    help='exit 1 when any commit since the asset\'s changes the engine\'s source')
    ap.add_argument('--list', type=int, default=40, metavar='N', help='list at most N commits (default 40)')
    args = ap.parse_args(argv)
    actions = os.environ.get('GITHUB_ACTIONS') == 'true'
    try:
        asset_id, commit = runtimes_asset(args.assets)
        commits = commits_since(args.repo, commit)
    except ProvenanceError as e:
        print('error: %s' % e, file=sys.stderr)
        if actions:
            print('::error title=Runtimes provenance::%s' % e)
        return 2
    text = report(asset_id, commit, commits, args.list)
    sys.stdout.write(text)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write(text + '\n')
    if commits and actions:
        print('::%s title=Runtimes provenance::%s (from %s) is %d engine-source commits behind HEAD'
              % ('error' if args.fail_on_stale else 'warning', asset_id, commit[:12], len(commits)))
    return 1 if commits and args.fail_on_stale else 0


if __name__ == '__main__':
    sys.exit(main())
