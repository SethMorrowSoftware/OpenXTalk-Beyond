#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License v3 as published by the
# Free Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""The web engine's sockets over WebSocket, without the engine.

- The WebSocket echo of web_check.make_server (which the web engine's
  socket tests, tests/lcs/core/network/websocket.livecodescript, talk to
  in tools/ci/web_tests.py), driven by a client written here: it echoes
  text and binary messages, closes for "please close" and drops the
  connection for "please drop".
- engine/src/em-socket.js, run in Node (22 or later, which has a
  WebSocket) with stand-ins for what Emscripten gives it, against that
  echo: the events it hands the engine (MCEmscriptenSocketHandleEvent),
  with their bytes, and which messages it sends as text and which as
  binary. Skipped where Node or its WebSocket is missing.
- The engine's C++ (em-osspec-network.cpp) and the build list the
  library, and the C++ and the JavaScript agree on the events."""

import base64
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import web_check  # noqa: E402

LIBRARY = os.path.join(REPO, 'engine', 'src', 'em-socket.js')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


class Server(object):
    def __enter__(self):
        self.site = tempfile.mkdtemp()
        self.server = web_check.make_server(self.site)
        self.port = self.server.server_address[1]
        return self

    def __exit__(self, *exc):
        self.server.shutdown()
        self.server.server_close()
        shutil.rmtree(self.site, ignore_errors=True)


class Client(object):
    """A WebSocket client, enough for the echo"""

    def __init__(self, port):
        self.sock = socket.create_connection(('127.0.0.1', port), timeout=10)
        key = base64.b64encode(os.urandom(16)).decode('ascii')
        self.sock.sendall(('GET %s HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\n'
                           'Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n'
                           'Sec-WebSocket-Version: 13\r\n\r\n'
                           % (web_check.WEBSOCKET_ECHO_PATH, port, key)).encode('ascii'))
        self.stream = self.sock.makefile('rb')
        self.status = self.stream.readline().decode('ascii').strip()
        self.headers = {}
        while True:
            line = self.stream.readline().decode('ascii').strip()
            if not line:
                break
            name, _, value = line.partition(':')
            self.headers[name.strip().lower()] = value.strip()
        self.key = key

    def send(self, opcode, payload):
        mask = os.urandom(4)
        n = len(payload)
        head = bytes([0x80 | opcode])
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 65536:
            head += bytes([0x80 | 126]) + struct.pack('>H', n)
        else:
            head += bytes([0x80 | 127]) + struct.pack('>Q', n)
        self.sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def receive(self):
        return web_check.websocket_read_frame(self.stream)

    def close(self):
        self.stream.close()
        self.sock.close()


class TheEcho(unittest.TestCase):
    def test_the_accept_key(self):
        # RFC 6455's example
        self.assertEqual(web_check.websocket_accept('dGhlIHNhbXBsZSBub25jZQ=='), 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=')

    def test_it_echoes_text_and_binary(self):
        with Server() as server:
            client = Client(server.port)
            try:
                self.assertEqual(client.status, 'HTTP/1.1 101 Switching Protocols')
                self.assertEqual(client.headers.get('sec-websocket-accept'), web_check.websocket_accept(client.key))
                client.send(1, b'hello')
                self.assertEqual(client.receive(), (True, 1, b'hello'))
                client.send(2, bytes([0, 255, 13, 10]))
                self.assertEqual(client.receive(), (True, 2, bytes([0, 255, 13, 10])))
                big = b'x' * 70000
                client.send(1, big)
                self.assertEqual(client.receive(), (True, 1, big))
                client.send(9, b'ping')
                self.assertEqual(client.receive(), (True, 10, b'ping'))
                client.send(1, b'please close')
                fin, opcode, payload = client.receive()
                self.assertEqual((opcode, struct.unpack('>H', payload)[0]), (8, 1000))
                client.send(8, payload)
            finally:
                client.close()

    def test_it_drops_on_request(self):
        with Server() as server:
            client = Client(server.port)
            try:
                client.send(1, b'please drop')
                self.assertIsNone(client.receive())
            finally:
                client.close()

    def test_a_plain_get_is_refused(self):
        import urllib.error
        import urllib.request
        with Server() as server:
            with self.assertRaises(urllib.error.HTTPError) as caught:
                urllib.request.urlopen('http://127.0.0.1:%d%s' % (server.port, web_check.WEBSOCKET_ECHO_PATH))
            self.assertEqual(caught.exception.code, 400)


# The library in Node: mergeInto hands over its object, and stand-ins
# for LiveCodeAsync (resume runs the closure), LiveCodeUtil, and Module
# (_malloc, HEAPU8, and a ccall that records the engine's events)
NODE_HARNESS = r'''
const fs = require('fs');
const lib = {};
global.LibraryManager = { library: lib };
global.mergeInto = (target, obj) => Object.assign(target, obj);
eval(fs.readFileSync(process.argv[2], 'utf8'));
global.LiveCodeSocket = lib.$LiveCodeSocket;
global.LiveCodeAsync = { resume: (f) => f() };
const heap = new Uint8Array(1 << 20);
let top = 8;
const events = [];
global.Module = {
    HEAPU8: heap,
    _malloc: (n) => { const p = top; top += n; return p; },
    ccall: (name, ret, types, args) => {
        const [id, event, ptr, length, flag] = args;
        events.push({ name, id, event, flag,
                      bytes: Array.from(heap.slice(ptr, ptr + length)) });
    },
};
global.LiveCodeUtil = { stringFromUTF16: (s) => s };
const url = process.argv[3];
const done = () => { console.log(JSON.stringify({ events, refused })); process.exit(0); };
const refused = lib.MCEmscriptenSocketOpen('ftp://not-a-websocket/', 0);
const id = lib.MCEmscriptenSocketOpen(url, 0);
const put = (bytes) => { const p = top; top += bytes.length; heap.set(bytes, p); return [p, bytes.length]; };
const sent = [];
const step = () => {
    const opens = events.filter(e => e.event == 1).length;
    const datas = events.filter(e => e.event == 2).length;
    if (opens == 1 && sent.length == 0) {
        sent.push(lib.MCEmscriptenSocketSend(id, ...put(Buffer.from('hello\n'))));
        sent.push(lib.MCEmscriptenSocketSend(id, ...put(new Uint8Array([0, 255, 10]))));
        sent.push(lib.MCEmscriptenSocketSend(id, ...put(Buffer.from('héllo\n', 'utf8'))));
        // UTF-8 that starts with a byte order mark: it goes as it is
        sent.push(lib.MCEmscriptenSocketSend(id, ...put(new Uint8Array([0xEF, 0xBB, 0xBF, 0x61, 10]))));
    }
    if (datas == 4 && sent.length == 4) {
        sent.push(lib.MCEmscriptenSocketSend(id, ...put(Buffer.from('please close'))));
    }
    if (events.some(e => e.event == 4)) {
        events.push({ sent });
        // a closed socket refuses to send, and closing it again is nothing
        events.push({ after: lib.MCEmscriptenSocketSend(id, ...put(Buffer.from('x'))) });
        lib.MCEmscriptenSocketClose(id);
        return done();
    }
    setTimeout(step, 20);
};
step();
setTimeout(() => { console.log(JSON.stringify({ events, refused, timeout: true })); process.exit(1); }, 15000);
'''


def node_with_websocket():
    node = shutil.which('node')
    if not node:
        return None
    try:
        out = subprocess.run([node, '-e', 'console.log(typeof WebSocket)'], capture_output=True,
                             text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    return node if out == 'function' else None


class TheLibrary(unittest.TestCase):
    def test_it_talks_to_the_echo(self):
        node = node_with_websocket()
        if not node:
            self.skipTest('no Node with a WebSocket (Node 22 or later)')
        work = tempfile.mkdtemp()
        try:
            harness = os.path.join(work, 'harness.js')
            with open(harness, 'w', encoding='utf-8') as f:
                f.write(NODE_HARNESS)
            with Server() as server:
                url = 'ws://127.0.0.1:%d%s' % (server.port, web_check.WEBSOCKET_ECHO_PATH)
                run = subprocess.run([node, harness, LIBRARY, url], capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            result = json.loads(run.stdout.strip().splitlines()[-1])
        finally:
            shutil.rmtree(work, ignore_errors=True)
        # a URL that is not ws: or wss: is refused at once
        self.assertEqual(result['refused'], 0)
        events = result['events']
        engine = [e for e in events if 'event' in e]
        self.assertTrue(all(e['name'] == 'MCEmscriptenSocketHandleEvent' for e in engine))
        self.assertTrue(all(e['id'] == engine[0]['id'] and e['id'] > 0 for e in engine))
        self.assertEqual([e['event'] for e in engine], [1, 2, 2, 2, 2, 4])
        # text as UTF-8, binary as it was
        self.assertEqual([bytes(e['bytes']) for e in engine if e['event'] == 2],
                         [b'hello\n', bytes([0, 255, 10]), 'héllo\n'.encode('utf-8'),
                          bytes([0xEF, 0xBB, 0xBF, 0x61, 10])])
        # the server closed it cleanly (1000)
        self.assertEqual(engine[-1]['flag'], 1)
        self.assertEqual(events[-2], {'sent': [True, True, True, True, True]})
        self.assertEqual(events[-1], {'after': False})


class OneLibrary(unittest.TestCase):
    def test_the_events_agree(self):
        js = read('engine', 'src', 'em-socket.js')
        cpp = read('engine', 'src', 'em-osspec-network.cpp')
        for name, value in (('Open', 1), ('Data', 2), ('Error', 3), ('Close', 4)):
            self.assertIn('k%s: %d,' % (name, value), js)
            self.assertIn('kMCEmscriptenSocketEvent%s = %d,' % (name, value), cpp)
        self.assertIn('MCEmscriptenSocketHandleEvent(uint32_t p_id, int32_t p_event, byte_t *p_bytes, '
                      'uint32_t p_length, int32_t p_flag)', cpp)
        self.assertIn("Module.ccall('MCEmscriptenSocketHandleEvent', null,\n"
                      "\t\t\t\t             ['number', 'number', 'number', 'number', 'number'],", js)
        for name in ('MCEmscriptenSocketOpen', 'MCEmscriptenSocketSend', 'MCEmscriptenSocketClose'):
            self.assertIn('extern "C"', cpp.split(name, 1)[0][-80:])
            self.assertRegex(js, r'\n\t%s: function\(' % name)

    def test_the_build_links_it(self):
        gyp = read('engine', 'engine.gyp')
        # in each engine's inputs and its --js-library list, after liburl's
        self.assertEqual(gyp.count("'src/em-socket.js',"), gyp.count("'src/em-liburl.js',"))
        self.assertEqual(len(re.findall(r"'src/em-liburl\.js',\n\t+'src/em-socket\.js',", gyp)),
                         gyp.count("'src/em-liburl.js',"))
        self.assertIn("'src/em-socket.js',", read('engine', 'engine-sources.gypi'))

    def test_a_waiting_write_is_its_writers(self):
        # A write with no message waits in MCS_write_socket, which deletes
        # it: the socket's close must not delete it under that script
        cpp = read('engine', 'src', 'em-osspec-network.cpp')
        body = cpp.split('MCSocket::deletewrites()', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('MCSocketwrite *eptr = wevents->remove(wevents);', body)
        self.assertRegex(body, r'if \(eptr->message != nil\)\n\t\t\tdelete eptr;')

    def test_reads_waiting_are_done_at_a_clean_close(self):
        cpp = read('engine', 'src', 'em-osspec-network.cpp')
        close = cpp.split('case kMCEmscriptenSocketEventClose:', 1)[1].split('break;\n\t}', 1)[0]
        self.assertIn('else if (s->error == nil && s->revents != nil && !s->waiting)', close)
        self.assertLess(close.index('s->deletewrites();\n\t\t\ts->processreadqueue();'),
                        close.index('s->doclose();'))
        # and socketClosed goes once, after the last of them
        queue = cpp.split('MCSocket::processreadqueue()', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('if (nread == 0 && fd == 0 && revents == nil && object.IsValid())', queue)

    def test_it_needs_no_desktop_time(self):
        # curtime is defined by the desktop event loops only: the web
        # engine's link failed on it ("undefined symbol: curtime")
        cpp = read('engine', 'src', 'em-osspec-network.cpp')
        code = re.sub(r'/\*.*?\*/', '', cpp, flags=re.S)
        self.assertNotRegex(code, r'\bcurtime\b')

    def test_other_names_fail_as_before(self):
        cpp = read('engine', 'src', 'em-osspec-network.cpp')
        body = cpp.split('MCS_open_socket(MCNameRef p_name,', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('if (p_datagram || !MCEmscriptenSocketURL(p_name, p_secure, &t_url))\n'
                      '\t{\n\t\tMCresult->sets("not supported");\n\t\treturn nil;', body)


if __name__ == '__main__':
    unittest.main()
