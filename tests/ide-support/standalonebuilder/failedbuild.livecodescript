script "StandaloneBuilderFailedBuild"
-- OXT-Beyond: a standalone build that stops on an error leaves the stack
-- as it was (openxtalk.org p=26321, tperry2x: now and then a stack "gets
-- a copy of the IDE's Answer and Ask stack embedded in it").
--
-- For each target the builder changes the stack in memory
-- (revCopyResources in ide-support/revsaveasstandalone.livecodescript):
-- the IDE's Answer, Ask and print dialogs become its substacks, its
-- standalone settings and development properties are taken off, and it is
-- saved into the build folder, which gives it that file's name. Only the
-- end of a target's build put it back. A build that stopped in between
-- left the changed stack in memory, closed, and it was opened again as
-- the stack being worked on: up to 0.2.8-dp.1 with the dialogs in it,
-- without its standalone settings, under the build folder's file name or,
-- when the build's copy could not be written, under its own, so that the
-- next Save wrote the dialogs into the stack's file.
--
-- The build is stopped here by a front script on revStandaloneProgress,
-- the command the builder reports each of its steps with, at three of
-- them: with the stack changed and still open ("Copying icons..."), with
-- it changed and closed under its own file name ("Saving stack
-- files..."), and with it saved into the build folder ("Copying
-- files..."). No engine is attached in those, so they run wherever the
-- IDE does.
--
-- One way a build stopped there by itself: a stack file whose extension
-- the IDE takes for a stack's and the builder's save did not (.mc, .lc,
-- .stk, .oxtscript). revStandalonePreBuild kept the name, revSaveToFolder
-- saved it with ".oxtstack" added, and the steps after looked for a stack
-- that was not there (error 91 in revCopyExternals). Such a stack builds
-- now, and runs.

constant kHolder = "StandaloneBuilderFailedBuildHolder"
constant kStopped = "the test stopped the build at"
constant kMarker = "as it was"

local sSupportStack, sDialogs, sWasTestEnvironment

on TestSetup
   start using stack "revSBLibrary"

   set the itemdelimiter to slash
   local tSupportStack
   put the filename of me into tSupportStack
   put "_support.livecodescript" into item -1 of tSupportStack
   put tSupportStack into sSupportStack
   start using stack sSupportStack

   -- the builder's own error dialog is not wanted (revSBSuppressDialogs);
   -- any other dialog the IDE opens is noted and answered (watchDialogs)
   put revTestEnvironment() into sWasTestEnvironment
   revSetTestEnvironment true
   put empty into sDialogs
   send "watchDialogs" to me in 300 milliseconds
end TestSetup

on TestTeardown
   local tMessage
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "watchDialogs" then
         cancel item 1 of tMessage
      end if
   end repeat
   stopBuildAt empty
   revSetTestEnvironment sWasTestEnvironment
   if there is a stack kHolder then
      delete stack kHolder
   end if
   StandaloneBuilderCleanUpStandalones
   stop using stack sSupportStack
end TestTeardown

--------------------------------------------------------------------------------
-- Helpers

-- (sent) An Answer Dialog that is open, the IDE's or a copy of it that is
-- a substack of another stack, has its text noted and its OK pressed: up
-- to 0.2.8-dp.1 the IDE warned 'A stack "Answer Dialog" is already in
-- memory' when the changed stack was opened again, and that would keep
-- this test waiting
on watchDialogs
   local tMain, tRefs, tRef, tText, i
   repeat for each line tMain in the mainStacks
      if tMain is "Answer Dialog" then
         put the long id of stack tMain & return after tRefs
      else if "Answer Dialog" is among the lines of the substacks of stack tMain then
         put the long id of stack "Answer Dialog" of stack tMain & return after tRefs
      end if
   end repeat
   repeat for each line tRef in tRefs
      if the mode of tRef is 0 then next repeat
      put empty into tText
      repeat with i = 1 to the number of fields of card 1 of tRef
         put the text of field i of card 1 of tRef & space after tText
      end repeat
      replace return with space in tText
      put tText & return after sDialogs
      if there is a button "OK" of card 1 of tRef then
         send "mouseUp" to button "OK" of card 1 of tRef
      else
         close tRef
      end if
   end repeat
   send "watchDialogs" to me in 300 milliseconds
end watchDialogs

-- Stops the next build when the builder reports the step pStep, with an
-- error that names it; empty takes the front script out again
private command stopBuildAt pStep
   local tDefault
   if there is a stack kHolder then
      try
         remove the script of button "front" of stack kHolder from front
      end try
   end if
   if pStep is empty then
      exit stopBuildAt
   end if
   put the defaultStack into tDefault
   if there is not a stack kHolder then
      create invisible stack kHolder
      set the defaultStack to kHolder
      create button "front"
   end if
   set the script of button "front" of stack kHolder to \
         "on revStandaloneProgress pStep" & return & \
         "if pStep is" && quote & pStep & quote && "then" & return & \
         "throw" && quote & kStopped && pStep & quote & return & \
         "end if" & return & \
         "pass revStandaloneProgress" & return & \
         "end revStandaloneProgress"
   insert the script of button "front" of stack kHolder into front
   set the defaultStack to tDefault
end stopBuildAt

-- A folder of this test's own, next to it, empty
private function workFolder pName
   local tFolder
   set the itemdelimiter to slash
   put item 1 to -2 of the filename of me & slash & pName into tFolder
   if there is a folder tFolder then
      revDeleteFolder tFolder
   end if
   create folder tFolder
   return tFolder
end workFolder

-- A stack as a person has one: saved in pFile, open, set to build for
-- this computer's platform, with a script that uses answer and ask, so
-- that the builder, which looks for what a stack needs, puts both dialogs
-- into its copy on every platform
private command makeStack pName, pFile
   local tTarget
   create stack pName
   set the defaultStack to pName
   create button "Ask"
   set the script of button "Ask" of stack pName to \
         "on mouseUp" & return & \
         "ask" && quote & "Your name?" & quote & return & \
         "answer" && quote & "Hello" & quote && "& it" & return & \
         "end mouseUp"
   set the script of stack pName to \
         "on startup" & return & \
         "quit 0" & return & \
         "end startup"
   set the cFailedBuildMarker of stack pName to kMarker
   set the cRevStandaloneSettings["name"] of stack pName to pName
   repeat for each item tTarget in revSBDesktopTargets()
      set the cRevStandaloneSettings[tTarget] of stack pName to (tTarget is GetBuildPlatform())
   end repeat
   set the filename of stack pName to pFile
   save stack pName as pFile
   revIDESaveStack the long id of stack pName
   go stack pName
end makeStack

-- What a build must leave as it found it, as lines: the stack's file
-- name, its substacks, whether it is open, a property of its own and its
-- standalone settings
private function stackState pName
   local tState, tSubstacks, tSettingsA, tKeys, tKey
   if there is not a stack pName then
      return "no stack" && pName
   end if
   put the substacks of stack pName into tSubstacks
   replace return with comma in tSubstacks
   put "file name:" && the filename of stack pName & return & \
         "substacks:" && tSubstacks & return & \
         "open:" && (pName is among the lines of the openStacks) & return & \
         "marker:" && the cFailedBuildMarker of stack pName & return into tState
   put the customProperties["cRevStandaloneSettings"] of stack pName into tSettingsA
   put the keys of tSettingsA into tKeys
   sort lines of tKeys
   repeat for each line tKey in tKeys
      put "setting" && tKey & ":" && tSettingsA[tKey] & return after tState
   end repeat
   return tState
end stackState

-- The copies of the IDE's dialogs in memory: the IDE's own are main
-- stacks, so a substack of one of those names is a copy the builder made
private function dialogCopies
   local tMain, tSub, tCopies
   repeat for each line tMain in the mainStacks
      repeat for each line tSub in the substacks of stack tMain
         if tSub is among the items of "Answer Dialog,Ask Dialog,Print Dialog,Page Setup Dialog" then
            put tSub && "in" && tMain & comma after tCopies
         end if
      end repeat
   end repeat
   return tCopies
end dialogCopies

-- A build of a new stack, stopped at pStep, and the stack after it
private command checkStoppedBuild pName, pStep
   local tFolder, tFile, tBefore, tBytes, tExe, tResult, tAfter, tSaved
   put workFolder("_" & pName) into tFolder
   put tFolder & slash & pName & ".livecode" into tFile
   makeStack pName, tFile
   put stackState(pName) into tBefore
   put url ("binfile:" & tFile) into tBytes
   TestAssert pStep && "the stack is saved and open before the build", \
         there is a file tFile and pName is among the lines of the openStacks \
         and the substacks of stack pName is empty

   put empty into sDialogs
   stopBuildAt pStep
   StandaloneBuilderSaveAsStandalone pName, tExe
   put the result into tResult
   stopBuildAt empty

   -- (the build reached the step and stopped there: a step the builder
   -- no longer reports would let the build finish, and test nothing)
   TestAssert pStep && "the build stopped there", tResult contains (kStopped && pStep)

   put stackState(pName) into tAfter
   if tAfter is not tBefore then
      TestDiagnostic "before the build:" & return & tBefore
      TestDiagnostic "after it:" & return & tAfter
   end if
   TestAssert pStep && "the stack is as it was", tAfter is tBefore
   TestAssert pStep && "no copy of an IDE dialog is left in memory", dialogCopies() is empty
   TestDiagnostic "copies:" && dialogCopies()
   TestAssert pStep && "the stack's file is as it was", url ("binfile:" & tFile) is tBytes
   if sDialogs is not empty then
      TestDiagnostic "dialogs:" && sDialogs
   end if
   TestAssert pStep && "the IDE asked nothing", sDialogs is empty

   -- what a person does next: save
   if there is a stack pName then
      revIDESaveStack the long id of stack pName
   end if
   put url ("binfile:" & tFile) into tSaved
   TestAssert pStep && "a save after it writes no dialog into the stack's file", \
         not (tSaved contains "Answer Dialog") and not (tSaved contains "Ask Dialog")
   TestAssert pStep && "and the stack is still as it was", stackState(pName) is tBefore

   if there is a stack pName then
      delete stack pName
   end if
   revDeleteFolder tFolder
end checkStoppedBuild

-- A build of a new stack saved in a file with the extension pExtension:
-- it makes a standalone, the standalone runs, and the stack is as it was
private command checkBuildWithExtension pExtension
   local tName, tFolder, tFile, tBefore, tBytes, tExe, tResult, tAfter, tCommand
   put "FailedBuild" & pExtension into tName
   put workFolder("_" & tName) into tFolder
   put tFolder & slash & tName & "." & pExtension into tFile
   makeStack tName, tFile
   put stackState(tName) into tBefore
   put url ("binfile:" & tFile) into tBytes

   put empty into sDialogs
   StandaloneBuilderSaveAsStandalone tName, tExe
   put the result into tResult

   if tResult is not empty then
      TestDiagnostic "the build of" && tFile && "said:" && tResult
   end if
   TestAssert "a stack file ." & pExtension && "builds", tResult is empty
   TestAssert "a stack file ." & pExtension && "makes a standalone", tExe is not empty and there is a file tExe
   put stackState(tName) into tAfter
   if tAfter is not tBefore then
      TestDiagnostic "before the build:" & return & tBefore
      TestDiagnostic "after it:" & return & tAfter
   end if
   TestAssert "a stack file ." & pExtension && "is as it was after the build", tAfter is tBefore
   TestAssert "a stack file ." & pExtension && "leaves no copy of an IDE dialog in memory", dialogCopies() is empty
   TestAssert "a stack file ." & pExtension && "is the same file after the build", url ("binfile:" & tFile) is tBytes
   if sDialogs is not empty then
      TestDiagnostic "dialogs:" && sDialogs
   end if
   TestAssert "a stack file ." & pExtension && ": the IDE asked nothing", sDialogs is empty

   -- the stack quits with status 0 when it starts up
   if tExe is not empty and there is a file tExe then
      put quote & tExe & quote into tCommand
      if the environment contains "command line" then
         put " -ui" after tCommand
      end if
      get shell(tCommand)
      put the result into tResult
      if tResult is not empty then
         TestDiagnostic "the standalone ended with" && tResult & ":" && it
      end if
      TestAssert "a stack file ." & pExtension && ": its standalone runs", tResult is empty
   end if

   if there is a stack tName then
      delete stack tName
   end if
   revDeleteFolder tFolder
end checkBuildWithExtension

--------------------------------------------------------------------------------
-- Tests

-- The build stops with the IDE's dialogs in the stack and the stack still
-- open, as the builder has it while it changes it. (This one was right
-- before: revCleanBuildStacks takes an open stack out of memory.)
on TestBuildStoppedWhileStackIsOpen
   checkStoppedBuild "FailedBuildOpen", "Copying icons..."
end TestBuildStoppedWhileStackIsOpen

-- The build stops with the stack changed and closed, before its copy is
-- written into the build folder: what a copy that cannot be written (a
-- full disk, a path too long) came to. The stack kept its own file name,
-- so the next Save put the dialogs into its file
on TestBuildStoppedBeforeCopyIsSaved
   checkStoppedBuild "FailedBuildClosed", "Saving stack files..."
end TestBuildStoppedBeforeCopyIsSaved

-- The build stops with the stack saved into the build folder, before the
-- engine is attached: the stack that was opened again was the build's copy
on TestBuildStoppedAfterCopyIsSaved
   checkStoppedBuild "FailedBuildSaved", "Copying files..."
end TestBuildStoppedAfterCopyIsSaved

-- The extensions the IDE takes for a stack's (revIDEAcceptedTypes) that
-- the builder's save did not: such a stack file builds
on TestBuildOfMcStackFile
   checkBuildWithExtension "mc"
end TestBuildOfMcStackFile

on TestBuildOfLcStackFile
   checkBuildWithExtension "lc"
end TestBuildOfLcStackFile

on TestBuildOfStkStackFile
   checkBuildWithExtension "stk"
end TestBuildOfStkStackFile

on TestBuildOfOxtscriptStackFile
   checkBuildWithExtension "oxtscript"
end TestBuildOfOxtscriptStackFile

-- And the ones both took, which built before and build the same
on TestBuildOfOxtstackStackFile
   checkBuildWithExtension "oxtstack"
end TestBuildOfOxtstackStackFile

on TestBuildOfLivecodeStackFile
   checkBuildWithExtension "livecode"
end TestBuildOfLivecodeStackFile
