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

"""How the web engine waits when it yields (engine/src/em-async.js).

A browser holds a timer set from inside another timer's callback for at
least 4 ms, and the web engine resumes from its own timers, so every
short yield of a running engine cost 4 ms or more (a game that gave the
page a turn twice a frame lost 8 ms of each frame). A wait shorter than
4 ms now goes round the page's MessageChannel, unless the page turns it
off (do "window.oxtShortWaits = false" as "JavaScript"); a longer one is
a timer, as before. Run in Node (which has MessageChannel) with a stand-in for
Asyncify:

- a wait of 0 or 1 ms sets no timer and resumes once, not before its
  deadline, as timed out;
- a wait of 4 ms or more is still a timer;
- an event that resumes the engine first cancels a short wait: it never
  resumes the engine a second time, and its messages stop going round;
- a chain of short waits, each set as the last resumed (the engine's
  own loop), resumes once for each wait;
- a page that turns them off waits on timers, exactly as before;
- with no MessageChannel, or while the page is hidden (where a browser
  slows its timers down), the engine waits on a timer, as it did.

Skipped where Node is missing."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
LIBRARY = os.path.join(REPO, 'engine', 'src', 'em-async.js')

NODE_HARNESS = r'''
const fs = require('fs');
const lib = {};
global.LibraryManager = { library: lib };
global.mergeInto = (target, obj) => Object.assign(target, obj);
global.assert = (c) => { if (!c) throw new Error('assert'); };
if (process.argv[3] === 'turned-off') global.window = { oxtShortWaits: false };
if (process.argv[3] === 'no-channel') delete global.MessageChannel;
if (process.argv[3] === 'hidden') global.document = { hidden: true };
eval(fs.readFileSync(process.argv[2], 'utf8'));
const LCA = lib.$LiveCodeAsync;
global.LiveCodeAsync = LCA;
// Asyncify: pause() hands its closure the engine's continuation; here
// the continuation records how the engine was resumed.
let onResume = null;
global.Asyncify = {
    handleSleep: (f) => f((v) => { const r = onResume; onResume = null; r(v); }),
    State: { Normal: 0 }, state: 0, currData: null, exportCallStack: [1]
};
let timers = 0;
const realSetTimeout = global.setTimeout;
global.setTimeout = function (f, ms) { timers++; return realSetTimeout(f, ms); };
const now = () => performance.now();
const out = {};
const wait = (ms) => new Promise((res) => {
    const t = now();
    onResume = (v) => res({ v, took: now() - t });
    LCA.pause(ms);
});
(async () => {
    timers = 0;
    let r = await wait(0);
    out.zero = { v: r.v, timers };
    timers = 0;
    r = await wait(1);
    out.one = { v: r.v, timers, early: r.took < 0.95 };
    timers = 0;
    r = await wait(6);
    out.six = { v: r.v, timers, early: r.took < 5.5 };
    // an event first: the engine resumes once, as not timed out
    let resumes = 0;
    onResume = () => { resumes++; };
    LCA.pause(2);
    LCA.resume();
    await new Promise((res) => realSetTimeout(res, 30));
    out.event = { resumes, fromTimeout: LCA.isTimedOut(), stale: LCA._mcHandle !== null && LCA._timeoutHandle === LCA._mcHandle };
    // the engine's loop: each wait set from the last one's resume
    let n = 0;
    const t0 = now();
    await new Promise((res) => {
        const step = () => { n++; if (n === 200) return res(); onResume = step; LCA.pause(0); };
        onResume = step; LCA.pause(0);
    });
    out.chain = { n, ms: now() - t0 };
    console.log(JSON.stringify(out));
    process.exit(0);
})();
realSetTimeout(() => { console.log(JSON.stringify({ timeout: true, out })); process.exit(1); }, 15000);
'''


def run(*extra):
    node = shutil.which('node')
    if not node:
        return None
    work = tempfile.mkdtemp()
    try:
        harness = os.path.join(work, 'harness.js')
        with open(harness, 'w', encoding='utf-8') as f:
            f.write(NODE_HARNESS)
        proc = subprocess.run([node, harness, LIBRARY] + list(extra), capture_output=True, text=True, timeout=60)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    if proc.returncode != 0:
        raise AssertionError(proc.stdout + proc.stderr)
    return json.loads(proc.stdout.strip().splitlines()[-1])


class TheShortWait(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = run()
        cls.plain = run('no-channel')
        cls.hidden = run('hidden')
        cls.off = run('turned-off')

    def setUp(self):
        if self.result is None:
            self.skipTest('no Node')

    def test_a_wait_of_0_ms_sets_no_timer(self):
        self.assertEqual(self.result['zero'], {'v': 0, 'timers': 0})

    def test_a_wait_of_1_ms_is_not_early_and_sets_no_timer(self):
        self.assertEqual(self.result['one'], {'v': 0, 'timers': 0, 'early': False})

    def test_a_longer_wait_is_still_a_timer(self):
        self.assertEqual(self.result['six'], {'v': 0, 'timers': 1, 'early': False})

    def test_an_event_cancels_a_short_wait(self):
        self.assertEqual(self.result['event'], {'resumes': 1, 'fromTimeout': False, 'stale': False})

    def test_the_engines_loop_resumes_once_a_wait(self):
        self.assertEqual(self.result['chain']['n'], 200)
        # 200 waits of 0 ms on a 4 ms timer would take 800 ms or more
        self.assertLess(self.result['chain']['ms'], 400)

    def test_without_a_channel_it_waits_on_a_timer(self):
        self.assertEqual(self.plain['zero'], {'v': 0, 'timers': 1})
        self.assertEqual(self.plain['one']['timers'], 1)

    def test_a_page_that_turns_them_off_waits_on_a_timer_as_before(self):
        self.assertEqual(self.off['zero'], {'v': 0, 'timers': 1})
        self.assertEqual(self.off['one']['timers'], 1)
        self.assertEqual(self.off['six']['timers'], 1)
        self.assertEqual(self.off['event']['resumes'], 1)

    def test_a_hidden_page_waits_on_a_timer(self):
        self.assertEqual(self.hidden['zero'], {'v': 0, 'timers': 1})
        self.assertEqual(self.hidden['one']['timers'], 1)


if __name__ == '__main__':
    unittest.main()
