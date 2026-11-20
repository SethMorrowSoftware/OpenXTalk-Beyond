/* Copyright (C) 2015 LiveCode Ltd.
 
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

#include <include/cef_app.h>

#include <stdlib.h>

#include "core.h"
#include "libbrowser_cef.h"

////////////////////////////////////////////////////////////////////////////////

extern bool MCCefCreateApp(CefRefPtr<CefApp> &r_app);

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
	CefMainArgs t_args(argc, argv);
	
	CefRefPtr<CefApp> t_app;
	if (!MCCefCreateApp(t_app))
		return -1;
	
	// OXT-Beyond: [[ CEF 156 ]] This process does not return from main.
	// Chromium's zygote (this program, forked for each renderer and utility
	// process) gives every child it forks a new stack canary
	// (--change-stack-guard-on-fork=enable), and the child comes back out of
	// CefExecuteProcess into this frame, whose canary is the zygote's: main's
	// return then failed the compiler's check, and each child that ended
	// was killed with "*** stack smashing detected ***: terminated" (SIGABRT),
	// twice for every page the Dictionary or a browser widget opened, seen
	// with 0.2.8-dp.2 on Ubuntu 24.04. Chromium's own main is built without
	// the check for this (NO_STACK_PROTECTOR); exit() makes no check, and
	// ends the process as main's return did, with the same status.
	exit(CefExecuteProcess(t_args, t_app, NULL));
}

////////////////////////////////////////////////////////////////////////////////

bool MCCefPlatformEnableHiDPI(void)
{
	return true;
}

////////////////////////////////////////////////////////////////////////////////

