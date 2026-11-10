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

#include "graphics.h"
#include "graphics-internal.h"

#include <pango/pangoft2.h>
#include <pango/pangofc-fontmap.h>
#include <glib.h>
#include <pthread.h>

////////////////////////////////////////////////////////////////////////////////

// MW-2013-12-19: [[ Bug 11559 ]] If 'false' after initializing we have no
//   text support as the needed libs are not available.
static bool s_has_text_support = false;

////////////////////////////////////////////////////////////////////////////////

extern "C" int initialise_weak_link_pango();
extern "C" int initialise_weak_link_pangoft2();
extern "C" int initialise_weak_link_glib();
extern "C" int initialise_weak_link_gobject();

extern void MCCStringFree(char *p_string);
extern bool MCCStringFromUnicodeSubstring(const unichar_t *p_chars, uint32_t p_char_count, char*& r_string);

////////////////////////////////////////////////////////////////////////////////

static inline MCGRectangle MCGRectangleFromPangoRectangle(const PangoRectangle &p_rect)
{
	return MCGRectangleMake(p_rect.x / (MCGFloat)PANGO_SCALE, p_rect.y / (MCGFloat)PANGO_SCALE, p_rect.width / (MCGFloat)PANGO_SCALE, p_rect.height / (MCGFloat)PANGO_SCALE);
}

static inline PangoMatrix MCGAffineTransformToPangoMatrix(const MCGAffineTransform &p_transform)
{
	PangoMatrix t_matrix;
	t_matrix . xx = p_transform . a;
	t_matrix . yx = p_transform . b;
	t_matrix . xy = p_transform . c;
	t_matrix . yy = p_transform . d;
	t_matrix . x0 = p_transform . tx;
	t_matrix . y0 = p_transform . ty;
	return t_matrix;
}

////////////////////////////////////////////////////////////////////////////////

static PangoFontMap *s_font_map = NULL;
static PangoContext *s_pango = NULL;
static PangoLayout *s_layout = NULL;

// OXT-Beyond: drawing leaves its transform on the shared context; measuring
// resets it so text is measured the same whatever was drawn last.
static void lnx_pango_reset_matrix(void)
{
	if (s_pango == NULL)
		return;

	PangoMatrix t_identity;
	t_identity = MCGAffineTransformToPangoMatrix(MCGAffineTransformMakeIdentity());
	pango_context_set_matrix(s_pango, &t_identity);
}

// OXT-Beyond: the fonts a script loads ("start using font file") are in a
// new fontconfig configuration that the engine makes current (lnxdc.cpp,
// MCLinuxFontConfigLoad). Pango's font map takes the configuration current
// when it is first used and keeps it (Pango 1.48 and later), so a font
// loaded after that was never drawn: Pango drew the fallback face. Before
// it lays text out, the font map takes the current configuration when it
// has changed. The font map holds a reference to the configuration
// remembered here, so the address cannot be freed and reused while it is
// remembered. pango_fc_font_map_set_config is Pango 1.38's (2015), weak
// linked as optional (engine/src/linux.stubs): without it nothing changes.
typedef void (*pango_fc_font_map_set_configPTR)(PangoFcFontMap *fcfontmap, FcConfig *fcconfig);
extern "C" pango_fc_font_map_set_configPTR pango_fc_font_map_set_config_ptr;
static FcConfig *s_font_config = NULL;

static void lnx_pango_follow_font_config(void)
{
	if (s_font_map == NULL || pango_fc_font_map_set_config_ptr == NULL)
		return;

	FcConfig *t_current;
	t_current = FcConfigGetCurrent();
	if (t_current == NULL || t_current == s_font_config)
		return;

	pango_fc_font_map_set_config_ptr((PangoFcFontMap *) s_font_map, t_current);
	s_font_config = t_current;
}

// OXT-Beyond: [[ HiDPI ]] For a transform that scales uniformly, without
// rotation or skew, and not by 1: a copy of the font at the scaled size (the
// caller frees it) and the scale. Else nil, and the text takes the old path.
// Drawing and measuring both use it, so text is measured at the size it is
// drawn: Pango rounds each glyph's advance to a whole pixel, so the font at
// twice the size is not twice as wide, and a width measured at the unscaled
// size put the caret and the next run of text up to a point per character
// away from the glyphs drawn at the scaled size.
static PangoFontDescription *lnx_pango_copy_scaled_font(const MCGFont &p_font, const MCGAffineTransform &p_transform, MCGFloat &r_scale)
{
	if (p_transform . b != 0 || p_transform . c != 0 ||
		p_transform . a != p_transform . d || p_transform . a <= 0 || p_transform . a == 1)
		return nil;

	PangoFontDescription *t_scaled_font;
	t_scaled_font = pango_font_description_copy((PangoFontDescription *) p_font . fid);
	if (t_scaled_font == nil)
		return nil;

	r_scale = p_transform . a;
	if (pango_font_description_get_size_is_absolute(t_scaled_font))
		pango_font_description_set_absolute_size(t_scaled_font, pango_font_description_get_size(t_scaled_font) * r_scale);
	else
		pango_font_description_set_size(t_scaled_font, gint(pango_font_description_get_size(t_scaled_font) * r_scale + 0.5));

	return t_scaled_font;
}

static bool lnx_pango_objects_initialize()
{
    bool t_success;
	t_success = true;
    
    if (t_success)
    {
        s_font_map = pango_ft2_font_map_new();
        t_success = s_font_map != NULL;
    }
    
	if (t_success)
    {
        s_pango = pango_ft2_font_map_create_context((PangoFT2FontMap *) s_font_map);
        t_success = s_pango != NULL;
    }
	
	if (t_success)
    {
        s_layout = pango_layout_new(s_pango);
        t_success = s_layout != NULL;
    }
    
	return t_success;
}

static bool lnx_pango_initialize(void)
{
	bool t_success;
	t_success = true;
	
	// Note: these libraries should be listed in dependency order
	if (t_success)
		t_success =
			initialise_weak_link_glib() != 0 &&
			initialise_weak_link_gobject() != 0 &&
			initialise_weak_link_pango() != 0 &&
			initialise_weak_link_pangoft2() != 0;
			
    
    if (t_success)
        t_success = lnx_pango_objects_initialize();
	
	return t_success;
}

static void lnx_pango_finalize(void)
{
    if (s_layout != NULL)
        g_object_unref(s_layout);
    
    if (s_pango != NULL)
        g_object_unref(s_pango);

    if (s_font_map != NULL)
        g_object_unref(s_font_map);
}

////////////////////////////////////////////////////////////////////////////////

void MCGPlatformInitialize(void)
{
	s_has_text_support = lnx_pango_initialize();
}

void MCGPlatformFinalize(void)
{
	lnx_pango_finalize();
}
////////////////////////////////////////////////////////////////////////////////

void MCGContextDrawPlatformText(MCGContextRef self, const unichar_t *p_text, uindex_t p_length, MCGPoint p_location, const MCGFont &p_font, bool p_rtl)
{
	// TODO: RTL
    
    // MW-2013-12-19: [[ Bug 11559 ]] Do nothing if no text support.
	if (!s_has_text_support)
		return;
	
	if (!MCGContextIsValid(self))
		return;	
	
	lnx_pango_follow_font_config();

	bool t_success;
	t_success = true;

	char *t_text;
	t_text = nil;
	if (t_success)
		t_success = MCCStringFromUnicodeSubstring(p_text, p_length / 2, t_text);
	
	MCGAffineTransform t_transform;
	t_transform = MCGContextGetDeviceTransform(self);

	// OXT-Beyond: [[ HiDPI ]] Pango's FT2 renderer scales the glyphs of a font
	// it loaded for a scaled context matrix a second time, so text drawn at a
	// scale (a HiDPI window's backing scale, or a stack's scaleFactor) came
	// out at twice its size, overlapping and cut off. For a scale without
	// rotation, lay the text out in device pixels instead: the font at the
	// scaled size, and a matrix that only translates. Text drawn at a scale
	// of 1 (or rotated, or skewed) takes the path it always took.
	MCGPoint t_location;
	t_location = p_location;
	PangoFontDescription *t_scaled_font;
	t_scaled_font = nil;
	MCGFloat t_scale;
	t_scale = 1;
	if (t_success)
		t_scaled_font = lnx_pango_copy_scaled_font(p_font, t_transform, t_scale);
	if (t_scaled_font != nil)
	{
		t_transform = MCGAffineTransformMakeTranslation(t_transform . tx, t_transform . ty);
		t_location = MCGPointMake(p_location . x * t_scale, p_location . y * t_scale);
	}

	PangoLayoutLine *t_line;
	t_line = nil;
	if (t_success)
	{
		// The transform needs to be applied before setting the text + font,
		// otherwise the glyph orientation will be incorrectly set from the
		// previous transform.
		PangoMatrix t_ptransform;
		t_ptransform = MCGAffineTransformToPangoMatrix(t_transform);
		pango_context_set_matrix(s_pango, &t_ptransform);

		pango_layout_set_font_description(s_layout, t_scaled_font != nil ? t_scaled_font : (PangoFontDescription *) p_font . fid);
		pango_layout_set_text(s_layout, t_text, -1);
		MCCStringFree(t_text);
		
		extern PangoLayoutLine *(*pango_layout_get_line_readonly_ptr)(PangoLayout *, int);
		if (pango_layout_get_line_readonly_ptr != nil)
			t_line = pango_layout_get_line_readonly_ptr(s_layout, 0);
		else
			t_line = pango_layout_get_line(s_layout, 0);
		t_success = t_line != nil;
	}
	
	MCGIntegerRectangle t_bitmap_bounds;
	if (t_success)
	{
		PangoRectangle t_pbounds;
		pango_layout_line_get_extents(t_line, NULL, &t_pbounds);
		
		MCGRectangle t_float_text_bounds;
		t_float_text_bounds = MCGRectangleFromPangoRectangle(t_pbounds);
		
		// Apply translation to put target location at the origin
		t_transform = MCGAffineTransformPostTranslate(t_transform, t_location.x, t_location.y);

		MCGRectangle t_device_text_bounds;
		t_device_text_bounds = MCGRectangleApplyAffineTransform(t_float_text_bounds, t_transform);
		
		MCGRectangle t_device_clip;
		t_device_clip = MCGContextGetDeviceClipBounds(self);

		t_bitmap_bounds = MCGRectangleGetBounds(MCGRectangleIntersection(t_device_text_bounds, t_device_clip));
		
		if (t_bitmap_bounds.size.width == 0 || t_bitmap_bounds.size.height == 0)
		{
			if (t_scaled_font != nil)
				pango_font_description_free(t_scaled_font);
			return;
		}
	}
	
	void *t_data;
	t_data = nil;
	if (t_success)
		t_success = MCMemoryNew(t_bitmap_bounds.size.width * t_bitmap_bounds.size.height, t_data);
	
	if (t_success)
	{
		FT_Bitmap t_ftbitmap;
		t_ftbitmap . rows = t_bitmap_bounds.size.height;
		t_ftbitmap . width = t_bitmap_bounds.size.width;
		t_ftbitmap . pitch = t_bitmap_bounds.size.width;
		t_ftbitmap . buffer = (unsigned char*) t_data;
		t_ftbitmap . num_grays = 256;
		t_ftbitmap . pixel_mode = FT_PIXEL_MODE_GRAY;
		t_ftbitmap . palette_mode = 0;
		t_ftbitmap . palette = nil;

		// Apply translation to offset drawing into the bitmap
		t_transform = MCGAffineTransformPreTranslate(t_transform, -t_bitmap_bounds.origin.x, -t_bitmap_bounds.origin.y);
		
		PangoMatrix t_ptransform;
		t_ptransform = MCGAffineTransformToPangoMatrix(t_transform);
		pango_context_set_matrix(s_pango, &t_ptransform);
		
		pango_ft2_render_layout_line(&t_ftbitmap, t_line, 0, 0);
		
        // The paint containing the fill settings
        SkPaint t_paint;
        if (MCGContextSetupFill(self, t_paint))
        {
            SkImageInfo t_info = SkImageInfo::MakeA8(t_bitmap_bounds.size.width, t_bitmap_bounds.size.height);
            
            SkBitmap t_bitmap;
            t_bitmap.setInfo(t_info);
            t_bitmap.setPixels(t_data);

            self->layer->canvas->save();
            self->layer->canvas->resetMatrix();
            self->layer->canvas->drawBitmap(t_bitmap,
                            t_bitmap_bounds.origin.x,
                            t_bitmap_bounds.origin.y,
                            &t_paint);
            self->layer->canvas->restore();
        }
        else
        {
            self->is_valid = false;
        }
	}
    
	MCMemoryDelete(t_data);
	// The layout keeps a copy of its font description, so ours can go.
	if (t_scaled_font != nil)
		pango_font_description_free(t_scaled_font);
	self -> is_valid = t_success;
}

MCGFloat __MCGContextMeasurePlatformText(MCGContextRef self, const unichar_t *p_text, uindex_t p_length, const MCGFont &p_font, const MCGAffineTransform &p_transform)
{	
	// MW-2013-12-19: [[ Bug 11559 ]] Do nothing if no text support.
	if (!s_has_text_support)
		return 0.0;
	
	lnx_pango_follow_font_config();

	bool t_success;
	t_success = true;
	
	char *t_text;
	t_text = nil;
	if (t_success)
		t_success = MCCStringFromUnicodeSubstring(p_text, p_length / 2, t_text);
	
	MCGFloat t_width;
	t_width = 0.0;
	if (t_success)
	{
		// OXT-Beyond: from Tom Perry's OpenXTalk Lite 7 engine.
		lnx_pango_reset_matrix();

		// OXT-Beyond: [[ HiDPI ]] Text that is drawn scaled (a HiDPI
		// window's backing scale, or a stack's scaleFactor) is measured at
		// the size it is drawn, and the width given back in logical units,
		// as the transform's contract asks (MM-2014-04-16: [[ Bug 11964 ]]).
		// At a scale of 1 it is measured as it always was.
		PangoFontDescription *t_scaled_font;
		MCGFloat t_scale;
		t_scale = 1;
		t_scaled_font = lnx_pango_copy_scaled_font(p_font, p_transform, t_scale);

		pango_layout_set_text(s_layout, t_text, -1);
		pango_layout_set_font_description(s_layout, t_scaled_font != nil ? t_scaled_font : (PangoFontDescription *) p_font . fid);
		
		PangoRectangle t_bounds;
		if (t_scaled_font != nil)
		{
			pango_layout_get_extents(s_layout, NULL, &t_bounds);
			t_width = t_bounds . width / (MCGFloat(PANGO_SCALE) * t_scale);
			pango_font_description_free(t_scaled_font);
		}
		else
		{
			pango_layout_get_pixel_extents(s_layout, NULL, &t_bounds);
			t_width = t_bounds . width;
		}
	}
	
	MCCStringFree(t_text);

	return t_width;
}

bool MCGContextMeasurePlatformTextImageBounds(MCGContextRef self, const unichar_t *p_text, uindex_t p_length, const MCGFont &p_font, const MCGAffineTransform &p_transform, MCGRectangle &r_bounds)
{
	// MW-2013-12-19: [[ Bug 11559 ]] Do nothing if no text support.
	if (!s_has_text_support)
		return false;
	
	bool t_success;
	t_success = true;
	
	// OXT-Beyond: use the objects made at startup, as drawing and measuring
	// do. This made a new font map, context and layout on every call and
	// never freed the old ones. A new context had no transform, so reset it.
	if (t_success)
		t_success = s_layout != NULL;

	if (t_success)
	{
		lnx_pango_follow_font_config();
		lnx_pango_reset_matrix();
	}
	
	char *t_text;
	t_text = nil;
	if (t_success)
		t_success = MCCStringFromUnicodeSubstring(p_text, p_length / 2, t_text);
	
	// Get extents of first line in order to get correct offset to baseline
	PangoLayoutLine *t_line;
	if (t_success)
	{
		pango_layout_set_text(s_layout, t_text, -1);
		pango_layout_set_font_description(s_layout, (PangoFontDescription *) p_font . fid);
		
		extern PangoLayoutLine *(*pango_layout_get_line_readonly_ptr)(PangoLayout *, int);
		if (pango_layout_get_line_readonly_ptr != nil)
			t_line = pango_layout_get_line_readonly_ptr(s_layout, 0);
		else
			t_line = pango_layout_get_line(s_layout, 0);
		t_success = t_line != nil;
	}
	
	if (t_success)
	{
		PangoRectangle t_layout_bounds, t_image_bounds;
		pango_layout_line_get_extents(t_line, &t_image_bounds, &t_layout_bounds);
		
		r_bounds = MCGRectangleFromPangoRectangle(t_image_bounds);
	}
	
	MCCStringFree(t_text);
	
	return t_success;
}

////////////////////////////////////////////////////////////////////////////////
