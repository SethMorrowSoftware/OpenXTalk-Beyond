/* The stack checker's page: takes a file (chosen, dropped, or one of the
   two samples), hands its bytes to StackCheck, and draws the report. The
   file never leaves the page: there is no upload, and nothing in it runs. */
(function () {
  'use strict';
  var SC = window.StackCheck;
  var zone = document.getElementById('drop');
  var input = document.getElementById('file');
  var pick = document.getElementById('pick');
  var out = document.getElementById('reports');
  var busy = document.getElementById('busy');
  if (!SC || !zone || !out) return;

  var PLAYER = 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/player/';
  var FORUM = 'https://openxtalk.org/forum/';
  var ISSUE = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues/new?template=bug_report.yml';

  var STATUS = {
    ok: ['ok', 'Works'],
    preview: ['preview', 'In the preview'],
    note: ['note', 'Differs'],
    info: ['info', 'Good to know'],
    blocked: ['no', 'Stops it'],
    doubt: ['note', 'Check']
  };
  var ORDER = { blocked: 0, doubt: 1, note: 2, preview: 3, ok: 4, info: 5 };
  var MARK = {
    opens: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>',
    notes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/><circle cx="19" cy="18" r="1.6" fill="currentColor" stroke="none"/></svg>',
    doubt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 6v8"/><circle cx="12" cy="18" r="1.3" fill="currentColor" stroke="none"/></svg>',
    blocked: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><path d="M6.5 17.5l11-11"/></svg>',
    import: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="13" height="17" rx="2"/><path d="M8 3v4h5M20 13l-4 4-2-2"/></svg>',
    unknown: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.4a2.5 2.5 0 1 1 3.4 2.6c-.7.3-1 .8-1 1.5v.5"/><circle cx="12" cy="17" r="1" fill="currentColor" stroke="none"/></svg>'
  };

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
  }

  function chip(status) {
    var s = STATUS[status] || ['info', status];
    return el('span', 'chip ' + s[0], s[1]);
  }

  function kb(n) {
    if (n < 1024) return n + ' bytes';
    if (n < 1024 * 1024) return (n / 1024).toFixed(n < 10240 ? 1 : 0) + ' KB';
    return (n / 1048576).toFixed(1) + ' MB';
  }

  function render(r) {
    var card = el('article', 'report reveal in');
    var verdict = r.verdict || 'unknown';
    var head = el('div', 'report-head ' + verdict);
    var mark = el('div', 'mark');
    mark.innerHTML = MARK[verdict] || MARK.unknown;
    head.appendChild(mark);
    var hd = el('div');
    hd.appendChild(el('div', 'filename', (r.path || r.fileName) + (r.inZip ? '  ·  in ' + r.inZip : '') + '  ·  ' + kb(r.size || 0)));
    hd.appendChild(el('h3', null, r.title || 'Checked'));
    if (r.summary) hd.appendChild(el('p', null, r.summary));
    head.appendChild(hd);
    card.appendChild(head);

    var body = el('div', 'report-body');
    var left = el('div');
    var right = el('div');

    if (r.facts && r.facts.length) {
      left.appendChild(el('h4', null, 'The file'));
      var dl = el('dl', 'facts');
      r.facts.forEach(function (f) {
        dl.appendChild(el('dt', null, f[0]));
        var dd = el('dd', null, f[1]);
        if (f[2]) dd.appendChild(el('small', null, f[2]));
        dl.appendChild(dd);
      });
      left.appendChild(dl);
    }
    if (r.widgets && r.widgets.length) {
      left.appendChild(el('h4', null, 'Widgets'));
      var ul = el('ul', 'widgets');
      r.widgets.forEach(function (w) {
        var li = el('li', w.shipped ? '' : 'missing');
        li.appendChild(el('span', null, w.shipped ? w.name : 'Not in OXT-Beyond'));
        li.appendChild(el('code', null, w.id));
        if (w.note) li.title = w.note;
        ul.appendChild(li);
      });
      left.appendChild(ul);
    }
    if (r.platforms && r.platforms.length) {
      left.appendChild(el('h4', null, 'Set up to build for'));
      var pl = el('ul', 'plats');
      r.platforms.forEach(function (p) { pl.appendChild(el('li', p === 'iOS' ? 'no' : '', p)); });
      left.appendChild(pl);
    }
    if (r.handlers && r.handlers.count) {
      left.appendChild(el('h4', null, 'Its scripts'));
      var hp = el('p', 'handlers');
      hp.appendChild(document.createTextNode('About ' + r.handlers.count + ' handler' + (r.handlers.count === 1 ? '' : 's') + ', among them '));
      r.handlers.top.slice(0, 6).forEach(function (h, i, arr) {
        hp.appendChild(el('code', null, h.name));
        if (i < arr.length - 1) hp.appendChild(document.createTextNode(i === arr.length - 2 ? ' and ' : ', '));
      });
      hp.appendChild(document.createTextNode('.'));
      left.appendChild(hp);
    }
    if (r.libraries && r.libraries.length) {
      left.appendChild(el('h4', null, 'Stacks it starts using'));
      var lp = el('p', 'handlers');
      lp.appendChild(document.createTextNode('Bring these along: '));
      r.libraries.forEach(function (n, i) {
        lp.appendChild(el('code', null, n));
        if (i < r.libraries.length - 1) lp.appendChild(document.createTextNode(', '));
      });
      left.appendChild(lp);
    }

    var findings = (r.findings || []).slice().sort(function (a, b) { return (ORDER[a.status] || 9) - (ORDER[b.status] || 9); });
    right.appendChild(el('h4', null, 'What it found'));
    if (findings.length) {
      var fl = el('ul', 'findings');
      findings.forEach(function (f) {
        var li = el('li', 'finding');
        li.appendChild(chip(f.status));
        var div = el('div');
        div.appendChild(el('strong', null, f.title));
        if (f.detail) div.appendChild(el('p', null, f.detail));
        if (f.code) div.appendChild(el('pre', null, f.code));
        if (f.names && f.names.length) {
          var names = el('div', 'names');
          f.names.forEach(function (n) { names.appendChild(el('code', null, n)); });
          div.appendChild(names);
        }
        if (f.link) {
          var a = el('a', 'link', 'Read the details');
          a.href = f.link;
          a.rel = 'noopener';
          var p = el('p');
          p.appendChild(a);
          div.appendChild(p);
        }
        li.appendChild(div);
        fl.appendChild(li);
      });
      right.appendChild(fl);
    } else {
      right.appendChild(el('p', 'muted', r.kind === 'binary' || r.kind === 'scriptonly'
        ? 'Nothing in it calls for a change: no widgets or libraries the checker knows to be missing.'
        : 'Nothing more to say about this file.'));
    }
    if (r.next && r.next.length) {
      right.appendChild(el('h4', null, 'What to do next')).style.marginTop = '24px';
      var nx = el('ul', 'next');
      r.next.forEach(function (n) {
        var li = el('li');
        var s = el('strong', null, n[0] + '. ');
        li.appendChild(s);
        li.appendChild(document.createTextNode(n[1] + ' '));
        if (n[2] === 'player') { var a = el('a', 'link', 'Open the Stack Player'); a.href = PLAYER; li.appendChild(a); }
        if (n[2] === 'report') {
          var b = el('a', 'link', 'Report it on GitHub'); b.href = ISSUE; li.appendChild(b);
          li.appendChild(document.createTextNode(' or ask on '));
          var f = el('a', 'link', 'the OpenXTalk forum'); f.href = FORUM; li.appendChild(f);
        }
        nx.appendChild(li);
      });
      right.appendChild(nx);
    }
    body.appendChild(left);
    body.appendChild(right);
    if (!left.childNodes.length) { body.style.gridTemplateColumns = '1fr'; body.removeChild(left); }
    card.appendChild(body);

    var foot = el('div', 'report-foot');
    foot.appendChild(el('p', null, 'Read from the file in this page, without running it. A stack can still behave differently when it runs: if it does, tell us.'));
    var row = el('div', 'row');
    var copy = el('button', 'button quiet no-arrow', 'Copy the report');
    copy.type = 'button';
    copy.addEventListener('click', function () {
      var t = SC.toText(r);
      var done = function () { copy.textContent = 'Copied'; setTimeout(function () { copy.textContent = 'Copy the report'; }, 1800); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(t).then(done, function () { fallbackCopy(t); done(); });
      } else { fallbackCopy(t); done(); }
    });
    row.appendChild(copy);
    if (r.verdict === 'blocked' || r.verdict === 'doubt') {
      var rep = el('a', 'button quiet', 'Ask on the forum');
      rep.href = FORUM;
      row.appendChild(rep);
    } else if (r.verdict === 'opens' || r.verdict === 'notes' || r.verdict === 'import') {
      var play = el('a', 'button', 'Play it in your browser');
      play.href = PLAYER;
      row.appendChild(play);
    }
    foot.appendChild(row);
    card.appendChild(foot);
    return card;
  }

  function fallbackCopy(t) {
    var ta = document.createElement('textarea');
    ta.value = t;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) { /* nothing more to try */ }
    document.body.removeChild(ta);
  }

  function showAll(reports) {
    out.innerHTML = '';
    reports.forEach(function (r) { out.appendChild(render(r)); });
    busy.classList.remove('on');
    var first = out.querySelector('.report');
    if (first) {
      first.setAttribute('tabindex', '-1');
      first.focus({ preventScroll: true });
      first.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
    }
  }

  function check(name, bytes) {
    busy.classList.add('on');
    SC.inspectFile(name, bytes).then(showAll, function () {
      showAll([{ verdict: 'unknown', title: 'Could not read it', summary: 'The browser could not read this file.', fileName: name, size: bytes.length, facts: [], findings: [] }]);
    });
  }

  function readFile(file) {
    if (!file) return;
    if (file.size > 300 * 1024 * 1024) {
      showAll([{ verdict: 'unknown', title: 'Too big to check here', summary: 'The checker reads files up to 300 MB.', fileName: file.name, size: file.size, facts: [], findings: [] }]);
      return;
    }
    busy.classList.add('on');
    file.arrayBuffer().then(function (buf) { check(file.name, new Uint8Array(buf)); });
  }

  pick.addEventListener('click', function () { input.click(); });
  input.addEventListener('change', function () { readFile(input.files[0]); input.value = ''; });
  ['dragenter', 'dragover'].forEach(function (t) {
    zone.addEventListener(t, function (e) { e.preventDefault(); zone.classList.add('over'); });
  });
  ['dragleave', 'drop'].forEach(function (t) {
    zone.addEventListener(t, function (e) { e.preventDefault(); zone.classList.remove('over'); });
  });
  zone.addEventListener('drop', function (e) {
    var f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
    readFile(f);
  });
  // a file dropped anywhere else on the page is checked too, not opened by the browser
  window.addEventListener('dragover', function (e) { e.preventDefault(); });
  window.addEventListener('drop', function (e) {
    e.preventDefault();
    if (e.target && zone.contains(e.target)) return;
    var f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
    readFile(f);
  });

  document.querySelectorAll('[data-sample]').forEach(function (b) {
    b.addEventListener('click', function () {
      var s = (window.SAMPLE_STACKS || [])[Number(b.getAttribute('data-sample'))];
      if (!s) return;
      var bin = atob(s.data);
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      check(s.name, bytes);
    });
  });

  // From the front page's stack window: the report it made there
  if (/[?&]from=home\b/.test(location.search)) {
    try {
      var saved = JSON.parse(sessionStorage.getItem('oxtb-last-report') || 'null');
      if (saved) showAll([saved]);
    } catch (e) { /* nothing saved: the page waits for a file */ }
  }
  // ?sample=0 or 1 shows a sample report straight away (used for screenshots and links)
  var m = /[?&]sample=(\d)/.exec(location.search);
  if (m) {
    var btn = document.querySelector('[data-sample="' + m[1] + '"]');
    if (btn) btn.click();
  }
})();
