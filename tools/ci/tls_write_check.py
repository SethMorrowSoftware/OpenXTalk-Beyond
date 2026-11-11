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

"""Check that the engine writes to a secure socket while a read on it waits
for the rest of a TLS record.

  python3 tools/ci/tls_write_check.py --engine FILE [--log FILE]
      [--timeout SECONDS]

Issue #461: `put url "https://dave.writersweb.org/..."` ended with "socket
timeout" in OXT-Beyond 0.2.7 and LiveCode Community, and worked in curl.
The site is served by Caddy, a Go server, which sends its TLS 1.3 session
tickets with its side of the handshake. The engine finished the handshake
while writing libURL's request (MCSocket::write, engine/src/opensslsocket.cpp)
and so wrote the request on the next round of its socket loop; when the
tickets were read first, SSL_read ended wanting more (SSL_ERROR_WANT_READ),
and MCSocket::write held every write back until a later read, which never
came: the server was waiting for the request. The engine now holds a write
back only while the handshake has not finished.

Whether the tickets are read before the request goes depends on timing (on
the network, about six fetches in ten timed out), so this check makes the
state on purpose: its own TLS server (Python's ssl, over memory buffers so
that it decides what bytes go out) sends, after the handshake and a line from
the engine, only the first bytes of a record, and the rest only once the
engine has written a second line. tools/ci/tls-write-check.livecodescript is
the client, run by a standalone engine with -ui (no window, no X server).
A package's runtime keeps revsecurity, the library the engine loads for
SSL, in its Support folder, and the standalone builder puts it next to the
standalone it builds; the check does the same, running a copy of the engine
with the library next to it.
Up to 0.2.7 the second write timed out; now it goes at once and the engine
reads the record.

The check fails, rather than passing blind, when the server never got the
first line or never sent the partial record (the engine was not in the state
the check is for). Needs the openssl command, to make the server's
certificate. Exit status 0 when every check passed, 1 otherwise. Under
GitHub Actions a failure is an annotation and the results go into the job
summary.
"""

import argparse
import os
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'tls-write-check.livecodescript')
# What the engine writes and reads (as in the script)
HELLO = b'HELLO\r\n'
REQ2 = b'REQ2\r\n'
WORLD = b'WORLD'
# Bytes of the WORLD record sent before REQ2: fewer than a record header
# (5), so SSL_read cannot finish it
PARTIAL = 3
# How long the server waits for each line; longer than the script's
# socketTimeoutInterval (4 s), so a held-back write fails in the engine
# first
LINE_WAIT = 8


def log(msg=''):
    print(msg, flush=True)


SECURITY = ('revsecurity.so', 'revsecurity.dylib', 'revsecurity.dll')


def stage_engine(engine, work):
    """A copy of the engine in work with revsecurity next to it, from next
    to the engine or from a runtime's Support folder, as a built standalone
    has it."""
    here = os.path.dirname(engine)
    for folder in (here, os.path.join(here, 'Support')):
        for name in SECURITY:
            lib = os.path.join(folder, name)
            if os.path.isfile(lib):
                staged = os.path.join(work, 'engine')
                os.mkdir(staged)
                shutil.copy2(engine, os.path.join(staged, os.path.basename(engine)))
                shutil.copy2(lib, os.path.join(staged, name))
                return os.path.join(staged, os.path.basename(engine))
    raise RuntimeError('no revsecurity next to %s or in its Support folder' % engine)


def make_certificate(work):
    openssl = shutil.which('openssl')
    if not openssl:
        raise RuntimeError('the openssl command is not installed')
    cert, key = os.path.join(work, 'cert.pem'), os.path.join(work, 'key.pem')
    subprocess.run([openssl, 'req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256',
                    '-nodes', '-keyout', key, '-out', cert, '-days', '2', '-subj', '/CN=127.0.0.1'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return cert, key


class Server:
    """One connection: the handshake, HELLO, the first PARTIAL bytes of a
    record with WORLD, REQ2, the rest of the record. Records what it saw in
    self.events."""

    def __init__(self, cert, key):
        self.ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.ctx.load_cert_chain(cert, key)
        self.listener = socket.socket()
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(1)
        self.port = self.listener.getsockname()[1]
        self.events = []
        self.thread = threading.Thread(target=self.run, daemon=True)

    def run(self):
        try:
            self.listener.settimeout(60)
            conn, _ = self.listener.accept()
            with conn:
                self.serve(conn)
        except Exception as e:  # reported, not raised: the thread ends
            self.events.append('error: %s' % e)
        finally:
            self.listener.close()

    def serve(self, conn):
        inc, out = ssl.MemoryBIO(), ssl.MemoryBIO()
        tls = self.ctx.wrap_bio(inc, out, server_side=True)

        def flush():
            data = out.read()
            if data:
                conn.sendall(data)

        def feed(deadline):
            conn.settimeout(max(0.05, deadline - time.monotonic()))
            data = conn.recv(65536)
            if not data:
                raise EOFError('the engine closed the connection')
            inc.write(data)

        deadline = time.monotonic() + LINE_WAIT
        while True:
            try:
                tls.do_handshake()
                break
            except ssl.SSLWantReadError:
                flush()
                feed(deadline)
        flush()  # the end of the handshake and, in TLS 1.3, the session tickets
        self.events.append('handshake')

        def read_line(want, what):
            got = b''
            deadline = time.monotonic() + LINE_WAIT
            while not got.endswith(b'\r\n'):
                try:
                    got += tls.read(4096)
                except ssl.SSLWantReadError:
                    try:
                        feed(deadline)
                    except socket.timeout:
                        self.events.append('no %s within %d s' % (what, LINE_WAIT))
                        return False
            self.events.append('%s %s' % (what, 'ok' if got == want else 'wrong: %r' % got))
            return got == want

        if not read_line(HELLO, 'HELLO'):
            return
        tls.write(WORLD)
        record = out.read()
        conn.sendall(record[:PARTIAL])
        self.events.append('partial %d of %d bytes' % (PARTIAL, len(record)))
        if not read_line(REQ2, 'REQ2'):
            return
        conn.sendall(record[PARTIAL:])
        self.events.append('rest')
        # Let the engine read it and close first
        time.sleep(1)


def evaluate(result, events):
    """[(name, ok, detail)] for the engine's log lines and the server's
    events."""
    checks = []
    got = {}
    for line in result:
        word, _, rest = line.partition(' ')
        got.setdefault(word, rest.strip())
    errors = [x for x in result if x.startswith('ERROR')]
    checks.append(('the script ran without an error', not errors, '; '.join(errors)))
    checks.append(('the secure socket opened', got.get('OPEN') == '', 'the result was %r' % got.get('OPEN')))
    checks.append(('the first line was written', got.get('HELLO') == '', 'the result was %r' % got.get('HELLO')))
    checks.append(('the server got the first line', 'HELLO ok' in events, '; '.join(events)))
    # Without it the engine was never in the state the check is for
    checks.append(('the server sent part of a record and waited',
                   any(e.startswith('partial') for e in events), '; '.join(events)))
    req2 = got.get('REQ2')
    req2_result = None if req2 is None else req2.rsplit(' ', 1)[0] if ' ' in req2 else ''
    checks.append(('the second line was written while the read waited (no timeout)', req2_result == '',
                   'the result was %r' % req2))
    checks.append(('the server got the second line', 'REQ2 ok' in events, '; '.join(events)))
    checks.append(('the engine read the whole record', got.get('READ') == WORLD.decode(),
                   'it read %r' % got.get('READ')))
    checks.append(('the engine quit when it was done', 'QUIT' in got, ''))
    return checks


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--timeout', type=int, default=60, help='seconds the engine may take')
    args = ap.parse_args(argv)
    engine = os.path.abspath(args.engine)

    lines, problems = [], []
    work = tempfile.mkdtemp(prefix='oxt-tlswrite-')
    try:
        cert, key = make_certificate(work)
        engine = stage_engine(engine, work)
        server = Server(cert, key)
        server.thread.start()
        result_log = os.path.join(work, 'engine.log')
        env = dict(os.environ)
        env.update({'OXT_TLSWRITE_LOG': result_log, 'OXT_TLSWRITE_HOST': '127.0.0.1:%d' % server.port})
        log('Engine %s, TLS server on port %d' % (engine, server.port))
        try:
            proc = subprocess.run([engine, '-ui', SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=args.timeout)
            code, output = proc.returncode, proc.stdout.decode('utf-8', 'replace')
        except subprocess.TimeoutExpired as e:
            code, output = None, (e.stdout or b'').decode('utf-8', 'replace')
        server.thread.join(LINE_WAIT * 2 + 5)
        result = []
        if os.path.exists(result_log):
            with open(result_log, encoding='utf-8', errors='replace') as f:
                result = [x.rstrip('\r\n') for x in f if x.strip()]
        lines += ['INFO engine: ' + x for x in result]
        lines += ['INFO server: ' + x for x in server.events]
        if code is None:
            lines.append('INFO the engine timed out after %d seconds' % args.timeout)
        for name, ok, detail in evaluate(result, server.events):
            lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
            if not ok:
                problems.append('%s%s' % (name, (': ' + detail) if detail else ''))
        if problems and output.strip():
            lines.append('INFO engine output: ' + output[-2000:])
    except (RuntimeError, subprocess.CalledProcessError, OSError) as e:
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=TLS write check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### TLS write check\n\n```\n%s\n```\n' % '\n'.join(lines))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
