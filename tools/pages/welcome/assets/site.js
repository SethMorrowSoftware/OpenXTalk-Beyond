/* The site's own script. It loads nothing from anywhere, and every page
   works without it. It adds the light and dark switch, the bar at the top
   that turns to glass once the page moves, the phone menu, the section bar
   that keeps your place on a long page, the light that follows the
   pointer over a card, things rising into view once, the clips that play
   while pointed at, the filters of the guide's status board, the download
   for this computer, and the stack window on the front page. */
(function () {
  'use strict';
  var root = document.documentElement;
  root.classList.remove('no-js');
  root.classList.add('js');
  window.OXTB = true;
  var mq = function (q) { return window.matchMedia ? window.matchMedia(q).matches : false; };
  var reduced = mq('(prefers-reduced-motion: reduce)');
  var each = function (list, fn) { Array.prototype.forEach.call(list, fn); };

  // ---- Light or dark: the reader's setting, unless they choose here ----
  var KEY = 'oxtb-theme';
  function store(v) { try { localStorage.setItem(KEY, v); } catch (e) { /* private window: the choice lasts this page */ } }
  function current() { return root.getAttribute('data-theme') || (mq('(prefers-color-scheme: dark)') ? 'dark' : 'light'); }
  each(document.querySelectorAll('.theme'), function (toggle) {
    var label = function () { toggle.setAttribute('aria-label', current() === 'dark' ? 'Use the light appearance' : 'Use the dark appearance'); };
    label();
    toggle.addEventListener('click', function () {
      var next = current() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      store(next);
      label();
    });
  });

  // ---- The logo in the header moves for the first seconds, then rests ----
  root.classList.add('opening');
  setTimeout(function () { root.classList.remove('opening'); }, 6000);

  // ---- One scroll listener, run once a frame, for the bar and the section bar ----
  var onScroll = [];
  var ticking = false;
  window.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; onScroll.forEach(function (fn) { fn(); }); });
  }, { passive: true });

  // ---- The bar at the top: clear over the sky, glass once the page moves,
  //      with a line under it as long as the part of the page read ----
  var bar = document.querySelector('.topbar');
  if (bar) {
    var readLine = bar.querySelector('.progress');
    var glass = function () {
      bar.classList.toggle('scrolled', window.scrollY > 8);
      if (readLine) {
        var room = document.documentElement.scrollHeight - window.innerHeight;
        readLine.style.setProperty('--read', room > 0 ? Math.min(1, window.scrollY / room).toFixed(4) : '0');
      }
    };
    onScroll.push(glass);
    glass();
  }

  // ---- The phone menu closes on a link, on Escape, or on a tap outside it ----
  var menu = document.querySelector('.menu');
  if (menu) {
    menu.addEventListener('click', function (e) { if (e.target.closest('a')) menu.open = false; });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && menu.open) { menu.open = false; menu.querySelector('summary').focus(); }
    });
    document.addEventListener('click', function (e) { if (menu.open && !menu.contains(e.target)) menu.open = false; });
  }

  // ---- Things rise into place once, as they come into view, one after another ----
  var reveals = document.querySelectorAll('.reveal');
  each(reveals, function (el) {
    var n = 0;
    for (var s = el.previousElementSibling; s; s = s.previousElementSibling) if (s.classList.contains('reveal')) n++;
    if (n) el.style.setProperty('--d', Math.min(n, 6) * 70 + 'ms');
  });
  if (!reduced && 'IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -6% 0px', threshold: 0.06 });
    each(reveals, function (el) { io.observe(el); });
  } else {
    each(reveals, function (el) { el.classList.add('in'); });
  }

  // ---- A light that follows the pointer over a card ----
  if (!reduced && mq('(hover: hover) and (pointer: fine)')) {
    document.addEventListener('pointermove', function (e) {
      var t = e.target && e.target.closest ? e.target.closest('.spot') : null;
      if (!t) return;
      var r = t.getBoundingClientRect();
      t.style.setProperty('--mx', Math.round(e.clientX - r.left) + 'px');
      t.style.setProperty('--my', Math.round(e.clientY - r.top) + 'px');
    }, { passive: true });
  }

  // ---- Clips: still at rest; they play while pointed at, or after a tap ----
  each(document.querySelectorAll('.clip'), function (clip) {
    var video = clip.querySelector('video');
    var button = clip.querySelector('.frame');
    if (!video || !button) return;
    var tapped = false;
    function play() {
      var p = video.play();
      if (p && p.catch) p.catch(function () { /* a browser that will not play it keeps the still */ });
      clip.classList.add('playing');
      button.setAttribute('aria-label', 'Pause the clip: ' + clip.getAttribute('data-title'));
    }
    function pause() {
      video.pause();
      clip.classList.remove('playing');
      button.setAttribute('aria-label', 'Play the clip: ' + clip.getAttribute('data-title'));
    }
    button.setAttribute('aria-label', 'Play the clip: ' + clip.getAttribute('data-title'));
    if (!reduced) {
      clip.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse' && !tapped) play(); });
      clip.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse' && !tapped) pause(); });
    }
    button.addEventListener('click', function () {
      if (video.paused) { tapped = true; play(); } else { tapped = false; pause(); }
    });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { if (!e.isIntersecting && !video.paused) { tapped = false; pause(); } });
      }).observe(clip);
    }
  });

  // ---- The section bar: marks the section you are reading ----
  var sub = document.querySelector('.subnav');
  if (sub) {
    var track = sub.querySelector('.subnav-track');
    var links = Array.prototype.slice.call(sub.querySelectorAll('a[href^="#"]'));
    var targets = links.map(function (a) {
      var t = document.getElementById(a.getAttribute('href').slice(1));
      return t ? (t.closest('section') || t) : null;
    });
    var on = null;
    var spy = function () {
      var line = bar ? bar.offsetHeight + sub.offsetHeight + window.innerHeight * 0.22 : window.innerHeight * 0.3;
      var idx = -1;
      targets.forEach(function (t, i) { if (t && t.getBoundingClientRect().top <= line) idx = i; });
      if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) {
        for (var i = targets.length - 1; i >= 0; i--) { if (targets[i] && targets[i].getBoundingClientRect().top < window.innerHeight) { idx = i; break; } }
      }
      var a = links[idx] || null;
      if (a === on) return;
      if (on) { on.classList.remove('on'); on.removeAttribute('aria-current'); }
      on = a;
      if (a) {
        a.classList.add('on');
        a.setAttribute('aria-current', 'location');
        // keep the marked link in sight inside the bar, without moving the page
        var left = a.offsetLeft - (track.clientWidth - a.offsetWidth) / 2;
        if (track.scrollTo) track.scrollTo({ left: Math.max(0, left), behavior: reduced ? 'auto' : 'smooth' });
        else track.scrollLeft = Math.max(0, left);
      }
    };
    onScroll.push(spy);
    window.addEventListener('resize', spy);
    spy();
  }

  // ---- Where everything stands: count each kind, and show one kind at a time ----
  var board = document.querySelector('.board');
  var filters = document.querySelector('.filters');
  if (board && filters) {
    var lanes = Array.prototype.slice.call(board.querySelectorAll('.lane'));
    var buttons = Array.prototype.slice.call(filters.querySelectorAll('button'));
    var status = document.getElementById('board-status');
    var total = 0;
    lanes.forEach(function (lane) {
      var n = lane.querySelectorAll('li').length;
      total += n;
      var c = lane.querySelector('.count');
      if (c) c.textContent = n;
      var b = filters.querySelector('[data-filter="' + lane.getAttribute('data-status') + '"] .n');
      if (b) b.textContent = n;
    });
    var all = filters.querySelector('[data-filter="all"] .n');
    if (all) all.textContent = total;
    filters.hidden = false;
    filters.addEventListener('click', function (e) {
      var b = e.target.closest('button');
      if (!b) return;
      var f = b.getAttribute('data-filter');
      buttons.forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
      var shown = 0;
      lanes.forEach(function (lane) {
        var hide = f !== 'all' && lane.getAttribute('data-status') !== f;
        lane.hidden = hide;
        if (!hide) shown += lane.querySelectorAll('li').length;
      });
      board.classList.toggle('filtered', f !== 'all');
      if (status) status.textContent = f === 'all' ? 'Showing all ' + total + ' features.' : 'Showing ' + shown + ' of ' + total + ': ' + b.firstChild.textContent.trim() + '.';
    });
  }

  // ---- Downloads: mark the files for this computer ----
  var dl = document.getElementById('download');
  if (dl) {
    var ua = navigator.userAgent || '';
    var plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
    var os = null;
    if (/Android|iPhone|iPad|iPod|CrOS/i.test(ua) || (/Mac/i.test(plat) && navigator.maxTouchPoints > 1)) os = 'device';
    else if (/Win/i.test(plat) || /Windows/i.test(ua)) os = 'windows';
    else if (/Mac/i.test(plat) || /Mac OS X/i.test(ua)) os = 'mac';
    else if (/Linux|X11/i.test(plat + ' ' + ua)) os = 'linux';
    var note = document.getElementById('os-note');
    var NAMES = { windows: 'Windows', mac: 'a Mac', linux: 'Linux' };
    if (os === 'device' && note) {
      note.querySelector('span').innerHTML = 'On a phone or tablet? The <a href="https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/ide/">web IDE</a> and the <a href="https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/player/">Stack Player</a> run in the browser, with nothing to download.';
      note.hidden = false;
    } else if (os && NAMES[os]) {
      each(dl.querySelectorAll('.platform[data-os="' + os + '"]'), function (p) {
        p.classList.add('mine');
        var tag = document.createElement('span');
        tag.className = 'mine-tag';
        tag.textContent = 'This computer';
        var h = p.querySelector('h4');
        if (h) h.appendChild(tag);
      });
      if (note) {
        note.querySelector('span').textContent = 'This looks like ' + NAMES[os] + ', so its downloads are marked in both releases.';
        note.hidden = false;
      }
    }
  }

  // ---- The front page's stack window: drop a stack on it ----
  var face = document.getElementById('hero-drop');
  if (face && window.StackCheck) {
    var input = document.getElementById('hero-file');
    var pick = document.getElementById('hero-pick');
    var answer = document.getElementById('answer');
    var text = document.getElementById('answer-text');
    var ok = document.getElementById('answer-ok');
    var more = document.getElementById('answer-more');
    var VERDICT_WORDS = {
      opens: 'Opens in OXT-Beyond.',
      notes: 'Opens, with notes.',
      doubt: 'Check this file first.',
      blocked: 'Won\'t open as it is.',
      import: 'A HyperCard stack: OXT-Beyond imports it.',
      unknown: 'That doesn\'t look like a stack.'
    };
    var show = function (r) {
      var name = r.stackName ? '"' + r.stackName + '"' : r.fileName;
      var bits = [];
      if (r.format && r.format.label) bits.push('format ' + r.format.label);
      var notes = r.findings.filter(function (f) { return f.status === 'note' || f.status === 'preview' || f.status === 'blocked' || f.status === 'doubt'; }).length;
      if (notes) bits.push(notes + (notes === 1 ? ' note' : ' notes'));
      if (r.widgets && r.widgets.length) bits.push(r.widgets.length + (r.widgets.length === 1 ? ' widget' : ' widgets'));
      text.innerHTML = '';
      var strong = document.createElement('strong');
      strong.textContent = VERDICT_WORDS[r.verdict] || r.title;
      text.appendChild(strong);
      text.appendChild(document.createTextNode(name + (bits.length ? ': ' + bits.join(', ') + '.' : '.')));
      answer.classList.add('shown');
      try { sessionStorage.setItem('oxtb-last-report', JSON.stringify(r)); } catch (e) { /* the full report page asks again */ }
      (more || ok).focus();
    };
    var read = function (file) {
      if (!file) return;
      file.arrayBuffer().then(function (buf) {
        return window.StackCheck.inspectFile(file.name, new Uint8Array(buf));
      }).then(function (reports) { show(reports[0]); }, function () {
        show({ verdict: 'unknown', title: 'Could not read it', fileName: file.name, findings: [] });
      });
    };
    pick.addEventListener('click', function () { input.click(); });
    input.addEventListener('change', function () { read(input.files[0]); input.value = ''; });
    ['dragenter', 'dragover'].forEach(function (t) {
      face.addEventListener(t, function (e) { e.preventDefault(); face.classList.add('over'); });
    });
    ['dragleave', 'drop'].forEach(function (t) {
      face.addEventListener(t, function (e) { e.preventDefault(); face.classList.remove('over'); });
    });
    face.addEventListener('drop', function (e) {
      var f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
      read(f);
    });
    ok.addEventListener('click', function () { answer.classList.remove('shown'); pick.focus(); });
  }
})();
