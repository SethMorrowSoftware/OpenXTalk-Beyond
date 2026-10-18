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
  var state = 'off';      // off, connecting, connected, waiting
  var generation = 0;
  var retry = null;

  function open() {
    retry = null;
    if (!wanted) {
      return;
    }
    state = state === 'off' ? 'connecting' : state;
    var mine;
    try {
      mine = new WebSocket(url);
    } catch (e) {
      later();
      return;
    }
    socket = mine;
    mine.onopen = function () {
      if (socket !== mine) {
        return;
      }
      generation++;
      queue.length = 0;
      state = 'connected';
    };
    mine.onmessage = function (event) {
      if (socket === mine && typeof event.data === 'string') {
        queue.push(generation + '\t' + event.data);
      }
    };
    mine.onclose = function () {
      if (socket !== mine) {
        return;
      }
      socket = null;
      if (state === 'connected') {
        generation++;
        queue.length = 0;
      }
      state = wanted ? 'waiting' : 'off';
      later();
    };
  }

  function later() {
    if (wanted && !retry) {
      retry = setTimeout(open, RETRY_MS);
    }
  }

  window.oxtMcpLink = {
    // Starts connecting to the MCP server on this port of this computer
    start: function (port) {
      url = 'ws://127.0.0.1:' + Number(port) + '/';
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
        generation++;
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
      if (socket && socket.readyState === 1 && g === generation) {
        socket.send(line);
      }
    }
  };
})();
