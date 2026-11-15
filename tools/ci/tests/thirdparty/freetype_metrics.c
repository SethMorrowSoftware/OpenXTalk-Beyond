/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

/* Prints what the web and Android engines lay text out with, for one font
   file at the sizes a stack uses most: the face's and each size's metrics
   (Skia's line heights start from them), every glyph's advance as
   HarfBuzz's FreeType functions ask for it (FT_Get_Advance without
   hinting: the widths of measured text), and the kerning of the first
   glyphs. Built with the FreeType of thirdparty/libfreetype. */

#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_ADVANCES_H

static const int s_sizes[] = { 9, 10, 11, 12, 13, 14, 16, 18, 24, 36, 72 };

int main(int argc, char **argv)
{
	FT_Library library;
	FT_Face face;
	unsigned int s;
	if (argc < 2 || FT_Init_FreeType(&library) != 0)
		return 2;
	if (FT_New_Face(library, argv[1], 0, &face) != 0)
	{
		printf("not opened\n");
		return 0;
	}
	printf("face %s glyphs %ld upem %d ascender %d descender %d height %d\n",
	       face->family_name, face->num_glyphs, face->units_per_EM,
	       face->ascender, face->descender, face->height);
	for (s = 0; s < sizeof s_sizes / sizeof s_sizes[0]; s++)
	{
		FT_Size_Metrics *m;
		long g, a, b;
		FT_Set_Char_Size(face, s_sizes[s] * 64, 0, 0, 0);
		m = &face->size->metrics;
		printf("size %d ppem %d %d ascender %ld descender %ld height %ld max %ld\n",
		       s_sizes[s], m->x_ppem, m->y_ppem, m->ascender, m->descender,
		       m->height, m->max_advance);
		for (g = 0; g < face->num_glyphs; g++)
		{
			FT_Fixed advance = 0;
			FT_Get_Advance(face, (FT_UInt) g, FT_LOAD_DEFAULT | FT_LOAD_NO_HINTING, &advance);
			printf("%ld %ld\n", g, advance);
		}
		if (FT_HAS_KERNING(face))
			for (a = 1; a < 40 && a < face->num_glyphs; a++)
				for (b = 1; b < 40 && b < face->num_glyphs; b++)
				{
					FT_Vector k;
					FT_Get_Kerning(face, (FT_UInt) a, (FT_UInt) b, FT_KERNING_DEFAULT, &k);
					if (k.x != 0)
						printf("kern %ld %ld %ld\n", a, b, k.x);
				}
	}
	FT_Done_Face(face);
	FT_Done_FreeType(library);
	return 0;
}
