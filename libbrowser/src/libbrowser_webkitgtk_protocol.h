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

/* The wire between the Linux WebKitGTK browser (libbrowser_webkitgtk.cpp,
 * in the engine) and its helper process (libbrowser_webkitprocess_lnx.cpp).
 *
 * The engine is a GTK 2 program; WebKitGTK 4.x needs GTK 3, and GTK refuses
 * to have both in one process. So each browser is a WebKitWebView in a
 * GtkPlug of a helper process, which the engine's native layer embeds
 * (XEmbed, MCNativeLayerX11), and the two talk over a socket.
 *
 * A message is one line: its fields joined by tabs, ended by a newline,
 * with a backslash, tab, newline and carriage return in a field written as
 * \\, \t, \n and \r. Fields are UTF-8; nothing else is changed.
 *
 * Engine to helper: <verb> <id> <arguments...>. The helper answers every
 * one, in the order it finishes them: "ret" <id> <1 or 0> <value>.
 *
 *   go <url>                    load a URL
 *   html <text> <base url>      load HTML text (htmlText)
 *   back, forward, reload, stop
 *   eval <script>               run JavaScript; the value is String(result)
 *   handlers <names>            the javascriptHandlers, one per line
 *   useragent <text>            the user agent; empty for WebKitGTK's own
 *   get <name>                  url, useragent, source, canback, canforward,
 *                               secure: the value, "1"/"0" for a boolean
 *   set <name> <1 or 0>         newwindows, contextmenu, interaction
 *   quit
 *
 * Helper to engine, at any time:
 *
 *   ready <xid>                 the GtkPlug's window, once, at the start
 *   fail <reason>               the helper cannot run (and then ends)
 *   ev <kind> <url> [<error>]   begin, complete, failed (navigation and
 *                               document), unhandled
 *   js <json>                   a javascriptHandler was called:
 *                               [<name>, [<parameters>]]
 */

#ifndef __LIBBROWSER_WEBKITGTK_PROTOCOL_H__
#define __LIBBROWSER_WEBKITGTK_PROTOCOL_H__

#include <stddef.h>

#include <string>
#include <vector>

namespace MCWebKitGtkProtocol
{
	// The line for <p_fields>, newline included
	std::string Encode(const std::vector<std::string> &p_fields);

	// The fields of a line (without its newline); false for a line that
	// Encode could not have written
	bool Decode(const std::string &p_line, std::vector<std::string> &r_fields);

	// Whole lines from bytes as they arrive
	class LineReader
	{
	public:
		void Append(const char *p_bytes, size_t p_length);
		bool Next(std::string &r_line);

	private:
		std::string m_buffer;
	};
}

#endif
