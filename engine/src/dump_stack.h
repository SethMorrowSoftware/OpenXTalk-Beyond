/* Copyright (C) 2003-2015 LiveCode Ltd.
 * Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#ifndef __DUMP_STACK_H__
#define __DUMP_STACK_H__

#include "internal.h"

class MCInternalDumpStack : public MCStatement
{
public:
	MCInternalDumpStack(void);
	~MCInternalDumpStack(void);

	Parse_stat parse(MCScriptPoint& sp);
	void exec_ctxt(MCExecContext &ctxt);

private:
	MCExpression *m_path_expr;
};

#endif
