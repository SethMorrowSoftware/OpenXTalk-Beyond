/*                                                                     -*-c++-*-

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

#include "prefix.h"

#include "em-dc.h"
#include "em-javascript.h"
#include "em-view.h"
#include "em-async.h"
#include "em-event.h"
#include "em-util.h"
#include "em-liburl.h"

#include "osspec.h"
#include "eventqueue.h"
#include "redraw.h"
#include "dispatch.h"
#include "globals.h"
#include "graphics_util.h"
#include "image.h"
#include "imagebitmap.h"
#include "clipboard.h"
#include "em-clipboard.h"
#include "em-printer.h"
#include "em-font.h"
#include "stacklst.h"

#include <emscripten.h>

/* ================================================================
 * Globals
 * ================================================================ */

/* Set by the event queue when it sees a third click (eventqueue.cpp),
 * as on mobile. */
Boolean tripleclick = False;

/* ================================================================
 * Helper Functions
 * ================================================================ */

MCRectangle MCEmscriptenGetWindowRect(uint32_t p_window_id)
{
	uint32_t t_left, t_top, t_right, t_bottom;
	MCEmscriptenGetWindowRect(p_window_id, &t_left, &t_top, &t_right, &t_bottom);
	
	return MCRectangleMake(t_left, t_top, t_right - t_left, t_bottom - t_top);
}

void MCEmscriptenSetWindowRect(uint32_t p_window_id, const MCRectangle &p_rect)
{
	MCEmscriptenSetWindowRect(p_window_id, p_rect.x, p_rect.y, p_rect.x + p_rect.width, p_rect.y + p_rect.height);
}

MCRectangle MCEmscriptenGetWindowFrameRect(uint32_t p_window_id)
{
	int32_t t_left, t_top, t_right, t_bottom;
	MCEmscriptenGetWindowFrameRect(p_window_id, &t_left, &t_top, &t_right, &t_bottom);

	return MCRectangleMake(t_left, t_top, t_right - t_left, t_bottom - t_top);
}

MCRectangle MCEmscriptenGetDisplayRect()
{
	uint32_t t_left, t_top, t_right, t_bottom;
	MCEmscriptenGetDisplayRect(&t_left, &t_top, &t_right, &t_bottom);
	
	return MCRectangleMake(t_left, t_top, t_right - t_left, t_bottom - t_top);
}

/* The browser's window changed size, or its pixels did (a zoom, or the
 * window moved to another screen): the screen is the part of the page
 * that the window shows, so the stacks hear desktopChanged, as the
 * desktop's do when the screens change */
extern "C" MC_DLLEXPORT_DEF bool
MCEmscriptenHandleScreenChanged()
{
	if (MCscreen == nil || !MCdefaultstackptr)
		return false;

	MCscreen->delaymessage(MCdefaultstackptr->getcurcard(), MCM_desktop_changed);
	return true;
}

/* OXT-Beyond: the window of <p_stack> moved on the screen while it was
 * on it (em-dc.js): the page moved its canvas, as a centred page does
 * when the browser's window is resized, or the user dragged it. A menu
 * that is open is a window of its own, fixed where it opened, so it
 * would be left behind: it closes, as the desktop engines close it when
 * the system cancels it (MCPlatformHandleWindowCancel()), and as a
 * browser closes a <select>'s list. A menu's own window moving (a
 * cascade opening beside it) or a tooltip's leaves it open. */
extern "C" MC_DLLEXPORT_DEF bool
MCEmscriptenHandleWindowMoved(MCStack *p_stack)
{
	if (MCnoui || p_stack == nil || MCdispatcher->getmenu() == nil)
		return false;

	switch (p_stack->getmode())
	{
		case WM_TOP_LEVEL:
		case WM_TOP_LEVEL_LOCKED:
		case WM_MODELESS:
		case WM_PALETTE:
		case WM_MODAL:
		case WM_SHEET:
		case WM_DRAWER:
			break;
		default:
			return false;
	}

	MCdispatcher->closemenus();
	return true;
}

/* OXT-Beyond: the mouse went down on the page outside every stack's
 * window, or the page lost the focus (em-event.js): a click on the page
 * around the windows, on a window's frame or on a native layer, or in
 * another window. On the desktop a menu that is open takes every click
 * until it closes, and a click outside it cancels it
 * (MCPlatformHandleWindowCancel()); on the web such a click reached no
 * stack, so the menu stayed open until its button was clicked again. It
 * closes, with no menuPick, as a click outside it on a stack closes it. */
extern "C" MC_DLLEXPORT_DEF bool
MCEmscriptenHandleMenuCancel()
{
	if (MCnoui || MCdispatcher->getmenu() == nil)
		return false;

	MCdispatcher->closemenus();
	return true;
}

/* ================================================================
 * Initialization / Finalization
 * ================================================================ */

extern "C" bool MCEmscriptenDCInitializeJS();
bool MCEmscriptenDCInitialize()
{
	return MCEmscriptenDCInitializeJS();
}

extern "C" void MCEmscriptenDCFinalizeJS();
void MCEmscriptenDCFinalize()
{
	MCEmscriptenDCFinalizeJS();
}

/* ================================================================
 * Construction/Destruction
 * ================================================================ */

MCUIDC *
MCCreateScreenDC()
{
	return new MCScreenDC;
}

MC_DLLEXPORT_DEF MCStack *
MCEmscriptenGetStackForWindow(Window p_window)
{
	if (MCnoui) return nil;
	
	MCStack *t_stack = MCdispatcher->findstackd(p_window);

	return t_stack;
}

/* OXT-Beyond: whether a stack takes the user's mouse and keys. A modal
 * dialog disables the stacks under it (MCStacklist::enableformodal(),
 * which openwindow() and closewindow() call, as the Linux engine's do),
 * and a disabled stack gets none of the page's mouse or key events, as a
 * disabled window gets none on the desktop. em-event.js asks before it
 * gives a stack the keyboard. */
static bool MCEmscriptenStackTakesEvents(MCStack *p_stack)
{
	return p_stack == nil || !p_stack->getextendedstate(ECS_DISABLED_FOR_MODAL);
}

MC_DLLEXPORT_DEF bool
MCEmscriptenStackIsEnabled(MCStack *p_stack)
{
	if (MCnoui || p_stack == nil)
		return false;

	return MCEmscriptenStackTakesEvents(p_stack);
}

/* OXT-Beyond: whether a stack is open as a menu (a pulldown, popup, option
 * or combo box list, or a cascade). On the desktop a menu takes the mouse
 * while it is open but never the keyboard, and stays where it is in the
 * stack of windows: em-event.js neither gives it the keyboard nor brings
 * it to the front when it is pressed. Given the keyboard, the menu that
 * was pressed lost it again as the press went on (its button's mdown()
 * unfocuses its menu), and that closed the cascade of the item under the
 * pointer: an item with a submenu could not be tapped open. */
MC_DLLEXPORT_DEF bool
MCEmscriptenStackIsMenu(MCStack *p_stack)
{
	if (MCnoui || p_stack == nil)
		return false;

	switch (p_stack->getmode())
	{
	case WM_PULLDOWN:
	case WM_POPUP:
	case WM_OPTION:
	case WM_CASCADE:
	case WM_COMBO:
		return true;
	default:
		return false;
	}
}

/* OXT-Beyond: whether the system would make a stack's window the active
 * one, which has the keyboard, when it opens: a toplevel stack's, a
 * dialog's or a sheet's, not a palette's, a menu's or a tooltip's */
static bool MCEmscriptenStackTakesKeyboard(MCStack *p_stack)
{
	switch (p_stack->getmode())
	{
	case WM_TOP_LEVEL:
	case WM_TOP_LEVEL_LOCKED:
	case WM_MODELESS:
	case WM_MODAL:
	case WM_SHEET:
		return true;
	default:
		return false;
	}
}

MC_DLLEXPORT_DEF
bool MCEmscriptenHandleMousePress(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, MCMousePressState p_state, int32_t p_button)
{
	if (MCnoui) return false;

	/* OXT-Beyond: not on a stack under a modal dialog */
	if (!MCEmscriptenStackTakesEvents(p_stack))
		return true;

	MCScreenDC *t_dc = static_cast<MCScreenDC *>(MCscreen);
	t_dc->update_mouse_press_state(p_state, p_button);

	/* OXT-Beyond: the button going up drops what a drag carries */
	if (t_dc->drag_mouse_press(p_state))
		return true;

	MCEventQueuePostMousePress(p_stack, p_time, p_modifiers, p_state, p_button);

	return true;
}

MC_DLLEXPORT_DEF
bool MCEmscriptenHandleMouseWheel(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, int32_t p_dh, int32_t p_dv)
{
	if (MCnoui) return false;

	/* OXT-Beyond: not on a stack under a modal dialog */
	if (!MCEmscriptenStackTakesEvents(p_stack))
		return true;

	return MCEventQueuePostMouseWheel(p_stack, p_time, p_modifiers, p_dh, p_dv);
}

static inline MCPoint MCEmscriptenWindowToGlobalLoc(MCStack *p_stack, const MCPoint &p_loc)
{
	MCRectangle t_window_rect = p_stack->view_getrect();
	return MCPointOffset(p_loc, t_window_rect.x, t_window_rect.y);
}

MC_DLLEXPORT_DEF
bool MCEmscriptenHandleMousePosition(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, int32_t p_x, int32_t p_y)
{
	if (MCnoui) return false;

	/* OXT-Beyond: not over a stack under a modal dialog */
	if (!MCEmscriptenStackTakesEvents(p_stack))
		return true;

	MCScreenDC *t_dc = static_cast<MCScreenDC *>(MCscreen);
	
	MCPoint t_position = MCPointMake(p_x, p_y);
	if (p_stack)
		t_position = MCEmscriptenWindowToGlobalLoc(p_stack, t_position);
	if (t_dc->update_mouse_position(t_position, p_stack))
		MCEventQueuePostMousePosition(p_stack, p_time, p_modifiers, p_x, p_y);

	return true;
}

/* The beep's defaults, as the Windows engine's */
#define kMCEmscriptenBeepPitch 440
#define kMCEmscriptenBeepDuration 100
#define kMCEmscriptenBeepLoudness 100

MCScreenDC::MCScreenDC()
	: m_main_window(nil), m_mouse_button_state(0),
	  m_drag_state(kMCEmscriptenDragStateNone),
	  m_beep_pitch(kMCEmscriptenBeepPitch),
	  m_beep_duration(kMCEmscriptenBeepDuration),
	  m_beep_loudness(kMCEmscriptenBeepLoudness)
{
	m_mouse_position = MCPointMake(-1,-1);
	m_mouse_stack = nil;
}

MCScreenDC::~MCScreenDC()
{
}

Boolean
MCScreenDC::open()
{
	/* OXT-Beyond: the colours of Windows 10's light theme, as the Windows
	 * engine sets them when it starts (MCWin32UpdateSystemColors, and the
	 * hilite colour that it reads from the registry) and as the web theme
	 * gives them to controls (em-theme.cpp): the background of a stack
	 * with none of its own, and the hiliteColor and accent colour, which
	 * data grids and selected text show. They were the engine's own
	 * defaults: mid grey (#C0C0C0) and navy. */
	background_pixel.red = background_pixel.green = background_pixel.blue = 0xF0F0;
	MChilitecolor.red = 0x0000;
	MChilitecolor.green = 0x7878;
	MChilitecolor.blue = 0xD7D7;
	MCaccentcolor = MChilitecolor;

	return
		MCEmscriptenJSInitialize() &&
		MCEmscriptenEventInitialize() &&
		MCEmscriptenViewInitialize() &&
        MCEmscriptenLibUrlInitialize() &&
        MCEmscriptenDCInitialize();
}


Boolean
MCScreenDC::close(Boolean force)
{
	MCEmscriptenDCFinalize();
	MCEmscriptenViewFinalize();
	MCEmscriptenEventFinalize();
    MCEmscriptenLibUrlFinalize();
    MCEmscriptenJSFinalize();

	return true;
}

/* ================================================================
 * Window management
 * ================================================================ */

void
MCScreenDC::openwindow(Window p_window,
                       Boolean override)
{
	uint32_t t_window = reinterpret_cast<uint32_t>(p_window);
	/* OXT-Beyond: the engine opens a window that is already on the screen
	 * too (setting a shown stack's visible, its decorations, ...) */
	bool t_was_visible = MCEmscriptenGetWindowVisible(t_window);
	MCLog("set window visible");
	MCEmscriptenSetWindowVisible(t_window, true);

	MCLog("find stack");
	MCStack *t_stack = MCdispatcher->findstackd(p_window);

	/* Enable drawing */
	MCLog("activate tilecache");
	t_stack->view_activatetilecache();

	t_stack->setextendedstate(false, ECS_DONTDRAW);

	/* Set up view to match window, as far as possible. The window's rect
	 * is in points (CSS pixels); its canvas has as many pixels as the
	 * device has there (MCStack::view_device_updatewindow()). */
	MCEmscriptenSetWindowRect(t_window, t_stack->view_getrect());

	t_stack->view_configure(true);
	t_stack->dirtyall();

	/* OXT-Beyond: a modal dialog disables the stacks under it, as on the
	 * desktop (lnxdcs.cpp), and the window that the system would make the
	 * active one takes the keyboard when the stacks have it. Only when it
	 * comes onto the screen: showing a window that is there already does
	 * not activate it on the desktop, so the palette or window the user
	 * clicked keeps the keyboard (the IDE's Script Editor reopens its
	 * window while the user types in the Message Box). */
	MCstacks->enableformodal(p_window, False);
	if (!t_was_visible && MCEmscriptenStackTakesKeyboard(t_stack))
		MCEmscriptenPassKeyboard(0, t_window);
}

void
MCScreenDC::closewindow(Window p_window)
{
	MCAssert(p_window);

	/* OXT-Beyond: the stacks that a modal dialog disabled are enabled
	 * again (the closing stack has left MCstacks), and when the closing
	 * window has the keyboard, the window that the system would make the
	 * active one now takes it */
	MCstacks->enableformodal(p_window, True);
	uint32_t t_next = 0;
	MCStacknode *t_top = MCstacks->topnode();
	MCStacknode *t_node = t_top;
	while (t_node != nil && t_next == 0)
	{
		MCStack *t_stack = t_node->getstack();
		if (t_stack->getw() != nil && t_stack->getw() != p_window &&
		    t_stack->isvisible() && MCEmscriptenStackTakesKeyboard(t_stack) &&
		    MCEmscriptenStackTakesEvents(t_stack))
			t_next = reinterpret_cast<uint32_t>(t_stack->getw());
		t_node = t_node->next();
		if (t_node == t_top)
			break;
	}

	uint32_t t_window = reinterpret_cast<uint32_t>(p_window);
	MCEmscriptenPassKeyboard(t_window, t_next);
	MCEmscriptenSetWindowVisible(t_window, false);
}

void
MCScreenDC::destroywindow(Window & x_window)
{
	uint32_t t_window = reinterpret_cast<uint32_t>(x_window);
	MCEmscriptenDestroyWindow(t_window);
	
	x_window = nil;
}

void
MCScreenDC::raisewindow(Window p_window)
{
	uint32_t t_window = reinterpret_cast<uint32_t>(p_window);
	MCEmscriptenRaiseWindow(t_window);
}

/* OXT-Beyond: a stack's title (or name) is in its window's title bar, as
 * on the desktop. The main stack's window is the page's canvas, which has
 * none: the page's own title is the stack's when it is built. */
void
MCScreenDC::setname(Window p_window, MCStringRef p_name)
{
	MCAutoStringRefAsUTF16String t_name;
	if (p_window == nil || !t_name.Lock(p_name))
		return;

	MCEmscriptenSetWindowTitle(reinterpret_cast<uint32_t>(p_window), t_name.Ptr(), t_name.Size());
}

/* OXT-Beyond: "start using font file": the font of a file in the engine's
 * file system is used by name, as on the desktop. A page has no fonts but
 * its own, so "globally" makes no difference here. */
bool
MCScreenDC::loadfont(MCStringRef p_path, bool p_globally, void*& r_loaded_font_handle)
{
	return MCEmscriptenCustomFontLoadFile(p_path, r_loaded_font_handle);
}

/* OXT-Beyond: "stop using font file" */
bool
MCScreenDC::unloadfont(MCStringRef p_path, bool p_globally, void *p_loaded_font_handle)
{
	return MCEmscriptenCustomFontUnloadFile(p_loaded_font_handle);
}

uintptr_t
MCScreenDC::dtouint(Drawable p_window)
{
	return reinterpret_cast<uint32_t>(p_window);
}

Boolean
MCScreenDC::uinttowindow(uintptr_t p_uint, Window &r_window)
{
	r_window = reinterpret_cast<Window>(p_uint);
	return True;
}

void *MCScreenDC::GetNativeWindowHandle(Window p_window)
{
    return (void*)dtouint(p_window);
}

bool
MCScreenDC::platform_getwindowgeometry(Window p_window,
                                       MCRectangle & r_rect)
{
	/* In points (CSS pixels), whatever the device's pixel scale */
	uint32_t t_window = reinterpret_cast<uint32_t>(p_window);
	r_rect = MCEmscriptenGetWindowRect(t_window);
	return true;
}

/* ================================================================
 * Display management
 * ================================================================ */

bool MCScreenDC::platform_getdisplays(bool p_effective, MCDisplay *&r_displays, uint32_t &r_count)
{
	MCDisplay *t_display = nil;
	if (!MCMemoryNew(t_display))
		return false;
	
	t_display->viewport = t_display->workarea = MCEmscriptenGetDisplayRect();
	t_display->pixel_scale = emscripten_get_device_pixel_ratio();
	
	r_displays = t_display;
	r_count = 1;
	return true;
}

/* ================================================================
 * Event loop
 * ================================================================ */

/* Returns true if quit is requested, or if the engine cannot yield. */
Boolean
MCScreenDC::wait(real64_t p_duration,
                 Boolean p_allow_dispatch,
                 Boolean p_accept_any_event)
{
	/* Waits nest as on the desktop: the engine yields to the browser
	 * with Asyncify, which can save the stack from inside any handler.
	 * It cannot while JavaScript has called into the engine (a handler
	 * that the page calls, or a resume hook); a wait there returns at
	 * once, as aborted, as every inner wait did in LiveCode's HTML5
	 * engine (the Emterpreter could only yield from the main loop). */
	if (!MCEmscriptenAsyncCanYield())
	{
		return true;
	}

	p_duration = MCMax(p_duration, 0.0);

	/* We allow p_duration to be infinite, but only if
	 * p_accept_any_event is set. */
	MCAssert(isfinite(p_duration) || p_accept_any_event);

	MCDeletedObjectsEnterWait(p_allow_dispatch);
	++MCwaitdepth;

	real64_t t_current_time = MCS_time();
	real64_t t_exit_time = t_current_time + p_duration;
	real64_t t_event_time = t_exit_time;

	bool t_first = true;
	bool t_done = false;

	while (!t_done && !MCquit)
	{
		/* If more than one iteration through the wait loop is needed
		 * (i.e. doing the work that was already queued didn't take
		 * long enough), wait for a timeout. */
		if (!t_first)
		{
			/* Update estimate of time remaining */
			t_current_time = MCS_time();

			real64_t t_sleep_time = MCMin(t_event_time - t_current_time,
			                              t_exit_time - t_current_time);

			/* Check if the requested wait duration has already
			 * elapsed. A pending message that fell due while the
			 * engine handled the last one does not end the wait, as
			 * it does not on the desktop: it is handled next (a wait
			 * that ended on it lost the message, when the browser ran
			 * the engine's timer late). */
			if (!t_done)
			{
				t_done = (t_exit_time - t_current_time <= 0);
			}

			/* There's still some waiting required, so give up running the
			 * engine for now and wait for an event or timeout from the
			 * browser: no time at all if a message is due, which keeps
			 * the page answering while the messages run */
			if (!t_done &&
			    MCEmscriptenAsyncYield(MCMax(t_sleep_time, 0.0)))
			{
				t_done = p_accept_any_event;
			}

			/* Update the times based on the result of the yield */
			t_current_time = MCS_time();
		}

		if (!t_done)
		{
			DoRunloopActions();
		}

		/* Dispatch pending engine messages */
		t_event_time = t_exit_time;

		if (!t_done &&
		    handlepending(t_current_time, t_event_time, p_allow_dispatch))
		{
			t_done = p_accept_any_event;
		}

		/* Dispatch queued incoming system events */
		if (!t_done &&
		    p_allow_dispatch && MCEventQueueDispatch())
		{
			t_done = p_accept_any_event;
		}

		/* Redraw the screen */
		MCRedrawUpdateScreen();

		t_first = false;
	}

	--MCwaitdepth;
	MCDeletedObjectsLeaveWait(p_allow_dispatch);

	return MCquit;
}

/* ================================================================
 * Ask/answer
 * ================================================================ */

// These functions are implemented in javascript (em-dialog.js)
extern "C" int32_t MCEmscriptenDialogShowAlert(const unichar_t* p_message, size_t p_message_length);
extern "C" bool MCEmscriptenDialogShowConfirm(const unichar_t* p_message, size_t p_message_length);
extern "C" int32_t MCEmscriptenDialogShowPrompt(const unichar_t* p_message, size_t p_message_length, const unichar_t* p_default, size_t p_default_length, unichar_t** r_result, size_t* r_result_length);

extern "C" uint32_t MCEmscriptenDialogOpen(uint32_t p_kind, uint32_t p_type, const unichar_t *p_title, size_t p_title_length, const unichar_t *p_message, size_t p_message_length, const unichar_t *p_buttons, size_t p_buttons_length, const unichar_t *p_text, size_t p_text_length);
extern "C" uint32_t MCEmscriptenDialogPickFiles(const unichar_t *p_title, size_t p_title_length, const unichar_t *p_message, size_t p_message_length, bool p_multiple, bool p_folder, const unichar_t *p_accept, size_t p_accept_length, const unichar_t *p_labels, size_t p_labels_length);
extern "C" bool MCEmscriptenDialogIsOpen(uint32_t p_id);
extern "C" int32_t MCEmscriptenDialogGetButton(uint32_t p_id);
extern "C" bool MCEmscriptenDialogGetText(uint32_t p_id, unichar_t **r_text, size_t *r_text_length);
extern "C" void MCEmscriptenDialogRelease(uint32_t p_id);
extern "C" bool MCEmscriptenOfferDownload(const unichar_t *p_path, size_t p_path_length);
extern "C" bool MCEmscriptenOpenDocument(const unichar_t *p_path, size_t p_path_length);

/* Waits until the dialog <p_id> of the page is closed, then reads what
 * it returned and forgets it. The engine goes on running its timers
 * and answering the page's events meanwhile, as in the modal loop of a
 * desktop dialog; the dialog covers the stacks' windows, so they get
 * no clicks. A click on one of its buttons resumes the engine. */
static void
MCEmscriptenDialogWait(uint32_t p_id, int32_t &r_button, MCStringRef *r_text)
{
	while (!MCquit && MCEmscriptenDialogIsOpen(p_id))
	{
		if (MCscreen->wait(60.0, True, True))
			break;
	}

	/* Closed by quitting (or a wait that could not yield): cancelled */
	if (MCEmscriptenDialogIsOpen(p_id))
		r_button = -1;
	else
		r_button = MCEmscriptenDialogGetButton(p_id);

	if (r_text != nil)
	{
		unichar_t *t_chars = nil;
		size_t t_length = 0;
		if (r_button < 0 ||
		    !MCEmscriptenDialogGetText(p_id, &t_chars, &t_length) ||
		    !MCStringCreateWithCharsAndRelease(t_chars, t_length, *r_text))
		{
			*r_text = MCValueRetain(kMCEmptyString);
		}
	}

	MCEmscriptenDialogRelease(p_id);
}

/* Converts nil to empty and locks the string as UTF-16 */
static bool
MCEmscriptenDialogLock(MCAutoStringRefAsUTF16String &x_u16, MCStringRef p_string)
{
	return x_u16.Lock(p_string != nil ? p_string : kMCEmptyString);
}

bool
MCEmscriptenShowDialog(MCEmscriptenDialogKind p_kind,
                       uint32_t p_type,
                       MCStringRef p_title,
                       MCStringRef p_message,
                       MCStringRef *p_buttons,
                       uindex_t p_button_count,
                       MCStringRef p_text,
                       int32_t &r_button,
                       MCStringRef *r_text)
{
	if (!MCEmscriptenAsyncCanYield())
		return false;

	/* The buttons' labels, one per line */
	MCAutoListRef t_list;
	MCAutoStringRef t_labels;
	if (!MCListCreateMutable('\n', &t_list))
		return false;
	for (uindex_t i = 0; i < p_button_count; i++)
	{
		MCAutoStringRef t_label;
		if (!MCStringMutableCopy(p_buttons[i], &t_label) ||
		    !MCStringFindAndReplaceChar(*t_label, '\n', ' ', kMCStringOptionCompareExact) ||
		    !MCListAppend(*t_list, *t_label))
			return false;
	}
	if (!MCListCopyAsString(*t_list, &t_labels))
		return false;

	MCAutoStringRefAsUTF16String t_title_u16, t_message_u16, t_labels_u16, t_text_u16;
	if (!MCEmscriptenDialogLock(t_title_u16, p_title) ||
	    !MCEmscriptenDialogLock(t_message_u16, p_message) ||
	    !MCEmscriptenDialogLock(t_labels_u16, *t_labels) ||
	    !MCEmscriptenDialogLock(t_text_u16, p_text))
		return false;

	uint32_t t_id = MCEmscriptenDialogOpen(p_kind, p_type,
	                                       t_title_u16.Ptr(), t_title_u16.Size(),
	                                       t_message_u16.Ptr(), t_message_u16.Size(),
	                                       t_labels_u16.Ptr(), t_labels_u16.Size(),
	                                       t_text_u16.Ptr(), t_text_u16.Size());

	MCEmscriptenDialogWait(t_id, r_button, r_text);
	return true;
}

bool
MCEmscriptenPickFiles(MCStringRef p_title,
                      MCStringRef p_message,
                      bool p_multiple,
                      bool p_folder,
                      MCStringRef p_accept,
                      MCStringRef &r_paths)
{
	if (!MCEmscriptenAsyncCanYield())
		return false;

	/* The labels of the buttons of the dialog that asks for a click to
	 * open the browser's file picker, when it needs one (UTF-8, for the
	 * ellipsis) */
	const char *t_labels_utf8;
	if (p_folder)
		t_labels_utf8 = "Cancel\nChoose Folder\u2026";
	else if (p_multiple)
		t_labels_utf8 = "Cancel\nChoose Files\u2026";
	else
		t_labels_utf8 = "Cancel\nChoose File\u2026";
	MCAutoStringRef t_labels;
	if (!MCStringCreateWithBytes(reinterpret_cast<const byte_t *>(t_labels_utf8), strlen(t_labels_utf8),
	                             kMCStringEncodingUTF8, false, &t_labels))
		return false;

	MCAutoStringRefAsUTF16String t_title_u16, t_message_u16, t_accept_u16, t_labels_u16;
	if (!MCEmscriptenDialogLock(t_title_u16, p_title) ||
	    !MCEmscriptenDialogLock(t_message_u16, p_message) ||
	    !MCEmscriptenDialogLock(t_accept_u16, p_accept) ||
	    !MCEmscriptenDialogLock(t_labels_u16, *t_labels))
		return false;

	uint32_t t_id = MCEmscriptenDialogPickFiles(t_title_u16.Ptr(), t_title_u16.Size(),
	                                            t_message_u16.Ptr(), t_message_u16.Size(),
	                                            p_multiple, p_folder,
	                                            t_accept_u16.Ptr(), t_accept_u16.Size(),
	                                            t_labels_u16.Ptr(), t_labels_u16.Size());

	int32_t t_button;
	MCAutoStringRef t_paths;
	MCEmscriptenDialogWait(t_id, t_button, &(&t_paths));

	if (t_button >= 0 && !MCStringIsEmpty(*t_paths))
		r_paths = MCValueRetain(*t_paths);
	else
		r_paths = nil;
	return true;
}

bool
MCEmscriptenDownloadFile(MCStringRef p_path)
{
	MCAutoStringRefAsUTF16String t_path_u16;
	return t_path_u16.Lock(p_path) &&
		MCEmscriptenOfferDownload(t_path_u16.Ptr(), t_path_u16.Size());
}

bool
MCEmscriptenShowDocument(MCStringRef p_path)
{
	MCAutoStringRefAsUTF16String t_path_u16;
	return t_path_u16.Lock(p_path) &&
		MCEmscriptenOpenDocument(t_path_u16.Ptr(), t_path_u16.Size());
}

int32_t
MCScreenDC::popupanswerdialog(MCStringRef *p_buttons, uint32_t p_button_count, uint32_t p_type, MCStringRef p_title, MCStringRef p_message, bool p_blocking)
{
    /* A dialog of the page, with its title, icon and buttons, when the
     * engine can wait for it. The answer command passes the type
     * kMCAnswerDialogTypePlain for no icon. */
    uint32_t t_icon = 0;
    if (p_type <= kMCAnswerDialogTypeError)
        t_icon = p_type + 1;

    MCStringRef t_ok = MCSTR("OK");
    MCStringRef *t_buttons = p_buttons;
    uint32_t t_button_count = p_button_count;
    if (t_button_count == 0)
    {
        t_buttons = &t_ok;
        t_button_count = 1;
    }

    int32_t t_button;
    if (MCEmscriptenShowDialog(kMCEmscriptenDialogKindAnswer, t_icon, p_title, p_message, t_buttons, t_button_count, kMCEmptyString, t_button, nil))
    {
        if (t_button >= int32_t(p_button_count))
            return p_button_count == 0 ? 0 : -1;
        return t_button;
    }

    /* Otherwise the browser's own alert() or confirm(), which block the
     * page until they are answered. */

    // Default to returning an unsuccessful result
    int32_t t_result = -1;
    
    // We need to have a UTF-16 string pointer for the message string. The other
    // parameters are not supported by the JavaScript built-in dialogues.
    MCAutoStringRefAsUTF16String t_message_u16;
    t_message_u16.Lock(p_message);
    
    switch (p_button_count)
    {
		case 0:
			// If no buttons specified, assume that an "OK" button is fine
        case 1:
            // Only one button - treat it as an "OK" button
            t_result = MCEmscriptenDialogShowAlert(t_message_u16.Ptr(), t_message_u16.Size());
            break;
            
        case 2:
            // Two buttons - treat it as an "OK"/"Cancel" button pair
            {
                int32_t t_ok_button = 0, t_cancel_button = 1;
                // check order of ok/cancel
                if (MCStringIsEqualToCString(p_buttons[1], "ok", kMCStringOptionCompareCaseless) ||
                    MCStringIsEqualToCString(p_buttons[0], "cancel", kMCStringOptionCompareCaseless))
                {
                    t_ok_button = 1;
                    t_cancel_button = 0;
                }
                
                if (MCEmscriptenDialogShowConfirm(t_message_u16.Ptr(), t_message_u16.Size()))
                    t_result = t_ok_button;
                else
                    t_result = t_cancel_button;
            }
            break;
            
        default:
            // Not supported
            break;
    }
    
    return t_result;
}

bool
MCScreenDC::popupaskdialog(uint32_t p_type, MCStringRef p_title, MCStringRef p_message, MCStringRef p_initial, bool p_hint, MCStringRef& r_result)
{
    /* A dialog of the page, when the engine can wait for it; ask
     * password's field shows dots for what is typed. */
    MCStringRef t_buttons[2] = { MCSTR("Cancel"), MCSTR("OK") };
    int32_t t_button;
    MCAutoStringRef t_text;
    if (MCEmscriptenShowDialog(p_type == AT_PASSWORD ? kMCEmscriptenDialogKindPassword : kMCEmscriptenDialogKindAsk,
                               p_hint ? 1 : 0, p_title, p_message, t_buttons, 2,
                               p_initial, t_button, &(&t_text)))
    {
        if (t_button != 1)
            return false;
        r_result = MCValueRetain(*t_text);
        return true;
    }

    /* Otherwise the browser's own prompt() */
    MCAutoStringRefAsUTF16String t_message_u16;
    MCAutoStringRefAsUTF16String t_default_u16;
    t_message_u16.Lock(p_message);
    t_default_u16.Lock(p_initial != nil ? p_initial : kMCEmptyString);
    
    unichar_t* t_result;
    size_t t_result_length;
    if (!MCEmscriptenDialogShowPrompt(t_message_u16.Ptr(), t_message_u16.Size(), t_default_u16.Ptr(), t_default_u16.Size(), &t_result, &t_result_length))
    {
        return false;
    }
    
    MCStringCreateWithBytesAndRelease((byte_t*)t_result, t_result_length, kMCStringEncodingUTF16, false, r_result);
    return true;
}

bool
MCScreenDC::hasfeature(MCPlatformFeature p_feature)
{
	switch (p_feature)
	{
	/* answer file, answer folder, ask file and answer color use the
	 * page's dialogs and the browser's file picker (MCA_file ... in
	 * em-osspec-misc.cpp) */
	case PLATFORM_FEATURE_OS_FILE_DIALOGS:
	case PLATFORM_FEATURE_OS_COLOR_DIALOGS:
		return true;
	/* OXT-Beyond: answer printer and answer page setup are the browser's
	 * print dialog, which opens when the pages print (em-printer.cpp) */
	case PLATFORM_FEATURE_OS_PRINT_DIALOGS:
		return true;
	default:
		return false;
	}
}

/* OXT-Beyond: the browser prints the pages (em-printer.cpp) */
MCPrinter *
MCScreenDC::createprinter(void)
{
	return MCEmscriptenPrinterCreate();
}

/* OXT-Beyond: an unlocked field has the keyboard focus (or lost it), as
 * on a phone, where its keyboard then comes up (or goes away): a touch
 * screen's keyboard comes up when the touch that focused it ends */
void
MCScreenDC::activateIME(Boolean p_activate)
{
	MCEmscriptenSetTextInput(p_activate);
}

/* ================================================================
 * Cursors
 * ================================================================ */

// Implemented in em-dc.js
extern "C" uint32_t MCEmscriptenCreateStandardCursor(uint32_t p_index);
extern "C" uint32_t MCEmscriptenCreateCustomCursor(const void *p_pixels, uint32_t p_width, uint32_t p_height, uint32_t p_stride, int32_t p_xhot, int32_t p_yhot);
extern "C" void MCEmscriptenFreeCursor(uint32_t p_cursor);
extern "C" void MCEmscriptenSetWindowCursor(uint32_t p_window, uint32_t p_cursor);

/* A cursor is a CSS cursor that em-dc.js keeps */
struct MCCursor
{
	uint32_t id;
};

static MCCursorRef
MCEmscriptenNewCursor(uint32_t p_id)
{
	MCCursorRef t_cursor = new (nothrow) MCCursor;
	if (t_cursor == nil)
	{
		MCEmscriptenFreeCursor(p_id);
		return nil;
	}
	t_cursor->id = p_id;
	return t_cursor;
}

void
MCScreenDC::resetcursors()
{
	// Make sure no stacks reference one of the standard cursors
	MCdispatcher -> clearcursors();

	/* Browsers show colour cursors with alpha, up to 128 pixels square */
	MCcursormaxsize = 128;
	MCcursorcanbealpha = MCcursorcanbecolor = True;
	MCcursorbwonly = False;

	for (uindex_t i = 0; i < PI_NCURSORS; i++)
	{
		freecursor(MCcursors[i]);
		MCcursors[i] = nil;

		/* The stacks' cursor images (ids 1 to 28), if any, as on the
		 * desktop; else the browser's cursors */
		MCImage *t_image = (MCImage *)MCdispatcher->getobjid(CT_IMAGE, i);
		if (t_image != nil)
			MCcursors[i] = t_image->createcursor();
		if (MCcursors[i] == nil)
			MCcursors[i] = MCEmscriptenNewCursor(MCEmscriptenCreateStandardCursor(i));
	}
}

void
MCScreenDC::setcursor(Window w, MCCursorRef c)
{
	// Disable cursor setting when we are a drag-target
	if (MCdispatcher -> isdragtarget())
		return;

	if (c == nil)
		c = MCcursors[PI_ARROW];

	MCEmscriptenSetWindowCursor(reinterpret_cast<uint32_t>(w), c != nil ? c->id : 0);
}

MCCursorRef
MCScreenDC::createcursor(MCImageBitmap *p_image, int2 p_xhot, int2 p_yhot)
{
	if (p_image == nil)
		return nil;

	return MCEmscriptenNewCursor(MCEmscriptenCreateCustomCursor(p_image->data, p_image->width, p_image->height, p_image->stride, p_xhot, p_yhot));
}

void
MCScreenDC::freecursor(MCCursorRef c)
{
	if (c == nil)
		return;

	MCEmscriptenFreeCursor(c->id);
	delete c;
}

/* ================================================================
 * Beep
 * ================================================================ */

// Implemented in em-dc.js
extern "C" void MCEmscriptenBeep(int32_t p_pitch, int32_t p_duration, int32_t p_loudness);

void
MCScreenDC::beep()
{
	MCEmscriptenBeep(m_beep_pitch, m_beep_duration, m_beep_loudness);
}

void
MCScreenDC::getbeep(uint4 p_property, int4& r_value)
{
	switch (p_property)
	{
	case P_BEEP_LOUDNESS:
		r_value = m_beep_loudness;
		break;
	case P_BEEP_PITCH:
		r_value = m_beep_pitch;
		break;
	case P_BEEP_DURATION:
		r_value = m_beep_duration;
		break;
	default:
		r_value = 0;
		break;
	}
}

/* -1 restores the default, as on the desktop */
void
MCScreenDC::setbeep(uint4 p_property, int4 p_value)
{
	switch (p_property)
	{
	case P_BEEP_LOUDNESS:
		m_beep_loudness = p_value < 0 ? kMCEmscriptenBeepLoudness : MCMin(p_value, 100);
		break;
	case P_BEEP_PITCH:
		m_beep_pitch = p_value < 0 ? kMCEmscriptenBeepPitch : p_value;
		break;
	case P_BEEP_DURATION:
		m_beep_duration = p_value < 0 ? kMCEmscriptenBeepDuration : p_value;
		break;
	}
}

/* ================================================================
 * Keyboard state
 * ================================================================ */

// Implemented in em-event.js
extern "C" uint32_t MCEmscriptenGetModifierKeys(void);
extern "C" uint32_t MCEmscriptenGetKeysDown(uint32_t *r_codes, uint32_t p_max);

/* As on the desktop, the keys that are down now: the page's latest key,
 * mouse or wheel event says, and the browser tells a page nothing more */
uint2
MCScreenDC::querymods()
{
	if (lockmods)
	{
		return MCmodifierstate;
	}

	uint32_t t_keys = MCEmscriptenGetModifierKeys();
	uint2 t_state = 0;
	if ((t_keys & 1) != 0)
		t_state |= MS_SHIFT;
	if ((t_keys & 2) != 0)
		t_state |= MS_MOD1;
	if ((t_keys & 4) != 0)
		t_state |= MS_CONTROL;
	if ((t_keys & 8) != 0)
		t_state |= MS_MOD2;
	if ((t_keys & 16) != 0)
		t_state |= MS_CAPS_LOCK;

	return t_state;
}

bool
MCScreenDC::getkeysdown(MCListRef& r_list)
{
	uint32_t t_codes[32];
	uint32_t t_count = MCEmscriptenGetKeysDown(t_codes, 32);

	MCAutoListRef t_list;
	if (!MCListCreateMutable(',', &t_list))
	{
		return false;
	}

	for (uint32_t i = 0; i < t_count && i < 32; i++)
	{
		if (!MCListAppendUnsignedInteger(*t_list, t_codes[i]))
		{
			return false;
		}
	}

	return MCListCopy(*t_list, r_list);
}

void
MCScreenDC::update_mouse_press_state(MCMousePressState p_state, int32_t p_button)
{
	// track mouse button pressed state
	/* NOTE - assumes there are no more than 32 mouse buttons */
	if (p_button < 32)
	{
		if (p_state == kMCMousePressStateDown)
			m_mouse_button_state |= 1UL << p_button;
		else if (p_state == kMCMousePressStateUp)
			m_mouse_button_state &= ~(1UL << p_button);
	}
}

bool
MCScreenDC::update_mouse_position(const MCPoint &p_position, MCStack *p_stack)
{
	/* OXT-Beyond: the same position in another stack is news to that
	 * stack: the mouse went from one stack's window to another's, and the
	 * events that say so are at one point (mouseleave, then mouseenter) */
	bool t_changed = !MCPointIsEqual(m_mouse_position, p_position) ||
		p_stack != m_mouse_stack;
	
	m_mouse_position = p_position;

	/* OXT-Beyond: a drag follows the mouse itself (dodragdrop()), and the
	 * stacks get the position after it, whatever it is */
	if (drag_mouse_position())
	{
		m_mouse_stack = nil;
		return false;
	}

	m_mouse_stack = p_stack;
	
	return t_changed;
}

/* OXT-Beyond: the page's events reach the engine only while it waits, so
 * a script that asks about the mouse again and again without waiting (a
 * "repeat while the mouse is down" loop) waits a little each time, as the
 * Linux and Windows engines do when it asks again within 9 ms (lnxdce.cpp,
 * w32dce.cpp): the button going up and where the mouse is come in, and the
 * stacks are drawn, but no message is sent. Before, such a loop never saw
 * the button go up, and the page stopped answering. A handler that the
 * page calls cannot wait, and gets what the engine knows. */
static bool
MCEmscriptenWaitForMouse(real64_t &x_last_time)
{
	real64_t t_interval = 9.0 / 1000.0;
	real64_t t_time = MCS_time();
	bool t_quit = false;
	if (t_time - x_last_time < t_interval && MCEmscriptenAsyncCanYield())
		t_quit = MCscreen->wait(t_interval, False, False);
	x_last_time = t_time;
	return t_quit;
}

Boolean
MCScreenDC::getmouse(uint2 p_button, Boolean& r_abort)
{
	static real64_t s_last_time = 0.0;
	r_abort = MCEmscriptenWaitForMouse(s_last_time);
	if (r_abort)
		return False;

	// return recorded mouse button state
	if (p_button < 32)
		return (m_mouse_button_state & (1 << p_button)) != 0;

	return false;
}

/* OXT-Beyond: whether the mouse was clicked, and the click not yet sent
 * to the stacks: the click is taken from the event queue, as the Windows
 * engine takes it when it draws its windows itself (w32dce.cpp). Before,
 * the mouseClick was always false on the web, so "wait until the
 * mouseClick" never ended. */
Boolean
MCScreenDC::getmouseclick(uint2 p_button, Boolean& r_abort)
{
	static real64_t s_last_time = 0.0;
	r_abort = MCEmscriptenWaitForMouse(s_last_time);
	if (r_abort)
		return False;

	return MCEventQueueGetMouseClick(p_button);
}

void
MCScreenDC::platform_querymouse(int16_t& r_x, int16_t& r_y)
{
    // There is no asynchronous mouse position in Emscripten; just whatever the
    // browser has told us about.
    r_x = m_mouse_position.x;
    r_y = m_mouse_position.y;
}

/* ================================================================
 * Drag and drop
 * ================================================================ */

/* OXT-Beyond: drag and drop between the stacks in the page, as the
 * desktop engines have it between their windows. A drag starts when the
 * mouse moves dragDelta points with a button down (eventqueue.cpp), and
 * the dragStart handler puts what it carries on the dragboard; the drag
 * then follows the mouse here, as a desktop's drag loop does
 * (lnxdnd.cpp): the stack under the pointer gets dragEnter, dragMove
 * and dragLeave, and the one under it when the button goes up gets
 * dragDrop, then the source dragEnd. The page draws the drag's image
 * under the pointer, and a cursor that says what a drop there would do.
 * What the drag carries stays in the engine: the browser's own drag and
 * drop, to other pages and applications, is not the engine's. What they
 * drag can be dropped on a stack, though (below). */

/* Why a drag was cancelled (LiveCodeEvents.kDragCancel*, em-event.js) */
enum
{
	kMCEmscriptenDragCancelNone,
	kMCEmscriptenDragCancelEscape,
	kMCEmscriptenDragCancelLost,
};

// Implemented in em-event.js
extern "C" void MCEmscriptenDragBegin(const void *p_pixels, uint32_t p_width, uint32_t p_height, uint32_t p_stride, int32_t p_xoffset, int32_t p_yoffset);
extern "C" uint32_t MCEmscriptenDragGetTarget(int32_t *r_x, int32_t *r_y);
extern "C" uint32_t MCEmscriptenDragGetCancel(void);
extern "C" void MCEmscriptenDragSetAction(uint32_t p_action);
extern "C" void MCEmscriptenDragEnd(void);

/* The window that the pointer is over, if it is a stack's, and where in
 * it the pointer is */
static Window
MCEmscriptenDragTarget(MCPoint &r_location)
{
	int32_t t_x = 0, t_y = 0;
	Window t_window = reinterpret_cast<Window>(MCEmscriptenDragGetTarget(&t_x, &t_y));
	if (t_window != nil && MCdispatcher->findstackd(t_window) == nil)
		t_window = nil;

	r_location = MCPointMake(t_x, t_y);
	return t_window;
}

/* What a drop does: the stack's choice, made one that the source allows,
 * as on Windows (CDropTarget::DragOver(), w32dnd.cpp): a move or a link
 * that it does not allow is a copy */
static MCDragAction
MCEmscriptenDragAllowedAction(MCDragAction p_action, MCDragActionSet p_allowed_actions)
{
	if ((p_action == DRAG_ACTION_MOVE || p_action == DRAG_ACTION_LINK) &&
	    (p_allowed_actions & p_action) == 0)
		return DRAG_ACTION_COPY;
	return p_action;
}

MCDragAction
MCScreenDC::dodragdrop(Window w,
                       MCDragActionSet p_allowed_actions,
                       MCImage *p_image,
                       const MCPoint *p_image_offset)
{
	/* The drag waits for the page's events, which the engine cannot do in
	 * a handler that the page called (wait()). The button that started it
	 * is still down, unless it went up while dragStart ran. */
	if (!MCEmscriptenAsyncCanYield() ||
	    m_drag_state != kMCEmscriptenDragStateNone ||
	    m_mouse_button_state == 0)
	{
		return DRAG_ACTION_NONE;
	}

	/* The drag's image follows the pointer, which is dragImageOffset from
	 * its top left */
	MCImageBitmap *t_bitmap = nil;
	if (p_image != nil && !p_image->lockbitmap(t_bitmap, true))
		t_bitmap = nil;
	MCEmscriptenDragBegin(t_bitmap != nil ? t_bitmap->data : nil,
	                      t_bitmap != nil ? t_bitmap->width : 0,
	                      t_bitmap != nil ? t_bitmap->height : 0,
	                      t_bitmap != nil ? t_bitmap->stride : 0,
	                      p_image_offset != nil ? p_image_offset->x : 0,
	                      p_image_offset != nil ? p_image_offset->y : 0);
	if (t_bitmap != nil)
		p_image->unlockbitmap(t_bitmap);

	/* The drag has the mouse now: the press that started it is over for
	 * the stacks, as on a Mac (MCMacPlatformSyncMouseBeforeDragging(),
	 * mac-core.mm), and its button going up drops what the drag carries */
	MCbuttonstate = 0;
	m_drag_state = kMCEmscriptenDragStateDragging;

	uint16_t t_old_modifiers = MCmodifierstate;

	Window t_over = nil;
	MCDragAction t_action = DRAG_ACTION_NONE;
	for (;;)
	{
		/* Escape cancels the drag, as on the desktop, and so does the page
		 * losing the mouse (when it may not hear the button go up) */
		uint32_t t_cancel = MCEmscriptenDragGetCancel();
		if (t_cancel != kMCEmscriptenDragCancelNone)
		{
			if (m_drag_state == kMCEmscriptenDragStateDragging &&
			    t_cancel == kMCEmscriptenDragCancelEscape)
				m_drag_state = kMCEmscriptenDragStateCancelled;
			else if (m_drag_state == kMCEmscriptenDragStateDragging ||
			         m_drag_state == kMCEmscriptenDragStateDropped)
				m_drag_state = kMCEmscriptenDragStateAborted;
		}

		if (MCquit ||
		    m_drag_state == kMCEmscriptenDragStateCancelled ||
		    m_drag_state == kMCEmscriptenDragStateAborted)
		{
			break;
		}

		/* The drag leaves the stack that it was over for the one under
		 * the pointer now, which says what a drop there would do (as the
		 * modifier keys can change it, they are the keys down now, as in
		 * a desktop's drag loop) */
		MCmodifierstate = querymods();

		MCPoint t_location;
		Window t_window = MCEmscriptenDragTarget(t_location);
		if (t_window != t_over)
		{
			if (t_over != nil)
				MCdispatcher->wmdragleave(t_over);
			t_over = t_window;
			if (t_over != nil)
				MCdispatcher->wmdragenter(t_over);
		}

		t_action = DRAG_ACTION_NONE;
		if (t_over != nil)
			t_action = MCEmscriptenDragAllowedAction(MCdispatcher->wmdragmove(t_over, t_location.x, t_location.y),
			                                         p_allowed_actions);
		MCEmscriptenDragSetAction(t_action);

		/* The button went up where the pointer is now */
		if (m_drag_state != kMCEmscriptenDragStateDragging)
			break;

		/* Wait for the mouse to move or its button to go up. Only the
		 * engine's own timers run meanwhile (a field scrolls as a drag
		 * nears its edge), as in a desktop's drag loop. */
		if (wait(60.0, False, True))
			break;
	}

	/* The stack under the pointer takes the drop, if it takes one at all;
	 * otherwise the drag leaves it */
	MCDragAction t_result = DRAG_ACTION_NONE;
	if (t_over != nil)
	{
		if (m_drag_state == kMCEmscriptenDragStateDropped &&
		    t_action != DRAG_ACTION_NONE)
			t_result = MCEmscriptenDragAllowedAction(MCdispatcher->wmdragdrop(t_over),
			                                         p_allowed_actions);
		else
			MCdispatcher->wmdragleave(t_over);
	}

	MCEmscriptenDragEnd();
	MCmodifierstate = t_old_modifiers;

	/* After Escape, the drag has the mouse until its button goes up
	 * (drag_mouse_press()) */
	if (m_drag_state != kMCEmscriptenDragStateCancelled)
		m_drag_state = kMCEmscriptenDragStateNone;

	/* The mouse's events are the stacks' again, from the stack where the
	 * drag ended, as on the desktop when a drag is over */
	MCPoint t_location;
	Window t_window = MCEmscriptenDragTarget(t_location);
	if (t_window != nil)
	{
		MCStack *t_stack = MCdispatcher->findstackd(t_window);
		MCEventQueuePostMouseFocus(t_stack, MCeventtime, true);
		MCEventQueuePostMousePosition(t_stack, MCeventtime, MCmodifierstate,
		                              t_location.x, t_location.y);
	}

	return t_result;
}

bool
MCScreenDC::drag_mouse_position(void)
{
	return m_drag_state == kMCEmscriptenDragStateDragging ||
		m_drag_state == kMCEmscriptenDragStateCancelled;
}

bool
MCScreenDC::drag_mouse_press(MCMousePressState p_state)
{
	switch (m_drag_state)
	{
	case kMCEmscriptenDragStateDragging:
		/* The button went up, or the browser cancelled the touch that was
		 * the mouse */
		if (p_state == kMCMousePressStateUp)
			m_drag_state = kMCEmscriptenDragStateDropped;
		else if (p_state == kMCMousePressStateRelease)
			m_drag_state = kMCEmscriptenDragStateAborted;
		return true;

	case kMCEmscriptenDragStateCancelled:
		/* The drag that Escape cancelled is over when the button goes up;
		 * a press that comes first (the button went up away from the
		 * page) is the stacks' */
		m_drag_state = kMCEmscriptenDragStateNone;
		return p_state != kMCMousePressStateDown;

	default:
		return false;
	}
}

/* ----------------------------------------------------------------
 * Drops from outside the page
 * ---------------------------------------------------------------- */

/* OXT-Beyond: files and folders, text and HTML dragged from another page
 * or application can be dropped on a stack (em-event.js). The browser
 * shows what such a drag carries only when it is dropped, so the stack
 * under the pointer hears of the drag then, as one that ends there would
 * on the desktop (CDropTarget::Drop(), w32dnd.cpp): dragEnter and
 * dragMove, then dragDrop if it takes the drop, dragLeave if it does not.
 * The files and folders are copied into /uploads first, as the files that
 * the user picks are, and the dragData["files"] has their copies' paths. */

// Implemented in em-event.js
extern "C" bool MCEmscriptenDropIsPending(uint32_t p_drop);
extern "C" bool MCEmscriptenDropGetFiles(uint32_t p_drop, unichar_t **r_paths, size_t *r_length);
extern "C" void MCEmscriptenDropRelease(uint32_t p_drop);

/* Puts <p_string> (if any) on the dragboard, as the representation
 * <p_type>: returns true if it did */
static bool
MCEmscriptenDropAdd(MCEmscriptenRawClipboard *p_board, MCRawClipboardKnownType p_type, MCStringRef p_string)
{
	MCAutoDataRef t_data;
	return p_string != nil && !MCStringIsEmpty(p_string) &&
		MCStringEncode(p_string, kMCStringEncodingUTF8, false, &t_data) &&
		p_board->AddExternalData(p_type, *t_data);
}

class MCEmscriptenDropEvent: public MCCustomEvent
{
public:
	/* Takes <p_text> and <p_html>, which may be nil. <p_drop> is the
	 * page's drop whose files and folders are being copied, or 0. */
	MCEmscriptenDropEvent(Window p_window, uint32_t p_time, uint32_t p_modifiers,
	                      int32_t p_x, int32_t p_y,
	                      MCStringRef p_text, MCStringRef p_html, uint32_t p_drop)
		: m_window(p_window), m_time(p_time), m_modifiers(p_modifiers),
		  m_x(p_x), m_y(p_y), m_text(p_text), m_html(p_html), m_drop(p_drop)
	{
	}

	virtual void Destroy(void)
	{
		MCValueRelease(m_text);
		MCValueRelease(m_html);
		if (m_drop != 0)
			MCEmscriptenDropRelease(m_drop);
		delete this;
	}

	virtual void Dispatch(void)
	{
		/* The files are copied first. The stacks' other events wait
		 * meanwhile, as they do in a drag. */
		while (m_drop != 0 && !MCquit && MCEmscriptenDropIsPending(m_drop))
		{
			if (MCscreen->wait(60.0, False, True))
				break;
		}

		MCAutoStringRef t_files;
		if (m_drop != 0)
		{
			unichar_t *t_paths = nil;
			size_t t_length = 0;
			if (!MCEmscriptenDropIsPending(m_drop) &&
			    MCEmscriptenDropGetFiles(m_drop, &t_paths, &t_length) &&
			    !MCStringCreateWithCharsAndRelease(t_paths, t_length, &t_files))
			{
				free(t_paths);
			}
			MCEmscriptenDropRelease(m_drop);
			m_drop = 0;
		}

		/* The drop is over a stack's window, not one under a modal dialog,
		 * and no drag is going on */
		MCStack *t_stack = MCdispatcher->findstackd(m_window);
		if (MCquit || t_stack == nil || !MCEmscriptenStackTakesEvents(t_stack) ||
		    MCdispatcher->isdragsource() || MCdispatcher->isdragtarget())
			return;

		/* The dragboard has what was dropped, as a drag from another
		 * application has */
		MCdragboard->Clear();
		MCEmscriptenRawClipboard *t_board =
			static_cast<MCEmscriptenRawClipboard *>(MCdragboard->GetRawClipboard());
		t_board->BeginExternalData();
		bool t_carries = false;
		if (MCEmscriptenDropAdd(t_board, kMCRawClipboardKnownTypeUTF8, m_text))
			t_carries = true;
		if (MCEmscriptenDropAdd(t_board, kMCRawClipboardKnownTypeHTML, m_html))
			t_carries = true;
		if (MCEmscriptenDropAdd(t_board, kMCRawClipboardKnownTypeFileURLList, *t_files))
			t_carries = true;
		if (!t_carries)
		{
			MCdragboard->Clear();
			return;
		}

		uint16_t t_old_modifiers = MCmodifierstate;
		MCmodifierstate = m_modifiers;

		/* The pointer comes from outside the window, so the stack works
		 * out what is under it afresh (wmdragmove() does only when the
		 * mouse has moved) */
		if (MCmousestackptr)
			MCmousestackptr->munfocus();
		MCmousex = MCmousey = -MAXINT2;

		MCdispatcher->wmdragenter(m_window);
		if (MCdispatcher->wmdragmove(m_window, m_x, m_y) != DRAG_ACTION_NONE)
			MCdispatcher->wmdragdrop(m_window);
		else
			MCdispatcher->wmdragleave(m_window);

		MCmodifierstate = t_old_modifiers;

		/* The mouse's events are the stack's again, from where the drop
		 * was, as when a drag is over (dodragdrop()) */
		t_stack = MCdispatcher->findstackd(m_window);
		if (t_stack != nil)
		{
			MCScreenDC *t_dc = static_cast<MCScreenDC *>(MCscreen);
			t_dc->update_mouse_position(MCEmscriptenWindowToGlobalLoc(t_stack, MCPointMake(m_x, m_y)), t_stack);
			MCEventQueuePostMouseFocus(t_stack, m_time, true);
			MCEventQueuePostMousePosition(t_stack, m_time, m_modifiers, m_x, m_y);
		}
	}

private:
	Window m_window;
	uint32_t m_time;
	uint32_t m_modifiers;
	int32_t m_x, m_y;
	MCStringRef m_text;
	MCStringRef m_html;
	uint32_t m_drop;
};

/* Something was dropped from outside the page at <p_x>, <p_y> in the
 * window <p_window> (em-event.js): text, HTML (UTF-8, as on the
 * clipboard) and the drop <p_drop> whose files and folders are being
 * copied into /uploads (0 if none). Takes <p_text> and <p_html>, which
 * may be nil. */
MC_DLLEXPORT_DEF bool
MCEmscriptenHandleDrop(uint32_t p_window, uint32_t p_time, uint32_t p_modifiers,
                       int32_t p_x, int32_t p_y,
                       MCStringRef p_text, MCStringRef p_html, uint32_t p_drop)
{
	MCEmscriptenDropEvent *t_event = nil;
	if (!MCnoui)
		t_event = new (nothrow) MCEmscriptenDropEvent(reinterpret_cast<Window>(p_window),
		                                              p_time, p_modifiers, p_x, p_y,
		                                              p_text, p_html, p_drop);
	if (t_event == nil)
	{
		MCValueRelease(p_text);
		MCValueRelease(p_html);
		if (p_drop != 0)
			MCEmscriptenDropRelease(p_drop);
		return false;
	}

	if (!MCEventQueuePostCustom(t_event))
	{
		t_event->Destroy();
		return false;
	}
	return true;
}

/* ================================================================
 * Window frames
 * ================================================================ */

/* OXT-Beyond: the user clicked the close box in the title bar of a stack's
 * window (em-dc.js): the stack hears closeStackRequest and closes unless
 * it handles it, as when the user closes a window on the desktop */
class MCEmscriptenWindowCloseEvent: public MCCustomEvent
{
public:
	MCEmscriptenWindowCloseEvent(Window p_window)
		: m_window(p_window)
	{
	}

	virtual void Destroy(void)
	{
		delete this;
	}

	virtual void Dispatch(void)
	{
		/* Not after the stack's window went, nor while a drag is going
		 * on: the stack might be its source or its target */
		if (MCquit || MCdispatcher->findstackd(m_window) == nil ||
		    MCdispatcher->isdragsource() || MCdispatcher->isdragtarget())
			return;

		MCdispatcher->wclose(m_window);
	}

private:
	Window m_window;
};

MC_DLLEXPORT_DEF bool
MCEmscriptenHandleWindowClose(uint32_t p_window)
{
	MCEmscriptenWindowCloseEvent *t_event = nil;
	if (!MCnoui)
		t_event = new (nothrow) MCEmscriptenWindowCloseEvent(reinterpret_cast<Window>(p_window));
	if (t_event == nil)
		return false;

	if (!MCEventQueuePostCustom(t_event))
	{
		t_event->Destroy();
		return false;
	}
	return true;
}

/* ================================================================
 * The system's appearance
 * ================================================================ */

/* OXT-Beyond: the web engine said "light" for the systemAppearance whatever
 * the browser's colour scheme, so a stack drew in the light colours in a
 * browser set to dark, while the desktop engines follow the system (Paul,
 * openxtalk.org p=25208; bwmilby p=25615). A page that asks for it, with
 * <meta name="oxt-appearance" content="system"> (the "Appearance" setting
 * of the Standalone Settings' HTML5 pane), now gets the browser's scheme,
 * and the systemAppearanceChanged message when it changes, as the desktop
 * engines do. A page without it, which every page was, keeps "light", so
 * that a stack made for the light colours looks as it did. The colours of
 * each appearance are em-theme.cpp's. */

extern "C" int32_t MCEmscriptenGetSystemAppearanceIsDark(void);

void
MCScreenDC::getsystemappearance(MCSystemAppearance &r_appearance)
{
	if (MCEmscriptenGetSystemAppearanceIsDark() != 0)
		r_appearance = kMCSystemAppearanceDark;
	else
		r_appearance = kMCSystemAppearanceLight;
}

/* Every stack is drawn again in the colours of the new appearance (they are
 * read as the stacks draw), and the current card gets the message, as on
 * the desktop (MCPlatformHandleSystemAppearanceChanged in desktop.cpp) */
class MCEmscriptenSystemAppearanceChangedEvent: public MCCustomEvent
{
public:
	virtual void Destroy(void)
	{
		delete this;
	}

	virtual void Dispatch(void)
	{
		if (MCquit || MCstacks == nil)
			return;

		MCStacknode *t_node = MCstacks->topnode();
		if (t_node != nil)
		{
			MCStacknode *t_start = t_node;
			do
			{
				MCStack *t_stack = t_node->getstack();
				if (t_stack != nil)
					t_stack->dirtyall();
				t_node = t_node->next();
			} while (t_node != nil && t_node != t_start);
		}

		if (MCdefaultstackptr && MCdefaultstackptr->getcurcard() != nil)
			MCscreen->delaymessage(MCdefaultstackptr->getcurcard(), MCM_system_appearance_changed);
	}
};

extern "C" MC_DLLEXPORT_DEF bool
MCEmscriptenHandleSystemAppearanceChanged(void)
{
	MCEmscriptenSystemAppearanceChangedEvent *t_event = nil;
	if (!MCnoui)
		t_event = new (nothrow) MCEmscriptenSystemAppearanceChangedEvent;
	if (t_event == nil)
		return false;

	if (!MCEventQueuePostCustom(t_event))
	{
		t_event->Destroy();
		return false;
	}
	return true;
}

/* ================================================================
 * Snapshots of the screen
 * ================================================================ */

/* OXT-Beyond: the page's side of snapshots (em-dc.js) */
extern "C" bool MCEmscriptenSnapshot(int32_t p_left, int32_t p_top, int32_t p_width, int32_t p_height,
                                     int32_t p_out_width, int32_t p_out_height, void *r_pixels);
extern "C" void MCEmscriptenSnapshotSelectBegin(void);
extern "C" int32_t MCEmscriptenSnapshotSelectState(int32_t *r_rect, bool p_cancel);

/* OXT-Beyond: a snapshot of the screen, which is the browser's viewport,
 * as the desktop engines take one (import snapshot, export snapshot, the
 * mouseColor): what the stacks' windows show in the rect <r>, of the
 * window <p_window> unless it is 0, at the size <p_size> unless it is nil.
 * The rest of the page, the browser widget's frames and the players'
 * movies, which a page cannot read, are the page's background colour.
 *
 * As on Linux, with no rect and no window (r.x is -32768) the user drags
 * out the rect on the page first, and a click takes the window under it;
 * Escape cancels. A window's empty rect is the whole window. Nil if there
 * is nothing to take, the user cancelled, or the engine cannot wait for
 * the user (in a handler that the page called). */
MCImageBitmap *
MCScreenDC::snapshot(MCRectangle &r, uint4 p_window, MCStringRef p_display, MCPoint *p_size)
{
	/* The page is the only display */
	if (p_display != nil && !MCStringIsEmpty(p_display))
		return nil;

	if (p_window == 0 && r.x == -32768)
	{
		if (!MCEmscriptenAsyncCanYield())
			return nil;

		MCEmscriptenSnapshotSelectBegin();
		int32_t t_selected[4] = {0, 0, 0, 0};
		int32_t t_state;
		while ((t_state = MCEmscriptenSnapshotSelectState(t_selected, false)) == 0)
		{
			if (MCquit || MCscreen->wait(60.0, False, True))
			{
				t_state = MCEmscriptenSnapshotSelectState(t_selected, true);
				break;
			}
		}
		if (t_state != 1)
			return nil;

		r = MCU_make_rect(t_selected[0], t_selected[1],
		                  t_selected[2] - t_selected[0], t_selected[3] - t_selected[1]);
	}

	MCRectangle t_rect = r;
	if (p_window != 0)
	{
		Window t_window = reinterpret_cast<Window>(p_window);
		if (MCdispatcher->findstackd(t_window) == nil)
			return nil;

		MCRectangle t_window_rect = MCEmscriptenGetWindowRect(p_window);
		if (t_rect.width == 0 || t_rect.height == 0)
			t_rect = MCU_make_rect(0, 0, t_window_rect.width, t_window_rect.height);
		t_rect.x += t_window_rect.x;
		t_rect.y += t_window_rect.y;
	}

	if (t_rect.width == 0 || t_rect.height == 0)
		return nil;

	uindex_t t_width = t_rect.width;
	uindex_t t_height = t_rect.height;
	if (p_size != nil)
	{
		t_width = MCMax(p_size->x, 1);
		t_height = MCMax(p_size->y, 1);
	}

	MCImageBitmap *t_bitmap = nil;
	if (!MCImageBitmapCreate(t_width, t_height, t_bitmap))
		return nil;

	/* Its rows are 4 bytes a pixel, as the page writes them */
	if (t_bitmap->stride != t_width * 4 ||
	    !MCEmscriptenSnapshot(t_rect.x, t_rect.y, t_rect.width, t_rect.height,
	                          t_width, t_height, t_bitmap->data))
	{
		MCImageFreeBitmap(t_bitmap);
		return nil;
	}

	return t_bitmap;
}
