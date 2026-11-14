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

/* Prints the events expat reports for a file, read in small pieces through
   XML_GetBuffer and XML_ParseBuffer as Skia's parsers read (SkXMLParser,
   SkFontMgr_android_parser), with namespaces on unless a second argument
   is given. Built with the expat of thirdparty/libexpat. */

#include <stdio.h>
#include <string.h>
#include "expat.h"

static char s_text[65536];
static int s_text_length = 0;

static void flush_text(void)
{
	if (s_text_length > 0)
		printf("T %.*s|\n", s_text_length, s_text);
	s_text_length = 0;
}

static void XMLCALL on_start(void *u, const XML_Char *name, const XML_Char **atts)
{
	(void) u;
	flush_text();
	printf("S %s", name);
	for (; *atts != NULL; atts += 2)
		printf(" [%s=%s]", atts[0], atts[1]);
	printf("\n");
}

static void XMLCALL on_end(void *u, const XML_Char *name)
{
	(void) u;
	flush_text();
	printf("E %s\n", name);
}

static void XMLCALL on_text(void *u, const XML_Char *s, int len)
{
	int i;
	(void) u;
	for (i = 0; i < len && s_text_length < (int) sizeof s_text; i++)
		s_text[s_text_length++] = s[i];
}

int main(int argc, char **argv)
{
	FILE *f;
	XML_Parser p;
	int ok = 1;
	size_t n;
	if (argc < 2 || (f = fopen(argv[1], "rb")) == NULL)
		return 2;
	p = argc > 2 ? XML_ParserCreate(NULL) : XML_ParserCreateNS(NULL, '|');
	XML_SetElementHandler(p, on_start, on_end);
	XML_SetCharacterDataHandler(p, on_text);
	do
	{
		void *buffer = XML_GetBuffer(p, 512);
		n = fread(buffer, 1, 512, f);
		ok = XML_ParseBuffer(p, (int) n, n == 0) != XML_STATUS_ERROR;
	} while (ok && n > 0);
	flush_text();
	if (!ok)
		printf("ERROR %s\n", XML_ErrorString(XML_GetErrorCode(p)));
	XML_ParserFree(p);
	fclose(f);
	return 0;
}
