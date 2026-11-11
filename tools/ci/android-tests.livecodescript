script "OXTAndroidTests"
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

-- The script of the main stack of the Android standalone that
-- tools/ci/android_tests.py builds (through the IDE's builder, as
-- android_check.py ide --probe tests) to run the LiveCode Script tests of
-- tests/lcs on an Android device or emulator. It runs them as
-- tools/ci/web-tests.livecodescript runs them in the web engine, and as
-- tests/_standalonetestrunner/StandaloneTestRunner.livecodescript runs them
-- in a standalone: one test command after the other in this engine, with
-- the test runner's behavior (tests/_testrunnerbehavior), so that each
-- test gets the same set-up, tear-down and clean-up as in a test run on
-- the desktop, where each runs in an engine of its own.
--
-- The stack is named StandaloneTestRunnerMainstack, as LiveCode's, which
-- is how the test library knows that it runs in a standalone
-- (TestIsInStandalone): tests that need the IDE, the documentation or the
-- LiveCode Builder compiler skip there.
--
-- The package has, in its copy files (specialFolderPath("engine")):
--    oxt-tests/            the tests and what they read from the checkout
--                          (android_tests.py prepare), with
--       android-tests.txt  the tests to run, one a line: the test file
--                          (a path in oxt-tests), a tab, the test command
--       files.txt          every file of oxt-tests, one path a line
--    packaged_extensions/  the extensions that the tests load, where the
--                          test library looks for them (TestLoadExtension
--                          walks up from specialFolderPath("engine"))
-- The files of oxt-tests are copied once into the app's own documents
-- folder (specialFolderPath("documents")/oxt-tests), and the tests run from
-- there: as in a checkout on the desktop, a test can write beside itself,
-- and a folder lists its files and its folders (a package's copy files
-- are read in place, and are read-only).
--
-- Every line of the run goes to the device's log as an engine log line
-- (a put with no container: tag LiveCode), which android_tests.py reads:
--
--    OXTTESTS COUNT <number of tests>
--    OXTTESTS RESUME <line>                after a restart: the last test
--                                          that began (see below)
--    OXTTESTS BEGIN <line>                 before a test
--    OXTTESTS TAP <line> <n> <TAP line>    each line of its output, n its
--                                          place there (the log folds lines
--                                          that are the same)
--    OXTTESTS QUIT <line>                  the test quit (see below)
--    OXTTESTS DONE <line>                  after it
--    OXTTESTS END                          after the last
--    OXTTESTS ERROR <what>                 the run cannot go on
--
-- Before each test the runner writes its line into
-- oxt-tests-progress.txt in the documents folder. When a test stops the
-- engine (a crash), or never ends and android_tests.py stops the app,
-- android_tests.py starts the app again, and the runner goes on with the
-- test after the one in that file. A new install starts with no file, at
-- the first test.
--
-- A test that quits would end the engine, and with it the run: the test
-- library quits when it cannot load an extension (TestLoadExtension), and
-- in a desktop run each test has an engine of its own. A backscript
-- cancels the quit instead (its shutdownRequest handler does not pass it,
-- which the quit command asks first) and says so, and the test goes on.
-- Should a quit end the app anyway, the run goes on after it as after a
-- crash.

constant kPrefix = "OXTTESTS"
constant kFolder = "oxt-tests"
constant kProgressFile = "oxt-tests-progress.txt"
constant kCopiedFile = "copied.txt"

local sStarted
local sTests
local sIndex
local sRoot

on openStack
   -- only in the app: not as the IDE makes and builds the stack
   if sStarted is true or the environment is not "mobile" then
      pass openStack
   end if
   put true into sStarted
   set the backgroundColor of me to "31,158,90"
   -- after openStack, so that the stack is on the screen and the engine
   -- is idle when the first test starts
   send "androidTestsStart" to me in 100 milliseconds
end openStack

-- A line to the device's log
private command androidSay pLine
   put kPrefix && pLine
end androidSay

on androidTestsStart
   local tError
   put specialFolderPath("documents") & slash & kFolder into sRoot
   put androidCopyTests(specialFolderPath("engine") & slash & kFolder, sRoot) into tError
   if tError is not empty then
      androidSay "ERROR" && tError
      exit androidTestsStart
   end if

   -- The test runner's behavior, as tests/_testrunner.livecodescript sets
   -- it, and the libraries a test command needs (_testlib and _inputlib)
   try
      set the behavior of me to the long id of stack (sRoot & "/tests/_testrunnerbehavior.livecodescript")
      TestRunnerInvokeLoadLibraries
      TestOutputToVariable
   catch tError
      androidSay "ERROR the test runner's behavior and libraries do not load:" && line 1 of tError
      exit androidTestsStart
   end try

   -- The backscript that cancels a quit, in a button of this stack that
   -- nobody sees
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to the short name of me
   create invisible button "AndroidTestsQuit"
   set the script of it to "on shutdownRequest" & return & \
         "   put" && quote & kPrefix && "QUIT " & quote & " & the uIndex of me" & return & \
         "end shutdownRequest"
   insert the script of it into back
   set the defaultStack to tDefault

   put url ("file:" & sRoot & "/android-tests.txt") into sTests
   if the last char of sTests is return then
      delete the last char of sTests
   end if
   androidSay "COUNT" && the number of lines of sTests

   -- after a restart: the test after the last one that began
   local tProgress, tLast
   put specialFolderPath("documents") & slash & kProgressFile into tProgress
   put 1 into sIndex
   if there is a file tProgress then
      put word 1 of url ("file:" & tProgress) into tLast
      if tLast is an integer and tLast >= 1 then
         androidSay "RESUME" && tLast
         put tLast + 1 into sIndex
      end if
   end if
   send "androidTestsNext" to me in 0 milliseconds
end androidTestsStart

-- Copies the files that files.txt in pFrom names into pTo, once: empty, or
-- what went wrong
private function androidCopyTests pFrom, pTo
   local tList, tPath, tFolder, tData, i
   if there is a file (pTo & slash & kCopiedFile) then
      return empty
   end if
   put url ("file:" & pFrom & "/files.txt") into tList
   if tList is empty then
      return "the package has no" && kFolder & "/files.txt"
   end if
   set the itemDelimiter to slash
   repeat for each line tPath in tList
      if tPath is empty then
         next repeat
      end if
      put pTo into tFolder
      androidEnsureFolder tFolder
      repeat with i = 1 to the number of items of tPath - 1
         put slash & item i of tPath after tFolder
         androidEnsureFolder tFolder
      end repeat
      put url ("binfile:" & pFrom & slash & tPath) into tData
      if the result is not empty then
         return "cannot read" && kFolder & slash & tPath && "in the package:" && the result
      end if
      put tData into url ("binfile:" & pTo & slash & tPath)
      if the result is not empty then
         return "cannot write" && pTo & slash & tPath & ":" && the result
      end if
   end repeat
   put the number of lines of tList into url ("file:" & pTo & slash & kCopiedFile)
   return empty
end androidCopyTests

private command androidEnsureFolder pFolder
   if there is no folder pFolder then
      create folder pFolder
   end if
end androidEnsureFolder

on androidTestsNext
   if sIndex > the number of lines of sTests then
      androidSay "END"
      exit androidTestsNext
   end if

   local tFile, tCommand, tOutput, tLine, tError, tPlace
   set the itemDelimiter to tab
   put sRoot & slash & item 1 of line sIndex of sTests into tFile
   put item 2 of line sIndex of sTests into tCommand
   put sIndex into url ("file:" & specialFolderPath("documents") & slash & kProgressFile)
   set the uIndex of button "AndroidTestsQuit" of me to sIndex
   androidSay "BEGIN" && sIndex

   try
      TestRunnerInvokeTestCommand tFile, tCommand
   catch tError
      TestAssert "run the test command", false
      TestDiagnostic tError
   end try

   -- The test's TAP output
   put TestFetchAndClearOutput() into tOutput
   replace numToChar(13) with numToChar(10) in tOutput
   put 0 into tPlace
   repeat for each line tLine in tOutput
      add 1 to tPlace
      androidSay "TAP" && sIndex && tPlace && tLine
   end repeat
   androidSay "DONE" && sIndex

   add 1 to sIndex
   send "androidTestsNext" to me in 0 milliseconds
end androidTestsNext
