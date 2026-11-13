/*                                                              -*-Javascript-*-

Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// OXT-Beyond: sockets over WebSocket (em-osspec-network.cpp).
//
// A page cannot open a TCP socket, but it can open a WebSocket, so the
// web engine's "open socket to" a ws:// or wss:// URL opens one. What the
// server sends reaches the engine as the socket's bytes (a text message
// as its UTF-8 bytes, a binary one as it is), and what a script writes is
// sent as one message: a text message when its bytes are UTF-8, a binary
// one otherwise. Each event of the WebSocket wakes the engine, which
// handles it (MCEmscriptenSocketHandleEvent) and sends the socket's
// messages as a desktop engine would.

mergeInto(LibraryManager.library, {

	$LiveCodeSocket__deps: ['$LiveCodeAsync'],
	$LiveCodeSocket: {

		// The WebSockets, by the engine's id for them (never 0)
		_sockets: {},
		_nextId: 1,

		// The events the engine hears of (enum MCEmscriptenSocketEvent,
		// em-osspec-network.cpp)
		kOpen: 1,
		kData: 2,
		kError: 3,
		kClose: 4,

		_encoder: null,
		_decoder: null,

		// Opens a WebSocket to <url>; returns its id, or 0 when the
		// browser refuses the URL (one that is not ws: or wss:, or a
		// ws: one from an https: page)
		open: function(url) {
			var ws;
			try {
				ws = new WebSocket(url);
			} catch (e) {
				return 0;
			}
			ws.binaryType = 'arraybuffer';
			var id = LiveCodeSocket._nextId++;
			LiveCodeSocket._sockets[id] = ws;

			ws.addEventListener('open', function() {
				LiveCodeSocket._notify(id, LiveCodeSocket.kOpen, null);
			});
			ws.addEventListener('message', function(event) {
				var bytes;
				if (typeof event.data === 'string') {
					if (!LiveCodeSocket._encoder) {
						LiveCodeSocket._encoder = new TextEncoder();
					}
					bytes = LiveCodeSocket._encoder.encode(event.data);
				} else {
					bytes = new Uint8Array(event.data);
				}
				LiveCodeSocket._notify(id, LiveCodeSocket.kData, bytes);
			});
			ws.addEventListener('error', function() {
				// A browser says nothing of why, for the page's safety
				LiveCodeSocket._notify(id, LiveCodeSocket.kError, null);
			});
			ws.addEventListener('close', function(event) {
				delete LiveCodeSocket._sockets[id];
				// 1000 is a normal close, by either side, and 1005 one
				// with no code: anything else, before the socket opened
				// or after, is an error
				var clean = event.wasClean && (event.code == 1000 || event.code == 1005);
				LiveCodeSocket._notify(id, LiveCodeSocket.kClose,
				                       null, clean ? 1 : 0);
			});
			return id;
		},

		// Sends <bytes> (a Uint8Array) on socket <id>: as a text message
		// when they are UTF-8, a binary one otherwise. Bytes that begin
		// with a UTF-8 byte order mark go as binary: a text message's
		// receiver decodes it without the mark (the WebSocket standard's
		// "UTF-8 decode"), and the bytes must arrive as they were sent.
		// Returns false if the socket is not open.
		send: function(id, bytes) {
			var ws = LiveCodeSocket._sockets[id];
			if (!ws || ws.readyState !== 1) {
				return false;
			}
			if (!LiveCodeSocket._decoder) {
				LiveCodeSocket._decoder = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true });
			}
			var text = null;
			var bom = bytes.length >= 3 && bytes[0] === 0xEF &&
			          bytes[1] === 0xBB && bytes[2] === 0xBF;
			try {
				text = bom ? null : LiveCodeSocket._decoder.decode(bytes);
			} catch (e) {
				text = null;
			}
			try {
				ws.send(text !== null ? text : bytes);
			} catch (e) {
				return false;
			}
			return true;
		},

		// Closes socket <id>; the engine hears nothing more of it
		close: function(id) {
			var ws = LiveCodeSocket._sockets[id];
			if (!ws) {
				return;
			}
			delete LiveCodeSocket._sockets[id];
			try {
				ws.close(1000);
			} catch (e) {
			}
		},

		// Tells the engine of an event of socket <id>, with <bytes> (a
		// Uint8Array, or null) and <flag>, and wakes it
		_notify: function(id, event, bytes, flag) {
			LiveCodeAsync.resume(function() {
				var ptr = 0;
				var length = 0;
				if (bytes && bytes.length > 0) {
					length = bytes.length;
					ptr = Module._malloc(length);
					if (!ptr) {
						return;
					}
					Module.HEAPU8.set(bytes, ptr);
				}
				// The engine frees the bytes
				Module.ccall('MCEmscriptenSocketHandleEvent', null,
				             ['number', 'number', 'number', 'number', 'number'],
				             [id, event, ptr, length, flag ? 1 : 0]);
			});
		},
	},

	MCEmscriptenSocketOpen__deps: ['$LiveCodeSocket', '$LiveCodeUtil'],
	MCEmscriptenSocketOpen: function(p_url, p_length) {
		return LiveCodeSocket.open(LiveCodeUtil.stringFromUTF16(p_url, p_length));
	},

	MCEmscriptenSocketSend__deps: ['$LiveCodeSocket'],
	MCEmscriptenSocketSend: function(p_id, p_bytes, p_length) {
		return LiveCodeSocket.send(p_id, Module.HEAPU8.slice(p_bytes, p_bytes + p_length));
	},

	MCEmscriptenSocketClose__deps: ['$LiveCodeSocket'],
	MCEmscriptenSocketClose: function(p_id) {
		LiveCodeSocket.close(p_id);
	},
});
