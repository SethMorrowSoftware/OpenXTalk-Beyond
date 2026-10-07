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

#include "context.h"
#include "osxtheme.h"

#include "graphics_util.h"

#ifndef _IOS_MOBILE
#define CGFloat float
#endif

//-- tperry 18th October 2025
// Import modern AppKit controls to replace deprecated HITheme
#import <AppKit/NSAppearance.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButtonCell.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSComboBox.h>
#import <AppKit/NSProgressIndicator.h>
#import <AppKit/NSSegmentedControl.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSTabView.h>
#import <AppKit/NSSlider.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSColor.h>

extern double MCMacGetAnimationStartTime(void);
extern double MCMacGetAnimationCurrentTime(void);

static inline Rect MCRectToMacRect(const MCRectangle &p_rect)
{
	Rect t_rect;
	t_rect.left = p_rect.x;
	t_rect.top = p_rect.y;
	t_rect.right = p_rect.x + p_rect.width;
	t_rect.bottom = p_rect.y + p_rect.height;
	
	return t_rect;
}

////////////////////////////////////////////////////////////////////////////////

static inline CGAffineTransform MCGAffineTransformToCGAffineTransform(const MCGAffineTransform &p_transform)
{
	return CGAffineTransformMake(p_transform.a, p_transform.b, p_transform.c, p_transform.d, p_transform.tx, p_transform.ty);
}

static void convertcgtomcrect(CGRect r, MCRectangle& r_mc)
{
    r_mc . x = r . origin . x;
    r_mc . y = r . origin . y;
    r_mc . width = r . size . width;
    r_mc . height = r . size . height;
}

static void convertmctocgrect(MCRectangle r, CGRect& r_cg)
{
    r_cg . origin . x = r . x;
    r_cg . origin . y = r . y;
    r_cg . size . width = r . width;
    r_cg . size . height = r . height;
}

////////////////////////////////////////////////////////////////////////////////

static void getthemebuttonpartandstate(const MCWidgetInfo &winfo, HIThemeButtonDrawInfo &bNewInfo,const MCRectangle &drect, HIRect &macR);
static void drawthemebutton(MCDC *dc, const MCWidgetInfo &widgetinfo, const MCRectangle &drect);
static void drawthemetabs(MCDC *dc, const MCWidgetInfo &widgetinfo, const MCRectangle &drect);
static Widget_Part HitTestScrollControls(const MCWidgetInfo &winfo, int2 mx,int2 my, const MCRectangle &drect);
static void DrawMacAMScrollControls(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect);
static ThemeTrackKind getscrollbarkind(Widget_Type wtype);
static void getscrollbarpressedstate(const MCWidgetInfo &winfo, HIThemeTrackDrawInfo &drawInfo);
static void fillTrackDrawInfo(const MCWidgetInfo &winfo, HIThemeTrackDrawInfo &drawInfo, const MCRectangle &drect);

enum {
    kControlLowerUpButtonPart = 28,
    kControlUpperDownButtonPart = 29
};


static Boolean doublesbarrows;

Boolean MCNativeTheme::load()
{	
	return True;
}


static void converttohirect(const Rect *trect, HIRect *dhrect)
{
	dhrect->origin.x = trect->left;
	dhrect->origin.y = trect->top;
	dhrect->size.width = trect->right - trect->left;
	dhrect->size.height = trect->bottom - trect->top;
}

static void converttohirect(const MCRectangle& in, HIRect& out)
{
    out.origin.x = in.x;
    out.origin.y = in.y;
    out.size.width = in.width;
    out.size.height = in.height;
}

static void converttonativerect(const MCRectangle &mcR, Rect &macR)
{
	macR.top = mcR.y;
	macR.left = mcR.x;
	macR.bottom = mcR.y + mcR.height;
	macR.right = mcR.x + mcR.width;
}


static void converttomcrect(const Rect &macR, MCRectangle &mcR)
{
	mcR.x = macR.left;
	mcR.y = macR.top;
	mcR.width = macR.right - macR.left;
	mcR.height = macR.bottom - macR.top;
}


void MCNativeTheme::unload()
{
}



Boolean MCNativeTheme::iswidgetsupported(Widget_Type w)
{
	switch (w)
	{
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_GROUP_FRAME:
		return True;
		break;
	case WTHEME_TYPE_TABPANE:
	case WTHEME_TYPE_TAB:
		return True;
		break;
	default:
		return True;
	}
}

int4 MCNativeTheme::getmetric(Widget_Metric wmetric)
{
	switch (wmetric)
	{
	case WTHEME_METRIC_TABOVERLAP:
		return -1;
		break;
	case WTHEME_METRIC_TABRIGHTMARGIN:
		return 11;
	case WTHEME_METRIC_TABLEFTMARGIN:
		return 12;
		break;
	case WTHEME_METRIC_TABNONSELECTEDOFFSET:
		return 0;
		break;
	case WTHEME_METRIC_COMBOSIZE:
		return 22;
		break;
	// MH-2007-03-16 [[ Bug 3598 ]] Adding support for the option button arrow size.
	case WTHEME_METRIC_OPTIONBUTTONARROWSIZE:
		return 21;
		break;
    case WTHEME_METRIC_TABBUTTON_HEIGHT:
        return 21;
        break;
	default:
		return 0;
	}
}

int4 MCNativeTheme::getwidgetmetric(const MCWidgetInfo &winfo, Widget_Metric wmetric)
{
	return 0;
}

Boolean MCNativeTheme::getthemepropbool(Widget_ThemeProps themeprop)
{
	if (themeprop == WTHEME_PROP_DRAWTABPANEFIRST)
		return true;
	else if (themeprop == WTHEME_PROP_TABSELECTONMOUSEUP)
		return true;
	else if (themeprop == WTHEME_PROP_TABBUTTONSOVERLAPPANE)
		return true;
	return False;
}


void MCNativeTheme::getwidgetrect(const MCWidgetInfo &winfo, Widget_Metric wmetric, const MCRectangle &srect,
                                  MCRectangle &drect)
{

	switch (winfo.type)
	{
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR:
	case WTHEME_TYPE_PROGRESSBAR:
	case WTHEME_TYPE_SLIDER:
		if (wmetric == WTHEME_METRIC_PARTSIZE)
		{
			HIThemeTrackDrawInfo drawInfo;
			fillTrackDrawInfo(winfo,drawInfo,srect);
			if (winfo.part == WTHEME_PART_THUMB)
			{
				HIShapeRef t_shape;
                
				HIThemeGetTrackThumbShape(&drawInfo, &t_shape);
                
				CGRect t_rect;
                HIShapeGetBounds(t_shape, &t_rect);
                CFRelease(t_shape);
				convertcgtomcrect(t_rect,drect);
				return;
			}
			else if (winfo.part == WTHEME_PART_TRACK_INC)
			{
				CGRect t_rect;
                
				HIThemeGetTrackBounds(&drawInfo, &t_rect);
                
				convertcgtomcrect(t_rect,drect);
				return;
			}
		}
	case WTHEME_TYPE_COMBO:
		{
			if (wmetric == WTHEME_METRIC_PARTSIZE)
			{
				MCRectangle combobuttonrect = srect;
				combobuttonrect.x += srect.width - 22 - 2;
				combobuttonrect.width = 18;
				if (winfo.part == WTHEME_PART_COMBOTEXT)
				{
					HIThemeButtonDrawInfo bNewInfo;
					HIRect macR,maccontentbounds;
					getthemebuttonpartandstate(winfo, bNewInfo,srect,macR);

                    HIThemeGetButtonBackgroundBounds(&macR, &bNewInfo, &maccontentbounds);
                    
					drect = srect;
					drect.height = maccontentbounds.size.height - 1;
					drect = MCU_reduce_rect(drect,2);
					drect.width -= combobuttonrect.width;
				}
				else if (winfo.part == WTHEME_PART_COMBOBUTTON)
					drect = srect;
				return;
			}
		}
	case WTHEME_TYPE_COMBOTEXT:
		{
			if (wmetric == 	WTHEME_METRIC_PARTSIZE)
			{
				drect.width = drect.height = 0;
			}
			else
				drect = srect;
		}
	default:
		break;
	}
	MCTheme::getwidgetrect(winfo,wmetric,srect,drect);
}

uint2 MCNativeTheme::getthemeid()
{
	return LF_NATIVEMAC;
}

uint2 MCNativeTheme::getthemefamilyid()
{
	return LF_MAC;
}

Boolean MCNativeTheme::drawwidget(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	MCRectangle trect = drect;
	switch (winfo.type)
{
	case WTHEME_TYPE_CHECKBOX:
	case WTHEME_TYPE_PUSHBUTTON:
	case WTHEME_TYPE_BEVELBUTTON:
	case WTHEME_TYPE_RADIOBUTTON:
	case WTHEME_TYPE_OPTIONBUTTON:
	case WTHEME_TYPE_PULLDOWN:
		drawthemebutton(dc, winfo, drect);
		break;
	case WTHEME_TYPE_COMBOFRAME:
		break;

	case WTHEME_TYPE_TABPANE:
	case WTHEME_TYPE_TAB:
		drawthemetabs(dc, winfo, drect);
		break;
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
		}
		break;
	case WTHEME_TYPE_COMBOBUTTON:
		drawthemebutton(dc, winfo, trect);
		break;
	case WTHEME_TYPE_SLIDER:
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR:
	case WTHEME_TYPE_PROGRESSBAR:
		DrawMacAMScrollControls(dc, winfo, drect);
		break;
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
		break; //support in future for drawing primatives

	case WTHEME_TYPE_TEXTFIELD_FRAME:
	case WTHEME_TYPE_COMBOTEXT:
	case WTHEME_TYPE_LISTBOX_FRAME:
		{
			MCThemeDrawInfo t_info;
			t_info.dest = drect;
			converttonativerect(MCU_reduce_rect(trect, 1), t_info . frame . bounds);
			if ((winfo . state & WTHEME_STATE_DISABLED) != 0)
				t_info . frame . state = kThemeStateInactive;
			else if ((winfo . state & WTHEME_STATE_PRESSED) != 0)
				t_info . frame . state = kThemeStatePressed;
			else
				t_info . frame . state = kThemeStateActive;
			t_info . frame . is_list = false;
			dc -> drawtheme(THEME_DRAW_TYPE_FRAME, &t_info);
		}
		break;
	case WTHEME_TYPE_GROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FILL:
	case WTHEME_TYPE_SECONDARYGROUP_FRAME:
	case WTHEME_TYPE_GROUP_FRAME:
		{
			MCThemeDrawInfo t_info;
			t_info.dest = drect;
			converttonativerect(trect, t_info . group . bounds);
			
			if ((winfo . state & WTHEME_STATE_DISABLED) != 0)
				t_info . group . state = kThemeStateInactive;
			else
				t_info . group . state = kThemeStateActive;
				
			if (winfo . datatype == WTHEME_DATA_RECT)
			{
				MCRectangle *textrect = (MCRectangle *)winfo.data;
				t_info . group . bounds . top = textrect -> y + textrect -> height + 2;
			}
			
			t_info . group . is_secondary = (winfo . type == WTHEME_TYPE_SECONDARYGROUP_FILL || winfo . type == WTHEME_TYPE_SECONDARYGROUP_FRAME);
			t_info . group . is_filled = (winfo . type == WTHEME_TYPE_GROUP_FILL || winfo . type == WTHEME_TYPE_SECONDARYGROUP_FILL);
			
			dc -> drawtheme(THEME_DRAW_TYPE_GROUP, &t_info);
		}
		break;
	default:
		break;
	}
	
	return True;
}

Widget_Part MCNativeTheme::hittest(const MCWidgetInfo &winfo, int2 mx,int2 my, const MCRectangle &drect)
{
	switch (winfo.type)
	{
	case WTHEME_TYPE_SLIDER:
	case WTHEME_TYPE_SCROLLBAR:
	case WTHEME_TYPE_SMALLSCROLLBAR:
		return HitTestScrollControls(winfo,mx,my,drect);
		break;
	default:
		return MCU_point_in_rect(drect, mx, my)?WTHEME_PART_ALL:WTHEME_PART_UNDEFINED;
		break;
	}
}

////////////////////////////////////////////////////////////////////////////////

static void getthemebuttonpartandstate(const MCWidgetInfo &widgetinfo, HIThemeButtonDrawInfo &bNewInfo,const MCRectangle &drect, HIRect &macR)
{
	MCRectangle trect = drect;
	ThemeButtonKind themebuttonkind;
	switch (widgetinfo.type)
	{
	case WTHEME_TYPE_CHECKBOX:
		themebuttonkind = kThemeCheckBox;
		break;
	case WTHEME_TYPE_PUSHBUTTON:
		themebuttonkind = kThemePushButton;
		break;
	case WTHEME_TYPE_BEVELBUTTON:
		themebuttonkind = kThemeBevelButton;
		break;
	case WTHEME_TYPE_RADIOBUTTON:
		themebuttonkind = kThemeRadioButton;
		break;
	case WTHEME_TYPE_OPTIONBUTTON:
		themebuttonkind =  kThemePopupButton;
		break;
	case WTHEME_TYPE_COMBOBUTTON:
	case WTHEME_TYPE_COMBO:
		themebuttonkind = kThemeComboBox;
		break;
	case WTHEME_TYPE_PULLDOWN:
		themebuttonkind = kThemeBevelButton;
		break;
	default:
		MCUnreachable();
		break;
	}
	//set state stuff

    // Version number is always zero
    bNewInfo.version = 0;
    
	if (widgetinfo.state & WTHEME_STATE_DISABLED)
		bNewInfo.state = kThemeStateInactive;
	else
	{
		if (widgetinfo.state & WTHEME_STATE_PRESSED)
			bNewInfo.state = kThemeStatePressed;
		else
			bNewInfo.state = kThemeStateActive;
	}
	if (widgetinfo.state & WTHEME_STATE_HILITED)
		bNewInfo.value = kThemeButtonOn;
	else
		bNewInfo.value = kThemeButtonOff;
	//set adornment
	bNewInfo.adornment = kThemeAdornmentNone;
	if (themebuttonkind == kThemeCheckBox)
		bNewInfo.adornment = kThemeAdornmentDrawIndicatorOnly;
	else if (themebuttonkind == kThemeArrowButton)
		bNewInfo.adornment = kThemeAdornmentArrowDownArrow;
	else if (widgetinfo.state & WTHEME_STATE_HASDEFAULT &&
	         themebuttonkind == kThemePushButton )
	{
		if (!(widgetinfo.state & (WTHEME_STATE_PRESSED | WTHEME_STATE_SUPPRESSDEFAULT)))
			bNewInfo.adornment = kThemeAdornmentDefault;
	}

    Rect t_rect;
	converttonativerect(trect, t_rect);
	
	if (themebuttonkind == kThemeCheckBox || themebuttonkind == kThemeRadioButton)
	{
		if (trect.height < 16)
			if (themebuttonkind == kThemeCheckBox)
				themebuttonkind = kThemeSmallCheckBox;
			else
				themebuttonkind = kThemeSmallRadioButton;
		else
			t_rect.left--;
	}
	else if (themebuttonkind == kThemePushButton || themebuttonkind == kThemePopupButton)
	{
		if (themebuttonkind == kThemePushButton && trect.height < 21)
		{
			t_rect.top--;
			t_rect.left += 2;
			t_rect.right -= 2;
		}
		t_rect.bottom -= 2;
		
		// IM-2014-02-12: [[ Bug 11785 ]] Constrain option button height to 20 px.
		//   Drawing above this height is not supported on OSX with a retina display. 
		if (themebuttonkind == kThemePopupButton && t_rect.bottom - t_rect.top > 20)
		{
			// center within button rect
			uint32_t t_adjust = ((t_rect.bottom - t_rect.top) - 20) / 2;
			t_rect.top += t_adjust;
			t_rect.bottom = t_rect.top + 20;
		}
	}

    converttohirect(&t_rect, &macR);
    
    // Set the kind, too
    bNewInfo.kind = themebuttonkind;
}

//draw theme button to MCScreen
static void drawthemebutton(MCDC *dc, const MCWidgetInfo &widgetinfo, const MCRectangle &drect)
{
	MCThemeDrawInfo t_info;
	t_info . dest = drect;
	getthemebuttonpartandstate(widgetinfo, t_info . button . info, drect, t_info . button . bounds);
	// tperry 3rd December 2025: Store original widget type to distinguish BEVELBUTTON from PULLDOWN
	t_info . button . widget_type = widgetinfo.type;
	if (t_info . button . info . kind == kThemePushButton && t_info . button . info . adornment == kThemeAdornmentDefault)
	{
		t_info . button . info . animation . time . start = MCMacGetAnimationStartTime();
		t_info . button . info . animation . time . current = MCMacGetAnimationCurrentTime();
	}
	else
		t_info . button . info . animation . time . start = t_info . button . info . animation . time . current = 0;
		
	dc -> drawtheme(THEME_DRAW_TYPE_BUTTON, &t_info);
}


static void drawthemetabs(MCDC *dc, const MCWidgetInfo &widgetinfo, const MCRectangle &drect)
{
	if (widgetinfo.type == WTHEME_TYPE_TABPANE)
	{
		MCThemeDrawInfo t_info;
		t_info . dest = drect;
		
		converttonativerect(drect, t_info . tab_pane . bounds);
		
		t_info . tab_pane . state = (widgetinfo.state & WTHEME_STATE_DISABLED) != 0 ? kThemeStateInactive: kThemeStateActive;
		
		dc -> drawtheme(THEME_DRAW_TYPE_TAB_PANE, &t_info);
	}
	else
	{
		MCThemeDrawInfo t_info;
		t_info.dest = drect;
		
		// MM-2012-11-18: [[ Bug 11456 ]] The height in the dest rect is based on font size.
		//   However, on OS X, tab buttons are always 22 pixels high, irrespective of font size. Was causing clipping with small font sizes.
		t_info . dest . height = 22;
				
		converttonativerect(drect, t_info . tab . bounds);
		t_info . tab . is_hilited = (widgetinfo . state & WTHEME_STATE_HILITED) != 0;
		t_info . tab . is_disabled = (widgetinfo . state & WTHEME_STATE_DISABLED) != 0;
		t_info . tab . is_pressed = (widgetinfo . state & WTHEME_STATE_PRESSED) != 0;
		t_info . tab . is_first = (widgetinfo . attributes & WTHEME_ATT_FIRSTTAB) != 0;
		t_info . tab . is_last = (widgetinfo . attributes & WTHEME_ATT_LASTTAB) != 0;
		dc -> drawtheme(THEME_DRAW_TYPE_TAB, &t_info);
	}
}

static Widget_Part HitTestScrollControls(const MCWidgetInfo &winfo, int2 mx,int2 my, const MCRectangle &drect)
{
	Widget_Part wpart =  WTHEME_PART_THUMB;
	HIPoint mouseLoc;
	mouseLoc.x = mx;
	mouseLoc.y = my;
	HIThemeTrackDrawInfo ttdi;
	fillTrackDrawInfo(winfo,ttdi,drect);
	Boolean inScrollbarArrow = False;
	ControlPartCode partCode;
	// scrollbar needs to check first if mouse-down occurred in arrows
	if (ttdi.kind == kThemeScrollBar || ttdi.kind == kThemeSmallScrollBar)
	{
		// MW-2008-11-02: [[ Bug ]] If this scrollbar is rendered as a little arrows control, then
		//   ensure we hit-test it as such!
		if (drect.height > drect.width && (drect.width == 0 || drect.height / drect.width < 3))
		{
			if (my <= drect . y + drect . height / 2)
				wpart = WTHEME_PART_ARROW_DEC;
			else
				wpart = WTHEME_PART_ARROW_INC;
			
			// MW-2011-10-10: [[ Bug 9797 ]] Make sure we flag ourselves as having
			//   finished the hit test otherwise we invariable end up with the wrong
			//   part code for little arrows.
			inScrollbarArrow = True;
		}
		else
        {
            HIScrollBarTrackInfo t_sbinfo;
            t_sbinfo . version = 0;
            t_sbinfo . pressState = ttdi . trackInfo . scrollbar . pressState;
            t_sbinfo . enableState = ttdi . enableState;
            t_sbinfo . viewsize = ttdi . trackInfo . scrollbar . viewsize;
            if (HIThemeHitTestScrollBarArrows(&ttdi.bounds, &t_sbinfo,
		                                drect.width > drect.height, &mouseLoc,
		                                &ttdi.bounds, &partCode))
            {
                inScrollbarArrow = True;
                if (partCode == kControlUpButtonPart
                        || partCode == kControlLowerUpButtonPart)
                    wpart = WTHEME_PART_ARROW_DEC;
                else if (partCode == kControlDownButtonPart
                         || partCode == kControlUpperDownButtonPart)
                    wpart = WTHEME_PART_ARROW_INC;
                doublesbarrows = partCode == kControlLowerUpButtonPart
                                 || partCode == kControlUpperDownButtonPart;
            }
        }
	}
	if (!inScrollbarArrow)
	{
		if (HIThemeHitTestTrack(&ttdi, &mouseLoc, &partCode))
		{
			if (partCode == kControlPageUpPart)
				wpart = WTHEME_PART_TRACK_DEC;
			else
				if (partCode == kControlPageDownPart)
					wpart = WTHEME_PART_TRACK_INC;
		}//if partCode == kControlIndicatorPart, fall through
	}
	return wpart;
}

static void DrawMacAMScrollControls(MCDC *dc, const MCWidgetInfo &winfo, const MCRectangle &drect)
{
	MCThemeDrawInfo t_info;
	t_info . dest = drect;
	if (winfo.datatype != WTHEME_DATA_SCROLLBAR && winfo.type != WTHEME_TYPE_SMALLSCROLLBAR)
		return;
	
	// Check if scrollbar should be hidden (content doesn't need scrolling)
	// This is for regular scrollbars, not sliders or progress bars
	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;
	if (winfo.type == WTHEME_TYPE_SCROLLBAR || winfo.type == WTHEME_TYPE_SMALLSCROLLBAR)
	{
		// Content doesn't need scrolling when range <= thumbsize
		real8 range = fabs(sbinfo->endvalue - sbinfo->startvalue);
		if (range <= sbinfo->thumbsize + 0.5)
			return;
	}
	
	fillTrackDrawInfo(winfo, t_info . slider . info, drect);
	
	// MW-2007-08-30: [[ Bug 4155 ]] Ensure the case of endvalue < startvalue is handled correctly.
	if (t_info . slider . info . kind == kThemeSlider)
	{
		if ((winfo.attributes & WTHEME_ATT_SHOWVALUE) != 0)
			t_info . slider . count = (uint2)(fabs(sbinfo->endvalue - sbinfo->startvalue) / (sbinfo->pageinc - sbinfo->lineinc));
		else
			t_info . slider . count = 0;
		dc -> drawtheme(THEME_DRAW_TYPE_SLIDER, &t_info);
	}
	else if (t_info.slider.info.kind == kThemeScrollBar || t_info.slider.info.kind == kThemeSmallScrollBar)
	{
		if (drect.height > drect.width && (drect.width == 0 || drect.height / drect.width < 3))
		{
			converttohirect(drect, t_info . button . bounds);
			t_info . button . bounds . origin . x++;
            t_info . button . bounds . size . width--;
				
			if (winfo.state & WTHEME_STATE_DISABLED)
				t_info . button . info . state = kThemeStateInactive;
			else
				if (winfo.state & WTHEME_STATE_PRESSED)
					if (winfo.part == WTHEME_PART_ARROW_DEC)
						t_info . button . info . state = kThemeStatePressedUp;
					else
						t_info . button . info . state = kThemeStatePressedDown;
				else
					t_info . button . info . state = kThemeStateActive;
			t_info . button . info . adornment = kThemeAdornmentNone;
			t_info . button . info . value = kThemeButtonOff;
			t_info . button . info . kind = kThemeIncDecButton;
			dc -> drawtheme(THEME_DRAW_TYPE_BUTTON, &t_info);
		}
		else
		{
			t_info . scrollbar . horizontal = drect . width > drect . height;
			dc -> drawtheme(THEME_DRAW_TYPE_SCROLLBAR, &t_info);
		}
	}
	else
	{
		// MW-2012-09-17: [[ Bug 9212 ]] Set the phase appropriately for animation.
		int32_t t_steps_per_second, t_millisecs_per_step;
		t_steps_per_second = 30;
		t_millisecs_per_step = 1000 / t_steps_per_second;
		
		// MW-2012-10-01: [[ Bug 10419 ]] Wrap phase at 256 as more frames on Lion+
		//   animation than in Snow Leopard.
		t_info . progress . info . trackInfo . progress . phase = ((int32_t)((MCMacGetAnimationCurrentTime() - MCMacGetAnimationStartTime()) * 1000)) / t_millisecs_per_step % 256;
		dc -> drawtheme(THEME_DRAW_TYPE_PROGRESS, &t_info);
	}
}

//get theme track kind
static ThemeTrackKind getscrollbarkind(Widget_Type wtype)
{
	switch (wtype)
	{
	case WTHEME_TYPE_PROGRESSBAR:
		return kThemeProgressBar;
		break;
	case WTHEME_TYPE_SLIDER:
		return kThemeSlider;
		break;
	case WTHEME_TYPE_SMALLSCROLLBAR:
		return kThemeSmallScrollBar;
		break;
	default:
		return kThemeScrollBar;
	}
}

//fill themetrackinfo with state
static void getscrollbarpressedstate(const MCWidgetInfo &winfo, HIThemeTrackDrawInfo &drawInfo)
{
	ThemeTrackPressState ps = 0;
	if (winfo.state & WTHEME_STATE_PRESSED)
	{
		if (winfo.part == WTHEME_PART_THUMB)  //in scrolling mode, means the thumb is pressed
			ps = kThemeThumbPressed;
		else
		{
			switch (winfo.part)
			{
			case WTHEME_PART_ARROW_DEC:
				{
                    NSString* t_arrow_style = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleScrollBarVariant"];
                    if (![t_arrow_style isEqualToString:@"DoubleBoth"])
					{
						if (doublesbarrows)
							ps = kThemeLeftInsideArrowPressed;
						else
							ps = kThemeLeftOutsideArrowPressed;
					}
					else
					{
						// MW-2012-09-20: [[ Bug ]] Arrow not highlighting when pressed as
						//   wrong constant was used.
						ps = kThemeLeftInsideArrowPressed;
				}
				}
				break;
			case WTHEME_PART_ARROW_INC:
				if (doublesbarrows)
					ps = kThemeRightInsideArrowPressed;
				else
					ps = kThemeRightOutsideArrowPressed;
				break;
			case WTHEME_PART_TRACK_DEC:
				ps = kThemeLeftTrackPressed;
				break;
			case WTHEME_PART_TRACK_INC:
				ps = kThemeRightTrackPressed;
				break;
			default:
				break;
			}
		}
	}
	if (winfo.type == WTHEME_TYPE_SLIDER)
		drawInfo.trackInfo.slider.pressState = ps;
	else
		drawInfo.trackInfo.scrollbar.pressState = ps;
}

#define SB_MAXVALUE 16384

static void fillTrackDrawInfo(const MCWidgetInfo &winfo, HIThemeTrackDrawInfo &drawInfo, const MCRectangle &drect)
{
	/******************************************************************************
	* fill in the fields in the ThemeTrackDrawInfo structure to be used by other *
	* Appearance Manager routines                                                *
	******************************************************************************/
    drawInfo.version = 0;
	drawInfo.kind = getscrollbarkind(winfo.type);
	if (winfo.datatype != WTHEME_DATA_SCROLLBAR)
		return;
	
	// MW-2010-12-05: [[ Bug 9211 ]] If the height of the control >= 20 then render as a large progress bar.
	if (drawInfo.kind == kThemeProgressBar && drect.height >= 20)
		drawInfo.kind = kThemeLargeProgressBar;
    
    MCRectangle trect = winfo.type == WTHEME_TYPE_SLIDER ? MCU_reduce_rect(drect, 2) : drect;
	convertmctocgrect(trect, drawInfo.bounds);
    
	//FIX
	MCWidgetScrollBarInfo *sbinfo = (MCWidgetScrollBarInfo *)winfo.data;
    
    // MW-2014-04-10: [[ Bug 12027 ]] Calculate all the values in pixels (rather than relative to INT2_MAX). This
    //   means we know the size of the thumb (viewsize) and thus can work-around the HiDPI rendering glitch.
    //   (in HiDPI mode, the min size of thumb that will be rendered is < in non-HiDPI mode; however hittesting
    //    is not adjusted by the HITheme API).
    int t_size;
	if (drect.width > drect.height)
        t_size = drect . width;
    else
        t_size = drect . height;
    
    int t_viewsize, t_maxval, t_val;
    
    if (winfo . type == WTHEME_TYPE_PROGRESSBAR || winfo . type == WTHEME_TYPE_SLIDER)
    {
        t_maxval = t_size;
        if ((sbinfo -> endvalue - sbinfo -> startvalue) != 0.0)
            t_val = (sbinfo -> thumbpos - sbinfo -> startvalue) * t_maxval / (sbinfo -> endvalue - sbinfo -> startvalue);
        else
            t_maxval = 0, t_val = 0;
    }
    else
    {
        if ((sbinfo -> endvalue - sbinfo -> startvalue - sbinfo -> thumbsize) != 0.0)
        {
            t_viewsize = sbinfo -> thumbsize / (sbinfo -> endvalue - sbinfo -> startvalue) * t_size;
            t_maxval = t_size - t_viewsize;
            t_val = (sbinfo -> thumbpos - sbinfo -> startvalue) * t_maxval / (sbinfo -> endvalue - sbinfo -> startvalue - sbinfo -> thumbsize);
        }
        else
            t_maxval = 0, t_val = 0, t_viewsize = 0;
    }

	drawInfo.min = 0;
	drawInfo.max = t_maxval;
	drawInfo.value = t_val;
	
	if (drect.width > drect.height)
		drawInfo.attributes = kThemeTrackHorizontal | kThemeTrackShowThumb;
	else
		drawInfo.attributes = kThemeTrackShowThumb;
	// MW-2012-09-17: [[ Bug ]] If the app is inactive, then render the progressbar
	//   as such.
	if (winfo.state & WTHEME_STATE_DISABLED)
		drawInfo.enableState = kThemeTrackDisabled;
	else if (MCappisactive)
		drawInfo.enableState = kThemeTrackActive;
	else
		drawInfo.enableState = kThemeTrackInactive;
	switch (drawInfo.kind)
	{
	case kThemeProgressBar:
		// Set orientation based on dimensions: vertical if height > width
		// Note: Vertical is indicated by absence of kThemeTrackHorizontal flag
		if (drect.height > drect.width)
			drawInfo.attributes = 0;  // Vertical (no horizontal flag)
		else
			drawInfo.attributes = kThemeTrackHorizontal;
		drawInfo.trackInfo.progress.phase = 0;
		break;
	case kThemeSlider:
		if (drect.width > drect.height)
			drawInfo.bounds.size.height = (drect.y - 1 + 17) - drawInfo . bounds . origin . y;
		else
			drawInfo.bounds.size.width = drawInfo.bounds.origin.x + 17 - drawInfo . bounds . origin . x;
		if (winfo.attributes & WTHEME_ATT_SHOWVALUE)
			drawInfo.trackInfo.slider.thumbDir = kThemeThumbDownward;
		else
			drawInfo.trackInfo.slider.thumbDir = kThemeThumbPlain;
		if (!(winfo.state & WTHEME_STATE_DISABLED))
			getscrollbarpressedstate(winfo,drawInfo);
		break;

		// MW-2005-01-13: Fix bug 2523 - for some reason this was commented out in the recent
		//   past.
	case kThemeSmallScrollBar:
	case kThemeScrollBar:
		if (!(winfo.state & WTHEME_STATE_DISABLED))
			getscrollbarpressedstate(winfo,drawInfo);
		else
			drawInfo . trackInfo . scrollbar . pressState = 0;
			
        drawInfo.trackInfo.scrollbar.viewsize = t_viewsize;
		break;
	default:
		break;
	}
}

////////////////////////////////////////////////////////////////////////////////

static inline void assign(HIRect& d, Rect s)
{
	d . origin . x = s . left;
	d . origin . y = s . top;
	d . size . width = s . right - s . left;
	d . size . height = s . bottom - s . top;
}

static inline CGRect CGRectFromRect(Rect s)
{
	CGRect t_rect;
	t_rect . origin . x = s . left;
	t_rect . origin . y = s . top;
	t_rect . size . width = s . right - s . left;
	t_rect . size . height = s . bottom - s . top;
	return t_rect;
}

void MCMacDrawTheme(MCThemeDrawType p_type, MCThemeDrawInfo& p_info, CGContextRef p_context, bool p_hidpi)
{
	CGContextRef t_context = p_context;
	
	switch(p_type)
	{
		case THEME_DRAW_TYPE_SLIDER:
		{
			//-- tperry 29th May 2026
			// Use a real NSSlider control and pass it as its own inView:.
			// NSSliderCell requires a valid control view to resolve thumb
			// position, track geometry and enabled/pressed state.
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				NSRect t_frame = NSRectFromCGRect(p_info.slider.info.bounds);
				
				// Create slider with origin at (0,0) so the draw rect and
				// view bounds match exactly inside the off-screen image.
				NSSlider *t_slider = [[NSSlider alloc] initWithFrame:
				    NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height)];
				
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				if (MCPlatformGetSystemAppearanceIsDark())
					[t_slider setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
				else
					[t_slider setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
				
				[t_slider setMinValue:p_info.slider.info.min];
				[t_slider setMaxValue:p_info.slider.info.max];
				[t_slider setDoubleValue:p_info.slider.info.value];
				[t_slider setEnabled:(p_info.slider.info.enableState != kThemeTrackDisabled)];
				
				bool t_is_vertical = t_frame.size.height > t_frame.size.width;
				if (@available(macOS 10.10, *))
					[t_slider setVertical:t_is_vertical];
				
				// Draw into image then flip
				NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
				[t_image lockFocus];
				
				NSRect t_draw_rect = NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height);
				[[t_slider cell] drawWithFrame:t_draw_rect inView:t_slider];
				
				[t_image unlockFocus];
				
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:p_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				CGContextSaveGState(p_context);
				CGContextTranslateCTM(p_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(p_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0)
				            fromRect:NSZeroRect
				           operation:NSCompositingOperationSourceOver
				            fraction:1.0];
				
				CGContextRestoreGState(p_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
				[t_slider release];
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIThemeTrackDrawInfo t_info;
				
				t_info . version = 0;
				t_info . kind = p_info . slider . info . kind;
				t_info . bounds = p_info . slider . info . bounds;
				t_info . min = p_info . slider . info . min;
				t_info . max = p_info . slider . info . max;
				t_info . value = p_info . slider . info . value;
				t_info . reserved = 0;
				t_info . attributes = p_info . slider . info . attributes;
				t_info . enableState = p_info . slider . info . enableState;
				t_info . filler1 = 0;
				t_info . trackInfo . slider . thumbDir = p_info . slider . info . trackInfo . slider . thumbDir;
				t_info . trackInfo . slider . pressState = p_info . slider . info . trackInfo . slider . pressState;
				t_info . bounds . origin . y += 1;
				
				HIThemeDrawTrack(&t_info, NULL, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_SCROLLBAR:
		{
			// Skip drawing entirely if scrollbar is disabled (content doesn't need scrolling)
			if (p_info.scrollbar.info.enableState == kThemeTrackDisabled)
				break;
			
			//-- tperry 18th October 2025
			// Use modern NSScroller for proper dark mode and system appearance
			bool t_use_nsscroller = false;
			if (@available(macOS 10.14, *))
			{
				t_use_nsscroller = true;
				
				NSRect t_frame = NSRectFromCGRect(p_info.scrollbar.info.bounds);
				
				NSScroller *t_scroller = [[NSScroller alloc] initWithFrame:t_frame];
				
				// Set appearance
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				if (MCPlatformGetSystemAppearanceIsDark())
					[t_scroller setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
				else
					[t_scroller setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
				
				// Set scroller style (legacy or overlay)
				[t_scroller setScrollerStyle:NSScrollerStyleLegacy];
				
				// Set enabled state
				[t_scroller setEnabled:(p_info.scrollbar.info.enableState != kThemeTrackDisabled)];
				
				// Calculate knob proportion (thumb size)
				// Note: viewsize is in pixels, range is the scroll range
				// We need to convert viewsize from pixels to a proportion of the track
				CGFloat t_range = p_info.scrollbar.info.max - p_info.scrollbar.info.min;
				CGFloat t_viewsize_pixels = p_info.scrollbar.info.trackInfo.scrollbar.viewsize;
				CGFloat t_knob_proportion = 0.0;
				
				// Get the track size in pixels
				CGFloat t_track_size = (t_frame.size.height > t_frame.size.width) ? 
					t_frame.size.height : t_frame.size.width;
				
				// Check if content needs scrolling
				// When max <= min, there's no scrollable range - hide the thumb
				if (t_range <= 0 || t_viewsize_pixels <= 0)
				{
					// No scrolling needed - hide thumb by setting proportion to 0
					t_knob_proportion = 0.0;
				}
				else if (t_track_size > 0)
				{
					// Content needs scrolling - calculate knob proportion
					t_knob_proportion = t_viewsize_pixels / t_track_size;
					
					// Clamp to valid range [0.01, 1.0]
					if (t_knob_proportion < 0.01)
						t_knob_proportion = 0.01;
					else if (t_knob_proportion > 1.0)
						t_knob_proportion = 1.0;
				}
				else
				{
					// Invalid track size - hide thumb
					t_knob_proportion = 0.0;
				}
				
				// Set knob proportion
				[t_scroller setKnobProportion:t_knob_proportion];
				
				// Calculate and set double value (position)
				CGFloat t_double_value = 0.0;
				
				if (t_range > 0)
				{
					// Calculate the normalized position (0.0 to 1.0)
					CGFloat t_normalized = (p_info.scrollbar.info.value - p_info.scrollbar.info.min) / t_range;
					
					// The drawing context is flipped (line 1015), so we need to invert
					// vertical scrollbar positions: top (0.0) becomes bottom (1.0)
					bool t_is_vertical = t_frame.size.height > t_frame.size.width;
					if (t_is_vertical)
						t_double_value = 1.0 - t_normalized;
					else
						t_double_value = t_normalized;
				}
				// else: t_range <= 0 means no scrolling, thumb is hidden, position doesn't matter
				
				[t_scroller setDoubleValue:t_double_value];
				
				// Only draw scrollbar if content needs scrolling
				// When t_range <= 0 or viewsize <= 0, skip drawing entirely
				if (t_range > 0 && t_viewsize_pixels > 0)
				{
					// Draw scroller into an image first, then flip it
					NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
					[t_image lockFocus];
					
					// Draw both track and knob
					NSRect t_draw_rect = NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height);
					[t_scroller drawKnobSlotInRect:t_draw_rect highlight:NO];
					[t_scroller drawKnob];
					
					[t_image unlockFocus];
				
				// Now draw the image into the context (flipped)
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:t_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				// Flip and draw
				CGContextSaveGState(t_context);
				CGContextTranslateCTM(t_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(t_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0) 
				            fromRect:NSZeroRect 
				           operation:NSCompositingOperationSourceOver 
				            fraction:1.0];
				
				CGContextRestoreGState(t_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
				}
				
				[t_scroller release];
			}
			
			if (!t_use_nsscroller)
			{
				// Fallback to HITheme for older macOS
				HIThemeTrackDrawInfo t_info;
				
				t_info . version = 0;
				t_info . kind = p_info . scrollbar . info . kind;
				t_info . bounds = p_info . slider . info . bounds;
				t_info . min = p_info . scrollbar . info . min;
				t_info . max = p_info . scrollbar . info . max;
				t_info . value = p_info . scrollbar . info . value;
				t_info . reserved = 0;
				t_info . attributes = p_info . scrollbar . info . attributes;
				t_info . enableState = p_info . scrollbar . info . enableState;
				t_info . filler1 = 0;
				t_info . trackInfo . scrollbar . viewsize = p_info . scrollbar . info . trackInfo . scrollbar . viewsize;
				t_info . trackInfo . scrollbar . pressState = p_info . scrollbar . info . trackInfo . scrollbar . pressState;
				
				if (p_hidpi && t_info . trackInfo . scrollbar . viewsize < 18)
				{
					t_info . trackInfo . scrollbar . viewsize = 18;
				}
				
				HIThemeDrawTrack(&t_info, NULL, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_PROGRESS:
		{
			//-- tperry 18th October 2025
			// Use modern NSProgressIndicator for proper dark mode and system appearance
			bool t_use_nsprogress = false;
			if (@available(macOS 10.14, *))
			{
				t_use_nsprogress = true;
				
				NSRect t_frame = NSRectFromCGRect(p_info.progress.info.bounds);
				NSProgressIndicator *t_progress = [[NSProgressIndicator alloc] initWithFrame:t_frame];
				
				// Set appearance
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				if (MCPlatformGetSystemAppearanceIsDark())
					[t_progress setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
				else
					[t_progress setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
				
				// Set style (bar or spinning)
				[t_progress setStyle:NSProgressIndicatorStyleBar];
				[t_progress setIndeterminate:NO];
				
				// Set min/max/value
				[t_progress setMinValue:p_info.progress.info.min];
				[t_progress setMaxValue:p_info.progress.info.max];
				[t_progress setDoubleValue:p_info.progress.info.value];
				
				// Draw progress bar into an image first, then flip it
				NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
				[t_image lockFocus];
				
				// Draw into the image
				NSRect t_draw_rect = NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height);
				[t_progress drawRect:t_draw_rect];
				
				[t_image unlockFocus];
				
				// Now draw the image into the context (flipped)
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:t_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				// Flip and draw
				CGContextSaveGState(t_context);
				CGContextTranslateCTM(t_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(t_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0) 
				            fromRect:NSZeroRect 
				           operation:NSCompositingOperationSourceOver 
				            fraction:1.0];
				
				CGContextRestoreGState(t_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
				[t_progress release];
			}
			
			if (!t_use_nsprogress)
			{
				// Fallback to HITheme for older macOS
				HIThemeTrackDrawInfo t_info;
				
				t_info . version = 0;
				t_info . kind = p_info . progress . info . kind;
				t_info . bounds = p_info . slider . info . bounds;
				t_info . min = p_info . progress . info . min;
				t_info . max = p_info . progress . info . max;
				t_info . value = p_info . progress . info . value;
				t_info . reserved = 0;
				t_info . attributes = p_info . progress . info . attributes;
				t_info . enableState = p_info . progress . info . enableState;
				t_info . filler1 = 0;
				t_info . trackInfo . progress . phase = p_info . progress . info . trackInfo . progress . phase;
				
				HIThemeDrawTrack(&t_info, NULL, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_BUTTON:
		{
			//-- tperry 18th October 2025
			// Use modern NSButton/NSPopUpButton for proper dark mode and system appearance
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				// tperry 2nd November 2025
				// For push buttons, use the original destination rect (p_info.dest) instead of
				// HITheme-adjusted bounds. NSButton handles its own sizing, antialiasing, and shadows.
				// HITheme adjustments (insets/offsets) were causing incorrect sizing.
				NSRect t_frame;
				bool t_is_push_button = (p_info.button.info.kind == kThemePushButton);
				if (t_is_push_button)
				{
					CGRect t_dest_rect;
					convertmctocgrect(p_info.dest, t_dest_rect);
					t_frame = NSRectFromCGRect(t_dest_rect);
					
					// Adjust frame width to fill container properly:
					// - Expand width by 5px on each side (10px total)
					t_frame.origin.x -= 5;
					t_frame.size.width += 10;
				}
				else
				{
					// For other button types (checkboxes, radio, popups), use adjusted bounds
					t_frame = NSRectFromCGRect(p_info.button.bounds);
				}
				
				// Set appearance
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				NSAppearance *t_appearance = MCPlatformGetSystemAppearanceIsDark() ?
					[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua] :
					[NSAppearance appearanceNamed:NSAppearanceNameAqua];
				
				NSControl *t_control = nil;
				
				// Create appropriate control based on button kind
				if (p_info.button.info.kind == kThemeComboBox)
				{
					// Combo box
					NSComboBox *t_combo = [[NSComboBox alloc] initWithFrame:t_frame];
					[t_combo setStringValue:@""];
					t_control = t_combo;
				}
				else if (p_info.button.info.kind == kThemePopupButton)
				{
					// Option/Popup menu (shows popup arrow)
					NSPopUpButton *t_popup = [[NSPopUpButton alloc] initWithFrame:t_frame pullsDown:NO];
					[t_popup addItemWithTitle:@""];
					t_control = t_popup;
				}
				else if (p_info.button.info.kind == kThemeBevelButton && p_info.button.widget_type == WTHEME_TYPE_PULLDOWN)
				{
					// Pulldown menu (shows pulldown arrow)
					// Only WTHEME_TYPE_PULLDOWN should show the arrow, not WTHEME_TYPE_BEVELBUTTON (rectangle buttons)
					NSPopUpButton *t_popup = [[NSPopUpButton alloc] initWithFrame:t_frame pullsDown:YES];
					[t_popup addItemWithTitle:@""];
					t_control = t_popup;
				}
				else if (p_info.button.info.kind == kThemeBevelButton && p_info.button.widget_type == WTHEME_TYPE_BEVELBUTTON)
				{
					// Rectangle button (no arrow)
					// Use a regular NSButton with textured square bezel style
					NSButton *t_button = [[NSButton alloc] initWithFrame:t_frame];
					[t_button setButtonType:NSMomentaryPushInButton];
					[t_button setBezelStyle:NSBezelStyleTexturedSquare];
					[t_button setTitle:@""];
					t_control = t_button;
				}
				else if (p_info.button.info.kind == kThemeCheckBox || p_info.button.info.kind == kThemeSmallCheckBox)
				{
					// Checkbox
					NSButton *t_button = [[NSButton alloc] initWithFrame:t_frame];
					[t_button setButtonType:NSSwitchButton];
					[t_button setTitle:@""];  // No title, just the checkbox
					
					// Set state
					if (p_info.button.info.value == kThemeButtonOn)
						[t_button setState:NSOnState];
					else if (p_info.button.info.value == kThemeButtonMixed)
						[t_button setState:NSMixedState];
					else
						[t_button setState:NSOffState];
					
					t_control = t_button;
				}
				else if (p_info.button.info.kind == kThemeRadioButton || p_info.button.info.kind == kThemeSmallRadioButton)
				{
					// Radio button
					NSButton *t_button = [[NSButton alloc] initWithFrame:t_frame];
					[t_button setButtonType:NSRadioButton];
					[t_button setTitle:@""];  // No title, just the radio
					
					// tperry 7-12-2025 -- Set state based on value (ON/OFF), not pressed state
					// The pressed state (mouse down) should be handled by highlighted property
					if (p_info.button.info.value == kThemeButtonOn)
						[t_button setState:NSOnState];
					else
						[t_button setState:NSOffState];
					
					// tperry 7-12-2025 -- Handle pressed state (mouse down) separately from selected state
					// This fixes autohilite radio buttons showing as always hilited
					if (p_info.button.info.state == kThemeStatePressed)
						[t_button setHighlighted:YES];
					
					t_control = t_button;
				}
				else if (p_info.button.info.kind == kThemePushButton)
				{
					// Push button
					NSButton *t_button = [[NSButton alloc] initWithFrame:t_frame];
					[t_button setButtonType:NSMomentaryPushInButton];
					[t_button setBezelStyle:NSRoundedBezelStyle];
					[t_button setTitle:@""];
					
					// Check if this is a default button (has default adornment)
					if (p_info.button.info.adornment == kThemeAdornmentDefault)
					{
						[t_button setKeyEquivalent:@"\r"];  // Makes it the default button
					}
					
					// tperry 17-01-2026 -- Handle hilite/pressed state for standard buttons
					// When hilite is true (kThemeButtonOn) or button is pressed, show highlighted state
					// This makes the button slightly lighter (RGB 116,119,121 vs 93,96,96)
					if (p_info.button.info.value == kThemeButtonOn || 
					    p_info.button.info.state == kThemeStatePressed)
					{
						[t_button setHighlighted:YES];
					}
					
					t_control = t_button;
				}
				else
				{
					// Fallback to HITheme for unknown types
					t_use_modern = false;
				}
				
				if (t_use_modern && t_control != nil)
				{
					// Set common properties
					[t_control setAppearance:t_appearance];
					[t_control setEnabled:(p_info.button.info.state != kThemeStateInactive)];
					
					// Create a flipped image to draw the control correctly
					NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
					[t_image lockFocus];
					
					// Draw into the image with correct orientation
					NSRect t_draw_rect = NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height);
					[[t_control cell] drawWithFrame:t_draw_rect inView:nil];
					
					[t_image unlockFocus];
					
					// Now draw the image into the context (flipped)
					NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:t_context flipped:NO];
					[NSGraphicsContext saveGraphicsState];
					[NSGraphicsContext setCurrentContext:t_ns_context];
					
					// Flip and draw
					CGContextSaveGState(t_context);
					CGContextTranslateCTM(t_context, 0, t_frame.origin.y + t_frame.size.height);
					CGContextScaleCTM(t_context, 1.0, -1.0);
					
					[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0) 
					            fromRect:NSZeroRect 
					           operation:NSCompositingOperationSourceOver 
					            fraction:1.0];
					
					CGContextRestoreGState(t_context);
					[NSGraphicsContext restoreGraphicsState];
					[t_image release];
					[t_control release];
				}
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme
				HIThemeDrawButton(&p_info.button.bounds, &p_info.button.info, t_context, kHIThemeOrientationNormal, NULL);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_GROUP:
		{
			//-- tperry 27th May 2026
			// Use modern NSBox for proper dark mode and system appearance
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				NSRect t_frame = NSRectFromCGRect(CGRectFromRect(p_info.group.bounds));
				
				// Draw into image then flip
				NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
				[t_image lockFocus];
				
				NSRect t_draw_rect = NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height);
				
				// tperry 28-5-2026
				// Only fill background when is_filled is true (GROUP_FILL).
				// When is_filled is false (GROUP_FRAME), we must NOT fill
				// because this is drawn on top of already-rendered child controls.
				if (p_info.group.is_filled)
				{
					NSBezierPath *t_fill_path = [NSBezierPath bezierPathWithRect:t_draw_rect];
					[[NSColor controlBackgroundColor] setFill];
					[t_fill_path fill];
				}
				
				// tperry 29-5-2026
				// Draw 3D bevel border: dark top/right, light bottom/left
				// (matching classic HITheme recessed group box appearance)
				NSBezierPath *t_shadow_path = [NSBezierPath bezierPath];
				[t_shadow_path moveToPoint:NSMakePoint(0.5, 0.5)];
				[t_shadow_path lineToPoint:NSMakePoint(t_draw_rect.size.width - 0.5, 0.5)];
				[t_shadow_path moveToPoint:NSMakePoint(t_draw_rect.size.width - 0.5, 0.5)];
				[t_shadow_path lineToPoint:NSMakePoint(t_draw_rect.size.width - 0.5, t_draw_rect.size.height - 0.5)];
				[t_shadow_path setLineWidth:1.0];
				[[NSColor controlShadowColor] setStroke];
				[t_shadow_path stroke];
				
				NSBezierPath *t_highlight_path = [NSBezierPath bezierPath];
				[t_highlight_path moveToPoint:NSMakePoint(0.5, t_draw_rect.size.height - 0.5)];
				[t_highlight_path lineToPoint:NSMakePoint(t_draw_rect.size.width - 0.5, t_draw_rect.size.height - 0.5)];
				[t_highlight_path moveToPoint:NSMakePoint(0.5, 0.5)];
				[t_highlight_path lineToPoint:NSMakePoint(0.5, t_draw_rect.size.height - 0.5)];
				[t_highlight_path setLineWidth:1.0];
				[[NSColor controlHighlightColor] setStroke];
				[t_highlight_path stroke];
				
				[t_image unlockFocus];
				
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:p_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				CGContextSaveGState(p_context);
				CGContextTranslateCTM(p_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(p_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0)
				            fromRect:NSZeroRect
				           operation:NSCompositingOperationSourceOver
				            fraction:1.0];
				
				CGContextRestoreGState(p_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_rect;
				HIThemeGroupBoxDrawInfo t_info;
				
				assign(t_rect, p_info . group . bounds);
				
				t_info . version = 0;
				t_info . state = p_info . group . state;
				t_info . kind = p_info . group . is_secondary ? kHIThemeGroupBoxKindSecondary : kHIThemeGroupBoxKindPrimary;
				
				HIThemeDrawGroupBox(&t_rect, &t_info, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_FRAME:
		{
			//-- tperry 27th May 2026
			// Use modern NSBox / NSBezierPath for proper dark mode frame rendering
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				NSRect t_frame = NSRectFromCGRect(CGRectFromRect(p_info.frame.bounds));
				
				// Draw frame using NSBezierPath for consistent appearance
				NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
				[t_image lockFocus];
				
				NSBezierPath *t_path = [NSBezierPath bezierPathWithRect:NSMakeRect(0.5, 0.5,
					t_frame.size.width - 1.0, t_frame.size.height - 1.0)];
				[t_path setLineWidth:1.0];
				
				// Use system colors for dark/light mode
				if (p_info.frame.is_list)
					[[NSColor separatorColor] setStroke];
				else
					[[NSColor controlColor] setStroke];
				
				[t_path stroke];
				
				[t_image unlockFocus];
				
				// Draw into context (flipped)
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:p_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				CGContextSaveGState(p_context);
				CGContextTranslateCTM(p_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(p_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0)
				            fromRect:NSZeroRect
				           operation:NSCompositingOperationSourceOver
				            fraction:1.0];
				
				CGContextRestoreGState(p_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_bounds;
				HIThemeFrameDrawInfo t_info;
				
				assign(t_bounds, p_info . frame . bounds);
				
				t_info . version = 0;
				t_info . kind = p_info . frame . is_list ? kHIThemeFrameListBox : kHIThemeFrameTextFieldSquare;
				t_info . state = p_info . frame . state;
				t_info . isFocused = false;
				
				HIThemeDrawFrame(&t_bounds, &t_info, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_TAB:
		{
			//-- tperry 29th May 2026
			// Direct NSBezierPath drawing for tab buttons.
			// NSSegmentedControl cannot render correctly in a headless
			// NSImage context because it requires a window/view hierarchy
			// for its layer-backed cell rendering. NSImage lockFocus also
			// conflicts with the bitmap context that MCThemeDraw creates,
			// so we draw NSBezierPath directly via NSGraphicsContext.
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				CGRect t_cgrect = CGRectMake(p_info.tab.bounds.left, p_info.tab.bounds.top,
					p_info.tab.bounds.right - p_info.tab.bounds.left,
					p_info.tab.bounds.bottom - p_info.tab.bounds.top);
				NSRect t_frame = NSRectFromCGRect(t_cgrect);
				
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				bool t_is_dark = MCPlatformGetSystemAppearanceIsDark();
				
				bool t_is_selected = p_info.tab.is_hilited;
				bool t_is_disabled = p_info.tab.is_disabled;
				bool t_is_pressed = p_info.tab.is_pressed;
				bool t_is_first = p_info.tab.is_first;
				bool t_is_last = p_info.tab.is_last;
				
				// Draw directly into the bitmap context via NSGraphicsContext.
				// NSImage lockFocus produces black/transparent output for tabs,
				// likely because the nested bitmap context conflicts with the
				// temporary image context. Drawing directly avoids NSImage.
				[NSGraphicsContext saveGraphicsState];
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:t_context flipped:YES];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				NSRect t_draw_rect = NSMakeRect(t_frame.origin.x, t_frame.origin.y, t_frame.size.width, t_frame.size.height);
				
				// Button background path — rounded rect, position-aware corners
				CGFloat t_radius = 4.0;
				NSBezierPath *t_bg;
				
				if (t_is_first && t_is_last)
				{
					// Single tab — round all corners
					t_bg = [NSBezierPath bezierPathWithRoundedRect:t_draw_rect xRadius:t_radius yRadius:t_radius];
				}
				else if (t_is_first)
				{
					// First tab — round left corners, square right edge
					t_bg = [NSBezierPath bezierPath];
					[t_bg moveToPoint:NSMakePoint(t_draw_rect.origin.x + t_radius, t_draw_rect.origin.y)];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y)];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y + t_draw_rect.size.height)];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_radius, t_draw_rect.origin.y + t_draw_rect.size.height)];
					[t_bg appendBezierPathWithArcFromPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y + t_draw_rect.size.height)
					                             toPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y + t_draw_rect.size.height - t_radius)
					                              radius:t_radius];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y + t_radius)];
					[t_bg appendBezierPathWithArcFromPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y)
					                             toPoint:NSMakePoint(t_draw_rect.origin.x + t_radius, t_draw_rect.origin.y)
					                              radius:t_radius];
					[t_bg closePath];
				}
				else if (t_is_last)
				{
					// Last tab — round right corners, square left edge
					t_bg = [NSBezierPath bezierPath];
					[t_bg moveToPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y)];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width - t_radius, t_draw_rect.origin.y)];
					[t_bg appendBezierPathWithArcFromPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y)
					                             toPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y + t_radius)
					                              radius:t_radius];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y + t_draw_rect.size.height - t_radius)];
					[t_bg appendBezierPathWithArcFromPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width, t_draw_rect.origin.y + t_draw_rect.size.height)
					                             toPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width - t_radius, t_draw_rect.origin.y + t_draw_rect.size.height)
					                              radius:t_radius];
					[t_bg lineToPoint:NSMakePoint(t_draw_rect.origin.x, t_draw_rect.origin.y + t_draw_rect.size.height)];
					[t_bg closePath];
				}
				else
				{
					// Middle tab — square left/right edges, rounded top/bottom
					t_bg = [NSBezierPath bezierPathWithRoundedRect:t_draw_rect xRadius:1.0 yRadius:1.0];
				}
				
				// Fill background based on state
				if (t_is_disabled)
				{
					if (t_is_dark)
						[[NSColor colorWithWhite:0.22 alpha:1.0] setFill];
					else
						[[NSColor colorWithWhite:0.90 alpha:1.0] setFill];
				}
				else if (t_is_selected)
				{
					if (t_is_dark)
						[[NSColor colorWithWhite:0.30 alpha:1.0] setFill];
					else
						[[NSColor controlBackgroundColor] setFill];
				}
				else if (t_is_pressed)
				{
					if (t_is_dark)
						[[NSColor colorWithWhite:0.28 alpha:1.0] setFill];
					else
						[[NSColor colorWithWhite:0.82 alpha:1.0] setFill];
				}
				else
				{
					// Unselected, not pressed
					if (t_is_dark)
						[[NSColor colorWithWhite:0.25 alpha:1.0] setFill];
					else
						[[NSColor colorWithWhite:0.88 alpha:1.0] setFill];
				}
				[t_bg fill];
				
				// Border stroke
				if (t_is_dark)
					[[NSColor colorWithWhite:0.35 alpha:1.0] setStroke];
				else
					[[NSColor separatorColor] setStroke];
				[t_bg setLineWidth:1.0];
				[t_bg stroke];
				
				// Selected tab accent bottom border (modern macOS look)
				if (t_is_selected && !t_is_disabled)
				{
					NSBezierPath *t_accent = [NSBezierPath bezierPath];
					[t_accent moveToPoint:NSMakePoint(t_draw_rect.origin.x + 2.0, t_draw_rect.origin.y + 1.0)];
					[t_accent lineToPoint:NSMakePoint(t_draw_rect.origin.x + t_draw_rect.size.width - 2.0, t_draw_rect.origin.y + 1.0)];
					[t_accent setLineWidth:2.5];
					[t_accent setLineCapStyle:NSLineCapStyleRound];
					if (@available(macOS 10.14, *))
						[[NSColor controlAccentColor] setStroke];
					else
						[[NSColor systemBlueColor] setStroke];
					[t_accent stroke];
				}
				
				[NSGraphicsContext restoreGraphicsState];
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_bounds;
				HIThemeTabDrawInfo t_info;
				
				assign(t_bounds, p_info . tab . bounds);
				
				t_info . version = 1;
				t_info . direction = kThemeTabNorth;
				t_info . size = kHIThemeTabSizeNormal;
				if (p_info . tab . is_hilited)
					t_info . style = (p_info . tab . is_disabled ? kThemeTabFrontInactive : kThemeTabFront);
				else if (p_info . tab . is_disabled)
					t_info . style = kThemeTabNonFrontInactive;
				else
					t_info . style = (p_info . tab . is_pressed ? kThemeTabNonFrontPressed : kThemeTabNonFront);
				t_info . adornment = kHIThemeTabAdornmentNone;
				t_info . kind = kHIThemeTabKindNormal;
				if (p_info . tab . is_first && p_info . tab . is_last)
					t_info . position = kHIThemeTabPositionOnly;
				else if (p_info . tab . is_first)
				{
					t_info . adornment = kHIThemeTabAdornmentTrailingSeparator;
					t_info . position = kHIThemeTabPositionFirst;
				}
				else if (p_info . tab . is_last)
					t_info . position = kHIThemeTabPositionLast;
				else
				{
					t_info . adornment = kHIThemeTabAdornmentTrailingSeparator;
					t_info . position = kHIThemeTabPositionMiddle;
				}
				
				HIThemeDrawTab(&t_bounds, &t_info, t_context, kHIThemeOrientationNormal, NULL);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_TAB_PANE:
		{
			//-- tperry 27th May 2026
			// Use modern NSBox for proper dark mode tab pane rendering
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				CGRect t_cgrect = CGRectFromRect(p_info.tab_pane.bounds);
				t_cgrect.origin.y += 1;
				NSRect t_frame = NSRectFromCGRect(t_cgrect);
				
				extern bool MCPlatformGetSystemAppearanceIsDark(void);
				bool t_is_dark = MCPlatformGetSystemAppearanceIsDark();
				
				// Draw directly to the bitmap context (already in screen coords
				// thanks to MCThemeDraw's TranslateCTM + ScaleCTM setup).
				if (t_is_dark)
					CGContextSetFillColorWithColor(p_context, [NSColor colorWithWhite:0.20 alpha:1.0].CGColor);
				else
					CGContextSetFillColorWithColor(p_context, [NSColor controlBackgroundColor].CGColor);
				CGContextFillRect(p_context, NSRectToCGRect(t_frame));
				
				if (t_is_dark)
					CGContextSetStrokeColorWithColor(p_context, [NSColor colorWithWhite:0.35 alpha:1.0].CGColor);
				else
					CGContextSetStrokeColorWithColor(p_context, [NSColor separatorColor].CGColor);
				CGContextSetLineWidth(p_context, 1.0);
				CGContextStrokeRect(p_context, NSRectToCGRect(t_frame));
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_bounds;
				HIThemeTabPaneDrawInfo t_info;
				
				p_info . tab_pane . bounds . top += 1;
				assign(t_bounds, p_info . tab_pane . bounds);
				
				t_info . version = 1;
				t_info . state = p_info . tab_pane . state;
				t_info . direction = kThemeTabNorth;
				t_info . size = kHIThemeTabSizeNormal;
				t_info . kind = kHIThemeTabKindNormal;
				t_info . adornment = kHIThemeTabPaneAdornmentNormal;
				
				HIThemeDrawTabPane(&t_bounds, &t_info, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_BACKGROUND:
		{
			//-- tperry 27th May 2026
			// Use modern NSColor fill for proper dark mode background
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				NSRect t_frame = NSRectFromCGRect(CGRectFromRect(p_info.background.bounds));
				
				NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
				[t_image lockFocus];
				
				// Fill with system background color (approximates metal look)
				[[NSColor windowBackgroundColor] setFill];
				NSRectFill(NSMakeRect(0, 0, t_frame.size.width, t_frame.size.height));
				
				[t_image unlockFocus];
				
				// Draw into context (flipped)
				NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:p_context flipped:NO];
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:t_ns_context];
				
				CGContextSaveGState(p_context);
				CGContextTranslateCTM(p_context, 0, t_frame.origin.y + t_frame.size.height);
				CGContextScaleCTM(p_context, 1.0, -1.0);
				
				[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0)
				            fromRect:NSZeroRect
				           operation:NSCompositingOperationSourceOver
				            fraction:1.0];
				
				CGContextRestoreGState(p_context);
				[NSGraphicsContext restoreGraphicsState];
				[t_image release];
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_bounds;
				HIThemeBackgroundDrawInfo t_info;
				
				assign(t_bounds, p_info . background . bounds);
				
				t_info . version = 0;
				t_info . state = p_info . background . state;
				t_info . kind = kThemeBackgroundMetal;
				
				HIThemeDrawBackground(&t_bounds, &t_info, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_FOCUS_RECT:
		{
			//-- tperry 27th May 2026
			// Use modern NSBezierPath for proper dark mode focus ring
			bool t_use_modern = false;
			if (@available(macOS 10.14, *))
			{
				t_use_modern = true;
				
				NSRect t_frame = NSRectFromCGRect(CGRectFromRect(p_info.focus_rect.bounds));
				
				if (p_info.focus_rect.focused)
				{
					NSImage *t_image = [[NSImage alloc] initWithSize:t_frame.size];
					[t_image lockFocus];
					
					// Draw focus ring using system accent color
					NSBezierPath *t_path = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5, 1.5,
						t_frame.size.width - 3.0, t_frame.size.height - 3.0)];
					[t_path setLineWidth:2.0];
					[[NSColor keyboardFocusIndicatorColor] setStroke];
					[t_path stroke];
					
					[t_image unlockFocus];
					
					// Draw into context (flipped)
					NSGraphicsContext *t_ns_context = [NSGraphicsContext graphicsContextWithCGContext:p_context flipped:NO];
					[NSGraphicsContext saveGraphicsState];
					[NSGraphicsContext setCurrentContext:t_ns_context];
					
					CGContextSaveGState(p_context);
					CGContextTranslateCTM(p_context, 0, t_frame.origin.y + t_frame.size.height);
					CGContextScaleCTM(p_context, 1.0, -1.0);
					
					[t_image drawAtPoint:NSMakePoint(t_frame.origin.x, 0)
					            fromRect:NSZeroRect
					           operation:NSCompositingOperationSourceOver
					            fraction:1.0];
					
					CGContextRestoreGState(p_context);
					[NSGraphicsContext restoreGraphicsState];
					[t_image release];
				}
			}
			
			if (!t_use_modern)
			{
				// Fallback to HITheme for older macOS
				HIRect t_bounds;
				assign(t_bounds, p_info . focus_rect . bounds);
				
				HIThemeDrawFocusRect(&t_bounds, p_info . focus_rect . focused, t_context, kHIThemeOrientationNormal);
			}
		}
			break;
			
		case THEME_DRAW_TYPE_MENU:
		case THEME_DRAW_TYPE_GTK:
			MCUnreachable();
			break;
	}
}

////////////////////////////////////////////////////////////////////////////////

// MW-2011-09-14: [[ Bug 9719 ]] Override to return the actual sizeof(MCThemeDrawInfo).
uint32_t MCNativeTheme::getthemedrawinfosize(void)
{
	return sizeof(MCThemeDrawInfo);
}

bool MCNativeTheme::drawfocusborder(MCContext *p_context, const MCRectangle& p_dirty, const MCRectangle& p_rect)
{
	MCRectangle trect;
	trect = MCU_reduce_rect(p_rect, 3);
	MCThemeDrawInfo t_info;
	t_info.dest = p_rect;
	//MCScreenDC *pms = (MCScreenDC *)MCscreen;
	t_info . focus_rect . focused = True;
	t_info . focus_rect . bounds = MCRectToMacRect(trect);
	p_context -> drawtheme(THEME_DRAW_TYPE_FOCUS_RECT, &t_info);
	
	return true;
}

bool MCNativeTheme::drawmetalbackground(MCContext *p_context, const MCRectangle& p_dirty, const MCRectangle& p_rect, MCObject *p_object)
{
	if (p_context -> gettype() == CONTEXT_TYPE_PRINTER)
		return false;

	uint2 i;
	if (p_object -> getcindex(DI_BACK, i) || p_object -> getpindex(DI_BACK, i))
		return false;

	MCThemeDrawInfo p_info;
	p_info.dest = p_rect;
	p_info . background . bounds . left = p_dirty . x;
	p_info . background . bounds . top = p_dirty . y;
	p_info . background . bounds . right = p_dirty . x + p_dirty . width;
	p_info . background . bounds . bottom = p_dirty . y + p_dirty . height;
	
	Window t_window;
	t_window = p_object -> getstack() -> getwindow();
    p_info . background . state = kThemeStateActive;

	MCRectangle t_clip;
	t_clip = p_context -> getclip();
	
	p_context->save();
	p_context->cliprect(MCU_intersect_rect(p_rect, p_dirty));
	p_context -> drawtheme(THEME_DRAW_TYPE_BACKGROUND, &p_info);

	p_context->restore();
	
	return true;
}

////////////////////////////////////////////////////////////////////////////////

MCTheme *MCThemeCreateNative(void)
{
	return new MCNativeTheme;
}

////////////////////////////////////////////////////////////////////////////////

extern CGBitmapInfo MCGPixelFormatToCGBitmapInfo(uint32_t p_pixel_format, bool p_alpha);
extern bool MCMacPlatformGetImageColorSpace(CGColorSpaceRef &r_colorspace);

// IM-2014-01-24: [[ HiDPI ]] Factor out creation of CGBitmapContext for MCImageBitmap
bool MCOSXCreateCGContextForBitmap(MCImageBitmap *p_bitmap, CGContextRef &r_context)
{
	bool t_success;
	t_success = true;
	
	CGContextRef t_cgcontext = nil;
	CGColorSpaceRef t_colorspace = nil;
	
	t_success = MCMacPlatformGetImageColorSpace(t_colorspace);
	
	if (t_success)
	{
		// IM-2013-08-21: [[ RefactorGraphics ]] Refactor CGImage creation code to be pixel-format independent
		CGBitmapInfo t_bitmap_info;
		t_bitmap_info = MCGPixelFormatToCGBitmapInfo(kMCGPixelFormatNative, true);
		
		t_success = nil != (t_cgcontext = CGBitmapContextCreate(p_bitmap->data, p_bitmap->width, p_bitmap->height, 8, p_bitmap->stride, t_colorspace, t_bitmap_info));
	}
	
	if (t_colorspace != nil)
		CGColorSpaceRelease(t_colorspace);
	
	
	if (t_success)
		r_context = t_cgcontext;
	
	return t_success;
}
		

bool MCThemeDraw(MCGContextRef p_context, MCThemeDrawType p_type, MCThemeDrawInfo *p_info_ptr)
{
	bool t_success = true;
	
	MCImageBitmap *t_bitmap = nil;
	CGContextRef t_cgcontext = nil;
	MCRectangle t_rect;

	t_rect = p_info_ptr->dest;
	
	MCGAffineTransform t_transform;
	t_transform = MCGContextGetDeviceTransform(p_context);
	
	CGAffineTransform t_cg_transform;
	t_cg_transform = CGAffineTransformIdentity;
	
	MCGRectangle t_dst;
	uint32_t t_width, t_height;
	int32_t t_x, t_y;
	
	// IM-2014-01-23: [[ HiDPI ]] OSX theme rendering only supports 2x scale transform,
	// so limit transform scale to 1.0 or 2.0
	MCGFloat t_ui_scale;
	t_ui_scale = 1.0;
	
	if (MCGAffineTransformIsRectangular(t_transform))
	{
		MCGFloat t_transform_scale;
		t_transform_scale = MCGAffineTransformGetEffectiveScale(t_transform);
		
		if (t_transform_scale > 1.0)
			t_ui_scale = 2.0;
	}
	
	// IM-2014-01-20: [[ HiDPI ]] Improve scaled UI appearance by rendering to the temporary bitmap with the scale transform.
	if (t_ui_scale != 1.0)
	{
		t_cg_transform = CGAffineTransformMakeScale(t_ui_scale, t_ui_scale);
		
		// calculate scaled destination rect and device buffer size & origin
		MCGRectangle t_scaled_bounds;
		t_scaled_bounds = MCGRectangleScale(MCRectangleToMCGRectangle(t_rect), t_ui_scale);
		
		MCRectangle t_int_bounds;
		t_int_bounds = MCGRectangleGetIntegerBounds(t_scaled_bounds);
		
		t_width = t_int_bounds.width;
		t_height = t_int_bounds.height;
		
		t_x = t_int_bounds.x;
		t_y = t_int_bounds.y;
		
		// Caculate new destination rect for temporary image
		t_dst = MCGRectangleScale(MCRectangleToMCGRectangle(t_int_bounds), 1 / t_ui_scale);
	}
	else
	{
		// render at normal size & draw into target rect
		t_x = t_rect.x;
		t_y = t_rect.y;
		
		t_width = t_rect.width;
		t_height = t_rect.height;
		
		t_dst = MCGRectangleMake(t_x, t_y, t_width, t_height);
	}
	
	t_success = MCImageBitmapCreate(t_width, t_height, t_bitmap);
	
	if (t_success)
	{
		MCImageBitmapClear(t_bitmap);
		
		t_success = MCOSXCreateCGContextForBitmap(t_bitmap, t_cgcontext);
	}
	
	if (t_success)
	{
		// Invert y-axis origin to top-left of bitmap
		CGContextTranslateCTM(t_cgcontext, 0, (CGFloat)t_bitmap->height);
		CGContextScaleCTM(t_cgcontext, 1.0, -1.0);
		
		// Relocate origin to top-left of destination rect
		CGContextTranslateCTM(t_cgcontext, -(CGFloat)t_x, -(CGFloat)t_y);
		
		// Apply UI scaling transform
		CGContextConcatCTM(t_cgcontext, t_cg_transform);
		
		MCMacDrawTheme(p_type, *p_info_ptr, t_cgcontext, t_ui_scale > 1.0);
		
		CGContextRelease(t_cgcontext);
		
		MCGRaster t_raster;
		t_raster.width = t_bitmap->width;
		t_raster.height = t_bitmap->height;
		t_raster.pixels = t_bitmap->data;
		t_raster.stride = t_bitmap->stride;
		t_raster.format = kMCGRasterFormat_ARGB;
		
		// MM-2013-12-16: [[ Bug 11567 ]] Use bilinear filter when drawing theme elements.
        // MM-2014-01-27: [[ UpdateImageFilters ]] Updated to use new libgraphics image filter types (was bilinear).
		MCGContextDrawPixels(p_context, t_raster, t_dst, kMCGImageFilterMedium);
	}
	
	if (t_bitmap != nil)
		MCImageFreeBitmap(t_bitmap);
		
	return t_success;
}

////////////////////////////////////////////////////////////////////////////////
