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

"""tools/web-ide/xtalk_web_libraries.py test-files: the files the web IDE's
xTalk Suite check (tools/ci/web-ide-xtalk.livecodescript) runs besides the
IDE's own extensions.

NostrXT's relay library is the one the check puts in place of the IDE's.
It must be the library the NEXT release ships, the file pinned for the
NostrXT member in tools/oxt/xtalk-extensions.json and checked against that
pin's SHA-256, and not the suite's newest copy: otherwise the check passes
on a browser transport the shipped IDE does not have (it did: the pin was
a commit before the transport, and xTalk Chat in the released web IDE
could not reach a relay). No network: the downloads are faked.
"""

import contextlib
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import xtalk_web_libraries as xwl  # noqa: E402
import xtalk_extensions  # noqa: E402

RELAY_PATH = 'src/nostr-relay.livecodescript'


def nostrxt(data):
    return next(m for m in data['members'] if m['name'] == 'NostrXT')


def relay_file(member):
    return next(f for f in member['files'] if f['path'] == RELAY_PATH)


class PinnedRelayTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        with open(xwl.MANIFEST, encoding='utf-8') as f:
            self.data = json.load(f)
        self.member = nostrxt(self.data)
        self.relay = b'-- the pinned relay library\non nxrConnect pUrl\nend nxrConnect\n'
        relay_file(self.member)['sha256'] = hashlib.sha256(self.relay).hexdigest()
        relay_file(self.member)['size'] = len(self.relay)
        self.manifest = os.path.join(self.tmp, 'xtalk-extensions.json')
        with open(self.manifest, 'w', encoding='utf-8') as f:
            json.dump(self.data, f)
        self.out = os.path.join(self.tmp, 'out')
        self.urls = []

    def fake_get(self, relay):
        def get(url, log, accept=None):
            self.urls.append(url)
            if url.endswith('/' + RELAY_PATH):
                return relay
            return b'-- a test file\n'
        return get

    def run_test_files(self, relay):
        with mock.patch.object(xtalk_extensions, '_http_get', self.fake_get(relay)), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return xwl.main(['--manifest', self.manifest, 'test-files', '--out', self.out])

    def test_relay_comes_from_the_nostrxt_pin(self):
        self.assertEqual(self.run_test_files(self.relay), 0)
        want = 'https://raw.githubusercontent.com/%s/%s/%s' % (
            self.member['repository'], self.member['commit'], RELAY_PATH)
        self.assertIn(want, self.urls)
        # Not the suite's copy at the web libraries' commit
        self.assertFalse(any(u.endswith('/nostrxt/' + RELAY_PATH) for u in self.urls), self.urls)
        with open(os.path.join(self.out, 'nostr-relay.livecodescript'), 'rb') as f:
            body = f.read()
        self.assertEqual(body, xtalk_extensions.wrap_lcs(self.relay, 'nostr-relay', RELAY_PATH)[0])

    def test_relay_that_is_not_the_pinned_one_is_refused(self):
        self.assertEqual(self.run_test_files(self.relay + b'-- changed\n'), 1)
        self.assertFalse(os.path.exists(os.path.join(self.out, 'nostr-relay.livecodescript')))

    def test_the_other_files_still_come_from_the_suite(self):
        self.assertEqual(self.run_test_files(self.relay), 0)
        lib = self.data['web_libraries']['libraries'][0]
        for name, path in xwl.TEST_FILES:
            if name == 'nostr-relay.livecodescript':
                continue
            self.assertIn('https://raw.githubusercontent.com/%s/%s/%s' % (lib['repository'], lib['commit'], path),
                          self.urls)


class ShippedPinTest(unittest.TestCase):
    """The pin itself: NostrXT at a commit that has the browser transport.
    The commit is the first of NostrXT's with it (SethMorrowSoftware/
    xtalk-suite#165, published as NostrXT 1bcdaa5); the browser check
    (web-ide.yml's "Web IDE xTalk Suite" job) is what shows it works."""

    BEFORE_TRANSPORT = 'c26824300eccf7a6e19bf2dc61e20d64dae41fda'

    def test_nostrxt_is_not_pinned_before_the_browser_transport(self):
        with open(xwl.MANIFEST, encoding='utf-8') as f:
            member = nostrxt(json.load(f))
        self.assertNotEqual(member['commit'], self.BEFORE_TRANSPORT)


if __name__ == '__main__':
    unittest.main()
