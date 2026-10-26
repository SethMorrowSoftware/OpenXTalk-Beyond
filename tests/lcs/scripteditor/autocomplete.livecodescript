script "TestScriptEditorAutoComplete"
-- OXT-Beyond: tests of the script editor's check of whether an "if" it
-- has just seen needs an "end if" added (autoCompleteIFsAreBalanced, in
-- ide/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript).
-- It removes the handler's /* */ comments first. A "/*" with no "*/" after
-- it (an unclosed comment, or a "*/" earlier in the handler) made that
-- loop run for ever, so typing in such a script hung the IDE (LiveCode bug
-- 22826; OXT DPE carried Mark Wieder's fix for the first case). The scripts
-- whose comments close give the results they gave before the fix.

-- The behavior has syntax that compiles only in the IDE (_internal), so
-- the test compiles the handler on its own, from the behavior's file, as
-- the script of a button
constant kHandler = "autoCompleteIFsAreBalanced"

local sObject

on TestSetup
   local tText, tStart, tEnd
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & "/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript"), "UTF-8") into tText
   put offset(return & "function " & kHandler & " ", tText) into tStart
   put offset(return & "end " & kHandler, tText, tStart) into tEnd
   create stack "TestScriptEditorAutoCompleteStack"
   set the defaultStack to "TestScriptEditorAutoCompleteStack"
   create button "handler"
   put the long id of button "handler" into sObject
   set the script of sObject to char tStart + 1 to tStart + tEnd + length("end " & kHandler) of tText
   TestAssert "the handler compiles", the result is empty and kHandler is in the revAvailableHandlers of sObject
end TestSetup

on TestTeardown
   if there is a stack "TestScriptEditorAutoCompleteStack" then
      delete stack "TestScriptEditorAutoCompleteStack"
   end if
end TestTeardown

-- Whether an "end if" is needed for the "if" on line pLine of pScript, in
-- which "|" stands for a return
private function __Required pScript, pLine
   replace "|" with return in pScript
   dispatch function kHandler to sObject with pLine, pScript
   return the result
end __Required

on TestClosedComments
   -- No comment: the open "if" needs its "end if", a closed one does not
   TestAssert "an open if needs an end if", \
         __Required("on test|   if tX then|end test", 2) is true
   TestAssert "a closed if needs no end if", \
         __Required("on test|   if tX then|   end if|end test", 2) is false
   -- An "end if" inside a closed comment does not count
   TestAssert "an end if in a comment does not close the if", \
         __Required("on test|   if tX then|   /* end if */|end test", 2) is true
   TestAssert "an end if after a comment closes the if", \
         __Required("on test|   if tX then|   /* a comment */|   end if|end test", 2) is false
   TestAssert "two comments are both removed", \
         __Required("on test|   if tX then|   /* end if */ /* end if */|end test", 2) is true
end TestClosedComments

on TestUnclosedComment
   -- These ran for ever before the fix; the unclosed comment runs to the
   -- end of the handler, so an "end if" after it does not count
   TestAssert "an unclosed comment returns", \
         __Required("on test|   if tX then|   /* not closed|end test", 2) is true
   TestAssert "an end if in an unclosed comment does not close the if", \
         __Required("on test|   if tX then|   /* not closed|   end if|end test", 2) is true
   TestAssert "a closed if before an unclosed comment needs no end if", \
         __Required("on test|   if tX then|   end if|   /* not closed|end test", 2) is false
end TestUnclosedComment

on TestEndMarkBeforeComment
   -- A "*/" before the "/*" (here in a string) ran for ever too
   TestAssert "a */ before the comment returns", \
         __Required("on test|   put " & quote & "*/" & quote & " into tX|   if tX then|   /* end if */|end test", 3) is true
   TestAssert "a */ before the comment: the comment is still removed", \
         __Required("on test|   put " & quote & "*/" & quote & " into tX|   if tX then|   /* a comment */|   end if|end test", 3) is false
end TestEndMarkBeforeComment
