/*                                                              -*-Javascript-*-

Copyright (C) 2003-2015 LiveCode Ltd.

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

	$LiveCodeEvents__deps: ['$LiveCodeAsync', '$LiveCodeDC', '$LiveCodeUtil', '$LiveCodeClipboard', '$LiveCodeDialog'],
	$LiveCodeEvents: {

		// true if ensureInit() has ever been run
		_initialised: false,

		// contains mouse event data
		_mouseEvent: null,

		// text element used to capture input events
		_inputelement: null,

		// current target of keyboard / input events
		_inputtarget: null,

		// This function is used to call a function for each event
		// type to handler mapping defined for LiveCode on Emscripten.
		//
		// The <func> must take two arguments: the event type, and the
		// handler function used to handle that event type.
		_eventForEach: function(func) {

			// Master mapping from event types to handler functions.
			var mapping = [
				['focus', LiveCodeEvents._handleFocusEvent],
				['blur', LiveCodeEvents._handleFocusEvent],

				['mousemove', LiveCodeEvents._handleMouseEvent],
				['mousedown', LiveCodeEvents._handleMouseEvent],
				['mouseup', LiveCodeEvents._handleMouseEvent],
				['mouseenter', LiveCodeEvents._handleMouseEvent],
				['mouseleave', LiveCodeEvents._handleMouseEvent],

				['contextmenu', LiveCodeEvents._handleContextMenu],

				['wheel', LiveCodeEvents._handleWheelEvent],

				['touchstart', LiveCodeEvents._handleTouchEvent],
				['touchmove', LiveCodeEvents._handleTouchEvent],
				['touchend', LiveCodeEvents._handleTouchEvent],
				['touchcancel', LiveCodeEvents._handleTouchEvent],
			];

			var mapLength = mapping.length;
			for (var i = 0; i < mapLength; i++) {
				func(mapping[i][0], mapping[i][1], mapping[i][2]);
			}
		},

		_inputEventForEach: function(pFunc) {
			var mapping = [
				['keyup', LiveCodeEvents._handleKeyboardEvent],
				['keydown', LiveCodeEvents._handleKeyboardEvent],

				['input', LiveCodeEvents._handleInput],
				['beforeinput', LiveCodeEvents._handleInput],

				['compositionstart', LiveCodeEvents._handleComposition],
				['compositionupdate', LiveCodeEvents._handleComposition],
				['compositionend', LiveCodeEvents._handleComposition],

				['copy', LiveCodeEvents._handleCopyEvent],
				['cut', LiveCodeEvents._handleCopyEvent],
				['paste', LiveCodeEvents._handlePasteEvent],
			];

			var mapLength = mapping.length;
			for (var i = 0; i < mapLength; i++) {
				pFunc(mapping[i][0], mapping[i][1]);
			}
		},

		addEventListeners: function(pElement)
		{
			// (not passive: the handlers stop what the browser would do)
			LiveCodeEvents._eventForEach(function(type, handler) {
				pElement.addEventListener(type, handler, {capture: true, passive: false});
			});

			// Make sure the canvas is treated as focusable...
			pElement.tabIndex = 0;

			// Force the canvas to use a normal mouse cursor by
			// default
			pElement.style.cursor = 'default';

			// A touch on a stack is the stack's: the browser neither
			// scrolls nor zooms the page for it
			pElement.style.touchAction = 'none';
		},
		
		removeEventListeners: function(pElement)
		{
			// Remove all of the event handlers
			LiveCodeEvents._eventForEach(function (type, handler) {
				pElement.removeEventListener(type, handler, true);
			});
		},
		
		initialize: function() {
			// Make sure this only ever gets run once
			if (LiveCodeEvents._initialised) {
				return;
			}

			LiveCodeEvents._isMac = /^(Mac|iPhone|iPad|iPod)/.test(navigator.platform || '');

			// Add document event listeners to track mouse events outside canvas
			document.addEventListener("mouseup", LiveCodeEvents._handleDocumentMouseEvent);
			document.addEventListener("mousemove", LiveCodeEvents._handleDocumentMouseEvent);
			window.addEventListener("blur", LiveCodeEvents._handleWindowBlur);
			// OXT-Beyond: a press on the page outside every stack's canvas
			// (_handlePressOutside()). In the capture phase, as a window's
			// frame stops its own presses; the mouse's too, for a browser
			// that sends no pointer events (_attachFrame(), em-dc.js).
			window.addEventListener("pointerdown", LiveCodeEvents._handlePressOutside, true);
			window.addEventListener("mousedown", LiveCodeEvents._handlePressOutside, true);

			// OXT-Beyond: drops from outside the page on the stacks'
			// windows (_handleDrop())
			document.addEventListener('dragenter', LiveCodeEvents._handleDrop);
			document.addEventListener('dragover', LiveCodeEvents._handleDrop);
			document.addEventListener('drop', LiveCodeEvents._handleDrop);
			
			// Create the hidden input element
			var tInput = document.createElement('input');
			tInput.type = 'text';
			tInput.style.position = 'fixed';
			tInput.style.display = 'block';
			tInput.style.zIndex = 0;
			tInput.style.opacity = 0;
			tInput.style.setProperty('left', '0px', 'important');
			tInput.style.setProperty('top', '0px', 'important');
			tInput.style.setProperty('width', '1px', 'important');
			tInput.style.setProperty('height', '1px', 'important');

			// OXT-Beyond: a touch screen's keyboard comes up for the
			// input only while an unlocked field has the focus
			// (setTextInput()), and types into the stacks what its keys
			// say: no corrections and no capitals of its own (the input is
			// emptied after each key, so each would start a sentence). Its
			// text is big enough that Safari does not zoom the page in to
			// it when it has the focus.
			tInput.style.setProperty('font-size', '16px', 'important');
			tInput.inputMode = 'none';
			tInput.autocomplete = 'off';
			tInput.setAttribute('autocorrect', 'off');
			tInput.setAttribute('autocapitalize', 'off');
			tInput.spellcheck = false;
			if (navigator.virtualKeyboard && 'virtualKeyboardPolicy' in tInput) {
				tInput.virtualKeyboardPolicy = 'manual';
			}

			LiveCodeEvents._inputelement = tInput;
			document.body.appendChild(tInput);

			LiveCodeEvents._inputEventForEach(function(type, handler) {
				tInput.addEventListener(type, handler);
			});

			// Add listener for changes to device pixel ratio
			LiveCodeEvents._watchDevicePixelRatio();

			// The screen is the browser's window: desktopChanged
			window.addEventListener('resize', LiveCodeEvents._handleScreenResize);

			LiveCodeEvents._initialised = true;
		},

		finalize: function() {
			if (!LiveCodeEvents._initialised) {
				return;
			}

			document.body.removeChild(LiveCodeEvents._inputelement);
			LiveCodeEvents._inputelements = null;

			LiveCodeEvents._initialised = false;;
		},
		
		_getStackForWindow: function(pWindow) {
			return Module.ccall('MCEmscriptenGetStackForWindow', 'number',
								['number'],
								[pWindow]);
		},
		
		_getStackForCanvas: function(pCanvas) {
			var window = LiveCodeDC.getWindowIDForCanvas(pCanvas);
			if (window == 0)
			{
				return null;
			}
			return LiveCodeEvents._getStackForWindow(window);
		},

		// True in a browser on a Mac (or an iPad), where Cmd is the
		// command key (set by initialize(): this object is built when
		// the engine is linked, with no browser around it)
		_isMac: false,

		// The modifier keys that are down, as the latest key, mouse or
		// wheel event of the page says (the shiftKey, the commandKey and
		// the like): 1 Shift, 2 Alt, 4 Ctrl, 8 Meta (Cmd on a Mac), 16
		// Caps Lock
		_modifierKeys: 0,

		// The keys that are down (the keysDown): {key_code: true}
		_keysDown: {},

		_trackModifiers: function(e) {
			if (typeof e.shiftKey != 'boolean') {
				return;
			}
			var keys = (e.shiftKey ? 1 : 0) | (e.altKey ? 2 : 0) |
				(e.ctrlKey ? 4 : 0) | (e.metaKey ? 8 : 0);
			if (e.getModifierState && e.getModifierState('CapsLock')) {
				keys |= 16;
			}
			LiveCodeEvents._modifierKeys = keys;
		},

		// The page lost the keyboard: the keys that are down go up for it.
		// OXT-Beyond: a drag ends there too, as the page may not hear its
		// button go up; and a menu that is open closes, as on the desktop
		// when another window is clicked: a click in a browser widget's
		// page or outside the page reaches no handler of this page, which
		// only loses the focus (_cancelMenu()).
		_handleWindowBlur: function() {
			LiveCodeEvents._cancelMenu();
			LiveCodeEvents._modifierKeys &= 16;
			LiveCodeEvents._keysDown = {};
			if (LiveCodeEvents._drag && !LiveCodeEvents._drag.cancel) {
				LiveCodeEvents._drag.cancel = LiveCodeEvents.kDragCancelLost;
				LiveCodeAsync.resume();
			}
		},

		// The engine's modifiers that are down (MCScreenDC::querymods()):
		// 1 shift, 2 alt, 4 its command key (Ctrl, or Cmd on a Mac), 8 its
		// other one (Meta, or Ctrl on a Mac), 16 caps lock
		getModifierKeys: function() {
			var keys = LiveCodeEvents._modifierKeys;
			if (LiveCodeEvents._isMac) {
				keys = (keys & ~12) | ((keys & 4) << 1) | ((keys & 8) >> 1);
			}
			return keys;
		},

		// The engine's modifiers. On a Mac, Cmd is the engine's command
		// (control) key and Ctrl its other one, as in the desktop engine
		// on a Mac, so that Cmd+C copies and the commandKey is Cmd.
		_encodeModifiers: function(pShift, pAlt, pCtrl, pMeta) {
			if (LiveCodeEvents._isMac) {
				var tCtrl = pCtrl;
				pCtrl = pMeta;
				pMeta = tCtrl;
			}
			return Module.ccall('MCEmscriptenEventEncodeModifiers', 'number',
								['number', 'number', 'number', 'number'],
								[pShift, pAlt, pCtrl, pMeta]);
		},

		// ----------------------------------------------------------------
		// Focus events
		// ----------------------------------------------------------------

		// OXT-Beyond: whether <stack> takes the user's mouse and keys: not
		// while a modal dialog is above it, as a disabled window takes none
		// on the desktop (MCEmscriptenStackIsEnabled(), em-dc.cpp)
		_stackEnabled: function(stack) {
			return !!stack && Module.ccall('MCEmscriptenStackIsEnabled', 'number',
										   ['number'], [stack]) != 0;
		},

		// OXT-Beyond: the keyboard goes to the stack of the window <to>
		// (to none if 0) when the stacks have it (<from> 0) or the window
		// <from> has it: the engine opened the window that the system
		// would make the active one, or closed the one that had the
		// keyboard. A page that has not given the stacks the keyboard
		// keeps it.
		passKeyboard: function(from, to) {
			var target = LiveCodeEvents._inputtarget;
			if (target == null)
				return;
			if (from != 0 && target !== LiveCodeDC.getWindowCanvas(from))
				return;
			var canvas = to != 0 ? LiveCodeDC.getWindowCanvas(to) : null;
			if (canvas !== target)
				LiveCodeEvents._setInputFocus(canvas);
		},

		// Wrapper for MCEventQueuePostKeyFocus()
		_postKeyFocus: function(stack, owner) {
			// OXT-Beyond: a stack under a modal dialog does not take the
			// keyboard
			if (owner && !LiveCodeEvents._stackEnabled(stack))
				return;
			Module.ccall('MCEventQueuePostKeyFocus',
						 'number', // bool
						 ['number',  // MCStack *stack
						  'number'], // bool owner
						 [stack, owner]);
		},

		// When a LC canvas acquires focus, mark it as the current key focus target, then pass focus to the hidden input field
		_setInputFocus: function(pTarget) {
			if (pTarget != LiveCodeEvents._inputtarget)
			{
				if (LiveCodeEvents._inputtarget != null)
				{
					var tOldTarget = LiveCodeEvents._inputtarget;
					LiveCodeEvents._inputtarget = null;
					LiveCodeEvents._postKeyFocus(LiveCodeEvents._getStackForCanvas(tOldTarget), false);
					tOldTarget.blur();
				}

				if (pTarget != null)
				{
					LiveCodeEvents._inputtarget = pTarget;
					LiveCodeEvents._postKeyFocus(LiveCodeEvents._getStackForCanvas(pTarget), true);
				}

				// OXT-Beyond: the window with the keyboard looks active
				// (em-dc.js)
				LiveCodeDC.setActiveWindow(LiveCodeDC.getWindowIDForCanvas(pTarget));
			}

			if (LiveCodeEvents._inputelement != null)
				LiveCodeEvents._inputelement.focus({"preventScroll": true});
		},

		_handleFocusEvent: function(e) {
			LiveCodeAsync.delay(function() {
				var stack = LiveCodeEvents._getStackForCanvas(e.target);

				// clear the current focus target when the hidden input field loses focus to a non-LC element.
				if (e.target == LiveCodeEvents._inputelement &&
					(e.type == 'blur' || e.type == 'focusout') &&
					LiveCodeEvents._getStackForCanvas(e.relatedTarget) == null)
				{
					LiveCodeEvents._setInputFocus(null);
					return;
				}

				// ignore events for non-lc elements
				if (!stack)
					return;

				switch (e.type) {
				case 'focus':
				case 'focusin':
					LiveCodeEvents._setInputFocus(e.target);
					break;
				case 'blur':
				case 'focusout':
					// ignore passing focus to hidden input field
					if (e.relatedTarget == LiveCodeEvents._inputelement)
						return;

					// if losing focus to another LC stack don't remove focus here, as focus will
					// be reassigned in the 'focusin' event sent to that stack canvas
					var tFocusStack = LiveCodeEvents._getStackForCanvas(e.relatedTarget);
					if (tFocusStack != null)
						return;

					LiveCodeEvents._setInputFocus(null);
					break;
				default:
					console.debug('Unexpected focus event type: ' + e.type);
					return;
				}
			});
			LiveCodeAsync.resume();

			// Prevent event from propagating
			return false;
		},

		// ----------------------------------------------------------------
		// Keyboard events
		// ----------------------------------------------------------------

		// Converts a string in the form 'U+xxxx' into a codepoint number
		_parseCodepointString: function(string) {
			var codepointString = string.match(/^U\+([0-9a-fA-F]+)$/);
			if (codepointString) {
				var codepointNum = parseInt(codepointString[1], 16);
				if (codepointNum > 0xff) {
					return 0x01000000 | codepointNum;
				} else if (codepointNum === 0x08 || codepointNum === 0x09 || codepointNum < 0x80) {
					return codepointNum;
				} else {
					// Values outside the range HT,BS,0x20-0x7f tend to depend
					// on the browser and aren't reliable
					return 0;
				}
			}
			return 0;
		},

		// Converts ASCII control characters to their X11 key equivalents
		// or returns zero if not a control
		_controlToX11Key: function(codepoint) {
			switch (codepoint) {
				case 0x0008:	// Horizontal tab
				case 0x0009:	// Backspace
					return 0xff00 + codepoint;

				case 0x007f:	// Delete
					return 0xffff;

				default:		// Unrecognised
					return 0;
			}
		},

		// Generate the char_code argument needed by
		// MCEventQueuePostKeyPress() from JavaScript's
		// KeyboardEvent.key.
		_encodeKeyboardCharCode: function(keyboardEvent) {
			// Not all browsers implement the KeyboardEvent interface fully;
			// we may have to fall back to an older interface if not defined
			var key, high, low;
			if ('key' in keyboardEvent) {
				key = keyboardEvent.key;
				high = key.charCodeAt(0);
				low = key.charCodeAt(1);
			} else {
				// Browser uses the old-style key events. Just take whatever
				// charCode it has supplied (if any!)
				if (keyboardEvent.charCode !== 0) {
					return keyboardEvent.charCode;
				} else {
					// Try parsing the keyIdentifier
					return LiveCodeEvents._parseCodepointString(keyboardEvent.keyIdentifier);
				}
			}

			// Check if there's actually a key code at all
			if (isNaN(high)) {
				return 0;
			}

			// If the first and only character in the key is a BMP
			// character, then use it as the char code.  If it's not
			// the only character, then the key must be a named key
			// (i.e. non-printing).
			if (0xD800 > high)
			{
				if (key.length == 1) {
					return high;
				} else {
					return 0;
				}
			}

			// If the first character is a high surrogate, and the
			// subsequent character is a low surrogate, then combine
			// them into a character code.  If the low surrogate is
			// missing, then assume the key must be a named key.
			if (0xD800 <= high && high <= 0xDBFF) {
				if (isNan(low)) {
					console.debug('High surrogate not followed by low surrogate');
					return 0;
				}
				if (key.length == 2) {
					return ((high - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
				} else {
					return 0;
				}
			}

			return 0;
		},

		// Generate the key_code argument needed by
		// MCEventQueuePostKeyPress() from JavaScript's
		// KeyboardEvent.key.
		_encodeKeyboardKeyCode: function(keyboardEvent) {
			// Synthesize a keycode from the char code, if the key event has a
			// corresponding char code.
			// FIXME Maybe this should be done in the engine?
			var char_code = LiveCodeEvents._encodeKeyboardCharCode(keyboardEvent);

			// Non-control Unicode codepoints in the ISO/IEC 8859-1 range
			// U+0020..U+00FF are passed directly as keycodes.
			// Otherwise, the codepoint is returned with bit 21 set.
			if (char_code >= 0x20) {
				if ((char_code >= 0x20 && char_code < 0x7f) || (char_code >= 0xa0 && char_code <= 0xff)) {
					return char_code;
				} else if (char_code > 0xff) {
					return char_code | 0x1000000;
				} else {
					// Control character -- handled below
				}
			}

			// If the 'key' property isn't defined, the old-style keyboard events
			// are being used and we need to convert any ASCII control characters
			// into the corresponding XK_ code
			if (!('key' in keyboardEvent) && char_code !== 0) {
				return LiveCodeEvents._controlToX11Key(char_code);
			}

			// String describing the key. This is stored in the 'key' property for
			// new-style key events and 'keyIdentifier' for old-style events.
			var keyName;
			if ('key' in keyboardEvent) {
				keyName = keyboardEvent.key;
			} else {
				keyName = keyboardEvent.keyIdentifier;
			}

			// Otherwise, decode to an X11 keycode
			// See also DOM Level 3 KeyboardEvent key Values
			// <https://w3c.github.io/DOM-Level-3-Events-key/#key-value-tables>
			//
			// Conforms to W3C Editor's Draft 27 April 2015
			//
			// Not all of these keycodes are actually understood by
			// the engine, but they're all included for completeness.
			// The modifier keys, left or right, as on Linux
			var right = keyboardEvent.location === 2;
			switch (keyName) {

				// Modifier Keys
			case 'Shift':    return right ? 0xffe2 : 0xffe1; // XK_Shift_R, XK_Shift_L
			case 'Control':  return right ? 0xffe4 : 0xffe3; // XK_Control_R, XK_Control_L
			case 'CapsLock': return 0xffe5; // XK_Caps_Lock
			case 'Meta':     return right ? 0xffe8 : 0xffe7; // XK_Meta_R, XK_Meta_L
			case 'Alt':      return right ? 0xffea : 0xffe9; // XK_Alt_R, XK_Alt_L

				// Special Key Values
			case 'Unidentified':	return 0;
			case 'Dead':			return 0; // Dead keys for IME composition

				// Whitespace Keys
			case 'Enter':     return 0xff0d; // XK_Return
			case 'Separator': return 0xffac; // XK_KP_Separator
			case 'Tab':       return 0xff09; // XK_Tab

				// Navigation Keys
			case 'Down':
			case 'ArrowDown':  return 0xff54; // XK_Down
			case 'Left':
			case 'ArrowLeft':  return 0xff51; // XK_Left
			case 'Right':
			case 'ArrowRight': return 0xff53; // XK_Right
			case 'Up':
			case 'ArrowUp':    return 0xff52; // XK_Up
			case 'End':        return 0xff57; // XK_End
			case 'Home':       return 0xff50; // XK_Home
			case 'PageDown':   return 0xff56; // XK_Page_Down
			case 'PageUp':     return 0xff55; // XK_Page_Up

				// Editing Keys
			case 'Backspace': return 0xff08; // XK_BackSpace
			case 'Clear':     return 0xff0b; // XK_Clear
			case 'Copy':      return 0x1008ff57; // GDK_KEY_Copy
			case 'CrSel':     break;
			case 'Cut':       return 0x1008ff58; // GDK_KEY_Cut
			case 'Delete':    return 0xffff; // XK_Delete
			case 'EraseEof':  break;
			case 'ExSel':     break;
			case 'Insert':    return 0xff63; // XK_Insert
			case 'Paste':     return 0x1008ff6d; // GDK_KEY_Paste
			case 'Redo':      return 0xff66; // XK_Redo
			case 'Undo':      return 0xff65; // XK_Undo

				// UI Keys
			case 'Accept':      break;
			case 'Again':       return 0xff66; // XK_Redo
			case 'Attn':        break;
			case 'Cancel':      return 0xff69; // XK_Cancel
			case 'ContextMenu': return 0xff67; // XK_Menu
			case 'Escape':      return 0xff1b; // XK_Escape
			case 'Execute':     return 0xff62; // XK_Execute
			case 'Find':        return 0xff68; // XK_Find
			case 'Help':        return 0xff6a; // XK_Help
			case 'Pause':       return 0xff13; // XK_Pause
			case 'Play':        break;
			case 'Props':       break;
			case 'Select':      return 0xff60; // XK_Select
			case 'ZoomIn':      return 0x1008ff8b; // GDK_KEY_ZoomIn
			case 'ZoomOut':     return 0x1008ff8c; // GDK_KEY_ZoomOut

				// Device Keys
			case 'BrightnessDown': return 0x1008ff03; // GDK_KEY_MonBrightnessDown
			case 'BrightnessUp':   return 0x1008ff02; // GDK_KEY_MonBrightnessUp
			case 'Camera':         break;
			case 'Eject':          return 0x1008ff2c; // GDK_KEY_Eject
			case 'LogOff':         return 0x1008ff61; // GDK_KEY_LogOff
			case 'Power':          break;
			case 'PowerOff':       return 0x1008ff2a; // GDK_KEY_PowerOff
			case 'PrintScreen':    return 0xff15; // XK_Sys_Req
			case 'Hibernate':      return 0x1008ffa8; // GDK_KEY_Hibernate
			case 'Standby':        return 0x1008ff10; // GDK_KEY_Standby
			case 'WakeUp':         return 0x1008ff2b; // GDK_KEY_WakeUp

				// IME and Composition Keys
			case 'AllCandidates':     return 0xff3d; // XK_MultipleCandidate
			case 'Alphanumeric':      return 0xff2f; // ?? XK_Eisu_Shift
			case 'CodeInput':         return 0xff37; // XK_Codeinput
			case 'Compose':           return 0xff20; // XK_Multi_key
			case 'Convert':           return 0xff23; // ?? XK_Henkan
			case 'Dead':              break;
			case 'FinalMode':         break;
			case 'GroupFirst':        return 0xfe0c; // XK_ISO_First_Group
			case 'GroupLast':         return 0xfe0e; // XK_ISO_Last_Group
			case 'GroupNext':         return 0xfe08; // XK_ISO_Next_Group
			case 'GroupPrevious':     return 0xfe0a; // XK_ISO_Prev_Group
			case 'ModeChange':        break;
			case 'NextCandidate':     break;
			case 'PreviousCandidate': return 0xff3c; // XK_PreviousCandidate
			case 'Process':           break;
			case 'SingleCandidate':   return 0xff3c; // XK_SingleCandidate

			case 'HangulMode':        return 0xff31; // XK_Hangul
			case 'HanjaMode':         break;
			case 'JunjaMode':         break;

			case 'Eisu':             return 0xff2f; // XK_Eisu_toggle
			case 'Hankaku':          return 0xff29; // XK_Hankaku
			case 'Hiragana':         return 0xff25; // XK_Hiragana
			case 'HiraganaKatakana': return 0xff27; // XK_Hiragana_Katakana
			case 'KanaMode':         return 0xff2d; // XK_Kana_Lock
			case 'KanjiMode':        return 0xff21; // XK_Kanji
			case 'Katakana':         return 0xff26; // XK_Katakana
			case 'Romaji':           return 0xff24; // XK_Romaji
			case 'Zenkaku':          return 0xff28; // XK_Zenkaku
			case 'ZenkakuHankaku':   return 0xff2a; // XK_Zenkaku_Hankaku

				// General-Purpose Function Keys
				//
				// F1..F12 etc. are handled separately, after this
				// switch statement.

				// Multimedia Keys
			case 'Close':              return 0x1008ff56; // GDK_KEY_Close
			case 'MailForward':        return 0x1008ff90; // GDK_KEY_MailForward
			case 'MailReply':          return 0x1008ff72; // GDK_KEY_Reply
			case 'MailSend':           return 0x1008ff7b; // GDK_KEY_Send
			case 'MediaPlayPause':     return 0x1008ff31; // GDK_KEY_AudioPause
			case 'MediaSelect':        return 0x1008ff32; // GDK_KEY_AudioMedia
			case 'MediaStop':          return 0x1008ff15; // GDK_KEY_AudioStop
			case 'MediaTrackNext':     return 0x1008ff17; // GDK_KEY_AudioNext
			case 'MediaTrackPrevious': return 0x1008ff16; // GDK_KEY_AudioPrev
			case 'New':                return 0x1008ff68; // GDK_KEY_New
			case 'Open':               return 0x1008ff6b; // GDK_KEY_Open
			case 'Print':              break;
			case 'Save':               return 0x1008ff77; // GDK_KEY_Save
			case 'SpellCheck':         return 0x1008ff7c; // GDK_KEY_Spell
			case 'VolumeDown':         return 0x1008ff13; // GDK_KEY_AudioRaiseVolume
			case 'VolumeUp':            return 0x1008ff11; // GDK_KEY_AudioLowerVolume
			case 'VolumeMute':          return 0x1008ff12; // GDK_KEY_AudioMute

				// Application Keys
			case 'LaunchCalculator':    return 0x1008ff1d; // GDK_KEY_Calculator
			case 'LaunchCalendar':      return 0x1008ff20; // GDK_KEY_Calendar
			case 'LaunchMail':          return 0x1008ff19; // GDK_KEY_Mail
			case 'LaunchMediaPlayer':   return 0x1008ff53; // GDK_KEY_CD
			case 'LaunchMusicPlayer':   return 0x1008ff92; // GDK_KEY_Music
			case 'LaunchMyComputer':    return 0x1008ff33; // GDK_KEY_MyComputer
			case 'LaunchScreenSaver':   return 0x1008ff2d; // GDK_KEY_ScreenSaver
			case 'LaunchSpreadsheet':   return 0x1008ff5c; // GDK_KEY_Excel
			case 'LaunchWebBrowser':    return 0x1008ff2e; // GDK_KEY_WWW
			case 'LaunchWebCam':        return 0x1008ff8f; // GDK_KEY_WebCam
			case 'LaunchWordProcessor': return 0x1008ff89; // GDK_KEY_Word

				// Browser Keys
			case 'BrowserBack':      return 0x1008ff26; // GDK_KEY_Back
			case 'BrowserFavorites': return 0x1008ff30; // GDK_KEY_Favorites
			case 'BrowserForward':   return 0x1008ff27; // GDK_KEY_Forward
			case 'BrowserHome':      return 0x1008ff18; // GDK_KEY_HomePage
			case 'BrowserRefresh':   return 0x1008ff29; // GDK_KEY_Refresh
			case 'BrowserSearch':    return 0x1008ff1b; // GDK_KEY_Search
			case 'BrowserStop':      return 0x1008ff28; // GDK_KEY_Stop

				// Media Controller keys
				//
				// FIXME not supported

			default: break;
			}

			// General-Purpose Function keys
			var functionKey = keyName.match(/^F(\d+)$/);
			if (functionKey) {
				var functionNum = parseInt(functionKey[1]);
				if (functionNum >= 1 && functionNum <= 35) {
					return 0xffbd + functionNum; // XK_F...
				}
			}

			// Keys with Unicode codepoint names (U+xxxx)
			var codepoint = LiveCodeEvents._parseCodepointString(keyName);
			if (codepoint !== 0) {
				// Is this a control character?
				if (codepoint < 0x20 || codepoint === 0x7f) {
					return LiveCodeEvents._controlToX11Key(codepoint);
				} else {
					return codepoint;
				}
			}

			return 0;
		},

		// Wrapper for MCEventQueuePostKeyPress()
		_postKeyPress: function(stack, modifiers, char_code, key_code, key_state) {
			// OXT-Beyond: none for a stack under a modal dialog
			if (!LiveCodeEvents._stackEnabled(stack))
				return;
			Module.ccall('MCEventQueuePostKeyPress',
						 'number', // bool
						 ['number',  // MCStack *stack
						  'number',  // uint32_t modifiers
						  'number',  // uint32_t char_code
						  'number', // uint32_t key_code
						  'number'], // MCEventKeyState key_state
						 [stack, modifiers, char_code, key_code, key_state]);
		},

		// True if the key is the command key's (Cmd on a Mac, else Ctrl)
		// with <e>, without Alt (Ctrl+Alt is AltGr, which types)
		_isCommandKey: function(e) {
			return (LiveCodeEvents._isMac ? e.metaKey : e.ctrlKey) && !e.altKey;
		},

		// The command key's shortcuts that the browser keeps: reload, new
		// tab or window, close, quit and the address bar
		_browserKeys: {'r': true, 't': true, 'w': true, 'n': true, 'q': true, 'l': true},

		// True if the browser should not act on the key itself, so that
		// it goes to the stacks alone, as on the desktop: Tab (which would
		// take the keyboard out of the stacks), the page keys (which would
		// scroll the page) and the command key's shortcuts. Copy, cut and
		// paste keep the browser's action, for its clipboard events, and
		// so do the browser's own shortcuts and its developer tools.
		_keepFromBrowser: function(e) {
			if (e.key == 'Tab' || e.key == 'PageUp' || e.key == 'PageDown') {
				return true;
			}
			if (!LiveCodeEvents._isCommandKey(e) || typeof e.key != 'string' || e.key.length != 1) {
				return false;
			}
			var key = e.key.toLowerCase();
			if (key < 'a' || key > 'z' || key == 'c' || key == 'x' || key == 'v' ||
				LiveCodeEvents._browserKeys[key]) {
				return false;
			}
			if (e.shiftKey && (key == 'i' || key == 'j')) {
				return false;
			}
			return true;
		},

		// The paste key (Ctrl+V, Cmd+V), held back until the paste event
		// that follows it has put what is pasted on the engine's
		// clipboard: {'event', 'timer'}
		_heldPaste: null,

		// Keys pressed with Cmd on a Mac, whose keyup the browser does not
		// send while Cmd is down: they go up with Cmd. {key_code: [stack,
		// char_code]}
		_commandKeysDown: {},

		_handleKeyboardEvent: function(e) {
			// OXT-Beyond: the text that a key the stacks get types into the
			// input is theirs already (_handleInput())
			LiveCodeEvents._keyTyped = e.type == 'keydown' && !(e.isComposing || e.keyCode === 229);

			// ignore key events during IME composing
			if (e.isComposing || e.keyCode === 229)
				return false;

			LiveCodeEvents._trackModifiers(e);
			var code = LiveCodeEvents._encodeKeyboardKeyCode(e);
			if (code !== 0) {
				if (e.type == 'keydown') {
					LiveCodeEvents._keysDown[code] = true;
				} else if (e.type == 'keyup') {
					delete LiveCodeEvents._keysDown[code];
				}
			}

			// OXT-Beyond: in a drag the keys are the drag's, as in a
			// desktop's drag loop: Escape cancels it, and the modifier
			// keys (tracked above) can change what a drop would do
			if (LiveCodeEvents._drag) {
				if (e.type == 'keydown' && e.key == 'Escape' &&
					!LiveCodeEvents._drag.cancel) {
					LiveCodeEvents._drag.cancel = LiveCodeEvents.kDragCancelEscape;
				}
				e.preventDefault();
				LiveCodeAsync.resume();
				return false;
			}

			if (e.type == 'keydown' && LiveCodeEvents._keepFromBrowser(e)) {
				e.preventDefault();
			}

			var key = typeof e.key == 'string' ? e.key.toLowerCase() : '';
			var command = LiveCodeEvents._isCommandKey(e);
			if (e.type == 'keydown' && command && (key == 'c' || key == 'x')) {
				// a copy event after this key takes what the engine copies
				LiveCodeClipboard.beginKey();
			}

			// Hold the paste key back for its paste event; not for long,
			// as there is none if the browser has nothing to paste
			if (e.type == 'keydown' && command && key == 'v' && !e.repeat) {
				LiveCodeEvents._releaseHeldPaste();
				var held = {'event': e, 'timer': null};
				held.timer = setTimeout(function() {
					if (LiveCodeEvents._heldPaste === held) {
						LiveCodeEvents._releaseHeldPaste();
					}
				}, 300);
				LiveCodeEvents._heldPaste = held;
				return false;
			}

			// The keys after it (its keyup) follow it
			LiveCodeEvents._releaseHeldPaste();

			LiveCodeEvents._postKeyboardEvent(e);
			LiveCodeAsync.resume();

			return false;
		},

		_releaseHeldPaste: function() {
			var held = LiveCodeEvents._heldPaste;
			if (!held) {
				return;
			}
			LiveCodeEvents._heldPaste = null;
			clearTimeout(held.timer);
			LiveCodeEvents._postKeyboardEvent(held.event);
			LiveCodeAsync.resume();
		},

		_postKeyboardEvent: function(e) {
			LiveCodeAsync.delay(function() {

				const kKeyStateDown = 0;
				const kKeyStateUp = 1;
				const kKeyStatePressed = 2;

				var stack = LiveCodeEvents._getStackForCanvas(LiveCodeEvents._inputtarget);
				/* TODO - reenable alt key detection
				 * As there is no direct way to tell the difference between an alt+<key>
				 * combination that produces a different character, and holding alt down
				 * while typing that character directly, for now we ignore the state of
				 * the alt key so that typing such characters is possible.
				 */
				var mods = LiveCodeEvents._encodeModifiers(e.shiftKey, false, e.ctrlKey, e.metaKey);

				// Ignore alt key presses
				if (e.key == 'Alt')
					return;

				// ignore events for non-lc elements
				if (!stack)
					return;

				var char_code, key_code;
				switch (e.type) {
				case 'keyup':
					char_code = LiveCodeEvents._encodeKeyboardCharCode(e);
					key_code = LiveCodeEvents._encodeKeyboardKeyCode(e);
					LiveCodeEvents._postKeyPress(stack, mods, char_code, key_code, kKeyStateUp);
					delete LiveCodeEvents._commandKeysDown[key_code];

					// Cmd goes up: so do the keys pressed with it
					if (e.key == 'Meta' && LiveCodeEvents._isMac) {
						var down = LiveCodeEvents._commandKeysDown;
						LiveCodeEvents._commandKeysDown = {};
						Object.keys(down).forEach(function(code) {
							delete LiveCodeEvents._keysDown[code];
							LiveCodeEvents._postKeyPress(down[code][0], mods, down[code][1], Number(code), kKeyStateUp);
						});
					}
					break;
				case 'keydown':
					char_code = LiveCodeEvents._encodeKeyboardCharCode(e);
					key_code = LiveCodeEvents._encodeKeyboardKeyCode(e);

					// post synthetic keyup event if this is a repeat (i.e. held down) key event
					if (e.repeat)
						LiveCodeEvents._postKeyPress(stack, mods, char_code, key_code, kKeyStateUp);

					LiveCodeEvents._postKeyPress(stack, mods, char_code, key_code, kKeyStateDown);

					if (e.metaKey && e.key != 'Meta' && LiveCodeEvents._isMac) {
						LiveCodeEvents._commandKeysDown[key_code] = [stack, char_code];
					}
					break;
				default:
					return;
				}

				// Clear text input field after capturing key event
				LiveCodeEvents._inputelement.value = "";
			});
		},

		// ----------------------------------------------------------------
		// Clipboard events
		// ----------------------------------------------------------------

		_handleCopyEvent: function(e) {
			LiveCodeClipboard.handleCopy(e);
		},

		_handlePasteEvent: function(e) {
			var held = LiveCodeEvents._heldPaste;
			if (held) {
				// the paste event is here: no need for the timer
				clearTimeout(held.timer);
			}
			LiveCodeClipboard.handlePaste(e, function() {
				if (held) {
					if (LiveCodeEvents._heldPaste === held) {
						LiveCodeEvents._releaseHeldPaste();
					}
				} else {
					// The browser's Paste (from its menu): the engine
					// pastes with its paste key
					LiveCodeEvents._postPasteKey();
				}
			});
		},

		_postPasteKey: function() {
			LiveCodeAsync.delay(function() {
				var stack = LiveCodeEvents._getStackForCanvas(LiveCodeEvents._inputtarget);
				if (!stack)
					return;
				var mods = LiveCodeEvents._encodeModifiers(false, false, !LiveCodeEvents._isMac, LiveCodeEvents._isMac);
				var kKeyStatePressed = 2;
				LiveCodeEvents._postKeyPress(stack, mods, 0x76, 0x76, kKeyStatePressed);
			});
			LiveCodeAsync.resume();
		},

		// ----------------------------------------------------------------
		// Input events
		// ----------------------------------------------------------------

		_postImeCompose: function(stack, enabled, offset, chars, length) {
			// OXT-Beyond: none for a stack under a modal dialog
			if (!LiveCodeEvents._stackEnabled(stack))
				return;
			Module.ccall('MCEventQueuePostImeCompose',
						 'number',	/* bool */
						 ['number',	/* MCStack* stack */
						 'number',	/* bool enabled */
						 'number',	/* uindex_t offset */
						 'number',	/* unichar_t* chars */
						 'number'],	/* uindex_t char_count */
						 [stack, enabled, offset, chars, length]);
		},

		// OXT-Beyond: whether the last key down went to the stacks
		_keyTyped: false,

		// OXT-Beyond: text that comes with no key the stacks get: a touch
		// screen's keyboard (whose keys are "Unidentified"), dictation or
		// an emoji picker. The stacks get it a character at a time, as keys
		// that type it, as a phone's engine gives them what its keyboard
		// types; a key that the stacks got typed its own text, and a
		// composition's text goes as an IME's (_handleComposition()). A
		// correction, which would replace text that the input no longer
		// has, is not typed.
		_handleInput: function(inputEvent) {
			var input = LiveCodeEvents._inputelement;
			if (inputEvent.type == 'input') {
				// The input keeps no text but a composition's
				if (!inputEvent.isComposing && input && inputEvent.target == input) {
					input.value = '';
				}
				return;
			}

			var typed = LiveCodeEvents._keyTyped;
			LiveCodeEvents._keyTyped = false;
			if (typed || inputEvent.isComposing) {
				return;
			}

			var kKeyStatePressed = 2;
			var keys = [];
			switch (inputEvent.inputType) {
			case 'insertText':
				Array.from(inputEvent.data || '').forEach(function(ch) {
					var code = ch.codePointAt(0);
					if (code == 0x0a || code == 0x0d) {
						keys.push([0, 0xff0d]);
					} else if (code == 0x09) {
						keys.push([0, 0xff09]);
					} else if (code >= 0x20 && code < 0x7f || code >= 0xa0 && code <= 0xff) {
						keys.push([code, code]);
					} else if (code > 0xff) {
						keys.push([code, code | 0x1000000]);
					}
				});
				break;
			case 'insertLineBreak':
			case 'insertParagraph':
				keys.push([0, 0xff0d]);
				break;
			case 'deleteContentBackward':
				keys.push([0, 0xff08]);
				break;
			case 'deleteContentForward':
				keys.push([0, 0xffff]);
				break;
			default:
				return;
			}
			if (keys.length == 0) {
				return;
			}

			LiveCodeAsync.delay(function() {
				var stack = LiveCodeEvents._getStackForCanvas(LiveCodeEvents._inputtarget);
				if (!stack) {
					return;
				}
				keys.forEach(function(key) {
					LiveCodeEvents._postKeyPress(stack, 0, key[0], key[1], kKeyStatePressed);
				});
			});
			LiveCodeAsync.resume();
		},

		// OXT-Beyond: a touch screen's keyboard, which comes up while an
		// unlocked field has the focus, as on a phone: the engine says
		// when (MCScreenDC::activateIME(), em-dc.cpp). A browser brings
		// the keyboard up only for a touch that has ended (or a key or a
		// click), so it comes up when the next touch ends (_touchEnded()):
		// at the end of the touch that put the focus in the field, or of
		// the first touch after a script did. A mouse click brings up none:
		// a computer with a mouse and a touch screen has a keyboard too.
		_textInput: false,
		_keyboardShown: false,

		setTextInput: function(active) {
			var input = LiveCodeEvents._inputelement;
			if (!input || active == LiveCodeEvents._textInput) {
				return;
			}
			LiveCodeEvents._textInput = active;
			LiveCodeEvents._keyboardShown = false;
			input.inputMode = active ? 'text' : 'none';
			if (!active) {
				LiveCodeEvents._keyboard(false);
			}
		},

		// Brings up or puts away a touch screen's keyboard for the input:
		// with the VirtualKeyboard API (Chrome), or by focusing the input
		// again, which brings up the keyboard of its inputmode
		_keyboard: function(show) {
			var input = LiveCodeEvents._inputelement;
			if (!input || document.activeElement !== input || !navigator.maxTouchPoints) {
				return;
			}
			if (input.virtualKeyboardPolicy == 'manual') {
				if (show) {
					navigator.virtualKeyboard.show();
				} else {
					navigator.virtualKeyboard.hide();
				}
				return;
			}
			input.blur();
			input.focus({preventScroll: true});
		},

		// A touch ended: the keyboard comes up, if a field has the focus.
		// The VirtualKeyboard API brings it up again after each touch (it
		// may have been put away, and it does not flicker); focusing the
		// input again brings it up once.
		_touchEnded: function() {
			var input = LiveCodeEvents._inputelement;
			if (LiveCodeEvents._textInput && input &&
				(!LiveCodeEvents._keyboardShown || input.virtualKeyboardPolicy == 'manual')) {
				LiveCodeEvents._keyboardShown = true;
				LiveCodeEvents._keyboard(true);
			}
		},

		_stringToUTF16: function(string) {
			var buffer = LiveCodeUtil.stringToUTF16(string);
			return [buffer, string.length];
		},

		_handleComposition: function(compositionEvent) {
			LiveCodeAsync.delay(function() {
				// Stack that we're targeting
				var stack = LiveCodeEvents._getStackForCanvas(LiveCodeEvents._inputtarget);

				// ignore events for non-lc elements
				if (!stack)
					return;

				var encodedString;
				var chars, length;
				switch (compositionEvent.type) {
					case 'compositionstart':
					case 'compositionupdate':
						encodedString = LiveCodeEvents._stringToUTF16(compositionEvent.data);
						chars = encodedString[0];
						length = encodedString[1];
						LiveCodeEvents._postImeCompose(stack, true, 0, chars, length);
						_free(chars);
						break;
					case 'compositionend':
						encodedString = LiveCodeEvents._stringToUTF16(compositionEvent.data);
						chars = encodedString[0];
						length = encodedString[1];
						LiveCodeEvents._postImeCompose(stack, false, 0, chars, length);
						_free(chars);

						// Clear text input field once composition ends
						LiveCodeEvents._inputelement.value = "";
						break;
					default:
						console.debug('Unexpected composition event type: ' + compositionEvent.type)
						return;
				}
			});
			LiveCodeAsync.resume();

			// Preventing the IME event from propogating cancels the IME, so don't do that
			return false;
		},

		// ----------------------------------------------------------------
		// Mouse events
		// ----------------------------------------------------------------

		// Encode a mouse state using enum MCMousePressState.  You
		// need to update this code if you change the enumeration...
		_encodeMouseState: function(state) {
			switch (state) {
			case 'mouseup':
				return 0; /* kMCMousePressStateUp */
			case 'mousedown':
				return 1; /* kMCMousePressStateDown */
			default:
				return 2; /* kMCMousePressStateRelease */
			}
		},

		// Convert event coordinates to logical coordinates -- these
		// are in units of CSS pixels relative to the top left of the
		// target
		_encodeMouseCoordinates: function(mouseEvent) {
			var target = LiveCodeEvents._eventTarget(mouseEvent);
			var x = mouseEvent.clientX - target.getBoundingClientRect().left -
				target.clientLeft + target.scrollLeft;
			var y = mouseEvent.clientY - target.getBoundingClientRect().top -
				target.clientTop + target.scrollTop;

			return [x, y];
		},

		// Wrapper for MCEmscriptenHandleMousePosition
		_postMousePosition: function(stack, time, modifiers, x, y) {
			Module.ccall('MCEmscriptenHandleMousePosition',
						 'number', /* bool */
						 ['number', /* MCStack *stack */
						  'number', /* uint32_t time */
						  'number', /* uint32_t modifiers */
						  'number', 'number'], /* uint32_t x, y */
						 [stack, time, modifiers, x, y]);
		},

		// Wrapper for MCEmscriptenHandleMousePress
		_postMousePress: function(stack, time, modifiers, state, button)
		{
			Module.ccall('MCEmscriptenHandleMousePress',
						 'number', /* bool */
						 ['number', /* MCStack *stack */
						  'number', /* uint32_t time */
						  'number', /* uint32_t modifiers */
						  'number', /* MCMousePressState state */
						  'number'], /* int32_t button */
						 [stack, time, modifiers, state, button]);
		},

		// Wrapper for MCEventQueuePostMouseFocuse
		_postMouseFocus: function(stack, time, inside)
		{
			// OXT-Beyond: none for a stack under a modal dialog
			// (MCEmscriptenHandleMousePosition() and
			// MCEmscriptenHandleMousePress() drop its others)
			if (!LiveCodeEvents._stackEnabled(stack))
				return;
			Module.ccall('MCEventQueuePostMouseFocus',
						 'number', /* bool */
						 ['number', /* MCStack *stack */
						  'number', /* uint32_t time */
						  'number'], /* bool inside */
						 [stack, time, inside]);
		},

		// target for redirected mouse events
		_captureTarget: null,
		
		// Redirect mouse events to the specified target element
		_captureFocus: function(element) {
			LiveCodeEvents._captureTarget = element;
		},
		
		// End mouse event redirection
		_releaseFocus: function() {
			LiveCodeEvents._captureTarget = null;
		},
		
		// Return the target to which mouse events are dispatched
		_eventTarget: function(event) {
			if (event.type == "mousedown" || LiveCodeEvents._captureTarget == null)
				return event.target;
			else
				return LiveCodeEvents._captureTarget;
		},
		
		_handleMouseEvent: function(e) {
			LiveCodeEvents._trackModifiers(e);
			LiveCodeEvents._trackPointer(e);
			LiveCodeAsync.delay(function () {

				var target = LiveCodeEvents._eventTarget(e);
				var stack = LiveCodeEvents._getStackForCanvas(target);
				var mods = LiveCodeEvents._encodeModifiers(e.shiftKey, e.altKey, e.ctrlKey, e.metaKey);
				var pos = LiveCodeEvents._encodeMouseCoordinates(e);

				// ignore events for non-lc elements
				if (!stack)
					return;

				switch (e.type) {
				case 'mousemove':
					LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
					return;

				case 'mousedown':
					// In the case of mouse down, specifically request
					// keyboard focus. OXT-Beyond: the stack's window comes
					// to the front of its layer too, as a click brings a
					// window to the front on the desktop (em-dc.js); not
					// for a stack under a modal dialog, whose press goes
					// nowhere.
					if (LiveCodeEvents._stackEnabled(stack))
					{
						LiveCodeDC.raiseWindow(LiveCodeDC.getWindowIDForCanvas(target));
						LiveCodeEvents._setInputFocus(target);
					}

					LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
					var state = LiveCodeEvents._encodeMouseState(e.type);
					LiveCodeEvents._postMousePress(stack, e.timeStamp, mods,
												   state, e.button);
					
					// Redirect mouse events to this canvas while the mouse is down
					LiveCodeEvents._captureFocus(e.target);
					
					break;

				case 'mouseup':
					LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
					var state = LiveCodeEvents._encodeMouseState(e.type);
					LiveCodeEvents._postMousePress(stack, e.timeStamp, mods,
												   state, e.button);
					
					// change mouse focus if event target is different from captured target
					var refocus = target != e.target;
					if (refocus)
						LiveCodeEvents._postMouseFocus(stack, e.timeStamp, false);
					
					LiveCodeEvents._releaseFocus();
					
					if (refocus)
					{
						var stack = LiveCodeEvents._getStackForCanvas(e.target);
						var pos = LiveCodeEvents._encodeMouseCoordinates(e);
						if (stack)
						{
							LiveCodeEvents._postMouseFocus(stack, e.timeStamp, true);
							LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
						}
					}
					
					break;

				case 'mouseenter':
					// Don't send window focus events while capturing mouse events
					if (LiveCodeEvents._captureTarget == null)
					{
						LiveCodeEvents._postMouseFocus(stack, e.timeStamp, true);
						LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
					}
					break;

				case 'mouseleave':
					// Don't send window focus events while capturing mouse events
					if (LiveCodeEvents._captureTarget == null)
					{
						LiveCodeEvents._postMousePosition(stack, e.timeStamp, mods, pos[0], pos[1]);
						LiveCodeEvents._postMouseFocus(stack, e.timeStamp, false);
					}
					break;

				default:
					return;
				}

			});
			LiveCodeAsync.resume();

			// Prevent event from propagating
			e.preventDefault();
			return false;
		},

		// The wheel's movement not yet given to the engine, in pixels
		_wheel: {'x': 0, 'y': 0},

		// One click of a mouse's wheel, in pixels (Chrome's and Edge's
		// deltaY for one; Firefox's three lines are about as much)
		_wheelStep: 100,

		// The wheel scrolls the field or group under the mouse, as on the
		// desktop: the engine gets one wheel key (XK_WheelDown ...) per
		// click of the wheel, and a trackpad's small moves add up to one.
		// The engine's movements are the other way round from the page's,
		// as a Mac's are: a positive dv (XK_WheelDown, rawKeyDown 65309)
		// shows what is above, where a positive deltaY shows what is below.
		_handleWheelEvent: function(e) {
			LiveCodeEvents._trackModifiers(e);
			var scale = e.deltaMode == 1 ? 40 : (e.deltaMode == 2 ? 800 : 1);
			var wheel = LiveCodeEvents._wheel;
			var step = LiveCodeEvents._wheelStep;

			// a change of direction starts again
			if (e.deltaX * wheel.x < 0)
				wheel.x = 0;
			if (e.deltaY * wheel.y < 0)
				wheel.y = 0;
			wheel.x += e.deltaX * scale;
			wheel.y += e.deltaY * scale;

			var clicks = [];
			while (Math.abs(wheel.y) >= step) {
				var down = wheel.y > 0 ? 1 : -1;
				wheel.y -= down * step;
				clicks.push([0, -down]);
			}
			while (Math.abs(wheel.x) >= step) {
				var right = wheel.x > 0 ? 1 : -1;
				wheel.x -= right * step;
				clicks.push([-right, 0]);
			}

			// The page does not scroll under the stacks
			e.preventDefault();

			if (clicks.length == 0)
				return false;

			var target = e.target;
			LiveCodeAsync.delay(function() {
				var stack = LiveCodeEvents._getStackForCanvas(target);
				if (!stack)
					return;
				var mods = LiveCodeEvents._encodeModifiers(e.shiftKey, e.altKey, e.ctrlKey, e.metaKey);
				clicks.forEach(function(click) {
					Module.ccall('MCEmscriptenHandleMouseWheel', 'number',
								 ['number', 'number', 'number', 'number', 'number'],
								 [stack, e.timeStamp, mods, click[0], click[1]]);
				});
			});
			LiveCodeAsync.resume();
			return false;
		},
		
		// OXT-Beyond: the mouse went down outside every stack's canvas:
		// on the page around the windows, on a window's frame or on a
		// native layer. A canvas's own press goes to the engine
		// (_handleMouseEvent()), which gives it to the menu that is open;
		// this one reaches no stack, so a menu that is open closes, as a
		// click outside a menu closes it on the desktop (_cancelMenu()).
		_handlePressOutside: function(e) {
			if (LiveCodeDC.getWindowIDForCanvas(e.target) != 0) {
				return;
			}
			LiveCodeEvents._cancelMenu();
		},

		// OXT-Beyond: the menu that is open, if one is, closes with no
		// menuPick (MCEmscriptenHandleMenuCancel()). Both a pointer's press
		// and the mouse's may come for one click: the second finds no menu.
		_cancelMenu: function() {
			LiveCodeAsync.delay(function() {
				Module.ccall('MCEmscriptenHandleMenuCancel',
							 'number', /* bool */
							 [], []);
			});
			LiveCodeAsync.resume();
		},

		// Document mouse event handler - redirects to target element when capturing mouse events
		_handleDocumentMouseEvent: function(e) {
			if (LiveCodeEvents._captureTarget) {
				LiveCodeEvents._handleMouseEvent(e);
			}
		},

		// ----------------------------------------------------------------
		// Drag and drop
		// ----------------------------------------------------------------

		// OXT-Beyond: a drag that the engine started follows the mouse
		// until its button goes up (MCScreenDC::dodragdrop(), em-dc.cpp).
		// Meanwhile the keys are the drag's, the cursor says what a drop
		// would do, and the drag's image follows the pointer.

		// Where the pointer is in the page's viewport: [clientX, clientY]
		_pointer: null,

		// The drag, or null: {'cancel', 'image', 'xoffset', 'yoffset',
		// 'style', 'cursor'}. Its image is a canvas, if it has one, whose
		// top left is xoffset, yoffset from the pointer; its style makes
		// the cursor over the whole page the drag's.
		_drag: null,

		// Why a drag was cancelled: Escape (its button is still down), or
		// the page lost the mouse
		kDragCancelEscape: 1,
		kDragCancelLost: 2,

		// The cursors that say what a drop would do: none, then the
		// engine's drag actions (uidc.h): move, copy and link
		_dragCursors: {0: 'no-drop', 1: 'grabbing', 2: 'copy', 4: 'alias'},

		_trackPointer: function(e) {
			if (typeof e.clientX != 'number') {
				return;
			}
			LiveCodeEvents._pointer = [e.clientX, e.clientY];
			var drag = LiveCodeEvents._drag;
			if (drag && drag.image) {
				drag.image.style.left = (e.clientX - drag.xoffset) + 'px';
				drag.image.style.top = (e.clientY - drag.yoffset) + 'px';
			}
		},

		dragBegin: function(pixels, width, height, stride, xoffset, yoffset) {
			LiveCodeEvents.dragEnd();

			var drag = {'cancel': 0, 'image': null, 'xoffset': xoffset, 'yoffset': yoffset,
						'style': document.createElement('style'), 'cursor': null};
			document.head.appendChild(drag.style);

			if (pixels && width > 0 && height > 0) {
				var image = LiveCodeDC.canvasFromPixels(pixels, width, height, stride);
				if (image) {
					image.style.position = 'fixed';
					image.style.width = width + 'px';
					image.style.height = height + 'px';
					image.style.pointerEvents = 'none';
					image.style.zIndex = 2147483647;
					image.style.opacity = 0.75;
					document.body.appendChild(image);
					drag.image = image;
				}
			}

			LiveCodeEvents._drag = drag;
			if (LiveCodeEvents._pointer) {
				LiveCodeEvents._trackPointer({'clientX': LiveCodeEvents._pointer[0],
											  'clientY': LiveCodeEvents._pointer[1]});
			}
			LiveCodeEvents.dragSetCursor('grabbing');
		},

		dragSetCursor: function(cursor) {
			var drag = LiveCodeEvents._drag;
			if (drag && drag.cursor != cursor) {
				drag.cursor = cursor;
				drag.style.textContent = 'html, html * { cursor: ' + cursor + ' !important; }';
			}
		},

		dragEnd: function() {
			var drag = LiveCodeEvents._drag;
			if (!drag) {
				return;
			}
			LiveCodeEvents._drag = null;
			if (drag.style.parentNode) {
				drag.style.parentNode.removeChild(drag.style);
			}
			if (drag.image && drag.image.parentNode) {
				drag.image.parentNode.removeChild(drag.image);
			}
		},

		// The stack window under the pointer, or null (_windowAt())
		dragTarget: function() {
			var pointer = LiveCodeEvents._pointer;
			if (!pointer) {
				return null;
			}
			return LiveCodeEvents._windowAt(document.elementFromPoint(pointer[0], pointer[1]),
											pointer[0], pointer[1]);
		},

		// The stack window that <element> is part of (its canvas, or a
		// native layer over it): {'window', 'x', 'y'}, x, y being where
		// <clientX>, <clientY> is in its canvas (as for the mouse's
		// events: _encodeMouseCoordinates()), or null if it is in none
		_windowAt: function(element, clientX, clientY) {
			for (; element; element = element.parentElement) {
				var dataset = element.dataset || {};
				var id = Number(dataset.lcWindowId || dataset.lcLayerWindowId || 0);
				if (id) {
					var canvas = LiveCodeDC.getWindowCanvas(id);
					if (!canvas) {
						return null;
					}
					var rect = canvas.getBoundingClientRect();
					return {'window': id,
							'x': (clientX - rect.left - canvas.clientLeft + canvas.scrollLeft) | 0,
							'y': (clientY - rect.top - canvas.clientTop + canvas.scrollTop) | 0};
				}
			}
			return null;
		},

		// ----------------------------------------------------------------
		// Drops from outside the page
		// ----------------------------------------------------------------

		// OXT-Beyond: files and folders, text and HTML can be dragged
		// from outside the page and dropped on a stack. The browser shows
		// what a drag carries only when it is dropped, so the stack hears
		// of the drag then (MCEmscriptenHandleDrop(), em-dc.cpp), and
		// meanwhile the page says that a drop would copy.

		// The drops whose files and folders are being copied into
		// /uploads (LiveCodeDialog.storeDropped()): id: the copies'
		// paths, one per line, or null until they are copied
		_drops: {},
		_nextDrop: 1,

		// Whether a drag carries what a stack takes
		_dropCarries: function(data) {
			var types = data && data.types ? Array.prototype.slice.call(data.types) : [];
			return ['Files', 'text/plain', 'text/uri-list', 'text/html'].some(function(type) {
				return types.indexOf(type) >= 0;
			});
		},

		_handleDrop: function(e) {
			var data = e.dataTransfer;
			var target = LiveCodeEvents._windowAt(e.target, e.clientX, e.clientY);
			if (!target || !LiveCodeEvents._dropCarries(data)) {
				return;
			}

			// The stack takes the drag (the browser would open a file
			// dropped on the page)
			e.preventDefault();

			if (e.type != 'drop') {
				// A drop copies, if the drag lets it
				var allowed = (data.effectAllowed || 'all').toLowerCase();
				if (allowed == 'all' || allowed == 'uninitialized' || allowed.indexOf('copy') >= 0) {
					data.dropEffect = 'copy';
				} else if (allowed.indexOf('move') >= 0) {
					data.dropEffect = 'move';
				} else if (allowed.indexOf('link') >= 0) {
					data.dropEffect = 'link';
				}
				return;
			}

			LiveCodeEvents._trackModifiers(e);
			var mods = LiveCodeEvents._encodeModifiers(e.shiftKey, e.altKey, e.ctrlKey, e.metaKey);

			// The text, or else the links (one a line: text/uri-list has
			// comments too)
			var text = data.getData('text/plain');
			if (!text) {
				text = data.getData('text/uri-list').split(/\r?\n/).filter(function(line) {
					return line != '' && line.charAt(0) != '#';
				}).join('\n');
			}
			var html = data.getData('text/html');

			// The files and folders, which are copied into /uploads first
			var dropped = [];
			var items = data.items ? Array.prototype.slice.call(data.items) : [];
			items.forEach(function(item) {
				if (item.kind != 'file') {
					return;
				}
				var entry = item.webkitGetAsEntry ? item.webkitGetAsEntry() : null;
				var file = entry ? null : item.getAsFile();
				if (entry || file) {
					dropped.push(entry || file);
				}
			});
			if (items.length == 0 && data.files) {
				dropped = Array.prototype.slice.call(data.files);
			}
			var drop = 0;
			if (dropped.length > 0) {
				drop = LiveCodeEvents._nextDrop++;
				LiveCodeEvents._drops[drop] = null;
				LiveCodeDialog.storeDropped(dropped).then(function(paths) {
					if (drop in LiveCodeEvents._drops) {
						LiveCodeEvents._drops[drop] = paths;
						LiveCodeAsync.resume();
					}
				});
			}

			if (!text && !html && !drop) {
				return;
			}

			LiveCodeAsync.delay(function() {
				Module.ccall('MCEmscriptenHandleDrop', 'number',
							 ['number', /* Window window */
							  'number', /* uint32_t time */
							  'number', /* uint32_t modifiers */
							  'number', 'number', /* int32_t x, y */
							  'number', 'number', /* MCStringRef text, html */
							  'number'], /* uint32_t drop */
							 [target.window, e.timeStamp, mods, target.x, target.y,
							  text ? LiveCodeUtil.stringToMCStringRef(text) : 0,
							  html ? LiveCodeUtil.stringToMCStringRef(html) : 0,
							  drop]);
			});
			LiveCodeAsync.resume();
		},

		// ----------------------------------------------------------------
		// Touch events
		// ----------------------------------------------------------------

		// A touch screen drives the mouse, as a desktop's does: the first
		// finger to touch a stack is the mouse with its button down
		// (mouseDown, mouseMove as it moves, and mouseUp when it lifts, or
		// mouseRelease when the browser cancels the touch), and the
		// fingers that touch while it is down do nothing. The browser
		// does nothing of its own with a touch on a stack: no scrolling or
		// zooming, and none of the mouse events that it makes up for a
		// tap, which would come after the touch's and repeat them. The
		// mouse stays where the finger left it, until a finger touches
		// another stack or the mouse moves.

		// The touch that is the mouse while it is down (its identifier),
		// and the canvas of the stack touched last
		_touchId: null,
		_touchCanvas: null,

		_handleTouchEvent: function(e) {
			e.preventDefault();

			var touch = null;
			for (var i = 0; i < e.changedTouches.length; i++) {
				var t = e.changedTouches[i];
				if (e.type == 'touchstart' ?
					LiveCodeEvents._touchId == null :
					t.identifier == LiveCodeEvents._touchId) {
					touch = t;
					break;
				}
			}
			if (touch == null) {
				return false;
			}

			// The mouse event that the touch is (a touch's events all go to
			// the canvas that it started on)
			var mouse = function(type, target) {
				return {
					type: type,
					target: target || e.target,
					clientX: touch.clientX,
					clientY: touch.clientY,
					timeStamp: e.timeStamp,
					button: 0,
					shiftKey: e.shiftKey,
					altKey: e.altKey,
					ctrlKey: e.ctrlKey,
					metaKey: e.metaKey,
					// a touch does not change the Caps Lock
					getModifierState: function(key) {
						return key == 'CapsLock' && (LiveCodeEvents._modifierKeys & 16) != 0;
					},
					preventDefault: function() {},
				};
			};

			switch (e.type) {
			case 'touchstart':
				LiveCodeEvents._touchId = touch.identifier;
				// The mouse leaves the stack touched last, and comes to
				// this one
				if (LiveCodeEvents._touchCanvas != null &&
					LiveCodeEvents._touchCanvas != e.target) {
					LiveCodeEvents._handleMouseEvent(mouse('mouseleave', LiveCodeEvents._touchCanvas));
				}
				LiveCodeEvents._touchCanvas = e.target;
				LiveCodeEvents._handleMouseEvent(mouse('mouseenter'));
				LiveCodeEvents._handleMouseEvent(mouse('mousedown'));
				break;

			case 'touchmove':
				LiveCodeEvents._handleMouseEvent(mouse('mousemove'));
				break;

			case 'touchend':
				LiveCodeEvents._touchId = null;
				LiveCodeEvents._handleMouseEvent(mouse('mouseup'));
				LiveCodeEvents._touchEnded();
				break;

			case 'touchcancel':
				// No click: the button is let go as when the mouse is
				// released away from what it pressed
				LiveCodeEvents._touchId = null;
				LiveCodeAsync.delay(function() {
					var target = LiveCodeEvents._eventTarget(mouse('mousemove'));
					var stack = LiveCodeEvents._getStackForCanvas(target);
					if (stack) {
						var mods = LiveCodeEvents._encodeModifiers(e.shiftKey, e.altKey, e.ctrlKey, e.metaKey);
						LiveCodeEvents._postMousePress(stack, e.timeStamp, mods,
													   LiveCodeEvents._encodeMouseState('mouserelease'), 0);
					}
					LiveCodeEvents._releaseFocus();
				});
				LiveCodeAsync.resume();
				break;
			}
			return false;
		},

		// ----------------------------------------------------------------
		// UI events
		// ----------------------------------------------------------------
		
		// The query matches the device pixel ratio of the moment, so it
		// sees one change (a zoom, or the window moved to another screen):
		// each change watches for the next with a query of its own
		_watchDevicePixelRatio: function() {
			var query = window.matchMedia('(resolution: ' + window.devicePixelRatio + 'dppx)');
			var changed = function() {
				if (query.removeEventListener) {
					query.removeEventListener('change', changed);
				} else {
					query.removeListener(changed);
				}
				LiveCodeEvents._handleDevicePixelRatioChanged();
				LiveCodeEvents._watchDevicePixelRatio();
			};
			if (query.addEventListener) {
				query.addEventListener('change', changed);
			} else {
				query.addListener(changed);
			}
		},

		_handleDevicePixelRatioChanged: function() {
			LiveCodeAsync.delay(function() {
				Module.ccall('MCEmscriptenHandleDevicePixelRatioChanged',
								'number', /* bool */
								[],
								[])
			});
			LiveCodeAsync.resume();
			LiveCodeEvents._handleScreenResize();
		},

		// A window being resized changes its size many times a second:
		// the stacks hear of it once it has stopped for a moment
		_screenTimer: null,

		_handleScreenResize: function() {
			clearTimeout(LiveCodeEvents._screenTimer);
			LiveCodeEvents._screenTimer = setTimeout(function() {
				LiveCodeEvents._screenTimer = null;
				LiveCodeAsync.delay(function() {
					Module.ccall('MCEmscriptenHandleScreenChanged',
								 'number', /* bool */
								 [],
								 []);
				});
				LiveCodeAsync.resume();
			}, 100);
		},

		// prevent context menu popup on right-click
		_handleContextMenu: function(e) {
			e.preventDefault()
		},

		// ----------------------------------------------------------------
		// Window events
		// ----------------------------------------------------------------
		
		_postWindowReshape: function(stack, backingScale)
		{
			Module.ccall('MCEventQueuePostWindowReshape',
							'number', /* bool */
							['number', /* MCStack *stack */
							 'number'], /* MCGFloat backing_scale */
							[stack, backingScale]);
		},
		
		postWindowReshape: function(window)
		{
			LiveCodeAsync.delay(function () {
				var stack = LiveCodeEvents._getStackForWindow(window);
				if (stack == 0)
				{
					return
				}
				LiveCodeEvents._postWindowReshape(stack, 1.0);
			});
			LiveCodeAsync.resume();
		},

		// OXT-Beyond: the window moved on the screen (the page moved its
		// canvas, as a centred page does when the browser's window is
		// resized, or the user dragged it by its title bar). A menu is a
		// window of its own, fixed where it opened, so it would stay
		// behind: the engine closes it, as a browser closes a <select>'s
		// list when the page moves under it (MCEmscriptenHandleWindowMoved())
		postWindowMoved: function(window)
		{
			LiveCodeAsync.delay(function () {
				var stack = LiveCodeEvents._getStackForWindow(window);
				if (stack == 0)
				{
					return
				}
				Module.ccall('MCEmscriptenHandleWindowMoved',
							 'number', /* bool */
							 ['number'], /* MCStack *stack */
							 [stack]);
			});
			LiveCodeAsync.resume();
		},
	},

	MCEmscriptenEventInitializeJS__deps: ['$LiveCodeEvents'],
	MCEmscriptenEventInitializeJS: function() {
		LiveCodeEvents.initialize();
		return true;
	},

	MCEmscriptenEventFinalizeJS__deps: ['$LiveCodeEvents'],
	MCEmscriptenEventFinalizeJS: function() {
		LiveCodeEvents.finalize();
	},

	// The modifier keys that are down (see getModifierKeys)
	MCEmscriptenGetModifierKeys__deps: ['$LiveCodeEvents'],
	MCEmscriptenGetModifierKeys: function() {
		return LiveCodeEvents.getModifierKeys();
	},

	// The codes of the keys that are down, at most <max> of them into
	// <codes> (uint32_t); returns how many there are
	MCEmscriptenGetKeysDown__deps: ['$LiveCodeEvents'],
	MCEmscriptenGetKeysDown: function(codes, max) {
		var down = Object.keys(LiveCodeEvents._keysDown);
		for (var i = 0; i < down.length && i < max; i++) {
			{{{ makeSetValue('codes', 'i * 4', 'Number(down[i])', 'i32') }}};
		}
		return down.length;
	},

	// OXT-Beyond: whether an unlocked field has the keyboard focus: a touch
	// screen's keyboard comes up for it (MCScreenDC::activateIME(),
	// em-dc.cpp)
	MCEmscriptenSetTextInput__deps: ['$LiveCodeEvents'],
	MCEmscriptenSetTextInput: function(active) {
		LiveCodeEvents.setTextInput(!!active);
	},

	// OXT-Beyond: a window opened or closed (MCScreenDC::openwindow() and
	// closewindow(), em-dc.cpp)
	MCEmscriptenPassKeyboard__deps: ['$LiveCodeEvents'],
	MCEmscriptenPassKeyboard: function(from, to) {
		LiveCodeEvents.passKeyboard(from, to);
	},

	// OXT-Beyond: a drag that the engine started (MCScreenDC::dodragdrop(),
	// em-dc.cpp). Its image, if it has one, is <pixels>: premultiplied
	// RGBA, <stride> bytes a row; the pointer is <xoffset>, <yoffset> from
	// its top left.
	MCEmscriptenDragBegin__deps: ['$LiveCodeEvents'],
	MCEmscriptenDragBegin: function(pixels, width, height, stride, xoffset, yoffset) {
		LiveCodeEvents.dragBegin(pixels, width, height, stride, xoffset, yoffset);
	},

	// The window of the stack that the pointer is over (0 if none), and
	// where in it the pointer is (<r_x>, <r_y>: int32_t)
	MCEmscriptenDragGetTarget__deps: ['$LiveCodeEvents'],
	MCEmscriptenDragGetTarget: function(r_x, r_y) {
		var target = LiveCodeEvents.dragTarget();
		if (!target) {
			return 0;
		}
		{{{ makeSetValue('r_x', '0', 'target.x', 'i32') }}};
		{{{ makeSetValue('r_y', '0', 'target.y', 'i32') }}};
		return target.window;
	},

	// Why the drag was cancelled: 0 if it was not, 1 Escape (its button
	// is still down), 2 the page lost the mouse
	MCEmscriptenDragGetCancel__deps: ['$LiveCodeEvents'],
	MCEmscriptenDragGetCancel: function() {
		return LiveCodeEvents._drag ? LiveCodeEvents._drag.cancel : 0;
	},

	// What a drop would do (an engine drag action, or 0 for none): the
	// cursor shows it
	MCEmscriptenDragSetAction__deps: ['$LiveCodeEvents'],
	MCEmscriptenDragSetAction: function(action) {
		LiveCodeEvents.dragSetCursor(LiveCodeEvents._dragCursors[action] || 'no-drop');
	},

	MCEmscriptenDragEnd__deps: ['$LiveCodeEvents'],
	MCEmscriptenDragEnd: function() {
		LiveCodeEvents.dragEnd();
	},

	// OXT-Beyond: whether the files and folders of the drop <drop> from
	// outside the page (MCEmscriptenHandleDrop(), em-dc.cpp) are still
	// being copied
	MCEmscriptenDropIsPending__deps: ['$LiveCodeEvents'],
	MCEmscriptenDropIsPending: function(drop) {
		return LiveCodeEvents._drops[drop] === null;
	},

	// The paths of their copies, one per line (UTF-16, which the engine
	// frees); false if there are none. The drop is forgotten.
	MCEmscriptenDropGetFiles__deps: ['$LiveCodeEvents', '$LiveCodeUtil'],
	MCEmscriptenDropGetFiles: function(drop, r_paths, r_length) {
		var paths = LiveCodeEvents._drops[drop];
		delete LiveCodeEvents._drops[drop];
		if (!paths) {
			return false;
		}
		var buffer = LiveCodeUtil.stringToUTF16(paths);
		{{{ makeSetValue('r_paths', '0', 'buffer', 'i32') }}};
		{{{ makeSetValue('r_length', '0', 'paths.length', 'i32') }}};
		return true;
	},

	// Forgets the drop <drop>, whose files are not wanted
	MCEmscriptenDropRelease__deps: ['$LiveCodeEvents'],
	MCEmscriptenDropRelease: function(drop) {
		delete LiveCodeEvents._drops[drop];
	},

});

/*
 * Local Variables:
 * tab-width: 4
 * indent-tabs-mode: t
 * End:
 */
