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

"""The xTalk Suite's native libraries for the web IDE's engine (EXPERIMENTAL).

  python3 tools/web-ide/xtalk_web_libraries.py fetch --out DIR
      [--cache DIR] [--offline] [--local SUITE]
  python3 tools/web-ide/xtalk_web_libraries.py pin --commit SHA [--local SUITE]
  python3 tools/web-ide/xtalk_web_libraries.py localize ARCHIVE OUT --keep NAME
  python3 tools/web-ide/xtalk_web_libraries.py list
  python3 tools/web-ide/xtalk_web_libraries.py test-files --out DIR [--local SUITE]

A browser opens no library, so the web IDE's engine links the suite's
native libraries into itself (engine/src/em-xtalk-web.cpp says how they are
registered). Each member builds one for the web as
src/code/wasm32-emscripten/<name>.a: an archive of ONE WebAssembly object
with the member's shim, its third-party library and <name>_web_exports, the
table of every symbol the member's .lcb binds to. "web_libraries" in
tools/oxt/xtalk-extensions.json pins each archive: its repository, commit,
path, SHA-256 and size, and the Emscripten version it was built with, which
must be this checkout's (config/emscripten-version), since the object is
linked into an engine that Emscripten builds.

fetch downloads the pinned archives into the xTalk cache (the one
tools/oxt/xtalk_extensions.py uses), verifies them, and writes DIR/<name>.o
for each: the archive's object with every symbol it defines made LOCAL but
<name>_web_exports (and what Emscripten itself needs global: an EM_JS
function, an exported or no-strip symbol). The engine reaches a library
only through its table, so nothing else needs a global name, and two
members that carry the same vendored code (trezor-crypto's SHA-3 and
memzero are in both SodiumXT and CoinXT, and libsodium and trezor-crypto
both define blake2b) then link into one engine without clashing.
util/emscripten-javascriptify.py links DIR's objects into the web IDE's
engine and the web standalone engine (--xtalk-objects, which engine.gyp's
javascriptify-development and javascriptify pass; tools/ci/build-web-ide.sh
and tools/ci/build-web.sh fetch them), so HTML5 standalones and the Stack
Player have them too.

--local SUITE takes the archives from a checkout of the xTalk Suite instead
(SUITE/<path>, where <path> is the pinned path), for trying a library
before it is pinned; fetch then says so, and does not check the pin.

pin --commit SHA downloads every library at that commit of its repository
and rewrites its commit, SHA-256 and size (with --local, from the
checkout, which should be at that commit). It does not check that the
commit is on a default branch: these pins are experimental and may point
at a pull request's branch.

localize is the step fetch runs, for one archive.

test-files writes into DIR what tools/ci/web-ide-xtalk.livecodescript (the
browser check of these libraries) runs besides the IDE's extensions, from
the suite at the commit the libraries are pinned at (or from SUITE): the
Hold'em and Box2Dxt platformer apps and DataChannelXT's harness; and
NostrXT's relay library as the NostrXT member is pinned (the file the next
release's IDE ships, checked against the pin; with --local, SUITE's),
prepared as tools/oxt/xtalk_extensions.py bundles a script library, to
replace the IDE's, which comes from the released package the check
builds its site from.

Python 3.8 or later, standard library only.
"""

import argparse
import collections
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import fetch_assets  # noqa: E402
import xtalk_extensions  # noqa: E402

MANIFEST = os.path.join(REPO, 'tools', 'oxt', 'xtalk-extensions.json')
EMSCRIPTEN_VERSION_FILE = os.path.join(REPO, 'config', 'emscripten-version')

# The names the engine registers (engine/src/em-xtalk-web.cpp): a library
# whose name is not here would be linked and never found
KNOWN = ('sodiumxt', 'box2dxt', 'coinxt', 'datachannelxt')


class WebLibraryError(Exception):
    pass


# ---------------------------------------------------------------- manifest

def load(path=MANIFEST):
    with open(path, encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)
    block = data.get('web_libraries')
    if not isinstance(block, dict) or not isinstance(block.get('libraries'), list):
        raise WebLibraryError('%s has no "web_libraries" with a "libraries" list' % path)
    names = set()
    for lib in block['libraries']:
        w = '%s: web library %s' % (path, lib.get('name'))

        def need(cond, msg, w=w):
            if not cond:
                raise WebLibraryError('%s: %s' % (w, msg))

        need(lib.get('name') in KNOWN, 'the name must be one of %s (engine/src/em-xtalk-web.cpp)' % ', '.join(KNOWN))
        need(lib['name'] not in names, 'listed twice')
        names.add(lib['name'])
        need(xtalk_extensions._is_repository(lib.get('repository')), 'bad repository')
        need(xtalk_extensions._is_sha1(lib.get('commit')), 'commit must be a full 40-digit SHA-1')
        need(isinstance(lib.get('path'), str) and lib['path'].endswith('/wasm32-emscripten/%s.a' % lib['name']),
             'path must end with wasm32-emscripten/%s.a' % lib['name'])
        fetch_assets.safe_relpath(lib['path'], what='path')
        need(isinstance(lib.get('sha256'), str) and re.match(r'^[0-9a-f]{64}$', lib['sha256']), 'bad sha256')
        need(isinstance(lib.get('size'), int) and lib['size'] > 0, 'bad size')
        need(isinstance(lib.get('emscripten'), str) and lib['emscripten'], 'emscripten (the version it was built with) missing')
    return data, block


def emscripten_version():
    with open(EMSCRIPTEN_VERSION_FILE, encoding='utf-8') as f:
        return f.readline().strip()


def lib_url(lib):
    return 'https://raw.githubusercontent.com/%s/%s/%s' % (lib['repository'], lib['commit'], lib['path'])


def cache_path(cache, lib):
    return os.path.join(cache, lib['repository'].split('/')[1], lib['commit'], *lib['path'].split('/'))


# ---------------------------------------------------------------- ar

def ar_members(data, what):
    """The members of a System V / GNU ar archive, as (name, bytes), without
    the symbol index and the long-name table."""
    if not data.startswith(b'!<arch>\n'):
        raise WebLibraryError('%s is not an ar archive' % what)
    members = []
    names = b''
    pos = 8
    while pos < len(data):
        if pos + 60 > len(data):
            raise WebLibraryError('%s: a member header is cut short' % what)
        header = data[pos:pos + 60]
        if header[58:60] != b'`\n':
            raise WebLibraryError('%s: a member header is malformed' % what)
        name = header[0:16].rstrip(b' ')
        size = int(header[48:58].strip())
        body = data[pos + 60:pos + 60 + size]
        pos += 60 + size + (size & 1)
        if name in (b'/', b'/SYM64/', b'__.SYMDEF', b'__.SYMDEF SORTED'):
            continue
        if name == b'//':
            names = body
            continue
        if name.startswith(b'/') and name[1:].isdigit():
            start = int(name[1:])
            end = names.index(b'/\n', start)
            name = names[start:end]
        elif name.endswith(b'/'):
            name = name[:-1]
        members.append((name.decode('utf-8', 'replace'), body))
    return members


# ---------------------------------------------------------------- wasm objects

WASM_MAGIC = b'\0asm\x01\0\0\0'
SYMTAB = 8
KIND_FUNCTION, KIND_DATA, KIND_GLOBAL, KIND_SECTION, KIND_TAG, KIND_TABLE = 0, 1, 2, 3, 4, 5
FLAG_WEAK, FLAG_LOCAL, FLAG_UNDEFINED, FLAG_EXPORTED, FLAG_EXPLICIT_NAME, FLAG_NO_STRIP = \
    0x1, 0x2, 0x10, 0x20, 0x40, 0x80


def _uleb(data, pos):
    result = shift = 0
    while True:
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return result, pos
        shift += 7


def _enc(value):
    out = bytearray()
    while True:
        byte = value & 0x7f
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def _keep_global(name, keep):
    # Emscripten finds an EM_JS function, its library dependencies and the
    # start and end of its own sections by name in the linked module
    return name in keep or name.startswith(('__em_js__', '__em_lib_deps', '__start_', '__stop_'))


def localize(obj, keep, what='object'):
    """Return the WebAssembly object obj with every symbol it defines made
    local, but those named in keep and those Emscripten needs (_keep_global)
    or that are exported or kept from stripping. Returns (bytes, the global
    names it kept, the number it made local)."""
    if not obj.startswith(WASM_MAGIC):
        raise WebLibraryError('%s is not a WebAssembly object' % what)
    out = bytearray(obj[:8])
    pos = 8
    found_linking = False
    kept, localized = [], 0
    while pos < len(obj):
        section_id = obj[pos]
        size, body_start = _uleb(obj, pos + 1)
        body = obj[body_start:body_start + size]
        next_pos = body_start + size
        if section_id == 0:
            name_len, p = _uleb(body, 0)
            name = body[p:p + name_len]
            if name == b'linking':
                found_linking = True
                body, kept, localized = _localize_linking(body, p + name_len, keep, what)
        out.append(section_id)
        out += _enc(len(body))
        out += body
        pos = next_pos
    if not found_linking:
        raise WebLibraryError('%s has no linking section: is it a relocatable object (emcc -r, or -c)?' % what)
    missing = [k for k in keep if k not in kept]
    if missing:
        raise WebLibraryError('%s defines no %s' % (what, ', '.join(missing)))
    return bytes(out), kept, localized


def _localize_linking(body, p, keep, what):
    version, p = _uleb(body, p)
    if version != 2:
        raise WebLibraryError('%s: linking section version %d, not 2' % (what, version))
    new = bytearray(body[:p])
    kept, localized = [], 0
    while p < len(body):
        sub_type = body[p]
        sub_len, q = _uleb(body, p + 1)
        payload = body[q:q + sub_len]
        p = q + sub_len
        if sub_type == SYMTAB:
            payload, kept, localized = _localize_symtab(payload, keep, what)
        new.append(sub_type)
        new += _enc(len(payload))
        new += payload
    return bytes(new), kept, localized


def _localize_symtab(payload, keep, what):
    count, p = _uleb(payload, 0)
    out = bytearray(_enc(count))
    kept, localized = [], 0
    for _ in range(count):
        kind = payload[p]
        flags, p = _uleb(payload, p + 1)
        start = p
        name = None
        if kind in (KIND_FUNCTION, KIND_GLOBAL, KIND_TAG, KIND_TABLE):
            _, p = _uleb(payload, p)
            if not flags & FLAG_UNDEFINED or flags & FLAG_EXPLICIT_NAME:
                n, p = _uleb(payload, p)
                name = payload[p:p + n].decode('utf-8')
                p += n
        elif kind == KIND_DATA:
            n, p = _uleb(payload, p)
            name = payload[p:p + n].decode('utf-8')
            p += n
            if not flags & FLAG_UNDEFINED:
                for _ in range(3):
                    _, p = _uleb(payload, p)
        elif kind == KIND_SECTION:
            _, p = _uleb(payload, p)
        else:
            raise WebLibraryError('%s: unknown symbol kind %d' % (what, kind))
        rest = payload[start:p]
        defined = not flags & FLAG_UNDEFINED
        if (defined and kind != KIND_SECTION and not flags & FLAG_LOCAL and name is not None):
            if _keep_global(name, keep) or flags & (FLAG_EXPORTED | FLAG_NO_STRIP):
                kept.append(name)
            else:
                flags = (flags & ~FLAG_WEAK) | FLAG_LOCAL
                localized += 1
        out.append(kind)
        out += _enc(flags)
        out += rest
    if p != len(payload):
        raise WebLibraryError('%s: the symbol table has %d bytes left over' % (what, len(payload) - p))
    return bytes(out), kept, localized


def localize_archive(data, name, what):
    members = [m for m in ar_members(data, what) if m[1].startswith(WASM_MAGIC)]
    if len(members) != 1:
        raise WebLibraryError('%s holds %d WebAssembly objects, not one' % (what, len(members)))
    return localize(members[0][1], [name + '_web_exports'], '%s(%s)' % (what, members[0][0]))


# ---------------------------------------------------------------- commands

def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def cmd_fetch(args, log=print):
    _, block = load(args.manifest)
    version = emscripten_version()
    os.makedirs(args.out, exist_ok=True)
    cache = xtalk_extensions.cache_dir(REPO, args.cache)
    for lib in block['libraries']:
        if lib['emscripten'] != version:
            raise WebLibraryError('%s was built with Emscripten %s, and this checkout builds with %s '
                                  '(config/emscripten-version): rebuild and pin it'
                                  % (lib['name'], lib['emscripten'], version))
        if args.local:
            path = os.path.join(args.local, *lib['path'].split('/'))
            if not os.path.isfile(path):
                raise WebLibraryError('--local: %s does not exist' % path)
            with open(path, 'rb') as f:
                data = f.read()
            note = 'from %s (NOT the pin)' % path
        else:
            path = cache_path(cache, lib)
            if os.path.isfile(path) and fetch_assets.check_file(lib, path) is not None:
                os.remove(path)
            if not os.path.isfile(path):
                asset = collections.OrderedDict([('id', 'web library %s' % lib['name']), ('url', lib_url(lib)),
                                                 ('sha256', lib['sha256']), ('size', lib['size'])])
                try:
                    fetch_assets.fetch(asset, os.path.dirname(path), args.offline, log)
                except fetch_assets.AssetError as e:
                    raise WebLibraryError(str(e))
            with open(path, 'rb') as f:
                data = f.read()
            if _sha256(data) != lib['sha256']:
                raise WebLibraryError('%s: %s does not match its pin' % (lib['name'], path))
            note = '%s at %s' % (lib['repository'], lib['commit'][:12])
        obj, kept, localized = localize_archive(data, lib['name'], lib['name'] + '.a')
        out = os.path.join(args.out, lib['name'] + '.o')
        with open(out, 'wb') as f:
            f.write(obj)
        log('%s: %s, %d bytes; %d symbol(s) made local, global: %s'
            % (lib['name'], note, len(data), localized, ', '.join(sorted(kept))))
    return 0


def cmd_pin(args, log=print):
    data, block = load(args.manifest)
    version = emscripten_version()
    for lib in block['libraries']:
        if args.local:
            with open(os.path.join(args.local, *lib['path'].split('/')), 'rb') as f:
                body = f.read()
        else:
            body = xtalk_extensions._http_get('https://raw.githubusercontent.com/%s/%s/%s'
                                              % (lib['repository'], args.commit, lib['path']), log)
        localize_archive(body, lib['name'], lib['name'] + '.a')
        lib['commit'] = args.commit
        lib['sha256'] = _sha256(body)
        lib['size'] = len(body)
        lib['emscripten'] = version
        log('%s: %s at %s, %d bytes, %s' % (lib['name'], lib['path'], args.commit[:12], len(body), lib['sha256'][:16]))
    xtalk_extensions.write_manifest(args.manifest, data)
    return 0


def cmd_localize(args, log=print):
    with open(args.archive, 'rb') as f:
        data = f.read()
    if data.startswith(WASM_MAGIC):
        obj, kept, localized = localize(data, args.keep, args.archive)
    else:
        if len(args.keep) != 1 or not args.keep[0].endswith('_web_exports'):
            raise WebLibraryError('an archive needs exactly one --keep <name>_web_exports')
        obj, kept, localized = localize_archive(data, args.keep[0][:-len('_web_exports')], args.archive)
    with open(args.out, 'wb') as f:
        f.write(obj)
    log('%s: %d symbol(s) made local, global: %s' % (args.out, localized, ', '.join(sorted(kept))))
    return 0


# The suite's files the browser check needs (test-files): the name in DIR,
# and the path in the suite. NostrXT's relay library (RELAY_TEST_FILE) is
# the exception: it replaces the IDE's copy in the check, so it is the file
# the NostrXT member is pinned at in tools/oxt/xtalk-extensions.json (what
# the next release ships), checked against that pin, and not the suite's
# copy at the web libraries' commit, which once let the check pass on a
# browser transport the shipped IDE did not have.
RELAY_TEST_FILE = 'nostr-relay.livecodescript'
RELAY_MEMBER = 'NostrXT'
RELAY_MEMBER_PATH = 'src/nostr-relay.livecodescript'
TEST_FILES = [
    ('holdem.livecodescript', 'holde-em/src/holdem.livecodescript'),
    ('box2dxt-platformer.livecodescript', 'box2dxt/examples/box2dxt-platformer.livecodescript'),
    ('nostr-relay.livecodescript', 'nostrxt/src/nostr-relay.livecodescript'),
    ('datachannel-selftest.livecodescript', 'datachannelxt/tests/datachannel-selftest.livecodescript'),
]


def pinned_member_file(data, member_name, path, log):
    """The bytes of one file of an extension member as pinned (its
    repository and commit, verified against its SHA-256 and size), and a
    name for it in messages."""
    member = next((m for m in data.get('members', []) if m.get('name') == member_name), None)
    if member is None:
        raise WebLibraryError('the manifest pins no member %s' % member_name)
    f = next((f for f in member['files'] if f['path'] == path), None)
    if f is None:
        raise WebLibraryError('%s pins no %s' % (member_name, path))
    repo, commit = xtalk_extensions.file_source(member, f)
    body = xtalk_extensions._http_get('https://raw.githubusercontent.com/%s/%s/%s' % (repo, commit, path), log)
    if len(body) != f['size'] or hashlib.sha256(body).hexdigest() != f['sha256']:
        raise WebLibraryError('%s@%s %s is not the pinned file (SHA-256 or size differs)'
                              % (repo, commit[:12], path))
    return body, '%s@%s %s' % (repo, commit[:12], path)


def cmd_test_files(args, log=print):
    data, block = load(args.manifest)
    lib = block['libraries'][0]
    os.makedirs(args.out, exist_ok=True)
    for name, path in TEST_FILES:
        if args.local:
            with open(os.path.join(args.local, *path.split('/')), 'rb') as f:
                body = f.read()
        elif name == RELAY_TEST_FILE:
            body, path = pinned_member_file(data, RELAY_MEMBER, RELAY_MEMBER_PATH, log)
        else:
            body = xtalk_extensions._http_get('https://raw.githubusercontent.com/%s/%s/%s'
                                              % (lib['repository'], lib['commit'], path), log)
        if name == RELAY_TEST_FILE:
            body = xtalk_extensions.wrap_lcs(body, 'nostr-relay', path)[0]
        with open(os.path.join(args.out, name), 'wb') as f:
            f.write(body)
        log('%s: %s, %d bytes' % (name, path, len(body)))
    return 0


def cmd_list(args, log=print):
    _, block = load(args.manifest)
    for lib in block['libraries']:
        log('%-9s %s@%s %s (%d bytes, Emscripten %s)' % (lib['name'], lib['repository'], lib['commit'][:12],
                                                         lib['path'], lib['size'], lib['emscripten']))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--manifest', default=MANIFEST, help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('fetch')
    p.add_argument('--out', required=True)
    p.add_argument('--cache')
    p.add_argument('--offline', action='store_true')
    p.add_argument('--local')
    p.set_defaults(func=cmd_fetch)
    p = sub.add_parser('pin')
    p.add_argument('--commit', required=True)
    p.add_argument('--local')
    p.set_defaults(func=cmd_pin)
    p = sub.add_parser('localize')
    p.add_argument('archive')
    p.add_argument('out')
    p.add_argument('--keep', action='append', required=True)
    p.set_defaults(func=cmd_localize)
    p = sub.add_parser('test-files')
    p.add_argument('--out', required=True)
    p.add_argument('--local')
    p.set_defaults(func=cmd_test_files)
    p = sub.add_parser('list')
    p.set_defaults(func=cmd_list)
    args = parser.parse_args(argv)
    if getattr(args, 'commit', None) is not None and not xtalk_extensions._is_sha1(args.commit):
        parser.error('--commit must be a full 40-digit SHA-1')
    try:
        return args.func(args)
    except (WebLibraryError, xtalk_extensions.XtalkError, OSError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
