/* stackcheck.js: reads an xTalk stack file the way OXT-Beyond's engine
   starts to, and says what it found, without running anything.

   Everything here is a reading of the file's bytes, in this page. Nothing
   is sent anywhere, no script in the stack runs, and nothing is written.

   What it reads, and where the engine reads the same thing
   (OpenXTalk-Beyond, engine/src):

   - The header. A binary stack starts with "REVO" and four characters of
     version (stackfileformat.cpp, MCStackFileParseVersionNumber: 0-9,
     then A-Z for 10-35 and a-z for 36-61), or with the 255-byte MetaCard
     header whose "# MetaCard x.y" line gives the version (dispatch.cpp,
     readheader). OXT-Beyond reads every version up to 8100, the 8.1
     format (kMCStackFileFormatCurrentVersion), and refuses a newer one
     with "stack was produced by a newer version".
   - Then a charset byte (1 when it was saved on a Mac, where the native
     text is MacRoman; sysdefs.h, CHARSET), a type byte and a string
     (dispatch.cpp, trytoreadbinarystack), and the stack's own type:
     OT_STACK, or OT_ENCRYPT_STACK for a password-protected stack, which
     LiveCode Community never opened and OXT-Beyond does not either
     (stack3.cpp: "Encrypted stacks cannot be opened in Community
     Edition").
   - The stack's name: after its id, a string whose length is a uint2or4
     and whose text is UTF-8 from format 7.0, or a NUL-terminated native
     string with a uint2 length before it (object.cpp, MCObject::load;
     mcio.cpp).
   - The widgets: each one saves its kind as a length-prefixed name
     (widget.cpp). A kind OXT-Beyond does not ship still opens: the engine
     draws the widget as a stippled placeholder and saves its state back
     as it was read (widget.cpp, MCWidget::draw and save).
   - The Standalone Settings: the stack's custom property set
     cRevStandaloneSettings, read as the engine reads a property set
     (objectpropsets.cpp; before format 7.0 its array is laid out as
     foundation-legacy.cpp's MCArrayLoadFromHandleLegacy reads it, and from
     7.0 as mcio.cpp's IO_read_valueref_new does), for the targets that are
     ticked. On 2026-11-22 this gave the 0.2.8-dp.1 engine's answer for
     each of the 26 stacks in OXT-Beyond's repository whose files name the
     set (formats 2.7, 5.5, 7.0 and 8.1); tests/run.js keeps four of them.
   - The rest is a search of the file's text for the names of calls and
     libraries (scripts are stored as text), whatever their case. Those
     are hints, and the report says so.

   Works in a browser (window.StackCheck) and in node (module.exports). */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.StackCheck = api;
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ---- Facts the report uses, each from OXT-Beyond's own repository ----

  var CURRENT = 8100;            // the 8.1 format, the newest it reads and the one it saves
  var STABLE = '0.2.7';          // the stable release, 2026-11-10
  var PREVIEW = '0.2.8-dp.2.1';  // the developer preview, 2026-11-21 (both as the front page's downloads)
  var DP2 = '0.2.8-dp.2';        // the preview Chromium 156 and tsNetCompat came in, 2026-11-20
  var REPO = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond';
  var TSNET_DIFF = 'https://github.com/SethMorrowSoftware/xtalk-suite/blob/main/curlxt/docs/tsnet-compat.md';

  // The stack file formats, newest first: (lowest version, label, what saves it).
  // docs/glossary/s/stack-version.lcdoc
  var FORMATS = [
    [8100, '8.1', 'LiveCode 8.1 or later'],
    [8000, '8.0', 'LiveCode 8.0'],
    [7000, '7.0', 'LiveCode 7'],
    [5500, '5.5', 'LiveCode 5.5 or 6'],
    [2700, '2.7', 'Revolution 2.6.1 up to LiveCode 5.5'],
    [0, '2.4', 'Revolution before 2.6.1, or MetaCard']
  ];

  // The widgets an OXT-Beyond package carries: extensions/extensions.gyp
  // (the ones it builds) and ide/Extensions. [name, note or ''].
  var WIDGETS = {
    'com.livecode.widget.browser': ['Browser', 'On Windows and Linux x86-64 it runs Chromium 156 from ' + DP2 + ' (preview), Chromium 74 before; the Mac\'s is unchanged. The 64-bit ARM Linux package has no browser widget.'],
    'com.livecode.widget.clock': ['Clock', ''],
    'com.livecode.widget.linegraph': ['Line Graph', ''],
    'com.livecode.widget.headerbar': ['Header Bar', ''],
    'com.livecode.widget.iconpicker': ['Icon Picker', ''],
    'com.livecode.widget.navbar': ['Navigation Bar', ''],
    'com.livecode.widget.paletteactions': ['Palette Actions', ''],
    'com.livecode.widget.segmented': ['Segmented Control', ''],
    'com.livecode.widget.svgpath': ['SVG Icon', ''],
    'com.livecode.widget.switchbutton': ['Switch Button', ''],
    'com.livecode.widget.treeview': ['Tree View', ''],
    'com.livecode.widget.colorswatch': ['Color Swatch', ''],
    'com.livecode.widget.gradientrampeditor': ['Gradient Ramp Editor', ''],
    'com.livecode.widget.tile': ['Tile', ''],
    'com.livecode.widget.spinner': ['Spinner', ''],
    'com.livecode.widget.calendar': ['Calendar', ''],
    'com.livecode.widget.piechart': ['Pie Chart', ''],
    'com.livecode.widget.native.android.button': ['Android Native Button', 'Native on Android; elsewhere it is drawn as a stand-in.'],
    'com.livecode.widget.native.android.field': ['Android Native Field', 'Native on Android; elsewhere it is drawn as a stand-in.'],
    'com.livecode.widget.native.emscripten.button': ['HTML5 Native Button', 'Native in an HTML5 standalone.'],
    'com.livecode.widget.native.mac.button': ['macOS Native Button', 'Native on macOS.'],
    'com.livecode.widget.native.mac.textfield': ['macOS Native Field', 'Native on macOS.'],
    'com.livecode.widget.native.ios.button': ['iOS Native Button', 'It is there, but OXT-Beyond does not build for iOS.']
  };

  // A word in either case, letter by letter, for a pattern whose other
  // parts keep their case
  function anyCase(word) {
    return word.replace(/[A-Za-z]/g, function (c) { return '[' + c.toUpperCase() + c.toLowerCase() + ']'; });
  }

  // mergExt's calls are merg and a capital (mergAVCamStart). Written in
  // another case, a word that goes on from merg with e or ing is taken for
  // English (merged, merging, mergeSort), not a call; mergJSON is built
  // from source, and has its own entry.
  function isMergExt(word) {
    if (/^mergjson/i.test(word)) return false;
    return /^merg[A-Z]/.test(word) || !/^merg(?:e|ing)/i.test(word);
  }

  // Text that says what a script calls. Each: [id, pattern, status, title,
  // detail, link, keep]. The engine finds a handler however its name is
  // capitalized, so the patterns ignore case, bar the url pattern's t, p,
  // s, g or k with a capital after it: that is how a variable's name is
  // usually written, and its case is the clue. keep, where there is one,
  // says whether a match is a call. status: ok (works), preview (in the
  // preview release), note (works differently or is missing), info (good
  // to know)
  var CALLS = [
    ['tsnet', /\btsNet[A-Z][A-Za-z]+/gi, 'preview', 'tsNet calls',
      'tsNet came only with LiveCode\'s paid editions. From ' + DP2 + ' (preview), OXT-Beyond answers the same calls by name (tsNetCompat, over curlxt), with tsNet\'s parameter orders and callbacks. A few details differ; they are listed in curlxt\'s notes.',
      TSNET_DIFF],
    ['mergjson', /\b(?:JSONToArray|ArrayToJSON)\b/gi, 'ok', 'mergJSON (JSONToArray, ArrayToJSON)',
      'Built from mergJSON\'s source, so these work as they do in LiveCode (from 0.2.7-rc.6.4, in ' + STABLE + ').', ''],
    ['json', /\bJSON(?:Import|Export)\b/gi, 'ok', 'LiveCode\'s JSON library (JSONImport, JSONExport)',
      'Comes with OXT-Beyond (com.livecode.library.json).', ''],
    ['revdb', /\b(?:revOpenDatabase|revdb_connect|revQueryDatabase|revDataFromQuery|revExecuteSQL)\b/gi, 'ok', 'Databases (revDB)',
      'revDB comes with its SQLite, MySQL, PostgreSQL and ODBC drivers. MySQL connects over TLS 1.2 and 1.3; MySQL 8.4 logins and PostgreSQL\'s SCRAM logins work from 0.2.8-dp.1 (preview).', ''],
    ['revbrowser', /\brevBrowser[A-Z][A-Za-z]*/gi, 'ok', 'revBrowser',
      'Included. On Windows and Linux x86-64 it runs Chromium 156 from ' + DP2 + ' (preview), where ' + STABLE + ' has Chromium 74; the Mac\'s is unchanged. The 64-bit ARM Linux package has no browser.', ''],
    ['revxml', /\brevXML[A-Z][A-Za-z]*|\brevCreateXMLTree[A-Za-z]*/gi, 'ok', 'revXML',
      'Included, on libxml2 2.15.4 and libxslt 1.1.45, built from source.', ''],
    ['revzip', /\brevZip[A-Z][A-Za-z]*/gi, 'ok', 'revZip',
      'Included, on libzip 1.12, built from source.', ''],
    ['url', new RegExp('\\b(?:' + ['put', 'get', 'post', 'load'].map(anyCase).join('|') + ')\\b[^\\r\\n]{0,80}\\b' +
      anyCase('url') + '\\s*(?:"|\\(|[tpsgk][A-Z])|\\b' + anyCase('libURL') + '[A-Za-z]+', 'g'), 'ok', 'The internet library (libURL)',
      'get url, post, put ... into url and the httpHeaders family behave as before.', ''],
    ['datagrid', /\bdgProps\b|Data Grid Templates/gi, 'ok', 'The Data Grid',
      'Comes with OXT-Beyond, in the IDE, in standalones and in the Stack Player.', ''],
    ['mobile', /\bmobile[A-Z][A-Za-z]+/gi, 'info', 'mobile... calls',
      'These work in Android apps, which OXT-Beyond builds (target API 36 and App Bundles, for Google Play). On the desktop they do nothing, as in LiveCode.', ''],
    ['iphone', /\biphone[A-Z][A-Za-z]+/gi, 'note', 'iOS calls (iphone...)',
      'OXT-Beyond has no iOS build, so these are only for a stack that also runs on iOS in LiveCode. The rest of the stack is not affected.', ''],
    ['mergext', /\bmerg[A-Z][A-Za-z]+/gi, 'note', 'mergExt calls',
      'OXT-Beyond does not ship the mergExt externals (mergJSON aside, which it builds from source), so these calls will not be found. Install the external yourself if its licence lets you.', '', isMergExt]
  ];

  // The targets of the Standalone Settings: keys of the stack's
  // cRevStandaloneSettings, true when the target is ticked
  // (ide-support/revsblibrary.livecodescript, kDesktopTargets and
  // kAdditionalTargets; MacOSX and MacOSX PowerPC-32 are older stacks' Mac
  // targets, revsaveasstandalone.livecodescript). The engine compares keys
  // without regard to case, and stacks hold android and ios as well.
  var TARGETS = [
    ['Windows', ['windows', 'windows x86-64']],
    ['macOS', ['macosx', 'macosx powerpc-32', 'macosx x86-32', 'macosx x86-64', 'macosx x64-arm64']],
    ['Linux', ['linux', 'linux x64', 'linux armv6-hf', 'linux arm64']],
    ['Android', ['android']],
    ['iOS', ['ios']],
    ['HTML5', ['emscripten']]
  ];
  var SETTINGS = 'cRevStandaloneSettings';
  var OT_CUSTOM = 24;            // filedefs.h: the byte before a custom property set
  // Widget kinds are names, which the engine compares without regard to case
  var WIDGETS_LC = {};
  Object.keys(WIDGETS).forEach(function (id) { WIDGETS_LC[id.toLowerCase()] = WIDGETS[id]; });

  var IGNORE_END = { 'if': 1, 'repeat': 1, 'switch': 1, 'try': 1, 'case': 1, 'tell': 1, 'of': 1, 'the': 1, 'up': 1 };

  // ---- Reading bytes ----

  var MACROMAN = 'ÄÅÇÉÑÖÜáàâäãåçéè' +
    'êëíìîïñóòôöõúùûü' +
    '†°¢£§•¶ß®©™´¨≠ÆØ' +
    '∞±≤≥¥µ∂∑∏π∫ªºΩæø' +
    '¿¡¬√ƒ≈∆«»… ÀÃÕŒœ' +
    '–—“”‘’÷◊ÿŸ⁄€‹›ﬁﬂ' +
    '‡·‚„‰ÂÊÁËÈÍÎÏÌÓÔ' +
    'ÒÚÛÙıˆ˜¯˘˙˚¸˝˛ˇ';

  function u16(b, i) { return (b[i] << 8) | b[i + 1]; }
  function u32(b, i) { return ((b[i] << 24) >>> 0) + (b[i + 1] << 16) + (b[i + 2] << 8) + b[i + 3]; }
  function le16(b, i) { return b[i] | (b[i + 1] << 8); }
  function le32(b, i) { return (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)) >>> 0; }

  function ascii(b, start, end) {
    var s = '';
    for (var i = start; i < end && i < b.length; i++) s += String.fromCharCode(b[i]);
    return s;
  }

  function nativeText(b, start, end, mac) {
    var s = '';
    for (var i = start; i < end && i < b.length; i++) {
      var c = b[i];
      s += c < 128 ? String.fromCharCode(c) : (mac ? MACROMAN.charAt(c - 128) : String.fromCharCode(c));
    }
    return s;
  }

  function utf8Text(b, start, end) {
    try {
      return new TextDecoder('utf-8').decode(b.subarray(start, end));
    } catch (e) {
      return ascii(b, start, end);
    }
  }

  // The whole file as text, one character a byte, for the searches
  function byteText(b) {
    var limit = Math.min(b.length, 64 * 1024 * 1024);
    try {
      return new TextDecoder('latin1').decode(b.subarray(0, limit));
    } catch (e) {
      var out = [];
      for (var i = 0; i < limit; i += 65536) {
        out.push(String.fromCharCode.apply(null, b.subarray(i, Math.min(limit, i + 65536))));
      }
      return out.join('');
    }
  }

  function formatFor(version) {
    for (var i = 0; i < FORMATS.length; i++) {
      if (version >= FORMATS[i][0]) return { label: FORMATS[i][1], savedBy: FORMATS[i][2] };
    }
    return { label: String(version / 1000), savedBy: '' };
  }

  function versionLabel(v) {
    return Math.floor(v / 1000) + '.' + Math.floor((v % 1000) / 100);
  }

  function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }

  // ---- What the file is ----

  function sniff(b) {
    if (!b || b.length === 0) return 'empty';
    if (b.length >= 8 && ascii(b, 0, 4) === 'REVO') return 'binary';
    if (b.length >= 4 && b[0] === 0x50 && b[1] === 0x4B && (b[2] === 3 || b[2] === 5) && (b[3] === 4 || b[3] === 6)) return 'zip';
    if (b.length >= 64 && ascii(b, 0, 64).indexOf('MetaCard') >= 0) return 'binary';
    if (b.length >= 8 && ascii(b, 4, 8) === 'STAK') return 'hypercard';
    if (b.length >= 128 && b[0] === 0 && b[1] > 0 && b[1] < 64 && ascii(b, 65, 69) === 'STAK') return 'macbinary';
    if (b.length >= 4 && u32(b, 0) === 0x00051600) return 'applesingle';
    if (b.length >= 4 && u32(b, 0) === 0x00051607) return 'appledouble';
    var head = ascii(b, 0, Math.min(b.length, 512));
    if (head.indexOf('(This file must be converted with BinHex') >= 0) return 'binhex';
    if (b.length >= 1026 && b[1024] === 0x42 && b[1025] === 0x44) return 'diskimage';           // HFS: "BD"
    if (b.length >= 0x54 && b[0] > 0 && b[0] < 64 && b[0x52] === 1 && b[0x53] === 0) return 'diskimage'; // DiskCopy 4.2
    if (b.length >= 514 && b[0] === 0x45 && b[1] === 0x52 && b[512] === 0x50 && b[513] === 0x4D) return 'diskimage'; // Apple partition map
    if (/^(?:﻿|\xEF\xBB\xBF)?\s*script\s+"/.test(head)) return 'scriptonly';
    return 'unknown';
  }

  // ---- A binary stack's header ----

  function readHeader(b) {
    var r = { ok: false };
    var pos, version;
    if (ascii(b, 0, 4) === 'REVO') {
      version = 0;
      for (var i = 4; i < 8; i++) {
        var c = b[i];
        version *= 10;
        if (c >= 48 && c <= 57) version += c - 48;
        else if (c >= 65 && c <= 90) version += c - 65 + 10;
        else if (c >= 97 && c <= 122) version += c - 97 + 36;
        else { r.damaged = 'The first bytes say REVO, but the version after it is not one an xTalk engine writes.'; return r; }
      }
      r.headerText = ascii(b, 0, 8);
      pos = 8;
    } else {
      var head = ascii(b, 0, Math.min(255, b.length));
      var off = head.indexOf('# MetaCard ');
      if (off < 0 || b.length < 255) { r.damaged = 'It starts like a stack file but the header is cut short.'; return r; }
      if (head.charAt(off - 1) !== '\n' || head.charAt(off - 2) === '\r') {
        r.damaged = 'Its line endings were changed when it was copied as text (by FTP in text mode, an email program or a text editor), which breaks a binary stack. The engine says "stack was corrupted by a non-binary file transfer". Copy the original again in binary mode.';
        return r;
      }
      version = (head.charCodeAt(off + 11) - 48) * 1000 + (head.charCodeAt(off + 13) - 48) * 100;
      r.metacard = true;
      r.headerText = 'MetaCard ' + head.charAt(off + 11) + '.' + head.charAt(off + 13);
      pos = 255;
    }
    r.version = version;
    if (version > CURRENT) { r.newer = true; r.ok = true; return r; }

    // charset, type, a string
    if (pos + 4 > b.length) { r.damaged = 'The file ends just after its header.'; return r; }
    r.charset = b[pos];
    var type = b[pos + 1];
    pos += 2;
    pos += 2 + u16(b, pos);
    if (type === 1) {           // OT_HOME: the IDE's home stack, with two more strings
      pos += 2 + u16(b, pos);
      pos += 2 + u16(b, pos);
    }
    if (pos + 5 > b.length) { r.damaged = 'The file ends before the stack itself starts.'; return r; }
    var stackType = b[pos];
    pos += 1;
    if (stackType === 22) {     // OT_ENCRYPT_STACK
      r.encrypted = true;
      r.ok = true;
      return r;
    }
    if (stackType !== 3) {      // OT_STACK
      r.damaged = 'After the header the file does not go on the way a stack does. It may be damaged, or saved by something other than an xTalk engine.';
      return r;
    }
    pos += 4;                   // the stack's id
    try {
      if (version >= 7000) {
        var n = u16(b, pos);
        pos += 2;
        if (n & 0x8000) { n = (n & 0x7fff) | (u16(b, pos) << 15); pos += 2; }
        if (n > 0 && pos + n <= b.length && n < 4096) r.name = utf8Text(b, pos, pos + n);
      } else {
        var m = u16(b, pos);
        pos += 2;
        if (m > 0 && pos + m <= b.length && m < 4096) r.name = nativeText(b, pos, pos + m - 1, r.charset === 1);
      }
    } catch (e) { /* a name we cannot read is left out */ }
    r.ok = true;
    r.endsWell = b[b.length - 1] === 0;   // OT_END closes every stack file
    return r;
  }

  // ---- What a search of the text can tell ----

  function findWidgets(b, text) {
    var found = {};
    var re = /(?:com|community|org)\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+){1,6}/g;
    var m;
    while ((m = re.exec(text)) !== null) {
      var id = m[0];
      var at = m.index;
      if (at < 2) continue;
      // the kind is written with its length in front of it
      if (u16(b, at - 2) !== id.length) continue;
      if (!/widget|^community\.livecode|extensions/i.test(id)) continue;
      found[id] = (found[id] || 0) + 1;
    }
    return Object.keys(found).sort().map(function (id) {
      var known = WIDGETS_LC[id.toLowerCase()];
      return { id: id, count: found[id], shipped: !!known, name: known ? known[0] : null, note: known ? known[1] : '' };
    });
  }

  function findCalls(text) {
    var out = [];
    CALLS.forEach(function (c) {
      c[1].lastIndex = 0;
      var names = {};    // a name in lower case: [the first way it is written, how many]
      var total = 0;
      var m;
      while ((m = c[1].exec(text)) !== null) {
        var word = m[0].replace(/\s+/g, ' ');
        if (c[6] && !c[6](word)) continue;
        total++;
        if (c[0] === 'url') word = /url/i.test(word) ? 'url' : word;
        var key = word.toLowerCase();
        if (word.length < 40) {
          if (!names[key]) names[key] = [word, 0];
          names[key][1]++;
        }
        if (total > 5000) break;
      }
      if (total > 0) {
        var list = Object.keys(names).sort(function (a, b2) { return names[b2][1] - names[a][1]; }).slice(0, 6)
          .map(function (key) { return names[key][0]; });
        out.push({ id: c[0], status: c[2], title: c[3], detail: c[4], link: c[5], names: c[0] === 'url' || c[0] === 'datagrid' ? [] : list, count: total });
      }
    });
    return out;
  }

  function findLibraries(text) {
    var re = /\bstart\s+using\s+(?:stack\s+)?"([^"\r\n]{1,80})"/gi;
    var seen = {};
    var m;
    while ((m = re.exec(text)) !== null) seen[m[1]] = 1;
    return Object.keys(seen).slice(0, 12);
  }

  // A length as IO_read_uint2or4 reads it (mcio.cpp)
  function len2or4(b, p) {
    var n = u16(b, p);
    if (n & 0x8000) return { n: (n & 0x7fff) + u16(b, p + 2) * 32768, at: p + 4 };
    return { n: n, at: p + 2 };
  }

  // One value as IO_read_valueref_new reads it (mcio.cpp, from format
  // 7.0): a tag, then what it holds. Returns where the next thing starts
  // and, for a boolean or a short name or string, its text. Throws at
  // anything it cannot read.
  function readValue(b, p, depth) {
    if (p >= b.length || depth > 32) throw new Error('value');
    var q = p + 1;
    var n, i, s;
    switch (b[p]) {
      case 0: case 5: case 7: case 9: case 11: case 14:   // nothing, an empty name, string, data, array or list
        return { end: q, text: '' };
      case 1: return { end: q, text: 'false' };
      case 2: return { end: q, text: 'true' };
      case 3: return { end: q + 4, text: '' };            // an integer
      case 4: return { end: q + 8, text: '' };            // a real
      case 6: case 8:                                      // a name or a string, in UTF-8
        s = len2or4(b, q);
        return { end: s.at + s.n, text: s.n <= 16 ? utf8Text(b, s.at, s.at + s.n) : '' };
      case 10:                                             // data
        return { end: q + 4 + u32(b, q), text: '' };
      case 12: case 15:                                    // a sequence or a list: its values
        n = u32(b, q);
        q += 4;
        for (i = 0; i < n; i++) q = readValue(b, q, depth + 1).end;
        return { end: q, text: '' };
      case 13:                                             // an array: keys and values
        n = u32(b, q);
        q += 4;
        for (i = 0; i < n; i++) {
          s = len2or4(b, q);
          q = readValue(b, s.at + s.n, depth + 1).end;
        }
        return { end: q, text: '' };
    }
    throw new Error('value');
  }

  // A property set's array from format 7.0: a value, as above, whose keys
  // are a uint2or4 length and UTF-8. {key in lower case: text}, or null.
  function readSet(b, p) {
    var out = {};
    if (b[p] === 11) return out;                          // an empty array
    if (b[p] !== 13) return null;
    var n = u32(b, p + 1);
    var q = p + 5;
    for (var i = 0; i < n; i++) {
      var k = len2or4(b, q);
      var v = readValue(b, k.at + k.n, 1);
      out[utf8Text(b, k.at, k.at + k.n).toLowerCase()] = v.text;
      q = v.end;
    }
    return q <= b.length ? out : null;
  }

  // A property set's array before format 7.0, as MCArrayLoadFromHandleLegacy
  // reads it (foundation-legacy.cpp): a uint4 count whose top bits say the
  // set is encrypted or its values have 4-byte lengths, then for each
  // element a key (a uint1 length, its text and a zero) and a value (a
  // uint2 or uint4 length and its text). {key in lower case: text}, or null.
  function readSetLegacy(b, p) {
    var out = {};
    var n = u32(b, p);
    if (n >= 0x80000000) return null;                     // encrypted
    var large = n >= 0x40000000;
    if (large) n -= 0x40000000;
    var q = p + 4;
    for (var i = 0; i < n; i++) {
      if (q >= b.length) return null;
      var kl = b[q];
      var key = kl ? ascii(b, q + 1, q + kl) : '';
      q += 1 + kl;
      var vl = large ? u32(b, q) : u16(b, q);
      q += large ? 4 : 2;
      out[key.toLowerCase()] = vl <= 16 ? ascii(b, q, q + vl) : '';
      q += vl;
    }
    return q <= b.length ? out : null;
  }

  // The targets the Standalone Settings have ticked, or none when there
  // are no settings or they cannot be read. A property set is the byte
  // OT_CUSTOM, its name (before format 7.0 a uint2 length and a zero after
  // it, from 7.0 a uint2or4 length) and its array (objectpropsets.cpp,
  // MCObject::savepropsets). A stack writes its own property sets before
  // its cards, controls and substacks (stack3.cpp, MCStack::save_stack),
  // so the first set of this name that reads is the stack's.
  function findPlatforms(b, text, version) {
    var re = new RegExp(SETTINGS, 'gi');
    var m;
    while ((m = re.exec(text)) !== null) {
      var at = m.index;
      var end = at + SETTINGS.length;
      if (at < 3 || b[at - 3] !== OT_CUSTOM) continue;
      var set = null;
      try {
        if (version < 7000) {
          if (u16(b, at - 2) === SETTINGS.length + 1 && b[end] === 0) set = readSetLegacy(b, end + 1);
        } else if (u16(b, at - 2) === SETTINGS.length) {
          set = readSet(b, end);
        }
      } catch (e) {
        set = null;
      }
      if (!set) continue;
      return TARGETS.filter(function (t) {
        return t[1].some(function (key) { return /^true$/i.test(set[key] || ''); });
      }).map(function (t) { return t[0]; });
    }
    return [];
  }

  function findHandlers(text) {
    var re = /(?:^|[\r\n])[ \t]*end[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?=[\r\n\x00]|$|--)/g;
    var counts = {};
    var total = 0;
    var m;
    while ((m = re.exec(text)) !== null) {
      var name = m[1];
      if (IGNORE_END[name.toLowerCase()]) continue;
      counts[name] = (counts[name] || 0) + 1;
    }
    // keep a name only if something opens it: on, command, function...
    Object.keys(counts).forEach(function (name) {
      var opener = new RegExp('(?:^|[^A-Za-z0-9_])(?:on|command|function|getprop|setprop|before|after)[ \\t]+' + name + '\\b', 'i');
      if (!opener.test(text)) delete counts[name];
      else total += counts[name];
    });
    var names = Object.keys(counts).sort(function (a, b2) { return counts[b2] - counts[a] || (a < b2 ? -1 : 1); });
    return { count: total, distinct: names.length, top: names.slice(0, 8).map(function (n) { return { name: n, count: counts[n] }; }) };
  }

  // ---- The report ----

  function baseReport(name, size) {
    return {
      fileName: name || 'stack',
      size: size || 0,
      kind: 'unknown',
      verdict: 'unknown',
      title: '',
      summary: '',
      facts: [],       // [label, value, note]
      findings: [],    // {status, title, detail, names, link}
      widgets: [],
      platforms: [],
      handlers: null,
      libraries: [],
      next: []
    };
  }

  function nextStepsFor(r) {
    var steps = [];
    if (r.verdict === 'opens' || r.verdict === 'notes') {
      steps.push(['Play it in your browser', 'Open the Stack Player and choose this file. It runs in the page, with nothing to install.', 'player']);
      steps.push(['Keep a copy first', 'OXT-Beyond saves in the 8.1 format, which LiveCode 8.1 and later read, but going back and forth has not been tested yet. Work on a copy.', '']);
      steps.push(['Tell us if anything differs', 'Reports like that become fixes, and often tests that keep them fixed.', 'report']);
    } else if (r.verdict === 'import') {
      steps.push(['Import it', 'In OXT-Beyond, File > Import Stack > HyperCard Stack. Or drop it on the Stack Player, which imports it the same way.', 'player']);
    }
    return steps;
  }

  function finish(r) {
    var blocked = r.findings.some(function (f) { return f.status === 'blocked'; });
    var doubt = r.findings.some(function (f) { return f.status === 'doubt'; });
    var notes = r.findings.some(function (f) { return f.status === 'note' || f.status === 'preview'; });
    if (r.kind === 'binary' || r.kind === 'scriptonly') {
      if (blocked) {
        r.verdict = 'blocked';
        r.title = 'Won\'t open as it is';
      } else if (doubt) {
        r.verdict = 'doubt';
        r.title = 'Check this file first';
      } else if (notes) {
        r.verdict = 'notes';
        r.title = 'Opens, with notes';
      } else {
        r.verdict = 'opens';
        r.title = 'Opens in OXT-Beyond';
      }
    }
    r.next = nextStepsFor(r);
    return r;
  }

  function addScans(r, b, text) {
    if (r.kind === 'binary') {
      r.widgets = findWidgets(b, text);
      r.widgets.forEach(function (w) {
        if (!w.shipped) {
          r.findings.push({
            status: 'note',
            title: 'A widget OXT-Beyond does not have: ' + w.id,
            detail: 'The stack still opens. The widget shows as a placeholder, and the settings saved in it are kept, so they come back if you install its extension (an .lce package, in the Extension Manager).'
          });
        }
      });
    }
    findCalls(text).forEach(function (f) { r.findings.push(f); });
    r.libraries = findLibraries(text);
    // (a script-only stack has no property sets)
    r.platforms = r.kind === 'binary' ? findPlatforms(b, text, r.format.version) : [];
    if (r.platforms.indexOf('iOS') >= 0) {
      r.findings.push({
        status: 'note',
        title: 'Set up to build for iOS',
        detail: 'OXT-Beyond has no iOS build. It keeps the iOS settings, and builds the stack for its other platforms.'
      });
    }
    r.handlers = findHandlers(text);
  }

  function inspectBinary(r, b) {
    var h = readHeader(b);
    r.kind = 'binary';
    if (!h.ok) {
      r.kind = 'binary';
      r.verdict = 'blocked';
      r.title = 'Looks damaged';
      r.summary = h.damaged || 'The file could not be read as a stack.';
      r.findings.push({ status: 'blocked', title: 'The file could not be read', detail: r.summary });
      r.next = [['Check the backup', 'LiveCode and OXT-Beyond keep the copy before the last save beside the stack, with a ~ at the end of its name. Try that file.', '']];
      return r;
    }
    var fmt = formatFor(h.version);
    r.format = { version: h.version, label: h.newer ? versionLabel(h.version) : fmt.label, header: h.headerText };
    if (h.newer) {
      r.facts.push(['Stack file format', versionLabel(h.version), 'newer than OXT-Beyond reads (up to 8.1)']);
      r.findings.push({
        status: 'blocked',
        title: 'Saved in a newer stack format than OXT-Beyond reads',
        detail: 'OXT-Beyond reads every stack format up to 8.1, and this file says ' + versionLabel(h.version) + '. In the LiveCode that saved it, save a copy in the 8.1 format and check that copy:',
        code: 'save stack "' + (r.fileName.replace(/\.[A-Za-z]+$/, '') || 'Name') + '" as "copy.livecode" with format "8.1"'
      });
      r.summary = 'It was saved in a stack format newer than 8.1. A copy saved in format 8.1 would open.';
      return finish(r);
    }
    r.facts.push(['Stack file format', fmt.label + (h.version === CURRENT ? ' (the newest, and the one OXT-Beyond saves)' : ''), '']);
    r.facts.push(['Saved by', fmt.savedBy + (h.version === CURRENT ? '' : '') , '']);
    if (h.charset === 1 || h.charset === 0) {
      r.facts.push(['Saved on', h.charset === 1 ? 'a Mac' : 'Windows, Linux or another system that is not a Mac', h.version < 7000 ? 'its text is translated as it opens' : '']);
    }
    if (h.encrypted) {
      r.facts.unshift(['Stack', '(password-protected)', '']);
      r.findings.push({
        status: 'blocked',
        title: 'Password-protected',
        detail: 'LiveCode Community never opened password-protected stacks, and OXT-Beyond does not either. In the LiveCode that set the password, remove it and save, then check again:',
        code: 'set the password of this stack to empty'
      });
      r.summary = 'Its password keeps it closed to OXT-Beyond, as it did to LiveCode Community.';
      return finish(r);
    }
    if (h.name) r.facts.unshift(['Stack', h.name, '']);
    r.stackName = h.name || '';
    if (h.version === CURRENT) {
      r.findings.push({
        status: 'info',
        title: 'Format 8.1 does not say which LiveCode saved it',
        detail: 'LiveCode 8.1 and 9 both save this format, so the file cannot say which one saved it. If this stack came from LiveCode 10 or 11, the parts those versions added (new syntax and widgets) may not work: stacks from those versions have not been tested in OXT-Beyond yet.'
      });
    }
    if (h.endsWell === false) {
      r.findings.push({
        status: 'doubt',
        title: 'The file may be incomplete',
        detail: 'A stack file ends with a zero byte, and this one does not. If it was downloaded or copied, try that again; LiveCode and OXT-Beyond also keep the copy before the last save beside the stack, with a ~ after its name.'
      });
    }
    var text = byteText(b);
    addScans(r, b, text);
    finish(r);
    if (r.verdict === 'doubt') r.summary = 'Its format is one OXT-Beyond reads, but the file looks cut short, and a stack that is cut short will not open.';
    else if (r.verdict === 'opens') r.summary = 'Its format is one OXT-Beyond reads, and nothing the checker found needs a change.';
    else if (r.verdict === 'notes') r.summary = 'Its format is one OXT-Beyond reads. Read the notes: some parts work differently, need the preview release, or are not there.';
    return r;
  }

  function inspectScriptOnly(r, b) {
    r.kind = 'scriptonly';
    var text = utf8Text(b, 0, b.length).replace(/^﻿/, '');
    var m = /^\s*script\s+"([^"\r\n]*)"(?:\s+with\s+behavior\s+"([^"\r\n]*)")?/.exec(text);
    r.stackName = m ? m[1] : '';
    r.facts.push(['Stack', r.stackName || '(no name)', '']);
    r.facts.push(['Kind', 'Script-only stack: plain text, read as LiveCode 8 and later read it', '']);
    if (m && m[2]) r.facts.push(['Behavior', m[2], '']);
    r.facts.push(['Lines', String(text.split(/\r\n|\r|\n/).length), '']);
    addScans(r, b, text);
    finish(r);
    r.summary = r.verdict === 'opens'
      ? 'Script-only stacks open in OXT-Beyond as they do in LiveCode 8 and later.'
      : 'Script-only stacks open in OXT-Beyond as they do in LiveCode 8 and later. Read the notes about what it calls.';
    return r;
  }

  // A HyperCard stack's first block, STAK: its format at 0x10 (8 for
  // HyperCard 1, 10 for HyperCard 2; 9 and below 8 were pre-releases),
  // its backgrounds at 0x24 and its cards at 0x2C (checked against the
  // test stacks in OpenXTalk-Beyond's tests/lcs-input-files/hypercard)
  function hyperCardFacts(r, b, at) {
    if (b.length < at + 0x30 || ascii(b, at + 4, at + 8) !== 'STAK') return;
    var format = u32(b, at + 0x10);
    var label = format === 10 ? 'HyperCard 2' : format === 8 ? 'HyperCard 1' : format === 9 ? 'a HyperCard 2 pre-release' : format < 8 ? 'a HyperCard 1 pre-release' : '';
    if (label) r.facts.push(['Made with', label, '']);
    var cards = u32(b, at + 0x2C);
    var bgs = u32(b, at + 0x24);
    if (cards > 0 && cards < 100000) r.facts.push(['Cards', String(cards), plural(bgs, 'background', 'backgrounds')]);
  }

  function inspectOld(r, kind, b) {
    r.kind = 'hypercard';
    r.verdict = 'import';
    var kindFact = r.facts.length;
    var what = {
      hypercard: 'a HyperCard stack',
      macbinary: 'a HyperCard stack in a MacBinary file',
      applesingle: 'an AppleSingle file (a Mac file with its resource fork)',
      appledouble: 'the resource fork half of a Mac file (AppleDouble)',
      binhex: 'a BinHex file',
      diskimage: 'a Mac disk image'
    }[kind];
    r.title = kind === 'diskimage' ? 'A Mac disk image: import its stacks' : 'A HyperCard stack: import it';
    r.facts.splice(kindFact, 0, ['Kind', what.charAt(0).toUpperCase() + what.slice(1), '']);
    if (kind === 'hypercard') hyperCardFacts(r, b, 0);
    if (kind === 'macbinary') hyperCardFacts(r, b, 128);
    var detail = kind === 'diskimage'
      ? 'OXT-Beyond reads raw HFS images, DiskCopy 4.2 images and CD images with an Apple partition map, and lists the HyperCard stacks on them to choose from.'
      : kind === 'appledouble'
        ? 'This is the part of a Mac file that holds its resource fork. Give it to the importer together with the stack it belongs to (beside it as ._Name, or in a zip\'s __MACOSX folder).'
        : 'OXT-Beyond imports HyperCard stacks with their cards, scripts, pictures, palettes, colour and sound, and makes the scripts compile and run. MacBinary, BinHex and AppleSingle copies are read too.';
    r.findings.push({ status: 'ok', title: 'HyperCard import', detail: detail });
    if (kind !== 'diskimage' && /merryxmas/i.test(byteText(b))) {
      r.findings.push({
        status: 'note',
        title: 'The mark of the Merryxmas virus',
        detail: 'Its scripts contain "merryxmas", the mark of a HyperCard virus from the time that copies itself into other stacks\' scripts. After importing, find the handler marked --merryxmas (often an openBackground handler) and delete it before you use the stack.'
      });
    }
    r.summary = 'It is not an xTalk stack file yet, but OXT-Beyond imports it: File > Import Stack > HyperCard Stack, or drop it on the Stack Player.';
    r.next = nextStepsFor(r);
    return r;
  }

  // Inspect one file's bytes. Returns a report (zip files go through inspectFile).
  function inspect(bytes, name) {
    var b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    var r = baseReport(name, b.length);
    var kind = sniff(b);
    if (kind === 'binary') return inspectBinary(r, b);
    if (kind === 'scriptonly') return inspectScriptOnly(r, b);
    if (kind === 'hypercard' || kind === 'macbinary' || kind === 'applesingle' || kind === 'appledouble' || kind === 'binhex' || kind === 'diskimage') return inspectOld(r, kind, b);
    if (kind === 'empty') {
      r.kind = 'empty';
      r.title = 'The file is empty';
      r.summary = 'There is nothing in it to read.';
      return r;
    }
    if (kind === 'zip') {
      r.kind = 'zip';
      r.title = 'A zip file';
      r.summary = 'Open it with the checker\'s file chooser or drop it, and the stacks inside are checked.';
      return r;
    }
    r.kind = 'unknown';
    r.title = 'Not a stack file';
    r.summary = 'A stack file starts with REVO (or, if it is very old, a MetaCard header), and a script-only stack starts with script "its name". This file starts with neither.';
    return r;
  }

  // ---- Zip files: the stacks inside ----

  var STACK_NAME = /\.(livecode|livecodescript|rev|oxtstack|mc|lc|stack|hc|lcs)$/i;

  function inflate(data) {
    if (typeof DecompressionStream === 'undefined') return Promise.reject(new Error('no-inflate'));
    var ds = new DecompressionStream('deflate-raw');
    var stream = new Blob([data]).stream().pipeThrough(ds);
    return new Response(stream).arrayBuffer().then(function (buf) { return new Uint8Array(buf); });
  }

  function zipEntries(b) {
    // the end of central directory record, searched for from the end
    var end = -1;
    for (var i = b.length - 22; i >= Math.max(0, b.length - 65557); i--) {
      if (b[i] === 0x50 && b[i + 1] === 0x4B && b[i + 2] === 5 && b[i + 3] === 6) { end = i; break; }
    }
    if (end < 0) throw new Error('not-zip');
    var count = le16(b, end + 10);
    var dir = le32(b, end + 16);
    if (dir === 0xFFFFFFFF || count === 0xFFFF) throw new Error('zip64');
    var out = [];
    var p = dir;
    for (var k = 0; k < count && p + 46 <= b.length; k++) {
      if (le32(b, p) !== 0x02014b50) break;
      var method = le16(b, p + 10);
      var flags = le16(b, p + 8);
      var csize = le32(b, p + 20);
      var usize = le32(b, p + 24);
      var nlen = le16(b, p + 28);
      var xlen = le16(b, p + 30);
      var clen = le16(b, p + 32);
      var local = le32(b, p + 42);
      var nameBytes = b.subarray(p + 46, p + 46 + nlen);
      var name = (flags & 0x800) ? utf8Text(nameBytes, 0, nameBytes.length) : nativeText(nameBytes, 0, nameBytes.length, false);
      out.push({ name: name, method: method, csize: csize, usize: usize, local: local, encrypted: !!(flags & 1) });
      p += 46 + nlen + xlen + clen;
    }
    return out;
  }

  function entryBytes(b, e) {
    var p = e.local;
    if (le32(b, p) !== 0x04034b50) return Promise.reject(new Error('bad-entry'));
    var start = p + 30 + le16(b, p + 26) + le16(b, p + 28);
    var data = b.subarray(start, start + e.csize);
    if (e.method === 0) return Promise.resolve(data);
    if (e.method === 8) return inflate(data);
    return Promise.reject(new Error('method'));
  }

  // Inspect a file: {name, bytes}. Resolves to a list of reports (a zip
  // gives one for each stack in it).
  function inspectFile(name, bytes) {
    var b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    if (sniff(b) !== 'zip') return Promise.resolve([inspect(b, name)]);
    var entries;
    try {
      entries = zipEntries(b);
    } catch (e) {
      var r = baseReport(name, b.length);
      r.kind = 'zip';
      r.title = e.message === 'zip64' ? 'A zip too big to read here' : 'A zip that could not be read';
      r.summary = 'Unzip it, and check the stack file itself.';
      return Promise.resolve([r]);
    }
    var files = entries.filter(function (e) {
      return !/\/$/.test(e.name) && !/(^|\/)__MACOSX\//.test(e.name) && !/(^|\/)\._/.test(e.name) && e.usize < 200 * 1024 * 1024;
    });
    var named = files.filter(function (e) { return STACK_NAME.test(e.name); });
    var candidates = (named.length ? named : files.slice().sort(function (a, c) { return a.usize - c.usize; })).slice(0, 12);
    var reports = [];
    var chain = Promise.resolve();
    candidates.forEach(function (e) {
      chain = chain.then(function () {
        if (e.encrypted) return;
        return entryBytes(b, e).then(function (data) {
          var kind = sniff(data);
          if (kind === 'unknown' || kind === 'zip' || kind === 'empty') return;
          var rep = inspect(data, e.name.split('/').pop());
          rep.inZip = name;
          rep.path = e.name;
          reports.push(rep);
        }, function (err) {
          if (err && err.message === 'no-inflate') throw err;
        });
      });
    });
    return chain.then(function () {
      if (reports.length) return reports;
      var r = baseReport(name, b.length);
      r.kind = 'zip';
      r.title = 'No stack in this zip';
      r.summary = 'None of the ' + plural(files.length, 'file', 'files') + ' in it is a stack file, a script-only stack or a HyperCard stack.';
      return [r];
    }, function () {
      var r = baseReport(name, b.length);
      r.kind = 'zip';
      r.title = 'This browser cannot unzip it here';
      r.summary = 'Unzip it, and check the stack file itself.';
      return [r];
    });
  }

  // ---- The report as plain text, to paste into a forum post ----

  function toText(r) {
    var lines = [];
    lines.push('Stack checker report (OXT-Beyond ' + STABLE + ' / ' + PREVIEW + ')');
    lines.push('File: ' + (r.path || r.fileName) + (r.inZip ? ' (in ' + r.inZip + ')' : '') + ', ' + r.size + ' bytes');
    lines.push('Result: ' + r.title + (r.summary ? ' - ' + r.summary : ''));
    r.facts.forEach(function (f) { lines.push(f[0] + ': ' + f[1] + (f[2] ? ' (' + f[2] + ')' : '')); });
    if (r.widgets && r.widgets.length) {
      lines.push('Widgets: ' + r.widgets.map(function (w) { return w.id + (w.shipped ? '' : ' [not in OXT-Beyond]'); }).join(', '));
    }
    if (r.platforms && r.platforms.length) lines.push('Set up to build for: ' + r.platforms.join(', '));
    if (r.handlers && r.handlers.count) lines.push('Handlers found in its scripts: about ' + r.handlers.count);
    if (r.libraries && r.libraries.length) lines.push('Starts using: ' + r.libraries.join(', '));
    r.findings.forEach(function (f) {
      lines.push('- [' + f.status + '] ' + f.title + (f.names && f.names.length ? ' (' + f.names.join(', ') + ')' : ''));
    });
    lines.push('(Read from the file without running it.)');
    return lines.join('\n');
  }

  return {
    inspect: inspect,
    inspectFile: inspectFile,
    toText: toText,
    sniff: sniff,
    readHeader: readHeader,
    WIDGETS: WIDGETS,
    STABLE: STABLE,
    PREVIEW: PREVIEW,
    REPO: REPO
  };
});
