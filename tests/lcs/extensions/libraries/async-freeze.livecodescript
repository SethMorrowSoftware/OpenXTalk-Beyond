script "TestBackgroundJobsFreezeMeter"
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

-- The freeze meter: for how long a stack's own messages stop while
-- something slow is done the old way, with a call that blocks, and the new
-- way, as a job of the Background Jobs library.
--
-- A heart beats every few milliseconds: a message this stack sends itself,
-- as a progress bar, an animation or a "Cancel" button's handler would
-- need. The longest time between two beats is the freeze a user would
-- see. Each test writes both numbers to its output as a diagnostic that
-- begins "freeze meter", so the log of every run has them for its platform
-- (tools/ci/run_engine_tests.py --output keeps the whole of it).
--
-- What is asserted is far from either number, because the times are a
-- machine's and a busy one's at that: only that the blocking call froze
-- the stack for about as long as it took, where that is known, and that
-- the job did not.

-- A folder of this test's own
local sFolder
-- The jobs whose message has come
local sDone
-- The heart: whether it goes on, its pending message, when it last beat,
-- the longest time between two beats and how many there were
local sBeating
local sBeatMessage
local sLastBeat
local sLongest
local sBeats

constant kBeatMilliseconds = 5
constant kWaitSeconds = 120
-- The longest that a stack may stop for while a job runs. A beat is due
-- every 5 milliseconds; the test machines of CI stall for far longer than
-- that by themselves, and not for this long.
constant kFreezeLimit = 1000

on TestSetup
   TestSkipIfNot "extension", "org.openxtalk.library.async"
   TestLoadExtension "org.openxtalk.library.async"

   put empty into sDone
   put false into sBeating
   put specialFolderPath("temporary") & "/oxt-freeze-meter-" & the milliseconds & "-" & random(1000000) into sFolder
   create folder sFolder
end TestSetup

on TestTearDown
   local tJobs
   get stopHeart()
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
-- The heart
----------------------------------------------------------------

on heartBeat
   if not sBeating then
      exit heartBeat
   end if
   local tNow
   put the milliseconds into tNow
   put max(sLongest, tNow - sLastBeat) into sLongest
   put tNow into sLastBeat
   add 1 to sBeats
   send "heartBeat" to me in kBeatMilliseconds milliseconds
   put the result into sBeatMessage
end heartBeat

private command startHeart
   get stopHeart()
   put true into sBeating
   put 0 into sLongest
   put 0 into sBeats
   put the milliseconds into sLastBeat
   send "heartBeat" to me in kBeatMilliseconds milliseconds
   put the result into sBeatMessage
   -- going before anything is measured
   wait 50 milliseconds with messages
end startHeart

-- Stop the heart. The longest time it stopped for, in milliseconds, which
-- counts the time since its last beat: a freeze that has not ended yet.
private function stopHeart
   if not sBeating then
      return 0
   end if
   put false into sBeating
   cancel sBeatMessage
   return max(sLongest, the milliseconds - sLastBeat)
end stopHeart

on jobDone pJob, pResult, pError
   put true into sDone[pJob]["done"]
   put pError into sDone[pJob]["error"]
   put the number of bytes of pResult into sDone[pJob]["size"]
end jobDone

-- Wait for a job's message, with the stack's own messages going on. True
-- if it came, without an error.
private function jobIsDone pJob
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sDone[pJob]["done"] is not true and the milliseconds < tUntil
      wait 2 milliseconds with messages
   end repeat
   return sDone[pJob]["done"] is true and sDone[pJob]["error"] is empty
end jobIsDone

-- The meter's line in the test's output
private command meterSays pWhat, pBlocked, pBackground
   TestDiagnostic "freeze meter:" && pWhat & ": blocking call froze the stack for" && pBlocked && \
         "ms, background job for" && pBackground && "ms (" & the platform && the processor & ")"
end meterSays

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
-- A command that takes two seconds
----------------------------------------------------------------

on TestFreezeOfAShellCommand
   TestSkipIfNot "shell"

   local tCommand, tBlocked, tBackground, tBeats, tJob
   if the platform is "Win32" then
      put "ping -n 3 127.0.0.1 >nul" into tCommand
   else
      put "sleep 2" into tCommand
   end if

   -- the old way: nothing else happens until the command has ended
   startHeart
   get shell(tCommand)
   wait 20 milliseconds with messages
   put stopHeart() into tBlocked

   -- the new way
   startHeart
   put asyncShell(tCommand, "jobDone") into tJob
   TestAssert "the command runs as a job", jobIsDone(tJob)
   put sBeats into tBeats
   put stopHeart() into tBackground

   meterSays "a shell command that takes 2 s", tBlocked, tBackground
   TestAssert "shell() stops the stack's messages for as long as the command takes", tBlocked >= 1500
   TestAssert "asyncShell does not", tBackground < kFreezeLimit
   TestAssert "the stack's messages go on all the while", tBeats >= 40
end TestFreezeOfAShellCommand

----------------------------------------------------------------
-- A large file
----------------------------------------------------------------

on TestFreezeOfALargeFile
   -- (in a browser there are no threads: a file job is done inside the
   -- call that starts it, and freezes the page as the blocking call does)
   TestSkipIf "platform", "HTML5"

   local tBytes, tSize, tPath, tBlocked, tBackground, tJob, tRead
   put 64 * 1024 * 1024 into tSize
   put someBytes(tSize) into tBytes

   -- writing
   put sFolder & "/blocking.bin" into tPath
   startHeart
   put tBytes into url ("binfile:" & tPath)
   wait 20 milliseconds with messages
   put stopHeart() into tBlocked

   startHeart
   put asyncWriteFile(sFolder & "/background.bin", tBytes, "jobDone") into tJob
   TestAssert "the file is written as a job", jobIsDone(tJob)
   put stopHeart() into tBackground
   meterSays "writing a file of 64 MB", tBlocked, tBackground
   TestAssert "the stack's messages go on while a large file is written", tBackground < kFreezeLimit

   -- reading
   startHeart
   put url ("binfile:" & tPath) into tRead
   wait 20 milliseconds with messages
   put stopHeart() into tBlocked
   TestAssert "(the blocking read has the file)", the number of bytes of tRead is tSize
   put empty into tRead

   startHeart
   put asyncReadFile(sFolder & "/background.bin", "jobDone") into tJob
   TestAssert "the file is read as a job", jobIsDone(tJob) and sDone[tJob]["size"] is tSize
   put stopHeart() into tBackground
   meterSays "reading a file of 64 MB", tBlocked, tBackground
   TestAssert "the stack's messages go on while a large file is read", tBackground < kFreezeLimit

   -- copying, which a script could only do by reading and writing
   startHeart
   put url ("binfile:" & tPath) into url ("binfile:" & sFolder & "/blocking-copy.bin")
   wait 20 milliseconds with messages
   put stopHeart() into tBlocked

   startHeart
   put asyncCopyFile(tPath, sFolder & "/background-copy.bin", "jobDone") into tJob
   TestAssert "the file is copied as a job", jobIsDone(tJob)
   put stopHeart() into tBackground
   meterSays "copying a file of 64 MB", tBlocked, tBackground
   TestAssert "the stack's messages go on while a large file is copied", tBackground < kFreezeLimit
end TestFreezeOfALargeFile

----------------------------------------------------------------
-- A folder with many files
----------------------------------------------------------------

-- Every file below a folder, the way a script lists a tree
private function filesBelow pFolder
   local tList, tName
   repeat for each line tName in files(pFolder)
      put pFolder & "/" & tName & return after tList
   end repeat
   repeat for each line tName in folders(pFolder)
      if tName is not ".." and tName is not "." then
         put filesBelow(pFolder & "/" & tName) after tList
      end if
   end repeat
   return tList
end filesBelow

on TestFreezeOfAFolderTree
   TestSkipIf "platform", "HTML5"

   -- 40 folders of 50 files
   local tTree, tFolder, tBlocked, tBackground, tList, tJob, tCount
   put sFolder & "/tree" into tTree
   create folder tTree
   repeat with tFolderIndex = 1 to 40
      put tTree & "/folder-" & tFolderIndex into tFolder
      create folder tFolder
      repeat with tFileIndex = 1 to 50
         put empty into url ("binfile:" & tFolder & "/file-" & tFileIndex & ".txt")
      end repeat
   end repeat

   startHeart
   put filesBelow(tTree) into tList
   wait 20 milliseconds with messages
   put stopHeart() into tBlocked
   TestAssert "(the script's own listing has every file)", the number of lines of tList is 2000

   startHeart
   put asyncListFolder(tTree, true, "jobDone") into tJob
   TestAssert "the tree is listed as a job", jobIsDone(tJob)
   put stopHeart() into tBackground
   meterSays "listing a tree of 2000 files in 40 folders", tBlocked, tBackground
   TestAssert "the stack's messages go on while a tree is listed", tBackground < kFreezeLimit
end TestFreezeOfAFolderTree
