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

"""The inventory of a finished package's binaries: where each came from.

    python3 tools/ci/release_inventory.py ROOT --platform PLATFORM
        [--commit SHA] [--out FILE] [--fail-on-unknown]

ROOT is an installed or extracted package (the folder with the IDE's
executable, or the .app). PLATFORM is the package's own, as
tools/oxt/external-assets.json's excludes name them: win-x86_64,
win-x86, linux-x86_64, linux-x86, linux-arm64 or mac-universal.

Every ELF, Mach-O and PE file below ROOT (symbolic links are skipped, and
so is *.dbg/*.dSYM debug information) gets one JSON record: its path,
size, sha256, format, architectures, the oldest system it loads on
(tools/oxt/binfmt.py: the glibc and libstdc++ symbol versions of an ELF
file, the macOS minimum of each Mach-O slice), and its origin:

  built          built from this repository (at --commit)
  runtimes       a standalone runtime for another platform, from the
                 runtimes asset (external-assets.json), built from the
                 commit its record names
  runtimes-1.15  the Android runtime in that asset, carried over from
                 oxt-runtimes-1.15 and built from no commit here
  xtalk          an xTalk Suite library (tools/oxt/xtalk-extensions.json):
                 the member, its repository and pinned commit, and whether
                 the file's sha256 is the pinned one
  cef            the Chromium Embedded Framework, prebuilt (thirdparty)
  unknown        none of these: listed, and with --fail-on-unknown an
                 error

The record goes to --out (default: standard output). Under GitHub Actions
a summary goes to the job summary, and an xTalk library whose sha256 is
not the pinned one or a binary of unknown origin is a warning. Nothing is
uploaded with a release: the build workflows keep the file as a CI
artifact (modernization report MOD-09). Exit status 0, or 1 with
--fail-on-unknown when any origin is unknown.
"""

import argparse
import fnmatch
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OXT = os.path.join(REPO, 'tools', 'oxt')
sys.path.insert(0, OXT)

import binfmt  # noqa: E402

ASSETS = os.path.join(OXT, 'external-assets.json')
XTALK = os.path.join(OXT, 'xtalk-extensions.json')
PLATFORMS = ('win-x86_64', 'win-x86', 'linux-x86_64', 'linux-x86', 'linux-arm64', 'mac-universal')

# What the runtimes asset holds (tools/oxt/make_runtimes_asset.py): the
# Windows and Linux runtimes, the Android runtime, and the timezone
# library's code for those platforms; a package's own build makes what the
# asset record excludes for it
ASSET_RUNTIMES = ('Runtime/Windows/x86-32/', 'Runtime/Windows/x86-64/', 'Runtime/Linux/x86-32/',
                  'Runtime/Linux/x86-64/')
ANDROID_RUNTIME = 'Runtime/Android/'
TIMEZONE_CODE = 'Extensions/com.livecode.library.timezone/code/'
ASSET_TIMEZONE = ('x86-win32', 'x86_64-win32', 'x86-linux', 'x86_64-linux')

COMMIT_RE = re.compile(r'\bcommit ([0-9a-f]{7,40})\b')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def runtimes_record(path=ASSETS):
    """{id, commit, exclude} of the runtimes asset."""
    with open(path, encoding='utf-8') as f:
        assets = json.load(f).get('assets', [])
    for a in assets:
        if str(a.get('id', '')).startswith('oxt-runtimes-'):
            commits = COMMIT_RE.findall(a.get('source', ''))
            return {'id': a['id'], 'commit': commits[0] if commits else None, 'exclude': a.get('exclude', {})}
    return None


def xtalk_pins(path=XTALK):
    """{extension folder: (member, repository, commit, {file name: set of sha256})}"""
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    pins = {}
    for m in data.get('members', []):
        hashes = {}
        for item in m.get('files', []):
            if item.get('role') == 'library':
                hashes.setdefault(os.path.basename(item['path']), set()).add(item['sha256'])
        for folder in m.get('extensions', []) or []:
            name = folder if isinstance(folder, str) else folder.get('folder') or folder.get('name')
            if name:
                pins[name] = (m['name'], m['repository'], m['commit'], hashes)
    return pins


def excluded(rel, platform, exclude):
    """True when the runtimes asset leaves rel out of platform's packages."""
    for key, patterns in exclude.items():
        if fnmatch.fnmatchcase(platform, key):
            for pattern in patterns:
                if fnmatch.fnmatchcase(rel, pattern.replace('**', '*')):
                    return True
    return False


def package_path(rel):
    """The path as the runtimes asset and the layout name it: a Mac app's
    Contents/Tools/ is the other platforms' package root."""
    if rel.startswith('Contents/Tools/'):
        return rel[len('Contents/Tools/'):]
    return rel


def origin_of(rel, platform, runtimes, pins, digest):
    """(origin, details) for the binary at rel."""
    p = package_path(rel)
    parts = p.split('/')
    cef = 'CEF' in parts or 'Chromium Embedded Framework.framework' in parts or parts[-1].startswith('libcef')
    if parts[0] == 'Extensions' and len(parts) > 3 and parts[2] == 'code' and parts[1] in pins:
        member, repository, commit, hashes = pins[parts[1]]
        pinned = hashes.get(parts[-1])
        details = {'member': member, 'repository': repository, 'commit': commit,
                   'pinned': None if pinned is None else digest in pinned}
        if platform.startswith('mac-') and parts[3] == 'universal-mac':
            # the app's signing (tools/ci/sign_mac_app.py) signs the Mac
            # libraries again, which changes their bytes
            details['pinned'] = None
            details['note'] = 'signed with the app: not compared with the pin'
        return 'xtalk', details
    if p.startswith(ANDROID_RUNTIME) or (p.startswith(TIMEZONE_CODE) and 'android' in parts[3]):
        return 'runtimes-1.15', {'asset': runtimes['id'] if runtimes else None}
    in_asset = p.startswith(ASSET_RUNTIMES) or (p.startswith(TIMEZONE_CODE) and parts[3] in ASSET_TIMEZONE)
    if in_asset and runtimes and not excluded(p, platform, runtimes['exclude']):
        details = {'asset': runtimes['id'], 'commit': runtimes['commit']}
        if cef:
            details['cef'] = True
        return 'runtimes', details
    if cef:
        return 'cef', {}
    if built_here(p, rel, platform):
        return 'built', {}
    return 'unknown', {}


def built_here(p, rel, platform):
    """What this repository's build makes, by where the package puts it."""
    top = p.split('/')[0]
    if rel.startswith('Contents/MacOS/') or rel.startswith('Contents/Frameworks/'):
        return True
    if top in ('Externals', 'Toolchain', 'Runtime'):
        return True
    if p.startswith('Ext/mergJSON/'):
        return True
    if p.startswith('Extensions/'):
        # the extensions built from extensions/, and the timezone
        # library's code for the package's own platform
        return True
    # the IDE's executable and the libraries beside it
    return '/' not in p


def walk(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.endswith('.dSYM'))
        for name in sorted(files):
            path = os.path.join(folder, name)
            if os.path.islink(path) or name.endswith('.dbg'):
                continue
            yield path, os.path.relpath(path, root).replace(os.sep, '/')


def floors_of(path, kind):
    if kind not in ('elf', 'macho'):
        return {}
    try:
        info = binfmt.parse(path)
    except (binfmt.FormatError, Exception):  # noqa: BLE001 - a file it cannot read keeps no floor
        return {}
    if kind == 'macho' and len(info.slices) > 1:
        return {'macOS': {arch: binfmt.version_text(s.floors['macOS'])
                          for arch, s in zip(info.archs, info.slices) if 'macOS' in s.floors}}
    return {k: binfmt.version_text(v) for k, v in info.floors.items()}


def inventory(root, platform, commit=None, assets=ASSETS, xtalk=XTALK):
    runtimes = runtimes_record(assets)
    pins = xtalk_pins(xtalk)
    records = []
    for path, rel in walk(root):
        try:
            kind, archs = binfmt.arch_of(path)
        except OSError:
            continue
        if not kind:
            continue
        digest = sha256(path)
        origin, details = origin_of(rel, platform, runtimes, pins, digest)
        if origin == 'built' and commit:
            details = {'commit': commit}
        records.append({'path': rel, 'size': os.path.getsize(path), 'sha256': digest, 'format': kind,
                        'archs': archs, 'floors': floors_of(path, kind), 'origin': origin,
                        'details': details})
    return {'platform': platform, 'commit': commit, 'runtimes_asset': runtimes, 'binaries': records}


def summarise(inv):
    counts = {}
    for r in inv['binaries']:
        counts[r['origin']] = counts.get(r['origin'], 0) + 1
    unknown = [r['path'] for r in inv['binaries'] if r['origin'] == 'unknown']
    unpinned = [r['path'] for r in inv['binaries'] if r['origin'] == 'xtalk' and r['details']['pinned'] is False]
    lines = ['### Release inventory (%s)' % inv['platform'], '',
             '%d binaries: %s.' % (len(inv['binaries']),
                                   ', '.join('%d %s' % (n, o) for o, n in sorted(counts.items()))), '']
    rt = inv['runtimes_asset']
    if rt:
        lines.append('Runtimes asset: `%s`, built from commit `%s`.' % (rt['id'], (rt['commit'] or '?')[:12]))
    for title, items in (('Unknown origin', unknown), ('xTalk libraries not as pinned', unpinned)):
        if items:
            lines += ['', '**%s:**' % title] + ['- `%s`' % p for p in items]
    return '\n'.join(lines) + '\n', unknown, unpinned


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('root', help='the package (its root folder, or the .app)')
    ap.add_argument('--platform', required=True, choices=PLATFORMS, help='the package\'s own platform')
    ap.add_argument('--commit', default=None, help='the commit the package was built from')
    ap.add_argument('--out', default=None, help='the JSON file to write (default: standard output)')
    ap.add_argument('--fail-on-unknown', action='store_true', help='exit 1 when a binary\'s origin is unknown')
    args = ap.parse_args(argv)
    if not os.path.isdir(args.root):
        ap.error('%s is not a folder' % args.root)
    inv = inventory(args.root, args.platform, args.commit, ASSETS, XTALK)
    text = json.dumps(inv, indent=1, sort_keys=True) + '\n'
    if args.out:
        with open(args.out, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    summary, unknown, unpinned = summarise(inv)
    sys.stderr.write(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as f:
            f.write(summary + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in unknown:
            print('::%s title=Release inventory::%s: origin unknown'
                  % ('error' if args.fail_on_unknown else 'warning', p), file=sys.stderr)
        for p in unpinned:
            print('::warning title=Release inventory::%s: not the sha256 xtalk-extensions.json pins' % p,
                  file=sys.stderr)
    return 1 if unknown and args.fail_on_unknown else 0


if __name__ == '__main__':
    sys.exit(main())
