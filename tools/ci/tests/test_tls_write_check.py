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

"""tools/ci/tls_write_check.py: what passes and what fails, from the lines
the engine logs and what its server saw; that its server puts a client in
the state the check is for; that the script, the Python and the workflow
agree; and that MCSocket::write no longer waits for a read (issue #461).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import socket
import ssl
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import tls_write_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))

# What 0.2.7's standalone engine (linux-x86_64) logged, and what the server
# saw: the second write never left, and the read had nothing
OLD_ENGINE = ['OPEN ', 'HELLO ', 'REQ2 socket closed 7007', 'READ ', 'QUIT']
OLD_SERVER = ['handshake', 'HELLO ok', 'partial 3 of 27 bytes', 'no REQ2 within 8 s']
# The same engine with the fix (MCSocket::write's test of the retry flags
# changed in its code), run the same way
NEW_ENGINE = ['OPEN ', 'HELLO ', 'REQ2  0', 'READ WORLD', 'QUIT']
NEW_SERVER = ['handshake', 'HELLO ok', 'partial 3 of 27 bytes', 'REQ2 ok', 'rest']


def failed(result, events):
    return [name for name, ok, _ in tls_write_check.evaluate(result, events) if not ok]


class EvaluateTest(unittest.TestCase):

    def test_the_fixed_engine_passes(self):
        self.assertEqual(failed(NEW_ENGINE, NEW_SERVER), [])

    def test_the_old_engine_fails(self):
        self.assertEqual(failed(OLD_ENGINE, OLD_SERVER), [
            'the second line was written while the read waited (no timeout)',
            'the server got the second line',
            'the engine read the whole record',
        ])

    def test_a_write_that_timed_out_fails(self):
        result = ['OPEN ', 'HELLO ', 'REQ2 timeout 4001', 'READ ', 'QUIT']
        self.assertIn('the second line was written while the read waited (no timeout)',
                      failed(result, OLD_SERVER))

    def test_no_partial_record_fails_rather_than_passing_blind(self):
        # The engine was never in the state the check is for
        events = ['handshake', 'HELLO ok', 'REQ2 ok', 'rest']
        self.assertEqual(failed(NEW_ENGINE, events), ['the server sent part of a record and waited'])

    def test_a_server_that_never_got_the_first_line_fails(self):
        self.assertIn('the server got the first line', failed(NEW_ENGINE, ['handshake', 'no HELLO within 8 s']))

    def test_a_socket_that_did_not_open_fails(self):
        result = ['OPEN can\'t connect', 'HELLO socket closed', 'REQ2 socket closed 0', 'READ ', 'QUIT']
        self.assertIn('the secure socket opened', failed(result, []))

    def test_an_error_fails(self):
        result = NEW_ENGINE[:-1] + ['ERROR socketError error:0A000126', 'QUIT']
        self.assertEqual(failed(result, NEW_SERVER), ['the script ran without an error'])

    def test_no_output_fails(self):
        self.assertIn('the engine quit when it was done', failed([], []))
        self.assertIn('the second line was written while the read waited (no timeout)', failed([], []))


class StageEngineTest(unittest.TestCase):
    """A runtime keeps revsecurity in Support (tools/oxt/package.py,
    plan_runtimes); the check runs a copy with it next to the engine, as a
    built standalone has it. On the first CI run the runtime's Standalone
    ran as it is and could not load SSL."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-tlswrite-stage-')
        self.addCleanup(shutil.rmtree, self.work, True)
        self.runtime = os.path.join(self.work, 'Runtime')
        os.makedirs(os.path.join(self.runtime, 'Support'))
        self.engine = os.path.join(self.runtime, 'Standalone')
        with open(self.engine, 'w') as f:
            f.write('engine')
        self.out = os.path.join(self.work, 'out')
        os.mkdir(self.out)

    def test_from_the_support_folder(self):
        with open(os.path.join(self.runtime, 'Support', 'revsecurity.so'), 'w') as f:
            f.write('ssl')
        staged = tls_write_check.stage_engine(self.engine, self.out)
        self.assertEqual(os.path.basename(staged), 'Standalone')
        self.assertTrue(os.path.isfile(os.path.join(os.path.dirname(staged), 'revsecurity.so')))

    def test_from_next_to_the_engine(self):
        with open(os.path.join(self.runtime, 'revsecurity.so'), 'w') as f:
            f.write('ssl')
        staged = tls_write_check.stage_engine(self.engine, self.out)
        self.assertTrue(os.path.isfile(os.path.join(os.path.dirname(staged), 'revsecurity.so')))

    def test_none_fails(self):
        with self.assertRaises(RuntimeError):
            tls_write_check.stage_engine(self.engine, self.out)


@unittest.skipUnless(shutil.which('openssl'), 'needs the openssl command')
class ServerTest(unittest.TestCase):
    """The check's server, with a Python client in place of the engine."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-tlswrite-test-')
        self.addCleanup(shutil.rmtree, self.work, True)
        cert, key = tls_write_check.make_certificate(self.work)
        self.server = tls_write_check.Server(cert, key)
        self.server.thread.start()
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection(('127.0.0.1', self.server.port), timeout=10)
        self.client = ctx.wrap_socket(raw)
        self.addCleanup(self.client.close)

    def test_a_client_that_writes_while_it_waits_gets_the_record(self):
        self.client.sendall(tls_write_check.HELLO)
        # Only part of the record comes before the second line: a read now
        # ends wanting more, as the engine's SSL_read did
        self.client.settimeout(0.5)
        with self.assertRaises((socket.timeout, ssl.SSLWantReadError)):
            self.client.recv(5)
        self.client.settimeout(10)
        self.client.sendall(tls_write_check.REQ2)
        self.assertEqual(self.client.recv(5), tls_write_check.WORLD)
        self.server.thread.join(10)
        events = self.server.events
        self.assertEqual(events[:2], ['handshake', 'HELLO ok'])
        self.assertRegex(events[2], r'^partial %d of \d+ bytes$' % tls_write_check.PARTIAL)
        self.assertEqual(events[3:], ['REQ2 ok', 'rest'])

    def test_a_client_that_waits_for_a_read_before_writing_gets_nothing(self):
        # What the engine did up to 0.2.7: the server waits for the second
        # line and gives up
        self.client.sendall(tls_write_check.HELLO)
        self.server.thread.join(tls_write_check.LINE_WAIT + 5)
        self.assertEqual(self.server.events[-1], 'no REQ2 within %d s' % tls_write_check.LINE_WAIT)


class AgreementTest(unittest.TestCase):

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_script_writes_and_reads_what_the_server_expects(self):
        script = self.read('tools', 'ci', 'tls-write-check.livecodescript')
        self.assertIn('write "HELLO" & crlf to socket sSocket', script)
        self.assertIn('write "REQ2" & crlf to socket sSocket', script)
        self.assertIn('read from socket sSocket for %d with message' % len(tls_write_check.WORLD), script)
        for word in ('OPEN', 'HELLO', 'REQ2', 'READ', 'QUIT'):
            self.assertIn('tlsLog "%s"' % word, script)
        self.assertIn('$OXT_TLSWRITE_LOG', script)
        self.assertIn('$OXT_TLSWRITE_HOST', script)
        # The engine's own timeout comes before the server gives up, so a
        # held-back write fails in the engine (as "timeout" or, once the
        # server closes, "socket closed")
        timeout = int(re.search(r'set the socketTimeoutInterval to (\d+)', script).group(1))
        self.assertLess(timeout, tls_write_check.LINE_WAIT * 1000)

    def test_the_partial_record_is_shorter_than_a_record_header(self):
        self.assertLess(tls_write_check.PARTIAL, 5)
        self.assertGreater(tls_write_check.PARTIAL, 0)

    def test_the_linux_workflow_runs_it_on_the_standalone_engine(self):
        workflow = self.read('.github', 'workflows', 'build-linux.yml')
        self.assertRegex(workflow, r'tools/ci/tls_write_check\.py --engine "\$OXT_ROOT/Runtime/Linux/\$folder/Standalone"')

    def test_a_write_waits_only_for_the_handshake(self):
        source = self.read('engine', 'src', 'opensslsocket.cpp')
        body = source[source.index('int4 MCSocket::write('):]
        body = body[:body.index('rc = SSL_write(')]
        # The tests that hold a write back, one for each platform: the first
        # two after the line that clears SSTATE_RETRYWRITE
        body = body[body.index('sslstate &= ~SSTATE_RETRYWRITE;'):]
        tests = re.findall(r'if \((sslstate &[^{]*)\)\s*\{', body)[:2]
        for test in tests:
            self.assertNotIn('SSTATE_RETRYREAD', test)
            self.assertNotIn('SSLRETRYFLAGS', test)
            self.assertIn('SSTATE_RETRYCONNECT', test)


if __name__ == '__main__':
    unittest.main()
