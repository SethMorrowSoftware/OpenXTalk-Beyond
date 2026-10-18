// Copyright (C) 2026 OXT-Beyond contributors.
//
// This file is part of OXT-Beyond.
//
// OXT-Beyond is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License v3 as published by the Free
// Software Foundation.
//
// OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License
// along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

// The web IDE's end of the xTalk MCP Bridge's link: the page's half, which
// the plugin's main stack (mcpbridge.livecodescript) puts into the web IDE's
// page with do ... as "JavaScript" when the user chooses Connect.
//
// A page cannot listen for a connection, so it connects out: to the MCP
// server (server.js --web) that Claude's app runs on the user's computer,
// which listens on ws://127.0.0.1:<port>. Until that server is there (Claude
// is not open yet, or quit), the page tries again every few seconds.
//
// No script runs from here. Each request the server sends is queued, and
// the IDE's script takes it on a timer (oxtMcpLink.poll), runs the tool,
// and gives the answer back (oxtMcpLink.reply), so that a tool can ask the
// user or wait, as it does on the desktop. Each connection made or lost
// counts one more in generation: a request is queued with the generation
// it came in, and an answer is sent only on that same connection, since
// the server forgets what it asked over a connection once it closes.
//
// Any program on the computer could listen on that port first, so the
// page takes nothing from what answers until it proves it holds the key
// the IDE gave Claude's setup (server.js, OXT_MCP_WEB_KEY): the page sends
// a fresh nonce with the connection, the server's first message is its
// own nonce and an HMAC of both made with the key, and only when that is
// right does the page give its own HMAC; it counts itself connected when
// the server says it took the page. The state is "refused" while what
// answers on the port cannot prove it holds the key.

(function () {
  'use strict';
  if (window.oxtMcpLink) {
    return;
  }
  var RETRY_MS = 3000;
  var queue = [];
  var socket = null;
  var url = '';
  var wanted = false;
  var state = 'off';      // off, connecting, connected, waiting, refused, insecure
  var generation = 0;
  var retry = null;
  var key = '';

  function hex(bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; i++) {
      out += (bytes[i] + 256).toString(16).slice(1);
    }
    return out;
  }

  // The HMAC-SHA256, in hex, of text with the key (server.js's proof)
  function proof(text) {
    var encoder = new TextEncoder();
    return crypto.subtle.importKey('raw', encoder.encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
      .then(function (k) {
        return crypto.subtle.sign('HMAC', k, encoder.encode(text));
      })
      .then(function (signature) {
        return hex(new Uint8Array(signature));
      });
  }

  function open() {
    retry = null;
    if (!wanted) {
      return;
    }
    state = state === 'off' ? 'connecting' : state;
    // HMAC needs the browser's crypto, which a page has only over https
    // or on this computer
    if (!window.crypto || !crypto.subtle || !crypto.getRandomValues) {
      state = 'insecure';
      return;
    }
    var mine;
    var nonce = hex(crypto.getRandomValues(new Uint8Array(32)));
    var proven = false;
    var asked = false;      // the page gave its proof, and waits for the server's yes
    var hello;              // the server's first message, once it came
    try {
      mine = new WebSocket(url + '?n=' + nonce);
    } catch (e) {
      later();
      return;
    }
    socket = mine;
    mine.onmessage = function (event) {
      if (socket !== mine || typeof event.data !== 'string') {
        return;
      }
      if (proven) {
        queue.push(generation + '\t' + event.data);
        return;
      }
      if (asked) {
        var yes = null;
        try {
          yes = JSON.parse(event.data);
        } catch (e) {
          // not the server's yes
        }
        if (!yes || yes.oxtMcpWeb !== 1 || yes.connected !== true) {
          refuse(mine);
          return;
        }
        proven = true;
        generation++;
        queue.length = 0;
        state = 'connected';
        return;
      }
      if (hello !== undefined) {
        return;
      }
      // The first message: the server's proof that it holds the key
      hello = null;
      try {
        hello = JSON.parse(event.data);
      } catch (e) {
        // not a proof
      }
      if (!hello || hello.oxtMcpWeb !== 1 || !/^[0-9a-f]{64}$/.test(String(hello.nonce)) ||
          typeof hello.proof !== 'string') {
        refuse(mine);
        return;
      }
      var serverNonce = String(hello.nonce);
      proof('server\n' + nonce + '\n' + serverNonce).then(function (expected) {
        if (socket !== mine) {
          return null;
        }
        if (expected !== hello.proof) {
          refuse(mine);
          return null;
        }
        return proof('page\n' + nonce + '\n' + serverNonce);
      }).then(function (mineProof) {
        if (!mineProof || socket !== mine || mine.readyState !== 1) {
          return;
        }
        asked = true;
        mine.send(JSON.stringify({ oxtMcpWeb: 1, proof: mineProof }));
      }, function () {
        refuse(mine);
      });
    };
    mine.onclose = function () {
      if (socket !== mine) {
        return;
      }
      socket = null;
      if (proven) {
        generation++;
        queue.length = 0;
      }
      state = wanted ? 'waiting' : 'off';
      later();
    };
  }

  // Leaves what answered on the port without waiting for it to agree to
  // close (one that is not the server may never), and tries again later
  function refuse(mine) {
    if (socket !== mine) {
      return;
    }
    socket = null;
    try {
      mine.close();
    } catch (e) {
      // closed already
    }
    state = 'refused';
    later();
  }

  function later() {
    if (wanted && !retry) {
      retry = setTimeout(open, RETRY_MS);
    }
  }

  window.oxtMcpLink = {
    // Starts connecting to the MCP server on this port of this computer,
    // which has to prove it holds this key
    start: function (port, withKey) {
      url = 'ws://127.0.0.1:' + Number(port) + '/';
      key = String(withKey || '');
      if (!wanted) {
        wanted = true;
        state = 'connecting';
        open();
      }
    },
    // Disconnects, and stops trying
    stop: function () {
      wanted = false;
      if (retry) {
        clearTimeout(retry);
        retry = null;
      }
      if (socket) {
        var was = socket;
        socket = null;
        was.close();
        if (state === 'connected') {
          generation++;
        }
      }
      queue.length = 0;
      state = 'off';
    },
    // The state and the generation, a tab between them, then a line feed
    // and the oldest request queued ("<generation><tab><line>"), if any
    poll: function () {
      return state + '\t' + generation + '\n' + (queue.length ? queue.shift() : '');
    },
    // The answer to a request that came in generation g
    reply: function (g, line) {
      if (socket && socket.readyState === 1 && state === 'connected' && g === generation) {
        socket.send(line);
      }
    }
  };
})();
