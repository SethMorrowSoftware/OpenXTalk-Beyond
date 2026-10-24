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
//
// The web IDE. OXT-Beyond's IDE also runs in a browser tab (tools/web-ide),
// where nothing can listen for a connection and no file is shared with
// other programs. Started with --web (or OXT_MCP_WEB=1), this server turns
// it around once more: it listens on 127.0.0.1 itself, on OXT_MCP_WEB_PORT
// (47861 unless set), for a WebSocket from the tab, which connects when
// the user chooses Connect in the web IDE's xTalk MCP Bridge item. The
// lines are the same as over the desktop socket, without a token. Instead
// the two ends prove to each other, when the tab connects, that they hold
// the same key, OXT_MCP_WEB_KEY, which the web IDE made and put into the
// setup it gave (its desktop extension, or its Claude Code command): the
// page sends a fresh nonce, this answers with its own and an HMAC of both,
// the page answers with its HMAC, and this says it took the page
// (WebLink.upgrade, mcp/web-link.js).
// The page will not take requests from a program that took the port
// first, and this will not send Claude's to one that is not the page. Only
// a page from an origin this allows (the hosted web IDE, OXT-Beyond's own
// pages on localhost, and those in OXT_MCP_WEB_ORIGINS, a comma list) can
// connect at all, since a browser always sends a page's true origin.
// One Claude app can start this server more than once (Claude's desktop
// app starts one for its own chats and another for its Cowork and Code
// sessions), and only one can listen on the port. The one that finds the
// port taken sends its calls to the one listening, over HTTP on the same
// port (WebLink.relay, relayRequest): it first asks that one to prove it
// holds the key, so nothing goes to a program that took the port, then
// sends each call with its own proof, and takes the answer only with that
// one's proof of it. It tries the port again whenever the other is gone.
// Without --web, none of this runs, and the server does exactly what it
// does for the desktop IDE.

'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
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
// While a call takes long, how often OXT-Beyond is asked what it waits for
// (its status, over a connection of its own), to tell the client that
// asked for progress; and how long it may take to answer that
const STATUS_INTERVAL_MS = Number(process.env.OXT_MCP_STATUS_INTERVAL_MS) || 15000;
const STATUS_TIMEOUT_MS = 3000;
// For the web IDE (see the top of this file): whether this server is for
// it, the port it listens on for the tab, the key the two ends share, the
// origins it lets connect, the largest message it reads from the tab (a
// picture of a card, or a long script, is a few megabytes at most), and
// how long a tab has to prove it holds the key
const WEB = process.argv.includes('--web') || process.env.OXT_MCP_WEB === '1';
const WEB_PORT = Number(process.env.OXT_MCP_WEB_PORT) || 47861;
const WEB_KEY = String(process.env.OXT_MCP_WEB_KEY || '');
const WEB_ORIGINS = ['https://sethmorrow.com'].concat((process.env.OXT_MCP_WEB_ORIGINS || '').split(',')
  .map((o) => o.trim().replace(/\/+$/, '')).filter(Boolean));
const WEB_MAX_MESSAGE = 64 * 1024 * 1024;
const WEB_PROOF_TIMEOUT_MS = 10000;
// How far a relayed call's time may be from this computer's clock, and the
// largest call a server relays (its arguments: a script, a batch of changes)
const RELAY_WINDOW_MS = 60000;
const RELAY_MAX_REQUEST = 16 * 1024 * 1024;

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
  'are not sure of with lookup_dictionary rather than guess.',
  'When a call waits or is refused as busy, its text says what OXT-Beyond waits for: the user\'s answer to its question',
  '(ask them to look for that window), a script paused in the debugger (stop_paused_script), or a dialog a stack opened',
  '(answer_dialog). import_hypercard imports a HyperCard stack, or one from a Mac disk image, without running its scripts.'
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
  },
  {
    name: 'stop_paused_script',
    title: 'Stop the paused script',
    description: 'Stops the script of the user\'s that is paused in the debugger, as Stop in the Script Editor does: the rest ' +
      'of that handler, and of those that called it, does not run (what it did already stays done). While a script is ' +
      'paused, code run in OXT-Beyond waits for it; ide_context, debug_state and a call refused as busy say where it is ' +
      'paused. Read debug_state first when the user wants the error fixed, then stop it. It answers even while another ' +
      'call waits.',
    inputSchema: { type: 'object', properties: {} },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  {
    name: 'answer_dialog',
    title: 'Answer a dialog',
    description: 'Presses a button of the dialog in front in OXT-Beyond, when a script of the user\'s opened it (answer, ask, ' +
      'or a modal stack of theirs): the script that opened it waits until it is answered, and so does every other call. ' +
      'ide_context, and a call refused as busy, give the dialog\'s text and buttons. With text, it is typed into the ' +
      'dialog\'s field first (an ask dialog). Never OXT-Beyond\'s own question before a run, a save or an undo, nor a dialog ' +
      'of the IDE\'s: those are the user\'s to answer. Answer only as the user asked you to. It answers even while another call waits.',
    inputSchema: {
      type: 'object',
      properties: {
        button: { type: 'string', description: 'The button to press, by its label, as ide_context gives it' },
        text: { type: 'string', description: 'What to type into the dialog\'s field before (an ask dialog)' }
      },
      required: ['button']
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  {
    name: 'import_hypercard',
    title: 'Import a HyperCard stack',
    description: 'Imports a HyperCard stack into OXT-Beyond as File > Import Stack > HyperCard Stack does, with messages ' +
      'locked, so that none of its scripts runs (old stacks often carry a HyperTalk virus): from its file (a HyperCard ' +
      'stack, or a MacBinary or BinHex copy), or from a Mac disk image (a floppy or CD image with an HFS volume) with ' +
      'stack_path. With list, it lists the stacks on a disk image instead. Gives the import\'s summary: what came in, what ' +
      'was converted and what is missing. The stack is open afterwards, and not saved (save_stack saves it where the user ' +
      'chooses).',
    inputSchema: {
      type: 'object',
      properties: {
        file: { type: 'string', description: 'The path of the stack or the disk image, on this computer' },
        stack_path: { type: 'string', description: 'For a disk image: the stack\'s path on it, as list gives it (Volume:Folder:Stack)' },
        list: { type: 'boolean', description: 'For a disk image: list its stacks, and import nothing' }
      },
      required: ['file']
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false }
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

const WEB_NOT_CONNECTED = 'The OXT-Beyond web IDE is not connected. Ask the user to open the web IDE in their browser, ' +
  'on this computer, and choose Development > Plugins > xTalk MCP Bridge, then Connect; then try again.';

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
    this.notRunning = NOT_RUNNING;   // what a call is told when nothing answers
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
        throw new BridgeError(hello.error || this.notRunning);
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
          const text = timeoutText || ('OXT-Beyond did not answer in ' + Math.round(timeoutMs / 1000) + ' seconds. ' +
            'It may be waiting for the user, or running code that does not end (Control-period stops it). A question it was ' +
            'asking the user does nothing now, even if they answer it; code that was running may still finish: check ' +
            'list_changes before sending it again.');
          // What it waits for is asked before this connection closes: a
          // question still open then is one the user has not answered
          this.withStatus(text).then((e) => {
            reject(e);
            this.close();
          });
        }
      }, timeoutMs);
      // The connection can close between the hello and the call (onClose
      // empties it): say so, not "Cannot read properties of null"
      if (!this.socket) {
        clearTimeout(timer);
        reject(new BridgeError(this.notRunning));
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
      return this.dispatch(tool, args, ticket);
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
          this.withStatus(BUSY).then(reject);
        }
      }, BUSY_WAIT_MS);
      result.then((r) => { clearTimeout(timer); resolve(r); }, (e) => { clearTimeout(timer); reject(e); });
    });
  }

  // Where a call goes once its turn comes: to OXT-Beyond
  dispatch(tool, args) {
    return this.send({ method: 'call', tool, arguments: args || {} });
  }

  // What OXT-Beyond says it is doing and what holds it up (its status:
  // the user's answer to its question, a script paused in the debugger, a
  // dialog), asked over a connection of its own, since the one calls go on
  // is waiting for an answer. Resolves with the text, or '' when there is
  // none to give (an OXT-Beyond that has no status, or none running).
  status() {
    let info;
    try {
      info = this.readInfo();
    } catch (e) {
      return Promise.resolve('');
    }
    return new Promise((resolve) => {
      const socket = net.createConnection({ host: '127.0.0.1', port: info.port });
      let buffer = '';
      let done = false;
      const finish = (text) => {
        if (!done) {
          done = true;
          clearTimeout(timer);
          socket.destroy();
          resolve(text);
        }
      };
      const timer = setTimeout(() => finish(''), STATUS_TIMEOUT_MS);
      socket.setEncoding('utf8');
      socket.on('connect', () => socket.write(JSON.stringify({ id: 1, token: info.token, method: 'status' }) + '\n'));
      socket.on('data', (chunk) => {
        buffer += chunk;
        const at = buffer.indexOf('\n');
        if (at < 0) {
          return;
        }
        let reply = null;
        try {
          reply = JSON.parse(buffer.slice(0, at));
        } catch (e) {
          // not an answer
        }
        finish(reply && reply.ok && typeof reply.text === 'string' ? reply.text : '');
      });
      socket.on('error', () => finish(''));
    });
  }

  // A refusal or a timeout with what OXT-Beyond says it waits for after it
  withStatus(text) {
    return this.status().then((status) => new BridgeError(status ? text + '\n\n' + status : text));
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

function hmac(key, text) {
  return crypto.createHmac('sha256', key).update(text).digest('hex');
}

// Whether two proofs are the same, in a time that does not tell how much
// of them is
function sameText(given, expected) {
  const a = Buffer.from(given, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// An HTTP request to the server listening on this port of this computer:
// resolves with the parsed JSON of a 200 answer, rejects with the error
// (its code ECONNREFUSED when nothing listens there now)
function relayRequest(port, method, path, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? null : Buffer.from(JSON.stringify(body), 'utf8');
    const req = http.request({ host: '127.0.0.1', port, method, path,
      headers: data ? { 'Content-Type': 'application/json', 'Content-Length': data.length } : {} }, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error('it answered ' + res.statusCode));
          return;
        }
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch (e) {
          reject(new Error('its answer is not JSON'));
        }
      });
    });
    req.setTimeout(timeoutMs, () => req.destroy(new Error('it did not answer in time')));
    req.on('error', reject);
    if (data) {
      req.write(data);
    }
    req.end();
  });
}

// The web IDE's tab, over a WebSocket (RFC 6455, text messages only), for
// a server started with --web. It keeps the one tab connected (the newest:
// a reload, or the IDE opened again, takes over) and hands its messages to
// the bridge (WebBridge).
class WebLink {
  constructor(port, origins, key) {
    this.port = port;
    this.origins = origins;
    this.key = key;
    this.tab = null;        // the tab's socket
    this.problem = '';      // why it is not listening, when it is not
    this.taken = false;     // another server listens on the port: calls go to it
    this.onMessage = () => {};
    this.onClose = () => {};
    this.onRelay = () => Promise.reject(new BridgeError(WEB_NOT_CONNECTED));
    this.relayNonces = new Map();   // nonce -> when, of relayed calls taken
    this.relayTickets = new Map();  // nonce -> ticket, of relayed calls not answered yet
  }

  // Pages the link lets connect: the hosted web IDE, the origins given,
  // and pages on this computer (python serve.py, the downloadable web IDE)
  allows(origin) {
    if (this.origins.includes(origin)) {
      return true;
    }
    return /^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(origin);
  }

  // The proof of holding the key for one side ('server' or 'page') of the
  // connection made with these two nonces (mcp/web-link.js makes the same)
  proof(side, pageNonce, serverNonce) {
    return crypto.createHmac('sha256', this.key).update(side + '\n' + pageNonce + '\n' + serverNonce).digest('hex');
  }

  listen() {
    if (this.key.length < 32) {
      this.problem = 'This MCP server has no key for the web IDE (OXT_MCP_WEB_KEY), so the web IDE cannot connect. ' +
        'Ask the user to set Claude up again from the web IDE: Development > Plugins > xTalk MCP Bridge > Claude Setup..., ' +
        'and to use the extension or the command it gives now.';
      log(this.problem);
      return;
    }
    const server = http.createServer((req, res) => {
      if (String(req.url || '').startsWith('/relay')) {
        this.relay(req, res);
        return;
      }
      res.writeHead(426, { 'Content-Type': 'text/plain' });
      res.end('The OXT-Beyond MCP server: the web IDE connects here with a WebSocket.\n');
    });
    server.on('upgrade', (req, socket) => this.upgrade(req, socket));
    server.on('listening', () => {
      this.problem = '';
      this.taken = false;
    });
    server.on('error', (e) => {
      this.taken = e.code === 'EADDRINUSE';
      this.problem = e.code === 'EADDRINUSE'
        ? 'Port ' + this.port + ' of this computer is taken by a program that is not this MCP server set up for the same web IDE ' +
          '(another Claude app set up from another browser, or another program). Ask the user to quit it. (A different port is the ' +
          'web IDE\'s cMcpBridge,webPort preference, then Claude Setup... there again, which gives it to this server too.)'
        : 'This MCP server could not listen for the web IDE on port ' + this.port + ': ' + e.message;
      log(this.problem);
    });
    server.listen(this.port, '127.0.0.1', () => log('waiting for the web IDE on ws://127.0.0.1:' + this.port));
  }

  // A call another server of this computer relays (see the top of this
  // file): GET /relay-hello?n=<nonce> answers with this server's proof of
  // holding the key; POST /relay takes {request, proof}, where request is
  // the JSON text of {nonce, time, tool, arguments} and proof its HMAC,
  // and answers {response, proof}, response being the JSON text of
  // {reply, note} or {error} and proof its HMAC with the call's nonce
  // (note: the tools note, which the follower's client is the one to be
  // told). POST /relay-cancel takes {request, proof} the same way, request
  // being the JSON text of {nonce, time} of a call relayed before: the
  // client cancelled it, so if it still waits its turn here it is not
  // sent, as a call cancelled on this server is not. A browser page
  // always sends an Origin, so a request with one is refused.
  relay(req, res) {
    const answer = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(body));
    };
    const host = String(req.headers.host || '');
    if (req.headers.origin !== undefined || !/^(127\.0\.0\.1|localhost):\d+$/.test(host) || this.key.length < 32) {
      log('refused a relayed call from ' + (req.headers.origin || host || 'an unknown program'));
      answer(403, { error: 'refused' });
      return;
    }
    const url = new URL(req.url, 'http://127.0.0.1');
    if (req.method === 'GET' && url.pathname === '/relay-hello') {
      const nonce = url.searchParams.get('n') || '';
      if (!/^[0-9a-f]{64}$/.test(nonce)) {
        answer(400, { error: 'no nonce' });
        return;
      }
      answer(200, { proof: hmac(this.key, 'relay-hello\n' + nonce) });
      return;
    }
    if (req.method !== 'POST' || (url.pathname !== '/relay' && url.pathname !== '/relay-cancel')) {
      answer(404, { error: 'not found' });
      return;
    }
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > RELAY_MAX_REQUEST) {
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      let body = null;
      let request = null;
      try {
        body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        request = JSON.parse(String(body.request));
      } catch (e) {
        answer(400, { error: 'not JSON' });
        return;
      }
      // Written so a time that is not a number is outside the window:
      // Math.abs(NaN) > RELAY_WINDOW_MS is false
      if (url.pathname === '/relay-cancel') {
        if (!sameText(String(body.proof || ''), hmac(this.key, 'relay-cancel\n' + body.request)) ||
            !(Math.abs(Date.now() - Number(request.time)) <= RELAY_WINDOW_MS)) {
          log('refused to cancel a relayed call: the request does not hold this server\'s key');
          answer(403, { error: 'refused' });
          return;
        }
        const ticket = this.relayTickets.get(String(request.nonce));
        if (ticket) {
          ticket.cancelled = true;
        }
        answer(200, { cancelled: !!ticket });
        return;
      }
      if (!sameText(String(body.proof || ''), hmac(this.key, 'relay\n' + body.request)) ||
          !/^[0-9a-f]{64}$/.test(String(request.nonce)) || typeof request.tool !== 'string' ||
          !(Math.abs(Date.now() - Number(request.time)) <= RELAY_WINDOW_MS) || this.relayNonces.has(request.nonce)) {
        log('refused a relayed call: it does not hold this server\'s key, or was sent before');
        answer(403, { error: 'refused' });
        return;
      }
      const now = Date.now();
      for (const [nonce, when] of this.relayNonces) {
        if (now - when > 2 * RELAY_WINDOW_MS) {
          this.relayNonces.delete(nonce);
        }
      }
      this.relayNonces.set(request.nonce, now);
      const ticket = {};
      this.relayTickets.set(request.nonce, ticket);
      const respond = (result) => {
        this.relayTickets.delete(request.nonce);
        const response = JSON.stringify(result);
        answer(200, { response, proof: hmac(this.key, 'relayed\n' + request.nonce + '\n' + response) });
      };
      this.onRelay(request.tool, request.arguments || {}, ticket).then((done) => respond({ reply: done.reply, note: done.note }),
        (e) => respond({ error: e instanceof BridgeError ? e.message : 'The server the call was relayed to failed: ' + e.message }));
    });
  }

  upgrade(req, socket) {
    const origin = String(req.headers.origin || '');
    const key = req.headers['sec-websocket-key'];
    const upgrade = String(req.headers.upgrade || '').toLowerCase();
    const nonce = new URL(req.url || '/', 'http://127.0.0.1').searchParams.get('n') || '';
    if (!this.allows(origin) || !key || upgrade !== 'websocket' || !/^[0-9a-f]{32,128}$/.test(nonce)) {
      log('refused a connection from ' + (origin || 'a program that is not a web page'));
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');
      return;
    }
    const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
    socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
      'Sec-WebSocket-Accept: ' + accept + '\r\n\r\n');
    socket.setNoDelay(true);
    // The tab is the page only once it proves it holds the key: until then
    // its first message is that proof, and it neither takes over from the
    // tab connected now nor hears a request
    const serverNonce = crypto.randomBytes(32).toString('hex');
    const expected = this.proof('page', nonce, serverNonce);
    let proven = false;
    const timer = setTimeout(() => {
      log('a connection did not prove it is the web IDE in time; it is closed');
      this.drop(socket);
    }, WEB_PROOF_TIMEOUT_MS);
    this.frame(socket, 0x1, Buffer.from(JSON.stringify({
      oxtMcpWeb: 1, nonce: serverNonce, proof: this.proof('server', nonce, serverNonce)
    }), 'utf8'));
    const prove = (text) => {
      let message = null;
      try {
        message = JSON.parse(text);
      } catch (e) {
        // not a proof
      }
      const given = Buffer.from(String((message && message.proof) || ''), 'utf8');
      if (given.length !== expected.length || !crypto.timingSafeEqual(given, Buffer.from(expected, 'utf8'))) {
        log('refused a connection from ' + origin + ': it does not hold this server\'s key (set Claude up again from the web IDE)');
        this.drop(socket);
        return;
      }
      proven = true;
      clearTimeout(timer);
      // Said before the tab is taken: a request can only come after it
      this.frame(socket, 0x1, Buffer.from(JSON.stringify({ oxtMcpWeb: 1, connected: true }), 'utf8'));
      if (this.tab) {
        log('a newer web IDE tab takes over');
        const older = this.tab;
        this.tab = null;
        this.onClose();
        this.drop(older);
      }
      this.tab = socket;
      log('the web IDE connected from ' + origin);
    };
    let buffer = Buffer.alloc(0);
    let parts = [];
    let size = 0;
    socket.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      for (;;) {
        if (buffer.length < 2) {
          return;
        }
        const fin = (buffer[0] & 0x80) !== 0;
        const opcode = buffer[0] & 0x0f;
        const masked = (buffer[1] & 0x80) !== 0;
        let length = buffer[1] & 0x7f;
        let at = 2;
        if (length === 126) {
          if (buffer.length < 4) {
            return;
          }
          length = buffer.readUInt16BE(2);
          at = 4;
        } else if (length === 127) {
          if (buffer.length < 10) {
            return;
          }
          length = Number(buffer.readBigUInt64BE(2));
          at = 10;
        }
        // A browser masks every frame it sends; one too long to read is
        // not one of the IDE's
        if (!masked || size + length > WEB_MAX_MESSAGE) {
          log('the web IDE sent a frame this does not read; the connection is closed');
          this.drop(socket);
          return;
        }
        if (buffer.length < at + 4 + length) {
          return;
        }
        const mask = buffer.subarray(at, at + 4);
        const data = Buffer.from(buffer.subarray(at + 4, at + 4 + length));
        for (let i = 0; i < data.length; i++) {
          data[i] ^= mask[i & 3];
        }
        buffer = buffer.subarray(at + 4 + length);
        if (opcode === 0x8) {
          this.drop(socket);
          return;
        }
        if (opcode === 0x9) {
          this.frame(socket, 0xA, data);
        } else if (opcode === 0x1 || opcode === 0x0) {
          parts.push(data);
          size += data.length;
          if (fin) {
            const text = Buffer.concat(parts).toString('utf8');
            parts = [];
            size = 0;
            if (!proven) {
              prove(text);
            } else if (socket === this.tab) {
              this.onMessage(text);
            }
          }
        }
      }
    });
    const closed = () => {
      clearTimeout(timer);
      if (socket === this.tab) {
        this.tab = null;
        log('the web IDE disconnected');
        this.onClose();
      }
    };
    socket.on('end', () => {
      closed();
      socket.destroy();
    });
    socket.on('close', closed);
    socket.on('error', (e) => log('web IDE socket: ' + e.message));
  }

  frame(socket, opcode, data) {
    const length = data.length;
    let head;
    if (length < 126) {
      head = Buffer.from([0x80 | opcode, length]);
    } else if (length < 65536) {
      head = Buffer.from([0x80 | opcode, 126, length >> 8, length & 0xff]);
    } else {
      head = Buffer.alloc(10);
      head[0] = 0x80 | opcode;
      head[1] = 127;
      head.writeBigUInt64BE(BigInt(length), 2);
    }
    socket.write(Buffer.concat([head, data]));
  }

  send(text) {
    if (this.tab) {
      this.frame(this.tab, 0x1, Buffer.from(text, 'utf8'));
    }
  }

  // Closes a tab's connection; a closed socket's 'close' tells the bridge
  drop(socket) {
    try {
      this.frame(socket, 0x8, Buffer.alloc(0));
    } catch (e) {
      // already closed
    }
    socket.destroy();
  }
}

// The bridge to the web IDE: the desktop's Bridge, with the tab's
// WebSocket in place of the TCP socket and no file or token
class WebBridge extends Bridge {
  constructor(link) {
    super();
    this.link = link;
    this.notRunning = WEB_NOT_CONNECTED;
    link.onMessage = (text) => {
      if (this.socket) {
        this.onData(text.replace(/\n+$/, '') + '\n');
      }
    };
    link.onClose = () => {
      if (this.socket) {
        this.onClose();
      }
    };
    // A relayed call waits its turn here like this server's own, and the
    // tools note goes with its answer, to the client that asked
    link.onRelay = (tool, args, ticket) => this.call(tool, args, ticket)
      .then((reply) => ({ reply, note: reply && reply.ok ? this.takeToolsNote() : '' }));
  }

  // A call whose turn has come goes to the tab, or, while another server
  // holds the port, to that server (see the top of this file). It waits
  // its turn here first either way, so one the client cancels before then
  // is not sent at all.
  dispatch(tool, args, ticket) {
    if (!this.link.taken) {
      return super.dispatch(tool, args, ticket);
    }
    return this.relay(tool, args, ticket);
  }

  async relay(tool, args, ticket) {
    const port = this.link.port;
    const key = this.link.key;
    const timeout = CALL_TIMEOUT_MS + BUSY_WAIT_MS + 5000;
    const retry = (e) => {
      // Nothing listens there now: this server takes the port, and the
      // tab connects to it the next time it tries
      if (e.code === 'ECONNREFUSED' || e.code === 'ECONNRESET') {
        // Not taken from now on, not only once it listens: until then a
        // call queued behind this one was relayed to this server's own
        // port, waited behind itself and failed as busy (and the port's
        // old problem answered the calls after it). Only the first call
        // to find the port free listens; the error handler marks it
        // taken again if another program got there first.
        if (this.link.taken) {
          log('the server that held port ' + port + ' is gone; this one listens there now');
          this.link.taken = false;
          this.link.problem = '';
          this.link.listen();
        }
        throw new BridgeError(WEB_NOT_CONNECTED);
      }
      throw new BridgeError(this.link.problem + ' (A call to it failed: ' + e.message + '.)');
    };
    const hello = crypto.randomBytes(32).toString('hex');
    const proven = await relayRequest(port, 'GET', '/relay-hello?n=' + hello, undefined, CONNECT_TIMEOUT_MS).catch(retry);
    if (!sameText(String(proven.proof || ''), hmac(key, 'relay-hello\n' + hello))) {
      log('what listens on port ' + port + ' does not hold the key; nothing was sent to it');
      throw new BridgeError(this.link.problem);
    }
    const nonce = crypto.randomBytes(32).toString('hex');
    if (ticket && ticket.cancelled) {
      throw new BridgeError('Cancelled.');
    }
    // Cancelled once sent: the other server does not send it either if it
    // still waits its turn there
    const cancel = () => {
      const what = JSON.stringify({ nonce, time: Date.now() });
      relayRequest(port, 'POST', '/relay-cancel', { request: what, proof: hmac(key, 'relay-cancel\n' + what) }, CONNECT_TIMEOUT_MS)
        .catch((e) => log('could not cancel a relayed call: ' + e.message));
    };
    if (ticket) {
      ticket.onCancel = cancel;
    }
    const request = JSON.stringify({ nonce, time: Date.now(), tool, arguments: args || {} });
    const answer = await relayRequest(port, 'POST', '/relay', { request, proof: hmac(key, 'relay\n' + request) }, timeout)
      .catch(retry).finally(() => {
        if (ticket) {
          ticket.onCancel = null;
        }
      });
    const response = String(answer.response || '');
    if (!sameText(String(answer.proof || ''), hmac(key, 'relayed\n' + nonce + '\n' + response))) {
      throw new BridgeError('The answer from the server on port ' + port + ' did not carry its proof, so it was not used. What was asked ' +
        'may or may not have been done: read the stack again before going on.');
    }
    const result = JSON.parse(response);
    if (result.error !== undefined) {
      throw new BridgeError(String(result.error));
    }
    if (result.note) {
      this.toolsNote = String(result.note);
    }
    return result.reply;
  }

  // The tab answers one request at a time, on the one connection: there is
  // no second one to ask on
  status() {
    return Promise.resolve('');
  }

  connect() {
    if (this.link.problem) {
      return Promise.reject(new BridgeError(this.link.problem));
    }
    if (!this.link.tab) {
      return Promise.reject(new BridgeError(WEB_NOT_CONNECTED));
    }
    const tab = this.link.tab;
    this.token = null;
    this.buffer = '';
    this.socket = {
      write: (line) => {
        if (this.link.tab === tab) {
          this.link.send(line.replace(/\n+$/, ''));
        }
      },
      destroy: () => {
        if (this.link.tab === tab) {
          this.link.drop(tab);
        }
      }
    };
    return Promise.resolve();
  }
}

// Whether this file runs as the server, which it does however it was
// started: under the Node.js built into Claude's desktop app, a server
// that ran only when require.main was this module never read its first
// message (the app gave up on it: "Request timed out"), as when a script
// of its own loads this file. Only a
// program that loads it to read TOOLS sets OXT_MCP_LIBRARY=1.
const SERVES = process.env.OXT_MCP_LIBRARY !== '1';

let bridge;
if (WEB) {
  const link = new WebLink(WEB_PORT, WEB_ORIGINS, WEB_KEY);
  bridge = new WebBridge(link);
  if (SERVES) {
    link.listen();
  }
} else {
  bridge = new Bridge();
}
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
      const state = inFlight.get(params.requestId);
      state.cancelled = true;
      if (typeof state.onCancel === 'function') {
        state.onCancel();
      }
    }
    return;
  }
  switch (method) {
    case 'initialize': {
      const asked = params && params.protocolVersion;
      respond(id, {
        protocolVersion: MCP_VERSIONS.includes(asked) ? asked : MCP_VERSIONS[0],
        capabilities: { tools: { listChanged: false } },
        serverInfo: WEB ? { name: 'oxt-beyond-web', title: 'OXT-Beyond (web IDE)', version: SERVER_VERSION }
          : { name: 'oxt-beyond', title: 'OXT-Beyond', version: SERVER_VERSION },
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
      // A client that asked for progress (a progressToken) is told, while
      // the call takes long, what OXT-Beyond waits for
      const token = params && params._meta && params._meta.progressToken;
      let ticks = 0;
      const progress = (token === undefined || token === null) ? null : setInterval(() => {
        bridge.status().then((text) => {
          if (text && inFlight.get(id) === state) {
            ticks++;
            process.stdout.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/progress',
              params: { progressToken: token, progress: ticks, message: text } }) + '\n');
          }
        });
      }, STATUS_INTERVAL_MS);
      let result;
      let failure;
      try {
        result = await callTool(params, state);
      } catch (e) {
        failure = e;
      }
      if (progress) {
        clearInterval(progress);
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

if (SERVES) {
  main();
}

module.exports = { TOOLS, MCP_VERSIONS, BRIDGE_PROTOCOL };
