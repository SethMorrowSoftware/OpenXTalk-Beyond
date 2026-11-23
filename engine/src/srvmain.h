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

#ifndef __MC_SERVER_MAIN__
#define __MC_SERVER_MAIN__

#ifndef __MC_OSSPEC__
#include "osspec.h"
#endif

class MCServerScript;

extern MCStringRef MCserverinitialscript;
extern MCServerScript *MCserverscript;
extern MCSErrorMode MCservererrormode;
extern MCSOutputTextEncoding MCserveroutputtextencoding;
extern MCSOutputLineEndings MCserveroutputlineendings;

extern MCStringRef MCsessionsavepath;
extern MCStringRef MCsessionname;
extern MCStringRef MCsessionid;
extern uint32_t MCsessionlifetime;
// OXT-Beyond: the sessionCookieSecure and the sessionCookieSameSite
extern bool MCsessioncookiesecure;
extern intenum_t MCsessioncookiesamesite;

// OXT-Beyond: the values of the sessionCookieSameSite (the SameSite attribute
// of the session cookie); None leaves the attribute out, as before.
enum MCServerCookieSameSite
{
	kMCServerCookieSameSiteNone,
	kMCServerCookieSameSiteLax,
	kMCServerCookieSameSiteStrict,
	kMCServerCookieSameSiteCrossSite,
};

extern char **MCservercgiheaders;
extern uint32_t MCservercgiheadercount;

typedef struct mcservercookie_t
{
	char *name;
	char *value;
	char *path;
	char *domain;
	uint32_t expires;
	bool secure;
	bool http_only;
	// OXT-Beyond: a MCServerCookieSameSite (zero: no SameSite attribute)
	intenum_t same_site;
} MCServerCookie;

extern MCServerCookie *MCservercgicookies;
extern uint32_t MCservercgicookiecount;

extern MCStringRef MCservercgidocumentroot;

#endif
