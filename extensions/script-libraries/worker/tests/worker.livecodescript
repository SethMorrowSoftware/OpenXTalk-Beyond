script "TestWorkerLibrary"
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

-- The Background Workers library (com.livecode.library.worker) as a script
-- uses it: a worker is this engine started again without a window, which
-- runs the handlers of a script it is given while this stack goes on.
--
-- The script the workers of these tests are given is this file's own: the
-- handlers below whose names begin with "w" are the ones they run. (The
-- rest of the file is in the worker too, and is never called there.)
--
-- Every wait here is "with messages", since that is where an answer
-- arrives, and ends as soon as it has come: the time limits are for a
-- build that is broken, not a measure.

-- What came back for each call: ["times"], ["result"], ["error"],
-- ["parameters"], and ["order"], its place among everything that arrived
local sAnswers
-- The progress reports of each call, in the order they came
local sProgress
-- What each worker put, in the order it came
local sOutput
-- How each worker ended: ["times"], ["why"], ["errors"]
local sStopped
-- A count of everything that has arrived
local sArrived
-- A count kept by a timer of this stack's
local sTicks

constant kWaitSeconds = 60

on TestSetup
   -- Another engine is started as a process, which is the desktop's to do
   TestSkipIfNot "desktop"
   TestSkipIfNot "extension", "org.openxtalk.library.async"
   TestLoadExtension "org.openxtalk.library.async"

   local tLibFilename
   put TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/worker/worker.livecodescript" \
         into tLibFilename
   start using stack tLibFilename

   put empty into sAnswers
   put empty into sProgress
   put empty into sOutput
   put empty into sStopped
   put 0 into sArrived
   put 0 into sTicks
end TestSetup

on TestTearDown
   -- (workers is the library's: not there if it could not be loaded)
   local tWorkers
   try
      put workers() into tWorkers
   catch tError
   end try
   repeat for each line tWorker in tWorkers
      workerStop tWorker
   end repeat
end TestTearDown

----------------------------------------------------------------
-- The handlers the workers run
----------------------------------------------------------------

local sCalledTimes
global gWorkerTestGlobal

function wAddUp pA, pB
   return pA + pB
end wAddUp

command wShout pText
   return toUpper(pText)
end wShout

command wSayNothing pText
   get toUpper(pText)
end wSayNothing

function wEcho pValue
   return pValue
end wEcho

function wCountOf
   return the paramCount
end wCountOf

function wJoin pOne, pTwo, pThree, pFour, pFive, pSix, pSeven, pEight, pNine, pTen
   return pOne & pTwo & pThree & pFour & pFive & pSix & pSeven & pEight & pNine & pTen
end wJoin

-- What the array has, with one thing more
function wAddAKey pArray
   put the number of elements of pArray into pArray["count"]
   return pArray
end wAddAKey

function wLengthOf pData
   return the number of bytes of pData
end wLengthOf

-- When it began and when it ended, by the clock both processes read
function wSleep pMilliseconds
   local tStart
   put the milliseconds into tStart
   wait pMilliseconds milliseconds
   return tStart & comma & the milliseconds
end wSleep

-- Work that does not end by itself (but does, in a minute, if nothing
-- stops the worker)
command wBusy
   local tEnd
   put the milliseconds + 60000 into tEnd
   repeat until the milliseconds > tEnd
   end repeat
   return "never stopped"
end wBusy

function wThrow pText
   throw pText
end wThrow

function wDivide pBy
   return 1 / pBy
end wDivide

private function wHidden
   return "hidden"
end wHidden

function wCalledTimes
   add 1 to sCalledTimes
   return sCalledTimes
end wCalledTimes

function wGlobal
   return gWorkerTestGlobal
end wGlobal

function wReport pTimes
   repeat with i = 1 to pTimes
      workerSendProgress "step" && i
   end repeat
   return "reported"
end wReport

function wReportAnArray
   local tArray
   put 40 into tArray["percent"]
   put "half way" into tArray["text"]
   workerSendProgress tArray
   return "reported"
end wReportAnArray

function wPut pText
   put pText
   return "put"
end wPut

command wQuit
   quit 3
end wQuit

function wStartAWorker
   local tError
   try
      get workerStart("function f" & return & "return 1" & return & "end f")
   catch tError
      return tError
   end try
   return "started" && it
end wStartAWorker

function wWhatAmI
   return the environment & return & the number of lines of the openStacks & return & ($OXT_WORKER is empty)
end wWhatAmI

----------------------------------------------------------------
-- The messages
----------------------------------------------------------------

on answered pCall, pResult, pError
   add 1 to sArrived
   add 1 to sAnswers[pCall]["times"]
   put the paramCount into sAnswers[pCall]["parameters"]
   put pResult into sAnswers[pCall]["result"]
   put pError into sAnswers[pCall]["error"]
   put sArrived into sAnswers[pCall]["order"]
end answered

on workerProgress pCall, pValue
   add 1 to sArrived
   local tIndex
   put the number of elements of sProgress[pCall] + 1 into tIndex
   put pValue into sProgress[pCall][tIndex]["value"]
   put sArrived into sProgress[pCall][tIndex]["order"]
end workerProgress

on workerOutput pWorker, pText
   add 1 to sArrived
   local tIndex
   put the number of elements of sOutput[pWorker] + 1 into tIndex
   put pText into sOutput[pWorker][tIndex]["text"]
   put sArrived into sOutput[pWorker][tIndex]["order"]
end workerOutput

on workerStopped pWorker, pWhy, pErrors
   add 1 to sArrived
   add 1 to sStopped[pWorker]["times"]
   put pWhy into sStopped[pWorker]["why"]
   put pErrors into sStopped[pWorker]["errors"]
   put sArrived into sStopped[pWorker]["order"]
end workerStopped

on countATick
   add 1 to sTicks
   send "countATick" to me in 10 milliseconds
end countATick

-- Wait for a call's message. True if it came, once.
private function isAnswered pCall
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sAnswers[pCall]["times"] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   return sAnswers[pCall]["times"] is 1
end isAnswered

-- Wait for a worker to end. True if this stack was told, once.
private function hasStopped pWorker
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sStopped[pWorker]["times"] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   return sStopped[pWorker]["times"] is 1
end hasStopped

-- What a call of the library throws, or empty
private function thrownBy pStatement, pWorker
   local tError
   try
      do pStatement
   catch tError
      return tError
   end try
   return empty
end thrownBy

----------------------------------------------------------------
-- Calls
----------------------------------------------------------------

on TestAFunctionIsCalled
   local tWorker, tCall
   put workerStart(the script of me) into tWorker
   TestAssert "a worker has a number", tWorker is an integer and tWorker > 0
   TestAssert "and is listed", tWorker is among the lines of workers()
   TestAssert "with no call waiting", workerPending(tWorker) is 0

   put workerCall(tWorker, "wAddUp", "answered", 2, 3) into tCall
   TestAssert "a call has a number", tCall is an integer and tCall > 0
   TestAssert "and returns before its answer", sAnswers[tCall] is empty
   TestAssert "the worker has one call waiting", workerPending(tWorker) is 1

   TestAssert "the message comes, once", isAnswered(tCall)
   TestAssert "with what the function returned", sAnswers[tCall]["result"] is 5
   TestAssert "and no error", sAnswers[tCall]["error"] is empty
   TestAssert "as three parameters", sAnswers[tCall]["parameters"] is 3
   TestAssert "and no call is waiting then", workerPending(tWorker) is 0
end TestAFunctionIsCalled

on TestACommandIsCalled
   local tWorker, tCall, tQuiet
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wShout", "answered", "hello") into tCall
   put workerCall(tWorker, "wSayNothing", "answered", "hello") into tQuiet

   TestAssert "a command's message comes", isAnswered(tCall)
   TestAssert "with what it returned", sAnswers[tCall]["result"] is "HELLO" and sAnswers[tCall]["error"] is empty
   TestAssert "and so does one that returns nothing", isAnswered(tQuiet)
   TestAssert "with nothing", sAnswers[tQuiet]["result"] is empty and sAnswers[tQuiet]["error"] is empty
end TestACommandIsCalled

on TestParameters
   local tWorker, tNone, tTen, tOdd, tText
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wCountOf", "answered") into tNone
   put workerCall(tWorker, "wJoin", "answered", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j") into tTen

   -- Text that would mean something to a statement, if it were made part
   -- of one
   put quote & " & (1/0) & " & quote & ", it" & return & "quit" & tab & "\" into tText
   put workerCall(tWorker, "wEcho", "answered", tText) into tOdd

   TestAssert "a call with no parameters", isAnswered(tNone) and sAnswers[tNone]["result"] is 0
   TestAssert "a call with ten", isAnswered(tTen) and sAnswers[tTen]["result"] is "abcdefghij"
   TestAssert "text is passed as it is", isAnswered(tOdd) and sAnswers[tOdd]["result"] is tText \
         and sAnswers[tOdd]["error"] is empty
end TestParameters

on TestValuesAreCopied
   local tWorker, tArray, tBytes, tCall, tText, tBack
   put workerStart(the script of me) into tWorker

   repeat with i = 0 to 255
      put numToByte(i) after tBytes
   end repeat
   put numToCodepoint(233) & numToCodepoint(8364) & numToCodepoint(128512) & "!" into tText

   put "deep" into tArray["one"]["two"]["three"]
   put tBytes into tArray["bytes"]
   put tText into tArray["text"]
   put 3.25 into tArray["number"]
   put empty into tArray["empty"]
   put "x" into tArray[1]
   put "y" into tArray[2]
   put workerCall(tWorker, "wAddAKey", "answered", tArray) into tCall
   TestAssert "an array is answered", isAnswered(tCall) and sAnswers[tCall]["error"] is empty

   put sAnswers[tCall]["result"] into tBack
   TestAssert "with an array", tBack is an array
   TestAssert "that has what the handler added", tBack["count"] is 7
   TestAssert "a nested value", tBack["one"]["two"]["three"] is "deep"
   TestAssert "every byte", tBack["bytes"] is tBytes
   set the caseSensitive to true
   TestAssert "text beyond ASCII", tBack["text"] is tText
   set the caseSensitive to false
   TestAssert "a number", tBack["number"] is 3.25
   TestAssert "an empty element", "empty" is among the keys of tBack and tBack["empty"] is empty
   TestAssert "and its numbered ones", tBack[1] is "x" and tBack[2] is "y"

   put workerCall(tWorker, "wEcho", "answered", tText) into tCall
   set the caseSensitive to true
   TestAssert "text beyond ASCII by itself", isAnswered(tCall) and sAnswers[tCall]["result"] is tText
   set the caseSensitive to false

   put workerCall(tWorker, "wEcho", "answered", tBytes) into tCall
   TestAssert "binary data by itself", isAnswered(tCall) and sAnswers[tCall]["result"] is tBytes
end TestValuesAreCopied

on TestALotOfData
   local tWorker, tBytes, tLength, tEcho
   put workerStart(the script of me) into tWorker

   -- Three megabytes, no two kilobytes of it alike
   repeat with i = 1 to 3072
      put numToByte(i mod 256) & numToByte(i div 256) after tBytes
      repeat 10
         put numToByte(random(256) - 1) after tBytes
      end repeat
      put "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab" after tBytes
   end repeat
   repeat 3
      put tBytes after tBytes
   end repeat

   put workerCall(tWorker, "wLengthOf", "answered", tBytes) into tLength
   put workerCall(tWorker, "wEcho", "answered", tBytes) into tEcho
   TestAssert "megabytes reach the worker", isAnswered(tLength) and sAnswers[tLength]["result"] is the number of bytes of tBytes
   TestAssert "and come back", isAnswered(tEcho) and sAnswers[tEcho]["error"] is empty
   TestAssert "the same", sAnswers[tEcho]["result"] is tBytes
end TestALotOfData

-- Where a worker's input is slow to read (Windows), a large request is
-- sent as a file instead. Here, every request is.
on TestRequestsSentAsFiles
   local tWorker, tBytes, tArray, tCall, tEcho, tSmall, tFolders
   dispatch "__workerTestInlineLimit" to stack "com.livecode.library.worker" with 0
   put workerStart(the script of me) into tWorker
   repeat with i = 0 to 255
      put numToByte(i) after tBytes
   end repeat
   repeat 12
      put tBytes after tBytes
   end repeat
   put tBytes into tArray["bytes"]
   put numToCodepoint(8364) into tArray["text"]
   put workerCall(tWorker, "wAddAKey", "answered", tArray) into tCall
   put workerCall(tWorker, "wEcho", "answered", tBytes) into tEcho
   put workerCall(tWorker, "wAddUp", "answered", 1, 2) into tSmall
   TestAssert "a request sent as a file is answered", isAnswered(tCall) and sAnswers[tCall]["error"] is empty
   TestAssert "with what it was sent", sAnswers[tCall]["result"]["bytes"] is tBytes \
         and sAnswers[tCall]["result"]["text"] is numToCodepoint(8364) and sAnswers[tCall]["result"]["count"] is 2
   TestAssert "and so are the others", isAnswered(tEcho) and sAnswers[tEcho]["result"] is tBytes \
         and isAnswered(tSmall) and sAnswers[tSmall]["result"] is 3

   -- The worker deletes each file when it has read it, and its folder is
   -- deleted when it ends
   put folders(specialFolderPath("temporary")) into tFolders
   filter tFolders with ("oxt-worker-" & the processID & "-" & tWorker & "-*")
   TestAssert "the worker has a folder for them", the number of lines of tFolders is 1
   TestAssert "with nothing left in it", files(specialFolderPath("temporary") & "/" & tFolders) is empty
   if the platform is not "Win32" then
      -- (A detailed listing's tenth item is the permissions, in octal)
      local tDetail
      put folders(specialFolderPath("temporary"), "detailed") into tDetail
      filter tDetail with (tFolders & ",*")
      TestAssert "that only this user can read", item 10 of tDetail is "700"
   end if
   workerStop tWorker
   TestAssert "the worker is stopped", hasStopped(tWorker)
   TestAssert "and its folder is gone", there is not a folder (specialFolderPath("temporary") & "/" & tFolders)
   dispatch "__workerTestInlineLimit" to stack "com.livecode.library.worker" with empty
end TestRequestsSentAsFiles

on TestCallsAreRunInOrder
   local tWorker, tCalls, tCall, tRight, tLast
   put workerStart(the script of me) into tWorker
   repeat with i = 1 to 25
      put workerCall(tWorker, "wCalledTimes", "answered") into tCalls[i]
   end repeat
   TestAssert "calls wait for the worker", workerPending(tWorker) is 25

   put true into tRight
   put 0 into tLast
   repeat with i = 1 to 25
      put tCalls[i] into tCall
      if not isAnswered(tCall) or sAnswers[tCall]["result"] is not i or sAnswers[tCall]["order"] <= tLast then
         put false into tRight
      end if
      put sAnswers[tCall]["order"] into tLast
   end repeat
   TestAssert "each is run after the one before, and answered in that order", tRight
   TestAssert "and a script's local variables last from call to call", sAnswers[tCalls[25]]["result"] is 25
end TestCallsAreRunInOrder

----------------------------------------------------------------
-- The point of it
----------------------------------------------------------------

on TestTheStackGoesOn
   local tWorker, tCall, tWarm, tBefore
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wAddUp", "answered", 1, 1) into tWarm
   TestAssert "the worker is ready", isAnswered(tWarm)

   send "countATick" to me in 10 milliseconds
   put the milliseconds into tBefore
   put workerCall(tWorker, "wSleep", "answered", 600) into tCall
   TestAssert "a call returns while the handler runs", the milliseconds - tBefore < 500
   TestAssert "its answer comes", isAnswered(tCall)
   TestAssert "and this stack's own messages were delivered meanwhile", sTicks >= 5
   TestDiagnostic "timer messages delivered during a 600 ms call:" && sTicks

   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "countATick" then
         cancel item 1 of tMessage
      end if
   end repeat
end TestTheStackGoesOn

on TestTwoWorkersWorkAtOnce
   local tFirst, tSecond, tWarmOne, tWarmTwo, tOne, tTwo
   put workerStart(the script of me) into tFirst
   put workerStart(the script of me) into tSecond
   TestAssert "two workers are two", tFirst is not tSecond and the number of lines of workers() is 2

   -- Both started, so that the two calls begin together
   put workerCall(tFirst, "wAddUp", "answered", 1, 1) into tWarmOne
   put workerCall(tSecond, "wAddUp", "answered", 1, 1) into tWarmTwo
   TestAssert "both are ready", isAnswered(tWarmOne) and isAnswered(tWarmTwo)

   put workerCall(tFirst, "wSleep", "answered", 1500) into tOne
   put workerCall(tSecond, "wSleep", "answered", 1500) into tTwo
   TestAssert "both answer", isAnswered(tOne) and isAnswered(tTwo)

   -- Each says when it began and ended: the one began before the other
   -- ended, both ways round
   local tOneTimes, tTwoTimes
   put sAnswers[tOne]["result"] into tOneTimes
   put sAnswers[tTwo]["result"] into tTwoTimes
   TestAssert "and they ran at the same time", item 1 of tOneTimes < item 2 of tTwoTimes \
         and item 1 of tTwoTimes < item 2 of tOneTimes
end TestTwoWorkersWorkAtOnce

on TestAWorkerIsAnotherProcess
   local tWorker, tCall, tWhat
   global gWorkerTestGlobal
   put "this stack's" into gWorkerTestGlobal
   put workerStart(the script of me) into tWorker

   put workerCall(tWorker, "wGlobal", "answered") into tCall
   TestAssert "a worker does not have this stack's globals", isAnswered(tCall) and sAnswers[tCall]["result"] is empty \
         and sAnswers[tCall]["error"] is empty

   put workerCall(tWorker, "wWhatAmI", "answered") into tCall
   TestAssert "it says what it is", isAnswered(tCall)
   put sAnswers[tCall]["result"] into tWhat
   TestAssert "an engine with no window", line 1 of tWhat ends with "command line"
   TestAssert "that is not marked as a worker for the programs it starts", line 3 of tWhat is true
   TestAssert "and this process is not marked as one", $OXT_WORKER is empty
   TestDiagnostic "the worker's environment:" && line 1 of tWhat & "; stacks open in it:" && line 2 of tWhat

   put workerCall(tWorker, "wStartAWorker", "answered") into tCall
   TestAssert "a worker cannot start workers", isAnswered(tCall) \
         and sAnswers[tCall]["result"] is "workerStart: a worker cannot start workers"
end TestAWorkerIsAnotherProcess

----------------------------------------------------------------
-- What goes wrong in a handler
----------------------------------------------------------------

on TestErrors
   local tWorker, tThrown, tEngine, tMissing, tHidden, tAfter, tError
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wThrow", "answered", "that went wrong") into tThrown
   put workerCall(tWorker, "wDivide", "answered", 0) into tEngine
   put workerCall(tWorker, "wNoSuchHandler", "answered") into tMissing
   put workerCall(tWorker, "wHidden", "answered") into tHidden
   put workerCall(tWorker, "wDivide", "answered", 4) into tAfter

   TestAssert "what a handler throws is the error", isAnswered(tThrown) \
         and sAnswers[tThrown]["error"] is "that went wrong" and sAnswers[tThrown]["result"] is empty

   TestAssert "an error of the engine's is answered", isAnswered(tEngine) and sAnswers[tEngine]["result"] is empty
   put sAnswers[tEngine]["error"] into tError
   TestAssert "as the engine's lines", matchText(line 1 of tError, "^[0-9]+,[0-9]+,[0-9]+")
   TestAssert "which name the handler", "wDivide" is in tError
   TestAssert "and nothing of the library that called it", "dispatch" is not in tError and "Worker Script" is not in tError
   TestDiagnostic "the engine's error:" && replaceText(tError, "\n", " | ")

   TestAssert "a handler the script does not have", isAnswered(tMissing) \
         and sAnswers[tMissing]["error"] is "no such handler" and sAnswers[tMissing]["result"] is empty
   TestAssert "a private handler cannot be called", isAnswered(tHidden) \
         and sAnswers[tHidden]["error"] is "no such handler"
   TestAssert "and the worker goes on after them", isAnswered(tAfter) \
         and sAnswers[tAfter]["result"] is 0.25 and sAnswers[tAfter]["error"] is empty
end TestErrors

on TestAScriptThatDoesNotCompile
   local tWorker, tCall, tSecond
   put workerStart("function fine" & return & "return 1" & return & "end fine" & return & \
         "on broken" & return & "put 1 +" & return & "end broken") into tWorker
   put workerCall(tWorker, "fine", "answered") into tCall
   put workerCall(tWorker, "broken", "answered") into tSecond
   TestAssert "a call of a script that does not compile ends", isAnswered(tCall)
   TestAssert "with an error that says so", line 1 of sAnswers[tCall]["error"] is "script error" \
         and sAnswers[tCall]["result"] is empty
   TestAssert "and what the compiler said", the number of lines of sAnswers[tCall]["error"] > 1
   TestAssert "as does every other", isAnswered(tSecond) and line 1 of sAnswers[tSecond]["error"] is "script error"
   TestDiagnostic "the compile error:" && replaceText(sAnswers[tCall]["error"], "\n", " | ")
end TestAScriptThatDoesNotCompile

on TestTheScriptOfAScriptOnlyStack
   local tWorker, tCall, tFails, tScript
   -- As the text of a script file is: the first line names the stack, and
   -- is no part of the script
   put "script" && quote & "Sums" & quote & return & \
         "function double pNumber" & return & \
         "   return pNumber * 2" & return & \
         "end double" & return & \
         "function fails" & return & \
         "   return 1 / 0" & return & \
         "end fails" into tScript
   put workerStart(tScript) into tWorker
   put workerCall(tWorker, "double", "answered", 21) into tCall
   put workerCall(tWorker, "fails", "answered") into tFails
   TestAssert "the text of a script file is a script", isAnswered(tCall) and sAnswers[tCall]["result"] is 42 \
         and sAnswers[tCall]["error"] is empty
   TestAssert "and an error names the line of the file", isAnswered(tFails) \
         and item 2 of line 1 of sAnswers[tFails]["error"] is 6
end TestTheScriptOfAScriptOnlyStack

on TestWrongCalls
   local tWorker
   put workerStart(the script of me) into tWorker

   TestAssert "a call of no worker throws", \
         thrownBy("get workerCall(987654, " & quote & "wAddUp" & quote & ", " & quote & "answered" & quote & ")") \
         is "workerCall: no such worker"
   TestAssert "as does one of an empty worker", \
         thrownBy("get workerCall(empty, " & quote & "wAddUp" & quote & ", " & quote & "answered" & quote & ")") \
         is "workerCall: no such worker"
   TestAssert "a call with no message throws", \
         thrownBy("get workerCall(" & tWorker & ", " & quote & "wAddUp" & quote & ", empty)") \
         is "workerCall: no message to send when the handler has returned"
   TestAssert "a call of what is not a name throws", \
         thrownBy("get workerCall(" & tWorker & ", " & quote & "wAddUp 1, 2" & quote & ", " & quote & "answered" & quote & ")") \
         is "workerCall: not the name of a handler"
   TestAssert "and so does one of no name", \
         thrownBy("get workerCall(" & tWorker & ", empty, " & quote & "answered" & quote & ")") \
         is "workerCall: not the name of a handler"
   TestAssert "none of them was sent", workerPending(tWorker) is 0

   workerStop 987654
   TestAssert "stopping no worker says so", the result is "no such worker"
   TestAssert "no worker has no calls waiting", workerPending(987654) is empty
end TestWrongCalls

----------------------------------------------------------------
-- Progress and output
----------------------------------------------------------------

on TestProgress
   local tWorker, tCall, tArrayCall, tRight
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wReport", "answered", 3) into tCall
   put workerCall(tWorker, "wReportAnArray", "answered") into tArrayCall
   TestAssert "a handler that reports is answered", isAnswered(tCall) and sAnswers[tCall]["result"] is "reported"
   TestAssert "each report came", the number of elements of sProgress[tCall] is 3

   put true into tRight
   repeat with i = 1 to 3
      if sProgress[tCall][i]["value"] is not ("step" && i) or sProgress[tCall][i]["order"] >= sAnswers[tCall]["order"] then
         put false into tRight
      end if
   end repeat
   TestAssert "in order, before the answer", tRight

   TestAssert "a report can be an array", isAnswered(tArrayCall) \
         and sProgress[tArrayCall][1]["value"]["percent"] is 40 \
         and sProgress[tArrayCall][1]["value"]["text"] is "half way"

   -- (Here it is no worker's handler that calls it)
   workerSendProgress "nothing"
   TestAssert "outside a worker the command does nothing", the result is empty
end TestProgress

on TestWhatAWorkerPuts
   local tWorker, tCall
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wPut", "answered", "seen in the worker") into tCall
   TestAssert "a handler that puts is answered", isAnswered(tCall) and sAnswers[tCall]["result"] is "put"
   TestAssert "what it put came to the stack that started the worker", sOutput[tWorker][1]["text"] is "seen in the worker"
   TestAssert "once", the number of elements of sOutput[tWorker] is 1
   TestAssert "before the answer", sOutput[tWorker][1]["order"] < sAnswers[tCall]["order"]
end TestWhatAWorkerPuts

----------------------------------------------------------------
-- Stopping
----------------------------------------------------------------

on TestStop
   local tWorker, tWarm, tBusy, tQueued
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wAddUp", "answered", 1, 1) into tWarm
   TestAssert "the worker is ready", isAnswered(tWarm)

   put workerCall(tWorker, "wBusy", "answered") into tBusy
   put workerCall(tWorker, "wAddUp", "answered", 1, 1) into tQueued
   wait 200 milliseconds with messages
   TestAssert "a handler that does not end is not answered", sAnswers[tBusy] is empty

   workerStop tWorker
   TestAssert "stopping its worker", the result is empty
   TestAssert "a stopped worker takes no more calls", \
         thrownBy("get workerCall(" & tWorker & ", " & quote & "wAddUp" & quote & ", " & quote & "answered" & quote & ")") \
         is "workerCall: the worker has been stopped"

   TestAssert "ends the call", isAnswered(tBusy)
   TestAssert "with an error", sAnswers[tBusy]["error"] is "worker stopped" and sAnswers[tBusy]["result"] is empty
   TestAssert "and the one that was waiting", isAnswered(tQueued) and sAnswers[tQueued]["error"] is "worker stopped"
   TestAssert "in the order they were made", sAnswers[tBusy]["order"] < sAnswers[tQueued]["order"]

   TestAssert "the stack that started the worker is told", hasStopped(tWorker)
   TestAssert "that it was stopped", sStopped[tWorker]["why"] is "stopped"
   TestAssert "after its calls ended", sStopped[tWorker]["order"] > sAnswers[tQueued]["order"]
   TestAssert "and the worker is gone", tWorker is not among the lines of workers() and workerPending(tWorker) is empty

   workerStop tWorker
   TestAssert "stopping it again says it is not there", the result is "no such worker"
end TestStop

on TestAWorkerThatEndsByItself
   local tWorker, tCall, tQueued
   put workerStart(the script of me) into tWorker
   put workerCall(tWorker, "wQuit", "answered") into tCall
   put workerCall(tWorker, "wAddUp", "answered", 1, 1) into tQueued

   TestAssert "a call whose handler quits the worker ends", isAnswered(tCall)
   TestAssert "with an error", sAnswers[tCall]["error"] is "worker stopped"
   TestAssert "as does one that was waiting", isAnswered(tQueued) and sAnswers[tQueued]["error"] is "worker stopped"
   TestAssert "the stack is told the worker ended", hasStopped(tWorker)
   TestAssert "by itself", sStopped[tWorker]["why"] is "exit"
   TestAssert "and the worker is gone", workers() is empty
end TestAWorkerThatEndsByItself

----------------------------------------------------------------
-- Who is told
----------------------------------------------------------------

private function callerScript
   return "on startOne pScript" & return & \
         "   set the cWorker of me to workerStart(pScript)" & return & \
         "end startOne" & return & \
         "on callIt pWorker, pHandler, pA, pB" & return & \
         "   set the cCall of me to workerCall(pWorker, pHandler, " & quote & "buttonAnswered" & quote & ", pA, pB)" & return & \
         "end callIt" & return & \
         "on buttonAnswered pCall, pResult, pError" & return & \
         "   set the cAnswer of me to pCall & comma & pResult & comma & pError" & return & \
         "end buttonAnswered" & return & \
         "on workerStopped pWorker, pWhy" & return & \
         "   set the cStopped of me to pWorker & comma & pWhy" & return & \
         "end workerStopped"
end callerScript

on TestMessagesGoToTheObjectThatCalled
   local tWorker, tButton, tUntil, tCall, tOwn
   set the defaultStack to the short name of me
   create button "Caller"
   put it into tButton
   set the script of tButton to callerScript()

   -- A worker this stack starts, called by the button
   put workerStart(the script of me) into tWorker
   dispatch "callIt" to tButton with tWorker, "wAddUp", 20, 22
   put the cCall of tButton into tCall
   TestAssert "an object's call has a number", tCall is an integer

   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the cAnswer of tButton is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   TestAssert "the object that called is sent the message", the cAnswer of tButton is (tCall & ",42,")
   TestAssert "and this stack is not", sAnswers[tCall] is empty

   -- A worker the button starts, stopped by this stack
   dispatch "startOne" to tButton with the script of me
   put the cWorker of tButton into tOwn
   TestAssert "an object's worker has a number", tOwn is an integer and tOwn is not tWorker
   workerStop tOwn
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the cStopped of tButton is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   TestAssert "the object that started a worker is told it stopped", the cStopped of tButton is (tOwn & ",stopped")
   TestAssert "and this stack is not", sStopped[tOwn] is empty
end TestMessagesGoToTheObjectThatCalled

on TestAnObjectThatIsDeleted
   local tWorker, tButton, tUntil, tCall
   set the defaultStack to the short name of me
   create button "Caller"
   put it into tButton
   set the script of tButton to callerScript()

   put workerStart(the script of me) into tWorker
   dispatch "callIt" to tButton with tWorker, "wSleep", 300
   delete tButton

   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while workerPending(tWorker) > 0 and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   TestAssert "a call whose object has been deleted is answered to nobody", workerPending(tWorker) is 0
   wait 50 milliseconds with messages

   put workerCall(tWorker, "wAddUp", "answered", 4, 5) into tCall
   TestAssert "and the worker goes on", isAnswered(tCall) and sAnswers[tCall]["result"] is 9
end TestAnObjectThatIsDeleted
