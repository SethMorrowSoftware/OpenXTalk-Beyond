script "com.livecode.library.worker"
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

The stack is named com.livecode.library.worker, though LiveCode Ltd did not
write it, because the build names every script library's package
com.livecode.library.<file name> (extensions/extensions.gyp, and the tools
that read it), and the package must be named as its stack is.

HOW IT WORKS. The engine runs scripts on one thread, and nothing of a script
can be run on another: a handler that takes ten seconds stops the window for
ten seconds. What can run beside it is another engine. A worker is this same
engine started again as a process of its own, without a window ("-ui"), which
is given a script and then asked to call its handlers one after the other;
the stack that asked goes on, and is sent a message with each result.

This library is both halves. In the stack that starts workers it is an
ordinary library. In the process it starts it is the program: the engine
is started with the environment variable OXT_WORKER set, and either

 - with this file as the stack to run, when the engine is one that takes a
   stack on its command line (the IDE's engine, and a standalone engine with
   no application in it): the library is then the main stack and gets
   "startup"; or
 - with nothing, when the engine is a built application, which always opens
   its own stack: the application's startup script loads the libraries it
   was built with before its stack's "startup" is sent, this one puts itself
   among the front scripts when it finds OXT_WORKER set, and so gets
   "startup" first and never passes it. The application's own stack is never
   opened in that process.

Either way "startup" runs the worker (__workerMain) until its input ends,
and then quits.

The two talk through the worker's standard input and output, which the
Background Jobs library gives this one as a job (asyncProcessOpen). Each
thing said is an array (arrayEncode), in base64 so that no byte of it means
anything to a text stream:

 - to the worker: the count of base64 characters, a line feed, the base64
   and a line feed. The worker waits for its input, so it uses no
   processor while it has nothing to do, and reads the base64 in one piece.
   Where it can (Linux and macOS) it reads it as the file /dev/stdin, which
   the engine reads as fast as it comes. "read from stdin" is slower: when
   less has come than it was asked for, it waits a quarter of a second
   before it looks again, so a request of megabytes took many seconds. On
   Windows nothing else reads the input, so a request of more than
   kWorkerInlineLimit bytes is written to a file, in a folder of the
   worker's own, and the line "file " and the file's path in UTF-8 is sent
   in its place.
 - from the worker: a line feed, "OXT-WORKER ", the base64 and a line feed.
   Anything else the worker's script writes to its output ("put" with no
   window) is on other lines, and is passed on as it is (workerOutput).

On Linux the engine's output is held back when it is a pipe until there is
a lot of it, so the worker writes to /dev/stdout as a file there, which the
engine writes at once.
*/

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if

   -- A built application started again as a worker: this library is the
   -- program from here. It goes in front so that the application's own
   -- "startup" never runs.
   if __workerIsWorkerProcess() then
      insert the script of me into front
      exit extensionInitialize
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

Title: Background Workers

Summary: Runs a script's long handlers in another copy of the engine, while the stack goes on.

Author: OXT-Beyond contributors

Type: library

Version: 1.0.0

Description:

A handler that takes a long time stops the stack while it runs: the window
does not redraw, buttons do not answer, and no message is delivered. With
this library such handlers run in a **worker**, a second copy of the
engine with no window, while the stack goes on. The stack is sent a
message with each handler's result.

Start a worker with <workerStart>, giving it the script that holds the
handlers. Call one of them with <workerCall>, which returns at once; the
object that called is sent the message it named when the handler has
returned. Stop the worker with <workerStop>. A worker runs one call at a
time, in the order they were made; start more than one worker to do more
than one thing at once. (On Windows a worker with nothing to do looks for
its next call four times a second, so a call can start up to a quarter of
a second after it is made.)

A worker is another process. It shares nothing with the stack that
started it (no objects, no globals, no script local variables, no open
files). What its handlers need they are given as parameters, and what they
find out they return. Parameters and results can be text, numbers, binary
data and arrays, which are copied across. The worker's script is the only
script it has. The stack's own handlers, and libraries that were loaded
with `start using`, are not there unless the script loads them.

Three other messages may be sent to the object that started a worker or
made a call. Handle the ones that are wanted:

- `workerProgress pCall, pValue`: the handler being run called
  `workerSendProgress pValue`.
- `workerOutput pWorker, pText`: the worker's script used `put` with no
  destination, which in the stack would show `pText` in the message box.
  (A line the script writes to its standard output arrives the same way,
  though not always at once: on Linux the engine writes its output when
  enough has gathered.)
- `workerStopped pWorker, pWhy, pErrors`: the worker has ended. `pWhy` is
  "stopped" after <workerStop>, "exit" if the worker ended by itself, or
  "failed" if it could not be started. `pErrors` is what it last wrote to
  its error output, where the engine reports an error it could not send
  back.

Workers need the Background Jobs library, which starts their processes; a
standalone must include both. They are for the desktop: on Android and in
a browser no process can be started, so a worker started there ends at
once (`workerStopped` with "failed"), and the calls made to it before
that end with the error "worker failed: not supported". In a standalone
the worker is the application itself, started again without a window;
this library takes that process over before the application's own
`startup` handler runs, so it must be one of the application's
inclusions, not a stack loaded later.

Example:
local sWorker

on mouseUp
   if sWorker is empty then
      put workerStart(the script of button "Sums") into sWorker
   end if
   get workerCall(sWorker, "countPrimes", "primesCounted", 5000000)
   put "Counting..." into field "Status"
end mouseUp

on primesCounted pCall, pResult, pError
   if pError is not empty then
      put "Failed:" && pError into field "Status"
   else
      put pResult && "primes" into field "Status"
   end if
end primesCounted

Tags: Library, Worker

*/

-- The line a worker begins each thing it says with
constant kWorkerMarker = "OXT-WORKER "

-- How much of a worker's error output is kept for workerStopped
constant kWorkerErrorLimit = 4000

-- On Windows, the largest request (encoded with arrayEncode) that is sent
-- through a worker's input; a larger one is sent as a file (see above)
constant kWorkerInlineLimit = 32768

-- IN THE STACK THAT STARTS WORKERS
-- The workers that have not ended, by number (which is the number of the
-- Background Jobs job that runs the worker's process):
--   ["owner"]    the object that started it
--   ["buffer"]   what it has written that is not yet a whole line
--   ["errors"]   the end of what it has written to its error output
--   ["calls"]    the calls it has not answered, as the keys
--   ["stopping"] workerStop was called for it
--   ["folder"]   the folder for requests sent as files, once it has one
--   ["files"]    how many have been
local sWorkers
-- The largest request sent through a worker's input, or empty for no limit
-- (see kWorkerInlineLimit)
local sInlineLimit
-- The calls that have not been answered, by number: ["worker"], ["target"]
-- (the object to tell) and ["message"]
local sCalls
local sLastCall
-- What is to be sent to the stack's objects, each from a message of its own
-- (see __workerQueue), by number, and the first and last numbers in use
local sDeliveries
local sFirstDelivery
local sLastDelivery

-- IN A WORKER
local sIsWorker
-- The long id of the stack that has the script the worker was given
local sScriptStack
-- Why the script could not be used, if it could not
local sScriptError
-- The call being run
local sCurrentCall
-- The file the worker writes to instead of stdout, where it has to
local sReplyFile
-- The file the worker reads its input from instead of stdin, where it can
local sInputFile

--------------------------------------------------------------------------------
--
-- STARTING AND STOPPING
--

/**
Summary: Starts a worker: another engine, with no window, that runs the handlers of a script.

Syntax: workerStart(<pScript>)

Parameters:
pScript: The script whose handlers the worker is to run, as text: for example `the script of button "Sums"`, or the contents of a script file.

Returns: The number of the worker.

Description:
Use the <workerStart> function to start a worker for handlers that would
otherwise stop the stack while they run.

<workerStart> returns at once, while the worker is still starting. Calls
can be made straight away with <workerCall>: they wait in a queue until
the worker is ready. Starting a worker takes about as long as starting a
small application, so start it once and keep it, rather than one for each
call.

The script is the worker's own copy: changing the object it came from
later changes nothing in the worker. If the script does not compile, every
call ends with an error that says so.

The object whose script called <workerStart> is sent `workerStopped` when
the worker ends, and `workerOutput` for what the worker's script writes
to its output (see the library's description).

A worker cannot start workers of its own.

Example:
put workerStart(the script of stack "Number Crunching") into sWorker

Example:
-- a script kept in a file
put workerStart(url ("file:" & specialFolderPath("resources") & "/sums.livecodescript")) into sWorker

Tags: Library, Worker

References: workerCall (function), workerStop (command), workers (function)
*/
function workerStart pScript
   if __workerIsWorkerProcess() then
      throw "workerStart: a worker cannot start workers"
   end if

   local tOwner
   put __workerCaller() into tOwner

   -- The engine that is running, which the address names after the host
   local tEngine
   set the itemDelimiter to ":"
   put item 2 to -1 of the address into tEngine
   if tEngine is empty then
      -- (Nowhere a process can be started: the job fails, and says why)
      put the address into tEngine
   end if

   -- For an engine that takes a stack on its command line, this library is
   -- the stack. A built application takes no notice of it: there the
   -- library must have been built in, which gives it no file of its own
   -- (and a copy loaded from a file would leave the application's own
   -- "startup" to run in the worker, which would never answer).
   local tArguments, tLibrary
   put "-ui" into tArguments[1]
   put the effective filename of me into tLibrary
   if tLibrary is not empty and tLibrary is not tEngine and there is a file tLibrary then
      if the environment is "standalone application" then
         throw "workerStart: the Background Workers library must be one of the application's inclusions"
      end if
      put tLibrary into tArguments[2]
   end if

   -- The worker is told what it is by its environment, which it gets from
   -- this process as it is when the worker is started
   local tHide, tJob, tError
   put the hideConsoleWindows into tHide
   set the hideConsoleWindows to true
   put "1" into $OXT_WORKER
   try
      put asyncProcessOpen(tEngine, tArguments, "__workerEvent") into tJob
   catch tError
   end try
   put empty into $OXT_WORKER
   set the hideConsoleWindows to tHide
   if tError is not empty then
      throw tError
   end if

   put tOwner into sWorkers[tJob]["owner"]
   put empty into sWorkers[tJob]["buffer"]

   local tRequest
   put __workerScriptText(pScript) into tRequest["script"]
   __workerSay tJob, tRequest
   return tJob
end workerStart

/**
Summary: Stops a worker, and the call it is running.

Syntax: workerStop <pWorker>

Parameters:
pWorker: The number of the worker, as <workerStart> returned it.

Description:
Use the <workerStop> command to end a worker that is no longer needed, or
to stop a call that is taking too long: a call cannot be stopped by
itself, because the handler is running in another process, but its worker
can.

The worker's process is ended at once, with any process it started. Each
call it had not answered ends with the error "worker stopped", and the
object that started the worker is sent `workerStopped` with "stopped".

Workers that are still running when the application quits are stopped
then.

The result: Empty, or "no such worker".

Example:
workerStop sWorker
put empty into sWorker

Tags: Library, Worker

References: workerStart (function), workerCall (function)
*/
command workerStop pWorker
   if pWorker is empty or sWorkers[pWorker] is not an array then
      return "no such worker"
   end if
   put true into sWorkers[pWorker]["stopping"]
   -- Its last event tidies up after it (__workerEnded)
   asyncCancel pWorker
   return empty
end workerStop

/**
Summary: Lists the workers that are running.

Syntax: workers()

Returns: The numbers of the workers that have been started and have not ended, one to a line, oldest first.

Example:
repeat for each line tWorker in workers()
   workerStop tWorker
end repeat

Tags: Library, Worker

References: workerStart (function), workerStop (command), workerPending (function)
*/
function workers
   local tWorkers
   put the keys of sWorkers into tWorkers
   sort lines of tWorkers ascending numeric
   return tWorkers
end workers

/**
Summary: Returns how many calls a worker has not yet answered.

Syntax: workerPending(<pWorker>)

Parameters:
pWorker: The number of the worker.

Returns: The number of calls made to the worker with <workerCall> whose message has not been sent yet, counting the one being run. Empty if there is no such worker.

Example:
if workerPending(sWorker) is 0 then
   workerStop sWorker
end if

Tags: Library, Worker

References: workerCall (function), workers (function)
*/
function workerPending pWorker
   if pWorker is empty or sWorkers[pWorker] is not an array then
      return empty
   end if
   return the number of elements of sWorkers[pWorker]["calls"]
end workerPending

--------------------------------------------------------------------------------
--
-- CALLS
--

/**
Summary: Calls a handler of a worker's script, without waiting for it.

Syntax: workerCall(<pWorker>, <pHandler>, <pMessage> [, <pParameter>, ...])

Parameters:
pWorker: The number of the worker, as <workerStart> returned it.
pHandler: The name of the handler to call: a function or a command of the script the worker was started with.
pMessage: The name of the message to send to this object when the handler has returned.
pParameter: The handler's parameters, as many as it takes. Each can be text, a number, binary data or an array.

Returns: The number of the call.

Description:
Use the <workerCall> function to run a handler in a worker while the
stack goes on.

<workerCall> returns at once. When the handler has returned, the object
whose script called <workerCall> is sent <pMessage> with three parameters
(the number of the call, the handler's result, and an error).

- The result is what a function returned, or what a command returned
  with `return` (which a script that calls the command directly finds in
  `the result`). It can be text, a number, binary data or an array.
- The error is empty if the handler ran to its end. Otherwise it is what
  the handler threw, or the engine's error for the statement that failed,
  or one of: "no such handler" (the script has no handler of that name),
  a line beginning "script error" (the worker's script did not compile),
  "worker stopped" (the worker ended before it answered, whether
  <workerStop> was called or the process ended by itself), or a line
  beginning "worker failed" (the worker could not be started).

The message arrives as one sent `in 0 seconds` would: when the handlers
that are running have finished, or while one of them waits `with
messages`.

A worker runs one call at a time, in the order they were made. The
parameters are copied to the worker and the result is copied back, so a
change the handler makes to a parameter is not seen here.

While it runs, the handler can report how far it has got with
`workerSendProgress`. This object is then sent `workerProgress` with the
number of the call and the value.

Example:
get workerCall(sWorker, "thumbnailOf", "thumbnailMade", tImageData, 128)

on thumbnailMade pCall, pResult, pError
   if pError is empty then
      set the text of image "Thumbnail" to pResult
   end if
end thumbnailMade

Tags: Library, Worker

References: workerStart (function), workerStop (command), workerSendProgress (command), workerPending (function)
*/
function workerCall pWorker, pHandler, pMessage
   if pWorker is empty or sWorkers[pWorker] is not an array then
      throw "workerCall: no such worker"
   end if
   if not __workerIsName(pHandler) then
      throw "workerCall: not the name of a handler"
   end if
   if pMessage is empty then
      throw "workerCall: no message to send when the handler has returned"
   end if
   if sWorkers[pWorker]["stopping"] then
      throw "workerCall: the worker has been stopped"
   end if

   local tRequest
   add 1 to sLastCall
   put sLastCall into tRequest["id"]
   put pHandler into tRequest["handler"]
   put the paramCount - 3 into tRequest["count"]
   local i
   repeat with i = 4 to the paramCount
      put param(i) into tRequest["params"][i - 3]
   end repeat

   put pWorker into sCalls[sLastCall]["worker"]
   put __workerCaller() into sCalls[sLastCall]["target"]
   put pMessage into sCalls[sLastCall]["message"]
   put true into sWorkers[pWorker]["calls"][sLastCall]

   -- (If the process has just ended, its last event is on its way, and
   -- ends this call with the others)
   __workerSay pWorker, tRequest
   return sLastCall
end workerCall

/**
Summary: In a worker, reports the progress of the call being run.

Syntax: workerSendProgress <pValue>

Parameters:
pValue: What to report: text, a number, binary data or an array.

Description:
Use the <workerSendProgress> command in a handler that a worker runs, to
tell the stack how far it has got.

The object that made the call with <workerCall> is sent the message
`workerProgress pCall, pValue`, with the number of the call and the
value. Each report is copied to the stack, so report every so often, not
every time round a loop.

Outside a worker, and in a worker that is not running a call, the command
does nothing.

Example:
function countPrimes pLimit
   local tCount
   repeat with i = 2 to pLimit
      if isPrime(i) then add 1 to tCount
      if i mod 100000 is 0 then workerSendProgress round(100 * i / pLimit)
   end repeat
   return tCount
end countPrimes

Example:
-- in the stack
on workerProgress pCall, pPercent
   set the thumbPosition of scrollbar "Progress" to pPercent
end workerProgress

Tags: Library, Worker

References: workerCall (function)
*/
command workerSendProgress pValue
   if sIsWorker is not true or sCurrentCall is empty then
      exit workerSendProgress
   end if
   local tReply
   put sCurrentCall into tReply["id"]
   put true into tReply["progress"]
   put pValue into tReply["value"]
   __workerReply tReply
end workerSendProgress

--------------------------------------------------------------------------------
--
-- THE STACK'S SIDE
--

-- The object whose script called the library: the one to send messages to
private function __workerCaller
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
   -- (a handler of a behavior has the behavior's object as one more item)
   if not exists(tObject) then
      delete item -1 of tObject
   end if
   if tObject is empty or not exists(tObject) then
      return the long id of the target
   end if
   return tObject
end __workerCaller

private function __workerIsName pName
   return matchText(pName, "^[A-Za-z_][A-Za-z0-9_.]*$")
end __workerIsName

-- A script as a worker takes it: without the line that names a script-only
-- stack, which is not part of its script. The line is left empty, so that
-- the lines an error names are the lines of the file.
private function __workerScriptText pScript
   if word 1 of line 1 of pScript is "script" and char 1 of word 2 of line 1 of pScript is quote then
      put empty into line 1 of pScript
   end if
   return pScript
end __workerScriptText

-- An array as the base64 it is sent as, with no line breaks
private function __workerEncode pArray
   local tText
   put base64Encode(arrayEncode(pArray)) into tText
   replace return with empty in tText
   replace numToChar(13) with empty in tText
   return tText
end __workerEncode

-- Say something to a worker: the length, the base64, each with a line feed;
-- or where the worker's input is slow to read, a request that is large as
-- a file, and the line "file <path>"
private command __workerSay pWorker, pRequest
   local tData, tFile
   if sInlineLimit is empty and the platform is "Win32" then
      put kWorkerInlineLimit into sInlineLimit
   end if
   if sInlineLimit is not empty and sInlineLimit is not "none" then
      put arrayEncode(pRequest) into tData
      if the number of bytes of tData > sInlineLimit then
         put __workerRequestFile(pWorker) into tFile
      end if
   end if
   if tFile is not empty then
      put tData into url ("binfile:" & tFile)
      if the result is empty then
         asyncProcessWrite pWorker, "file " & textEncode(tFile, "UTF-8") & numToChar(10)
         exit __workerSay
      end if
      -- (If it cannot be written, the request goes the slow way)
      delete file tFile
   end if

   local tText
   if tData is not empty then
      put base64Encode(tData) into tText
      replace return with empty in tText
      replace numToChar(13) with empty in tText
   else
      put __workerEncode(pRequest) into tText
   end if
   asyncProcessWrite pWorker, the number of chars of tText & numToChar(10) & tText & numToChar(10)
end __workerSay

-- A new file for a request to a worker, in a folder of the worker's own
-- that only this user can read (it may hold anything a script passes);
-- empty if there cannot be one
private function __workerRequestFile pWorker
   local tFolder, tMask
   put sWorkers[pWorker]["folder"] into tFolder
   if tFolder is empty or there is not a folder tFolder then
      put specialFolderPath("temporary") into tFolder
      if tFolder is empty or there is not a folder tFolder then
         return empty
      end if
      put "/oxt-worker-" & the processID & "-" & pWorker & "-" & random(1000000000) after tFolder
      if the platform is not "Win32" then
         put the umask into tMask
         -- 63 is octal 077: none for the group or others
         set the umask to 63
      end if
      create folder tFolder
      if tMask is not empty then
         set the umask to tMask
      end if
      if there is not a folder tFolder then
         return empty
      end if
      put tFolder into sWorkers[pWorker]["folder"]
   end if
   add 1 to sWorkers[pWorker]["files"]
   return tFolder & "/" & sWorkers[pWorker]["files"]
end __workerRequestFile

-- A worker's folder, and the requests it had not read yet
private command __workerRemoveFolder pFolder
   if pFolder is empty or there is not a folder pFolder then
      exit __workerRemoveFolder
   end if
   local tFile
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & "/" & tFile)
   end repeat
   delete folder pFolder
end __workerRemoveFolder

-- For the library's tests: the largest request to send through a worker's
-- input (an integer), "none" for no limit, or empty for the platform's own
on __workerTestInlineLimit pLimit
   put pLimit into sInlineLimit
end __workerTestInlineLimit

-- An event of a worker's process, from the Background Jobs library
on __workerEvent pJob, pEvent, pData, pCode
   if sWorkers[pJob] is not an array then
      exit __workerEvent
   end if

   switch pEvent
      case "output"
         __workerHeard pJob, pData
         break
      case "error"
         put pData after sWorkers[pJob]["errors"]
         if the number of chars of sWorkers[pJob]["errors"] > kWorkerErrorLimit then
            put char -kWorkerErrorLimit to -1 of sWorkers[pJob]["errors"] into sWorkers[pJob]["errors"]
         end if
         break
      default
         __workerEnded pJob, pEvent, pData
         break
   end switch
end __workerEvent

-- What a worker has written: whole lines are taken, the rest waits
private command __workerHeard pWorker, pData
   local tLineFeed
   put numToChar(10) into tLineFeed

   put pData after sWorkers[pWorker]["buffer"]
   if tLineFeed is not in pData then
      exit __workerHeard
   end if

   -- Everything up to the last line feed is whole lines. What follows it
   -- in this piece is the start of the next.
   local tWhole, tTail
   set the lineDelimiter to tLineFeed
   if the last char of pData is tLineFeed then
      put 0 into tTail
   else
      put the number of chars of line -1 of pData into tTail
   end if
   put sWorkers[pWorker]["buffer"] into tWhole
   if tTail > 0 then
      put char -tTail to -1 of tWhole into sWorkers[pWorker]["buffer"]
      delete char -tTail to -1 of tWhole
   else
      put empty into sWorkers[pWorker]["buffer"]
   end if

   local tLine, tStart, tReply, tError
   repeat for each line tLine in tWhole
      if the last char of tLine is numToChar(13) then
         delete the last char of tLine
      end if
      if tLine is empty then
         next repeat
      end if

      put offset(kWorkerMarker, tLine) into tStart
      if tStart is 0 then
         __workerQueue sWorkers[pWorker]["owner"], "workerOutput", pWorker, tLine
         next repeat
      end if
      if tStart > 1 then
         __workerQueue sWorkers[pWorker]["owner"], "workerOutput", pWorker, char 1 to tStart - 1 of tLine
      end if

      put empty into tReply
      try
         put arrayDecode(base64Decode(char tStart + the number of chars of kWorkerMarker to -1 of tLine)) into tReply
      catch tError
      end try
      if tReply is an array then
         __workerAnswered pWorker, tReply
      end if
   end repeat
end __workerHeard

-- Something a worker said
private command __workerAnswered pWorker, pReply
   if pReply["output"] is true then
      __workerQueue sWorkers[pWorker]["owner"], "workerOutput", pWorker, pReply["value"]
      exit __workerAnswered
   end if

   local tCall
   put pReply["id"] into tCall
   if tCall is empty or sCalls[tCall] is not an array or sCalls[tCall]["worker"] is not pWorker then
      exit __workerAnswered
   end if

   if pReply["progress"] is true then
      __workerQueue sCalls[tCall]["target"], "workerProgress", tCall, pReply["value"]
      exit __workerAnswered
   end if

   local tTarget, tMessage
   put sCalls[tCall]["target"] into tTarget
   put sCalls[tCall]["message"] into tMessage
   delete variable sCalls[tCall]
   delete variable sWorkers[pWorker]["calls"][tCall]
   __workerQueue tTarget, tMessage, tCall, pReply["result"], pReply["error"]
end __workerAnswered

-- A worker's process has ended: every call it had not answered ends too
private command __workerEnded pWorker, pEvent, pData
   local tError, tWhy
   switch pEvent
      case "failed"
         put "worker failed:" && pData into tError
         put "failed" into tWhy
         break
      case "cancelled"
         put "worker stopped" into tError
         put "stopped" into tWhy
         break
      default
         put "worker stopped" into tError
         put "exit" into tWhy
         break
   end switch
   if sWorkers[pWorker]["stopping"] then
      put "stopped" into tWhy
   end if

   local tCalls, tCall
   put the keys of sWorkers[pWorker]["calls"] into tCalls
   sort lines of tCalls ascending numeric
   repeat for each line tCall in tCalls
      __workerQueue sCalls[tCall]["target"], sCalls[tCall]["message"], tCall, empty, tError
      delete variable sCalls[tCall]
   end repeat

   local tOwner, tErrors
   put sWorkers[pWorker]["owner"] into tOwner
   put sWorkers[pWorker]["errors"] into tErrors
   __workerRemoveFolder sWorkers[pWorker]["folder"]
   delete variable sWorkers[pWorker]
   __workerQueue tOwner, "workerStopped", pWorker, tWhy, tErrors
end __workerEnded

-- Send a message to one of the stack's objects, from a message of its own:
-- a handler of the stack's that fails, or that calls this library, then
-- does so with nothing of this library's half done. They are sent in the
-- order they were queued.
private command __workerQueue pTarget, pMessage, pFirst, pSecond, pThird
   if sLastDelivery is empty then
      put 0 into sLastDelivery
      put 1 into sFirstDelivery
   end if
   add 1 to sLastDelivery
   put pTarget into sDeliveries[sLastDelivery]["target"]
   put pMessage into sDeliveries[sLastDelivery]["message"]
   put pFirst into sDeliveries[sLastDelivery]["first"]
   put pSecond into sDeliveries[sLastDelivery]["second"]
   put pThird into sDeliveries[sLastDelivery]["third"]
   send "__workerDeliver" to me in 0 milliseconds
end __workerQueue

on __workerDeliver
   if sFirstDelivery is empty or sFirstDelivery > sLastDelivery then
      exit __workerDeliver
   end if

   local tDelivery
   put sDeliveries[sFirstDelivery] into tDelivery
   delete variable sDeliveries[sFirstDelivery]
   add 1 to sFirstDelivery

   -- An object that has been deleted has no messages coming
   if not exists(tDelivery["target"]) then
      exit __workerDeliver
   end if
   dispatch tDelivery["message"] to tDelivery["target"] with \
         tDelivery["first"], tDelivery["second"], tDelivery["third"]
end __workerDeliver

--------------------------------------------------------------------------------
--
-- THE WORKER'S SIDE
--

private function __workerIsWorkerProcess
   return sIsWorker is true or $OXT_WORKER is not empty
end __workerIsWorkerProcess

-- The first message of an engine. In a worker it is the whole run: as the
-- main stack of an engine started with this file, or from the front of a
-- built application's message path (see extensionInitialize).
on startup
   if not __workerIsWorkerProcess() then
      pass startup
   end if
   __workerMain
end startup

private command __workerMain
   local tFile, tLine, tLength, tText, tRequest, tError
   put true into sIsWorker
   -- What this process starts is not a worker: a program that the script
   -- runs gets the environment without the mark
   put empty into $OXT_WORKER

   -- The script the worker is given calls this library's handlers
   -- (workerSendProgress), so the library has to be in its message path
   if the long id of me is not among the lines of the frontScripts and \
         the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if

   -- The engine holds back what it writes to a pipe on Linux until there is
   -- a lot of it; a file is written at once
   if the platform is "Linux" then
      repeat for each item tFile in "/dev/stdout,/proc/self/fd/1"
         open file tFile for binary append
         if the result is empty then
            put tFile into sReplyFile
            exit repeat
         end if
      end repeat
   end if

   -- And it reads its input faster as a file (see the top of the script)
   if the platform is not "Win32" then
      repeat for each item tFile in "/dev/stdin,/proc/self/fd/0"
         open file tFile for binary read
         if the result is empty then
            put tFile into sInputFile
            exit repeat
         end if
      end repeat
   end if

   repeat forever
      -- The length, and then that many characters and a line feed; or a
      -- file
      put empty into tRequest
      if not __workerRead(empty, tLine) then
         -- The input has ended: the stack closed it, or has gone
         exit repeat
      end if
      if word 1 of tLine is "file" then
         put textDecode(char 6 to -1 of tLine, "UTF-8") into tFile
         if the last char of tFile is numToChar(10) then
            delete the last char of tFile
         end if
         try
            put arrayDecode(url ("binfile:" & tFile)) into tRequest
         catch tError
         end try
         delete file tFile
      else
         put word 1 of tLine into tLength
         if tLength is not an integer or tLength < 1 then
            next repeat
         end if
         if not __workerRead(tLength, tText) or not __workerRead(empty, tLine) then
            exit repeat
         end if
         try
            put arrayDecode(base64Decode(tText)) into tRequest
         catch tError
         end try
      end if

      if tRequest is an array then
         __workerDo tRequest
      end if
   end repeat

   quit 0
end __workerMain

-- Read pCount characters of the worker's input, or with no count a line.
-- False when the input has ended first.
private function __workerRead pCount, @rText
   local tResult
   if sInputFile is not empty then
      if pCount is empty then
         read from file sInputFile until linefeed
      else
         read from file sInputFile for pCount
      end if
   else
      if pCount is empty then
         read from stdin until linefeed
      else
         read from stdin for pCount
      end if
   end if
   -- (the result has to be taken at once)
   put the result into tResult
   put it into rText
   return tResult is empty
end __workerRead

-- Say something to the stack
private command __workerReply pReply
   local tText
   put numToChar(10) & kWorkerMarker & __workerEncode(pReply) & numToChar(10) into tText
   if sReplyFile is not empty then
      write tText to file sReplyFile
   else
      write tText to stdout
   end if
end __workerReply

-- "put" with no destination, in a worker's script. The engine asks the
-- object first with this message, and writes to its output only if nobody
-- takes it: here it is said to the stack like everything else, so it
-- arrives when it is put and not when the engine next empties its output.
on msgChanged pHandler, pLine
   if sIsWorker is not true then
      pass msgChanged
   end if
   local tReply
   put true into tReply["output"]
   put msg into tReply["value"]
   __workerReply tReply
end msgChanged

private command __workerDo pRequest
   if "script" is among the keys of pRequest then
      __workerLoad pRequest["script"]
   else if pRequest["handler"] is not empty then
      __workerRun pRequest
   end if
end __workerDo

-- Take the script whose handlers are to be run
private command __workerLoad pScript
   local tResult
   if sScriptStack is empty or not exists(sScriptStack) then
      create invisible stack "Worker Script"
      put it into sScriptStack
   end if
   set the script of sScriptStack to pScript
   put the result into tResult
   if tResult is not empty or the scriptStatus of sScriptStack is "error" then
      put "script error" & return & tResult into sScriptError
   else
      put empty into sScriptError
   end if
end __workerLoad

-- An error as the stack is told it. The engine's own has a line for each
-- place it passed through, the last of them in this library ("dispatch",
-- and the "do" it is in): those, and the line that names the stack the
-- script is kept in here, are no part of what went wrong in the script.
private function __workerErrorOf pError
   if pError is empty then
      return "error"
   end if
   if not matchText(line 1 of pError, "^[0-9]+,[0-9]+,[0-9]+") then
      return pError
   end if
   local tLast, tLine
   put 0 into tLast
   repeat with tLine = the number of lines of pError down to 1
      if line tLine of pError begins with "353," then
         put tLine into tLast
         exit repeat
      end if
   end repeat
   if tLast > 1 then
      return line 1 to tLast - 1 of pError
   end if
   return pError
end __workerErrorOf

-- Run a handler of the script and say what it returned
private command __workerRun pRequest
   local tReply
   put pRequest["id"] into tReply["id"]

   if sScriptError is not empty then
      put sScriptError into tReply["error"]
      __workerReply tReply
      exit __workerRun
   end if
   if sScriptStack is empty or not __workerIsName(pRequest["handler"]) then
      put "no such handler" into tReply["error"]
      __workerReply tReply
      exit __workerRun
   end if

   -- "with tParams[1],tParams[2]...": the parameters as the statement
   -- that passes them names them
   local tParams, tWith, i
   put pRequest["params"] into tParams
   repeat with i = 1 to pRequest["count"]
      if i is 1 then
         put " with tParams[1]" into tWith
      else
         put ",tParams[" & i & "]" after tWith
      end if
   end repeat

   -- A function first, and if the script has none of that name, a command
   local tHandled, tValue, tError, tKind
   put pRequest["id"] into sCurrentCall
   try
      set the defaultStack to the short name of sScriptStack
      repeat for each item tKind in "function,command"
         do "dispatch" && tKind && quote & pRequest["handler"] & quote && "to sScriptStack" & tWith
         put the result into tValue
         put it into tHandled
         if tHandled is not "unhandled" then
            exit repeat
         end if
      end repeat
      if tHandled is "unhandled" then
         put "no such handler" into tReply["error"]
      else
         put tValue into tReply["result"]
      end if
   catch tError
      put __workerErrorOf(tError) into tReply["error"]
   end try
   put empty into sCurrentCall

   __workerReply tReply
end __workerRun
