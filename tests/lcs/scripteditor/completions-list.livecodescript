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
-- while no list is showing. One test shows the list for a word, moves
-- through it, closes it and takes a completion with Tab, as the editor's
-- calls do. (Where the window appears, and that it is in front of the
-- editor, is checked by hand in the IDE; see the pull request.) The tests
-- after it check HyperXTalk #607's changes: what is offered depends on
-- where the word is in the line, keywords and words of three letters or
-- fewer are never offered, nothing is offered in a comment, the variables
-- in reach are offered after "into", end offers the handler it is in,
-- messages are offered after "on" with no dictionary, Match Abbreviations
-- turns the hump matching off, and a call's parameters are shown above it.
-- On Windows the list and the hint are never hidden once shown, only moved
-- out of sight (HyperXTalk's fix for the editor's title bar flicker), so
-- "shown" here means visible and not parked there.
--
-- The editor's behavior has syntax that compiles only in the IDE
-- (_internal), so its handlers are compiled on their own, from its file,
-- as the script of a button, beside stand-ins for what they call.

constant kLibrary = "ideautocompletelibrary"
constant kPopup = "ideAutoCompletePopup"
constant kHint = "ideAutoCompletePopupHint"
-- Where the library parks the list and the hint on Windows
constant kParked = "-20000,-20000"

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
         "end textReplace" & return & \
         "command getCaretToken" & return & "return the cToken of me" & return & \
         "end getCaretToken" & return & \
         "function getScriptField" & return & "return the cScriptField of me" & return & \
         "end getScriptField" & return into tStubs

   create stack "TestCompletionsListStack"
   set the defaultStack to "TestCompletionsListStack"
   create button "editor"
   put the long id of button "editor" into sEditor
   set the script of sEditor to tStubs & char tStart + 1 to tStart + tEnd + length("end ideAutocompleteInsertCompletion") of tText
   TestAssert "the editor's handlers compile", the result is empty
end TestSetup

on TestTeardown
   if there is a button "standIns" of stack "TestCompletionsListStack" then
      remove the script of button "standIns" of stack "TestCompletionsListStack" from back
   end if
   if there is a stack "TestCompletionsListStack" then
      delete stack "TestCompletionsListStack"
   end if
   if sLibraryFound is not true and there is a stack kLibrary then
      if the long id of stack kLibrary is among the lines of the backScripts then
         remove the script of stack kLibrary from back
      end if
      delete stack kLibrary
      if there is a stack kPopup then
         delete stack kPopup
      end if
      if there is a stack kHint then
         delete stack kHint
      end if
   end if
   if there is a stack "revPreferences" and the cMadeByTest of stack "revPreferences" is true then
      delete stack "revPreferences"
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
   TestAssert "no list was shown", not __Shown(kPopup)
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

on TestTheListForAWord
   __LoadLibrary
   -- The editor's script field, with the caret after a word being typed
   -- (a field takes a selection only on an open stack)
   local tField, tFirst
   go stack "TestCompletionsListStack"
   create field "script"
   put the long id of field "script" into tField
   set the text of tField to "on mouseUp" & return & "   rep"
   select after text of tField
   set the cToken of sEditor to "rep"
   set the cScriptField of sEditor to tField
   -- The IDE's, which the library asks for the object's key
   create button "standIns"
   set the script of button "standIns" to \
         "function revRuggedId pObject" & return & "return pObject" & return & "end revRuggedId"
   insert the script of button "standIns" into back

   -- The update the editor asks for on each key, run without waiting for
   -- its timer
   get __Command("ideAutocompleteUpdate", sEditor, sEditor, empty)
   send "ideAutocomplete_DoUpdate" to stack kLibrary
   TestAssert "the list shows", __Shown(kPopup)
   TestAssert "it has the commands the word begins", "replace" is among the lines of the text of field "completions" of stack kPopup
   TestAssert "it is a palette", the style of stack kPopup is "palette"
   -- On Windows the editor, taking the keyboard back, came in front of a
   -- palette (raisePalettes is off in the IDE): a system window stays on top
   if the platform is "Win32" then
      TestAssert "a system window on Windows", the systemWindow of stack kPopup is true
   else
      TestAssert "not a system window here", the systemWindow of stack kPopup is false
   end if
   TestAssert "down moves through the list", __Command("ideAutocompleteHandleArrow", sEditor, "down", sEditor) is false
   TestAssert "to the second word", the hilitedLine of field "completions" of stack kPopup is 2
   get __Command("ideAutocompleteCancelFind", sEditor, true)
   TestAssert "Escape closes it", not __Shown(kPopup)

   -- Tab takes the first completion, through the editor
   get __Command("ideAutocompleteUpdate", sEditor, sEditor, empty)
   TestAssert "Tab is taken", __Command("ideAutocompleteHandleTab", sEditor, sEditor) is false
   put line 1 of the text of field "completions" of stack kPopup into tFirst
   TestAssert "the first word replaces the one typed", the cReplaced of sEditor is "15,rep," & tFirst
   TestAssert "the list closes", not __Shown(kPopup)
end TestTheListForAWord

on TestWhereTheWordIs
   __LoadLibrary
   __OpenEditor
   local tList
   -- At the start of a statement: commands and control structures
   put __ListFor("on mouseUp|   rep", "rep") into tList
   TestAssert "a statement's start offers repeat", "repeat" is among the lines of tList
   TestAssert "and the replace command", "replace" is among the lines of tList
   TestAssert "but not the replaceText function", "replaceText" is not among the lines of tList
   -- Mid-line: functions, properties and constants, never a command
   put __ListFor("on mouseUp|   put repl", "repl") into tList
   TestAssert "mid-line offers replaceText", "replaceText" is among the lines of tList
   TestAssert "mid-line does not offer the replace command", "replace" is not among the lines of tList
   -- After "set the": properties only
   put __ListFor("on mouseUp|   set the backgroundC", "backgroundC") into tList
   TestAssert "set the offers backgroundColor", "backgroundColor" is among the lines of tList
   TestAssert "set the offers only properties", __AllAmong(tList, propertyNames())
   -- After "is a": the types a value can be tested for
   put __ListFor("on mouseUp|   if tX is a num", "num") into tList
   TestAssert "is a offers number", tList is "number"
   -- After "on": the name of a message, from the built-in list when there
   -- is no dictionary, as there is none here
   put __ListFor("on preOpenC", "preOpenC") into tList
   TestAssert "on offers preOpenCard", "preOpenCard" is among the lines of tList
   put __ListFor("on mouseU", "mouseU") into tList
   TestAssert "on offers mouseUp", "mouseUp" is among the lines of tList
end TestWhereTheWordIs

on TestNothingToOffer
   __LoadLibrary
   __OpenEditor
   -- A keyword typed in full
   TestAssert "into offers nothing", __ListFor("on mouseUp|   put 1 into", "into") is empty
   -- In a comment, of either kind
   TestAssert "nothing in a -- comment", __ListFor("on mouseUp|   -- rep", "rep") is empty
   -- (no hash sign in a test's name: the test protocol reads one as the
   -- start of a directive, and the run never ends)
   TestAssert "nothing in a hash comment", __ListFor("on mouseUp|   # rep", "rep") is empty
   TestAssert "nothing in a block comment", __ListFor("on mouseUp|   /* a note|   rep", "rep") is empty
   TestAssert "a closed block comment does not count", "repeat" is among the lines of \
         __ListFor("on mouseUp|   /* a note */|   rep", "rep")
   -- A /* in a string or a line comment opens no block comment
   -- (OXT-Beyond)
   TestAssert "a /* in a string opens no comment", "repeat" is among the lines of \
         __ListFor("on mouseUp|   put " & quote & "/*" & quote & " into tPattern|   rep", "rep")
   TestAssert "nor one after --", "repeat" is among the lines of \
         __ListFor("on mouseUp|   -- a /* in a note|   rep", "rep")
   TestAssert "a */ in a comment's string still closes it", "repeat" is among the lines of \
         __ListFor("on mouseUp|   /* a " & quote & "note */|   rep", "rep")
   -- In a string
   TestAssert "nothing in a string", __ListFor("on mouseUp|   put " & quote & "rep", "rep") is empty
   -- Words of three letters or fewer are never on the list
   TestAssert "put is never offered", "put" is not among the lines of __ListFor("on mouseUp|   pu", "pu")
   -- A single letter is too few
   TestAssert "one letter offers nothing", __ListFor("on mouseUp|   r", "r") is empty
end TestNothingToOffer

on TestVariablesAndBlocks
   __LoadLibrary
   __OpenEditor
   local tList
   -- The variables in reach after into, typed or not
   put __ListFor("on mouseUp|   local tCounter|   put 1 into tCo", "tCo") into tList
   TestAssert "a local is offered first after into", line 1 of tList is "tCounter"
   put __ListFor("on mouseUp pFirst|   local tCounter|   put 1 into ", empty) into tList
   TestAssert "after into and a space, the local", "tCounter" is among the lines of tList
   TestAssert "and the parameter", "pFirst" is among the lines of tList
   -- A variable of another handler is not in reach
   put __ListFor("on mouseDown|   local tOther|end mouseDown|on mouseUp|   put 1 into ", empty) into tList
   TestAssert "another handler's local is not", "tOther" is not among the lines of tList
   -- end offers the handler the caret is in, and the block that is open
   put __ListFor("on mouseUp|   beep|   end mou", "mou") into tList
   TestAssert "end offers the handler", tList is "mouseUp"
   put __ListFor("on mouseUp|   repeat 3 times|      beep|   end ", empty) into tList
   TestAssert "end after a space offers the open repeat, and only that", tList is "repeat"
   put __ListFor("on mouseUp|   repeat 3 times|      exit ", empty) into tList
   TestAssert "exit offers the repeat and the handler", tList is "repeat" & return & "mouseUp"
end TestVariablesAndBlocks

on TestMatchAbbreviations
   __LoadLibrary
   __OpenEditor
   -- Hump matching: the capitals of a long name. Mid-line it starts at
   -- three letters. (The engine's own lists of names are in lower case,
   -- and there is no dictionary here, so a handler of the script is used.)
   local tScript
   put "function sayHelloWorld|end sayHelloWorld|on mouseUp|   put " into tScript
   TestAssert "shw finds sayHelloWorld", "sayHelloWorld" is among the lines of __ListFor(tScript & "shw", "shw")
   if there is a stack "revPreferences" then
      -- (the IDE's own: its preference is the user's, not this test's)
      exit TestMatchAbbreviations
   end if
   local tPref
   put "cScriptEditor,editor,autocompletehumps" into tPref
   create invisible stack "revPreferences"
   set the cMadeByTest of stack "revPreferences" to true
   set the defaultStack to "TestCompletionsListStack"
   set the tPref of stack "revPreferences" to false
   TestAssert "unticked, shw finds nothing", "sayHelloWorld" is not among the lines of __ListFor(tScript & "shw", "shw")
   TestAssert "a plain start still matches", "sayHelloWorld" is among the lines of __ListFor(tScript & "sayH", "sayH")
   set the tPref of stack "revPreferences" to true
   TestAssert "ticked again, it does", "sayHelloWorld" is among the lines of __ListFor(tScript & "shw", "shw")
end TestMatchAbbreviations

on TestMatchAbbreviationsMenu
   -- The script editor's Edit > Options item, and its default
   local tText
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/palettes/script editor/behaviors/revsemenubarbehavior.livecodescript"), "UTF-8") into tText
   TestAssert "the menu has the item", tText contains quote & "Match Abbreviations" & quote
   TestAssert "the menu pick sets the preference", \
         tText contains "case " & quote & "Options|Match Abbreviations" & quote
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/palettes/script editor/behaviors/revseutilities.livecodescript"), "UTF-8") into tText
   TestAssert "on by default", tText contains "put true into tPrefs[" & quote & "editor,autocompletehumps" & quote & "]"
end TestMatchAbbreviationsMenu

on TestParameterHint
   __LoadLibrary
   __OpenEditor
   local tScript
   put "function addUp pFirst, pSecond|   return pFirst + pSecond|end addUp|" & \
         "command greet pName, pTimes|end greet|on mouseUp|" into tScript
   -- After a function's "(": its parameters, above the line
   get __ListFor(tScript & "   put addUp(", empty)
   TestAssert "a function's hint shows", __Shown(kHint)
   TestAssert "with its parameters", the text of field "hint" of stack kHint is "addUp(pFirst, pSecond)"
   TestAssert "the first is the one being typed", \
         the textStyle of char 7 to 12 of field "hint" of stack kHint is "bold"
   -- After the comma, the second
   get __ListFor(tScript & "   put addUp(1, ", empty)
   TestAssert "the second after a comma", \
         the textStyle of char 15 to 21 of field "hint" of stack kHint is "bold" and \
         the textStyle of char 7 to 12 of field "hint" of stack kHint is "plain"
   -- Out of the call, it goes
   get __ListFor(tScript & "   put addUp(1, 2) ", empty)
   TestAssert "the hint goes after the call", not __Shown(kHint)
   -- A command's, after a space
   get __ListFor(tScript & "   greet ", empty)
   TestAssert "a command's hint shows", __Shown(kHint)
   TestAssert "with its parameters", the text of field "hint" of stack kHint is "greet pName, pTimes"
   -- Not in a comment
   get __ListFor(tScript & "   -- put addUp(", empty)
   TestAssert "no hint in a comment", not __Shown(kHint)
   -- Not for a declaration
   get __ListFor(tScript & "   local ", empty)
   TestAssert "no hint for local", not __Shown(kHint)
   -- A command and a function of one name: each call shows its own
   -- (OXT-Beyond), in the script being edited
   put "command calc pInput|end calc|function calc pWidth, pHeight|end calc|on mouseUp|" into tScript
   get __ListFor(tScript & "   put calc(", empty)
   TestAssert "calc( shows the function's", the text of field "hint" of stack kHint is "calc(pWidth, pHeight)"
   get __ListFor(tScript & "   calc ", empty)
   TestAssert "calc shows the command's", the text of field "hint" of stack kHint is "calc pInput"
   -- ... and in the message path (the stack's script)
   set the script of stack "TestCompletionsListStack" to \
         "command pathCalc pOne" & return & "end pathCalc" & return & \
         "function pathCalc pA, pB" & return & "end pathCalc"
   get __ListFor("on mouseUp|   put 1 into x", empty)
   get __ListFor("on mouseUp|   put pathCalc(", empty)
   TestAssert "a path function's", __Shown(kHint) and \
         the text of field "hint" of stack kHint is "pathCalc(pA, pB)"
   get __ListFor("on mouseUp|   put 1 into x", empty)
   get __ListFor("on mouseUp|   pathCalc ", empty)
   TestAssert "a path command's", __Shown(kHint) and \
         the text of field "hint" of stack kHint is "pathCalc pOne"
   set the script of stack "TestCompletionsListStack" to empty
   if the platform is "Win32" then
      TestAssert "a system window on Windows", the systemWindow of stack kHint is true
   else
      TestAssert "not a system window here", the systemWindow of stack kHint is false
   end if
   -- The hint's window gone from memory while it shows: putting it away
   -- is no error, and the next call makes it again
   get __ListFor(tScript & "   put calc(", empty)
   delete stack kHint
   local tError
   try
      dispatch "ideAutocompleteCancelFind" to stack kLibrary with sEditor, true
   catch tError
   end try
   TestAssert "no error when the hint's window is gone", tError is empty
   get __ListFor(tScript & "   put calc(", empty)
   TestAssert "the hint comes back", __Shown(kHint)
end TestParameterHint

on TestInsertGoesThroughTheEditor
   get __Command("ideAutocompleteInsertCompletion", 12, "rep", "repeat")
   TestAssert "the editor's textReplace inserts the word", the cReplaced of sEditor is "12,rep,repeat"
end TestInsertGoesThroughTheEditor

--------------------------------------------------------------------------------

-- Whether the list or the hint is on the screen: visible, and on Windows,
-- where the library parks it instead of hiding it, not parked
private function __Shown pStack
   if there is not a stack pStack then return false
   if not the visible of stack pStack then return false
   return the topLeft of stack pStack is not kParked
end __Shown

-- Whether every line of pList is a line of pAmong
private function __AllAmong pList, pAmong
   if pList is empty then return false
   repeat for each line tLine in pList
      if tLine is not among the lines of pAmong then return false
   end repeat
   return true
end __AllAmong

-- The editor's script field on an open stack, with the IDE's stand-in the
-- library asks for an object's key
private command __OpenEditor
   go stack "TestCompletionsListStack"
   set the defaultStack to "TestCompletionsListStack"
   if there is not a field "script" then
      create field "script"
   end if
   set the cScriptField of sEditor to the long id of field "script"
   if there is not a button "standIns" then
      create button "standIns"
      set the script of button "standIns" to \
            "function revRuggedId pObject" & return & "return pObject" & return & "end revRuggedId"
      insert the script of button "standIns" into back
   end if
end __OpenEditor

-- Types pText (with "|" for a return) into the script field, the caret at
-- its end after the word pToken, runs the update the editor asks for and
-- gives the list it shows, or empty if it shows none. The list is closed
-- again; a parameter hint is left as it is.
private function __ListFor pText, pToken
   local tField, tList
   put the cScriptField of sEditor into tField
   replace "|" with return in pText
   set the text of tField to pText
   select after text of tField
   set the cToken of sEditor to pToken
   get __Command("ideAutocompleteUpdate", sEditor, sEditor, empty)
   send "ideAutocomplete_DoUpdate" to stack kLibrary
   if __Shown(kPopup) then
      put the text of field "completions" of stack kPopup into tList
   end if
   -- (cancel the update's timer, and close the list, but not the hint)
   send "ideAutocomplete_DeferredHide" to stack kLibrary
   get __Command("ideAutocompleteCancelFind", sEditor, false)
   return tList
end __ListFor

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
