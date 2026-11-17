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

"""A small Nostr relay on 127.0.0.1, for the web IDE's xTalk tour
(web_ide_tour.py --relay, EXPERIMENTAL): the browser's WebSocket reaches it
as ws://127.0.0.1:<port>/, so xTalk Chat and NostrXT's relay library are
tried end to end without a public relay.

  python3 tools/ci/nostr_test_relay.py [--port N] [--log FILE] [--ephemeral SECONDS]

It speaks NIP-01 (EVENT, REQ, CLOSE; OK, EOSE, EVENT, NOTICE) over RFC 6455,
keeps the events it is sent in memory (but ephemeral kinds, 20000 to
29999, which it only passes on), and gives each subscription the stored
events and then every new one its filters match (ids, authors, kinds,
#<letter> tags, since, until, limit). It checks no signature: the clients
under test do. It answers AUTH with nothing. Each message in and out is a
line of the log. Standard library only.

With --ephemeral (serve's ephemeral) it keeps an ephemeral event for
that many seconds and gives it, newest first, to a subscription that
asks while it has it, as some public relays do (strfry keeps them five
minutes by default). tools/ci/ember_bricks_check.py's lobby runs on one
that does: a client that takes whatever a relay gives as news fails
there, as it would on those. Without it nothing changes.

A test can have the relay hang up on everyone (Relay.hang_up): each
client's connection ends with no closing frame, as when a relay restarts
or a phone's network goes for a moment. The relay goes on listening, so a
client that asks again is let in.
"""

import argparse
import base64
import hashlib
import json
import socket
import socketserver
import struct
import threading
import time

GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'


class Relay:
    def __init__(self, log_path=None, ephemeral=0):
        self.lock = threading.Lock()
        self.events = []
        # the ephemeral events kept for a while, if any are: (when it is
        # forgotten, the event)
        self.ephemeral = ephemeral
        self.passing = []
        self.clients = set()
        self.log_file = open(log_path, 'a', encoding='utf-8') if log_path else None

    def take(self, event, now=None):
        """An event that came: False if the relay had it already; kept if
        it is of a kind that is kept, or ephemeral and those are kept for
        a while. (Called with the lock.)"""
        now = time.time() if now is None else now
        self.passing = [(until, e) for until, e in self.passing if until > now]
        if any(e['id'] == event['id'] for e in self.events) or any(e['id'] == event['id'] for _, e in self.passing):
            return False
        if not 20000 <= int(event['kind']) < 30000:
            self.events.append(event)
        elif self.ephemeral > 0:
            self.passing.append((now + self.ephemeral, event))
        return True

    def stored(self, now=None):
        """What a subscription is given first: the events kept, in the
        order they came, then the ephemeral ones still held, the newest
        first. (Called with the lock.)"""
        now = time.time() if now is None else now
        return list(self.events) + [e for until, e in reversed(self.passing) if until > now]

    def connected(self):
        """The clients connected now (a set of its own, to compare with
        a later one)."""
        with self.lock:
            return set(self.clients)

    def hang_up(self):
        """Ends every client's connection, with no closing frame; the
        relay goes on listening. Returns how many there were. (They are
        no clients from now, whenever each one's thread comes to know.)"""
        with self.lock:
            clients = set(self.clients)
            self.clients -= clients
        for client in clients:
            try:
                client.request.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        self.log('hung up on %d' % len(clients))
        return len(clients)

    def log(self, text):
        if self.log_file:
            with self.lock:
                self.log_file.write('%.3f %s\n' % (time.time(), text))
                self.log_file.flush()


def matches(event, flt):
    if 'ids' in flt and not any(event['id'].startswith(i) for i in flt['ids']):
        return False
    if 'authors' in flt and not any(event['pubkey'].startswith(a) for a in flt['authors']):
        return False
    if 'kinds' in flt and event['kind'] not in flt['kinds']:
        return False
    if 'since' in flt and event['created_at'] < flt['since']:
        return False
    if 'until' in flt and event['created_at'] > flt['until']:
        return False
    for key, values in flt.items():
        if key.startswith('#') and len(key) == 2:
            tagged = {t[1] for t in event.get('tags', []) if len(t) > 1 and t[0] == key[1]}
            if not tagged & set(values):
                return False
    return True


class Handler(socketserver.BaseRequestHandler):
    def setup(self):
        self.relay = self.server.relay
        self.subs = {}
        self.send_lock = threading.Lock()
        self.name = '%s:%d' % self.client_address

    def handle(self):
        if not self.handshake():
            return
        with self.relay.lock:
            self.relay.clients.add(self)
        self.relay.log('%s open' % self.name)
        try:
            for opcode, payload in self.frames():
                if opcode == 8:
                    self.send_frame(8, payload[:2])
                    break
                if opcode == 9:
                    self.send_frame(10, payload)
                elif opcode == 1:
                    self.message(payload.decode('utf-8'))
        except (ConnectionError, OSError, ValueError) as e:
            self.relay.log('%s ended: %s' % (self.name, e))
        finally:
            with self.relay.lock:
                self.relay.clients.discard(self)
            self.relay.log('%s closed' % self.name)

    def handshake(self):
        data = b''
        while b'\r\n\r\n' not in data:
            chunk = self.request.recv(4096)
            if not chunk:
                return False
            data += chunk
        key = None
        for line in data.split(b'\r\n')[1:]:
            name, _, value = line.partition(b':')
            if name.strip().lower() == b'sec-websocket-key':
                key = value.strip().decode('ascii')
        if not key:
            self.request.sendall(b'HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n')
            return False
        accept = base64.b64encode(hashlib.sha1((key + GUID).encode('ascii')).digest()).decode('ascii')
        self.request.sendall(('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n'
                              'Connection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n' % accept).encode('ascii'))
        return True

    def read(self, count):
        out = b''
        while len(out) < count:
            chunk = self.request.recv(count - len(out))
            if not chunk:
                raise ConnectionError('the client went away')
            out += chunk
        return out

    def frames(self):
        message, message_op = b'', None
        while True:
            head = self.read(2)
            fin, opcode = head[0] & 0x80, head[0] & 0x0f
            masked, length = head[1] & 0x80, head[1] & 0x7f
            if length == 126:
                length = struct.unpack('>H', self.read(2))[0]
            elif length == 127:
                length = struct.unpack('>Q', self.read(8))[0]
            if not masked:
                raise ValueError('an unmasked frame from a client')
            mask = self.read(4)
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(self.read(length)))
            if opcode >= 8:
                yield opcode, payload
                continue
            if opcode != 0:
                message, message_op = b'', opcode
            message += payload
            if fin:
                yield message_op, message
                message = b''

    def send_frame(self, opcode, payload):
        length = len(payload)
        if length < 126:
            head = struct.pack('>BB', 0x80 | opcode, length)
        elif length < 65536:
            head = struct.pack('>BBH', 0x80 | opcode, 126, length)
        else:
            head = struct.pack('>BBQ', 0x80 | opcode, 127, length)
        with self.send_lock:
            self.request.sendall(head + payload)

    def send(self, message):
        text = json.dumps(message, separators=(',', ':'))
        self.relay.log('%s <- %s' % (self.name, text[:300]))
        try:
            self.send_frame(1, text.encode('utf-8'))
        except OSError:
            pass

    def message(self, text):
        self.relay.log('%s -> %s' % (self.name, text[:300]))
        try:
            msg = json.loads(text)
            verb = msg[0]
        except (ValueError, IndexError, TypeError):
            self.send(['NOTICE', 'not a Nostr message'])
            return
        if verb == 'EVENT' and len(msg) > 1 and isinstance(msg[1], dict):
            self.event(msg[1])
        elif verb == 'REQ' and len(msg) > 1:
            sub, filters = msg[1], [f for f in msg[2:] if isinstance(f, dict)]
            self.subs[sub] = filters
            with self.relay.lock:
                stored = self.relay.stored()
            for flt in filters:
                found = [e for e in stored if matches(e, flt)]
                if 'limit' in flt:
                    found = found[-flt['limit']:] if flt['limit'] else []
                for event in found:
                    self.send(['EVENT', sub, event])
            self.send(['EOSE', sub])
        elif verb == 'CLOSE' and len(msg) > 1:
            self.subs.pop(msg[1], None)
            self.send(['CLOSED', msg[1], ''])
        elif verb != 'AUTH':
            self.send(['NOTICE', 'unknown message %s' % verb])

    def event(self, event):
        try:
            kind, event_id = int(event['kind']), str(event['id'])
            event['pubkey'], event['created_at']
        except (KeyError, ValueError, TypeError):
            self.send(['OK', str(event.get('id', '')), False, 'invalid: not an event'])
            return
        with self.relay.lock:
            duplicate = not self.relay.take(event)
            clients = list(self.relay.clients)
        self.send(['OK', event_id, True, 'duplicate:' if duplicate else ''])
        if duplicate:
            return
        for client in clients:
            for sub, filters in list(client.subs.items()):
                if any(matches(event, f) for f in filters):
                    client.send(['EVENT', sub, event])


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def serve(log_path=None, port=0, ephemeral=0):
    """Starts the relay on 127.0.0.1 in a thread of its own; returns the
    server (server_address[1] is its port, shutdown() stops it). With
    ephemeral, ephemeral events are kept that many seconds."""
    server = Server(('127.0.0.1', port), Handler)
    server.relay = Relay(log_path, ephemeral)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--port', type=int, default=7447)
    ap.add_argument('--log')
    ap.add_argument('--ephemeral', type=int, default=0, help='keep ephemeral events this many seconds (default: none is kept)')
    args = ap.parse_args()
    server = serve(args.log, args.port, args.ephemeral)
    print('ws://127.0.0.1:%d/' % server.server_address[1], flush=True)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == '__main__':
    main()
