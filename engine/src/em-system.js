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

	// The home folder (/livecode, which holds the documents, desktop,
	// preferences and support folders) is kept in the browser's storage
	// for the page's site (IndexedDB), so that what a stack writes there
	// is still there on its next visit, as on the desktop. The rest of
	// the engine's file system (/tmp, /downloads, /uploads, the
	// standalone's own folder) starts afresh with each visit.
	//
	// A page that does not want it sets Module.livecodePersistent to
	// false. Without the browser's storage (a private window may refuse
	// it), the home folder is not kept, and nothing else changes.
	$LiveCodeStorage__deps: ['$FS'],
	$LiveCodeStorage__postset: 'LiveCodeStorage.install();',
	$LiveCodeStorage: {
		_folder: '/livecode',

		// True once the folder's files are loaded from the browser's
		// storage: only then are its files written back, as writing an
		// unloaded folder back would delete what was kept
		_loaded: false,

		// The pending write (a timer), and whether one is under way and
		// another is wanted after it
		_timer: null,
		_writing: false,
		_again: false,

		// The folder is loaded before the engine starts
		install: function() {
			var preRun = Module['preRun'] || [];
			if (typeof preRun == 'function') {
				preRun = [preRun];
			}
			preRun.push(LiveCodeStorage._load);
			Module['preRun'] = preRun;
		},

		_load: function() {
			var idbfs = FS.filesystems && FS.filesystems['IDBFS'];
			if (Module['livecodePersistent'] === false || !idbfs ||
				typeof indexedDB == 'undefined') {
				return;
			}
			try {
				FS.mkdir(LiveCodeStorage._folder);
				FS.mount(idbfs, {}, LiveCodeStorage._folder);
			} catch (e) {
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
				if (error) {
					console.warn('The home folder will not be kept: ' + error);
				} else {
					LiveCodeStorage._loaded = true;
					// What is not yet written goes when the page goes
					window.addEventListener('pagehide', LiveCodeStorage.flush);
					document.addEventListener('visibilitychange', function() {
						if (document.visibilityState == 'hidden') {
							LiveCodeStorage.flush();
						}
					});
				}
				Module['removeRunDependency']('livecodeStorage');
			};
			// The engine starts without it if the storage does not answer
			timer = setTimeout(function() {
				finish('the browser\'s storage did not answer');
			}, 10000);
			try {
				FS.syncfs(true, function(error) {
					finish(error);
				});
			} catch (e) {
				finish(e);
			}
		},

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
			FS.syncfs(false, function(error) {
				LiveCodeStorage._writing = false;
				if (error) {
					console.warn('The home folder could not be kept: ' + error);
				}
				if (LiveCodeStorage._again) {
					LiveCodeStorage._again = false;
					LiveCodeStorage.flush();
				}
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
