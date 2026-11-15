script "TestReplicatePadlocks"
-- OXT-Beyond: Edit > Replicate's two padlock buttons (between the h and v
-- fields of "Offset by" and "Scale by") show dark icons, made for the
-- light appearance, that were dim grey on the dark window. When the
-- dialog opens they are now tinted light in the dark appearance and left
-- as they were in the light one (tools/oxt/ide-stack-patches/
-- replicate-padlock-icons-dark.txt, and revreplicate-... for the older
-- copy). The stack is loaded, not opened: its preOpenStack reads the IDE's
-- preferences stack, which an engine test does not have. The IDE's
-- revIDEAppearanceIsDark is a stand-in here.

constant kStandIn = "TestReplicatePadlocksAppearance"

global gTestReplicateDark

on TestSetup
   TestSkipIf "platform", "HTML5"
   create invisible stack kStandIn
   set the script of stack kStandIn to "global gTestReplicateDark" & return & \
         "function revIDEAppearanceIsDark" & return & \
         "  return gTestReplicateDark" & return & \
         "end revIDEAppearanceIsDark"
end TestSetup

on TestTeardown
   stop using stack kStandIn
   if there is a stack kStandIn then delete stack kStandIn
   if there is a stack "revReplicate" then delete stack "revReplicate"
end TestTeardown

private function _Overlay pFile, pDark, pStandIn
   local tPath, tCard, tOut, tLock
   if there is a stack "revReplicate" then delete stack "revReplicate"
   put TestGetIDERepositoryPath() & "/Toolset/palettes/" & pFile into tPath
   put the long id of card 1 of stack tPath into tCard
   if pStandIn then
      start using stack kStandIn
   else
      stop using stack kStandIn
   end if
   put pDark into gTestReplicateDark
   dispatch "revReplicateLockIconColours" to tCard
   if it is not "handled" then return "not handled"
   repeat for each item tLock in "offsetLockButton,scaleLockButton"
      put the colorOverlay["color"] of button tLock of tCard & "/" & \
            the colorOverlay["opacity"] of button tLock of tCard & ";" after tOut
   end repeat
   return tOut
end _Overlay

private command _Check pFile
   local tCard, tScript, tPre
   TestAssert pFile & ": dark appearance tints both padlocks light", \
         _Overlay(pFile, true, true) is "210,210,210/255;210,210,210/255;"
   TestAssert pFile & ": light appearance leaves them without an overlay", \
         _Overlay(pFile, false, true) is "/;/;"
   TestAssert pFile & ": without the IDE's function, no overlay", \
         _Overlay(pFile, true, false) is "/;/;"
   -- and preOpenStack calls it
   put the script of card 1 of stack "revReplicate" into tScript
   put char offset("on preOpenStack", tScript) to offset("end preOpenStack", tScript) of tScript into tPre
   TestAssert pFile & ": preOpenStack sets the padlocks' colours", \
         tPre contains "revReplicateLockIconColours"
end _Check

on TestReplicatePadlocks
   _Check "replicate.oxtstack"
end TestReplicatePadlocks

on TestOlderReplicatePadlocks
   _Check "revreplicate.rev"
end TestOlderReplicatePadlocks
