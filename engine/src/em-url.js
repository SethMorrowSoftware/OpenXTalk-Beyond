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

	$LiveCodeUrl__deps: ['$LiveCodeAsync', '$LiveCodeUtil'],
	$LiveCodeUrl: {
		// true if _ensureInit() has ever been run
		_initialised: false,

		_ensureInit: function() {
			// Make sure this only ever gets run once.
			if (LiveCodeUrl._initialised) {
				return;
			}
			LiveCodeUrl._initialised = true;
		},

		// ----------------------------------------------------------------
		// Wrappers for C++ functions
		// ----------------------------------------------------------------

		_postStatusStarted: function(callbackPtr, contextPtr) {
			Module.ccall('MCEmscriptenUrlCallbackStarted',
			             null,
			             ['number', // MCSystemUrlCallback p_callback,
			              'number'], // void *p_context
			             [callbackPtr, contextPtr]);
		},

		_postStatusProgress: function(loadedLength, totalLength,
		                              callbackPtr, contextPtr) {
			Module.ccall('MCEmscriptenUrlCallbackProgress',
			             null,
			             ['number', // uint32_t p_loaded_length
			              'number', // int32_t p_total_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [loadedLength, totalLength, callbackPtr, contextPtr]);
		},

		_postStatusFinished: function(data, callbackPtr, contextPtr) {
			// Copy the request data into the C++ heap as a byte array
			// FIXME maybe this needs a helper function in LiveCodeUtil
			var dataStack = new Uint8Array(data);
			var dataLength = dataStack.length;
			var dataPtr = Module._malloc(dataLength *
			                             dataStack.BYTES_PER_ELEMENT);
			var dataHeap = new Uint8Array(Module.HEAPU8.buffer, dataPtr,
			                              dataLength);
			dataHeap.set(dataStack);

			Module.ccall('MCEmscriptenUrlCallbackFinished',
			             null,
			             ['number', // const byte_t *p_data
			              'number', // uint32_t p_data_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [dataPtr, dataLength, callbackPtr, contextPtr]);

			Module._free(dataPtr);
		},

		_postStatusUploading: function(sentLength, callbackPtr, contextPtr) {
			Module.ccall('MCEmscriptenUrlCallbackUploading',
			             null,
			             ['number', // uint32_t p_sent_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [sentLength, callbackPtr, contextPtr]);
		},

		_postStatusUploaded: function(sentLength, callbackPtr, contextPtr) {
			Module.ccall('MCEmscriptenUrlCallbackUploaded',
			             null,
			             ['number', // uint32_t p_sent_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [sentLength, callbackPtr, contextPtr]);
		},

		// A response with an error status: the page the server sent,
		// then the error
		_postStatusHttpError: function(data, errorString,
		                               callbackPtr, contextPtr) {
			var dataStack = new Uint8Array(data);
			var dataLength = dataStack.length;
			var dataPtr = Module._malloc(dataLength *
			                             dataStack.BYTES_PER_ELEMENT);
			Module.HEAPU8.set(dataStack, dataPtr);
			var errorPtr = LiveCodeUtil.stringToUTF16(errorString);
			var errorLength = errorString.length;

			Module.ccall('MCEmscriptenUrlCallbackHttpError',
			             null,
			             ['number', // const byte_t *p_data
			              'number', // uint32_t p_data_length
			              'number', // const unichar_t *p_error
			              'number', // uint32_t p_error_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [dataPtr, dataLength, errorPtr, errorLength,
			              callbackPtr, contextPtr]);

			Module._free(dataPtr);
			Module._free(errorPtr);
		},

		_postStatusError: function(errorString, callbackPtr, contextPtr) {
			var errorPtr = LiveCodeUtil.stringToUTF16(errorString);
			var errorLength = errorString.length;

			Module.ccall('MCEmscriptenUrlCallbackError',
			             null,
			             ['number', // const unichar_t *p_error
			              'number', // uint32_t p_error_length
			              'number', // MCSystemUrlCallback p_callback
			              'number'], // void *p_context
			             [errorPtr, errorLength, callbackPtr, contextPtr]);

			Module._free(errorPtr);
		},

		// ----------------------------------------------------------------
		// Loading
		// ----------------------------------------------------------------

		load: function(urlPtr, urlLength,
		               headersPtr, headersLength,
		               timeout,
		               callbackPtr, contextPtr) {
			return LiveCodeUrl._request('GET',
			                            urlPtr, urlLength,
			                            headersPtr, headersLength,
			                            0, 0,
			                            timeout,
			                            callbackPtr, contextPtr);
		},

		// Start an HTTP request.  The engine follows it through the
		// callback: started, then the response's progress, data and
		// finish, or an error.  A post also reports its body as
		// uploaded when the response begins (upload progress events
		// would make every cross-origin post need a preflight
		// request).
		//
		// The engine stops following a put once its body is uploaded
		// (sysspec-url.cpp), so a put reports only that, when the
		// response arrives, or an error; nothing comes after either.
		_request: function(method,
		                   urlPtr, urlLength,
		                   headersPtr, headersLength,
		                   dataPtr, dataLength,
		                   timeout,
		                   callbackPtr, contextPtr) {

			var isPut = (method == "PUT");

			// Turn the url & headers into JavaScript strings
			var url = LiveCodeUtil.stringFromUTF16(urlPtr, urlLength);
			var headers = LiveCodeUtil.stringFromUTF16(headersPtr, headersLength);

			// Copy the body out of the engine's heap: the engine may
			// free it, and the heap may move, before it is sent.
			var body = null;
			if (method != "GET") {
				body = Module.HEAPU8.slice(dataPtr, dataPtr + dataLength);
			}

			// ---------- 1. Create request instance
			var xhr = new XMLHttpRequest();

			// ---------- 2. Install callbacks

			// There are some browsers and conditions in which neither
			// the "error", "abort" nor "load" handlers will be
			// dispatched.  Use the loadend handler as a fallback to
			// detect this case.
			var loadendHandler = function(e) {
				LiveCodeAsync.resume(function() {
					LiveCodeUrl._postStatusError("Request failed",
					                             callbackPtr,
					                             contextPtr);
				});
			};
			var clearLoadendHandler = function() {
				xhr.removeEventListener("loadend", loadendHandler, false);
			};
			xhr.addEventListener("loadend", loadendHandler, false);

			xhr.addEventListener("abort", function(e) {
				clearLoadendHandler();
				LiveCodeAsync.resume(function() {
					LiveCodeUrl._postStatusError("Request aborted",
					                             callbackPtr,
					                             contextPtr);
				});
			}, false);

			xhr.addEventListener("error", function(e) {
				clearLoadendHandler();
				LiveCodeAsync.resume(function() {
					LiveCodeUrl._postStatusError("Request failed",
					                             callbackPtr,
					                             contextPtr);
				});
			}, false);

			xhr.addEventListener("load", function(e) {
				clearLoadendHandler();
				LiveCodeAsync.resume(function() {
					// As on iOS and Android, a response with an error
					// status is an error, "<status> <reason>", that
					// comes after the page the server sent (which a put
					// does not follow)
					if (xhr.status >= 400) {
						var error = (xhr.status + " " +
						             LiveCodeUtil.httpReason(xhr)).trim();
						if (isPut) {
							LiveCodeUrl._postStatusError(error,
							                             callbackPtr,
							                             contextPtr);
						} else {
							LiveCodeUrl._postStatusHttpError(xhr.response,
							                                 error,
							                                 callbackPtr,
							                                 contextPtr);
						}
						return;
					}
					if (isPut) {
						LiveCodeUrl._postStatusUploaded(dataLength,
						                                callbackPtr,
						                                contextPtr);
						return;
					}
					LiveCodeUrl._postStatusFinished(xhr.response,
					                                callbackPtr,
					                                contextPtr);
				});
			}, false);

			xhr.addEventListener("loadstart", function(e) {
				LiveCodeAsync.resume(function() {
					LiveCodeUrl._postStatusStarted(callbackPtr,
					                               contextPtr);
				});
			}, false);

			if (method == "POST") {
				xhr.addEventListener("readystatechange", function(e) {
					if (xhr.readyState != XMLHttpRequest.HEADERS_RECEIVED) {
						return;
					}
					LiveCodeAsync.resume(function() {
						LiveCodeUrl._postStatusUploaded(dataLength,
						                                callbackPtr,
						                                contextPtr);
					});
				}, false);
			}

			if (!isPut) {
				xhr.addEventListener("progress", function(e) {
					var totalLength = -1;
					if (e.lengthComputable) {
						totalLength = e.total;
					}
					LiveCodeAsync.resume(function() {
						LiveCodeUrl._postStatusProgress(e.loaded,
						                                totalLength,
						                                callbackPtr,
						                                contextPtr);
					});
				}, false);
			}

			// ---------- 3. Set request parameters

			// Target URL
			xhr.open(method, url);

			// Headers
			//
			// Split each line in the request headers into a header
			// name and value.
			//
			// FIXME this isn't quite correct; we don't correctly
			// handle continuation lines in the headers text.
			var headerLines = headers.match(/[^\r\n]+/g);
			var hasContentType = false;
			// OXT-Beyond: the headers a page may not set (the Fetch
			// standard's forbidden request-headers). The browser sets
			// them itself, and refuses them with an error in the
			// console, so they are left out quietly, as the browser
			// would leave them out.
			var forbidden = /^(accept-charset|accept-encoding|access-control-request-headers|access-control-request-method|connection|content-length|cookie2?|date|dnt|expect|host|keep-alive|origin|referer|set-cookie|te|trailer|transfer-encoding|upgrade|via|proxy-.*|sec-.*)$/i;
			if (headerLines != null) {
				var numHeaders = headerLines.length;
				for (var i = 0; i < numHeaders; ++i) {
					// The name is everything before the first colon
					var re = /^([^:]*):(.*)$/;
					var headerFields = re.exec(headerLines[i]);
					var headerName = null;
					if (headerFields != null) {
						headerName = headerFields[1].trim();
					}
					if (headerName != null && forbidden.test(headerName)) {
						continue;
					}
					try {
						xhr.setRequestHeader(headerName,
						                     headerFields[2].trim());
					} catch (error) {
						console.log("Ignoring bad HTTP header '" +
						            headerLines[i] + "'");
						continue;
					}

					if (headerName.toLowerCase() == "content-type") {
						hasContentType = true;
					}
				}
			}

			// A post is a form's data unless the httpHeaders say
			// otherwise, as on the desktop.
			if (method == "POST" && !hasContentType) {
				xhr.setRequestHeader("Content-Type",
				                     "application/x-www-form-urlencoded");
			}

			// Timeout
			xhr.timeout = timeout * 1000;

			// We want an array buffer response (no string decoding
			// etc.)
			xhr.responseType = "arraybuffer";

			// ---------- 4. Execute request
			xhr.send(body);

			return true;
		},
	},

	// Start loading a URL
	//
	//   urlPtr, urlLength:         URL to be loaded
	//   headersPtr, headersLength: Custom request headers
	//   timeout:                   Socket timeout in milliseconds
	//   callbackPtr, contextPtr:   Callback for request status updates
	MCEmscriptenUrlLoad__deps: ['$LiveCodeUrl'],
	MCEmscriptenUrlLoad: function(urlPtr, urlLength,
	                              headersPtr, headersLength,
	                              timeout,
	                              callbackPtr, contextPtr) {

		return LiveCodeUrl.load(urlPtr, urlLength,
		                        headersPtr, headersLength,
		                        timeout,
		                        callbackPtr, contextPtr);
	},

	// Start posting data to a URL, or putting it at one
	//
	//   urlPtr, urlLength:         URL to send the data to
	//   headersPtr, headersLength: Custom request headers
	//   dataPtr, dataLength:       The data
	//   timeout:                   Socket timeout in seconds
	//   callbackPtr, contextPtr:   Callback for request status updates
	MCEmscriptenUrlPost__deps: ['$LiveCodeUrl'],
	MCEmscriptenUrlPost: function(urlPtr, urlLength,
	                              headersPtr, headersLength,
	                              dataPtr, dataLength,
	                              timeout,
	                              callbackPtr, contextPtr) {

		return LiveCodeUrl._request('POST',
		                            urlPtr, urlLength,
		                            headersPtr, headersLength,
		                            dataPtr, dataLength,
		                            timeout,
		                            callbackPtr, contextPtr);
	},

	MCEmscriptenUrlPut__deps: ['$LiveCodeUrl'],
	MCEmscriptenUrlPut: function(urlPtr, urlLength,
	                             headersPtr, headersLength,
	                             dataPtr, dataLength,
	                             timeout,
	                             callbackPtr, contextPtr) {

		return LiveCodeUrl._request('PUT',
		                            urlPtr, urlLength,
		                            headersPtr, headersLength,
		                            dataPtr, dataLength,
		                            timeout,
		                            callbackPtr, contextPtr);
	},
});

/*
 * Local Variables:
 * tab-width: 4
 * indent-tabs-mode: t
 * End:
 */
