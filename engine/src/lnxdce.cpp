/* Copyright (C) 2003-2015 LiveCode Ltd.

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

//
// ScreenDC event and signal handling functions
//
#include "lnxprefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "mcio.h"

#include "dispatch.h"
#include "stack.h"
#include "card.h"
#include "image.h"
#include "util.h"
#include "date.h"
#include "param.h"

#include "notify.h"
#include "eventqueue.h"
#include "region.h"
#include "osspec.h"
#include "mode.h"
#include "globals.h"
#include "notify.h"
#include "redraw.h"

#include "lnxdc.h"

#include "resolution.h"
#include "graphics_util.h"

#include <gdk/gdkkeysyms.h>

#define WM_TITLE_HEIGHT 16

// dsklnx.cpp: tells the players whose mplayer has ended
extern void MCS_handlechildexits(void);

// IM-2014-01-29: [[ HiDPI ]] Placeholder method for Linux HiDPI support
// OXT-Beyond: [[ HiDPI ]] Where the desktop scales, bound the rect in device
// coords and give it back in logical ones.
void MCScreenDC::platform_boundrect(MCRectangle &rect, Boolean title, Window_mode m, Boolean resizable)
{
	if (MCLinuxGetLogicalToScreenScale() == 1.0)
	{
		device_boundrect(rect, title, m);
		return;
	}

	MCRectangle t_rect;
	t_rect = logicaltoscreenrect(rect);
	device_boundrect(t_rect, title, m);

	// Only the position moves: keep the size as it was given.
	MCPoint t_origin;
	t_origin = screentologicalpoint(MCPointMake(t_rect.x, t_rect.y));
	rect.x = t_origin.x;
	rect.y = t_origin.y;
}

void MCScreenDC::device_boundrect(MCRectangle &rect, Boolean title, Window_mode m)
{
	MCRectangle srect;
	if (m >= WM_MODAL)
		MCU_set_rect(srect, 0, 0, device_getwidth(), device_getheight());
	else
	{
		// IM-2014-01-29: [[ HiDPI ]] Convert logical to screen coords
		srect = logicaltoscreenrect(MCwbr);
	}
	
	
	if (rect.x < srect.x)
		rect.x = srect.x;
	else
		if (rect.x + rect.width > srect.x + srect.width)
			rect.x = srect.x + srect.width - rect.width;
	int2 top = title ? WM_TITLE_HEIGHT : 0;
	srect.y += top;
	srect.height -= top;
	if (rect.y < srect.y)
		rect.y = srect.y;
	else
		if (rect.y + rect.height > srect.y + srect.height)
			rect.y = srect.y + srect.height - rect.height;
}

static bool MCExposeEventFilter(GdkEvent *e, void *)
{
    return e->type == GDK_EXPOSE || e->type == GDK_DAMAGE;
}

bool MCLinuxRegionToMCGRegion(GdkRegion*, MCGRegionRef&);

void MCScreenDC::expose()
{
	GdkEvent *event;

    while (true)
    {
        MCGRegionRef t_dirty;
        Window t_window;
        if (GetFilteredEvent(&MCExposeEventFilter, event, NULL))
        {
            GdkEventExpose *eevent = (GdkEventExpose*)event;
            t_window = eevent->window;
            
            MCLinuxRegionToMCGRegion(eevent->region, t_dirty);
            
            gdk_event_free(event);
        }
        else
            break;
        
        MCStack *t_stack;
		t_stack = MCdispatcher -> findstackd(t_window);
		if (t_stack != nil)
			t_stack -> onexpose((MCRegionRef)t_dirty);
        
		MCGRegionDestroy(t_dirty);
    }
}

Boolean MCScreenDC::abortkey()
{
	if (MCabortscript)
		return True;
	if (!MCalarm)
		return False;
	MCU_play();
	MCalarm = False;
	gdk_display_flush(dpy);
	Boolean abort, reset;
	handle(False, False, abort, reset);
	if (pendingevents != NULL)
	{
		MCEventnode *tptr = pendingevents;
		do
		{
			if (tptr->event->type == GDK_KEY_PRESS)
			{
				GdkEventKey *kpevent = (GdkEventKey*)tptr->event;
				/* OXT-Beyond: the abort key is Control-period or
				 * Control-Break, as on Windows (w32dce.cpp) and as the
				 * dictionary's allowInterrupts says. Control applied to
				 * Break only, so a period alone stopped the running
				 * handler: one typed while it ran, or into a GTK file
				 * dialog it had opened (gdk_event_fn queues the dialog's
				 * keys here too), once the dialog had returned. */
				if ((kpevent->state & GDK_CONTROL_MASK) &&
				    (kpevent->keyval == XK_Break ||
				     kpevent->keyval == 0x2e /*XK_period*/))
				{
					abort = True;
					tptr->remove
					(pendingevents);
					delete tptr;
					if (pendingevents == NULL)
						break;
					tptr = pendingevents;
					continue;
				}
			}
			tptr = (MCEventnode *)tptr->next();
		}
		while (tptr != pendingevents);
	}
	if (abort)
    {
		if (MCallowinterrupts && !MCdefaultstackptr->cantabort())
			return True;
		else
			MCinterrupt = True;
    }
	return False;
}

void MCScreenDC::waitconfigure(Window w)
{
}

void MCScreenDC::waitreparent(Window w)
{
	waitmessage(w, ReparentNotify);
}

static bool MCFocusOutFilter(GdkEvent *e, void *)
{
    if (e->type != GDK_FOCUS_CHANGE)
        return false;
    
    if (((GdkEventFocus*)e)->in)
        return false;
    
    return true;
}

void MCScreenDC::waitfocus()
{
	GdkEvent *e;
    gdk_display_sync(dpy);
    if (GetFilteredEvent(&MCFocusOutFilter, e, NULL))
    {
        MCdispatcher->wkunfocus(((GdkEventFocus*)e)->window);
        gdk_event_free(e);
    }
}

// OXT-Beyond: [[ HiDPI ]] The pointer's position in logical coords
void MCScreenDC::platform_querymouse(int16_t &x, int16_t &y)
{
	device_querymouse(x, y);

	MCPoint t_loc;
	t_loc = screentologicalpoint(MCPointMake(x, y));
	x = t_loc.x;
	y = t_loc.y;
}

void MCScreenDC::device_querymouse(int2 &x, int2 &y)
{
	gint rx, ry;
    gdk_display_get_pointer(dpy, NULL, &rx, &ry, NULL);
    x = rx;
    y = ry;
}

uint2 MCScreenDC::querymods()
{
	if (lockmods)
		return MCmodifierstate;
    
    GdkModifierType state;
    gdk_display_get_pointer(dpy, NULL, NULL, NULL, &state);

	// MW-2010-10-13: [[ Bug 9059 ]] Map the X masks to our masks correctly - previously
	//   this ditched the capsLock mask.
	unsigned int t_rstate;
	t_rstate = 0;
	if ((state & GDK_SHIFT_MASK) != 0)
		t_rstate |= MS_SHIFT;
	if ((state & GDK_LOCK_MASK) != 0)
		t_rstate |= MS_CAPS_LOCK;
	if ((state & GDK_CONTROL_MASK) != 0)
		t_rstate |= MS_CONTROL;
	if ((state & GDK_MOD1_MASK) != 0)
		t_rstate |= MS_MOD1;
	if ((state & GDK_MOD2_MASK) != 0)
		t_rstate |= MS_MOD2;

	return t_rstate;
}

// OXT-Beyond: [[ HiDPI ]] Move the pointer to a position in logical coords
void MCScreenDC::platform_setmouse(int16_t x, int16_t y)
{
	MCPoint t_loc;
	t_loc = logicaltoscreenpoint(MCPointMake(x, y));
	device_setmouse(t_loc.x, t_loc.y);
}

void MCScreenDC::device_setmouse(int2 x, int2 y)
{
	gdk_display_warp_pointer(dpy, gdk_display_get_default_screen(dpy), x, y);
}

Boolean MCScreenDC::getmouse(uint2 button, Boolean& r_abort)
{
	static real8 lasttime;
	real8 newtime = MCS_time();
	real8 sr = (real8)9.0 / 1000.0;
	if ((newtime - lasttime) < sr)
	{
		r_abort = MCscreen->wait(sr, False, False);
		if (r_abort)
			return False;
	}
	else
		r_abort = False;
	lasttime = newtime;
    
    GdkModifierType state;
    gdk_display_get_pointer(dpy, NULL, NULL, NULL, &state);

    switch (button)
    {
        case 0:
            return !!(state & GDK_BUTTON1_MASK);
            
        case 1:
            return !!(state & GDK_BUTTON2_MASK);
            
        case 2:
            return !!(state & GDK_BUTTON3_MASK);
            
        case 3:
            return !!(state & GDK_BUTTON4_MASK);
            
        case 4:
            return !!(state & GDK_BUTTON5_MASK);
            
        default:
            return false;
    }
}

Boolean MCScreenDC::getmouseclick(uint2 button, Boolean& r_abort)
{
	Boolean abort, reset;
	handle(False, False, abort, reset);
	if (abort)
	{
		r_abort = True;
		return False;
	}
	
	r_abort = False;
	
	MCEventnode *tptr = pendingevents;
	MCEventnode *pressptr = NULL;
	MCEventnode *releaseptr = NULL;
	if (pendingevents != NULL)
		do
		{
			if (tptr->event->type == GDK_BUTTON_PRESS)
			{
				GdkEventButton *bpevent = (GdkEventButton *)tptr->event;
				if (button == 0
				    || bpevent->state >> 8 & 0x1F & ~(0x1L << (button - 1)))
				{
					setmods(bpevent->state, 0, bpevent->button, False);
					
					MCPoint t_clickloc;
					t_clickloc = MCPointMake(bpevent->x, bpevent->y);
					
					// IM-2014-01-29: [[ HiDPI ]] Convert screen to logical coords
					t_clickloc = screentologicalpoint(t_clickloc);
					
					// IM-2013-10-09: [[ FullscreenMode ]] Update clickloc with MCscreen getters & setters
					MCscreen->setclickloc(MCmousestackptr, t_clickloc);
					
					pressptr = tptr;
					tptr = (MCEventnode *)tptr->next();
					break;
				}
			}
			tptr = (MCEventnode *)tptr->next();
		}
		while (tptr != pendingevents);
	Boolean value = False;
	if (tptr != pendingevents)
		do
		{
			if (tptr->event->type == GDK_BUTTON_RELEASE)
			{
				GdkEventButton *brevent = (GdkEventButton *)tptr->event;
				if (button == 0
				    || brevent->state >> 8 & 0x1F & ~(0x1L << (button - 1)))
				{
					setmods(brevent->state, 0, brevent->button, False);
					releaseptr = tptr;
					break;
				}
			}
			tptr = (MCEventnode *)tptr->next();
		}
		while (tptr != pendingevents);
	if (pressptr != NULL && releaseptr != NULL)
		value = True;
	else
		pressptr = releaseptr = NULL;
	if (pressptr != NULL)
	{
		tptr = (MCEventnode *)pressptr->remove
		       (pendingevents);
		delete tptr;
	}
	if (releaseptr != NULL)
	{
		tptr = (MCEventnode *)releaseptr->remove
		       (pendingevents);
		delete tptr;
	}
	return value;
}

Boolean MCScreenDC::wait(real8 duration, Boolean dispatch, Boolean anyevent)
{
    MCDeletedObjectsEnterWait(dispatch);
    
	MCwaitdepth++;
	real8 curtime = MCS_time();
	if (duration < 0.0)
		duration = 0.0;
	real8 exittime = curtime + duration;
	Boolean abort = False;
	Boolean reset = False;
	modalclosed = False;
	Boolean done = False;
	Boolean donepending = False;
	do
	{
		// IM-2014-03-06: [[ revBrowserCEF ]] Call additional runloop callbacks
		DoRunloopActions();

		real8 eventtime = exittime;
		donepending = handlepending(curtime, eventtime, dispatch);
		siguser();
		
		// MM-2012-09-04: Make sure MCModeQueueEvents is called.  This is used by the property listener feature.
		MCModeQueueEvents();
		
		// OXT-Beyond: what the SIGCHLD handler left to do (dsklnx.cpp)
		MCS_handlechildexits();
		if (MCplayers)
			IO_cleanprocesses();

		if (modalclosed ||
		    ((MCNotifyDispatch(dispatch == True) ||
		      (dispatch && MCEventQueueDispatch()) ||
		      handle(dispatch, anyevent, abort, reset) ||
		      donepending) &&
		     anyevent) ||
		    abort)
			break;

		if (MCquit)
			break;

		// MW-2012-09-19: [[ Bug 10218 ]] Make sure we update the screen in case
		//   any engine event handling methods need us to.
		MCRedrawUpdateScreen();

		if (curtime < eventtime)
        {
            // If there are run loop actions, ensure they are run occasionally
            real64_t t_sleep;
            t_sleep = eventtime - curtime;
            if (HasRunloopActions())
                t_sleep = MCMin(t_sleep, 0.01);
            
            gdk_display_sync(dpy);
            done = MCS_poll(donepending ? 0 : t_sleep, x11::XConnectionNumber(x11::gdk_x11_display_get_xdisplay(dpy)));
        }
		curtime = MCS_time();
	}
	while (curtime < exittime && !(anyevent && (done || donepending)));
	if (MCquit)
		abort = True;
	MCwaitdepth--;
	
	// MW-2012-09-19: [[ Bug 10218 ]] Make sure we update the screen in case
	//   any engine event handling methods need us to.
	MCRedrawUpdateScreen();

    MCDeletedObjectsLeaveWait(dispatch);
    
	return abort;
}

void MCScreenDC::flushevents(uint2 e)
{
	static int event_types[FE_LAST] = { 0, GDK_BUTTON_PRESS, GDK_BUTTON_RELEASE,
	                                    GDK_KEY_PRESS, GDK_KEY_RELEASE, 1, 1,
	                                    GDK_FOCUS_CHANGE, 1, 1 };
	Boolean abort, reset;
	handle(False, False, abort, reset);
	if (pendingevents != NULL)
	{
		MCEventnode *tptr = pendingevents;
		Boolean done;
		do
		{
			done = True;
			if (e == FE_ALL || event_types[e] == tptr->event->type)
			{
				tptr->remove
				(pendingevents);
				delete tptr;
				if (pendingevents == NULL)
					break;
				tptr = pendingevents;
				done = False;
			}
			else
				tptr = (MCEventnode *)tptr->next();
		}
		while (!done || tptr != pendingevents);
	}
}

Boolean MCScreenDC::istripleclick()
{
	return tripleclick;
}
