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

/* Runs each line of stdin as SQL on one connection set up as revDB's
   driver sets it up (thirdparty/libsqlite/src/sqlitedataset.cpp: 15
   significant digits), and prints the type and text of every value, the
   text a script gets. test_thirdparty_libraries.py compares it with the
   answers of SQLite 3.51.3. Built with the SQLite of thirdparty/libsqlite. */

#include <stdio.h>
#include <string.h>
#include "sqlite3.h"

int main(void)
{
	sqlite3 *db;
	char line[8192];
	if (sqlite3_open(":memory:", &db) != SQLITE_OK)
		return 1;
#ifdef SQLITE_DBCONFIG_FP_DIGITS
	sqlite3_db_config(db, SQLITE_DBCONFIG_FP_DIGITS, 15, (int *) 0);
#endif
	while (fgets(line, sizeof line, stdin))
	{
		const char *tail = line;
		line[strcspn(line, "\n")] = 0;
		printf("> %s\n", line);
		while (tail != NULL && *tail != 0)
		{
			sqlite3_stmt *st = NULL;
			int rc, i;
			if (sqlite3_prepare_v2(db, tail, -1, &st, &tail) != SQLITE_OK)
			{
				printf("ERR %s\n", sqlite3_errmsg(db));
				break;
			}
			if (st == NULL)
				break;
			while ((rc = sqlite3_step(st)) == SQLITE_ROW)
				for (i = 0; i < sqlite3_column_count(st); i++)
				{
					const unsigned char *z = sqlite3_column_text(st, i);
					printf("  %d %s\n", sqlite3_column_type(st, i), z ? (const char *) z : "NULL");
				}
			if (rc != SQLITE_DONE)
				printf("ERR %s\n", sqlite3_errmsg(db));
			sqlite3_finalize(st);
		}
	}
	sqlite3_close(db);
	return 0;
}
