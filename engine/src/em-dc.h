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

#ifndef __MC_EMSCRIPTEN_DC_H__
#define __MC_EMSCRIPTEN_DC_H__

#include <foundation.h>

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "sysdefs.h"
#include "stack.h"
#include "uidc.h"
#include "eventqueue.h"

MCUIDC *MCCreateScreenDC(void);

extern bool MCEmscriptenDCInitialize();
extern void MCEmscriptenDCFinalize();

extern "C" void MCEmscriptenGetDisplayRect(uint32_t *r_left, uint32_t *r_top, uint32_t *r_right, uint32_t *r_bottom);

extern "C" MCStack *MCEmscriptenGetStackForWindow(Window p_window);
extern "C" bool MCEmscriptenHandleMousePress(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, MCMousePressState p_state, int32_t p_button);
extern "C" bool MCEmscriptenHandleMousePosition(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, int32_t p_x, int32_t p_y);
extern "C" bool MCEmscriptenHandleMouseWheel(MCStack *p_stack, uint32_t p_time, uint32_t p_modifiers, int32_t p_dh, int32_t p_dv);
/* OXT-Beyond: whether a touch screen's keyboard comes up (em-event.js) */
extern "C" void MCEmscriptenSetTextInput(bool p_active);
/* OXT-Beyond: whether a stack takes the user's mouse and keys (not while a
 * modal dialog is above it) */
extern "C" bool MCEmscriptenStackIsEnabled(MCStack *p_stack);
/* OXT-Beyond: whether a stack is open as a menu, which a press neither
 * gives the keyboard nor brings to the front (em-event.js) */
extern "C" bool MCEmscriptenStackIsMenu(MCStack *p_stack);
/* OXT-Beyond: the keyboard goes to the stack of the window p_to (to none
 * if 0) when the stacks have it (p_from 0) or the window p_from has it
 * (em-event.js) */
extern "C" void MCEmscriptenPassKeyboard(uint32_t p_from, uint32_t p_to);
/* OXT-Beyond: something dropped on a stack from outside the page */
extern "C" bool MCEmscriptenHandleDrop(uint32_t p_window, uint32_t p_time, uint32_t p_modifiers, int32_t p_x, int32_t p_y, MCStringRef p_text, MCStringRef p_html, uint32_t p_drop);

/* OXT-Beyond: the frame of a window other than the main stack's, as a
 * desktop gives a window its decorations (MCStack::sethints(),
 * em-stack.cpp; em-dc.js): none, a title bar, or a palette's narrower
 * one, with a close box or not, and edges that resize the window or not.
 * Each window is in a layer, which the page keeps above the layers before
 * it. */
enum MCEmscriptenWindowFrame
{
	kMCEmscriptenWindowFrameNone,
	kMCEmscriptenWindowFrameTitle,
	kMCEmscriptenWindowFrameUtility,
};
enum MCEmscriptenWindowLayer
{
	kMCEmscriptenWindowLayerNormal,
	kMCEmscriptenWindowLayerPalette,
	kMCEmscriptenWindowLayerModal,
	kMCEmscriptenWindowLayerPopup,
};
extern "C" void MCEmscriptenSetWindowFrame(uint32_t p_window_id, int32_t p_frame, bool p_close, bool p_resizable, int32_t p_layer);
/* The title in a window's title bar */
extern "C" void MCEmscriptenSetWindowTitle(uint32_t p_window_id, const unichar_t *p_title, size_t p_length);
/* Whether the user can move, resize and close a window: not while a
 * modal dialog is above it */
extern "C" void MCEmscriptenSetWindowEnabled(uint32_t p_window_id, bool p_enabled);
/* The sizes that the user can resize a window to */
extern "C" void MCEmscriptenSetWindowSizeLimits(uint32_t p_window_id, int32_t p_min_width, int32_t p_min_height, int32_t p_max_width, int32_t p_max_height);
/* Where a window is with its frame (its rect when it has none) */
extern "C" void MCEmscriptenGetWindowFrameRect(uint32_t p_window_id, int32_t *r_left, int32_t *r_top, int32_t *r_right, int32_t *r_bottom);
/* The user clicked the close box of a window's frame */
extern "C" bool MCEmscriptenHandleWindowClose(uint32_t p_window);
/* OXT-Beyond: a window's opacity (0 to 255), and whether it lets the
 * mouse through to what is under it (em-dc.js) */
extern "C" void MCEmscriptenSetWindowOpacity(uint32_t p_window_id, uint32_t p_level);
extern "C" void MCEmscriptenSetWindowIgnoresMouse(uint32_t p_window_id, bool p_ignore);

extern "C" uint32_t MCEmscriptenCreateWindow();
extern "C" void MCEmscriptenDestroyWindow(uint32_t p_window_id);
extern "C" void MCEmscriptenRaiseWindow(uint32_t p_window_id);
extern "C" void MCEmscriptenSetWindowRect(uint32_t p_window_id, uint32_t p_left, uint32_t p_top, uint32_t p_right, uint32_t p_bottom);
extern "C" void MCEmscriptenGetWindowRect(uint32_t p_window_id, uint32_t *r_left, uint32_t *r_top, uint32_t *r_right, uint32_t *r_bottom);
extern "C" void MCEmscriptenSetWindowVisible(uint32_t p_window_id, bool p_visible);
extern "C" bool MCEmscriptenGetWindowVisible(uint32_t p_window_id);

extern "C" void MCEmscriptenSyncCanvasSize(uint32_t p_window_id, uint32_t p_width, uint32_t p_height);

/* ---------------------------------------------------------------- */

MCRectangle MCEmscriptenGetWindowRect(uint32_t p_window_id);
void MCEmscriptenSetWindowRect(uint32_t p_window_id, const MCRectangle &p_rect);
/* OXT-Beyond: where the window is with its frame */
MCRectangle MCEmscriptenGetWindowFrameRect(uint32_t p_window_id);

/* ----------------------------------------------------------------
 * The page's dialogs (em-dialog.js)
 * ---------------------------------------------------------------- */

/* The kinds of dialog (LiveCodeDialog.kAnswer ...) */
enum MCEmscriptenDialogKind
{
	kMCEmscriptenDialogKindAnswer,
	kMCEmscriptenDialogKindAsk,
	kMCEmscriptenDialogKindPassword,
	kMCEmscriptenDialogKindColor,
	kMCEmscriptenDialogKindChoose,
	kMCEmscriptenDialogKindSave,
};

/* Shows a dialog of the page and waits until one of its buttons is
 * clicked, answering timers and events meanwhile as a modal dialog's
 * loop does on the desktop. r_button is the index of the button
 * clicked (-1 if it was closed otherwise), and r_text (unless nil) the
 * text of the dialog's field.
 *
 * p_type is an answer dialog's icon (0: none, then the
 * kMCAnswerDialogType* plus one), or for an ask dialog, 1 if p_text is
 * a hint rather than the field's initial text.
 *
 * Returns false, showing nothing, when the engine cannot wait (in a
 * handler that the page called). */
bool MCEmscriptenShowDialog(MCEmscriptenDialogKind p_kind,
                            uint32_t p_type,
                            MCStringRef p_title,
                            MCStringRef p_message,
                            MCStringRef *p_buttons,
                            uindex_t p_button_count,
                            MCStringRef p_text,
                            int32_t &r_button,
                            MCStringRef *r_text);

/* Lets the user pick files (or a folder) with the browser's file
 * picker, and copies them into the engine's file system, under
 * /uploads. r_paths is their paths, one per line (for a folder, the
 * folder's path), or nil if the user cancelled. p_accept is the
 * picker's filter (the accept attribute of an <input type=file>).
 *
 * Returns false when the engine cannot wait (see above). */
bool MCEmscriptenPickFiles(MCStringRef p_title,
                           MCStringRef p_message,
                           bool p_multiple,
                           bool p_folder,
                           MCStringRef p_accept,
                           MCStringRef &r_paths);

/* Gives the user a file of the engine's file system as a download */
bool MCEmscriptenDownloadFile(MCStringRef p_path);

/* Opens a file of the engine's file system in a new tab of the browser */
bool MCEmscriptenShowDocument(MCStringRef p_path);

/* The folder of the files that the user picked, and the folder whose
 * files are given to the user as downloads when they are written */
#define kMCEmscriptenUploadsFolder "/uploads"
#define kMCEmscriptenDownloadsFolder "/downloads"

/* A file or folder of the engine's file system changed: the home folder,
 * which the browser keeps between visits, is written back to the
 * browser's storage soon after (em-system.js) */
extern "C" void MCEmscriptenStorageChanged(void);

/* ---------------------------------------------------------------- */

class MCScreenDC: public MCUIDC
{
public:
	/* ---------- Construction/destruction */
	MCScreenDC();
	virtual ~MCScreenDC();
	Boolean open();
	Boolean close(Boolean force);

	/* ---------- Window management */
	virtual void openwindow(Window p_window, Boolean override);
	virtual void closewindow(Window p_window);
	virtual void destroywindow(Window & x_window);
	virtual void raisewindow(Window p_window);
	virtual bool platform_getwindowgeometry(Window p_window,
	                                        MCRectangle & r_rect);

	uintptr_t dtouint(Drawable d);
	Boolean uinttowindow(uintptr_t, Window &w);
    void* GetNativeWindowHandle(Window p_window);

	/* ---------- Display management */

	virtual bool platform_getdisplays(bool p_effective, MCDisplay *&r_displays, uint32_t &r_count);

	/* ---------- Event loop */
	virtual Boolean wait(real64_t p_duration,
	                     Boolean p_allow_dispatch,
	                     Boolean p_allow_anyevent);

	/* ---------- Extra stuff */

    /* Pops up simple ask/answer dialogues */
    virtual int32_t popupanswerdialog(MCStringRef *p_buttons, uint32_t p_button_count, uint32_t p_type, MCStringRef p_title, MCStringRef p_message, bool p_blocking);
    virtual bool popupaskdialog(uint32_t p_type, MCStringRef p_title, MCStringRef p_message, MCStringRef p_initial, bool p_hint, MCStringRef& r_result);

    /* The page's dialogs stand in for the system's file and color
     * dialogs, and the browser's print dialog for its print dialogs */
    virtual bool hasfeature(MCPlatformFeature p_feature);

    /* OXT-Beyond: the browser prints (em-printer.cpp) */
    virtual MCPrinter *createprinter(void);

    /* OXT-Beyond: an unlocked field has the keyboard focus, or lost it: a
     * touch screen's keyboard comes up for it (em-event.js) */
    virtual void activateIME(Boolean activate);

    /* OXT-Beyond: a snapshot of the page's stacks, as a desktop takes one
     * of its screen; the user drags out the rectangle when it is not given
     * (em-dc.js) */
    virtual MCImageBitmap *snapshot(MCRectangle &r, uint4 window, MCStringRef displayname, MCPoint *size);

    /* OXT-Beyond: a stack's title, in its window's title bar (em-dc.js) */
    virtual void setname(Window window, MCStringRef newname);

    /* OXT-Beyond: the systemAppearance: the browser's colour scheme on a
     * page that asks for it, and else light, as before (em-dc.js) */
    virtual void getsystemappearance(MCSystemAppearance &r_appearance);

    /* OXT-Beyond: "start using font file" and "stop using font file"
     * (em-font.cpp) */
    virtual bool loadfont(MCStringRef p_path, bool p_globally, void*& r_loaded_font_handle);
    virtual bool unloadfont(MCStringRef p_path, bool p_globally, void *r_loaded_font_handle);

    /* Cursors: the canvases' CSS cursors */
    virtual void resetcursors();
    virtual void setcursor(Window w, MCCursorRef c);
    virtual MCCursorRef createcursor(MCImageBitmap *image, int2 xhot, int2 yhot);
    virtual void freecursor(MCCursorRef c);

    /* The beep: a tone of the beepPitch, beepDuration and beepLoudness */
    virtual void beep();
    virtual void getbeep(uint4 property, int4& r_value);
    virtual void setbeep(uint4 property, int4 beep);

    /* The modifier keys and the keys that are down, as the page's
     * latest events say (em-event.js) */
    virtual uint2 querymods();
    virtual bool getkeysdown(MCListRef& r_list);

    /* Mouse management */
	void update_mouse_press_state(MCMousePressState p_state, int32_t p_button);
	bool update_mouse_position(const MCPoint &p_position, MCStack *p_stack);

	virtual Boolean getmouse(uint2 button, Boolean& r_abort);
    /* OXT-Beyond: the mouseClick, from the event queue */
    virtual Boolean getmouseclick(uint2 button, Boolean& r_abort);
    virtual void platform_querymouse(int16_t& r_x, int16_t& r_y);

    /* OXT-Beyond: drag and drop between the stacks in the page. The drag
     * follows the mouse until its button goes up, and its events are the
     * drag's meanwhile, not the stacks': drag_mouse_position() and
     * drag_mouse_press() return true for those that the drag takes. */
    virtual MCDragAction dodragdrop(Window w, MCDragActionSet p_allowed_actions, MCImage *p_image, const MCPoint *p_image_offset);
    bool drag_mouse_position(void);
    bool drag_mouse_press(MCMousePressState p_state);

protected:
	void FitWindow();

private:
	Window m_main_window;
	uint32_t m_mouse_button_state;
	MCPoint m_mouse_position;
	/* The stack of the last position that the stacks got (only compared) */
	MCStack *m_mouse_stack;

	/* Where a drag is (dodragdrop()) */
	enum MCEmscriptenDragState
	{
		kMCEmscriptenDragStateNone,
		/* Following the mouse */
		kMCEmscriptenDragStateDragging,
		/* Its button went up: the drag drops */
		kMCEmscriptenDragStateDropped,
		/* It ends with no drop: the browser cancelled the touch that was
		 * the mouse, or the page lost the mouse */
		kMCEmscriptenDragStateAborted,
		/* Escape cancelled it: it ends with no drop, and has the mouse
		 * until its button goes up */
		kMCEmscriptenDragStateCancelled,
	};
	MCEmscriptenDragState m_drag_state;

	int4 m_beep_pitch;
	int4 m_beep_duration;
	int4 m_beep_loudness;
};

#endif /* ! __MC_EMSCRIPTEN_DC_H__ */
