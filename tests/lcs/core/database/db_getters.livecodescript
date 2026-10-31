script "CoreDatabaseTest"

/*
Copyright (C) 2017 LiveCode Ltd.

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

function generateStrings 
   local tArray, tBaseString, tCounter
   put 1 into tCounter
   put "Table%d" into tBaseString
   repeat 1800 times
      put format(tBaseString,tCounter) into tArray[tCounter]
      put tCounter+1 into tCounter
   end repeat
   return tArray
end generateStrings

command createTables pConnection, pStrings
   local tBaseStmt, tCounter
   put "CREATE TABLE %s (id integer)" into tBaseStmt
   put 1 into tCounter
   repeat 1800 times
      revExecuteSQL pConnection, format(tBaseStmt, pStrings[tCounter])
      put tCounter+1 into tCounter
   end repeat
end createTables

-- OXT-Beyond: run against the MySQL server that the environment names
-- (OXT_TEST_MYSQL_HOST and the rest, as server_databases.livecodescript
-- says), and skipped when there is none; LiveCode's skipped always. The
-- tables are dropped afterwards, and only they are counted, since the
-- other database tests share the database.
on TestDBTableGettersMySQL
   TestSkipIfNot "database", "mysql"
   if $OXT_TEST_MYSQL_HOST is empty then
      TestSkip "skipping DB test", "no mysql server: OXT_TEST_MYSQL_HOST is not set"
      exit TestDBTableGettersMySQL
   end if

   TestLoadExternal "revdb"
   
   local tArray
   put generateStrings() into tArray
   local tDatabaseID, tNames
   put revOpenDatabase("mysql",$OXT_TEST_MYSQL_HOST,$OXT_TEST_MYSQL_DATABASE,$OXT_TEST_MYSQL_USER,$OXT_TEST_MYSQL_PASSWORD,false) into tDatabaseID
   TestAssert "connect", tDatabaseID is an integer
   dropTables tDatabaseID, tArray
   createTables tDatabaseID, tArray
   put revDatabaseTableNames(tDatabaseID) into tNames
   filter tNames with regex pattern "^Table[0-9]+$"
   TestAssert "check the correct things are returned", the number of lines in tNames is 1800
   dropTables tDatabaseID, tArray
   revCloseDatabase tDatabaseID
end TestDBTableGettersMySQL

command dropTables pConnection, pStrings
   repeat with tCounter = 1 to 1800
      revExecuteSQL pConnection, "DROP TABLE IF EXISTS" && pStrings[tCounter]
   end repeat
end dropTables
