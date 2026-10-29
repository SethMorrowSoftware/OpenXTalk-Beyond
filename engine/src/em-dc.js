/*                                                              -*-Javascript-*-
 
 Copyright (C) 2017 LiveCode Ltd.
 
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
	$LiveCodeDC__deps: ['$LiveCodeEvents', '$LiveCodeUtil', '$LiveCodeAsync'],
	$LiveCodeDC: {
		// true if ensureInit() has ever been run
		_initialised: false,

		initialize: function() {
			// Make sure this only ever gets run once
			if (LiveCodeDC._initialised) {
				return;
			}
			
			LiveCodeDC._windowList = this.containerCreate(document.body, 1);
			LiveCodeDC._assignedMainWindow = false;

			LiveCodeDC._watchAppearance();

			LiveCodeDC._initialised = true;
		},

		finalize: function() {
			if (!LiveCodeDC._initialised) {
				return;
			}

			LiveCodeDC._initialised = false;
		},

		// OXT-Beyond: the browser's colour scheme, which is the
		// systemAppearance only on a page that asks for it with
		// <meta name="oxt-appearance" content="system"> (em-dc.cpp,
		// MCScreenDC::getsystemappearance). Elsewhere it stays light, as it
		// always was. When the scheme changes, the engine draws its stacks
		// again and sends systemAppearanceChanged.
		_appearanceQuery: null,

		_watchAppearance: function() {
			LiveCodeDC._appearanceQuery = null;
			var meta = document.querySelector('meta[name="oxt-appearance"]');
			if (!meta || meta.getAttribute('content') !== 'system' ||
			    typeof window.matchMedia !== 'function') {
				return;
			}
			var query = window.matchMedia('(prefers-color-scheme: dark)');
			LiveCodeDC._appearanceQuery = query;
			var changed = function() {
				LiveCodeAsync.delay(function() {
					Module.ccall('MCEmscriptenHandleSystemAppearanceChanged', 'number', [], []);
				});
				LiveCodeAsync.resume();
			};
			if (typeof query.addEventListener === 'function') {
				query.addEventListener('change', changed);
			} else if (typeof query.addListener === 'function') {
				// Safari before 14
				query.addListener(changed);
			}
		},

		// Read with a query of its own: Chromium sends a query's change
		// event only if the query's value differs from the one it last
		// gave, so reading the watched query after the scheme changed and
		// before the event (a script that read the systemAppearance then)
		// lost the event, and systemAppearanceChanged with it
		isAppearanceDark: function() {
			return LiveCodeDC._appearanceQuery !== null &&
				window.matchMedia('(prefers-color-scheme: dark)').matches;
		},

		containerCreate: function(containerElement, maxZIndex) {
			return {'element':containerElement, 'maxZIndex':maxZIndex, 'contents':[]};
		},
		
		containerAddElement: function(container, element) {
			// OXT-Beyond: an element already in the container stays where
			// it is (the engine can attach a native layer twice, and moving
			// a frame in the page reloads it)
			if (container['contents'].indexOf(element) != -1) {
				return;
			}
			element.style.position = 'absolute';
			element.style.zIndex = container['maxZIndex'];
			container['maxZIndex']++;
			container['element'].appendChild(element);
			container['contents'].push(element);
		},
		
		containerRemoveElement: function(container, element) {
			// OXT-Beyond: an element that is not in the container stays out
			if (element.parentNode !== container['element']) {
				return;
			}
			this.containerRaiseElement(container, element);
			container['element'].removeChild(element);
			container['maxZIndex']--;
			var index = container['contents'].indexOf(element);
			if (index !== -1) {
				container['contents'].splice(index, 1);
			}
		},
		
		containerRaiseElement: function(container, element) {
			// OXT-Beyond: compared as numbers (style values are strings)
			var zIndex = Number(element.style.zIndex);
			for (var i = 0, l = container['contents'].length; i < l; i++)
			{
				var otherElement = container['contents'][i];
				if (Number(otherElement.style.zIndex) > zIndex)
				{
					otherElement.style.zIndex--;
				}
			}
			element.style.zIndex = container['maxZIndex'] - 1;
		},
		
		// Windows are backed by an html canvas within a floating div
		createWindow: function() {
			var windowElement;
			var canvas;
			var rect;
			var mainWindow = false;
			if (!LiveCodeDC._assignedMainWindow)
			{
				mainWindow = true;
				canvas = Module['canvas'];
				rect = canvas.getBoundingClientRect();
				LiveCodeDC._assignedMainWindow = true;
				windowElement = canvas.parentElement;
				windowElement.style.setProperty('position', 'relative');
				windowElement.style.setProperty('width', rect['right'] - rect['left']);
				windowElement.style.setProperty('height', rect['bottom'] - rect['top']);
				canvas.style.setProperty('position', 'absolute');
				canvas.style.setProperty('left', '0px');
				canvas.style.setProperty('right', '0px');
				canvas.style.setProperty('width', '100%');
				canvas.style.setProperty('height', '100%');
			}
			else
			{
				windowElement = document.createElement('div');
				windowElement.style.display = 'none';
				windowElement.style.position = 'fixed';
				// OXT-Beyond: its frame (see setWindowFrame()), under
				// the canvas
				windowElement.className = 'oxt-window';
				var frame = LiveCodeDC._createFrame(windowElement);
				canvas = document.createElement('canvas');
				canvas.style.setProperty('position', 'absolute');
				canvas.style.setProperty('left', '0px');
				canvas.style.setProperty('right', '0px');
				canvas.style.setProperty('width', '100%');
				canvas.style.setProperty('height', '100%');
				windowElement.appendChild(canvas);
				this.containerAddElement(this._windowList, windowElement);
		  
				rect = {'left':0, 'top':0, 'right':0, 'bottom':0};
			}
			
			var tWindowID = LiveCodeUtil.storeObject({
				'mainWindow': mainWindow,
				'element': windowElement,
				'canvas': canvas,
				'container': this.containerCreate(windowElement, 1),
				'rect': rect,
				'visible':false,
				// OXT-Beyond: its frame's parts (none for the main window),
				// whether its stack takes the user's mouse and keys (not
				// under a modal dialog), and the sizes it can be resized to
				'frame': mainWindow ? null : frame,
				'enabled': true,
				'sizeLimits': [0, 0, 32767, 32767],
			});
			
			if (!mainWindow)
				LiveCodeDC._attachFrame(tWindowID);
			canvas.dataset.lcWindowId = tWindowID;
			LiveCodeEvents.addEventListeners(canvas);
			// OXT-Beyond: the engine also hears when a window that was on
			// the screen moves (postWindowMoved()): a window that opens or
			// closes comes from or goes to a rect of nothing
			var tLastRect = canvas.getBoundingClientRect();
			LiveCodeDC._monitorResize(canvas, function() {
				var tRect = canvas.getBoundingClientRect();
				var tWasShown = tLastRect.width > 0 && tLastRect.height > 0;
				var tIsShown = tRect.width > 0 && tRect.height > 0;
				var tMoved = tWasShown && tIsShown &&
					(tRect.left != tLastRect.left || tRect.top != tLastRect.top);
				tLastRect = tRect;
				if (tMoved)
					LiveCodeEvents.postWindowMoved(tWindowID);
				LiveCodeEvents.postWindowReshape(tWindowID);
			});
			
			return tWindowID;
		},
		
		destroyWindow: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
			{
				LiveCodeDC._removeResizeMonitor(window.canvas);
				LiveCodeDC.setWindowVisible(pID, false);
				
				if (window.mainWindow)
				{
					// TODO - handle cleanup of embedded canvas
					LiveCodeDC._assignedMainWindow = false;
				}
				else
				{
					this.containerRemoveElement(this._windowList, window.element);
				}
				LiveCodeUtil.releaseObject(pID);
			}
		},
		
		raiseWindow: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window && !window.mainWindow)
			{
				this.containerRaiseElement(this._windowList, window.element);
				// OXT-Beyond: in its layer (see _restack())
				LiveCodeDC._restack();
			}
		},
		
		setWindowRect: function(pID, pLeft, pTop, pRight, pBottom) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
			{
				var width = pRight - pLeft;
				var height = pBottom - pTop;
				window.rect = {'left':pLeft, 'top':pTop, 'right':pRight, 'bottom':pBottom};
				if (!window.mainWindow)
				{
					window.element.style.setProperty('left', pLeft + 'px', 'important');
					window.element.style.setProperty('top', pTop + 'px', 'important');
				}
				window.element.style.setProperty('width', width + 'px', 'important');
				window.element.style.setProperty('height', height + 'px', 'important');
			}
		},
		
		getWindowRect: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
				return window.canvas.getBoundingClientRect();
		  
			return null;
		},

		// OXT-Beyond: where the window is with its frame (see
		// setWindowFrame()), as the desktop's window is with its
		// decorations: its canvas's rect when it has none
		getWindowFrameRect: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (!window) {
				return {'left': 0, 'top': 0, 'right': 0, 'bottom': 0};
			}
			var rect = window.canvas.getBoundingClientRect();
			var frame = window.frame;
			if (!frame || !window.visible || frame.border.style.display == 'none') {
				return rect;
			}
			var border = frame.border.getBoundingClientRect();
			return {'left': Math.min(rect.left, border.left), 'top': Math.min(rect.top, border.top),
					'right': Math.max(rect.right, border.right),
					'bottom': Math.max(rect.bottom, border.bottom)};
		},

		// OXT-Beyond: the window that a part of the page is in (its canvas,
		// its frame, or a native layer in it), or 0
		_windowIDForElement: function(element) {
			for (; element && element.dataset; element = element.parentElement) {
				if (element.dataset.lcWindowId) {
					return Number(element.dataset.lcWindowId);
				}
				if (element.dataset.lcLayerWindowId) {
					return Number(element.dataset.lcLayerWindowId);
				}
				if (element.classList.contains('oxt-window')) {
					return LiveCodeDC.getWindowIDForCanvas(element.querySelector('canvas'));
				}
			}
			return 0;
		},
		
		setWindowVisible: function(pID, pVisible) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
			{
				// OXT-Beyond: a window that is shown comes to the front, as
				// a desktop's window manager brings a window that opens
				if (pVisible && !window.visible && !window.mainWindow)
					LiveCodeDC.raiseWindow(pID);
				window.visible = pVisible;
				if (!window.mainWindow)
				{
					if (pVisible)
						window.element.style.display = 'block';
					else
						window.element.style.display = 'none';
				}
				else
				{
					if (pVisible)
						window.element.style.visibility = 'visible';
					else
						window.element.style.visibility = 'hidden';
				}
			}
		},
		
		getWindowVisible: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
			{
				return window.visible;
			}
			
			return false;
		},
		
		getWindowCanvas: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window)
			{
				return window.canvas;
			}
			
			return null;
		},
		
		getWindowIDForCanvas: function(pCanvas) {
			if (pCanvas && pCanvas.dataset && pCanvas.dataset.lcWindowId)
				return Number(pCanvas.dataset.lcWindowId);
			return 0;
		},
		
		// The screen is the browser's viewport: the part of the page that
		// it shows, without its scrollbars
		getDisplayRect: function() {
			var root = document.documentElement;
			return {'left':0, 'top':0,
					'right':root.clientWidth || window.innerWidth,
					'bottom':root.clientHeight || window.innerHeight};
		},

		/*** Cursors ***/

		// The CSS cursor of each cursor, by id: a standard cursor's name,
		// or an image's url()
		_cursors: {},
		_nextCursor: 1,

		// The CSS cursors of the engine's standard cursors, in the order of
		// enum Pixmap_ids (parsedef.h): none, arrow, brush, spray, eraser,
		// bucket, busy, cross, hand, ibeam, lr, pencil, dropper, plus,
		// watch, help, busy1 to busy8, dragtext, dragclone, dragrefuse,
		// sizev, sizeh. The last is a hand: the constant hand is 28
		// (lextable.cpp), which is sizeh's place, and the cursor image 28
		// that the desktop shows there is a hand.
		_standardCursors: ['none', 'default', 'crosshair', 'crosshair', 'crosshair', 'crosshair',
			'wait', 'crosshair', 'pointer', 'text', 'ew-resize', 'crosshair', 'crosshair',
			'cell', 'wait', 'help', 'wait', 'wait', 'wait', 'wait', 'wait', 'wait', 'wait', 'wait',
			'grabbing', 'copy', 'no-drop', 'ns-resize', 'pointer'],

		createStandardCursor: function(index) {
			var id = LiveCodeDC._nextCursor++;
			LiveCodeDC._cursors[id] = LiveCodeDC._standardCursors[index] || 'default';
			return id;
		},

		// A cursor from an image: <pixels> is premultiplied RGBA, <stride>
		// bytes a row
		createCustomCursor: function(pixels, width, height, stride, xhot, yhot) {
			var canvas = LiveCodeDC.canvasFromPixels(pixels, width, height, stride);
			if (!canvas) {
				return LiveCodeDC.createStandardCursor(1);
			}
			var id = LiveCodeDC._nextCursor++;
			LiveCodeDC._cursors[id] = 'url("' + canvas.toDataURL('image/png') + '") ' +
				Math.max(0, Math.min(xhot, width - 1)) + ' ' +
				Math.max(0, Math.min(yhot, height - 1)) + ', auto';
			return id;
		},

		// A canvas that shows an image (a cursor's, or a drag's): <pixels>
		// is premultiplied RGBA, <stride> bytes a row. Null if there is no
		// image.
		canvasFromPixels: function(pixels, width, height, stride) {
			var canvas = document.createElement('canvas');
			canvas.width = width;
			canvas.height = height;
			var context = canvas.getContext('2d');
			if (!context || width == 0 || height == 0) {
				return null;
			}
			var image = context.createImageData(width, height);
			var data = image.data;
			for (var y = 0; y < height; y++) {
				for (var x = 0; x < width; x++) {
					var from = pixels + y * stride + x * 4;
					var to = (y * width + x) * 4;
					var alpha = HEAPU8[from + 3];
					if (alpha == 0) {
						continue;
					}
					data[to] = Math.min(255, Math.round(HEAPU8[from] * 255 / alpha));
					data[to + 1] = Math.min(255, Math.round(HEAPU8[from + 1] * 255 / alpha));
					data[to + 2] = Math.min(255, Math.round(HEAPU8[from + 2] * 255 / alpha));
					data[to + 3] = alpha;
				}
			}
			context.putImageData(image, 0, 0);
			return canvas;
		},

		freeCursor: function(id) {
			delete LiveCodeDC._cursors[id];
		},

		setWindowCursor: function(pID, id) {
			var canvas = LiveCodeDC.getWindowCanvas(pID);
			if (canvas) {
				canvas.style.cursor = LiveCodeDC._cursors[id] || 'default';
			}
		},

		/*** Native Layer API ***/
		nativeElementSetRect: function(pElementID, pLeft, pTop, pRight, pBottom) {
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			if (tElement)
			{
				tElement.style.setProperty('left', pLeft + 'px', 'important');
				tElement.style.setProperty('top', pTop + 'px', 'important');
				tElement.style.setProperty('width', pRight - pLeft + 'px', 'important');
				tElement.style.setProperty('height', pBottom - pTop + 'px', 'important');
			}
		},
		
		nativeElementSetClip: function(pElementID, pLeft, pTop, pRight, pBottom) {
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			if (tElement)
			{
				tElement.style.setProperty('clip', 'rect(' + pTop + 'px,' + pRight + 'px,' + pBottom + 'px,' + pLeft + 'px)', 'important');
			}
		},
		
		nativeElementSetVisible: function(pElementID, pVisible) {
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			if (tElement)
			{
				if (pVisible)
					tElement.style.display = 'block';
				else
					tElement.style.display = 'none';
			}
		},
		
		nativeElementAddToWindow: function(pElementID, pWindowID) {
			var tWindow = LiveCodeUtil.fetchObject(pWindowID);
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			if (tWindow && tElement)
			{
				this.containerAddElement(tWindow.container, tElement);
				// OXT-Beyond: a drag over the element is over its window
				// (LiveCodeEvents.dragTarget())
				tElement.dataset.lcLayerWindowId = pWindowID;
			}
		},

		nativeElementRemoveFromWindow: function(pElementID, pWindowID) {
			var tWindow = LiveCodeUtil.fetchObject(pWindowID);
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			if (tWindow && tElement)
			{
				this.containerRemoveElement(tWindow.container, tElement);
				delete tElement.dataset.lcLayerWindowId;
			}
		},
		
		nativeElementPlaceAbove: function(pElementID, pAboveElementID, pWindowID) {
			var tWindow = LiveCodeUtil.fetchObject(pWindowID);
			var tElement = LiveCodeUtil.fetchObject(pElementID);
			var tAboveElement = pAboveElementID ? LiveCodeUtil.fetchObject(pAboveElementID) : null;
			// OXT-Beyond: put the element just above the given one (or at the
			// bottom when there is none) by renumbering the stacking order of
			// the window's elements. The elements stay where they are in the
			// page, because moving a frame in the page reloads it.
			if (!tWindow || !tElement)
			{
				return;
			}
			var tContents = tWindow.container['contents'];
			if (tContents.indexOf(tElement) == -1)
			{
				return;
			}
			var tOrdered = tContents.slice().sort(function(a, b) {
				return Number(a.style.zIndex) - Number(b.style.zIndex);
			});
			tOrdered.splice(tOrdered.indexOf(tElement), 1);
			var tIndex = tAboveElement ? tOrdered.indexOf(tAboveElement) + 1 : 0;
			tOrdered.splice(tIndex, 0, tElement);
			for (var i = 0; i < tOrdered.length; i++)
			{
				tOrdered[i].style.zIndex = i + 1;
			}
		},
		
		_monitorResize: function(element, callback) {
			// initial setup on first call
			if (!LiveCodeDC._monitorResize.watched) {
				LiveCodeDC._monitorResize.watched = [];
		  
				var resizeCheck = function() {
					LiveCodeDC._monitorResize.watched.forEach(function(data) {
						var rect = data.element.getBoundingClientRect();
						if (rect.left != data.rect.left || rect.top != data.rect.top || rect.right != data.rect.right || rect.bottom != data.rect.bottom) {
							data.rect = rect;
							data.callback();
						}
					});
				};

				// Listen to the window's size changes
				window.addEventListener('resize', resizeCheck);
		  
				// Listen to changes on the elements in the page that affect layout
				var observer = new MutationObserver(resizeCheck);
				observer.observe(document.body, {
					attributes: true,
					childList: true,
					characterData: true,
					subtree: true
				});
			}
			
			LiveCodeDC._monitorResize.watched.push({'element':element, 'callback':callback, 'rect':element.getBoundingClientRect()});
		},
		
		_removeResizeMonitor: function(element) {
			if (LiveCodeDC._monitorResize.watched) {
				var index = 0;
				while (index < LiveCodeDC._monitorResize.watched.length)
				{
					if (LiveCodeDC._monitorResize.watched[index].element === element)
						LiveCodeDC._monitorResize.watched.splice(index, 1);
					else
						index++;
				}
			}
		},

		/*** Window frames ***/

		// OXT-Beyond: the window of a stack other than the main stack
		// (whose window is the page's canvas) has a frame, as a desktop
		// gives a window its decorations (MCStack::sethints(),
		// em-stack.cpp): a border, a title bar above the stack with its
		// title and a close box, which the user drags to move the window,
		// and, for a resizable stack, edges outside its right and bottom
		// sides that resize it. A press on the frame raises the window and
		// gives it the keyboard, as a press on the stack does, unless a
		// modal dialog is above it. Each window is in a layer (ordinary
		// windows, palettes, modal dialogs, menus and tooltips), which the
		// page keeps above the layers before it. A page can restyle the
		// frames: their class names start with "oxt-window".
		_frameStyled: false,

		_addFrameStyles: function() {
			if (LiveCodeDC._frameStyled) {
				return;
			}
			LiveCodeDC._frameStyled = true;
			var style = document.createElement('style');
			style.textContent =
				'.oxt-window-border{position:absolute;left:-1px;top:-31px;right:-1px;bottom:-1px;' +
				'border:1px solid #8c8c8c;box-shadow:0 6px 24px rgba(0,0,0,0.3);pointer-events:none}' +
				'.oxt-window-title{position:absolute;left:0;right:0;top:-30px;height:30px;display:flex;' +
				'background:#ffffff;color:#999999;' +
				'font:12px/30px "Segoe UI",system-ui,-apple-system,Roboto,sans-serif;cursor:default;' +
				'user-select:none;-webkit-user-select:none;touch-action:none;overflow:hidden}' +
				'.oxt-window-label{flex:1;min-width:0;padding:0 10px;white-space:nowrap;overflow:hidden;' +
				'text-overflow:ellipsis}' +
				'.oxt-window-close{flex:none;width:46px;text-align:center;font-size:14px}' +
				'.oxt-window-active>.oxt-window-title{color:#000000}' +
				'.oxt-window-close:hover{background:#e81123;color:#ffffff}' +
				'.oxt-window-disabled .oxt-window-close:hover{background:none;color:inherit}' +
				'.oxt-window-utility>.oxt-window-border{top:-23px}' +
				'.oxt-window-utility>.oxt-window-title{top:-22px;height:22px;line-height:22px;font-size:11px}' +
				'.oxt-window-utility .oxt-window-label{padding:0 6px}' +
				'.oxt-window-utility .oxt-window-close{width:28px;font-size:11px}' +
				'.oxt-window-edge{position:absolute;touch-action:none}' +
				'.oxt-window-edge-right{top:0;right:-6px;width:6px;height:100%;cursor:ew-resize}' +
				'.oxt-window-edge-bottom{left:0;bottom:-6px;width:100%;height:6px;cursor:ns-resize}' +
				'.oxt-window-edge-corner{right:-10px;bottom:-10px;width:12px;height:12px;cursor:nwse-resize}' +
				'.oxt-ignores-mouse,.oxt-ignores-mouse *{pointer-events:none!important}';
			document.head.appendChild(style);
		},

		// The parts of a frame, in the window's element, under its canvas:
		// hidden until the engine says what the window has
		_createFrame: function(windowElement) {
			LiveCodeDC._addFrameStyles();
			var part = function(className, parent) {
				var element = document.createElement('div');
				element.className = className;
				element.style.display = 'none';
				parent.appendChild(element);
				return element;
			};
			var frame = {};
			frame.border = part('oxt-window-border', windowElement);
			frame.title = part('oxt-window-title', windowElement);
			frame.label = part('oxt-window-label', frame.title);
			frame.label.style.display = '';
			frame.close = part('oxt-window-close', frame.title);
			frame.close.textContent = '\u2715';
			frame.edges = ['right', 'bottom', 'corner'].map(function(edge) {
				var element = part('oxt-window-edge oxt-window-edge-' + edge, windowElement);
				element.oxtEdge = edge;
				return element;
			});
			return frame;
		},

		// The user moves the window by its title bar, resizes it by its
		// edges and closes it with its close box
		_attachFrame: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			var frame = window.frame;
			var drag = null;

			// The mouse's own events too, for a drag that comes with no
			// pointer events: Firefox driven by Playwright sends only those
			// (seen 2026-10-16 in Firefox 142). Once a pointer event has
			// come, the mouse events are left alone; a mouse drag follows
			// the document's events, as a pointer drag follows its capture.
			var pointer = false;
			var mouse = 'mouse';
			var press = function(e, kind) {
				e.preventDefault();
				e.stopPropagation();
				if (e.button != 0 || !window.enabled) {
					return;
				}
				LiveCodeDC._activateWindow(pID);
				var id = e.pointerId === undefined ? mouse : e.pointerId;
				drag = {'kind': kind, 'pointer': id, 'x': e.clientX, 'y': e.clientY,
						'rect': window.rect};
				if (id === mouse) {
					document.addEventListener('mousemove', move, true);
					document.addEventListener('mouseup', end, true);
				} else {
					e.currentTarget.setPointerCapture(e.pointerId);
				}
			};
			var move = function(e) {
				var id = e.pointerId === undefined ? mouse : e.pointerId;
				if (!drag || id != drag.pointer) {
					return;
				}
				e.preventDefault();
				var dx = Math.round(e.clientX - drag.x);
				var dy = Math.round(e.clientY - drag.y);
				var rect = drag.rect;
				if (drag.kind == 'move') {
					LiveCodeDC._dragWindow(pID, rect.left + dx, rect.top + dy);
				} else {
					LiveCodeDC._resizeWindow(pID,
											 rect.right - rect.left + (drag.kind != 'bottom' ? dx : 0),
											 rect.bottom - rect.top + (drag.kind != 'right' ? dy : 0));
				}
			};
			var end = function(e) {
				var id = e.pointerId === undefined ? mouse : e.pointerId;
				if (drag && id == drag.pointer) {
					drag = null;
					if (id === mouse) {
						document.removeEventListener('mousemove', move, true);
						document.removeEventListener('mouseup', end, true);
					}
				}
			};

			[frame.title].concat(frame.edges).forEach(function(element) {
				element.addEventListener('pointerdown', function(e) {
					pointer = true;
					if (frame.close.contains(e.target)) {
						return;
					}
					press(e, element.oxtEdge || 'move');
				});
				element.addEventListener('mousedown', function(e) {
					if (pointer || frame.close.contains(e.target)) {
						return;
					}
					press(e, element.oxtEdge || 'move');
				});
				element.addEventListener('pointermove', function(e) {
					pointer = true;
					move(e);
				});
				element.addEventListener('pointerup', end);
				element.addEventListener('pointercancel', end);
			});

			frame.close.addEventListener('pointerdown', function(e) {
				e.preventDefault();
				e.stopPropagation();
				if (e.button == 0 && window.enabled) {
					LiveCodeDC._activateWindow(pID);
				}
			});
			frame.close.addEventListener('click', function(e) {
				e.preventDefault();
				e.stopPropagation();
				if (window.enabled) {
					LiveCodeAsync.delay(function() {
						Module.ccall('MCEmscriptenHandleWindowClose', 'number', ['number'], [pID]);
					});
					LiveCodeAsync.resume();
				}
			});
		},

		// A press on a window's frame: it comes to the front of its layer,
		// and its stack gets the keyboard
		_activateWindow: function(pID) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (!window) {
				return;
			}
			LiveCodeDC.raiseWindow(pID);
			LiveCodeAsync.delay(function() {
				LiveCodeEvents._setInputFocus(window.canvas);
			});
			LiveCodeAsync.resume();
		},

		// The user drags the window by its title bar to <left>, <top> (where
		// its stack is): its title bar stays on the screen, with some of it
		// to grab. The engine hears of the move as of the page moving a
		// window (_monitorResize()), and sends moveStack.
		_dragWindow: function(pID, pLeft, pTop) {
			var window = LiveCodeUtil.fetchObject(pID);
			var display = LiveCodeDC.getDisplayRect();
			var width = window.rect.right - window.rect.left;
			var height = window.rect.bottom - window.rect.top;
			var left = Math.max(Math.min(pLeft, display.right - 40), display.left + 40 - width);
			var top = Math.max(Math.min(pTop, display.bottom), display.top + window.frame.title.offsetHeight);
			LiveCodeDC.setWindowRect(pID, left, top, left + width, top + height);
		},

		// The user resizes the window by its edges to <width> x <height>,
		// within the stack's sizes (setWindowSizeLimits()). The engine hears
		// of it as of the page resizing a window, and sends resizeStack.
		_resizeWindow: function(pID, pWidth, pHeight) {
			var window = LiveCodeUtil.fetchObject(pID);
			var limits = window.sizeLimits;
			var width = Math.max(Math.min(pWidth, limits[2]), limits[0], 1);
			var height = Math.max(Math.min(pHeight, limits[3]), limits[1], 1);
			LiveCodeDC.setWindowRect(pID, window.rect.left, window.rect.top,
									 window.rect.left + width, window.rect.top + height);
		},

		// What the window's frame has (MCStack::sethints()): <kind> 0, no
		// frame; 1, a title bar; 2, a palette's narrower one; a close box if
		// <close>; edges that resize it if <resizable>. <layer> is its layer:
		// 0, ordinary windows; 1, palettes; 2, modal dialogs; 3, menus and
		// tooltips.
		setWindowFrame: function(pID, pKind, pClose, pResizable, pLayer) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (!window || !window.frame) {
				return;
			}
			var frame = window.frame;
			var show = function(element, visible) {
				element.style.display = visible ? '' : 'none';
			};
			show(frame.border, pKind != 0);
			show(frame.title, pKind != 0);
			show(frame.close, pKind != 0 && pClose);
			frame.edges.forEach(function(edge) {
				show(edge, pKind != 0 && pResizable);
			});
			window.element.classList.toggle('oxt-window-utility', pKind == 2);
			if (window.element.oxtLayer !== pLayer) {
				window.element.oxtLayer = pLayer;
				LiveCodeDC._restack();
			}
		},

		// The window whose stack has the keyboard looks active, as the
		// desktop's active window does, and the others' titles are grey
		// (LiveCodeEvents._setInputFocus())
		setActiveWindow: function(pID) {
			var active = LiveCodeUtil.fetchObject(pID);
			LiveCodeDC._windowList['contents'].forEach(function(element) {
				element.classList.toggle('oxt-window-active', !!active && element === active.element);
			});
		},

		// The stack's title, in its title bar
		setWindowTitle: function(pID, pTitle) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window && window.frame) {
				window.frame.label.textContent = pTitle;
			}
		},

		// Whether the window's stack takes the user's mouse and keys: not
		// while a modal dialog is above it (MCStack::enablewindow())
		setWindowEnabled: function(pID, pEnabled) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window) {
				window.enabled = !!pEnabled;
				// (the main stack's element is the page's own)
				if (window.frame) {
					window.element.classList.toggle('oxt-window-disabled', !pEnabled);
				}
			}
		},

		// OXT-Beyond: the window's opacity (0 to 255), from its stack's
		// blendLevel. The whole window is see-through, with its frame and
		// the stack's players and browser widgets, as on the desktop: for
		// the main stack, that is the page's element that holds its canvas.
		setWindowOpacity: function(pID, pLevel) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window) {
				window.opacity = Math.max(0, Math.min(pLevel, 255)) / 255;
				window.element.style.opacity = window.opacity < 1 ? String(window.opacity) : '';
			}
		},

		// OXT-Beyond: whether the window lets the mouse through to what is
		// under it in the page (its stack's ignoreMouseEvents): the whole
		// window, as the opacity, whatever its parts ask for themselves
		setWindowIgnoresMouse: function(pID, pIgnore) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window) {
				LiveCodeDC._addFrameStyles();
				window.element.classList.toggle('oxt-ignores-mouse', !!pIgnore);
			}
		},

		// The sizes that the user can resize the window to
		setWindowSizeLimits: function(pID, pMinWidth, pMinHeight, pMaxWidth, pMaxHeight) {
			var window = LiveCodeUtil.fetchObject(pID);
			if (window) {
				window.sizeLimits = [pMinWidth, pMinHeight, pMaxWidth, pMaxHeight];
			}
		},

		// The windows in the order of their layers, each layer's in the
		// order they had
		_restack: function() {
			var list = LiveCodeDC._windowList;
			var ordered = list['contents'].slice().sort(function(a, b) {
				return ((a.oxtLayer || 0) - (b.oxtLayer || 0)) ||
					(Number(a.style.zIndex) - Number(b.style.zIndex));
			});
			for (var i = 0; i < ordered.length; i++) {
				ordered[i].style.zIndex = i + 1;
			}
			list['maxZIndex'] = ordered.length + 1;
		},

		/*** Snapshots of the screen ***/

		// OXT-Beyond: what the screen (the browser's viewport) shows in
		// the rectangle <left>, <top>, <width>, <height>, drawn at
		// <outWidth> x <outHeight> into <pixels> (RGBA, 4 bytes a pixel,
		// all opaque): the stacks' windows, from the back, over the page's
		// background colour. What a page cannot draw into a canvas (the
		// rest of the page, the browser widget's frames and the players'
		// movies) is that colour. False if the browser cannot draw it.
		snapshot: function(left, top, width, height, outWidth, outHeight, pixels) {
			var out = document.createElement('canvas');
			out.width = outWidth;
			out.height = outHeight;
			var context = out.getContext('2d');
			if (!context || width <= 0 || height <= 0) {
				return false;
			}

			var background = '#ffffff';
			[document.body, document.documentElement].some(function(element) {
				var colour = element ? getComputedStyle(element).backgroundColor : '';
				if (colour && colour != 'transparent' && !/^rgba\(.*,\s*0\)$/.test(colour)) {
					background = colour;
					return true;
				}
				return false;
			});
			context.fillStyle = background;
			context.fillRect(0, 0, outWidth, outHeight);

			// The main stack's window is under the others, which are in
			// the order of their z-index
			var canvases = [];
			if (LiveCodeDC._assignedMainWindow && Module['canvas']) {
				canvases.push(Module['canvas']);
			}
			LiveCodeDC._windowList['contents'].slice().sort(function(a, b) {
				return Number(a.style.zIndex) - Number(b.style.zIndex);
			}).forEach(function(element) {
				var canvas = element.querySelector('canvas');
				if (canvas) {
					canvases.push(canvas);
				}
			});

			var scaleX = outWidth / width;
			var scaleY = outHeight / height;
			canvases.forEach(function(canvas) {
				var window = LiveCodeUtil.fetchObject(LiveCodeDC.getWindowIDForCanvas(canvas));
				if (!window || !window.visible) {
					return;
				}

				// A see-through window (setWindowOpacity()) is drawn whole
				// into a layer of its own, which then goes over the rest as
				// see-through as the page shows it
				var layer = context;
				if (window.opacity != null && window.opacity < 1) {
					var scratch = document.createElement('canvas');
					scratch.width = outWidth;
					scratch.height = outHeight;
					layer = scratch.getContext('2d') || context;
				}

				if (window.frame) {
					layer.save();
					layer.setTransform(scaleX, 0, 0, scaleY, -left * scaleX, -top * scaleY);
					LiveCodeDC._drawFrame(layer, window.frame);
					layer.restore();
				}
				var rect = canvas.getBoundingClientRect();
				if (canvas.width != 0 && canvas.height != 0 && rect.width != 0 && rect.height != 0) {
					layer.drawImage(canvas, 0, 0, canvas.width, canvas.height,
									(rect.left - left) * scaleX, (rect.top - top) * scaleY,
									rect.width * scaleX, rect.height * scaleY);
				}

				if (layer !== context) {
					context.globalAlpha = window.opacity;
					context.drawImage(layer.canvas, 0, 0);
					context.globalAlpha = 1;
				}
			});

			var data = context.getImageData(0, 0, outWidth, outHeight).data;
			HEAPU8.set(data, pixels);
			return true;
		},

		// OXT-Beyond: a window's frame in a snapshot, as the page shows it
		// (in the page's coordinates): its title bar, with its title cut
		// short as the page cuts it, its close box and its border. The
		// border's shadow is left out.
		_drawFrame: function(context, frame) {
			var shown = function(element) {
				return element.style.display != 'none';
			};
			var font = function(style) {
				return style.fontStyle + ' ' + style.fontWeight + ' ' + style.fontSize + ' ' +
					style.fontFamily;
			};
			if (!shown(frame.border)) {
				return;
			}

			if (shown(frame.title)) {
				var title = frame.title.getBoundingClientRect();
				context.fillStyle = getComputedStyle(frame.title).backgroundColor;
				context.fillRect(title.left, title.top, title.width, title.height);

				var label = frame.label.getBoundingClientRect();
				var labelStyle = getComputedStyle(frame.label);
				var padLeft = parseFloat(labelStyle.paddingLeft) || 0;
				var room = label.width - padLeft - (parseFloat(labelStyle.paddingRight) || 0);
				context.save();
				context.beginPath();
				context.rect(label.left, label.top, label.width, label.height);
				context.clip();
				context.font = font(labelStyle);
				context.fillStyle = labelStyle.color;
				context.textBaseline = 'middle';
				var text = frame.label.textContent;
				if (context.measureText(text).width > room) {
					while (text.length > 0 && context.measureText(text + '\u2026').width > room) {
						text = text.slice(0, -1);
					}
					text += '\u2026';
				}
				context.fillText(text, label.left + padLeft, label.top + label.height / 2);
				context.restore();

				if (shown(frame.close)) {
					var close = frame.close.getBoundingClientRect();
					var closeStyle = getComputedStyle(frame.close);
					context.save();
					context.fillStyle = closeStyle.backgroundColor;
					context.fillRect(close.left, close.top, close.width, close.height);
					context.font = font(closeStyle);
					context.fillStyle = closeStyle.color;
					context.textAlign = 'center';
					context.textBaseline = 'middle';
					context.fillText(frame.close.textContent, close.left + close.width / 2,
									 close.top + close.height / 2);
					context.restore();
				}
			}

			var border = frame.border.getBoundingClientRect();
			var borderStyle = getComputedStyle(frame.border);
			var line = parseFloat(borderStyle.borderTopWidth) || 0;
			if (line > 0) {
				context.strokeStyle = borderStyle.borderTopColor;
				context.lineWidth = line;
				context.strokeRect(border.left + line / 2, border.top + line / 2,
								   border.width - line, border.height - line);
			}
		},

		// OXT-Beyond: the rectangle that the user is dragging out for a
		// snapshot (import snapshot with no rect): null when there is none,
		// else its state, 'pending' until the button goes up ('done') or
		// Escape cancels it ('cancelled')
		_snapshotSelection: null,

		// The user drags out a rectangle on the page, as on the desktop:
		// the cursor is a crosshair over the whole page, which takes no
		// other mouse events meanwhile
		snapshotSelectBegin: function() {
			var overlay = document.createElement('div');
			overlay.className = 'oxt-snapshot-select';
			overlay.style.cssText = 'position: fixed; left: 0; top: 0; right: 0; bottom: 0; ' +
				'z-index: 2147483647; cursor: crosshair; touch-action: none;';
			var box = document.createElement('div');
			box.style.cssText = 'position: fixed; display: none; pointer-events: none; ' +
				'border: 1px dashed #000000; outline: 1px dashed #ffffff;';
			overlay.appendChild(box);
			document.body.appendChild(overlay);

			var selection = {'state': 'pending', 'rect': [0, 0, 0, 0]};
			LiveCodeDC._snapshotSelection = selection;
			var start = null;

			var place = function(e) {
				selection.control = e.ctrlKey;
				var x = Math.round(e.clientX), y = Math.round(e.clientY);
				var rect = [Math.min(start[0], x), Math.min(start[1], y),
							Math.max(start[0], x), Math.max(start[1], y)];
				selection.rect = rect;
				box.style.display = 'block';
				box.style.left = rect[0] + 'px';
				box.style.top = rect[1] + 'px';
				box.style.width = (rect[2] - rect[0]) + 'px';
				box.style.height = (rect[3] - rect[1]) + 'px';
			};
			var finish = function(state) {
				if (selection.state != 'pending') {
					return;
				}
				selection.state = state;
				document.removeEventListener('keydown', key, true);
				if (overlay.parentNode) {
					overlay.parentNode.removeChild(overlay);
				}

				// A click, not a drag, takes the stack's window under it,
				// or else the whole screen, as on Linux: with its frame when
				// the click is on the frame or the Control key is down
				var rect = selection.rect;
				if (state == 'done' && rect[2] - rect[0] < 4 && rect[3] - rect[1] < 4) {
					var under = document.elementFromPoint(rect[0], rect[1]);
					var id = LiveCodeDC._windowIDForElement(under);
					var bounds = null;
					if (id != 0) {
						var onFrame = LiveCodeDC.getWindowIDForCanvas(under) != id &&
							!(under.dataset && under.dataset.lcLayerWindowId);
						bounds = onFrame || selection.control ?
							LiveCodeDC.getWindowFrameRect(id) : LiveCodeDC.getWindowRect(id);
					}
					var display = LiveCodeDC.getDisplayRect();
					selection.rect = bounds ?
						[Math.round(bounds.left), Math.round(bounds.top),
						 Math.round(bounds.right), Math.round(bounds.bottom)] :
						[display.left, display.top, display.right, display.bottom];
				}
				LiveCodeAsync.resume();
			};
			selection.cancel = function() {
				finish('cancelled');
			};
			var key = function(e) {
				if (e.key == 'Escape') {
					finish('cancelled');
				}
				e.preventDefault();
				e.stopPropagation();
			};

			// The mouse's own events too, for a drag that comes with no
			// pointer events: Firefox driven by Playwright sends only those
			// (seen 2026-10-16 in Firefox 142). Once a pointer event has
			// come, the mouse events (which a browser sends after it unless
			// pointerdown is prevented, as it is here) are left alone.
			var pointer = false;
			var down = function(e) {
				start = [Math.round(e.clientX), Math.round(e.clientY)];
				place(e);
				e.preventDefault();
			};
			var move = function(e) {
				if (start) {
					place(e);
				}
				e.preventDefault();
			};
			var up = function(e) {
				if (start) {
					place(e);
					finish('done');
				}
				e.preventDefault();
			};
			overlay.addEventListener('pointerdown', function(e) {
				pointer = true;
				overlay.setPointerCapture(e.pointerId);
				down(e);
			});
			overlay.addEventListener('pointermove', function(e) {
				pointer = true;
				move(e);
			});
			overlay.addEventListener('pointerup', function(e) {
				pointer = true;
				up(e);
			});
			overlay.addEventListener('mousedown', function(e) {
				if (!pointer) {
					down(e);
				}
			});
			overlay.addEventListener('mousemove', function(e) {
				if (!pointer) {
					move(e);
				}
			});
			overlay.addEventListener('mouseup', function(e) {
				if (!pointer) {
					up(e);
				}
			});
			overlay.addEventListener('pointercancel', function() {
				finish('cancelled');
			});
			document.addEventListener('keydown', key, true);
		},

		// The selection's state: 0 while the user drags, 1 when it is done
		// (its rect is in <r>: left, top, right, bottom), 2 when it was
		// cancelled, as it is first if <cancel>. The selection is over once
		// it is not 0.
		snapshotSelectState: function(r, cancel) {
			var selection = LiveCodeDC._snapshotSelection;
			if (!selection) {
				return 2;
			}
			if (cancel) {
				selection.cancel();
			}
			if (selection.state == 'pending') {
				return 0;
			}
			LiveCodeDC._snapshotSelection = null;
			for (var i = 0; i < 4; i++) {
				HEAP32[(r >> 2) + i] = selection.rect[i];
			}
			return selection.state == 'done' ? 1 : 2;
		},
	},
	
	// OXT-Beyond: snapshots of the screen (MCScreenDC::snapshot(),
	// em-dc.cpp)
	MCEmscriptenSnapshot__deps: ['$LiveCodeDC'],
	MCEmscriptenSnapshot: function(pLeft, pTop, pWidth, pHeight, pOutWidth, pOutHeight, pPixels) {
		return LiveCodeDC.snapshot(pLeft, pTop, pWidth, pHeight, pOutWidth, pOutHeight, pPixels);
	},

	MCEmscriptenSnapshotSelectBegin__deps: ['$LiveCodeDC'],
	MCEmscriptenSnapshotSelectBegin: function() {
		LiveCodeDC.snapshotSelectBegin();
	},

	MCEmscriptenSnapshotSelectState__deps: ['$LiveCodeDC'],
	MCEmscriptenSnapshotSelectState: function(rRect, pCancel) {
		return LiveCodeDC.snapshotSelectState(rRect, pCancel);
	},

	// OXT-Beyond: the frames of the stacks' windows (MCStack::sethints(),
	// em-stack.cpp, and MCScreenDC::setname(), em-dc.cpp)
	MCEmscriptenSetWindowFrame__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowFrame: function(pWindowID, pKind, pClose, pResizable, pLayer) {
		LiveCodeDC.setWindowFrame(pWindowID, pKind, pClose, pResizable, pLayer);
	},

	MCEmscriptenSetWindowTitle__deps: ['$LiveCodeDC', '$LiveCodeUtil'],
	MCEmscriptenSetWindowTitle: function(pWindowID, pTitle, pLength) {
		LiveCodeDC.setWindowTitle(pWindowID, LiveCodeUtil.stringFromUTF16(pTitle, pLength));
	},

	MCEmscriptenSetWindowEnabled__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowEnabled: function(pWindowID, pEnabled) {
		LiveCodeDC.setWindowEnabled(pWindowID, pEnabled);
	},

	MCEmscriptenSetWindowSizeLimits__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowSizeLimits: function(pWindowID, pMinWidth, pMinHeight, pMaxWidth, pMaxHeight) {
		LiveCodeDC.setWindowSizeLimits(pWindowID, pMinWidth, pMinHeight, pMaxWidth, pMaxHeight);
	},

	MCEmscriptenSetWindowOpacity__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowOpacity: function(pWindowID, pLevel) {
		LiveCodeDC.setWindowOpacity(pWindowID, pLevel);
	},

	MCEmscriptenSetWindowIgnoresMouse__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowIgnoresMouse: function(pWindowID, pIgnore) {
		LiveCodeDC.setWindowIgnoresMouse(pWindowID, pIgnore);
	},

	MCEmscriptenGetWindowFrameRect__deps: ['$LiveCodeDC'],
	MCEmscriptenGetWindowFrameRect: function(pWindowID, rLeft, rTop, rRight, rBottom) {
		var rect = LiveCodeDC.getWindowFrameRect(pWindowID);
		{{{ makeSetValue('rLeft', '0', 'rect.left', 'i32') }}};
		{{{ makeSetValue('rTop', '0', 'rect.top', 'i32') }}};
		{{{ makeSetValue('rRight', '0', 'rect.right', 'i32') }}};
		{{{ makeSetValue('rBottom', '0', 'rect.bottom', 'i32') }}};
	},

	MCEmscriptenGetSystemAppearanceIsDark__deps: ['$LiveCodeDC'],
	MCEmscriptenGetSystemAppearanceIsDark: function() {
		return LiveCodeDC.isAppearanceDark() ? 1 : 0;
	},

	MCEmscriptenDCInitializeJS__deps: ['$LiveCodeDC'],
	MCEmscriptenDCInitializeJS: function() {
		LiveCodeDC.initialize();
		return true;
	},

	MCEmscriptenDCFinalizeJS__deps: ['$LiveCodeDC'],
	MCEmscriptenDCFinalizeJS: function() {
		LiveCodeDC.finalize();
	},

	MCEmscriptenCreateWindow__deps: ['$LiveCodeDC'],
	MCEmscriptenCreateWindow: function() {
		return LiveCodeDC.createWindow();
	},
	
	MCEmscriptenDestroyWindow__deps: ['$LiveCodeDC'],
	MCEmscriptenDestroyWindow: function(pWindowID) {
		LiveCodeDC.destroyWindow(pWindowID);
	},
	
	MCEmscriptenRaiseWindow__deps: ['$LiveCodeDC'],
	MCEmscriptenRaiseWindow: function(pWindowID) {
		LiveCodeDC.raiseWindow(pWindowID);
	},
	
	MCEmscriptenSetWindowRect__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowRect: function(pWindowID, pLeft, pTop, pRight, pBottom) {
		LiveCodeDC.setWindowRect(pWindowID, pLeft, pTop, pRight, pBottom);
	},

	MCEmscriptenGetWindowRect__deps: ['$LiveCodeDC'],
	MCEmscriptenGetWindowRect: function(pWindowID, rLeft, rTop, rRight, rBottom) {
		// OXT-Beyond: a rect of nothing for a window that is not there
		// (its stack's is gone, or it has none yet), as
		// getWindowFrameRect() answers: reading the rect of none threw,
		// in the middle of the engine's work, and the page stopped
		// taking the user's clicks (saving a stack in the web IDE)
		var rect = LiveCodeDC.getWindowRect(pWindowID) ||
			{'left': 0, 'top': 0, 'right': 0, 'bottom': 0};
		{{{ makeSetValue('rLeft', '0', 'rect.left', 'i32') }}};
		{{{ makeSetValue('rTop', '0', 'rect.top', 'i32') }}};
		{{{ makeSetValue('rRight', '0', 'rect.right', 'i32') }}};
		{{{ makeSetValue('rBottom', '0', 'rect.bottom', 'i32') }}};
	},
	
	MCEmscriptenSetWindowVisible__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowVisible: function(pWindowID, pVisible) {
		LiveCodeDC.setWindowVisible(pWindowID, pVisible);
	},
	
	MCEmscriptenGetWindowVisible__deps: ['$LiveCodeDC'],
	MCEmscriptenGetWindowVisible: function(pWindowID) {
		return LiveCodeDC.getWindowVisible(pWindowID);
	},
	
	MCEmscriptenGetDisplayRect__deps: ['$LiveCodeDC'],
	MCEmscriptenGetDisplayRect: function(rLeft, rTop, rRight, rBottom) {
		var rect = LiveCodeDC.getDisplayRect();
		{{{ makeSetValue('rLeft', '0', 'rect.left', 'i32') }}};
		{{{ makeSetValue('rTop', '0', 'rect.top', 'i32') }}};
		{{{ makeSetValue('rRight', '0', 'rect.right', 'i32') }}};
		{{{ makeSetValue('rBottom', '0', 'rect.bottom', 'i32') }}};
	},
	
	MCEmscriptenSyncCanvasSize__deps: ['$LiveCodeDC'],
	MCEmscriptenSyncCanvasSize: function(p_window_id, p_width, p_height)
	{
		var canvas = LiveCodeDC.getWindowCanvas(p_window_id);
		if (!canvas)
			return;
		
		if (canvas.width != p_width || canvas.height != p_height)
		{
			canvas.width = p_width;
			canvas.height = p_height;
		}
	},
	MCEmscriptenElementSetRect__deps: ['$LiveCodeDC'],
	MCEmscriptenElementSetRect: function(p_element, p_left, p_top, p_right, p_bottom) {
		LiveCodeDC.nativeElementSetRect(p_element, p_left, p_top, p_right, p_bottom);
	},
	MCEmscriptenElementSetClip__deps: ['$LiveCodeDC'],
	MCEmscriptenElementSetClip: function(p_element, p_left, p_top, p_right, p_bottom) {
		LiveCodeDC.nativeElementSetClip(p_element, p_left, p_top, p_right, p_bottom);
	},
	MCEmscriptenElementSetVisible__deps: ['$LiveCodeDC'],
	MCEmscriptenElementSetVisible: function(p_element, p_visible) {
		LiveCodeDC.nativeElementSetVisible(p_element, p_visible);
	},
	MCEmscriptenElementAddToWindow__deps: ['$LiveCodeDC'],
	MCEmscriptenElementAddToWindow: function(p_element, p_container) {
		LiveCodeDC.nativeElementAddToWindow(p_element, p_container);
	},
	MCEmscriptenElementRemoveFromWindow__deps: ['$LiveCodeDC'],
	MCEmscriptenElementRemoveFromWindow: function(p_element, p_container) {
		LiveCodeDC.nativeElementRemoveFromWindow(p_element, p_container);
	},
	MCEmscriptenElementPlaceAbove__deps: ['$LiveCodeDC'],
	MCEmscriptenElementPlaceAbove: function(p_element, p_above, p_container) {
		LiveCodeDC.nativeElementPlaceAbove(p_element, p_above, p_container);
	},

	MCEmscriptenCreateStandardCursor__deps: ['$LiveCodeDC'],
	MCEmscriptenCreateStandardCursor: function(p_index) {
		return LiveCodeDC.createStandardCursor(p_index);
	},

	MCEmscriptenCreateCustomCursor__deps: ['$LiveCodeDC'],
	MCEmscriptenCreateCustomCursor: function(p_pixels, p_width, p_height, p_stride, p_xhot, p_yhot) {
		return LiveCodeDC.createCustomCursor(p_pixels, p_width, p_height, p_stride, p_xhot, p_yhot);
	},

	MCEmscriptenFreeCursor__deps: ['$LiveCodeDC'],
	MCEmscriptenFreeCursor: function(p_cursor) {
		LiveCodeDC.freeCursor(p_cursor);
	},

	MCEmscriptenSetWindowCursor__deps: ['$LiveCodeDC'],
	MCEmscriptenSetWindowCursor: function(p_window_id, p_cursor) {
		LiveCodeDC.setWindowCursor(p_window_id, p_cursor);
	},

});
