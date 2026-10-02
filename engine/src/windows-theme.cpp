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


#include "prefix.h"
#include "platform.h"

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "filedefs.h"
#include "mcstring.h"
#include "globals.h"
#include "mctheme.h"
#include "util.h"
#include "object.h"
#include "stack.h"
#include "font.h"

#ifndef _SERVER
#include "w32dc.h"
#endif

static bool logfont_for_control(MCPlatformControlType p_type, LOGFONTW& r_lf)
{
#ifndef _SERVER
    // OXT-Beyond: in no-UI mode (-ui) MCscreen is a plain MCUIDC (X_open),
    // not an MCScreenDC, so there are no non-client metrics to read: the
    // cast read past the end of the object, and crashed the 32-bit engine
    // when that was the end of the heap's memory. The callers then use the
    // default UI font and size.
    if (MCnoui)
        return false;

    // Get the font used for the non-client areas of Windows. This font
    // gets used throughout the Windows UI.
    const NONCLIENTMETRICSW& t_ncm = ((MCScreenDC *)MCscreen)->getnonclientmetrics();
    if (t_ncm.cbSize != 0)
    {
        // Which LOGFONT structure contains the info for this control?
        const LOGFONTW* lf = NULL;
        switch (p_type)
        {
            case kMCPlatformControlTypeTooltip:
                lf = &t_ncm.lfStatusFont;
                break;
                
            case kMCPlatformControlTypeMenu:
            case kMCPlatformControlTypeMenuItem:
            case kMCPlatformControlTypeOptionMenu:
            case kMCPlatformControlTypePulldownMenu:
            case kMCPlatformControlTypePopupMenu:
                lf = &t_ncm.lfMenuFont;
                break;
                
            default:
                lf = &t_ncm.lfMessageFont;
                break;
        }
        
        if (lf != NULL)
        {
            // Return the LOGFONT structure
            memcpy(&r_lf, lf, sizeof(LOGFONTW));
            return true;
        }
    }
    
    return false;
#else
	return false;
#endif
}

bool MCPlatformGetControlThemePropBool(MCPlatformControlType, MCPlatformControlPart, MCPlatformControlState, MCPlatformThemeProperty, bool&)
{
    return false;
}

// Density used by default for the Win32 UI
#define NORMAL_DENSITY  96

bool MCPlatformGetControlThemePropInteger(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_prop, int& r_int)
{
    bool t_found;
    t_found = false;
    
    switch (p_prop)
    {
        case kMCPlatformThemePropertyTextSize:
        {
            // Find the LOGFONT structure for the requested control type
            t_found = true;
            LOGFONTW lf;
            if (!(p_state & kMCPlatformControlStateCompatibility) && logfont_for_control(p_type, lf))
            {
                // Scale compared to the "normal" windows scale
				uint32_t t_x_dpi, t_y_dpi;

#ifndef _SERVER
				t_x_dpi = ((MCScreenDC *)MCscreen)->getscreenxdpi();
				t_y_dpi = ((MCScreenDC *)MCscreen)->getscreenydpi();
#else
				t_x_dpi = t_y_dpi = NORMAL_DENSITY;
#endif

				// Get the size from the LOGFONT structure
                r_int = MCGFloat(-lf.lfHeight) / (MCGFloat(MCMax(t_x_dpi, t_y_dpi)) / NORMAL_DENSITY);
            }
            else
            {
                // The default text size depends on the Windows version
                r_int = MCmajorosversion >= MCOSVersionMake(6,0,0) ? 12 : 11;
            }
            break;
        }
    }
    
    return t_found;
}

bool MCPlatformGetControlThemePropColor(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_prop, MCColor& r_color)
{
    bool t_found;
    t_found = false;
    
    int t_color;
    
    //-- tperry 8th November 2025: Check if we're in dark mode
    // (OXT-Beyond: the appearance of the object whose colour this is, which
    // MCObject::getcontrolstate puts in the state; a light object in a dark
    // stack gets the light colours)
    bool t_is_dark = (p_state & kMCPlatformControlStateDarkAppearance) != 0;
    
    switch (p_prop)
    {
        case kMCPlatformThemePropertyTextColor:
        {
            t_found = true;
            if (p_state & kMCPlatformControlStateDisabled)
            {
                // COLOR_GRAYTEXT (109) is 3.15:1 on the dark background; the
                // dark disabled grey 137 is 4.7:1
                if (t_is_dark)
                {
                    r_color.red = r_color.green = r_color.blue = 0x8989;
                    return true;
                }
                t_color = COLOR_GRAYTEXT;
            }
            else if (p_state & kMCPlatformControlStateSelected)
            {
                t_color = COLOR_HIGHLIGHTTEXT;
            }
            else
            {
                switch (p_type)
                {
                    case kMCPlatformControlTypeMenu:
                    case kMCPlatformControlTypeMenuItem:
                    case kMCPlatformControlTypeOptionMenu:
                    case kMCPlatformControlTypePulldownMenu:
                    case kMCPlatformControlTypePopupMenu:
                    case kMCPlatformControlTypeComboBox:
                        //-- tperry 8th November 2025: White text for menus in dark mode
                        if (t_is_dark)
                        {
                            r_color.red = r_color.green = r_color.blue = 0xFFFF;
                            return true;
                        }
                        t_color = COLOR_MENUTEXT;
                        break;
                        
                    case kMCPlatformControlTypeButton:
                        //-- tperry 11th November 2025: White text for buttons in dark mode
                        if (t_is_dark)
                        {
                            r_color.red = r_color.green = r_color.blue = 0xFFFF;
                            return true;
                        }
                        t_color = COLOR_BTNTEXT;
                        break;
                        
                    default:
                        //-- tperry 8th November 2025: Return white text in dark mode
                        if (t_is_dark)
                        {
                            // Dark mode: white text
                            r_color.red = r_color.green = r_color.blue = 0xFFFF;
                            return true;
                        }
                        t_color = COLOR_WINDOWTEXT;
                        break;
                }
            }
            
            break;
        }
            
        case kMCPlatformThemePropertyBackgroundColor:
        {
            t_found = true;
            if (p_state & kMCPlatformControlStateSelected)
            {
                switch (p_type)
                {
                    case kMCPlatformControlTypeMenu:
                    case kMCPlatformControlTypeMenuItem:
                    case kMCPlatformControlTypeOptionMenu:
                    case kMCPlatformControlTypePulldownMenu:
                    case kMCPlatformControlTypeComboBox:
                        t_color = COLOR_MENUHILIGHT;
                        break;
                        
                    default:
                        t_color = COLOR_HIGHLIGHT;
                        break;
                }
            }
            else
            {
                switch (p_type)
                {
                    case kMCPlatformControlTypeInputField:
                    case kMCPlatformControlTypeList:
                    case kMCPlatformControlTypeComboBox:
                    case kMCPlatformControlTypeOptionMenu:
                    case kMCPlatformControlTypePulldownMenu:
                    case kMCPlatformControlTypePopupMenu:
                        //-- tperry 8th November 2025: Respect dark mode for opaque fields and menus
                        if (t_is_dark)
                        {
                            // Dark mode: dark background for opaque fields
                            r_color.red = r_color.green = r_color.blue = 0x2020;
                            return true;
                        }
                        else
                        {
                            // Light mode: white background
                            r_color.red = r_color.green = r_color.blue = 65535;
                            return true;
                        }
                        
                    case kMCPlatformControlTypeMenuItem:
                        // COLOR_MENU is light in both modes
                        if (t_is_dark)
                        {
                            r_color.red = r_color.green = r_color.blue = 0x2020;
                            return true;
                        }
                        t_color = COLOR_MENU;
                        break;
                        
                    case kMCPlatformControlTypeButton:
                        //-- tperry 11th November 2025: Button background for dark mode
                        if (t_is_dark)
                        {
                            // Dark mode: RGB(32,32,32)
                            r_color.red = r_color.green = r_color.blue = 0x2020;
                            return true;
                        }
                        else
                        {
                            // Light mode: RGB(240,240,240)
                            r_color.red = r_color.green = r_color.blue = 0xF0F0;
                            return true;
                        }
                        
                    case kMCPlatformControlTypeWindow:
                        // Use the control colour instead of the window colour
                        //t_color = COLOR_WINDOW;
                        //break;
                        
                    default:
                        //-- tperry 8th November 2025: Return dark/light mode colors
                        if (t_is_dark)
                        {
                            // Dark mode: RGB(32,32,32)
                            r_color.red = r_color.green = r_color.blue = 0x2020;
                            return true;
                        }
                        else
                        {
                            // Light mode: RGB(240,240,240)
                            r_color.red = r_color.green = r_color.blue = 0xF0F0;
                            return true;
                        }
                        break;
                }
            }
            
            break;
        }
            
        case kMCPlatformThemePropertyShadowColor:
            break;
            
        case kMCPlatformThemePropertyBorderColor:
            break;
            
        case kMCPlatformThemePropertyFocusColor:
            break;
            
        case kMCPlatformThemePropertyTopEdgeColor:
        case kMCPlatformThemePropertyLeftEdgeColor:
            t_found = true;
            // The 3D system colours are light in both modes: on the dark
            // background the white highlight is the brightest thing in a
            // control. The dark edges keep the raised and sunken look.
            if (t_is_dark)
            {
                r_color.red = r_color.green = r_color.blue = 0x5050;
                return true;
            }
            t_color = COLOR_3DHILIGHT;
            break;
            
        case kMCPlatformThemePropertyBottomEdgeColor:
        case kMCPlatformThemePropertyRightEdgeColor:
            t_found = true;
            if (t_is_dark)
            {
                r_color.red = r_color.green = r_color.blue = 0x1010;
                return true;
            }
            t_color = COLOR_3DSHADOW;
            break;
    }
    
    if (t_found)
    {
        // Colour << 8 + Colour == Colour*257
        DWORD t_colorref;
        t_colorref = GetSysColor(t_color);
        r_color.red = 257*GetRValue(t_colorref);
        r_color.green = 257*GetGValue(t_colorref);
        r_color.blue = 257*GetBValue(t_colorref);
    }
    
    return t_found;
}

bool MCPlatformGetControlThemePropFont(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_prop, MCFontRef& r_font)
{
    switch (p_prop)
    {
        case kMCPlatformThemePropertyTextFont:
        {
            // Note that we only look up the font outside of compatibility mode
            LOGFONTW lf;
            if (!(p_state & kMCPlatformControlStateCompatibility) && logfont_for_control(p_type, lf))
            {
                // Get the size of the font we should be using
				int t_fontsize;
				MCPlatformGetControlThemePropInteger(p_type, p_part, p_state, kMCPlatformThemePropertyTextSize, t_fontsize);
				
				// Get the font name and size from the LOGFONT structure and
                // create a font from it.
                MCAutoStringRef t_font_name_string;
                MCNewAutoNameRef t_font_name;
                if (MCStringCreateWithWString(lf.lfFaceName, &t_font_name_string)
                    && MCNameCreate(*t_font_name_string, &t_font_name))
                    return MCFontCreate(*t_font_name, 0, t_fontsize, r_font);
            }
            else
            {
                int t_fontsize;
                MCPlatformGetControlThemePropInteger(p_type, p_part, p_state, kMCPlatformThemePropertyTextSize, t_fontsize);
                if (MCmajorosversion >= MCOSVersionMake(6,0,0))
                {
                    // Return the Vista+ UI font
                    return MCFontCreate(MCNAME("Segoe UI"), 0, t_fontsize, r_font);
                }
                else
                {
                    // Return the Windows XP UI font
                    return MCFontCreate(MCNAME("Tahoma"), 0, t_fontsize, r_font);
                }
                
            }
            break;
        }
    }
    
    return false;
}
