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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

#include "prefix.h"

#include "em-dc.h"
#include "em-view.h"
#include "em-surface.h"
#include "em-util.h"

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "sysdefs.h"
#include "stack.h"
#include "resolution.h"
#include "graphics_util.h"
#include "globals.h"

#include "region.h"

/* ================================================================
 * Stack initialisation
 * ================================================================ */

void
MCStack::realize()
{
	view_setbackingscale(MCResGetPixelScale());

	start_externals();

	/* OXT-Beyond: an engine without a user interface (a web worker's,
	 * em-dc-mainloop.cpp) makes no window for a stack, as the desktop's
	 * makes none (desktop-stack.cpp): a worker has no page to put one
	 * in, and the stack opens without one */
	if (MCnoui)
	{
		return;
	}

	uint32_t t_window = MCEmscriptenCreateWindow();
	window = reinterpret_cast<Window>(t_window);

	/* OXT-Beyond: the window's opacity, and whether it lets the mouse
	 * through, as the desktop's (desktop-stack.cpp) */
	setopacity(blendlevel * 255 / 100);
	/* and the opacity it has (MCStack::SetBlendLevel) */
	old_blendlevel = blendlevel;
	updateignoremouseevents();

	/* By default, don't draw anything */
	setextendedstate(true, ECS_DONTDRAW);
}

void
MCStack::start_externals()
{
	loadexternals();
}

void
MCStack::stop_externals()
{
	unloadexternals();
}

/* ================================================================
 * Window management
 * ================================================================ */

void
MCStack::platform_openwindow(Boolean override)
{
	MCAssert(window != nil);

	/* Make sure to reset the geometry on the window before mapping it. */
	setgeom();

	MCscreen->openwindow(window, override);
}

void
MCStack::setgeom()
{
	if (!opened)
		return;

	MCRectangle t_old_rect;
	t_old_rect = rect;

	rect = view_setstackviewport(rect);

	/* Resize the stack, if necessary */
	state &= ~CS_NEED_RESIZE;

	if (t_old_rect.x      != rect.x ||
	    t_old_rect.y      != rect.y ||
	    t_old_rect.width  != rect.width ||
	    t_old_rect.height != rect.height)
	{
		resize(t_old_rect.width, t_old_rect.height);
	}
}

void
MCStack::release_window_buffer()
{
}

/* ================================================================
 * View management
 * ================================================================ */

static MCStackUpdateCallback s_updatewindow_callback = nullptr;
static void *s_updatewindow_context = nullptr;

bool MCStack::view_platform_dirtyviewonresize() const
{
	return true;
}

void MCStack::view_platform_updatewindowwithcallback(MCRegionRef p_region, MCStackUpdateCallback p_callback, void *p_context)
{
	s_updatewindow_callback = p_callback;
	s_updatewindow_context = p_context;

	view_platform_updatewindow(p_region);

	s_updatewindow_callback = nil;
	s_updatewindow_context = nil;
}

void MCStack::view_platform_updatewindow(MCRegionRef p_dirty_region)
{
	MCRegionRef t_scaled_region;
	t_scaled_region = nil;
	
	MCRegionRef t_screen_region;
	t_screen_region = nil;
	
	MCGFloat t_scale;
	t_scale = MCResGetPixelScale();
	
	if (t_scale != 1.0)
	{
		/* UNCHECKED */ MCRegionTransform(p_dirty_region, MCGAffineTransformMakeScale(t_scale, t_scale), t_scaled_region);
		t_screen_region = t_scaled_region;
	}
	else
		t_screen_region = p_dirty_region;
	
	view_device_updatewindow(t_screen_region);
	
	if (t_scaled_region != nil)
		MCRegionDestroy(t_scaled_region);
}

void MCStack::view_device_updatewindow(MCRegionRef p_region)
{
	/* dirtyrect() calls that occur prior to configure() being called
	 * for the first time will result in an update region being too
	 * big. Restrict to a valid region. */

	uint32_t t_window = reinterpret_cast<uint32_t>(window);
	
	MCRectangle t_window_rect = MCEmscriptenGetWindowRect(t_window);
	MCRectangle t_canvas_rect = MCRectangleGetScaledCeilingRect(t_window_rect, MCResGetPixelScale());
	t_canvas_rect.x = t_canvas_rect.y = 0;

	MCGRegionRef t_region = MCGRegionRef(p_region);

	MCGRegionIntersectRect(t_region, MCRectangleToMCGIntegerRectangle(t_canvas_rect));

	MCGIntegerRectangle t_rect = MCGRegionGetBounds(t_region);
	MCEmscriptenSyncCanvasSize(t_window, t_canvas_rect.width, t_canvas_rect.height);

	// IM-2014-01-30: [[ HiDPI ]] Ensure stack backing scale is set
	view_setbackingscale(MCResGetPixelScale());

	MCHtmlCanvasStackSurface t_surface(t_window, MCGRegionGetBounds(t_region));
	if (t_surface.Lock())
	{
		// IM-2014-01-31: [[ HiDPI ]] If a callback is given then use it to render to the surface
		if (s_updatewindow_callback != nil)
			s_updatewindow_callback(&t_surface, (MCRegionRef)t_region, s_updatewindow_context);
		else
			view_surface_redrawwindow(&t_surface, t_region);

		t_surface.Unlock();
	}
}

MCRectangle
MCStack::view_platform_setgeom(const MCRectangle &p_rect)
{
	uint32_t t_window = reinterpret_cast<uint32_t>(window);

	MCRectangle t_old = MCEmscriptenGetWindowRect(t_window);
	MCEmscriptenSetWindowRect(t_window, p_rect);
	return t_old;
}

MCRectangle MCStack::view_platform_getwindowrect() const
{
	/* OXT-Beyond: the window's rect with its frame (its title bar and
	 * border, em-dc.js), as on the desktop. While the screen is locked, a
	 * stack that is moved or resized keeps its window where it was until
	 * the screen is unlocked, so the window's rect is where it will be: the
	 * stack's with the frame around it, as the Linux engine does
	 * (lnxstack.cpp). Before, the effective rect of the stack was where its
	 * window had been until the screen was unlocked. */
	uint32_t t_window = reinterpret_cast<uint32_t>(window);

	MCRectangle t_frame_rect = MCEmscriptenGetWindowFrameRect(t_window);
	if (MClockscreen != 0)
	{
		MCRectangle t_content_rect = MCEmscriptenGetWindowRect(t_window);
		MCRectangle t_rect = MCRectangleGetTransformedBounds(rect, view_getviewtransform());
		t_rect.x -= t_content_rect.x - t_frame_rect.x;
		t_rect.y -= t_content_rect.y - t_frame_rect.y;
		t_rect.width += t_frame_rect.width - t_content_rect.width;
		t_rect.height += t_frame_rect.height - t_content_rect.height;
		return t_rect;
	}

	return t_frame_rect;
}

/* ================================================================
 * Window frames
 * ================================================================ */

/* OXT-Beyond: the frame of the stack's window, as a desktop gives a
 * window its decorations (lnxstack.cpp): a title bar with a close box for
 * a toplevel, modeless or modal stack, a narrower one for a palette, and
 * edges that resize the window of a resizable stack; none for menus,
 * popups, tooltips and drawers, nor when the decorations leave out the
 * title or give the window a shape, nor for a fullscreen stack. The page
 * keeps palettes (unless the raisePalettes is false) and system windows
 * above the other stacks, dialogs above those, and menus above all
 * (em-dc.js). The main stack's window, which is the page's canvas, has no
 * frame. */
void
MCStack::sethints()
{
	if (!opened || MCnoui || window == nil)
		return;

	int32_t t_frame = kMCEmscriptenWindowFrameNone;
	int32_t t_layer = kMCEmscriptenWindowLayerNormal;
	bool t_close = true;
	switch (mode)
	{
	case WM_TOP_LEVEL:
	case WM_TOP_LEVEL_LOCKED:
	case WM_MODELESS:
		t_frame = kMCEmscriptenWindowFrameTitle;
		break;
	case WM_PALETTE:
		t_frame = kMCEmscriptenWindowFrameUtility;
		if (MCraisepalettes)
			t_layer = kMCEmscriptenWindowLayerPalette;
		break;
	case WM_MODAL:
	case WM_SHEET:
		t_frame = kMCEmscriptenWindowFrameTitle;
		t_layer = kMCEmscriptenWindowLayerModal;
		break;
	case WM_DRAWER:
		break;
	case WM_LICENSE:
		t_layer = kMCEmscriptenWindowLayerModal;
		break;
	default:
		t_layer = kMCEmscriptenWindowLayerPopup;
		break;
	}

	if (t_frame != kMCEmscriptenWindowFrameNone && (flags & F_DECORATIONS))
	{
		if ((decorations & WD_TITLE) == 0 || (decorations & WD_SHAPE) != 0)
			t_frame = kMCEmscriptenWindowFrameNone;
		t_close = (decorations & WD_CLOSE) != 0;
	}

	/* A fullscreen stack's window covers the screen, with no frame */
	if (view_getfullscreen())
		t_frame = kMCEmscriptenWindowFrameNone;

	/* A system window floats above the other stacks */
	if ((flags & F_DECORATIONS) && (decorations & WD_UTILITY) &&
	    t_layer < kMCEmscriptenWindowLayerPalette)
		t_layer = kMCEmscriptenWindowLayerPalette;

	MCEmscriptenSetWindowFrame(reinterpret_cast<uint32_t>(window), t_frame,
	                           t_frame != kMCEmscriptenWindowFrameNone && t_close,
	                           getflag(F_RESIZABLE), t_layer);
	setsizehints();
}

/* OXT-Beyond: the sizes that the user can resize the stack's window to
 * by the edges of its frame, as the Linux engine gives the window manager
 * (lnxstack.cpp) */
void
MCStack::setsizehints()
{
	if (!opened || MCnoui || window == nil)
		return;

	if (getflag(F_RESIZABLE))
		MCEmscriptenSetWindowSizeLimits(reinterpret_cast<uint32_t>(window),
		                                minwidth, minheight, maxwidth, maxheight);
	else
	{
		MCRectangle t_rect = view_getrect();
		MCEmscriptenSetWindowSizeLimits(reinterpret_cast<uint32_t>(window),
		                                t_rect.width, t_rect.height, t_rect.width, t_rect.height);
	}
}

/* ================================================================
 * Stub functions
 * ================================================================ */

void
MCStack::applyscroll()
{
}

void
MCStack::clearscroll()
{
}

/* OXT-Beyond: a stack whose ignoreMouseEvents is true lets the mouse
 * through its window to what is under it in the page, as on the desktop
 * (em-dc.js) */
void
MCStack::updateignoremouseevents()
{
	if (window != nil)
		MCEmscriptenSetWindowIgnoresMouse(reinterpret_cast<uint32_t>(window),
		                                  getextendedstate(ECS_IGNORE_MOUSE_EVENTS));
}

void
MCStack::destroywindowshape()
{
}

/* OXT-Beyond: the stack's blendLevel makes its window see-through, as on
 * the desktop (em-dc.js) */
void
MCStack::setopacity(unsigned char p_level)
{
	if (window != nil)
		MCEmscriptenSetWindowOpacity(reinterpret_cast<uint32_t>(window), p_level);
}

void
MCStack::updatemodifiedmark()
{
}

void
MCStack::redrawicon()
{
}

void
MCStack::updatedocumentfilename()
{
}

/* OXT-Beyond: a modal dialog disables the stacks under it
 * (MCStacklist::enableformodal()), and a disabled stack then gets none of
 * the page's mouse or key events (MCEmscriptenStackIsEnabled(), em-dc.cpp),
 * as a disabled window gets none on the desktop. Its canvas stays as it
 * is, and the user cannot move, resize or close its window (em-dc.js). */
void
MCStack::enablewindow(bool p_enable)
{
	if (window != nil)
		MCEmscriptenSetWindowEnabled(reinterpret_cast<uint32_t>(window), p_enable);
}
