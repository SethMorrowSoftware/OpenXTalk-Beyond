/*                                                              -*-Javascript-*-
 
 Copyright (C) 2016 LiveCode Ltd.
 
 This file is part of LiveCode.
 
 LiveCode is free software; you can redistribute it and/or modify it under
 the terms of the GNU General Public License v3 as published by the Free
 Software Foundation.
 
 LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.
 
 You should have received a copy of the GNU General Public License
 along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

mergeInto(LibraryManager.library, {
          
    $LiveCodeSystem__deps: ['$LiveCodeUtil', '$LiveCodeAsync'],
    $LiveCodeSystem: {
		
		initialize: function() {
			if (!document['liveCode'])
				document['liveCode'] = {}
			document['liveCode']['findStackWithName'] = function(name) {
				return LiveCodeSystem.getStackWithName(name);
			};
		},
		
		finalize: function() {
			delete document['liveCodeGetStackWithName'];
		},
		
		//////////
		
		evaluateJavaScriptWithArguments: function(pScriptRef, pArgsRef, rResultRef) {
			var script = LiveCodeUtil.stringFromMCStringRef(pScriptRef);
			var args = [];
			if (pArgsRef)
				args = LiveCodeUtil.properListToJSArray(pArgsRef);
				
			// Evaluate javascript and convert result to a valueref.
			var result;
			var success;
			try
			{
				var jsResult = function() {
					return eval(script);
				}.apply(null, args);
				
				result = LiveCodeUtil.valueFromJSValue(jsResult);
				success = true;
			}
			catch (e)
			{
				// return the exception message on failure
				result = LiveCodeUtil.stringToMCStringRef(e.message);
				success = false;
			}
			
			{{{ makeSetValue('rResultRef', '0', 'result', '*') }}};
			return success;
		},

		//////////
		
		_callStackHandler: function(stack, handler, paramList)
		{
			return Module.ccall('MCEmscriptenSystemCallStackHandler', 'number', ['number', 'number', 'number'], [stack, handler, paramList]);
		},
		
		_getStackHandlerList: function(stack)
		{
			return Module.ccall('MCEmscriptenSystemGetJavascriptHandlersOfStack', 'number', ['number'], [stack]);
		},
		
		_makeHandlerProxy: function(stack, handler)
		{
			return function()
			{
				var tParams = Array.prototype.slice.call(arguments);
				var tJSResult;
				LiveCodeAsync.resume(function() {
					var tHandlerName = LiveCodeUtil.stringToMCStringRef(handler);
					var tConvertedParams = LiveCodeUtil.properListFromJSArray(tParams);
					var tResult = LiveCodeSystem._callStackHandler(stack, tHandlerName, tConvertedParams);
					LiveCodeUtil.valueRelease(tHandlerName);
					LiveCodeUtil.valueRelease(tConvertedParams);

					if (tResult)
					{
						tJSResult = LiveCodeUtil.valueToJSValue(tResult);
						LiveCodeUtil.valueRelease(tResult);
					}
				});
				
				return tJSResult;
			}
		},
		
		_stackHandle: function(stack)
		{
			var stackHandle = { _stack: stack };
			var handlerList = LiveCodeSystem._getStackHandlerList(stack);
			var count = LiveCodeUtil.properListGetLength(handlerList);
			for (var i = 0; i < count; i++)
			{
				var stringref = LiveCodeUtil.properListFetchElementAtIndex(handlerList, i);
				var handler_name = LiveCodeUtil.stringFromMCStringRef(stringref);
				stackHandle[handler_name] = LiveCodeSystem._makeHandlerProxy(stack, handler_name);
			}
			
			LiveCodeUtil.valueRelease(handlerList);
			
			return stackHandle;
		},
		
		_resolveStack: function(stack_name)
		{
			var stringref = LiveCodeUtil.stringToMCStringRef(stack_name);
			var stack = Module.ccall('MCEmscriptenResolveStack', 'number', ['number'], [stringref]);
			LiveCodeUtil.valueRelease(stringref);
			
			return stack
		},
		
		getStackWithName: function(name)
		{
			var stackHandle = null;
			LiveCodeAsync.resume(function() {
				var stack = LiveCodeSystem._resolveStack(name);
				if (stack != 0)
					stackHandle = LiveCodeSystem._stackHandle(stack);

			});
			return stackHandle;
		},
		
		//////////
		
		callHandlerWithParamList: function(handler, paramList) {
			return Module.ccall('MCEmscriptenSystemCallHandler', 'number', ['number', 'number'], [handler, paramList]);
		},
		
		wrapHandlerRef: function(handlerref) {
			var jsFunction = function() {
				var tParams = Array.prototype.slice.call(arguments);
				var jsResult;
				LiveCodeAsync.resume(function() {
					var paramList = LiveCodeUtil.properListFromJSArray(tParams);
					var result = LiveCodeSystem.callHandlerWithParamList(handlerref, paramList);

					if (paramList)
						LiveCodeUtil.valueRelease(paramList);

					if (result)
					{
						jsResult = LiveCodeUtil.valueToJSValue(result);
						LiveCodeUtil.valueRelease(result);
					}
				});

				return jsResult;
			};
			
			return LiveCodeUtil.objectRefFromJSObject(jsFunction);
		},
    },
    
    MCEmscriptenSystemEvaluateJavaScriptWithArguments__deps: ['$LiveCodeSystem'],
    MCEmscriptenSystemEvaluateJavaScriptWithArguments: function(pScriptRef, pArgsRef, rResultRef) {
		return LiveCodeSystem.evaluateJavaScriptWithArguments(pScriptRef, pArgsRef, rResultRef);
    },
    
    MCEmscriptenSystemWrapHandler__deps: ['$LiveCodeSystem'],
    MCEmscriptenSystemWrapHandler: function(pHandlerRef) {
		return LiveCodeSystem.wrapHandlerRef(pHandlerRef);
	},
	
	MCEmscriptenSystemInitializeJS__deps: ['$LiveCodeSystem'],
	MCEmscriptenSystemInitializeJS: function() {
		LiveCodeSystem.initialize();
		return true;
	},

	MCEmscriptenSystemFinalizeJS__deps: ['$LiveCodeSystem'],
	MCEmscriptenSystemFinalizeJS: function() {
		LiveCodeSystem.finalize();
	},

	// launch url: opens <url> in a new tab of the browser (mailto:, tel:
	// and the like in the application that answers them), relative to
	// the page if it is relative. Returns 0 if it is refused (not a URL,
	// or a javascript:, data: or vbscript: URL, which would run in or
	// stand for the page), 1 if it opened, and 2 if the page asks the
	// user first (em-dialog.js).
	MCEmscriptenSystemLaunchUrl__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
	MCEmscriptenSystemLaunchUrl: function(url, url_length) {
		var text = LiveCodeUtil.stringFromUTF16(url, url_length);
		var target;
		try {
			target = new URL(text, document.baseURI);
		} catch (e) {
			return 0;
		}
		var scheme = target.protocol.toLowerCase();
		if (scheme == 'javascript:' || scheme == 'data:' || scheme == 'vbscript:') {
			return 0;
		}
		var href = target.href;
		var tab = scheme == 'http:' || scheme == 'https:' || scheme == 'ftp:' ||
			scheme == 'blob:' || scheme == 'file:';
		var open = function() {
			if (tab) {
				var opened = window.open(href, '_blank');
				if (!opened) {
					return false;
				}
				try {
					opened.opener = null;
				} catch (e) {
				}
				return true;
			}
			// The browser hands the link to an application, and the page
			// stays
			var link = document.createElement('a');
			link.href = href;
			link.rel = 'noopener';
			link.style.display = 'none';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			return true;
		};
		return LiveCodeDialog.openWithClick(open, 'Open this link?', href);
	},

	// The name of the machine the page comes from (its host), as UTF-16
	// that the engine frees
	MCEmscriptenSystemGetHostName__deps: ['$LiveCodeUtil'],
	MCEmscriptenSystemGetHostName: function(r_chars, r_length) {
		var host = (typeof location != 'undefined' && location.hostname) || 'localhost';
		var chars = LiveCodeUtil.stringToUTF16(host);
		{{{ makeSetValue('r_chars', '0', 'chars', 'i32') }}};
		{{{ makeSetValue('r_length', '0', 'host.length', 'i32') }}};
	},

	// The home folder (/openxtalk, which holds the documents, desktop,
	// preferences and support folders) is kept in the browser's storage
	// for the page's site (IndexedDB), so that what a stack writes there
	// is still there on its next visit, as on the desktop. The rest of
	// the engine's file system (/tmp, /downloads, /uploads, the
	// standalone's own folder) starts afresh with each visit.
	//
	// OXT-Beyond: the home folder was /livecode until 0.2.7-rc.6.2.
	// /livecode is still there, as a link to /openxtalk, so a script or
	// a saved path that names it finds the same files, and a standalone
	// that brings files in livecode/ puts them in the home folder as
	// before. On the first visit with this engine, what the browser kept
	// for /livecode (its own IndexedDB database, named after the folder)
	// is copied into /openxtalk's; the old database is left as it was.
	//
	// A page that does not want it sets Module.livecodePersistent to
	// false. Without the browser's storage (a private window may refuse
	// it), the home folder is not kept, and nothing else changes.
	$LiveCodeStorage__deps: ['$FS', '$PATH'],
	$LiveCodeStorage__postset: 'LiveCodeStorage.install();',
	$LiveCodeStorage: {
		_folder: '/openxtalk',
		_legacyFolder: '/livecode',

		// True once the folder's files are loaded from the browser's
		// storage: only then are its files written back, as writing an
		// unloaded folder back would delete what was kept
		_loaded: false,

		// The pending write (a timer), and whether one is under way and
		// another is wanted after it
		_timer: null,
		_writing: false,
		_again: false,

		// The date (in milliseconds) of each file and folder of the home
		// folder as the browser's storage had it when this page last read
		// or wrote it. Another page of the site (the web IDE in a second
		// tab, a standalone) keeps the same folder in the same storage:
		// what it wrote since is what this page has neither written nor
		// known, and is read in instead of deleted (_write)
		_known: {},

		// The other pages of the site that keep the home folder, told when
		// this page has written to it, so that they read it in
		_channel: null,

		// Why the home folder is not being kept, empty while it is: the
		// last write to the browser's storage failed (a full disk, the
		// storage refused or deleted), or the folder could not be loaded
		// from it. The page is told each time it changes (_report).
		_error: '',

		// Tells the page whether the home folder is kept: <error> is why
		// not, or empty (or null) when it is. Module.livecodeStorageError
		// is that text, and the window gets an "oxtstoragestate" event
		// whose detail is {kept, error}, only when it changes. The engine
		// and its scripts see nothing of it, and a page that does not
		// listen (a standalone's) shows nothing, as before; the web IDE's
		// page shows a bar (tools/web-ide/index.html). Before, a failed
		// write was only a warning in the browser's console: a stack saved
		// in the web IDE looked saved, and was lost when the tab closed.
		_report: function(error) {
			var text = error ? String(error) : '';
			Module['livecodeStorageError'] = text;
			if (text === LiveCodeStorage._error) {
				return;
			}
			LiveCodeStorage._error = text;
			try {
				window.dispatchEvent(new CustomEvent('oxtstoragestate',
					{detail: {kept: text === '', error: text}}));
			} catch (e) {
				// a page without CustomEvent has Module.livecodeStorageError
			}
		},

		// The folder is loaded before the engine starts
		install: function() {
			var preRun = Module['preRun'] || [];
			if (typeof preRun == 'function') {
				preRun = [preRun];
			}
			preRun.push(LiveCodeStorage._load);
			Module['preRun'] = preRun;
		},

		// /livecode, the home folder's old name, made a link to it
		_alias: function() {
			try {
				FS.symlink(LiveCodeStorage._folder, LiveCodeStorage._legacyFolder);
			} catch (e) {
				// it is there already
			}
		},

		// The names in <path>, without . and ..
		_names: function(path) {
			return FS.readdir(path).filter(function(name) {
				return name != '.' && name != '..';
			});
		},

		// Copies the files and folders in <from> to <to>, with their modes
		// and dates
		_copy: function(from, to) {
			LiveCodeStorage._names(from).forEach(function(name) {
				var source = from + '/' + name;
				var target = to + '/' + name;
				var stat = FS.lstat(source);
				if (FS.isDir(stat.mode)) {
					try {
						FS.mkdir(target, stat.mode);
					} catch (e) {
						// it is there already
					}
					LiveCodeStorage._copy(source, target);
				} else if (FS.isFile(stat.mode)) {
					FS.writeFile(target, FS.readFile(source));
					FS.chmod(target, stat.mode);
				} else {
					return;
				}
				FS.utime(target, stat.mtime.getTime(), stat.mtime.getTime());
			});
		},

		// What the browser kept for /livecode, copied to the home folder
		// when it has nothing yet: <done>(error) is called after, and
		// /livecode is then the link
		_migrate: function(idbfs, done) {
			var legacy = LiveCodeStorage._legacyFolder;
			var mounted = false;
			var end = function(error) {
				if (mounted) {
					try {
						FS.unmount(legacy);
					} catch (e) {
						// it was not mounted
					}
				}
				try {
					FS.rmdir(legacy);
				} catch (e) {
					// it was not made
				}
				LiveCodeStorage._alias();
				done(error);
			};
			var copy = function() {
				try {
					FS.mkdir(legacy);
					FS.mount(idbfs, {}, legacy);
					mounted = true;
				} catch (e) {
					end(null);
					return;
				}
				FS.syncfs(true, function(error) {
					if (error) {
						// the copy is not made, and the old database is
						// left as it was
						console.warn('The old home folder (/livecode) could not be read: ' + error);
						end(null);
						return;
					}
					try {
						var copied = LiveCodeStorage._names(legacy).length > 0;
						LiveCodeStorage._copy(legacy, LiveCodeStorage._folder);
						LiveCodeStorage._copied = copied;
					} catch (e) {
						console.warn('The old home folder (/livecode) could not be copied: ' + e);
					}
					end(null);
				});
			};
			if (LiveCodeStorage._names(LiveCodeStorage._folder).length > 0) {
				end(null);
				return;
			}
			// Only a browser that kept /livecode has its database: one
			// that can list its databases makes none for the others
			if (typeof indexedDB.databases == 'function') {
				indexedDB.databases().then(function(databases) {
					if (databases.some(function(database) {
						return database.name == legacy;
					})) {
						copy();
					} else {
						end(null);
					}
				}, copy);
			} else {
				copy();
			}
		},

		_load: function() {
			var folder = LiveCodeStorage._folder;
			try {
				FS.mkdir(folder);
			} catch (e) {
				// the page made it
			}
			var idbfs = FS.filesystems && FS.filesystems['IDBFS'];
			if (Module['livecodePersistent'] === false) {
				LiveCodeStorage._alias();
				return;
			}
			if (!idbfs || typeof indexedDB == 'undefined') {
				LiveCodeStorage._alias();
				LiveCodeStorage._report('the browser has no storage for it');
				return;
			}
			try {
				FS.mount(idbfs, {}, folder);
			} catch (e) {
				LiveCodeStorage._alias();
				LiveCodeStorage._report(e);
				return;
			}

			Module['addRunDependency']('livecodeStorage');
			var finished = false;
			var timer;
			var finish = function(error) {
				if (finished) {
					return;
				}
				finished = true;
				clearTimeout(timer);
				LiveCodeStorage._alias();
				if (error) {
					console.warn('The home folder will not be kept: ' + error);
					LiveCodeStorage._report(error);
				} else {
					LiveCodeStorage._loaded = true;
					LiveCodeStorage._remember();
					LiveCodeStorage._listen();
					// What is not yet written goes when the page goes
					window.addEventListener('pagehide', LiveCodeStorage.flush);
					document.addEventListener('visibilitychange', function() {
						if (document.visibilityState == 'hidden') {
							LiveCodeStorage.flush();
						}
					});
					// What was copied from /livecode is kept in /openxtalk's
					// own database
					if (LiveCodeStorage._copied) {
						LiveCodeStorage.changed();
					}
				}
				Module['removeRunDependency']('livecodeStorage');
			};
			// The engine starts without it if the storage does not answer
			timer = setTimeout(function() {
				finish('the browser\'s storage did not answer');
			}, 10000);
			try {
				FS.syncfs(true, function(error) {
					if (error || finished) {
						finish(error);
						return;
					}
					try {
						LiveCodeStorage._migrate(idbfs, function() {
							finish(null);
						});
					} catch (e) {
						console.warn('The old home folder (/livecode) could not be copied: ' + e);
						finish(null);
					}
				});
			} catch (e) {
				finish(e);
			}
		},

		// True when files were copied from /livecode on this visit
		_copied: false,

		// A file or folder of the engine's changed: the home folder is
		// written back soon, with whatever else changes meanwhile
		changed: function() {
			if (!LiveCodeStorage._loaded || LiveCodeStorage._timer !== null) {
				return;
			}
			LiveCodeStorage._timer = setTimeout(LiveCodeStorage.flush, 200);
		},

		flush: function() {
			if (LiveCodeStorage._timer !== null) {
				clearTimeout(LiveCodeStorage._timer);
				LiveCodeStorage._timer = null;
			}
			if (!LiveCodeStorage._loaded) {
				return;
			}
			if (LiveCodeStorage._writing) {
				LiveCodeStorage._again = true;
				return;
			}
			LiveCodeStorage._writing = true;
			LiveCodeStorage._write(function(error, wrote) {
				LiveCodeStorage._writing = false;
				if (error) {
					console.warn('The home folder could not be kept: ' + error);
				} else if (wrote && LiveCodeStorage._channel) {
					try {
						LiveCodeStorage._channel.postMessage('changed');
					} catch (e) {
						// the other pages read it on their next write
					}
				}
				LiveCodeStorage._report(error);
				if (LiveCodeStorage._again) {
					LiveCodeStorage._again = false;
					LiveCodeStorage.flush();
				}
			});
		},

		// The home folder's mount, and IDBFS, which keeps it
		_mount: function() {
			var idbfs = FS.filesystems && FS.filesystems['IDBFS'];
			try {
				var mount = FS.lookupPath(LiveCodeStorage._folder).node.mount;
				if (idbfs && mount && mount.type === idbfs) {
					return mount;
				}
			} catch (e) {
				// it is not mounted
			}
			return null;
		},

		// The dates of the home folder's files and folders as they are
		// now, just after it was loaded from the browser's storage
		_remember: function() {
			var mount = LiveCodeStorage._mount();
			if (!mount) {
				return;
			}
			mount.type.getLocalSet(mount, function(error, local) {
				if (error) {
					return;
				}
				var known = {};
				Object.keys(local.entries).forEach(function(path) {
					known[path] = local.entries[path].timestamp.getTime();
				});
				LiveCodeStorage._known = known;
			});
		},

		// When another page of the site has written to the home folder,
		// this page reads in what it wrote soon
		_listen: function() {
			if (typeof BroadcastChannel != 'function') {
				return;
			}
			try {
				var channel = new BroadcastChannel('oxt-home:' + LiveCodeStorage._folder);
				channel.onmessage = function() {
					LiveCodeStorage.changed();
				};
				LiveCodeStorage._channel = channel;
			} catch (e) {
				// the other pages' files are read in on this page's next
				// write
			}
		},

		// Writes the home folder back to the browser's storage, calling
		// <done>(error, wrote), where <wrote> is true when the storage
		// changed. IDBFS's own write (FS.syncfs(false)) makes the storage
		// the same as this page's folder: it deleted what another page of
		// the site saved there after this one loaded it, and put this
		// page's older copy over another page's newer one, so a stack
		// saved in the web IDE in one tab was lost when the IDE in another
		// tab wrote anything. This writes what this page changed and
		// deleted, as that did, and reads in what another page wrote that
		// this page did not change, instead of deleting it. With one page,
		// the storage holds only what this page wrote, and it writes what
		// FS.syncfs(false) wrote.
		_write: function(done) {
			var mount = LiveCodeStorage._mount();
			if (!mount) {
				FS.syncfs(false, function(error) {
					done(error, !error);
				});
				return;
			}
			var idbfs = mount.type;
			idbfs.getLocalSet(mount, function(error, local) {
				if (error) {
					done(error, false);
					return;
				}
				idbfs.getRemoteSet(mount, function(error, remote) {
					if (error) {
						done(error, false);
						return;
					}
					var known = LiveCodeStorage._known;
					var kept = {};
					var push = [];
					var pull = [];
					var drop = [];
					Object.keys(local.entries).forEach(function(path) {
						var mine = local.entries[path].timestamp.getTime();
						var theirs = remote.entries[path];
						if (!theirs) {
							push.push(path);
						} else if (theirs.timestamp.getTime() == mine) {
							kept[path] = mine;
						} else if (known[path] === mine) {
							// unchanged here, written by another page: kept
							// as it is here until it is read in
							kept[path] = mine;
							pull.push(path);
						} else {
							push.push(path);
						}
					});
					Object.keys(remote.entries).forEach(function(path) {
						if (local.entries[path]) {
							return;
						}
						if (known[path] === remote.entries[path].timestamp.getTime()) {
							// deleted here
							drop.push(path);
						} else {
							// written by another page: a folder comes in
							// before what is in it
							pull.push(path);
						}
					});
					if (push.length == 0 && pull.length == 0 && drop.length == 0) {
						LiveCodeStorage._known = kept;
						done(null, false);
						return;
					}
					pull.sort();

					var failed = null;
					var finished = false;
					var finish = function(error, wrote) {
						if (!finished) {
							finished = true;
							done(error, wrote);
						}
					};
					var transaction;
					try {
						transaction = remote.db.transaction([idbfs.DB_STORE_NAME], 'readwrite');
					} catch (e) {
						done(e, false);
						return;
					}
					var store = transaction.objectStore(idbfs.DB_STORE_NAME);
					var fail = function(error) {
						if (error && !failed) {
							failed = error;
						}
					};
					transaction.oncomplete = function() {
						if (!failed) {
							LiveCodeStorage._known = kept;
						}
						finish(failed, push.length + drop.length > 0);
					};
					transaction.onerror = transaction.onabort = function(event) {
						if (event && event.preventDefault) {
							event.preventDefault();
						}
						finish(failed || transaction.error || 'the browser\'s storage refused the write', false);
					};
					push.forEach(function(path) {
						idbfs.loadLocalEntry(path, function(error, entry) {
							if (error) {
								fail(error);
								return;
							}
							kept[path] = entry.timestamp.getTime();
							idbfs.storeRemoteEntry(store, path, entry, fail);
						});
					});
					drop.forEach(function(path) {
						idbfs.removeRemoteEntry(store, path, fail);
					});
					pull.forEach(function(path) {
						idbfs.loadRemoteEntry(store, path, function(error, entry) {
							if (error || !entry) {
								fail(error);
								return;
							}
							try {
								FS.mkdirTree(PATH.dirname(path));
							} catch (e) {
								// it is there
							}
							idbfs.storeLocalEntry(path, entry, function(error) {
								if (error) {
									// a file this page has open, or a folder
									// where it keeps a file: left as it is
									return;
								}
								kept[path] = entry.timestamp.getTime();
							});
						});
					});
				});
			});
		},
	},

	MCEmscriptenStorageChanged__deps: ['$LiveCodeStorage'],
	MCEmscriptenStorageChanged: function() {
		LiveCodeStorage.changed();
	},

	// SQLite's fdatasync() (thirdparty/libsqlite/libsqlite.gyp). A
	// database in the home folder is written back to the browser's
	// storage soon, as every other file is (MCEmscriptenStorageChanged),
	// instead of SQLite waiting for it. Emscripten's own fsync() waits
	// for the browser's storage by suspending the engine, which needed
	// all of SQLite instrumented by Asyncify; its largest functions
	// instrumented made Safari's WebAssembly compiler use gigabytes,
	// and Safari reload the page.
	MCEmscriptenStorageSync__deps: ['$LiveCodeStorage', '$FS'],
	MCEmscriptenStorageSync: function(fd) {
		var stream = FS.getStream(fd);
		if (!stream) {
			return -1;
		}
		if (stream.node.mount.type.syncfs) {
			LiveCodeStorage.changed();
		}
		return 0;
	},

});

/*
 * Local Variables:
 * tab-width: 4
 * indent-tabs-mode: t
 * End:
 */
