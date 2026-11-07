Script "TestSQLiteValues"

/*
Copyright (C) 2026 OXT-Beyond contributors.

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

-- The text a script gets back from SQLite for numbers, as SQLite 3.51
-- writes it. revDB reads every value as text (sqlite3_column_text), so
-- SQLite's own number-to-text conversion decides what a script sees.
-- SQLite 3.53.0 changed it from 15 significant digits to 17: under it
-- "SELECT 0.1 + 0.2" gives 0.30000000000000004 and "4.35 * 100" gives
-- 434.99999999999994, where 3.51 gives 0.3 and 435.0. These tests hold
-- the 3.51 answers, so that an update of thirdparty/libsqlite that would
-- change them fails here first (OXT-Beyond moved from 3.51.1 to 3.51.3,
-- whose answers are the same, in 0.2.7-rc.6.18). The expected text was
-- produced by SQLite 3.51.1, the version 0.2.7-rc.6.17 shipped.

local sDatabaseID, sDatabaseFile

on TestSetup
   TestSkipIfNot "database", "sqlite"
   TestLoadExternal "revdb"
   put the tempname into sDatabaseFile
   put revOpenDatabase("sqlite", sDatabaseFile,,,,) into sDatabaseID
   if sDatabaseID is not an integer then
      throw "the database did not open:" && sDatabaseID
   end if
   revExecuteSQL sDatabaseID, "CREATE TABLE oxt_values (id INTEGER, r REAL, t TEXT, n NUMERIC)"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_values VALUES (1, 0.1, '0.1', '1.10')"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_values VALUES (2, 1.0/3, 'x', 3.0)"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_values VALUES (3, 100.0, '1e3', 2.5)"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_values VALUES (4, 9007199254740993, 'abc', '9007199254740993')"
end TestSetup

on TestTeardown
   revCloseDatabase sDatabaseID
   delete file sDatabaseFile
end TestTeardown

private function __Query pSQL
   return revDataFromQuery(tab, return, sDatabaseID, pSQL)
end __Query

private command __AssertQuery pDescription, pSQL, pExpected
   local tActual
   put __Query(pSQL) into tActual
   TestDiagnostic pSQL && "->" && tActual
   TestAssert pDescription, tActual is pExpected
end __AssertQuery

on TestRealLiterals
   __AssertQuery "real literals keep 15 significant digits", \
         "SELECT 0.1, 0.1 + 0.2, 1.0/3, 2.0/3, 123456789.123456789", \
         "0.1" & tab & "0.3" & tab & "0.333333333333333" & tab & \
         "0.666666666666667" & tab & "123456789.123457"
end TestRealLiterals

on TestRealArithmetic
   __AssertQuery "arithmetic on reals is rounded to 15 digits", \
         "SELECT 4.35 * 100, 1.1 * 1.1, 100 * 1.1, 0.07 * 100, 3.3 / 1.1, 1 - 0.9", \
         "435.0" & tab & "1.21" & tab & "110.0" & tab & "7.0" & tab & "3.0" & tab & "0.1"
end TestRealArithmetic

on TestLargeAndSmallReals
   __AssertQuery "large and small reals use the exponent form", \
         "SELECT 1e15, 1e16, 1e100, 1.5e-7, 12345678901234567890.0", \
         "1.0e+15" & tab & "1.0e+16" & tab & "1.0e+100" & tab & "1.5e-07" & tab & \
         "1.23456789012346e+19"
end TestLargeAndSmallReals

on TestStoredValues
   __AssertQuery "stored values come back as they did", \
         "SELECT id, r, t, n FROM oxt_values ORDER BY id", \
         "1" & tab & "0.1" & tab & "0.1" & tab & "1.1" & return & \
         "2" & tab & "0.333333333333333" & tab & "x" & tab & "3" & return & \
         "3" & tab & "100.0" & tab & "1e3" & tab & "2.5" & return & \
         "4" & tab & "9.00719925474099e+15" & tab & "abc" & tab & "9007199254740993"
end TestStoredValues

on TestAggregates
   __AssertQuery "sums and averages of reals", \
         "SELECT sum(r), avg(r) FROM oxt_values WHERE id < 4", \
         "100.433333333333" & tab & "33.4777777777778"
   __AssertQuery "group_concat of reals", \
         "SELECT group_concat(r, ',') FROM oxt_values WHERE id < 4", \
         "0.1,0.333333333333333,100.0"
end TestAggregates

on TestCastAndJSON
   __AssertQuery "CAST of a real to text", \
         "SELECT CAST(1.0/3 AS TEXT), 'a' || 1.5", \
         "0.333333333333333" & tab & "a1.5"
   __AssertQuery "reals in JSON", \
         "SELECT json_object('a', 0.1, 'b', 1.0/3)", \
         "{" & quote & "a" & quote & ":0.1," & quote & "b" & quote & ":0.333333333333333}"
end TestCastAndJSON

on TestCursorValues
   -- A cursor (revQueryDatabase) reads values through another path of
   -- the driver (sqlitedataset), which must agree with revDataFromQuery.
   local tCursor, tValue
   put revQueryDatabase(sDatabaseID, "SELECT r FROM oxt_values WHERE id = 2") into tCursor
   TestAssert "the cursor opens", tCursor is an integer
   put revDatabaseColumnNamed(tCursor, "r") into tValue
   revCloseCursor tCursor
   TestAssert "a cursor reads a real as revDataFromQuery does", tValue is "0.333333333333333"
end TestCursorValues
