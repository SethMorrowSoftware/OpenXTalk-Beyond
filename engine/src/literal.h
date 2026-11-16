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

//
// MCLiteral class declarations
//
#ifndef	LITERAL_H
#define	LITERAL_H

#include "express.h"

class MCLiteral : public MCExpression
{
	MCValueRef value;
public:
	MCLiteral(MCValueRef v)
	{
		/* UNCHECKED */ value = MCValueRetain(v);
	}
	~MCLiteral(void)
	{
		MCValueRelease(value);
	}

    virtual Parse_stat parse(MCScriptPoint &, Boolean the);
    virtual void eval_ctxt(MCExecContext &ctxt, MCExecValue &r_value);
};

// OXT-Beyond: a literal array, as in LiveCode 10: a sequence,
// "[<value>, <value>, ...]", whose keys are 1, 2, 3 and on, or an array
// of keys and values, "{<key>: <value>, ...}". Each key and value is any
// expression, worked out each time the literal is; a comma may follow the
// last, and "[]" and "{}" are an empty array. A key the same as an earlier
// one, as the caseSensitive says, gives that element its value, as "put"
// into the element would. "[" and "{" begin no expression otherwise, so
// the parser reads one only where what holds it did not compile without
// it (MCNewSyntax): every script that compiled before compiles as it did.
// It reads none in text worked out only if it compiles, and left as text
// otherwise, a merge template's or a parameter of send given as text
// (MCScriptPoint::m_literal_arrays), so that such text is left as it was
class MCArrayLiteral : public MCExpression
{
	// An element as written: its key (nil in a sequence) and its value
	struct Element
	{
		MCExpression *key;
		MCExpression *value;
	};

	// Whether it is "{...}", of keys and values
	bool m_keyed;
	// Its elements, in the order they are written
	Element *m_elements;
	uindex_t m_count;

	Parse_stat parseelements(MCScriptPoint &sp);

public:
	MCArrayLiteral(bool p_keyed);
	~MCArrayLiteral(void);

	virtual Parse_stat parse(MCScriptPoint &, Boolean the);
	virtual void eval_ctxt(MCExecContext &ctxt, MCExecValue &r_value);
};

#endif
