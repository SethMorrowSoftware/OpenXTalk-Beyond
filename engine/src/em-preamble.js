/*                                                              -*-Javascript-*-

Copyright (C) 2015 LiveCode Ltd.

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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

// The code in this file is run before the Emscripten engine starts.

// Ensure that there is a Module object.

var Module;
if (!Module) {
    Module = (typeof Module !== 'undefined' ? Module : null) || {};
}

// Ensure the Module object has a preRun list
if (!Module['preRun']) {
	Module['preRun'] = [];
}

// OXT-Beyond: where the engine's script is, for what loads the engine
// again (a web worker of the Background Workers library), unless the page
// says. Only while the script runs does the page know which it is.
if (typeof document !== 'undefined' && document.currentScript &&
    document.currentScript.src && !Module['livecodeEngineURL']) {
	Module['livecodeEngineURL'] = document.currentScript.src;
}

// ----------------------------------------------------------------
// Download standalone capsule
// ----------------------------------------------------------------

// Before the engine is allowed to start, we download the standalone
// capsule, which is a zip file containing the root filesystem to be
// used by the engine.
//
// There are several entries in the Module object that are used when
// downloading the capsule:
//
// * Module['livecodeStandalone'] is the filename of the standalone
//   zip file.  If it's not provided, the default value is
//   'standalone.zip'.
//
// * Module['locateFile'] is a function that takes a filename and
//   returns a corresponding URL.
//
// * Module['livecodeStandalonePrefixURL'] is prepended to the
//   standalone filename if there's no locateFile function available.
//
// * Module['livecodeStandaloneRequest'] stores the XMLHttpRequest()
//   object used to download the standalone file, for later use.

// FIXME Should this be moved into the engine?

Module['preRun'].push(function() {

	// Block running the engine
	Module['addRunDependency']('livecodeStandalone');

	// Compute the URL from which to download the capsule
	var standalone = 'standalone.zip';

	if (Module['livecodeStandalone']) {
		standalone = Module['livecodeStandalone'];
	}

	if (typeof Module['locateFile'] === 'function') {
		standalone = Module['locateFile'](standalone);
	} else if (Module['livecodeStandalonePrefixURL']) {
		standalone = Module['livecodeStandalonePrefixURL'] + standalone;
	}

	Module['livecodeStandaloneUrl'] = standalone;

	// Download the capsule

	// FIXME Can we cache the capsule locally?

	// OXT-Beyond: the engine waits for the capsule's request whether this
	// makes it or the page has (Module['livecodeStandaloneRequest']); it
	// waited for ever for a request that the page had made, and for a
	// download that failed
	var xhr = Module['livecodeStandaloneRequest'];

	if (!xhr) {
		xhr = new XMLHttpRequest();

		xhr.open("GET", standalone);
		xhr.responseType = "arraybuffer";
		xhr.send();

		// Save the request in the Module object for future reference.
		Module['livecodeStandaloneRequest'] = xhr;
	}

	var loaded = function() {
		if (xhr.status !== 200 && xhr.status !== 0) {
			throw 'Could not download LiveCode standalone';
		}

		if (!xhr.response ||
		    typeof xhr.response !== 'object' ||
		    !xhr.response.byteLength) {
			throw 'Bad result when downloading LiveCode standalone';
		}

		// Unblock running the engine
		Module['removeRunDependency']('livecodeStandalone');
	};

	// (a request the page made may have finished already)
	if (xhr.readyState === 4) {
		loaded();
	} else {
		xhr.addEventListener('load', loaded);
		xhr.addEventListener('error', function() {
			throw 'Could not download LiveCode standalone';
		});
	}
});
