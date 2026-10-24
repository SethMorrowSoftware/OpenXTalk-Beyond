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

"""Build a web standalone of a probe stack and run it in a headless
browser.

  python3 tools/ci/web_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser B] [--work DIR] [--timeout SECONDS] [--keep-serving]
  python3 tools/ci/web_check.py (--install DIR | --package FILE | --bin DIR)
      [--platform P] [--ide-timeout SECONDS] [--work DIR] [--timeout SECONDS]
  python3 tools/ci/web_check.py --built DIR [--work DIR] [--timeout SECONDS]

The probe stack is tools/ci/web-probe.livecodescript, with a button, a
field, a graphic and a PNG image (tools/ci/web-deploy.livecodescript makes
it). There are three ways to its standalone:

--runtime, without the IDE. DIR is the web runtime: the folder that the
IDE's web builder takes its files from (Runtime/Emscripten/js in an
installed OXT-Beyond, and the web build's output in CI), which holds

  standalone-community-<version>.js and .wasm   the engine
  standalone-community-<version>.html           the page template
  emscripten-standalone-template/               the files every standalone
                                                gets (its fonts)
  emscripten-startup-template.livecodescript    the startup script template

A development engine (--engine; or --engine-cache, which downloads the
Linux x86_64 engine of the OXT-Beyond release that tools/ci/build_docs.sh
pins into that folder, checked against its SHA-256) runs
web-deploy.livecodescript with -ui: it saves the probe stack and writes its
startup data with "_internal deploy emscripten", as the IDE's builder
(ide-support/revsaveasemscriptenstandalone.livecodescript) does, with the
modules of the browser widget and the library it uses from the engine's
packaged_extensions. Any engine can deploy for the web: the deploy command
only writes the stack, the modules and the startup script. This script
then makes the rest as the builder does: standalone.zip gets the template
folder (without dotfiles) and boot/__startup.data, and the folder gets the
engine's .js and .wasm and the page, WebProbe.html, with the stack's title
in its <title>.

--install, --package or --bin, with the IDE's own web builder. The IDE
starts as a user starts it, with web-deploy.livecodescript named on its
command line (as tools/ci/ui_tour.py starts it; under xvfb-run on Linux
without a DISPLAY). Once the IDE has started, the script builds the probe
stack with revSaveAsEmscriptenStandalone and the standalone settings that
a new stack has, and writes its lines to <work>/ide-build.txt. --install
is an installed layout and --package a package to extract, which must hold
the web runtime (Runtime/Emscripten/js in the tools folder); --bin is the
build output of a repository checkout, whose IDE is the checkout's
(repository mode) and whose web runtime is <checkout>/emscripten-bin.

--built, a standalone of the probe stack that is already built: DIR holds
its page, standalone.zip and the engine.

Then:

1. A web server on 127.0.0.1 serves the standalone's folder, and the
   requests the probe makes: GET /probe-data.txt, POST /echo (which
   answers "POST <Content-Type> <body>"), PUT and GET /store, a 404, and
   GET /probe-page.html, the page that its browser widget loads.

2. Headless Chromium (Playwright) opens the page. The probe writes PROBE
   lines to the console (see web-probe.livecodescript): its checks of
   waits (in openStack, in handlers, nested, with messages, until a
   condition), "send ... in", "do ... as JavaScript", files, a font file
   that it starts and stops using, URLs (get, post, put, load with
   message, a missing page), the page's dialogs (answer, answer with two
   buttons, ask), whose default buttons this script clicks, typing "Ada"
   into the ask dialog's field, the standard folders, a file written to
   /downloads (which must reach the browser as a download), the address,
   randomBytes, the modifier keys, the cursor, an audio clip that it plays
   (the samples the browser was given must be the clip's), a player that
   plays the clip's file, and a browser widget (its htmlText, a page of
   the site and "do ... in widget" each call a handler of its
   javascriptHandlers). An IDE without CEF (Linux arm64)
   has no browser widget, so neither has the standalone that it builds:
   the probe then writes "PROBE info browser-widget not loaded" instead of
   that check. Last come the externals that the web engine has: an XML
   tree read with revXML and transformed with XSLT, a zip archive written
   and read back with revZip, and an SQLite database with revDB, whose
   error for a missing table must reach the script as revDB's error (SQLite
   throws a C++ exception for it), and another in the probe's documents
   folder, whose row the browser's storage (IndexedDB) must have soon after
   the probe is ready (in /openxtalk's database: the home folder's name
   since 0.2.7-rc.6.2; then the page opens in a new browser profile whose
   database for /livecode, the old name, has a file, which must be copied
   to /openxtalk's). The builder includes them because the
   probe's scripts use them, and web-deploy.livecodescript names them when
   it builds without the IDE. Then encrypt and decrypt, with the OpenSSL
   that the web engine links: AES with a key and an IV, and Blowfish (of
   OpenSSL's legacy provider) with a password and a salt, which must give
   the desktop engines' bytes, and the cipherNames. Last, revSpeech, which
   speaks with the browser's speech synthesis: this script gives the page
   three voices of its own (headless Chromium has none), one named in
   Japanese, and the probe lists them (all, the female and the male), sets
   the one named in Japanese with a speed, pitch and volume, and speaks a
   text with an e acute and a euro sign, which the browser must be asked to
   say with that voice at the Web Speech API's rate, pitch and volume for
   those (3, 0.5 and 0.5). Then it prints: two pages to the browser, the
   first landscape, which the browser must be asked to print once, each
   page's picture on paper of its size (in the frame that prints, this
   script's print() stands in for the print dialog, and Chromium's PDF of
   that frame's document must have the two pages at their sizes); a job
   that it cancels, which prints nothing; with "open printing to pdf", a
   PDF in /downloads, which must reach the browser as a download and have
   the two pages' pictures, a link to a URL, an anchor and a link to it,
   two bookmarks and the document information that the probe gave; and
   with the printerOutput set to "file:", a PDF of a page in its documents
   folder. When the probe writes "PROBE ready", this
   script clicks the button, types "abc" into the field, and calls the
   stack's handlers from the page (document.liveCode.findStackWithName):
   probeFromJS(21) must return 42, probeReport() "abc|abc|1", and
   probeReport("keys"), with Shift held down, "down|65505". It taps the
   button with a finger, which must be one more click (the browser makes
   up no mouse events of its own after the touch's), and drags a finger
   across the graphic, which must send it mouseDown, mouseMove and mouseUp
   at the finger's points (probeReport("drag")). It drags one field onto
   another with the mouse: the first's dragStart gives the drag a text,
   which the second, an unlocked field, must take, with dragEnter,
   dragDrop and the first's dragEnd (probeReport("dnd")), and the cursor
   over it must say that a drop copies. It drops a file on the graphic
   "Drop Zone" as if from another application (through Chromium's DevTools
   protocol), which must get the path of its copy in /uploads, with the
   file's text (probeReport("drop")). It taps the field with a finger,
   which must bring up a touch screen's keyboard when the touch ends (the
   page gets a VirtualKeyboard API of this script's, as headless Chromium
   has none), and types into it with that keyboard: text with no keys of
   its own and a Backspace, which must reach the field as keys, and the
   keyboard must go away when the field loses the focus (probeUnfocus).
   It holds the mouse down on the graphic "Mouse Zone", whose mouseDown
   loops while the mouse is down and then waits until the mouseClick: the
   loop must see the mouse move and its button go up, and the wait must
   end on a click, with its clickLoc (probeReport("mouse")). With the
   mouse over the graphic, the probe takes snapshots of the page: of the
   graphic by the stack's window, of the whole stack by its rect on the
   screen at half its size, and of the graphic as a PNG, which must have
   the colours drawn, and the mouseColor must be the graphic's
   (probeReport("snapshot")). Then "import snapshot" with no rectangle,
   for which this script drags one out on the graphic over the page,
   must take it, and a second must fail when Escape cancels it. It opens
   a modal dialog (probeReport("modal")): a click on the button under it,
   a click on the field under it and typing must reach neither, the
   dialog's field must take what is typed into it, and its OK button must
   close it; then typing must reach the field again, and a click the
   button. It opens a palette (probeReport("window")): the page must give
   its window a title bar with its title and make it as see-through as
   its blendLevel says, a click on its close box must go through it while
   its ignoreMouseEvents is true, a drag by the title bar must move it
   (moveStack), and a click on the title bar's close box must close it
   (closeStackRequest, closeStack). It has an option menu
   (probeReport("menu")): a click on its button must open its list, and a
   click on the page outside every window must close it with no menuPick,
   twice.
   Then it takes a screenshot of the stack and checks the colours of the
   card, the graphic and the image in it.

The URLs are loaded by the engine, or by the Internet library (libURL)
when the standalone has it: the IDE's builder adds it, with its web
driver, to a stack whose scripts use URLs. The probe reports which ("PROBE
info url-path"), and each has results of its own for a missing page and a
load (see web-probe.livecodescript). A standalone made without the IDE must
use the engine, and one that the IDE made, libURL.

--browser is the browser that opens the page: chromium (the default),
firefox or webkit (Safari's engine), each Playwright's own build. Three
steps drive the browser through Chromium's DevTools protocol, which the
others have not got, and are left out in them, each with a line that says
so: the finger dragged across the graphic, the file dropped from outside
the page, and the paper that the frame which prints is printed on (a PDF
that only Chromium makes). Everything else is checked in all three.

Every check must pass, and nothing may reach the browser's error console
or the page's error handler. The screenshot is written to
<work>/WebProbe.png. --keep-serving keeps the server running after the
checks (Ctrl-C ends it), to open the page in a browser by hand.

Exit status 0 when everything passes, 1 otherwise. Under GitHub Actions
it writes annotations and a job summary. Needs Python 3.8 or later and,
for the browser, the Python package playwright with its browser
(python3 -m playwright install chromium, firefox or webkit).
"""

import argparse
import hashlib
import http.server
import json
import os
import re
import shutil
import socketserver
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DEPLOY_SCRIPT = os.path.join(HERE, 'web-deploy.livecodescript')
PROBE_SCRIPT = os.path.join(HERE, 'web-probe.livecodescript')
BUILD_DOCS = os.path.join(HERE, 'build_docs.sh')

STACK_NAME = 'WebProbe'
STACK_TITLE = 'Web Probe'
PROBE_DATA = 'probe data 123'
PROMPT_ANSWER = 'Ada'
# How long run_browser may take in all before the watchdog fails the
# check, at the least: a run takes about 25 seconds, and each of its waits
# at most --timeout (120 by default), so the limit is five of those when
# that is longer. browser_waiting[0] is what the run is waiting for
BROWSER_LIMIT = 600
browser_waiting = ['']

# The checks the probe makes before it is ready, in its order
PROBE_CHECKS = (
    'platform', 'wait-openstack', 'wait-handler', 'wait-nested', 'wait-until', 'send-in-time',
    'javascript', 'file-roundtrip', 'standalone-folder', 'font-file', 'font-bold', 'url-get', 'url-post', 'url-put',
    'url-missing', 'url-load', 'answer', 'answer-confirm', 'ask', 'folders', 'home-alias', 'download-written',
    'address', 'random-bytes', 'modifiers', 'cursor', 'sound', 'player', 'browser', 'objects',
    'xml', 'xslt', 'zip', 'database', 'database-error', 'database-home',
    'encrypt', 'encrypt-legacy', 'cipher-names', 'speech', 'print',
)

# The formattedWidth of "Hello, World 123" in 14-point plain text, with no
# font set, in "Droid Sans" and in "Arial" (probeFonts): what the font of
# LiveCode's HTML5 standalones gave, which the standalone's font must keep
# so that text wraps where it did
PROBE_PLAIN_WIDTHS = ('105', '105', '105')

# The page of the site that the probe's browser widget loads
PROBE_PAGE = ('<!DOCTYPE html><html><head><title>Probe Page</title></head><body>'
              '<script>liveCode.probeBrowserCall("page", document.title)</script></body></html>')

# ... and the same page in WebKit, which calls the handler once the page
# has its liveCode object. WebKit reads and runs the whole of a small page,
# its load event included, before the stack's page can do anything (seen
# 2026-10-16 in WebKit 26.0 and WebKitGTK 2.48): the engine readies a page
# of the site only after it has loaded, so a script that runs while the
# page is being read finds no liveCode object there (README, "Known
# limitations"). This one looks for it until it is there, for 5 seconds.
PROBE_PAGE_DEFERRED = ('<!DOCTYPE html><html><head><title>Probe Page</title></head><body><script>'
                       '(function call(n) {'
                       'if (window.liveCode) { liveCode.probeBrowserCall("page", document.title); }'
                       'else if (n < 500) { setTimeout(function() { call(n + 1); }, 10); }'
                       '})(0)</script></body></html>')

# The extensions that a standalone made without the IDE gets, from the
# development engine's packaged_extensions, each after those it uses: the
# browser widget, which the probe makes
PROBE_EXTENSIONS = ('com.livecode.library.widgetutils', 'com.livecode.widget.browser')

# The file the probe writes to /downloads, which the browser must download
PROBE_DOWNLOAD = ('probe-download.txt', b'download me')

# The SQLite database that the probe makes in its documents folder, with
# the one row it writes, which the browser's storage must have soon after
# the commit (probeExternals). The web engine keeps the home folder with
# Emscripten's IDBFS (engine/src/em-system.js), which stores each file
# under its path in the object store FILE_DATA of an IndexedDB database
# named after the folder; this reads one file's bytes from there as text,
# or null.
PROBE_HOME_DATABASE = ('/openxtalk/Documents/probe.db', 'kept between visits')
STORED_FILE_JS = '''([database, path]) => new Promise(resolve => {
    var request = indexedDB.open(database);
    request.onerror = () => resolve(null);
    request.onsuccess = () => {
        var db = request.result;
        if (!db.objectStoreNames.contains('FILE_DATA')) {
            db.close();
            resolve(null);
            return;
        }
        var get = db.transaction('FILE_DATA').objectStore('FILE_DATA').get(path);
        get.onerror = () => { db.close(); resolve(null); };
        get.onsuccess = () => {
            var contents = get.result && get.result.contents;
            var text = '';
            for (var i = 0; contents && i < contents.length; i++) {
                text += String.fromCharCode(contents[i]);
            }
            db.close();
            resolve(contents ? text : null);
        };
    };
})'''

# The home folder was /livecode until 0.2.7-rc.6.2 (engine/src/em-system.js):
# what a browser kept there is copied to /openxtalk on its first visit with
# a newer engine. This writes a file into the database that an older engine
# made (IDBFS's, version 21: the object store FILE_DATA, with the index
# timestamp; a folder's entry has its mode, a file's its mode and contents)
# before the page opens, and the copy must reach /openxtalk's database.
LEGACY_HOME_FILE = ('/livecode/Documents/legacy.txt', '/openxtalk/Documents/legacy.txt',
                    'kept by an older engine')
SEED_LEGACY_HOME_JS = '''([path, text]) => new Promise((resolve, reject) => {
    var request = indexedDB.open('/livecode', 21);
    request.onupgradeneeded = () => {
        var store = request.result.objectStoreNames.contains('FILE_DATA') ?
            request.transaction.objectStore('FILE_DATA') :
            request.result.createObjectStore('FILE_DATA');
        if (!store.indexNames.contains('timestamp')) {
            store.createIndex('timestamp', 'timestamp', {unique: false});
        }
    };
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
        var db = request.result;
        var transaction = db.transaction('FILE_DATA', 'readwrite');
        var store = transaction.objectStore('FILE_DATA');
        var now = new Date();
        store.put({timestamp: now, mode: 16895}, path.substring(0, path.lastIndexOf('/')));
        store.put({timestamp: now, mode: 33206,
                   contents: new Uint8Array(Array.from(text, c => c.charCodeAt(0)))}, path);
        transaction.oncomplete = () => { db.close(); resolve(true); };
        transaction.onerror = () => reject(transaction.error);
    };
})'''

# The files that the page writes in its documents folder from two tabs
# (probeReport("home-write <name>")), and what each holds
TWO_TABS_FILES = ('/openxtalk/Documents/first-tab.txt', '/openxtalk/Documents/second-tab.txt')
TWO_TABS_TEXTS = ('written by first-tab', 'written by second-tab')

# What the drag from the field "Drag Source" onto the field "Drag Target"
# sends, and then the target's text (probeReport("dnd"))
PROBE_DND = 'start|enter|drop:dropped text|end:copy|dropped text'

# The file dropped on the graphic "Drop Zone" from outside the page, and
# what the probe reports: its copy's path and text (probeReport("drop"))
PROBE_DROP = ('probe-drop.txt', 'dropped file')
PROBE_DROP_REPORT = '/uploads/probe-drop.txt:dropped file'

# What a touch screen's keyboard types into the field after a tap on it:
# text with no keys of its own, as an IME commits it (with a character
# beyond Unicode's first 65536), then "x", which a Backspace deletes; and
# what the probe then reports (probeReport()): the field's text, the
# keyDowns' keys and the two clicks on the button
PROBE_SOFT_TEXT = ' d\u00e9\U0001F600'
PROBE_SOFT_REPORT = 'abc%s|abc%sx|2' % (PROBE_SOFT_TEXT, PROBE_SOFT_TEXT)

# What the probe's snapshots of the page report (probeReport("snapshot")):
# the graphic's, by the stack's window, with the colour of its middle; the
# whole stack's, by its rect on the screen at half its size, with the
# colours of the graphic and the card in it; the first bytes of a PNG of
# the graphic; and the mouseColor, with the mouse over the graphic
PROBE_SNAPSHOTS = '100x100:204,51,0|240x180:204,51,0:51,102,204|PNG|204,51,0'

# What "import snapshot" with no rectangle reports (probeSnapshotSelect)
# when the rectangle dragged out is the graphic's, 10 points inside it,
# with the colour of its middle; then when Escape cancels it
PROBE_SNAPSHOT_SELECT = ('80x80:204,51,0', 'cancelled')

# What the probe's modal dialog reports when its OK button closes it
# (probeModal): its field's text, typed into it, the clicks on the button
# under it meanwhile, and whether the field under it has the text it had
PROBE_MODAL = 'ok|0|true'

# The title of the probe's palette (probeWindow), which its window's title
# bar shows, its window's opacity in the page (a blendLevel of 40), and
# how far this script drags it by the title bar
PROBE_WINDOW_TITLE = 'Probe Palette'
PROBE_WINDOW_OPACITY = '0.6'
PROBE_WINDOW_DRAG = (40, 20)

# The title bar and close box of the window whose title bar shows <title>
# (em-dc.js): their rects in the page, the frame's class names, whether
# the window is shown, and its opacity; null when no window shows it
WINDOW_FRAME_JS = '''(title) => {
    const window = Array.from(document.querySelectorAll('.oxt-window')).find(function(element) {
        const label = element.querySelector('.oxt-window-label');
        return label && label.textContent == title;
    });
    if (!window) {
        return null;
    }
    const rect = function(element) {
        const r = element.getBoundingClientRect();
        return [r.left, r.top, r.right, r.bottom];
    };
    return {title: rect(window.querySelector('.oxt-window-title')),
            close: rect(window.querySelector('.oxt-window-close')),
            classes: window.className, shown: window.style.display != 'none',
            opacity: window.style.opacity};
}'''

# How many windows the page shows: a menu's list is a window of its own
SHOWN_WINDOWS_JS = '''() => Array.from(document.querySelectorAll('canvas')).filter(function(canvas) {
    const r = canvas.getBoundingClientRect();
    return canvas.dataset.lcWindowId && r.width > 0 && r.height > 0;
}).length'''

# A point of the page, near a corner of the viewport, that no window or
# other element of the page covers ([x, y]), or null if every corner is
PAGE_OUTSIDE_JS = '''() => {
    const w = window.innerWidth, h = window.innerHeight;
    const corners = [[w - 10, h - 10], [10, h - 10], [w - 10, 10], [10, 10]];
    for (const point of corners) {
        const element = document.elementFromPoint(point[0], point[1]);
        if (!element || element == document.body || element == document.documentElement) {
            return point;
        }
    }
    return null;
}'''

# The samples of the audio clip the probe plays, as the browser has them:
# channels, rate, seconds and the tone's frequency (counted from where the
# samples change sign, within 2%)
PROBE_SOUND = {'channels': 1, 'rate': 8000, 'duration': 0.3, 'freq': 400}

# Records the samples the page gives the browser to play, before the page's
# own scripts run
SOUND_HOOK = r'''
window.__oxtSounds = [];
(function() {
  if (!window.AudioBufferSourceNode) {
    return;
  }
  const start = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function() {
    const b = this.buffer;
    const d = b.getChannelData(0);
    let crossings = 0;
    for (let i = 1; i < d.length; i++) {
      if ((d[i - 1] < 0) != (d[i] < 0)) {
        crossings++;
      }
    }
    window.__oxtSounds.push({channels: b.numberOfChannels, rate: b.sampleRate,
                             duration: Math.round(b.duration * 1000) / 1000,
                             freq: Math.round(crossings / 2 / b.duration)});
    return start.apply(this, arguments);
  };
})();
'''

# The voices the page gets (headless Chromium has none), and what the
# probe's revSpeech asks them to say: the text, the voice (by name) and the
# Web Speech API's rate, pitch and volume (probeSpeech: a speed of 390, a
# pitch of 120 and a volume of 50)
PROBE_VOICES = ('Probe Female Voice', 'Probe Male Voice', 'Probe \u65e5\u672c\u8a9e')
PROBE_SPEECH = {'text': 'Caf\u00e9 \u20ac1', 'voice': PROBE_VOICES[2], 'rate': 3.0, 'pitch': 0.5, 'volume': 0.5}

# Gives the page the voices, and records what they are asked to say, before
# the page's own scripts run. Each utterance speaks for 5 seconds, unless
# speech is cancelled.
SPEECH_HOOK = r'''
window.__oxtSpeech = [];
(function() {
  const voices = %s.map(function(name, i) {
    return {name: name, lang: 'en-US', voiceURI: 'probe-voice-' + i, localService: true, default: i == 0};
  });
  let speaking = false;
  let timer = null;
  function SpeechSynthesisUtterance(text) {
    this.text = text === undefined ? '' : String(text);
    this.voice = null;
    this.lang = '';
    this.rate = 1;
    this.pitch = 1;
    this.volume = 1;
  }
  const synthesis = {
    get speaking() { return speaking; },
    get pending() { return false; },
    get paused() { return false; },
    getVoices: function() { return voices.slice(); },
    speak: function(u) {
      window.__oxtSpeech.push({text: u.text, voice: u.voice ? u.voice.name : null,
                               rate: u.rate, pitch: u.pitch, volume: u.volume});
      speaking = true;
      clearTimeout(timer);
      timer = setTimeout(function() { speaking = false; }, 5000);
    },
    cancel: function() { speaking = false; clearTimeout(timer); },
    pause: function() {},
    resume: function() {},
    addEventListener: function() {},
    removeEventListener: function() {},
  };
  Object.defineProperty(window, 'speechSynthesis', {value: synthesis, configurable: true});
  window.SpeechSynthesisUtterance = SpeechSynthesisUtterance;
})();
''' % json.dumps(PROBE_VOICES)

# The pages that the probe prints (probePrint), to the browser and to its
# PDF: US Letter (headless Chromium's language is en-US), at 300 dots an
# inch, with the colours at points of them, in points from their top left.
# The first has the card (480x360) where the layout puts it, at 72,72; the
# second has it at half its size, into 0,0,240,180.
PROBE_PRINT_SIZE = (612, 792)
PROBE_PRINT_PIXELS = (2550, 3300)
# The probe prints the browser's first page landscape (a browser that lays
# out a page on the paper of the page before it puts the second on two)
PROBE_BROWSER_SIZES = (PROBE_PRINT_SIZE[::-1], PROBE_PRINT_SIZE)
PROBE_PRINT_PAGES = (
    (('paper', (36, 36), (255, 255, 255)),
     ('card', (512, 392), (0x33, 0x66, 0xCC)),
     ('graphic', (422, 162), (0xCC, 0x33, 0x00)),
     ('image', (384, 284), (0, 170, 0))),
    (('card', (220, 160), (0x33, 0x66, 0xCC)),
     ('graphic', (175, 45), (0xCC, 0x33, 0x00)),
     ('image', (156, 106), (0, 170, 0)),
     ('paper', (400, 400), (255, 255, 255))),
)
# The PDF that the probe prints to /downloads, with the link, the anchor
# (where its link on the second page goes) and the bookmarks it makes, in
# the PDF's points from the page's bottom left, and its document
# information
PROBE_PDF = 'probe.pdf'
PROBE_PDF_URI = 'https://example.com/probe'
PROBE_PDF_INFO = {'Title': 'Probe PDF', 'Author': 'OXT-Beyond \u00e9'}

# Records what the page asks the browser to print. The frame that prints
# (em-printer.js) runs this too, as every frame of the page does, and its
# print() keeps a copy of each page's picture, with the page's size, and
# of the frame's document, instead of opening the print dialog.
PRINT_HOOK = r'''
if (window === window.top) {
  window.__oxtPrints = [];
} else {
  window.print = function() {
    const pages = Array.from(document.querySelectorAll('.oxt-page')).map(function(page) {
      const image = page.querySelector('img');
      const canvas = window.top.document.createElement('canvas');
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      canvas.getContext('2d').drawImage(image, 0, 0);
      return {width: image.style.width, height: image.style.height, src: image.getAttribute('src'),
              canvas: canvas};
    });
    window.top.__oxtPrints.push({title: document.title, pages: pages,
                                 html: '<!DOCTYPE html>' + document.documentElement.outerHTML});
  };
}
'''

# A touch screen's keyboard for the page: headless Chromium has none, so
# the page gets a VirtualKeyboard API (Chrome's) of this script's, which
# records what the page asks of it
KEYBOARD_HOOK = r'''
(function() {
  window.__oxtKeyboard = [];
  const keyboard = {
    show: function() { window.__oxtKeyboard.push('show'); },
    hide: function() { window.__oxtKeyboard.push('hide'); },
    overlaysContent: false,
    boundingRect: new DOMRect(0, 0, 0, 0),
    addEventListener: function() {},
    removeEventListener: function() {},
  };
  Object.defineProperty(navigator, 'virtualKeyboard', {value: keyboard, configurable: true});
})();
'''

# Colours in the screenshot, at points of the card (the probe's stack is
# 480x360; see web-deploy.livecodescript)
COLOURS = (
    ('card', (440, 320), (0x33, 0x66, 0xCC)),
    ('graphic', (350, 90), (0xCC, 0x33, 0x00)),
    ('image', (312, 212), (0, 170, 0)),
)


def log(msg=''):
    print(msg, flush=True)


def gha():
    return os.environ.get('GITHUB_ACTIONS') == 'true'


def annotate(kind, msg):
    if gha():
        print('::%s::%s' % (kind, msg.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')), flush=True)


def summary(text):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if path:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(text)


class CheckError(Exception):
    pass


# ---------------------------------------------------------------------------
# The engines

def runtime_files(runtime):
    """(version, js, wasm, html) of the web runtime folder."""
    found = {}
    for name in os.listdir(runtime):
        m = re.match(r'^standalone-community-(.+)\.(js|wasm|html)$', name)
        if m:
            found.setdefault(m.group(1), {})[m.group(2)] = os.path.join(runtime, name)
    complete = [v for v, files in found.items() if len(files) == 3]
    if len(complete) != 1:
        raise CheckError('%s must hold one engine, standalone-community-<version>.js, .wasm and .html; it has %s'
                         % (runtime, ', '.join(sorted(os.listdir(runtime))) or 'nothing'))
    version = complete[0]
    files = found[version]
    for name in ('emscripten-standalone-template', 'emscripten-startup-template.livecodescript'):
        if not os.path.exists(os.path.join(runtime, name)):
            raise CheckError('%s has no %s' % (runtime, name))
    return version, files['js'], files['wasm'], files['html']


def pinned_engine():
    """(version, url, sha256) of the engine that build_docs.sh pins."""
    with open(BUILD_DOCS, encoding='utf-8') as f:
        text = f.read()
    values = dict(re.findall(r'(?m)^DOCS_ENGINE_(VERSION|URL|SHA256)=(\S+)$', text))
    if sorted(values) != ['SHA256', 'URL', 'VERSION']:
        raise CheckError('%s does not pin an engine (DOCS_ENGINE_VERSION, _URL, _SHA256)' % BUILD_DOCS)
    url = values['URL'].replace('$DOCS_ENGINE_VERSION', values['VERSION'])
    return values['VERSION'], url, values['SHA256']


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def fetch_engine(cache):
    """The development engine of the pinned release, downloaded into cache
    (once)."""
    version, url, sha256 = pinned_engine()
    os.makedirs(cache, exist_ok=True)
    folder = os.path.join(cache, 'engine-' + version)
    engine = os.path.join(folder, 'linux-x86_64-bin', 'LiveCode-Community')
    if os.path.isfile(engine):
        return engine
    tarball = os.path.join(cache, url.rsplit('/', 1)[1])
    if not os.path.isfile(tarball) or sha256_of(tarball) != sha256:
        log('Downloading the development engine of OXT-Beyond %s' % version)
        with urllib.request.urlopen(url, timeout=300) as r, open(tarball + '.part', 'wb') as f:
            shutil.copyfileobj(r, f)
        os.replace(tarball + '.part', tarball)
    if sha256_of(tarball) != sha256:
        raise CheckError('%s does not have the SHA-256 that build_docs.sh pins' % tarball)
    shutil.rmtree(folder, ignore_errors=True)
    with tarfile.open(tarball) as tar:
        tar.extractall(folder)
    if not os.path.isfile(engine):
        raise CheckError('%s has no linux-x86_64-bin/LiveCode-Community' % tarball)
    return engine


# ---------------------------------------------------------------------------
# 1. The standalone

def deploy(engine, runtime, version, work, timeout, modules=(), kind='probe', script=PROBE_SCRIPT):
    """Write <work>/__startup.data with the development engine; modules are
    the module.lcm files of the extensions to include, each after those it
    uses. kind "tests" makes the stack of tools/ci/web_tests.py from script
    (see web-deploy.livecodescript) instead of the probe stack."""
    stack = os.path.join(work, STACK_NAME + '.livecode')
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ)
    env.update(OXT_WEB_PROBE=script, OXT_WEB_STACK=stack, OXT_WEB_OUTPUT=output, OXT_WEB_VERSION=version,
               OXT_WEB_TEMPLATE=os.path.join(runtime, 'emscripten-startup-template.livecodescript'),
               OXT_WEB_MODULES='\n'.join(modules), OXT_WEB_KIND=kind)
    try:
        r = subprocess.run([engine, '-ui', DEPLOY_SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise CheckError('the deploy did not finish within %d seconds' % timeout)
    except OSError as e:
        raise CheckError('cannot run %s: %s' % (engine, e))
    out = r.stdout.decode('utf-8', 'replace').splitlines()
    for line in out + r.stderr.decode('utf-8', 'replace').splitlines():
        if line.strip():
            log('  deploy: %s' % line)
    if r.returncode != 0 or not any(x.startswith('DEPLOY OK') for x in out):
        why = next((x for x in out if x.startswith('DEPLOY FAILED')), 'exit status %s, no DEPLOY line' % r.returncode)
        raise CheckError('deploying the %s stack failed: %s' % (kind, why))
    return output


def engine_modules(engine):
    """The module.lcm files of PROBE_EXTENSIONS in the development engine's
    packaged_extensions."""
    modules = []
    for name in PROBE_EXTENSIONS:
        module = os.path.join(os.path.dirname(engine), 'packaged_extensions', name, 'module.lcm')
        if not os.path.isfile(module):
            raise CheckError('the engine has no %s' % module)
        modules.append(module)
    return modules


def make_standalone(runtime, js, wasm, html, startup_data, site, files=(), title=STACK_TITLE):
    """The standalone folder <site>, as the builder makes it; files are
    (path in standalone.zip, file) pairs to add, as the builder adds the
    files of the Copy Files pane under boot/standalone/, and title the
    page's title."""
    os.makedirs(site, exist_ok=True)
    template = os.path.join(runtime, 'emscripten-standalone-template')
    with zipfile.ZipFile(os.path.join(site, 'standalone.zip'), 'w', zipfile.ZIP_STORED) as z:
        # the builder's scanFolder leaves out names that start with "."
        for root, dirs, names in os.walk(template):
            dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
            for name in sorted(names):
                if not name.startswith('.'):
                    path = os.path.join(root, name)
                    z.write(path, os.path.relpath(path, template).replace(os.sep, '/'))
        z.write(startup_data, 'boot/__startup.data')
        for name, path in files:
            z.write(path, name)
    for path in (js, wasm):
        shutil.copyfile(path, os.path.join(site, os.path.basename(path)))
    with open(html, encoding='utf-8') as f:
        page = f.read()
    if '@STACK_TITLE@' not in page:
        raise CheckError('%s has no @STACK_TITLE@ for the builder to replace' % html)
    page = page.replace('@STACK_TITLE@', title)
    with open(os.path.join(site, STACK_NAME + '.html'), 'w', encoding='utf-8') as f:
        f.write(page)


def built_files(site):
    """(version, page) of a standalone's folder: its engine
    (standalone-community-<version>.js and .wasm), standalone.zip and the
    probe's page."""
    if not os.path.isdir(site):
        raise CheckError('%s is not a folder' % site)
    names = sorted(os.listdir(site))
    found = {}
    for name in names:
        m = re.match(r'^standalone-community-(.+)\.(js|wasm)$', name)
        if m:
            found.setdefault(m.group(1), set()).add(m.group(2))
    complete = [v for v, kinds in found.items() if kinds == {'js', 'wasm'}]
    if len(complete) != 1:
        raise CheckError('%s must hold one engine, standalone-community-<version>.js and .wasm; it has %s'
                         % (site, ', '.join(names) or 'nothing'))
    for name in ('standalone.zip', STACK_NAME + '.html'):
        if name not in names:
            raise CheckError('%s has no %s; it has %s' % (site, name, ', '.join(names)))
    return complete[0], os.path.join(site, STACK_NAME + '.html')


def build_with_ide(args, work, timeout):
    """Build the probe's standalone with the IDE's web builder (see the
    header) into <work>/site. Returns (site, lines, browser): browser is
    whether the IDE had the browser widget, which an IDE without CEF (Linux
    arm64) leaves out, and so its builder (None: it did not say)."""
    # the IDE is started as tools/ci/ui_tour.py starts it
    import ui_tour
    package, rlc = ui_tour.package, ui_tour.rlc
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    site = os.path.join(work, 'site')
    shutil.rmtree(site, ignore_errors=True)
    results = os.path.join(work, 'ide-build.txt')
    if os.path.exists(results):
        os.remove(results)
    # the document the IDE opens; a copy, as ui_tour.py opens its script
    document = os.path.join(work, 'oxt_web_deploy.livecodescript')
    shutil.copyfile(DEPLOY_SCRIPT, document)
    temp_dirs, lines, problems = [], [], []
    try:
        args.engine = None
        try:
            lay = rlc.find_layout(args, p, temp_dirs)
        except rlc.CheckError as e:
            raise CheckError(str(e))
        log('Layout : %s' % lay.root)
        log('Engine : %s' % lay.engine)

        def path(x):
            return x.replace('\\', '/')
        env = dict(os.environ)
        env.update(OXT_WEB_PROBE=path(PROBE_SCRIPT), OXT_WEB_STACK=path(os.path.join(work, STACK_NAME + '.livecode')),
                   OXT_WEB_OUTPUT=path(site), OXT_WEB_LOG=path(results))
        cmd = [lay.engine, document]
        if p.family == 'linux':
            # as ui_tour.py: without CEF (arm64) there is no browser widget
            # (a build folder, whose externals are at its top, has CEF in
            # its Externals folder)
            cef = os.path.join(lay.root, 'Externals') if lay.kind == 'development' else lay.externals
            if 'LIVECODE_USE_CEF' not in env and not os.path.isfile(os.path.join(cef, 'CEF', 'libcef.so')):
                env['LIVECODE_USE_CEF'] = '0'
            if not env.get('DISPLAY'):
                xvfb = shutil.which('xvfb-run')
                if not xvfb:
                    raise CheckError('no DISPLAY and no xvfb-run')
                cmd = [xvfb, '-a', '-s', '-screen 0 1440x900x24'] + cmd
        log('Running: %s' % ' '.join(cmd))
        started = time.time()
        progress = started
        status = 'did not finish within %d seconds' % timeout
        with open(os.path.join(work, 'ide-output.txt'), 'wb') as engine_log:
            kw = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else \
                {'start_new_session': True}
            proc = subprocess.Popen(cmd, cwd=work, env=env, stdout=engine_log, stderr=subprocess.STDOUT, **kw)
            try:
                while time.time() - started < timeout:
                    done = ui_tour.read_lines(results)
                    if any(x.startswith('DONE') for x in done):
                        status = None
                        break
                    if proc.poll() is not None:
                        status = 'the IDE ended with exit status %s after %.0f s' % (
                            proc.returncode, time.time() - started)
                        break
                    if time.time() - progress >= 15:
                        progress = time.time()
                        log('  after %.0f s: %s' % (progress - started, done[-1] if done else '(no lines yet)'))
                    time.sleep(0.5)
                # where a Mac's IDE stopped (ui_tour.py does the same)
                if status and p.family == 'mac' and proc.poll() is None:
                    if ui_tour.mac_screen(os.path.join(work, 'ide-screen-at-the-end.png')):
                        log('  (the screen when the build stopped: ide-screen-at-the-end.png)')
                    ui_tour.mac_sample(proc.pid, os.path.join(work, 'ide-sample-at-the-end.txt'))
                    if ui_tour.mac_app(lay.engine):
                        ui_tour.mac_ask(ui_tour.mac_app(lay.engine))
                    ui_tour.mac_tools_log()
            finally:
                ui_tour.stop(proc)
        browser = None
        for line in ui_tour.read_lines(results):
            log('  ide: %s' % line)
            if line.startswith('BUILD FAILED') or line.startswith('ERROR'):
                problems.append('the IDE\'s web build: %s' % line)
            if line.startswith('INFO browser-extension-loaded '):
                browser = line.split()[-1] == 'true'
        if status:
            problems.append('the IDE\'s web build %s' % status)
            for line in ui_tour.read_lines(os.path.join(work, 'ide-output.txt'))[-40:]:
                log('  ide output: %s' % line)
        else:
            lines.append('the IDE built the standalone in %.0f s' % (time.time() - started))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
    if problems:
        raise CheckError('; '.join(problems))
    return site, lines, browser


# ---------------------------------------------------------------------------
# 2. The web server

def make_server(site, probe_page=PROBE_PAGE):
    stored = {}

    class Handler(http.server.SimpleHTTPRequestHandler):
        extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map,
                              **{'.wasm': 'application/wasm', '.js': 'text/javascript'})

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=site, **kwargs)

        def log_message(self, fmt, *args):
            pass

        def reply(self, code, body, content_type='text/plain; charset=utf-8'):
            data = body.encode('utf-8')
            self.send_response(code)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(data)

        def body(self):
            return self.rfile.read(int(self.headers.get('Content-Length') or 0)).decode('utf-8', 'replace')

        def do_GET(self):
            if self.path == '/probe-data.txt':
                return self.reply(200, PROBE_DATA)
            if self.path == '/store':
                return self.reply(200, stored.get('store', ''))
            if self.path == '/missing':
                return self.reply(404, 'not found')
            if self.path == '/probe-page.html':
                return self.reply(200, probe_page, 'text/html; charset=utf-8')
            return super().do_GET()

        def do_POST(self):
            if self.path == '/echo':
                return self.reply(200, 'POST %s %s' % (self.headers.get('Content-Type', ''), self.body()))
            return self.reply(404, 'not found')

        def do_PUT(self):
            if self.path == '/store':
                stored['store'] = self.body()
                return self.reply(201, '')
            return self.reply(404, 'not found')

    class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True

    server = Server(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# ---------------------------------------------------------------------------
# 3. The browser

def parse_rect(text):
    parts = [int(x) for x in text.split(',')]
    if len(parts) != 4:
        raise CheckError('not a rectangle: %r' % text)
    return parts


def pdf_text(text):
    """A PDF text string as the web engine writes it: UTF-16BE after its
    byte order mark, in hexadecimal"""
    return b'<' + ('\ufeff' + text).encode('utf-16-be').hex().upper().encode() + b'>'


def pdf_objects(data):
    """The objects of a PDF that the web engine wrote (em-printer.cpp), by
    number, as their bytes, found through its cross-reference table, which
    must be right; and its trailer"""
    end = re.search(rb'startxref\n(\d+)\n%%EOF\n$', data)
    if not data.startswith(b'%PDF-1.4\n') or not end:
        raise CheckError('it is not a PDF of the web engine\'s: %r ... %r' % (data[:16], data[-32:]))
    xref = int(end.group(1))
    lines = data[xref:].split(b'\n')
    header = lines[1].split() if len(lines) > 1 else []
    if lines[0] != b'xref' or len(header) != 2 or header[0] != b'0' or not header[1].isdigit():
        raise CheckError('startxref does not point to a cross-reference table')
    count = int(header[1])
    offsets = {}
    for number in range(1, count):
        entry = lines[2 + number] + b'\n'
        if len(entry) != 20 or not entry.endswith(b' 00000 n \n'):
            raise CheckError('the cross-reference entry of object %d is %r' % (number, entry))
        offsets[number] = int(entry[:10])
        if not data.startswith(b'%d 0 obj\n' % number, offsets[number]):
            raise CheckError('the cross-reference table puts object %d at %d, where %r is'
                             % (number, offsets[number], data[offsets[number]:offsets[number] + 16]))
    starts = sorted(offsets.values()) + [xref]
    objects = {number: data[offset:starts[starts.index(offset) + 1]] for number, offset in offsets.items()}
    trailer = data[data.index(b'trailer', xref):]
    return objects, trailer


def pdf_ref(text, key):
    """The number of the object that <key> of a dictionary refers to"""
    found = re.search(rb'/' + key + rb' (\d+) 0 R', text)
    if not found:
        raise CheckError('no /%s in %r' % (key.decode(), text[:200]))
    return int(found.group(1))


def check_pdf(data):
    """The problems with the PDF that the probe printed: its two pages, each a
    picture with the colours of PROBE_PRINT_PAGES, the link of each (to
    PROBE_PDF_URI, and to the anchor "Probe", which a link to "probe"
    finds), the anchor, the bookmarks (the second a child of the first) and
    the document information"""
    problems = []
    objects, trailer = pdf_objects(data)
    catalog = objects[pdf_ref(trailer, b'Root')]
    kids = re.search(rb'/Kids \[([^\]]*)\]', objects[pdf_ref(catalog, b'Pages')]).group(1)
    pages = [int(n) for n in re.findall(rb'(\d+) 0 R', kids)]
    if len(pages) != len(PROBE_PRINT_PAGES):
        return ['it has %d pages, expected %d' % (len(pages), len(PROBE_PRINT_PAGES))]
    media_box = b'/MediaBox [0 0 %d %d]' % PROBE_PRINT_SIZE
    for number, (page, points) in enumerate(zip(pages, PROBE_PRINT_PAGES), 1):
        if media_box not in objects[page]:
            problems.append('page %d is not %r: %r' % (number, media_box, objects[page][:200]))
        image = objects[pdf_ref(objects[page], b'Im0')]
        width = int(re.search(rb'/Width (\d+)', image).group(1))
        height = int(re.search(rb'/Height (\d+)', image).group(1))
        length = int(objects[pdf_ref(image, b'Length')].split(b'\n')[1])
        start = image.index(b'>>\nstream\n') + len(b'>>\nstream\n')
        pixels = zlib.decompress(image[start:start + length])
        if (width, height) != PROBE_PRINT_PIXELS or len(pixels) != width * height * 3:
            problems.append('page %d\'s picture is %dx%d with %d bytes, expected %dx%d in RGB'
                            % ((number, width, height, len(pixels)) + PROBE_PRINT_PIXELS))
            continue
        for name, (x, y), want in points:
            at = (int(y * height / PROBE_PRINT_SIZE[1]) * width + int(x * width / PROBE_PRINT_SIZE[0])) * 3
            got = tuple(pixels[at:at + 3])
            if any(abs(a - b) > 8 for a, b in zip(got, want)):
                problems.append('page %d of the PDF has the %s at %s in %s, expected %s'
                                % (number, name, (x, y), got, want))
    # the links: to the URI on the first page, to the anchor on the second
    links = [b'/Rect [72 360 552 720] /Border [0 0 0] /A << /S /URI /URI <%s> >>'
             % PROBE_PDF_URI.encode().hex().upper().encode(),
             b'/Rect [0 692 100 792] /Border [0 0 0] /A << /S /GoTo /D <%s> >>' % b'Probe'.hex().upper().encode()]
    for number, (page, link) in enumerate(zip(pages, links), 1):
        annotations = re.search(rb'/Annots \[(\d+) 0 R\]', objects[page])
        if not annotations or link not in objects[int(annotations.group(1))]:
            problems.append('page %d does not have the link %r' % (number, link))
    # the anchor, on the first page
    anchor = b'<%s> [%d 0 R /XYZ 72 720 null]' % (b'Probe'.hex().upper().encode(), pages[0])
    names = re.search(rb'/Names << /Dests (\d+) 0 R >>', catalog)
    if not names or anchor not in objects[int(names.group(1))]:
        problems.append('the PDF does not have the anchor %r' % anchor)
    # the bookmarks: "Probe card" on the first page, with "Second page" (on
    # the second) in it
    try:
        outlines = objects[pdf_ref(catalog, b'Outlines')]
        first = objects[pdf_ref(outlines, b'First')]
        child = objects[pdf_ref(first, b'First')]
        if (b'/Count 2' not in outlines or pdf_text('Probe card') not in first or b'/Count 1' not in first
                or (b'/Dest [%d 0 R /XYZ 72 720 null]' % pages[0]) not in first
                or pdf_text('Second page') not in child
                or (b'/Dest [%d 0 R /XYZ 0 792 null]' % pages[1]) not in child):
            problems.append('the bookmarks are not "Probe card" with "Second page" in it: %r %r %r'
                            % (outlines, first, child))
    except CheckError as e:
        problems.append('the PDF does not have its bookmarks: %s' % e)
    # the document information
    info = objects[pdf_ref(trailer, b'Info')]
    for key, value in PROBE_PDF_INFO.items():
        if b'/%s %s' % (key.encode(), pdf_text(value)) not in info:
            problems.append('the document information does not have the %s %r: %r' % (key, value, info))
    return problems


def printed_paper(browser, html):
    """The paper, in points, of the pages that Chromium prints a document on,
    in their order: <html>, as the frame that prints a web standalone's
    pages (em-printer.js) has it, printed to a PDF in a page of its own (a
    description of what went wrong instead, as a string)"""
    page = None
    try:
        page = browser.new_page()
        page.set_content(html)
        pdf = page.pdf(prefer_css_page_size=True, print_background=True)
        # the page objects of the PDF (Chromium's are not compressed), from
        # its catalog's page tree
        objects = dict((int(m.group(1)), m.group(2)) for m in
                       re.finditer(rb'(?m)^(\d+) 0 obj\s*(<<.*?)(?:\bstream\b|\bendobj\b)', pdf, re.S))

        def pages(number):
            body = objects[number]
            if re.search(rb'/Type\s*/Pages\b', body):
                kids = re.search(rb'/Kids\s*\[([^\]]*)\]', body).group(1)
                return [paper for kid in re.findall(rb'(\d+)\s+0\s+R', kids) for paper in pages(int(kid))]
            left, bottom, right, top = (float(v) for v in re.search(rb'/MediaBox\s*\[([^\]]*)\]', body).group(1).split())
            return [[round(right - left), round(top - bottom)]]
        root = int(re.search(rb'trailer\s*<<.*?/Root\s+(\d+)\s+0\s+R', pdf, re.S).group(1))
        return pages(int(re.search(rb'/Pages\s+(\d+)\s+0\s+R', objects[root]).group(1)))
    except Exception as e:
        return 'none: %s' % e
    finally:
        if page:
            page.close()


def touch_drag_ok(report, points):
    """Whether the probe's report of a drag across its graphic
    (probeReport("drag"): "down@x,y move@x,y up@x,y", each with the mouse's
    place on the card) is what a finger at the points (on the card, the
    first where it touched and the last where it lifted) does: mouseDown
    where it touched, a mouseMove on its way, and mouseUp where it lifted
    (the engine may join moves, so the mouseMove may be at any point after
    the first)."""
    try:
        sent = [(word.split('@')[0], tuple(int(n) for n in word.split('@')[1].split(',')))
                for word in (report or '').split()]
    except (IndexError, ValueError):
        return False
    if [name for name, _ in sent] != ['down', 'move', 'up']:
        return False

    def near(at, point):
        return abs(at[0] - point[0]) <= 1 and abs(at[1] - point[1]) <= 1

    moved = sent[1][1]
    return (near(sent[0][1], points[0]) and near(sent[2][1], points[-1])
            and points[0][0] < moved[0] <= points[-1][0] + 1 and abs(moved[1] - points[0][1]) <= 1)


def snapshot_report_ok(report, wanted):
    """Whether the probe's report of snapshots (PROBE_SNAPSHOTS,
    PROBE_SNAPSHOT_SELECT) is the one wanted, each colour in it (red,
    green, blue) within 8 of the colour wanted"""
    split = lambda text: text.replace('|', ':').split(':')
    got, want = split(report or ''), split(wanted)
    if len(got) != len(want):
        return False
    for part, wanted_part in zip(got, want):
        if wanted_part.count(',') == 2:
            try:
                colour = [int(n) for n in part.split(',')]
            except ValueError:
                return False
            if len(colour) != 3 or any(abs(a - int(b)) > 8 for a, b in zip(colour, wanted_part.split(','))):
                return False
        elif part != wanted_part:
            return False
    return True


def browser_watchdog(browser_name, limit=BROWSER_LIMIT):
    """Start and return a timer that fails the check when run_browser
    has not returned within limit seconds. A Playwright call that never
    returns cannot be timed out from its own thread, so the timer names
    what the run was waiting for and ends the process, well inside the
    job's timeout, where a hang left only "The action has timed out"."""
    def hung():
        why = ('the check hung in %s for %d seconds, waiting for %s; the browser stopped answering'
               % (browser_name, limit, browser_waiting[0]))
        log('FAILED:')
        log('  ' + why)
        annotate('error', 'web check: ' + why)
        summary('### Web standalone check (%s)\n\n**Failed:** %s\n\n' % (browser_name, why))
        sys.stdout.flush()
        os._exit(1)

    timer = threading.Timer(limit, hung)
    timer.daemon = True
    timer.start()
    return timer


def run_browser(url, version, work, timeout, url_path=None, browser_widget=None, browser_name='chromium'):
    """Open the page in browser_name and check what the probe and the page do; url_path is
    what must load the probe's URLs, 'engine' or 'libURL' (None: either),
    and browser_widget whether the standalone must have the browser widget
    (None: the probe's check of it may also be left out, when it has none).
    Returns (problems, lines)."""
    try:
        from playwright.sync_api import sync_playwright, Error as PlaywrightError
        from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
    except ImportError:
        raise CheckError('the Python package playwright is missing (pip install playwright, then '
                         'python3 -m playwright install chromium)')
    problems, lines, console, page_errors, downloads = [], [], [], [], []
    probes = {}
    info = {}

    def on_console(msg):
        text = msg.text
        console.append((msg.type, text))
        if text.startswith('PROBE '):
            log('  %s' % text)
            parts = text[6:].split(' ', 2) + ['', '']
            if parts[0] == 'info':
                info[parts[1]] = parts[2]
            else:
                probes.setdefault(parts[0], []).append((parts[1], parts[2]))
        else:
            log('  console.%s: %s' % (msg.type, text))

    def on_dialog(dialog):
        log('  dialog (%s): %s' % (dialog.type, dialog.message))
        if dialog.type == 'prompt':
            dialog.accept(PROMPT_ANSWER)
        else:
            dialog.accept()

    def answer_page_dialog():
        # The page's dialogs (em-dialog.js), which the engine's answer and
        # ask show: the default button, after "Ada" in the field if any.
        # Locator.count() never returns once the page has crashed, so the
        # dialog is looked for with a wait that times out
        dialog = page.locator('.oxt-dialog').first
        try:
            dialog.wait_for(state='visible', timeout=50)
        except PlaywrightTimeoutError:
            return
        message = dialog.locator('.oxt-dialog-message')
        message = message.first.text_content() if message.count() else ''
        buttons = dialog.locator('.oxt-dialog-button').all_text_contents()
        field = dialog.locator('input')
        log('  page dialog: %r %r%s' % (message, buttons, ' (with a field)' if field.count() else ''))
        if field.count():
            field.first.fill(PROMPT_ANSWER)
        dialog.locator('.oxt-dialog-default').click(timeout=5000)

    def on_download(download):
        try:
            with open(download.path(), 'rb') as f:
                content = f.read()
        except (OSError, PlaywrightError) as e:
            content = 'unreadable: %s' % e
        log('  download %s: %r' % (download.suggested_filename, content[:80]))
        downloads.append((download.suggested_filename, content))

    def on_page_error(error):
        page_errors.append(str(error))
        log('  page error: %s' % error)

    # The browser's process for the page can die under it ("Target
    # crashed"): WebKit's did in CI before the engine had started, on
    # commits that passed before and after. On 2026-10-20 the run
    # then hung until the job's 15 minutes ran out, with nothing in the
    # log: a Playwright call on a crashed page can wait for ever
    # (Locator.count() in answer_page_dialog did, in Chromium as well).
    # That call is gone, the crashed page is not touched again, the second
    # try gets a browser of its own, and browser_watchdog ends a run that
    # hangs anyway
    crashed = []

    def on_crash(crashed_page):
        crashed.append(crashed_page)
        log('  the page crashed')

    def wait_for(predicate, what, seconds):
        browser_waiting[0] = what
        deadline = time.time() + seconds
        while time.time() < deadline:
            if predicate():
                return True
            if page_errors or crashed:
                return False
            try:
                answer_page_dialog()
            except PlaywrightError as e:
                log('  could not answer a page dialog: %s' % e)
            page.wait_for_timeout(100)
        problems.append('%s did not happen within %d seconds' % (what, seconds))
        return False

    browser_waiting[0] = '%s to start' % browser_name
    with sync_playwright() as p:
        browser = getattr(p, browser_name).launch()
        devtools = browser_name == 'chromium'
        lines.append('browser: %s %s' % (browser_name, browser.version))

        def open_page():
            opened = browser.new_page(viewport={'width': 800, 'height': 600}, accept_downloads=True,
                                      has_touch=True)
            opened.on('console', on_console)
            opened.on('dialog', on_dialog)
            opened.on('download', on_download)
            opened.on('pageerror', on_page_error)
            opened.on('crash', on_crash)
            opened.add_init_script(SOUND_HOOK)
            opened.add_init_script(SPEECH_HOOK)
            opened.add_init_script(PRINT_HOOK)
            opened.add_init_script(KEYBOARD_HOOK)
            return opened

        page = open_page()
        started = time.time()
        page.goto(url)
        engine_started = wait_for(lambda: 'version' in info, 'the engine starting (PROBE info version)',
                                  timeout)
        if not engine_started and crashed and not info and not probes:
            # A crash before the engine said anything is the browser's, not
            # the standalone's: the page gets one more try, which the report
            # names, and a second crash fails the check
            lines.append('the page crashed before the engine started; it was opened again')
            log('  the page crashed before the engine started; opening it again in a new browser')
            # The crashed page and its browser are left alone, since a call
            # on them may never return; sync_playwright's exit stops them
            # with the driver
            browser_waiting[0] = 'a new %s to start after the crash' % browser_name
            browser = getattr(p, browser_name).launch()
            del crashed[:]
            del console[:]
            browser_waiting[0] = 'the page to open again after the crash'
            page = open_page()
            started = time.time()
            page.goto(url)
            engine_started = wait_for(lambda: 'version' in info,
                                      'the engine starting (PROBE info version)', timeout)
        if not engine_started:
            problems.append('the page did not start the engine')
        else:
            lines.append('the engine started in %.1f s' % (time.time() - started))
            if info['version'] != version:
                problems.append('the engine reports the version %r, expected %r' % (info['version'], version))
            if wait_for(lambda: 'ready' in probes, 'the probe\'s checks', timeout):
                lines.append('the probe ran its checks in %.1f s' % (time.time() - started))
            title = page.title()
            if title != STACK_TITLE:
                problems.append('the page\'s title is %r, expected %r' % (title, STACK_TITLE))
        if 'ready' in probes and not page_errors:
            try:
                canvas = page.locator('#canvas').bounding_box()
                if not canvas:
                    raise CheckError('the page has no canvas')

                def at(rect):
                    left, top, right, bottom = parse_rect(rect)
                    return canvas['x'] + (left + right) / 2, canvas['y'] + (top + bottom) / 2

                # the probe's database, in the browser's storage
                stored = [None]

                def database_stored():
                    stored[0] = page.evaluate(STORED_FILE_JS, ['/openxtalk', PROBE_HOME_DATABASE[0]])
                    return bool(stored[0]) and stored[0].startswith('SQLite format 3\x00') \
                        and PROBE_HOME_DATABASE[1] in stored[0]
                if wait_for(database_stored, 'the probe\'s database reaching the browser\'s storage', 5):
                    lines.append('the probe\'s SQLite database in its documents folder reached the '
                                 'browser\'s storage')
                else:
                    problems.append('the browser\'s storage has %s for %s, expected an SQLite database '
                                    'with the row %r' % ('%d bytes' % len(stored[0]) if stored[0] else 'nothing',
                                                         PROBE_HOME_DATABASE[0], PROBE_HOME_DATABASE[1]))

                # a click on the button, and keys typed into the field
                page.mouse.click(*at(info['button-rect']))
                wait_for(lambda: 'click' in probes, 'the button\'s mouseUp', 10)
                page.mouse.click(*at(info['field-rect']))
                page.wait_for_timeout(200)
                page.keyboard.type('abc', delay=50)
                page.wait_for_timeout(300)
                # the stack's handlers, called from the page
                result = page.evaluate("document.liveCode.findStackWithName('%s').probeFromJS(21)" % STACK_NAME)
                if str(result) != '42':
                    problems.append('probeFromJS(21) returned %r from the page, expected 42' % (result,))
                report = page.evaluate("document.liveCode.findStackWithName('%s').probeReport()" % STACK_NAME)
                if report != 'abc|abc|1':
                    problems.append('probeReport() returned %r, expected the field\'s text, the keys and the '
                                    'clicks: \'abc|abc|1\'' % (report,))
                else:
                    lines.append('a click, typing and calls from the page reached the stack')
                # the shiftKey and the keysDown, with Shift held down
                page.keyboard.down('Shift')
                page.wait_for_timeout(100)
                keys = page.evaluate("document.liveCode.findStackWithName('%s').probeReport('keys')" % STACK_NAME)
                page.keyboard.up('Shift')
                if keys != 'down|65505':
                    problems.append('probeReport("keys") returned %r with Shift held down, expected the shiftKey '
                                    'and the keysDown: \'down|65505\'' % (keys,))
                else:
                    lines.append('the shiftKey and the keysDown saw Shift held down')
                # a touch: a tap on the button is one click (the browser makes up no mouse
                # events of its own after the touch's), and a finger dragged across the
                # graphic is the mouse with its button down
                page.touchscreen.tap(*at(info['button-rect']))
                wait_for(lambda: len(probes.get('click', [])) >= 2, 'the button\'s mouseUp for a tap', 10)
                page.wait_for_timeout(300)
                taps = len(probes.get('click', [])) - 1
                if taps != 1:
                    problems.append('a tap on the button sent its mouseUp %d times, expected once' % taps)
                start = at(info['graphic-rect'])
                points = [(start[0] + 8 * step, start[1]) for step in range(5)]
                if devtools:
                    cdp = page.context.new_cdp_session(page)
                    for i, (x, y) in enumerate(points):
                        cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart' if i == 0 else 'touchMove',
                                                              'touchPoints': [{'x': x, 'y': y}]})
                        page.wait_for_timeout(50)
                    cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
                    page.wait_for_timeout(300)
                    cdp.detach()
                    drag = page.evaluate("document.liveCode.findStackWithName('%s').probeReport('drag')" % STACK_NAME)
                if not devtools:
                    if taps == 1:
                        lines.append('a tap was one click (a finger dragged across the graphic is checked in '
                                     'Chromium only)')
                elif not touch_drag_ok(drag, [(x - canvas['x'], y - canvas['y']) for x, y in points]):
                    problems.append('a finger dragged across the graphic from %d,%d to %d,%d sent it %r, expected '
                                    'mouseDown, mouseMove and mouseUp at the finger\'s points' % (
                                        points[0][0] - canvas['x'], points[0][1] - canvas['y'],
                                        points[-1][0] - canvas['x'], points[-1][1] - canvas['y'], drag))
                elif taps == 1:
                    lines.append('a tap was one click, and a finger dragged across the graphic was the mouse')
                # drag and drop: the mouse drags the field "Drag Source" onto the field
                # "Drag Target" (the drag starts once it has moved dragDelta points with
                # its button down), which takes the text that dragStart gave the drag;
                # over it, the cursor says that a drop copies
                source, target = at(info['drag-source-rect']), at(info['drag-target-rect'])
                page.mouse.move(*source)
                page.mouse.down()
                steps = 10
                for i in range(1, steps + 1):
                    page.mouse.move(source[0] + (target[0] - source[0]) * i / steps,
                                    source[1] + (target[1] - source[1]) * i / steps)
                    page.wait_for_timeout(30)
                page.wait_for_timeout(300)
                cursor = page.evaluate("getComputedStyle(document.getElementById('canvas')).cursor")
                page.mouse.up()
                page.wait_for_timeout(300)
                dnd = page.evaluate("document.liveCode.findStackWithName('%s').probeReport('dnd')" % STACK_NAME)
                if dnd != PROBE_DND or cursor != 'copy':
                    problems.append('the field "Drag Source" dragged onto the field "Drag Target" sent and dropped '
                                    '%r with the cursor %r over the target, expected %r with the cursor \'copy\''
                                    % (dnd, cursor, PROBE_DND))
                else:
                    lines.append('a field dragged onto another sent the drag\'s messages and dropped its text, '
                                 'with the copy cursor over the target')
                # a file dragged from outside the page (Chromium's DevTools protocol
                # drives the browser's own drag and drop, as a drag from another
                # application) and dropped on the graphic "Drop Zone", whose
                # dragEnter takes files: the stack gets its copy in /uploads
                drop_file = os.path.join(work, PROBE_DROP[0])
                with open(drop_file, 'w') as f:
                    f.write(PROBE_DROP[1])
                zone = at(info['drop-zone-rect'])
                drag_data = {'items': [], 'files': [drop_file], 'dragOperationsMask': 1}
                if devtools:
                    cdp = page.context.new_cdp_session(page)
                    for kind in ('dragEnter', 'dragOver', 'drop'):
                        cdp.send('Input.dispatchDragEvent', {'type': kind, 'x': zone[0], 'y': zone[1], 'data': drag_data})
                        page.wait_for_timeout(50)
                else:
                    lines.append('a file dropped from outside the page is checked in Chromium only')
                report_drop = "document.liveCode.findStackWithName('%s').probeReport('drop')" % STACK_NAME
                if devtools and wait_for(lambda: page.evaluate(report_drop), 'the drop of %s' % PROBE_DROP[0], 10):
                    dropped = page.evaluate(report_drop)
                    if dropped != PROBE_DROP_REPORT:
                        problems.append('a file dropped on the graphic "Drop Zone" from outside the page gave it %r, '
                                        'expected %r' % (dropped, PROBE_DROP_REPORT))
                    else:
                        lines.append('a file dropped from outside the page reached the stack as its copy in /uploads')
                # a touch screen's keyboard: it comes up when a tap on the field
                # ends, what it types reaches the field as keys (text with no keys
                # of its own, as Playwright's insert_text and an IME commit it, and
                # a Backspace), and it goes away when the field loses the focus;
                # the hidden input that takes the keys asks for no keyboard
                # meanwhile (its inputmode)
                stack_js = "document.liveCode.findStackWithName('%s')" % STACK_NAME
                input_mode = 'document.activeElement ? document.activeElement.inputMode : null'
                page.evaluate(stack_js + '.probeUnfocus()')
                unfocused_mode = page.evaluate(input_mode)
                page.evaluate('window.__oxtKeyboard = []')
                page.touchscreen.tap(*at(info['field-rect']))
                page.wait_for_timeout(300)
                tapped = page.evaluate('window.__oxtKeyboard.slice()')
                tapped_mode = page.evaluate(input_mode)
                page.keyboard.insert_text(PROBE_SOFT_TEXT + 'x')
                page.evaluate('''() => document.activeElement.dispatchEvent(new InputEvent('beforeinput',
                    {inputType: 'deleteContentBackward', bubbles: true, cancelable: true}))''')
                page.wait_for_timeout(300)
                typed = page.evaluate(stack_js + '.probeReport()')
                page.evaluate(stack_js + '.probeUnfocus()')
                put_away = page.evaluate('window.__oxtKeyboard.slice()')
                # Only Chromium has the VirtualKeyboard API: elsewhere the engine
                # brings the keyboard up by focusing the input again, so the
                # page's stand-in for the API hears nothing. And Playwright's
                # insert_text is an input method's composition in Firefox
                # (as an Android keyboard's text often is), which the engine
                # puts into the field through its composition handling (from
                # LiveCode's HTML5 engine), with no keyDown for it: the text
                # must arrive either way
                wanted_keyboard = (['show'], ['show', 'hide']) if devtools else ([], [])
                composed = 'abc%s|abc|2' % PROBE_SOFT_TEXT
                if ((unfocused_mode, tapped, tapped_mode, put_away) !=
                        ('none', wanted_keyboard[0], 'text', wanted_keyboard[1])
                        or typed not in ((PROBE_SOFT_REPORT,) if devtools else (PROBE_SOFT_REPORT, composed))):
                    problems.append('a touch screen\'s keyboard: with no field focused the input asked for the keyboard '
                                    '%r; a tap on the field asked the keyboard for %r and the input for %r; after the '
                                    'keyboard typed %r and a Backspace the probe reported %r; and when the field lost '
                                    'the focus the keyboard had been asked for %r; expected \'none\', %r, '
                                    '\'text\', %r and %r'
                                    % (unfocused_mode, tapped, tapped_mode, PROBE_SOFT_TEXT + 'x', typed, put_away,
                                       wanted_keyboard[0], PROBE_SOFT_REPORT, wanted_keyboard[1]))
                elif devtools:
                    lines.append('a tap on the field brought up a touch screen\'s keyboard, which typed into it, and '
                                 'it went away when the field lost the focus')
                else:
                    lines.append('a tap on the field focused the input for a touch screen\'s keyboard, which typed '
                                 'into it (%s)'
                                 % ('as keys' if typed == PROBE_SOFT_REPORT
                                    else 'as an input method\'s text, with no keyDown for it'))
                # a loop in mouseDown that asks for the mouse until its button
                # goes up, then a wait for a click (probeMouseLoop): the page's
                # events must reach the engine while the loop runs, or it never
                # sees the button go up or the click (it gives up on each after
                # 10 seconds). The click is the script's: no message is sent
                # for it, nor for the button going up before it, as on the
                # desktop; a click on the card after it puts the button up for
                # the engine.
                zone = parse_rect(info['mouse-zone-rect'])
                start = ((zone[0] + zone[2]) // 2, (zone[1] + zone[3]) // 2)
                end = (start[0] + 20, start[1] + 10)
                click = (zone[2] + 10, zone[1] + 10)
                point = lambda p: (canvas['x'] + p[0], canvas['y'] + p[1])
                started = time.time()
                page.mouse.move(*point(start))
                page.mouse.down()
                page.wait_for_timeout(200)
                page.mouse.move(*point(end), steps=4)
                page.wait_for_timeout(200)
                page.mouse.up()
                page.wait_for_timeout(200)
                page.mouse.click(*point(click))
                report_mouse = lambda: page.evaluate(stack_js + '.probeReport("mouse")')
                if wait_for(lambda: report_mouse().count('|') == 4, 'the probe\'s mouse loop and click', 30):
                    looped = report_mouse()
                    wanted = 'true|%d,%d|true|%d,%d|true' % (end + click)
                    if looped != wanted:
                        problems.append('a loop while the mouse was down, then a wait for a click, reported %r (the '
                                        'loop ran more than once, the last mouseLoc it saw, the button went up in '
                                        'time, the clickLoc, the click came in time), expected %r' % (looped, wanted))
                    else:
                        lines.append('a loop while the mouse was down saw it move and its button go up, and a wait '
                                     'for a click ended on the click (%.1f s)' % (time.time() - started))
                page.mouse.click(*point(click))
                # snapshots of what the page shows, as the desktop engines take
                # them of the screen (probeReport("snapshot")): of the graphic by
                # the stack's window, of the whole stack by its rect on the screen
                # at half its size, of the graphic as a PNG, and the colour under
                # the mouse, which is over the graphic
                page.mouse.move(*at(info['graphic-rect']))
                page.wait_for_timeout(300)
                snapshots = page.evaluate(stack_js + '.probeReport("snapshot")')
                if not snapshot_report_ok(snapshots, PROBE_SNAPSHOTS):
                    problems.append('snapshots of the page, with the mouse over the graphic, reported %r, expected %r '
                                    '(sizes and colours)' % (snapshots, PROBE_SNAPSHOTS))
                else:
                    lines.append('import snapshot, export snapshot and the mouseColor read what the page shows')
                # "import snapshot" with no rectangle: the user drags one out over
                # the page, here on the graphic, 10 points inside it; then Escape
                # cancels a second one, and the import fails. Nothing of either
                # is left on the page.
                selector = '.oxt-snapshot-select'
                graphic = parse_rect(info['graphic-rect'])
                selected = []
                # what the page saw of the drag, for the report if it fails
                page.evaluate('''() => { window.__oxtPointer = [];
                    for (const type of ['pointerdown', 'pointermove', 'pointerup', 'pointercancel',
                                        'gotpointercapture', 'lostpointercapture', 'mousedown', 'mouseup']) {
                      window.addEventListener(type, (e) => { if (window.__oxtPointer.length < 40)
                        window.__oxtPointer.push(e.type + (e.pointerType ? ':' + e.pointerType : '') + '@' +
                          ((e.target && e.target.className) || (e.target && e.target.tagName) || '?')); }, true);
                    } }''')
                for cancel in (False, True):
                    page.evaluate(stack_js + '.probeReport("snapshot-select")')
                    if not wait_for(lambda: page.locator(selector).count() > 0,
                                    'the page asking for the rectangle of a snapshot', 10):
                        break
                    if cancel:
                        page.keyboard.press('Escape')
                    else:
                        page.mouse.move(canvas['x'] + graphic[0] + 10, canvas['y'] + graphic[1] + 10)
                        page.mouse.down()
                        page.mouse.move(canvas['x'] + graphic[2] - 10, canvas['y'] + graphic[3] - 10, steps=5)
                        page.mouse.up()
                    if not wait_for(lambda: 'snapshot-select' in info, 'the probe\'s import snapshot ending', 10):
                        break
                    selected.append(info.pop('snapshot-select'))
                left = page.locator(selector).count()
                if (len(selected) != 2 or not snapshot_report_ok(selected[0], PROBE_SNAPSHOT_SELECT[0])
                        or selected[1] != PROBE_SNAPSHOT_SELECT[1] or left):
                    problems.append('import snapshot with a rectangle dragged out on the graphic, then with Escape, '
                                    'reported %r, leaving %d of the page\'s selections, expected %r and none; the '
                                    'page saw %s'
                                    % (selected, left, list(PROBE_SNAPSHOT_SELECT),
                                       ' '.join(page.evaluate('window.__oxtPointer || []')) or 'no pointer events'))
                else:
                    lines.append('import snapshot took the rectangle dragged out on the page, and Escape cancelled it')
                # a modal dialog (probeReport("modal")): the stack under it takes
                # neither the mouse nor the keys (a click on the button, a click
                # on the field and typing), the dialog's field takes the keys,
                # and its OK button closes it; then the keyboard is the field's
                # again, where it was, and the button takes clicks
                page.mouse.click(*at(info['field-rect']))
                page.wait_for_timeout(200)
                before = page.evaluate(stack_js + '.probeReport()')
                clicks = len(probes.get('click', []))
                centre = lambda rect: ((parse_rect(rect)[0] + parse_rect(rect)[2]) / 2,
                                       (parse_rect(rect)[1] + parse_rect(rect)[3]) / 2)
                page.evaluate(stack_js + '.probeReport("modal")')
                modal, after = None, None
                if wait_for(lambda: 'modal-button-rect' in info, 'the modal dialog opening', 10):
                    page.mouse.click(*at(info['button-rect']))
                    page.mouse.click(*at(info['field-rect']))
                    page.keyboard.type('zz', delay=50)
                    page.mouse.click(*centre(info['modal-field-rect']))
                    page.keyboard.type('ok', delay=50)
                    page.mouse.click(*centre(info['modal-button-rect']))
                    if wait_for(lambda: 'modal' in info, 'the modal dialog closing', 10):
                        modal = info['modal']
                        page.wait_for_timeout(200)
                        page.keyboard.type('k', delay=50)
                        page.mouse.click(*at(info['button-rect']))
                        wait_for(lambda: len(probes.get('click', [])) > clicks,
                                 'the button\'s mouseUp after the modal dialog', 10)
                        page.wait_for_timeout(200)
                        after = page.evaluate(stack_js + '.probeReport()')
                text, keys, clicked = (before.split('|') + ['', '', '0'])[:3]
                wanted = '%sk|%sk|%d' % (text, keys, int(clicked or 0) + 1)
                if (modal, after) != (PROBE_MODAL, wanted):
                    problems.append('a modal dialog, with clicks and typing under it and typing into it, reported %r, '
                                    'and the stack under it %r after it closed and more typing and a click, expected '
                                    '%r and %r' % (modal, after, PROBE_MODAL, wanted))
                else:
                    lines.append('a modal dialog kept the mouse and the keys from the stack under it, and gave them '
                                 'back when it closed')
                # a palette (probeReport("window")): the page gives its window a
                # title bar with its title, which the user drags to move it
                # (moveStack), and a close box, which closes it
                # (closeStackRequest, closeStack); the window is as see-through
                # as the palette's blendLevel says, and a click goes through it
                # while its ignoreMouseEvents is true
                page.evaluate(stack_js + '.probeReport("window")')
                window_problem = None
                if wait_for(lambda: 'window-rect' in info, 'the palette opening', 10):
                    frame = page.evaluate(WINDOW_FRAME_JS, PROBE_WINDOW_TITLE)
                    start = parse_rect(info['window-rect'])
                    moved = ','.join(str(start[i] + PROBE_WINDOW_DRAG[i % 2]) for i in range(4))
                    if frame and frame['shown'] and frame['opacity'] == PROBE_WINDOW_OPACITY:
                        ignoring = page.evaluate(stack_js + '.probeReport("window-ignore")')
                        page.mouse.click((frame['close'][0] + frame['close'][2]) / 2,
                                         (frame['close'][1] + frame['close'][3]) / 2)
                        page.wait_for_timeout(500)
                        heeding = page.evaluate(stack_js + '.probeReport("window-heed")')
                    if not frame or not frame['shown'] or 'oxt-window-utility' not in frame['classes']:
                        window_problem = ('the page shows no palette\'s title bar with the title %r: %r'
                                          % (PROBE_WINDOW_TITLE, frame))
                    elif frame['opacity'] != PROBE_WINDOW_OPACITY:
                        window_problem = ('the palette, with a blendLevel of 40, has the opacity %r in the page, '
                                          'expected %s' % (frame['opacity'], PROBE_WINDOW_OPACITY))
                    elif (str(ignoring).lower(), str(heeding).lower()) != ('true', 'false') or \
                            'window-request' in info or \
                            not page.evaluate(WINDOW_FRAME_JS, PROBE_WINDOW_TITLE)['shown']:
                        window_problem = ('with the palette\'s ignoreMouseEvents set to %r, then back to %r, a '
                                          'click on its close box between them sent closeStackRequest: %s; the '
                                          'palette is shown: %s'
                                          % (ignoring, heeding, 'window-request' in info,
                                             page.evaluate(WINDOW_FRAME_JS, PROBE_WINDOW_TITLE)['shown']))
                    else:
                        grab = (frame['title'][0] + 30, (frame['title'][1] + frame['title'][3]) / 2)
                        page.mouse.move(*grab)
                        page.mouse.down()
                        page.mouse.move(grab[0] + PROBE_WINDOW_DRAG[0], grab[1] + PROBE_WINDOW_DRAG[1], steps=5)
                        page.mouse.up()
                        if not wait_for(lambda: info.get('window-moved') == moved,
                                        'the palette\'s moveStack to %s' % moved, 10):
                            window_problem = ('a drag by the palette\'s title bar moved it to %r, expected %s'
                                              % (info.get('window-moved'), moved))
                        else:
                            close = page.evaluate(WINDOW_FRAME_JS, PROBE_WINDOW_TITLE)['close']
                            page.mouse.click((close[0] + close[2]) / 2, (close[1] + close[3]) / 2)
                            if not wait_for(lambda: 'window-closed' in info, 'the palette closing', 10):
                                window_problem = ('a click on the palette\'s close box sent %s, and closed it %s'
                                                  % ('closeStackRequest' if 'window-request' in info else 'nothing',
                                                     'window-closed' in info))
                            elif 'window-request' not in info or page.evaluate(
                                    WINDOW_FRAME_JS, PROBE_WINDOW_TITLE)['shown']:
                                window_problem = ('the palette closed without closeStackRequest, or its window '
                                                  'stayed: %r' % page.evaluate(WINDOW_FRAME_JS, PROBE_WINDOW_TITLE))
                else:
                    window_problem = 'the palette did not open'
                if window_problem:
                    problems.append(window_problem)
                else:
                    lines.append('a palette\'s title bar showed its title, moved it when dragged, and closed it '
                                 'with its close box; its blendLevel made it see-through, and a click went through '
                                 'it while its ignoreMouseEvents was true')
                # an option menu (probeReport("menu")): a click on its button
                # opens its list, a window of its own, and a click on the page
                # outside every window closes it with no menuPick, as a click
                # outside a menu closes it on the desktop; it opens again, and
                # closes again the same way
                page.evaluate(stack_js + '.probeReport("menu")')
                menu_problem = None
                if wait_for(lambda: 'menu-rect' in info, 'the option menu', 10):
                    outside = page.evaluate(PAGE_OUTSIDE_JS)
                    if not outside:
                        menu_problem = 'the page has no point outside every window to click'
                    for attempt in range(2):
                        if menu_problem:
                            break
                        shown = page.evaluate(SHOWN_WINDOWS_JS)
                        page.mouse.click(*at(info['menu-rect']))
                        if not wait_for(lambda: page.evaluate(SHOWN_WINDOWS_JS) > shown,
                                        'the option menu\'s list opening', 10):
                            menu_problem = 'a click on the option menu\'s button showed no list'
                            break
                        page.wait_for_timeout(300)
                        page.mouse.click(*outside)
                        if not wait_for(lambda: page.evaluate(SHOWN_WINDOWS_JS) == shown,
                                        'the option menu\'s list closing', 10):
                            menu_problem = ('a click on the page outside every window, at %d,%d, left the option '
                                            'menu\'s list open' % tuple(outside))
                        elif 'menu-pick' in info:
                            menu_problem = ('a click on the page outside the option menu\'s list sent menuPick %r'
                                            % info['menu-pick'])
                else:
                    menu_problem = 'the option menu was not made'
                page.evaluate(stack_js + '.probeReport("menu-done")')
                if menu_problem:
                    problems.append(menu_problem)
                else:
                    lines.append('an option menu\'s list closed with no menuPick when the page outside every window '
                                 'was clicked, and opened again')
                # the files the probe wrote to /downloads: a text file, and the
                # PDF that it printed
                names = lambda: [name for name, _ in downloads]
                if wait_for(lambda: PROBE_DOWNLOAD[0] in names() and PROBE_PDF in names(),
                            'the downloads of %s and %s' % (PROBE_DOWNLOAD[0], PROBE_PDF), 10):
                    if sorted(names()) != sorted([PROBE_DOWNLOAD[0], PROBE_PDF]):
                        problems.append('the browser downloaded %r, expected %s and %s'
                                        % (names(), PROBE_DOWNLOAD[0], PROBE_PDF))
                    elif PROBE_DOWNLOAD not in downloads:
                        problems.append('the browser downloaded %r, expected %r' % (downloads, PROBE_DOWNLOAD))
                    else:
                        lines.append('the file written to /downloads reached the browser as a download')
                    pdf = dict(downloads)[PROBE_PDF]
                    with open(os.path.join(work, PROBE_PDF), 'wb') as f:
                        f.write(pdf)
                    try:
                        pdf_problems = check_pdf(pdf)
                    except (CheckError, IndexError, ValueError, KeyError, zlib.error) as e:
                        pdf_problems = ['it could not be read: %s' % e]
                    if pdf_problems:
                        problems.extend('the PDF that the probe printed: %s' % p for p in pdf_problems)
                    else:
                        lines.append('open printing to pdf wrote a PDF of %d bytes with the pages, link, anchor, '
                                     'bookmarks and document information printed, which reached the browser as '
                                     'a download (%s ms)' % (len(pdf), info.get('pdf-ms')))
                # what the probe printed: the browser was asked to print its two
                # pages once, with their pictures, the first landscape; the
                # frame's document, with the pictures in it, is as the browser
                # printed it
                prints = page.evaluate('''(points) => window.__oxtPrints.map(function(job) {
                    let html = job.html;
                    job.pages.forEach(function(page) {
                        html = html.split(page.src).join(page.canvas.toDataURL('image/png'));
                    });
                    return {title: job.title, html: html, pages: job.pages.map(function(page, i) {
                        const c = page.canvas;
                        const scale = [c.width / parseFloat(page.width), c.height / parseFloat(page.height)];
                        return {size: page.width + ' ' + page.height, pixels: [c.width, c.height],
                                colours: (points[i] || []).map(function(point) {
                                    const data = c.getContext('2d').getImageData(Math.floor(point[0] * scale[0]),
                                        Math.floor(point[1] * scale[1]), 1, 1).data;
                                    return Array.from(data.slice(0, 3));
                                })};
                    })};
                })''', [[list(point) for _, point, _ in points] for points in PROBE_PRINT_PAGES])
                sizes = ['%dpt %dpt' % size for size in PROBE_BROWSER_SIZES]
                pixels = [[size[0] * 300 // 72, size[1] * 300 // 72] for size in PROBE_BROWSER_SIZES]
                if (len(prints) != 1 or prints[0]['title'] != STACK_TITLE
                        or [p['size'] for p in prints[0]['pages']] != sizes
                        or [p['pixels'] for p in prints[0]['pages']] != pixels):
                    problems.append('the browser was asked to print %r, expected one job, %r, of pages of %s, with '
                                    'pictures of %s' % ([dict((k, v) for k, v in job.items() if k != 'html')
                                                          for job in prints], STACK_TITLE, sizes, pixels))
                else:
                    wrong = ['page %d has the %s at %s in %s, expected %s' % (number, name, point, tuple(got), want)
                             for number, (printed, points) in enumerate(zip(prints[0]['pages'], PROBE_PRINT_PAGES), 1)
                             for (name, point, want), got in zip(points, printed['colours'])
                             if any(abs(a - b) > 8 for a, b in zip(got, want))]
                    paper = printed_paper(browser, prints[0]['html']) if devtools else None
                    if devtools and paper != [list(size) for size in PROBE_BROWSER_SIZES]:
                        wrong.append('the browser printed the frame\'s document on paper of %s, expected %s'
                                     % (paper, [list(size) for size in PROBE_BROWSER_SIZES]))
                    if wrong:
                        problems.extend('the browser was asked to print: %s' % w for w in wrong)
                    else:
                        lines.append('the browser was asked to print the two pages that the probe printed, with '
                                     'their pictures, each on paper of its size (%s ms)' % info.get('print-ms'))
                # the samples of the audio clip that the probe played
                sounds = page.evaluate('window.__oxtSounds')
                if (len(sounds) != 1
                        or any(sounds[0].get(k) != v for k, v in PROBE_SOUND.items() if k != 'freq')
                        or abs(sounds[0].get('freq', 0) - PROBE_SOUND['freq']) > PROBE_SOUND['freq'] * 0.02):
                    problems.append('the browser was given the sounds %r, expected %r' % (sounds, [PROBE_SOUND]))
                else:
                    lines.append('the audio clip\'s samples reached the browser')
                # what the probe's revSpeech asked the browser to say
                spoken = page.evaluate('window.__oxtSpeech')
                if (len(spoken) != 1
                        or any(spoken[0].get(k) != v for k, v in PROBE_SPEECH.items() if not isinstance(v, float))
                        or any(abs((spoken[0].get(k) or 0) - v) > 0.001
                               for k, v in PROBE_SPEECH.items() if isinstance(v, float))):
                    problems.append('the browser was asked to say %r, expected %r' % (spoken, [PROBE_SPEECH]))
                else:
                    lines.append('revSpeech spoke its text with the voice, rate, pitch and volume it set')
                # the colours drawn
                shot = os.path.join(work, STACK_NAME + '.png')
                page.screenshot(path=shot, clip=dict(x=canvas['x'], y=canvas['y'],
                                                     width=canvas['width'], height=canvas['height']))
                pixels = page.evaluate('''([x, y, points]) => {
                    const c = document.getElementById('canvas');
                    const ctx = c.getContext('2d');
                    return points.map(([px, py]) => Array.from(ctx.getImageData(px, py, 1, 1).data.slice(0, 3)));
                }''', [canvas['x'], canvas['y'], [list(pt) for _, pt, _ in COLOURS]])
                for (name, point, want), got in zip(COLOURS, pixels):
                    if any(abs(a - b) > 8 for a, b in zip(got, want)):
                        problems.append('the %s at %s is drawn %s, expected %s' % (name, point, tuple(got), want))
                lines.append('canvas %dx%d at (%d, %d); screenshot %s' % (
                    canvas['width'], canvas['height'], canvas['x'], canvas['y'], shot))
            except (CheckError, PlaywrightError, KeyError, ValueError) as e:
                problems.append('the interactive checks failed: %s' % e)
        if 'ready' in probes and not page_errors:
            # the page in two tabs of a new browser profile, which keep the
            # same home folder in the same storage: a file that the first
            # tab writes after the second has loaded the folder must still
            # be there after the second writes one (until 0.2.7-rc.6.3, the
            # second tab's write deleted it, and a stack saved in the web
            # IDE in one tab was lost when the IDE in another wrote
            # anything), and the second tab must have it. With ?tab=, the
            # probe runs no checks.
            try:
                browser_waiting[0] = 'the page in two tabs'
                tabs = browser.new_context()
                report_js = "document.liveCode.findStackWithName('%s').probeReport('%%s')" % STACK_NAME
                opened = []
                for name in ('first', 'second'):
                    tab = tabs.new_page()
                    tab.on('dialog', on_dialog)
                    tab.goto(url + ('&' if '?' in url else '?') + 'tab=' + name)
                    tab.wait_for_function("() => document.liveCode && document.liveCode.findStackWithName "
                                          "&& document.liveCode.findStackWithName('%s')" % STACK_NAME,
                                          timeout=timeout * 1000)
                    tab.wait_for_timeout(1000)
                    opened.append(tab)
                first, second = opened
                first_wrote = first.evaluate(report_js % 'home-write first-tab')
                stored = [None]

                def first_stored():
                    stored[0] = first.evaluate(STORED_FILE_JS, ['/openxtalk', TWO_TABS_FILES[0]])
                    return stored[0] == TWO_TABS_TEXTS[0]
                wait_for(first_stored, 'the first tab\'s file reaching the browser\'s storage', 10)
                second_wrote = second.evaluate(report_js % 'home-write second-tab')

                def both_stored():
                    stored[0] = [first.evaluate(STORED_FILE_JS, ['/openxtalk', path]) for path in TWO_TABS_FILES]
                    return stored[0] == list(TWO_TABS_TEXTS)
                if first_wrote != 'written' or second_wrote != 'written':
                    problems.append('the two tabs\' probeReport("home-write") returned %r and %r, expected '
                                    '"written"' % (first_wrote, second_wrote))
                elif not wait_for(both_stored, 'both tabs\' files in the browser\'s storage', 10):
                    problems.append('with the page in two tabs, the browser\'s storage has %r for %s, '
                                    'expected %r' % (stored[0], ' and '.join(TWO_TABS_FILES),
                                                     list(TWO_TABS_TEXTS)))
                else:
                    seen = [None]

                    def second_has():
                        seen[0] = second.evaluate(report_js % 'home-has first-tab')
                        return seen[0] == TWO_TABS_TEXTS[0]
                    if wait_for(second_has, 'the second tab reading in the first tab\'s file', 10):
                        lines.append('with the page in two tabs, each kept the file the other wrote '
                                     'in the home folder')
                    else:
                        problems.append('the second tab has %r for the first tab\'s file, expected %r'
                                        % (seen[0], TWO_TABS_TEXTS[0]))
                tabs.close()
            except (PlaywrightError, PlaywrightTimeoutError) as e:
                problems.append('the check of the page in two tabs failed: %s' % e)
        if 'ready' in probes:
            # what an older engine kept in /livecode, in a new browser
            # profile: written before the page opens, copied to /openxtalk.
            # The copy is the engine's, at start (em-system.js), so the page
            # opens with ?tab=, where the probe runs no checks: without it
            # the probe ran all its checks a second time in this page (its
            # downloads, its printing, its palette closed by its close box),
            # and in WebKit the page was closed under the evaluate below
            # ("Target page, context or browser has been closed"), twice on
            # #208, whose change the web runtime does not contain. The page
            # is in a context of its own, closed after, as the two tabs' is.
            try:
                browser_waiting[0] = 'the old home folder\'s copy'
                profile = browser.new_context()
                fresh = profile.new_page()
                fresh.on('dialog', on_dialog)
                fresh.goto(urllib.parse.urljoin(url, '/no-such-page'))  # the site, without the engine
                fresh.evaluate(SEED_LEGACY_HOME_JS, [LEGACY_HOME_FILE[0], LEGACY_HOME_FILE[2]])
                fresh.goto(url + ('&' if '?' in url else '?') + 'tab=legacy')
                copied = [None]

                def legacy_copied():
                    copied[0] = fresh.evaluate(STORED_FILE_JS, ['/openxtalk', LEGACY_HOME_FILE[1]])
                    return copied[0] == LEGACY_HOME_FILE[2]
                if wait_for(legacy_copied, 'the old home folder (/livecode) reaching /openxtalk\'s storage',
                            timeout):
                    lines.append('a file an older engine kept in /livecode was copied to /openxtalk')
                kept = fresh.evaluate(STORED_FILE_JS, ['/livecode', LEGACY_HOME_FILE[0]])
                if kept != LEGACY_HOME_FILE[2]:
                    problems.append('the old home folder\'s database has %r for %s after the copy, expected '
                                    'it left as it was' % (kept, LEGACY_HOME_FILE[0]))
                profile.close()
            except PlaywrightError as e:
                problems.append('the check of the old home folder\'s copy failed: %s' % e)
        browser_waiting[0] = 'the browser to close'
        browser.close()

    checks = list(PROBE_CHECKS)
    if info.get('browser-widget') == 'not loaded':
        # The probe leaves its check out when the standalone has no browser
        # widget: right when the IDE that built it had none
        checks.remove('browser')
        if browser_widget:
            problems.append('the standalone has no browser widget: its extension is not loaded (the '
                            'extensions are %s)' % (info.get('extensions') or 'none'))
        else:
            lines.append('the browser widget was not checked: the IDE has none here (no CEF), and so '
                         'neither has the standalone')
    for name in checks:
        results = probes.get(name)
        if not results:
            problems.append('the probe did not report the check %s' % name)
        for status, detail in results or []:
            if status != 'PASS':
                problems.append('%s: %s %s' % (name, status, detail))
    for name, results in sorted(probes.items()):
        if name not in checks and name not in ('ready', 'click'):
            for status, detail in results:
                if status != 'PASS':
                    problems.append('%s: %s %s' % (name, status, detail))
    if not probes.get('click'):
        problems.append('the click on the button did not reach its mouseUp handler')
    if 'url-path' not in info:
        problems.append('the probe did not report what loads its URLs (PROBE info url-path)')
    elif url_path and info['url-path'] != url_path:
        problems.append('the probe\'s URLs were loaded by %s, expected %s' % (info['url-path'], url_path))
    else:
        lines.append('the URLs were loaded by %s' % info['url-path'])
    plain = tuple(item.split('>')[0] for item in info.get('font-widths', '').split(','))
    if plain != PROBE_PLAIN_WIDTHS:
        problems.append('plain text is %r points wide (no font set, Droid Sans, Arial), expected %r, as the old '
                        'font drew it' % (plain, PROBE_PLAIN_WIDTHS))
    else:
        lines.append('plain text kept its width, and bold text is bold (%s)' % info.get('font-widths'))
    if 'wait=refused' not in info.get('js-call', ''):
        problems.append('a wait in a handler called from the page did not fail as it must: %r'
                        % info.get('js-call'))
    if crashed:
        problems.append('the page crashed (the browser\'s "Target crashed")')
    for error in page_errors:
        problems.append('page error: %s' % error)
    # The browser may report the probe's request for a missing page
    # (url-missing): Chromium and WebKit do, in these words; Firefox does not
    expected = ['Failed to load resource: the server responded with a status of 404 (Not Found)']
    for kind, text in console:
        if kind == 'error' and not text.startswith('PROBE '):
            if text in expected:
                expected.remove(text)
            else:
                problems.append('console error: %s' % text)
    return problems, lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--runtime', help='the web runtime folder: build without the IDE')
    ap.add_argument('--engine', help='with --runtime: a development engine (LiveCode-Community)')
    ap.add_argument('--engine-cache', help='with --runtime: download the pinned development engine into this folder')
    ap.add_argument('--install', metavar='DIR', help='an installed OXT-Beyond: build with its IDE')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and build with its IDE')
    ap.add_argument('--bin', dest='bin_dir', metavar='DIR',
                    help='the build output of a repository checkout: build with the checkout\'s IDE')
    ap.add_argument('--platform', help='with --install or --package: the layout (default: this machine\'s)')
    ap.add_argument('--built', metavar='DIR', help='a standalone of the probe stack that is already built')
    ap.add_argument('--browser', choices=('chromium', 'firefox', 'webkit'), default='chromium',
                    help='the browser that opens the page (default chromium)')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for each step (default 120)')
    ap.add_argument('--ide-timeout', type=int, default=600,
                    help='seconds for the IDE to start and build (default 600)')
    ap.add_argument('--keep-serving', action='store_true', help='keep serving the page after the checks')
    args = ap.parse_args(argv)
    modes = [x for x in ('runtime', 'ide', 'built')
             if (args.install or args.package or args.bin_dir if x == 'ide' else getattr(args, x))]
    if len(modes) != 1 or len([x for x in (args.install, args.package, args.bin_dir) if x]) > 1:
        ap.error('pass one of --runtime, --install, --package, --bin and --built')
    if (modes[0] == 'runtime') != bool(args.engine or args.engine_cache) or (args.engine and args.engine_cache):
        ap.error('--runtime needs one of --engine and --engine-cache, and only --runtime takes them')
    mode = modes[0]

    work = os.path.abspath(args.work) if args.work else tempfile.mkdtemp(prefix='oxt-web-check-')
    os.makedirs(work, exist_ok=True)
    problems, lines = [], []
    server = None
    try:
        if mode == 'runtime':
            runtime = os.path.abspath(args.runtime)
            version, js, wasm, html = runtime_files(runtime)
            engine = os.path.abspath(args.engine) if args.engine else fetch_engine(os.path.abspath(args.engine_cache))
            log('Deploying with %s' % engine)
            startup = deploy(engine, runtime, version, work, args.timeout, engine_modules(engine))
            site = os.path.join(work, 'site')
            shutil.rmtree(site, ignore_errors=True)
            make_standalone(runtime, js, wasm, html, startup, site)
            url_path = 'engine'
            browser_widget = True
            lines.append('built without the IDE, from %s' % runtime)
        elif mode == 'ide':
            site, built, browser_widget = build_with_ide(args, work, args.ide_timeout)
            lines += built
            url_path = 'libURL'
        else:
            site = os.path.abspath(args.built)
            url_path = None
            browser_widget = None
            lines.append('built before: %s' % site)
        version, page = built_files(site)
        js, wasm = [os.path.join(site, 'standalone-community-%s.%s' % (version, x)) for x in ('js', 'wasm')]
        log('Web engine %s: %s (%.1f MB), %s (%.1f MB)' % (
            version, os.path.basename(js), os.path.getsize(js) / 1e6, os.path.basename(wasm),
            os.path.getsize(wasm) / 1e6))
        lines.append('web engine %s: .wasm %.1f MB, .js %.0f kB' % (
            version, os.path.getsize(wasm) / 1e6, os.path.getsize(js) / 1e3))
        lines.append('standalone.zip %.1f kB' % (os.path.getsize(os.path.join(site, 'standalone.zip')) / 1e3))
        server = make_server(site, PROBE_PAGE_DEFERRED if args.browser == 'webkit' else PROBE_PAGE)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], os.path.basename(page))
        log('Opening %s' % url)
        watchdog = browser_watchdog(args.browser, max(BROWSER_LIMIT, 5 * args.timeout))
        try:
            p, l = run_browser(url, version, work, args.timeout, url_path, browser_widget, args.browser)
        finally:
            watchdog.cancel()
        problems += p
        lines += l
        if args.keep_serving:
            log('Serving %s (Ctrl-C ends it)' % url)
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                pass
    except CheckError as e:
        problems.append(str(e))
    finally:
        if server:
            server.shutdown()

    log()
    for line in lines:
        log('  ' + line)
    if problems:
        log('FAILED:')
        for problem in problems:
            log('  ' + problem)
            annotate('error', 'web check: ' + problem)
    else:
        log('PASSED')
    title = {'runtime': 'without the IDE', 'ide': 'the IDE\'s builder', 'built': 'built before'}[mode]
    summary('### Web standalone check (%s, %s)\n\n' % (title, args.browser) + ''.join('- %s\n' % x for x in lines)
            + ('\n**Failed:**\n\n' + ''.join('- %s\n' % x for x in problems) if problems else '\nAll checks passed.\n')
            + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
