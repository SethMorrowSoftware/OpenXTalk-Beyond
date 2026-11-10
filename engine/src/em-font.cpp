/* Copyright (C) 2020 LiveCode Ltd.

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

#include <foundation.h>

#include "prefix.h"

#include "filedefs.h"

#include "system.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include <freetype/ftsnames.h>

#include "customfont.h"
#include "freetype-font.h"
#include "skiatypeface.h"

#include "em-font.h"
#include "textlayout.h"

#define MCEMSCRIPTEN_FONT_FOLDER "/boot/standalone"

bool MCEmscriptenCustomFontsInitialize()
{
	return MCCustomFontListInitialize();
}

void MCEmscriptenCustomFontsFinalize()
{
	MCCustomFontListFinalize();
}

static bool MCEmscriptenCreateCustomFontFromPath(MCStringRef p_path, FT_Library p_library, MCCustomFont *&r_custom_font)
{
	bool t_success;
	t_success = true;
	
	MCAutoStringRef t_font_path;
	
	MCAutoDataRef t_buffer;
	if (t_success)
		t_success = MCS_loadbinaryfile(p_path, &t_buffer);
	
	MCCustomFont *t_font;
	t_font = nil;
	if (t_success)
		t_success = MCMemoryNew(t_font);
	
	if (t_success)
		t_success = MCFreeTypeGetFontInfoFromData(p_library, *t_buffer, t_font->name, t_font->family, t_font->style);

	if (t_success)
	{
		MCValueAssign(t_font->path, p_path);
		r_custom_font = t_font;
	}
	else
		MCCustomFontDelete(t_font);
	
	return t_success;
}

static bool MCEmscriptenCustomFontLoadCallback(void *p_context, const MCSystemFolderEntry *p_entry)
{
	FT_Library t_ft_library = reinterpret_cast<FT_Library>(p_context);

	if (!p_entry->is_folder)
	{
		MCCustomFont *t_font;
		if (MCEmscriptenCreateCustomFontFromPath(p_entry->name, t_ft_library, t_font))
			MCCustomFontListAddFont(t_font);
	}

	return true;
}

// Parse the fonts folder (as set up by the standalone builder), locating any font files.
// For each font file found, attempt to parse using freetype and if successful, add to the custom font list.
// If particularly intensive, the parsing step could be moved to the IDE, which would just generate the required meta-data.
bool MCEmscriptenCustomFontsLoad()
{
	bool t_success;
	t_success = true;
	
	FT_Library t_ft_library;
	t_ft_library = nil;
	if (t_success)
		t_success = FT_Init_FreeType(&t_ft_library) == 0;
	
	if (t_success)
		t_success = MCsystem->ListFolderEntries(MCSTR(MCEMSCRIPTEN_FONT_FOLDER), MCEmscriptenCustomFontLoadCallback, t_ft_library);
	
	if (t_ft_library != nil)
		FT_Done_FreeType(t_ft_library);

	return t_success;
}

/* OXT-Beyond: "start using font file" (MCScreenDC::loadfont(), em-dc.cpp).
 * The file's font joins those of the standalone's folder, as on the
 * desktop, where the engine reads the file again whenever it makes a font
 * from it. Its handle is the font in the list. */
bool MCEmscriptenCustomFontLoadFile(MCStringRef p_path, void *&r_handle)
{
	FT_Library t_ft_library;
	t_ft_library = nil;
	if (FT_Init_FreeType(&t_ft_library) != 0)
		return false;

	MCCustomFont *t_font;
	t_font = nil;
	bool t_success;
	t_success = MCEmscriptenCreateCustomFontFromPath(p_path, t_ft_library, t_font);
	FT_Done_FreeType(t_ft_library);
	if (!t_success)
		return false;

	MCCustomFontListAddFont(t_font);
	r_handle = t_font;
	return true;
}

/* OXT-Beyond: "stop using font file" (MCScreenDC::unloadfont()): the
 * font that "start using font file" loaded (its handle) leaves the list */
bool MCEmscriptenCustomFontUnloadFile(void *p_handle)
{
	MCCustomFont *t_font;
	t_font = static_cast<MCCustomFont *>(p_handle);
	if (t_font == nil || !MCCustomFontListRemoveFont(t_font))
		return false;

	MCCustomFontDelete(t_font);
	return true;
}


/* OXT-Beyond: desktop font names on the web.
 *
 * A browser has none of the desktop's fonts, so text in Arial, Helvetica,
 * Times or Courier drew in Droid Sans, the face every standalone has, and
 * wrapped where Droid Sans's widths put it rather than where it wraps on
 * the desktop. A standalone that carries the metric-compatible open fonts
 * (Arimo, Tinos and Cousine, from Google's Croscore set: each glyph is as
 * wide as Arial's, Times New Roman's or Courier New's), as one built with
 * the Web pane's "Desktop fonts" does, draws those names in them. The
 * table maps a name to the family that stands in for it. A font loaded
 * under the name itself (from the Copy Files pane, or by "start using font
 * file") always wins, and without the family loaded nothing changes: text
 * draws in Droid Sans, as before.
 *
 * The Mac names that HyperCard stacks use (Geneva, New York, Monaco,
 * Palatino) map to the nearest of the three, and so do the desktop fonts
 * that File > Import Stack puts in their place on a desktop without them
 * (revHyperCardMacFonts: Verdana, Palatino Linotype, Lucida Console), so
 * that a stack imported on the desktop draws on the web as one imported
 * there. Those last are not as wide as their stand-ins: they draw in the
 * nearer face, not at the desktop's widths. */
static const char * const kMCEmscriptenFontStandIns[][2] =
{
	{"Arial", "Arimo"},
	{"Helvetica", "Arimo"},
	{"Helvetica Neue", "Arimo"},
	{"Liberation Sans", "Arimo"},
	{"Geneva", "Arimo"},
	{"Verdana", "Arimo"},
	{"Times New Roman", "Tinos"},
	{"Times", "Tinos"},
	{"Liberation Serif", "Tinos"},
	{"New York", "Tinos"},
	{"Palatino", "Tinos"},
	{"Palatino Linotype", "Tinos"},
	{"Courier New", "Cousine"},
	{"Courier", "Cousine"},
	{"Liberation Mono", "Cousine"},
	{"Monaco", "Cousine"},
	{"Menlo", "Cousine"},
	{"Lucida Console", "Cousine"},
};

/* The family that stands in for p_name, if that family is loaded */
static bool MCEmscriptenFontStandIn(MCStringRef p_name, MCStringRef &r_family)
{
	for (size_t i = 0; i < sizeof(kMCEmscriptenFontStandIns) / sizeof(kMCEmscriptenFontStandIns[0]); i++)
	{
		if (!MCStringIsEqualToCString(p_name, kMCEmscriptenFontStandIns[i][0], kMCStringOptionCompareCaseless))
			continue;
		MCAutoStringRef t_family;
		if (!MCStringCreateWithCString(kMCEmscriptenFontStandIns[i][1], &t_family))
			return false;
		if (MCCustomFontListGetStylesForName(*t_family) == 0)
			return false;
		r_family = MCValueRetain(*t_family);
		return true;
	}
	return false;
}

/* For the fontNames: the names of the table whose family is loaded and
 * that no loaded font has itself, so that a stack that checks for its
 * fonts (as HyperCard stacks did: "These fonts are missing from your
 * system: Helvetica 9...") finds them */
static bool MCEmscriptenFontStandInNames(MCListRef p_list)
{
	for (size_t i = 0; i < sizeof(kMCEmscriptenFontStandIns) / sizeof(kMCEmscriptenFontStandIns[0]); i++)
	{
		MCAutoStringRef t_name;
		if (!MCStringCreateWithCString(kMCEmscriptenFontStandIns[i][0], &t_name))
			return false;
		if (MCCustomFontListGetStylesForName(*t_name) != 0)
			continue;
		MCAutoStringRef t_family;
		if (!MCEmscriptenFontStandIn(*t_name, &t_family))
			continue;
		if (!MCListAppend(p_list, *t_name))
			return false;
	}
	return true;
}

bool MCEmscriptenListFontFamilies(MCListRef& r_names)
{
	MCAutoListRef t_list;
	if (!MCListCreateMutable('\n', &t_list))
		return false;
	
	MCAutoStringRef t_custom_font_names;
	if (!MCCustomFontListGetNames(&t_custom_font_names) ||
			!MCListAppend(*t_list, *t_custom_font_names))
		return false;

	/* OXT-Beyond: the desktop names that a loaded family stands in for */
	if (!MCEmscriptenFontStandInNames(*t_list))
		return false;
	
	return MCListCopy(*t_list, r_names);
}

bool MCEmscriptenListFontsForFamily(MCStringRef p_family, uint32_t p_fsize, MCListRef& r_styles)
{
	uint32_t t_styles;
	t_styles = 0;
	
	if (t_styles == 0)
		t_styles = MCCustomFontListGetStylesForName(p_family);

	/* OXT-Beyond: a desktop name has the styles of its stand-in */
	if (t_styles == 0)
	{
		MCAutoStringRef t_stand_in;
		if (MCEmscriptenFontStandIn(p_family, &t_stand_in))
			t_styles = MCCustomFontListGetStylesForName(*t_stand_in);
	}
	
	MCAutoListRef t_list;
	if (!MCListCreateMutable('\n', &t_list))
		return false;

	if (t_styles & kMCCustomFontStyleRegular)
		if (!MCListAppendCString(*t_list, "plain"))
			return false;
	if (t_styles & kMCCustomFontStyleBold)
		if (!MCListAppendCString(*t_list, "bold"))
			return false;
	if (t_styles & kMCCustomFontStyleItalic)
		if (!MCListAppendCString(*t_list, "italic"))
			return false;
	if (t_styles & kMCCustomFontStyleBoldItalic)
		if (!MCListAppendCString(*t_list, "bold-italic"))
			return false;

	return MCListCopy(*t_list, r_styles);
}


static bool MCEmscriptenCustomFontsCreateTypefaceFromNameAndStyle(MCStringRef p_name, bool p_bold, bool p_italic, MCSkiaTypefaceRef &r_typeface)
{
	bool t_success;
	t_success = true;
	
	MCCustomFont *t_font;
	t_font = nil;
	if (t_success)
	{
		t_success = MCCustomFontListLookupFont(p_name, p_bold, p_italic, t_font);
		/* OXT-Beyond: a desktop name, in the family that stands in for it */
		if (!t_success)
		{
			MCAutoStringRef t_family;
			if (MCEmscriptenFontStandIn(p_name, &t_family))
				t_success = MCCustomFontListLookupFont(*t_family, p_bold, p_italic, t_font);
		}
	}
	
	MCAutoDataRef t_buffer;
	if (t_success)
		t_success = MCS_loadbinaryfile(t_font->path, &t_buffer);
	
	MCSkiaTypefaceRef t_typeface;
	t_typeface = nil;
	if (t_success)
		t_success = MCSkiaTypefaceCreateWithData(*t_buffer, t_typeface);
	
	if (t_success)
		r_typeface = t_typeface;
	
	return t_success;
}

void* MCEmscriptenFontCreate(MCStringRef p_name, uint32_t p_size, bool p_bold, bool p_italic)
{
	MCSkiaFont *t_font = nil;
	
	if (MCMemoryNew(t_font))
	{
		t_font -> typeface = nil;
		// MM-2012-03-06: Check to see if we have a custom font of the given style and name available
		if (!MCEmscriptenCustomFontsCreateTypefaceFromNameAndStyle(p_name, p_bold, p_italic, t_font->typeface))
		{
			// AL-2014-09-10: [[ Bug 13335 ]] If the font does not exist, fall back to the default family
			//  but retain the styling.
			if (!MCSkiaTypefaceCreateWithName(p_name, p_bold, p_italic, t_font->typeface))
				MCSkiaTypefaceCreateWithName(nil, p_bold, p_italic, t_font->typeface);
		}
		
		MCAssert(t_font->typeface != NULL);
		t_font->size = p_size;
	}
	
	return t_font;
}

void MCEmscriptenFontDestroy(void *font)
{
	MCSkiaFont *t_font = (MCSkiaFont*)font;
	if (t_font != nil && t_font->typeface != nil)
		MCSkiaTypefaceRelease(t_font->typeface);
	MCMemoryDelete(font);
}

void MCEmscriptenFontGetMetrics(void *p_font, float &r_ascent, float &r_descent, float &r_leading, float &r_xheight)
{
	MCSkiaFont *t_font = (MCSkiaFont*)p_font;
	
	/* UNCHECKED */ MCSkiaTypefaceGetMetrics(t_font->typeface, t_font->size, r_ascent, r_descent, r_leading, r_xheight);
}

float MCEmscriptenFontMeasureText(void *p_font, const char *p_text, uint32_t p_text_length, bool p_is_unicode)
{
	MCSkiaFont *t_font = (MCSkiaFont*)p_font;
	
	float t_length;
	if (p_is_unicode)
	{
		/* UNCHECKED */ MCSkiaTypefaceMeasureText(t_font->typeface, t_font->size, p_text, p_text_length, true, t_length);
	}
	else
	{
		MCAutoStringRef t_string;
		MCStringCreateWithCString(p_text, &t_string);
		MCAutoStringRefAsUTF8String t_utf8_string;
		/* UNCHECKED */ t_utf8_string . Lock(*t_string);
		
		/* UNCHECKED */ MCSkiaTypefaceMeasureText(t_font->typeface, t_font->size, *t_utf8_string, t_utf8_string.Size(), false, t_length);
	}
	
	return t_length;
}

/* ================================================================
 * Text layout for printing
 *
 * Printing to PDF (customprinter.cpp) lays text out with these on the
 * desktop; as on the server, the web engine has no text layout of its
 * own for it.
 * ================================================================ */

bool
MCTextLayoutInitialize()
{
	return false;
}

void
MCTextLayoutFinalize()
{
}

bool
MCTextLayout(const unichar_t *p_chars,
             uint32_t p_char_count,
             MCFontStruct *p_font,
             MCTextLayoutCallback p_callback,
             void *p_context)
{
	return false;
}
