/* Copyright (C) 2015 LiveCode Ltd.

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

#include "core.h"

#include "libbrowser_cef.h"

#include <X11/Xlib.h>

////////////////////////////////////////////////////////////////////////////////

class MCCefLinuxBrowser : public MCCefBrowserBase
{
public:
	MCCefLinuxBrowser(Display *p_display, Window p_parent_window);
	virtual ~MCCefLinuxBrowser(void);

	bool GetXDisplay(Display *&r_display);
	bool GetXWindow(Window &r_window);

	virtual void PlatformConfigureWindow(CefWindowInfo &r_info);
	virtual bool PlatformGetNativeLayer(void *&r_layer);

	virtual bool PlatformSetVisible(bool p_visible);
	virtual bool PlatformGetVisible(bool &r_visible);

	virtual bool PlatformGetRect(MCBrowserRect &r_rect);
	virtual bool PlatformSetRect(const MCBrowserRect &p_rect);
	virtual bool PlatformGetWindowID(int32_t &r_id);

	virtual bool PlatformGetAuthCredentials(bool p_is_proxy, const CefString &p_url, const CefString &p_realm, MCCefAuthScheme p_auth_scheme, CefString &r_user, CefString &r_password);

	virtual bool PlatformGetAllowUserInteraction(bool &r_allow_interaction);
	virtual bool PlatformSetAllowUserInteraction(bool p_allow_interaction);

private:
	Display *m_display;
	Window m_parent_window;
};

//////////

MCCefLinuxBrowser::MCCefLinuxBrowser(Display *p_display, Window p_parent_window)
{
	m_display = p_display;
	m_parent_window = p_parent_window;
}

MCCefLinuxBrowser::~MCCefLinuxBrowser()
{
}

//////////

bool MCCefLinuxBrowser::GetXDisplay(Display *&r_display)
{
	r_display = m_display;
	return true;
}

bool MCCefLinuxBrowser::GetXWindow(Window &r_window)
{
	CefRefPtr<CefBrowser> t_browser;
	t_browser = GetCefBrowser();

	if (t_browser == nil)
		return false;

	Window t_window;
	t_window = t_browser->GetHost()->GetWindowHandle();

	if (t_window == None)
		return false;

	r_window = t_window;

	return true;
}

//////////

bool MCCefLinuxBrowser::PlatformGetNativeLayer(void *&r_layer)
{
	return GetXWindow((Window&)r_layer);
}

// The window CEF creates its browser windows in, until the native layer
// embeds each one in its stack (MCNativeLayerX11). A browser window made
// directly on the root window is a top-level window, so the window manager
// takes it as soon as CEF maps it: depending on the window manager and on
// timing, the browser then stayed unmapped after the native layer took it
// (an empty browser, typically from the second browser on) or was shown and
// focused as a window of its own. This window is never mapped and is
// override-redirect, so the window manager never sees it or its children.
// It is a child of the root window with the root's visual, the visual CEF
// needs (with the stack's window as the parent the content views were not
// created and CEF crashed). One for the process, never destroyed.
static Window s_cef_holder_window = None;

static Window MCCefLinuxGetHolderWindow(Display *p_display)
{
	if (s_cef_holder_window == None && p_display != nil)
	{
		XSetWindowAttributes t_attributes;
		t_attributes.override_redirect = True;
		s_cef_holder_window = XCreateWindow(p_display, DefaultRootWindow(p_display),
		                                    -100, -100, 1, 1, 0,
		                                    CopyFromParent, InputOutput, CopyFromParent,
		                                    CWOverrideRedirect, &t_attributes);
		// CEF uses a connection of its own, so the window must exist on the
		// server before CEF creates the browser window in it
		XSync(p_display, False);
	}
	
	return s_cef_holder_window;
}

void MCCefLinuxBrowser::PlatformConfigureWindow(CefWindowInfo &r_info)
{
	// Only the parent: the size stays CEF's default, as when the root
	// window was the parent, and the native layer sets the real one
	r_info.parent_window = MCCefLinuxGetHolderWindow(m_display);
}

bool MCCefLinuxBrowser::PlatformGetRect(MCBrowserRect &r_rect)
{
	Display *t_display;
	if (!GetXDisplay(t_display))
		return false;

	Window t_window;
	if (!GetXWindow(t_window))
		return false;

	Window t_root;
	int32_t t_win_x, t_win_y;
	uint32_t t_width, t_height, t_border_width, t_depth;

	XGetGeometry(t_display, t_window, &t_root, &t_win_x, &t_win_y, &t_width, &t_height, &t_border_width, &t_depth);

	r_rect.left = t_win_x;
	r_rect.top = t_win_y;
	r_rect.right = t_win_x + t_width;
	r_rect.bottom = t_win_y + t_height;

	return true;
}

bool MCCefLinuxBrowser::PlatformSetRect(const MCBrowserRect &p_rect)
{
	Display *t_display;
	if (!GetXDisplay(t_display))
		return false;

	Window t_window;
	if (!GetXWindow(t_window))
		return false;

	XMoveResizeWindow(t_display, t_window, p_rect.left, p_rect.top, p_rect.right - p_rect.left, p_rect.bottom - p_rect.top);

	return true;
}

bool MCCefLinuxBrowser::PlatformGetVisible(bool &r_visible)
{
	Display *t_display;
	if (!GetXDisplay(t_display))
		return false;

	Window t_window;
	if (!GetXWindow(t_window))
		return false;

	XWindowAttributes t_attributes;
	
	XGetWindowAttributes(t_display, t_window, &t_attributes);
	
	r_visible = t_attributes.map_state != IsUnmapped;
	
	return true;
}

bool MCCefLinuxBrowser::PlatformSetVisible(bool p_visible)
{
	Display *t_display;
	if (!GetXDisplay(t_display))
		return false;

	Window t_window;
	if (!GetXWindow(t_window))
		return false;

	if (p_visible)
		XMapWindow(t_display, t_window);
	else
		XUnmapWindow(t_display, t_window);
		
	return true;
}

bool MCCefLinuxBrowser::PlatformGetWindowID(int32_t &r_id)
{
	r_id = (int32_t) m_parent_window;
	return true;
}

bool MCCefLinuxBrowser::PlatformGetAuthCredentials(bool p_is_proxy, const CefString &p_url, const CefString &p_realm, MCCefAuthScheme p_auth_scheme, CefString &r_user, CefString &r_password)
{
	/* TODO - implement */
	return false;
}


bool MCCefLinuxBrowser::PlatformGetAllowUserInteraction(bool &r_value)
{
	/* TODO - implement */
	r_value = true;
	return false;
}

bool MCCefLinuxBrowser::PlatformSetAllowUserInteraction(bool p_value)
{
	/* TODO - implement */
	return false;
}

////////////////////////////////////////////////////////////////////////////////

bool MCCefPlatformCreateBrowser(void *p_display, void *p_window_id, MCCefBrowserBase *&r_browser)
{
	MCCefLinuxBrowser *t_browser;
	t_browser = new (nothrow) MCCefLinuxBrowser((Display*)p_display, (Window)p_window_id);
	
	if (t_browser == nil)
		return false;
	
	r_browser = t_browser;
	
	return true;
}

////////////////////////////////////////////////////////////////////////////////

bool MCCefPlatformEnableHiDPI()
{
    return true;
}

bool MCCefPlatformGetHiDPIEnabled()
{
    return false;
}

////////////////////////////////////////////////////////////////////////////////
