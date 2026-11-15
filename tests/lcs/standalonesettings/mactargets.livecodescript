script "TestStandaloneSettingsMacTargets"
-- OXT-Beyond: the Mac card of Standalone Settings
-- (ide/Toolset/palettes/standalone settings/revstandalonesettingsmacbehavior.livecodescript)
-- opened on Linux or Windows. It used to send the group "Flavors" its
-- mouseUp with every box off, which stored the boxes as the stack's
-- targets, so a stack set up on a Mac lost all its Mac targets when the
-- card was only looked at on another platform. Now the boxes show the
-- stack's targets and the targets are kept. The card here is built from
-- the behavior and the group "Flavors" script of the real stack
-- (stack-scripts/.../stack_revStandaloneSettings_group_id_1086), with
-- stand-ins for what the rest of the palette provides.

-- The palette's own name: the scripts name it
constant kPalette = "revStandaloneSettings"
constant kTarget = "TestMacCardTarget"

local sSetSettingsCalls

on TestSetup
   TestSkipIf "platform", "MacOS"
   TestSkipIf "platform", "HTML5"
   TestSkipIf "stack", kPalette

   local tPath, tScript, tName
   create invisible stack kTarget
   create invisible stack kPalette
   set the cRevTargetStack of stack kPalette to kTarget
   set the defaultStack to kPalette
   -- What the palette's own behavior gives the card
   set the script of stack kPalette to \
         "function getSettings" & return & \
         "  return the customProperties[" & quote & "cRevStandaloneSettings" & quote & "] of stack " & quote & kTarget & quote & return & \
         "end getSettings" & return & \
         "command setSettings pSettings" & return & \
         "  dispatch " & quote & "_MacTargetsSetSettingsCalled" & quote & " to stack " & quote & "TestStandaloneSettingsMacTargets" & quote & return & \
         "  set the customProperties[" & quote & "cRevStandaloneSettings" & quote & "] of stack " & quote & kTarget & quote & " to pSettings" & return & \
         "end setSettings" & return & \
         "function computeDefault pValue, pDefault" & return & \
         "  if pValue is empty then return pDefault" & return & \
         "  return pValue" & return & \
         "end computeDefault" & return & \
         "function revDownloadEngine pTag" & return & "  return true" & return & "end revDownloadEngine" & return & \
         "command buildForEnabled" & return & "end buildForEnabled" & return & \
         "command revSetEdit" & return & "end revSetEdit"

   create group "Flavors"
   repeat for each item tName in "MacOSX x86-32,MacOSX x86-64,MacOS-IntelArmUniversal"
      create button tName in group "Flavors"
      set the style of button tName to "checkbox"
   end repeat
   set the cSettingTag of button "MacOSX x86-32" to "MacOSX x86-32"
   set the cSettingTag of button "MacOSX x86-64" to "MacOSX x86-64"
   set the cSettingTag of button "MacOS-IntelArmUniversal" to "MacOSX x64-ARM64"
   create group "OSX"
   create button "Spacer" in group "OSX"
   create group "checks"
   create button "OSXchecked" in group "checks"

   -- The real stack's script of the group "Flavors" (less its header)
   put TestGetEngineRepositoryPath() & "/stack-scripts/ide/Toolset/palettes/standalone settings/" & \
         "revstandalonesettings.8.rev.bst/scripts/stack_revStandaloneSettings_group_id_1086.livecodescript" into tPath
   put textDecode(url ("binfile:" & tPath), "utf-8") into tScript
   delete line 1 of tScript
   set the script of group "Flavors" of stack kPalette to tScript

   set the behavior of card 1 of stack kPalette to the long id of stack \
         (TestGetIDERepositoryPath() & "/Toolset/palettes/standalone settings/revstandalonesettingsmacbehavior.livecodescript")
   put 0 into sSetSettingsCalls
end TestSetup

on TestTeardown
   if there is a stack kPalette then delete stack kPalette
   if there is a stack kTarget then delete stack kTarget
end TestTeardown

on _MacTargetsSetSettingsCalled
   add 1 to sSetSettingsCalls
end _MacTargetsSetSettingsCalled

private function _Targets
   local tSettings
   put the customProperties["cRevStandaloneSettings"] of stack kTarget into tSettings
   return (tSettings["MacOSX x86-32"] is true) & comma & \
         (tSettings["MacOSX x86-64"] is true) & comma & \
         (tSettings["MacOSX x64-ARM64"] is true)
end _Targets

private command _SetTargets p32, p64, pUniversal
   local tSettings
   put "true" into tSettings["Linux x64"]
   put p32 into tSettings["MacOSX x86-32"]
   put p64 into tSettings["MacOSX x86-64"]
   put pUniversal into tSettings["MacOSX x64-ARM64"]
   set the customProperties["cRevStandaloneSettings"] of stack kTarget to tSettings
end _SetTargets

private command _OpenMacCard
   send "preOpenCard" to card 1 of stack kPalette
end _OpenMacCard

on TestMacCardKeepsIntelTarget
   _SetTargets false, true, false
   _OpenMacCard
   TestAssert "the Intel 64-bit target is kept", _Targets() is "false,true,false"
   TestAssert "its box shows it", the hilite of button "MacOSX x86-64" of stack kPalette
   TestAssert "the universal box is off", not the hilite of button "MacOS-IntelArmUniversal" of stack kPalette
   TestAssert "the card stores no settings", sSetSettingsCalls is 0
   local tSettings
   put the customProperties["cRevStandaloneSettings"] of stack kTarget into tSettings
   TestAssert "another platform's target is untouched", tSettings["Linux x64"] is "true"
end TestMacCardKeepsIntelTarget

on TestMacCardKeepsUniversalTarget
   _SetTargets false, false, true
   _OpenMacCard
   TestAssert "the universal target is kept", _Targets() is "false,false,true"
   TestAssert "its box shows it", the hilite of button "MacOS-IntelArmUniversal" of stack kPalette
   TestAssert "the card stores no settings", sSetSettingsCalls is 0
end TestMacCardKeepsUniversalTarget

on TestMacCardWithNoTargets
   _SetTargets false, false, false
   _OpenMacCard
   TestAssert "a stack with no Mac target still has none", _Targets() is "false,false,false"
   TestAssert "no box is on", not (the hilite of button "MacOSX x86-64" of stack kPalette or \
         the hilite of button "MacOS-IntelArmUniversal" of stack kPalette or \
         the hilite of button "MacOSX x86-32" of stack kPalette)
end TestMacCardWithNoTargets

on TestMacCardBoxesCannotBeChanged
   _SetTargets false, true, false
   _OpenMacCard
   TestAssert "the Intel 64-bit box is disabled off a Mac", not the enabled of button "MacOSX x86-64" of stack kPalette
   TestAssert "the universal box is disabled off a Mac", not the enabled of button "MacOS-IntelArmUniversal" of stack kPalette
end TestMacCardBoxesCannotBeChanged
