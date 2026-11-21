script "com.livecode.library.asyncdatabase"
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

The stack is named com.livecode.library.asyncdatabase, though LiveCode Ltd
did not write it, because the build names every script library's package
com.livecode.library.<file name> (extensions/extensions.gyp).

HOW IT WORKS. A database call of revDB (the revdb external) waits for the
database: a query that takes three seconds on a server stops the stack for
three seconds. Here each connection is held by a worker of the Background
Workers library (com.livecode.library.worker), another copy of the engine
with no window, which loads revdb and makes the same revDB calls there.
Its calls are this script's own handlers whose names begin with
"_asyncDatabaseWorker": the worker is started with this whole script, and
the rest of it is never called there. They are commands, whose return
value a worker sends back as it does a function's, so that the dictionary
(which lists every public function and command declared with "function"
or "command") leaves them out.

A request is a call of the worker (workerCall), answered to this stack,
which passes the answer on to the object that made the request. A worker
runs its calls one at a time, so the requests of one connection are
answered in the order they were made, as a database connection would run
them. Connections are separate workers and run at the same time.

What the worker gets back from revDB is passed on as it is: the same text
for each value as revDatabaseColumnNumbered would give the stack, and
revDB's own error text.
*/

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   insert the script of me into back
   if the environment contains "development" then
      set the _ideoverride of me to true
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   remove the script of me from back
end extensionFinalize

/**

Title: Background Database

Summary: Database queries that do not stop the stack while the database works.

Author: OXT-Beyond contributors

Type: library

Version: 1.0.0

Description:

A revDB call such as <revQueryDatabase> or <revExecuteSQL> waits for
the database. While a slow query runs on a server, or a large one in a
local file, the stack does not redraw, buttons do not answer and no
message is delivered. With this library the same work is done in the background, and
the stack is sent a message with the result.

Open a connection with <asyncDatabaseOpen>, giving the arguments that
<revOpenDatabase> takes. Make requests with <asyncDatabaseQuery> and
<asyncDatabaseExecute>, which return at once; the object that made a
request is sent the message it named when the database has answered. A
connection answers its requests one at a time, in the order they were
made, so requests can be made straight after <asyncDatabaseOpen> and one
after another without waiting. Open more than one connection to have
more than one request run at once. Close a connection with
<asyncDatabaseClose>.

The revDB calls of a script are not changed by this library, and a
connection of this library is not one of revDB's: its number works only
with the calls of this library.

Each connection is held by a worker of the Background Workers library, a
second copy of the engine with no window, which makes the revDB calls
there. Values come back as revDB gives them to a script, and errors with
revDB's text. Connections are for the desktop: on Android and in a browser
a connection cannot be opened (in a browser a worker has a file system of
its own, without the page's database files). A standalone must include the
Background Database, Background Workers and Background Jobs libraries, and
the Database external with the drivers it uses.

Example:
local sConnection

on openCard
   put asyncDatabaseOpen("sqlite", specialFolderPath("documents") & "/notes.sqlite", "databaseOpened") into sConnection
end openCard

on mouseUp
   get asyncDatabaseQuery(sConnection, "SELECT title, body FROM notes WHERE title LIKE :1", "notesFound", "%" & field "Search" & "%")
   put "Searching..." into field "Status"
end mouseUp

on notesFound pRequest, pRows, pError
   if pError is not empty then
      put "Failed:" && pError into field "Status"
      exit notesFound
   end if
   put empty into field "Titles"
   repeat with i = 1 to the number of elements of pRows
      put pRows[i]["title"] & return after field "Titles"
   end repeat
   put the number of elements of pRows && "notes" into field "Status"
end notesFound

on databaseOpened pConnection, pResult, pError
   if pError is not empty then
      answer "The notes could not be opened:" && pError
   end if
end databaseOpened

Tags: Library, Database

*/

-- The connections that are open, by number:
--   ["worker"]   the worker that holds it (empty in a browser, where
--                there is none)
--   ["owner"]    the object that opened it
--   ["message"]  the message to send it when the connection is open
--   ["requests"] the requests not yet answered, as the keys
local sConnections
local sLastConnection
-- The requests not yet answered, by number: ["connection"], ["call"],
-- ["target"], ["message"], ["kind"] (open, query, execute)
local sRequests
local sLastRequest
-- The request of each call of a worker, by the call's number
local sCallRequests
-- The last number of a call of no worker's (__asyncDatabaseNoCall)
local sLastNoCall
-- The messages waiting to be sent to the stack's objects (see
-- __asyncDatabaseSend), by number, and the first and last numbers in use
local sOutbox
local sFirstOut
local sLastOut

-- IN A WORKER
-- revDB's number of the connection this worker holds
local sDatabaseID
-- Why it could not be opened, if it could not
local sOpenError

--------------------------------------------------------------------------------
--
-- CONNECTIONS
--

/**
Summary: Opens a database connection in the background.

Syntax: asyncDatabaseOpen(<pType>, <pArguments>, <pMessage>)

Parameters:
pType: The type of database, as <revOpenDatabase> takes it: "sqlite", "mysql", "postgresql", "odbc" and so on.
pArguments: The other arguments of <revOpenDatabase>, in order: an array with the keys 1 to N, or text with one argument on each line. For SQLite, the file of the database.
pMessage: The name of the message to send to this object when the connection is open, or empty for none.

Returns: The number of the connection.

Description:
Use the <asyncDatabaseOpen> function to open a database connection whose
requests are run in the background.

<asyncDatabaseOpen> returns at once with the number of the connection,
which <asyncDatabaseQuery> and <asyncDatabaseExecute> can use at once.
Their requests wait until the connection is open, and are run in the
order they were made.

When the database has answered, the object whose script called
<asyncDatabaseOpen> is sent <pMessage> with three parameters: the number
of the connection, empty, and an error. The error is empty if the
connection is open. Otherwise it is what <revOpenDatabase> returned (for
example "revdberr,..." or the driver's message), or a line beginning
"worker failed" if no worker could be started; the connection is then
closed, and each request made to it ends with the same error.

Example:
put asyncDatabaseOpen("mysql", "db.example.com" & return & "shop" & return & "reader" & return & tPassword, "shopOpened") into sShop

Example:
local tArguments
put "db.example.com:5432" into tArguments[1]
put "shop" into tArguments[2]
put "reader" into tArguments[3]
put tPassword into tArguments[4]
put asyncDatabaseOpen("postgresql", tArguments, empty) into sShop

Tags: Library, Database

References: revOpenDatabase (function), asyncDatabaseQuery (function), asyncDatabaseExecute (function), asyncDatabaseClose (command)
*/
function asyncDatabaseOpen pType, pArguments, pMessage
   local tArguments, tOwner, tWorker, tConnection, tCall
   if pType is empty then
      throw "asyncDatabaseOpen: no type of database"
   end if
   if pArguments is an array then
      put pArguments into tArguments
   else
      local tLine, tIndex
      put 0 into tIndex
      repeat for each line tLine in pArguments
         add 1 to tIndex
         put tLine into tArguments[tIndex]
      end repeat
   end if
   put __asyncDatabaseCaller() into tOwner

   -- In a browser a worker is a web worker of the page, whose file system
   -- has none of the page's files: a database there would not be the
   -- page's. So no worker is started, and the connection ends as one
   -- whose worker could not be started does (as it did before workers
   -- could run in a browser).
   if the platform is "HTML5" then
      put empty into tWorker
   else
      put workerStart(the script of me) into tWorker
   end if

   add 1 to sLastConnection
   put sLastConnection into tConnection
   put tWorker into sConnections[tConnection]["worker"]
   put tOwner into sConnections[tConnection]["owner"]
   put pMessage into sConnections[tConnection]["message"]

   if tWorker is empty then
      put __asyncDatabaseNoCall() into tCall
      send "__asyncDatabaseNotSupported" && tConnection to me in 0 milliseconds
   else
      put workerCall(tWorker, "_asyncDatabaseWorkerOpen", "__asyncDatabaseAnswered", \
            __asyncDatabaseExternal(), __asyncDatabaseDriverPath(), pType, tArguments) into tCall
   end if
   get __asyncDatabaseRequest(tConnection, tCall, "open", tOwner, pMessage)
   return tConnection
end asyncDatabaseOpen

/**
Summary: Closes a connection that <asyncDatabaseOpen> opened.

Syntax: asyncDatabaseClose <pConnection>

Parameters:
pConnection: The number of the connection.

Description:
Use the <asyncDatabaseClose> command to close a connection that is no
longer needed, or to stop a request that is taking too long.

The connection is closed at once, with the request it is running: the
database sees the connection end, as when a program that held it ends,
and a transaction that was not committed is not. Each request not yet
answered ends with the error "connection closed".

To close a connection when its requests have been answered, call
<asyncDatabaseClose> from the message of the last of them.

The result: Empty, or "no such connection".

Example:
asyncDatabaseClose sShop
put empty into sShop

Tags: Library, Database

References: asyncDatabaseOpen (function), asyncDatabases (function)
*/
command asyncDatabaseClose pConnection
   if pConnection is empty or sConnections[pConnection] is not an array then
      return "no such connection"
   end if
   __asyncDatabaseEnd pConnection, "connection closed"
   return empty
end asyncDatabaseClose

/**
Summary: Lists the connections that <asyncDatabaseOpen> opened and that have not been closed.

Syntax: asyncDatabases()

Returns: The numbers of the connections, one to a line, oldest first.

Example:
repeat for each line tConnection in asyncDatabases()
   asyncDatabaseClose tConnection
end repeat

Tags: Library, Database

References: asyncDatabaseOpen (function), asyncDatabaseClose (command)
*/
function asyncDatabases
   local tConnections
   put the keys of sConnections into tConnections
   sort lines of tConnections ascending numeric
   return tConnections
end asyncDatabases

--------------------------------------------------------------------------------
--
-- REQUESTS
--

/**
Summary: Runs a query in the background, and sends its rows in a message.

Syntax: asyncDatabaseQuery(<pConnection>, <pSQL>, <pMessage> [, <pValue>, ...])

Parameters:
pConnection: The number of the connection, as <asyncDatabaseOpen> returned it.
pSQL: The query, as <revQueryDatabase> takes it, with :1, :2 and so on where values are to go.
pMessage: The name of the message to send to this object with the rows.
pValue: The values for :1, :2 and so on, one parameter each; or one array of them, with the keys 1 to N, as <revQueryDatabase> takes an array (a key "*b" and a number marks binary data).

Returns: The number of the request.

Description:
Use the <asyncDatabaseQuery> function to run a SELECT, or any other
statement that returns rows, without the stack waiting for it.

<asyncDatabaseQuery> returns at once. When the rows have come, the object
whose script called it is sent <pMessage> with four parameters:

- the number of the request;
- the rows: an array with the keys 1 to N, one for each row in order,
  each an array of the row's values keyed by the names of the columns.
  A value is the text or data that <revDatabaseColumnNumbered> gives. A
  NULL value has no key, so that it can be told from empty text:
  `"total" is not among the keys of pRows[1]`;
- an error, empty if the query ran. Otherwise it is revDB's error for the
  query (as <revQueryDatabase> would return it), "connection closed",
  the error of a connection that could not be opened, or "worker stopped"
  if the worker that held the connection ended (the connection is then
  closed);
- the names of the columns, one to a line, in their order in the query.

Two columns of a row with the same name are one key, and the later
column's value is kept: give them names of their own with AS.

The values are given to the database in the background as
<revQueryDatabase> gives them: `:1` takes the first value as text,
and in an array, the key `*b1` instead of `1` takes binary data.

All the rows are sent at once, so a query of a million rows makes a
large array: ask for the rows that are needed, with WHERE and LIMIT.

Example:
get asyncDatabaseQuery(sShop, "SELECT id, name, price FROM products WHERE price < :1 ORDER BY name", "productsFound", 20)

on productsFound pRequest, pRows, pError, pColumns
   if pError is not empty then
      answer pError
      exit productsFound
   end if
   repeat with i = 1 to the number of elements of pRows
      put pRows[i]["name"] & tab & pRows[i]["price"] & return after tList
   end repeat
   put tList into field "Products"
end productsFound

Tags: Library, Database

References: revQueryDatabase (function), asyncDatabaseExecute (function), asyncDatabaseOpen (function), revDatabaseColumnNumbered (function)
*/
function asyncDatabaseQuery pConnection, pSQL, pMessage
   local tValues, i
   put __asyncDatabaseValues(the paramCount, param(4), 4) into tValues
   if the paramCount > 4 then
      repeat with i = 5 to the paramCount
         put param(i) into tValues[i - 3]
      end repeat
   end if
   return __asyncDatabaseCall("asyncDatabaseQuery", pConnection, pSQL, pMessage, "query", tValues)
end asyncDatabaseQuery

/**
Summary: Runs a statement that changes the database in the background, and sends a message when it is done.

Syntax: asyncDatabaseExecute(<pConnection>, <pSQL>, <pMessage> [, <pValue>, ...])

Parameters:
pConnection: The number of the connection, as <asyncDatabaseOpen> returned it.
pSQL: The statement, as <revExecuteSQL> takes it, with :1, :2 and so on where values are to go.
pMessage: The name of the message to send to this object when the statement has run.
pValue: The values for :1, :2 and so on, one parameter each; or one array of them, with the keys 1 to N, as <revExecuteSQL> takes an array (a key "*b" and a number marks binary data).

Returns: The number of the request.

Description:
Use the <asyncDatabaseExecute> function to run an INSERT, UPDATE,
DELETE, CREATE or any other statement that returns no rows, without the
stack waiting for it.

<asyncDatabaseExecute> returns at once. When the statement has run, the
object whose script called it is sent <pMessage> with three parameters:
the number of the request, what <revExecuteSQL> puts into the result
(for most databases, the number of rows the statement changed), and an
error, which is empty if the statement ran and otherwise is revDB's
error, "connection closed", the error of a connection that could not be
opened, or "worker stopped" if the worker that held the connection ended
(the connection is then closed).

A transaction is statements of one connection: "BEGIN", the statements,
and "COMMIT" or "ROLLBACK", each a request of its own (the requests of a
connection run in the order they were made).

Example:
get asyncDatabaseExecute(sShop, "UPDATE products SET price = :1 WHERE id = :2", "priceChanged", tPrice, tID)

Example:
local tValues
put tName into tValues[1]
put tPhotoData into tValues["*b2"]
get asyncDatabaseExecute(sShop, "INSERT INTO photos (name, data) VALUES (:1, :2)", "photoAdded", tValues)

Tags: Library, Database

References: revExecuteSQL (command), asyncDatabaseQuery (function), asyncDatabaseOpen (function)
*/
function asyncDatabaseExecute pConnection, pSQL, pMessage
   local tValues, i
   put __asyncDatabaseValues(the paramCount, param(4), 4) into tValues
   if the paramCount > 4 then
      repeat with i = 5 to the paramCount
         put param(i) into tValues[i - 3]
      end repeat
   end if
   return __asyncDatabaseCall("asyncDatabaseExecute", pConnection, pSQL, pMessage, "execute", tValues)
end asyncDatabaseExecute

--------------------------------------------------------------------------------
--
-- THE STACK'S SIDE
--

-- The object whose script called the library
private function __asyncDatabaseCaller
   local tLine, tObject
   put -1 into tLine
   repeat while item 1 to -3 of line tLine of the executionContexts is the long id of me \
         or item 1 to -4 of line tLine of the executionContexts is the long id of me
      subtract 1 from tLine
      if line tLine of the executionContexts is empty then
         exit repeat
      end if
   end repeat
   put item 1 to -3 of line tLine of the executionContexts into tObject
   if not exists(tObject) then
      delete item -1 of tObject
   end if
   if tObject is empty or not exists(tObject) then
      return the long id of the target
   end if
   return tObject
end __asyncDatabaseCaller

-- The values of a request: the fourth parameter if it is an array and the
-- only one, otherwise the parameters from the fourth on (the caller adds
-- the ones after the fourth)
private function __asyncDatabaseValues pCount, pFirst, pFrom
   local tValues
   if pCount < pFrom then
      return empty
   end if
   if pCount is pFrom and pFirst is an array then
      return pFirst
   end if
   put pFirst into tValues[1]
   return tValues
end __asyncDatabaseValues

private function __asyncDatabaseCall pName, pConnection, pSQL, pMessage, pKind, pValues
   local tOwner, tCall
   if pConnection is empty or sConnections[pConnection] is not an array then
      throw pName & ": no such connection"
   end if
   if pMessage is empty then
      throw pName & ": no message to send when the database has answered"
   end if
   put __asyncDatabaseCaller() into tOwner
   if sConnections[pConnection]["worker"] is empty then
      -- (a connection in a browser, which ends with its requests)
      put __asyncDatabaseNoCall() into tCall
   else if pKind is "query" then
      put workerCall(sConnections[pConnection]["worker"], "_asyncDatabaseWorkerQuery", \
            "__asyncDatabaseAnswered", pSQL, pValues) into tCall
   else
      put workerCall(sConnections[pConnection]["worker"], "_asyncDatabaseWorkerExecute", \
            "__asyncDatabaseAnswered", pSQL, pValues) into tCall
   end if
   return __asyncDatabaseRequest(pConnection, tCall, pKind, tOwner, pMessage)
end __asyncDatabaseCall

private function __asyncDatabaseRequest pConnection, pCall, pKind, pOwner, pMessage
   add 1 to sLastRequest
   put pConnection into sRequests[sLastRequest]["connection"]
   put pCall into sRequests[sLastRequest]["call"]
   put pKind into sRequests[sLastRequest]["kind"]
   put pOwner into sRequests[sLastRequest]["target"]
   put pMessage into sRequests[sLastRequest]["message"]
   put true into sConnections[pConnection]["requests"][sLastRequest]
   put sLastRequest into sCallRequests[pCall]
   return sLastRequest
end __asyncDatabaseRequest

-- For a connection with no worker, a call of no worker's: its request is
-- ended with the connection's (__asyncDatabaseNotSupported)
private function __asyncDatabaseNoCall
   add 1 to sLastNoCall
   return "none" & sLastNoCall
end __asyncDatabaseNoCall

-- A connection opened where no worker can be started (in a browser) ends,
-- and each of its requests with it, as when its worker could not be
-- started
on __asyncDatabaseNotSupported pConnection
   if pConnection is not empty and sConnections[pConnection] is an array then
      __asyncDatabaseEnd pConnection, "worker failed: not supported"
   end if
end __asyncDatabaseNotSupported

-- A worker has answered a call
on __asyncDatabaseAnswered pCall, pResult, pError
   local tRequest, tConnection
   put sCallRequests[pCall] into tRequest
   delete variable sCallRequests[pCall]
   if tRequest is empty or sRequests[tRequest] is not an array then
      exit __asyncDatabaseAnswered
   end if
   put sRequests[tRequest]["connection"] into tConnection

   -- A worker's own failure is the connection's end (the Background
   -- Workers library's errors, which no driver gives)
   if pError is "worker stopped" or pError begins with "worker failed:" then
      if sConnections[tConnection] is an array then
         __asyncDatabaseEnd tConnection, pError
      end if
      exit __asyncDatabaseAnswered
   end if

   local tRequestA
   put sRequests[tRequest] into tRequestA
   delete variable sRequests[tRequest]
   delete variable sConnections[tConnection]["requests"][tRequest]

   switch tRequestA["kind"]
      case "open"
         if pError is not empty then
            -- The requests made since fail with the connection
            __asyncDatabaseEnd tConnection, pError
         end if
         if tRequestA["message"] is not empty then
            __asyncDatabaseSend tRequestA["target"], tRequestA["message"], tConnection, empty, pError
         end if
         break
      case "query"
         __asyncDatabaseSend tRequestA["target"], tRequestA["message"], tRequest, \
               pResult["rows"], pError, pResult["columns"]
         break
      default
         __asyncDatabaseSend tRequestA["target"], tRequestA["message"], tRequest, pResult, pError
         break
   end switch
end __asyncDatabaseAnswered

-- A worker of this library's has ended, with no request of its connection
-- to say so (one that has them ends it in __asyncDatabaseAnswered). The
-- message comes to this stack; one of a worker of a script's own that the
-- script did not handle passes through here, and goes on.
on workerStopped pWorker, pWhy, pErrors
   local tConnection
   if the target is not me then
      pass workerStopped
   end if
   repeat for each key tConnection in sConnections
      if sConnections[tConnection]["worker"] is pWorker then
         __asyncDatabaseEnd tConnection, "connection closed"
         exit repeat
      end if
   end repeat
end workerStopped

-- A connection's end: its worker is stopped, and each request not yet
-- answered ends with pError
private command __asyncDatabaseEnd pConnection, pError
   local tRequests, tRequest, tRequestA
   put the keys of sConnections[pConnection]["requests"] into tRequests
   sort lines of tRequests ascending numeric
   workerStop sConnections[pConnection]["worker"]
   delete variable sConnections[pConnection]
   repeat for each line tRequest in tRequests
      put sRequests[tRequest] into tRequestA
      delete variable sRequests[tRequest]
      delete variable sCallRequests[tRequestA["call"]]
      if tRequestA["kind"] is "open" then
         if tRequestA["message"] is not empty then
            __asyncDatabaseSend tRequestA["target"], tRequestA["message"], pConnection, empty, pError
         end if
      else if tRequestA["kind"] is "query" then
         __asyncDatabaseSend tRequestA["target"], tRequestA["message"], tRequest, empty, pError, empty
      else
         __asyncDatabaseSend tRequestA["target"], tRequestA["message"], tRequest, empty, pError
      end if
   end repeat
end __asyncDatabaseEnd

-- A message to one of the stack's objects, from a message of its own, so
-- that a handler of the stack that fails or calls this library does so
-- with nothing of this library's half done
private command __asyncDatabaseSend pTarget, pMessage, pFirst, pSecond, pThird, pFourth
   if sLastOut is empty then
      put 0 into sLastOut
      put 1 into sFirstOut
   end if
   add 1 to sLastOut
   put pTarget into sOutbox[sLastOut]["target"]
   put pMessage into sOutbox[sLastOut]["message"]
   put pFirst into sOutbox[sLastOut]["first"]
   put pSecond into sOutbox[sLastOut]["second"]
   put pThird into sOutbox[sLastOut]["third"]
   put pFourth into sOutbox[sLastOut]["fourth"]
   put the paramCount - 2 into sOutbox[sLastOut]["count"]
   send "__asyncDatabaseDeliver" to me in 0 milliseconds
end __asyncDatabaseSend

on __asyncDatabaseDeliver
   local tOut
   if sFirstOut is empty or sFirstOut > sLastOut then
      exit __asyncDatabaseDeliver
   end if
   put sOutbox[sFirstOut] into tOut
   delete variable sOutbox[sFirstOut]
   add 1 to sFirstOut
   if not exists(tOut["target"]) then
      exit __asyncDatabaseDeliver
   end if
   if tOut["count"] is 4 then
      dispatch tOut["message"] to tOut["target"] with \
            tOut["first"], tOut["second"], tOut["third"], tOut["fourth"]
   else
      dispatch tOut["message"] to tOut["target"] with \
            tOut["first"], tOut["second"], tOut["third"]
   end if
end __asyncDatabaseDeliver

-- The revdb external this process loaded, for a worker that is not this
-- application started again (which loads its own): a line of the
-- externals of an open stack
private function __asyncDatabaseExternal
   local tStack, tLine
   repeat for each line tStack in the mainStacks
      repeat for each line tLine in the externals of stack tStack
         set the itemDelimiter to "/"
         if item -1 of tLine begins with "revdb." then
            return tLine
         end if
      end repeat
   end repeat
   return empty
end __asyncDatabaseExternal

-- Where this process's revDB looks for its drivers, if it is loaded and
-- one was set: empty if none was (revdb then looks beside the application,
-- as it will in a worker that is the application started again)
private function __asyncDatabaseDriverPath
   local tPath, tError
   try
      put revGetDatabaseDriverPath() into tPath
   catch tError
      put empty into tPath
   end try
   return tPath
end __asyncDatabaseDriverPath

--------------------------------------------------------------------------------
--
-- IN A WORKER
--

-- Whether revdb is loaded here. (Asked with revdb_version, which needs
-- nothing set: until this library came, revGetDatabaseDriverPath ended
-- the engine when no driver path had been set.)
private function __asyncDatabaseHasRevDB
   local tError
   try
      get revdb_version()
   catch tError
      return false
   end try
   return true
end __asyncDatabaseHasRevDB

on _asyncDatabaseWorkerOpen pExternal, pDriverPath, pType, pArguments
   local tCall, tResult, tStack, i
   if not __asyncDatabaseHasRevDB() and pExternal is not empty then
      set the externals of the templateStack to pExternal
      create invisible stack "Background Database External"
      put it into tStack
      start using tStack
      reset the templateStack
   end if
   if not __asyncDatabaseHasRevDB() then
      put "the database external (revdb) is not available" into sOpenError
      throw sOpenError
   end if
   if pDriverPath is not empty then
      revSetDatabaseDriverPath pDriverPath
   end if

   -- revOpenDatabase(pType, pArguments[1], ...), with as many as there are
   put "put revOpenDatabase(pType" into tCall
   repeat with i = 1 to the number of elements of pArguments
      put ", pArguments[" & i & "]" after tCall
   end repeat
   put ") into tResult" after tCall
   do tCall
   if tResult is not an integer then
      put tResult into sOpenError
      if sOpenError is empty then
         put "the database could not be opened" into sOpenError
      end if
      throw sOpenError
   end if
   put tResult into sDatabaseID
   return empty
end _asyncDatabaseWorkerOpen

on _asyncDatabaseWorkerQuery pSQL, pValues
   local tCursor, tCount, tNames, tRows, tRow, tValue, tResult, i
   if sDatabaseID is empty then
      throw __asyncDatabaseNotOpen()
   end if
   if pValues is an array then
      put revQueryDatabase(sDatabaseID, pSQL, "pValues") into tCursor
   else
      put revQueryDatabase(sDatabaseID, pSQL) into tCursor
   end if
   if tCursor is not an integer then
      throw tCursor
   end if

   put revDatabaseColumnCount(tCursor) into tCount
   put revDatabaseColumnNames(tCursor) into tNames
   put 0 into tRow
   if not revQueryIsAtEnd(tCursor) then
      repeat
         add 1 to tRow
         repeat with i = 1 to tCount
            if revDatabaseColumnIsNull(tCursor, i) is not true then
               get revDatabaseColumnNumbered(tCursor, i, "tValue")
               put tValue into tRows[tRow][item i of tNames]
            end if
         end repeat
         if tRows[tRow] is empty then
            -- (a row whose every value is NULL is still a row)
            put empty into tRows[tRow]
         end if
         revMoveToNextRecord tCursor
         if the result is not true then
            exit repeat
         end if
      end repeat
   end if
   revCloseCursor tCursor

   replace comma with return in tNames
   put tRows into tResult["rows"]
   put tNames into tResult["columns"]
   return tResult
end _asyncDatabaseWorkerQuery

on _asyncDatabaseWorkerExecute pSQL, pValues
   local tResult
   if sDatabaseID is empty then
      throw __asyncDatabaseNotOpen()
   end if
   if pValues is an array then
      revExecuteSQL sDatabaseID, pSQL, "pValues"
   else
      revExecuteSQL sDatabaseID, pSQL
   end if
   put the result into tResult
   if tResult is not empty and tResult is not an integer then
      throw tResult
   end if
   return tResult
end _asyncDatabaseWorkerExecute

private function __asyncDatabaseNotOpen
   if sOpenError is not empty then
      return sOpenError
   end if
   return "the connection is not open"
end __asyncDatabaseNotOpen
