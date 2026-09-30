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
#include "objdefs.h"
#include "parsedef.h"
#include "filedefs.h"

#include "mcstring.h"
#include "mctheme.h"
#include "util.h"
#include "globals.h"
#include "osspec.h"

#include "context.h"
#include "button.h"

#include "w32dc.h"
#include "w32theme.h"

#include "exec.h"
#include "graphics_util.h"

// The header contains nothing without this define for the Win7 SDK
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x600

#include <uxtheme.h>

////////////////////////////////////////////////////////////////////////////////

// Generic state constants
#define TS_NORMAL    1
 #define TS_HOVER     2
 #define TS_ACTIVE    3
 #define TS_DISABLED  4
 #define TS_FOCUSED   5
#define TS_CONTROL_HOVER 5 // 'Hover' state for scrollbars

// Button constants
#define BP_BUTTON    1
 #define BP_RADIO     2
 #define BP_CHECKBOX  3
#define BP_GROUPBOX 4

// Textfield constants
#define TFP_TEXTFIELD 1
 #define TFS_READONLY  6

// Treeview/listbox constants
#define TREEVIEW_BODY 1

// Scrollbar constants
#define SP_BUTTON          1
 #define SP_THUMBHOR        2
 #define SP_THUMBVERT       3
 #define SP_TRACKSTARTHOR   4
 #define SP_TRACKENDHOR     5
 #define SP_TRACKSTARTVERT  6
 #define SP_TRACKENDVERT    7
 #define SP_GRIPPERHOR      8
 #define SP_GRIPPERVERT     9

#define SLIDERP_TRACKHOR 1
#define SLIDERP_TRACKVERT 2
#define SLIDERP_THUMBHOR 4
#define SLIDERP_THUMBVERT 8

#define SLIDERP_THUMBDISABLED 5



// Progress bar constants
#define PP_BAR             1
 #define PP_BARVERT         2
 #define PP_CHUNK           3
 #define PP_CHUNKVERT       4


// Tab constants
#define TABP_TAB             4
#define TABP_TAB_SELECTED    5
#define TABP_PANELS          9
#define TABP_PANEL           9


// Tooltip constants
#define TTP_STANDARD         1

// Dropdown constants
#define CBP_DROPMARKER       1
#define CBP_READONLY		 5
#define CBP_DROPDOWNBUTTONRIGHT 6


enum {
	MENU_MENUITEM_TMSCHEMA = 1,
	MENU_MENUDROPDOWN_TMSCHEMA = 2,
	MENU_MENUBARITEM_TMSCHEMA = 3,
	MENU_MENUBARDROPDOWN_TMSCHEMA = 4,
	MENU_CHEVRON_TMSCHEMA = 5,
	MENU_SEPARATOR_TMSCHEMA = 6,
	MENU_BARBACKGROUND = 7,
	MENU_BARITEM = 8,
	MENU_POPUPBACKGROUND = 9,
	MENU_POPUPBORDERS = 10,
	MENU_POPUPCHECK = 11,
	MENU_POPUPCHECKBACKGROUND = 12,
	MENU_POPUPGUTTER = 13,
	MENU_POPUPITEM = 14,
	MENU_POPUPSEPARATOR = 15,
	MENU_POPUPSUBMENU = 16,
	MENU_SYSTEMCLOSE = 17,
	MENU_SYSTEMMAXIMIZE = 18,
	MENU_SYSTEMMINIMIZE = 19,
	MENU_SYSTEMRESTORE = 20,
};

enum {
	MB_ACTIVE = 1,
	MB_INACTIVE = 2,
};

enum {
	MBI_NORMAL = 1,
	MBI_HOT = 2,
	MBI_PUSHED = 3,
	MBI_DISABLED = 4,
	MBI_DISABLEDHOT = 5,
	MBI_DISABLEDPUSHED = 6,
};

enum {
	MC_CHECKMARKNORMAL = 1,
	MC_CHECKMARKDISABLED = 2,
	MC_BULLETNORMAL = 3,
	MC_BULLETDISABLED = 4,
};

enum {
	MCB_DISABLED = 1,
	MCB_NORMAL = 2,
	MCB_BITMAP = 3,
};

enum {
	MPI_NORMAL = 1,
	MPI_HOT = 2,
	MPI_DISABLED = 3,
	MPI_DISABLEDHOT = 4,
};

enum {
	MSM_NORMAL = 1,
	MSM_DISABLED = 2,
};

typedef HANDLE HPAINTBUFFER;

typedef HANDLE (WINAPI*OpenThemeDataPtr)(HWND hwnd, LPCWSTR pszClassList);
typedef HRESULT (WINAPI*CloseThemeDataPtr)(HANDLE hTheme);
typedef HRESULT (WINAPI*DrawThemeBackgroundPtr)(HANDLE hTheme, HDC hdc, int iPartId,
        int iStateId, const RECT *pRect,
        const RECT* pClipRect);
typedef HRESULT (WINAPI*GetThemeContentRectPtr)(HANDLE hTheme, HDC hdc, int iPartId,
        int iStateId, const RECT* pRect,
        RECT* pContentRect);
typedef HRESULT (WINAPI*GetThemePartSizePtr)(HANDLE hTheme, HDC hdc, int iPartId,
        int iStateId, RECT* prc, int ts,
        SIZE* psz);
typedef HRESULT (WINAPI*GetThemeFontPtr)(HANDLE hTheme, HDC hdc, int iPartId,
        int iStateId, int iPropId, OUT LOGFONT* pFont);
typedef HRESULT (WINAPI*GetThemeSysFontPtr)(HANDLE hTheme, int iFontId, OUT LOGFONT* pFont);
typedef HRESULT (WINAPI*GetThemeColorPtr)(HANDLE hTheme, HDC hdc, int iPartId,
        int iStateId, int iPropId, OUT COLORREF* pFont);
typedef HRESULT (WINAPI*GetThemeTextMetricsPtr)(HANDLE hTheme, OPTIONAL HDC hdc, int iPartId,
        int iStateId, OUT TEXTMETRICA* ptm);
typedef HRESULT (WINAPI *GetThemeBackgroundRegionPtr)(HANDLE hTheme, OPTIONAL HDC hdc, int iPartId,
				int iStateId, const RECT *pRect, HRGN *pRegion);
typedef HRESULT (WINAPI *DrawThemeBackgroundExPtr)(HANDLE hTheme, HDC hdc, 
    int iPartId, int iStateId, const RECT *pRect, OPTIONAL const DTBGOPTS *pOptions);
typedef HPAINTBUFFER (WINAPI *BeginBufferedPaintPtr)(HDC hdcTarget, const RECT *prcTarget, BP_BUFFERFORMAT dwFormat,
												BP_PAINTPARAMS *pPaintParams, HDC *phdc);
typedef HRESULT (WINAPI *EndBufferedPaintPtr)(HPAINTBUFFER hBufferedPaint, BOOL fUpdateTarget);
typedef HRESULT (WINAPI *BufferedPaintClearPtr)(HPAINTBUFFER hBufferedPaint, const RECT *prc);
typedef HRESULT (WINAPI *GetBufferedPaintBitsPtr)(HPAINTBUFFER hBufferedPaint, RGBQUAD **ppbBuffer, int *pcxRow);

static OpenThemeDataPtr openTheme = NULL;
static CloseThemeDataPtr closeTheme = NULL;
static DrawThemeBackgroundPtr drawThemeBG = NULL;
static DrawThemeBackgroundExPtr drawThemeBGEx = NULL;
static GetThemeContentRectPtr getThemeContentRect = NULL;
static GetThemePartSizePtr getThemePartSize = NULL;
static GetThemeFontPtr getThemeFont = NULL;
static GetThemeSysFontPtr getThemeSysFont = NULL;
static GetThemeColorPtr getThemeColor = NULL;
static GetThemeTextMetricsPtr getThemeTextMetrics = NULL;
static GetThemeBackgroundRegionPtr getThemeBackgroundRegion = NULL;
static BeginBufferedPaintPtr beginBufferedPaint = NULL;
static EndBufferedPaintPtr endBufferedPaint = NULL;
static BufferedPaintClearPtr bufferedPaintClear = NULL;
static GetBufferedPaintBitsPtr getBufferedPaintBits = NULL;

#define NMENUCOLORS 4
static MCStringRef menucolors[NMENUCOLORS];


static char menucolorsregs[][255] = {
                                        "HKEY_CURRENT_USER\\Control Panel\\Colors\\MenuText",
                                        "HKEY_CURRENT_USER\\Control Panel\\Colors\\MenuHilight",
                                        "HKEY_CURRENT_USER\\Control Panel\\Colors\\Menu",
                                        "HKEY_CURRENT_USER\\Control Panel\\Colors\\ButtonShadow"
                                    };

#define FIXED_THUMB_SIZE 17

static bool MCWin32ThemePartDrawsDark(MCWinSysHandle p_theme, int4 p_part, int4 p_state);

// Whether a widget is drawn in the dark appearance: that of the object it is
// drawn for (MCObject::isdarkappearance), so a light-designed stack keeps its
// light native controls whatever the appAppearance is. Widgets drawn for no
// object follow the appAppearance. Never dark on a printer.
static bool widgetisdark(const MCWidgetInfo& p_winfo, MCDC *p_dc)
{
	MCContextType t_type;
	t_type = p_dc != nil ? p_dc -> gettype() : CONTEXT_TYPE_SCREEN;
	if (t_type == CONTEXT_TYPE_PRINTER)
		return false;
	if (p_winfo . whichobject != nil)
		return p_winfo . whichobject -> isdarkappearance(t_type);
	return MCAppearanceIsDark(nil);
}

// The same for a background the engine draws for an object (a menu's card,
// the menubar group)
static bool objectisdark(MCObject *p_object, MCDC *p_dc)
{
	MCContextType t_type;
	t_type = p_dc != nil ? p_dc -> gettype() : CONTEXT_TYPE_SCREEN;
	if (t_type == CONTEXT_TYPE_PRINTER)
		return false;
	if (p_object != nil)
		return p_object -> isdarkappearance(t_type);
	return MCAppearanceIsDark(nil);
}

Boolean MCNativeTheme::load()
{
	if (mThemeDLL != NULL)
		return True;
	mThemeDLL = NULL;
	mButtonTheme = NULL;
	mTextFieldTheme = NULL;
	mTooltipTheme = NULL;
	mToolbarTheme = NULL;
	mRebarTheme = NULL;
	mProgressTheme = NULL;
	mScrollbarTheme = NULL;
	mScrollbarDarkTheme = NULL;
	mScrollbarDarkChecked = false;
	mSmallScrollbarTheme = NULL;
	mStatusbarTheme = NULL;
	mTabTheme = NULL;
	mTreeViewTheme = NULL;
	mComboBoxTheme = NULL;
	mSliderTheme = NULL;
	mHeaderTheme = NULL;
	mMenuTheme = NULL;
	mSpinTheme = NULL;
	mThemeDLL = (MCSysModuleHandle)LoadLibraryA("UxTheme.dll");
	if (mThemeDLL == NULL)
		return False;

	openTheme = (OpenThemeDataPtr)GetProcAddress((HMODULE)mThemeDLL, "OpenThemeData");
	closeTheme = (CloseThemeDataPtr)GetProcAddress((HMODULE)mThemeDLL, "CloseThemeData");
	drawThemeBG = (DrawThemeBackgroundPtr)GetProcAddress((HMODULE)mThemeDLL, "DrawThemeBackground");
	getThemeContentRect = (GetThemeContentRectPtr)GetProcAddress((HMODULE)mThemeDLL, "GetThemeBackgroundContentRect");
	getThemePartSize = (GetThemePartSizePtr)GetProcAddress((HMODULE)mThemeDLL, "GetThemePartSize");
	getThemeSysFont = (GetThemeSysFontPtr)GetProcAddress((HMODULE)mThemeDLL, "GetThemeSysFont");
	getThemeColor = (GetThemeColorPtr)GetProcAddress((HMODULE)mThemeDLL, "GetThemeColor");
	getThemeBackgroundRegion = (GetThemeBackgroundRegionPtr)GetProcAddress((HMODULE)mThemeDLL, "GetThemeBackgroundRegion");
	beginBufferedPaint = (BeginBufferedPaintPtr)GetProcAddress((HMODULE)mThemeDLL, "BeginBufferedPaint");
	endBufferedPaint = (EndBufferedPaintPtr)GetProcAddress((HMODULE)mThemeDLL, "EndBufferedPaint");
	bufferedPaintClear = (BufferedPaintClearPtr)GetProcAddress((HMODULE)mThemeDLL, "BufferedPaintClear");
	getBufferedPaintBits = (GetBufferedPaintBitsPtr)GetProcAddress((HMODULE)mThemeDLL, "GetBufferedPaintBits");

	drawThemeBGEx = (DrawThemeBackgroundExPtr)GetProcAddress((HMODULE)mThemeDLL, "DrawThemeBackgroundEx");

	uint2 i;
    MCExecContext ctxt(nil, nil, nil);
	for (i = 0; i < NMENUCOLORS; i++)
	{
		menucolors[i] = nil;

        MCAutoStringRef t_type, t_error, t_string_value;
        MCAutoValueRef t_value;
        if (MCS_query_registry(MCSTR(menucolorsregs[i]), &t_value, &t_type, &t_error)
            && *t_value != nil
            && ctxt . ConvertToMutableString(*t_value, &t_string_value)
            && MCStringFindAndReplaceChar(*t_string_value, ' ', ',', kMCCompareExact))
		{
			/* UNCHECKED */ MCStringCopy(*t_string_value, menucolors[i]);
		}
	}
	
	if (MCmajorosversion >= MCOSVersionMake(6,0,0))
		mMenuTheme = (MCWinSysHandle)openTheme(NULL, L"Menu");

	return GetTheme(WTHEME_TYPE_PUSHBUTTON) != NULL;
}


void MCNativeTheme::unload()
{
	if (mThemeDLL == NULL)
		return;
	uint2 i;
	for (i = 0; i < NMENUCOLORS; i++)
	{
		if (menucolors[i] != nil)
		{
			MCValueRelease(menucolors[i]);
			menucolors[i] = nil;
		}
	}
	CloseData();
	if (mThemeDLL)
		FreeLibrary((HMODULE)mThemeDLL);
	mThemeDLL = NULL;
}

MCWinSysHandle MCNativeTheme::GetTheme(Widget_Type wtype)
{
	if (!mThemeDLL)
		return NULL;
	switch (wtype)
	{

	case WTHEME_TYPE_CHECKBOX:
	case WTHEME_TYPE_PUSHBUTTON:
	case WTHEME_TYPE_RADIOBUTTON:
	case WTHEME_TYPE_GROUP_FRAME:
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
		{
			if (!mButtonTheme)
				mButtonTheme = (MCWinSysHandle)openTheme(NULL, L"Button");
			return mButtonTheme;
		}
	case WTHEME_TYPE_TEXTFIELD:
	case WTHEME_TYPE_TEXTFIELD_FRAME:
	case WTHEME_TYPE_TEXTFIELD_FILL:
	case WTHEME_TYPE_COMBOFRAME:
	case WTHEME_TYPE_COMBOTEXT:
		{
			if (!mTextFieldTheme)
				mTextFieldTheme = (MCWinSysHandle)openTheme(NULL, L"Edit");
			return mTextFieldTheme;
		}
	case WTHEME_TYPE_TOOLTIP:
		{
			if (!mTooltipTheme)
				mTooltipTheme = (MCWinSysHandle)openTheme(NULL, L"Tooltip");
			return mTooltipTheme;
		}
	case WTHEME_TYPE_PROGRESSBAR:
	case WTHEME_TYPE_PROGRESSBAR_HORIZONTAL:
	case WTHEME_TYPE_PROGRESSBAR_VERTICAL:
	case WTHEME_TYPE_PROGRESSBAR_CHUNK:
	case WTHEME_TYPE_PROGRESSBAR_CHUNK_VERTICAL:
		{
			if (!mProgressTheme)
				mProgressTheme = (MCWinSysHandle)openTheme(NULL, L"Progress");
			return mProgressTheme;
		}
	case WTHEME_TYPE_TAB:
	case WTHEME_TYPE_TABPANE:
		{
			if (!mTabTheme)
				mTabTheme = (MCWinSysHandle)openTheme(NULL, L"Tab");
			return mTabTheme;
		}

	case WTHEME_TYPE_SMALLSCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_UP:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_DOWN:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_LEFT:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_RIGHT:

		{
			if (!mSmallScrollbarTheme)
				mSmallScrollbarTheme = (MCWinSysHandle)openTheme(NULL, L"Spin");
			return mSmallScrollbarTheme;
		}
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_UP:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_RIGHT:
	case WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL:
	case WTHEME_TYPE_SCROLLBAR_GRIPPER_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_GRIPPER_HORIZONTAL:
		{
			if (!mScrollbarTheme)
				mScrollbarTheme = (MCWinSysHandle)openTheme(NULL, L"Scrollbar");
			return mScrollbarTheme;
		}
	case WTHEME_TYPE_SLIDER:
	case WTHEME_TYPE_SLIDER_TRACK_HORIZONTAL:
	case WTHEME_TYPE_SLIDER_TRACK_VERTICAL:
	case WTHEME_TYPE_SLIDER_THUMB_HORIZONTAL:
	case WTHEME_TYPE_SLIDER_THUMB_VERTICAL:
		{
			if (!mSliderTheme)
				mSliderTheme = (MCWinSysHandle)openTheme(NULL, L"Trackbar");
			return mSliderTheme;
		}
	case WTHEME_TYPE_OPTIONBUTTON:
	case WTHEME_TYPE_OPTIONBUTTONTEXT:
	case WTHEME_TYPE_OPTIONBUTTONARROW:
		if (MCmajorosversion < MCOSVersionMake(6,0,0))
			return NULL;
	case WTHEME_TYPE_COMBOBUTTON:
	case WTHEME_TYPE_COMBO:
		{
			if (!mComboBoxTheme)
				mComboBoxTheme = (MCWinSysHandle)openTheme(NULL, L"Combobox");
			return mComboBoxTheme;
		}
	case WTHEME_TYPE_TREEVIEW_HEADER_CELL:
	case WTHEME_TYPE_TREEVIEW_HEADER_SORTARROW:
		{
			if (!mHeaderTheme)
				mHeaderTheme = (MCWinSysHandle)openTheme(NULL, L"Header");
			return mHeaderTheme;
		}
	case WTHEME_TYPE_LISTBOX:
	case WTHEME_TYPE_LISTBOX_LISTITEM:
	case WTHEME_TYPE_TREEVIEW:
	case WTHEME_TYPE_TREEVIEW_TWISTY_OPEN:
	case WTHEME_TYPE_TREEVIEW_TREEITEM:
		{
			if (!mTreeViewTheme)
				mTreeViewTheme = (MCWinSysHandle)openTheme(NULL, L"Listview");
			return mTreeViewTheme;
		}
	case WTHEME_TYPE_SPIN:
		{
			if (!mSpinTheme)
				mSpinTheme = (MCWinSysHandle)openTheme(NULL, L"Spin");
			return mSpinTheme;
		}
	}
	return NULL;
}

// Dark scrollbars use the dark variant of the scrollbar class that Explorer
// uses, "DarkMode_Explorer::ScrollBar" (Windows 10 1809 and later), which
// draws the scrollbar natively, with the system's own hover states. The class
// is not documented, and uxtheme resolves an unknown "<application>::" prefix
// to the plain class, so on a Windows without it OpenThemeData hands back the
// light scrollbar instead of failing. So the dark class is only kept when its
// track really draws dark; otherwise drawwidget draws the parts itself in
// dark colours (drawdarkscrollbarpart). Both classes stay open: whether a
// scrollbar is dark is decided for each one (widgetisdark), and the part
// sizes always come from the light class, so a scrollbar keeps its layout in
// either appearance. The dark class is tried again whenever the theme is
// reloaded (CloseData).
MCWinSysHandle MCNativeTheme::GetDarkScrollbarTheme(void)
{
	if (!mScrollbarDarkChecked && openTheme != NULL)
	{
		mScrollbarDarkChecked = true;
		mScrollbarDarkTheme = (MCWinSysHandle)openTheme(NULL, L"DarkMode_Explorer::ScrollBar");
		if (mScrollbarDarkTheme != NULL &&
			!MCWin32ThemePartDrawsDark(mScrollbarDarkTheme, SP_TRACKENDVERT, TS_NORMAL))
		{
			closeTheme(mScrollbarDarkTheme);
			mScrollbarDarkTheme = NULL;
		}
	}
	return mScrollbarDarkTheme;
}

void MCNativeTheme::CloseData()
{
	if (mToolbarTheme)
	{
		closeTheme(mToolbarTheme);
		mToolbarTheme = NULL;
	}
	if (mScrollbarTheme)
	{
		closeTheme(mScrollbarTheme);
		mScrollbarTheme = NULL;
	}
	if (mScrollbarDarkTheme)
	{
		closeTheme(mScrollbarDarkTheme);
		mScrollbarDarkTheme = NULL;
	}
	mScrollbarDarkChecked = false;
	if (mSmallScrollbarTheme)
	{
		closeTheme(mSmallScrollbarTheme);
		mSmallScrollbarTheme = NULL;
	}
	if (mRebarTheme)
	{
		closeTheme(mRebarTheme);
		mRebarTheme = NULL;
	}
	if (mProgressTheme)
	{
		closeTheme(mProgressTheme);
		mProgressTheme = NULL;
	}
	if (mButtonTheme)
	{
		closeTheme(mButtonTheme);
		mButtonTheme = NULL;
	}
	if (mTextFieldTheme)
	{
		closeTheme(mTextFieldTheme);
		mTextFieldTheme = NULL;
	}
	if (mTooltipTheme)
	{
		closeTheme(mTooltipTheme);
		mTooltipTheme = NULL;
	}
	if (mSliderTheme)
	{
		closeTheme(mSliderTheme);
		mSliderTheme = NULL;
	}
	if (mStatusbarTheme)
	{
		closeTheme(mStatusbarTheme);
		mStatusbarTheme = NULL;
	}
	if (mTabTheme)
	{
		closeTheme(mTabTheme);
		mTabTheme = NULL;
	}
	if (mTreeViewTheme)
	{
		closeTheme(mTreeViewTheme);
		mTreeViewTheme = NULL;
	}
	if (mComboBoxTheme)
	{
		closeTheme(mComboBoxTheme);
		mComboBoxTheme = NULL;
	}
	if (mHeaderTheme)
	{
		closeTheme(mHeaderTheme);
		mHeaderTheme = NULL;
	}
	// The light/dark switch reloads the theme (w32dcw32.cpp), so close every
	// handle load() and GetTheme() open, or each switch would leak them.
	if (mSpinTheme)
	{
		closeTheme(mSpinTheme);
		mSpinTheme = NULL;
	}
	if (mMenuTheme)
	{
		closeTheme(mMenuTheme);
		mMenuTheme = NULL;
	}
}

Boolean MCNativeTheme::iswidgetsupported(Widget_Type wtype)
{

	HANDLE htheme = GetTheme(wtype);
	return htheme != NULL;

}

int4 MCNativeTheme::getmetric(Widget_Metric wmetric)
{
	switch (wmetric)
	{
	case WTHEME_METRIC_TABSTARTOFFSET:
		return 2;
		break;
	case WTHEME_METRIC_TABOVERLAP:
		return -1;
		break;
	case WTHEME_METRIC_TABNONSELECTEDOFFSET:
		return 2;
		break;
	case WTHEME_METRIC_TABRIGHTMARGIN:
		return 12;
	case WTHEME_METRIC_TABLEFTMARGIN:
		return 11;
		break;
	case WTHEME_METRIC_COMBOSIZE:
		return -1;
		break;
	// MH-2007-03-16 [[ Bug 3598 ]] Adding in support for option menu button arrow size for appropriate clipping.
	case WTHEME_METRIC_OPTIONBUTTONARROWSIZE:
		return 20;
		break;
	}
	return 0;
}

int4 MCNativeTheme::getwidgetmetric(const MCWidgetInfo &winfo, Widget_Metric wmetric)
{
	return 0;
}

Boolean MCNativeTheme::getthemepropbool(Widget_ThemeProps themeprop)
{
	if (themeprop == WTHEME_PROP_SUPPORTHOVERING)
		return True;
	return False;
}

Widget_Part MCNativeTheme::hittest(const MCWidgetInfo &winfo, int2 mx, int2 my, const MCRectangle &drect)
{

	switch (winfo.type)
	{
	case WTHEME_TYPE_SLIDER:
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR:
		return hittestscrollcontrols(winfo,mx,my,drect);
		break;
	default:
		return MCU_point_in_rect(drect, mx, my)?WTHEME_PART_ALL:WTHEME_PART_UNDEFINED;
		break;
	}
}



Widget_Part MCNativeTheme::hittestscrollcontrols(const MCWidgetInfo &winfo, int2 mx,int2 my, const MCRectangle &drect)
{
	Widget_Part wpart = WTHEME_PART_UNDEFINED;
	MCRectangle sbincarrowrect,sbdecarrowrect, sbthumbrect, sbinctrackrect, sbdectrackrect;
	getscrollbarrects(winfo, drect, sbincarrowrect, sbdecarrowrect, sbthumbrect,sbinctrackrect,sbdectrackrect);
	if (MCU_point_in_rect(sbincarrowrect, mx, my))
		wpart = WTHEME_PART_ARROW_INC;
	else if (MCU_point_in_rect(sbinctrackrect, mx, my))
		wpart = WTHEME_PART_TRACK_INC;
	else if (MCU_point_in_rect(sbthumbrect, mx, my))
		wpart = WTHEME_PART_THUMB;
	else if (MCU_point_in_rect(sbdectrackrect, mx, my))
		wpart = WTHEME_PART_TRACK_DEC;
	else if (MCU_point_in_rect(sbdecarrowrect, mx, my))
		wpart = WTHEME_PART_ARROW_DEC;

	bool t_vertical;
	t_vertical = (winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0;
	if ((t_vertical && drect . width * 2 >= drect . height) || (!t_vertical && drect . height * 2 >= drect . width))
	{
		if (wpart == WTHEME_PART_ARROW_INC)
			wpart = WTHEME_PART_ARROW_DEC;
		else if (wpart == WTHEME_PART_ARROW_DEC)
			wpart = WTHEME_PART_ARROW_INC;
	}

	return wpart;
}


void MCNativeTheme::getwidgetrect(const MCWidgetInfo &winfo, Widget_Metric wmetric, const MCRectangle &srect,
                                  MCRectangle &drect)
{
	if (wmetric == WTHEME_METRIC_PARTSIZE || wmetric == WTHEME_METRIC_CONTENTSIZE && winfo.type == WTHEME_TYPE_COMBOTEXT && winfo . part == WTHEME_PART_COMBOTEXT)
	{
		switch (winfo.type)
		{
		case WTHEME_TYPE_SCROLLBAR:
		case WTHEME_TYPE_PROGRESSBAR:
		case WTHEME_TYPE_SLIDER:
			{
				MCRectangle sbincarrowrect,sbdecarrowrect, sbthumbrect, sbinctrackrect, sbdectrackrect;
				getscrollbarrects(winfo, srect, sbincarrowrect, sbdecarrowrect, sbthumbrect,sbinctrackrect,sbdectrackrect);
				switch (winfo.part)
				{
				case WTHEME_PART_ARROW_DEC:
					drect = sbdecarrowrect;
					break;
				case WTHEME_PART_ARROW_INC:
					drect = sbincarrowrect;
					break;
				case WTHEME_PART_TRACK_DEC:
					drect = sbdectrackrect;
					break;
				case WTHEME_PART_TRACK_INC:
					drect = sbinctrackrect;
					break;
				case WTHEME_PART_THUMB:
					drect = sbthumbrect;
					break;
				}
				return;
			}
		case WTHEME_TYPE_COMBO:
		case WTHEME_TYPE_COMBOTEXT:
			{
				MCRectangle combobuttonrect = srect;
				MCWidgetInfo twinfo = winfo;
				twinfo.type = WTHEME_TYPE_COMBOBUTTON;
				uint1 comboframesize = 1;//we should query comboframe value
				int4 t_button_size;
				t_button_size = srect . height - 2;

				combobuttonrect.x = srect . x + srect . width - comboframesize - t_button_size;
				combobuttonrect.y = srect . y + 1 + ((srect . height - 2) - t_button_size) / 2;
				combobuttonrect.width = t_button_size;
				combobuttonrect.height = t_button_size;
				if (winfo.part == WTHEME_PART_COMBOTEXT)
				{
					if (wmetric == WTHEME_METRIC_CONTENTSIZE)
					{
						drect = MCU_reduce_rect(srect,comboframesize);
						drect.width -= combobuttonrect . width;
					}
					else
						drect = srect;
				}
				else if (winfo.part == WTHEME_PART_COMBOBUTTON)
					drect = combobuttonrect;
				return;
			}
		}
		MCTheme::getwidgetrect(winfo,wmetric,srect,drect);
	}
	else
	{
		RECT trect;
		HANDLE htheme = GetTheme(winfo.type);
		if (!htheme)
			return;
		int4 part, state;
		Boolean res = GetThemePartAndState(winfo, part, state);
		if (!res)
			return;
		SetRect(&trect,srect.x,srect.y,
		        srect.width+srect.x,srect.height+srect.y);
		MCScreenDC *pms = (MCScreenDC *)MCscreen;
		HDC tdc = pms->getsrchdc();
		if (!tdc)
			return;
		if (wmetric == WTHEME_METRIC_CONTENTSIZE)
		{
			RECT contentrect;
			if (getThemeContentRect && getThemeContentRect(htheme, tdc, part, state, &trect,&contentrect) == S_OK)
			{
				drect.x = (int2)contentrect.left;
				drect.y = (int2)contentrect.top;
				drect.width = uint2(contentrect.right - contentrect.left);
				drect.height = uint2(contentrect.bottom - contentrect.top);
			}
			return;
		}
		else
		{
			THEMESIZE themesize = TS_MIN;
			if (wmetric == WTHEME_METRIC_OPTIMUMSIZE)
				themesize = TS_TRUE;
			else if (wmetric == WTHEME_METRIC_DRAWSIZE)
				themesize = TS_DRAW;
			SIZE tsize;
			if (getThemePartSize && getThemePartSize(htheme, tdc, part, state, &trect, themesize, &tsize) == S_OK)
			{
				drect.x = srect.x;
				drect.y = srect.y;
				drect.width = (uint2)tsize.cx;
				drect.height = (uint2)tsize.cy;
				return;
			}
		}
		MCTheme::getwidgetrect(winfo,wmetric,srect,drect);
	}
}

uint2 MCNativeTheme::getthemeid()
{
	return LF_NATIVEWIN; //it's a native windows theme
}

void MCNativeTheme::getthemecolor(const MCWidgetInfo &winfo, Widget_Color ctype, MCStringRef &r_colorbuf)
{
	if (winfo.type == WTHEME_TYPE_MENU)
	{
		switch (ctype)
		{
            case WCOLOR_TEXT:
                {
                    //-- tperry 11th November 2025: Check dark mode first, ignore registry colors
                    // (OXT-Beyond: in the appearance of the menu's button,
                    // MCStack::createmenu)
                    bool t_is_dark = widgetisdark(winfo, nil);
                    
                    if (t_is_dark)
                        /* UNCHECKED */ MCStringCreateWithCString("255,255,255", r_colorbuf);
                    else if (menucolors[0] != nil)
                        r_colorbuf = MCValueRetain(menucolors[0]);
                    else
                        /* UNCHECKED */ MCStringCreateWithCString("0,0,0", r_colorbuf);
                }
                break;
            case WCOLOR_HILIGHT:
                if (menucolors[1] != nil)
                    r_colorbuf = MCValueRetain(menucolors[1]);
                else
                    /* UNCHECKED */ MCStringCreateWithCString("255,0,0", r_colorbuf);
                break;
            case WCOLOR_BACK:
                {
                    //-- tperry 11th November 2025: Check dark mode first, ignore registry colors
                    bool t_is_dark = widgetisdark(winfo, nil);
                    
                    if (t_is_dark)
                        /* UNCHECKED */ MCStringCreateWithCString("32,32,32", r_colorbuf);
                    else if (menucolors[2] != nil)
                        r_colorbuf = MCValueRetain(menucolors[2]);
                    else
                        /* UNCHECKED */ MCStringCreateWithCString("240,240,240", r_colorbuf);
                }
                break;
            case WCOLOR_BORDER:
                if (menucolors[3] != nil)
                    r_colorbuf = MCValueRetain(menucolors[3]);
                else
                    /* UNCHECKED */ MCStringCreateWithCString("155,155,155", r_colorbuf);
                break;
		}
	}
	else if (winfo.type == WTHEME_TYPE_OPTIONBUTTON || winfo.type == WTHEME_TYPE_OPTIONBUTTONTEXT)
	{
		//-- tperry 11th November 2025: Handle option menu colors for dark mode
		bool t_is_dark = widgetisdark(winfo, nil);
		
		switch (ctype)
		{
			case WCOLOR_TEXT:
				if (t_is_dark)
					/* UNCHECKED */ MCStringCreateWithCString("255,255,255", r_colorbuf);
				else
					/* UNCHECKED */ MCStringCreateWithCString("0,0,0", r_colorbuf);
				break;
			case WCOLOR_BACK:
				if (t_is_dark)
					/* UNCHECKED */ MCStringCreateWithCString("32,32,32", r_colorbuf);
				else
					/* UNCHECKED */ MCStringCreateWithCString("255,255,255", r_colorbuf);
				break;
			default:
				r_colorbuf = MCValueRetain(kMCEmptyString);
				break;
		}
	}
	else if (winfo.type == WTHEME_TYPE_PUSHBUTTON || 
	         winfo.type == WTHEME_TYPE_CHECKBOX || 
	         winfo.type == WTHEME_TYPE_RADIOBUTTON)
	{
		//-- tperry 11th November 2025: Handle button/checkbox/radio colors for dark mode
		bool t_is_dark = widgetisdark(winfo, nil);
		
		switch (ctype)
		{
			case WCOLOR_TEXT:
				if (t_is_dark)
					/* UNCHECKED */ MCStringCreateWithCString("255,255,255", r_colorbuf);
				else
					/* UNCHECKED */ MCStringCreateWithCString("0,0,0", r_colorbuf);
				break;
			case WCOLOR_BACK:
				if (t_is_dark)
					/* UNCHECKED */ MCStringCreateWithCString("32,32,32", r_colorbuf);
				else
					/* UNCHECKED */ MCStringCreateWithCString("240,240,240", r_colorbuf);
				break;
			default:
				r_colorbuf = MCValueRetain(kMCEmptyString);
				break;
		}
	}
    else
        r_colorbuf = MCValueRetain(kMCEmptyString);
}




uint2 MCNativeTheme::getthemefamilyid()
{
	return LF_WIN95; //however it belongs to the win32 theme family
}

////////////////////////////////////////////////////////////////////////////////
//
//  Dark native controls
//
//  uxtheme has no dark variant of the button, edit, tab, trackbar or
//  progress classes: they draw light whatever the application's mode. Tom
//  Perry's dark mode (38d5712b2) drew push buttons, option menus and combo
//  boxes itself as a flat fill and a grey outline; HyperXTalk (Emily-Elizabeth
//  Howard, 7107166b1 and ddcb9ff9f) added checkboxes, radio buttons, fields,
//  tabs and groups. Here they are drawn flat, like the dark controls of
//  Windows 11, with states, for widgets drawn in the dark appearance
//  (widgetisdark). The background stays the dark theme's 0x20
//  (windows-theme.cpp). Outlines are at least 3:1 on it, and the faces keep
//  the disabled grey label (137) at 4.5:1. Edges are one logical pixel wide
//  and drawn as filled strips, which stay crisp when scaled by 250%.

// Push buttons, option menus and the button of combo boxes
static const uint16_t s_dark_face = 0x3737;
static const uint16_t s_dark_face_hover = 0x4545;
static const uint16_t s_dark_face_pressed = 0x2B2B;
static const uint16_t s_dark_face_disabled = 0x2020;
static const uint16_t s_dark_face_border = 0x6E6E;
// Checkbox and radio button indicators; checked ones are filled with the
// accent colour
static const uint16_t s_dark_indicator_fill = 0x2020;
static const uint16_t s_dark_indicator_border = 0x9A9A;
static const uint16_t s_dark_indicator_border_hover = 0xC0C0;
static const uint16_t s_dark_indicator_disabled = 0x6E6E;
static const uint16_t s_dark_indicator_checked_disabled = 0x5555;
// Tabs and the tab pane
static const uint16_t s_dark_tab_pane = 0x2B2B;
static const uint16_t s_dark_tab_selected = 0x2B2B;
static const uint16_t s_dark_tab_unselected = 0x2020;
static const uint16_t s_dark_tab_hover = 0x3333;
static const uint16_t s_dark_tab_border = 0x6E6E;
// The frame of fields and combo boxes (the fill is the field's own)
static const uint16_t s_dark_frame = 0x7A7A;
static const uint16_t s_dark_frame_hover = 0x9A9A;
static const uint16_t s_dark_frame_disabled = 0x3C3C;
// The frame of groups
static const uint16_t s_dark_group_border = 0x6E6E;
// Arrows: the chevron of option menus and combo boxes
static const uint16_t s_dark_glyph = 0xD0D0;
static const uint16_t s_dark_glyph_hover = 0xF0F0;
static const uint16_t s_dark_glyph_disabled = 0x6E6E;
// Scrollbars drawn without the dark scrollbar class (drawdarkscrollbarpart)
static const uint16_t s_dark_scrollbar_track = 0x2B2B;
static const uint16_t s_dark_scrollbar_thumb = 0x6E6E;
static const uint16_t s_dark_scrollbar_thumb_active = 0x8A8A;
static const uint16_t s_dark_scrollbar_glyph = 0x9A9A;
static const uint16_t s_dark_scrollbar_glyph_active = 0xD0D0;
static const uint16_t s_dark_scrollbar_glyph_disabled = 0x5555;

static MCColor MCDarkGrey(uint16_t p_level)
{
	MCColor t_color;
	t_color . red = t_color . green = t_color . blue = p_level;
	return t_color;
}

static void MCDarkFill(MCDC *dc, const MCRectangle& p_rect, const MCColor& p_color)
{
	if (p_rect . width == 0 || p_rect . height == 0)
		return;
	dc -> setforeground(p_color);
	dc -> setfillstyle(FillSolid, nil, 0, 0);
	dc -> fillrect(p_rect);
}

// An outline p_width logical pixels wide inside p_rect, as four strips. The
// part of the top edge from p_gap_start to p_gap_end (x) is left out: the gap
// of a tab pane under its selected tab, the label of a group.
static void MCDarkRing(MCDC *dc, const MCRectangle& p_rect, uint2 p_width, const MCColor& p_color, int2 p_gap_start = 0, int2 p_gap_end = 0)
{
	if (p_rect . width <= 2 * p_width || p_rect . height <= 2 * p_width)
	{
		MCDarkFill(dc, p_rect, p_color);
		return;
	}

	int2 t_left = p_rect . x;
	int2 t_right = p_rect . x + p_rect . width;
	if (p_gap_end > p_gap_start)
	{
		int2 t_start = MCU_max(t_left, MCU_min(t_right, p_gap_start));
		int2 t_end = MCU_max(t_left, MCU_min(t_right, p_gap_end));
		MCDarkFill(dc, MCU_make_rect(t_left, p_rect . y, t_start - t_left, p_width), p_color);
		MCDarkFill(dc, MCU_make_rect(t_end, p_rect . y, t_right - t_end, p_width), p_color);
	}
	else
		MCDarkFill(dc, MCU_make_rect(t_left, p_rect . y, p_rect . width, p_width), p_color);
	MCDarkFill(dc, MCU_make_rect(t_left, p_rect . y + p_rect . height - p_width, p_rect . width, p_width), p_color);
	MCDarkFill(dc, MCU_make_rect(t_left, p_rect . y + p_width, p_width, p_rect . height - 2 * p_width), p_color);
	MCDarkFill(dc, MCU_make_rect(t_right - p_width, p_rect . y + p_width, p_width, p_rect . height - 2 * p_width), p_color);
}

// A filled triangle pointing in p_direction, centred in p_rect, twice as
// wide as it is high: p_half is half its width. The arrows of the dark
// scrollbar parts, the little arrows and the option and combo chevron.
enum MCDarkGlyph
{
	kMCDarkGlyphUp,
	kMCDarkGlyphDown,
	kMCDarkGlyphLeft,
	kMCDarkGlyphRight,
};

static void MCDarkDrawGlyph(MCDC *dc, const MCRectangle& p_rect, MCDarkGlyph p_direction, int2 p_half, const MCColor& p_color)
{
	if (p_half < 2)
		p_half = 2;
	int2 t_cx = p_rect.x + p_rect.width / 2;
	int2 t_cy = p_rect.y + p_rect.height / 2;
	int2 t_near = p_half / 2;
	int2 t_far = p_half - t_near;
	MCPoint t_points[3];
	switch (p_direction)
	{
	case kMCDarkGlyphUp:
		t_points[0] = MCPointMake(t_cx - p_half, t_cy + t_far);
		t_points[1] = MCPointMake(t_cx + p_half, t_cy + t_far);
		t_points[2] = MCPointMake(t_cx, t_cy - t_near);
		break;
	case kMCDarkGlyphDown:
		t_points[0] = MCPointMake(t_cx - p_half, t_cy - t_near);
		t_points[1] = MCPointMake(t_cx + p_half, t_cy - t_near);
		t_points[2] = MCPointMake(t_cx, t_cy + t_far);
		break;
	case kMCDarkGlyphLeft:
		t_points[0] = MCPointMake(t_cx + t_far, t_cy - p_half);
		t_points[1] = MCPointMake(t_cx + t_far, t_cy + p_half);
		t_points[2] = MCPointMake(t_cx - t_near, t_cy);
		break;
	default:
		t_points[0] = MCPointMake(t_cx - t_near, t_cy - p_half);
		t_points[1] = MCPointMake(t_cx - t_near, t_cy + p_half);
		t_points[2] = MCPointMake(t_cx + t_far, t_cy);
		break;
	}
	dc -> setforeground(p_color);
	dc -> setfillstyle(FillSolid, nil, 0, 0);
	dc -> fillpolygon(t_points, 3);
}

// The colour of a glyph drawn on the accent colour: black or white, whichever
// contrasts more with it
static MCColor MCDarkGlyphOn(const MCColor& p_fill)
{
	return MCAppearanceColorIsLight(p_fill) ? MCDarkGrey(0x0000) : MCDarkGrey(0xFFFF);
}

static MCColor MCDarkGlyphColor(const MCWidgetInfo& winfo)
{
	if (winfo . state & WTHEME_STATE_DISABLED)
		return MCDarkGrey(s_dark_glyph_disabled);
	if (winfo . state & (WTHEME_STATE_HOVER | WTHEME_STATE_PRESSED))
		return MCDarkGrey(s_dark_glyph_hover);
	return MCDarkGrey(s_dark_glyph);
}

// The face of a push button, an option menu or a combo box's button: the
// default button and the focused one are outlined in the accent colour
static void MCDarkDrawFace(MCDC *dc, const MCWidgetInfo& winfo, const MCRectangle& p_rect)
{
	uint16_t t_face;
	if (winfo . state & WTHEME_STATE_DISABLED)
		t_face = s_dark_face_disabled;
	else if (winfo . state & (WTHEME_STATE_PRESSED | WTHEME_STATE_HILITED))
		t_face = s_dark_face_pressed;
	else if (winfo . state & WTHEME_STATE_HOVER)
		t_face = s_dark_face_hover;
	else
		t_face = s_dark_face;
	MCDarkFill(dc, p_rect, MCDarkGrey(t_face));

	bool t_accent;
	t_accent = (winfo . state & WTHEME_STATE_DISABLED) == 0 &&
		(winfo . state & (WTHEME_STATE_HASDEFAULT | WTHEME_STATE_HASFOCUS)) != 0 &&
		(winfo . state & WTHEME_STATE_SUPPRESSDEFAULT) == 0;
	if (t_accent)
		MCDarkRing(dc, p_rect, 2, MCaccentcolor);
	else
		MCDarkRing(dc, p_rect, 1, MCDarkGrey(s_dark_face_border));
}

// A checkbox's box or a radio button's circle: dark with a light outline,
// or filled with the accent colour and a tick or dot when checked
static void MCDarkDrawIndicator(MCDC *dc, const MCWidgetInfo& winfo, const MCRectangle& p_rect, bool p_round)
{
	bool t_disabled = (winfo . state & WTHEME_STATE_DISABLED) != 0;
	bool t_checked = (winfo . state & WTHEME_STATE_HILITED) != 0;

	// A square, centred where the theme would draw the part
	uint2 t_size = MCU_min(p_rect . width, p_rect . height);
	MCRectangle t_box = MCU_make_rect(p_rect . x + (p_rect . width - t_size) / 2,
									  p_rect . y + (p_rect . height - t_size) / 2, t_size, t_size);

	MCColor t_fill, t_border;
	if (t_checked)
	{
		t_fill = t_disabled ? MCDarkGrey(s_dark_indicator_checked_disabled) : MCaccentcolor;
		t_border = t_fill;
	}
	else
	{
		t_fill = MCDarkGrey(s_dark_indicator_fill);
		if (t_disabled)
			t_border = MCDarkGrey(s_dark_indicator_disabled);
		else if (winfo . state & (WTHEME_STATE_HOVER | WTHEME_STATE_PRESSED))
			t_border = MCDarkGrey(s_dark_indicator_border_hover);
		else
			t_border = MCDarkGrey(s_dark_indicator_border);
	}

	dc -> setfillstyle(FillSolid, nil, 0, 0);
	if (p_round)
	{
		dc -> setforeground(t_border);
		dc -> fillarc(t_box, 0, 360);
		dc -> setforeground(t_fill);
		dc -> fillarc(MCU_reduce_rect(t_box, 1), 0, 360);
	}
	else
	{
		MCDarkFill(dc, t_box, t_fill);
		MCDarkRing(dc, t_box, 1, t_border);
	}

	if (!t_checked)
		return;

	MCColor t_glyph;
	t_glyph = t_disabled ? MCDarkGrey(s_dark_indicator_fill) : MCDarkGlyphOn(t_fill);
	dc -> setforeground(t_glyph);
	if (p_round)
	{
		// A round dot, half the circle's width
		uint2 t_dot = MCU_max(4, t_size / 2);
		dc -> fillarc(MCU_make_rect(t_box . x + (t_size - t_dot) / 2, t_box . y + (t_size - t_dot) / 2, t_dot, t_dot), 0, 360);
	}
	else
	{
		// The tick of MCButton::drawcheck, scaled from its 9 pixels to the box
		MCRectangle t_inside = MCU_reduce_rect(t_box, 2);
		static const int2 s_tick[6][2] = { {1, 3}, {3, 5}, {8, 0}, {8, 3}, {3, 8}, {1, 6} };
		MCPoint t_points[6];
		for (int i = 0; i < 6; i++)
		{
			t_points[i] . x = t_inside . x + s_tick[i][0] * t_inside . width / 9;
			t_points[i] . y = t_inside . y + s_tick[i][1] * t_inside . height / 9;
		}
		dc -> fillpolygon(t_points, 6);
	}
}

// Draws the widget in the dark appearance, after drawwidget has worked out its
// rectangle (p_rect) and the part of it to draw (p_clip). Returns false for
// the widgets it leaves to uxtheme.
Boolean MCNativeTheme::drawdarkwidget(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &p_rect, const MCRectangle &p_clip)
{
	switch (winfo . type)
	{
	case WTHEME_TYPE_PUSHBUTTON:
	case WTHEME_TYPE_OPTIONBUTTONTEXT:
		MCDarkDrawFace(dc, winfo, p_rect);
		return True;

	case WTHEME_TYPE_OPTIONBUTTONARROW:
		// The chevron, on the option menu's face
		MCDarkDrawGlyph(dc, p_rect, kMCDarkGlyphDown, MCU_max(4, MCU_min(p_rect . width, p_rect . height) / 3), MCDarkGlyphColor(winfo));
		return True;

	case WTHEME_TYPE_COMBOBUTTON:
		// The combo box's button, with its chevron; the frame around the
		// whole combo box is drawn next (COMBOTEXT)
		MCDarkDrawFace(dc, winfo, p_rect);
		MCDarkDrawGlyph(dc, p_rect, kMCDarkGlyphDown, MCU_max(4, MCU_min(p_rect . width, p_rect . height) / 3), MCDarkGlyphColor(winfo));
		return True;

	case WTHEME_TYPE_CHECKBOX:
		MCDarkDrawIndicator(dc, winfo, p_rect, false);
		return True;

	case WTHEME_TYPE_RADIOBUTTON:
		MCDarkDrawIndicator(dc, winfo, p_rect, true);
		return True;

	case WTHEME_TYPE_TEXTFIELD_FRAME:
	case WTHEME_TYPE_COMBOTEXT:
	{
		// The frame only: the field fills its content with its own
		// background, the theme's 0x20 unless it sets one
		uint16_t t_frame;
		if (winfo . state & WTHEME_STATE_DISABLED)
			t_frame = s_dark_frame_disabled;
		else if (winfo . state & WTHEME_STATE_HASFOCUS)
			t_frame = 0;
		else if (winfo . state & WTHEME_STATE_HOVER)
			t_frame = s_dark_frame_hover;
		else
			t_frame = s_dark_frame;
		MCDarkRing(dc, p_rect, 1, t_frame == 0 ? MCaccentcolor : MCDarkGrey(t_frame));
		return True;
	}

	case WTHEME_TYPE_TABPANE:
	{
		MCDarkFill(dc, p_rect, MCDarkGrey(s_dark_tab_pane));
		int2 t_gap_start = 0, t_gap_end = 0;
		if (winfo . datatype == WTHEME_DATA_TABPANE && winfo . data != nil)
		{
			const MCWidgetTabPaneInfo *t_pane = (const MCWidgetTabPaneInfo *)winfo . data;
			if (t_pane -> gap_length > 0)
			{
				// Open under the selected tab, which joins the pane
				t_gap_start = p_rect . x + t_pane -> gap_start + 1;
				t_gap_end = p_rect . x + t_pane -> gap_start + t_pane -> gap_length - 1;
			}
		}
		MCDarkRing(dc, p_rect, 1, MCDarkGrey(s_dark_tab_border), t_gap_start, t_gap_end);
		return True;
	}

	case WTHEME_TYPE_TAB:
	{
		// The part of the tab drawwidget clips it to (p_clip), which leaves
		// out its bottom edge where it meets the pane
		uint16_t t_face;
		if (winfo . state & WTHEME_STATE_HILITED)
			t_face = s_dark_tab_selected;
		else if ((winfo . state & WTHEME_STATE_DISABLED) == 0 && (winfo . state & (WTHEME_STATE_HOVER | WTHEME_STATE_PRESSED)) != 0)
			t_face = s_dark_tab_hover;
		else
			t_face = s_dark_tab_unselected;
		MCRectangle t_tab;
		t_tab = MCU_intersect_rect(p_rect, p_clip);
		MCDarkFill(dc, t_tab, MCDarkGrey(t_face));
		if (t_tab . width > 2 && t_tab . height > 1)
		{
			MCColor t_border = MCDarkGrey(s_dark_tab_border);
			MCDarkFill(dc, MCU_make_rect(t_tab . x, t_tab . y, t_tab . width, 1), t_border);
			MCDarkFill(dc, MCU_make_rect(t_tab . x, t_tab . y + 1, 1, t_tab . height - 1), t_border);
			MCDarkFill(dc, MCU_make_rect(t_tab . x + t_tab . width - 1, t_tab . y + 1, 1, t_tab . height - 1), t_border);
		}
		return True;
	}

	case WTHEME_TYPE_GROUP_FRAME:
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
	{
		// The frame only, with a gap for the label: an opaque group fills
		// itself with its own background
		int2 t_gap_start = 0, t_gap_end = 0;
		if (winfo . datatype == WTHEME_DATA_RECT && winfo . data != nil)
		{
			const MCRectangle *t_label = (const MCRectangle *)winfo . data;
			t_gap_start = t_label -> x;
			t_gap_end = t_label -> x + t_label -> width;
		}
		MCDarkRing(dc, p_rect, 1, MCDarkGrey(s_dark_group_border), t_gap_start, t_gap_end);
		return True;
	}

	default:
		return False;
	}
}

Boolean MCNativeTheme::drawwidget(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	HANDLE htheme = GetTheme(winfo.type);
	if (!htheme)
		return False;

	// The parts of a dark scrollbar (the scrollbar as a whole goes through
	// drawscrollcontrols, which lays the parts out with the light class's
	// sizes): with the dark class, or drawn here when there is none (see
	// GetDarkScrollbarTheme)
	if (htheme == (HANDLE)mScrollbarTheme && winfo.type != WTHEME_TYPE_SCROLLBAR && widgetisdark(winfo, dc))
	{
		HANDLE t_dark_theme = GetDarkScrollbarTheme();
		if (t_dark_theme == NULL)
			return drawdarkscrollbarpart(dc, winfo, drect);
		htheme = t_dark_theme;
	}

	if (!drawThemeBG)
		return False;
	int4 part, state;
	Boolean res = GetThemePartAndState(winfo, part, state);
	if (!res)
		return False;
		
	MCRectangle crect = drect;
	MCRectangle trect = drect;
	bool t_clip_interior = false;
	MCRectangle t_interior;

	switch (winfo.type)
	{
	case WTHEME_TYPE_COMBO:
		{
			MCWidgetInfo twinfo = winfo;
			MCRectangle comboentryrect,combobuttonrect;
			//draw text box
			twinfo.part = WTHEME_PART_COMBOTEXT;
			getwidgetrect(twinfo, WTHEME_METRIC_PARTSIZE,drect,comboentryrect);
			twinfo.part = WTHEME_PART_COMBOBUTTON;
			getwidgetrect(twinfo, WTHEME_METRIC_PARTSIZE,drect,combobuttonrect);

			twinfo.type = WTHEME_TYPE_COMBOBUTTON;
			drawwidget(dc, twinfo, combobuttonrect);
			
			twinfo.type = WTHEME_TYPE_COMBOTEXT;

			drawwidget(dc, twinfo, comboentryrect);
			return True;
		}

	case WTHEME_TYPE_OPTIONBUTTON:
		{
			MCWidgetInfo twinfo = winfo;
			MCRectangle arrowrect;
			
			MCU_set_rect(arrowrect, trect . x + trect . width - 4 - 7 - 4 - 2, trect . y, 4 + 7 + 4, trect . height);

			twinfo.type = WTHEME_TYPE_OPTIONBUTTONTEXT;
			drawwidget(dc, twinfo, trect);

			twinfo.type = WTHEME_TYPE_OPTIONBUTTONARROW;
			drawwidget(dc, twinfo, arrowrect);
			return True;
		}

	case WTHEME_TYPE_TAB:
		{
			if (winfo.attributes & WTHEME_ATT_TABFIRSTSELECTED &&
			        winfo.state & WTHEME_STATE_HILITED)
			{
				//align to edge of pane
				trect.x -= 2;
				trect.height++;
				;
				trect.width +=2;
				crect = trect;
				crect.height--;
			}
			if (!(winfo.state & WTHEME_STATE_HILITED))
				crect.height--; //make sure non hilited tab doesn't draw over tab pane
			if (winfo.attributes & WTHEME_ATT_TABRIGHTEDGE ||
			        winfo.attributes & WTHEME_ATT_TABLEFTEDGE)
			{
				//hardcoded to make it draw correctly
				uint1 edgeSize = 2;
				// Armed with the size of the edge, we now need to either shift to the left or to the
				// right.  The clip rect won't include this extra area, so we know that we're
				// effectively shifting the edge out of view (such that it won't be painted).
				if (winfo.attributes & WTHEME_ATT_TABLEFTEDGE)
					// The right edge should not be drawn.  Extend our rect by the edge size.
					trect.width += edgeSize;
				else
				{
					// The left edge should not be drawn.  Move the widget rect's left coord back.
					trect.x -= edgeSize;
					trect.width += edgeSize;
				}
			}
			break;
		}
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR:
		return drawscrollcontrols(dc, winfo, drect);
		break;
	case WTHEME_TYPE_PROGRESSBAR:
		return drawprogressbar(dc, winfo, drect);
		break;
	case WTHEME_TYPE_SLIDER:
		return drawslider(dc, winfo, drect);
		break;
	case WTHEME_TYPE_COMBOTEXT:
	case WTHEME_TYPE_TEXTFIELD_FRAME:
	case WTHEME_TYPE_TEXTFIELD_FILL:
		//this is used to draw border of text fields and not contents..
		//there is a drawthemebackex call which can do this, but only in win2000!.
		MCRectangle tfcontentrect;
		getwidgetrect(winfo,WTHEME_METRIC_CONTENTSIZE,crect,tfcontentrect);
		if (winfo . type == WTHEME_TYPE_TEXTFIELD_FRAME || winfo . type == WTHEME_TYPE_COMBOTEXT)
		{
			t_clip_interior = true;
			t_interior = tfcontentrect;

			// MW-2007-07-05: [[ Bug 2508 ]] - Missing single pixel border on XP fields
			t_interior = MCU_reduce_rect(t_interior, 1);
		}
		else
			crect = tfcontentrect;
		break;
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_GROUP_FRAME:
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
		if (winfo . datatype == WTHEME_DATA_RECT)
		{
			t_clip_interior = true;
			t_interior = *(MCRectangle *)winfo . data;
		}
		break;
	}

	//-- tperry 18th November 2025: Custom draw widgets in dark mode
	// (OXT-Beyond: here, after the switch above, as HyperXTalk 7107166b1 does,
	// so that option menus and combo boxes are split into their parts and get
	// their arrow; per widget, in the appearance of its object)
	if (widgetisdark(winfo, dc) && drawdarkwidget(dc, winfo, trect, crect))
		return True;

	MCThemeDrawInfo t_info;
	t_info . theme = (MCWinSysHandle)htheme;
	t_info . part = part;
	t_info . state = state;
	t_info . bounds = trect;
	t_info . clip = crect;
	t_info . clip_interior = t_clip_interior;
	if (t_clip_interior)
		t_info . interior = t_interior;
	dc -> drawtheme(THEME_DRAW_TYPE_BACKGROUND, &t_info);

	return True;
}


Boolean MCNativeTheme::drawprogressbar(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	if (winfo.datatype != WTHEME_DATA_SCROLLBAR)
		return False;
	uint4 pbpartdefaultstate = winfo.state & WTHEME_STATE_DISABLED? WTHEME_STATE_DISABLED: WTHEME_STATE_CLEAR;
	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;
	MCWidgetInfo twinfo = winfo;
	twinfo.type = winfo.attributes & WTHEME_ATT_SBVERTICAL ? WTHEME_TYPE_PROGRESSBAR_VERTICAL:
	              WTHEME_TYPE_PROGRESSBAR_HORIZONTAL;
	twinfo.state = pbpartdefaultstate;
	drawwidget(dc, twinfo, drect);
	MCRectangle progressbarrect;
	getwidgetrect(twinfo,WTHEME_METRIC_CONTENTSIZE,drect,progressbarrect);
	if (progressbarrect.width && progressbarrect.height)
	{
		int2 endpos = 0;
		if (winfo.attributes & WTHEME_ATT_SBVERTICAL)
		{
			endpos = (int2)(sbinfo->thumbpos / (sbinfo->endvalue - sbinfo->startvalue)
			                * (real8)progressbarrect.height) + progressbarrect.y;
			uint2 ty = (progressbarrect.y+progressbarrect.height) - (endpos - progressbarrect.y);
			progressbarrect.height =  endpos - progressbarrect.y;
			progressbarrect.y = ty;
		}
		else
		{
			endpos = (int2)(sbinfo->thumbpos / (sbinfo->endvalue - sbinfo->startvalue)
			                * (real8)progressbarrect.width) + progressbarrect.x;
			progressbarrect.width =  endpos - progressbarrect.x;
		}
		twinfo.type = winfo.attributes & WTHEME_ATT_SBVERTICAL ? WTHEME_TYPE_PROGRESSBAR_CHUNK_VERTICAL:
		              WTHEME_TYPE_PROGRESSBAR_CHUNK;
		twinfo.state = pbpartdefaultstate;
		drawwidget(dc, twinfo, progressbarrect);
	}
	return True;
}




Boolean MCNativeTheme::drawslider(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	if (winfo.datatype != WTHEME_DATA_SCROLLBAR &&
	        winfo.type != WTHEME_TYPE_SMALLSCROLLBAR)
		return False;
	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;
	//draw arrows
	MCWidgetInfo twinfo = winfo;
	MCRectangle sbincarrowrect,sbdecarrowrect, sbthumbrect, sbinctrackrect, sbdectrackrect;
	getscrollbarrects(winfo, drect, sbincarrowrect, sbdecarrowrect, sbthumbrect,sbinctrackrect,sbdectrackrect);
	uint4 sbpartdefaultstate = winfo.state & WTHEME_STATE_DISABLED? WTHEME_STATE_DISABLED: WTHEME_STATE_CLEAR;
	memset(&twinfo,0,sizeof(MCWidgetInfo)); //clear widget info
	// The parts are drawn in the appearance of the slider's object
	twinfo.whichobject = winfo.whichobject;
	//draw upper and lower tracks first
	twinfo.type = winfo.attributes & WTHEME_ATT_SBVERTICAL ? WTHEME_TYPE_SLIDER_TRACK_VERTICAL: WTHEME_TYPE_SLIDER_TRACK_HORIZONTAL;
	twinfo.state = sbpartdefaultstate;
	if (winfo.part == WTHEME_PART_TRACK_DEC || winfo.part == WTHEME_PART_TRACK_INC)
		twinfo.state = winfo.state;
	MCRectangle trect;
	getwidgetrect(twinfo,WTHEME_METRIC_OPTIMUMSIZE,drect,trect);
	if (winfo.attributes & WTHEME_ATT_SBVERTICAL)
	{
		trect.height = drect.height;
		trect.x += (sbthumbrect.width - trect.width) >> 1;
	}
	else
	{
		trect.width = drect.width;
		trect.y += (sbthumbrect.height - trect.height) >> 1;
	}
	drawwidget(dc, twinfo, trect);
	twinfo.state = sbpartdefaultstate;
	twinfo.type = winfo.attributes & WTHEME_ATT_SBVERTICAL ? WTHEME_TYPE_SLIDER_THUMB_VERTICAL: WTHEME_TYPE_SLIDER_THUMB_HORIZONTAL;
	if (winfo.part == WTHEME_PART_THUMB)
		twinfo.state = winfo.state;
	drawwidget(dc, twinfo, sbthumbrect);

	return True;
}

Boolean MCNativeTheme::drawscrollcontrols(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	if (winfo.datatype != WTHEME_DATA_SCROLLBAR &&
	        winfo.type != WTHEME_TYPE_SMALLSCROLLBAR)
		return False;
	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;

	//draw arrows
	MCWidgetInfo twinfo = winfo;
	MCRectangle sbincarrowrect, sbdecarrowrect, sbthumbrect, sbinctrackrect, sbdectrackrect;
	getscrollbarrects(winfo, drect, sbincarrowrect, sbdecarrowrect, sbthumbrect,sbinctrackrect,sbdectrackrect);

	uint4 sbpartdefaultstate = winfo.state & WTHEME_STATE_DISABLED ? WTHEME_STATE_DISABLED: WTHEME_STATE_CLEAR;
	if ((winfo . state & WTHEME_STATE_CONTROL_HOVER) != 0 && MCmajorosversion >= MCOSVersionMake(6,0,0))
		sbpartdefaultstate |= WTHEME_STATE_CONTROL_HOVER;
	
	memset(&twinfo,0,sizeof(MCWidgetInfo)); //clear widget info
	// The parts are drawn in the appearance of the scrollbar's object
	twinfo.whichobject = winfo.whichobject;

	bool t_vertical;
	t_vertical = (winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0;

	if ((t_vertical && drect . width * 2 >= drect . height) || (!t_vertical && drect . height * 2 >= drect . width))
	{
		twinfo . type = WTHEME_TYPE_SPIN;
		twinfo . part = t_vertical ? WTHEME_PART_SPIN_ARROW_UP : WTHEME_PART_SPIN_ARROW_LEFT;
		twinfo . state = (winfo . part == WTHEME_PART_ARROW_DEC ? winfo . state : sbpartdefaultstate);
		drawwidget(dc, twinfo, sbincarrowrect);

		twinfo . type = WTHEME_TYPE_SPIN;
		twinfo . part = t_vertical ? WTHEME_PART_SPIN_ARROW_DOWN : WTHEME_PART_SPIN_ARROW_RIGHT;
		twinfo . state = (winfo . part == WTHEME_PART_ARROW_INC ? winfo . state : sbpartdefaultstate);
		drawwidget(dc, twinfo, sbdecarrowrect);
	}
	else
	{
		twinfo . type = t_vertical ? WTHEME_TYPE_SCROLLBAR_BUTTON_UP : WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT;
		twinfo . state = winfo . part == WTHEME_PART_ARROW_DEC ? winfo . state : sbpartdefaultstate;
		drawwidget(dc, twinfo, sbdecarrowrect);

		twinfo . type = t_vertical ? WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL : WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL;
		twinfo . part = WTHEME_PART_TRACK_DEC;
		twinfo . state = winfo . part == WTHEME_PART_TRACK_DEC ? winfo . state : sbpartdefaultstate;
		drawwidget(dc, twinfo, sbdectrackrect);

		if ((sbthumbrect . height != 0 && sbthumbrect . width != 0) || (winfo . state & WTHEME_STATE_DISABLED) == 0)
		{
			twinfo . type =  t_vertical ? WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL : WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL;
			twinfo . state = winfo . part == WTHEME_PART_THUMB ? winfo . state : sbpartdefaultstate;
			drawwidget(dc, twinfo, sbthumbrect);

			MCRectangle sbgripperrect;
			twinfo.type = t_vertical ? WTHEME_TYPE_SCROLLBAR_GRIPPER_VERTICAL : WTHEME_TYPE_SCROLLBAR_GRIPPER_HORIZONTAL;
			twinfo.state = sbpartdefaultstate;
			getwidgetrect(twinfo, WTHEME_METRIC_OPTIMUMSIZE, sbthumbrect, sbgripperrect);

			sbgripperrect . x += (sbthumbrect . width - sbgripperrect . width) / 2;
			sbgripperrect . y += (sbthumbrect . height - sbgripperrect . height) / 2;

			if (t_vertical && sbgripperrect . y > sbthumbrect . y || !t_vertical && sbgripperrect . x > sbthumbrect . x)
				drawwidget(dc, twinfo, sbgripperrect);
		}

		twinfo . type = t_vertical ? WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL : WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL;
		twinfo . part = WTHEME_PART_TRACK_INC;
		twinfo . state = winfo . part == WTHEME_PART_TRACK_INC ? winfo . state : sbpartdefaultstate;
		drawwidget(dc, twinfo, sbinctrackrect);

		twinfo . type = t_vertical ? WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN : WTHEME_TYPE_SCROLLBAR_BUTTON_RIGHT;
		twinfo . state = winfo . part == WTHEME_PART_ARROW_INC ? winfo . state : sbpartdefaultstate;
		drawwidget(dc, twinfo, sbincarrowrect);
	}

	return True;
}

// Draws one part of a scrollbar in dark mode when the dark scrollbar class
// is missing (see GetDarkScrollbarTheme). It is flat, like Tom Perry's dark
// buttons in drawwidget: a dark track, a lighter thumb that brightens under
// the mouse, and light grey arrow glyphs on the track colour. The thumb has
// no gripper.
Boolean MCNativeTheme::drawdarkscrollbarpart(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	bool t_disabled = (winfo.state & WTHEME_STATE_DISABLED) != 0;
	bool t_active = !t_disabled && (winfo.state & (WTHEME_STATE_HOVER | WTHEME_STATE_PRESSED)) != 0;

	MCColor t_track;
	t_track = MCDarkGrey(s_dark_scrollbar_track);

	dc->setfillstyle(FillSolid, nil, 0, 0);
	switch (winfo.type)
	{
	case WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL:
		dc->setforeground(t_track);
		dc->fillrect(drect);
		return True;

	case WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL:
		{
			// The track shows around the thumb, as in the native scrollbars
			dc->setforeground(t_track);
			dc->fillrect(drect);

			MCColor t_thumb;
			t_thumb = MCDarkGrey(t_active ? s_dark_scrollbar_thumb_active : s_dark_scrollbar_thumb);
			dc->setforeground(t_thumb);
			dc->fillrect(MCU_reduce_rect(drect, 2));
			return True;
		}

	case WTHEME_TYPE_SCROLLBAR_BUTTON_UP:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_RIGHT:
		{
			dc->setforeground(t_track);
			dc->fillrect(drect);

			// A triangle twice as wide as it is high, centred in the button
			MCDarkGlyph t_direction;
			switch (winfo.type)
			{
			case WTHEME_TYPE_SCROLLBAR_BUTTON_UP:
				t_direction = kMCDarkGlyphUp;
				break;
			case WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN:
				t_direction = kMCDarkGlyphDown;
				break;
			case WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT:
				t_direction = kMCDarkGlyphLeft;
				break;
			default:
				t_direction = kMCDarkGlyphRight;
				break;
			}
			MCDarkDrawGlyph(dc, drect, t_direction, (drect.width < drect.height ? drect.width : drect.height) / 4,
							MCDarkGrey(t_disabled ? s_dark_scrollbar_glyph_disabled : (t_active ? s_dark_scrollbar_glyph_active : s_dark_scrollbar_glyph)));
			return True;
		}

	default:
		// The gripper
		return True;
	}
}


void MCNativeTheme::getsliderrects(const MCWidgetInfo &winfo, const MCRectangle &srect,
                                   MCRectangle &sbincarrowrect,MCRectangle &sbdecarrowrect, MCRectangle &sbthumbrect,
                                   MCRectangle &sbinctrackrect,MCRectangle &sbdectrackrect)
{

	if (winfo.datatype != WTHEME_DATA_SCROLLBAR)
		return;

	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;
	MCWidgetInfo twinfo;
	memset(&twinfo,0,sizeof(MCWidgetInfo));
	
	bool t_vertical;
	t_vertical = (winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0;

	MCU_set_rect(sbdecarrowrect, 0, 0, 0, 0);

	twinfo . type = t_vertical ? WTHEME_TYPE_SLIDER_THUMB_VERTICAL : WTHEME_TYPE_SLIDER_THUMB_HORIZONTAL;
	getwidgetrect(twinfo, WTHEME_METRIC_OPTIMUMSIZE, srect, sbthumbrect);

	int4 t_track_size;
	t_track_size = t_vertical ? srect . height : srect . width;

	int4 t_thumb_size;
	t_thumb_size = t_vertical ? sbthumbrect . height : sbthumbrect . width;

	int4 t_thumb_offset;
	if (sbinfo -> endvalue - sbinfo -> startvalue != 0)
	{
		t_thumb_offset = t_thumb_size / 2 + (int4)floor((t_track_size - t_thumb_size) * (sbinfo -> thumbpos - sbinfo -> startvalue) / (sbinfo -> endvalue - sbinfo -> startvalue));

		if (t_vertical)
			MCU_set_rect(sbthumbrect, srect . x, srect . y + t_thumb_offset - sbthumbrect . height / 2, sbthumbrect . width, sbthumbrect . height);
		else
			MCU_set_rect(sbthumbrect, srect . x + t_thumb_offset - sbthumbrect . width / 2, srect . y, sbthumbrect . width, sbthumbrect . height);
	}
	else
	{
		t_thumb_offset = t_track_size;
		t_thumb_size = 0;
		MCU_set_rect(sbthumbrect, 0, 0, 0, 0);
	}

	if (t_vertical)
	{
		MCU_set_rect(sbdectrackrect, srect . x, srect . y, srect . width, t_thumb_offset - t_thumb_size / 2);
		MCU_set_rect(sbinctrackrect, srect . x, srect . y + t_thumb_offset - t_thumb_size / 2 + t_thumb_size, srect . width, t_track_size - (t_thumb_offset - t_thumb_size / 2 + t_thumb_size));
	}
	else
	{
		MCU_set_rect(sbdectrackrect, srect . x, srect . y, t_thumb_offset - t_thumb_size / 2, srect . height);
		MCU_set_rect(sbinctrackrect, srect . x + t_thumb_offset - t_thumb_size / 2 + t_thumb_size, srect . y, t_track_size - (t_thumb_offset - t_thumb_size / 2 + t_thumb_size), srect . height);
	}

	MCU_set_rect(sbincarrowrect, 0, 0, 0, 0);
}


void MCNativeTheme::getscrollbarrects(const MCWidgetInfo &winfo, const MCRectangle &srect,
                                      MCRectangle &sbincarrowrect,MCRectangle &sbdecarrowrect, MCRectangle &sbthumbrect,
                                      MCRectangle &sbinctrackrect,MCRectangle &sbdectrackrect)
{
	if (winfo.type == WTHEME_TYPE_SLIDER)
	{
		getsliderrects(winfo,srect,sbincarrowrect,sbdecarrowrect,sbthumbrect,sbinctrackrect,sbdectrackrect);
		return;
	}

	if (winfo.datatype != WTHEME_DATA_SCROLLBAR && winfo.type != WTHEME_TYPE_SMALLSCROLLBAR)
		return;

	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;

	if ((winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0 && srect . width * 2 >= srect . height)
	{
		MCU_set_rect(sbincarrowrect, srect . x, srect . y, srect . width, srect . height / 2);
		MCU_set_rect(sbdecarrowrect, srect . x, srect . y + srect . height / 2, srect . width, srect . height / 2);
		MCU_set_rect(sbthumbrect, 0, 0, 0, 0);
		MCU_set_rect(sbinctrackrect, 0, 0, 0, 0);
		MCU_set_rect(sbdectrackrect, 0, 0, 0, 0);
	}
	else if ((winfo . attributes & WTHEME_ATT_SBVERTICAL) == 0 && srect . height * 2 >= srect . width)
	{
		MCU_set_rect(sbincarrowrect, srect . x, srect . y, srect . width / 2, srect . height);
		MCU_set_rect(sbdecarrowrect, srect . x + srect . width / 2, srect . y, srect . width / 2, srect . height);
		MCU_set_rect(sbthumbrect, 0, 0, 0, 0);
		MCU_set_rect(sbinctrackrect, 0, 0, 0, 0);
		MCU_set_rect(sbdectrackrect, 0, 0, 0, 0);
	}
	else
	{
		int4 t_track_size;
		if ((winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0)
			t_track_size = srect . height - 2 * srect . width;
		else
			t_track_size = srect . width - 2 * srect . height;

		int4 t_thumb_size;
		int4 t_thumb_offset;
		if ((winfo.state & WTHEME_STATE_DISABLED) != 0 || (sbinfo -> endvalue - sbinfo -> startvalue) == 0)
		{
			t_thumb_offset = t_track_size;
			t_thumb_size = 0;
		}
		else
		{
			MCRectangle sbminthumbrect;
			MCWidgetInfo twinfo;
			twinfo.type = (winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0 ? WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL : WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL;
			twinfo.state = TS_NORMAL;
			getwidgetrect(twinfo, WTHEME_METRIC_OPTIMUMSIZE, srect, sbminthumbrect);

			int4 t_thumb_minimum_size;
			t_thumb_minimum_size = (winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0 ? sbminthumbrect . height : sbminthumbrect . width;

			t_thumb_size = (int4)ceil(t_track_size * sbinfo -> thumbsize / (sbinfo -> endvalue - sbinfo -> startvalue));
			if (t_thumb_size < t_thumb_minimum_size || !MCproportionalthumbs)
			{
				t_thumb_size = t_thumb_minimum_size;
				t_thumb_offset = (int4)floor((t_track_size - t_thumb_size) * (sbinfo -> thumbpos - sbinfo -> startvalue) / (sbinfo -> endvalue - sbinfo -> startvalue - (sbinfo -> endvalue > sbinfo -> startvalue ? sbinfo -> thumbsize : -sbinfo -> thumbsize)));
			}
			else
				t_thumb_offset = (int4)floor(t_track_size * (sbinfo -> thumbpos - sbinfo -> startvalue) / (sbinfo -> endvalue - sbinfo -> startvalue));


			if (t_thumb_size > t_track_size)
			{
				t_thumb_size = 0;
				t_thumb_offset = t_track_size;
			}
		}

		if ((winfo . attributes & WTHEME_ATT_SBVERTICAL) != 0)
		{
			MCU_set_rect(sbdecarrowrect, srect . x, srect . y, srect . width, srect . width);
			MCU_set_rect(sbincarrowrect, srect . x, srect . y + srect . height - srect . width, srect . width, srect . width);
			MCU_set_rect(sbdectrackrect, srect . x, srect . y + srect . width, srect . width, t_thumb_offset);
			MCU_set_rect(sbthumbrect, srect . x, srect . y + srect . width + t_thumb_offset, srect . width, t_thumb_size);
			MCU_set_rect(sbinctrackrect, srect . x, srect . y + srect . width + t_thumb_offset + t_thumb_size, srect . width, t_track_size - t_thumb_size - t_thumb_offset);
		}
		else
		{
			MCU_set_rect(sbdecarrowrect, srect . x, srect . y, srect . height, srect . height);
			MCU_set_rect(sbincarrowrect, srect . x + srect . width - srect . height, srect . y, srect . height, srect . height);
			MCU_set_rect(sbdectrackrect, srect . x + srect . height, srect . y, t_thumb_offset, srect . height);
			MCU_set_rect(sbthumbrect, srect . x + srect . height + t_thumb_offset, srect . y, t_thumb_size, srect . height);
			MCU_set_rect(sbinctrackrect, srect . x + srect . height + t_thumb_offset + t_thumb_size, srect . y, t_track_size - t_thumb_size - t_thumb_offset, srect . height);
		}
	}
}

Boolean MCNativeTheme::GetThemePartAndState(const MCWidgetInfo &winfo, int4& aPart, int4& aState)
{
	// MW-2006-04-21: [[ Purify ]] aPart, aState should be 0
	aPart = 0;
	aState = 0;
	switch (winfo.type)
	{
	case WTHEME_TYPE_PUSHBUTTON:
		aPart = BP_BUTTON;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{
			aState = TS_NORMAL;

			if (winfo.state & WTHEME_STATE_PRESSED &&
			        winfo.state & WTHEME_STATE_HOVER)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HASFOCUS)
				aState = TS_FOCUSED;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else
				aState = TS_NORMAL;
			if (aState == TS_NORMAL && winfo.state & WTHEME_STATE_HASDEFAULT)
				aState = TS_FOCUSED;
		}
		break;
	case WTHEME_TYPE_CHECKBOX:
	case WTHEME_TYPE_RADIOBUTTON:
		aPart = (winfo.type == WTHEME_TYPE_CHECKBOX) ? BP_CHECKBOX : BP_RADIO;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;

		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED &&
			        winfo.state & WTHEME_STATE_HOVER)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else
				aState = TS_NORMAL;
		}
		if (winfo.state & WTHEME_STATE_HILITED)
			aState += 4; // 4 unchecked states, 4 checked states.
		break;
	case WTHEME_TYPE_GROUP_FRAME:
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
		aPart = BP_GROUPBOX;
		aState = winfo.state & WTHEME_STATE_DISABLED? TS_DISABLED: TS_NORMAL;
		break;
	case WTHEME_TYPE_COMBOFRAME:
	case WTHEME_TYPE_COMBOTEXT:
	case WTHEME_TYPE_TEXTFIELD:
	case WTHEME_TYPE_TEXTFIELD_FRAME:
	case WTHEME_TYPE_TEXTFIELD_FILL:
		aPart = TFP_TEXTFIELD;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{

			if (winfo.state & WTHEME_STATE_READONLY)
				aState = TFS_READONLY;
			else
			{
				if (winfo.state & WTHEME_STATE_PRESSED &&
				        winfo.state & WTHEME_STATE_HOVER)
					aState = TS_ACTIVE;
				else if (winfo.state & WTHEME_STATE_HASFOCUS)
					aState = TS_FOCUSED;
				else if (winfo.state & WTHEME_STATE_HOVER)
					aState = TS_HOVER;
				else
					aState = TS_NORMAL;
			}
		}
		break;
	case WTHEME_TYPE_TOOLTIP:
		aPart = TTP_STANDARD;
		aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_PROGRESSBAR:
	case WTHEME_TYPE_PROGRESSBAR_HORIZONTAL:
		aPart = PP_BAR;
		aState = winfo.state & WTHEME_STATE_DISABLED? TS_DISABLED: TS_NORMAL;
		break;
	case WTHEME_TYPE_PROGRESSBAR_CHUNK:
		aPart = PP_CHUNK;
		aState = winfo.state & WTHEME_STATE_DISABLED? TS_DISABLED: TS_NORMAL;
		break;
	case WTHEME_TYPE_PROGRESSBAR_VERTICAL:
		aPart = PP_BARVERT;
		aState = winfo.state & WTHEME_STATE_DISABLED? TS_DISABLED: TS_NORMAL;
		break;
	case WTHEME_TYPE_PROGRESSBAR_CHUNK_VERTICAL:
		aPart = PP_CHUNKVERT;
		aState = winfo.state & WTHEME_STATE_DISABLED? TS_DISABLED: TS_NORMAL;
		break;
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_UP:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_DOWN:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_LEFT:
	case WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_RIGHT:
		if (winfo.type == WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_UP ||
		        winfo.type == WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_DOWN)
			aPart =   winfo.type == WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_UP? 1: 2;
		else
			aPart =  winfo.type == WTHEME_TYPE_SMALLSCROLLBAR_BUTTON_RIGHT? 3: 4;

		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED && winfo.state & WTHEME_STATE_HOVER)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else if (winfo.state & WTHEME_STATE_CONTROL_HOVER)
				aState = TS_CONTROL_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_SCROLLBAR_BUTTON_UP:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT:
	case WTHEME_TYPE_SCROLLBAR_BUTTON_RIGHT:
		aPart = SP_BUTTON;
		aState = (winfo.type - WTHEME_TYPE_SCROLLBAR_BUTTON_UP)*4;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState += TS_DISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED && winfo.state & WTHEME_STATE_HOVER)
				aState += TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState += TS_HOVER;
			else if (winfo.state & WTHEME_STATE_CONTROL_HOVER)
				aState = 17 + (winfo.type - WTHEME_TYPE_SCROLLBAR_BUTTON_UP);
			else
				aState += TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL:
	case WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL:
		if (winfo . type == WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL)
			aPart = winfo . part == WTHEME_PART_TRACK_DEC ? SP_TRACKSTARTHOR : SP_TRACKSTARTHOR;
		else
			aPart = winfo . part == WTHEME_PART_TRACK_INC ? SP_TRACKENDVERT : SP_TRACKENDVERT;

		if (winfo.state & WTHEME_STATE_DISABLED)
			aState += TS_DISABLED;
		else 	if (winfo.state & WTHEME_STATE_PRESSED && winfo.state & WTHEME_STATE_HOVER)
			aState = TS_ACTIVE;
		else
			aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL:
	case WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL:
		aPart = (winfo.type == WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL) ? SP_THUMBHOR : SP_THUMBVERT;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else if (winfo.state & WTHEME_STATE_CONTROL_HOVER)
				aState = TS_CONTROL_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_SCROLLBAR_GRIPPER_VERTICAL:
	case WTHEME_TYPE_SCROLLBAR_GRIPPER_HORIZONTAL:
		aPart = (winfo.type == WTHEME_TYPE_SCROLLBAR_GRIPPER_HORIZONTAL) ? SP_GRIPPERHOR : SP_GRIPPERVERT;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else if (winfo.state & WTHEME_STATE_CONTROL_HOVER)
				aState = TS_CONTROL_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_SLIDER_TRACK_HORIZONTAL:
	case WTHEME_TYPE_SLIDER_TRACK_VERTICAL:
		aPart = (winfo.type == WTHEME_TYPE_SLIDER_TRACK_HORIZONTAL)? SLIDERP_TRACKHOR : SLIDERP_TRACKVERT;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState += TS_DISABLED;
		else 	if (winfo.state & WTHEME_STATE_PRESSED && winfo.state & WTHEME_STATE_HOVER)
			aState = TS_ACTIVE;
		else
			aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_SLIDER_THUMB_HORIZONTAL:
	case WTHEME_TYPE_SLIDER_THUMB_VERTICAL:
		aPart = (winfo.type == WTHEME_TYPE_SLIDER_THUMB_HORIZONTAL)? SLIDERP_THUMBHOR : SLIDERP_THUMBVERT;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = SLIDERP_THUMBDISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_PRESSED)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;


	case WTHEME_TYPE_SMALLSCROLLBAR:
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SLIDER:
	case WTHEME_TYPE_COMBO:
	case WTHEME_TYPE_OPTIONBUTTON:
		aPart = aState = 0;
		break;
	case WTHEME_TYPE_TREEVIEW:
	case WTHEME_TYPE_LISTBOX:
		aPart = TREEVIEW_BODY;
		aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_TABPANE:
		aPart = TABP_PANEL;
		aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_TAB:
		aPart = TABP_TAB;
		if (winfo.state & WTHEME_STATE_DISABLED)
		{
			aState = TS_DISABLED;
			break;
		}
		if (winfo.state & WTHEME_STATE_HILITED)
		{
			aPart = TABP_TAB_SELECTED;
			aState = TS_ACTIVE;
		}
		else
		{
			if (winfo.state & WTHEME_STATE_HOVER && winfo.state & WTHEME_STATE_PRESSED)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HASFOCUS)
				aState = TS_FOCUSED;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_TREEVIEW_HEADER_SORTARROW:
		aPart = 4;
		aState = 1;
		break;
	case WTHEME_TYPE_COMBOBUTTON:
		aPart = CBP_DROPMARKER;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else
		{
			if (winfo.state & WTHEME_STATE_HOVER && winfo.state & WTHEME_STATE_PRESSED)
				aState = TS_ACTIVE;
			else if (winfo.state & WTHEME_STATE_HOVER)
				aState = TS_HOVER;
			else
				aState = TS_NORMAL;
		}
		break;
	case WTHEME_TYPE_OPTIONBUTTONTEXT:
		aPart = CBP_READONLY;
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else if (winfo.state & WTHEME_STATE_HOVER && winfo.state & WTHEME_STATE_PRESSED)
			aState = TS_ACTIVE;
		else if (winfo . state & WTHEME_STATE_HOVER)
			aState = TS_HOVER;
		else
			aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_OPTIONBUTTONARROW:
		aPart = CBP_DROPDOWNBUTTONRIGHT;
		aState = TS_NORMAL;
		break;
	case WTHEME_TYPE_SPIN:
		aPart = 1 + (winfo.part - WTHEME_PART_SPIN_ARROW_UP);
		if (winfo.state & WTHEME_STATE_DISABLED)
			aState = TS_DISABLED;
		else if (winfo.state & WTHEME_STATE_HOVER && winfo.state & WTHEME_STATE_PRESSED)
			aState = TS_ACTIVE;
		else if (winfo . state & WTHEME_STATE_HOVER)
			aState = TS_HOVER;
		else
			aState = TS_NORMAL;
		break;
	default:
		aPart = 0;
		aState = 0;
		return False;
	}
	return True;
}

////////////////////////////////////////////////////////////////////////////////

// MW-2011-09-14: [[ Bug 9719 ]] Override to return the actual sizeof(MCThemeDrawInfo).
uint32_t MCNativeTheme::getthemedrawinfosize(void)
{
	return sizeof(MCThemeDrawInfo);
}

int32_t MCNativeTheme::fetchtooltipstartingheight(void)
{
	if (MCmajorosversion < MCOSVersionMake(5,0,0))
		return 0;

	// MW-2012-09-19: [[ Bug ]] Adjustment to tooltip metrics for XP.
	if (MCmajorosversion < MCOSVersionMake(6,0,0))
		return 2;

	return 3;
}

bool MCNativeTheme::applythemetotooltipwindow(Window p_window, const MCRectangle& p_rect)
{
	if (MCmajorosversion < MCOSVersionMake(6,0,0))
		return false;

	// IM-2014-04-21: [[ Bug 12235 ]] Scale themed tooltip rect to screen coords
	MCRectangle t_screen_rect;
	t_screen_rect = MCscreen->logicaltoscreenrect(p_rect);

	RECT t_win_rect;
	SetRect(&t_win_rect, 0, 0, t_screen_rect . width, t_screen_rect . height);

	HDC t_dc;
	t_dc = GetDC(NULL);

	HRGN t_region;
	getThemeBackgroundRegion(mTooltipTheme, t_dc, TTP_STANDARD, TS_NORMAL, &t_win_rect, &t_region);

	ReleaseDC(NULL, t_dc);

	SetWindowRgn((HWND)p_window -> handle . window, t_region, TRUE);

	return true;
}

bool MCNativeTheme::drawtooltipbackground(MCContext *p_context, const MCRectangle& p_rect)
{
	if (MCmajorosversion < MCOSVersionMake(6,0,0))
		return false;

	MCWidgetInfo t_info;
	t_info . attributes = 0;
	t_info . data = NULL;
	t_info . datatype = WTHEME_DATA_NONE;
	t_info . part = WTHEME_PART_ALL;
	t_info . state = 0;
	t_info . type = WTHEME_TYPE_TOOLTIP;
	t_info . whichobject = 0;
	drawwidget(p_context, t_info, p_rect);

	
	return true;
}

bool MCNativeTheme::settooltiptextcolor(MCContext *p_context)
{
	if (MCmajorosversion < MCOSVersionMake(6,0,0))
		return false;

	MCColor t_color;
	t_color . red = 64;
	t_color . green = 64;
	t_color . blue = 64;
	p_context -> setforeground(t_color);

	return true;
}

bool MCNativeTheme::drawmenubackground(MCDC *dc, const MCRectangle& dirty, const MCRectangle& rect, bool p_gutter, MCObject *p_object)
{
	//-- tperry 8th November 2025: Draw dropdown menu with dark/light mode colors
	// (OXT-Beyond: in the appearance of the menu's card, which is that of the
	// menu's button, MCStack::createmenu)
	bool t_is_dark = objectisdark(p_object, dc);
	
	MCColor t_bg_color;
	MCColor t_border_color;
	
	if (t_is_dark)
	{
		// Dark mode: RGB(32,32,32) background
		t_bg_color.red = t_bg_color.green = t_bg_color.blue = 0x2020;
		// Slightly lighter border
		t_border_color.red = t_border_color.green = t_border_color.blue = 0x4040;
	}
	else
	{
		// Light mode: RGB(240,240,240) background
		t_bg_color.red = t_bg_color.green = t_bg_color.blue = 0xF0F0;
		// Slightly darker border
		t_border_color.red = t_border_color.green = t_border_color.blue = 0xC0C0;
	}
	
	// Draw border
	dc->setforeground(t_border_color);
	dc->setfillstyle(FillSolid, nil, 0, 0);
	dc->drawrect(rect);
	
	// Draw background
	MCRectangle t_inner_rect;
	MCU_set_rect(t_inner_rect, rect.x + 1, rect.y + 1, rect.width - 2, rect.height - 2);
	dc->setforeground(t_bg_color);
	dc->fillrect(t_inner_rect);
	
	return true;
}

bool MCNativeTheme::drawmenubarbackground(MCDC *dc, const MCRectangle& dirty, const MCRectangle& rect, bool is_active, MCObject *p_object)
{
	//-- tperry 8th November 2025: Draw menubar with dark/light mode colors
	// (OXT-Beyond: in the menubar group's appearance)
	bool t_is_dark = objectisdark(p_object, dc);
	
	// Set the background color based on dark/light mode
	MCColor t_bg_color;
	if (t_is_dark)
	{
		// Dark mode: RGB(32,32,32)
		t_bg_color.red = t_bg_color.green = t_bg_color.blue = 0x2020;
	}
	else
	{
		// Light mode: RGB(240,240,240)
		t_bg_color.red = t_bg_color.green = t_bg_color.blue = 0xF0F0;
	}
	
	// Fill the menubar background with the appropriate color
	dc->setforeground(t_bg_color);
	dc->setfillstyle(FillSolid, nil, 0, 0);
	dc->fillrect(rect);
	
	return true;
}

bool MCNativeTheme::drawmenuheaderbackground(MCContext *p_context, const MCRectangle& p_dirty, MCButton *p_button)
{
	//-- tperry 8th November 2025: Draw menubar items with system accent color for hover/pressed
	
	// Only draw background for hover or pressed states
	if (p_button -> getstate(CS_ARMED) || p_button -> gethovering())
	{
		// Use the system accent color (hilite color)
		p_context->setforeground(MChilitecolor);
		p_context->setfillstyle(FillSolid, nil, 0, 0);
		p_context->fillrect(p_button -> getrect());
	}
	
	return true;
}

bool MCNativeTheme::drawmenuitembackground(MCContext *p_context, const MCRectangle& p_dirty, MCButton *p_button)
{
	//-- tperry 21st January 2026: Draw menu items for pulldown menus (File, Edit, Tools) and cascading submenus
	//   This handles the background, checkmarks, and submenu arrows
	
	if (p_button -> getmenucontrol() == MENUCONTROL_ITEM)
	{
		MCRectangle t_rect = p_button -> getrect();
		
		// Draw background for hovered/armed state
		if (p_button -> getstate(CS_ARMED))
		{
			// Use system accent color for hover
			p_context->setforeground(MChilitecolor);
			p_context->setfillstyle(FillSolid, nil, 0, 0);
			p_context->fillrect(t_rect);
		}
		
		// Draw checkmark if menu item is hilited (checked)
		if (p_button -> getstate(CS_HILITED))
		{
			bool t_is_dark = objectisdark(p_button, p_context);
			
			// Set checkmark color based on dark mode
			if (t_is_dark)
				p_context->setforeground(p_context->getwhite());
			else
				p_context->setforeground(p_context->getblack());
			
			// Draw checkmark polygon (✓)
			MCPoint p[6];
			int2 check_x = t_rect.x + 4;
			int2 check_y = t_rect.y + (t_rect.height >> 1) - 3;
			p[0].x = p[5].x = check_x;
			p[1].x = p[4].x = check_x + 2;
			p[2].x = p[3].x = check_x + 7;
			p[0].y = check_y + 3;
			p[1].y = check_y + 5;
			p[2].y = check_y;
			p[3].y = check_y + 3;
			p[4].y = check_y + 8;
			p[5].y = check_y + 6;
			
			p_context->setfillstyle(FillSolid, nil, 0, 0);
			p_context->fillpolygon(p, 6);
		}
		
		// Draw cascade arrow if menu item has submenu
		if (p_button -> getmenumode() == WM_CASCADE)
		{
			bool t_is_dark = objectisdark(p_button, p_context);
			
			// Set arrow color based on dark mode
			if (t_is_dark)
				p_context->setforeground(p_context->getwhite());
			else
				p_context->setforeground(p_context->getblack());
			
			// Draw cascade arrow (>)
			MCPoint arrow[3];
			arrow[0].x = t_rect.x + t_rect.width - 9;
			arrow[1].x = arrow[2].x = arrow[0].x - 4;
			arrow[0].y = t_rect.y + (t_rect.height >> 1);
			arrow[1].y = arrow[0].y + 4;
			arrow[2].y = arrow[0].y - 4;
			
			p_context->fillpolygon(arrow, 3);
		}
		
		return true; // We handled the drawing
	}
	else
	{
		// Draw separator line
		bool t_is_dark = objectisdark(p_button, p_context);
		
		MCColor t_sep_color;
		if (t_is_dark)
		{
			t_sep_color.red = t_sep_color.green = t_sep_color.blue = 0x4040;
		}
		else
		{
			t_sep_color.red = t_sep_color.green = t_sep_color.blue = 0xC0C0;
		}
		
		MCRectangle t_rect = p_button -> getrect();
		p_context->setforeground(t_sep_color);
		p_context->setfillstyle(FillSolid, nil, 0, 0);
		MCRectangle t_line;
		MCU_set_rect(t_line, t_rect.x + 2, t_rect.y + t_rect.height / 2, t_rect.width - 4, 1);
		p_context->fillrect(t_line);
		return true;
	}
}

////////////////////////////////////////////////////////////////////////////////

MCTheme *MCThemeCreateNative(void)
{
	return new MCNativeTheme;
}

////////////////////////////////////////////////////////////////////////////////

typedef void (*MCGDIDrawFunc)(HDC p_hdc, void *p_context);
bool MCGDIDrawAlpha(uint32_t p_width, uint32_t p_height, MCGDIDrawFunc p_draw, void *p_context, MCImageBitmap *&r_bitmap);
void MCGDIDrawTheme(HDC p_dc, void *p_context);

typedef struct
{
	MCThemeDrawType type;
	MCThemeDrawInfo *info;
	MCPoint origin;
} MCGDIThemeDrawContext;

bool MCWin32ThemeDrawBuffered(MCGContextRef p_context, MCThemeDrawType p_type, MCThemeDrawInfo *p_info_ptr)
{
	bool t_success = true;

	int32_t t_x, t_y;
	uint32_t t_width, t_height;

	MCGDIThemeDrawContext t_context;
	t_context.type = p_type;
	t_context.info = p_info_ptr;

	t_x = p_info_ptr->bounds.x;
	t_y = p_info_ptr->bounds.y;
	t_width = p_info_ptr->bounds.width;
	t_height = p_info_ptr->bounds.height;

	HDC t_dc = ((MCScreenDC*)MCscreen)->getdsthdc();
	t_success = t_dc != nil;

	HDC t_paintdc = nil;
	HPAINTBUFFER t_buffer = nil;
	RECT t_target_rect;

	if (t_success)
	{
		SetRect(&t_target_rect, 0, 0, p_info_ptr->bounds.width, p_info_ptr->bounds.height);
		t_buffer = beginBufferedPaint(t_dc, &t_target_rect, BPBF_TOPDOWNDIB, NULL, &t_paintdc);
		t_success = t_buffer != nil;
	}

	RGBQUAD *t_bits = nil;
	int t_row_width = 0;
	if (t_success)
		t_success = S_OK == bufferedPaintClear(t_buffer, NULL);

	if (t_success)
	{
		MCGDIDrawTheme(t_paintdc, &t_context);
		t_success = S_OK == getBufferedPaintBits(t_buffer, &t_bits, &t_row_width);
	}

	if (t_success)
	{
		MCGRaster t_raster;
		t_raster.width = t_width;
		t_raster.height = t_height;
		t_raster.stride = t_row_width * sizeof(uint32_t);
		t_raster.pixels = t_bits;
		t_raster.format = kMCGRasterFormat_ARGB;

		MCGRectangle t_dst = MCGRectangleMake(t_x, t_y, t_width, t_height);
		
		// MM-2013-12-16: [[ Bug 11567 ]] Use bilinear filter when drawing theme elements.
        // MM-2014-01-27: [[ UpdateImageFilters ]] Updated to use new libgraphics image filter types (was bilinear).
		MCGContextDrawPixels(p_context, t_raster, t_dst, kMCGImageFilterMedium);
	}

	if (t_buffer != nil)
		endBufferedPaint(t_buffer, FALSE);

	return t_success;
}

bool MCThemeDraw(MCGContextRef p_context, MCThemeDrawType p_type, MCThemeDrawInfo *p_info_ptr)
{
	bool t_success = true;

	/* OVERHAUL - REVISIT: This does not seem to fix the issue of alpha-transparency with windows GDI calls, disabling for now */
	//if (beginBufferedPaint != nil)
	//	return MCWin32ThemeDrawBuffered(p_context, p_type, p_info_ptr);

	MCImageBitmap *t_bitmap = nil;
	int32_t t_x, t_y;
	uint32_t t_width, t_height;

	MCGRectangle t_dst;

	MCRectangle t_old_bounds, t_old_interior, t_old_clip;
	t_old_bounds = p_info_ptr->bounds;
	t_old_clip = p_info_ptr->clip;
	t_old_interior = p_info_ptr->interior;

	MCGAffineTransform t_transform;
	t_transform = MCGContextGetDeviceTransform(p_context);

	// IM-2013-12-13: [[ HiDPI ]] Improve scaled UI appearance by rendering at transformed size.
	if (MCGAffineTransformIsRectangular(t_transform))
	{
		// render theme elements at scaled size

		MCGRectangle t_scaled_bounds;
		t_scaled_bounds = MCGRectangleApplyAffineTransform(MCRectangleToMCGRectangle(p_info_ptr->bounds), t_transform);

		MCGRectangle t_scaled_interior;
		t_scaled_interior = MCGRectangleApplyAffineTransform(MCRectangleToMCGRectangle(p_info_ptr->interior), t_transform);

		MCGRectangle t_scaled_clip;
		t_scaled_clip = MCGRectangleApplyAffineTransform(MCRectangleToMCGRectangle(p_info_ptr->clip), t_transform);

		MCRectangle t_int_bounds;
		t_int_bounds = MCGRectangleGetIntegerInterior(t_scaled_bounds);

		MCRectangle t_int_interior;
		t_int_interior = MCGRectangleGetIntegerBounds(t_scaled_interior);

		MCRectangle t_int_clip;
		t_int_clip = MCGRectangleGetIntegerBounds(t_scaled_clip);
		t_int_clip = MCU_intersect_rect(t_int_clip, t_int_bounds);


		t_width = t_int_clip.width;
		t_height = t_int_clip.height;

		p_info_ptr->bounds = t_int_bounds;
		p_info_ptr->interior = t_int_interior;
		p_info_ptr->clip = t_int_clip;

		t_x = t_int_clip.x;
		t_y = t_int_clip.y;

		t_dst = MCGRectangleApplyAffineTransform(MCRectangleToMCGRectangle(t_int_clip), MCGAffineTransformInvert(t_transform));
	}
	else
	{
		// render at normalsize & draw into target rect
	t_x = p_info_ptr->bounds.x;
	t_y = p_info_ptr->bounds.y;

	t_width = p_info_ptr->bounds.width;
	t_height = p_info_ptr->bounds.height;

		t_dst = MCGRectangleMake(t_x, t_y, t_width, t_height);
	}

	MCGDIThemeDrawContext t_context;
	t_context.type = p_type;
	t_context.info = p_info_ptr;
	t_context.origin = MCPointMake(t_x, t_y);


	// render theme to bitmap
	t_success = MCGDIDrawAlpha(t_width, t_height, MCGDIDrawTheme, &t_context, t_bitmap);
	if (t_success)
	{
		MCGRaster t_raster;
		t_raster = MCImageBitmapGetMCGRaster(t_bitmap, true);
		t_raster.format = kMCGRasterFormat_ARGB;

		
		// MM-2013-12-16: [[ Bug 11567 ]] Use bilinear filter when drawing theme elements.
        // MM-2014-01-27: [[ UpdateImageFilters ]] Updated to use new libgraphics image filter types (was bilinear).
		MCGContextDrawPixels(p_context, t_raster, t_dst, kMCGImageFilterMedium);
	}

	p_info_ptr->bounds = t_old_bounds;
	p_info_ptr->interior = t_old_interior;
	p_info_ptr->clip = t_old_clip;

	MCImageFreeBitmap(t_bitmap);

	return t_success;
}

void MCGDIDrawTheme(HDC p_dc, void *p_context)
{
	MCGDIThemeDrawContext *t_context = (MCGDIThemeDrawContext*)p_context;

	MCThemeDrawInfo& p_info = *t_context->info;

	HRGN t_clip_region = NULL;

	// IM-2013-12-13: [[ HiDPI ]] Use context origin to offset drawing rects
	int32_t t_xoff, t_yoff;
	t_xoff = t_context->origin.x;
	t_yoff = t_context->origin.y;

	MCRectangle t_bounds, t_interior, t_clip;
	t_bounds = MCU_offset_rect(p_info.bounds, -t_xoff, -t_yoff);
	t_interior = MCU_offset_rect(p_info.interior, -t_xoff, -t_yoff);
	t_clip = MCU_offset_rect(p_info.clip, -t_xoff, -t_yoff);

	if (p_info . clip_interior)
	{
		HRGN t_outside_region;
		t_outside_region = CreateRectRgn(t_bounds.x, t_bounds.y, t_bounds.x + t_bounds.width, t_bounds.y + t_bounds.height);

		HRGN t_inside_region;
		t_inside_region = CreateRectRgn(t_interior.x, t_interior.y, t_interior.x + t_interior.width, t_interior.y + t_interior.height);

		CombineRgn(t_inside_region, t_outside_region, t_inside_region, RGN_DIFF);
		DeleteObject(t_outside_region);

		t_clip_region = t_inside_region;
	}

	SaveDC(p_dc);

	if (t_clip_region != NULL)
		SelectClipRgn(p_dc, t_clip_region);

	RECT t_widget_rect;
	RECT t_clip_rect;
	SetRect(&t_widget_rect, t_bounds.x, t_bounds.y, t_bounds.x + t_bounds.width, t_bounds.y + t_bounds.height);
	SetRect(&t_clip_rect, t_clip.x, t_clip.y, t_clip.x + t_clip.width, t_clip.y + t_clip.height);
	drawThemeBG(p_info . theme, p_dc, p_info . part, p_info . state, &t_widget_rect, &t_clip_rect);

	RestoreDC(p_dc, -1);

	if (t_clip_region != NULL)
		DeleteObject(t_clip_region);
}

// Whether a theme part comes out dark: it is drawn into a small bitmap the
// way MCThemeDraw draws it, and the mean luminance of the result over black
// must be below half. A part that draws nothing counts as dark, which is
// what matters here: the dark background shows through it. Used to tell the
// dark scrollbar class from the light one it falls back to (see
// MCNativeTheme::GetDarkScrollbarTheme).
static bool MCWin32ThemePartDrawsDark(MCWinSysHandle p_theme, int4 p_part, int4 p_state)
{
	const uint2 t_width = 16;
	const uint2 t_height = 32;

	MCThemeDrawInfo t_info;
	t_info . theme = p_theme;
	t_info . part = p_part;
	t_info . state = p_state;
	MCU_set_rect(t_info . bounds, 0, 0, t_width, t_height);
	t_info . clip = t_info . bounds;
	t_info . clip_interior = false;
	t_info . interior = t_info . bounds;

	MCGDIThemeDrawContext t_context;
	t_context . type = THEME_DRAW_TYPE_BACKGROUND;
	t_context . info = &t_info;
	t_context . origin = MCPointMake(0, 0);

	MCImageBitmap *t_bitmap = nil;
	if (!MCGDIDrawAlpha(t_width, t_height, MCGDIDrawTheme, &t_context, t_bitmap))
		return false;

	// MCGDIDrawAlpha keeps the colour drawn over black in the low 24 bits
	uint64_t t_sum = 0;
	for (uint32_t y = 0; y < t_bitmap -> height; y++)
	{
		const uint32_t *t_row = (const uint32_t *)((const uint8_t *)t_bitmap -> data + y * t_bitmap -> stride);
		for (uint32_t x = 0; x < t_bitmap -> width; x++)
			t_sum += 299 * ((t_row[x] >> 16) & 0xFF) + 587 * ((t_row[x] >> 8) & 0xFF) + 114 * (t_row[x] & 0xFF);
	}
	uint64_t t_pixels = uint64_t(t_bitmap -> width) * t_bitmap -> height;
	MCImageFreeBitmap(t_bitmap);

	return t_pixels != 0 && t_sum / (1000 * t_pixels) < 128;
}

////////////////////////////////////////////////////////////////////////////////
