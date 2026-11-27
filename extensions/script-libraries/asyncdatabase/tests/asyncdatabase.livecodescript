script "TestAsyncDatabaseLibrary"
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
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.
*/

-- The Background Database library (com.livecode.library.asyncdatabase) as
-- a script uses it, with SQLite: each connection is held by a worker that
-- makes the revDB calls, and the stack is sent the answers.
--
-- Every wait here is "with messages" and ends as soon as the message has
-- come: the time limits are for a build that is broken, not a measure.

-- What came back for each request: ["times"], ["result"], ["error"],
-- ["columns"], ["parameters"], ["order"]
local sAnswers
-- What came back for each connection's opening
local sOpened
-- A count of everything that has arrived, and of a timer's messages
local sArrived
local sTicks
-- This test's database files
local sFolder

constant kWaitSeconds = 60

on TestSetup
   TestSkipIfNot "desktop"
   TestSkipIfNot "database", "sqlite"
   TestSkipIfNot "extension", "org.openxtalk.library.async"
   TestLoadExtension "org.openxtalk.library.async"
   TestLoadExternal "revdb"

   local tRepo
   put TestGetEngineRepositoryPath() into tRepo
   start using stack (tRepo & "/extensions/script-libraries/worker/worker.livecodescript")
   start using stack (tRepo & "/extensions/script-libraries/asyncdatabase/asyncdatabase.livecodescript")

   put empty into sAnswers
   put empty into sOpened
   put 0 into sArrived
   put 0 into sTicks
   put specialFolderPath("temporary") & "/oxt-asyncdb-test-" & the milliseconds & "-" & random(1000000) into sFolder
   create folder sFolder
end TestSetup

on TestTearDown
   local tConnections
   try
      put asyncDatabases() into tConnections
   catch tError
   end try
   repeat for each line tConnection in tConnections
      asyncDatabaseClose tConnection
   end repeat
   if sFolder is not empty and there is a folder sFolder then
      repeat for each line tFile in files(sFolder)
         delete file (sFolder & "/" & tFile)
      end repeat
      delete folder sFolder
   end if
end TestTearDown

----------------------------------------------------------------
-- The messages
----------------------------------------------------------------

on answered pRequest, pResult, pError, pColumns
   add 1 to sArrived
   add 1 to sAnswers[pRequest]["times"]
   put the paramCount into sAnswers[pRequest]["parameters"]
   put pResult into sAnswers[pRequest]["result"]
   put pError into sAnswers[pRequest]["error"]
   put pColumns into sAnswers[pRequest]["columns"]
   put sArrived into sAnswers[pRequest]["order"]
end answered

on opened pConnection, pResult, pError
   add 1 to sArrived
   add 1 to sOpened[pConnection]["times"]
   put the paramCount into sOpened[pConnection]["parameters"]
   put pResult into sOpened[pConnection]["result"]
   put pError into sOpened[pConnection]["error"]
   put sArrived into sOpened[pConnection]["order"]
end opened

on countATick
   add 1 to sTicks
   send "countATick" to me in 10 milliseconds
end countATick

private function isAnswered pRequest
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sAnswers[pRequest]["times"] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   return sAnswers[pRequest]["times"] is 1
end isAnswered

private function isOpened pConnection
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sOpened[pConnection]["times"] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   return sOpened[pConnection]["times"] is 1
end isOpened

private function thrownBy pStatement
   local tError
   try
      do pStatement
   catch tError
      return tError
   end try
   return empty
end thrownBy

-- A database of this test's, open, with a table of three rows
private function openWithTable
   local tConnection, tCreate, tInsert
   put asyncDatabaseOpen("sqlite", sFolder & "/" & random(1000000000) & ".sqlite", "opened") into tConnection
   put asyncDatabaseExecute(tConnection, "CREATE TABLE fruit (id INTEGER, name TEXT, price REAL, note TEXT, data BLOB)", "answered") into tCreate
   put asyncDatabaseExecute(tConnection, "INSERT INTO fruit (id, name, price, note) VALUES (1, 'apple', 0.5, 'red'), (2, 'pear', 0.75, NULL), (3, 'plum', 1.25, '')", "answered") into tInsert
   if not isAnswered(tInsert) or sAnswers[tInsert]["error"] is not empty then
      throw "the test database was not made:" && sAnswers[tCreate]["error"] && sAnswers[tInsert]["error"]
   end if
   return tConnection
end openWithTable

----------------------------------------------------------------
-- Opening
----------------------------------------------------------------

on TestOpen
   local tConnection
   put asyncDatabaseOpen("sqlite", sFolder & "/open.sqlite", "opened") into tConnection
   TestAssert "a connection has a number", tConnection is an integer and tConnection > 0
   TestAssert "and is listed", tConnection is among the lines of asyncDatabases()
   TestAssert "opening is answered once", isOpened(tConnection)
   TestAssert "with no error", sOpened[tConnection]["error"] is empty
   TestAssert "as three parameters", sOpened[tConnection]["parameters"] is 3
   TestAssert "and the file is made", there is a file (sFolder & "/open.sqlite")

   asyncDatabaseClose tConnection
   TestAssert "closing", the result is empty
   TestAssert "takes it off the list", tConnection is not among the lines of asyncDatabases()
   asyncDatabaseClose tConnection
   TestAssert "closing it again says it is not there", the result is "no such connection"
end TestOpen

on TestArgumentsAsAnArray
   local tConnection, tArguments, tRequest
   put sFolder & "/array.sqlite" into tArguments[1]
   put asyncDatabaseOpen("sqlite", tArguments, "opened") into tConnection
   TestAssert "the arguments can be an array", isOpened(tConnection) and sOpened[tConnection]["error"] is empty
   put asyncDatabaseQuery(tConnection, "SELECT 1 + 1 AS two", "answered") into tRequest
   TestAssert "and the connection answers", isAnswered(tRequest) and sAnswers[tRequest]["result"][1]["two"] is 2
end TestArgumentsAsAnArray

on TestOpenFails
   local tConnection, tQuery, tExecute
   put asyncDatabaseOpen("nosuchdatabase", "x", "opened") into tConnection
   put asyncDatabaseQuery(tConnection, "SELECT 1", "answered") into tQuery
   put asyncDatabaseExecute(tConnection, "CREATE TABLE t (a)", "answered") into tExecute
   TestAssert "a connection that cannot open is answered", isOpened(tConnection)
   TestAssert "with an error", sOpened[tConnection]["error"] is not empty
   TestDiagnostic "the error:" && sOpened[tConnection]["error"]
   TestAssert "the requests made to it end with that error", isAnswered(tQuery) and isAnswered(tExecute) \
         and sAnswers[tQuery]["error"] is sOpened[tConnection]["error"] \
         and sAnswers[tExecute]["error"] is sOpened[tConnection]["error"]
   TestAssert "and it is closed", tConnection is not among the lines of asyncDatabases()
end TestOpenFails

----------------------------------------------------------------
-- Requests
----------------------------------------------------------------

on TestQuery
   local tConnection, tRequest, tRows
   put openWithTable() into tConnection
   put asyncDatabaseQuery(tConnection, "SELECT id, name, price, note FROM fruit ORDER BY id", "answered") into tRequest
   TestAssert "a query returns at once", sAnswers[tRequest] is empty
   TestAssert "and is answered once", isAnswered(tRequest)
   TestAssert "with no error", sAnswers[tRequest]["error"] is empty
   TestAssert "as four parameters", sAnswers[tRequest]["parameters"] is 4
   put sAnswers[tRequest]["result"] into tRows
   TestAssert "with a row for each", the number of elements of tRows is 3
   TestAssert "keyed by the columns' names", tRows[1]["id"] is 1 and tRows[1]["name"] is "apple" \
         and tRows[2]["name"] is "pear" and tRows[3]["name"] is "plum"
   TestAssert "in their order", tRows[3]["price"] is 1.25
   TestAssert "a NULL value has no key", "note" is not among the keys of tRows[2]
   TestAssert "and empty text has one", "note" is among the keys of tRows[3] and tRows[3]["note"] is empty
   TestAssert "the columns are named in order", sAnswers[tRequest]["columns"] is ("id" & return & "name" & return & "price" & return & "note")
end TestQuery

on TestColumnNamesWithCommas
   local tConnection, tRequest, tRows, tAmbiguous
   put openWithTable() into tConnection
   -- revDB joins the names with commas, and an expression's has its own
   put asyncDatabaseQuery(tConnection, "SELECT coalesce(NULL, 'x'), 42 AS answer, name FROM fruit WHERE id = 1", "answered") into tRequest
   TestAssert "a query whose column names have commas is answered", isAnswered(tRequest) and sAnswers[tRequest]["error"] is empty
   put sAnswers[tRequest]["result"] into tRows
   TestAssert "with each column named as it is", sAnswers[tRequest]["columns"] is \
         ("coalesce(NULL, 'x')" & return & "answer" & return & "name")
   TestAssert "and each value under its own name", tRows[1]["coalesce(NULL, 'x')"] is "x" \
         and tRows[1]["answer"] is 42 and tRows[1]["name"] is "apple"

   -- A quoted alias's commas cannot be told from revDB's: the columns are
   -- then named by their numbers, and no value is given another's name
   put asyncDatabaseQuery(tConnection, "SELECT 'y' AS " & quote & "a, b" & quote & ", name FROM fruit WHERE id = 1", "answered") into tAmbiguous
   TestAssert "a query whose names cannot be told apart is answered", isAnswered(tAmbiguous) and sAnswers[tAmbiguous]["error"] is empty
   put sAnswers[tAmbiguous]["result"] into tRows
   TestAssert "with its columns named by number", sAnswers[tAmbiguous]["columns"] is ("1" & return & "2")
   TestAssert "and its values under them", tRows[1][1] is "y" and tRows[1][2] is "apple" \
         and the number of elements of tRows[1] is 2
end TestColumnNamesWithCommas

on TestNoRows
   local tConnection, tRequest
   put openWithTable() into tConnection
   put asyncDatabaseQuery(tConnection, "SELECT id, name FROM fruit WHERE id > 100", "answered") into tRequest
   TestAssert "a query with no rows is answered", isAnswered(tRequest) and sAnswers[tRequest]["error"] is empty
   TestAssert "with none", the number of elements of sAnswers[tRequest]["result"] is 0
   TestAssert "and its columns", sAnswers[tRequest]["columns"] is ("id" & return & "name")
end TestNoRows

on TestExecute
   local tConnection, tRequest, tQuery
   put openWithTable() into tConnection
   put asyncDatabaseExecute(tConnection, "UPDATE fruit SET price = price * 2 WHERE price < 1", "answered") into tRequest
   TestAssert "a statement is answered", isAnswered(tRequest) and sAnswers[tRequest]["error"] is empty
   TestAssert "with the rows it changed", sAnswers[tRequest]["result"] is 2
   TestAssert "as three parameters", sAnswers[tRequest]["parameters"] is 3
   put asyncDatabaseQuery(tConnection, "SELECT price FROM fruit ORDER BY id", "answered") into tQuery
   TestAssert "and the change is there", isAnswered(tQuery) and sAnswers[tQuery]["result"][1]["price"] is 1.0 \
         and sAnswers[tQuery]["result"][2]["price"] is 1.5
end TestExecute

on TestValues
   local tConnection, tInsert, tQuery, tText, tBytes, tValues, tArrayInsert, tRows
   put openWithTable() into tConnection
   put "it's ;--" & quote & " not SQL" into tText
   put asyncDatabaseExecute(tConnection, "INSERT INTO fruit (id, name) VALUES (:1, :2)", "answered", 10, tText) into tInsert
   TestAssert "values are given as parameters", isAnswered(tInsert) and sAnswers[tInsert]["error"] is empty

   repeat with i = 0 to 255
      put numToByte(i) after tBytes
   end repeat
   put 11 into tValues[1]
   put tBytes into tValues["*b2"]
   put asyncDatabaseExecute(tConnection, "INSERT INTO fruit (id, data) VALUES (:1, :2)", "answered", tValues) into tArrayInsert
   TestAssert "or as an array, with binary data", isAnswered(tArrayInsert) and sAnswers[tArrayInsert]["error"] is empty

   put asyncDatabaseQuery(tConnection, "SELECT id, name, data FROM fruit WHERE id >= :1 ORDER BY id", "answered", 10) into tQuery
   TestAssert "a query takes values too", isAnswered(tQuery) and sAnswers[tQuery]["error"] is empty
   put sAnswers[tQuery]["result"] into tRows
   TestAssert "the text came back as it went in", tRows[1]["name"] is tText
   TestAssert "and every byte", tRows[2]["data"] is tBytes
   TestAssert "of the two rows", the number of elements of tRows is 2
end TestValues

on TestErrors
   local tConnection, tBad, tAfter, tBadExecute
   put openWithTable() into tConnection
   put asyncDatabaseQuery(tConnection, "SELEKT nothing", "answered") into tBad
   put asyncDatabaseExecute(tConnection, "INSERT INTO nosuchtable VALUES (1)", "answered") into tBadExecute
   put asyncDatabaseQuery(tConnection, "SELECT count(*) AS n FROM fruit", "answered") into tAfter
   TestAssert "a query that fails is answered with revDB's error", isAnswered(tBad) \
         and sAnswers[tBad]["error"] is not empty and sAnswers[tBad]["result"] is empty
   TestDiagnostic "the query's error:" && sAnswers[tBad]["error"]
   TestAssert "as is a statement", isAnswered(tBadExecute) and sAnswers[tBadExecute]["error"] is not empty
   TestDiagnostic "the statement's error:" && sAnswers[tBadExecute]["error"]
   TestAssert "and the connection goes on", isAnswered(tAfter) and sAnswers[tAfter]["result"][1]["n"] is 3
end TestErrors

on TestWrongCalls
   local tConnection
   put openWithTable() into tConnection
   TestAssert "a request of no connection throws", \
         thrownBy("get asyncDatabaseQuery(987654, " & quote & "SELECT 1" & quote & ", " & quote & "answered" & quote & ")") \
         is "asyncDatabaseQuery: no such connection"
   TestAssert "as does a statement", \
         thrownBy("get asyncDatabaseExecute(empty, " & quote & "SELECT 1" & quote & ", " & quote & "answered" & quote & ")") \
         is "asyncDatabaseExecute: no such connection"
   TestAssert "a request with no message throws", \
         thrownBy("get asyncDatabaseQuery(" & tConnection & ", " & quote & "SELECT 1" & quote & ", empty)") \
         is "asyncDatabaseQuery: no message to send when the database has answered"
   TestAssert "an opening with no type throws", \
         thrownBy("get asyncDatabaseOpen(empty, " & quote & "x" & quote & ", empty)") \
         is "asyncDatabaseOpen: no type of database"
   asyncDatabaseClose 987654
   TestAssert "closing no connection says so", the result is "no such connection"
end TestWrongCalls

on TestOrder
   local tConnection, tRequests, tRight, tLast
   put openWithTable() into tConnection
   repeat with i = 1 to 20
      put asyncDatabaseExecute(tConnection, "INSERT INTO fruit (id) VALUES (:1)", "answered", 100 + i) into tRequests[i]
   end repeat
   put asyncDatabaseQuery(tConnection, "SELECT count(*) AS n FROM fruit", "answered") into tRequests[21]
   put true into tRight
   put 0 into tLast
   repeat with i = 1 to 21
      if not isAnswered(tRequests[i]) or sAnswers[tRequests[i]]["order"] <= tLast then
         put false into tRight
      end if
      put sAnswers[tRequests[i]]["order"] into tLast
   end repeat
   TestAssert "a connection's requests are run and answered in order", tRight
   TestAssert "the last saw all the others", sAnswers[tRequests[21]]["result"][1]["n"] is 23
end TestOrder

on TestRequestsBeforeTheConnectionIsOpen
   local tConnection, tCreate, tQuery
   put asyncDatabaseOpen("sqlite", sFolder & "/early.sqlite", "opened") into tConnection
   put asyncDatabaseExecute(tConnection, "CREATE TABLE t (a)", "answered") into tCreate
   put asyncDatabaseQuery(tConnection, "SELECT count(*) AS n FROM t", "answered") into tQuery
   TestAssert "requests made straight after opening wait for it", isAnswered(tQuery) and sAnswers[tQuery]["error"] is empty \
         and sAnswers[tQuery]["result"][1]["n"] is 0
   TestAssert "and come after the opening", sOpened[tConnection]["order"] < sAnswers[tCreate]["order"]
end TestRequestsBeforeTheConnectionIsOpen

----------------------------------------------------------------
-- The point of it
----------------------------------------------------------------

-- A query that keeps SQLite busy for a while: counting a few million
-- numbers it makes itself
constant kSlowQuery = "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c WHERE x < 3000000) SELECT count(*) AS n FROM c"

on TestTheStackGoesOn
   local tConnection, tWarm, tRequest, tBefore, tBlocking, tDatabaseID, tBlockingTicks
   put openWithTable() into tConnection

   -- The same query with revDB itself, for the comparison
   put revOpenDatabase("sqlite", sFolder & "/blocking.sqlite",,,,) into tDatabaseID
   put 0 into sTicks
   send "countATick" to me in 10 milliseconds
   wait 30 milliseconds with messages
   put sTicks into tBlockingTicks
   put the milliseconds into tBefore
   get revDataFromQuery(tab, return, tDatabaseID, kSlowQuery)
   put the milliseconds - tBefore into tBlocking
   put sTicks - tBlockingTicks into tBlockingTicks
   revCloseDatabase tDatabaseID
   TestAssert "revDB's own query stops the stack's messages", tBlockingTicks is 0

   put 0 into sTicks
   put the milliseconds into tBefore
   put asyncDatabaseQuery(tConnection, kSlowQuery, "answered") into tRequest
   TestAssert "the request returns before the query has run", the milliseconds - tBefore < tBlocking div 2
   TestAssert "its answer comes", isAnswered(tRequest) and sAnswers[tRequest]["result"][1]["n"] is 3000000
   TestAssert "and this stack's own messages were delivered meanwhile", sTicks >= 3
   TestDiagnostic "the query took" && tBlocking && "ms with revDB, during which no timer message came;" \
         && sTicks && "timer messages came during it here"

   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "countATick" then
         cancel item 1 of tMessage
      end if
   end repeat
end TestTheStackGoesOn

on TestTwoConnectionsAtOnce
   local tFirst, tSecond, tOne, tTwo, tBefore, tBoth
   put openWithTable() into tFirst
   put openWithTable() into tSecond
   put the milliseconds into tBefore
   put asyncDatabaseQuery(tFirst, kSlowQuery, "answered") into tOne
   put asyncDatabaseQuery(tSecond, kSlowQuery, "answered") into tTwo
   TestAssert "two connections answer", isAnswered(tOne) and isAnswered(tTwo)
   put the milliseconds - tBefore into tBoth
   TestAssert "with their rows", sAnswers[tOne]["result"][1]["n"] is 3000000 and sAnswers[tTwo]["result"][1]["n"] is 3000000
   TestDiagnostic "two slow queries on two connections took" && tBoth && "ms together"
end TestTwoConnectionsAtOnce

----------------------------------------------------------------
-- Closing
----------------------------------------------------------------

on TestCloseStopsARequest
   local tConnection, tSlow, tQueued
   put openWithTable() into tConnection
   put asyncDatabaseQuery(tConnection, kSlowQuery, "answered") into tSlow
   put asyncDatabaseQuery(tConnection, "SELECT 1 AS one", "answered") into tQueued
   wait 50 milliseconds with messages
   asyncDatabaseClose tConnection
   TestAssert "closing", the result is empty
   TestAssert "ends the request being run", isAnswered(tSlow) and sAnswers[tSlow]["error"] is "connection closed"
   TestAssert "and the one waiting", isAnswered(tQueued) and sAnswers[tQueued]["error"] is "connection closed"
   TestAssert "in their order", sAnswers[tSlow]["order"] < sAnswers[tQueued]["order"]
   TestAssert "and no request can be made then", \
         thrownBy("get asyncDatabaseQuery(" & tConnection & ", " & quote & "SELECT 1" & quote & ", " & quote & "answered" & quote & ")") \
         is "asyncDatabaseQuery: no such connection"
   wait 200 milliseconds with messages
   TestAssert "nothing more is sent", sAnswers[tSlow]["times"] is 1 and sAnswers[tQueued]["times"] is 1
end TestCloseStopsARequest

on TestMessagesGoToTheObjectThatAsked
   local tConnection, tButton, tUntil
   set the defaultStack to the short name of me
   create button "Asker"
   put it into tButton
   set the script of tButton to "on askTheDatabase pConnection" & return & \
         "   set the cRequest of me to asyncDatabaseQuery(pConnection, " & quote & "SELECT 6 * 7 AS n" & quote & ", " & quote & "buttonAnswered" & quote & ")" & return & \
         "end askTheDatabase" & return & \
         "on buttonAnswered pRequest, pRows, pError" & return & \
         "   set the cAnswer of me to pRequest & comma & pRows[1][" & quote & "n" & quote & "] & comma & pError" & return & \
         "end buttonAnswered"
   put openWithTable() into tConnection
   dispatch "askTheDatabase" to tButton with tConnection
   TestAssert "the button's script compiles and runs", it is "handled"
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the cAnswer of tButton is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   TestAssert "the object that made the request is sent the answer", the cAnswer of tButton is (the cRequest of tButton & ",42,")
   TestAssert "and this stack is not", sAnswers[the cRequest of tButton] is empty
   delete tButton
end TestMessagesGoToTheObjectThatAsked

----------------------------------------------------------------
-- MySQL and PostgreSQL
----------------------------------------------------------------

-- A server is used only when the environment names it, as
-- tests/lcs/core/database/server_databases.livecodescript says
-- (OXT_TEST_MYSQL_HOST and the rest; the Linux build's "Databases" job
-- starts the servers and runs these tests). Everywhere else these tests
-- are skipped. What a connection here gives is held to what revDB gives
-- the stack for the same statements, through a connection of its own.

private function serverSetting pDriver, pName
   do "return $OXT_TEST_" & toUpper(pDriver) & "_" & pName
end serverSetting

-- The arguments of revOpenDatabase for the server, without TLS
private function serverArguments pDriver
   local tArguments
   put serverSetting(pDriver, "HOST") into tArguments[1]
   put serverSetting(pDriver, "DATABASE") into tArguments[2]
   put serverSetting(pDriver, "USER") into tArguments[3]
   put serverSetting(pDriver, "PASSWORD") into tArguments[4]
   if pDriver is "mysql" then
      put false into tArguments[5]
   else
      put "sslmode=disable" into tArguments[5]
   end if
   return tArguments
end serverArguments

-- The rows of a request as revDataFromQuery gives them: tab between
-- values, return between rows, empty for NULL
private function rowsAsText pRows, pColumns
   local tText, tColumn
   repeat with i = 1 to the number of elements of pRows
      if i > 1 then
         put return after tText
      end if
      repeat for each line tColumn in pColumns
         put pRows[i][tColumn] & tab after tText
      end repeat
      delete the last char of tText
   end repeat
   return tText
end rowsAsText

private command testServer pDriver, pSleepSQL
   local tArguments, tConnection, tDatabaseID, tRequest, tCreate, tInsert, tAll, tBad, tSlow, tBlocking, tText

   TestSkipIfNot "database", pDriver
   if serverSetting(pDriver, "HOST") is empty then
      throw "SKIP no" && pDriver && "server: OXT_TEST_" & toUpper(pDriver) & "_HOST is not set"
   end if
   put serverArguments(pDriver) into tArguments

   put asyncDatabaseOpen(pDriver, tArguments, "opened") into tConnection
   TestAssert pDriver & ": a connection opens", isOpened(tConnection) and sOpened[tConnection]["error"] is empty
   TestDiagnostic pDriver & ": the opening's error, if any: " & sOpened[tConnection]["error"]
   put revOpenDatabase(pDriver, tArguments[1], tArguments[2], tArguments[3], tArguments[4], tArguments[5]) into tDatabaseID
   TestAssert pDriver & ": and revDB's own, to compare with", tDatabaseID is an integer

   put asyncDatabaseExecute(tConnection, "DROP TABLE IF EXISTS oxt_background", "answered") into tRequest
   TestAssert pDriver & ": a table is dropped", isAnswered(tRequest) and sAnswers[tRequest]["error"] is empty
   put asyncDatabaseExecute(tConnection, "CREATE TABLE oxt_background (id integer, name varchar(64), price decimal(6,2), note varchar(64))", "answered") into tCreate
   put "it's ;--" & quote & " not SQL" into tText
   put asyncDatabaseExecute(tConnection, "INSERT INTO oxt_background (id, name, price, note) VALUES (1, 'apple', 0.5, 'red'), (2, 'pear', 0.75, NULL), (3, :1, 1.25, '')", "answered", tText) into tInsert
   TestAssert pDriver & ": a table is made", isAnswered(tCreate) and sAnswers[tCreate]["error"] is empty
   TestAssert pDriver & ": rows are added, with a value", isAnswered(tInsert) and sAnswers[tInsert]["error"] is empty
   TestAssert pDriver & ": the result is the number of rows", sAnswers[tInsert]["result"] is 3

   put asyncDatabaseQuery(tConnection, "SELECT id, name, price, note FROM oxt_background ORDER BY id", "answered") into tAll
   TestAssert pDriver & ": the rows come", isAnswered(tAll) and sAnswers[tAll]["error"] is empty \
         and the number of elements of sAnswers[tAll]["result"] is 3
   TestAssert pDriver & ": with the columns' names", sAnswers[tAll]["columns"] is ("id" & return & "name" & return & "price" & return & "note")
   TestAssert pDriver & ": the value went in as text", sAnswers[tAll]["result"][3]["name"] is tText
   TestAssert pDriver & ": NULL has no key", "note" is not among the keys of sAnswers[tAll]["result"][2]
   TestAssert pDriver & ": each value is what revDB gives", \
         rowsAsText(sAnswers[tAll]["result"], sAnswers[tAll]["columns"]) is \
         revDataFromQuery(tab, return, tDatabaseID, "SELECT id, name, price, note FROM oxt_background ORDER BY id")

   put asyncDatabaseQuery(tConnection, "SELECT nothing FROM oxt_no_such_table", "answered") into tBad
   TestAssert pDriver & ": an error is the driver's", isAnswered(tBad) and sAnswers[tBad]["error"] is not empty
   TestDiagnostic pDriver & ": the error: " & sAnswers[tBad]["error"]

   -- A query the server takes a second over: the stack goes on meanwhile
   put 0 into sTicks
   send "countATick" to me in 10 milliseconds
   put the milliseconds into tBlocking
   put asyncDatabaseQuery(tConnection, pSleepSQL, "answered") into tSlow
   TestAssert pDriver & ": a slow query is answered", isAnswered(tSlow) and sAnswers[tSlow]["error"] is empty
   put the milliseconds - tBlocking into tBlocking
   TestAssert pDriver & ": and the stack's own messages came meanwhile", sTicks >= 10
   TestDiagnostic pDriver & ": the slow query took" && tBlocking && "ms, during which" && sTicks && "timer messages came"
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "countATick" then
         cancel item 1 of tMessage
      end if
   end repeat

   revExecuteSQL tDatabaseID, "DROP TABLE oxt_background"
   revCloseDatabase tDatabaseID
   asyncDatabaseClose tConnection
   TestAssert pDriver & ": the connection closes", the result is empty
end testServer

on TestMySQL
   testServer "mysql", "SELECT SLEEP(1) AS slept"
end TestMySQL

on TestPostgreSQL
   testServer "postgresql", "SELECT pg_sleep(1) AS slept"
end TestPostgreSQL
