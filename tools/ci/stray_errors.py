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

"""Errors of other scripts in an OXT-Beyond web page, for the browser checks.

Each page that runs the web engine (the web IDE's, the Stack Player's,
the gallery's and the web standalone's, PAGES) tells an error of its own
from another script's with the same function, oxtOwnError: a script's of
the page's site or the engine's WebAssembly's is the page's, and only
that stops or flags anything. A browser extension's script in the page
is not, nor another site's script. Before 0.2.7-rc.6.15 every error was
the page's: seth's web IDE showed "Something went wrong" in a normal
window and opened in a private one, which leaves the extensions out
(2026-11-04).

The checks put these scripts into the page before it loads:

STRAY_ERRORS defines window.oxtStrayErrors(), which raises one round of
other scripts' errors: one thrown by a script with no file (as an
extension's script put in the page reports it), one by a script from a
file of its own (a blob), and those a browser reports for an extension's
file in Chromium and Firefox and for another site's script ("Script
error.", with no file). It raises a round at 300 ms, 2.5 s and 6 s, while
the engine downloads and starts; a check calls it again once the page has
started (STRAY_NOW). Each message has STRAY_MARK, so that a check does not
count the thrown ones as the page's errors (Playwright's pageerror).

OWN_NOW raises an error of the page's own (its file is the page's), and
OWN_ERROR raises it once the page's own scripts have run
(DOMContentLoaded), before the engine can have started: a Stack Player
served from the same computer was ready in 1.5 s. The page must show it
as it always did.

own_error_function(text) is a page's oxtOwnError, its lines stripped, so
that a test can hold every page's to the same rule.
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The pages that carry oxtOwnError, from the repository's root
PAGES = (
    'tools/web-ide/index.html',
    'tools/web-player/index.html',
    'tools/web-player/play.html',
    'engine/rsrc/emscripten-html-template.html',
    'tools/pages/games/waterwheel/index.html',
    'tools/pages/games/pixel-maker/index.html',
    'tools/pages/games/svg-lab/index.html',
)

STRAY_MARK = 'stray error of the check'
STRAY_ERRORS = '''
(function() {
  var mark = '%s';
  window.oxtStrayErrors = function() {
    setTimeout(function() {
      throw new Error(mark + ', from a script with no file');
    }, 0);
    try {
      var script = document.createElement('script');
      script.src = URL.createObjectURL(new Blob(
        ['throw new Error("' + mark + ', from a file of its own");'],
        {type: 'text/javascript'}));
      (document.head || document.documentElement).appendChild(script);
    } catch (e) {
    }
    [['chrome-extension://oxtcheck/inject.js', 'Uncaught Error: ' + mark + ', from an extension'],
     ['moz-extension://oxtcheck/inject.js', 'Error: ' + mark + ', from an extension'],
     ['', 'Script error.']].forEach(function(error) {
      window.dispatchEvent(new ErrorEvent('error', {message: error[1], filename: error[0]}));
    });
  };
  [300, 2500, 6000].forEach(function(ms) {
    setTimeout(window.oxtStrayErrors, ms);
  });
})();
''' % STRAY_MARK
STRAY_NOW = 'window.oxtStrayErrors()'

OWN_ERROR_TEXT = 'an error of the page itself, from the check'
OWN_NOW = '''(function() {
  window.dispatchEvent(new ErrorEvent('error', {
    message: 'Uncaught Error: %s',
    filename: location.href.replace(/[?#].*$/, ''), lineno: 1, colno: 1}));
})()''' % OWN_ERROR_TEXT
OWN_ERROR = '''
document.addEventListener('DOMContentLoaded', function() {
  %s;
});
''' % OWN_NOW


def own_error_function(text):
    """The page's function oxtOwnError(e), each line stripped, or None."""
    lines = [line.strip() for line in text.splitlines()]
    try:
        start = lines.index('function oxtOwnError(e) {')
        # (the function's last statement, then its closing brace)
        last = next(i for i in range(start, len(lines)) if lines[i].startswith("return file !== ''"))
        end = lines.index('}', last)
    except (ValueError, StopIteration):
        return None
    return '\n'.join(lines[start:end + 1])


def page_text(path):
    with open(os.path.join(REPO, path), encoding='utf-8') as f:
        return f.read()
