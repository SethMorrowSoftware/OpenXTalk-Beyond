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

"""The files the Box2Dxt platformer sample is built from, as pinned.

  python3 tools/web-player/box2dxt_platformer_files.py --out DIR [--local SUITE]

The platformer (seven scrolling levels, the xTalk Suite's
box2dxt/examples/box2dxt-platformer.livecodescript, with the b2k Game Kit
carried inside it) and the five Kenney sheets it draws from (CC0, the
suite's box2dxt/Spritesheets) are not kept in this repository: like the
suite's extensions, they are taken from the suite at the commit
box2dxt-platformer/pin.json names, each checked against its SHA-256 and
size. DIR then holds box2dxt-platformer.livecodescript and Spritesheets/,
which box2dxt-platformer.livecodescript (the builder, run by an engine with
OXT_PLATFORMER_FILES=DIR) makes stacks/Box2Dxt Platformer.oxtstack from.

With --local, the files are read from a checkout of the suite instead
(which should be at the pinned commit: they are checked all the same).

To take a newer platformer, change the commit in pin.json and run
--repin (with --local at that commit), which rewrites each file's size and
SHA-256; then build the stack again.
"""

import argparse
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
PIN = os.path.join(HERE, 'box2dxt-platformer', 'pin.json')
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

SCRIPT = 'box2dxt/examples/box2dxt-platformer.livecodescript'
SHEETS = 'box2dxt/Spritesheets/'


class PinError(Exception):
    pass


def load(path=PIN):
    with open(path, encoding='utf-8') as f:
        pin = json.load(f)
    commit = pin.get('commit', '')
    if len(commit) != 40 or any(c not in '0123456789abcdef' for c in commit):
        raise PinError('pin.json: the commit must be a full 40-digit SHA-1')
    paths = [f['path'] for f in pin['files']]
    if SCRIPT not in paths:
        raise PinError('pin.json does not pin %s' % SCRIPT)
    for p in paths:
        if p != SCRIPT and not (p.startswith(SHEETS) and '/' not in p[len(SHEETS):]):
            raise PinError('pin.json: %s is neither the platformer nor one of its sheets' % p)
    return pin


def target_name(path):
    """Where a pinned file goes in DIR."""
    if path == SCRIPT:
        return 'box2dxt-platformer.livecodescript'
    return 'Spritesheets/' + path[len(SHEETS):]


def read(pin, entry, local, log):
    if local:
        with open(os.path.join(local, *entry['path'].split('/')), 'rb') as f:
            return f.read()
    import xtalk_extensions
    url = 'https://raw.githubusercontent.com/%s/%s/%s' % (pin['repository'], pin['commit'], entry['path'])
    return xtalk_extensions._http_get(url, log)


def fetch(out, local=None, log=print, pin=None):
    pin = pin or load()
    for entry in pin['files']:
        body = read(pin, entry, local, log)
        if len(body) != entry['size'] or hashlib.sha256(body).hexdigest() != entry['sha256']:
            raise PinError('%s at %s is not the pinned file (SHA-256 or size differs)'
                           % (entry['path'], pin['commit'][:12]))
        target = os.path.join(out, *target_name(entry['path']).split('/'))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'wb') as f:
            f.write(body)
        log('%s: %d bytes' % (target_name(entry['path']), len(body)))


def repin(local, log=print):
    pin = load()
    for entry in pin['files']:
        with open(os.path.join(local, *entry['path'].split('/')), 'rb') as f:
            body = f.read()
        entry['size'] = len(body)
        entry['sha256'] = hashlib.sha256(body).hexdigest()
    with open(PIN, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(pin, f, indent=1)
        f.write('\n')
    log('pinned %d files at %s' % (len(pin['files']), pin['commit'][:12]))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--out', help='the folder to write the files into')
    p.add_argument('--local', help='a checkout of the xTalk Suite to read them from')
    p.add_argument('--repin', action='store_true', help='rewrite the sizes and SHA-256s from --local')
    args = p.parse_args(argv)
    try:
        if args.repin:
            if not args.local:
                p.error('--repin needs --local')
            repin(args.local)
            return 0
        if not args.out:
            p.error('--out is required')
        fetch(args.out, args.local)
    except PinError as e:
        print('error: %s' % e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
