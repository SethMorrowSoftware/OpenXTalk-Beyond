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

/* A JSON array as a libbrowser list: the parameters of a javascriptHandler
 * call, as the WebKitGTK browser's helper hands them on (the page makes the
 * JSON; see libbrowser_webkitprocess_lnx.cpp).
 *
 * The values are those CEF gives for the same call (MCCefV8ArrayToList,
 * libbrowser_cefprocess.cpp): true and false are booleans; a number that is
 * whole and fits in 32 bits is an integer, any other a double; text is
 * UTF-8; an array is a list and an object a dictionary. CEF gives any other
 * value as String(value): the page turns undefined, functions and numbers
 * that are not finite into that text before it makes the JSON, and null,
 * which JSON has, becomes the text "null" here.
 *
 * Strict RFC 8259 JSON: anything else is refused, so a helper that sends
 * something wrong is noticed rather than half read.
 */

#include <core.h>

#include "libbrowser_internal.h"

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include <string>

////////////////////////////////////////////////////////////////////////////////

namespace
{

class MCBrowserJSONReader
{
public:
	MCBrowserJSONReader(const char *p_text) : m_text(p_text), m_depth(0) {}

	bool ReadTopList(MCBrowserListRef &r_list)
	{
		SkipSpace();
		if (*m_text != '[')
			return false;
		if (!ReadList(r_list))
			return false;
		SkipSpace();
		if (*m_text != '\0')
		{
			MCBrowserListRelease(r_list);
			r_list = nil;
			return false;
		}
		return true;
	}

private:
	// Deeper than this is not a page's parameters, and would run the stack
	// out on the way down
	enum { kMaxDepth = 256 };

	const char *m_text;
	uint32_t m_depth;

	enum ValueKind { kNone, kBoolean, kInteger, kDouble, kString, kList, kDictionary };

	struct Value
	{
		ValueKind kind;
		bool boolean;
		int32_t integer;
		double number;
		std::string string;
		MCBrowserListRef list;
		MCBrowserDictionaryRef dictionary;

		Value() : kind(kNone), boolean(false), integer(0), number(0), list(nil), dictionary(nil) {}
		~Value()
		{
			if (list != nil)
				MCBrowserListRelease(list);
			if (dictionary != nil)
				MCBrowserDictionaryRelease(dictionary);
		}
	};

	void SkipSpace()
	{
		while (*m_text == ' ' || *m_text == '\t' || *m_text == '\n' || *m_text == '\r')
			m_text++;
	}

	bool ReadLiteral(const char *p_literal)
	{
		size_t t_length = strlen(p_literal);
		if (strncmp(m_text, p_literal, t_length) != 0)
			return false;
		m_text += t_length;
		return true;
	}

	static bool HexValue(char p_char, uint32_t &r_value)
	{
		if (p_char >= '0' && p_char <= '9')
			r_value = p_char - '0';
		else if (p_char >= 'a' && p_char <= 'f')
			r_value = p_char - 'a' + 10;
		else if (p_char >= 'A' && p_char <= 'F')
			r_value = p_char - 'A' + 10;
		else
			return false;
		return true;
	}

	bool ReadHex4(uint32_t &r_unit)
	{
		uint32_t t_unit = 0;
		for (int i = 0; i < 4; i++)
		{
			uint32_t t_digit;
			if (!HexValue(m_text[i], t_digit))
				return false;
			t_unit = t_unit * 16 + t_digit;
		}
		m_text += 4;
		r_unit = t_unit;
		return true;
	}

	static void AppendUTF8(std::string &x_string, uint32_t p_codepoint)
	{
		if (p_codepoint < 0x80)
			x_string += char(p_codepoint);
		else if (p_codepoint < 0x800)
		{
			x_string += char(0xC0 | (p_codepoint >> 6));
			x_string += char(0x80 | (p_codepoint & 0x3F));
		}
		else if (p_codepoint < 0x10000)
		{
			x_string += char(0xE0 | (p_codepoint >> 12));
			x_string += char(0x80 | ((p_codepoint >> 6) & 0x3F));
			x_string += char(0x80 | (p_codepoint & 0x3F));
		}
		else
		{
			x_string += char(0xF0 | (p_codepoint >> 18));
			x_string += char(0x80 | ((p_codepoint >> 12) & 0x3F));
			x_string += char(0x80 | ((p_codepoint >> 6) & 0x3F));
			x_string += char(0x80 | (p_codepoint & 0x3F));
		}
	}

	bool ReadString(std::string &r_string)
	{
		if (*m_text != '"')
			return false;
		m_text++;

		std::string t_string;
		for (;;)
		{
			unsigned char t_char = (unsigned char)*m_text;
			if (t_char == '\0' || t_char < 0x20)
				return false;
			m_text++;
			if (t_char == '"')
				break;
			if (t_char != '\\')
			{
				t_string += char(t_char);
				continue;
			}

			char t_escape = *m_text++;
			switch (t_escape)
			{
				case '"': t_string += '"'; break;
				case '\\': t_string += '\\'; break;
				case '/': t_string += '/'; break;
				case 'b': t_string += '\b'; break;
				case 'f': t_string += '\f'; break;
				case 'n': t_string += '\n'; break;
				case 'r': t_string += '\r'; break;
				case 't': t_string += '\t'; break;
				case 'u':
				{
					uint32_t t_unit;
					if (!ReadHex4(t_unit))
						return false;
					if (t_unit >= 0xDC00 && t_unit <= 0xDFFF)
						return false;
					if (t_unit >= 0xD800 && t_unit <= 0xDBFF)
					{
						// A high surrogate needs its low one
						uint32_t t_low;
						if (m_text[0] != '\\' || m_text[1] != 'u')
							return false;
						m_text += 2;
						if (!ReadHex4(t_low) || t_low < 0xDC00 || t_low > 0xDFFF)
							return false;
						t_unit = 0x10000 + ((t_unit - 0xD800) << 10) + (t_low - 0xDC00);
					}
					AppendUTF8(t_string, t_unit);
					break;
				}
				default:
					return false;
			}
		}

		r_string.swap(t_string);
		return true;
	}

	bool ReadNumber(Value &r_value)
	{
		const char *t_start = m_text;
		bool t_whole = true;

		if (*m_text == '-')
			m_text++;
		if (*m_text == '0')
			m_text++;
		else if (*m_text >= '1' && *m_text <= '9')
			while (*m_text >= '0' && *m_text <= '9')
				m_text++;
		else
			return false;

		if (*m_text == '.')
		{
			t_whole = false;
			m_text++;
			if (!(*m_text >= '0' && *m_text <= '9'))
				return false;
			while (*m_text >= '0' && *m_text <= '9')
				m_text++;
		}
		if (*m_text == 'e' || *m_text == 'E')
		{
			t_whole = false;
			m_text++;
			if (*m_text == '+' || *m_text == '-')
				m_text++;
			if (!(*m_text >= '0' && *m_text <= '9'))
				return false;
			while (*m_text >= '0' && *m_text <= '9')
				m_text++;
		}

		std::string t_number(t_start, m_text - t_start);

		// JSON.stringify writes a whole number without a point or an
		// exponent up to 1e21, so these are the numbers V8 calls Int
		if (t_whole)
		{
			errno = 0;
			long long t_integer = strtoll(t_number.c_str(), nil, 10);
			if (errno == 0 && t_integer >= INT32_MIN && t_integer <= INT32_MAX)
			{
				r_value.kind = kInteger;
				r_value.integer = int32_t(t_integer);
				return true;
			}
		}

		// strtod reads a point as the C locale's, which is the engine's
		r_value.kind = kDouble;
		r_value.number = strtod(t_number.c_str(), nil);
		return true;
	}

	bool ReadValue(Value &r_value)
	{
		SkipSpace();
		switch (*m_text)
		{
			case '[':
				r_value.kind = kList;
				return ReadList(r_value.list);
			case '{':
				r_value.kind = kDictionary;
				return ReadDictionary(r_value.dictionary);
			case '"':
				r_value.kind = kString;
				return ReadString(r_value.string);
			case 't':
				r_value.kind = kBoolean;
				r_value.boolean = true;
				return ReadLiteral("true");
			case 'f':
				r_value.kind = kBoolean;
				r_value.boolean = false;
				return ReadLiteral("false");
			case 'n':
				// String(null), as CEF gives it
				r_value.kind = kString;
				r_value.string = "null";
				return ReadLiteral("null");
			default:
				return ReadNumber(r_value);
		}
	}

	bool Append(MCBrowserListRef p_list, const Value &p_value)
	{
		switch (p_value.kind)
		{
			case kBoolean: return MCBrowserListAppendBoolean(p_list, p_value.boolean);
			case kInteger: return MCBrowserListAppendInteger(p_list, p_value.integer);
			case kDouble: return MCBrowserListAppendDouble(p_list, p_value.number);
			case kString: return MCBrowserListAppendUTF8String(p_list, p_value.string.c_str());
			case kList: return MCBrowserListAppendList(p_list, p_value.list);
			case kDictionary: return MCBrowserListAppendDictionary(p_list, p_value.dictionary);
			default: return false;
		}
	}

	bool Set(MCBrowserDictionaryRef p_dict, const char *p_key, const Value &p_value)
	{
		switch (p_value.kind)
		{
			case kBoolean: return MCBrowserDictionarySetBoolean(p_dict, p_key, p_value.boolean);
			case kInteger: return MCBrowserDictionarySetInteger(p_dict, p_key, p_value.integer);
			case kDouble: return MCBrowserDictionarySetDouble(p_dict, p_key, p_value.number);
			case kString: return MCBrowserDictionarySetUTF8String(p_dict, p_key, p_value.string.c_str());
			case kList: return MCBrowserDictionarySetList(p_dict, p_key, p_value.list);
			case kDictionary: return MCBrowserDictionarySetDictionary(p_dict, p_key, p_value.dictionary);
			default: return false;
		}
	}

	bool ReadList(MCBrowserListRef &r_list)
	{
		if (*m_text != '[' || ++m_depth > kMaxDepth)
			return false;
		m_text++;

		MCBrowserListRef t_list = nil;
		if (!MCBrowserListCreate(t_list))
			return false;

		bool t_success = true;
		SkipSpace();
		if (*m_text == ']')
			m_text++;
		else
		{
			for (;;)
			{
				Value t_value;
				t_success = ReadValue(t_value) && Append(t_list, t_value);
				if (!t_success)
					break;
				SkipSpace();
				if (*m_text == ',')
				{
					m_text++;
					continue;
				}
				t_success = *m_text == ']';
				if (t_success)
					m_text++;
				break;
			}
		}

		m_depth--;
		if (!t_success)
		{
			MCBrowserListRelease(t_list);
			return false;
		}
		r_list = t_list;
		return true;
	}

	bool ReadDictionary(MCBrowserDictionaryRef &r_dict)
	{
		if (*m_text != '{' || ++m_depth > kMaxDepth)
			return false;
		m_text++;

		MCBrowserDictionaryRef t_dict = nil;
		if (!MCBrowserDictionaryCreate(t_dict))
			return false;

		bool t_success = true;
		SkipSpace();
		if (*m_text == '}')
			m_text++;
		else
		{
			for (;;)
			{
				std::string t_key;
				SkipSpace();
				t_success = ReadString(t_key);
				if (t_success)
				{
					SkipSpace();
					t_success = *m_text == ':';
					if (t_success)
						m_text++;
				}
				Value t_value;
				if (t_success)
					t_success = ReadValue(t_value) && Set(t_dict, t_key.c_str(), t_value);
				if (!t_success)
					break;
				SkipSpace();
				if (*m_text == ',')
				{
					m_text++;
					continue;
				}
				t_success = *m_text == '}';
				if (t_success)
					m_text++;
				break;
			}
		}

		m_depth--;
		if (!t_success)
		{
			MCBrowserDictionaryRelease(t_dict);
			return false;
		}
		r_dict = t_dict;
		return true;
	}
};

}

////////////////////////////////////////////////////////////////////////////////

bool MCBrowserListCreateFromJSON(const char *p_json, MCBrowserListRef &r_list)
{
	if (p_json == nil)
		return false;

	MCBrowserJSONReader t_reader(p_json);
	return t_reader.ReadTopList(r_list);
}
