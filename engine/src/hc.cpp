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
#include "mcio.h"

#include "aclip.h"
#include "font.h"
#include "util.h"
#include "cdata.h"
#include "button.h"
#include "field.h"
#include "paragraf.h"
#include "image.h"
#include "scrolbar.h"
#include "group.h"
#include "objptr.h"
#include "card.h"
#include "stack.h"
#include "hndlrlst.h"
#include "cardlst.h"
#include "hc.h"

#include "exec-interface.h"

#include "globals.h"

static uint4 maxid;
static uint4 version;

static uint2 iconx, icony;
static uint2 cursorx, cursory;

static const uint2 hc_icons[HC_NICONS] =
    {
        24694, 2002, 1000, 1001, 1002, 1003,
        1004, 1005, 1006, 1007, 1008, 1019, 26884, 18814, 27056, 15420,
        16560, 6720, 16692, 3584, 24317, 29903, 1014, 1013, 1012, 29019,
        2730, 30557, 26865, 9301, 27009, 2162, 32488, 2335, 5472, 766, 902,
        26425, 29114, 4895, 6724, 21449, 24830, 17779, 8419, 7417, 26020,
        15279, 19381, 22308, 14953, 6464, 6179, 3835, 29484, 9120, 19162,
        1016, 32650, 1011, 11045, 20098, 21700, 20689, 21847, 1017, 10610,
        20696, 17481, 3430, 11645, 4432, 20965, 17357, 21209, 8961, 22855,
        4263, 15972, 20186, 32670, 26635, 25002, 32462, 21060, 2507, 31685,
        1020, 23078, 19678, 2478, 14767, 1018, 1015, 1009, 8538, 9761, 7012,
        13149, 16344, 17343, 12195, 28023, 28024, 28022, 18222, 18223, 290,
        25309, 24753, 21437, 31885, 29589, 16735, 21711, 17214, 6544, 11260,
        7142, 18607, 21573, 21574, 21575, 21576, 24694, 6560, 6491, 12722,
        24081, 27328, 22978, 15993, 2181, 13744, 13745, 8323, 10935, 17838,
        17896, 17890, 17937, 23613, 8348, 8347, 8979, 8964, 8980, 6044,
        6043, 28811, 28810, 8350, 8349, 23717, 23718, 29654, 27774, 3071,
        3358, 27969, 9104, 10181, 12411, 19638, 17264, 11714, 17169, 3333,
        11216, 16321, 2101, 2102, 2103, 2104, 2105, 2106, 26665, 49012,
        59013, 49014, 49044, 49045, 49046, 49047, 49048, 49049, 49056,
        49124, 65535, 1, 2, 59457 };

static const uint2 mc_icons[HC_NICONS] =
    {
        330, 361, 344, 344, 379, 379, 342, 343,
        359, 335, 336, 359, 379, 339, 356, 320, 321, 396, 325, 324, 319,
        322, 320, 321, 396, 325, 324, 319, 322, 320, 321, 396, 325, 324,
        319, 322, 320, 321, 396, 325, 324, 319, 322, 367, 368, 396, 365,
        366, 367, 368, 396, 601, 602, 601, 602, 601, 602, 601, 602, 351,
        352, 350, 353, 352, 353, 387, 388, 387, 345, 345, 346, 337, 369,
        369, 338, 338, 338, 338, 337, 348, 344, 330, 330, 330, 361, 361,
        361, 361, 330, 362, 363, 364, 370, 328, 354, 378, 370, 358, 330,
        395, 380, 342, 360, 360, 360, 358, 358, 395, 383, 339, 371, 343,
        330, 357, 344, 356, 605, 606, 395, 389, 805, 806, 807, 808, 361,
        384, 389, 338, 341, 350, 350, 350, 353, 352, 352, 352, 352, 387,
        388, 387, 387, 388, 321, 320, 368, 367, 361, 321, 320, 368, 367,
        368, 367, 368, 367, 378, 370, 304, 385, 368, 368, 348, 361, 361,
        330, 330, 330, 330, 330, 330, 372, 373, 374, 375, 376, 377, 394,
        386, 394, 386, 394, 394, 393, 392, 391, 390, 339, 348, 605, 604,
        331, 349 };

void hcstat_append(const char *msg, ...)
{
	// Build the new message string (msg is printf format string)
	va_list t_args;
	va_start(t_args, msg);
	MCAutoStringRef t_new_line;
	/* UNCHECKED */ MCStringFormatV(&t_new_line, msg, t_args);
	va_end(t_args);
	
	// Turn the current MChcstat stringref into a mutable stringref
	MCAutoStringRef t_mutable_hcstat;
	/* UNCHECKED */ MCStringMutableCopyAndRelease(MChcstat, &t_mutable_hcstat);

	// If the string isn't empty, it needs a return char
	if (!MCStringIsEmpty(*t_mutable_hcstat))
		/* UNCHECKED */ MCStringAppendChar(*t_mutable_hcstat, '\n');

	// Append the new line
	/* UNCHECKED */ MCStringAppend(*t_mutable_hcstat, *t_new_line);

	// We've released the previous MChcstat var above so just copy as immutable into MChcstat.
	/* UNCHECKED */ MCStringCopy(*t_mutable_hcstat, MChcstat);
}

static uint32_t MCHCBitmapStride(uint32_t p_width)
{
	// rows are padded to a multiple of 4 bytes
	return ((p_width + 31) & ~0x1F ) / 8;
}

// Big-endian reads that leave the block in place: the parsers below used to
// swap fields in the block itself, which made reading a field twice (or
// reading the size of a record another parser had swapped) depend on the
// order the parsers ran in.
static uint2 hc_get_uint2(const char *p_ptr)
{
	const uint1 *t_ptr = (const uint1 *)p_ptr;
	return uint2((t_ptr[0] << 8) | t_ptr[1]);
}

static int2 hc_get_int2(const char *p_ptr)
{
	return int2(hc_get_uint2(p_ptr));
}

static uint4 hc_get_uint4(const char *p_ptr)
{
	const uint1 *t_ptr = (const uint1 *)p_ptr;
	return (uint4(t_ptr[0]) << 24) | (uint4(t_ptr[1]) << 16) | (uint4(t_ptr[2]) << 8) | uint4(t_ptr[3]);
}

// Every block is read into a buffer with this many zero bytes after it, so
// that the name and script strings at the end of a block are always
// terminated and a short fixed-size header near its end reads zeros rather
// than whatever follows in memory.
#define HC_BLOCK_PADDING 64

// XOR each bit of a row with the bit p_distance bits to its left, from left
// to right, so that each result feeds the next (the "dh" step of the bitmap
// format: p_distance is 1, 2, 8 or 16).
static void hcbitmap_apply_dh(uint1 *p_row, uint32_t p_stride, uint32_t p_distance)
{
	uint32_t t_bits = p_stride * 8;
	for (uint32_t k = p_distance ; k < t_bits ; k++)
	{
		uint32_t s = k - p_distance;
		if (p_row[s >> 3] & (0x80 >> (s & 7)))
			p_row[k >> 3] ^= (0x80 >> (k & 7));
	}
}

// Decode one plane (image or mask) of a BMAP block: Bill Atkinson's
// "WOBA" compression, as documented by the HyperCard format notes of
// Rebecca Bettencourt and implemented by HyperCardPreview and stackimport.
// p_top is the plane's top edge on the card: the pattern rows of opcodes
// 0x83 and 0x84 are indexed by the card row, not the plane's.
// IM-2014-04-08: [[ Bug 12101 ]] Modify to return decoded bitmap data directly
static bool convert_hcbitmap_data(const uint1 *sptr, uint4 p_length, uint2 width, uint2 height, int2 p_top, uint8_t *&r_bitmapdata)
{
	uint8_t *t_data;
	uint32_t t_stride;

	t_stride = MCHCBitmapStride(width);

	if (!MCMemoryNewArray(t_stride * height + 1, t_data))
		return false;

	r_bitmapdata = t_data;

	if (t_stride == 0)
		return true;

	const uint1 *startptr = sptr;
	const uint1 *eptr = sptr + p_length;

	// The pattern bytes start as a 50% grey, for each decode.
	uint1 t_patterns[8] = {0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55};
	uint32_t dh = 0;
	uint32_t dv = 0;
	uint32_t y = 0;
	while (y < height)
	{
		uint1 *t_row = t_data + y * t_stride;
		uint32_t x = 0;
		uint32_t t_repeat = 1;
		bool t_whole_rows = false;
		while (x < t_stride && !t_whole_rows)
		{
			if (sptr >= eptr)
			{
				hcstat_append("Error: ran out of bitmap data at offset %d, line %d",
				              (int)(sptr - startptr), (int)y);
				return true;
			}
			uint1 opcode = *sptr++;
			if (opcode < 0x80)
			{
				// z zero bytes followed by d data bytes
				uint32_t t_zeros = opcode & 0x0F;
				uint32_t t_bytes = opcode >> 4;
				if ((uint32_t)(eptr - sptr) < t_bytes)
					t_bytes = (uint32_t)(eptr - sptr);
				while (t_repeat--)
				{
					x += t_zeros;
					for (uint32_t i = 0 ; i < t_bytes ; i++, x++)
						if (x < t_stride)
							t_row[x] = sptr[i];
				}
				sptr += t_bytes;
				t_repeat = 1;
			}
			else if (opcode >= 0xA0 && opcode < 0xC0)
				t_repeat = opcode & 0x1F;
			else if (opcode >= 0xC0 && opcode < 0xE0)
			{
				// (opcode & 0x1F) * 8 data bytes
				uint32_t t_bytes = (opcode & 0x1F) << 3;
				if ((uint32_t)(eptr - sptr) < t_bytes)
					t_bytes = (uint32_t)(eptr - sptr);
				while (t_repeat--)
					for (uint32_t i = 0 ; i < t_bytes ; i++, x++)
						if (x < t_stride)
							t_row[x] = sptr[i];
				sptr += t_bytes;
				t_repeat = 1;
			}
			else if (opcode >= 0xE0)
			{
				// (opcode & 0x1F) * 16 zero bytes
				x += ((opcode & 0x1F) << 4) * t_repeat;
				t_repeat = 1;
			}
			else if (opcode >= 0x88 && opcode <= 0x8F)
			{
				static const uint1 s_dh[8] = {16, 0, 0, 0, 1, 1, 2, 8};
				static const uint1 s_dv[8] = {0, 0, 1, 2, 0, 1, 2, 0};
				dh = s_dh[opcode - 0x88];
				dv = s_dv[opcode - 0x88];
			}
			else if (opcode <= 0x86)
			{
				// Whole rows, repeated t_repeat times: these are stored as
				// they are, with no dh or dv step.
				uint1 t_value = 0;
				if (opcode == 0x83)
				{
					if (sptr >= eptr)
						return true;
					t_value = *sptr++;
					t_patterns[(p_top + y) & 7] = t_value;
				}
				if (opcode == 0x80 && (uint32_t)(eptr - sptr) < t_stride)
				{
					hcstat_append("Error: ran out of bitmap data at offset %d, line %d",
					              (int)(sptr - startptr), (int)y);
					return true;
				}
				while (t_repeat-- && y < height)
				{
					t_row = t_data + y * t_stride;
					switch (opcode)
					{
					case 0x80:
						memcpy(t_row, sptr, t_stride);
						break;
					case 0x81:
						break;
					case 0x82:
						memset(t_row, 0xFF, t_stride);
						break;
					case 0x83:
						memset(t_row, t_value, t_stride);
						break;
					case 0x84:
						memset(t_row, t_patterns[(p_top + y) & 7], t_stride);
						break;
					case 0x85:
						if (y >= 1)
							memcpy(t_row, t_row - t_stride, t_stride);
						break;
					case 0x86:
						if (y >= 2)
							memcpy(t_row, t_row - 2 * t_stride, t_stride);
						break;
					}
					y++;
				}
				if (opcode == 0x80)
					sptr += t_stride;
				t_whole_rows = true;
			}
			else
			{
				// 0x87 and 0x90-0x9F are not opcodes: the data is over.
				hcstat_append("Unknown BMAP opcode %x at offset %d, line %d",
				              opcode, (int)(sptr - startptr), (int)y);
				return true;
			}
		}
		if (t_whole_rows)
			continue;

		if (dh != 0)
			hcbitmap_apply_dh(t_row, t_stride, dh);
		if (dv != 0 && y >= dv)
		{
			const uint1 *t_above = t_row - dv * t_stride;
			for (uint32_t i = 0 ; i < t_stride ; i++)
				t_row[i] ^= t_above[i];
		}
		y++;
	}
	return true;
}

static const char *convert_font(char *sptr)
{
	return sptr;  // pass font names directly through: will be ugly on Windows systems!
}

static uint2 convert_style(uint2 istyle)
{
	uint2 ostyle = FA_DEFAULT_STYLE;
	if (istyle != 0xFFFF)
	{
		if (istyle & HC_TSTYLE_BOLD)
			ostyle = (FE_NORMAL << 4) + MCFW_BOLD;
		if (istyle & HC_TSTYLE_ITALIC)
			ostyle |= FA_ITALIC;
		if (istyle & HC_TSTYLE_UNDERLINE)
			ostyle |= FA_UNDERLINE;
		if (istyle & HC_TSTYLE_GROUP)
			ostyle |= FA_LINK;
	}
	return ostyle;
}

// HyperCard's text, names and scripts are MacRoman. convert_string and
// convert_script keep them MacRoman (with line ends and HyperTalk's
// operators changed), and hc_string and hc_name decode them, so each comes
// in as the character HyperCard showed on every platform. (Off the Mac the
// importer used to translate the bytes with MCisotranslations, which goes
// from native to MacRoman, the wrong way, so a curly quote came in as "n"
// with a tilde; Windows-1252 and ISO 8859-1, the native encodings there,
// have no place for some MacRoman characters at all.) One MacRoman byte
// is one character, so the offsets of style runs stay right.
// (libfoundation decodes kMCStringEncodingMacRoman only on the Mac, so the
// importer has its own table: the upper half of MacRoman, as Apple's
// ROMAN.TXT maps it and libfoundation's MacRoman table does.)
#ifndef _MACOSX
static const unichar_t kHcMacRomanUpper[128] =
{
	0x00c4, 0x00c5, 0x00c7, 0x00c9, 0x00d1, 0x00d6, 0x00dc, 0x00e1, 0x00e0, 0x00e2, 0x00e4, 0x00e3,
	0x00e5, 0x00e7, 0x00e9, 0x00e8, 0x00ea, 0x00eb, 0x00ed, 0x00ec, 0x00ee, 0x00ef, 0x00f1, 0x00f3,
	0x00f2, 0x00f4, 0x00f6, 0x00f5, 0x00fa, 0x00f9, 0x00fb, 0x00fc, 0x2020, 0x00b0, 0x00a2, 0x00a3,
	0x00a7, 0x2022, 0x00b6, 0x00df, 0x00ae, 0x00a9, 0x2122, 0x00b4, 0x00a8, 0x2260, 0x00c6, 0x00d8,
	0x221e, 0x00b1, 0x2264, 0x2265, 0x00a5, 0x00b5, 0x2202, 0x2211, 0x220f, 0x03c0, 0x222b, 0x00aa,
	0x00ba, 0x03a9, 0x00e6, 0x00f8, 0x00bf, 0x00a1, 0x00ac, 0x221a, 0x0192, 0x2248, 0x2206, 0x00ab,
	0x00bb, 0x2026, 0x00a0, 0x00c0, 0x00c3, 0x00d5, 0x0152, 0x0153, 0x2013, 0x2014, 0x201c, 0x201d,
	0x2018, 0x2019, 0x00f7, 0x25ca, 0x00ff, 0x0178, 0x2044, 0x20ac, 0x2039, 0x203a, 0xfb01, 0xfb02,
	0x2021, 0x00b7, 0x201a, 0x201e, 0x2030, 0x00c2, 0x00ca, 0x00c1, 0x00cb, 0x00c8, 0x00cd, 0x00ce,
	0x00cf, 0x00cc, 0x00d3, 0x00d4, 0xf8ff, 0x00d2, 0x00da, 0x00db, 0x00d9, 0x0131, 0x02c6, 0x02dc,
	0x00af, 0x02d8, 0x02d9, 0x02da, 0x00b8, 0x02dd, 0x02db, 0x02c7
};
#endif

static bool hc_string(const char *p_macroman, uindex_t p_length, MCStringRef &r_string)
{
#ifdef _MACOSX
	// MacRoman is native: as before
	return MCStringCreateWithNativeChars((const char_t *)p_macroman, p_length, r_string);
#else
	MCAutoArray<unichar_t> t_chars;
	if (!t_chars.New(p_length))
		return false;
	for (uindex_t i = 0; i < p_length; i++)
	{
		uint1 t_byte = (uint1)p_macroman[i];
		t_chars[i] = t_byte < 0x80 ? (unichar_t)t_byte : kHcMacRomanUpper[t_byte - 0x80];
	}
	return MCStringCreateWithChars(t_chars.Ptr(), p_length, r_string);
#endif
}

static bool hc_string(const char *p_macroman, MCStringRef &r_string)
{
	return hc_string(p_macroman, strlen(p_macroman), r_string);
}

static void hc_setname(MCObject *p_object, const char *p_macroman)
{
	MCAutoStringRef t_string;
	MCNewAutoNameRef t_name;
	if (hc_string(p_macroman, &t_string) && MCNameCreate(*t_string, &t_name))
		p_object->setname(*t_name);
}

static char *convert_string(const char *string)
{
	const uint1 *sptr = (const uint1 *)string;
	char *newstring = new (nothrow) char[strlen(string) + 1];
	uint1 *dptr = (uint1 *)newstring;
	while (*sptr)
	{
		if (*sptr == 0x0D)
			*dptr = '\n';
		else
			*dptr = *sptr;

		dptr++;
		sptr++;
	}
	*dptr = *sptr;
	return newstring;
}

static char *convert_script(const char *string)
{
	if (!*string)
		return NULL;

	const uint1 *sptr = (const uint1 *)string;
	uint2 conversions = 0;
	uint2 length = 0;

	while (*sptr)
	{
		switch (*sptr)
		{
		case 0xB2:
		case 0xB3:
		case 0xAD:
			conversions++;
			break;
		default:
			break;
		}
		length++;
		sptr++;
	}
	sptr = (const uint1 *)string;
	char *newstring = new (nothrow) char[length + conversions + 1];
	uint1 *dptr = (uint1 *)newstring;
	while (*sptr)
	{
		switch (*sptr)
		{
		case 0x0D:
			*dptr = '\n';
			break;
		case 0xC2:
			*dptr = '\\';
			break;
		case 0xB2:
			*dptr++ = '<';
			*dptr = '=';
			break;
		case 0xB3:
			*dptr++ = '>';
			*dptr = '=';
			break;
		case 0xAD:
			*dptr++ = '<';
			*dptr = '>';
			break;
		default:
			*dptr = *sptr;

			break;
		}
		dptr++;
		sptr++;
	}
	*dptr = *sptr;
	return newstring;
}

// Read the name and the script that end a part, card or background record:
// the name, its terminating zero, (for a part) one more byte, then the
// script. Both are bounded by p_avail, the bytes left in the record, and
// the name is converted from MacRoman as the text and scripts are.
static void hc_read_name_and_script(const char *sptr, uint4 p_avail, uint4 p_gap, char *&r_name, char *&r_script)
{
	r_name = NULL;
	r_script = NULL;
	uint4 t_name_length = 0;
	while (t_name_length < p_avail && sptr[t_name_length] != '\0')
		t_name_length++;
	if (t_name_length != 0)
	{
		char *t_name = new (nothrow) char[t_name_length + 1];
		memcpy(t_name, sptr, t_name_length);
		t_name[t_name_length] = '\0';
		r_name = convert_string(t_name);
		delete[] t_name;
	}
	uint4 t_script_offset = t_name_length + p_gap;
	if (t_script_offset >= p_avail)
		return;
	uint4 t_script_length = 0;
	while (t_script_offset + t_script_length < p_avail && sptr[t_script_offset + t_script_length] != '\0')
		t_script_length++;
	char *t_script = new (nothrow) char[t_script_length + 1];
	memcpy(t_script, &sptr[t_script_offset], t_script_length);
	t_script[t_script_length] = '\0';
	r_script = convert_script(t_script);
	delete[] t_script;
}

// Read a part's rectangle (top, left, bottom, right at offset 6).
static MCRectangle hc_read_part_rect(const char *sptr)
{
	MCRectangle t_rect;
	int4 t_top = hc_get_int2(&sptr[6]);
	int4 t_left = hc_get_int2(&sptr[8]);
	int4 t_bottom = hc_get_int2(&sptr[10]);
	int4 t_right = hc_get_int2(&sptr[12]);
	t_rect.x = t_left;
	t_rect.y = t_top;
	t_rect.width = MCU_max(t_right - t_left + 1, 0);
	t_rect.height = MCU_max(t_bottom - t_top + 1, 0);
	return t_rect;
}

static MCHcfield *findfield(MCHcfield *flist, uint2 fid)
{
	if (flist != NULL)
	{
		MCHcfield *fptr = flist;
		do
		{
			if (fptr->id == fid)
				return fptr;
			fptr = (MCHcfield *)fptr->next();
		}
		while (fptr != flist);
	}
	return NULL;
}

static MCHcbutton *findbutton(MCHcbutton *blist, uint2 bid)
{
	if (blist != NULL)
	{
		MCHcbutton *bptr = blist;
		do
		{
			if (bptr->id == bid)
				return bptr;
			bptr = (MCHcbutton *)bptr->next();
		}
		while (bptr != blist);
	}
	return NULL;
}

MCHcsnd::MCHcsnd()
{
    m_name = MCValueRetain(kMCEmptyName);
	data = NULL;
}

MCHcsnd::~MCHcsnd()
{
    MCValueRelease(m_name);
	if (data != NULL)
		delete[] data;
}

// A 'snd ' resource is format 1 (a list of synthesizers, then commands) or
// format 2 (commands only). Its first command is a bufferCmd whose second
// parameter is the offset of the sound header. Only uncompressed sampled
// sound (a standard sound header, encode 0) is imported.
Boolean MCHcsnd::import(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length)
{
	id = inid;
	maxid = MCU_max((uint4)id, maxid);
    MCValueAssign(m_name, inname);
	if (p_length < 4)
		return False;
	uint2 type = hc_get_uint2(sptr);
	uint4 t_commands;
	if (type == 1)
		t_commands = 4 + hc_get_uint2(&sptr[2]) * 6;
	else if (type == 2)
		t_commands = 4;
	else
		return False;
	// the number of commands, then the first command: cmd, param1, param2
	if (t_commands + 10 > p_length || hc_get_uint2(&sptr[t_commands]) == 0)
		return False;
	uint4 hsize = hc_get_uint4(&sptr[t_commands + 6]);
	if (hsize > p_length || p_length - hsize < 22)
		return False;
	if (sptr[hsize + 20]) // compressed or extended sound
		return False;
	size = hc_get_uint4(&sptr[hsize + 4]);
	rate = hc_get_uint2(&sptr[hsize + 8]);
	uint1 t_base = (uint1)sptr[hsize + 21];
	if (t_base == 0)
		t_base = 0x3C;
	real8 baserate = (real8)((int)t_base - 0x3C);
	if (size > p_length - hsize - 22)
		size = p_length - hsize - 22;
	rate = (uint2)((real8)rate / pow(1.05946309434, baserate));
	data = new (nothrow) int1[size];
	if (data == NULL)
		return False;
	memcpy(data, sptr + hsize + 22, size);
	uint1 *dptr = (uint1 *)data;
	uint4 i = size;
	while (i--)
		*dptr++ -= 128;
	return True;
}

MCAudioClip *MCHcsnd::build()
{
	MCAudioClip *aptr = new (nothrow) MCAudioClip;
	aptr->size = size;
    aptr->setname(m_name);
	aptr->samples = (int1 *)data;
	data = NULL;
	aptr->nchannels = 1;
	aptr->format = AF_SLINEAR;
	aptr->rate = rate;
	aptr->swidth = 1;
	return aptr;
}

MCHctext::MCHctext()
{
	card = False;
	atts = NULL;
	nruns = 0;
	string = NULL;
}

MCHctext::~MCHctext()
{
	delete[] atts;
	delete[] string;
}

// Parse one content record of a card or background block, given the bytes
// left in the block, and return the record's length in r_length.
IO_stat MCHctext::parse(char *sptr, uint4 p_avail, uint4 &r_length)
{
	if (p_avail < 2)
		return IO_ERROR;
	int2 fid = hc_get_int2(sptr);
	if (fid < 0)
	{
		card = True;
		id = -fid;
	}
	else
		id = fid;
	if (version == 1)
	{
		string = convert_string(&sptr[2]);
		r_length = MCU_min((uint4)strlen(&sptr[2]) + 3, p_avail);
	}
	else
	{
		if (p_avail < 4)
			return IO_ERROR;
		uint4 tsize = hc_get_uint2(&sptr[2]);
		r_length = MCU_min(((tsize + 1) & ~0x01) + 4, p_avail);
		if (tsize > p_avail - 4)
			tsize = p_avail - 4;
		uint4 offset;
		uint1 *uint1ptr = (uint1 *)sptr;
		if (tsize != 0 && uint1ptr[4] & 0x80)
		{
			uint4 natts = 0;
			if (tsize >= 2)
				natts = hc_get_uint2(&sptr[4]) & 0x7FFF;
			if (natts < 2 || natts > tsize)
			{
				hcstat_append("Error: bad text style length %d in part %d", (int)natts, (int)id);
				natts = tsize;
			}
			tsize -= natts;
			offset = natts + 4;
			natts = (natts >> 1) - 1;
			if (natts != 0)
			{
				atts = new (nothrow) uint2[natts + 1];
				uint2 i;
				for (i = 0 ; i < natts ; i++)
					atts[i] = hc_get_uint2(&sptr[6 + i * 2]);
				atts[natts] = tsize;
				nruns = natts / 2;
			}
		}
		else
		{
			if (tsize != 0)
				tsize--;
			offset = 5;
		}
		char *newstring = new (nothrow) char[tsize + 1];
		strncpy(newstring, &sptr[offset], tsize);
		newstring[tsize] = '\0';
		string = convert_string(newstring);
		delete[] newstring;
	}
	return IO_NORMAL;
}

MCCdata *MCHctext::buildf(MCHcstak *hcsptr, MCField *parent)
{
	MCCdata *fptr = new (nothrow) MCCdata(cid);
	if (string == NULL)
		string = MCU_empty();
	// The style runs: pairs of (offset in the text, style id), the last
	// followed by the length of the text. A run covers its offset up to the
	// next run's, across line ends, so each line takes the part of each run
	// that falls inside it. (The old walk never left the first run of the
	// last line, so a one-line field kept only its first style.)
	char *eptr = string;
	MCParagraph *paragraphs = NULL;
	uint4 t_line_start = 0;

    MCExecContext ctxt(nil, nil, nil);
	do
	{
		char *sptr = eptr;
		eptr = strchr(sptr, '\n');
		if (eptr != NULL)
			*eptr++ = '\0';
		uint2 length = strlen(sptr);
		MCParagraph *pgptr = new (nothrow) MCParagraph;
		pgptr->setparent(parent);
		MCAutoStringRef t_string;
		/* UNCHECKED */ hc_string(sptr, length, &t_string);
		pgptr->settext(*t_string);
		pgptr->appendto(paragraphs);
		for (uint2 r = 0 ; r < nruns ; r++)
		{
			uint4 t_from = MCU_max((uint4)atts[r * 2], t_line_start);
			uint4 t_to = MCU_min((uint4)atts[r * 2 + 2], t_line_start + length);
			if (t_from >= t_to)
				continue;
			integer_t t_first = (integer_t)(t_from - t_line_start);
			integer_t t_last = (integer_t)(t_to - t_line_start);
			const char *tname = nullptr;
			uint2 tsize = 0;
			uint2 tstyle = 0;
			hcsptr->getatts(atts[r * 2 + 1], tname, tsize, tstyle);
			if (tname != NULL)
			{
				MCAutoStringRef t_fontname;
				MCStringCreateWithCString(tname, &t_fontname);
				pgptr -> SetTextFontOfCharChunk(ctxt, t_first, t_last, *t_fontname);
			}
			if (tsize != 0xFFFF)
			{
				uinteger_t t_size;
				t_size = tsize;
				pgptr -> SetTextSizeOfCharChunk(ctxt, t_first, t_last, &t_size);
			}
			if (tstyle != FA_DEFAULT_STYLE)
			{
				MCInterfaceTextStyle t_style;
				t_style . style = tstyle;
				pgptr -> SetTextStyleOfCharChunk(ctxt, t_first, t_last, t_style);
			}
		}
		// the line and its line end
		t_line_start += length + 1;
	}
	while (eptr != NULL);
	fptr->setparagraphs(paragraphs);
	return fptr;
}

MCCdata *MCHctext::buildb()
{
	MCCdata *bptr = new (nothrow) MCCdata(cid);
	bptr->setset(string[0] == '1');
	return bptr;
}

char *MCHctext::buildm()
{
	char *tstring = string;
	string = NULL;
	return tstring;
}

MCHcfield::MCHcfield()
{
	name = NULL;
	script = NULL;
	text = NULL;
}

MCHcfield::~MCHcfield()
{
	delete[] name;
	delete[] script;
	while (text != NULL)
	{
		MCHctext *tptr = text->remove
		                 (text);
		delete tptr;
	}
}

IO_stat MCHcfield::parse(char *sptr, uint4 p_size)
{
	if (p_size < 30)
		return IO_ERROR;
	id = hc_get_uint2(&sptr[2]);
	rect = hc_read_part_rect(sptr);
	atts = (uint2(uint1(sptr[5])) << 8) | uint1(sptr[14]);
	style = uint1(sptr[15]);
	tfont = hc_get_uint2(&sptr[22]);
	tsize = hc_get_uint2(&sptr[24]);
	hctstyle = hc_get_uint2(&sptr[26]);
	tstyle = convert_style(hctstyle);
	talign = uint1(sptr[21]);
	theight = hc_get_uint2(&sptr[28]);
	hc_read_name_and_script(&sptr[30], p_size - 30, 2, name, script);
	return IO_NORMAL;
}

MCControl *MCHcfield::build(MCHcstak *hcsptr, MCStack *sptr)
{
	MCField *fptr = (MCField *)MCtemplatefield->clone(False, OP_NONE, false);
	fptr->parent = sptr;
	if (name != NULL)
		hc_setname(fptr, name);
	delete[] name;
	fptr->altid = id;
	fptr->obj_id = ++maxid;
	if (script != NULL)
	{
		MCAutoStringRef t_script;
		if (hc_string(script, &t_script))
			fptr->setscript(*t_script);
		delete[] script;
	}
	name = script = NULL;
	fptr->rect = rect;
	fptr->fontheight = theight;
	const char *fontname = hcsptr->getfont(tfont);
	if (fontname != NULL || tsize != HC_DEFAULT_TEXT_SIZE
	        || tstyle != FA_DEFAULT_STYLE)
	{
		if (fontname == NULL)
			fontname = HC_DEFAULT_TEXT_FONT;

		// MW-2012-02-17: [[ LogFonts ]] Set the font attributes of the object.
        MCAutoStringRef t_fontname;
        /* UNCHECKED */ MCStringCreateWithCString(fontname, &t_fontname);
		fptr -> setfontattrs(*t_fontname, tsize, tstyle);
	}
	fptr->flags &= ~(F_STYLE | F_DISPLAY_STYLE | F_SHOW_LINES | F_LOCK_TEXT
	                 | F_AUTO_TAB | F_SHARED_TEXT
	                 | F_F_DONT_SEARCH | F_DONT_WRAP);
	if (atts & HC_F_MARGINS)
	{
		fptr->leftmargin = fptr->rightmargin =
		                       fptr->topmargin = fptr->bottommargin = 14;
	}
	else
	{
		fptr->leftmargin = fptr->rightmargin =
		                       fptr->topmargin = fptr->bottommargin = 8;
	}

	if (!(fptr->flags & F_LOCK_TEXT))
		rect = MCU_reduce_rect(rect, -MCfocuswidth);
	else
		fptr->flags &= ~F_TRAVERSAL_ON;

	if (atts & HC_F_MULTIPLE)
		fptr->flags |= F_MULTIPLE_HILITES;
	if (atts & HC_F_AUTO_SELECT)
		fptr->flags |= F_LIST_BEHAVIOR | F_TRAVERSAL_ON;
	if (atts & HC_F_SHOW_LINES)
		fptr->flags |= F_SHOW_LINES;
	if (atts & HC_F_LOCK_TEXT)
	{
		fptr->flags |= F_LOCK_TEXT;
		if (!(atts & HC_F_AUTO_SELECT))
			fptr->flags &= ~F_TRAVERSAL_ON;
	}
	if (atts & HC_F_AUTO_TAB)
		fptr->flags |= F_AUTO_TAB;
	if (atts & HC_F_UNFIXED_HEIGHT)
		fptr->flags &= ~F_FIXED_HEIGHT;
	if (atts & HC_F_SHARED_TEXT)
		fptr->flags |= F_SHARED_TEXT | F_LOCK_TEXT;
	if (atts & HC_F_DONT_SEARCH)
		fptr->flags |= F_F_DONT_SEARCH;
	if (atts & HC_F_DONT_WRAP)
		fptr->flags |= F_DONT_WRAP;
	if (atts & HC_F_INVISIBLE)
		fptr->flags &= ~F_VISIBLE;

	switch (talign)
	{
	case HC_TALIGN_LEFT:
		fptr->flags |= F_ALIGN_LEFT;
		break;
	case HC_TALIGN_CENTER:
		fptr->flags |= F_ALIGN_CENTER;
		break;
	case HC_TALIGN_RIGHT:
		fptr->flags |= F_ALIGN_RIGHT;
		break;
	}
	switch (style)
	{
	case HC_FSTYLE_TRANS:
		fptr->flags |= F_3D;
		break;
	case HC_FSTYLE_OPAQUE:
		fptr->flags |= F_OPAQUE | F_3D;
		break;
	case HC_FSTYLE_RECT:
		fptr->flags |= F_SHOW_BORDER | F_OPAQUE | F_3D;
		break;
	case HC_FSTYLE_SHADOW:
		fptr->flags |= F_SHOW_BORDER | F_OPAQUE | F_SHADOW;
		break;
	case HC_FSTYLE_SCROLL:
		fptr->flags |= F_SHOW_BORDER | F_OPAQUE | F_3D;
		fptr->flags &= ~F_SHOW_LINES;
		if (!(fptr->flags & F_VSCROLLBAR))
		{
			fptr->flags |= F_VSCROLLBAR;
			fptr->vscrollbar = new (nothrow) MCScrollbar(*MCtemplatescrollbar);
			fptr->vscrollbar->setparent(fptr);
			fptr->vscrollbar->allowmessages(False);
			fptr->vscrollbar->setflag(False, F_TRAVERSAL_ON);
			fptr->setsbrects();
		}
		break;
	}
	if (hctstyle & HC_TSTYLE_OUTLINE)
	{
		fptr->ncolors = 1;
		fptr->colors = new (nothrow) MCColor;
		fptr->colors[0].red = fptr->colors[0].green
		                      = fptr->colors[0].blue = MAXUINT2;
		fptr->colornames = new (nothrow) MCStringRef[1];
		fptr->colornames[0] = nil;
		fptr->dflags |= DF_FORE_COLOR;
	}
	while (text != NULL)
	{
		MCHctext *tptr = text->remove
		                 (text);
		MCCdata *newfdata = tptr->buildf(hcsptr, fptr);
		newfdata->appendto(fptr->fdata);
		delete tptr;
	}
	return fptr;
}

MCHcbutton::MCHcbutton()
{
	name = NULL;
	script = NULL;
	text = NULL;
}

MCHcbutton::~MCHcbutton()
{
	delete[] name;
	delete[] script;
	while (text != NULL)
	{
		MCHctext *tptr = text->remove
		                 (text);
		delete tptr;
	}
}

IO_stat MCHcbutton::parse(char *sptr, uint4 p_size)
{
	if (p_size < 30)
		return IO_ERROR;
	id = hc_get_uint2(&sptr[2]);
	rect = hc_read_part_rect(sptr);
	atts = (uint2(uint1(sptr[5])) << 8) | uint1(sptr[14]);
	style = uint1(sptr[15]);
	titlewidth = hc_get_uint2(&sptr[16]);
	icon = hc_get_uint2(&sptr[18]);
	tfont = hc_get_uint2(&sptr[22]);
	tsize = hc_get_uint2(&sptr[24]);
	hctstyle = hc_get_uint2(&sptr[26]);
	tstyle = convert_style(hctstyle);
	talign = uint1(sptr[21]);
	hc_read_name_and_script(&sptr[30], p_size - 30, 2, name, script);
	return IO_NORMAL;
}

MCControl *MCHcbutton::build(MCHcstak *hcsptr, MCStack *sptr)
{
	MCButton *bptr = (MCButton *)MCtemplatebutton->clone(False, OP_NONE, false);
	bptr->parent = sptr;
	if (name != NULL)
		hc_setname(bptr, name);
	delete[] name;
	bptr->altid = id;
	bptr->obj_id = ++maxid;
	bptr->rect = rect;
	if (script != NULL)
	{
		MCAutoStringRef t_script;
		if (hc_string(script, &t_script))
			bptr->setscript(*t_script);
		delete[] script;
	}
	name = script = NULL;
	bptr->flags &= ~(F_STYLE | F_DISPLAY_STYLE | F_ALIGNMENT | F_SHOW_ICON
	                 | F_TRAVERSAL_ON | F_SHOW_NAME | F_AUTO_HILITE
	                 | F_SHARED_HILITE | F_HILITE_MODE | F_ARM_MODE);
	bptr->family = atts & 0x0F;
	if (!(atts & HC_B_NOT_SHARED))
		bptr->flags |= F_SHARED_HILITE;
	if (atts & HC_B_SHOW_NAME)
		bptr->flags |= F_SHOW_NAME;
	if (atts & HC_B_AUTO_HILITE || bptr->family)
		bptr->flags |= F_AUTO_HILITE;
	if (atts & HC_B_INVISIBLE)
		bptr->flags &= ~F_VISIBLE;
	if (atts & HC_B_DISABLED)
		bptr->flags |= F_DISABLED;
	while (text != NULL)
	{
		MCHctext *tptr = text->remove
		                 (text);
		if (!(bptr->flags & F_SHARED_HILITE) && tptr->cid != 0)
		{
			MCCdata *newbdata = tptr->buildb();
			newbdata->appendto(bptr->bdata);
		}
		else
		{
			MCStringRef t_menustring = nil;
			char *t_menu = tptr->buildm();
			/* UNCHECKED */ hc_string(t_menu != NULL ? t_menu : "", t_menustring);
			delete[] t_menu;
			MCValueAssign(bptr->menustring, t_menustring);
			MCValueRelease(t_menustring);
		}
		delete tptr;
	}
	switch (style)
	{
	case HC_BSTYLE_TRANS:
		bptr->flags |= F_RECTANGLE | F_3D;
		break;
	case HC_BSTYLE_OPAQUE:
		bptr->flags |= F_RECTANGLE | F_OPAQUE | F_3D | F_HILITE_FILL;
		break;
	case HC_BSTYLE_DEFAULT:
		bptr->flags |= F_DEFAULT;
	case HC_BSTYLE_STANDARD:
		bptr->flags |= F_STANDARD | F_SHOW_BORDER | F_OPAQUE
		               | F_3D | F_HILITE_BOTH | F_ARM_BORDER;
		break;
	case HC_BSTYLE_RECT:
		bptr->flags |= F_RECTANGLE | F_SHOW_BORDER | F_OPAQUE
		               | F_3D | F_HILITE_BOTH | F_ARM_BORDER;
		break;
	case HC_BSTYLE_SHADOW:
		bptr->flags |= F_RECTANGLE | F_SHOW_BORDER | F_OPAQUE
		               | F_SHADOW | F_HILITE_BOTH;
		break;
	case HC_BSTYLE_ROUND:
		bptr->flags |=  F_ROUNDRECT | F_SHOW_BORDER | F_OPAQUE | F_HILITE_FILL;
		break;
	case HC_BSTYLE_CHECK:
		bptr->flags |= F_CHECK | F_3D;
		talign = HC_TALIGN_LEFT;
		icon = 0;
		break;
	case HC_BSTYLE_RADIO:
		bptr->flags |= F_RADIO | F_3D;
		talign = HC_TALIGN_LEFT;
		icon = 0;
		break;
	case HC_BSTYLE_OVAL:
		bptr->flags |= F_OVAL_BUTTON | F_HILITE_FILL;
		break;
	case HC_BSTYLE_POPUP:
		bptr->flags |= F_MENU | F_3D | F_SHOW_BORDER | F_OPAQUE
		               | F_ALIGN_CENTER | F_ARM_BORDER;
		bptr->menumode = WM_OPTION;
		talign = HC_TALIGN_LEFT;
		bptr->menuhistory = icon;
		bptr->labelwidth = titlewidth;
		icon = 0;
		bptr->resetlabel();
		break;
	}
	switch (talign)
	{
	case HC_TALIGN_LEFT:
		bptr->flags |= F_ALIGN_LEFT;
		break;
	case HC_TALIGN_CENTER:
		bptr->flags |= F_ALIGN_CENTER;
		break;
	case HC_TALIGN_RIGHT:
		bptr->flags |= F_ALIGN_RIGHT;
		break;
	}
	uint4 iid = hcsptr->geticon(icon);
	if (iid != 0)
	{
		bptr->icons = new (nothrow) iconlist;
		memset(bptr->icons, 0, sizeof(iconlist));
		bptr->icons->iconids[CI_DEFAULT] = iid;	
		bptr->flags |= F_SHOW_ICON;

		// MW-2012-02-17: [[ LogFonts ]] Set the font attributes of the object.
		bptr -> setfontattrs(MCSTR("textfont"), 9, FA_DEFAULT_STYLE);
		bptr -> fontheight = 12;
	}
	else
	{
		bptr->fontheight = heightfromsize(tsize);
		const char *fontname = hcsptr->getfont(tfont);
		if (fontname != NULL || tsize != HC_DEFAULT_TEXT_SIZE
		        || tstyle != FA_DEFAULT_STYLE)
		{
			if (fontname == NULL)
				fontname = HC_DEFAULT_TEXT_FONT;

			// MW-2012-02-17: [[ LogFonts ]] Set the font attributes of the object.
            MCAutoStringRef t_fontname;
            /* UNCHECKED */ MCStringCreateWithCString(fontname, &t_fontname);
			bptr -> setfontattrs(*t_fontname, tsize, tstyle);
		}
	}
	if (hctstyle & HC_TSTYLE_OUTLINE)
	{
		bptr->ncolors = 1;
		bptr->colors = new (nothrow) MCColor;
		bptr->colors[0].red = bptr->colors[0].green = bptr->colors[0].blue = MAXUINT2;
		bptr->colornames = new (nothrow) MCStringRef[1];
		bptr->colornames[0] = nil;
		bptr->dflags |= DF_FORE_COLOR;
	}
	if (bptr->flags & F_SHARED_HILITE)
	{
		MCCdata *newbdata = new (nothrow) MCCdata(0);
		newbdata->setset(atts & HC_B_HILITED);
		newbdata->appendto(bptr->bdata);
	}
	return bptr;
}

MCHcbmap::MCHcbmap()
{
    m_name = MCValueRetain(kMCEmptyName);
	mask = nil;
	data = nil;
	visible = True;
	xhot = yhot = 1;
}

MCHcbmap::~MCHcbmap()
{
    MCValueRelease(m_name);
	if (data != nil)
		MCMemoryDeleteArray(data);
	if (mask != nil)
		MCMemoryDeleteArray(mask);
}

void MCHcbmap::setvisible(Boolean newvis)
{
	visible = newvis;
}

void MCHcbmap::icon(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length)
{
	id = inid;
    MCValueAssign(m_name, inname);
	rect.x = iconx;
	rect.y = icony;
	iconx += 32;
	if (iconx >= 512)
	{
		iconx = 0;
		icony += 32;
	}
	rect.width = rect.height = 32;
	// IM-2014-04-08: [[ Bug 12101 ]] Copy raw bitmap to data
	/* UNCHECKED */ MCMemoryNewArray(128, data);
	if (data != nil)
		MCMemoryCopy(data, sptr, MCU_min(p_length, (uint4)128));
}

void MCHcbmap::cursor(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length)
{
	id = inid;
    MCValueAssign(m_name, inname);
	rect.x = cursorx;
	rect.y = cursory;
	cursorx += 16;
	if (cursorx >= 512)
	{
		cursorx = 0;
		cursory += 16;
	}
	rect.width = rect.height = 16;
	mrect = rect;
	// A CURS resource is 68 bytes: the image, the mask, then the hot spot.
	char t_curs[68];
	memset(t_curs, 0, sizeof(t_curs));
	memcpy(t_curs, sptr, MCU_min(p_length, (uint4)sizeof(t_curs)));
	// IM-2014-04-08: [[ Bug 12101 ]] Copy raw bitmaps to data and mask
	// The cursor's rows are 2 bytes; the bitmaps here pad rows to 4.
	uint32_t t_stride = MCHCBitmapStride(16);
	/* UNCHECKED */ MCMemoryNewArray(t_stride * 16, data);
	/* UNCHECKED */ MCMemoryNewArray(t_stride * 16, mask);
	for (uint32_t y = 0 ; data != nil && mask != nil && y < 16 ; y++)
	{
		memcpy(&data[y * t_stride], &t_curs[y * 2], 2);
		memcpy(&mask[y * t_stride], &t_curs[32 + y * 2], 2);
	}
	xhot = hc_get_uint2(&t_curs[64]);
	yhot = hc_get_uint2(&t_curs[66]);
}

// Read a BMAP rectangle (top, left, bottom, right) as the 32-pixel aligned
// rectangle its bitmap is stored in.
static MCRectangle hc_read_bmap_rect(const char *sptr, MCRectangle &r_exact)
{
	int4 t_top = hc_get_int2(&sptr[0]);
	int4 t_left = hc_get_int2(&sptr[2]);
	int4 t_bottom = hc_get_int2(&sptr[4]);
	int4 t_right = hc_get_int2(&sptr[6]);
	r_exact.x = t_left;
	r_exact.y = t_top;
	r_exact.width = MCU_max(t_right - t_left, 0);
	r_exact.height = MCU_max(t_bottom - t_top, 0);
	MCRectangle t_rect;
	t_rect.x = t_left & 0xFFE0;
	t_rect.y = t_top;
	t_rect.width = MCU_max((t_right - t_rect.x + 31) & 0xFFE0, 0);
	t_rect.height = r_exact.height;
	return t_rect;
}

IO_stat MCHcbmap::parse(char *sptr, uint4 p_size)
{
	// version 1 blocks have no filler after the id, so every field is 4
	// bytes earlier
	uint4 t_shift = version == 1 ? 4 : 0;
	if (p_size < 64 - t_shift)
		return IO_ERROR;
	id = hc_get_uint4(&sptr[8]);
	maxid = MCU_max(id, maxid);
	MCRectangle t_exact_mask, t_exact_rect;
	mrect = hc_read_bmap_rect(&sptr[32 - t_shift], t_exact_mask);
	rect = hc_read_bmap_rect(&sptr[40 - t_shift], t_exact_rect);
	uint4 masksize = hc_get_uint4(&sptr[56 - t_shift]);
	uint4 datasize = hc_get_uint4(&sptr[60 - t_shift]);
	uint4 offset = 64 - t_shift;
	if (masksize > p_size - offset)
		masksize = p_size - offset;
	// IM-2014-04-08: [[ Bug 12101 ]] Decode bitmap to mask
	if (masksize != 0 && mrect.width != 0 && mrect.height != 0)
		/* UNCHECKED */ convert_hcbitmap_data((uint1 *)&sptr[offset], masksize, mrect.width, mrect.height, mrect.y, mask);
	else if (t_exact_mask.width != 0 && t_exact_mask.height != 0)
	{
		// A mask rectangle with no mask data is an opaque rectangle: the
		// white of the picture inside it hides what is behind it.
		uint32_t t_stride = MCHCBitmapStride(mrect.width);
		if (MCMemoryNewArray(t_stride * mrect.height, mask))
		{
			uint32_t t_from = t_exact_mask.x - mrect.x;
			uint32_t t_to = t_from + t_exact_mask.width;
			for (uint32_t y = 0 ; y < mrect.height ; y++)
				for (uint32_t x = t_from ; x < t_to ; x++)
					mask[y * t_stride + (x >> 3)] |= 0x80 >> (x & 7);
		}
	}
	offset += masksize;
	if (datasize > p_size - offset)
		datasize = p_size - offset;
	// IM-2014-04-08: [[ Bug 12101 ]] Decode bitmap to data
	if (rect.width != 0 && rect.height != 0)
		/* UNCHECKED */ convert_hcbitmap_data((uint1 *)&sptr[offset], datasize, rect.width, rect.height, rect.y, data);
	else if (mask != nil)
	{
		// a picture that is only white: no black pixels, in the mask's area
		rect = mrect;
		/* UNCHECKED */ MCMemoryNewArray(MCHCBitmapStride(rect.width) * rect.height, data);
	}
	return IO_NORMAL;
}

void MCImageBitmapApplyPlane(MCImageBitmap *p_dst, uint8_t *p_src, uindex_t p_src_stride, uint32_t p_value);
void surface_merge_with_mask(void *p_pixels, uint4 p_pixel_stride, void *p_mask, uint4 p_mask_stride, uint4 p_offset, uint4 p_width, uint4 p_height);
MCControl *MCHcbmap::build()
{
	if (data == nil)
		return nil;

	uint8_t *data2;
	data2 = nil;

	if (mask == nil)
	{
		// IM-2014-04-08: [[ Bug 12101 ]] Use data bitmap as mask if not given
		/* UNCHECKED */ MCMemoryAllocateCopy(data, rect.height * MCHCBitmapStride(rect.width), mask);
        mrect = rect;
	}
	else
	{
		MCRectangle trect = MCU_union_rect(mrect, rect);

		uint32_t t_stride;
		t_stride = MCHCBitmapStride(trect.width);

		uint32_t t_bytes;
		t_bytes = t_stride * trect.height;

		if (!MCU_equal_rect(trect, mrect))
		{
			// IM-2014-04-08: [[ Bug 12101 ]] Resize mask bitmap to new size
			uint8_t *t_newmask;
			t_newmask = nil;

			/* UNCHECKED */ MCMemoryNewArray(t_bytes, t_newmask);

			uint32_t t_mask_stride;
			t_mask_stride = MCHCBitmapStride(mrect.width);

			uint4 sbpl = t_mask_stride;
			uint4 offset = (mrect.y - trect.y) * t_stride + (mrect.x - trect.x) / 8;
			for (uint32_t i = 0 ; i < mrect.height ; i++)
				MCMemoryCopy(&t_newmask[i * t_stride + offset], &mask[i * sbpl], sbpl);
			MCMemoryDeleteArray(mask);
			mask = t_newmask;
			mrect = trect;
		}

		if (!MCU_equal_rect(trect, rect))
		{
			// IM-2014-04-08: [[ Bug 12101 ]] Resize data bitmap to new size
			uint8_t* t_newdata;
			t_newdata = nil;

			/* UNCHECKED */ MCMemoryNewArray(t_bytes, t_newdata);

			uint4 sbpl = MCHCBitmapStride(rect.width);
			uint4 offset = (rect.y - trect.y) * t_stride + (rect.x - trect.x) / 8;
			for (uint32_t i = 0 ; i < rect.height ; i++)
				MCMemoryCopy(&t_newdata[i * t_stride + offset], &data[i * sbpl], sbpl);
			MCMemoryDeleteArray(data);
			data = t_newdata;
			rect = trect;
		}

		// IM-2014-04-08: [[ Bug 12101 ]] Make bits set in data opaque in mask
		uint4 bytes = t_bytes;
		uint1 *sptr = data;
		uint1 *dptr = mask;
		while (bytes--)
			*dptr++ |= *sptr++;

		// IM-2014-04-08: [[ Bug 12101 ]] Extract bits set in mask but not in data - these will be opaque white in final image
		/* UNCHECKED */ MCMemoryAllocateCopy(mask, t_bytes, data2);
		bytes = t_bytes;
		sptr = data;
		dptr = data2;
		while (bytes--)
			*dptr++ ^= *sptr++;
	}

	MCImage *iptr = (MCImage *)MCtemplateimage->clone(False, OP_NONE, false);

	iptr->obj_id = id;
	iptr->rect = rect;
	if (!visible)
		iptr->flags &= ~F_VISIBLE;
	iptr->flags |= MCscreen->getpad() >> 3;
	iptr->flags |= F_RLE;

	uint32_t t_bytes, t_stride;
	t_stride = MCHCBitmapStride(rect.width);
	t_bytes = t_stride * rect.height;

	MCImageBitmap *t_bitmap = nil;
	MCImageCompressedBitmap *t_compressed = nil;
	/* UNCHECKED */ MCImageBitmapCreate(rect.width, rect.height, t_bitmap);
	// set first plane to opaque black
	MCImageBitmapApplyPlane(t_bitmap, data, t_stride, 0xFF000000);
	// set second plane to opaque white
	if (data2 != nil)
		MCImageBitmapApplyPlane(t_bitmap, data2, t_stride, 0xFFFFFFFF);
	if (mask != nil)
	{
		surface_merge_with_mask(t_bitmap->data, t_bitmap->stride, mask, t_stride, 0, rect.width, rect.height);
		MCImageBitmapCheckTransparency(t_bitmap);
	}
	MCImageCompress(t_bitmap, false, t_compressed);
	iptr->setcompressedbitmap(t_compressed);
	MCImageFreeBitmap(t_bitmap);
	MCImageFreeCompressedBitmap(t_compressed);

	if (mask != nil)
		MCMemoryDeleteArray(mask);
	if (data != nil)
		MCMemoryDeleteArray(data);
	if (data2 != nil)
		MCMemoryDeleteArray(data2);

	mask = data = data2 = nil;

	iptr->setname(m_name);
	iptr->xhot = xhot;
	iptr->yhot = yhot;
	return iptr;
}

MCHccard::MCHccard()
{
	name = NULL;
	script = NULL;
	objects = NULL;
	hcbuttons = NULL;
	hcfields = NULL;
	hctexts = NULL;
}

MCHccard::~MCHccard()
{
	delete[] name;
	delete[] script;
	delete[] objects;
	while (hcbuttons != NULL)
	{
		MCHcbutton *bptr = hcbuttons->remove
		                   (hcbuttons);
		delete bptr;
	}
	while (hcfields != NULL)
	{
		MCHcfield *fptr = hcfields->remove
		                  (hcfields);
		delete fptr;
	}
	while (hctexts != NULL)
	{
		MCHctext *fptr = hctexts->remove
		                 (hctexts);
		delete fptr;
	}
}

// Parse the parts, contents, name and script of a card or background
// block. p_offset is the offset of the first part. Every record is checked
// against the block size: a record that would run past the end stops the
// parse there, keeping what was read before it.
static void hc_parse_layer(char *sptr, uint4 p_size, uint4 p_offset, uint2 &x_nobjects, uint2 p_ntext,
                           uint4 p_cid, uint2 *&r_objects, MCHcbutton *&x_buttons, MCHcfield *&x_fields,
                           MCHctext *&x_texts, char *&r_name, char *&r_script)
{
	uint4 offset = p_offset;
	uint2 t_wanted = x_nobjects;
	x_nobjects = 0;
	if (t_wanted)
		r_objects = new (nothrow) uint2[t_wanted];
	uint2 i;
	for (i = 0 ; i < t_wanted ; i++)
	{
		if (offset > p_size || p_size - offset < 30)
		{
			hcstat_append("Error: part %d of block %d runs past its end", (int)i + 1, (int)p_cid);
			break;
		}
		uint4 t_part_size = hc_get_uint2(&sptr[offset]);
		if (t_part_size < 30 || t_part_size > p_size - offset)
		{
			hcstat_append("Error: part %d of block %d has a bad size (%d)", (int)i + 1, (int)p_cid, (int)t_part_size);
			break;
		}
		uint2 t_type = uint1(sptr[offset + 4]);
		r_objects[x_nobjects++] = t_type;
		switch (t_type)
		{
		case HC_OTYPE_BUTTON:
			{
				MCHcbutton *newbutton = new (nothrow) MCHcbutton;
				newbutton->appendto(x_buttons);
				newbutton->parse(&sptr[offset], t_part_size);
			}
			break;
		case HC_OTYPE_FIELD:
			{
				MCHcfield *newfield = new (nothrow) MCHcfield;
				newfield->appendto(x_fields);
				newfield->parse(&sptr[offset], t_part_size);
			}
			break;
		default:
			hcstat_append("Error: unknown object type %x", t_type);
			break;
		}
		offset += t_part_size;
	}
	while (p_ntext--)
	{
		if (offset >= p_size)
		{
			hcstat_append("Error: the text of block %d runs past its end", (int)p_cid);
			break;
		}
		MCHctext *newtext = new (nothrow) MCHctext;
		newtext->cid = p_cid;
		newtext->appendto(x_texts);
		uint4 t_length = 0;
		if (newtext->parse(&sptr[offset], p_size - offset, t_length) != IO_NORMAL || t_length == 0)
			break;
		offset += t_length;
	}
	if (offset < p_size)
		hc_read_name_and_script(&sptr[offset], p_size - offset, 1, r_name, r_script);
}

IO_stat MCHccard::parse(char *sptr, uint4 p_size)
{
	// version 1 blocks have no filler after the id
	uint4 t_shift = version == 1 ? 4 : 0;
	if (p_size < 54 - t_shift)
		return IO_ERROR;
	id = hc_get_uint4(&sptr[8]);
	maxid = MCU_max(id, maxid);
	bmapid = hc_get_uint4(&sptr[16 - t_shift]);
	atts = uint1(sptr[20 - t_shift]);
	bkgdid = hc_get_uint4(&sptr[36 - t_shift]);
	nobjects = hc_get_uint2(&sptr[40 - t_shift]);
	uint2 ntext = hc_get_uint2(&sptr[48 - t_shift]);
	hc_parse_layer(sptr, p_size, 54 - t_shift, nobjects, ntext, id, objects, hcbuttons, hcfields, hctexts, name, script);
	return IO_NORMAL;
}

MCCard *MCHccard::build(MCHcstak *hcsptr, MCStack *sptr)
{
	MCObjptr *newoptr;
	MCCard *cptr = MCtemplatecard->clone(False, False);
	cptr->obj_id = id;
	if (name != NULL)
		hc_setname(cptr, name);
	delete[] name;
	if (script != NULL)
	{
		MCAutoStringRef t_script;
		if (hc_string(script, &t_script))
			cptr->setscript(*t_script);
		delete[] script;
	}
	name = script = NULL;
	if (atts & HC_BC_DONT_SEARCH)
		cptr->flags |= F_C_DONT_SEARCH;
	if (atts & HC_BC_CANT_DELETE)
		cptr->flags |= F_C_CANT_DELETE;
	newoptr = new (nothrow) MCObjptr;
	newoptr->setparent(cptr);
	newoptr->setid(bkgdid);
	newoptr->appendto(cptr->objptrs);
	if (bmapid != 0)
	{
		newoptr = new (nothrow) MCObjptr;
		newoptr->setparent(cptr);
		newoptr->setid(bmapid);
		newoptr->appendto(cptr->objptrs);
		MCHcbmap *bmptr = hcsptr->getbmap(bmapid);
		if (bmptr != NULL)
			bmptr->setvisible((atts & HC_BC_HIDE_BMAP) == 0);
	}
	MCHcbkgd *bgptr = hcsptr->getbkgd(bkgdid);
	if (bgptr == NULL)
		hcstat_append("Error: card %d has no background %d", (int)id, (int)bkgdid);
	while (hctexts != NULL)
	{
		MCHctext *tptr = hctexts->remove
		                 (hctexts);
		if (tptr->card)
		{
			MCHcfield *fptr = findfield(hcfields, tptr->id);
			if (fptr != NULL)
				tptr->appendto(fptr->text);
			else
			{
				MCHcbutton *bptr = findbutton(hcbuttons, tptr->id);
				if (bptr != NULL)
					tptr->appendto(bptr->text);
				else
					delete tptr;
			}
		}
		else if (bgptr == NULL)
			delete tptr;
		else
		{
			MCHcfield *fptr = findfield(bgptr->hcfields, tptr->id);
			if (fptr != NULL)
				tptr->appendto(fptr->text);
			else
			{
				MCHcbutton *bptr = findbutton(bgptr->hcbuttons, tptr->id);
				if (bptr != NULL)
					tptr->appendto(bptr->text);
				else
					delete tptr;
			}
		}
	}
	uint2 i;
	for (i = 0 ; i < nobjects ; i++)
		switch (objects[i])
		{
		case HC_OTYPE_BUTTON:
			{
				MCHcbutton *bptr = hcbuttons->remove
				                   (hcbuttons);
				MCControl *newbutton = bptr->build(hcsptr, sptr);
				newbutton->setparent(sptr);
				newbutton->appendto(sptr->controls);
				newoptr = new (nothrow) MCObjptr;
				newoptr->setparent(cptr);
				newoptr->setid(newbutton->getid());
				newoptr->appendto(cptr->objptrs);
				delete bptr;
			}
			break;
		case HC_OTYPE_FIELD:
			{
				MCHcfield *fptr = hcfields->remove
				                  (hcfields);
				MCControl *newfield = fptr->build(hcsptr, sptr);
				newfield->setparent(sptr);
				newfield->appendto(sptr->controls);
				newoptr = new (nothrow) MCObjptr;
				newoptr->setparent(cptr);
				newoptr->setid(newfield->getid());
				newoptr->appendto(cptr->objptrs);
				delete fptr;
			}
			break;
		}
	return cptr;
}

MCHcbkgd::MCHcbkgd()
{
	name = NULL;
	script = NULL;
	objects = NULL;
	hcbuttons = NULL;
	hcfields = NULL;
	hctexts = NULL;
	nextid = 0;
}

MCHcbkgd::~MCHcbkgd()
{
	delete[] name;
	delete[] script;
	delete[] objects;
	while (hcbuttons != NULL)
	{
		MCHcbutton *bptr = hcbuttons->remove
		                   (hcbuttons);
		delete bptr;
	}
	while (hcfields != NULL)
	{
		MCHcfield *fptr = hcfields->remove
		                  (hcfields);
		delete fptr;
	}
	while (hctexts != NULL)
	{
		MCHctext *fptr = hctexts->remove
		                 (hctexts);
		delete fptr;
	}
}

IO_stat MCHcbkgd::parse(char *sptr, uint4 p_size)
{
	// version 1 blocks have no filler after the id
	uint4 t_shift = version == 1 ? 4 : 0;
	if (p_size < 50 - t_shift)
		return IO_ERROR;
	id = hc_get_uint4(&sptr[8]);
	maxid = MCU_max(id, maxid);
	bmapid = hc_get_uint4(&sptr[16 - t_shift]);
	atts = uint1(sptr[20 - t_shift]);
	nextid = hc_get_uint4(&sptr[28 - t_shift]);
	nobjects = hc_get_uint2(&sptr[36 - t_shift]);
	uint2 ntext = hc_get_uint2(&sptr[44 - t_shift]);
	// background contents belong to no card: cid 0
	hc_parse_layer(sptr, p_size, 50 - t_shift, nobjects, ntext, 0, objects, hcbuttons, hcfields, hctexts, name, script);
	return IO_NORMAL;
}

MCGroup *MCHcbkgd::build(MCHcstak *hcsptr, MCStack *sptr)
{
	MCGroup *gptr = (MCGroup *)MCtemplategroup->clone(False, OP_NONE, false);
	// MW-2011-08-09: [[ Groups ]] HC backgrounds are shared.
	gptr->flags = (gptr -> flags & ~F_GROUP_ONLY) | F_GROUP_SHARED;
	gptr->obj_id = id;
	if (name != NULL)
		hc_setname(gptr, name);
	delete[] name;
	gptr->rect = sptr->getrect();
	gptr->rect.x = gptr->rect.y = 0;
	if (script != NULL)
	{
		MCAutoStringRef t_script;
		if (hc_string(script, &t_script))
			gptr->setscript(*t_script);
		delete[] script;
	}
	name = script = NULL;
	if (atts & HC_BC_DONT_SEARCH)
		gptr->flags |= F_G_DONT_SEARCH;
	if (atts & HC_BC_CANT_DELETE)
		gptr->flags |= F_G_CANT_DELETE;
	if (bmapid != 0)
	{
		MCHcbmap *bmptr = hcsptr->removebmap(bmapid);
		MCControl *iptr = NULL;
		if (bmptr != NULL)
		{
			bmptr->setvisible((atts & HC_BC_HIDE_BMAP) == 0);
			iptr = bmptr->build();
			delete bmptr;
		}
		if (iptr != NULL)
		{
			iptr->setparent(gptr);
			iptr->appendto(gptr->controls);
		}
	}
	while (hctexts != NULL)
	{
		MCHctext *tptr = hctexts->remove
		                 (hctexts);
		MCHcfield *fptr = findfield(hcfields, tptr->id);
		if (fptr != NULL)
			tptr->appendto(fptr->text);
		else
		{
			MCHcbutton *bptr = findbutton(hcbuttons, tptr->id);
			if (bptr != NULL)
				tptr->appendto(bptr->text);
			else
				delete tptr;
		}
	}
	uint2 i;
	for (i = 0 ; i < nobjects ; i++)
		switch (objects[i])
		{
		case HC_OTYPE_BUTTON:
			{
				MCHcbutton *bptr = hcbuttons->remove
				                   (hcbuttons);
				MCControl *newbutton = bptr->build(hcsptr, sptr);
				newbutton->setparent(gptr);
				newbutton->appendto(gptr->controls);
				delete bptr;
			}
			break;
		case HC_OTYPE_FIELD:
			{
				MCHcfield *fptr = hcfields->remove
				                  (hcfields);
				MCControl *newfield = fptr->build(hcsptr, sptr);
				newfield->setparent(gptr);
				newfield->appendto(gptr->controls);
				delete fptr;
			}
			break;
		}
	return gptr;
}

MCHcstak::MCHcstak(char *inname)
	: rect(kMCEmptyRectangle),
	  name(inname),
	  script(nullptr),
	  fullbuffer(nullptr),
	  buffer(nullptr),
	  pages(nullptr),
	  marks(nullptr),
	  npages(0),
	  fonts(nullptr),
	  atts(nullptr),
	  nfonts(0),
	  natts(0),
	  pagesize(0),
	  npbuffers(0),
	  pbuffersizes(nullptr),
	  pbufferids(nullptr),
	  pbuffers(nullptr),
	  nlistpages(0),
	  firstbkgd(0),
	  listpageids(nullptr),
	  listpagecounts(nullptr),
	  nfontbuffers(0),
	  fontbuffers(nullptr),
	  hcbkgds(nullptr),
	  hccards(nullptr),
	  hcbmaps(nullptr),
	  icons(nullptr),
	  cursors(nullptr),
	  snds(nullptr)
{
}

MCHcstak::~MCHcstak()
{
	delete[] name;
	delete[] script;
	delete[] fullbuffer;
	delete[] pages;
	delete[] marks;
	delete[] fonts;
	delete[] atts;
	uint4 i;
	for (i = 0 ; i < npbuffers ; i++)
		delete[] pbuffers[i];
	if (pbuffers != NULL)
	{
		delete[] pbuffers;
		delete[] pbuffersizes;
		delete[] pbufferids;
	}
	delete[] listpageids;
	delete[] listpagecounts;
	for (i = 0 ; i < nfontbuffers ; i++)
		delete[] fontbuffers[i];
	delete[] fontbuffers;
	while (hcbkgds != NULL)
	{
		MCHcbkgd *bgptr = hcbkgds->remove
		                  (hcbkgds);
		delete bgptr;
	}
	while (hcbmaps != NULL)
	{
		MCHcbmap *bmptr = hcbmaps->remove
		                  (hcbmaps);
		delete bmptr;
	}
	while (hccards != NULL)
	{
		MCHccard *cptr = hccards->remove
		                 (hccards);
		delete cptr;
	}
	while (icons != NULL)
	{
		MCHcbmap *bmptr = icons->remove
		                  (icons);
		delete bmptr;
	}
	while (cursors != NULL)
	{
		MCHcbmap *bmptr = cursors->remove
		                  (cursors);
		delete bmptr;
	}
	while (snds != NULL)
	{
		MCHcsnd *sptr = snds->remove
		                (snds);
		delete sptr;
	}
}

uint4 MCHcstak::geticon(uint2 iid)
{
	if (iid == 0)
		return 0;
	if (icons != NULL)
	{
		MCHcbmap *bptr = icons;
		do
		{
			if (bptr->id == iid)
				return iid;
			bptr = bptr->next();
		}
		while (bptr != icons);
	}
	uint2 i;
	for (i = 0 ; i < HC_NICONS ; i++)
		if (iid == hc_icons[i])
			return mc_icons[i];
	return HC_DEFAULT_ICON;
}

MCHcbmap *MCHcstak::getbmap(uint4 bid)
{
	MCHcbmap *bptr = hcbmaps;
	if (bptr == NULL)
		return NULL;
	do
	{
		if (bptr->id == bid)
			return bptr;
		bptr = bptr->next();
	}
	while (bptr != hcbmaps);
	return NULL;
}

MCHcbmap *MCHcstak::removebmap(uint4 bid)
{
	MCHcbmap *bptr = getbmap(bid);
	if (bptr == NULL)
		return NULL;
	return bptr->remove
	       (hcbmaps);
}

MCHcbkgd *MCHcstak::getbkgd(uint4 bid)
{
	MCHcbkgd *bptr = hcbkgds;
	if (bptr == NULL)
		return NULL;
	do
	{
		if (bptr->id == bid)
			return bptr;
		bptr = bptr->next();
	}
	while (bptr != hcbkgds);
	return NULL;
}

const char *MCHcstak::getfont(uint2 fid)
{
	uint2 i;
	for (i = 0 ; i < nfonts ; i++)
		if (fonts[i].id == fid)
			return fonts[i].name;
	return NULL;
}

void MCHcstak::getatts(uint2 aid, const char *&font,
                       uint2 &size, uint2 &style)
{
	uint2 i;
	for (i = 0 ; i < natts ; i++)
		if (atts[i].id == aid)
		{
			if (atts[i].fid != 0xFFFF)
				font = getfont(atts[i].fid);
			else
				font = NULL;
			size = atts[i].size;
			style = atts[i].style;
			return;
		}
	font = NULL;
	size = 0xFFFF;
	style = FA_DEFAULT_STYLE;
}

// Decode a BinHex 4.0 file into its data and resource forks. p_text is the
// file from the ':' that starts the encoded data. Returns false if the data
// is not well formed.
static bool hc_decode_binhex(const uint1 *p_text, uint4 p_length, char *&r_name,
                             uint1 *&r_data, uint4 &r_data_size, uint1 *&r_rsrc, uint4 &r_rsrc_size)
{
	static const char s_alphabet[] =
		"!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr";
	int1 t_value[256];
	memset(t_value, -1, sizeof(t_value));
	for (int i = 0 ; i < 64 ; i++)
		t_value[(uint1)s_alphabet[i]] = (int1)i;

	// 6-bit characters to 8-bit bytes
	uint1 *t_packed = new (nothrow) uint1[p_length * 3 / 4 + 3];
	if (t_packed == NULL)
		return false;
	uint4 t_packed_size = 0;
	uint4 t_bits = 0;
	uint4 t_nbits = 0;
	bool t_closed = false;
	for (uint4 i = 0 ; i < p_length ; i++)
	{
		uint1 c = p_text[i];
		if (c == ':')
		{
			t_closed = true;
			break;
		}
		if (c == '\r' || c == '\n' || c == ' ' || c == '\t')
			continue;
		if (t_value[c] < 0)
			break;
		t_bits = (t_bits << 6) | (uint4)t_value[c];
		t_nbits += 6;
		if (t_nbits >= 8)
		{
			t_nbits -= 8;
			t_packed[t_packed_size++] = uint1(t_bits >> t_nbits);
		}
	}
	if (!t_closed)
	{
		delete[] t_packed;
		return false;
	}

	// Run-length decoding: 0x90 n repeats the byte before it n times in all,
	// 0x90 0 is a 0x90.
	uint4 t_full_capacity = t_packed_size * 2 + 256;
	uint1 *t_full = (uint1 *)malloc(t_full_capacity);
	uint4 t_full_size = 0;
	bool t_ok = t_full != NULL;
	for (uint4 i = 0 ; t_ok && i < t_packed_size ; i++)
	{
		uint4 t_count = 1;
		uint1 t_byte = t_packed[i];
		if (t_byte == 0x90 && i + 1 < t_packed_size)
		{
			uint1 n = t_packed[++i];
			if (n != 0)
			{
				if (t_full_size == 0)
					continue;
				t_byte = t_full[t_full_size - 1];
				t_count = n - 1;
			}
		}
		if (t_full_size + t_count > t_full_capacity)
		{
			t_full_capacity = (t_full_size + t_count) * 2;
			uint1 *t_new = (uint1 *)realloc(t_full, t_full_capacity);
			if (t_new == NULL)
				t_ok = false;
			else
				t_full = t_new;
		}
		while (t_ok && t_count--)
			t_full[t_full_size++] = t_byte;
	}
	delete[] t_packed;

	// The header: name, version, type, creator, flags, the fork lengths and
	// a CRC, then each fork followed by its CRC.
	uint4 t_offset = 0;
	if (t_ok && t_full_size > 0)
		t_offset = 1 + t_full[0];
	if (!t_ok || t_full_size < t_offset + 21)
	{
		free(t_full);
		return false;
	}
	r_name = new (nothrow) char[t_full[0] + 1];
	memcpy(r_name, &t_full[1], t_full[0]);
	r_name[t_full[0]] = '\0';
	t_offset += 1;
	bool t_is_stack = memcmp(&t_full[t_offset], "STAK", 4) == 0;
	t_offset += 10;
	r_data_size = hc_get_uint4((const char *)&t_full[t_offset]);
	r_rsrc_size = hc_get_uint4((const char *)&t_full[t_offset + 4]);
	t_offset += 10;
	if (!t_is_stack || r_data_size > t_full_size - t_offset)
	{
		free(t_full);
		return false;
	}
	r_data = new (nothrow) uint1[r_data_size + 1];
	memcpy(r_data, &t_full[t_offset], r_data_size);
	t_offset += r_data_size + 2;
	r_rsrc = NULL;
	if (t_offset > t_full_size || r_rsrc_size > t_full_size - t_offset)
		r_rsrc_size = 0;
	if (r_rsrc_size != 0)
	{
		r_rsrc = new (nothrow) uint1[r_rsrc_size];
		memcpy(r_rsrc, &t_full[t_offset], r_rsrc_size);
	}
	free(t_full);
	return true;
}

// Read the resources HyperCard stacks keep in their resource fork: icons,
// cursors and sounds. Every offset is checked against the fork.
void MCHcstak::readresources(const uint1 *p_fork, uint4 p_size)
{
	const char *t_fork = (const char *)p_fork;
	if (p_size < 16)
		return;
	uint4 t_data_offset = hc_get_uint4(&t_fork[0]);
	uint4 t_map_offset = hc_get_uint4(&t_fork[4]);
	uint4 t_map_size = hc_get_uint4(&t_fork[12]);
	if (t_data_offset > p_size || t_map_offset > p_size || t_map_size > p_size - t_map_offset || t_map_size < 30)
	{
		hcstat_append("Error: bad resource fork");
		return;
	}
	const char *t_map = &t_fork[t_map_offset];
	uint4 t_types_offset = hc_get_uint2(&t_map[24]);
	uint4 t_names_offset = hc_get_uint2(&t_map[26]);
	if (t_types_offset + 2 > t_map_size)
		return;
	const char *t_types = &t_map[t_types_offset];
	uint2 typecount = uint2(hc_get_uint2(t_types) + 1);
	iconx = icony = cursorx = cursory = 0;
	for (uint2 i = 0 ; i < typecount ; i++)
	{
		uint4 t_entry = t_types_offset + 2 + i * 8;
		if (t_entry + 8 > t_map_size)
			break;
		uint4 t_type = hc_get_uint4(&t_map[t_entry]);
		uint4 count = uint4(uint2(hc_get_uint2(&t_map[t_entry + 4]) + 1));
		uint4 t_refs = t_types_offset + hc_get_uint2(&t_map[t_entry + 6]);
		for (uint4 j = 0 ; j < count ; j++)
		{
			uint4 t_ref = t_refs + j * 12;
			if (t_ref + 12 > t_map_size)
				break;
			uint2 id = hc_get_uint2(&t_map[t_ref]);
			uint2 soffset = hc_get_uint2(&t_map[t_ref + 2]);
			uint4 offset = hc_get_uint4(&t_map[t_ref + 4]) & 0xFFFFFF;

            MCNewAutoNameRef t_name;
            uint4 t_name_at = t_names_offset + soffset;
            if (soffset == UINT16_MAX || t_name_at >= t_map_size
                || t_name_at + 1 + (uint1)t_map[t_name_at] > t_map_size)
                t_name = kMCEmptyName;
            else
            {
                // a Pascal string, converted from MacRoman as the names of
                // the stack's objects are
                uint1 t_length = (uint1)t_map[t_name_at];
                char *t_raw = new (nothrow) char[t_length + 1];
                memcpy(t_raw, &t_map[t_name_at + 1], t_length);
                t_raw[t_length] = '\0';
                char *t_converted = convert_string(t_raw);
                delete[] t_raw;
                MCAutoStringRef t_string;
                if (!hc_string(t_converted, &t_string) || !MCNameCreate(*t_string, &t_name))
                    t_name = kMCEmptyName;
                delete[] t_converted;
            }

			if (offset > p_size - t_data_offset || p_size - t_data_offset - offset < 4)
				continue;
			char *t_resource = (char *)&t_fork[t_data_offset + offset + 4];
			uint4 t_length = hc_get_uint4(&t_fork[t_data_offset + offset]);
			if (t_length > p_size - t_data_offset - offset - 4)
				t_length = p_size - t_data_offset - offset - 4;
			switch (t_type)
			{
			case HC_ICON:
				{
					MCHcbmap *newicon = new (nothrow) MCHcbmap;
					newicon->appendto(icons);
					newicon->icon(id, *t_name, t_resource, t_length);
				}
				break;
			case HC_CURS:
				{
					MCHcbmap *newcurs = new (nothrow) MCHcbmap;
					newcurs->appendto(cursors);
					newcurs->cursor(id, *t_name, t_resource, t_length);
				}
				break;
			case HC_SND:
				{
					MCHcsnd *newsnd = new (nothrow) MCHcsnd;
					if (newsnd->import(id, *t_name, t_resource, t_length))
						newsnd->appendto(snds);
					else
						delete newsnd;
				}
				break;
			default:
                {
                    MCAutoStringRefAsCString t_name_str;
                    /* UNCHECKED */ t_name_str.Lock(MCNameGetString(*t_name));
                    hcstat_append("Not converting %4.4s id %5d \"%s\"",
                                  (char *)&t_map[t_entry], id, *t_name_str);
                }
				break;
			}
		}
	}
}

// Read a HyperCard stack: a bare data fork, a MacBinary file or a BinHex
// 4.0 file. The whole file is read, and every block is checked against
// the data fork before it is parsed.
IO_stat MCHcstak::read(IO_handle stream)
{
	char header[HC_HEADER_SIZE];
	if (IO_read(header, HC_HEADER_SIZE, stream) != IO_NORMAL)
		return IO_ERROR;

	HC_File_type filetype;
	if (hc_get_uint4(&header[4]) == HC_STAK)
		filetype = HC_RAW;
	else if (header[0] == '\0' && header[74] == '\0' && header[82] == '\0')
	{
		if (!strnequal(&header[65], "STAK", 4))
			return IO_ERROR;
		filetype = HC_MACBIN;
	}
	else
	{
		header[255] = '\0';
		uint4 foffset;
		if (!MCU_offset("BinHex", header, foffset))
			return IO_ERROR;
		filetype = HC_BINHEX;
	}

	uint4 t_file_size = (uint4)MCS_fsize(stream);
	uint1 *t_file = new (nothrow) uint1[t_file_size + 1];
	if (t_file == NULL)
		return IO_ERROR;
	MCS_seek_set(stream, 0);
	if (IO_read(t_file, t_file_size, stream) != IO_NORMAL)
	{
		delete[] t_file;
		return IO_ERROR;
	}
	t_file[t_file_size] = '\0';

	const uint1 *t_data = NULL;
	uint4 t_data_size = 0;
	const uint1 *t_rsrc = NULL;
	uint4 t_rsrc_size = 0;
	uint1 *t_decoded_data = NULL;
	uint1 *t_decoded_rsrc = NULL;
	switch (filetype)
	{
	case HC_RAW:
		t_data = t_file;
		t_data_size = t_file_size;
		break;
	case HC_MACBIN:
		{
			delete[] name;
			uint1 t_name_length = (uint1)header[1] > 63 ? 63 : (uint1)header[1];
			name = new (nothrow) char[t_name_length + 1];
			memcpy(name, &header[2], t_name_length);
			name[t_name_length] = '\0';
			t_data_size = hc_get_uint4(&header[83]);
			t_rsrc_size = hc_get_uint4(&header[87]);
			uint4 roffset = (128 + t_data_size + 127) & ~127U;
			if (t_data_size > t_file_size - 128)
				t_data_size = t_file_size - 128;
			t_data = t_file + 128;
			if (roffset >= t_file_size || t_rsrc_size > t_file_size - roffset)
				t_rsrc_size = 0;
			else
				t_rsrc = t_file + roffset;
		}
		break;
	case HC_BINHEX:
		{
			uint4 foffset;
			MCU_offset("BinHex", header, foffset);
			while (foffset < t_file_size && t_file[foffset] != ':')
				foffset++;
			char *t_name = NULL;
			if (foffset >= t_file_size
			    || !hc_decode_binhex(t_file + foffset + 1, t_file_size - foffset - 1, t_name,
			                         t_decoded_data, t_data_size, t_decoded_rsrc, t_rsrc_size))
			{
				delete[] t_file;
				return IO_ERROR;
			}
			delete[] name;
			name = t_name;
			t_data = t_decoded_data;
			t_rsrc = t_decoded_rsrc;
		}
		break;
	}

	IO_stat t_stat = readblocks(t_data, t_data_size);

	if (t_stat == IO_NORMAL)
	{
		if (t_rsrc != NULL && t_rsrc_size != 0)
			readresources(t_rsrc, t_rsrc_size);
#ifdef _MAC_DESKTOP
		else if (filetype == HC_RAW)
			t_stat = macreadresources();
#endif
	}

	delete[] t_decoded_data;
	delete[] t_decoded_rsrc;
	delete[] t_file;
	return t_stat;
}

// Parse the blocks of a data fork, up to the TAIL block.
IO_stat MCHcstak::readblocks(const uint1 *p_data, uint4 p_size)
{
	uint4 boffset = 0;
	uint4 type = 0;
	bool t_have_stack = false;
	while (type != HC_TAIL)
	{
		if (boffset >= p_size || p_size - boffset < 8)
		{
			// Some stacks end without a TAIL block.
			if (!t_have_stack)
				return IO_ERROR;
			hcstat_append("Warning: the stack ends without a TAIL block");
			break;
		}
		// The top byte of a block's size can hold flags.
		uint4 size = hc_get_uint4((const char *)&p_data[boffset]) & 0x00FFFFFF;
		type = hc_get_uint4((const char *)&p_data[boffset + 4]);
		if (type == HC_BUGS)
			size = 512;
		if (size < 8)
		{
			if (!t_have_stack)
				return IO_ERROR;
			hcstat_append("Error: bad block size %d at offset %d", (int)size, (int)boffset);
			break;
		}
		if (size > p_size - boffset)
		{
			if (!t_have_stack)
				return IO_ERROR;
			hcstat_append("Warning: the last block runs past the end of the stack");
			size = p_size - boffset;
		}

		char *t_buffer = new (nothrow) char[size + HC_BLOCK_PADDING];
		if (t_buffer == NULL)
			return IO_ERROR;
		memcpy(t_buffer, &p_data[boffset], size);
		memset(&t_buffer[size], 0, HC_BLOCK_PADDING);
		boffset += size;

		if (!t_have_stack && type != HC_STAK)
		{
			delete[] t_buffer;
			return IO_ERROR;
		}

		IO_stat t_stat = IO_NORMAL;
		switch (type)
		{
		case HC_STAK:
			{
				t_have_stack = true;
				// The file format: 1 to 8 is HyperCard 1, 9 and 10 HyperCard 2.
				uint4 t_format = hc_get_uint4(&t_buffer[16]);
				if (t_format >= 1 && t_format <= 8)
					version = 1;
				else if (t_format == 9 || t_format == 10)
					version = 2;
				else
				{
					// An unknown format: go by the version of HyperCard that
					// last changed the stack, as this importer always has.
					version = uint1(t_buffer[108]);
					if (version > 2)
						t_stat = IO_ERROR;
					if (version == 0)
						version = 1;
				}
				firstbkgd = hc_get_uint4(&t_buffer[0x28]);
				if (size > 0x1BC)
				{
					rect.width = hc_get_uint2(&t_buffer[0x1BA]);
					rect.height = hc_get_uint2(&t_buffer[0x1B8]);
				}
				if (version == 1 || rect.width == 0 || rect.height == 0)
				{
					rect.width = 512;
					rect.height = 342;
				}
				if (size > 1536)
					script = convert_script(&t_buffer[1536]);
			}
			break;
		case HC_LIST:
			{
				uint4 t_shift = version == 1 ? 4 : 0;
				pagesize = hc_get_uint2(&t_buffer[0x1C - t_shift]);
				uint4 t_count = hc_get_uint4(&t_buffer[0x10 - t_shift]);
				if (size >= 0x30 && t_count <= (size - 0x30) / 6)
				{
					delete[] listpageids;
					delete[] listpagecounts;
					nlistpages = t_count;
					listpageids = new (nothrow) uint4[t_count + 1];
					listpagecounts = new (nothrow) uint4[t_count + 1];
					for (uint4 i = 0 ; i < t_count ; i++)
					{
						listpageids[i] = hc_get_uint4(&t_buffer[0x30 + i * 6]);
						listpagecounts[i] = hc_get_uint2(&t_buffer[0x30 + i * 6 + 4]);
					}
				}
			}
			break;
		case HC_PAGE:
			MCU_realloc((char **)&pbuffers, npbuffers,
			            npbuffers + 1, sizeof(char *));
			MCU_realloc((char **)&pbuffersizes, npbuffers,
			            npbuffers + 1, sizeof(uint4));
			MCU_realloc((char **)&pbufferids, npbuffers,
			            npbuffers + 1, sizeof(uint4));
			pbuffersizes[npbuffers] = size;
			pbufferids[npbuffers] = hc_get_uint4(&t_buffer[8]);
			pbuffers[npbuffers++] = t_buffer;
			t_buffer = NULL;
			break;
		case HC_BKGD:
			{
				MCHcbkgd *newbkgd = new (nothrow) MCHcbkgd;
				newbkgd->appendto(hcbkgds);
				if (newbkgd->parse(t_buffer, size) != IO_NORMAL)
				{
					hcstat_append("Error: skipping a short BKGD block");
					newbkgd->remove(hcbkgds);
					delete newbkgd;
				}
			}
			break;
		case HC_CARD:
			{
				MCHccard *newcard = new (nothrow) MCHccard;
				newcard->appendto(hccards);
				if (newcard->parse(t_buffer, size) != IO_NORMAL)
				{
					hcstat_append("Error: skipping a short CARD block");
					newcard->remove(hccards);
					delete newcard;
				}
			}
			break;
		case HC_BMAP:
			{
				MCHcbmap *newbmap = new (nothrow) MCHcbmap;
				newbmap->appendto(hcbmaps);
				if (newbmap->parse(t_buffer, size) != IO_NORMAL)
				{
					hcstat_append("Error: skipping a short BMAP block");
					newbmap->remove(hcbmaps);
					delete newbmap;
				}
			}
			break;
		case HC_STBL:
			{
				uint4 t_count = hc_get_uint2(&t_buffer[18]);
				if (size < 24 || t_count > (size - 24) / 24)
					t_count = size < 24 ? 0 : (size - 24) / 24;
				if (t_count != 0)
				{
					delete[] atts;
					natts = t_count;
					atts = new (nothrow) Hcatts[natts];
					for (uint4 i = 0 ; i < natts ; i++)
					{
						const char *t_entry = &t_buffer[24 + i * 24];
						atts[i].id = hc_get_uint2(&t_entry[2]);
						atts[i].fid = hc_get_uint2(&t_entry[12]);
						atts[i].style = convert_style(hc_get_uint2(&t_entry[14]));
						atts[i].size = hc_get_uint2(&t_entry[16]);
					}
				}
			}
			break;
		case HC_FTBL:
			{
				uint4 t_count = hc_get_uint2(&t_buffer[18]);
				if (t_count != 0)
				{
					// The font names are kept in the table's block, which
					// lives as long as the importer does.
					MCU_realloc((char **)&fontbuffers, nfontbuffers,
					            nfontbuffers + 1, sizeof(char *));
					fontbuffers[nfontbuffers++] = t_buffer;
					delete[] fonts;
					fonts = new (nothrow) Hcfont[t_count];
					nfonts = 0;
					uint4 offset = 24;
					while (nfonts < t_count && offset + 2 < size)
					{
						fonts[nfonts].id = hc_get_uint2(&t_buffer[offset]);
						fonts[nfonts].name = convert_font(&t_buffer[offset + 2]);
						nfonts++;
						offset += (strlen(&t_buffer[offset + 2]) + 4) & ~1U;
					}
					t_buffer = NULL;
				}
			}
			break;
		case HC_FREE:
		case HC_MAST:
		case HC_PRNT:
		case HC_PRFT:
		case HC_PRST:
		case HC_TAIL:
			break;
		default:
			hcstat_append("Error: unknown section type -> %x", type);
			break;
		}
		delete[] t_buffer;
		if (t_stat != IO_NORMAL)
			return t_stat;
	}
	return IO_NORMAL;
}

MCStack *MCHcstak::build()
{
	MCStack *sptr = MCtemplatestack->clone();
	// clone() sends newStack, and a handler that refers to a card of the new
	// stack (the IDE's do) makes the template card on a stack that has none
	// (MCStack::getchildbyordinal and the others). Take any such card off
	// now, so that HyperCard's first card is the stack's first card; it is
	// deleted once the stack has its own cards.
	MCCard *t_made_cards = sptr->cards;
	sptr->cards = NULL;
	sptr->curcard = NULL;
	sptr->flags |= F_HC_STACK | F_HC_ADDRESSING | F_DYNAMIC_PATHS;
	const char *tname = strrchr(name, PATH_SEPARATOR);
	if (tname != NULL)
		tname += 1;
	else
		tname = name;
	sptr->setname_cstring(tname);
	delete[] name;
	if (script != NULL)
	{
		MCAutoStringRef t_script;
		if (hc_string(script, &t_script))
			sptr->setscript(*t_script);
		delete[] script;
		if (sptr->hlist != NULL)
		{
			delete sptr->hlist;
			sptr->hlist = NULL;
		}
	}
	name = script = NULL;
	sptr->rect = rect;
	// MW-2012-02-17: [[ LogFonts ]] Set the font attributes of the object.
	sptr -> setfontattrs(MCSTR(HC_DEFAULT_TEXT_FONT), HC_DEFAULT_TEXT_SIZE, FA_DEFAULT_STYLE);
	sptr->fontheight = heightfromsize(HC_DEFAULT_TEXT_SIZE);
	// The card order: the PAGE blocks in the order the LIST block gives them,
	// each with as many card ids as the LIST says it holds. Without a usable
	// LIST, the PAGE blocks in the order of the file, each up to a zero id.
	uint4 i;
	bool t_listed = nlistpages != 0 && pagesize >= 8;
	for (i = 0 ; t_listed && i < nlistpages ; i++)
	{
		uint4 b;
		for (b = 0 ; b < npbuffers ; b++)
			if (pbufferids[b] == listpageids[i])
				break;
		if (b == npbuffers)
			t_listed = false;
	}
	uint4 t_capacity = 0;
	if (pagesize >= 8)
		for (i = 0 ; i < npbuffers ; i++)
			t_capacity += pbuffersizes[i] / pagesize + 1;
	if (t_capacity != 0)
	{
		pages = new (nothrow) uint4[t_capacity];
		marks = new (nothrow) uint1[t_capacity];
	}
	uint4 t_page_count = t_listed ? nlistpages : npbuffers;
	for (uint4 p = 0 ; pages != NULL && marks != NULL && p < t_page_count ; p++)
	{
		uint4 b = p;
		uint4 t_count = UINT32_MAX;
		if (t_listed)
		{
			for (b = 0 ; pbufferids[b] != listpageids[p] ; b++)
				;
			t_count = listpagecounts[p];
		}
		const char *t_page = pbuffers[b];
		for (uint4 k = 0 ; k < t_count && npages < t_capacity ; k++)
		{
			// MW-2008-02-12: [[ Bug 5232 ]] Crash when importing certain HC stack - just added
			//   bounds checks.
			uint4 t_entry = 24 + k * pagesize;
			if (t_entry + 5 > pbuffersizes[b])
				break;
			uint4 t_id = hc_get_uint4(&t_page[t_entry]);
			if (t_id == 0)
			{
				if (t_listed)
					continue;
				break;
			}
			pages[npages] = t_id;
			marks[npages] = t_page[t_entry + 4] & 0x10;
			npages++;
		}
	}
	for (i = 0 ; i < npbuffers ; i++)
		delete[] pbuffers[i];
	if (pbuffers != NULL)
	{
		npbuffers = 0;
		delete[] pbuffers;
		pbuffers = NULL;
		delete[] pbuffersizes;
		pbuffersizes = NULL;
		delete[] pbufferids;
		pbufferids = NULL;
	}
	if (npages == 0)
		while (hccards != NULL)
		{
			MCHccard *cptr = hccards->remove
			                 (hccards);
			MCCard *newcard = cptr->build(this, sptr);
			newcard->setparent(sptr);
			newcard->appendto(sptr->cards);
			delete cptr;
		}
	else
	{
		for (i = 0 ; i < npages && hccards != NULL ; i++)
		{
			MCHccard *cptr = hccards;
			do
			{
				if (cptr->id == pages[i])
				{
					cptr->remove
					(hccards);
					MCCard *newcard = cptr->build(this, sptr);
					newcard->setmark(marks[i]);
					newcard->setparent(sptr);
					newcard->appendto(sptr->cards);
					delete cptr;
					break;
				}
				cptr = cptr->next();
			}
			while (cptr != hccards);
		}
		if (hccards != NULL)
			hcstat_append("Warning: cards that are in no page were left out");
	}
	// The cards newStack made: deleted when HyperCard's cards replace them,
	// kept (as before) on a stack that brought none, and kept in front of
	// HyperCard's (as before) when newStack put a control on one, since
	// deleting the card would leave its controls behind in the stack
	bool t_made_has_controls = false;
	if (t_made_cards != NULL)
	{
		MCCard *t_card = t_made_cards;
		do
		{
			if (t_card->getobjptrs() != NULL)
				t_made_has_controls = true;
			t_card = t_card->next();
		}
		while (t_card != t_made_cards);
	}
	if (sptr->cards == NULL)
		sptr->cards = t_made_cards;
	else if (t_made_has_controls)
	{
		while (sptr->cards != NULL)
		{
			MCCard *t_card = sptr->cards->remove(sptr->cards);
			t_card->appendto(t_made_cards);
		}
		sptr->cards = t_made_cards;
	}
	else
		while (t_made_cards != NULL)
		{
			MCCard *t_card = t_made_cards->remove(t_made_cards);
			MCrecent->deletecard(t_card);
			MCcstack->deletecard(t_card);
			sptr->uncacheobjectbyid(t_card);
			t_card->removereferences();
			t_card->scheduledelete(false);
		}
	sptr->curcard = sptr->cards;
	// The background order: HyperCard's own, the chain from the STAK
	// block's first background through each one's next, so "bg 1" names the
	// background it named in HyperCard. Backgrounds the chain misses (a
	// broken stack) follow in the order of the file.
	uint4 t_next = firstbkgd;
	while (hcbkgds != NULL)
	{
		MCHcbkgd *bgptr = hcbkgds;
		if (t_next != 0)
		{
			do
			{
				if (bgptr->id == t_next)
					break;
				bgptr = bgptr->next();
			}
			while (bgptr != hcbkgds);
			if (bgptr->id != t_next)
				bgptr = hcbkgds;
		}
		bgptr->remove(hcbkgds);
		t_next = bgptr->id == t_next ? bgptr->nextid : 0;
		MCControl *newobj = bgptr->build(this, sptr);
		newobj->setparent(sptr);
		newobj->appendto(sptr->controls);
		delete bgptr;
	}
	while (hcbmaps != NULL)
	{
		MCHcbmap *bmptr = hcbmaps->remove
		                  (hcbmaps);
		MCControl *newobj = bmptr->build();
		if (newobj != NULL)
		{
			newobj->setparent(sptr);
			newobj->appendto(sptr->controls);
		}
		delete bmptr;
	}
	if (icons != NULL)
	{
		MCGroup *gptr = (MCGroup *)MCtemplategroup->clone(False, OP_NONE, false);
		// MW-2011-08-09: [[ Groups ]] HC backgrounds are shared.
		gptr->flags = (gptr -> flags & ~F_GROUP_ONLY) | F_GROUP_SHARED;
		gptr->obj_id = ++maxid;
		gptr->setname_cstring("HC Icons");
		gptr->setparent(sptr);
		MCControl *cptr = (MCControl *)gptr;
		cptr->appendto(sptr->controls);
		while (icons != NULL)
		{
			MCHcbmap *bmptr = icons->remove
			                  (icons);
			MCControl *newobj = bmptr->build();
			if (newobj != NULL)
			{
				newobj->setparent(gptr);
				newobj->appendto(gptr->controls);
			}
			delete bmptr;
		}
	}
	if (cursors != NULL)
	{
		MCGroup *gptr = (MCGroup *)MCtemplategroup->clone(False, OP_NONE, false);
		gptr->obj_id = ++maxid;
		// MW-2011-08-09: [[ Groups ]] HC backgrounds are shared.
		gptr->flags = (gptr -> flags & ~F_GROUP_ONLY) | F_GROUP_SHARED;
		gptr->setname_cstring("HC cursors");
		gptr->setparent(sptr);
		MCControl *cptr = (MCControl *)gptr;
		cptr->appendto(sptr->controls);
		while (cursors != NULL)
		{
			MCHcbmap *bmptr = cursors->remove
			                  (cursors);
			MCControl *newobj = bmptr->build();
			if (newobj != NULL)
			{
				newobj->setparent(gptr);
				newobj->appendto(gptr->controls);
			}
			delete bmptr;
		}
	}
	while (snds != NULL)
	{
		MCHcsnd *sndptr = snds->remove
		                  (snds);
		MCAudioClip *aptr = sndptr->build();
		aptr->setparent(sptr);
		aptr->appendto(sptr->aclips);
		delete sndptr;
	}
	sptr->obj_id = maxid;
	return sptr;
}


IO_stat hc_import(MCStringRef name, IO_handle stream, MCStack *&sptr)
{
	maxid = 0;
	MCValueAssign(MChcstat, kMCEmptyString);

    char* t_cname;
    if(!MCStringConvertToCString(name, t_cname))
		return IO_ERROR;
	// The importer frees its names with delete[], so hand it one from new[].
	char *t_name = new (nothrow) char[strlen(t_cname) + 1];
	if (t_name == NULL)
	{
		MCMemoryDeleteArray(t_cname);
		return IO_ERROR;
	}
	strcpy(t_name, t_cname);
	MCMemoryDeleteArray(t_cname);
	
    MCHcstak *hcstak = new (nothrow) MCHcstak(t_name);
	hcstat_append("Loading stack %s...", t_name);
	uindex_t startlen = MCStringGetLength(MChcstat);
	IO_stat stat;
	if ((stat = hcstak->read(stream)) == IO_NORMAL)
		sptr = hcstak->build();
	
	delete hcstak;
	// Show the import log, if it says anything, only for a stack that was
	// read: on an error sptr was never set.
	if (stat == IO_NORMAL && !MClockerrors && MCStringGetLength(MChcstat) != startlen)
	{
		MCStack *tptr = MCdefaultstackptr->findstackname(MCN_hcstat);
		if (tptr != NULL)
		{
			sptr->open();
			tptr->openrect(MCdefaultstackptr->getrect(), WM_MODELESS,
			               NULL, WP_DEFAULT, OP_NONE);
		}
	}
	return stat;
}


