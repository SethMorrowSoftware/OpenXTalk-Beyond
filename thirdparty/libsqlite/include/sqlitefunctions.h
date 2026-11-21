/* OXT-Beyond (Seth Morrow, 2026): the SQL functions that revDB's SQLite
   driver adds to every connection it opens, besides SQLite's own
   (src/sqlitefunctions.c says which, and why they are added this way). */

#ifndef SQLITEFUNCTIONS_H
#define SQLITEFUNCTIONS_H

#include "sqlite3.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Adds SQLite's math functions, regexp() and regexpi() to the connection.
   Returns SQLITE_OK, or the error of the first that could not be added
   (only when memory runs out). */
int oxt_sqlite_add_functions(sqlite3 *db);

#ifdef __cplusplus
}
#endif

#endif
