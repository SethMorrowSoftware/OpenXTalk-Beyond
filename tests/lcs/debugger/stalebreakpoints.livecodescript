script "TestDebuggerStaleBreakpoints"
-- OXT-Beyond: tests of the debugger library
-- (ide/Toolset/libraries/revdebuggerlibrary.livecodescript) with a
-- breakpoint and a watch saved in a stack for a control that has since
-- been deleted. Activating them (as the library's preOpenStack frontscript
-- does before it passes the message, and revDebuggerEnable does for every
-- open stack) stopped with an error at that entry, so on opening such a
-- stack its own preOpenStack never ran (OXT DPE, Mark Wieder's fix). The
-- entry is now skipped, and the others are still activated. Clearing the
-- stale entries is left to the library, as before.

constant kStack = "TestDebuggerStaleStack"
constant kMissingId = 99999

local sFound

on TestSetup
   put there is a stack "revdebuggerlibrary" into sFound
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revmetadatalibrary.livecodescript")
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revcommonlibrary.livecodescript")
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revdebuggerlibrary.livecodescript")
   create stack kStack
   set the defaultStack to kStack
   create button "Kept"
   set the script of button "Kept" of stack kStack to "on mouseUp" & return & "beep" & return & "end mouseUp"
end TestSetup

on TestTeardown
   set the breakpoints to empty
   set the watchedVariables to empty
   if there is a stack kStack then delete stack kStack
   if there is a stack "revdebuggerlibrary" and not sFound then
      delete stack "revdebuggerlibrary"
   end if
end TestTeardown

-- Saves pBreakpoints (lines of "id,line") and pWatches (lines of
-- "id,handler,variable") in the stack, every one active, as the library
-- stores them
private command __Save pBreakpoints, pWatches
   local tStates
   repeat for each line tLine in pBreakpoints
      put "active" & return after tStates
   end repeat
   delete the last char of tStates
   revMetadataSet the long id of stack kStack, "general", "breakpoints", pBreakpoints
   revMetadataSet the long id of stack kStack, "general", "breakpointstates", tStates
   put empty into tStates
   repeat for each line tLine in pWatches
      put "active" & return after tStates
   end repeat
   delete the last char of tStates
   revMetadataSet the long id of stack kStack, "general", "watches", pWatches
   revMetadataSet the long id of stack kStack, "general", "watchstates", tStates
end __Save

on TestStaleEntriesAreSkipped
   local tKeptId
   put the id of button "Kept" of stack kStack into tKeptId
   -- What the entries that resolve activate on their own
   __Save tKeptId & ",2", "0,,tStackVar" & return & tKeptId & ",mouseUp,tKept"
   dispatch "revDebuggerEnable" to stack "revdebuggerlibrary"
   local tBreakpoints, tWatches
   put the breakpoints into tBreakpoints
   put the watchedVariables into tWatches
   -- The same with a stale breakpoint and watch first, so that the old
   -- error came before the entries that resolve
   __Save kMissingId & ",2" & return & tKeptId & ",2", \
         kMissingId & ",mouseUp,tGone" & return & "0,,tStackVar" & return & tKeptId & ",mouseUp,tKept"
   -- revDebuggerEnable adds to the watches already active, so start again
   set the watchedVariables to empty
   local tError
   try
      dispatch "revDebuggerEnable" to stack "revdebuggerlibrary"
   catch tError
   end try
   TestDiagnostic tError
   TestAssert "activating a stale breakpoint and watch throws no error", tError is empty
   TestAssert "the breakpoint that resolves is active", \
         (the long id of button "Kept" of stack kStack & ",2") is among the lines of the breakpoints
   TestAssert "the stale entries change no other breakpoint", the breakpoints is tBreakpoints
   TestAssert "the stale entries change no other watch", the watchedVariables is tWatches
   TestAssert "no stale entry is active", \
         kMissingId is not in the breakpoints and kMissingId is not in the watchedVariables
end TestStaleEntriesAreSkipped

on TestEntriesThatResolve
   -- With nothing stale, the breakpoint is activated as before
   local tKeptId
   put the id of button "Kept" of stack kStack into tKeptId
   __Save tKeptId & ",2", empty
   dispatch "revDebuggerEnable" to stack "revdebuggerlibrary"
   TestAssert "the breakpoint is active", \
         (the long id of button "Kept" of stack kStack & ",2") is among the lines of the breakpoints
end TestEntriesThatResolve

-- A breakpoint saved for a deleted control is dropped when the library
-- lists a stack's breakpoints. The breakpoints after it must keep their
-- own state and condition: they took those of the entry before them,
-- so a breakpoint that was off read as on, with the condition of the
-- deleted control's breakpoint (an error when it stopped there, since
-- the condition names what its own handler does not have).
on TestDroppedBreakpointLeavesStatesAndConditions
   local tKeptId, tOtherId, tStack
   put the long id of stack kStack into tStack
   put the id of button "Kept" of stack kStack into tKeptId
   set the defaultStack to kStack
   create button "Other"
   put the id of it into tOtherId
   revMetadataSet tStack, "general", "breakpoints", \
         kMissingId & ",2" & return & tKeptId & ",2" & return & tOtherId & ",3"
   revMetadataSet tStack, "general", "breakpointstates", \
         "active" & return & "inactive" & return & "active"
   revMetadataSet tStack, "general", "breakpointconditions", \
         "tGone is 1" & return & empty & return & "tOther is 2"
   local tListed
   dispatch function "revDebuggerListBreakpoints" to stack "revdebuggerlibrary" with the long id of button "Kept" of stack kStack
   put the result into tListed
   TestAssert "the kept control's breakpoint is listed", \
         tListed is (the long id of button "Kept" of stack kStack & ",2")
   TestAssert "the deleted control's breakpoint is dropped", \
         revMetadataGet(tStack, "general", "breakpoints") is \
         (tKeptId & ",2" & return & tOtherId & ",3")
   TestAssert "the breakpoints after it keep their states", \
         revMetadataGet(tStack, "general", "breakpointstates") is ("inactive" & return & "active")
   TestAssert "the breakpoints after it keep their conditions", \
         revMetadataGet(tStack, "general", "breakpointconditions") is (empty & return & "tOther is 2")
   dispatch function "revDebuggerListBreakpointStates" to stack "revdebuggerlibrary" with the long id of button "Kept" of stack kStack
   TestAssert "the library gives the kept breakpoint's own state", the result is "inactive"
end TestDroppedBreakpointLeavesStatesAndConditions

-- The same for a breakpoint saved twice: the second copy is dropped and
-- the entries after it keep their own state and condition
on TestDuplicateBreakpointLeavesStatesAndConditions
   local tKeptId, tOtherId, tStack
   put the long id of stack kStack into tStack
   put the id of button "Kept" of stack kStack into tKeptId
   set the defaultStack to kStack
   create button "Other"
   put the id of it into tOtherId
   revMetadataSet tStack, "general", "breakpoints", \
         tKeptId & ",2" & return & tKeptId & ",2" & return & tOtherId & ",3"
   revMetadataSet tStack, "general", "breakpointstates", \
         "inactive" & return & "active" & return & "active"
   revMetadataSet tStack, "general", "breakpointconditions", \
         empty & return & "tTwice is 1" & return & "tOther is 2"
   dispatch function "revDebuggerListBreakpoints" to stack "revdebuggerlibrary" with the long id of button "Kept" of stack kStack
   TestAssert "one copy of the breakpoint is kept", \
         revMetadataGet(tStack, "general", "breakpoints") is (tKeptId & ",2" & return & tOtherId & ",3")
   TestAssert "the first copy's state is kept, and the next entry's own", \
         revMetadataGet(tStack, "general", "breakpointstates") is ("inactive" & return & "active")
   TestAssert "the next entry keeps its condition", \
         revMetadataGet(tStack, "general", "breakpointconditions") is (empty & return & "tOther is 2")
end TestDuplicateBreakpointLeavesStatesAndConditions

-- A watch saved for a deleted control is dropped when a watch is added;
-- the watches after it keep their own state
on TestDroppedWatchLeavesStates
   local tKeptId, tStack
   put the long id of stack kStack into tStack
   put the id of button "Kept" of stack kStack into tKeptId
   revMetadataSet tStack, "general", "watches", \
         kMissingId & ",mouseUp,tGone" & return & tKeptId & ",mouseUp,tKept" & return & tKeptId & ",mouseUp,tSecond"
   revMetadataSet tStack, "general", "watchstates", \
         "active" & return & "inactive" & return & "active"
   dispatch "revDebuggerAddWatch" to stack "revdebuggerlibrary" with the long id of button "Kept" of stack kStack, "mouseUp", "tNew"
   local tWatches, tStates
   put revMetadataGet(tStack, "general", "watches") into tWatches
   put revMetadataGet(tStack, "general", "watchstates") into tStates
   TestDiagnostic tWatches
   TestDiagnostic tStates
   TestAssert "the deleted control's watch is dropped", kMissingId is not in tWatches
   TestAssert "the first watch after it keeps its state", \
         line lineOffset(tKeptId & ",mouseUp,tKept", tWatches) of tStates is "inactive"
   TestAssert "the second watch after it keeps its state", \
         line lineOffset(tKeptId & ",mouseUp,tSecond", tWatches) of tStates is "active"
end TestDroppedWatchLeavesStates
