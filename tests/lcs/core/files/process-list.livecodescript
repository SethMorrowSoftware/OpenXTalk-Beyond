script "CoreFilesProcessList"
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
On Linux and macOS, when a process opened for read or update ends, it
stays in the openProcesses and the openProcessIDs (its ID 0) until "close process",
even once its output has been read to the end. It has since LiveCode 7:
the engine asks whether the stream is at its end by comparing its
position with its size, and a pipe has neither (IO_cleanprocesses in
engine/src/mcio.cpp). Scripts may rely on that, so it stays the default,
and these tests pin it. The closeEndedProcesses, false by default, lets
such a process go once a read has taken its output to the end ("eof").
On Windows such a process has always left by itself once it ended and
its output was read (the engine answers a pipe's position and size as
equal there), with the property or without it; the tests pin that too.

The processes print "foo" and end. On Linux and macOS they sleep a moment
first: the engine reaps its children right after the fork, so one that
has already ended by then is "not opened" (see TestReadFromProcessUntilEOF
in files.livecodescript).
*/

constant kWaitSeconds = 10

private function _EndingCommand
   if the platform is "Win32" then
      return "cmd.exe /c echo foo"
   else
      return "/bin/sh -c" && quote & "sleep 0.2; echo foo" & quote
   end if
end _EndingCommand

-- A process that ends a moment after it starts and prints nothing
private function _QuietEndingCommand
   if the platform is "Win32" then
      return "cmd.exe /c exit 0"
   else
      return "/bin/sh -c" && quote & "sleep 0.2" & quote
   end if
end _QuietEndingCommand

-- A process that runs for a few seconds and prints nothing
private function _RunningCommand
   if the platform is "Win32" then
      return "cmd.exe /c ping -n 6 127.0.0.1 >nul"
   else
      return "/bin/sh -c" && quote & "sleep 5" & quote
   end if
end _RunningCommand

-- The process's ID in the openProcessIDs, empty when it is not listed
private function _ListedID pProcess
   local tLine
   repeat with tLine = 1 to the number of lines of the openProcesses
      if line tLine of the openProcesses is pProcess then
         return line tLine of the openProcessIDs
      end if
   end repeat
   return empty
end _ListedID

private function _Listed pProcess
   return pProcess is among the lines of the openProcesses
end _Listed

on TestCloseEndedProcessesProperty
   TestAssert "the closeEndedProcesses is false by default", \
         the closeEndedProcesses is false
   set the closeEndedProcesses to true
   TestAssert "it can be set to true", the closeEndedProcesses is true
   set the closeEndedProcesses to "false"
   TestAssert "it takes a string false", the closeEndedProcesses is false

   local tError
   try
      set the closeEndedProcesses to "sometimes"
   catch tError
   end try
   TestAssert "a value that is not a boolean is refused", tError is not empty
   TestAssert "and the property is as it was", the closeEndedProcesses is false
end TestCloseEndedProcessesProperty

-- The name is no keyword: a custom property, a variable and a handler of
-- that name are as they were
on TestCloseEndedProcessesNameAsBefore
   local tButton
   create button "OXTCloseEndedProcessesProbe"
   put it into tButton
   set the closeEndedProcesses of tButton to "mine"
   TestAssert "the closeEndedProcesses of an object is its custom property", \
         the closeEndedProcesses of tButton is "mine"
   TestAssert "and the global one is apart from it", \
         the closeEndedProcesses is false
   delete tButton

   local closeEndedProcesses
   put 41 into closeEndedProcesses
   add 1 to closeEndedProcesses
   TestAssert "a variable of that name is a variable", closeEndedProcesses is 42
   TestAssert "a handler of that name is a handler", \
         _CallCloseEndedProcesses() is "called"
end TestCloseEndedProcessesNameAsBefore

private function _CallCloseEndedProcesses
   return closeEndedProcesses("called")
end _CallCloseEndedProcesses

private function closeEndedProcesses pValue
   return pValue
end closeEndedProcesses

-- The behaviour of LiveCode 7 and later, kept by default
on TestEndedProcessStaysByDefault
   TestSkipIf "platform", "HTML5,iPhone,Android"

   local tProcess, tOutput, tResult
   put _EndingCommand() into tProcess
   open process tProcess for text read
   TestAssert "the process opened", the result is empty
   wait 500 milliseconds with messages
   read from process tProcess until EOF in kWaitSeconds seconds
   put it into tOutput
   put the result into tResult

   TestAssert "its output is read", word 1 of tOutput is "foo"
   TestAssert "the read ends with eof", tResult is "eof"
   if the platform is "Win32" then
      -- On Windows a process read to its end has always left the list by
      -- itself: MCS_eof asks a pipe's position and size there too, and
      -- Windows answers them as equal, so the closeEndedProcesses changes
      -- nothing there. Pinned as it is
      TestAssert "on Windows it has left the openProcesses", not _Listed(tProcess)
      close process tProcess
      TestAssert "and close process says it is not open", \
            the result is "process is not open"
      exit TestEndedProcessStaysByDefault
   end if

   TestAssert "it is still in the openProcesses", _Listed(tProcess)
   TestAssert "its ID in the openProcessIDs is 0", _ListedID(tProcess) is 0

   read from process tProcess until EOF in kWaitSeconds seconds
   TestAssert "another read ends with eof", the result is "eof"
   TestAssert "it is still in the openProcesses after that", _Listed(tProcess)

   close process tProcess
   TestAssert "close process closes it", the result is empty
   TestAssert "and it has left the openProcesses", not _Listed(tProcess)
end TestEndedProcessStaysByDefault

on TestEndedProcessLeavesWhenSet
   TestSkipIf "platform", "HTML5,iPhone,Android"

   set the closeEndedProcesses to true
   local tProcess, tOutput, tResult
   put _EndingCommand() into tProcess
   open process tProcess for text read
   TestAssert "the process opened", the result is empty
   wait 500 milliseconds with messages
   read from process tProcess until EOF in kWaitSeconds seconds
   put it into tOutput
   put the result into tResult

   TestAssert "its output is read", word 1 of tOutput is "foo"
   TestAssert "the read ends with eof", tResult is "eof"
   TestAssert "it has left the openProcesses", not _Listed(tProcess)
   TestAssert "and the openProcessIDs", \
         the number of lines of the openProcessIDs is \
         the number of lines of the openProcesses

   close process tProcess
   TestAssert "close process then says it is not open", \
         the result is "process is not open"
   set the closeEndedProcesses to false
end TestEndedProcessLeavesWhenSet

-- Output that has not been read keeps the process listed, so it can be
-- read
on TestEndedProcessKeepsUnreadOutputWhenSet
   TestSkipIf "platform", "HTML5,iPhone,Android"

   set the closeEndedProcesses to true
   local tProcess, tOutput, tResult
   put _EndingCommand() into tProcess
   open process tProcess for text read
   TestAssert "the process opened", the result is empty
   wait 1 second with messages

   TestAssert "an ended process with unread output is still listed", \
         _Listed(tProcess)

   read from process tProcess until EOF in kWaitSeconds seconds
   put it into tOutput
   put the result into tResult
   TestAssert "its output can still be read", word 1 of tOutput is "foo"
   TestAssert "the read ends with eof", tResult is "eof"
   TestAssert "then it has left the openProcesses", not _Listed(tProcess)
   set the closeEndedProcesses to false
end TestEndedProcessKeepsUnreadOutputWhenSet

-- A process that is still running stays, whatever a read gives
on TestRunningProcessStaysWhenSet
   TestSkipIf "platform", "HTML5,iPhone,Android"

   set the closeEndedProcesses to true
   local tProcess
   put _RunningCommand() into tProcess
   open process tProcess for text read
   TestAssert "the process opened", the result is empty
   read from process tProcess until EOF in 300 milliseconds
   TestAssert "a read of a running process times out", the result is "timed out"
   TestAssert "it is still in the openProcesses", _Listed(tProcess)
   TestAssert "with its ID", _ListedID(tProcess) is an integer \
         and _ListedID(tProcess) is not 0

   close process tProcess
   TestAssert "close process closes it", the result is empty
   set the closeEndedProcesses to false
end TestRunningProcessStaysWhenSet

-- Turning it off again brings the default back
on TestCloseEndedProcessesOffAgain
   TestSkipIf "platform", "HTML5,iPhone,Android"

   set the closeEndedProcesses to true
   set the closeEndedProcesses to false
   local tProcess
   put _EndingCommand() into tProcess
   open process tProcess for text read
   wait 500 milliseconds with messages
   read from process tProcess until EOF in kWaitSeconds seconds
   TestAssert "the read ends with eof", the result is "eof"
   if the platform is "Win32" then
      -- (see TestEndedProcessStaysByDefault)
      TestAssert "on Windows it has left the list, as it always has", \
            not _Listed(tProcess)
      close process tProcess
   else
      TestAssert "the ended process is still listed", _Listed(tProcess)
      close process tProcess
      TestAssert "close process closes it", the result is empty
   end if
end TestCloseEndedProcessesOffAgain

-- A process opened for write leaves when it ends, as it always has
on TestEndedWriteProcessLeaves
   TestSkipIf "platform", "HTML5,iPhone,Android"

   local tProcess
   put _QuietEndingCommand() into tProcess
   open process tProcess for write
   TestAssert "the process opened", the result is empty

   local tTries
   repeat with tTries = 1 to 100
      if not _Listed(tProcess) then
         exit repeat
      end if
      wait 100 milliseconds with messages
   end repeat
   TestAssert "a process opened for write leaves the openProcesses when it ends", \
         not _Listed(tProcess)
   if _Listed(tProcess) then
      close process tProcess
   end if
end TestEndedWriteProcessLeaves
