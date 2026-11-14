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

// The wire format of libbrowser_webkitgtk_protocol.h. Plain C++ only: the
// helper process links this and nothing else of libbrowser.

#include "libbrowser_webkitgtk_protocol.h"

namespace MCWebKitGtkProtocol
{

std::string Encode(const std::vector<std::string> &p_fields)
{
	std::string t_line;
	for (size_t i = 0; i < p_fields.size(); i++)
	{
		if (i > 0)
			t_line += '\t';
		const std::string &t_field = p_fields[i];
		for (size_t j = 0; j < t_field.size(); j++)
		{
			switch (t_field[j])
			{
				case '\\': t_line += "\\\\"; break;
				case '\t': t_line += "\\t"; break;
				case '\n': t_line += "\\n"; break;
				case '\r': t_line += "\\r"; break;
				default: t_line += t_field[j]; break;
			}
		}
	}
	t_line += '\n';
	return t_line;
}

bool Decode(const std::string &p_line, std::vector<std::string> &r_fields)
{
	std::vector<std::string> t_fields(1);
	for (size_t i = 0; i < p_line.size(); i++)
	{
		char t_char = p_line[i];
		if (t_char == '\t')
			t_fields.push_back(std::string());
		else if (t_char == '\n' || t_char == '\r')
			return false;
		else if (t_char != '\\')
			t_fields.back() += t_char;
		else
		{
			if (++i == p_line.size())
				return false;
			switch (p_line[i])
			{
				case '\\': t_fields.back() += '\\'; break;
				case 't': t_fields.back() += '\t'; break;
				case 'n': t_fields.back() += '\n'; break;
				case 'r': t_fields.back() += '\r'; break;
				default: return false;
			}
		}
	}
	r_fields.swap(t_fields);
	return true;
}

void LineReader::Append(const char *p_bytes, size_t p_length)
{
	m_buffer.append(p_bytes, p_length);
}

bool LineReader::Next(std::string &r_line)
{
	size_t t_end = m_buffer.find('\n');
	if (t_end == std::string::npos)
		return false;
	r_line.assign(m_buffer, 0, t_end);
	m_buffer.erase(0, t_end + 1);
	return true;
}

}
