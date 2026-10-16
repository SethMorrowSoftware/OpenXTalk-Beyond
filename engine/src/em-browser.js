/*                                                              -*-Javascript-*-

 Copyright (C) 2026 OXT-Beyond contributors.

 This file is part of OXT-Beyond.

 OXT-Beyond is free software; you can redistribute it and/or modify it
 under the terms of the GNU General Public License v3 as published by the
 Free Software Foundation.

 OXT-Beyond is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// The web engine's browsers (libbrowser/src/libbrowser_em.cpp), which the
// browser widget shows: each is an <iframe> of the page, which the engine
// places over the stack's canvas as the widget's native layer.
//
// A frame shows a page of the stack's site, the widget's htmlText, a file
// of the engine's file system (a file: URL, or a path), or a page of
// another site that lets other sites frame it. The first three are the
// stack's own, as every page is on the desktop: the engine reads their URL
// and HTML text, runs JavaScript in them (do ... in widget), and gives them
// the liveCode object, with a function for each of the javascriptHandlers.
// A page of another site is the browser's: the engine knows only the URL
// it gave the frame, and the page calls a handler with
//
//     window.parent.postMessage({liveCode: 'handlerName',
//                                parameters: [...]}, '*')
//
// The engine hears when a page begins and ends loading (the widget sends
// browserNavigateBegin, browserDocumentLoadComplete, ...), as from the
// desktop's browsers: nothing for the htmlText, and for a page of another
// site, only what the stack sends it to (the frame does not say where that
// page's links lead).
//
// A frame's pages cannot take the stack's page (a page that "breaks out of
// frames", or a link to _top, would replace the stack): the frame is
// sandboxed with every other permission. The browser's PDF viewer does not
// run in a sandboxed frame, so a PDF the stack sends the frame to is shown
// in a frame without the sandbox.

mergeInto(LibraryManager.library, {

	$LiveCodeBrowser__deps: ['$LiveCodeUtil', '$LiveCodeAsync', '$FS', '$stringToNewUTF8'],
	$LiveCodeBrowser: {

		// The browsers, by the engine's id for them
		_browsers: {},

		// The events the engine hears of (enum MCEmscriptenBrowserEvent,
		// libbrowser_em.cpp)
		kNavigateBegin: 1,
		kNavigateComplete: 2,
		kNavigateFailed: 3,
		kDocumentLoadBegin: 4,
		kDocumentLoadComplete: 5,
		kDocumentLoadFailed: 6,
		kUnhandled: 7,
		kProgress: 8,

		// Its properties (enum MCEmscriptenBrowserProperty)
		kVScrollbar: 1,
		kHScrollbar: 2,
		kAllowUserInteraction: 3,
		kIsSecure: 4,
		kURL: 5,
		kHTMLText: 6,
		kUserAgent: 7,
		kJavaScriptHandlers: 8,
		kCanGoBack: 9,
		kCanGoForward: 10,

		// The types of the values in the engine's lists (enum
		// MCBrowserValueType, libbrowser.h)
		kBoolean: 1,
		kInteger: 2,
		kDouble: 3,
		kString: 4,
		kList: 5,
		kDictionary: 6,

		_sandbox: 'allow-downloads allow-forms allow-modals allow-orientation-lock ' +
			'allow-pointer-lock allow-popups allow-popups-to-escape-sandbox ' +
			'allow-presentation allow-same-origin allow-scripts',

		// Those of them that this browser knows: Safari reports each one
		// it does not (allow-orientation-lock, allow-presentation) as an
		// error in the console every time the frame gets them, and ignores
		// it, so leaving them out changes nothing but the console
		_sandboxFlags: function() {
			if (LiveCodeBrowser._supportedSandbox === undefined) {
				var flags = LiveCodeBrowser._sandbox;
				try {
					var list = document.createElement('iframe').sandbox;
					if (list && list.supports) {
						flags = flags.split(' ').filter(function(flag) {
							return list.supports(flag);
						}).join(' ');
					}
				} catch (e) {
				}
				LiveCodeBrowser._supportedSandbox = flags;
			}
			return LiveCodeBrowser._supportedSandbox;
		},

		// The media types of the files that a frame shows, by extension
		_types: {
			'html': 'text/html', 'htm': 'text/html', 'xhtml': 'application/xhtml+xml',
			'txt': 'text/plain', 'css': 'text/css', 'js': 'text/javascript',
			'mjs': 'text/javascript', 'json': 'application/json', 'xml': 'application/xml',
			'svg': 'image/svg+xml', 'png': 'image/png', 'jpg': 'image/jpeg',
			'jpeg': 'image/jpeg', 'gif': 'image/gif', 'webp': 'image/webp',
			'bmp': 'image/bmp', 'ico': 'image/x-icon', 'pdf': 'application/pdf',
			'mp4': 'video/mp4', 'webm': 'video/webm', 'ogg': 'audio/ogg',
			'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'woff': 'font/woff',
			'woff2': 'font/woff2', 'ttf': 'font/ttf', 'otf': 'font/otf',
		},

		// Makes the frame of browser <id>, and returns its object id
		// (LiveCodeUtil.storeObject), for the engine's native layer
		create: function(id) {
			var frame = document.createElement('iframe');
			frame.setAttribute('sandbox', LiveCodeBrowser._sandboxFlags());
			frame.setAttribute('allow', 'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture');
			frame.style.border = 'none';
			// A page without a background shows white, as on the desktop
			frame.style.backgroundColor = '#FFFFFF';

			var browser = {
				'id': id,
				'frame': frame,
				'url': '',              // the URL of its page; '' for the htmlText
				'entries': [],          // its pages, {url} or {html}, for back and forward
				'index': -1,
				'expect': null,         // the page it is loading: {url, html, begun, user}
				'doc': null,            // its page's document, when the page is the stack's
				'pending': null,        // where that page is going (a link, a form)
				'listeners': [],        // ... on that page's window
				'blobs': [],            // the object URLs of its page's files
				'oldBlobs': [],         // ... and of the page it is leaving
				'poll': null,
				'handlerText': '',      // the javascriptHandlers
				'handlers': [],
				'vScrollbar': true,
				'hScrollbar': true,
				'interaction': true,
				'userAgent': '',
				'destroyed': false,
			};

			// The first script of the htmlText calls this, before the page's
			// own scripts run
			frame.__oxtLiveCode = function(win) {
				LiveCodeBrowser._prepare(browser, win);
			};
			browser.onLoad = function() {
				LiveCodeBrowser._loaded(browser);
			};
			frame.addEventListener('load', browser.onLoad);
			browser.onMessage = function(event) {
				LiveCodeBrowser._message(browser, event);
			};
			window.addEventListener('message', browser.onMessage);

			LiveCodeBrowser._browsers[id] = browser;
			return LiveCodeUtil.storeObject(frame);
		},

		destroy: function(id) {
			var browser = LiveCodeBrowser._browsers[id];
			if (!browser) {
				return;
			}
			delete LiveCodeBrowser._browsers[id];
			browser.destroyed = true;
			LiveCodeBrowser._stopPolling(browser);
			LiveCodeBrowser._forget(browser);
			window.removeEventListener('message', browser.onMessage);
			var frame = browser.frame;
			frame.removeEventListener('load', browser.onLoad);
			delete frame.__oxtLiveCode;
			// The native layer has taken the frame out of the page, which
			// ends its page; one still in the page stops (and its sounds)
			if (frame.isConnected) {
				frame.removeAttribute('srcdoc');
				frame.src = 'about:blank';
			}
			LiveCodeBrowser._revoke(browser.blobs.concat(browser.oldBlobs));
			browser.blobs = [];
			browser.oldBlobs = [];
		},

		_get: function(id) {
			return LiveCodeBrowser._browsers[id] || null;
		},

		goToURL: function(id, url) {
			var browser = LiveCodeBrowser._get(id);
			return browser ? LiveCodeBrowser._open(browser, {'url': url}, true) : false;
		},

		loadHTMLText: function(id, html) {
			var browser = LiveCodeBrowser._get(id);
			return browser ? LiveCodeBrowser._open(browser, {'html': html}, true) : false;
		},

		// Back and forward through the pages it has shown, without the
		// history of the stack's page
		go: function(id, delta) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return;
			}
			var index = browser.index + delta;
			if (index < 0 || index >= browser.entries.length) {
				return;
			}
			browser.index = index;
			LiveCodeBrowser._open(browser, browser.entries[index], false);
		},

		reload: function(id) {
			var browser = LiveCodeBrowser._get(id);
			if (browser && browser.index >= 0) {
				LiveCodeBrowser._open(browser, browser.entries[browser.index], false);
			}
		},

		stop: function(id) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return;
			}
			if (LiveCodeBrowser._document(browser)) {
				try {
					browser.frame.contentWindow.stop();
				} catch (e) {
				}
			}
			LiveCodeBrowser._stopPolling(browser);
			browser.expect = null;
		},

		// Shows <entry> ({url} or {html}); <record>: a new page after the
		// one it shows
		_open: function(browser, entry, record) {
			LiveCodeBrowser._stopPolling(browser);
			browser.pending = null;

			if (entry.html !== undefined) {
				if (record) {
					LiveCodeBrowser._record(browser, {'html': entry.html});
				}
				browser.url = '';
				browser.expect = {'html': true};
				LiveCodeBrowser._retire(browser);
				LiveCodeBrowser._sandboxed(browser, true);
				browser.frame.srcdoc = LiveCodeBrowser._bootstrap(entry.html);
				return true;
			}

			var url = entry.url;
			var file = LiveCodeBrowser._fileOf(url);
			if (file !== null) {
				// A file of the engine's file system, shown from an object
				// URL: it is the stack's page
				url = 'file://' + encodeURI(file);
				if (record) {
					LiveCodeBrowser._record(browser, {'url': url});
				}
				browser.url = url;
				LiveCodeBrowser._retire(browser);
				LiveCodeBrowser._begin(browser, url);
				var blob = LiveCodeBrowser._fileURL(browser, file, true);
				if (blob === null) {
					// As the desktop's browsers do for a missing file
					browser.expect = null;
					LiveCodeBrowser._failed(browser, url, 'file not found');
					return true;
				}
				browser.expect = {'url': url, 'begun': true};
				LiveCodeBrowser._navigate(browser, blob, LiveCodeBrowser._typeOf(file) == 'application/pdf');
				LiveCodeBrowser._poll(browser);
				return true;
			}

			var href = LiveCodeBrowser._resolve(url);
			if (href === null) {
				// A URL that a frame cannot show (mailto:, tel:, an app's):
				// the stack hears of it, as on the desktop
				LiveCodeBrowser._notify(browser, LiveCodeBrowser.kUnhandled, url);
				return true;
			}
			if (record) {
				LiveCodeBrowser._record(browser, {'url': href});
			}
			browser.url = href;
			LiveCodeBrowser._retire(browser);
			LiveCodeBrowser._begin(browser, href);
			browser.expect = {'url': href, 'begun': true};
			LiveCodeBrowser._navigate(browser, href, LiveCodeBrowser._isPDF(href));
			LiveCodeBrowser._poll(browser);
			return true;
		},

		// Sends the frame to <href>, without a new entry in the history of
		// the stack's page
		_navigate: function(browser, href, pdf) {
			var frame = browser.frame;
			LiveCodeBrowser._sandboxed(browser, !pdf);
			var win = frame.contentWindow;
			if (win) {
				try {
					// The page it shows (if it is the stack's) says when the
					// next one is there
					win.addEventListener('pagehide', function() {
						LiveCodeBrowser._soon(browser);
					}, {'once': true});
				} catch (e) {
				}
				try {
					win.location.replace(href);
					return;
				} catch (e) {
				}
			}
			// Not in the page yet: it loads its src when it is
			frame.removeAttribute('srcdoc');
			frame.src = href;
		},

		_sandboxed: function(browser, sandboxed) {
			if (sandboxed) {
				browser.frame.setAttribute('sandbox', LiveCodeBrowser._sandboxFlags());
			} else {
				browser.frame.removeAttribute('sandbox');
			}
		},

		_isPDF: function(href) {
			try {
				return /\.pdf$/i.test(new URL(href).pathname);
			} catch (e) {
				return false;
			}
		},

		// The URL that a frame shows for <url>, or null if a frame cannot
		// show it. A URL without a scheme is of the stack's site, relative
		// to the stack's page (as a player's is).
		_resolve: function(url) {
			if (url === '') {
				return 'about:blank';
			}
			if (/^[a-z][a-z0-9+.\-]*:/i.test(url) && !/^(https?|data|blob|about):/i.test(url)) {
				return null;
			}
			try {
				return new URL(url, document.baseURI).href;
			} catch (e) {
				return null;
			}
		},

		// The file of the engine's file system that <url> names (a file:
		// URL, or the path of a file), or null
		_fileOf: function(url) {
			if (/^file:/i.test(url)) {
				try {
					return LiveCodeBrowser._normalise(
						decodeURIComponent(url.replace(/^file:(\/\/[^\/]*)?/i, '').replace(/[?#].*$/, '')));
				} catch (e) {
					return null;
				}
			}
			if (url.charAt(0) == '/' && LiveCodeBrowser._isFile(url)) {
				return url;
			}
			return null;
		},

		_normalise: function(path) {
			var parts = [];
			path.split('/').forEach(function(part) {
				if (part == '..') {
					parts.pop();
				} else if (part != '.' && part != '') {
					parts.push(part);
				}
			});
			return '/' + parts.join('/');
		},

		_isFile: function(path) {
			try {
				return FS.isFile(FS.stat(path).mode);
			} catch (e) {
				return false;
			}
		},

		_typeOf: function(path) {
			var dot = path.lastIndexOf('.');
			return dot < 0 ? '' : LiveCodeBrowser._types[path.substring(dot + 1).toLowerCase()] || '';
		},

		// An object URL of the file at <path>, or null if it cannot be
		// read. In the page (<page>) of an HTML file, the relative URLs of
		// files (its images, scripts, style sheets, ...) become theirs, and
		// its links to files are followed (_watch).
		_fileURL: function(browser, path, page) {
			var data;
			try {
				if (!FS.isFile(FS.stat(path).mode)) {
					return null;
				}
				data = FS.readFile(path);
			} catch (e) {
				return null;
			}
			var type = LiveCodeBrowser._typeOf(path);
			if (page && type == 'text/html') {
				var text;
				try {
					text = new TextDecoder('utf-8', {'fatal': true}).decode(data);
				} catch (e) {
					text = new TextDecoder('windows-1252').decode(data);
				}
				var doc = new DOMParser().parseFromString(text, 'text/html');
				LiveCodeBrowser._localise(browser, doc, path.substring(0, path.lastIndexOf('/') + 1));
				var script = doc.createElement('script');
				script.textContent = LiveCodeBrowser._readyScript;
				doc.head.insertBefore(script, doc.head.firstChild);
				data = (doc.doctype ? new XMLSerializer().serializeToString(doc.doctype) + '\n' : '') +
					doc.documentElement.outerHTML;
				type = 'text/html;charset=utf-8';
			}
			var url = URL.createObjectURL(new Blob([data], {'type': type}));
			browser.blobs.push(url);
			return url;
		},

		_localise: function(browser, doc, folder) {
			[['[src]', 'src'], ['link[href]', 'href'], ['video[poster]', 'poster'], ['object[data]', 'data']].forEach(function(which) {
				Array.prototype.forEach.call(doc.querySelectorAll(which[0]), function(element) {
					var file = LiveCodeBrowser._localFile(folder, element.getAttribute(which[1]));
					var url = file === null ? null : LiveCodeBrowser._fileURL(browser, file, false);
					if (url !== null) {
						element.setAttribute(which[1], url);
					}
				});
			});
			Array.prototype.forEach.call(doc.querySelectorAll('a[href], area[href]'), function(element) {
				var href = element.getAttribute('href');
				var file = LiveCodeBrowser._localFile(folder, href);
				if (file !== null) {
					var hash = href.indexOf('#');
					element.setAttribute('data-oxt-file', 'file://' + encodeURI(file) + (hash < 0 ? '' : href.substring(hash)));
				}
			});
		},

		// The file that the relative URL <ref> of a file in <folder> names,
		// if there is one
		_localFile: function(folder, ref) {
			if (!ref || /^([a-z][a-z0-9+.\-]*:|\/\/|#)/i.test(ref)) {
				return null;
			}
			var path;
			try {
				path = decodeURIComponent(ref.replace(/[?#].*$/, ''));
			} catch (e) {
				return null;
			}
			path = LiveCodeBrowser._normalise(path.charAt(0) == '/' ? path : folder + path);
			return LiveCodeBrowser._isFile(path) ? path : null;
		},

		// The page it leaves keeps its files until the next one is there
		_retire: function(browser) {
			LiveCodeBrowser._revoke(browser.oldBlobs);
			browser.oldBlobs = browser.blobs;
			browser.blobs = [];
		},

		_revoke: function(urls) {
			urls.forEach(function(url) {
				URL.revokeObjectURL(url);
			});
		},

		// The first script of the htmlText and of a file's page: it readies
		// the page before the page's own scripts run, and then takes itself
		// out
		_readyScript: '(function(s){try{var f=window.frameElement;' +
			'if(f&&f.__oxtLiveCode)f.__oxtLiveCode(window)}catch(e){}' +
			'if(s&&s.parentNode)s.parentNode.removeChild(s)})(document.currentScript)',

		// The htmlText, with that script after the doctype, which must come
		// first
		_bootstrap: function(html) {
			var script = '<script>' + LiveCodeBrowser._readyScript + '<\/script>';
			var doctype = /^(\s*(<!--[\s\S]*?-->\s*)*<!doctype[^>]*>)/i.exec(html);
			if (doctype) {
				return doctype[1] + script + html.substring(doctype[1].length);
			}
			return script + html;
		},

		_record: function(browser, entry) {
			browser.entries.length = browser.index + 1;
			browser.entries.push(entry);
			browser.index = browser.entries.length - 1;
		},

		// The document of its page, if the page is the stack's
		_document: function(browser) {
			try {
				return browser.frame.contentDocument || null;
			} catch (e) {
				return null;
			}
		},

		// The frame has loaded a page
		_loaded: function(browser) {
			if (browser.destroyed) {
				return;
			}
			var frame = browser.frame;
			var doc = LiveCodeBrowser._document(browser);
			var href = doc ? doc.URL : '';
			var expect = browser.expect;
			// Its first, empty page
			if (doc && href == 'about:blank' && !(expect && expect.url == 'about:blank')) {
				return;
			}

			LiveCodeBrowser._stopPolling(browser);
			browser.expect = null;
			LiveCodeBrowser._revoke(browser.oldBlobs);
			browser.oldBlobs = [];
			if (doc) {
				LiveCodeBrowser._prepare(browser, frame.contentWindow);
			} else {
				LiveCodeBrowser._forget(browser);
				browser.doc = null;
			}

			if (!expect) {
				// A page of the stack's site that a script sent the frame
				// to before the frame saw it go
				if (!doc || href == 'about:srcdoc' || /^blob:/i.test(href)) {
					return;
				}
				expect = {'url': href, 'user': true};
			}
			// The htmlText: no messages, as on the desktop
			if (expect.html) {
				return;
			}
			// Where the stack's page ended up (after redirects); a file's
			// is its file: URL
			var url = expect.url;
			if (doc && href != 'about:srcdoc' && !/^blob:/i.test(href)) {
				url = href;
			}
			// A page of another site went where the frame cannot see
			if (!url) {
				return;
			}
			if (!expect.begun) {
				LiveCodeBrowser._begin(browser, url);
			}
			if (expect.user) {
				LiveCodeBrowser._record(browser, {'url': url});
			}
			browser.url = url;
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kProgress, url, null, 100);
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kDocumentLoadComplete, url);
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kNavigateComplete, url);
		},

		_begin: function(browser, url) {
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kNavigateBegin, url);
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kDocumentLoadBegin, url);
		},

		_failed: function(browser, url, error) {
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kDocumentLoadFailed, url, error);
			LiveCodeBrowser._notify(browser, LiveCodeBrowser.kNavigateFailed, url, error);
		},

		// While the frame loads a page that may be the stack's, readies the
		// page as soon as it is there, so that its scripts find the
		// liveCode object: right after the page it leaves has gone (_soon),
		// or else when it next looks
		_poll: function(browser) {
			LiveCodeBrowser._stopPolling(browser);
			var start = Date.now();
			// A page of another site does not say when it goes: going from
			// one to the stack's page, it looks between every two things the
			// browser does, for a while
			var close = !LiveCodeBrowser._document(browser) &&
				LiveCodeBrowser._isOwn(browser.expect && browser.expect.url);
			var tick = function() {
				browser.poll = null;
				if (browser.destroyed || !browser.expect || Date.now() - start > 60000) {
					return;
				}
				LiveCodeBrowser._check(browser);
				if (close && !browser.doc && Date.now() - start < 5000) {
					var channel = new MessageChannel();
					channel.port1.onmessage = function() {
						channel.port1.close();
						tick();
					};
					browser.poll = {'cancel': function() {
						channel.port1.close();
					}};
					channel.port2.postMessage(null);
				} else {
					var timer = setTimeout(tick, 10);
					browser.poll = {'cancel': function() {
						clearTimeout(timer);
					}};
				}
			};
			var first = setTimeout(tick, 0);
			browser.poll = {'cancel': function() {
				clearTimeout(first);
			}};
		},

		// Whether <url> is a page of the stack's site, or a file
		_isOwn: function(url) {
			if (!url) {
				return false;
			}
			if (/^file:/i.test(url)) {
				return true;
			}
			try {
				return new URL(url, document.baseURI).origin === window.location.origin;
			} catch (e) {
				return false;
			}
		},

		_check: function(browser) {
			if (browser.destroyed || !browser.expect) {
				return;
			}
			var doc = LiveCodeBrowser._document(browser);
			if (doc && doc !== browser.doc && doc.URL != 'about:blank') {
				LiveCodeBrowser._prepare(browser, browser.frame.contentWindow);
			}
		},

		// The page that the frame showed has gone, as the next one comes:
		// that one is there once the browser has finished putting it there
		_soon: function(browser) {
			var channel = new MessageChannel();
			channel.port1.onmessage = function() {
				channel.port1.close();
				LiveCodeBrowser._check(browser);
			};
			channel.port2.postMessage(null);
		},

		_stopPolling: function(browser) {
			if (browser.poll) {
				browser.poll.cancel();
				browser.poll = null;
			}
		},

		// Readies the stack's page in the frame: its liveCode object, its
		// scroll bars, and what tells the frame where the page goes
		_prepare: function(browser, win) {
			if (browser.destroyed) {
				return;
			}
			var doc;
			try {
				doc = win.document;
			} catch (e) {
				return;
			}
			if (doc !== browser.doc) {
				browser.doc = doc;
				browser.pending = null;
				LiveCodeBrowser._install(browser, win);
				LiveCodeBrowser._watch(browser, win);
			}
			LiveCodeBrowser._scrollbars(browser);
		},

		// The liveCode object of the page, with a function for each of the
		// javascriptHandlers
		_install: function(browser, win) {
			try {
				if (browser.handlers.length == 0) {
					delete win.liveCode;
					return;
				}
				var liveCode = new win.Object();
				browser.handlers.forEach(function(name) {
					liveCode[name] = function() {
						LiveCodeBrowser._call(browser, name, arguments);
					};
				});
				win.Object.defineProperty(win, 'liveCode', {'value': liveCode, 'configurable': true,
				                                            'enumerable': false, 'writable': false});
			} catch (e) {
			}
		},

		_watch: function(browser, win) {
			LiveCodeBrowser._forget(browser);
			var listen = function(target, type, handler, capture) {
				target.addEventListener(type, handler, capture);
				browser.listeners.push([target, type, handler, capture]);
			};
			// Where the page is going: a link it follows, a form it sends,
			// or (where the browser tells) any page
			listen(win, 'click', function(event) {
				if (event.button != 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) {
					return;
				}
				var target = event.target;
				var link = target && target.closest ? target.closest('a[href], area[href]') : null;
				if (!link || (link.target && link.target != '_self') || link.hasAttribute('download')) {
					return;
				}
				var file = link.getAttribute('data-oxt-file');
				if (file !== null) {
					// A file's link to another: the frame shows that file as
					// one the stack gives it
					event.preventDefault();
					setTimeout(function() {
						if (!browser.destroyed) {
							LiveCodeBrowser._open(browser, {'url': file}, true);
						}
					}, 0);
					return;
				}
				browser.pending = link.href;
			}, true);
			listen(win, 'submit', function(event) {
				var form = event.target;
				if (form && (!form.target || form.target == '_self')) {
					browser.pending = form.action;
				}
			}, true);
			// A page that stops the link or form goes nowhere
			var stopped = function(event) {
				if (event.defaultPrevented) {
					browser.pending = null;
				}
			};
			listen(win, 'click', stopped, false);
			listen(win, 'submit', stopped, false);
			try {
				if (win.navigation && win.navigation.addEventListener) {
					listen(win.navigation, 'navigate', function(event) {
						if (event.destination && !event.destination.sameDocument && !event.downloadRequest) {
							browser.pending = event.destination.url;
						}
					}, false);
				}
			} catch (e) {
			}
			listen(win, 'pagehide', function() {
				LiveCodeBrowser._leaving(browser);
				LiveCodeBrowser._soon(browser);
			}, false);
		},

		_forget: function(browser) {
			browser.listeners.forEach(function(listener) {
				try {
					listener[0].removeEventListener(listener[1], listener[2], listener[3]);
				} catch (e) {
				}
			});
			browser.listeners = [];
		},

		// The stack's page in the frame is going, where the stack did not
		// send it: to where it said, if it did
		_leaving: function(browser) {
			if (browser.destroyed || browser.expect || !browser.frame.isConnected) {
				return;
			}
			var url = browser.pending;
			browser.pending = null;
			browser.expect = {'url': url, 'begun': !!url, 'user': true};
			if (url) {
				LiveCodeBrowser._begin(browser, url);
			}
			LiveCodeBrowser._poll(browser);
		},

		_scrollbars: function(browser) {
			var frame = browser.frame;
			if (browser.vScrollbar || browser.hScrollbar) {
				frame.removeAttribute('scrolling');
			} else {
				frame.setAttribute('scrolling', 'no');
			}
			var doc = browser.doc;
			if (!doc || !doc.documentElement || (browser.vScrollbar && browser.hScrollbar && !doc.__oxtScrollbars)) {
				return;
			}
			try {
				var style = doc.documentElement.style;
				style.overflowY = browser.vScrollbar ? '' : 'hidden';
				style.overflowX = browser.hScrollbar ? '' : 'hidden';
				doc.__oxtScrollbars = true;
			} catch (e) {
			}
		},

		// A message from the frame's page: a call of one of the
		// javascriptHandlers from a page of another site
		_message: function(browser, event) {
			if (browser.destroyed || !event.source || event.source !== browser.frame.contentWindow) {
				return;
			}
			var data = event.data;
			if (!data || typeof data !== 'object' || typeof data.liveCode !== 'string') {
				return;
			}
			LiveCodeBrowser._call(browser, data.liveCode, Array.isArray(data.parameters) ? data.parameters : []);
		},

		// The page calls handler <name> of the javascriptHandlers: the
		// widget sends it to its object, after what the page is doing,
		// with the arguments as the desktop's browsers give them
		_call: function(browser, name, args) {
			if (browser.destroyed || browser.handlers.indexOf(name) < 0) {
				return;
			}
			var values = [];
			for (var i = 0; i < args.length; i++) {
				values.push(LiveCodeBrowser._value(args[i], 0));
			}
			setTimeout(function() {
				if (browser.destroyed) {
					return;
				}
				LiveCodeAsync.resume(function() {
					LiveCodeBrowser._deliver(browser, name, values);
				});
			}, 0);
		},

		// A value of the page, as {t: type, v: value}: a boolean, an
		// integer, a number, a string, an array (a list), or an object or
		// a function (a dictionary of its own keys); anything else (null,
		// undefined) is a string, as JavaScript's String() writes it
		_value: function(value, depth) {
			var B = LiveCodeBrowser;
			switch (typeof value) {
				case 'boolean':
					return {'t': B.kBoolean, 'v': value};
				case 'number':
					if (value === Math.floor(value) && value >= -2147483648 && value <= 2147483647) {
						return {'t': B.kInteger, 'v': value};
					}
					return {'t': B.kDouble, 'v': value};
				case 'string':
					return {'t': B.kString, 'v': value};
				case 'object':
				case 'function':
					if (value === null || depth >= 64) {
						break;
					}
					try {
						if (Array.isArray(value)) {
							var items = [];
							for (var i = 0; i < value.length; i++) {
								items.push(B._value(value[i], depth + 1));
							}
							return {'t': B.kList, 'v': items};
						}
						return {'t': B.kDictionary, 'v': Object.keys(value).map(function(key) {
							return [key, B._value(value[key], depth + 1)];
						})};
					} catch (e) {
					}
					break;
			}
			try {
				return {'t': B.kString, 'v': String(value)};
			} catch (e) {
				return {'t': B.kString, 'v': ''};
			}
		},

		_deliver: function(browser, name, values) {
			var list = LiveCodeBrowser._list(values);
			if (!list) {
				return;
			}
			var namePtr = stringToNewUTF8(name);
			try {
				Module.ccall('MCEmscriptenBrowserHandleJavaScriptCall', null,
				             ['number', 'number', 'number'], [browser.id, namePtr, list]);
			} finally {
				Module._free(namePtr);
				LiveCodeBrowser._release(LiveCodeBrowser.kList, list);
			}
		},

		// The engine's list of <values>, or 0
		_list: function(values) {
			var list = Module.ccall('MCEmscriptenBrowserListCreate', 'number', [], []);
			for (var i = 0; list && i < values.length; i++) {
				if (!LiveCodeBrowser._put(list, null, values[i])) {
					LiveCodeBrowser._release(LiveCodeBrowser.kList, list);
					list = 0;
				}
			}
			return list;
		},

		// The engine's dictionary of <entries> ([key, value]), or 0
		_dictionary: function(entries) {
			var dict = Module.ccall('MCEmscriptenBrowserDictionaryCreate', 'number', [], []);
			for (var i = 0; dict && i < entries.length; i++) {
				if (!LiveCodeBrowser._put(dict, entries[i][0], entries[i][1])) {
					LiveCodeBrowser._release(LiveCodeBrowser.kDictionary, dict);
					dict = 0;
				}
			}
			return dict;
		},

		// Appends <item> to the engine's list <container>, or sets it as
		// <key> of its dictionary
		_put: function(container, key, item) {
			var B = LiveCodeBrowser;
			var number = 0, string = null, ref = 0;
			if (item.t == B.kBoolean) {
				number = item.v ? 1 : 0;
			} else if (item.t == B.kInteger || item.t == B.kDouble) {
				number = item.v;
			} else if (item.t == B.kString) {
				string = item.v;
			} else if (item.t == B.kList) {
				ref = B._list(item.v);
			} else if (item.t == B.kDictionary) {
				ref = B._dictionary(item.v);
			}
			if ((item.t == B.kList || item.t == B.kDictionary) && !ref) {
				return false;
			}
			var stringPtr = string === null ? 0 : stringToNewUTF8(string);
			var keyPtr = key === null ? 0 : stringToNewUTF8(key);
			try {
				if (key === null) {
					return Module.ccall('MCEmscriptenBrowserListAppend', 'boolean',
					                    ['number', 'number', 'number', 'number', 'number'],
					                    [container, item.t, number, stringPtr, ref]);
				}
				return Module.ccall('MCEmscriptenBrowserDictionarySet', 'boolean',
				                    ['number', 'number', 'number', 'number', 'number', 'number'],
				                    [container, keyPtr, item.t, number, stringPtr, ref]);
			} finally {
				if (stringPtr) {
					Module._free(stringPtr);
				}
				if (keyPtr) {
					Module._free(keyPtr);
				}
				if (ref) {
					B._release(item.t, ref);
				}
			}
		},

		_release: function(type, ref) {
			Module.ccall('MCEmscriptenBrowserValueRelease', null, ['number', 'number'], [type, ref]);
		},

		// Tells the engine of an event of the frame, after what the page
		// is doing, and wakes it
		_notify: function(browser, event, url, error, progress) {
			setTimeout(function() {
				if (browser.destroyed) {
					return;
				}
				LiveCodeAsync.resume(function() {
					var urlPtr = stringToNewUTF8(url || '');
					var errorPtr = stringToNewUTF8(error || '');
					try {
						Module.ccall('MCEmscriptenBrowserHandleEvent', null,
						             ['number', 'number', 'number', 'number', 'number'],
						             [browser.id, event, urlPtr, errorPtr, progress || 0]);
					} finally {
						Module._free(urlPtr);
						Module._free(errorPtr);
					}
				});
			}, 0);
		},

		// The URL of its page: the stack's page's where it is, else the one
		// it was sent to
		_url: function(browser) {
			if (browser.url === '') {
				return '';
			}
			var doc = LiveCodeBrowser._document(browser);
			if (doc && doc === browser.doc && /^(https?|data|about):/i.test(doc.URL) &&
			    doc.URL != 'about:blank' && doc.URL != 'about:srcdoc') {
				return doc.URL;
			}
			return browser.url;
		},

		// The HTML text of the stack's page in the frame
		_htmlText: function(browser) {
			var doc = LiveCodeBrowser._document(browser);
			if (!doc || !doc.documentElement) {
				return '';
			}
			var text = doc.documentElement.outerHTML;
			if (doc.doctype) {
				text = new XMLSerializer().serializeToString(doc.doctype) + '\n' + text;
			}
			return text;
		},

		getBoolean: function(id, property) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return false;
			}
			var B = LiveCodeBrowser;
			switch (property) {
				case B.kVScrollbar:
					return browser.vScrollbar;
				case B.kHScrollbar:
					return browser.hScrollbar;
				case B.kAllowUserInteraction:
					return browser.interaction;
				case B.kIsSecure:
					return /^https:/i.test(B._url(browser));
				case B.kCanGoBack:
					return browser.index > 0;
				case B.kCanGoForward:
					return browser.index < browser.entries.length - 1;
			}
			return false;
		},

		setBoolean: function(id, property, value) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return;
			}
			var B = LiveCodeBrowser;
			var frame = browser.frame;
			switch (property) {
				case B.kVScrollbar:
					browser.vScrollbar = value;
					B._scrollbars(browser);
					break;
				case B.kHScrollbar:
					browser.hScrollbar = value;
					B._scrollbars(browser);
					break;
				case B.kAllowUserInteraction:
					// Neither the pointer nor the keyboard reach its page
					browser.interaction = value;
					frame.style.pointerEvents = value ? '' : 'none';
					if (value) {
						frame.removeAttribute('inert');
					} else {
						frame.setAttribute('inert', '');
					}
					break;
			}
		},

		getString: function(id, property) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return 0;
			}
			var B = LiveCodeBrowser;
			var value = '';
			switch (property) {
				case B.kURL:
					value = B._url(browser);
					break;
				case B.kHTMLText:
					value = B._htmlText(browser);
					break;
				case B.kUserAgent:
					value = browser.userAgent;
					break;
				case B.kJavaScriptHandlers:
					value = browser.handlerText;
					break;
			}
			return stringToNewUTF8(value);
		},

		setString: function(id, property, value) {
			var browser = LiveCodeBrowser._get(id);
			if (!browser) {
				return;
			}
			var B = LiveCodeBrowser;
			switch (property) {
				case B.kUserAgent:
					// The browser sends its own: a page cannot change it
					browser.userAgent = value;
					break;
				case B.kJavaScriptHandlers:
					browser.handlerText = value;
					browser.handlers = value.split(/[\r\n]+/).map(function(name) {
						return name.trim();
					}).filter(function(name) {
						return name !== '';
					});
					var doc = B._document(browser);
					if (doc && doc === browser.doc) {
						B._install(browser, browser.frame.contentWindow);
					}
					break;
			}
		},

		// Runs <script> in the stack's page in the frame, and returns its
		// value as a string, or null if it throws or the page is another
		// site's
		evaluate: function(id, script) {
			var browser = LiveCodeBrowser._get(id);
			var doc = browser ? LiveCodeBrowser._document(browser) : null;
			if (!doc) {
				return 0;
			}
			var result;
			try {
				result = browser.frame.contentWindow.eval(script);
				result = typeof result === 'string' ? result : String(result);
			} catch (e) {
				return 0;
			}
			return stringToNewUTF8(result);
		},
	},

	MCEmscriptenBrowserCreate__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserCreate: function(p_id) {
		return LiveCodeBrowser.create(p_id);
	},

	MCEmscriptenBrowserDestroy__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserDestroy: function(p_id) {
		LiveCodeBrowser.destroy(p_id);
	},

	MCEmscriptenBrowserGoToURL__deps: ['$LiveCodeBrowser', '$UTF8ToString'],
	MCEmscriptenBrowserGoToURL: function(p_id, p_url) {
		return LiveCodeBrowser.goToURL(p_id, UTF8ToString(p_url));
	},

	MCEmscriptenBrowserLoadHTMLText__deps: ['$LiveCodeBrowser', '$UTF8ToString'],
	MCEmscriptenBrowserLoadHTMLText: function(p_id, p_html) {
		return LiveCodeBrowser.loadHTMLText(p_id, UTF8ToString(p_html));
	},

	MCEmscriptenBrowserGoBack__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserGoBack: function(p_id) {
		LiveCodeBrowser.go(p_id, -1);
	},

	MCEmscriptenBrowserGoForward__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserGoForward: function(p_id) {
		LiveCodeBrowser.go(p_id, 1);
	},

	MCEmscriptenBrowserReload__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserReload: function(p_id) {
		LiveCodeBrowser.reload(p_id);
	},

	MCEmscriptenBrowserStop__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserStop: function(p_id) {
		LiveCodeBrowser.stop(p_id);
	},

	MCEmscriptenBrowserEvaluate__deps: ['$LiveCodeBrowser', '$UTF8ToString'],
	MCEmscriptenBrowserEvaluate: function(p_id, p_script) {
		return LiveCodeBrowser.evaluate(p_id, UTF8ToString(p_script));
	},

	MCEmscriptenBrowserGetBoolean__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserGetBoolean: function(p_id, p_property) {
		return LiveCodeBrowser.getBoolean(p_id, p_property) ? 1 : 0;
	},

	MCEmscriptenBrowserSetBoolean__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserSetBoolean: function(p_id, p_property, p_value) {
		LiveCodeBrowser.setBoolean(p_id, p_property, !!p_value);
	},

	MCEmscriptenBrowserGetString__deps: ['$LiveCodeBrowser'],
	MCEmscriptenBrowserGetString: function(p_id, p_property) {
		return LiveCodeBrowser.getString(p_id, p_property);
	},

	MCEmscriptenBrowserSetString__deps: ['$LiveCodeBrowser', '$UTF8ToString'],
	MCEmscriptenBrowserSetString: function(p_id, p_property, p_value) {
		LiveCodeBrowser.setString(p_id, p_property, UTF8ToString(p_value));
	},
});
