script "CoreEngineSigterm"
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

/*
A TERM signal (kill, killall) on macOS. The engine used to send
shutDownRequest and shutDown from inside the signal handler, so script ran
in the middle of whatever the engine was doing, which could hang or crash
it. Now the request waits for the event loop. The child stack
(_sigterm.livecodescript) is busy in a handler when the signal comes: the
messages must come after that handler ends, never inside it, and they must
be the same messages as before.

macOS only: Linux keeps its own handling (it quits at once with status
-1 unless shutDownRequest is handled), unchanged here, and Windows has no
TERM signal to send.
*/

private function _SigtermRun pMode
   local tStack, tLog, tEngine, tPid
   put the effective filename of me into tStack
   set the itemDelimiter to slash
   put "_sigterm.livecodescript" into item -1 of tStack
   put the tempName into tLog
   set the itemDelimiter to ":"
   put item 2 to -1 of the address into tEngine

   -- Started in the background, so that this engine can signal it
   put shell(format("OXT_SIGTERM_LOG='%s' OXT_SIGTERM_MODE='%s' " & \
         "\"%s\" -ui \"%s\" >/dev/null 2>&1 & echo $!", \
         tLog, pMode, tEngine, tStack)) into tPid
   put word 1 of tPid into tPid
   TestDiagnostic "child" && tPid && "log" && tLog

   -- Wait for it to start its busy handler, then signal it in the middle
   local tUntil
   put the milliseconds + 30000 into tUntil
   repeat until there is a file tLog or the milliseconds > tUntil
      wait 50 milliseconds
   end repeat
   wait 1 second
   get shell("kill -TERM" && tPid)

   -- Wait for it to end (kill -0 fails once it is gone)
   put the milliseconds + 30000 into tUntil
   repeat until the milliseconds > tUntil
      get shell("kill -0" && tPid && "2>/dev/null")
      if the result is not empty then exit repeat
      wait 100 milliseconds
   end repeat
   get shell("kill -0" && tPid && "2>/dev/null")
   if the result is empty then
      get shell("kill -KILL" && tPid)
      TestDiagnostic "the child did not end; killed"
   end if

   local tLines
   put url ("file:" & tLog) into tLines
   delete file tLog
   TestDiagnostic "log:" && tLines
   return tLines
end _SigtermRun

on TestSigtermRunsShutdownAfterTheRunningHandler
   TestSkipIfNot "platform", "MacOS"
   TestSkipIfNot "shell"

   local tLog
   put _SigtermRun("pass") into tLog
   replace return with comma in tLog
   if char -1 of tLog is comma then delete char -1 of tLog
   TestAssert "TERM: shutDownRequest and shutDown come after the busy handler ends", \
         tLog is "ready,busydone,shutDownRequest,shutDown"
end TestSigtermRunsShutdownAfterTheRunningHandler

on TestSigtermRefusedByShutdownRequestKeepsRunning
   TestSkipIfNot "platform", "MacOS"
   TestSkipIfNot "shell"

   local tLog
   put _SigtermRun("refuse") into tLog
   replace return with comma in tLog
   if char -1 of tLog is comma then delete char -1 of tLog
   TestAssert "TERM refused by shutDownRequest: the engine keeps running", \
         tLog is "ready,busydone,shutDownRequest,stillrunning"
end TestSigtermRefusedByShutdownRequestKeepsRunning
