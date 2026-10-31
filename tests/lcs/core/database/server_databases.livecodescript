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
-- revCommitDatabase and revRollBackDatabase do nothing), and change no
-- driver.
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
   TestAssert pDriver & ": connects (" & lDatabaseID & ")", lDatabaseID is an integer
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
   -- The client library (thirdparty/libmysql, Connector/C 6.0) asks for
   -- TLS 1.0 alone (TLSv1_client_method in viosslfactories.c), which
   -- MySQL 8.0.28 and later and current MariaDB refuse: "SSL connection
   -- error" (found 2026-10-31, for seth: the plan's MOD-D3). Ssl_cipher
   -- is empty in a session without TLS.
   __TestTLS "mysql", "SHOW SESSION STATUS LIKE 'Ssl_cipher'", 2, \
         "the MySQL client library speaks TLS 1.0 only, which current servers refuse"
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
-- - PostgreSQL's revCommitDatabase commits it, and so does its
--   revRollBackDatabase: REVDB_Rollback (revdb.cpp) calls transCommit,
--   not transRollback, so a "rolled back" transaction is kept. That is
--   asserted as broken, not fixed here: a fix changes what scripts see
--   (found 2026-10-31, for seth). SQLite's revRollBackDatabase goes
--   through the same REVDB_Rollback.

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
      TestAssertBroken pDriver & ": revRollBackDatabase undoes the transaction", __Count("oxt_trans") is 1, \
            "REVDB_Rollback calls transCommit, so the transaction is committed"
      -- Whatever it did, no transaction is open now
      __Exec "ROLLBACK"
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
