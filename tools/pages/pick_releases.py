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

"""The releases the site's Downloads section offers (.github/workflows/
pages.yml): the current stable release and the current preview of the
next one, side by side, so that a visitor can choose.

  gh release list --exclude-drafts --limit 200 --json tagName,isPrerelease > releases.json
  python3 tools/pages/pick_releases.py releases.json

prints two lines, with nothing after the = when there is no such release:

  stable=v0.2.7
  preview=v0.2.8-dp.1

The stable release is the one with the highest version among those that
are not a pre-release: not marked as one on GitHub, and with no
pre-release part in the version (the Release workflow marks every version
that has one). The preview is the pre-release with the highest version,
and it is offered only while its version is higher than the stable
release's: 0.2.7's release candidates are behind 0.2.7, so they are not
put beside it, and the day 0.2.8 is released its previews leave the page.

Versions are compared as semantic versioning orders them, not by the
dates of the releases: numbers as numbers (0.2.8-dp.10 is after
0.2.8-dp.9), a developer preview before a release candidate (dp before
rc, as letters), and a version after all of its own pre-releases. So a
fix to the stable release that comes out after a preview of the next
version leaves that preview on the page. A tag that is not v<version>
is no release of the IDE (the runtimes asset's oxt-runtimes-<label>) and
is left out, as a draft is.
"""

import json
import re
import sys

# v<numbers with dots>[-<pre-release parts with dots>][+<build>]: every tag
# tools/pages/build_pages.py takes as a release (its --release, --preview)
TAG = re.compile(r'^v(?P<core>[0-9]+(?:\.[0-9]+)*)(?:-(?P<pre>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
                 r'(?:\+[0-9A-Za-z.-]+)?\Z')


def order(tag):
    """What a release tag sorts by, or None for a tag that is not
    v<version>: the version's numbers, then a finished version after its
    pre-releases, then the pre-release parts (a number before a word,
    numbers by value, words by their letters, fewer parts first)."""
    m = TAG.match(tag or '')
    if not m:
        return None
    core = tuple(int(n) for n in m.group('core').split('.'))
    if m.group('pre') is None:
        return (core, 1, ())
    return (core, 0, tuple((0, int(part), '') if part.isdigit() else (1, 0, part)
                           for part in m.group('pre').split('.')))


def pick(releases):
    """(stable, preview) among releases, the rows of gh release list
    --json tagName,isPrerelease: each a tag, or '' for none."""
    stable = preview = None
    for row in releases:
        tag = row.get('tagName')
        key = order(tag)
        if key is None or row.get('isDraft'):
            continue
        if row.get('isPrerelease') or key[1] == 0:
            if preview is None or key > preview[0]:
                preview = (key, tag)
        elif stable is None or key > stable[0]:
            stable = (key, tag)
    if stable and preview and preview[0] <= stable[0]:
        preview = None
    return (stable[1] if stable else '', preview[1] if preview else '')


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    try:
        with open(sys.argv[1], encoding='utf-8') as f:
            releases = json.load(f)
        if not isinstance(releases, list) or not all(isinstance(row, dict) for row in releases):
            raise ValueError('not a list of releases')
    except (OSError, ValueError) as e:
        print('pick_releases.py: %s: %s' % (sys.argv[1], e), file=sys.stderr)
        sys.exit(1)
    print('stable=%s\npreview=%s' % pick(releases))


if __name__ == '__main__':
    main()
