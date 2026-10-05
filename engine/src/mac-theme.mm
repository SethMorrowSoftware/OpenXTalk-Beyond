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


#include "platform.h"

#include "osxprefix.h"

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

#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSImageRep.h>
#import <CoreText/CoreText.h>


// Returns the name of the legacy font
static NSString* get_legacy_font_name()
{
    if (MCmajorosversion < MCOSVersionMake(10,10,0))
        return @"Lucida Grande";
    if (MCmajorosversion > MCOSVersionMake(10,11,0))
        return @"San Francisco";
    else
        return @"Helvetica Neue";
}

// Returns the correct font for a control of the given type
static NSFont* font_for_control(MCPlatformControlType p_type, MCPlatformControlState p_state, MCNameRef* r_name = nil)
{
    // Always return the same font regardless of control type in legacy mode
    if (p_state & kMCPlatformControlStateCompatibility)
    {
        static NSFont* s_legacy_font = nil;
        if (nil == s_legacy_font)
            s_legacy_font = [[NSFont fontWithName:get_legacy_font_name() size:11] retain];
        if (nil == s_legacy_font)
            s_legacy_font = [[NSFont systemFontOfSize:11] retain];

        MCAssert(nil != s_legacy_font);

        if (r_name)
            *r_name = nil;
        return s_legacy_font;
    }
    
    switch (p_type)
    {
        case kMCPlatformControlTypeRichText:
        {
            static NSFont* s_user_font = [[NSFont userFontOfSize:-1.0] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_usertext);
            return s_user_font;
        }
            
        case kMCPlatformControlTypeMenu:
        case kMCPlatformControlTypeMenuItem:
        case kMCPlatformControlTypePopupMenu:
        case kMCPlatformControlTypeOptionMenu:
        case kMCPlatformControlTypePulldownMenu:
        {
            static NSFont* s_menu_font = [[NSFont menuFontOfSize:-1.0] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_menutext);
            return s_menu_font;
        }
            
        case kMCPlatformControlTypeInputField:
        case kMCPlatformControlTypeComboBox:
        {
            static NSFont* s_content_font = [[NSFont controlContentFontOfSize:-1.0] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_content);
            return s_content_font;
        }
            
        case kMCPlatformControlTypeButton:
        case kMCPlatformControlTypeCheckbox:
        case kMCPlatformControlTypeLabel:
        case kMCPlatformControlTypeRadioButton:
        case kMCPlatformControlTypeList:
        case kMCPlatformControlTypeMessageBox:
        case kMCPlatformControlTypeTabButton:
        case kMCPlatformControlTypeTabPane:
        {
            static NSFont* s_message_font = [[NSFont messageFontOfSize:-1.0] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_message);
            return s_message_font;
        }
            
        case kMCPlatformControlTypeTooltip:
        {
            static NSFont* s_tooltip_font = [[NSFont toolTipsFontOfSize:-1.0] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_tooltip);
            return s_tooltip_font;
        }
            
        default:
        {
            static NSFont* s_system_font = [[NSFont systemFontOfSize:[NSFont systemFontSize]] retain];
            if (r_name)
                *r_name = MCValueRetain(MCN_font_system);
            return s_system_font;
        }
    }
}


bool MCPlatformGetControlThemePropBool(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, bool& r_bool)
{
    return false;
}

bool MCPlatformGetControlThemePropInteger(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, int& r_int)
{
    bool t_found;
    t_found = false;
    
    switch (p_which)
    {
        case kMCPlatformThemePropertyTextSize:
        {
            // If in backwards-compatibility mode, all text is size 11
            if (p_state & kMCPlatformControlStateCompatibility)
                r_int = 11;
            else
                return [font_for_control(p_type, p_state) pointSize];
        }
        
        // Property is not known
        default:
            break;
    }
    
    return t_found;
}

// The colours are AppKit's dynamic colours, which resolve in the current
// appearance. They are resolved in the appearance of the object they are for
// (kMCPlatformControlStateDarkAppearance, MCObject::getcontrolstate): a light
// object in a dark stack gets Aqua's colours, whatever the application's or
// the window's appearance is. Resolving them is slow, and the same few are
// asked for on every redraw, so they are kept by type, part, state and
// property until they may have changed (MCMacThemeClearColorCache): when the
// appearance is applied again (MCScreenDC::updatesystemappearance, for a
// change of the Mac's light or dark setting and when a script sets the
// appAppearance or a stackAppearance), and when the accent or highlight
// colour changes, which several of them follow (systemColorsChanged: in
// mac-core.mm).
struct MCMacThemeColorCacheEntry
{
    bool valid;
    bool found;
    MCPlatformControlType type;
    MCPlatformControlPart part;
    MCPlatformControlState state;
    MCPlatformThemeProperty which;
    MCColor color;
};

static MCMacThemeColorCacheEntry s_theme_color_cache[256];

// OXT-Beyond: the system's accent colour as the dark appearance draws it
// (controlAccentColor, macOS 10.14 and later), for the controls the engine
// draws itself in a dark stack (osxtheme.mm). MCaccentcolor is LiveCode's
// own navy, not the user's choice. Cached with the theme colours.
static bool s_accent_color_valid = false;
static bool s_accent_color_found = false;
static MCColor s_accent_color;

void MCMacThemeClearColorCache(void)
{
    for (uint32_t i = 0; i < sizeof(s_theme_color_cache) / sizeof(s_theme_color_cache[0]); i++)
        s_theme_color_cache[i] . valid = false;
    s_accent_color_valid = false;
}

bool MCMacThemeGetAccentColor(MCColor& r_color)
{
    if (!s_accent_color_valid)
    {
        s_accent_color_found = false;
        if (@available(macOS 10.14, *))
        {
            NSAppearance *t_saved_appearance;
            t_saved_appearance = [[NSAppearance currentAppearance] retain];
            [NSAppearance setCurrentAppearance: [NSAppearance appearanceNamed: NSAppearanceNameDarkAqua]];
            
            NSColor *t_color;
            t_color = [[NSColor controlAccentColor] colorUsingColorSpace: [NSColorSpace sRGBColorSpace]];
            if (t_color != nil)
            {
                s_accent_color . red = [t_color redComponent] * 65535;
                s_accent_color . green = [t_color greenComponent] * 65535;
                s_accent_color . blue = [t_color blueComponent] * 65535;
                s_accent_color_found = true;
            }
            
            [NSAppearance setCurrentAppearance: t_saved_appearance];
            [t_saved_appearance release];
        }
        s_accent_color_valid = true;
    }
    
    if (s_accent_color_found)
        r_color = s_accent_color;
    return s_accent_color_found;
}

static bool MCMacThemeLookupControlColor(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, MCColor& r_color);

bool MCPlatformGetControlThemePropColor(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, MCColor& r_color)
{
    uint32_t t_slot;
    t_slot = (uint32_t(p_type) * 31 + uint32_t(p_part) * 7 + uint32_t(p_state) * 13 + uint32_t(p_which)) % (sizeof(s_theme_color_cache) / sizeof(s_theme_color_cache[0]));
    MCMacThemeColorCacheEntry& t_entry = s_theme_color_cache[t_slot];
    if (t_entry . valid && t_entry . type == p_type && t_entry . part == p_part &&
        t_entry . state == p_state && t_entry . which == p_which)
    {
        if (t_entry . found)
            r_color = t_entry . color;
        return t_entry . found;
    }

    // Resolve in the object's appearance, and leave AppKit's current one as
    // it was
    NSAppearance *t_saved_appearance = nil;
    bool t_switched = false;
    if (@available(macOS 10.14, *))
    {
        t_saved_appearance = [[NSAppearance currentAppearance] retain];
        [NSAppearance setCurrentAppearance: [NSAppearance appearanceNamed: (p_state & kMCPlatformControlStateDarkAppearance) != 0 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua]];
        t_switched = true;
    }

    MCColor t_color;
    bool t_found;
    t_found = MCMacThemeLookupControlColor(p_type, p_part, p_state, p_which, t_color);

    if (t_switched)
    {
        [NSAppearance setCurrentAppearance: t_saved_appearance];
        [t_saved_appearance release];
    }

    t_entry . valid = true;
    t_entry . found = t_found;
    t_entry . type = p_type;
    t_entry . part = p_part;
    t_entry . state = p_state;
    t_entry . which = p_which;
    if (t_found)
    {
        t_entry . color = t_color;
        r_color = t_color;
    }
    return t_found;
}

static bool MCMacThemeLookupControlColor(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, MCColor& r_color)
{
    bool t_found;
    t_found = false;
    
    NSColor *t_color;
    t_color = nil;
    
    bool t_is_pattern;
    t_is_pattern = false;
    
    switch (p_which)
    {
        case kMCPlatformThemePropertyTextColor:
        {
            t_found = true;
            if (p_state & kMCPlatformControlStateDisabled)
            {
                // OXT-Beyond: in the dark appearance disabledControlTextColor
                // is white at 25%; the engine's disabled grey
                // (MCScreenDC::getdefaultcolors), 4.5:1 on the dark window
                if (p_state & kMCPlatformControlStateDarkAppearance)
                    t_color = [NSColor colorWithCalibratedWhite: 0x88 / 255.0 alpha: 1.0];
                else
                    t_color = [NSColor disabledControlTextColor];
            }
            else
            {
                switch (p_type)
                {
                    case kMCPlatformControlTypeInputField:
                    {
                        if (p_state & kMCPlatformControlStateSelected)
                            t_color = [NSColor selectedTextColor];
                        else
                            t_color = [NSColor textColor];
                        break;
                    }
                        
                    case kMCPlatformControlTypeTabPane:
                    case kMCPlatformControlTypeTabButton:
                    {
						if (MCmajorosversion < MCOSVersionMake(10,16,0))
						{
							// These really should update like the other menu types
							// do when the window isn't active but we don't have
							// access to the active-tab-but-inactive-window button
							// appearance used for "real" tabbed controls.
							if (p_state & kMCPlatformControlStateSelected)
								t_color = [NSColor selectedMenuItemTextColor];
							else
								t_color = [NSColor controlTextColor];
						}
                        else
                            t_color = [NSColor controlTextColor];
                        break;
                    }
                        
                    case kMCPlatformControlTypeMenu:
                    case kMCPlatformControlTypeOptionMenu:
                    case kMCPlatformControlTypePopupMenu:
                    case kMCPlatformControlTypePulldownMenu:
                    case kMCPlatformControlTypeList:
                    {
                        if (p_state & kMCPlatformControlStateSelected
                            && p_state & kMCPlatformControlStateWindowActive)
                        {
                            if (p_type == kMCPlatformControlTypeList)
                                t_color = [NSColor alternateSelectedControlTextColor];
                            else
                                t_color = [NSColor selectedMenuItemTextColor];
                            break;
                        }
                        
                        /* FALLTHROUGH */
                    }
                        
                    default:
                        t_color = [NSColor controlTextColor];
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
                    case kMCPlatformControlTypeInputField:
                        t_color = [NSColor selectedTextBackgroundColor];
                        break;
                        
                    case kMCPlatformControlTypeMenu:
                    case kMCPlatformControlTypeOptionMenu:
                    case kMCPlatformControlTypePopupMenu:
                    case kMCPlatformControlTypePulldownMenu:
                        t_color = [NSColor selectedMenuItemColor];
                        break;
                        
                    case kMCPlatformControlTypeList:
                        if (p_state & kMCPlatformControlStateWindowActive)
                            t_color = [NSColor alternateSelectedControlColor];
                        else
                            t_color = [NSColor secondarySelectedControlColor];
                        break;
                        
                    default:
                        t_color = [NSColor selectedControlColor];
                        break;
                }
            }
            
            // Handle non-selected controls
            if (t_color == nil)
            {
                switch (p_type)
                {
                    case kMCPlatformControlTypeInputField:
                    case kMCPlatformControlTypeList:
                        t_color = [NSColor textBackgroundColor];
                        break;
                        
                    case kMCPlatformControlTypeTooltip:
                        // Undocumented but it works (and other mac apps use it)
                        t_color = [NSColor toolTipColor];
                        t_found = t_color != nil;
                        break;
                        
                    case kMCPlatformControlTypeWindow:
                        // In compatibility mode, handle window colour the old way
                        if (p_state & kMCPlatformControlStateCompatibility)
                        {
                            return false;
                        }
                        /* FALLTHROUGH */
                        
                    case kMCPlatformControlTypeMessageBox:
                        // windowBackgroundColor is a pattern
                        t_is_pattern = true;
                        t_color = [NSColor windowBackgroundColor];
                        break;
                        
                    default:
                        // controlColor is a pattern
                        t_is_pattern = true;
                        t_color = [NSColor controlColor];
                        break;
                }
            }
            
            break;
        }
        
        case kMCPlatformThemePropertyBorderColor:
        {
            t_found = true;
            // OXT-Beyond: black is 1.2:1 on the dark window; the grey of the
            // engine's dark borders (MCObject::getforecolor, DI_BORDER)
            if (p_state & kMCPlatformControlStateDarkAppearance)
                t_color = [NSColor colorWithCalibratedWhite: 0x6E / 255.0 alpha: 1.0];
            else
                t_color = [NSColor blackColor];
            break;
        }
            
        case kMCPlatformThemePropertyShadowColor:
        {
            t_found = true;
            if (p_type == kMCPlatformControlTypeWindow || p_type == kMCPlatformControlTypeMessageBox)
                t_color = [NSColor shadowColor];
            else
                t_color = [NSColor controlShadowColor];
            break;
        }
            
        case kMCPlatformThemePropertyFocusColor:
        {
            t_found = true;
            t_color = [NSColor keyboardFocusIndicatorColor];
            break;
        }
            
        case kMCPlatformThemePropertyTopEdgeColor:
        case kMCPlatformThemePropertyLeftEdgeColor:
        {
            t_found = true;
            t_color = [NSColor controlLightHighlightColor];
            break;
        }
            
        case kMCPlatformThemePropertyBottomEdgeColor:
        case kMCPlatformThemePropertyRightEdgeColor:
        {
            t_found = true;
            t_color = [NSColor controlShadowColor];
            break;
        }
            
        // Property is not known
        default:
            break;
    }
    
    if (t_found && t_color != nil)
    {
        bool t_dark;
        t_dark = (p_state & kMCPlatformControlStateDarkAppearance) != 0;
        
        if (t_is_pattern && !t_dark)
        {
            // Patterns not supported at the moment
            t_color = [[NSColor controlHighlightColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        }
        else
        {
            // OXT-Beyond: in the dark appearance windowBackgroundColor and
            // controlColor are plain colours (macOS 10.14 and later), and
            // controlHighlightColor, which stands in for them in the light
            // one, would give a dark stack a light card. They are resolved
            // in sRGB, the space AppKit's dark colours are defined in (the
            // calibrated space gives a darker window: 37 rather than 50).
            t_color = [t_color colorUsingColorSpace: [NSColorSpace sRGBColorSpace]];
        }
        
        CGFloat t_red, t_green, t_blue;
        t_red = [t_color redComponent];
        t_green = [t_color greenComponent];
        t_blue = [t_color blueComponent];
        
        // OXT-Beyond: many of the dark appearance's colours are white with
        // some alpha (controlColor is white at 25%), which the engine
        // cannot use; a fill or a line is that colour over the dark window,
        // as AppKit draws it. Text keeps its colour (white).
        if (t_dark && p_which != kMCPlatformThemePropertyTextColor && [t_color alphaComponent] < 1.0)
        {
            NSColor *t_window;
            t_window = [[NSColor windowBackgroundColor] colorUsingColorSpace: [NSColorSpace sRGBColorSpace]];
            if (t_window != nil)
            {
                CGFloat t_alpha;
                t_alpha = [t_color alphaComponent];
                t_red = t_red * t_alpha + [t_window redComponent] * (1 - t_alpha);
                t_green = t_green * t_alpha + [t_window greenComponent] * (1 - t_alpha);
                t_blue = t_blue * t_alpha + [t_window blueComponent] * (1 - t_alpha);
            }
        }
        
        r_color.red = t_red * 65535;
        r_color.green = t_green * 65535;
        r_color.blue = t_blue * 65535;
    }
    
    return t_found;
}

bool MCPlatformGetControlThemePropFont(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, MCFontRef& r_font)
{
    // Get the font for the given control type
	MCNewAutoNameRef t_font_name;
    NSFont* t_font = font_for_control(p_type, p_state, &(&t_font_name));
    if (t_font == nil)
        return false;
    
    // Ensure the font is registered and return it
    return MCFontCreateWithHandle((MCSysFontHandle)t_font, *t_font_name, r_font);
}
