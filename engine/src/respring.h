/* Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation. */

#ifndef __RESPRING_H__
#define __RESPRING_H__

class MCInternalRespring : public MCStatement
{
public:
    MCInternalRespring(void);
    virtual ~MCInternalRespring(void);

    virtual Parse_stat parse(MCScriptPoint& sp);
    virtual void exec_ctxt(MCExecContext &ctxt);
};

// Check whether a respring has been requested (flag set by exec_ctxt)
extern Boolean MCRespringIsPending(void);

// Perform the actual respring (teardown + reload). Call only after the
// handler chain has fully unwound. Returns True on success.
extern Boolean MCRespringDoRespring(void);

#endif
