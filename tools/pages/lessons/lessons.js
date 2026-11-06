/* The lessons of OXT-Beyond's GitHub Pages site (lessons/), made by
   tools/pages/build_lessons.py: the search, the Copy buttons, the
   sidebar's place in the lesson, and the level filter of the lessons'
   front page. Everything here answers the reader; nothing runs on a
   timer of its own, and a page works without it (the links and the
   lessons are plain HTML). */
(function () {
  'use strict';
  var root = document.body.getAttribute('data-root') || './';
  var doc = document.documentElement;

  // The header's logo moves for the page's first seconds, then only while
  // it is pointed at (without this script it is still)
  if (document.querySelector('.hero-logo')) {
    doc.classList.add('opening');
    setTimeout(function () { doc.classList.remove('opening'); }, 6000);
  }

  // Copy: the code of the example, as it runs
  Array.prototype.forEach.call(document.querySelectorAll('figure.example .copy'), function (button) {
    button.addEventListener('click', function () {
      var code = button.closest('figure').querySelector('pre.code code');
      var text = code ? code.textContent : '';
      var label = button.querySelector('span');
      var done = function (ok) {
        button.classList.toggle('done', ok);
        label.textContent = ok ? 'Copied' : 'Select and copy';
        setTimeout(function () { button.classList.remove('done'); label.textContent = 'Copy'; }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); });
      } else {
        var area = document.createElement('textarea');
        area.value = text;
        document.body.appendChild(area);
        area.select();
        var ok = false;
        try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
        document.body.removeChild(area);
        done(ok);
      }
    });
  });

  // A link to each heading of a lesson, for sharing
  Array.prototype.forEach.call(document.querySelectorAll('article.lesson h2[id], article.lesson h3[id]'), function (h) {
    var a = document.createElement('a');
    a.className = 'anchor';
    a.href = '#' + h.id;
    a.setAttribute('aria-label', 'Link to this section');
    a.textContent = '#';
    h.appendChild(a);
  });

  // The sidebar: open and closed on a narrow screen, and the section in
  // view lit in the lesson's contents
  var side = document.querySelector('.side');
  var toggle = document.querySelector('.side-toggle');
  if (side && toggle) {
    toggle.addEventListener('click', function () {
      var open = side.classList.toggle('open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
  var tocLinks = document.querySelectorAll('.side .toc a');
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var byId = {};
    Array.prototype.forEach.call(tocLinks, function (a) { byId[a.getAttribute('href').slice(1)] = a; });
    var seen = {};
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { seen[e.target.id] = e.isIntersecting ? e.boundingClientRect.top : null; });
      var best = null;
      Object.keys(seen).forEach(function (id) {
        if (seen[id] !== null && (best === null || seen[id] < seen[best])) best = id;
      });
      if (best === null) return;
      Array.prototype.forEach.call(tocLinks, function (a) { a.classList.toggle('on', a === byId[best]); });
    }, { rootMargin: '0px 0px -55% 0px' });
    Array.prototype.forEach.call(document.querySelectorAll('article.lesson h2[id]'), function (h) {
      if (byId[h.id]) observer.observe(h);
    });
  }

  // The level filter of the lessons' front page
  var filters = document.querySelectorAll('.filters button');
  Array.prototype.forEach.call(filters, function (button) {
    button.addEventListener('click', function () {
      var level = button.getAttribute('data-level');
      Array.prototype.forEach.call(filters, function (b) { b.setAttribute('aria-pressed', b === button ? 'true' : 'false'); });
      Array.prototype.forEach.call(document.querySelectorAll('section.level'), function (s) {
        s.hidden = level !== 'all' && s.getAttribute('data-level') !== level;
      });
    });
  });

  // The search: every section of every lesson (search-index.js, loaded
  // the first time a search box is used), each word of the question
  // found in a section's title, words or text
  var index = null;
  var waiting = [];
  function withIndex(then) {
    if (index) { then(); return; }
    waiting.push(then);
    if (waiting.length > 1) return;
    var script = document.createElement('script');
    script.src = root + 'search-index.js';
    script.onload = function () {
      index = (window.OXT_LESSONS || []).map(function (row) {
        row.low = {
          t: row.t.toLowerCase(), h: row.h.toLowerCase(), w: (row.w || '').toLowerCase(),
          s: (row.s || '').toLowerCase(), x: row.x.toLowerCase()
        };
        return row;
      });
      var run = waiting; waiting = [];
      run.forEach(function (f) { f(); });
    };
    script.onerror = function () { index = []; var run = waiting; waiting = []; run.forEach(function (f) { f(); }); };
    document.head.appendChild(script);
  }

  function terms(query) {
    return query.toLowerCase().split(/[^a-z0-9#&@.\-]+/).filter(function (t) { return t.length > 0; });
  }

  function score(row, words) {
    var total = 0;
    for (var i = 0; i < words.length; i++) {
      var w = words[i], s = 0;
      if (row.low.t.indexOf(w) >= 0) s += 12;
      if (row.low.h.indexOf(w) >= 0) s += 8;
      if ((' ' + row.low.w + ' ').indexOf(' ' + w + ' ') >= 0) s += 10;
      if (row.low.s.indexOf(w) >= 0) s += 4;
      var at = row.low.x.indexOf(w);
      if (at >= 0) {
        s += 2;
        // a whole word counts more than a piece of one
        var before = at === 0 ? ' ' : row.low.x.charAt(at - 1), after = row.low.x.charAt(at + w.length);
        if (!/[a-z0-9]/.test(before) && !/[a-z0-9]/.test(after || ' ')) s += 2;
      }
      if (s === 0) return 0;
      total += s;
    }
    return total;
  }

  function search(query) {
    var words = terms(query);
    if (!words.length || !index) return [];
    var found = [];
    index.forEach(function (row) {
      var s = score(row, words);
      if (s > 0) found.push({ row: row, score: s - row.n * 0.001 });
    });
    found.sort(function (a, b) { return b.score - a.score; });
    // At most two sections of a lesson, so that one lesson does not fill
    // the list
    var per = {}, out = [];
    for (var i = 0; i < found.length && out.length < 14; i++) {
      var n = found[i].row.n;
      per[n] = (per[n] || 0) + 1;
      if (per[n] <= 2) out.push(found[i].row);
    }
    return { rows: out, words: words };
  }

  function esc(text) {
    return text.replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; });
  }

  function mark(text, words) {
    var out = esc(text);
    words.forEach(function (w) {
      var safe = esc(w).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      out = out.replace(new RegExp('(' + safe + ')', 'gi'), '<mark>$1</mark>');
    });
    return out;
  }

  function snippet(row, words) {
    var at = -1;
    for (var i = 0; i < words.length && at < 0; i++) at = row.low.x.indexOf(words[i]);
    if (at < 0) return row.s || row.x.slice(0, 140);
    var start = Math.max(0, at - 60);
    var text = row.x.slice(start, start + 170);
    return (start > 0 ? '…' : '') + text + (start + 170 < row.x.length ? '…' : '');
  }

  var LEVELS = { beginner: 'Beginner', intermediate: 'Intermediate', advanced: 'Advanced', expert: 'Expert', extensions: 'Extensions' };

  function render(list, query) {
    var found = search(query);
    if (!found.rows || !found.rows.length) {
      list.innerHTML = '<li class="r-none">No lesson has “' + esc(query) + '”. Try another word, such as ' +
        '<code>repeat</code>, <code>array</code> or <code>files</code>.</li>';
      return;
    }
    list.innerHTML = found.rows.map(function (row, i) {
      return '<li><a href="' + esc(root + row.u) + '"' + (i === 0 ? ' class="on"' : '') + '>' +
        '<span class="r-title"><span>' + mark(row.t, found.words) + '</span> <small>' + (LEVELS[row.l] || '') + ' · ' + row.n +
        '</small></span>' + (row.h ? '<span class="r-where">' + mark(row.h, found.words) + '</span>' : '') +
        '<span class="r-snip">' + mark(snippet(row, found.words), found.words) + '</span></a></li>';
    }).join('');
  }

  Array.prototype.forEach.call(document.querySelectorAll('.search'), function (box) {
    var input = box.querySelector('input');
    var list = box.querySelector('.results');
    if (!input || !list) return;
    var update = function () {
      var query = input.value.trim();
      if (!query) { list.hidden = true; input.setAttribute('aria-expanded', 'false'); return; }
      withIndex(function () {
        if (input.value.trim() !== query) return;
        render(list, query);
        list.hidden = false;
        input.setAttribute('aria-expanded', 'true');
      });
    };
    input.addEventListener('focus', function () { withIndex(function () {}); if (input.value.trim()) update(); });
    input.addEventListener('input', update);
    input.addEventListener('keydown', function (e) {
      var links = list.querySelectorAll('a');
      var on = list.querySelector('a.on');
      var i = Array.prototype.indexOf.call(links, on);
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        if (!links.length) return;
        e.preventDefault();
        i = e.key === 'ArrowDown' ? Math.min(links.length - 1, i + 1) : Math.max(0, i - 1);
        Array.prototype.forEach.call(links, function (a, n) { a.classList.toggle('on', n === i); });
        links[i].scrollIntoView({ block: 'nearest' });
      } else if (e.key === 'Enter') {
        if (on) { e.preventDefault(); window.location.href = on.href; }
      } else if (e.key === 'Escape') {
        list.hidden = true;
        input.setAttribute('aria-expanded', 'false');
      }
    });
    document.addEventListener('click', function (e) {
      if (!box.contains(e.target)) { list.hidden = true; input.setAttribute('aria-expanded', 'false'); }
    });
    // A search asked for in the address (?q=, the lessons' "words" links)
    var asked = /[?&]q=([^&#]*)/.exec(window.location.search);
    if (asked && box.classList.contains('main-search')) {
      input.value = decodeURIComponent(asked[1].replace(/\+/g, ' '));
      update();
      input.focus();
    }
  });

  // "/" puts the keyboard in the search box, as on many documentation sites
  document.addEventListener('keydown', function (e) {
    if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    var input = document.querySelector('.search input');
    if (input) { e.preventDefault(); input.focus(); }
  });
})();
