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

/* A loadable SQLite extension of the kind a stack loads on a connection
   opened with revOpenDatabase's "extensions" option, with
   SELECT load_extension(...): functions with the names of some that
   revDB's driver adds to every connection (sqlitefunctions.c), which
   answer otherwise, as those of the extensions stacks use do:

   - log(X), the natural logarithm, as extension-functions.c's is (SQLite's
     log(X) is base 10);
   - ceil(X), an integer, as extension-functions.c's is (SQLite's gives a
     real for a real);
   - regexp(P, S), for the REGEXP operator: 1 when P is in S as it is, with
     no regular expression at all.

   Like a careful extension, it fails to load when SQLite refuses one of
   its functions, so a refusal shows. test_thirdparty_libraries.py loads it
   into sqlite_text, where these must answer, not the driver's. */

#include <math.h>
#include <string.h>
#include "sqlite3ext.h"
SQLITE_EXTENSION_INIT1

static void ext_log(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
	(void) argc;
	sqlite3_result_double(ctx, log(sqlite3_value_double(argv[0])));
}

static void ext_ceil(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
	(void) argc;
	sqlite3_result_int64(ctx, (sqlite3_int64) ceil(sqlite3_value_double(argv[0])));
}

static void ext_regexp(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
	const char *pattern = (const char *) sqlite3_value_text(argv[0]);
	const char *text = (const char *) sqlite3_value_text(argv[1]);
	(void) argc;
	if (pattern != NULL && text != NULL)
		sqlite3_result_int(ctx, strstr(text, pattern) != NULL);
}

#ifdef _WIN32
__declspec(dllexport)
#endif
int sqlite3_sqliteextension_init(sqlite3 *db, char **error,
                                 const sqlite3_api_routines *api)
{
	int rc;
	SQLITE_EXTENSION_INIT2(api);
	rc = sqlite3_create_function(db, "log", 1, SQLITE_UTF8, NULL, ext_log, NULL, NULL);
	if (rc == SQLITE_OK)
		rc = sqlite3_create_function(db, "ceil", 1, SQLITE_UTF8, NULL, ext_ceil, NULL, NULL);
	if (rc == SQLITE_OK)
		rc = sqlite3_create_function(db, "regexp", 2, SQLITE_UTF8, NULL, ext_regexp, NULL, NULL);
	if (rc != SQLITE_OK && error != NULL)
		*error = sqlite3_mprintf("%s", sqlite3_errmsg(db));
	return rc;
}
