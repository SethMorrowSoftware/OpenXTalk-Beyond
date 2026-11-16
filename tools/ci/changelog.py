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

"""The changelog fragments of changelog/, and folding them into
CHANGELOG.md.

  python3 tools/ci/changelog.py check [--base COMMIT]
  python3 tools/ci/changelog.py fold [--dry-run]

Every pull request used to add its lines to the end of the "Unreleased"
section of CHANGELOG.md, so each merge left every other open pull request
in conflict on that one file, and the merge of main that settled it built
all three platforms again. Now a pull request writes its lines to a file
of its own, changelog/<name>.md (any name no other pull request uses:
its branch's with any "/" made a "-", or its number once it has
one), in CHANGELOG.md's own form,
one "- " line per change ending with the pull request's number:

  - Tools palette: long names shrink or wrap instead of being cut off (#168)

check (CI checks, on every pull request and push): changelog/ holds
only .md files (a folder, as a branch name with a "/" would make, is an
error, since fold would miss it), every fragment holds at least one line, every line that is not empty starts with "- ", none is
a heading, each ends with its pull request's number as every line of
CHANGELOG.md does ("(#168)", or "(#511, #513)" for more than one), no
line of it is in CHANGELOG.md already (a fragment folded
once and come back, as two did after 0.2.7-rc.6.15's squash), and
CHANGELOG.md has at most one "## Unreleased" section.

check --base COMMIT (what CI runs, with HEAD^1: the base of a pull
request's merge commit, and main as it was before a push): also, no
pull request's lines are lost. Every pull request with a line in a
fragment COMMIT has must still have one, in a fragment or in
CHANGELOG.md (where a fold puts them). #508 came from a branch whose
name #502's had been, wrote its fragment under that name, and so wrote
its two lines over #502's five; nothing saw it, and the fold for
0.2.8-dp.2 would have left #502 out of the release notes. A line may
be reworded, and one of several removed: what is refused is a pull
request left with none. A COMMIT that cannot be read is an error, not
a pass.

fold (the pull request that sets a release's version, before it renames
"## Unreleased" to the version; BUILDING.md, "Making a release"): appends
the fragments' lines to the end of "## Unreleased" (made above the newest
release's section when there is none), in the order the fragments came
into main (the first-parent commit that added each, from git: a merge
commit counts when it was merged, not when its branch was written; by
name when git cannot tell, as in a shallow clone), and deletes the
fragments. So
CHANGELOG.md reads exactly as it did when the lines were added to it by
hand. changelog/README.md is not a fragment. Only the Python 3 standard
library is used.
"""

import argparse
import os
import re
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHANGELOG = 'CHANGELOG.md'
FRAGMENTS = 'changelog'
README = 'README.md'
UNRELEASED = '## Unreleased'
# How a line ends: the pull request it came from, or several
NUMBERED = re.compile(r'\((#\d+(?:, #\d+)*)\)$')


class ChangelogError(Exception):
    pass


def fragment_names(repo):
    folder = os.path.join(repo, FRAGMENTS)
    if not os.path.isdir(folder):
        return []
    return sorted(f for f in os.listdir(folder)
                  if f.endswith('.md') and f != README
                  and os.path.isfile(os.path.join(folder, f)))


def strays(repo):
    """What changelog/ holds besides its fragments and README.md: a
    folder (a fragment named after a branch with a "/" in it), or a file
    that is not .md, which fold would leave out."""
    folder = os.path.join(repo, FRAGMENTS)
    if not os.path.isdir(folder):
        return []
    return sorted(f for f in os.listdir(folder)
                  if f != README and not (f.endswith('.md')
                                          and os.path.isfile(os.path.join(folder, f))))


def pull_requests(line):
    """The numbers of the pull requests a line names at its end ("(#168)",
    "(#511, #513)"); empty when it names none there."""
    found = NUMBERED.search(line.rstrip())
    return found.group(1).replace('#', '').split(', ') if found else []


def fragment_lines(repo, name):
    """The "- " lines of a fragment; an error for anything else in it,
    and for a line that does not end with its pull request's number."""
    path = os.path.join(repo, FRAGMENTS, name)
    with open(path, encoding='utf-8') as f:
        text = f.read()
    lines = []
    for number, line in enumerate(text.splitlines(), 1):
        line = line.rstrip()
        if not line:
            continue
        if not line.startswith('- ') or not line[2:].strip():
            raise ChangelogError('%s/%s, line %d: not a "- " line: %r'
                                 % (FRAGMENTS, name, number, line))
        if not pull_requests(line):
            raise ChangelogError('%s/%s, line %d: does not end with its pull request\'s '
                                 'number, as "(#168)" (or "(#511, #513)"): %r'
                                 % (FRAGMENTS, name, number, line[-60:]))
        lines.append(line)
    if not lines:
        raise ChangelogError('%s/%s holds no "- " line' % (FRAGMENTS, name))
    return lines


def read_changelog(repo):
    with open(os.path.join(repo, CHANGELOG), encoding='utf-8') as f:
        return f.read().split('\n')


def unreleased_count(lines):
    return sum(1 for line in lines if line.rstrip() == UNRELEASED)


def git_text(repo, commit, path):
    """A file as a commit has it; None when the commit has none (or git
    cannot say)."""
    try:
        return subprocess.run(['git', 'show', '%s:%s' % (commit, path)], cwd=repo,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              check=True).stdout.decode('utf-8', 'replace')
    except (OSError, subprocess.CalledProcessError):
        return None


def dash_lines(text):
    return [line.rstrip() for line in text.splitlines()
            if line.startswith('- ') and line[2:].strip()]


def held(repo, commit=None):
    """What the working tree holds, or what a commit does: ({fragment:
    its "- " lines}, CHANGELOG.md's "- " lines). Read as they are: a
    fragment with something else in it is check's to report."""
    if commit is None:
        fragments = {}
        for name in fragment_names(repo):
            with open(os.path.join(repo, FRAGMENTS, name), encoding='utf-8') as f:
                fragments[name] = dash_lines(f.read())
        return fragments, dash_lines('\n'.join(read_changelog(repo)))
    try:
        listed = subprocess.run(['git', 'ls-tree', '-z', '--name-only', commit, FRAGMENTS + '/'],
                                cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                check=True).stdout.decode('utf-8', 'replace').split('\0')
    except (OSError, subprocess.CalledProcessError):
        listed = []
    fragments = {}
    for path in listed:
        name = path[len(FRAGMENTS) + 1:]
        if not name.endswith('.md') or name == README:
            continue
        text = git_text(repo, commit, path)
        # (None for a folder named like a fragment: not one)
        if text is not None:
            fragments[name] = dash_lines(text)
    return fragments, dash_lines(git_text(repo, commit, CHANGELOG) or '')


def lost(repo, base, head=None):
    """The pull requests' lines that the fragments of the commit base
    hold and the working tree (or the commit head) has lost, as a list
    of problems.

    A line is kept when it is still there word for word, in any fragment
    or in CHANGELOG.md (a fold moves it there). A line that is not, is
    lost when a pull request it names has no line left at all: so a line
    may be reworded, and one of a pull request's several removed, but a
    fragment written over by another pull request's (#508's over #502's,
    under a branch name used twice) or deleted without a fold is seen.
    A line that names no pull request (five were merged before check
    asked for the number) may only gain its number."""
    if base.startswith('-') or git_lines(repo, 'rev-parse', '--verify', '--quiet',
                                         base + '^{commit}') is None:
        return ['cannot read the commit %s, so cannot tell whether a line of its fragments is '
                'lost (no git here, or a clone without its history)' % base]
    before = held(repo, base)[0]
    fragments, entered = held(repo, head)
    here = set(entered)
    for lines in fragments.values():
        here.update(lines)
    named = set(number for line in here for number in pull_requests(line))
    problems = []
    for name in sorted(before):
        gone, unnamed = [], set()
        for line in before[name]:
            if line in here:
                continue
            numbers = pull_requests(line)
            if numbers:
                missing = [number for number in numbers if number not in named]
                if not missing:
                    continue
                unnamed.update(missing)
            elif any(other.startswith(line + ' (#') and pull_requests(other) for other in here):
                continue
            gone.append(line)
        if not gone:
            continue
        whose = ('no line is left of ' + ', '.join('#' + number for number in sorted(unnamed, key=int))
                 if unnamed else 'it named no pull request, so it may only gain its number')
        problems.append('%s/%s: %d of the lines it has in %s are gone from the fragments and are not '
                        'in %s (%r), and %s. Put them back: a fragment that takes the name of an '
                        'earlier one writes over its lines, so name it after the pull request\'s number'
                        % (FRAGMENTS, name, len(gone), base, CHANGELOG, gone[0][:90], whose))
    return problems


def check(repo, base=None):
    """Every problem found, as a list of messages (empty when none).
    With base, a commit: also the lines its fragments hold that are lost
    here (see lost)."""
    problems = ['%s/%s is not a fragment: write changelog/<name>.md, with no "/" in the name'
                % (FRAGMENTS, name) for name in strays(repo)]
    # A fragment whose lines CHANGELOG.md already holds was folded and has
    # come back (a squash that took an older merge base restored two that
    # 0.2.7-rc.6.15's fold deleted): the next fold would write them twice
    entered = set(line.rstrip() for line in read_changelog(repo))
    for name in fragment_names(repo):
        try:
            lines = fragment_lines(repo, name)
        except ChangelogError as e:
            problems.append(str(e))
            continue
        folded_already = [line for line in lines if line in entered]
        if folded_already:
            problems.append('%s/%s: %d of its lines are already in %s (%r): it was folded, delete it'
                            % (FRAGMENTS, name, len(folded_already), CHANGELOG, folded_already[0]))
    if unreleased_count(read_changelog(repo)) > 1:
        problems.append('%s has more than one "%s" section' % (CHANGELOG, UNRELEASED))
    if base is not None:
        problems.extend(lost(repo, base))
    return problems


def git_lines(repo, *args):
    """The lines git prints, or None when it fails (no git, no repository)."""
    try:
        return subprocess.run(['git'] + list(args), cwd=repo, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, universal_newlines=True,
                              check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        return None


def ordered(repo, names):
    """Fragments in the order they were merged: the position on main's
    first-parent history of the commit that brought each one in (for a
    pull request merged with a merge commit, that merge, whenever its
    branch's own commits were made). Uncommitted fragments come last, and
    those git cannot place (no git, a shallow clone) go by name."""
    history = git_lines(repo, 'rev-list', '--first-parent', '--reverse', 'HEAD') or []
    position = dict((sha, i) for i, sha in enumerate(history))

    def key(name):
        # --first-parent: a merge's diff against its first parent, so the
        # merge that brought a branch's fragment in is the commit that
        # added it
        added = git_lines(repo, 'log', '--first-parent', '--diff-filter=A', '--format=%H',
                          '--', FRAGMENTS + '/' + name) or []
        at = position.get(added[-1]) if added else None
        return (at is None, at or 0, name)
    return sorted(names, key=key)


def folded(lines, new_lines):
    """CHANGELOG.md's lines with new_lines at the end of its Unreleased
    section (made above the first release's section if there is none)."""
    lines = list(lines)
    if unreleased_count(lines) == 0:
        first = next((i for i, line in enumerate(lines) if line.startswith('## ')), None)
        if first is None:
            raise ChangelogError('%s has no "## " section to put "%s" above'
                                 % (CHANGELOG, UNRELEASED))
        lines[first:first] = [UNRELEASED, '']
    start = next(i for i, line in enumerate(lines) if line.rstrip() == UNRELEASED)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('## ')),
               len(lines))
    # after the section's last line that is not empty
    last = end - 1
    while last > start and not lines[last].strip():
        last -= 1
    if last == start:
        # an empty section: its lines start after one empty line, and the
        # empty lines it had stay below them, before the next section
        insert = [''] + new_lines
        if start + 1 >= len(lines) or lines[start + 1].strip():
            insert.append('')
        lines[start + 1:start + 1] = insert
    else:
        lines[last + 1:last + 1] = new_lines
    return lines


def fold(repo, dry_run=False):
    """Fold every fragment into CHANGELOG.md and delete it; the lines
    added, in order."""
    problems = check(repo)
    if problems:
        raise ChangelogError('\n'.join(problems))
    names = ordered(repo, fragment_names(repo))
    new_lines = [line for name in names for line in fragment_lines(repo, name)]
    if not new_lines:
        return []
    lines = folded(read_changelog(repo), new_lines)
    if not dry_run:
        with open(os.path.join(repo, CHANGELOG), 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines))
        for name in names:
            os.remove(os.path.join(repo, FRAGMENTS, name))
    return new_lines


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=REPO, help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest='command')
    sub.required = True
    p = sub.add_parser('check', help='check the fragments and CHANGELOG.md')
    p.add_argument('--base', metavar='COMMIT',
                   help='also: no pull request with a line in the fragments COMMIT has is left '
                        'with none (CI gives HEAD^1)')
    p = sub.add_parser('fold', help='fold the fragments into CHANGELOG.md')
    p.add_argument('--dry-run', action='store_true',
                   help='print the lines, change nothing')
    args = parser.parse_args(argv)
    try:
        if args.command == 'check':
            problems = check(args.repo, args.base)
            for problem in problems:
                print('ERROR: ' + problem)
            if problems:
                return 1
            print('%d changelog fragment(s), all well formed' % len(fragment_names(args.repo))
                  + ('; no line of %s\'s fragments is lost' % args.base if args.base else ''))
            return 0
        added = fold(args.repo, args.dry_run)
        for line in added:
            print(line)
        print('%s %d line(s) under "%s"' % ('Would add' if args.dry_run else 'Added',
                                            len(added), UNRELEASED))
        return 0
    except ChangelogError as e:
        print('ERROR: %s' % e)
        return 1


if __name__ == '__main__':
    sys.exit(main())
