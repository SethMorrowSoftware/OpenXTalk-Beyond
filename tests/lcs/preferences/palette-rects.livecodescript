script "TestPreferencesPaletteRects"
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

-- The window positions the IDE keeps in its preferences, one
-- palette_rect_<name> property of stack "revPreferences" for each stack
-- (revIDESetPaletteRectPreference in
-- ide/Toolset/libraries/revidelibrary.8.livecodescript). A stack with no
-- name of its own is named by its file's path, so one opened from the
-- temporary folder left a property that nothing read again, and the
-- preferences file grew with every run (HyperXTalk #623, Mark Wieder).
-- These check that no position is kept for such a stack, that every other
-- stack's is kept as before, and that the ones kept by earlier versions
-- are taken out, once, and only those.
--
-- The library has syntax that compiles only in the IDE, so its handlers
-- are compiled on their own, from its file, as the script of a button,
-- beside stand-ins for the IDE's preference handlers, which here set and
-- read the properties of a stack "revPreferences" made by the test.

local sLibrary, sMadePreferences

on TestSetup
   TestSkipIfNot "desktop"
   if there is a stack "revPreferences" then
      -- (the IDE's own preferences are the user's: not this test's to change)
      throw "SKIP the IDE's preferences are in memory"
   end if
   local tText, tStart, tEnd, tStubs
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/libraries/revidelibrary.8.livecodescript"), "UTF-8") into tText
   -- (a checkout on Windows ends its lines with CR LF)
   replace numToChar(13) & numToChar(10) with return in tText
   put offset(return & "on revIDESetPaletteRectPreference pStackName" & return, tText) into tStart
   put offset(return & "end revIDEForgetTempPaletteRects", tText, tStart) into tEnd
   if tStart is 0 or tEnd is 0 then
      throw "the palette rect handlers are not there"
   end if

   put "on revIDESetPreference pName, pValue" & return & \
         "set the pName of stack " & quote & "revPreferences" & quote & " to pValue" & return & \
         "end revIDESetPreference" & return & \
         "function revIDEGetPreference pName" & return & \
         "return the pName of stack " & quote & "revPreferences" & quote & return & \
         "end revIDEGetPreference" & return & \
         "function revIDEPreferenceNames" & return & \
         "return the customKeys of stack " & quote & "revPreferences" & quote & return & \
         "end revIDEPreferenceNames" & return & \
         "on revInternal__SavePreferences" & return & \
         "set the cSaves of me to the cSaves of me + 1" & return & \
         "end revInternal__SavePreferences" & return into tStubs

   create stack "TestPaletteRectsStack"
   set the defaultStack to "TestPaletteRectsStack"
   create button "library"
   put the long id of button "library" into sLibrary
   set the script of sLibrary to tStubs & \
         char tStart + 1 to tStart + tEnd + length("end revIDEForgetTempPaletteRects") of tText
   TestAssert "the handlers compile", the result is empty
   set the cSaves of sLibrary to 0

   create invisible stack "revPreferences"
   put true into sMadePreferences
   set the defaultStack to "TestPaletteRectsStack"
end TestSetup

on TestTeardown
   repeat for each item tStack in "TestPaletteRectsStack,TestPaletteRectsProbe"
      if there is a stack tStack then delete stack tStack
   end repeat
   if there is a stack __TempName() then delete stack __TempName()
   if sMadePreferences is true and there is a stack "revPreferences" then
      delete stack "revPreferences"
   end if
end TestTeardown

--------------------------------------------------------------------------------

on TestTempPaths
   local tTemp
   put specialFolderPath("temporary") into tTemp
   TestDiagnostic "the temporary folder:" && tTemp
   TestAssert "/tmp is temporary", __IsTemp("/tmp/notes.livecode") is true
   TestAssert "a file in the OS's temporary folder", __IsTemp(tTemp & "/notes.oxtstack") is true
   TestAssert "with its spaces made underscores, as the preference has them", \
         __IsTemp(__Underscores(tTemp) & "/notes.oxtstack") is true
   TestAssert "the folder alone is no file in it", __IsTemp(tTemp) is false
   TestAssert "with backslashes, as on Windows", __IsTemp("\tmp\notes.livecode") is true
   if tTemp begins with "/var/" then
      TestAssert "macOS: /private/var as well as /var", __IsTemp("/private" & tTemp & "/notes.rev") is true
   end if
   -- What is not one
   TestAssert "an IDE palette is not", __IsTemp("revInspector 1") is false
   TestAssert "the message box is not", __IsTemp("Message Box") is false
   TestAssert "a stack of the user's is not", __IsTemp("My Stack") is false
   TestAssert "a name that begins with tmp is not", __IsTemp("tmp stuff") is false
   TestAssert "a file elsewhere is not", __IsTemp("/home/me/tmp/notes.livecode") is false
   TestAssert "/tmpfiles is not /tmp", __IsTemp("/tmpfiles/notes.livecode") is false
   TestAssert "an empty name is not", __IsTemp(empty) is false
end TestTempPaths

on TestPositionKeptAsBefore
   -- A stack with a name of its own: its rect is kept, under its name with
   -- its spaces made underscores, as before
   create invisible stack "TestPaletteRectsProbe"
   set the rect of stack "TestPaletteRectsProbe" to 100,120,400,420
   dispatch "revIDESetPaletteRectPreference" to sLibrary with "TestPaletteRectsProbe"
   TestAssert "the rect is kept", the palette_rect_TestPaletteRectsProbe of stack "revPreferences" is "100,120,400,420"
   TestAssert "and read back", __Get("TestPaletteRectsProbe") is "100,120,400,420"
end TestPositionKeptAsBefore

on TestNoPositionForATempStack
   local tName, tKeysBefore
   put __TempName() into tName
   create invisible stack "TestPaletteRectsProbe"
   set the name of stack "TestPaletteRectsProbe" to tName
   TestAssert "the probe has the temporary file's name", there is a stack tName
   -- (a preference already there, so that "no property is made" has
   -- something to compare with)
   set the cGrid of stack "revPreferences" to true
   put the customKeys of stack "revPreferences" into tKeysBefore
   dispatch "revIDESetPaletteRectPreference" to sLibrary with tName
   TestAssert "no property is made for it", the customKeys of stack "revPreferences" is tKeysBefore
   TestAssert "and none is read back", __Get(tName) is empty
end TestNoPositionForATempStack

on TestForgetTempPositions
   local tTemp, tProps, tKeys
   put __Underscores(specialFolderPath("temporary")) into tTemp
   replace backslash with slash in tTemp
   put "1,2,3,4" into tProps["palette_rect_/tmp/a.livecode"]
   put "1,2,3,4" into tProps["palette_rect_" & tTemp & "/b.oxtstack"]
   put "5,6,7,8" into tProps["palette_rect_revInspector_1"]
   put "5,6,7,8" into tProps["palette_rect_revMenubar"]
   put "/tmp/kept.livecode" into tProps["cRecentStacks"]
   put true into tProps["cGrid"]
   set the customProperties of stack "revPreferences" to tProps

   TestAssert "the two are taken out", __Forget() is 2
   put the customKeys of stack "revPreferences" into tKeys
   TestAssert "not /tmp's", "palette_rect_/tmp/a.livecode" is not among the lines of tKeys
   TestAssert "not the temporary folder's", ("palette_rect_" & tTemp & "/b.oxtstack") is not among the lines of tKeys
   TestAssert "the palettes' are kept", ("palette_rect_revInspector_1" is among the lines of tKeys) and \
         (the palette_rect_revMenubar of stack "revPreferences" is "5,6,7,8")
   TestAssert "other preferences are kept, a path in one included", \
         (the cRecentStacks of stack "revPreferences" is "/tmp/kept.livecode") and \
         (the cGrid of stack "revPreferences" is true)
   TestAssert "the preferences are saved once", the cSaves of sLibrary is 1

   TestAssert "a second time there is nothing to take out", __Forget() is 0
   TestAssert "and nothing is saved", the cSaves of sLibrary is 1
end TestForgetTempPositions

--------------------------------------------------------------------------------

private function __IsTemp pName
   dispatch function "revIDEStackNameIsTempPath" to sLibrary with pName
   return the result
end __IsTemp

private function __Get pName
   dispatch function "revIDEGetPaletteRectPreference" to sLibrary with pName
   return the result
end __Get

private function __Forget
   dispatch function "revIDEForgetTempPaletteRects" to sLibrary
   return the result
end __Forget

private function __Underscores pText
   replace space with "_" in pText
   return pText
end __Underscores

-- The name a stack with none of its own would have, opened from the
-- temporary folder
private function __TempName
   return specialFolderPath("temporary") & "/TestPaletteRects probe.livecode"
end __TempName
