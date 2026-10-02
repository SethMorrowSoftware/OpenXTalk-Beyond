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

#include "prefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"

#include "dispatch.h"
#include "osspec.h"
#include "image.h"
#include "stack.h"
#include "util.h"
#include "stacklst.h"

#include "globals.h"
#include "notify.h"

#include "w32dc.h"
#include "w32printer.h"
#include "resolution.h"
#include "mode.h"

#include "w32compat.h"

#include "mctheme.h"
#include "redraw.h"

#include "graphicscontext.h"
#include "graphics_util.h"

////////////////////////////////////////////////////////////////////////////////

static inline POINT MCPointToWin32POINT(const MCPoint &p_point)
{
	POINT t_point;
	t_point.x = p_point.x;
	t_point.y = p_point.y;

	return t_point;
}

////////////////////////////////////////////////////////////////////////////////

MCScreenDC::MCScreenDC()
{
	f_src_dc = NULL;
	f_dst_dc = NULL;

#ifdef FEATURE_TASKBAR_ICON
	f_has_icon = False;
	f_icon_menu = NULL;
#endif

	pendingevents = NULL;
	beeppitch = 440L;                    //440 Hz
	beepduration = 100;                 // 1/100 second
	grabbingclipboard = False;
	exposures = False;
	opened = 0;
	taskbarhidden = False;

	backdrop_active = false;
	backdrop_hard = false;
	backdrop_window = NULL;
	memset(&backdrop_colour, 0, sizeof(MCColor));
	backdrop_pattern = NULL;
	backdrop_badge = NULL;

	m_printer_dc = NULL;
	m_printer_dc_locked = false;
	m_printer_dc_changed = false;

	/* Initialize metrics with sensible defaults. */
	m_metrics_x_dpi = 96;
	m_metrics_y_dpi = 96;
	memset(&m_metrics_non_client, 0, sizeof(m_metrics_non_client));
}

MCScreenDC::~MCScreenDC()
{
	showtaskbar();
	while (opened)
		close(True);
	if (ncolors != 0)
	{
		uint2 i;
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
		MCEventnode *tptr =(MCEventnode *)pendingevents->remove(pendingevents);
		delete tptr;
	}
}

bool MCScreenDC::hasfeature(MCPlatformFeature p_feature)
{
	switch(p_feature)
	{
	case PLATFORM_FEATURE_WINDOW_TRANSPARENCY:
		return MCmajorosversion >= MCOSVersionMake(5,0,0);
	break;

	case PLATFORM_FEATURE_OS_COLOR_DIALOGS:
	case PLATFORM_FEATURE_OS_FILE_DIALOGS:
	case PLATFORM_FEATURE_OS_PRINT_DIALOGS:
		return true;
	break;
	
	case PLATFORM_FEATURE_TRANSIENT_SELECTION:
		return false;
	break;

	default:
		assert(false);
	break;
	}

	return false;
}
// TD-2013-07-01 [[ DynamicFonts ]]
bool MCScreenDC::loadfont(MCStringRef p_path, bool p_globally, void*& r_loaded_font_handle)
{
	bool t_success = true;
    DWORD t_private = NULL;
    
    if (!p_globally)
        t_private = FR_PRIVATE;
    
	if (t_success)
		t_success = (MCS_exists(p_path, true) == True);
	
    MCAutoStringRefAsWString t_wide_path;
    if (t_success)
        t_success = t_wide_path . Lock(p_path);
    
	if (t_success)
		t_success = (AddFontResourceExW(*t_wide_path, t_private, 0) != 0);
    
	if (t_success && p_globally)
		PostMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
    
	if (t_success && !p_globally)
		t_success = MCGFontAddPlatformFileResource(p_path);

	return t_success;
}


bool MCScreenDC::unloadfont(MCStringRef p_path, bool p_globally, void *r_loaded_font_handle)
{
    bool t_success = true;
    DWORD t_private = NULL;
    
    if (!p_globally)
        t_private = FR_PRIVATE;
    
    MCAutoStringRefAsWString t_wide_path;
    if (t_success)
        t_success = t_wide_path . Lock(p_path);
    
    if (t_success)
		t_success = (RemoveFontResourceExW(*t_wide_path, t_private, 0) != 0);
    
	if (t_success && p_globally)
		PostMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
    
	if (t_success && !p_globally)
		t_success = MCGFontRemovePlatformFileResource(p_path);

	return t_success;
}

///////////////////////////////////////////////////////////////////////////////

LPWSTR MCScreenDC::convertutf8towide(const char *p_utf8_string)
{
	int t_new_length;
	t_new_length = UTF8ToUnicode(p_utf8_string, strlen(p_utf8_string), NULL, 0);

	LPWSTR t_result;
	t_result = new (nothrow) WCHAR[t_new_length + 2];

	t_new_length = UTF8ToUnicode(p_utf8_string, strlen(p_utf8_string), (uint2*)t_result, t_new_length);
	t_result[t_new_length / 2] = 0;

	return t_result;
}

LPCSTR MCScreenDC::convertutf8toansi(const char *p_utf8_string)
{
	LPWSTR t_wide;
	t_wide = convertutf8towide(p_utf8_string);

	int t_length;
	t_length = WideCharToMultiByte(CP_ACP, 0, t_wide, -1, NULL, 0, NULL, NULL);

	LPSTR t_result;
	t_result = new (nothrow) CHAR[t_length];
	WideCharToMultiByte(CP_ACP, 0, t_wide, -1, t_result, t_length, NULL, NULL);

	delete t_wide;

	return t_result;
}

///////////////////////////////////////////////////////////////////////////////

MCPrinter *MCScreenDC::createprinter(void)
{
	return new MCWindowsPrinter;
}

bool MCScreenDC::listprinters(MCStringRef& r_printers)
{
	MCAutoListRef t_list;
	if (!MCListCreateMutable('\n', &t_list))
		return false;

	DWORD t_flags;
	DWORD t_level;
	t_flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
	t_level = 4;

	DWORD t_printer_count;
	DWORD t_bytes_needed;
	t_printer_count = 0;
	t_bytes_needed = 0;
	if (EnumPrintersW(t_flags, NULL, t_level, NULL, 0, &t_bytes_needed, &t_printer_count) != 0 || GetLastError() == ERROR_INSUFFICIENT_BUFFER)
	{
		MCAutoPointer<byte_t> t_printers;
		if (!MCMemoryNewArray(t_bytes_needed, &t_printers))
			return false;

		if (EnumPrintersW(t_flags, NULL, t_level, (LPBYTE)*t_printers, t_bytes_needed, &t_bytes_needed, &t_printer_count) != 0)
		{
			for(uint4 i = 0; i < t_printer_count; ++i)
			{
				MCAutoStringRef t_printer_name;
				if (!MCStringCreateWithWString(((PRINTER_INFO_4W *)*t_printers)[i] . pPrinterName, &t_printer_name))
					return false;
				if (!MCListAppend(*t_list, *t_printer_name))
					return false;
			}
		}
	}

	return MCListCopyAsString(*t_list, r_printers);
}

///////////////////////////////////////////////////////////////////////////////

MCStack *MCScreenDC::platform_getstackatpoint(int32_t x, int32_t y)
{
	MCPoint t_loc;
	t_loc = MCPointMake(x, y);

	// IM-2014-01-28: [[ HiDPI ]] Convert logical to screen coordinates
	t_loc = logicaltoscreenpoint(t_loc);

	POINT t_location;
	t_location = MCPointToWin32POINT(t_loc);
	
	HWND t_window;
	t_window = WindowFromPoint(t_location);

	if (t_window == nil)
		return nil;
		
	return MCdispatcher->findstackwindowid((uint32_t)t_window);
}

///////////////////////////////////////////////////////////////////////////////

void MCScreenDC::updatemetrics(void)
{
	/* Get the DC representing the whole 'screen' so we can get default dpi
	 * metrics from it. */
	HDC t_dc;
	t_dc = GetDC(NULL);
	if (t_dc != NULL)
	{
		m_metrics_x_dpi = GetDeviceCaps(t_dc, LOGPIXELSX);
		m_metrics_y_dpi = GetDeviceCaps(t_dc, LOGPIXELSY);
		ReleaseDC(NULL, t_dc);
	}
	else
	{
		m_metrics_x_dpi = 96;
		m_metrics_y_dpi = 96;
	}

	/* Fetch the 'non-client-metrics' which contains the names of fonts to use
	 * which match the current system settings. */
	m_metrics_non_client.cbSize = sizeof(m_metrics_non_client);
	if (!SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(m_metrics_non_client), &m_metrics_non_client, 0))
	{
		memset(&m_metrics_non_client, 0, sizeof(m_metrics_non_client));
	}
}

///////////////////////////////////////////////////////////////////////////////

void *MCScreenDC::GetNativeWindowHandle(Window p_win)
{
	return p_win != nil ? p_win->handle.window : nil;
}

///////////////////////////////////////////////////////////////////////////////

// OXT-Beyond: see w32dc.h. MCScreenDC::open makes its DCs the same way.
HDC MCWin32GetScreenSourceDC(void)
{
	if (!MCnoui)
		return static_cast<MCScreenDC *>(MCscreen)->getsrchdc();

	static HDC s_noui_src_dc = CreateCompatibleDC(NULL);
	return s_noui_src_dc;
}

HDC MCWin32GetScreenDestinationDC(void)
{
	if (!MCnoui)
		return static_cast<MCScreenDC *>(MCscreen)->getdsthdc();

	static HDC s_noui_dst_dc = CreateCompatibleDC(NULL);
	return s_noui_dst_dc;
}

///////////////////////////////////////////////////////////////////////////////

#define NORMAL_DENSITY (96.0)

// IM-2014-01-28: [[ HiDPI ]] Return the DPI scale factor of the main screen.
//   This gives us the pixelscale for system-DPI-aware applications.
MCGFloat MCWin32GetLogicalToScreenScale(void)
{
	// TODO - determine the correct value on Win8.1 - this may depend on the display in question

	// IM-2014-08-08: [[ Bug 12372 ]] If pixel scaling is disabled, then
	// we don't need to scale from logical -> screen.
	if (!MCResGetUsePixelScaling())
		return 1.0;

	uint32_t t_x, t_y;
	t_x = ((MCScreenDC *)MCscreen)->getscreenxdpi();
	t_y = ((MCScreenDC *)MCscreen)->getscreenydpi();

	return (MCGFloat) MCMax(t_x, t_y) / NORMAL_DENSITY;
}

////////////////////////////////////////////////////////////////////////////////

// IM-2014-01-28: [[ HiDPI ]] Return the DPI scale factor of the given monitor.
//   For system-DPI-aware applications this will be the global system DPI value.
//   For Per-Monitor-DPI-aware applications, this will be the effective DPI scale of the given monitor
bool MCWin32GetMonitorPixelScale(HMONITOR p_monitor, MCGFloat &r_pixel_scale)
{
	UINT t_xdpi, t_ydpi;
	HRESULT t_result;
	
	// try to get per-monitor DPI setting
	if (!MCWin32GetDpiForMonitor(t_result, p_monitor, kMCWin32MDTDefault, &t_xdpi, &t_ydpi) ||
		t_result != S_OK)
	{
		t_xdpi = ((MCScreenDC *)MCscreen)->getscreenxdpi();
		t_ydpi = ((MCScreenDC *)MCscreen)->getscreenydpi();
	}

	r_pixel_scale = (MCGFloat)MCMax(t_xdpi, t_ydpi) / NORMAL_DENSITY;

	return true;
}

///////////////////////////////////////////////////////////////////////////////

// IM-2014-08-08: [[ Bug 12372 ]] Set up dpi-awareness if pixel scaling is enabled
void MCResPlatformInitPixelScaling()
{
	if (MCModeCanEnablePixelScaling() && MCModeGetPixelScalingEnabled())
	{
		BOOL t_result;
		/* UNCHECKED */ MCWin32SetProcessDPIAware(t_result);
	}
}

// IM-2014-01-27: [[ HiDPI ]] Return whether the application is DPI-aware
bool MCResPlatformSupportsPixelScaling(void)
{
	BOOL t_aware;
	if (!MCWin32IsProcessDPIAware(t_aware) || !t_aware)
		return false;

	// IM-2014-08-08: [[ Bug 12372 ]] Support for pixel scaling depends on
	// whether or not it is enabled for the current environment.
	return MCModeGetPixelScalingEnabled();
}

// IM-2014-01-27: [[ HiDPI ]] On Windows, DPI-awareness can only be set at app startup or in the app manifest
bool MCResPlatformCanChangePixelScaling(void)
{
	return false;
}

// IM-2014-01-30: [[ HiDPI ]] Pixel scale cannot be set on Windows
bool MCResPlatformCanSetPixelScale(void)
{
	return false;
}

// IM-2014-01-30: [[ HiDPI ]] Pixel scale is 1.0 on Windows
MCGFloat MCResPlatformGetDefaultPixelScale(void)
{
	return 1.0;
}

// IM-2014-03-14: [[ HiDPI ]] UI scale is 1.0 on Windows
MCGFloat MCResPlatformGetUIDeviceScale(void)
{
	return 1.0;
}

// IM-2014-01-30: [[ HiDPI ]] No-op as this cannot be modified at runtime on Windows
void MCResPlatformHandleScaleChange(void)
{
}

///////////////////////////////////////////////////////////////////////////////

extern MCGFloat MCWin32GetLogicalToScreenScale(void);

MCPoint MCScreenDC::logicaltoscreenpoint(const MCPoint &p_point)
{
	MCGFloat t_scale;
	t_scale = MCWin32GetLogicalToScreenScale();
	return MCPointTransform(p_point, MCGAffineTransformMakeScale(t_scale, t_scale));
}

MCPoint MCScreenDC::screentologicalpoint(const MCPoint &p_point)
{
	MCGFloat t_scale;
	t_scale = 1 / MCWin32GetLogicalToScreenScale();
	return MCPointTransform(p_point, MCGAffineTransformMakeScale(t_scale, t_scale));
}

MCRectangle MCScreenDC::logicaltoscreenrect(const MCRectangle &p_rect)
{
	// IM-2014-04-21: [[ Bug 12236 ]] Switch to scaled floor function which
	// gives consistent width & height for different x, y values
	return MCRectangleGetScaledFloorRect(p_rect, MCWin32GetLogicalToScreenScale());
}

MCRectangle MCScreenDC::screentologicalrect(const MCRectangle &p_rect)
{
	// IM-2014-04-21: [[ Bug 12236 ]] Switch to scaled ceiling function which
	// gives consistent width & height for different x, y values
	return MCRectangleGetScaledCeilingRect(p_rect, 1 / MCWin32GetLogicalToScreenScale());
}

///////////////////////////////////////////////////////////////////////////////

// The light/dark app setting is cached. getsystemappearance is called from
// the drawing code for every themed colour, menu item, checkmark and
// scrollbar, and opening the registry key for each of those calls cost CPU in
// every redraw. MCWin32UpdateSystemColors refreshes the cache, at startup and
// when Windows broadcasts the ImmersiveColorSet setting change (the light/dark
// switch), which is also when the colours that depend on it are updated.
static bool s_system_appearance_is_dark = false;
static bool s_system_appearance_cached = false;

//-- tperry 11th October 2025
// Windows implementation of getsystemappearance - detect dark mode from registry
static bool MCWin32ReadSystemAppearanceIsDark(void)
{
	// Check Windows registry for dark mode setting. Only AppsUseLightTheme is
	// read: it is the "app mode" setting that applications follow;
	// SystemUsesLightTheme is the one for the taskbar and the Start menu.
	bool t_is_dark = false;
	HKEY hKey;
	
	if (RegOpenKeyExW(HKEY_CURRENT_USER, 
		L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
		0, KEY_READ, &hKey) == ERROR_SUCCESS)
	{
		DWORD value = 1; // Default to light mode
		DWORD size = sizeof(DWORD);
		
		// Check AppsUseLightTheme (0 = dark, 1 = light)
		if (RegQueryValueExW(hKey, L"AppsUseLightTheme", NULL, NULL, (LPBYTE)&value, &size) == ERROR_SUCCESS)
		{
			t_is_dark = (value == 0);
		}
		
		RegCloseKey(hKey);
	}
	
	return t_is_dark;
}

void MCWin32RefreshSystemAppearance(void)
{
	s_system_appearance_is_dark = MCWin32ReadSystemAppearanceIsDark();
	s_system_appearance_cached = true;
}

bool MCWin32IsSystemAppearanceDark(void)
{
	if (!s_system_appearance_cached)
		MCWin32RefreshSystemAppearance();
	return s_system_appearance_is_dark;
}

void MCScreenDC::getsystemappearance(MCSystemAppearance &r_appearance)
{
	r_appearance = MCWin32IsSystemAppearanceDark() ? kMCSystemAppearanceDark : kMCSystemAppearanceLight;
}

// A High Contrast theme replaces the system colours with the user's own, and
// the light drawing path uses the system colours (GetSysColor and uxtheme),
// the dark one fixed greys. So with High Contrast on, everything is drawn the
// light way (MCAppearanceIsDark). Asked for every colour, so cached, and read
// again on WM_SETTINGCHANGE SPI_SETHIGHCONTRAST (w32dcw32.cpp).
static bool s_high_contrast = false;
static bool s_high_contrast_cached = false;

bool MCWin32RefreshHighContrast(void)
{
	HIGHCONTRASTW t_high_contrast;
	memset(&t_high_contrast, 0, sizeof(t_high_contrast));
	t_high_contrast.cbSize = sizeof(t_high_contrast);
	bool t_on = SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(t_high_contrast), &t_high_contrast, 0) != FALSE &&
		(t_high_contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;

	bool t_changed = s_high_contrast_cached && t_on != s_high_contrast;
	s_high_contrast = t_on;
	s_high_contrast_cached = true;
	return t_changed;
}

bool MCWin32IsHighContrast(void)
{
	if (!s_high_contrast_cached)
		MCWin32RefreshHighContrast();
	return s_high_contrast;
}

extern void MCWin32UpdateSystemColors(void);
extern bool MCWin32ThemeSystemAppearanceDark;

// Tom Perry's colours of each appearance (MCWin32UpdateSystemColors, 38d5712b2):
// the dark background 32,32,32 with the disabled grey 137 (4.7:1), and the
// light 240,240,240 with 128
void MCScreenDC::getdefaultcolors(bool p_dark, MCColor& r_background, MCColor& r_gray)
{
	r_background.red = r_background.green = r_background.blue = p_dark ? 0x2020 : 0xF0F0;
	r_gray.red = r_gray.green = r_gray.blue = p_dark ? 0x8989 : 0x8080;
}

// Applies the light or dark appearance again, to every window at once: when
// the OS setting changed (the WM_SETTINGCHANGE "ImmersiveColorSet" handler in
// w32dcw32.cpp, through MCPlatformHandleSystemAppearanceChanged), and when a
// script set the appAppearance or a stackAppearance, which sends no message
// (MCAppearanceChanged).
void MCScreenDC::updatesystemappearance(void)
{
	MCAppearanceRefreshSystem();
	MCWin32UpdateSystemColors();

	// Windows re-themes itself on the light/dark switch; reopen the native
	// theme's handles then, as for WM_THEMECHANGED. Setting the properties
	// needs no reload: the dark and the light scrollbar handles are both
	// kept open (MCNativeTheme::GetScrollbarTheme).
	bool t_system_dark = MCWin32IsSystemAppearanceDark();
	if (t_system_dark != MCWin32ThemeSystemAppearanceDark)
	{
		MCWin32ThemeSystemAppearanceDark = t_system_dark;
		if (MCcurtheme != NULL && MCcurtheme->getthemeid() == LF_NATIVEWIN)
		{
			MCcurtheme->unload();
			MCcurtheme->load();
		}
	}

	// The title bars, of the windows whose appearance changed
	MCStacknode *t_node = MCstacks->topnode();
	if (t_node != NULL)
	{
		MCStacknode *t_start = t_node;
		do
		{
			MCStack *t_stack = t_node->getstack();
			if (t_stack != NULL)
				t_stack->updatewindowappearance();
			t_node = t_node->next();
		}
		while (t_node != t_start);
	}

	// Everything else is redrawn, in the colours it now has
	MCRedrawDirtyScreen();
}

///////////////////////////////////////////////////////////////////////////////
