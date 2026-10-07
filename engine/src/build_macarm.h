/* Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation. */

#ifndef __BUILD_MACARM_H__
#define __BUILD_MACARM_H__

// MCStatement, MCExpression, MCScriptPoint, MCExecContext etc. are
// already available via prefix.h -> globdefs.h and the other standard
// engine headers included before this file.

class MCInternalBuildMacARM : public MCStatement
{
public:
    MCInternalBuildMacARM(void);
    virtual ~MCInternalBuildMacARM(void);

    virtual Parse_stat parse(MCScriptPoint& sp);
    virtual void exec_ctxt(MCExecContext &ctxt);

private:
    MCExpression *m_folder_name;
};

#endif
