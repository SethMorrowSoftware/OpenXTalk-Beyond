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

#include "parsedef.h"
#include "objdefs.h"
#include "font.h"
#include "platform.h"
#include "mctheme.h"
#include "context.h"
#include "uidc.h"
#include "globals.h"

/* OXT-Beyond: the web has no native theme, so the engine draws every
 * control itself. It draws them in the look of the desktop engines' themes
 * on Windows and Linux, "Windows 95", which is what those engines draw a
 * control in when the system draws no part of it (as a Linux engine does
 * with -ui): this theme loads nothing, and the engine falls back to the
 * look of its family (X_open in globals.cpp), as when the Windows theme
 * fails to load. Before, it kept the look compiled in as the default,
 * Motif, which the web is the only place to show: the troughs of
 * scrollbars, sliders and progress bars were black, and fields grey.
 * "set the lookAndFeel to Motif" still gives that look. */
class MCWebTheme : public MCTheme
{
public:
	virtual Boolean load()
	{
		return False;
	}

	virtual uint2 getthemeid()
	{
		return LF_WIN95;
	}

	virtual uint2 getthemefamilyid()
	{
		return LF_WIN95;
	}
};

MCTheme *
MCThemeCreateNative()
{
	return new (nothrow) MCWebTheme;
}

/* There is no native theme, so the engine draws its controls itself;
 * as on the server, drawing a native part fails. */
bool
MCThemeDraw(MCGContextRef p_context,
            MCThemeDrawType p_type,
            MCThemeDrawInfo *p_info)
{
	return false;
}


/* ================================================================
 * Platform theming
 * ================================================================ */

/* OXT-Beyond: the colours a control has when it sets none, as the
 * desktop engines take them from the system: here those of Windows 10's
 * light theme, which the Windows engine reads (windows-theme.cpp), so that
 * a stack looks on the web as it does there. As there, a control's border
 * stays black (on the Mac too). The shadow colour, which the Windows
 * engine leaves black, is the grey of a control's lower edge, as the
 * shadow is on the Mac and Linux: the engine draws the troughs of
 * scrollbars, sliders and progress bars with it, which the system draws on
 * the desktop. Before, there were no colours, so the engine's own defaults
 * were used: a stack's background was mid grey (#C0C0C0), the selection
 * navy, and every shadow black. */

static bool
em_theme_color(uint32_t p_rgb, MCColor& r_color)
{
	r_color.red = ((p_rgb >> 16) & 0xFF) * 257;
	r_color.green = ((p_rgb >> 8) & 0xFF) * 257;
	r_color.blue = (p_rgb & 0xFF) * 257;
	return true;
}

/* Windows 10's GetSysColor() for the colours that windows-theme.cpp reads */
#define kMCWebThemeWindowText       0x000000 /* COLOR_WINDOWTEXT, _BTNTEXT, _MENUTEXT */
#define kMCWebThemeGrayText         0x6D6D6D /* COLOR_GRAYTEXT */
#define kMCWebThemeHighlightText    0xFFFFFF /* COLOR_HIGHLIGHTTEXT */
#define kMCWebThemeHighlight        0x0078D7 /* COLOR_HIGHLIGHT */
#define kMCWebThemeMenuHighlight    0x3399FF /* COLOR_MENUHILIGHT */
#define kMCWebThemeFace             0xF0F0F0 /* COLOR_BTNFACE, COLOR_MENU */
#define kMCWebThemeWindow           0xFFFFFF /* COLOR_WINDOW */
#define kMCWebThemeHilightEdge      0xFFFFFF /* COLOR_3DHILIGHT */
#define kMCWebThemeShadowEdge       0xA0A0A0 /* COLOR_3DSHADOW */

/* OXT-Beyond: in the dark appearance (a page that follows the browser's
 * colour scheme: MCScreenDC::getsystemappearance in em-dc.cpp), the colours
 * that the Windows engine gives a control in Windows' dark mode
 * (windows-theme.cpp): white text, and RGB(32,32,32) behind controls,
 * fields and windows. The others stay as in the light appearance, as
 * there. */
#define kMCWebThemeDarkText         0xFFFFFF
#define kMCWebThemeDarkFace         0x202020

/* OXT-Beyond: and the light edge of a 3-D border, a little lighter than
 * the dark face: white there drew a bright line around every field, scroll
 * bar and arrow box, and a disabled label's white emboss under its grey
 * text read as a second, brighter copy of the label (the web IDE's toolbar
 * and Preferences in a dark browser) */
#define kMCWebThemeDarkHilightEdge  0x3A3A3A

static bool
em_theme_is_dark(void)
{
	MCSystemAppearance t_appearance;
	MCscreen->getsystemappearance(t_appearance);
	return t_appearance == kMCSystemAppearanceDark;
}

bool
MCPlatformGetControlThemePropColor(MCPlatformControlType p_type,
                                   MCPlatformControlPart p_part,
                                   MCPlatformControlState p_state,
                                   MCPlatformThemeProperty p_prop,
                                   MCColor& r_color)
{
	bool t_dark = em_theme_is_dark();

	switch (p_prop)
	{
	case kMCPlatformThemePropertyTextColor:
		if (p_state & kMCPlatformControlStateDisabled)
			return em_theme_color(kMCWebThemeGrayText, r_color);
		if (p_state & kMCPlatformControlStateSelected)
			return em_theme_color(kMCWebThemeHighlightText, r_color);
		return em_theme_color(t_dark ? kMCWebThemeDarkText : kMCWebThemeWindowText, r_color);

	case kMCPlatformThemePropertyBackgroundColor:
		if (p_state & kMCPlatformControlStateSelected)
		{
			switch (p_type)
			{
			case kMCPlatformControlTypeMenu:
			case kMCPlatformControlTypeMenuItem:
			case kMCPlatformControlTypeOptionMenu:
			case kMCPlatformControlTypePulldownMenu:
			case kMCPlatformControlTypeComboBox:
				return em_theme_color(kMCWebThemeMenuHighlight, r_color);
			default:
				return em_theme_color(kMCWebThemeHighlight, r_color);
			}
		}
		switch (p_type)
		{
		case kMCPlatformControlTypeInputField:
		case kMCPlatformControlTypeList:
		case kMCPlatformControlTypeComboBox:
		case kMCPlatformControlTypeOptionMenu:
		case kMCPlatformControlTypePulldownMenu:
		case kMCPlatformControlTypePopupMenu:
			return em_theme_color(t_dark ? kMCWebThemeDarkFace : kMCWebThemeWindow, r_color);
		default:
			return em_theme_color(t_dark ? kMCWebThemeDarkFace : kMCWebThemeFace, r_color);
		}

	case kMCPlatformThemePropertyShadowColor:
		return em_theme_color(kMCWebThemeShadowEdge, r_color);

	case kMCPlatformThemePropertyTopEdgeColor:
	case kMCPlatformThemePropertyLeftEdgeColor:
		return em_theme_color(t_dark ? kMCWebThemeDarkHilightEdge : kMCWebThemeHilightEdge, r_color);

	case kMCPlatformThemePropertyBottomEdgeColor:
	case kMCPlatformThemePropertyRightEdgeColor:
		return em_theme_color(kMCWebThemeShadowEdge, r_color);

	default:
		/* the border and the focus ring, which the Windows engine leaves
		 * to the engine's defaults too */
		return false;
	}
}

bool
MCPlatformGetControlThemePropFont(MCPlatformControlType p_type,
                                  MCPlatformControlPart p_part,
                                  MCPlatformControlState p_state,
                                  MCPlatformThemeProperty p_prop,
                                  MCFontRef& r_font)
{
	/* For now, ask for the compiled-in default font name and size*/
	return MCFontCreate(MCNAME(DEFAULT_TEXT_FONT), 0,
	                    DEFAULT_TEXT_SIZE, r_font);
}
