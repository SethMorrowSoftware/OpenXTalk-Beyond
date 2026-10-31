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
#import <AppKit/NSColorSpace.h>
#import <AppKit/NSAppearance.h>
#import <AppKit/NSApplication.h>
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

// OXT-Beyond: [NSColor windowBackgroundColor] as a plain RGB colour, as the
// app's appearance (light or dark) shows it, or nil. It is a dynamic colour,
// which a conversion outside a drawing appearance may not resolve, so it is
// converted inside one.
static NSColor *MCMacResolveWindowBackgroundColor(void)
{
    __block NSColor *t_resolved = nil;
    if (@available(macOS 11.0, *))
    {
        [[NSApp effectiveAppearance] performAsCurrentDrawingAppearance:^{
            t_resolved = [[[NSColor windowBackgroundColor] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] retain];
        }];
        [t_resolved autorelease];
    }
    else if (@available(macOS 10.14, *))
    {
        NSAppearance *t_old = [NSAppearance currentAppearance];
        [NSAppearance setCurrentAppearance:[NSApp effectiveAppearance]];
        t_resolved = [[NSColor windowBackgroundColor] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
        [NSAppearance setCurrentAppearance:t_old];
    }
    else
        t_resolved = [[NSColor windowBackgroundColor] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return t_resolved;
}

// (mac-core.mm: NSApp's effectiveAppearance is dark.) The server engine
// compiles this file too but has no app, nor mac-core.mm: its stacks are
// never in the dark appearance
#ifdef _SERVER
static bool MCPlatformGetSystemAppearanceIsDark(void)
{
    return false;
}
#else
extern bool MCPlatformGetSystemAppearanceIsDark(void);
#endif

// OXT-Beyond: p_color, a system colour, as calibrated RGB as the app's
// appearance (light or dark) shows it now, or nil. A system colour is
// dynamic: converted outside a drawing appearance it took whichever
// appearance the main thread last drew in, so a script reading the
// effective colours of a stack or card after a switch between light and
// dark got the old ones, or some of each (bwmilby, openxtalk.org p=25665,
// p=25668). NSApp's effectiveAppearance is the system's, set afresh on
// every switch (MCMacPlatformUpdateAllWindowAppearances) before the stacks
// are drawn again and systemAppearanceChanged is sent; every window is set
// to it too, so a colour is drawn as it is read.
// With p_light, as the light appearance shows it (a stack or card printed
// in the dark appearance: kMCPlatformControlStateLightAppearance).
static NSColor *MCMacThemeResolveColor(NSColor *p_color, bool p_light)
{
    __block NSColor *t_resolved = nil;
    if (@available(macOS 11.0, *))
    {
        NSAppearance *t_appearance = p_light ? [NSAppearance appearanceNamed: NSAppearanceNameAqua] : [NSApp effectiveAppearance];
        [t_appearance performAsCurrentDrawingAppearance:^{
            t_resolved = [[p_color colorUsingColorSpaceName: NSCalibratedRGBColorSpace] retain];
        }];
        [t_resolved autorelease];
    }
    else if (@available(macOS 10.14, *))
    {
        NSAppearance *t_old = [NSAppearance currentAppearance];
        [NSAppearance setCurrentAppearance:p_light ? [NSAppearance appearanceNamed: NSAppearanceNameAqua] : [NSApp effectiveAppearance]];
        t_resolved = [p_color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        [NSAppearance setCurrentAppearance:t_old];
    }
    else
        t_resolved = [p_color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
    return t_resolved;
}

bool MCPlatformGetControlThemePropColor(MCPlatformControlType p_type, MCPlatformControlPart p_part, MCPlatformControlState p_state, MCPlatformThemeProperty p_which, MCColor& r_color)
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
                        // OXT-Beyond: with the useSystemWindowColor true, the
                        // system's window colour itself (light grey, or dark
                        // in dark mode), resolved in the app's appearance;
                        // otherwise white, as below, as stacks always were.
                        // In the dark appearance it is the system's window
                        // colour whatever the useSystemWindowColor (seth's
                        // choice 1A of 2026-10-31: a stack's and card's
                        // colours follow the Mac's own, live), where the
                        // pattern's stand-in below is a light grey; stacks
                        // and cards are drawn in it (MCObject::getforecolor)
                        // (not when the light appearance's colours are
                        // asked for: a stack or card printed)
                        if (MCusesystemwindowcolor ||
                            ((p_state & kMCPlatformControlStateLightAppearance) == 0 && MCPlatformGetSystemAppearanceIsDark()))
                        {
                            if ((p_state & kMCPlatformControlStateLightAppearance) != 0)
                                t_color = MCMacThemeResolveColor([NSColor windowBackgroundColor], true);
                            else
                                t_color = MCMacResolveWindowBackgroundColor();
                            if (t_color != nil)
                                break;
                        }
                        
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
        // OXT-Beyond: converted in the app's appearance, as it is now
        // (MCMacThemeResolveColor), not in the one last drawn in
        bool t_light = (p_state & kMCPlatformControlStateLightAppearance) != 0;
        if (t_is_pattern)
        {
            // Patterns not supported at the moment
            t_color = MCMacThemeResolveColor([NSColor controlHighlightColor], t_light);
        }
        else
        {
            t_color = MCMacThemeResolveColor(t_color, t_light);
        }
        
        r_color.red = [t_color redComponent] * 65535;
        r_color.green = [t_color greenComponent] * 65535;
        r_color.blue = [t_color blueComponent] * 65535;
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
