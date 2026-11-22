script "TestScriptEditorCompletionsList"
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

-- The script editor's list of completions, from HyperXTalk
-- (ide/Toolset/libraries/ideautocompletelibrary.livecodescript, and the
-- calls to it at the top of revsecommoneditorbehavior.livecodescript). It
-- is off until the user ticks Edit > Options > Autocomplete, so the editor
-- does what it always did for everyone else: these check that it is off
-- by default, that the editor's calls do nothing when it is off or not
-- loaded, and that Tab, Return, the arrows and Help keep their usual jobs
-- while no list is showing. (The list itself, a window by the caret, is
-- checked by hand in the IDE; see the pull request.)
--
-- The editor's behavior has syntax that compiles only in the IDE
-- (_internal), so its handlers are compiled on their own, from its file,
-- as the script of a button, beside stand-ins for what they call.

constant kLibrary = "ideautocompletelibrary"

local sEditor, sLibraryFound

on TestSetup
   TestSkipIfNot "desktop"
   put there is a stack kLibrary into sLibraryFound

   local tText, tStart, tEnd, tStubs
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript"), "UTF-8") into tText
   -- (a checkout on Windows ends its lines with CR LF)
   replace numToChar(13) & numToChar(10) with return in tText
   put offset(return & "function ideAutocompleteIsEnabled" & return, tText) into tStart
   put offset(return & "end ideAutocompleteInsertCompletion", tText, tStart) into tEnd
   if tStart is 0 or tEnd is 0 then
      throw "the editor's completion handlers are not there"
   end if

   -- What the handlers call in the editor
   put "function __GetPreference pPreference, pDefault" & return & \
         "if the cPrefs[pPreference] of me is not empty then return the cPrefs[pPreference] of me" & return & \
         "return pDefault" & return & "end __GetPreference" & return & \
         "command textReplace pOffset, pOld, pNew" & return & \
         "set the cReplaced of me to pOffset & comma & pOld & comma & pNew" & return & \
         "end textReplace" & return into tStubs

   create stack "TestCompletionsListStack"
   set the defaultStack to "TestCompletionsListStack"
   create button "editor"
   put the long id of button "editor" into sEditor
   set the script of sEditor to tStubs & char tStart + 1 to tStart + tEnd + length("end ideAutocompleteInsertCompletion") of tText
   TestAssert "the editor's handlers compile", the result is empty
end TestSetup

on TestTeardown
   if there is a stack "TestCompletionsListStack" then
      delete stack "TestCompletionsListStack"
   end if
   if sLibraryFound is not true and there is a stack kLibrary then
      if the long id of stack kLibrary is among the lines of the backScripts then
         remove the script of stack kLibrary from back
      end if
      delete stack kLibrary
   end if
end TestTeardown

--------------------------------------------------------------------------------

on TestOffByDefault
   TestAssert "off until it is turned on", __Call("ideAutocompleteIsEnabled") is false
   set the cPrefs["editor,showautocomplete"] of sEditor to true
   TestAssert "on when it is", __Call("ideAutocompleteIsEnabled") is true
end TestOffByDefault

on TestPreferenceDefault
   -- The script editor's own default, from its utilities
   local tText, tStart, tEnd, tPrefs
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/palettes/script editor/behaviors/revseutilities.livecodescript"), "UTF-8") into tText
   replace numToChar(13) & numToChar(10) with return in tText
   put offset(return & "command sePrefGetDefaults" & return, tText) into tStart
   put offset(return & "end sePrefGetDefaults", tText, tStart) into tEnd
   create button "defaults"
   set the script of button "defaults" to \
         "command seColorizationLoadScheme pName, @xPrefs" & return & "end seColorizationLoadScheme" & return & \
         "function seGetPlatform" & return & "return the platform" & return & "end seGetPlatform" & return & \
         "function seGetIcon pTag" & return & "return empty" & return & "end seGetIcon" & return & \
         "function testDefaults" & return & "sePrefGetDefaults" & return & "return the result" & return & "end testDefaults" & \
         char tStart to tStart + tEnd + length("end sePrefGetDefaults") of tText
   TestAssert "the defaults compile", the result is empty
   dispatch function "testDefaults" to button "defaults"
   put the result into tPrefs
   TestAssert "the list is off by default", tPrefs["editor,showautocomplete"] is false
   TestAssert "the other completion preference is as it was", tPrefs["editor,providercompletion"] is true
end TestPreferenceDefault

on TestNoLibraryKeysCarryOn
   if there is a stack kLibrary then
      throw "SKIP the library is in memory"
   end if
   TestAssert "Tab carries on", __Command("ideAutocompleteHandleTab", "editor", "object") is true
   TestAssert "Return carries on", __Command("ideAutocompleteHandleReturn", "editor") is true
   TestAssert "an arrow carries on", __Command("ideAutocompleteHandleArrow", "editor", "down", "object") is true
   TestAssert "Help goes on to the dictionary", __Command("ideAutocompleteHandleHelp", "editor", "object") is false
   TestAssert "a cancel does nothing", __Command("ideAutocompleteCancelFind", "editor", true) is empty
end TestNoLibraryKeysCarryOn

on TestLibraryKeysCarryOnWithNoList
   __LoadLibrary
   TestAssert "the library is the one stack of its name", the short name of stack kLibrary is kLibrary
   TestAssert "Tab carries on with no list showing", __Command("ideAutocompleteHandleTab", "editor", "object") is true
   TestAssert "Return carries on", __Command("ideAutocompleteHandleReturn", "editor") is true
   TestAssert "up carries on", __Command("ideAutocompleteHandleArrow", "editor", "up", "object") is true
   TestAssert "left carries on", __Command("ideAutocompleteHandleArrow", "editor", "left", "object") is true
   TestAssert "Help goes on to the dictionary", __Command("ideAutocompleteHandleHelp", "editor", "object") is false
   get __Command("ideAutocompleteCancelFind", "editor", true)
   TestAssert "no list was shown", there is no stack "ideAutoCompletePopup" or not the visible of stack "ideAutoCompletePopup"
end TestLibraryKeysCarryOnWithNoList

on TestLibraryLoadsOnce
   __LoadLibrary
   local tCount
   send "extensionInitialize" to stack kLibrary
   send "extensionInitialize" to stack kLibrary
   put 0 into tCount
   repeat for each line tScript in the backScripts
      if tScript is the long id of stack kLibrary then add 1 to tCount
   end repeat
   TestAssert "in the back once", tCount is 1
   -- another stack's extensionInitialize passing through the back is not
   -- the library's own
   create stack "TestCompletionsOther"
   send "extensionInitialize" to stack "TestCompletionsOther"
   TestAssert "another stack's message leaves it alone", the long id of stack kLibrary is among the lines of the backScripts
   delete stack "TestCompletionsOther"
   send "extensionFinalize" to stack kLibrary
   TestAssert "out of the back when finalized", the long id of stack kLibrary is not among the lines of the backScripts
end TestLibraryLoadsOnce

on TestInsertGoesThroughTheEditor
   get __Command("ideAutocompleteInsertCompletion", 12, "rep", "repeat")
   TestAssert "the editor's textReplace inserts the word", the cReplaced of sEditor is "12,rep,repeat"
end TestInsertGoesThroughTheEditor

--------------------------------------------------------------------------------

private function __Call pFunction
   dispatch function pFunction to sEditor
   return the result
end __Call

private function __Command pCommand, pOne, pTwo, pThree
   dispatch pCommand to sEditor with pOne, pTwo, pThree
   return the result
end __Command

private command __LoadLibrary
   if there is a stack kLibrary then
      exit __LoadLibrary
   end if
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/libraries/ideautocompletelibrary.livecodescript")
end __LoadLibrary
