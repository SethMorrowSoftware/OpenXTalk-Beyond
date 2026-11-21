script "TestBackgroundJobsLibrary"
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

-- The Background Jobs library (org.openxtalk.library.async) as a script
-- uses it: each call returns at once with a job's number, the work is done
-- on another thread of the engine, and this stack is sent a message when
-- it is done. The threads themselves have their own checks, without the
-- engine (tools/ci/async_core_check.py); these are of what a script sees.
--
-- Every wait here is "with messages", since that is where a job's message
-- arrives, and ends as soon as the message has come: the time limits are
-- for a build that is broken, not a measure.

-- What the messages of the file and shell jobs brought, by job
local sDone
-- The events of the programs, by job, in the order they came
local sEvents
-- A folder of this test's own
local sFolder

constant kWaitSeconds = 30

on TestSetup
   -- The library needs no compiler where the tests run, only its module:
   -- these run in the web standalone too, and in the Android one when the
   -- IDE that built it has the library (see the requirement).
   TestSkipIfNot "extension", "org.openxtalk.library.async"
   TestLoadExtension "org.openxtalk.library.async"

   put empty into sDone
   put empty into sEvents
   put specialFolderPath("temporary") & "/oxt-async-test-" & the milliseconds & "-" & random(1000000) into sFolder
   create folder sFolder
end TestSetup

on TestTearDown
   -- (asyncJobs is this library's: not there if it could not be loaded)
   local tJobs
   try
      put asyncJobs() into tJobs
   catch tError
   end try
   repeat for each line tJob in tJobs
      asyncCancel tJob
   end repeat
   if sFolder is not empty then
      deleteTree sFolder
   end if
end TestTearDown

private command deleteTree pFolder
   if there is not a folder pFolder then
      exit deleteTree
   end if
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & "/" & tFile)
   end repeat
   repeat for each line tFolder in folders(pFolder)
      if tFolder is not ".." and tFolder is not "." then
         deleteTree pFolder & "/" & tFolder
      end if
   end repeat
   delete folder pFolder
end deleteTree

----------------------------------------------------------------
-- The messages
----------------------------------------------------------------

on jobDone pJob, pResult, pError, pCode
   add 1 to sDone[pJob]["times"]
   put the paramCount into sDone[pJob]["parameters"]
   put pResult into sDone[pJob]["result"]
   put pError into sDone[pJob]["error"]
   put pCode into sDone[pJob]["code"]
end jobDone

on programSaid pJob, pEvent, pData, pCode
   local tIndex
   put the number of elements of sEvents[pJob] + 1 into tIndex
   put pEvent into sEvents[pJob][tIndex]["event"]
   put pData into sEvents[pJob][tIndex]["data"]
   put pCode into sEvents[pJob][tIndex]["code"]
   put the paramCount into sEvents[pJob][tIndex]["parameters"]
end programSaid

-- Wait for a file or shell job's message. True if it came.
private function jobIsDone pJob
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sDone[pJob]["times"] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
   return sDone[pJob]["times"] is 1
end jobIsDone

-- Wait for a program's last event, and return it (empty if none came)
private function lastEventOf pJob
   local tUntil, tCount
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the milliseconds < tUntil
      put the number of elements of sEvents[pJob] into tCount
      if tCount > 0 and sEvents[pJob][tCount]["event"] is among the items of "exit,cancelled,failed" then
         return sEvents[pJob][tCount]["event"]
      end if
      wait 5 milliseconds with messages
   end repeat
   return empty
end lastEventOf

-- All that a program wrote to its output, or its error output
private function outputOf pJob, pEvent
   local tOutput
   repeat with tIndex = 1 to the number of elements of sEvents[pJob]
      if sEvents[pJob][tIndex]["event"] is pEvent then
         put sEvents[pJob][tIndex]["data"] after tOutput
      end if
   end repeat
   return tOutput
end outputOf

-- Bytes of every value, more than the 1 MB that the threads read at once
private function someBytes pCount
   local tBytes
   repeat with tByte = 0 to 255
      put numToByte(tByte) after tBytes
   end repeat
   repeat while the number of bytes of tBytes < pCount
      put tBytes after tBytes
   end repeat
   return byte 1 to pCount of tBytes
end someBytes

----------------------------------------------------------------
-- Files
----------------------------------------------------------------

on TestWriteThenReadFile
   local tPath, tBytes, tWrite, tRead
   put sFolder & "/written.bin" into tPath
   put someBytes(3000000) into tBytes

   put asyncWriteFile(tPath, tBytes, "jobDone") into tWrite
   TestAssert "a job has a number", tWrite is an integer and tWrite > 0
   TestAssert "no message before the script waits", sDone[tWrite] is empty
   TestAssert "the write's message comes, once", jobIsDone(tWrite)
   TestAssert "with four parameters", sDone[tWrite]["parameters"] is 4
   TestAssert "without an error", sDone[tWrite]["error"] is empty and sDone[tWrite]["code"] is 0
   TestAssert "and nothing as its result", sDone[tWrite]["result"] is empty
   TestAssert "the file is written whole", url ("binfile:" & tPath) is tBytes

   put asyncReadFile(tPath, "jobDone") into tRead
   TestAssert "the next job has another number", tRead is an integer and tRead > 0 and tRead is not tWrite
   TestAssert "the read's message comes, once", jobIsDone(tRead)
   TestAssert "with the file's bytes", sDone[tRead]["result"] is tBytes
   TestAssert "and no error", sDone[tRead]["error"] is empty and sDone[tRead]["code"] is 0

   wait 100 milliseconds with messages
   TestAssert "no message comes twice", sDone[tWrite]["times"] is 1 and sDone[tRead]["times"] is 1
   TestAssert "a job that is over has no status", asyncStatus(tRead) is empty and asyncProgress(tRead) is empty
   TestAssert "and is not among the jobs", asyncJobs() is empty
end TestWriteThenReadFile

on TestWriteText
   -- text is written as its native bytes, as with a binfile: URL
   local tPath, tJob
   put sFolder & "/text.txt" into tPath
   put asyncWriteFile(tPath, "plain text" & return, "jobDone") into tJob
   TestAssert "text is written", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "as its bytes", url ("binfile:" & tPath) is "plain text" & numToByte(10)

   put asyncWriteFile(tPath, empty, "jobDone") into tJob
   TestAssert "nothing is written", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "which leaves an empty file", there is a file tPath and url ("binfile:" & tPath) is empty

   put asyncReadFile(tPath, "jobDone") into tJob
   TestAssert "an empty file is read", jobIsDone(tJob) and sDone[tJob]["error"] is empty and sDone[tJob]["result"] is empty
end TestWriteText

on TestAppendFile
   local tPath, tJob
   put sFolder & "/log.txt" into tPath
   put asyncAppendFile(tPath, "one" & return, "jobDone") into tJob
   TestAssert "appending makes the file", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   put asyncAppendFile(tPath, "two" & return, "jobDone") into tJob
   TestAssert "and adds to it", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "at its end", url ("binfile:" & tPath) is "one" & numToByte(10) & "two" & numToByte(10)

   put asyncWriteFile(tPath, "three", "jobDone") into tJob
   TestAssert "writing replaces it", jobIsDone(tJob) and url ("binfile:" & tPath) is "three"
end TestAppendFile

on TestFileErrors
   local tJob
   put asyncReadFile(sFolder & "/not-there.txt", "jobDone") into tJob
   TestAssert "reading a file that is not there still sends the message", jobIsDone(tJob)
   TestAssert "with an error", sDone[tJob]["error"] is "can't open file"
   TestAssert "the system's code", sDone[tJob]["code"] is an integer and sDone[tJob]["code"] > 0
   TestAssert "and no data", sDone[tJob]["result"] is empty

   put asyncReadFile(sFolder, "jobDone") into tJob
   TestAssert "a folder is not read as a file", jobIsDone(tJob) and sDone[tJob]["error"] is "can't open file"

   put asyncWriteFile(sFolder & "/no-such-folder/file.txt", "x", "jobDone") into tJob
   TestAssert "writing where there is no folder fails", jobIsDone(tJob) and sDone[tJob]["error"] is "can't open file"
   TestAssert "and makes no folder", there is not a folder (sFolder & "/no-such-folder")
end TestFileErrors

on TestRelativePath
   -- a path that is not absolute is from the defaultFolder as it is when
   -- the job is started, wherever it is by the time the job runs
   local tJob, tWas
   put the defaultFolder into tWas
   set the defaultFolder to sFolder
   put asyncWriteFile("relative.txt", "here", "jobDone") into tJob
   set the defaultFolder to tWas
   TestAssert "a relative path is written", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "in the defaultFolder of the call", url ("binfile:" & sFolder & "/relative.txt") is "here"
end TestRelativePath

on TestCopyFile
   local tFrom, tTo, tBytes, tJob
   put sFolder & "/original.bin" into tFrom
   put sFolder & "/copy.bin" into tTo
   put someBytes(2500000) into tBytes
   put tBytes into url ("binfile:" & tFrom)
   put "old" into url ("binfile:" & tTo)

   put asyncCopyFile(tFrom, tTo, "jobDone") into tJob
   TestAssert "the copy's message comes", jobIsDone(tJob)
   TestAssert "without an error", sDone[tJob]["error"] is empty and sDone[tJob]["result"] is empty
   TestAssert "the copy is whole, in place of what was there", url ("binfile:" & tTo) is tBytes
   TestAssert "and the original is as it was", url ("binfile:" & tFrom) is tBytes

   put asyncCopyFile(sFolder & "/not-there.bin", sFolder & "/never.bin", "jobDone") into tJob
   TestAssert "copying a file that is not there fails", jobIsDone(tJob) and sDone[tJob]["error"] is "can't open file"
   TestAssert "and leaves no copy", there is not a file (sFolder & "/never.bin")

   put asyncCopyFile(tFrom, tFrom, "jobDone") into tJob
   TestAssert "a file is not copied onto itself", jobIsDone(tJob) and sDone[tJob]["error"] is not empty
   TestAssert "and is still whole", url ("binfile:" & tFrom) is tBytes
end TestCopyFile

on TestListFolder
   local tJob
   create folder sFolder & "/tree"
   create folder sFolder & "/tree/sub"
   create folder sFolder & "/tree/sub/deep"
   create folder sFolder & "/tree/empty"
   put "a" into url ("binfile:" & sFolder & "/tree/a file.txt")
   put "b" into url ("binfile:" & sFolder & "/tree/sub/b.txt")
   put "c" into url ("binfile:" & sFolder & "/tree/sub/deep/c.txt")
   put "z" into url ("binfile:" & sFolder & "/tree/z.txt")

   put asyncListFolder(sFolder & "/tree", false, "jobDone") into tJob
   TestAssert "the listing's message comes", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "a folder alone: a line for each entry, folders with a slash", \
         sDone[tJob]["result"] is "a file.txt" & return & "empty/" & return & "sub/" & return & "z.txt" & return

   put asyncListFolder(sFolder & "/tree", true, "jobDone") into tJob
   TestAssert "the tree's message comes", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "a tree: each folder followed by what it holds", \
         sDone[tJob]["result"] is "a file.txt" & return & "empty/" & return & "sub/" & return & \
         "sub/b.txt" & return & "sub/deep/" & return & "sub/deep/c.txt" & return & "z.txt" & return

   put asyncListFolder(sFolder & "/tree/empty", true, "jobDone") into tJob
   TestAssert "an empty folder has an empty listing", jobIsDone(tJob) and sDone[tJob]["error"] is empty and sDone[tJob]["result"] is empty

   put asyncListFolder(sFolder & "/not-there", true, "jobDone") into tJob
   TestAssert "a folder that is not there cannot be listed", jobIsDone(tJob) and sDone[tJob]["error"] is "can't open folder"
end TestListFolder

on TestManyJobs
   -- more jobs than there are threads for them: each has its message, once
   local tJobs, tJob, tAllDone, tAllRight
   repeat with tIndex = 1 to 60
      put asyncWriteFile(sFolder & "/many-" & tIndex & ".txt", "file" && tIndex, "jobDone") into tJob
      put tIndex into tJobs[tJob]
   end repeat
   TestAssert "sixty jobs have sixty numbers", the number of elements of tJobs is 60
   -- some are over already: asyncJobs lists the ones that are not
   local tListed, tOurs
   put true into tOurs
   repeat for each line tListed in asyncJobs()
      put tOurs and tListed is among the keys of tJobs into tOurs
   end repeat
   TestAssert "asyncJobs lists none but those", tOurs

   put true into tAllDone
   put true into tAllRight
   repeat for each key tJob in tJobs
      put tAllDone and jobIsDone(tJob) into tAllDone
      put tAllRight and url ("binfile:" & sFolder & "/many-" & tJobs[tJob] & ".txt") is "file" && tJobs[tJob] into tAllRight
   end repeat
   TestAssert "every one of 60 jobs sends its message once", tAllDone
   TestAssert "and wrote its own file", tAllRight
   TestAssert "none is left", asyncJobs() is empty
end TestManyJobs

on TestMessageWaitsForMessages
   -- a job's message is a pending message: it does not interrupt a
   -- handler, and comes where one sent "in 0" would
   local tJob
   put asyncWriteFile(sFolder & "/waited.txt", "x", "jobDone") into tJob
   wait 300 milliseconds
   TestAssert "the job is done while the script waits", url ("binfile:" & sFolder & "/waited.txt") is "x"
   TestAssert "but its message does not come in a wait without messages", sDone[tJob] is empty
   wait 0 milliseconds with messages
   TestAssert "it comes in a wait with messages", sDone[tJob]["times"] is 1
end TestMessageWaitsForMessages

on TestMessageGoesToCaller
   -- the message goes to the object whose script started the job
   local tJob
   create invisible stack "AsyncJobsOtherObject"
   set the script of stack "AsyncJobsOtherObject" to \
         "local sGot" & return & \
         "function startJob pPath" & return & \
         "return asyncReadFile(pPath, " & quote & "otherDone" & quote & ")" & return & \
         "end startJob" & return & \
         "on otherDone pJob, pResult" & return & \
         "put pJob & comma & pResult into sGot" & return & \
         "end otherDone" & return & \
         "function whatCame" & return & \
         "return sGot" & return & \
         "end whatCame"
   put "to the other" into url ("binfile:" & sFolder & "/other.txt")

   local tUntil, tGot
   put value("startJob(" & quote & sFolder & "/other.txt" & quote & ")", stack "AsyncJobsOtherObject") into tJob
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while tGot is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
      put value("whatCame()", stack "AsyncJobsOtherObject") into tGot
   end repeat
   TestAssert "the object that started the job gets its message", tGot is tJob & comma & "to the other"
   TestAssert "and no other does", sDone[tJob] is empty

   -- an object that is deleted before its job is done gets nothing, and
   -- nothing goes wrong
   put value("startJob(" & quote & sFolder & "/other.txt" & quote & ")", stack "AsyncJobsOtherObject") into tJob
   delete stack "AsyncJobsOtherObject"
   wait 300 milliseconds with messages
   TestAssert "a job outlives the object that started it", asyncStatus(tJob) is empty and asyncJobs() is empty
end TestMessageGoesToCaller

on TestCancelFileJob
   local tBytes, tJobs, tJob, tCancelled, tAllDone

   if the platform is "HTML5" then
      -- a page has no threads: a file job is over before the call that
      -- started it returns, so there is never one to cancel
      put asyncWriteFile(sFolder & "/at-once.bin", "x", "jobDone") into tJob
      asyncCancel tJob
      TestAssert "in a browser a file job is over when the call returns", the result is "no such job"
      TestAssert "its message comes all the same, with no error", jobIsDone(tJob) and sDone[tJob]["error"] is empty
      TestAssert "and its file is written", url ("binfile:" & sFolder & "/at-once.bin") is "x"
      exit TestCancelFileJob
   end if

   -- jobs that wait behind others are cancelled before they run
   put someBytes(4000000) into tBytes
   repeat with tIndex = 1 to 24
      put asyncWriteFile(sFolder & "/cancel-" & tIndex & ".bin", tBytes, "jobDone") into tJob
      put tJob & return after tJobs
   end repeat
   repeat for each line tJob in tJobs
      asyncCancel tJob
   end repeat

   put true into tAllDone
   put 0 into tCancelled
   repeat for each line tJob in tJobs
      put tAllDone and jobIsDone(tJob) into tAllDone
      if sDone[tJob]["error"] is "cancelled" then
         add 1 to tCancelled
      else if sDone[tJob]["error"] is not empty then
         put false into tAllDone
      end if
   end repeat
   TestAssert "every cancelled job still sends its message, with cancelled or done", tAllDone
   TestAssert "most of 24 large writes were stopped", tCancelled >= 12

   asyncCancel line 1 of tJobs
   TestAssert "cancelling a job that is over says so", the result is "no such job"
   asyncCancel empty
   TestAssert "as does cancelling no job at all", the result is "no such job"
   asyncCancel "not a number"
   TestAssert "or something that is no number", the result is "no such job"
   TestAssert "none of which has a status", asyncStatus(empty) is empty and asyncProgress("x") is empty
end TestCancelFileJob

on TestWrongCalls
   TestAssertThrow "a job with no message to send is refused", \
         "ReadWithNoMessage", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "a program with no name is refused", \
         "OpenNoProgram", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "arguments that are not a list are refused", \
         "OpenWithBadArguments", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssert "and none of them left a job", asyncJobs() is empty
end TestWrongCalls

on ReadWithNoMessage
   get asyncReadFile(sFolder & "/x", empty)
end ReadWithNoMessage

on OpenNoProgram
   get asyncProcessOpen(empty, empty, "programSaid")
end OpenNoProgram

on OpenWithBadArguments
   local tArguments
   put "a" into tArguments["first"]
   get asyncProcessOpen("sort", tArguments, "programSaid")
end OpenWithBadArguments

----------------------------------------------------------------
-- Where no program can be run
----------------------------------------------------------------

on TestNoPrograms
   -- an Android app and a page in a browser can start no other program
   -- (shell() fails there too): the call is not an error, the job's message
   -- says so
   TestSkipIf "shell"

   local tJob
   put asyncShell("echo x", "jobDone") into tJob
   TestAssert "a command that cannot run still sends its message", jobIsDone(tJob)
   TestAssert "which says why", sDone[tJob]["error"] is "not supported" and sDone[tJob]["result"] is empty

   put asyncProcessOpen("sort", empty, "programSaid") into tJob
   TestAssert "a program that cannot run fails", lastEventOf(tJob) is "failed"
   TestAssert "with the same reason, and no other event", \
         sEvents[tJob][1]["data"] is "not supported" and the number of elements of sEvents[tJob] is 1
   TestAssert "and neither is left", asyncJobs() is empty
end TestNoPrograms

----------------------------------------------------------------
-- Shell commands
----------------------------------------------------------------

on TestShell
   TestSkipIfNot "shell"

   local tJob, tExpected
   repeat for each item tCommand in "echo hello,echo one && echo two,echo to-error 1>&2"
      put shell(tCommand) into tExpected
      put asyncShell(tCommand, "jobDone") into tJob
      TestAssert "the message of" && quote & tCommand & quote && "comes", jobIsDone(tJob)
      TestAssert "with what shell() returns", sDone[tJob]["result"] is tExpected and tExpected is not empty
      TestAssert "no error, and the exit code 0", sDone[tJob]["error"] is empty and sDone[tJob]["code"] is 0
   end repeat

   put asyncShell("exit 3", "jobDone") into tJob
   TestAssert "a command that fails still ran", jobIsDone(tJob) and sDone[tJob]["error"] is empty
   TestAssert "and its exit code is the fourth parameter", sDone[tJob]["code"] is 3

   put asyncShell("oxt-no-such-command-anywhere", "jobDone") into tJob
   TestAssert "a command the shell does not know is the shell's to report", \
         jobIsDone(tJob) and sDone[tJob]["error"] is empty and sDone[tJob]["code"] is not 0
end TestShell

on TestShellDoesNotBlock
   TestSkipIfNot "shell"

   -- a command that takes two seconds: the call returns at once, and the
   -- stack's own messages go on while it runs
   local tCommand, tJob, tStarted, tReturned, tBeatsBefore
   if the platform is "Win32" then
      put "ping -n 3 127.0.0.1 >nul" into tCommand
   else
      put "sleep 2" into tCommand
   end if

   put 0 into sDone["beats"]
   send "heartBeat" to me in 20 milliseconds
   put the milliseconds into tStarted
   put asyncShell(tCommand, "jobDone") into tJob
   put the milliseconds - tStarted into tReturned
   TestAssert "asyncShell returns before the command ends", tReturned < 1000
   TestAssert "the job is running", asyncStatus(tJob) is "running" and tJob is among the lines of asyncJobs()

   TestAssert "the command's message comes", jobIsDone(tJob)
   TestAssert "after the time the command took", the milliseconds - tStarted >= 1500
   TestAssert "and the stack's own messages ran meanwhile", sDone["beats"] >= 20
   put "stop" into sDone["beats"]
end TestShellDoesNotBlock

on heartBeat
   if sDone["beats"] is "stop" then
      exit heartBeat
   end if
   add 1 to sDone["beats"]
   send "heartBeat" to me in 20 milliseconds
end heartBeat

on TestShellCancel
   TestSkipIfNot "shell"

   local tCommand, tJob, tStarted
   if the platform is "Win32" then
      put "echo started && ping -n 60 127.0.0.1 >nul" into tCommand
   else
      put "echo started; sleep 60" into tCommand
   end if
   put asyncShell(tCommand, "jobDone") into tJob
   wait 500 milliseconds with messages
   put the milliseconds into tStarted
   asyncCancel tJob
   TestAssert "a running command is cancelled", the result is empty
   TestAssert "its message comes", jobIsDone(tJob)
   TestAssert "at once, not when the command would have ended", the milliseconds - tStarted < 10000
   TestAssert "with cancelled", sDone[tJob]["error"] is "cancelled"
   TestAssert "and what the command had written", word 1 of sDone[tJob]["result"] is "started"
end TestShellCancel

----------------------------------------------------------------
-- Programs
----------------------------------------------------------------

on TestProcess
   TestSkipIfNot "shell"

   -- sort is a program of every desktop system, and reads its input to
   -- the end before it writes
   local tJob, tOutput
   put asyncProcessOpen("sort", empty, "programSaid") into tJob
   TestAssert "a program has a job", tJob is an integer and tJob > 0
   TestAssert "which is running", asyncStatus(tJob) is "running"
   asyncProcessWrite tJob, "pear" & return
   TestAssert "it is sent input", the result is empty
   asyncProcessWrite tJob, "apple" & return & "melon" & return
   asyncProcessCloseInput tJob
   TestAssert "its input is ended", the result is empty
   asyncProcessWrite tJob, "late" & return
   TestAssert "after which there is nowhere to write", the result is "not running"

   TestAssert "the program ends", lastEventOf(tJob) is "exit"
   put outputOf(tJob, "output") into tOutput
   replace numToByte(13) with empty in tOutput
   TestAssert "having written its output", tOutput is "apple" & numToByte(10) & "melon" & numToByte(10) & "pear" & numToByte(10)
   TestAssert "with the exit code 0", sEvents[tJob][the number of elements of sEvents[tJob]]["code"] is 0
   TestAssert "each message has four parameters", sEvents[tJob][1]["parameters"] is 4

   asyncProcessWrite tJob, "x"
   TestAssert "a program that has ended is not written to", the result is "not running"
   asyncProcessCloseInput tJob
   TestAssert "nor has it an input to end", the result is "not running"
   TestAssert "and it is not among the jobs", asyncJobs() is empty
end TestProcess

on TestProcessArguments
   TestSkipIfNot "platform", "MacOS,Linux"

   -- each argument reaches the program as it is given: spaces, quotes,
   -- an empty one, and characters a shell would act on
   local tArguments, tJob, tExpected
   put "-c" into tArguments[1]
   put "printf '[%s]' " & quote & "$@" & quote & "; echo to-error 1>&2; exit 5" into tArguments[2]
   put "name" into tArguments[3]
   put "two words" into tArguments[4]
   put empty into tArguments[5]
   put "a" & quote & "b" into tArguments[6]
   put "$HOME;*" into tArguments[7]
   put 12 into tArguments[8]
   put asyncProcessOpen("/bin/sh", tArguments, "programSaid") into tJob
   TestAssert "the program ends", lastEventOf(tJob) is "exit"
   put "[two words][][a" & quote & "b][$HOME;*][12]" into tExpected
   TestAssert "an array's elements are the arguments, as they are", outputOf(tJob, "output") is tExpected
   TestAssert "the error output comes apart from the output", outputOf(tJob, "error") is "to-error" & numToByte(10)
   TestAssert "the exit code comes with the last event", sEvents[tJob][the number of elements of sEvents[tJob]]["code"] is 5

   put asyncProcessOpen("/bin/sh", "-c" & return & "printf '[%s]' " & quote & "$@" & quote & return & "name" & return & "one" & return & "two words" & return, "programSaid") into tJob
   TestAssert "a program given its arguments as lines ends", lastEventOf(tJob) is "exit"
   TestAssert "with an argument for each line", outputOf(tJob, "output") is "[one][two words]"
end TestProcessArguments

on TestProcessFails
   TestSkipIfNot "shell"

   local tJob
   put asyncProcessOpen("oxt-no-such-program-anywhere", empty, "programSaid") into tJob
   TestAssert "a program that is not there still has a job", tJob is an integer and tJob > 0
   TestAssert "whose one message says it failed", lastEventOf(tJob) is "failed" and the number of elements of sEvents[tJob] is 1
   TestAssert "and why", sEvents[tJob][1]["data"] is "can't run program"
   TestAssert "with the system's code", sEvents[tJob][1]["code"] is an integer and sEvents[tJob][1]["code"] > 0

   put asyncProcessOpen(sFolder & "/no/such/program", empty, "programSaid") into tJob
   TestAssert "nor is one at a path that is not there", lastEventOf(tJob) is "failed"
end TestProcessFails

on TestProcessCancel
   TestSkipIfNot "shell"

   -- sort waits for input that never ends
   local tJob, tStarted
   put asyncProcessOpen("sort", empty, "programSaid") into tJob
   wait 200 milliseconds with messages
   put the milliseconds into tStarted
   asyncCancel tJob
   TestAssert "a running program is cancelled", the result is empty
   TestAssert "its last message says so", lastEventOf(tJob) is "cancelled"
   TestAssert "at once", the milliseconds - tStarted < 10000
   asyncCancel tJob
   TestAssert "and it is not there to cancel again", the result is "no such job"
end TestProcessCancel
