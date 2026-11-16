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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

#include "prefix.h"

#include "globdefs.h"
#include "parsedef.h"
#include "filedefs.h"

#include "literal.h"
#include "scriptpt.h"
#include "mcerror.h"

#include "globals.h"
#include "exec.h"

Parse_stat MCLiteral::parse(MCScriptPoint &sp, Boolean the)
{
	initpoint(sp);
	return PS_NORMAL;
}

void MCLiteral::eval_ctxt(MCExecContext& ctxt, MCExecValue& r_value)
{
	r_value . type = kMCExecValueTypeValueRef;
	r_value . valueref_value = MCValueRetain(value);
}

////////////////////////////////////////////////////////////////////////////////

MCArrayLiteral::MCArrayLiteral(bool p_keyed)
	: m_keyed(p_keyed),
	  m_elements(nil),
	  m_count(0)
{
}

MCArrayLiteral::~MCArrayLiteral(void)
{
	for (uindex_t i = 0; i < m_count; i++)
	{
		delete m_elements[i] . key;
		delete m_elements[i] . value;
	}
	MCMemoryDeleteArray(m_elements);
}

// (MCScriptPoint::parseexp has read the "[" or "{")
Parse_stat MCArrayLiteral::parse(MCScriptPoint &sp, Boolean the)
{
	initpoint(sp);

	// A colon ends a key's expression only while it is read: this literal
	// may be in a key of another
	bool t_key_colon = sp . getkeycolon();
	Parse_stat t_stat = parseelements(sp);
	sp . setkeycolon(t_key_colon);
	return t_stat;
}

// Whether a comma is next, where an element's key or value should begin:
// parseexp reads nothing before a comma as empty, as in a list of
// parameters, but an element is written with its key and its value
static bool MCArrayLiteralAtComma(MCScriptPoint &sp)
{
	Symbol_type t_type;
	Parse_stat t_stat = sp . next(t_type);
	sp . backup();
	return t_stat == PS_NORMAL && t_type == ST_SEP;
}

Parse_stat MCArrayLiteral::parseelements(MCScriptPoint &sp)
{
	Symbol_type t_end = m_keyed ? ST_RC : ST_RB;
	Symbol_type t_type;

	while (true)
	{
		// "]" or "}": the literal is empty, or a comma followed its last
		sp . setkeycolon(false);
		if (sp . next(t_type) != PS_NORMAL)
		{
			MCperror -> add(PE_ARRAYLITERAL_NOEND, sp);
			return PS_ERROR;
		}
		if (t_type == t_end)
			return PS_NORMAL;
		sp . backup();

		if (!MCMemoryResizeArray(m_count + 1, m_elements, m_count))
		{
			MCperror -> add(PE_OUTOFMEMORY, sp);
			return PS_ERROR;
		}
		Element &t_element = m_elements[m_count - 1];

		if (m_keyed)
		{
			// The key ends at the colon after it, which is a token of its
			// own, so that a value such as +1 is not read as part of it
			sp . setkeycolon(true);
			if (MCArrayLiteralAtComma(sp) ||
				sp . parseexp(False, False, &t_element . key) != PS_NORMAL)
			{
				MCperror -> add(PE_ARRAYLITERAL_BADKEY, sp);
				return PS_ERROR;
			}
			if (sp . next(t_type) != PS_NORMAL || t_type != ST_OP ||
				!sp . token_is_cstring(":"))
			{
				MCperror -> add(PE_ARRAYLITERAL_NOCOLON, sp);
				return PS_ERROR;
			}
			sp . setkeycolon(false);
		}

		if (MCArrayLiteralAtComma(sp) ||
			sp . parseexp(False, False, &t_element . value) != PS_NORMAL)
		{
			MCperror -> add(PE_ARRAYLITERAL_BADVALUE, sp);
			return PS_ERROR;
		}

		// A comma, and another element or the end, or the end
		if (sp . next(t_type) != PS_NORMAL)
		{
			MCperror -> add(PE_ARRAYLITERAL_NOEND, sp);
			return PS_ERROR;
		}
		if (t_type == t_end)
			return PS_NORMAL;
		if (t_type != ST_SEP)
		{
			MCperror -> add(PE_ARRAYLITERAL_NOEND, sp);
			return PS_ERROR;
		}
	}
}

void MCArrayLiteral::eval_ctxt(MCExecContext &ctxt, MCExecValue &r_value)
{
	MCAutoArrayRef t_array;
	if (!MCArrayCreateMutable(&t_array))
	{
		ctxt . Throw();
		return;
	}

	for (uindex_t i = 0; i < m_count; i++)
	{
		MCAutoValueRef t_value;
		if (m_keyed)
		{
			// The key first, as it is written first. A key is text: an array
			// with elements in it is none (as text it would be empty, and
			// its elements lost), and an empty one is empty, as anywhere
			MCAutoValueRef t_key_value;
			MCNewAutoNameRef t_key;
			if (!ctxt . EvalExprAsValueRef(m_elements[i] . key, EE_ARRAYLITERAL_BADKEY, &t_key_value))
				return;
			if ((MCValueIsArray(*t_key_value) && !MCArrayIsEmpty(static_cast<MCArrayRef>(*t_key_value))) ||
				!ctxt . ConvertToName(*t_key_value, &t_key))
			{
				ctxt . LegacyThrow(EE_ARRAYLITERAL_BADKEY);
				return;
			}
			if (!ctxt . EvalExprAsValueRef(m_elements[i] . value, EE_ARRAYLITERAL_BADVALUE, &t_value))
				return;
			if (!MCArrayStoreValue(*t_array, ctxt . GetCaseSensitive(), *t_key, *t_value))
			{
				ctxt . Throw();
				return;
			}
		}
		else
		{
			if (!ctxt . EvalExprAsValueRef(m_elements[i] . value, EE_ARRAYLITERAL_BADVALUE, &t_value))
				return;
			if (!MCArrayStoreValueAtIndex(*t_array, i + 1, *t_value))
			{
				ctxt . Throw();
				return;
			}
		}
	}

	MCArrayRef t_result;
	if (!MCArrayCopy(*t_array, t_result))
	{
		ctxt . Throw();
		return;
	}
	MCExecValueTraits<MCArrayRef>::set(r_value, t_result);
}
