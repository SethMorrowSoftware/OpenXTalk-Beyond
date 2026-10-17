#!/usr/bin/env node
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

// The MCP server of the xTalk MCP Bridge: Claude's own apps (the Claude
// desktop app, Claude Code) start it, and it passes what Claude asks for to
// OXT-Beyond, so that Claude, paid for by the user's own Claude plan, can
// read, build and run the stacks open in the IDE. Anthropic lets no other
// program sign in to a Claude account, so the IDE does not talk to Claude:
// Claude talks to the IDE, through this.
//
// The Model Context Protocol over stdio: JSON-RPC 2.0 messages, one per
// line, on standard input and output (anything else this prints goes to
// standard error). The tools are listed here, with their descriptions and
// schemas, so that Claude sees them even while OXT-Beyond is closed; a call
// then says how to start the bridge.
//
// OXT-Beyond's side (mcpbridge-tools.livecodescript, in the folder above)
// listens on 127.0.0.1 only, on a port the system picks, and writes the
// port and a token to ~/.oxt-beyond/mcp-bridge.json while the bridge is on
// (OXT_MCP_BRIDGE_FILE names another file, for tests). Each call goes to it
// as a line of JSON with the token, and its answer comes back as a line.
// Calls go one at a time: the IDE does one thing at a time anyway.
//
// Node 16 or later, its standard library only: the Claude desktop app runs
// this with the Node it carries, so the user installs nothing.

'use strict';

const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const readline = require('readline');

const SERVER_VERSION = '0.2.0';
// The bridge protocol this speaks (the "protocol" of the IDE's file and of
// its answer to hello)
const BRIDGE_PROTOCOL = 1;
// The MCP versions this answers to, newest first: a client asking for one
// of them gets it, any other client the newest
const MCP_VERSIONS = ['2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'];
// How long a call may take, in milliseconds: a run, or the user answering
// a question in the IDE, can take minutes
const CALL_TIMEOUT_MS = Number(process.env.OXT_MCP_TIMEOUT_MS) || 10 * 60 * 1000;
const CONNECT_TIMEOUT_MS = 5000;
// How long OXT-Beyond may take to answer hello: it answers at once unless
// it is stuck
const HELLO_TIMEOUT_MS = Number(process.env.OXT_MCP_HELLO_TIMEOUT_MS) || 15000;
// How long a call waits for an earlier one to finish before it is told
// that OXT-Beyond is busy (the earlier one may be waiting for the user to
// answer a question there)
const BUSY_WAIT_MS = Number(process.env.OXT_MCP_BUSY_WAIT_MS) || 20000;

const INSTRUCTIONS = [
  'These tools work in OXT-Beyond, a free IDE for xTalk Script (the language of LiveCode Community 9 and',
  'OpenXTalk, descended from HyperCard), on the stacks the user has open in it.',
  'Call xtalk_guide once before you write xTalk code: it is the house guide to the language and this engine.',
  'Find the user\'s stacks with list_stacks, and what they have in front of them (the selection, the script open in',
  'the Script Editor, the last error) with ide_context. Read a stack with read_stack (an outline first, then cards or',
  'controls by their ids), find text in its scripts with search_scripts, and see a card with look_at_card.',
  'Build with make_changes (controls, cards, a new stack,',
  'properties and scripts, as one checked batch), try code with run_code, and save with save_stack.',
  'A long script is read in parts with read_script and changed a handler or a range of lines at a time with edit_script.',
  'A change is made as soon as the user allows the tool here; OXT-Beyond asks the user itself before every run of code',
  '(showing it), before saving, and before undoing what they changed since.',
  'undo_changes takes back what you changed or ran on a stack. Check code with check_code and look up what you',
  'are not sure of with lookup_dictionary rather than guess.'
].join(' ');

const READ_ONLY = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };
const CHANGES = { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false };
// Code run in OXT-Beyond can do what the IDE can: files, the network, other programs
const RUNS = { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true };
// What make_changes creates (the xTalk Assistant's xtbKinds)
const KINDS = ['button', 'default button', 'checkbox', 'radio button', 'option menu', 'pulldown menu', 'popup menu', 'combo box',
  'tab panel', 'field', 'text area', 'label', 'list field', 'table field', 'rectangle', 'round rectangle', 'oval', 'line',
  'polygon', 'regular polygon', 'curve', 'scrollbar', 'slider', 'progress bar', 'image', 'player', 'group', 'widget', 'card',
  'stack'];
const STACK = { type: 'string', description: 'The stack or substack, by name, as list_stacks gives it; empty for the one the user is working on' };

const TOOLS = [
  {
    name: 'xtalk_guide',
    title: 'Read the xTalk guide',
    description: 'Gives the guide to writing xTalk Script for OXT-Beyond: the language, its objects, what this engine does ' +
      'differently from other xTalks, and the house style. Read it once, before you write xTalk code.',
    inputSchema: { type: 'object', properties: {} },
    annotations: READ_ONLY
  },
  {
    name: 'list_stacks',
    title: 'List the open stacks',
    description: 'Lists the user\'s stacks open in OXT-Beyond (not the IDE\'s own): each one\'s name, file, cards and ' +
      'substacks, and which one the user is working on (that of the script open in the Script Editor, else the stack in front).',
    inputSchema: { type: 'object', properties: {} },
    annotations: READ_ONLY
  },
  {
    name: 'ide_context',
    title: 'See what the user has in front of them',
    description: 'Tells what the user has in front of them in OXT-Beyond: the stack they work on and the card in front, the ' +
      'objects selected with the pointer tool, the script open in the Script Editor with the line its caret is on (and ' +
      'whether it holds changes they have not applied), the last error the IDE showed them with the script around it, and ' +
      'whether a script is paused in the debugger. Use it when the user speaks of "this", "the selected button" or "the error".',
    inputSchema: { type: 'object', properties: {} },
    annotations: READ_ONLY
  },
  {
    name: 'read_stack',
    title: 'Read a stack',
    description: 'Reads a stack of the user\'s. With no id: an outline of it and its substacks, their cards and their ' +
      'controls with ids and rects, and how long each script is. With an id from the outline, and the stack it is in ' +
      '(ids repeat from stack to stack): that card\'s or control\'s properties and script, and a card\'s controls. ' +
      'With ids: several at once. An object\'s properties are those a new one of its kind would not have (all_properties ' +
      'for every one), with its custom properties and their values. With details true and no id: the stack\'s own ' +
      'properties, cards and script. Password-protected stacks are not read. ' +
      'A script is shown up to 24,000 characters; read_script reads a longer one whole, in parts.',
    inputSchema: {
      type: 'object',
      properties: {
        stack: STACK,
        id: { type: 'integer', description: 'The id of a card or control, as the outline gives it' },
        ids: { type: 'array', items: { type: 'integer' }, maxItems: 20, description: 'Several ids, read at once' },
        details: { type: 'boolean', description: 'With no id: the stack\'s own properties and script instead of the outline' },
        all_properties: { type: 'boolean', description: 'Every property with a short value, not only those a new object would not have' }
      }
    },
    annotations: READ_ONLY
  },
  {
    name: 'read_script',
    title: 'Read a script',
    description: 'Reads the script of a stack, card or control of the user\'s, with line numbers and where each handler ' +
      'begins and ends: the whole of a long script, in parts (about 20,000 characters at a time; the result says where ' +
      'to read on), or one handler by name. Use it before edit_script, which takes these line numbers.',
    inputSchema: {
      type: 'object',
      properties: {
        stack: STACK,
        id: { type: 'integer', description: 'The id of a card or control, as read_stack gives it; none for the stack\'s own script' },
        handler: { type: 'string', description: 'Only this handler, by name (mouseUp)' },
        from_line: { type: 'integer', description: 'The first line to read (1 when none)' },
        to_line: { type: 'integer', description: 'The last line to read (the end when none)' }
      }
    },
    annotations: READ_ONLY
  },
  {
    name: 'search_scripts',
    title: 'Search the scripts',
    description: 'Finds text in every script of a stack of the user\'s (the stack, its cards and controls, and its substacks), ' +
      'or of all their open stacks when none is named: each line found with its object, line number and the handler it is ' +
      'in, and where a handler of that name is defined. Case is ignored. Use it to find where a handler is defined or ' +
      'called, or a variable or property is used, rather than reading each object.',
    inputSchema: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'What to find: a handler\'s name, a word, a phrase' },
        stack: { type: 'string', description: 'The stack, by name, searched with its main stack and substacks; every stack of the user\'s open when none' },
        regex: { type: 'boolean', description: 'text is a regular expression (PCRE), matched against each line' }
      },
      required: ['text']
    },
    annotations: READ_ONLY
  },
  {
    name: 'look_at_card',
    title: 'Look at a card',
    description: 'Takes a picture of a card of the user\'s stack as it looks now, to see what you built or what the user ' +
      'asks about: where the controls are, whether they overlap or are cut off, whether their text fits. read_stack gives ' +
      'the names, ids and properties; this shows the card. With labels, each control is outlined with its id written on ' +
      'it, to match what you see with read_stack; with id, only that control is shown.',
    inputSchema: {
      type: 'object',
      properties: {
        stack: STACK,
        card: { type: 'integer', description: 'The id of the card, as the outline gives it; the card the stack shows when none' },
        id: { type: 'integer', description: 'Only this control, by its id' },
        labels: { type: 'boolean', description: 'Outline each control and write its id on it' }
      }
    },
    annotations: READ_ONLY
  },
  {
    name: 'lookup_dictionary',
    title: 'Look up the Dictionary',
    description: 'Looks up an entry of the OXT-Beyond Dictionary: a command, function, property, message, keyword, constant ' +
      'or control structure of xTalk Script (put, split, topStack, mouseUp, repeat...). Gives its syntax, parameters, ' +
      'description and examples, or the entries with the nearest names when there is none. Look up what you are not sure ' +
      'exists or how it is written, rather than guess.',
    inputSchema: {
      type: 'object',
      properties: { term: { type: 'string', description: 'The entry\'s name alone: topStack, not the topStack' } },
      required: ['term']
    },
    annotations: READ_ONLY
  },
  {
    name: 'check_code',
    title: 'Compile code',
    description: 'Compiles xTalk Script on OXT-Beyond\'s engine as the Script Editor does, without running it, and gives ' +
      'each problem with its line: compile errors, curly quotes, lines outside any handler, a handler defined twice and, ' +
      'in handlers, names never declared. Give whole handlers, or statements (checked inside a handler of their own).',
    inputSchema: {
      type: 'object',
      properties: { code: { type: 'string', description: 'The code, as it would be in a script' } },
      required: ['code']
    },
    annotations: READ_ONLY
  },
  {
    name: 'make_changes',
    title: 'Change a stack',
    description: 'Changes the user\'s stack as one batch: creates controls, cards or a new stack; sets properties, custom ' +
      'properties and scripts; deletes controls or cards. The batch is checked first, and a mistake (a property the engine ' +
      'does not have, with the nearest names, a value it refuses, a script that does not compile) comes back with nothing changed, to correct and ' +
      'send again. A batch is made whole or not at all, with messages locked (none of the user\'s handlers runs), and ' +
      'undo_changes takes it back. The result gives the ids of what was created. Read the stack first to know its cards, ' +
      'ids and scripts. Each change has an action: create (kind: button, default button, checkbox, radio button, option ' +
      'menu, pulldown menu, popup menu, combo box, tab panel, field, text area, label, list field, table field, rectangle, ' +
      'round rectangle, oval, line, polygon, regular polygon, curve, scrollbar, slider, progress bar, image, player, group, ' +
      'widget (give its widget_kind), card or stack; with name, rect, properties, custom_properties, script, and ref, a word ' +
      'the later changes of the batch can use for it as object, card or group); set (object, and properties, ' +
      'custom_properties or script); or delete (object: a control or a card). A new stack is the first change of its ' +
      'batch, and the rest of the batch is in it; a new card goes after the current card. A script replaces the object\'s ' +
      'whole script and is made of handlers; to change part of a script, above all a long one (read_stack shows 24,000 ' +
      'characters of a script), use edit_script. Properties are the engine\'s, by name; a list of numbers is one value ' +
      '([10, 20] is 10,20). Build a large stack over several batches.',
    inputSchema: {
      type: 'object',
      properties: {
        stack: { type: 'string', description: 'The stack or substack to change, by name; empty for the one the user is working on' },
        changes: {
          type: 'array',
          description: 'The changes, made in order',
          items: {
            type: 'object',
            properties: {
              action: { type: 'string', enum: ['create', 'set', 'delete'] },
              kind: { type: 'string', enum: KINDS, description: 'create: what to create' },
              name: { type: 'string', description: 'create: its name' },
              ref: { type: 'string', description: 'create: a word the later changes of this batch name it by' },
              card: { description: 'create: the card to put it on (an id, a ref or a card\'s name); the current card when none' },
              group: { description: 'create: the group to put it in (an id or a ref)' },
              rect: { type: 'array', items: { type: 'integer' }, description: 'create: left, top, right, bottom' },
              widget_kind: { type: 'string', description: 'create, a widget: its kind, such as com.livecode.widget.svgpath' },
              object: { description: 'set and delete: an id, a ref, or the word stack for the stack itself' },
              properties: { type: 'object', description: 'Properties of the engine\'s, by name' },
              custom_properties: { type: 'object', description: 'Custom properties, by name' },
              script: { type: 'string', description: 'The object\'s whole new script: handlers' }
            },
            required: ['action']
          }
        }
      },
      required: ['changes']
    },
    annotations: CHANGES
  },
  {
    name: 'edit_script',
    title: 'Edit a script',
    description: 'Changes part of the script of a stack, card or control of the user\'s, leaving the rest as it is: ' +
      'replaces one handler (handler, and code: that handler whole, from its first line to its end line), adds it when the ' +
      'script has none of that name, or deletes it (handler and delete: true); or replaces lines from_line to to_line ' +
      '(as read_script numbers them) with code, when they still read as old_text (an empty code, or delete: true, deletes ' +
      'them). The whole script is then checked and compiled, and set as make_changes sets one: a mistake comes back with ' +
      'nothing changed, and undo_changes takes it back. Line numbers move after an edit: read again before the next edit by lines.',
    inputSchema: {
      type: 'object',
      properties: {
        stack: STACK,
        id: { type: 'integer', description: 'The id of a card or control, as read_stack gives it; none for the stack\'s own script' },
        handler: { type: 'string', description: 'The handler to replace, add or delete, by name' },
        from_line: { type: 'integer', description: 'The first line to replace' },
        to_line: { type: 'integer', description: 'The last line to replace' },
        old_text: { type: 'string', description: 'With from_line and to_line: those lines as you read them, without their numbers' },
        code: { type: 'string', description: 'The new handler, or the new lines' },
        delete: { type: 'boolean', description: 'Delete the handler or the lines' }
      }
    },
    annotations: CHANGES
  },
  {
    name: 'run_code',
    title: 'Run code',
    description: 'Runs xTalk Script statements and gives back what they put into the Message Box (put with no container), ' +
      'what they returned, and any error with its line. Use it to try code, and to see what a stack does. Where: sandbox ' +
      '(the default), a hidden stack made for the run and deleted after it, where the code can call the handlers you give; ' +
      'or stack, the user\'s stack, as the Message Box runs code there (with the stack\'s own handlers, me being the card ' +
      'or control given by target, the current card when none), after a checkpoint undo_changes goes back to (on the ' +
      'stack, return gives nothing back: put the value instead; a run that changed nothing keeps no checkpoint). Every run is shown to the user in OXT-Beyond first, and ' +
      'runs only when they allow it: keep the code short and plain, so that they can read it. Do not use answer or ask: ' +
      'the run would wait for the user. A run ' +
      'that never ends is stopped only by the user (Control-period, Command-period on a Mac).',
    inputSchema: {
      type: 'object',
      properties: {
        code: { type: 'string', description: 'Statements, as typed into the Message Box' },
        where: { type: 'string', enum: ['sandbox', 'stack'] },
        handlers: { type: 'string', description: 'sandbox: whole handlers the code can call' },
        stack: { type: 'string', description: 'stack: the stack or substack, by name; empty for the one the user is working on' },
        target: { type: 'integer', description: 'stack: the id of the card or control that is me' }
      },
      required: ['code']
    },
    annotations: RUNS
  },
  {
    name: 'save_stack',
    title: 'Save a stack',
    description: 'Saves a stack of the user\'s to its file, with its substacks, as File > Save does, after the user says yes ' +
      'in OXT-Beyond, every time. A stack never saved (a new one you made) is saved where the user chooses. Save when the ' +
      'user asks you to, or offer to when you have built a new stack. Saving cannot be undone.',
    inputSchema: { type: 'object', properties: { stack: STACK } },
    annotations: CHANGES
  },
  {
    name: 'list_changes',
    title: 'List the changes',
    description: 'Lists what was changed or run on the user\'s stacks through these tools since the bridge was turned on, ' +
      'each with its number, and whether it was undone.',
    inputSchema: { type: 'object', properties: {} },
    annotations: READ_ONLY
  },
  {
    name: 'undo_changes',
    title: 'Undo changes',
    description: 'Undoes a change (by its number, from list_changes or the result of make_changes or run_code; the newest ' +
      'still applied when none), and every later one on the same stack, newest first: what was created is deleted, what ' +
      'was set gets its properties and script back, what was deleted comes back, and a run on the stack goes back to its ' +
      'checkpoint. When the user has changed those objects since, they are asked in OXT-Beyond first. Read the stack again after.',
    inputSchema: { type: 'object', properties: { entry: { type: 'integer', description: 'The number of the change' } } },
    annotations: CHANGES
  },
  {
    name: 'debug_state',
    title: 'Read the debugger',
    description: 'Reads where a script of the user\'s is paused in the debugger (at a breakpoint, or at an error with Script ' +
      'Debug Mode on): the line and handler, the handlers that led there, their variables with their values, and the ' +
      'script around the line. It only reads: stepping and going on are the user\'s, in the Script Editor.',
    inputSchema: { type: 'object', properties: {} },
    annotations: READ_ONLY
  }
];

const TOOL_NAMES = new Set(TOOLS.map((t) => t.name));

function log(message) {
  process.stderr.write('[oxt-beyond-mcp] ' + message + '\n');
}

function infoFilePath() {
  return process.env.OXT_MCP_BRIDGE_FILE || path.join(os.homedir(), '.oxt-beyond', 'mcp-bridge.json');
}

const NOT_RUNNING = 'OXT-Beyond is not running, or its xTalk MCP Bridge is off. Ask the user to open OXT-Beyond and choose ' +
  'Development > Plugins > xTalk MCP Bridge, then Turn On; then try again.';

const STALE = 'OXT-Beyond is not running: the bridge\'s file was left by an OXT-Beyond that has quit or crashed. Ask the user ' +
  'to open OXT-Beyond (the bridge starts with it when it was on) or turn the bridge on in Development > Plugins > ' +
  'xTalk MCP Bridge; then try again.';

const BUSY = 'OXT-Beyond is still busy with an earlier request: it may be waiting for the user to answer a question there, ' +
  'or running code. Ask the user to look at OXT-Beyond, then try again.';

class BridgeError extends Error {}

// True when a process with this id runs (one the user may not signal still
// runs: EPERM)
function processRuns(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return e.code === 'EPERM';
  }
}

// The connection to OXT-Beyond, made when a call needs it and made again
// after it closes (the user may turn the bridge off and on, which changes
// the port and the token)
class Bridge {
  constructor() {
    this.socket = null;
    this.token = null;
    this.buffer = '';
    this.pending = null;   // { id, resolve, reject, timer }
    this.nextId = 1;
    this.queue = Promise.resolve();
    this.waiting = 0;      // calls queued or running
    this.toolsNote = '';   // said once after connecting, when the tools differ
  }

  readInfo() {
    let text;
    try {
      text = fs.readFileSync(infoFilePath(), 'utf8');
    } catch (e) {
      log('no bridge file: ' + e.message);
      throw new BridgeError(NOT_RUNNING);
    }
    let info;
    try {
      info = JSON.parse(text);
    } catch (e) {
      throw new BridgeError('The bridge\'s file ' + infoFilePath() + ' cannot be read. Ask the user to turn the bridge off and on again in OXT-Beyond.');
    }
    if (info.protocol !== BRIDGE_PROTOCOL) {
      throw new BridgeError('This OXT-Beyond speaks bridge protocol ' + info.protocol + ', and this MCP server speaks ' +
        BRIDGE_PROTOCOL + '. Ask the user to update the MCP server from OXT-Beyond (xTalk MCP Bridge > Claude Setup).');
    }
    if (!Number.isInteger(info.port) || typeof info.token !== 'string') {
      throw new BridgeError('The bridge\'s file ' + infoFilePath() + ' has no port or token.');
    }
    // The IDE that wrote it has gone (an older OXT-Beyond writes no pid)
    if (Number.isInteger(info.pid) && info.pid > 0 && !processRuns(info.pid)) {
      log('the bridge file names process ' + info.pid + ', which is not running');
      throw new BridgeError(STALE);
    }
    return info;
  }

  connect() {
    const info = this.readInfo();
    return new Promise((resolve, reject) => {
      const socket = net.createConnection({ host: '127.0.0.1', port: info.port });
      const timer = setTimeout(() => {
        socket.destroy();
        reject(new BridgeError(NOT_RUNNING));
      }, CONNECT_TIMEOUT_MS);
      socket.setEncoding('utf8');
      socket.once('connect', () => {
        clearTimeout(timer);
        this.socket = socket;
        this.token = info.token;
        this.buffer = '';
        socket.on('data', (chunk) => this.onData(chunk));
        socket.on('close', () => this.onClose());
        socket.on('error', (e) => log('socket: ' + e.message));
        resolve();
      });
      socket.once('error', (e) => {
        clearTimeout(timer);
        log('could not connect to 127.0.0.1:' + info.port + ': ' + e.message);
        reject(new BridgeError(NOT_RUNNING));
      });
    });
  }

  onData(chunk) {
    this.buffer += chunk;
    let at;
    while ((at = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, at);
      this.buffer = this.buffer.slice(at + 1);
      if (line.trim() === '') {
        continue;
      }
      let reply;
      try {
        reply = JSON.parse(line);
      } catch (e) {
        log('an answer that is not JSON: ' + line.slice(0, 200));
        continue;
      }
      const pending = this.pending;
      if (pending && reply.id === pending.id) {
        this.pending = null;
        clearTimeout(pending.timer);
        pending.resolve(reply);
      }
    }
  }

  onClose() {
    this.socket = null;
    this.token = null;
    const pending = this.pending;
    this.pending = null;
    if (pending) {
      clearTimeout(pending.timer);
      pending.reject(new BridgeError('OXT-Beyond closed the connection before it answered (the bridge was turned off, ' +
        'or the IDE quit). What was asked may or may not have been done: read the stack again before going on.'));
    }
  }

  async send(request) {
    if (!this.socket) {
      await this.connect();
      const hello = await this.exchange({ method: 'hello' }, HELLO_TIMEOUT_MS,
        'OXT-Beyond did not answer within ' + Math.round(HELLO_TIMEOUT_MS / 1000) + ' seconds of connecting. It may be ' +
        'busy (waiting for the user to answer a question there, or running code); ask the user to look at OXT-Beyond, then try again.');
      if (!hello.ok) {
        this.close();
        throw new BridgeError(hello.error || NOT_RUNNING);
      }
      if (hello.protocol !== BRIDGE_PROTOCOL) {
        this.close();
        throw new BridgeError('OXT-Beyond speaks bridge protocol ' + hello.protocol + ', and this MCP server ' + BRIDGE_PROTOCOL + '.');
      }
      this.toolsNote = toolsDifference(hello.tools);
    }
    return this.exchange(request, CALL_TIMEOUT_MS);
  }

  exchange(request, timeoutMs, timeoutText) {
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timer = setTimeout(() => {
        if (this.pending && this.pending.id === id) {
          this.pending = null;
          reject(new BridgeError(timeoutText || ('OXT-Beyond did not answer in ' + Math.round(timeoutMs / 1000) + ' seconds. ' +
            'It may be waiting for the user, or running code that does not end (Control-period stops it). A question it was ' +
            'asking the user does nothing now, even if they answer it; code that was running may still finish: check ' +
            'list_changes before sending it again.')));
          this.close();
        }
      }, timeoutMs);
      // The connection can close between the hello and the call (onClose
      // empties it): say so, not "Cannot read properties of null"
      if (!this.socket) {
        clearTimeout(timer);
        reject(new BridgeError(NOT_RUNNING));
        return;
      }
      this.pending = { id, resolve, reject, timer };
      this.socket.write(JSON.stringify(Object.assign({ id, token: this.token }, request)) + '\n');
    });
  }

  close() {
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }
  }

  // One call at a time, in the order they came. A call that waits more
  // than BUSY_WAIT_MS for an earlier one is told that OXT-Beyond is busy,
  // and is not sent later; a call cancelled by the client before its turn
  // is not sent at all (one already sent cannot be taken back).
  call(tool, args, state) {
    const ticket = state || {};
    const run = () => {
      if (ticket.abandoned || ticket.cancelled) {
        return Promise.reject(new BridgeError(ticket.cancelled ? 'Cancelled.' : BUSY));
      }
      ticket.started = true;
      return this.send({ method: 'call', tool, arguments: args || {} });
    };
    const busy = this.waiting > 0;
    this.waiting++;
    const result = this.queue.then(run, run);
    const settled = result.catch(() => {}).then(() => { this.waiting--; });
    this.queue = settled;
    if (!busy) {
      return result;
    }
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!ticket.started) {
          ticket.abandoned = true;
          reject(new BridgeError(BUSY));
        }
      }, BUSY_WAIT_MS);
      result.then((r) => { clearTimeout(timer); resolve(r); }, (e) => { clearTimeout(timer); reject(e); });
    });
  }

  // The note about the tools, once
  takeToolsNote() {
    const note = this.toolsNote;
    this.toolsNote = '';
    return note;
  }
}

// What differs between the tools OXT-Beyond has (its answer to hello: a
// comma list) and those listed here: the .mcpb holds a copy of this file
// taken when it was saved, and OXT-Beyond may have been updated since
function toolsDifference(ideTools) {
  if (typeof ideTools !== 'string' || ideTools === '') {
    return '';
  }
  const ide = new Set(ideTools.split(',').map((t) => t.trim()).filter(Boolean));
  const missingHere = [...ide].filter((t) => !TOOL_NAMES.has(t));
  const missingThere = [...TOOL_NAMES].filter((t) => !ide.has(t));
  if (missingHere.length === 0 && missingThere.length === 0) {
    return '';
  }
  log('tools differ: OXT-Beyond has ' + [...ide].join(',') + '; this server ' + [...TOOL_NAMES].join(','));
  let note = 'Note: this MCP server and OXT-Beyond are different versions';
  if (missingHere.length) {
    note += ' (OXT-Beyond also has ' + missingHere.join(', ') + ', which this server does not offer)';
  }
  if (missingThere.length) {
    note += ' (' + missingThere.join(', ') + ' will fail: OXT-Beyond does not have them)';
  }
  return note + '. Tell the user to set Claude up again from OXT-Beyond: Development > Plugins > xTalk MCP Bridge > Claude Setup.';
}

const bridge = new Bridge();
// The state of each tools/call not yet answered, by its request id
const inFlight = new Map();

function textResult(text, isError) {
  return { content: [{ type: 'text', text }], isError: !!isError };
}

async function callTool(params, state) {
  const name = params && params.name;
  if (!TOOL_NAMES.has(name)) {
    return textResult('There is no tool named "' + name + '".', true);
  }
  const args = params.arguments && typeof params.arguments === 'object' ? params.arguments : {};
  let reply;
  try {
    reply = await bridge.call(name, args, state);
  } catch (e) {
    if (e instanceof BridgeError) {
      return textResult(e.message, true);
    }
    throw e;
  }
  if (!reply.ok) {
    return textResult(reply.error || 'OXT-Beyond refused the request.', true);
  }
  const note = bridge.takeToolsNote();
  const content = [{ type: 'text', text: (reply.text || '') + (note ? '\n\n' + note : '') }];
  if (reply.image) {
    content.push({ type: 'image', data: reply.image, mimeType: reply.imageType || 'image/png' });
  }
  return { content, isError: !!reply.isError };
}

function respond(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result }) + '\n');
}

function respondError(id, code, message) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, error: { code, message } }) + '\n');
}

async function handle(message) {
  if (!message || typeof message !== 'object' || Array.isArray(message)) {
    respondError(null, -32600, 'Invalid request');
    return;
  }
  const { id, method, params } = message;
  const isRequest = id !== undefined && id !== null;
  if (!isRequest) {
    // A cancelled call is not sent if it has not been yet, and gets no
    // answer; other notifications (initialized...) need nothing
    if (method === 'notifications/cancelled' && params && inFlight.has(params.requestId)) {
      inFlight.get(params.requestId).cancelled = true;
    }
    return;
  }
  switch (method) {
    case 'initialize': {
      const asked = params && params.protocolVersion;
      respond(id, {
        protocolVersion: MCP_VERSIONS.includes(asked) ? asked : MCP_VERSIONS[0],
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: 'oxt-beyond', title: 'OXT-Beyond', version: SERVER_VERSION },
        instructions: INSTRUCTIONS
      });
      return;
    }
    case 'ping':
      respond(id, {});
      return;
    case 'tools/list':
      respond(id, { tools: TOOLS });
      return;
    case 'tools/call': {
      const state = { cancelled: false };
      inFlight.set(id, state);
      let result;
      let failure;
      try {
        result = await callTool(params, state);
      } catch (e) {
        failure = e;
      }
      inFlight.delete(id);
      if (state.cancelled) {
        return;
      }
      if (failure) {
        respondError(id, -32603, 'Internal error: ' + failure.message);
      } else {
        respond(id, result);
      }
      return;
    }
    default:
      respondError(id, -32601, 'Method not found: ' + method);
  }
}

function main() {
  const input = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
  input.on('line', (line) => {
    if (line.trim() === '') {
      return;
    }
    let message;
    try {
      message = JSON.parse(line);
    } catch (e) {
      respondError(null, -32700, 'Parse error');
      return;
    }
    handle(message).catch((e) => log('error: ' + e.stack));
  });
  input.on('close', () => {
    bridge.close();
    process.exit(0);
  });
}

if (require.main === module) {
  main();
}

module.exports = { TOOLS, MCP_VERSIONS, BRIDGE_PROTOCOL };
