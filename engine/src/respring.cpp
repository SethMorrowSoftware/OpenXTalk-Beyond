/* Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation. */

////////////////////////////////////////////////////////////////////////////////
//
//  Private Source File:
//    respring.cpp
//
//  Description:
//    Implementation of _internal respring command.
//    Closes all stacks, clears per-session state, and reloads the
//    home stack from scratch — an in-process restart without quitting.
//
//    Usage from script:
//      _internal respring
//
//    The command works in two phases:
//      1. exec_ctxt sets a global flag and triggers MCquit/MCexitall
//         to safely unwind the handler chain (same mechanism as quit).
//      2. MCRespringDoRespring() is called from the main loop after
//         the handler chain has fully unwound. It performs the actual
//         teardown and reload.
//
//    This is a cross-platform function that works on macOS, Windows,
//    and Linux. It only touches the stack layer — all engine
//    infrastructure (screen, fonts, graphics, templates, extensions,
//    printer, theme) is left intact.
//
////////////////////////////////////////////////////////////////////////////////

#include "prefix.h"

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "filedefs.h"
#include "mcio.h"

#include "exec.h"
#include "handler.h"
#include "scriptpt.h"
#include "newobj.h"
#include "cmds.h"
#include "mcerror.h"
#include "globals.h"
#include "express.h"
#include "internal.h"
#include "debug.h"

#include "dispatch.h"
#include "stack.h"
#include "stacklst.h"
#include "cardlst.h"
#include "sellst.h"
#include "undolst.h"
#include "image.h"
#include "osspec.h"

#include "respring.h"
#include "license.h"
#if defined(_WINDOWS)
#include "w32dc.h"
#endif

extern uint4 MCstartupstack_length;
extern uint1 MCstartupstack[];
extern bool MCFiltersDecompress(MCDataRef p_source, MCDataRef& r_result);

////////////////////////////////////////////////////////////////////////////////

// Global flag: set by exec_ctxt, checked by the main loop.
static Boolean s_respring_pending = False;

Boolean MCRespringIsPending(void)
{
    return s_respring_pending;
}

// Function pointers in dskmain.cpp — register ourselves at startup
extern Boolean (*MCRespringIsPendingPtr)(void);
extern Boolean (*MCRespringDoRespringPtr)(void);

// Auto-register via static initializer
static struct MCRespringRegistrar {
    MCRespringRegistrar() {
        MCRespringIsPendingPtr = MCRespringIsPending;
        MCRespringDoRespringPtr = MCRespringDoRespring;
    }
} s_respring_registrar;

////////////////////////////////////////////////////////////////////////////////

extern void send_startup_message(bool p_do_relaunch = true);

////////////////////////////////////////////////////////////////////////////////

MCInternalRespring::MCInternalRespring(void)
{
}

MCInternalRespring::~MCInternalRespring(void)
{
}

Parse_stat MCInternalRespring::parse(MCScriptPoint& sp)
{
    return PS_NORMAL;
}

void MCInternalRespring::exec_ctxt(MCExecContext &ctxt)
{
    // Just set the flag. The main loop checks it before each iteration.
    // Do NOT set MCquit or MCexitall — the unwind path crashes on Windows.
    s_respring_pending = True;
}

////////////////////////////////////////////////////////////////////////////////
//
//  MCRespringDoRespring — called from the main loop after the handler
//  chain has fully unwound (MCquit caused X_main_loop to exit).
//
//  Phase 1: Teardown — close all stacks and clear per-session state.
//  Phase 2: Reload — re-run startup() to load the home stack afresh.
//
//  Returns true on success, false on failure.
//
////////////////////////////////////////////////////////////////////////////////

Boolean MCRespringDoRespring(void)
{
    // Clear the pending flag
    s_respring_pending = False;

    //
    // Phase 1: Teardown
    //

    // Lock messages so no scripts fire during teardown
    MClockmessages = True;

    // Close all open stack windows (MCstacks is the open-window list)
    if (MCstacks != nil)
        MCstacks->closeall();

    // Closing the home stack sets MCquit — force it back to False
    MCquit = False;
    MCexitall = False;

    // Drain the pending-destroy list
    if (MCtodestroy != nil && !MCtodestroy->isempty())
        MCtodestroy->destroy();

    // Force MCquit off again in case destroy triggered it
    MCquit = False;

    // Clear selection and undo state
    if (MCselected != nil)
        MCselected->clear(False);
    if (MCundos != nil)
        MCundos->freestate();

    // Clear card history lists
    if (MCrecent != nil)
    {
        delete MCrecent;
        MCrecent = new (nothrow) MCCardlist;
    }
    if (MCcstack != nil)
    {
        delete MCcstack;
        MCcstack = new (nothrow) MCCardlist;
    }

    // Clear front/backscript lists (these are object reference chains)
    while (MCfrontscripts != nil)
    {
        MCObjectList *t_next = MCfrontscripts->next();
        delete MCfrontscripts;
        MCfrontscripts = (t_next == MCfrontscripts) ? nil : t_next;
    }
    MCfrontscripts = nil;

    while (MCbackscripts != nil)
    {
        MCObjectList *t_next = MCbackscripts->next();
        delete MCbackscripts;
        MCbackscripts = (t_next == MCbackscripts) ? nil : t_next;
    }
    MCbackscripts = nil;

    // Null out all global stack handle pointers
    MCtopstackptr = nil;
    MCdefaultstackptr = nil;
    MCstaticdefaultstackptr = nil;
    MCmousestackptr = nil;
    MCclickstackptr = nil;
    MCfocusedstackptr = nil;

    // Clear the message stack reference on the audio clip pointer
    if (MCacptr.IsValid())
        MCacptr->setmessagestack(NULL);

    // Destroy all loaded stacks from the dispatcher's internal list.
    // This deletes all mainstack and substack objects but keeps the
    // dispatcher itself alive.
    MCdispatcher->clearstacks();

    //
    // Phase 2: Reload
    //

    // Reset quit/exit flags so the engine doesn't shut down
    MCquit = False;
    MCexitall = False;
    MCtraceabort = False;
    MCtracereturn = False;

    // Unlock messages before startup (scripts need to run)
    MClockmessages = False;

    // Clear the result
    MCresult->clear();

    // Re-load the environment following the same sequence as
    // MCDispatch::startup() in mode_development.cpp, but without
    // entering a nested X_main_loop().
    //
    // Normal boot order:
    //   1. Decompress & read the embedded startup (environment) stack
    //   2. Send "startup" to it — its script sets "the result" to
    //      the home stack path
    //   3. Destroy the startup stack
    //   4. Load the home stack by name from "the result"
    //   5. send_startup_message(false) on the home stack
    //   6. Open the home stack

    // Re-init image cache
    MCCachedImageRep::init();

    MCStack *sptr = nil;

    // Step 1: Decompress and read the embedded startup stack
    {
        MCAutoDataRef t_decompressed;
        {
            MCAutoDataRef t_compressed;
            /* UNCHECKED */ MCDataCreateWithBytes((const char_t*)MCstartupstack,
                                                  MCstartupstack_length,
                                                  &t_compressed);
            /* UNCHECKED */ MCFiltersDecompress(*t_compressed, &t_decompressed);
        }

        IO_handle stream = MCS_fakeopen(MCDataGetBytePtr(*t_decompressed),
                                        MCDataGetLength(*t_decompressed));

        IO_stat stat = MCdispatcher->readfile(NULL, NULL, stream, sptr);
        MCS_close(stream);

        /* FRAGILE */ memset((void *)MCDataGetBytePtr(*t_decompressed), 0,
                             MCDataGetLength(*t_decompressed));

        if (stat != IO_NORMAL || sptr == nil)
            return False;
    }

#if defined(_WINDOWS)
    SetForegroundWindow(((MCScreenDC *)MCscreen) -> getinvisiblewindow());
#endif

    // Step 2: Send startup message to the environment stack
    MCenvironmentactive = True;
    sptr -> setfilename(MCcmd);
    MCdefaultstackptr = MCstaticdefaultstackptr = MCdispatcher->getstacks();

    MCdefaultstackptr -> setextendedstate(true, ECS_DURING_STARTUP);
    MCdefaultstackptr -> message(MCM_start_up, nil, False, True);
    MCdefaultstackptr -> setextendedstate(false, ECS_DURING_STARTUP);

    if (MCquit)
    {
        MCquit = False;
        return False;
    }

    // Step 3: Check the result — the startup stack's script should have
    // set it to the home stack path
    {
        MCExecContext ctxt(nil, nil, nil);
        MCValueRef t_valueref = nil;
        MCresult -> eval(ctxt, t_valueref);

        if (!MCValueIsEmpty(t_valueref))
        {
            // Step 3a: Destroy the startup/environment stack
            MCdispatcher->destroystack(sptr, True);
            MCtopstackptr = nil;
            MCquit = False;
            MCenvironmentactive = False;

            // Step 4: Load the home stack by name

            MCNewAutoNameRef t_name;
            if (ctxt.ConvertToName(t_valueref, &t_name))
            {
                sptr = MCdispatcher->findstackname(*t_name);
                if (sptr == NULL)
                    MCdispatcher->loadfile(MCNameGetString(*t_name), sptr);
            }

            MCValueRelease(t_valueref);

            if (sptr == nil)
                return False;
        }
        else
        {
            // No result — just open the startup stack directly
            MCValueRelease(t_valueref);
        }
    }

    // Step 5 & 6: Set up and open the home stack
    if (!MCquit)
    {
        MCallowinterrupts = true;
        sptr -> setparent(MCdispatcher);
        MCdefaultstackptr = MCstaticdefaultstackptr = MCdispatcher->getstacks();

        send_startup_message(false);

        if (!MCquit)
            sptr -> open();
    }

    return True;
}
