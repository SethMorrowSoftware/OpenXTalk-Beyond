Script "TestSQLiteFunctions"

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

-- SQLite's math functions (sqrt(), pi(), log() and the rest) and REGEXP,
-- which revDB's SQLite driver adds to every connection it opens from
-- OXT-Beyond 0.2.8-dp.3 (thirdparty/libsqlite/src/sqlitefunctions.c).
-- LiveCode's driver had none of them: each of these queries failed with
-- "no such function". The functions are SQLite's own code, and
-- tools/ci/tests/test_thirdparty_libraries.py holds their answers to
-- those of a SQLite built with its math functions, value for value; the
-- answers here are the text a script gets, with 15 significant digits
-- (sqlite_values). A stack that loads an extension of its own with the
-- same names keeps that extension's (also held there, as no stack here
-- can load one).

local sDatabaseID, sDatabaseFile

on TestSetup
   TestSkipIfNot "database", "sqlite"
   TestLoadExternal "revdb"
   put the tempname into sDatabaseFile
   put revOpenDatabase("sqlite", sDatabaseFile,,,,) into sDatabaseID
   if sDatabaseID is not an integer then
      throw "the database did not open:" && sDatabaseID
   end if
   revExecuteSQL sDatabaseID, "CREATE TABLE oxt_names (n TEXT)"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_names VALUES ('Ada'), ('bob'), ('Carol'), ('Dave'), ('ann'), (NULL), ('Bea')"
   revExecuteSQL sDatabaseID, "CREATE TABLE oxt_numbers (v INTEGER)"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_numbers VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)"
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

-- An error comes back as the text "revdberr," and SQLite's message
private command __AssertError pDescription, pSQL, pMessage
   local tActual
   put __Query(pSQL) into tActual
   TestDiagnostic pSQL && "->" && tActual
   TestAssert pDescription, tActual begins with "revdberr," and tActual contains pMessage
end __AssertError

on TestMathFunctions
   __AssertQuery "square roots, powers, exp and pi", \
         "SELECT sqrt(16), pi(), exp(0), pow(2, 10), power(2, 0.5)", \
         "4.0" & tab & "3.14159265358979" & tab & "1.0" & tab & "1024.0" & tab & "1.4142135623731"
end TestMathFunctions

on TestLogarithms
   -- SQLite's log() is base 10, as log10() is; ln() is the natural one
   __AssertQuery "logarithms", \
         "SELECT log(100), log10(1000), log2(8), ln(1), log(2, 8), round(ln(exp(2)), 6)", \
         "2.0" & tab & "3.0" & tab & "3.0" & tab & "0.0" & tab & "3.0" & tab & "2.0"
end TestLogarithms

on TestRounding
   -- an integer stays an integer, a real gives a real
   __AssertQuery "ceil, floor and trunc", \
         "SELECT ceil(1.2), ceiling(-1.2), floor(1.8), floor(-1.5), trunc(-2.7), ceil(5), floor(-3)", \
         "2.0" & tab & "-1.0" & tab & "1.0" & tab & "-2.0" & tab & "-2.0" & tab & "5" & tab & "-3"
end TestRounding

on TestTrigonometry
   __AssertQuery "trigonometry, angles and mod", \
         "SELECT sin(0), cos(0), degrees(pi()), radians(180), atan2(1, 1) * 4, mod(7, 3), mod(-7, 3)", \
         "0.0" & tab & "1.0" & tab & "180.0" & tab & "3.14159265358979" & tab & \
         "3.14159265358979" & tab & "1.0" & tab & "-1.0"
end TestTrigonometry

on TestMathNulls
   -- NULL, a value outside a function's domain and text that is not a
   -- number give NULL, which a script gets as empty; text that is a
   -- number is that number
   __AssertQuery "NULL for what has no answer", \
         "SELECT sqrt(NULL), sqrt(-1), ln(0), log(-1), sqrt('x'), sqrt('16')", \
         tab & tab & tab & tab & tab & "4.0"
end TestMathNulls

on TestMathInQueries
   __AssertQuery "math in a WHERE clause", \
         "SELECT v FROM oxt_numbers WHERE sqrt(v) = floor(sqrt(v)) ORDER BY v", \
         "1" & return & "4" & return & "9"
   __AssertQuery "math in aggregates", \
         "SELECT round(sum(sqrt(v)), 6), max(log(v)), group_concat(mod(v, 3), ',') FROM oxt_numbers", \
         "22.468278" & tab & "1.0" & tab & "1.0,2.0,0.0,1.0,2.0,0.0,1.0,2.0,0.0,1.0"
   __AssertQuery "math in ORDER BY", \
         "SELECT v FROM oxt_numbers ORDER BY mod(v, 4), v DESC LIMIT 4", \
         "8" & return & "4" & return & "9" & return & "5"
end TestMathInQueries

on TestMathArguments
   __AssertError "sqrt() takes one argument", "SELECT sqrt(1, 2)", \
         "wrong number of arguments to function sqrt()"
   __AssertError "pi() takes none", "SELECT pi(1)", \
         "wrong number of arguments to function pi()"
end TestMathArguments

on TestRegexpOperator
   -- X REGEXP Y is regexp(Y, X): Y anywhere in X, unless anchored
   __AssertQuery "the REGEXP operator", \
         "SELECT 'abc' REGEXP 'b', 'abc' REGEXP '^b', 'abc' NOT REGEXP 'z', regexp('b', 'abc')", \
         "1" & tab & "0" & tab & "1" & tab & "1"
end TestRegexpOperator

on TestRegexpSyntax
   __AssertQuery "classes, counts, word boundaries and optional characters", \
         "SELECT '2026-11-21' REGEXP '^\d{4}-\d{2}-\d{2}$', 'colour' REGEXP '^colou?r$'," && \
         "'hello world' REGEXP '\bworld\b', 'helloworld' REGEXP '\bworld'", \
         "1" & tab & "1" & tab & "1" & tab & "0"
end TestRegexpSyntax

on TestRegexpInWhereClauses
   __AssertQuery "REGEXP in a WHERE clause", \
         "SELECT n FROM oxt_names WHERE n REGEXP '^[A-C]' ORDER BY n", \
         "Ada" & return & "Bea" & return & "Carol"
   __AssertQuery "NOT REGEXP in a WHERE clause", \
         "SELECT n FROM oxt_names WHERE n NOT REGEXP 'a' ORDER BY n", \
         "bob"
end TestRegexpInWhereClauses

on TestRegexpCase
   -- REGEXP tells upper case from lower; regexpi() does not
   __AssertQuery "REGEXP and regexpi()", \
         "SELECT 'ABC' REGEXP 'b', regexpi('b', 'ABC'), (SELECT count(*) FROM oxt_names WHERE regexpi('^a', n))", \
         "0" & tab & "1" & tab & "2"
end TestRegexpCase

on TestRegexpNulls
   __AssertQuery "NULL REGEXP gives NULL", \
         "SELECT NULL REGEXP 'a', 'a' REGEXP NULL", \
         tab
end TestRegexpNulls

on TestRegexpErrors
   __AssertError "a pattern that is not one", "SELECT 'abc' REGEXP '('", "unmatched '('"
   __AssertError "regexp() takes two arguments", "SELECT regexp('a')", \
         "wrong number of arguments to function regexp()"
end TestRegexpErrors

on TestEveryConnection
   -- a connection opened with the options has them too
   local tFile, tID, tActual
   put the tempname into tFile
   put revOpenDatabase("sqlite", tFile, "binary,extensions") into tID
   TestAssert "the connection opens", tID is an integer
   put revDataFromQuery(tab, return, tID, "SELECT sqrt(16), 'abc' REGEXP '^a.c$'") into tActual
   revCloseDatabase tID
   delete file tFile
   TestDiagnostic tActual
   TestAssert "the functions are on a connection opened with options", tActual is "4.0" & tab & "1"
end TestEveryConnection

on TestCursors
   -- a cursor (revQueryDatabase) runs the query as revDataFromQuery does
   local tCursor, tValue
   put revQueryDatabase(sDatabaseID, "SELECT sqrt(v) AS r FROM oxt_names, oxt_numbers WHERE n REGEXP '^Car' AND v = 9") into tCursor
   TestAssert "the cursor opens", tCursor is an integer
   if tCursor is not an integer then
      exit TestCursors
   end if
   put revDatabaseColumnNamed(tCursor, "r") into tValue
   revCloseCursor tCursor
   TestAssert "a cursor reads the answer", tValue is "3.0"
end TestCursors
