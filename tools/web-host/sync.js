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

// OXT-Beyond web host: keeps the web IDE's ~/Documents on the server too.
//
// oxt_web_host.py adds this script to the IDE's index.html as it serves it,
// after the page's own script (which sets window.Module) and before the
// engine, which the page loads once it has downloaded it. Neither the page
// nor the engine is changed.
//
// The engine keeps its home folder (/openxtalk, /livecode before
// 0.2.7-rc.6.2) in the browser's IndexedDB (LiveCodeStorage in
// engine/src/em-system.js). This script sits beside that:
//
// - before the engine starts, once the browser's copy is loaded, the
//   server's files that are newer than the browser's are written into
//   <home>/Documents, and a file deleted on the server, and unchanged here
//   since the last sync, is deleted here;
// - whenever the engine says a file changed (LiveCodeStorage.changed), the
//   folder is compared with what the server has, a second later, and what
//   differs is sent (PUT) or removed (DELETE); and again when the tab is
//   hidden.
//
// The browser's copy stays: with the server unreachable the IDE works as it
// does on any static site, and the next change sends everything that
// differs. Per file, newest wins (README.md, "Limits").
//
// What the page can see: window.oxtHostSync {pulled, pushed, removed,
// errors, ready, busy, folder, push()}. tools/web-host/e2e_check.py reads it.
(function() {
  'use strict';

  var API = '/_host/api/files';
  var MEMORY = 'oxt-host-synced';   // localStorage: what the last sync saw

  var Module = window.Module;
  if (!Module) {
    return;
  }

  // path -> [size, mtime seconds, mtime milliseconds here], as the server
  // and this browser last agreed (the milliseconds tell apart two saves of
  // the same size in one second; the server keeps whole seconds)
  var known = {};
  try {
    known = JSON.parse(localStorage.getItem(MEMORY) || '{}') || {};
  } catch (e) {
    known = {};
  }
  function remember() {
    try {
      localStorage.setItem(MEMORY, JSON.stringify(known));
    } catch (e) {
      // the next visit compares everything again
    }
  }

  var state = { pulled: 0, pushed: 0, removed: 0, errors: 0, ready: false, busy: false, folder: '',
                listed: false, loaded: false, refused: 0 };
  window.oxtHostSync = state;

  function say(text) {
    console.log('[oxt-host] ' + text);
  }

  // The engine's storage, once its script has run
  function engineStorage() {
    return typeof LiveCodeStorage !== 'undefined' ? LiveCodeStorage : null;
  }

  // <home>/Documents: the home folder is the engine's own name for it
  function folder() {
    var storage = engineStorage();
    return ((storage && storage._folder) || '/livecode') + '/Documents';
  }

  function url(rel) {
    return API + '/' + rel.split('/').map(encodeURIComponent).join('/');
  }

  // Every file under the folder: rel path -> [size, mtime seconds, ms]
  function walk() {
    var found = {};
    function visit(dir, rel) {
      var names;
      try {
        names = FS.readdir(dir);
      } catch (e) {
        return;
      }
      names.forEach(function(name) {
        if (name === '.' || name === '..') {
          return;
        }
        var path = dir + '/' + name;
        var st;
        try {
          st = FS.lstat(path);
        } catch (e) {
          return;
        }
        var r = rel ? rel + '/' + name : name;
        if (FS.isDir(st.mode)) {
          visit(path, r);
        } else if (FS.isFile(st.mode)) {
          var ms = st.mtime.getTime();
          found[r] = [st.size, Math.floor(ms / 1000), ms];
        }
      });
    }
    visit(state.folder, '');
    return found;
  }

  // The same size and date; to the millisecond when both know it
  function same(a, b) {
    return !!(a && b && a[0] === b[0] && a[1] === b[1] &&
              (a[2] === undefined || b[2] === undefined || a[2] === b[2]));
  }

  // The server's copy of rel, written here with its date: what the server
  // has is newer than this browser's (pull, and a save the server refused)
  function fetchInto(rel, entry) {
    return fetch(url(rel), { cache: 'no-store', credentials: 'same-origin' }).then(checked).then(function(r) {
      var mtime = Number(r.headers.get('X-Mtime')) || entry[1];
      return r.arrayBuffer().then(function(data) {
        var path = state.folder + '/' + rel;
        mkdirs(path);
        FS.writeFile(path, new Uint8Array(data));
        FS.utime(path, mtime * 1000, mtime * 1000);
        known[rel] = [data.byteLength, mtime, mtime * 1000];
        state.pulled++;
      });
    });
  }

  function mkdirs(path) {
    var parts = path.split('/').slice(0, -1);
    var dir = '';
    parts.forEach(function(part) {
      if (!part) {
        return;
      }
      dir += '/' + part;
      try {
        FS.mkdir(dir);
      } catch (e) {
        // it is there already
      }
    });
  }

  function checked(response) {
    if (!response.ok) {
      throw new Error('HTTP ' + response.status);
    }
    return response;
  }

  // ---- before the engine starts: the server's files come in -------------

  // The engine loads the browser's copy in its own preRun step, after this
  // one: wait for it (or for its storage to give up), as long as the engine
  // itself waits (10 s) and a little more
  function waitForBrowserCopy() {
    return new Promise(function(resolve) {
      var tries = 0;
      (function check() {
        var storage = engineStorage();
        if ((storage && (storage._loaded || storage._error)) ||
            (storage && Module.livecodePersistent === false) || ++tries > 240) {
          resolve(storage);
        } else {
          setTimeout(check, 50);
        }
      })();
    });
  }

  function pull() {
    Module.addRunDependency('oxtHostSync');
    var listing = fetch(API, { cache: 'no-store', credentials: 'same-origin' }).then(checked).then(function(r) {
      return r.json();
    });
    // Both settle before anything is compared: after a failed listing, a
    // push must still not compare the server with a folder not yet loaded
    // (it would look empty, and its files deleted)
    var copy = waitForBrowserCopy();
    var listed = listing.then(function(value) {
      return { ok: true, value: value };
    }, function(error) {
      return { ok: false, error: error };
    });
    Promise.all([listed, copy]).then(function(done) {
      var storage = done[1];
      state.folder = folder();
      state.loaded = !!(storage && storage._loaded);
      hookChanges(storage);
      if (!done[0].ok) {
        throw done[0].error;
      }
      state.listed = true;
      var server = done[0].value.files || {};
      var local = walk();
      var jobs = [];
      Object.keys(server).forEach(function(rel) {
        var mine = local[rel];
        if (mine && (same(mine, server[rel]) || mine[1] >= server[rel][1])) {
          if (same(mine, server[rel])) {
            known[rel] = mine;
          }
          return;   // this browser's copy is as new or newer: it is sent later
        }
        jobs.push(fetchInto(rel, server[rel]));
      });
      // Deleted on the server since this browser last synced, unchanged here
      Object.keys(local).forEach(function(rel) {
        if (!server[rel] && same(local[rel], known[rel])) {
          try {
            FS.unlink(state.folder + '/' + rel);
            state.removed++;
          } catch (e) {
            // gone already
          }
          delete known[rel];
        }
      });
      // What the server no longer has, and this browser does not either
      Object.keys(known).forEach(function(rel) {
        if (!server[rel] && !local[rel]) {
          delete known[rel];
        }
      });
      return Promise.all(jobs).then(function() {
        remember();
        if (storage && storage.changed) {
          storage.changed();   // the browser's copy takes what came in
        }
      });
    }).catch(function(error) {
      state.errors++;
      say('the server\'s copy could not be read (' + (error && error.message || error) +
          '): the IDE keeps this browser\'s');
    }).then(function() {
      state.ready = true;
      say('in: ' + state.pulled + ' file(s) from the server, ' + state.removed + ' removed');
      Module.removeRunDependency('oxtHostSync');
      schedule();   // stacks kept only in this browser go to the server
    });
  }

  // ---- while it runs: changes go out --------------------------------------

  var timer = null;
  var again = false;

  function hookChanges(storage) {
    if (!storage || storage._oxtHostHooked || typeof storage.changed !== 'function') {
      return;
    }
    storage._oxtHostHooked = true;
    var changed = storage.changed;
    storage.changed = function() {
      var result = changed.apply(storage, arguments);
      schedule();
      return result;
    };
  }

  function schedule() {
    if (!state.ready) {
      return;
    }
    if (timer !== null) {
      clearTimeout(timer);
    }
    timer = setTimeout(push, 1000);
  }

  function push() {
    if (timer !== null) {
      clearTimeout(timer);
      timer = null;
    }
    if (!state.ready) {
      return Promise.resolve();
    }
    if (state.busy) {
      again = true;
      return Promise.resolve();
    }
    state.busy = true;
    var local = walk();
    var jobs = [];
    Object.keys(local).forEach(function(rel) {
      if (same(local[rel], known[rel])) {
        return;
      }
      var entry = local[rel];
      var data;
      try {
        data = FS.readFile(state.folder + '/' + rel);
      } catch (e) {
        return;
      }
      jobs.push(fetch(url(rel), {
        method: 'PUT', body: data, credentials: 'same-origin', keepalive: data.length < 60000,
        headers: { 'X-Mtime': String(entry[1]), 'Content-Type': 'application/octet-stream' },
      }).then(function(r) {
        if (r.status === 409) {
          // The server has a newer save (another browser's): newest wins,
          // so this browser takes it
          state.refused++;
          return fetchInto(rel, entry).then(function() {
            var storage = engineStorage();
            if (storage && storage.changed) {
              storage.changed();
            }
          });
        }
        checked(r);
        known[rel] = entry;
        state.pushed++;
      }));
    });
    // A file gone from here is deleted on the server only when this page
    // has compared the two (the listing came in, and the browser's copy was
    // loaded): a folder that only looks empty deletes nothing
    Object.keys(known).forEach(function(rel) {
      if (local[rel] || !state.listed || !state.loaded) {
        return;
      }
      jobs.push(fetch(url(rel), { method: 'DELETE', credentials: 'same-origin', keepalive: true })
        .then(checked).then(function() {
          delete known[rel];
          state.removed++;
        }));
    });
    return Promise.all(jobs).catch(function(error) {
      state.errors++;
      say('not kept on the server yet (' + (error && error.message || error) +
          '); trying again with the next change');
    }).then(function() {
      remember();
      state.busy = false;
      if (jobs.length) {
        say('out: ' + state.pushed + ' sent, ' + state.removed + ' removed so far');
      }
      if (again) {
        again = false;
        schedule();
      }
    });
  }
  state.push = push;

  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'hidden' && state.ready) {
      push();
    }
  });

  var preRun = Module.preRun || [];
  if (typeof preRun === 'function') {
    preRun = [preRun];
  }
  preRun.push(pull);
  Module.preRun = preRun;
})();
