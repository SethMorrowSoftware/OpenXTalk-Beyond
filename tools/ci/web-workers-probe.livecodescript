script "WorkersProbe"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- The stack of tools/ci/web_workers_check.py: a web standalone with the
-- Background Workers and Background Database libraries, whose script
-- starts web workers and calls their handlers one case after the other,
-- as a stack would. Each case writes a line to the page's console
-- (stdout):
--    PROBE <case> ok <what it saw>
--    PROBE <case> FAIL <what it saw>
--    PROBE <name> info <a measurement>
-- and the last line is "PROBE done <failures>". web_workers_check.py
-- checks that every case it expects said ok.

-- The busy case's count: primes up to kBusyLimit, which the worker takes
-- a second or more to count in a browser
constant kBusyLimit = 60000
constant kBusyPrimes = 6057

local sStart, sWorker, sSecond, sThird, sCase, sFailures
local sBytes, sProgress, sOutput, sTicks, sTicking, sBusyStart
local sParallel, sStopped, sPending, sQuitCall

on openStack
   send "probeBegin" to me in 100 milliseconds
end openStack

-- A case's line
private command say pName, pOk, pDetail
   local tLine
   if pOk is true then
      put "PROBE" && pName && "ok" && pDetail into tLine
   else
      put "PROBE" && pName && "FAIL" && pDetail into tLine
      add 1 to sFailures
   end if
   replace return with "\n" in tLine
   write tLine & return to stdout
end say

private command info pName, pDetail
   replace return with "\n" in pDetail
   write "PROBE" && pName && "info" && pDetail & return to stdout
end info

-- The script of the workers
private function workerScript
   local tScript
   put "function addUp pA, pB" & return after tScript
   put "   return pA + pB" & return after tScript
   put "end addUp" & return after tScript
   put "function echoBack pValue" & return after tScript
   put "   return pValue" & return after tScript
   put "end echoBack" & return after tScript
   put "function keysOf pArray" & return after tScript
   put "   local tKeys" & return after tScript
   put "   put the keys of pArray into tKeys" & return after tScript
   put "   sort lines of tKeys" & return after tScript
   put "   replace return with comma in tKeys" & return after tScript
   put "   return tKeys & comma & pArray[" & quote & "c" & quote & "][" & quote & "nested" & quote & "]" & return after tScript
   put "end keysOf" & return after tScript
   put "function makeArray pCount" & return after tScript
   put "   local tArray, i" & return after tScript
   put "   repeat with i = 1 to pCount" & return after tScript
   put "      put i * i into tArray[i]" & return after tScript
   put "   end repeat" & return after tScript
   put "   return tArray" & return after tScript
   put "end makeArray" & return after tScript
   put "function boom" & return after tScript
   put "   throw " & quote & "boom from the worker" & quote & return after tScript
   put "end boom" & return after tScript
   put "command withProgress" & return after tScript
   put "   workerSendProgress 50" & return after tScript
   put "   return " & quote & "progressed" & quote & return after tScript
   put "end withProgress" & return after tScript
   put "command speak" & return after tScript
   put "   put " & quote & "hello from the worker" & quote & return after tScript
   put "   return " & quote & "spoke" & quote & return after tScript
   put "end speak" & return after tScript
   put "function countPrimes pLimit" & return after tScript
   put "   local tCount, n, d, tPrime" & return after tScript
   put "   put 0 into tCount" & return after tScript
   put "   repeat with n = 2 to pLimit" & return after tScript
   put "      put true into tPrime" & return after tScript
   put "      repeat with d = 2 to trunc(sqrt(n))" & return after tScript
   put "         if n mod d is 0 then" & return after tScript
   put "            put false into tPrime" & return after tScript
   put "            exit repeat" & return after tScript
   put "         end if" & return after tScript
   put "      end repeat" & return after tScript
   put "      if tPrime then add 1 to tCount" & return after tScript
   put "   end repeat" & return after tScript
   put "   return tCount" & return after tScript
   put "end countPrimes" & return after tScript
   put "function whereAmI" & return after tScript
   put "   return the platform & " & quote & "|" & quote & " & the environment" & return after tScript
   put "end whereAmI" & return after tScript
   put "function ownFiles pPageFile" & return after tScript
   put "   put " & quote & "written in the worker" & quote & " into url " & quote & "file:/tmp/worker-file.txt" & quote & return after tScript
   put "   return url " & quote & "file:/tmp/worker-file.txt" & quote & " & " & quote & "|" & quote & " & (there is a file pPageFile)" & return after tScript
   put "end ownFiles" & return after tScript
   put "function waitAndReturn pMilliseconds" & return after tScript
   put "   local tStart" & return after tScript
   put "   put the milliseconds into tStart" & return after tScript
   put "   wait pMilliseconds milliseconds with messages" & return after tScript
   put "   return the milliseconds - tStart" & return after tScript
   put "end waitAndReturn" & return after tScript
   put "local sSent" & return after tScript
   put "function sentLater" & return after tScript
   put "   put empty into sSent" & return after tScript
   put "   send " & quote & "noteSent" & quote & " to me in 50 milliseconds" & return after tScript
   put "   wait until sSent is not empty with messages" & return after tScript
   put "   return sSent" & return after tScript
   put "end sentLater" & return after tScript
   put "on noteSent" & return after tScript
   put "   put " & quote & "sent" & quote & " into sSent" & return after tScript
   put "end noteSent" & return after tScript
   put "command quitNow" & return after tScript
   put "   quit" & return after tScript
   put "end quitNow" & return after tScript
   return tScript
end workerScript

on probeBegin
   put 0 into sFailures
   send "probeTimeout" to me in 150 seconds
   info "page", the platform & "|" & the environment
   put the milliseconds into sStart
   put workerStart(workerScript()) into sWorker
   say "start", sWorker is an integer, sWorker
   put "first-call" into sCase[workerCall(sWorker, "addUp", "probeAnswer", 2, 3)]
end probeBegin

on probeTick
   if sTicking is true then
      add 1 to sTicks
      send "probeTick" to me in 20 milliseconds
   end if
end probeTick

on workerProgress pCall, pValue
   put pValue into sProgress
end workerProgress

on workerOutput pWorker, pText
   if pWorker is sWorker then
      put pText after sOutput
   end if
end workerOutput

on workerStopped pWorker, pWhy, pErrors
   put pWhy into sStopped[pWorker]
   if pWorker is sSecond then
      say "stop", pWhy is "stopped", pWhy
      -- A worker whose script quits
      put "quit-call" into sCase[workerCall(sWorker, "quitNow", "probeAnswer")]
      put "after-quit" into sCase[workerCall(sWorker, "addUp", "probeAnswer", 1, 1)]
      put 2 into sQuitCall
   else if pWorker is sWorker then
      say "quit", pWhy is "exit", pWhy && pErrors
      send "probeScriptError" to me in 0 milliseconds
   end if
end workerStopped

on probeAnswer pCall, pResult, pError
   local tCase, tBytes, tArray, i, tMs
   put sCase[pCall] into tCase
   delete variable sCase[pCall]
   switch tCase
      case "first-call"
         say "first-call", pResult is 5 and pError is empty, pResult & "|" & pError
         info "first-call-ms", the milliseconds - sStart
         repeat with i = 0 to 255
            put numToByte(i) after tBytes
         end repeat
         put tBytes into sBytes
         put "binary" into sCase[workerCall(sWorker, "echoBack", "probeAnswer", tBytes)]
         break
      case "binary"
         say "binary", pResult is sBytes and the number of bytes of pResult is 256, the number of bytes of pResult && pError
         put "one" into tArray["a"]
         put "two" into tArray["b"]
         put "three" into tArray["c"]["nested"]
         put "array-in" into sCase[workerCall(sWorker, "keysOf", "probeAnswer", tArray)]
         break
      case "array-in"
         say "array-in", pResult is "a,b,c,three", pResult && pError
         put "array-out" into sCase[workerCall(sWorker, "makeArray", "probeAnswer", 4)]
         break
      case "array-out"
         say "array-out", pResult is an array and pResult[3] is 9 and the number of elements of pResult is 4, \
               the number of elements of pResult && pError
         put "error" into sCase[workerCall(sWorker, "boom", "probeAnswer")]
         break
      case "error"
         say "error", "boom from the worker" is in pError and pResult is empty, line 1 of pError
         put "no-handler" into sCase[workerCall(sWorker, "nothingHere", "probeAnswer")]
         break
      case "no-handler"
         say "no-handler", pError is "no such handler", pError
         put empty into sProgress
         put "progress" into sCase[workerCall(sWorker, "withProgress", "probeAnswer")]
         break
      case "progress"
         say "progress", sProgress is 50 and pResult is "progressed", sProgress & "|" & pResult && pError
         put empty into sOutput
         put "output" into sCase[workerCall(sWorker, "speak", "probeAnswer")]
         break
      case "output"
         say "output", sOutput is "hello from the worker" and pResult is "spoke", sOutput & "|" & pResult && pError
         put "where" into sCase[workerCall(sWorker, "whereAmI", "probeAnswer")]
         break
      case "where"
         set the itemDelimiter to "|"
         say "where", item 1 of pResult is "HTML5", pResult && pError
         put "on the page" into url "file:/tmp/page-file.txt"
         put "files" into sCase[workerCall(sWorker, "ownFiles", "probeAnswer", "/tmp/page-file.txt")]
         break
      case "files"
         say "files", pResult is "written in the worker|false", pResult && pError
         put "wait" into sCase[workerCall(sWorker, "waitAndReturn", "probeAnswer", 300)]
         break
      case "wait"
         say "wait", pResult is an integer and pResult >= 250 and pResult < 5000, pResult && pError
         put "send" into sCase[workerCall(sWorker, "sentLater", "probeAnswer")]
         break
      case "send"
         say "send", pResult is "sent", pResult && pError
         -- The page goes on while the worker counts
         put 0 into sTicks
         put true into sTicking
         send "probeTick" to me in 20 milliseconds
         put the milliseconds into sBusyStart
         put "busy" into sCase[workerCall(sWorker, "countPrimes", "probeAnswer", kBusyLimit)]
         break
      case "busy"
         put false into sTicking
         put the milliseconds - sBusyStart into tMs
         say "busy", pResult is kBusyPrimes and sTicks >= 5, \
               pResult && "primes in" && tMs && "ms, while the page's timer ran" && sTicks && "times"
         info "busy-ms", tMs
         -- Two workers at once
         put the milliseconds into sStart
         put workerStart(workerScript()) into sSecond
         put 0 into sParallel
         put "parallel-1" into sCase[workerCall(sWorker, "countPrimes", "probeAnswer", 2000)]
         put "parallel-2" into sCase[workerCall(sSecond, "countPrimes", "probeAnswer", 3000)]
         break
      case "parallel-1"
         say "parallel-1", pResult is 303, pResult && pError
         probeParallelDone
         break
      case "parallel-2"
         say "parallel-2", pResult is 430, pResult && pError
         info "second-worker-ms", the milliseconds - sStart
         probeParallelDone
         break
      case "stopped-call"
         say "stopped-call", pError is "worker stopped" and pResult is empty, pError
         break
      case "quit-call"
         say "quit-call", pError is "worker stopped", pResult && pError
         break
      case "after-quit"
         say "after-quit", pError is "worker stopped", pResult && pError
         break
      case "script-error"
         say "script-error", pError begins with "script error", line 1 of pError
         workerStop sThird
         send "probeDatabase" to me in 0 milliseconds
         break
      default
         say "unknown-answer", false, pCall && tCase && pResult && pError
         break
   end switch
end probeAnswer

private command probeParallelDone
   add 1 to sParallel
   if sParallel < 2 then
      exit probeParallelDone
   end if
   say "workers", sWorker is among the lines of workers() and sSecond is among the lines of workers(), \
         the number of lines of workers()
   -- Stopped: its call ends, and the worker says it stopped
   put "stopped-call" into sCase[workerCall(sSecond, "countPrimes", "probeAnswer", 10000000)]
   send "probeStop" to me in 300 milliseconds
end probeParallelDone

on probeStop
   workerStop sSecond
end probeStop

-- A script that does not compile: its calls end with the error
on probeScriptError
   put workerStart("function broken" & return & "   put (" & return & "end broken") into sThird
   put "script-error" into sCase[workerCall(sThird, "broken", "probeAnswer")]
end probeScriptError

-- The Background Database library cannot open a connection in a browser
on probeDatabase
   if "asyncDatabaseOpen" is not in the revAvailableHandlers of stack "com.livecode.library.asyncdatabase" then
      say "database", false, "the library is not loaded"
      probeEnd
      exit probeDatabase
   end if
   get asyncDatabaseOpen("sqlite", "/tmp/probe.sqlite", "probeDatabaseOpened")
end probeDatabase

on probeDatabaseOpened pConnection, pResult, pError
   say "database", pError is "worker failed: not supported", pError
   probeEnd
end probeDatabaseOpened

on probeTimeout
   say "timeout", false, "the cases that had not ended:" && the keys of sCase
   probeEnd
end probeTimeout

private command probeEnd
   local tMessage
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "probeTimeout" then
         cancel item 1 of tMessage
      end if
   end repeat
   write "PROBE done" && sFailures & return to stdout
end probeEnd
