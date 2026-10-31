script "TestSQLiteRollback"

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

-- revRollBackDatabase and revdb_rollback discard a transaction that a
-- script began with SQL, and revCommitDatabase keeps one. Until
-- 0.2.7-rc.6.10 REVDB_Rollback (revdb/src/revdb.cpp) called the driver's
-- transCommit, so a "rolled back" transaction was committed (seth's
-- decision, 2026-10-31: make it roll back, as its dictionary entry says).
-- revdb never begins a transaction itself, so a statement made outside one
-- is kept whatever follows it.

local sDatabaseID, sDatabaseFile

on TestSetup
   TestSkipIfNot "database", "sqlite"
   TestLoadExternal "revdb"
   put the tempname into sDatabaseFile
   put revOpenDatabase("sqlite", sDatabaseFile,,,,) into sDatabaseID
   if sDatabaseID is not an integer then
      throw "the database did not open:" && sDatabaseID
   end if
   revExecuteSQL sDatabaseID, "CREATE TABLE oxt_trans (id INTEGER)"
end TestSetup

on TestTeardown
   revCloseDatabase sDatabaseID
   delete file sDatabaseFile
end TestTeardown

private function __Count
   return revDataFromQuery(comma, return, sDatabaseID, "SELECT COUNT(*) FROM oxt_trans")
end __Count

on TestRollBackOutsideATransaction
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_trans VALUES (1)"
   revRollBackDatabase sDatabaseID
   TestAssert "with no transaction begun, a statement is kept", __Count() is 1
end TestRollBackOutsideATransaction

on TestRollBackDatabase
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_trans VALUES (1)"
   revExecuteSQL sDatabaseID, "BEGIN"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_trans VALUES (2)"
   TestAssert "the transaction sees its own row", __Count() is 2
   revRollBackDatabase sDatabaseID
   TestAssert "revRollBackDatabase discards the transaction", __Count() is 1
   TestAssert "revRollBackDatabase's result is empty", the result is empty
   -- and no transaction is open: a new one can begin
   revExecuteSQL sDatabaseID, "BEGIN"
   TestAssert "a new transaction begins after it", not (the result contains "transaction")
   revExecuteSQL sDatabaseID, "ROLLBACK"
end TestRollBackDatabase

on TestRollbackFunction
   revExecuteSQL sDatabaseID, "BEGIN"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_trans VALUES (3)"
   get revdb_rollback(sDatabaseID)
   TestAssert "revdb_rollback returns empty", it is empty
   TestAssert "revdb_rollback discards the transaction", __Count() is 0
end TestRollbackFunction

on TestCommitDatabase
   revExecuteSQL sDatabaseID, "BEGIN"
   revExecuteSQL sDatabaseID, "INSERT INTO oxt_trans VALUES (4)"
   revCommitDatabase sDatabaseID
   revRollBackDatabase sDatabaseID
   TestAssert "revCommitDatabase keeps the transaction, and a rollback after it undoes nothing", \
         __Count() is 1
end TestCommitDatabase
