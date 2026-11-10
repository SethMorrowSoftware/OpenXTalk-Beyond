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

//
// ScreenDC virtual functions
//

#include "lnxprefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"



#include "dispatch.h"
#include "image.h"
#include "stack.h"
#include "util.h"
#include "variable.h"

#include "globals.h"

#include "printer.h"

#include "lnxdc.h"

#include "lnxpsprinter.h"

#include "mctheme.h"

#include "notify.h"

//#include <X11/extensions/Xinerama.h>

#include "graphics_util.h"
#include "resolution.h"
#include "stacklst.h"
#include <fontconfig/fontconfig.h>
#include <pango/pangofc-fontmap.h>
#include "font.h"

#include <math.h>
#include <stdlib.h>

////////////////////////////////////////////////////////////////////////////////

static Boolean pserror;
Bool debugtest = False;

////////////////////////////////////////////////////////////////////////////////

MCGFloat MCResGetSystemScale(void)
{
	// IM-2013-08-12: [[ ResIndependence ]] Linux implementation currently returns 1.0
	return 1.0;
}

////////////////////////////////////////////////////////////////////////////////

MCScreenDC::MCScreenDC()
{
	m_application_has_focus = true ; // The application start's up having focus, one assumes.
}

MCScreenDC::~MCScreenDC()
{
	if (opened)
		close(True);
	if (ncolors != 0)
	{
		int2 i;
		for (i = 0 ; i < ncolors ; i++)
		{
            if (colornames[i] != NULL)
                MCValueRelease(colornames[i]);
		}
		delete colors;
		delete colornames;
		delete allocs;
	}
	
	while (pendingevents != NULL)
	{
		MCEventnode *tptr =(MCEventnode *)pendingevents->remove
		                   (pendingevents);
		
		if ( tptr != NULL ) 
			delete tptr;
	}
}


//TS : X11 Context creation
/*

  These functions are needed to create the context's that graphics are drawn with.
 
*/

bool MCScreenDC::hasfeature(MCPlatformFeature p_feature)
{
	switch(p_feature)
	{
	case PLATFORM_FEATURE_WINDOW_TRANSPARENCY:
		return is_composite_wm(0);
	break;
		
	case PLATFORM_FEATURE_OS_COLOR_DIALOGS:
		return m_has_native_color_dialogs;
	break;

		
	case PLATFORM_FEATURE_OS_FILE_DIALOGS:
		return m_has_native_file_dialogs;
	break;

	case PLATFORM_FEATURE_OS_PRINT_DIALOGS:
		return m_has_native_print_dialogs;
	break;
		
	case PLATFORM_FEATURE_NATIVE_THEMES:
		return m_has_native_theme;
	break;

	case PLATFORM_FEATURE_TRANSIENT_SELECTION:
		return true;
	break;

	default:
		assert(false);
	break;
	}

	return false;
}

///////////////////////////////////////////////////////////////////////////////

bool MCX11GetWindowWorkarea(GdkDisplay *p_display, Window p_window, MCRectangle &r_workarea)
{
    x11::Atom t_ret;
	int t_format, t_status;
	unsigned long t_count, t_after;
	unsigned long *t_workarea = nil;

    x11::Atom XA_CARDINAL = x11::gdk_x11_atom_to_xatom_for_display(p_display, gdk_atom_intern_static_string("CARDINAL"));
    
    t_status = x11::XGetWindowProperty(x11::gdk_x11_display_get_xdisplay(p_display),
                                       x11::gdk_x11_drawable_get_xid(p_window),
                                       x11::gdk_x11_atom_to_xatom_for_display(p_display, MCworkareaatom),
                                       0, 4, False, XA_CARDINAL, &t_ret, &t_format, &t_count, &t_after,
                                       (unsigned char**)&t_workarea);
	
	bool t_success;
	t_success = t_status == Success && t_ret == XA_CARDINAL && t_format == 32 && t_count == 4;
	
	if (t_success)
		r_workarea = MCRectangleMake(t_workarea[0], t_workarea[1], t_workarea[2], t_workarea[3]);
		
	if (t_workarea != nil)
		x11::XFree(t_workarea);
	
	return t_success;
}

// IM-2014-01-29: [[ HiDPI ]] Apply screen workarea to given MCDisplay array
bool MCScreenDC::apply_workarea(MCDisplay *p_displays, uint32_t p_display_count)
{
	bool t_success;
	t_success = true;
	
	MCRectangle t_workarea;
	t_success = MCX11GetWindowWorkarea(dpy, getroot(), t_workarea);
	
	if (t_success)
	{
		for (uint32_t i = 0; i < p_display_count; i++)
			p_displays[i].workarea = MCU_intersect_rect(t_workarea, p_displays[i].viewport);
	}
	
	return t_success;
}

// IM-2014-01-29: [[ HiDPI ]] Apply screen struts to given MCDisplay array
bool MCScreenDC::apply_partial_struts(MCDisplay *p_displays, uint32_t p_display_count)
{
	if (MCstrutpartialatom == None || MCclientlistatom == None)
		return false;
	
	bool t_success = true;
	
    x11::Atom t_ret;
	int t_format, t_status;
    x11::Window *t_clients = nil;
	unsigned long t_client_count, t_after;
	
    x11::Atom XA_WINDOW = x11::gdk_x11_atom_to_xatom_for_display(dpy, gdk_atom_intern_static_string("WINDOW"));
    x11::Atom XA_CARDINAL = x11::gdk_x11_atom_to_xatom_for_display(dpy, gdk_atom_intern_static_string("CARDINAL"));
    
    t_status = x11::XGetWindowProperty(x11::gdk_x11_display_get_xdisplay(dpy),
                                       x11::gdk_x11_drawable_get_xid(getroot()),
                                       x11::gdk_x11_atom_to_xatom_for_display(dpy, MCclientlistatom),
                                       0, -1, False,XA_WINDOW, &t_ret, &t_format, &t_client_count, &t_after,
                                       (unsigned char **)&t_clients);
    
	t_success = t_status == Success && t_ret == XA_WINDOW && t_format == 32;
	
	if (t_success)
	{
		int32_t t_screenwidth, t_screenheight;
		t_screenwidth = device_getwidth();
		t_screenheight = device_getheight();
		for (uindex_t i = 0; t_success && i < t_client_count; i++)
		{
			unsigned long t_strut_count;
			unsigned long *t_struts = nil;
			
            t_status = x11::XGetWindowProperty(x11::gdk_x11_display_get_xdisplay(dpy),
                                               t_clients[i],
                                               x11::gdk_x11_atom_to_xatom_for_display(dpy, MCstrutpartialatom),
                                               0, 12, False, XA_CARDINAL, &t_ret, &t_format, &t_strut_count, &t_after,
                                               (unsigned char **)&t_struts);

			if (t_status == Success && t_ret == XA_CARDINAL && t_format == 32 && t_strut_count == 12)
			{
				MCRectangle t_strut_rect = {0,0,0,0};
				MCRectangle t_strut_test = {0,0,0,0};
				
				if (t_struts[0] > 0)
				{
					// LEFT
					t_strut_rect.x = t_struts[0];
					t_strut_rect.y = 0;
					t_strut_rect.width = t_screenwidth - t_strut_rect.x;
					t_strut_rect.height = t_screenheight;
				
					t_strut_test = t_strut_rect;
					t_strut_test.y = t_struts[4];
					t_strut_test.height = t_struts[5] - t_strut_test.y;
				}
				else if (t_struts[1] > 0)
				{
					// RIGHT
					t_strut_rect.x = 0;
					t_strut_rect.y = 0;
					t_strut_rect.width = t_screenwidth - t_struts[1];
					t_strut_rect.height = t_screenheight;
				
					t_strut_test = t_strut_rect;
					t_strut_test.y = t_struts[6];
					t_strut_test.height = t_struts[7] - t_strut_test.y;
				}
				else if (t_struts[2] > 0)
				{
					// TOP
					t_strut_rect.x = 0;
					t_strut_rect.y = t_struts[2];
					t_strut_rect.width = t_screenwidth;
					t_strut_rect.height = t_screenheight - t_strut_rect.y;
				
					t_strut_test = t_strut_rect;
					t_strut_test.x = t_struts[8];
					t_strut_test.width = t_struts[9] - t_strut_test.x;
				}
				else if (t_struts[3] > 0)
				{
					// BOTTOM
					t_strut_rect.x = 0;
					t_strut_rect.y = 0;
					t_strut_rect.width = t_screenwidth;
					t_strut_rect.height = t_screenheight - t_struts[3];
				
					t_strut_test = t_strut_rect;
					t_strut_test.x = t_struts[10];
					t_strut_test.width = t_struts[11] - t_strut_test.x;
				}
				
				for (uindex_t s = 0; s < p_display_count; s++)
				{
					MCRectangle t_workarea = p_displays[s].workarea;

					MCRectangle t_test = MCU_intersect_rect(t_strut_test, t_workarea);
					if (t_test.width != 0 && t_test.height != 0)
						t_workarea = MCU_intersect_rect(t_strut_rect, t_workarea);
						
					p_displays[s].workarea = t_workarea;
				}
			}
			if (t_struts != nil)
				x11::XFree(t_struts);
		}
	}
	
	if (t_clients != nil)
		x11::XFree(t_clients);
		
	return t_success;
}

// IM-2014-01-29: [[ HiDPI ]] Placeholder method for Linux HiDPI support
// OXT-Beyond: [[ HiDPI ]] The displays in logical coords, each with the
// desktop's scale, on a desktop that scales; unchanged where it does not.
bool MCScreenDC::platform_getdisplays(bool p_effective, MCDisplay *&r_displays, uint32_t &r_display_count)
{
	if (!device_getdisplays(p_effective, r_displays, r_display_count))
		return false;

	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale != 1.0)
	{
		for (uint32_t i = 0; i < r_display_count; i++)
		{
			r_displays[i].pixel_scale = t_scale;
			r_displays[i].viewport = screentologicalrect(r_displays[i].viewport);
			r_displays[i].workarea = screentologicalrect(r_displays[i].workarea);
		}
	}

	return true;
}

// IM-2014-01-29: [[ HiDPI ]] Refactored to handle display info caching in MCUIDC superclass
bool MCScreenDC::device_getdisplays(bool p_effective, MCDisplay * &r_displays, uint32_t &r_display_count)
{
	// NOTE: this code assumes that there is only one GdkScreen!
    GdkScreen *t_screen;
    t_screen = gdk_display_get_default_screen(dpy);
    
    // Get the number of monitors attached to this screen
    gint t_monitor_count;
    t_monitor_count = gdk_screen_get_n_monitors(t_screen);
    
    // Allocate the list of monitors
    MCDisplay *t_displays;
    if (!MCMemoryNewArray(t_monitor_count, t_displays))
		{
			  return false;
		}
    
    // Get the geometry of each monitor
    for (gint i = 0; i < t_monitor_count; i++)
    {
        GdkRectangle t_rect;
        gdk_screen_get_monitor_geometry(t_screen, i, &t_rect);
        
        MCRectangle t_mc_rect;
        t_mc_rect = MCRectangleMake(t_rect.x, t_rect.y, t_rect.width, t_rect.height);
        
        t_displays[i].index = i;
        t_displays[i].pixel_scale = 1.0;
        t_displays[i].viewport = t_displays[i].workarea = t_mc_rect;
    }
    
    if (t_monitor_count == 1)
    {
        apply_workarea(t_displays, t_monitor_count) || apply_partial_struts(t_displays, t_monitor_count);
    }
    else
    {
        apply_partial_struts(t_displays, t_monitor_count);
    }
    
    // All done
    r_displays = t_displays;
    r_display_count = t_monitor_count;
    return true;
}



#define LIST_PRINTER_SCRIPT "put \"\" into tPrinters;" \
 "repeat for each line tLine in shell(\"lpstat -a\");" \
 "put word 1 of tLine & return after tPrinters ;" \
 "end repeat;" \
 "delete the last char of tPrinters;" \
 "get tPrinters; return it" \



bool MCScreenDC::listprinters(MCStringRef& r_printers)
{
	MCdefaultstackptr->domess(MCSTR(LIST_PRINTER_SCRIPT));
    MCresult->copyasvalueref((MCValueRef&)r_printers);
	return true;
}



MCPrinter *MCScreenDC::createprinter(void)
{
	return ( new MCPSPrinter );
	
}

////////////////////////////////////////////////////////////////////////////////

// OXT-Beyond: [[ HiDPI ]] The conversions as on Windows (w32dc.cpp), at the
// desktop's scale. At a scale of 1 each returns its input untouched, so a
// desktop that does not scale sees exactly the coordinates it saw before.
MCPoint MCScreenDC::logicaltoscreenpoint(const MCPoint &p_point)
{
	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale == 1.0)
		return p_point;
	return MCPointTransform(p_point, MCGAffineTransformMakeScale(t_scale, t_scale));
}

MCPoint MCScreenDC::screentologicalpoint(const MCPoint &p_point)
{
	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale == 1.0)
		return p_point;
	return MCPointTransform(p_point, MCGAffineTransformMakeScale(1 / t_scale, 1 / t_scale));
}

MCRectangle MCScreenDC::logicaltoscreenrect(const MCRectangle &p_rect)
{
	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale == 1.0)
		return p_rect;
	// The scaled floor and ceiling functions, as on Windows (IM-2014-04-21:
	// [[ Bug 12236 ]]), give the same width and height wherever the rect is.
	return MCRectangleGetScaledFloorRect(p_rect, t_scale);
}

MCRectangle MCScreenDC::screentologicalrect(const MCRectangle &p_rect)
{
	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale == 1.0)
		return p_rect;
	return MCRectangleGetScaledCeilingRect(p_rect, 1 / t_scale);
}

bool MCScreenDC::platform_get_display_handle(void *&r_display)
{
	r_display = x11::gdk_x11_display_get_xdisplay(getDisplay());
	
	return true;
}

void *MCScreenDC::GetNativeWindowHandle(Window p_window)
{
	// x11 window handle - dtouint returns the X11 Window id.
	return (void*)dtouint(p_window);
}

////////////////////////////////////////////////////////////////////////////////

void MCResPlatformInitPixelScaling(void)
{
}

////////////////////////////////////////////////////////////////////////////////

// OXT-Beyond: [[ HiDPI ]] Linux had no pixel scaling (IM-2014-01-29), so on a
// HiDPI screen every stack, the IDE included, came out at half the size of the
// rest of the desktop: a GTK 2 program is not scaled by GTK, and a compositor
// that leaves X11 programs to scale themselves (GNOME on Wayland with the
// xwayland-native-scaling feature, KDE, a plain X11 HiDPI desktop) leaves the
// window's pixels as they are. Now the engine scales its windows itself, the
// way it does on Windows: the pixelScale stays 1, the stacks keep their
// logical coordinates, and each window is drawn into a backing buffer at the
// desktop's scale.
//
// The scale is the one a GTK 3 program (HyperXTalk, say) uses: GDK_SCALE when
// it is set, else the desktop's Gdk/WindowScalingFactor XSETTING. With no
// XSETTINGS manager (a bare X11 window manager), an Xft.dpi resource of 168
// or more (twice 96, less a margin) gives its whole multiple of 96. Only whole
// scales are used, as GTK 3 does; a desktop at 1 (and every desktop with
// GDK_SCALE=1) keeps the old behaviour exactly, usePixelScaling false and not
// settable included, as before.

static int s_linux_desktop_scale = 1;

// The logical-to-screen scale the open windows and MCwbr were last set up at
static MCGFloat s_linux_applied_scale = 1.0;

// The desktop scales above this are not believed (GTK 3 has no limit; a scale
// of 9 on a real screen would leave a window a handful of controls across).
#define MAX_DESKTOP_SCALE 8

static bool MCLinuxScaleFromString(const char *p_string, int &r_scale)
{
	if (p_string == nil || *p_string == '\0')
		return false;

	char *t_end;
	long t_value;
	t_value = strtol(p_string, &t_end, 10);
	if (*t_end != '\0' || t_value < 1 || t_value > MAX_DESKTOP_SCALE)
		return false;

	r_scale = (int)t_value;
	return true;
}

static uint32_t MCLinuxXSettingsCard32(const uint8_t *p_data, bool p_msb_first)
{
	if (p_msb_first)
		return (uint32_t(p_data[0]) << 24) | (uint32_t(p_data[1]) << 16) | (uint32_t(p_data[2]) << 8) | uint32_t(p_data[3]);
	return (uint32_t(p_data[3]) << 24) | (uint32_t(p_data[2]) << 16) | (uint32_t(p_data[1]) << 8) | uint32_t(p_data[0]);
}

static uint16_t MCLinuxXSettingsCard16(const uint8_t *p_data, bool p_msb_first)
{
	if (p_msb_first)
		return uint16_t((p_data[0] << 8) | p_data[1]);
	return uint16_t((p_data[1] << 8) | p_data[0]);
}

static inline size_t MCLinuxXSettingsPad(size_t p_length)
{
	return (p_length + 3) & ~size_t(3);
}

// Find the integer setting p_name in an _XSETTINGS_SETTINGS property (the
// XSETTINGS specification, version 0.5). Returns false when it is not there or
// the property is malformed.
static bool MCLinuxXSettingsFindInteger(const uint8_t *p_data, size_t p_length, const char *p_name, int32_t &r_value)
{
	if (p_length < 12)
		return false;

	bool t_msb_first;
	t_msb_first = p_data[0] != 0;

	uint32_t t_count;
	t_count = MCLinuxXSettingsCard32(p_data + 8, t_msb_first);

	size_t t_name_length;
	t_name_length = strlen(p_name);

	size_t t_offset = 12;
	for (uint32_t i = 0; i < t_count; i++)
	{
		if (p_length - t_offset < 4)
			return false;

		uint8_t t_type;
		t_type = p_data[t_offset];

		size_t t_length;
		t_length = MCLinuxXSettingsCard16(p_data + t_offset + 2, t_msb_first);
		t_offset += 4;
		if (p_length - t_offset < MCLinuxXSettingsPad(t_length) + 4)
			return false;

		bool t_match;
		t_match = t_length == t_name_length && memcmp(p_data + t_offset, p_name, t_length) == 0;
		t_offset += MCLinuxXSettingsPad(t_length) + 4; // the name, then its last-change serial

		switch (t_type)
		{
			case 0: // XSettingsTypeInteger
				if (p_length - t_offset < 4)
					return false;
				if (t_match)
				{
					r_value = (int32_t)MCLinuxXSettingsCard32(p_data + t_offset, t_msb_first);
					return true;
				}
				t_offset += 4;
				break;

			case 1: // XSettingsTypeString
				if (p_length - t_offset < 4)
					return false;
				t_length = MCLinuxXSettingsCard32(p_data + t_offset, t_msb_first);
				t_offset += 4;
				if (p_length - t_offset < MCLinuxXSettingsPad(t_length))
					return false;
				t_offset += MCLinuxXSettingsPad(t_length);
				break;

			case 2: // XSettingsTypeColor
				if (p_length - t_offset < 8)
					return false;
				t_offset += 8;
				break;

			default:
				return false;
		}
	}

	return false;
}

// Read the desktop's XSETTINGS. r_has_manager says whether an XSETTINGS
// manager runs at all; r_scale is set only when it publishes
// Gdk/WindowScalingFactor.
static void MCLinuxReadXSettingsScale(GdkDisplay *p_display, bool &r_has_manager, int &r_scale, bool &r_has_scale)
{
	r_has_manager = false;
	r_has_scale = false;

	x11::Display *t_xdisplay;
	t_xdisplay = x11::gdk_x11_display_get_xdisplay(p_display);

	char t_selection_name[32];
	snprintf(t_selection_name, sizeof(t_selection_name), "_XSETTINGS_S%d", gdk_screen_get_number(gdk_display_get_default_screen(p_display)));

	x11::Atom t_selection;
	t_selection = x11::gdk_x11_atom_to_xatom_for_display(p_display, gdk_atom_intern(t_selection_name, FALSE));

	x11::Window t_manager;
	t_manager = x11::XGetSelectionOwner(t_xdisplay, t_selection);
	if (t_manager == None)
		return;

	r_has_manager = true;

	x11::Atom t_settings;
	t_settings = x11::gdk_x11_atom_to_xatom_for_display(p_display, gdk_atom_intern_static_string("_XSETTINGS_SETTINGS"));

	x11::Atom t_type;
	int t_format;
	unsigned long t_count, t_after;
	uint8_t *t_data = nil;

	// The manager can exit between the two calls: trap the BadWindow.
	gdk_error_trap_push();
	int t_status;
	t_status = x11::XGetWindowProperty(t_xdisplay, t_manager, t_settings, 0, 0x4000, False,
									   t_settings, &t_type, &t_format, &t_count, &t_after,
									   (unsigned char **)&t_data);
	gdk_flush();
	bool t_error;
	t_error = gdk_error_trap_pop() != 0;

	if (!t_error && t_status == Success && t_data != nil && t_type == t_settings && t_format == 8)
	{
		int32_t t_value;
		if (MCLinuxXSettingsFindInteger(t_data, t_count, "Gdk/WindowScalingFactor", t_value) &&
			t_value >= 1 && t_value <= MAX_DESKTOP_SCALE)
		{
			r_scale = t_value;
			r_has_scale = true;
		}
	}

	if (t_data != nil)
		x11::XFree(t_data);
}

// The scale an Xft.dpi resource in the root window's RESOURCE_MANAGER
// property gives, if it is 2 or more.
static bool MCLinuxReadXftDpiScale(GdkDisplay *p_display, int &r_scale)
{
	x11::Display *t_xdisplay;
	t_xdisplay = x11::gdk_x11_display_get_xdisplay(p_display);

	GdkWindow *t_root;
	t_root = gdk_screen_get_root_window(gdk_display_get_default_screen(p_display));

	x11::Atom t_type;
	int t_format;
	unsigned long t_count, t_after;
	char *t_data = nil;

	int t_status;
	t_status = x11::XGetWindowProperty(t_xdisplay, x11::gdk_x11_drawable_get_xid(t_root),
									   x11::gdk_x11_atom_to_xatom_for_display(p_display, gdk_atom_intern_static_string("RESOURCE_MANAGER")),
									   0, 0x10000, False,
									   x11::gdk_x11_atom_to_xatom_for_display(p_display, gdk_atom_intern_static_string("STRING")),
									   &t_type, &t_format, &t_count, &t_after, (unsigned char **)&t_data);

	bool t_found = false;
	double t_dpi = 0;
	if (t_status == Success && t_data != nil && t_format == 8)
	{
		// Each line is "name:\tvalue"; the last Xft.dpi line wins, as in Xrm.
		const char *t_line = t_data;
		const char *t_end = t_data + t_count;
		while (t_line < t_end)
		{
			const char *t_line_end;
			t_line_end = (const char *)memchr(t_line, '\n', t_end - t_line);
			if (t_line_end == nil)
				t_line_end = t_end;

			static const char kXftDpi[] = "Xft.dpi:";
			if (size_t(t_line_end - t_line) > sizeof(kXftDpi) - 1 &&
				memcmp(t_line, kXftDpi, sizeof(kXftDpi) - 1) == 0)
			{
				char t_value[32];
				size_t t_value_length;
				t_value_length = MCMin(size_t(t_line_end - t_line) - (sizeof(kXftDpi) - 1), sizeof(t_value) - 1);
				memcpy(t_value, t_line + sizeof(kXftDpi) - 1, t_value_length);
				t_value[t_value_length] = '\0';

				char *t_number_end;
				double t_number;
				t_number = strtod(t_value, &t_number_end);
				if (t_number_end != t_value && t_number > 0)
				{
					t_dpi = t_number;
					t_found = true;
				}
			}

			t_line = t_line_end + 1;
		}
	}

	if (t_data != nil)
		x11::XFree(t_data);

	if (!t_found)
		return false;

	int t_scale;
	t_scale = (int)floor(t_dpi / 96.0 + 0.25);
	if (t_scale < 2)
		return false;

	r_scale = MCMin(t_scale, MAX_DESKTOP_SCALE);
	return true;
}

void MCLinuxReadDesktopScale(GdkDisplay *p_display)
{
	int t_scale = 1;

	// GDK_SCALE, as GTK 3 reads it: a whole number, and it overrides the desktop
	// (GDK_SCALE=1 turns the scaling off).
	if (!MCLinuxScaleFromString(getenv("GDK_SCALE"), t_scale))
	{
		bool t_has_manager, t_has_scale;
		int t_xsettings_scale = 1;
		MCLinuxReadXSettingsScale(p_display, t_has_manager, t_xsettings_scale, t_has_scale);
		if (t_has_scale)
			t_scale = t_xsettings_scale;
		else if (!t_has_manager)
		{
			int t_dpi_scale;
			if (MCLinuxReadXftDpiScale(p_display, t_dpi_scale))
				t_scale = t_dpi_scale;
		}
	}

	s_linux_desktop_scale = t_scale;

	// The engine set up pixel scaling before the display was open, when it
	// could not know the desktop's scale: turn it on now, before anything
	// (the windowBoundingRect first) is measured in logical coords.
	if (s_linux_desktop_scale != 1)
		MCResSetUsePixelScaling(true);
}

MCGFloat MCLinuxGetLogicalToScreenScale(void)
{
	// IM-2014-08-08: [[ Bug 12372 ]] (as on Windows) If pixel scaling is
	// disabled, logical and screen coordinates are the same.
	if (s_linux_desktop_scale == 1 || !MCResGetUsePixelScaling())
		return 1.0;

	return (MCGFloat)s_linux_desktop_scale;
}

// OXT-Beyond: [[ HiDPI ]] The scale the browser widget's CEF draws its pages
// at (libbrowser_cef_lnx.cpp): the same as the stacks', so a page fills its
// widget at the size it has on Windows and macOS. Read once, when CEF starts.
extern "C" double MCLinuxGetBrowserDeviceScale(void)
{
	return MCLinuxGetLogicalToScreenScale();
}

// OXT-Beyond: [[ HiDPI ]] Pixel scaling is supported where the desktop scales:
// on a desktop at 1 it is unsupported, as it always was on Linux.
bool MCResPlatformSupportsPixelScaling(void)
{
	return !MCnoui && s_linux_desktop_scale != 1;
}

// OXT-Beyond: [[ HiDPI ]] Where the desktop scales, usePixelScaling can be set
// to false (and back), as on macOS, to draw at the screen's pixels.
bool MCResPlatformCanChangePixelScaling(void)
{
	return !MCnoui && s_linux_desktop_scale != 1;
}

// IM-2014-01-30: [[ HiDPI ]] Pixel scale cannot be set on Linux (as on Windows
// and macOS, the pixelScale stays 1 on the desktop)
bool MCResPlatformCanSetPixelScale(void)
{
	return false;
}

// IM-2014-01-30: [[ HiDPI ]] Pixel scale is 1.0 on Linux
MCGFloat MCResPlatformGetDefaultPixelScale(void)
{
	return 1.0;
}

// IM-2014-03-14: [[ HiDPI ]] UI scale is 1.0 on Linux
MCGFloat MCResPlatformGetUIDeviceScale(void)
{
	return 1.0;
}

// OXT-Beyond: [[ HiDPI ]] usePixelScaling changed: keep the windowBoundingRect
// on the same part of the screen, and reopen the open stacks' windows, which
// realize() makes at the new backing scale.
void MCResPlatformHandleScaleChange(void)
{
	if (MCnoui)
		return;

	MCGFloat t_scale;
	t_scale = MCLinuxGetLogicalToScreenScale();
	if (t_scale == s_linux_applied_scale)
		return;

	MCwbr = MCRectangleGetScaledFloorRect(MCwbr, s_linux_applied_scale / t_scale);
	s_linux_applied_scale = t_scale;

	if (MCstacks != nil)
		MCstacks->reopenallstackwindows();

	// The cursors made from images are scaled by the scale they were made at
	// (MCScreenDC::createcursor, lnxcursor.cpp): make them again, once they
	// have been made. At start-up the display turns pixel scaling on while it
	// opens (MCLinuxReadDesktopScale), before the stacks the cursors come from
	// exist; the cursors are made later, at the right scale.
	if (MCcursors[PI_ARROW] != nil)
		MCscreen->resetcursors();
}

////////////////////////////////////////////////////////////////////////////////

// OXT-Beyond: the fonts a script loads ("start using font file") reach
// fontconfig as application fonts of a new configuration, made current. Two
// things kept them from the text a stack lists and draws:
//
//  - loading a font made a fresh configuration with only that one file in
//    it, so each font loaded dropped the ones loaded before it (the IDE loads
//    its code font, its icon fonts and then the user's; only the last stayed);
//  - Pango's font maps (the one the engine lists and measures fonts with,
//    pango_cairo_font_map_get_default, and the one libgraphics draws with)
//    take the configuration that is current when they are first used and
//    keep it (Pango 1.48 and later), so a configuration made current later
//    was never seen: the font was neither in "the fontNames" nor drawn.
//
// Each load or unload now makes the configuration from every font still
// loaded, plus the one being loaded or minus the one being unloaded, and
// hands it to the engine's font map here; libgraphics follows the current
// configuration itself before it draws (lnxtext.cpp).

// pango_fc_font_map_set_config is Pango 1.38's (2015): it is weak linked as
// optional (linux.stubs), so an older Pango keeps the behaviour it had.
typedef void (*pango_fc_font_map_set_configPTR)(PangoFcFontMap *fcfontmap, FcConfig *fcconfig);
extern "C" pango_fc_font_map_set_configPTR pango_fc_font_map_set_config_ptr;

static bool MCLinuxFontConfigLoad(MCStringRef p_adding, MCStringRef p_removing)
{
    if (!FcInit())
        return false;
    
    // fontconfig has no function to remove one application font, so every
    // change starts again from the system fonts.
    FcConfig *t_config;
    t_config = FcInitLoadConfigAndFonts();
    if (t_config == nil)
        return false;
    
    MCStringRef *t_loaded = nil;
    uindex_t t_count = 0;
    if (!MCFontListLoaded(t_count, t_loaded))
        return false;
    MCAutoStringRefArray t_files;
    t_files . Give(t_loaded, t_count);
    
    for (uindex_t i = 0; i < t_files . Count(); i++)
    {
        if (p_removing != nil &&
            MCStringIsEqualTo(t_files[i], p_removing, kMCStringOptionCompareCaseless))
            continue;
        
        // A file that loaded once is taken as it loaded then: one that has
        // gone since cannot stop the others loading.
        MCAutoStringRefAsSysString t_file;
        if (t_file . Lock(t_files[i]))
            FcConfigAppFontAddFile(t_config, (FcChar8*)*t_file);
    }
    
    // The file being loaded must load, or the load fails and the fonts stay
    // as they were.
    if (p_adding != nil)
    {
        MCAutoStringRefAsSysString t_file;
        if (!t_file . Lock(p_adding))
            return false;
        if (FcFalse == FcConfigAppFontAddFile(t_config, (FcChar8*)*t_file))
            return false;
    }
    
    if (FcFalse == FcConfigSetCurrent(t_config))
        return false;
    
    if (FcFalse == FcConfigBuildFonts(t_config))
        return false;
    
    // The engine's font map: "the fontNames", and the fonts it measures with.
    // On Linux Pango's cairo font map is always a fontconfig one;
    // pango_fc_font_map_set_config checks it is and clears what it cached.
    if (pango_fc_font_map_set_config_ptr != nil)
    {
        PangoFontMap *t_font_map;
        t_font_map = pango_cairo_font_map_get_default();
        if (t_font_map != nil)
            pango_fc_font_map_set_config_ptr((PangoFcFontMap *)t_font_map, t_config);
    }
    
    return true;
}

// AL-2015-01-20 [[ DynamicFonts ]] Implement font loading on Linux
bool MCScreenDC::loadfont(MCStringRef p_path, bool p_globally, void*& r_loaded_font_handle)
{
    // We can't load fonts globally with fontconfig
    if (p_globally)
        return false;
    
    // MCFontLoad adds the file to the loaded fonts after this succeeds, so it
    // is not among them yet.
    if (!MCLinuxFontConfigLoad(p_path, nil))
        return false;
    
    // We don't actually do anything with the loaded font handle at the moment.
    // It is slightly awkward to create one, so we just set it to nil for now.
    r_loaded_font_handle = nil;
    return true;
}

bool MCScreenDC::unloadfont(MCStringRef p_path, bool p_globally, void *r_loaded_font_handle)
{
    // We can't unload fonts globally with fontconfig
    if (p_globally)
        return false;
    
    // MCFontUnload removes the file from the loaded fonts after this
    // succeeds, so it is still among them: leave it out.
    return MCLinuxFontConfigLoad(nil, p_path);
}
