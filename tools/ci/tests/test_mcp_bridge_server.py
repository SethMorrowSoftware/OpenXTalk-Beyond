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

"""The MCP server of the xTalk MCP Bridge
(ide/Extensions/org.openxtalk.plugin.mcpbridge/mcp/server.js), driven as
Claude's apps drive it: JSON-RPC over its standard input and output, with
a stand-in for OXT-Beyond's side (a socket server on 127.0.0.1 that answers
as mcpbridge-tools.livecodescript does, and the file with its port and
token). OXT-Beyond's side itself is tested by tests/lcs/mcpbridge.

It checks that the server answers initialize, ping and tools/list without
OXT-Beyond, that its tools are the ones OXT-Beyond knows (its kTools) and
those the desktop extension's manifest lists, that a call goes to OXT-Beyond
with the token after a hello and comes back as MCP content (a picture as an
image), that a refused token, a missing file or a closed IDE comes back as
a tool error that says what to do, and that calls go one at a time.

And the server for the web IDE (server.js --web), with a stand-in for the
web IDE's page (a WebSocket client, as the page's mcp/web-link.js is):
that it waits for the page on its port, lets only the origins it allows
connect, sends the same lines without a token, says how to connect when no
page is there, and that a newer page takes over.

Skipped where Node.js is not installed.

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import hashlib
import hmac
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
PLUGIN = os.path.join(REPO, 'ide', 'Extensions', 'org.openxtalk.plugin.mcpbridge')
SERVER = os.path.join(PLUGIN, 'mcp', 'server.js')
NODE = shutil.which('node')


def ide_tools():
    """The tools OXT-Beyond says it has: its kTools."""
    with open(os.path.join(PLUGIN, 'mcpbridge-tools.livecodescript'), encoding='utf-8') as f:
        match = re.search(r'^constant kTools = "([^"]*)"', f.read(), re.M)
    return match.group(1) if match else ''


class FakeOXT:
    """OXT-Beyond's side: answers each line with handler(request)."""

    def __init__(self, handler, token='0123456789abcdef0123456789abcdef', tools=None, hello_delay=0):
        self.handler = handler
        self.token = token
        self.tools = ide_tools() if tools is None else tools
        self.hello_delay = hello_delay
        self.requests = []
        self.connections = 0
        self.in_flight = 0
        self.most_in_flight = 0
        self.lock = threading.Lock()
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(5)
        self.port = self.listener.getsockname()[1]
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            try:
                conn, _ = self.listener.accept()
            except OSError:
                return
            self.connections += 1
            threading.Thread(target=self.client, args=(conn,), daemon=True).start()

    def client(self, conn):
        data = b''
        with conn:
            while True:
                try:
                    chunk = conn.recv(65536)
                except OSError:
                    return
                if not chunk:
                    return
                data += chunk
                while b'\n' in data:
                    line, data = data.split(b'\n', 1)
                    request = json.loads(line.decode('utf-8'))
                    self.requests.append(request)
                    with self.lock:
                        self.in_flight += 1
                        self.most_in_flight = max(self.most_in_flight, self.in_flight)
                    if request.get('token') != self.token:
                        reply = {'ok': False, 'error': 'The token is not the bridge\'s.'}
                    elif request.get('method') == 'hello':
                        if self.hello_delay:
                            time.sleep(self.hello_delay)
                        reply = {'ok': True, 'protocol': 1, 'tools': self.tools}
                    else:
                        reply = self.handler(request)
                    with self.lock:
                        self.in_flight -= 1
                    if reply is None:
                        return
                    reply = dict(reply, id=request.get('id'))
                    conn.sendall((json.dumps(reply) + '\n').encode('utf-8'))

    def close(self):
        self.listener.close()


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


# The key the web tests give the server (OXT_MCP_WEB_KEY) and the page
WEB_KEY = 'ab' * 32


def web_proof(key, side, page_nonce, server_nonce):
    """server.js's and web-link.js's proof of holding the key."""
    return hmac.new(key.encode('utf-8'), ('%s\n%s\n%s' % (side, page_nonce, server_nonce)).encode('utf-8'),
                    hashlib.sha256).hexdigest()


class FakeTab:
    """The web IDE's page: a WebSocket client that proves it holds key,
    then answers each request with handler(request), as the page and the
    IDE's script do together. server_ok is whether the server's proof was
    right, accepted whether the server then took this tab as the page."""

    def __init__(self, port, handler, origin='http://localhost:8000', tools=None, key=WEB_KEY):
        self.handler = handler
        self.tools = ide_tools() if tools is None else tools
        self.requests = []
        self.status = None
        self.closed = False
        self.sock = None
        self.server_ok = None
        self.accepted = None
        self.key = key
        deadline = time.time() + 10
        while True:
            try:
                self.sock = socket.create_connection(('127.0.0.1', port), timeout=10)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.05)
        key = base64.b64encode(os.urandom(16)).decode('ascii')
        self.nonce = os.urandom(32).hex()
        self.sock.sendall(('GET /?n=%s HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                           'Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\nOrigin: %s\r\n\r\n'
                           % (self.nonce, port, key, origin)).encode('ascii'))
        head = b''
        while b'\r\n\r\n' not in head:
            chunk = self.sock.recv(1)
            if not chunk:
                break
            head += chunk
        self.status = int(head.split(b' ')[1]) if head else None
        if self.status == 101:
            hello = json.loads(self.read_frame()[1].decode('utf-8'))
            self.server_ok = hello['proof'] == web_proof(self.key, 'server', self.nonce, hello['nonce'])
            self.send(json.dumps({'oxtMcpWeb': 1, 'proof': web_proof(self.key, 'page', self.nonce, hello['nonce'])}))
            # The server says it took the page, or closes the connection
            try:
                opcode, data = self.read_frame()
                self.accepted = opcode == 0x1 and json.loads(data.decode('utf-8')).get('connected') is True
            except OSError:
                self.accepted = False
            if self.accepted:
                threading.Thread(target=self.serve, daemon=True).start()
            else:
                self.closed = True
                self.close()

    def read_frame(self):
        b0, b1 = self.recv_exact(2)
        length = b1 & 0x7f
        if length == 126:
            length = int.from_bytes(self.recv_exact(2), 'big')
        elif length == 127:
            length = int.from_bytes(self.recv_exact(8), 'big')
        return b0 & 0x0f, self.recv_exact(length)

    def recv_exact(self, n):
        data = b''
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise OSError('closed')
            data += chunk
        return data

    def serve(self):
        try:
            while True:
                opcode, data = self.read_frame()
                if opcode == 0x8:
                    break
                request = json.loads(data.decode('utf-8'))
                self.requests.append(request)
                if request.get('method') == 'hello':
                    reply = {'ok': True, 'protocol': 1, 'tools': self.tools}
                else:
                    reply = self.handler(request)
                if reply is None:
                    break
                self.send(json.dumps(dict(reply, id=request.get('id'))))
        except OSError:
            pass
        self.closed = True
        self.close()

    def send(self, text):
        data = text.encode('utf-8')
        mask = os.urandom(4)
        head = bytearray([0x81])
        if len(data) < 126:
            head.append(0x80 | len(data))
        elif len(data) < 65536:
            head.append(0x80 | 126)
            head += len(data).to_bytes(2, 'big')
        else:
            head.append(0x80 | 127)
            head += len(data).to_bytes(8, 'big')
        self.sock.sendall(bytes(head) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# The web IDE's page for run_page: web-link.js in a context like a page's,
# whose WebSocket sends the page's origin, then the IDE's part (read the
# queue, answer each request) until it has answered the calls asked for
PAGE_HARNESS = r'''
'use strict';
const fs = require('fs');
const vm = require('vm');
const [file, port, key, calls] = process.argv.slice(2);
class PageSocket extends WebSocket {
  constructor(url) {
    super(url, { headers: { origin: 'http://localhost:8000' } });
  }
}
const page = { WebSocket: PageSocket, crypto: globalThis.crypto, TextEncoder, setTimeout, clearTimeout, JSON, Number, String };
page.window = page;
vm.createContext(page);
vm.runInContext(fs.readFileSync(file, 'utf8'), page);
const link = page.oxtMcpLink;
link.start(Number(port), key);
const queued = [];
let answered = 0;
let state = '';
const started = Date.now();
const timer = setInterval(() => {
  const text = link.poll();
  const nl = text.indexOf('\n');
  state = text.slice(0, nl).split('\t')[0];
  const item = text.slice(nl + 1);
  if (item) {
    const tab = item.indexOf('\t');
    const request = JSON.parse(item.slice(tab + 1));
    queued.push(request);
    const reply = request.method === 'hello'
      ? { id: request.id, ok: true, protocol: 1, tools: 'list_stacks' }
      : { id: request.id, ok: true, isError: false, text: 'from the page' };
    link.reply(Number(item.slice(0, tab)), JSON.stringify(reply));
    if (request.method !== 'hello') {
      answered++;
    }
  }
  if ((Number(calls) > 0 && answered >= Number(calls)) || Date.now() - started > 8000 ||
      (Number(calls) === 0 && state === 'refused' && Date.now() - started > 1500)) {
    clearInterval(timer);
    setTimeout(() => {
      link.stop();
      process.stdout.write(JSON.stringify({ state, queued: queued.filter((r) => r.method !== 'hello') }));
      process.exit(0);
    }, 300);
  }
}, 20);
'''


class McpBridgeServerBase(unittest.TestCase):
    """Starting the server and talking to it, for the tests below."""

    def setUp(self):
        self.folder = tempfile.mkdtemp()
        self.info = os.path.join(self.folder, 'mcp-bridge.json')
        self.oxt = None
        self.proc = None
        self.next_id = 1

    def tearDown(self):
        if self.proc:
            self.proc.stdin.close()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
            self.proc.stdout.close()
            self.proc.stderr.close()
        if self.oxt:
            self.oxt.close()
        shutil.rmtree(self.folder, ignore_errors=True)

    def start_oxt(self, handler, protocol=1, token=None, pid=None, **fake):
        self.oxt = FakeOXT(handler, **fake)
        info = {'protocol': protocol, 'port': self.oxt.port,
                'token': token or self.oxt.token, 'engine': 'test'}
        if pid is not None:
            info['pid'] = pid
        with open(self.info, 'w') as f:
            json.dump(info, f)

    def start_server(self, args=(), **settings):
        env = dict(os.environ, OXT_MCP_BRIDGE_FILE=self.info, OXT_MCP_TIMEOUT_MS='20000', **settings)
        self.proc = subprocess.Popen([NODE, SERVER] + list(args), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE, env=env)

    def send(self, method, params=None, notify=False):
        message = {'jsonrpc': '2.0', 'method': method}
        if params is not None:
            message['params'] = params
        if not notify:
            message['id'] = self.next_id
            self.next_id += 1
        self.proc.stdin.write((json.dumps(message) + '\n').encode('utf-8'))
        self.proc.stdin.flush()
        return message.get('id')

    def receive(self):
        line = self.proc.stdout.readline()
        if not line:
            self.fail('the server ended: ' + self.proc.stderr.read().decode('utf-8', 'replace'))
        return json.loads(line)

    def request(self, method, params=None):
        sent = self.send(method, params)
        reply = self.receive()
        self.assertEqual(reply.get('id'), sent)
        return reply

    def call(self, name, arguments=None):
        reply = self.request('tools/call', {'name': name, 'arguments': arguments or {}})
        self.assertIn('result', reply, reply)
        return reply['result']

    def initialize(self, version='2025-06-18'):
        reply = self.request('initialize', {'protocolVersion': version, 'capabilities': {},
                                            'clientInfo': {'name': 'test', 'version': '1'}})
        self.send('notifications/initialized', notify=True)
        return reply


@unittest.skipUnless(NODE, 'Node.js is not installed')
class McpBridgeServerTest(McpBridgeServerBase):

    # --- without OXT-Beyond --------------------------------------------------

    def test_initialize_and_list_without_the_ide(self):
        self.start_server()
        reply = self.initialize('2025-06-18')
        result = reply['result']
        self.assertEqual(result['protocolVersion'], '2025-06-18')
        self.assertIn('tools', result['capabilities'])
        self.assertEqual(result['serverInfo']['name'], 'oxt-beyond')
        self.assertIn('xtalk_guide', result['instructions'])
        self.assertEqual(self.request('ping')['result'], {})
        tools = self.request('tools/list')['result']['tools']
        for tool in tools:
            self.assertEqual(tool['inputSchema']['type'], 'object', tool['name'])
            self.assertTrue(tool['description'], tool['name'])
            self.assertIn('readOnlyHint', tool['annotations'], tool['name'])
        names = [t['name'] for t in tools]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(self.request('nothing/here').get('error', {}).get('code'), -32601)

    def test_an_unknown_version_gets_the_newest(self):
        self.start_server()
        reply = self.initialize('1999-01-01')
        self.assertRegex(reply['result']['protocolVersion'], r'^\d{4}-\d{2}-\d{2}$')
        self.assertNotEqual(reply['result']['protocolVersion'], '1999-01-01')

    def test_the_tools_are_those_oxt_and_the_manifest_know(self):
        self.start_server()
        self.initialize()
        names = [t['name'] for t in self.request('tools/list')['result']['tools']]
        with open(os.path.join(PLUGIN, 'mcpbridge-tools.livecodescript'), encoding='utf-8') as f:
            match = re.search(r'^constant kTools = "([^"]*)"', f.read(), re.M)
        self.assertIsNotNone(match, 'kTools in mcpbridge-tools.livecodescript')
        self.assertEqual(names, match.group(1).split(','))
        with open(os.path.join(PLUGIN, 'mcp', 'manifest.json'), encoding='utf-8') as f:
            manifest = json.load(f)
        self.assertEqual([t['name'] for t in manifest['tools']], names)
        self.assertEqual(manifest['server']['entry_point'], 'server.js')

    def test_a_call_without_the_ide_says_how_to_turn_it_on(self):
        self.start_server()
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('xTalk MCP Bridge', result['content'][0]['text'])

    def test_a_tool_there_is_not(self):
        self.start_server()
        self.initialize()
        result = self.call('format_disk')
        self.assertTrue(result['isError'])

    # --- with a stand-in for OXT-Beyond ---------------------------------------

    def test_a_call_goes_to_the_ide_with_the_token(self):
        def handler(request):
            return {'ok': True, 'isError': False, 'text': 'read ' + json.dumps(request['arguments'])}
        self.start_oxt(handler)
        self.start_server()
        self.initialize()
        result = self.call('read_stack', {'stack': 'Héllo', 'id': 1003})
        self.assertFalse(result['isError'])
        self.assertEqual(result['content'], [{'type': 'text', 'text': 'read {"stack": "H\\u00e9llo", "id": 1003}'}])
        methods = [r['method'] for r in self.oxt.requests]
        self.assertEqual(methods, ['hello', 'call'])
        call = self.oxt.requests[1]
        self.assertEqual(call['tool'], 'read_stack')
        self.assertEqual(call['token'], self.oxt.token)
        self.assertEqual(call['arguments'], {'stack': 'Héllo', 'id': 1003})
        # The connection is kept for the next call
        self.call('list_stacks')
        self.assertEqual(self.oxt.connections, 1)

    def test_a_picture_comes_back_as_an_image(self):
        def handler(request):
            return {'ok': True, 'isError': False, 'text': 'A picture', 'image': 'iVBORw0KGgo=', 'imageType': 'image/png'}
        self.start_oxt(handler)
        self.start_server()
        self.initialize()
        result = self.call('look_at_card')
        self.assertEqual(result['content'][1], {'type': 'image', 'data': 'iVBORw0KGgo=', 'mimeType': 'image/png'})

    def test_a_tool_error_is_a_tool_error(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': True, 'text': 'Nothing was changed'})
        self.start_server()
        self.initialize()
        result = self.call('make_changes', {'changes': []})
        self.assertTrue(result['isError'])
        self.assertEqual(result['content'][0]['text'], 'Nothing was changed')

    def test_a_wrong_token_is_refused(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'should not run'}, token='f' * 32)
        self.start_server()
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('token', result['content'][0]['text'])
        self.assertEqual([r['method'] for r in self.oxt.requests], ['hello'])

    def test_another_protocol_is_refused(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'x'}, protocol=2)
        self.start_server()
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('protocol', result['content'][0]['text'])
        self.assertEqual(self.oxt.requests, [])

    def test_the_ide_closing_mid_call(self):
        self.start_oxt(lambda request: None)
        self.start_server()
        self.initialize()
        result = self.call('run_code', {'code': 'put 1'})
        self.assertTrue(result['isError'])
        self.assertIn('closed the connection', result['content'][0]['text'])

    def test_calls_go_one_at_a_time(self):
        def handler(request):
            time.sleep(0.2)
            return {'ok': True, 'isError': False, 'text': request['tool']}
        self.start_oxt(handler)
        self.start_server()
        self.initialize()
        sent = [self.send('tools/call', {'name': name, 'arguments': {}})
                for name in ('list_stacks', 'xtalk_guide', 'list_changes')]
        replies = {}
        for _ in sent:
            reply = self.receive()
            replies[reply['id']] = reply['result']['content'][0]['text']
        self.assertEqual([replies[i] for i in sent], ['list_stacks', 'xtalk_guide', 'list_changes'])
        self.assertEqual(self.oxt.most_in_flight, 1)

    def test_a_file_left_by_an_ide_that_quit(self):
        ended = subprocess.Popen([NODE, '-e', ''])
        ended.wait()
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'should not run'}, pid=ended.pid)
        self.start_server()
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('quit or crashed', result['content'][0]['text'])
        self.assertEqual(self.oxt.requests, [])

    def test_a_file_naming_a_running_ide(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'ran'}, pid=os.getpid())
        self.start_server()
        self.initialize()
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'ran')

    def test_an_ide_that_never_says_hello(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'ran'}, hello_delay=3)
        self.start_server(OXT_MCP_HELLO_TIMEOUT_MS='500')
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('within', result['content'][0]['text'])

    def test_other_tools_in_the_ide_are_noted_once(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'ran'},
                       tools=ide_tools() + ',paint_card')
        self.start_server()
        self.initialize()
        first = self.call('list_stacks')['content'][0]['text']
        self.assertIn('paint_card', first)
        self.assertIn('Claude Setup', first)
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'ran')

    def test_the_same_tools_get_no_note(self):
        self.start_oxt(lambda request: {'ok': True, 'isError': False, 'text': 'ran'})
        self.start_server()
        self.initialize()
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'ran')

    def test_a_call_that_waits_too_long_is_told_the_ide_is_busy(self):
        def handler(request):
            time.sleep(1.5)
            return {'ok': True, 'isError': False, 'text': request['tool']}
        self.start_oxt(handler)
        self.start_server(OXT_MCP_BUSY_WAIT_MS='300')
        self.initialize()
        first = self.send('tools/call', {'name': 'list_stacks', 'arguments': {}})
        second = self.send('tools/call', {'name': 'list_changes', 'arguments': {}})
        replies = {}
        for _ in range(2):
            reply = self.receive()
            replies[reply['id']] = reply['result']
        self.assertEqual(replies[first]['content'][0]['text'], 'list_stacks')
        self.assertTrue(replies[second]['isError'])
        self.assertIn('busy', replies[second]['content'][0]['text'])
        time.sleep(0.5)
        self.assertEqual([r.get('tool') for r in self.oxt.requests if r['method'] == 'call'], ['list_stacks'])

    def test_a_cancelled_call_is_not_sent_and_not_answered(self):
        def handler(request):
            time.sleep(0.8)
            return {'ok': True, 'isError': False, 'text': request['tool']}
        self.start_oxt(handler)
        self.start_server()
        self.initialize()
        first = self.send('tools/call', {'name': 'list_stacks', 'arguments': {}})
        second = self.send('tools/call', {'name': 'list_changes', 'arguments': {}})
        self.send('notifications/cancelled', {'requestId': second, 'reason': 'test'}, notify=True)
        self.assertEqual(self.receive()['id'], first)
        ping = self.send('ping')
        self.assertEqual(self.receive()['id'], ping)
        self.assertEqual([r.get('tool') for r in self.oxt.requests if r['method'] == 'call'], ['list_stacks'])


@unittest.skipUnless(NODE, 'Node.js is not installed')
class McpBridgeWebServerTest(McpBridgeServerBase):
    """server.js --web, for the web IDE."""

    def setUp(self):
        super().setUp()
        self.port = free_port()
        self.tabs = []

    def tearDown(self):
        for tab in self.tabs:
            tab.close()
        super().tearDown()

    def start_web(self, **settings):
        settings.setdefault('OXT_MCP_WEB_KEY', WEB_KEY)
        self.start_server(args=['--web'], OXT_MCP_WEB_PORT=str(self.port), **settings)

    def tab(self, handler, **kwargs):
        tab = FakeTab(self.port, handler, **kwargs)
        self.tabs.append(tab)
        return tab

    def test_web_initialize_names_the_web_server(self):
        self.start_web()
        result = self.initialize()['result']
        self.assertEqual(result['serverInfo']['name'], 'oxt-beyond-web')
        names = [t['name'] for t in self.request('tools/list')['result']['tools']]
        self.assertEqual(names, ide_tools().split(','))

    def test_web_a_call_without_the_page_says_how_to_connect(self):
        self.start_web()
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('web IDE is not connected', result['content'][0]['text'])
        self.assertIn('Connect', result['content'][0]['text'])

    def test_web_a_call_goes_to_the_page_without_a_token(self):
        self.start_web()
        self.initialize()
        tab = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'read ' + json.dumps(r['arguments'])})
        self.assertEqual(tab.status, 101)
        self.assertTrue(tab.server_ok)
        result = self.call('read_stack', {'stack': 'Héllo'})
        self.assertFalse(result['isError'])
        self.assertEqual(result['content'][0]['text'], 'read {"stack": "H\\u00e9llo"}')
        self.assertEqual([r['method'] for r in tab.requests], ['hello', 'call'])
        self.assertIsNone(tab.requests[1].get('token'))
        self.call('list_stacks')
        self.assertEqual([r['method'] for r in tab.requests], ['hello', 'call', 'call'])

    def test_web_a_big_picture_comes_back_as_an_image(self):
        picture = base64.b64encode(os.urandom(300000)).decode('ascii')
        self.start_web()
        self.initialize()
        self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'A picture', 'image': picture, 'imageType': 'image/png'})
        result = self.call('look_at_card')
        self.assertEqual(result['content'][1], {'type': 'image', 'data': picture, 'mimeType': 'image/png'})

    def test_web_another_origin_is_refused(self):
        self.start_web()
        self.initialize()
        tab = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'should not run'}, origin='https://example.com')
        self.assertEqual(tab.status, 403)
        self.assertTrue(self.call('list_stacks')['isError'])

    def test_web_the_hosted_ide_and_origins_given_are_let_in(self):
        self.start_web(OXT_MCP_WEB_ORIGINS='https://example.org/, https://ide.example.net')
        self.initialize()
        for origin in ('https://sethmorrow.com', 'https://example.org', 'https://ide.example.net', 'http://127.0.0.1:9000'):
            tab = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'ran'}, origin=origin)
            self.assertEqual(tab.status, 101, origin)
            self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'ran', origin)

    def test_web_the_page_closing_mid_call(self):
        self.start_web()
        self.initialize()
        self.tab(lambda r: None)
        result = self.call('run_code', {'code': 'put 1'})
        self.assertTrue(result['isError'])
        self.assertIn('closed the connection', result['content'][0]['text'])

    def test_web_a_newer_page_takes_over(self):
        self.start_web()
        self.initialize()
        first = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'first'})
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'first')
        self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'second'})
        deadline = time.time() + 5
        while not first.closed and time.time() < deadline:
            time.sleep(0.05)
        self.assertTrue(first.closed)
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'second')

    def test_web_a_tab_without_the_key_is_refused(self):
        self.start_web()
        self.initialize()
        tab = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'should not run'}, key='cd' * 32)
        self.assertEqual(tab.status, 101)
        self.assertFalse(tab.server_ok)
        self.assertFalse(tab.accepted)
        self.assertTrue(tab.closed)
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('web IDE is not connected', result['content'][0]['text'])
        self.assertEqual(tab.requests, [])

    def test_web_a_tab_without_the_key_does_not_take_over(self):
        self.start_web()
        self.initialize()
        self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'the page'})
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'the page')
        intruder = self.tab(lambda r: {'ok': True, 'isError': False, 'text': 'not the page'}, key='cd' * 32)
        self.assertFalse(intruder.accepted)
        self.assertEqual(self.call('list_stacks')['content'][0]['text'], 'the page')

    def test_web_a_connection_without_a_nonce_is_refused(self):
        self.start_web()
        self.initialize()
        with socket.create_connection(('127.0.0.1', self.port), timeout=10) as sock:
            deadline = time.time() + 10
            sock.sendall(('GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                          'Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\nOrigin: http://localhost:8000\r\n\r\n'
                          % base64.b64encode(os.urandom(16)).decode('ascii')).encode('ascii'))
            self.assertIn(b' 403 ', sock.recv(100))
            self.assertLess(time.time(), deadline)

    def test_web_without_a_key_says_to_set_up_again(self):
        self.start_web(OXT_MCP_WEB_KEY='')
        self.initialize()
        result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('no key for the web IDE', result['content'][0]['text'])
        self.assertIn('Claude Setup', result['content'][0]['text'])

    def run_page(self, port, key, calls=0):
        """Runs the page's own script (mcp/web-link.js) under Node, which has
        WebSocket and the browser's crypto, until it is connected and has
        answered calls requests, or 8 seconds pass; its last state, and the
        requests it queued."""
        harness = os.path.join(self.folder, 'page.js')
        with open(harness, 'w') as f:
            f.write(PAGE_HARNESS)
        return subprocess.Popen([NODE, harness, os.path.join(PLUGIN, 'mcp', 'web-link.js'), str(port), key, str(calls)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def test_web_the_page_script_connects_to_its_server(self):
        self.start_web()
        self.initialize()
        page = self.run_page(self.port, WEB_KEY, calls=1)
        deadline = time.time() + 8
        result = None
        while time.time() < deadline:
            result = self.call('list_stacks')
            if not result['isError']:
                break
            time.sleep(0.2)
        out = json.loads(page.communicate(timeout=15)[0])
        self.assertTrue(result['content'][0]['text'].startswith('from the page'))
        self.assertEqual(out['state'], 'connected')

    def test_web_the_page_script_refuses_a_server_with_another_key(self):
        self.start_web(OXT_MCP_WEB_KEY='cd' * 32)
        self.initialize()
        out = json.loads(self.run_page(self.port, WEB_KEY).communicate(timeout=15)[0])
        self.assertEqual(out['state'], 'refused')
        self.assertEqual(out['queued'], [])
        self.assertTrue(self.call('list_stacks')['isError'])

    def test_web_the_page_script_refuses_another_program_on_the_port(self):
        # A program that took the port: it accepts the WebSocket, sends a
        # proof it cannot make, then a request, which must not reach the IDE
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('127.0.0.1', self.port))
        listener.listen(4)

        def frame(text):
            data = text.encode('utf-8')
            return bytes([0x81, len(data)]) + data if len(data) < 126 else \
                bytes([0x81, 126]) + len(data).to_bytes(2, 'big') + data

        def impostor():
            while True:
                try:
                    conn, _ = listener.accept()
                except OSError:
                    return
                head = b''
                while b'\r\n\r\n' not in head:
                    chunk = conn.recv(1)
                    if not chunk:
                        break
                    head += chunk
                key = re.search(rb'Sec-WebSocket-Key: (\S+)', head, re.I).group(1)
                accept = base64.b64encode(hashlib.sha1(key + b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest())
                conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                             b'Sec-WebSocket-Accept: ' + accept + b'\r\n\r\n')
                conn.sendall(frame(json.dumps({'oxtMcpWeb': 1, 'nonce': 'ef' * 32, 'proof': '00' * 32})))
                conn.sendall(frame(json.dumps({'id': 1, 'method': 'call', 'tool': 'read_stack', 'arguments': {}})))

        threading.Thread(target=impostor, daemon=True).start()
        try:
            out = json.loads(self.run_page(self.port, WEB_KEY).communicate(timeout=15)[0])
        finally:
            listener.close()
        self.assertEqual(out['state'], 'refused')
        self.assertEqual(out['queued'], [])

    def test_web_a_taken_port_is_said(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as taken:
            taken.bind(('127.0.0.1', self.port))
            taken.listen(1)
            self.start_web()
            self.initialize()
            time.sleep(0.3)
            result = self.call('list_stacks')
        self.assertTrue(result['isError'])
        self.assertIn('Port %d' % self.port, result['content'][0]['text'])


if __name__ == '__main__':
    unittest.main()
