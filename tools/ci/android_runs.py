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

"""What a change needs of android-engine.yml: whether the Android engine is
built (and run on the emulator), and whether the script tests run on the
emulator, with the engine built in this run or with one an earlier run on
main built from the same engine sources.

  python3 tools/ci/android_runs.py gate --event NAME --repo OWNER/NAME
      --sha SHA [--pr N] [--before SHA] [--output FILE] [--summary FILE]

The workflow starts for any change but the documentation's, the
installers', the changelog's and the other workflows' (its paths), and
its first job runs this:

  - the engine is built when the change touches what it is built from
    (ENGINE_PATHS, the paths the workflow started for until 0.2.8-dp.2:
    every file but those of the IDE, the documentation, the tests, the
    installers, the changelog, the Markdown files, the other workflows and
    the CI scripts, and with them the workflow and the scripts that build
    and check the engine), on a workflow_dispatch, and whenever the change
    cannot be read;
  - the script tests run when the engine is built, and when the change
    touches what they read (the tests' inputs): tests/, the files of the
    checkout the tests read and the IDE folders of the checkout they test
    (android_tests.copy_files), the checkout's Android builder that the
    tests' standalone is built with (android_check.OVERLAY), and the
    scripts that build and run it. Until 0.2.8-dp.2 a change to these alone
    started nothing, so that a test that failed on Android was first seen
    on main (#556's six tests of the pointer, #567).

When the tests run and the engine is not built, they take the engine of
the newest run of this workflow on main whose four build jobs passed and
whose four folders are still there (ENGINE_ARTIFACTS), and whose commit
has the same engine sources as this change's: GitHub's comparison of the
two commits, both ways, names no file of ENGINE_PATHS. If there is none
(of the newest RUNS_LOOKED_AT runs), the engine is built after all.

The decision is written to --output (GitHub's step outputs): engine=true
or false, tests=true or false, engine_run=<run id> or empty, and said in
the log and in --summary. GitHub's API is asked through the gh command
(GH_TOKEN).
"""

import argparse
import functools
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

WORKFLOW = 'android-engine.yml'

# What the engine and its externals are built from, as GitHub's paths
# filters read them: in order, and the last pattern that matches a file
# says whether it is in (a "!" pattern leaves it out)
ENGINE_PATHS = (
    '**',
    '!ide/**',
    '!ide-support/**',
    '!docs/**',
    '!tests/**',
    '!Installer/**',
    '!changelog/**',
    '!**.md',
    '!.github/**',
    '!tools/**',
    '.github/workflows/android-engine.yml',
    'tools/ci/build-android.sh',
    'tools/ci/android_engine.py',
    'tools/ci/android_java.py',
    'tools/ci/android_tests.py',
    'tools/ci/android-tests.livecodescript',
    'tools/ci/android-tests-baseline-*.txt',
    'tools/javac_wrapper.sh',
    'tools/pathify.sh',
)

# The scripts the tests job runs, beside the engine's
TESTS_SCRIPTS = (
    'tools/ci/android_runs.py',
    'tools/ci/android_tests.py',
    'tools/ci/android-tests.livecodescript',
    'tools/ci/android-tests-baseline-*.txt',
    'tools/ci/android_check.py',
    'tools/ci/android-check.livecodescript',
    'tools/ci/android_engine.py',
    'tools/ci/run_engine_tests.py',
    '.github/workflows/android-engine.yml',
)

# The build jobs, and the folders they upload (one an architecture)
BUILD_JOBS = ('Android engine (arm64)', 'Android engine (armv7)', 'Android engine (x86)',
              'Android engine (x86_64)')
ENGINE_ARTIFACTS = ('android-engine-arm64-v8a', 'android-engine-armeabi-v7a', 'android-engine-x86',
                    'android-engine-x86_64')
RUNS_LOOKED_AT = 20
# GitHub's comparison of two commits names at most this many files: one
# that names as many may have left some out
COMPARE_FILES = 300
# A pull request's list of files has at most this many
PR_FILES = 3000


def log(text=''):
    print(text, flush=True)


@functools.lru_cache(maxsize=None)
def glob_regex(pattern):
    """A paths filter's pattern as a regular expression: ** is any
    characters, / among them; * and ? are any characters and one character
    but /."""
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith('**/', i):
            out.append('(?:.*/)?')
            i += 3
        elif pattern.startswith('**', i):
            out.append('.*')
            i += 2
        elif pattern[i] == '*':
            out.append('[^/]*')
            i += 1
        elif pattern[i] == '?':
            out.append('[^/]')
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile('^%s$' % ''.join(out))


def matches(path, patterns):
    """Whether a paths filter of these patterns takes the file path."""
    taken = False
    for pattern in patterns:
        leave = pattern.startswith('!')
        if glob_regex(pattern[1:] if leave else pattern).match(path):
            taken = not leave
    return taken


def tests_inputs(repo=REPO):
    """The patterns of what the script tests read of the checkout: tests/,
    the checkout's files and IDE folders that they read
    (android_tests.copy_files), and each path they name that is not there
    (android_tests.named_paths: a change that deletes or moves one is a
    change to what they read; #595's review), the Android builder the
    tests' standalone is built with (android_check.OVERLAY), and the
    scripts that build and run it."""
    import android_check
    import android_tests
    patterns = ['tests/**']
    for path in android_tests.copy_files(repo, None)[3]:
        # a folder (copied whole), or a file. A folder a test names a file
        # of as it runs ("/Toolset/palettes/" & pFile, in
        # tests/lcs/replicate/padlocks) is ide/Toolset/palettes//: the
        # pattern is the folder's
        patterns.append(path.rstrip('/') + '/**' if path.endswith('/') else path)
    for path in android_tests.named_paths(repo):
        if not os.path.exists(os.path.join(repo, path)):
            # gone: a file, or a folder
            patterns += [path.rstrip('/'), path.rstrip('/') + '/**']
    patterns += list(android_check.OVERLAY)
    patterns += list(TESTS_SCRIPTS)
    return patterns


def decide(changed, repo=REPO):
    """(engine, tests, why): whether the files changed need the engine
    built, and the script tests run, and why, a line each."""
    engine = sorted(p for p in changed if matches(p, ENGINE_PATHS))
    inputs = tests_inputs(repo)
    tests = sorted(p for p in changed if any(glob_regex(x).match(p) for x in inputs))
    why = []
    if engine:
        why.append('the engine is built: the change touches what it is built from (%s)' % names(engine))
    if tests:
        why.append('the script tests run: the change touches what they read (%s)' % names(tests))
    elif engine:
        why.append('the script tests run with the engine built')
    else:
        why.append('nothing to build or run: the change touches neither the engine nor what the tests read')
    return bool(engine), bool(engine or tests), why


def names(paths, most=5):
    shown = ', '.join(paths[:most])
    return shown + (' and %d more' % (len(paths) - most) if len(paths) > most else '')


def gh_api(path):
    """GitHub's answer to GET path (gh api), as JSON; None when it gives
    none."""
    try:
        out = subprocess.run(['gh', 'api', '-H', 'Accept: application/vnd.github+json', path],
                             capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        log('gh api %s: %s' % (path, e))
        return None
    if out.returncode != 0:
        log('gh api %s: %s' % (path, (out.stderr or out.stdout).strip()[:300]))
        return None
    try:
        return json.loads(out.stdout)
    except ValueError:
        return None


def changed_files(api, event, repo, sha, pr=None, before=None):
    """The files the change touches (a pull request's, or a push's), or
    None when they cannot be read, or not all of them."""
    if event == 'pull_request':
        files, count, page = [], 0, 1
        while True:
            answer = api('repos/%s/pulls/%s/files?per_page=100&page=%d' % (repo, pr, page))
            if not isinstance(answer, list):
                return None
            count += len(answer)
            for f in answer:
                files.append(f['filename'])
                if f.get('previous_filename'):
                    files.append(f['previous_filename'])
            if len(answer) < 100:
                break
            page += 1
        if count >= PR_FILES:
            return None
        return files
    if event == 'push':
        if not before or not before.strip('0'):
            return None
        return compared(api, repo, before, sha)
    return None


def compared(api, repo, base, head):
    """The files that differ from the commits' common ancestor to head
    (GitHub's comparison base...head), or None when it does not say all."""
    answer = api('repos/%s/compare/%s...%s' % (repo, base, head))
    if not isinstance(answer, dict) or not isinstance(answer.get('files'), list):
        return None
    if len(answer['files']) >= COMPARE_FILES:
        return None
    files = []
    for f in answer['files']:
        files.append(f['filename'])
        if f.get('previous_filename'):
            files.append(f['previous_filename'])
    return files


def engine_run(api, repo, sha):
    """(run id, why) of the newest run on main whose engine this commit's
    tests can take: its four build jobs passed, its four folders are there,
    and its commit's engine sources are this one's; (None, why) if no run
    of the newest RUNS_LOOKED_AT is."""
    runs = api('repos/%s/actions/workflows/%s/runs?branch=main&status=completed&per_page=%d'
               % (repo, WORKFLOW, RUNS_LOOKED_AT))
    if not isinstance(runs, dict):
        return None, 'the runs on main could not be read'
    for run in runs.get('workflow_runs', []):
        rid = run['id']
        jobs = api('repos/%s/actions/runs/%s/jobs?per_page=100' % (repo, rid))
        if not isinstance(jobs, dict):
            continue
        passed = set(j['name'] for j in jobs.get('jobs', []) if j.get('conclusion') == 'success')
        if not set(BUILD_JOBS) <= passed:
            continue
        artifacts = api('repos/%s/actions/runs/%s/artifacts?per_page=100' % (repo, rid))
        if not isinstance(artifacts, dict):
            continue
        kept = set(a['name'] for a in artifacts.get('artifacts', []) if not a.get('expired'))
        if not set(ENGINE_ARTIFACTS) <= kept:
            continue
        # both ways: what this commit changed since they parted, and what
        # main changed since then up to the run's commit
        ours = compared(api, repo, run['head_sha'], sha)
        theirs = compared(api, repo, sha, run['head_sha'])
        if ours is None or theirs is None:
            continue
        differ = sorted(set(p for p in ours + theirs if matches(p, ENGINE_PATHS)))
        if differ:
            log('run %s (%s): its engine sources differ (%s)' % (rid, run['head_sha'][:10], names(differ)))
            continue
        return rid, ('the engine of run %s on main (%s), built from the same engine sources'
                     % (rid, run['head_sha'][:10]))
    return None, 'no run of the newest %d on main has an engine of the same sources to take' % RUNS_LOOKED_AT


def gate(args, api=gh_api):
    if args.event == 'workflow_dispatch':
        engine, tests, why = True, True, ['started by hand: the engine is built and everything runs']
    else:
        changed = changed_files(api, args.event, args.repo, args.sha, args.pr, args.before)
        if changed is None:
            engine, tests, why = True, True, ['the change\'s files could not all be read: the engine is built']
        else:
            engine, tests, why = decide(changed)
    run = ''
    if tests and not engine:
        found, said = engine_run(api, args.repo, args.sha)
        if found:
            run = str(found)
        else:
            engine = True
            said += ': the engine is built'
        why.append(said)
    for line in why:
        log(line)
    log('engine=%s tests=%s engine_run=%s' % (str(engine).lower(), str(tests).lower(), run))
    if args.output:
        with open(args.output, 'a', encoding='utf-8') as f:
            f.write('engine=%s\ntests=%s\nengine_run=%s\n' % (str(engine).lower(), str(tests).lower(), run))
    if args.summary:
        with open(args.summary, 'a', encoding='utf-8') as f:
            f.write('### What this run builds and runs\n\n')
            for line in why:
                f.write('- %s\n' % line)
            f.write('\n')
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    g = sub.add_parser('gate', help='what the change needs, as step outputs')
    g.add_argument('--event', required=True, help='github.event_name')
    g.add_argument('--repo', required=True, help='OWNER/NAME')
    g.add_argument('--sha', required=True, help='the commit the run is of (github.sha)')
    g.add_argument('--pr', help='the pull request\'s number')
    g.add_argument('--before', help='a push\'s commit before it')
    g.add_argument('--output', help='the step\'s outputs file ($GITHUB_OUTPUT)')
    g.add_argument('--summary', help='the job\'s summary ($GITHUB_STEP_SUMMARY)')
    args = ap.parse_args(argv)
    return gate(args)


if __name__ == '__main__':
    sys.exit(main())
