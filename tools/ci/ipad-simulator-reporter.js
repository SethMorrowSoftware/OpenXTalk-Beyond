/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// What the Phone Starter's page does in Safari on an iPad simulator, told
// to tools/ci/ipad_simulator_check.py, which taps the page from outside
// (a click on the Simulator's window is a finger on the screen) and so
// cannot ask the page anything. The page's head loads this before the
// engine. It posts to /ipad/log, as JSON lists of events, each with the
// page's time in ms (t):
//
//   touchstart, touchend   where the finger was, in the page's CSS pixels
//                          (x, y), whether the browser made the event
//                          (trusted), the user activation (active) and
//                          what had the focus (focus)
//   asked                  the browser got a request for full screen;
//                          focus is what had the focus then, which is
//                          what WebKit's rule on an iPhone or an iPad
//                          looks at (a text input with the focus ends
//                          full screen: WebKit bug 185617)
//   fullscreenchange       full: whether the page is full screen now
//   fullscreenerror        the browser refused the request
//   focus                  something took the focus (to)
//   state                  the page and the stack (MobileWebCheck's
//                          mwcState): when it changes, and every 2 s
//                          whatever happens, so that "it stayed so" has
//                          the page's own time behind it
//   done                   a command of the check's was carried out
//
// The check's commands come from GET /ipad/command:
//
//   leave    the page leaves full screen (no tap is needed for that)
//   unfix    the engine is made to do what it did before 0.2.8-dp.2: its
//            hidden text input has the focus when the page asks for full
//            screen and while the page is full screen (it took the focus
//            at every press). On an iPad WebKit then takes full screen
//            back (CamelCaps' report: "in a split second it comes back"),
//            so a check that sees that can see the bug. Both halves are
//            needed: the engine takes the focus from its input again
//            when the page goes full screen, and the iPad simulator
//            showed that an input blurred then keeps full screen (the
//            run of 2026-11-18, case blur-on-change).
(function() {
  'use strict';
  var queue = [], sending = false, lastKey = '', lastStateAt = -1e9, unfixed = false;

  function now() {
    return Math.round(window.performance && performance.now ? performance.now() : Date.now());
  }

  function post(kind, data) {
    var e = {t: now(), kind: kind};
    for (var k in data) {
      if (Object.prototype.hasOwnProperty.call(data, k)) e[k] = data[k];
    }
    queue.push(e);
  }

  function flush() {
    if (sending || !queue.length) return;
    var batch = queue;
    queue = [];
    sending = true;
    var back = function() { queue = batch.concat(queue); };
    try {
      fetch('/ipad/log', {method: 'POST', headers: {'Content-Type': 'application/json'},
                          body: JSON.stringify(batch), keepalive: true})
        .then(function(r) { if (!r.ok) back(); }, back)
        .then(function() { sending = false; });
    } catch (err) {
      back();
      sending = false;
    }
  }

  function isFull() {
    return !!(document.fullscreenElement || document.webkitFullscreenElement);
  }

  // The engine's hidden text input (em-event.js: the only input it makes,
  // and the only one whose inputmode is "none")
  function engineInput() {
    return document.querySelector ? document.querySelector('input[inputmode="none"]') : null;
  }

  function describe(el) {
    if (!el) return 'none';
    if (el === document.body) return 'body';
    if (el === document.documentElement) return 'html';
    var input = engineInput();
    if (input && el === input) return 'engine-input';
    var tag = String(el.tagName || '?').toLowerCase();
    return tag + (el.type ? ':' + el.type : '') + (el.id ? '#' + el.id : '');
  }

  function stackState() {
    var lc = document.liveCode;
    var h = lc && lc.findStackWithName && lc.findStackWithName('MobileWebCheck');
    if (!h || !h.mwcState) return null;
    var out = {};
    String(h.mwcState()).split('\n').forEach(function(line) {
      var i = line.indexOf('=');
      if (i > 0) out[line.slice(0, i)] = line.slice(i + 1);
    });
    return out;
  }

  ['touchstart', 'touchend'].forEach(function(type) {
    window.addEventListener(type, function(e) {
      var f = e.changedTouches && e.changedTouches[0];
      post(type, {x: f ? Math.round(f.clientX) : null, y: f ? Math.round(f.clientY) : null,
                  trusted: e.isTrusted,
                  active: navigator.userActivation ? navigator.userActivation.isActive : null,
                  focus: describe(document.activeElement)});
    }, {capture: true, passive: true});
  });
  function focusEngineInput() {
    var input = engineInput();
    if (input) input.focus({preventScroll: true});
    post('unfixed', {focus: describe(document.activeElement)});
  }
  ['fullscreenchange', 'webkitfullscreenchange'].forEach(function(type) {
    document.addEventListener(type, function() {
      post('fullscreenchange', {full: isFull(), focus: describe(document.activeElement),
                                w: window.innerWidth, h: window.innerHeight});
      // unfixed: after the engine's own handler, which blurs its input
      // when the page is full screen
      if (unfixed && isFull()) setTimeout(focusEngineInput, 0);
      flush();
    });
  });
  ['fullscreenerror', 'webkitfullscreenerror'].forEach(function(type) {
    document.addEventListener(type, function() {
      post('fullscreenerror', {focus: describe(document.activeElement)});
      flush();
    });
  });
  window.addEventListener('focusin', function(e) {
    post('focus', {to: describe(e.target)});
  }, true);

  // The browser's own request, wrapped before the engine wraps it (the
  // engine wraps it when it starts, on an iPhone or an iPad), so that this
  // runs last, as the browser gets the request
  function wrap(name, before, after) {
    if (typeof Element == 'undefined') return;
    var ask = Element.prototype[name];
    if (typeof ask != 'function') return;
    Element.prototype[name] = function() {
      if (before) before();
      var r = ask.apply(this, arguments);
      if (after) after();
      return r;
    };
  }
  ['requestFullscreen', 'webkitRequestFullscreen', 'webkitRequestFullScreen'].forEach(function(name) {
    wrap(name, function() {
      post('asked', {how: name, focus: describe(document.activeElement)});
    });
  });

  function run(command) {
    if (command === 'leave') {
      var leave = document.exitFullscreen || document.webkitExitFullscreen;
      try {
        var p = leave ? leave.call(document) : null;
        if (p && p.catch) p.catch(function() {});
        post('done', {command: command, full: isFull()});
      } catch (err) {
        post('done', {command: command, error: String(err && err.message || err)});
      }
    } else if (command === 'unfix') {
      // Around the engine's own wrapper: the engine gives the focus up
      // and asks; the focus goes back to its input at once, as it was
      // before 0.2.8-dp.2 (the input kept the focus from the first press)
      if (!unfixed) {
        unfixed = true;
        ['requestFullscreen', 'webkitRequestFullscreen', 'webkitRequestFullScreen'].forEach(function(name) {
          wrap(name, null, focusEngineInput);
        });
      }
      post('done', {command: command});
    } else {
      post('done', {command: command, error: 'unknown command'});
    }
    flush();
  }

  function poll() {
    var again = function() { setTimeout(poll, 300); };
    try {
      fetch('/ipad/command', {cache: 'no-store'})
        .then(function(r) { return r.ok ? r.text() : ''; })
        .then(function(command) { if (command) run(command); }, function() {})
        .then(again, again);
    } catch (err) {
      again();
    }
  }

  function tick() {
    var s = null;
    try {
      s = stackState();
    } catch (err) {
      s = null;
    }
    var snap = {full: isFull(), focus: describe(document.activeElement),
                w: window.innerWidth, h: window.innerHeight};
    if (s) {
      ['card', 'rect', 'tabs', 'labels', 'buttons'].forEach(function(k) { snap[k] = s[k]; });
    }
    var key = JSON.stringify(snap);
    if (key !== lastKey || now() - lastStateAt >= 2000) {
      post('state', snap);
      lastKey = key;
      lastStateAt = now();
    }
    flush();
  }

  post('loaded', {agent: navigator.userAgent, platform: navigator.platform,
                  touchPoints: navigator.maxTouchPoints, w: window.innerWidth, h: window.innerHeight});
  setInterval(tick, 400);
  poll();
  window.__oxtIPadReporter = {run: run, tick: tick, flush: flush, describe: describe};
})();
