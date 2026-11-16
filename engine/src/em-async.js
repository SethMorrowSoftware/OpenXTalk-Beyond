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

mergeInto(LibraryManager.library, {

	// This class is used to emulate a synchronous LiveCode main loop
	// using Emscripten's Asyncify.  When the engine has nothing to do
	// it yields (MCEmscriptenAsyncYield()): Asyncify saves the
	// WebAssembly call stack and returns to the browser.  An event
	// (resume()) or a timeout restores the stack, and the engine
	// carries on from the point where it yielded.  (LiveCode's HTML5
	// engine did the same with the Emterpreter, which only ran a short
	// list of functions, so the engine could only yield from its main
	// loop; Asyncify instruments the whole engine, so a wait can yield
	// from inside a handler too.)
	$LiveCodeAsync__deps: ['$Asyncify'],
	$LiveCodeAsync: {
		// true if ensureInit() has ever been run
		_initialised: false,

		// Asyncify's function that resumes the LiveCode main loop,
		// while the engine is paused.
		_continuation: null,

		// List of hooks to be run before every resume
		_hooks: [],

		// List of callbacks to be run just before resuming the main
		// loop.
		_preResume: [],

		// The handle for the setTimeout() handler for the current
		// yield state.
		_timeoutHandle: null,

		// True if the last resume was from a timeout
		_fromTimeout: false,

		_ensureInit: function() {
			// Make sure this only ever gets run once.
			if (LiveCodeAsync._initialised) {
				return;
			}
			LiveCodeAsync._initialised = true;

			LiveCodeAsync.addResumeHook(function () {
				// Run pre-resume callbacks.  Take the list first: a
				// callback that delays another closure runs it at
				// once (the engine is no longer paused).
				var preResume = LiveCodeAsync._preResume;
				LiveCodeAsync._preResume = [];
				preResume.forEach(function (c) { c(); });
			});
		},

		_resumeTimeout: function() {
			LiveCodeAsync._timeoutHandle = null;
			LiveCodeAsync._fromTimeout = true;
			LiveCodeAsync.resume();
		},

		// Resume the main loop.  Returns when the engine next yields.
		resume: function(delayed) {
			LiveCodeAsync._ensureInit();

			// For convenience, simplify delay+resume
			if (delayed) {
				LiveCodeAsync.delay(delayed);
			}

			// Don't allow calls to resume() when not actually paused.
			if (!LiveCodeAsync.isPaused()) {
				return;
			}

			// Cancel the timeout for this yield state
			if (LiveCodeAsync._timeoutHandle) {
				clearTimeout(LiveCodeAsync._timeoutHandle);
			}

			var resume = LiveCodeAsync._continuation;

			// Clear state
			LiveCodeAsync._timeoutHandle = null;
			LiveCodeAsync._continuation = null;

			// Run the pre-resume hooks.  The engine's stack is still
			// saved, so the hooks can call into the engine (to post
			// events, or to run a handler), but the engine cannot
			// yield from those calls (canYield() is false).  The
			// engine resumes even if a hook throws.
			try {
				LiveCodeAsync._runHooks();
			} finally {
				// Restore the engine's stack.  The engine runs until
				// it next yields, and then this returns.  The value
				// is what MCEmscriptenAsyncYield() returns: non-zero
				// unless the resume is due to the timeout.
				resume(LiveCodeAsync.isTimedOut() ? 0 : 1);
			}
		},

		// Yield the main loop; save the execution state and return to
		// the browser.  The main loop will be resumed the next time
		// the browser sends the engine an event.
		//
		// If no event has occurred by the time <timeout> milliseconds
		// elapse, pause() returns false.  Otherwise,
		// pause() returns true.
		pause: function(timeout) {
			LiveCodeAsync._ensureInit();

			// Suspend execution.  Asyncify calls this function a
			// second time when it restores the stack; the closure
			// passed to Asyncify.handleSleep() is only called the
			// first time, so all the work needs to be done in it.
			return Asyncify.handleSleep(function(resume) {

				// Can't yield recursively
				assert(!LiveCodeAsync._continuation);
				assert(!LiveCodeAsync._timeoutHandle);

				LiveCodeAsync._continuation = resume;

				// Make sure that we get restarted in time; if the
				// timout is negative, never timeout
				LiveCodeAsync._fromTimeout = false;
				if (timeout >= 0) {
					var event = setTimeout(LiveCodeAsync._resumeTimeout,
										   timeout);
					LiveCodeAsync._timeoutHandle = event;
				}
			});
		},

		// Test whether the engine is currently paused
		isPaused: function() {
			return (!!LiveCodeAsync._continuation);
		},

		// Test whether the engine can yield now.  Asyncify can only
		// save the engine's stack when nothing but the engine is on
		// it: not while its stack is already saved (a call into the
		// engine from a resume hook), and not when JavaScript that the
		// engine called has called back into the engine (a JavaScript
		// frame cannot be saved).
		canYield: function() {
			return Asyncify.state === Asyncify.State.Normal &&
				!Asyncify.currData &&
				Asyncify.exportCallStack.length === 1;
		},

		// Test whether the engine is currently being resumed from a
		// timeout.  Returns false if the resume is due to an event.
		isTimedOut: function() {
			LiveCodeAsync._ensureInit()
			return LiveCodeAsync._fromTimeout
		},

		// Add a closure to be run before the engine next resumes
		delay: function(delayed) {
			LiveCodeAsync._ensureInit();

			if (!LiveCodeAsync.isPaused()) {
				// Engine is live, just run the closure
				delayed();
			} else {
				LiveCodeAsync._preResume.push(delayed);
			}
		},

		// Run pre-resume hooks.
		_runHooks: function() {
			LiveCodeAsync._hooks.forEach(function (h) { h(); });
		},

		// Register a closure to be run before every resume.  If
		// <callback> is already in the list of hooks, does nothing.
		//
		// callback: closure taking no arguments.
		addResumeHook: function(callback) {
			LiveCodeAsync._ensureInit();

			// Make sure the same hook doesn't get registered twice
			if (LiveCodeAsync._hooks.some(function (h) {
				return (h === callback);
			})) {
				return;
			}

			LiveCodeAsync._hooks.push(callback);
		},

		// Remove a closure from the list of pre-resume hooks.  If
		// <callback> is not in the list of hooks, does nothing.
		removeResumeHook: function(callback) {
			LiveCodeAsync._ensureInit();

			// Find and remove the specified hook
			var numHooks = LiveCodeAsync._hooks.length;
			for (var i = 0; i < numHooks; i++) {
				if (LiveCodeAsync._hooks[i] === callback) {
					LiveCodeAsync._hooks.splice(i, 1);
				}
			}
		},
	},

	// Yield for up to <timeout> seconds
	MCEmscriptenAsyncYield__deps: ['$LiveCodeAsync'],
	MCEmscriptenAsyncYield__async: true,
	MCEmscriptenAsyncYield: function(timeout) {
		if (!isFinite(timeout)) {
			timeout = -1;
		}
		return LiveCodeAsync.pause(timeout*1000);
	},

	// Test whether the engine can yield now
	MCEmscriptenAsyncCanYield__deps: ['$LiveCodeAsync'],
	MCEmscriptenAsyncCanYield: function() {
		return LiveCodeAsync.canYield();
	},

	// Resume the engine on event
	MCEmscriptenAsyncResume__deps: ['$LiveCodeAsync'],
	MCEmscriptenAsyncResume: function() {
		LiveCodeAsync.resume();
	},

	// Delay a closure until the next time the engine resumes
	MCEmscriptenAsyncDelay__deps: ['$LiveCodeAsync'],
	MCEmscriptenAsyncDelay: function(delayed) {
		LiveCodeAsync.delay(delayed);
	},
});

/*
 * Local Variables:
 * tab-width: 4
 * indent-tabs-mode: t
 * End:
 */
