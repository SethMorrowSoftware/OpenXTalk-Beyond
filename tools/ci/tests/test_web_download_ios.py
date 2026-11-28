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

"""A file the web engine gives the user, on an iPhone or an iPad
(engine/src/em-dialog.js, LiveCodeDialog._download).

The forum's report (CamelCaps, openxtalk.org p=26900): a card saved as a
PDF in a web stack on an iPad "is opened immediately in the same tab as the
player is and so the player needs to be reloaded". The engine gives a file
of /downloads to the browser as a link with a download name, and Safari on
an iPhone or an iPad shows a kind of file it can show (a PDF, a picture, a
text) in the page's own tab instead. There such a file now goes to the
Share sheet, named as it is (Save to Files is there), or, where the Share
sheet cannot take files, to a new tab: never the page's tab. Everything
else is given as before. Run in Node with stand-ins for the browser:

- an iPad (which says it is a Mac, with a touch screen) and an iPhone give
  a PDF to the Share sheet, as a file of its name and type, and click no
  download link;
- without the Share sheet's files, a new tab opens with the file;
- without a tap to answer (no user activation) the user is asked first,
  and the file goes to the Share sheet from the dialog's button;
- a Mac (no touch screen), a Linux or Windows browser, and a zip file on an
  iPad are given the download link as before, named as the file is.

Skipped where Node is missing."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
LIBRARY = os.path.join(REPO, 'engine', 'src', 'em-dialog.js')

NODE_HARNESS = r'''
const fs = require('fs');
const lib = {};
global.LibraryManager = { library: lib };
global.mergeInto = (target, obj) => Object.assign(target, obj);
const setup = JSON.parse(process.argv[3]);
const out = { clicks: [], shares: [], opens: [], dialogs: [] };
global.FS = { readFile: (path) => new Uint8Array([37, 80, 68, 70]) };
global.URL.createObjectURL = (blob) => 'blob:test/' + out.opens.length;
global.URL.revokeObjectURL = () => {};
const share = setup.share ? function (data) {
    out.shares.push(data.files.map((f) => ({ name: f.name, type: f.type, size: f.size })));
    return Promise.resolve();
} : undefined;
const canShare = setup.share ? (data) => !!(data && data.files && data.files.length) : undefined;
Object.defineProperty(global, 'navigator', { value: {
    platform: setup.platform, maxTouchPoints: setup.touch, share: share, canShare: canShare,
    userActivation: { isActive: setup.active }
}, configurable: true });
global.window = { open: (url, target) => { out.opens.push(target); return {}; } };
global.document = {
    body: { appendChild: () => {}, removeChild: () => {} },
    createElement: () => ({ style: {}, click: function () { out.clicks.push(this.download); } })
};
eval(fs.readFileSync(process.argv[2], 'utf8'));
const LCD = lib.$LiveCodeDialog;
global.LiveCodeDialog = LCD;
LCD._dialogs = {};
let pending = null;
LCD.open = function (kind, type, title, message, buttons, text, callback, index) {
    out.dialogs.push({ title: title, message: message, buttons: buttons });
    pending = callback;
    LCD._dialogs[1] = {};
    return 1;
};
out.result = LCD._download(setup.path);
out.beforeAnswer = { shares: out.shares.length, opens: out.opens.length, clicks: out.clicks.length };
if (pending) pending();
setTimeout(() => { console.log(JSON.stringify(out)); process.exit(0); }, 20);
'''

IPAD = {'platform': 'MacIntel', 'touch': 5}
IPHONE = {'platform': 'iPhone', 'touch': 5}
MAC = {'platform': 'MacIntel', 'touch': 0}
LINUX = {'platform': 'Linux x86_64', 'touch': 0}
WINDOWS = {'platform': 'Win32', 'touch': 10}


def run(device, path='/downloads/card.pdf', share=True, active=True):
    node = shutil.which('node')
    if not node:
        return None
    setup = dict(device, path=path, share=share, active=active)
    work = tempfile.mkdtemp()
    try:
        harness = os.path.join(work, 'harness.js')
        with open(harness, 'w', encoding='utf-8') as f:
            f.write(NODE_HARNESS)
        proc = subprocess.run([node, harness, LIBRARY, json.dumps(setup)],
                              capture_output=True, text=True, timeout=60)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    if proc.returncode != 0:
        raise AssertionError(proc.stdout + proc.stderr)
    return json.loads(proc.stdout.strip().splitlines()[-1])


class ADownloadOnAnIPhoneOrIPad(unittest.TestCase):

    def setUp(self):
        if not shutil.which('node'):
            self.skipTest('Node is not installed')

    def test_an_ipad_shares_a_pdf_and_leaves_the_page(self):
        r = run(IPAD)
        self.assertEqual(r['shares'], [[{'name': 'card.pdf', 'type': 'application/pdf', 'size': 4}]])
        self.assertEqual(r['clicks'], [], 'a download link was clicked: Safari shows the PDF in the page\'s tab')
        self.assertEqual(r['opens'], [])
        self.assertTrue(r['result'])

    def test_an_iphone_shares_a_picture(self):
        r = run(IPHONE, path='/downloads/shot.png')
        self.assertEqual(r['shares'], [[{'name': 'shot.png', 'type': 'image/png', 'size': 4}]])
        self.assertEqual(r['clicks'], [])

    def test_without_the_share_sheet_a_new_tab(self):
        r = run(IPAD, share=False)
        self.assertEqual(r['opens'], ['_blank'])
        self.assertEqual(r['clicks'], [])
        self.assertEqual(r['shares'], [])

    def test_without_a_tap_the_user_is_asked_first(self):
        r = run(IPAD, active=False)
        self.assertEqual(r['beforeAnswer'], {'shares': 0, 'opens': 0, 'clicks': 0})
        self.assertEqual(len(r['dialogs']), 1)
        self.assertEqual(r['dialogs'][0]['message'], 'card.pdf')
        self.assertEqual(r['shares'], [[{'name': 'card.pdf', 'type': 'application/pdf', 'size': 4}]])

    def test_a_zip_on_an_ipad_is_a_download_as_before(self):
        r = run(IPAD, path='/downloads/stacks.zip')
        self.assertEqual(r['clicks'], ['stacks.zip'])
        self.assertEqual(r['shares'], [])


class ADownloadElsewhereIsAsBefore(unittest.TestCase):

    def setUp(self):
        if not shutil.which('node'):
            self.skipTest('Node is not installed')

    def test_every_other_browser_clicks_the_download_link(self):
        for name, device in (('a Mac', MAC), ('Linux', LINUX), ('Windows with a touch screen', WINDOWS)):
            with self.subTest(name):
                r = run(device)
                self.assertEqual(r['clicks'], ['card.pdf'])
                self.assertEqual(r['shares'], [])
                self.assertEqual(r['opens'], [])
                self.assertEqual(r['dialogs'], [])
                self.assertTrue(r['result'])


if __name__ == '__main__':
    unittest.main()
