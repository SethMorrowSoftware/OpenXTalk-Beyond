script "CoreDatabaseServerTest"

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

-- The MySQL and PostgreSQL drivers of revdb against real servers: what
-- they do today, so that a later change of the client libraries (the
-- plan's MOD-D3) has a baseline to be compared with. These tests pin the
-- drivers' current behaviour, including where it is surprising (MySQL's
-- revCommitDatabase and revRollBackDatabase do nothing).
--
-- A server is used only when the environment names it, so everywhere
-- else (the build jobs' engine tests, a developer's machine) every test
-- here is skipped. The Linux build's "Databases" job starts the servers
-- and sets, for MYSQL and for POSTGRESQL:
--
--    OXT_TEST_<DB>_HOST       host:port
--    OXT_TEST_<DB>_DATABASE   a database the user may create tables in
--    OXT_TEST_<DB>_USER, OXT_TEST_<DB>_PASSWORD
--    OXT_TEST_<DB>_TLS        "true" when the server accepts TLS
--
-- Every table made here begins with "oxt_" and is dropped first, so a
-- run can follow a failed one.

local lDatabaseID

private function __Env pDriver, pName
   do "return $OXT_TEST_" & toUpper(pDriver) & "_" & pName
end __Env

-- Skips the test (as TestSkipIfNot does, by throwing) unless the
-- environment names a server for pDriver
private command __SkipUnlessServer pDriver
   TestSkipIfNot "database", pDriver
   if __Env(pDriver, "HOST") is empty then
      throw "SKIP no" && pDriver && "server: OXT_TEST_" & toUpper(pDriver) & "_HOST is not set"
   end if
   TestLoadExternal "revdb"
end __SkipUnlessServer

-- The connection, with TLS when pTLS is true, else without; the id, or
-- the driver's error text
private function __Open pDriver, pTLS, pPassword
   local tHost, tDatabase, tUser
   put __Env(pDriver, "HOST") into tHost
   put __Env(pDriver, "DATABASE") into tDatabase
   put __Env(pDriver, "USER") into tUser
   if pPassword is empty then
      put __Env(pDriver, "PASSWORD") into pPassword
   end if
   if pDriver is "mysql" then
      return revOpenDatabase("mysql", tHost, tDatabase, tUser, pPassword, pTLS is true)
   end if
   if pTLS is true then
      return revOpenDatabase("postgresql", tHost, tDatabase, tUser, pPassword, "sslmode=require")
   end if
   return revOpenDatabase("postgresql", tHost, tDatabase, tUser, pPassword, "sslmode=disable")
end __Open

private function __Field pRow, pColumn
   set the itemDelimiter to tab
   return item pColumn of line 1 of pRow
end __Field

private command __Connect pDriver
   put __Open(pDriver, false) into lDatabaseID
   -- (a test's description is one line; an error text can have several)
   local tShown
   put lDatabaseID into tShown
   replace return with " " in tShown
   TestAssert pDriver & ": connects (" & tShown & ")", lDatabaseID is an integer
end __Connect

private command __Disconnect
   if lDatabaseID is an integer then
      revCloseDatabase lDatabaseID
   end if
   put empty into lDatabaseID
end __Disconnect

private command __Exec pSQL
   revExecuteSQL lDatabaseID, pSQL
   if item 1 of the result is "revdberr" then
      TestDiagnostic pSQL & ": " & the result
   end if
end __Exec

private function __Count pTable
   return revDataFromQuery(,, lDatabaseID, "SELECT COUNT(*) FROM" && pTable)
end __Count

-- Connecting, the database type, the table list, closing

private command __TestConnect pDriver, pType
   __SkipUnlessServer pDriver
   __Connect pDriver
   TestAssert pDriver & ": revDatabaseType", revDatabaseType(lDatabaseID) is pType
   TestAssert pDriver & ": the connection is listed", lDatabaseID is among the items of revOpenDatabases()
   __Exec "DROP TABLE IF EXISTS oxt_names"
   __Exec "CREATE TABLE oxt_names (id integer)"
   TestAssert pDriver & ": revDatabaseTableNames lists a new table", \
         "oxt_names" is among the lines of revDatabaseTableNames(lDatabaseID)
   __Exec "DROP TABLE oxt_names"
   local tID
   put lDatabaseID into tID
   __Disconnect
   TestAssert pDriver & ": closed", tID is not among the items of revOpenDatabases()
end __TestConnect

on TestMySQLConnect
   __TestConnect "mysql", "MySQL"
end TestMySQLConnect

on TestPostgreSQLConnect
   __TestConnect "postgresql", "PostgreSQL"
end TestPostgreSQLConnect

-- A wrong password is an error text, not an id, and not a crash

private command __TestWrongPassword pDriver
   __SkipUnlessServer pDriver
   local tResult
   put __Open(pDriver, false, "not-the-password") into tResult
   TestDiagnostic pDriver & " with a wrong password: " & tResult
   TestAssert pDriver & ": a wrong password gives no connection", tResult is not an integer
   TestAssert pDriver & ": a wrong password gives an error text", tResult is not empty
   if tResult is an integer then
      revCloseDatabase tResult
   end if
end __TestWrongPassword

on TestMySQLWrongPassword
   __TestWrongPassword "mysql"
end TestMySQLWrongPassword

on TestPostgreSQLWrongPassword
   __TestWrongPassword "postgresql"
end TestPostgreSQLWrongPassword

-- TLS, when the server offers it: the session is encrypted

-- pCheckSQL answers one row whose column pColumn is empty or "f"
-- without TLS
private command __TestTLS pDriver, pCheckSQL, pColumn, pBrokenReason
   __SkipUnlessServer pDriver
   if __Env(pDriver, "TLS") is not "true" then
      throw "SKIP the" && pDriver && "server does not offer TLS (OXT_TEST_" & toUpper(pDriver) & "_TLS)"
   end if
   put __Open(pDriver, true) into lDatabaseID
   if pBrokenReason is empty then
      TestAssert pDriver & ": connects with TLS (" & lDatabaseID & ")", lDatabaseID is an integer
   else
      TestAssertBroken pDriver & ": connects with TLS (" & lDatabaseID & ")", lDatabaseID is an integer, pBrokenReason
   end if
   if lDatabaseID is an integer then
      local tAnswer
      put revDataFromQuery(tab, return, lDatabaseID, pCheckSQL) into tAnswer
      TestDiagnostic pDriver & " TLS: " & tAnswer
      TestAssert pDriver & ": the session is encrypted", \
            item 1 of tAnswer is not "revdberr" and __Field(tAnswer, pColumn) is not among the items of ",f"
   end if
   __Disconnect
end __TestTLS

on TestMySQLTLS
   -- The client library (thirdparty/libmysql, Connector/C 6.0) asked for
   -- TLS 1.0 alone (TLSv1_client_method in viosslfactories.c), which
   -- OpenSSL 3 at its default security level, MySQL 8.0.28 and later and
   -- current MariaDB refuse: "SSL connection error" (found 2026-10-31).
   -- It asks for any version both ends share now (TLS_method; seth's
   -- decision the same day), and the session must say which.
   -- Ssl_cipher is empty in a session without TLS.
   __TestTLS "mysql", "SHOW SESSION STATUS LIKE 'Ssl_cipher'", 2
   -- (__TestTLS skips the test without a TLS server, and disconnects)
   put __Open("mysql", true) into lDatabaseID
   if lDatabaseID is an integer then
      local tVersion
      put revDataFromQuery(tab, return, lDatabaseID, "SHOW SESSION STATUS LIKE 'Ssl_version'") into tVersion
      TestDiagnostic "mysql TLS version: " & tVersion
      TestAssert "mysql: the session uses TLS 1.2 or later (" & tVersion & ")", \
            __Field(tVersion, 2) is among the items of "TLSv1.2,TLSv1.3"
   end if
   __Disconnect
end TestMySQLTLS

on TestPostgreSQLTLS
   __TestTLS "postgresql", "SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()", 1
end TestPostgreSQLTLS

-- Text, NULLs and placeholders

private command __TestValues pDriver
   __SkipUnlessServer pDriver
   __Connect pDriver
   __Exec "DROP TABLE IF EXISTS oxt_values"
   __Exec "CREATE TABLE oxt_values (id integer, txt varchar(200))"

   -- A value with quotes and a backslash, through a placeholder
   local tValues
   put 1 into tValues[1]
   put "it's" && quote & "quoted" & quote && "\ and; DROP TABLE x" into tValues[2]
   revExecuteSQL lDatabaseID, "INSERT INTO oxt_values (id, txt) VALUES (:1, :2)", "tValues"
   TestAssert pDriver & ": insert through placeholders (" & the result & ")", the result is 1
   __Exec "INSERT INTO oxt_values (id, txt) VALUES (2, NULL)"
   __Exec "INSERT INTO oxt_values (id, txt) VALUES (3, '')"

   TestAssert pDriver & ": the quoted value comes back unchanged", \
         revDataFromQuery(,, lDatabaseID, "SELECT txt FROM oxt_values WHERE id = 1") is tValues[2]

   -- revDataFromQuery gives a NULL as empty, the same as ''
   TestAssert pDriver & ": revDataFromQuery gives NULL and '' alike", \
         revDataFromQuery(tab, return, lDatabaseID, "SELECT id, txt FROM oxt_values WHERE id > 1 ORDER BY id") \
         is "2" & tab & return & "3" & tab

   -- revDatabaseColumnIsNull tells them apart
   local tCursor
   put revQueryDatabase(lDatabaseID, "SELECT id, txt FROM oxt_values WHERE id > 1 ORDER BY id") into tCursor
   TestAssert pDriver & ": a cursor (" & tCursor & ")", tCursor is an integer
   if tCursor is an integer then
      TestAssert pDriver & ": the NULL is NULL", revDatabaseColumnIsNull(tCursor, 2) is true
      revMoveToNextRecord tCursor
      TestAssert pDriver & ": the '' is not NULL", revDatabaseColumnIsNull(tCursor, 2) is false
      TestAssert pDriver & ": revNumberOfRecords", revNumberOfRecords(tCursor) is 2
      TestAssert pDriver & ": revDatabaseColumnNames", revDatabaseColumnNames(tCursor) is "id,txt"
      revCloseCursor tCursor
   end if
   __Exec "DROP TABLE oxt_values"
   __Disconnect
end __TestValues

on TestMySQLValues
   __TestValues "mysql"
end TestMySQLValues

on TestPostgreSQLValues
   __TestValues "postgresql"
end TestPostgreSQLValues

-- Binary data through a *b placeholder, every byte value and 1 MB of
-- random bytes

private command __TestBinary pDriver, pBlobType
   __SkipUnlessServer pDriver
   -- randomBytes
   TestSkipIfNot "external", "revsecurity"
   __Connect pDriver
   __Exec "DROP TABLE IF EXISTS oxt_binary"
   __Exec "CREATE TABLE oxt_binary (id integer, data" && pBlobType & ")"

   local tBytes, tValues, tData, tCursor
   repeat with i = 0 to 255
      put numToByte(i) after tBytes
   end repeat
   put tBytes & randomBytes(1048576) into tValues["*b1"]
   revExecuteSQL lDatabaseID, "INSERT INTO oxt_binary (id, data) VALUES (1, :1)", "tValues"
   TestAssert pDriver & ": insert binary data (" & the result & ")", the result is 1

   put revQueryDatabase(lDatabaseID, "SELECT data FROM oxt_binary WHERE id = 1") into tCursor
   TestAssert pDriver & ": a cursor on binary data (" & tCursor & ")", tCursor is an integer
   if tCursor is an integer then
      get revDatabaseColumnNamed(tCursor, "data", "tData")
      TestDiagnostic pDriver & " binary: " & the number of bytes of tData & " bytes back of " & \
            the number of bytes of tValues["*b1"]
      TestAssert pDriver & ": binary data comes back unchanged", tData is tValues["*b1"]
      revCloseCursor tCursor
   end if
   __Exec "DROP TABLE oxt_binary"
   __Disconnect
end __TestBinary

on TestMySQLBinary
   __TestBinary "mysql", "LONGBLOB"
end TestMySQLBinary

on TestPostgreSQLBinary
   __TestBinary "postgresql", "BYTEA"
end TestPostgreSQLBinary

-- Transactions. The drivers never begin one themselves (revdb never
-- calls transBegin), so each statement is committed on its own until a
-- script begins one with SQL. Then:
--
-- - MySQL's revRollBackDatabase and revCommitDatabase do nothing
--   (dbmysql's transCommit and transRollback are empty, as revdb.cpp's
--   comments say), and the script ends the transaction with SQL.
-- - PostgreSQL's revCommitDatabase commits it, and its
--   revRollBackDatabase rolls it back. Until 0.2.7-rc.6.10 REVDB_Rollback
--   (revdb.cpp) called transCommit, not transRollback, so a "rolled back"
--   transaction was kept (found 2026-10-31; fixed on seth's decision the
--   same day). SQLite's revRollBackDatabase goes through the same
--   REVDB_Rollback (sqlite_rollback.livecodescript).

private command __TestTransactions pDriver, pBegin
   __SkipUnlessServer pDriver
   __Connect pDriver
   __Exec "DROP TABLE IF EXISTS oxt_trans"
   if pDriver is "mysql" then
      __Exec "CREATE TABLE oxt_trans (id integer) ENGINE=InnoDB"
   else
      __Exec "CREATE TABLE oxt_trans (id integer)"
   end if

   -- Each statement on its own is kept: revRollBackDatabase undoes nothing
   __Exec "INSERT INTO oxt_trans VALUES (1)"
   revRollBackDatabase lDatabaseID
   TestAssert pDriver & ": with no transaction begun, a statement is kept", __Count("oxt_trans") is 1

   -- SQL's own ROLLBACK
   __Exec pBegin
   __Exec "INSERT INTO oxt_trans VALUES (2)"
   __Exec "ROLLBACK"
   TestAssert pDriver & ": SQL ROLLBACK undoes the transaction", __Count("oxt_trans") is 1

   -- revRollBackDatabase in a transaction begun with SQL
   local tKept
   __Exec pBegin
   __Exec "INSERT INTO oxt_trans VALUES (3)"
   revRollBackDatabase lDatabaseID
   if pDriver is "mysql" then
      TestAssert pDriver & ": revRollBackDatabase does nothing (the transaction is still open)", \
            __Count("oxt_trans") is 2
      __Exec "ROLLBACK"
      TestAssert pDriver & ": then SQL ROLLBACK undoes it", __Count("oxt_trans") is 1
   else
      TestAssert pDriver & ": revRollBackDatabase undoes the transaction", __Count("oxt_trans") is 1
   end if
   put __Count("oxt_trans") into tKept

   -- revCommitDatabase
   __Exec pBegin
   __Exec "INSERT INTO oxt_trans VALUES (4)"
   revCommitDatabase lDatabaseID
   if pDriver is "mysql" then
      __Exec "COMMIT"
   end if
   __Disconnect
   __Connect pDriver
   TestAssert pDriver & ": a committed row is there on a new connection", __Count("oxt_trans") is tKept + 1
   __Exec "DROP TABLE oxt_trans"
   __Disconnect
end __TestTransactions

on TestMySQLTransactions
   __TestTransactions "mysql", "START TRANSACTION"
end TestMySQLTransactions

on TestPostgreSQLTransactions
   __TestTransactions "postgresql", "BEGIN"
end TestPostgreSQLTransactions

-- Errors: revDataFromQuery's result begins "revdberr", while
-- revExecuteSQL's and revQueryDatabase's are the server's message alone;
-- the connection stays usable after one

private command __TestErrors pDriver
   __SkipUnlessServer pDriver
   __Connect pDriver
   local tResult
   revExecuteSQL lDatabaseID, "SELEC nothing"
   put the result into tResult
   TestDiagnostic pDriver & " bad SQL: " & tResult
   -- The result is the server's own message, with no "revdberr" before it
   TestAssert pDriver & ": revExecuteSQL of bad SQL gives the server's message", \
         tResult is not empty and tResult is not an integer and item 1 of tResult is not "revdberr"
   get revDataFromQuery(,, lDatabaseID, "SELECT * FROM oxt_no_such_table")
   TestAssert pDriver & ": revDataFromQuery of a missing table", item 1 of it is "revdberr"
   -- revQueryDatabase gives the server's message too, not a cursor id
   get revQueryDatabase(lDatabaseID, "SELECT * FROM oxt_no_such_table")
   TestDiagnostic pDriver & " missing table: " & it
   TestAssert pDriver & ": revQueryDatabase of a missing table gives the server's message", \
         it is not empty and it is not an integer and item 1 of it is not "revdberr"
   if pDriver is "postgresql" then
      -- PostgreSQL ends a transaction an error interrupted; outside one
      -- there is nothing to end
      __Exec "ROLLBACK"
   end if
   TestAssert pDriver & ": the connection still answers", revDataFromQuery(,, lDatabaseID, "SELECT 1") is 1
   __Disconnect
end __TestErrors

on TestMySQLErrors
   __TestErrors "mysql"
end TestMySQLErrors

on TestPostgreSQLErrors
   __TestErrors "postgresql"
end TestPostgreSQLErrors

-- The client library itself: what changing it (MySQL Connector/C 6.0
-- and libpq 9.4 to MariaDB Connector/C 3.4 and libpq 17, OXT-Beyond
-- 0.2.8) could change for a script. tools/ci/compare_test_output.py
-- compares these tests' diagnostics between two builds' runs, as the
-- Databases job does with the previous release's.

-- The character sets of a MySQL connection. A script that names none
-- gets latin1, as with Connector/C 6.0 (MariaDB Connector/C's own default
-- is utf8mb4; thirdparty/libmysql/include/ma_config.h), and the server
-- converts what it sends to it.
on TestMySQLCharacterSet
   __SkipUnlessServer "mysql"
   __Connect "mysql"
   local tSets
   put revDataFromQuery(tab, return, lDatabaseID, \
         "SELECT @@character_set_client, @@character_set_connection, @@character_set_results") into tSets
   TestDiagnostic "mysql character sets: " & tSets
   TestAssert "mysql: the connection's character set is latin1", \
         tSets is "latin1" & tab & "latin1" & tab & "latin1"
   __Disconnect
end TestMySQLCharacterSet

-- Text with letters beyond ASCII, in a utf8mb4 column, through SQL and
-- through a placeholder: the engine gives the driver native text (ISO
-- 8859-1 on Linux), which the server stores as UTF-8 and converts back
on TestMySQLNativeText
   __SkipUnlessServer "mysql"
   __Connect "mysql"
   __Exec "DROP TABLE IF EXISTS oxt_text"
   __Exec "CREATE TABLE oxt_text (id integer, txt varchar(100)) CHARACTER SET utf8mb4"
   local tText, tValues, tAnswer
   put "caf" & numToNativeChar(233) && numToNativeChar(252) & "ber" && numToNativeChar(169) into tText
   __Exec "INSERT INTO oxt_text VALUES (1, '" & tText & "')"
   put 2 into tValues[1]
   put tText into tValues[2]
   revExecuteSQL lDatabaseID, "INSERT INTO oxt_text VALUES (:1, :2)", "tValues"
   put revDataFromQuery(tab, return, lDatabaseID, "SELECT id, HEX(txt) FROM oxt_text ORDER BY id") into tAnswer
   TestDiagnostic "mysql native text, as the server stores it: " & tAnswer
   TestAssert "mysql: the server stores native text as UTF-8", \
         tAnswer is "1" & tab & "636166C3A920C3BC62657220C2A9" & return & "2" & tab & "636166C3A920C3BC62657220C2A9"
   TestAssert "mysql: native text comes back unchanged", \
         revDataFromQuery(tab, return, lDatabaseID, "SELECT txt FROM oxt_text ORDER BY id") is tText & return & tText
   __Exec "DROP TABLE oxt_text"
   __Disconnect
end TestMySQLNativeText

-- PostgreSQL's connection takes the database's encoding unless a script
-- sets client_encoding, with libpq 17 as with 9.4
on TestPostgreSQLCharacterSet
   __SkipUnlessServer "postgresql"
   __Connect "postgresql"
   local tEncoding
   put revDataFromQuery(tab, return, lDatabaseID, "SHOW client_encoding") into tEncoding
   TestDiagnostic "postgresql client_encoding: " & tEncoding
   TestAssert "postgresql: client_encoding is the database's", \
         tEncoding is revDataFromQuery(tab, return, lDatabaseID, \
         "SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()")
   __Disconnect
end TestPostgreSQLCharacterSet

on TestPostgreSQLNativeText
   __SkipUnlessServer "postgresql"
   __Connect "postgresql"
   __Exec "SET client_encoding TO 'LATIN1'"
   __Exec "DROP TABLE IF EXISTS oxt_text"
   __Exec "CREATE TABLE oxt_text (id integer, txt varchar(100))"
   local tText, tValues, tAnswer
   put "caf" & numToNativeChar(233) && numToNativeChar(252) & "ber" && numToNativeChar(169) into tText
   __Exec "INSERT INTO oxt_text VALUES (1, '" & tText & "')"
   put 2 into tValues[1]
   put tText into tValues[2]
   revExecuteSQL lDatabaseID, "INSERT INTO oxt_text VALUES (:1, :2)", "tValues"
   put revDataFromQuery(tab, return, lDatabaseID, \
         "SELECT id, encode(convert_to(txt, 'UTF8'), 'hex') FROM oxt_text ORDER BY id") into tAnswer
   TestDiagnostic "postgresql native text, as the server stores it: " & tAnswer
   TestAssert "postgresql: the server stores LATIN1 text as UTF-8", \
         tAnswer is "1" & tab & "636166c3a920c3bc62657220c2a9" & return & "2" & tab & "636166c3a920c3bc62657220c2a9"
   TestAssert "postgresql: native text comes back unchanged", \
         revDataFromQuery(tab, return, lDatabaseID, "SELECT txt FROM oxt_text ORDER BY id") is tText & return & tText
   __Exec "DROP TABLE oxt_text"
   __Disconnect
end TestPostgreSQLNativeText

-- Column types: the text of each value and revDatabaseColumnTypes. The
-- values are the server's text (both drivers use the text protocol), and
-- the types are what the drivers make of the field types the client
-- library reports, as OXT-Beyond 0.2.7 gave them: MySQL's DECIMAL is
-- STRING and its BIGINT INTEGER, YEAR is DATE; PostgreSQL's BIGINT,
-- TIMESTAMP and the text types are STRING, NUMERIC is DOUBLE and
-- INTERVAL TIME.

private command __TestTypes pDriver, pCreate, pInsert, pValues, pTypes
   __SkipUnlessServer pDriver
   __Connect pDriver
   __Exec "DROP TABLE IF EXISTS oxt_types"
   __Exec pCreate
   __Exec pInsert
   local tRow, tCursor, tTypes
   put revDataFromQuery(tab, return, lDatabaseID, "SELECT * FROM oxt_types") into tRow
   TestDiagnostic pDriver & " values: " & tRow
   TestAssert pDriver & ": the values' text", tRow is pValues
   put revQueryDatabase(lDatabaseID, "SELECT * FROM oxt_types") into tCursor
   TestAssert pDriver & ": a cursor on the types (" & tCursor & ")", tCursor is an integer
   if tCursor is an integer then
      put revDatabaseColumnTypes(tCursor) into tTypes
      TestDiagnostic pDriver & " revDatabaseColumnTypes: " & tTypes
      TestAssert pDriver & ": revDatabaseColumnTypes", tTypes is pTypes
      revCloseCursor tCursor
   end if
   __Exec "DROP TABLE oxt_types"
   __Disconnect
end __TestTypes

on TestMySQLTypes
   local tValues
   put "-5,300,70000,123456,9007199254740993,12.345,1.5,2.25,2026-11-10,13:14:15," & \
         "2026-11-10 13:14:15,2026-11-10 13:14:15,2026,ab,abc,text,blob,b,x" into tValues
   replace comma with tab in tValues
   __TestTypes "mysql", \
         "CREATE TABLE oxt_types (t tinyint, s smallint, m mediumint, i integer, b bigint," && \
         "d decimal(10,3), f float, g double, dt date, tm time, dtm datetime, ts timestamp NULL," && \
         "y year, c char(5), v varchar(10), tx text, bl blob, e enum('a','b'), st set('x','y'))", \
         "INSERT INTO oxt_types VALUES (-5, 300, 70000, 123456, 9007199254740993, 12.345, 1.5, 2.25," && \
         "'2026-11-10', '13:14:15', '2026-11-10 13:14:15', '2026-11-10 13:14:15', 2026, 'ab', 'abc'," && \
         "'text', 'blob', 'b', 'x')", \
         tValues, \
         "SMALLINT,SMALLINT,INTEGER,INTEGER,INTEGER,STRING,FLOAT,DOUBLE,DATE,TIME,DATETIME," & \
         "TIMESTAMP,DATE,STRING,STRING,BLOB,BLOB,STRING,STRING"
end TestMySQLTypes

on TestPostgreSQLTypes
   local tValues
   put "-5,123456,9007199254740993,12.345,1.5,2.25,t,2026-11-10,13:14:15,2026-11-10 13:14:15," & \
         "ab   ,abc,text,1 day 02:00:00,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11" into tValues
   replace comma with tab in tValues
   __TestTypes "postgresql", \
         "CREATE TABLE oxt_types (s smallint, i integer, b bigint, d numeric(10,3), f real," && \
         "g double precision, bo boolean, dt date, tm time, ts timestamp, c char(5), v varchar(10)," && \
         "tx text, iv interval, u uuid)", \
         "INSERT INTO oxt_types VALUES (-5, 123456, 9007199254740993, 12.345, 1.5, 2.25, true," && \
         "'2026-11-10', '13:14:15', '2026-11-10 13:14:15', 'ab', 'abc', 'text', '1 day 2 hours'," && \
         "'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')", \
         tValues, \
         "INTEGER,INTEGER,STRING,DOUBLE,FLOAT,DOUBLE,BOOLEAN,DATE,TIME,STRING,STRING," & \
         "STRING,STRING,TIME,STRING"
end TestPostgreSQLTypes

-- A server that is not there: an error text from the client library, not
-- an id. The text is the library's own, so it is a diagnostic here: MariaDB
-- Connector/C words it "Can't connect to server on ..." where Connector/C
-- 6.0 said "Can't connect to MySQL server on ...".

private command __TestNoServer pDriver
   __SkipUnlessServer pDriver
   local tResult
   put revOpenDatabase(pDriver, "127.0.0.1:1", "oxt_test", "oxt", "x") into tResult
   TestDiagnostic pDriver & " with no server: " & tResult
   TestAssert pDriver & ": no server gives no connection", tResult is not an integer
   TestAssert pDriver & ": no server gives an error text", tResult is not empty
   if tResult is an integer then
      revCloseDatabase tResult
   end if
end __TestNoServer

on TestMySQLNoServer
   __TestNoServer "mysql"
end TestMySQLNoServer

on TestPostgreSQLNoServer
   __TestNoServer "postgresql"
end TestPostgreSQLNoServer

-- The server, and how the user logged in: a diagnostic, for the
-- comparison of two builds' runs. The Databases job runs these tests
-- against servers whose default logins differ (MySQL 8.0 with
-- mysql_native_password, MySQL 8.4 with caching_sha2_password, MariaDB,
-- PostgreSQL 16 with md5 and 17 with SCRAM-SHA-256), and the connection
-- tests above are each login's test.

on TestMySQLServer
   __SkipUnlessServer "mysql"
   __Connect "mysql"
   TestDiagnostic "mysql server: " & revDataFromQuery(tab, return, lDatabaseID, "SELECT VERSION()")
   __Disconnect
end TestMySQLServer

on TestPostgreSQLServer
   __SkipUnlessServer "postgresql"
   __Connect "postgresql"
   TestDiagnostic "postgresql server: " & revDataFromQuery(tab, return, lDatabaseID, "SHOW server_version")
   TestDiagnostic "postgresql password_encryption: " & \
         revDataFromQuery(tab, return, lDatabaseID, "SHOW password_encryption")
   __Disconnect
end TestPostgreSQLServer
