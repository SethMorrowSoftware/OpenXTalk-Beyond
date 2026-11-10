script "TestMessageBoxAppearanceColours"
-- OXT-Beyond: tests that the script typed in the Message Box is coloured
-- again when the appearance switches between light and dark
-- (ideSystemAppearanceChanged and __RecolorizeMessages, in
-- ide/Toolset/palettes/message box/behaviors/revmessageboxbehavior.livecodescript),
-- and that recalling a line of the history colours it as typed text is
-- (revNextLine and revPrevLine, in
-- ide/Toolset/palettes/message box/behaviors/revmessageboxsinglelinemessagebehavior.livecodescript).
-- Its colours come from revSEColorizeField, which picks the Script
-- Editor's scheme for the appearance (the light one, or "dark mode" in
-- the dark one). Before, the Message Box kept the colours of the
-- appearance the script was typed in, so after a switch from light to
-- dark its words were olive, purple, navy and black on the dark field
-- (seth, the web IDE, 2026-11-08), and the history's lines were coloured
-- with whatever scheme the engine was last given.
--
-- The behaviors need the IDE (a superstack behavior, _internal syntax
-- before the fix), so the test compiles the handlers on their own, from
-- the behaviors' files, into a stack laid out as the Message Box is (a
-- card "Single Line" with fields "message" and "auto complete", a card
-- "Multiple Lines" with a field "script"), with a stand-in stack
-- "revSEUtilities" whose revSEColorizeField notes the fields it was given.
-- (The colours themselves, light and dark, are checked in the web IDE by
-- tools/ci/web-ide-tour.livecodescript's message-box-colours step.)
--
-- It also tests that the selection in both fields is drawn in the Script
-- Editor's highlight colour (__UpdateMessageHilite, from openStack and
-- from a change to the "editor,hilitecolor" preference), which the
-- stand-in's revSEGetPreference answers from gTestMessageBoxHilite.
-- Before, both kept a hiliteColor saved in the stack, much too light in
-- the dark appearance (bwmilby, the forum, 2026-11-09).
-- In kStubs "|" stands for a return and "~" for a quote.
constant kStack = "TestMessageBoxAppearanceColoursStack"

constant kBoxHandlers = "ideSystemAppearanceChanged,__RecolorizeMessages,idePreferenceChanged,__UpdateMessageHilite"
constant kBoxStubs = "local lSelectedCard|command setUpDataView|end setUpDataView|command testUpdateHilite|__UpdateMessageHilite|end testUpdateHilite"

constant kLineHandlers = "revNextLine,revPrevLine"
constant kLineStubs = "local lHistory, lHistoryIndex, lNumInHistory, lMatchingHistory, lNumMatching, lMatchingIndex|command testSetHistory pHistory|put pHistory into lHistory|put the number of lines of pHistory into lNumInHistory|put 0 into lHistoryIndex|end testSetHistory"

constant kUtilities = "global gTestMessageBoxColourized, gTestMessageBoxHilite, gTestMessageBoxPrefAsked|command revSEColorizeField pField|put pField & return after gTestMessageBoxColourized|end revSEColorizeField|command revSEGetPreference pPreference|put pPreference & return after gTestMessageBoxPrefAsked|return gTestMessageBoxHilite|end revSEGetPreference"

global gTestMessageBoxColourized, gTestMessageBoxHilite, gTestMessageBoxPrefAsked

local sSingle, sMultiple

-- The handlers pNames of the file pPath, after pStubs, as one script.
-- (The callers name each file from TestGetIDERepositoryPath() with its path,
-- which is how tools/ci/web_tests.py finds the files to give the web
-- engine.)
private function __Handlers pPath, pNames, pStubs
   local tText, tScript, tName, tKind, tStart, tEnd
   put textDecode(url ("binfile:" & pPath), "UTF-8") into tText
   -- A Windows checkout has CRLF line ends, and the search below goes by
   -- returns
   replace crlf with return in tText
   put pStubs into tScript
   replace "|" with return in tScript
   replace "~" with quote in tScript
   repeat for each item tName in pNames
      put 0 into tStart
      repeat for each item tKind in "on,command,function,private command,private function"
         put offset(return & tKind && tName & return, tText) into tStart
         if tStart is 0 then
            put offset(return & tKind && tName & space, tText) into tStart
         end if
         if tStart is not 0 then
            exit repeat
         end if
      end repeat
      put offset(return & "end " & tName & return, tText, tStart) into tEnd
      TestAssert "found" && tName, tStart is not 0 and tEnd is not 0
      put return & char tStart + 1 to tStart + tEnd + length("end " & tName) of tText after tScript
   end repeat
   return tScript
end __Handlers

on TestSetup
   local tScript
   if there is not a stack "revSEUtilities" then
      create stack "revSEUtilities"
      put kUtilities into tScript
      replace "|" with return in tScript
      set the script of stack "revSEUtilities" to tScript
   end if
   put empty into gTestMessageBoxColourized
   put empty into gTestMessageBoxHilite
   put empty into gTestMessageBoxPrefAsked

   create stack kStack
   set the defaultStack to kStack
   set the name of card 1 of stack kStack to "Single Line"
   create field "auto complete"
   create field "message"
   put the long id of field "message" into sSingle
   set the script of sSingle to __Handlers(TestGetIDERepositoryPath() & "/Toolset/palettes/message box/behaviors/revmessageboxsinglelinemessagebehavior.livecodescript", kLineHandlers, kLineStubs)
   TestAssert "the Single Line handlers compile", the result is empty and "revNextLine" is in the revAvailableHandlers of sSingle
   create card "Multiple Lines"
   create field "script"
   put the long id of field "script" of card "Multiple Lines" of stack kStack into sMultiple
   go card "Single Line" of stack kStack
   set the script of stack kStack to __Handlers(TestGetIDERepositoryPath() & "/Toolset/palettes/message box/behaviors/revmessageboxbehavior.livecodescript", kBoxHandlers, kBoxStubs)
   TestAssert "the Message Box handlers compile", the result is empty and "__RecolorizeMessages" is in the revAvailableHandlers of stack kStack
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if there is a stack "revSEUtilities" then
      delete stack "revSEUtilities"
   end if
end TestTeardown

-- Both of the Message Box's scripts are coloured again, as the
-- appearance changes, whichever card is shown
on TestAppearanceChangeColoursBothFields
   set the text of sSingle to "put the loc of button 1"
   set the text of sMultiple to "put 1 into tX" & return & "answer tX"
   send "ideSystemAppearanceChanged" to stack kStack
   TestAssert "the Single Line message is coloured", sSingle is among the lines of gTestMessageBoxColourized
   TestAssert "the Multiple Lines script is coloured", sMultiple is among the lines of gTestMessageBoxColourized
   TestAssert "each once", the number of lines of gTestMessageBoxColourized is 2

   put empty into gTestMessageBoxColourized
   go card "Multiple Lines" of stack kStack
   send "ideSystemAppearanceChanged" to stack kStack
   TestAssert "the same with the other card shown", the number of lines of gTestMessageBoxColourized is 2
end TestAppearanceChangeColoursBothFields

-- An empty field is left as it is
on TestAppearanceChangeLeavesEmptyFields
   set the text of sSingle to empty
   set the text of sMultiple to "answer 1"
   send "ideSystemAppearanceChanged" to stack kStack
   TestAssert "only the script with text", gTestMessageBoxColourized is sMultiple & return

   put empty into gTestMessageBoxColourized
   set the text of sMultiple to empty
   send "ideSystemAppearanceChanged" to stack kStack
   TestAssert "neither", gTestMessageBoxColourized is empty
end TestAppearanceChangeLeavesEmptyFields

-- A line recalled from the history (the up and down arrows) is coloured
-- by revSEColorizeField, as typed text is, and it is the line recalled
on TestHistoryLineIsColouredAsTyped
   send "testSetHistory" && quote & "answer 2" & quote to sSingle
   send "revNextLine" to sSingle
   TestAssert "next line", the text of sSingle is "answer 2"
   TestAssert "next line coloured", gTestMessageBoxColourized is sSingle & return

   put empty into gTestMessageBoxColourized
   send "revPrevLine" to sSingle
   TestAssert "previous line", the text of sSingle is "answer 2"
   TestAssert "previous line coloured", gTestMessageBoxColourized is sSingle & return
end TestHistoryLineIsColouredAsTyped

-- A colour as the Message Box's stack has saved for both fields
constant kStoredHilite = "200,220,255"

-- The selection in both fields takes the Script Editor's highlight colour:
-- empty (the engine's, as the Script Editor's default on macOS) and a
-- colour (as its default elsewhere), asked for by its preference's name
on TestHiliteFollowsScriptEditor
   set the hiliteColor of sSingle to kStoredHilite
   set the hiliteColor of sMultiple to kStoredHilite
   send "testUpdateHilite" to stack kStack
   TestAssert "the preference asked for", gTestMessageBoxPrefAsked is "editor,hilitecolor" & return
   TestAssert "the Single Line message's is empty", the hiliteColor of sSingle is empty
   TestAssert "the Multiple Lines script's is empty", the hiliteColor of sMultiple is empty

   put "178,180,191" into gTestMessageBoxHilite
   send "testUpdateHilite" to stack kStack
   TestAssert "the Single Line message's is the Script Editor's", the hiliteColor of sSingle is "178,180,191"
   TestAssert "the Multiple Lines script's is the Script Editor's", the hiliteColor of sMultiple is "178,180,191"
end TestHiliteFollowsScriptEditor

-- A change to the Script Editor's highlight preference reaches both
-- fields; a change to another preference leaves them as they are
on TestHilitePreferenceChange
   put "10,20,30" into gTestMessageBoxHilite
   send "idePreferenceChanged" && quote & "cScriptEditor,editor,hilitecolor" & quote & ", 1" to stack kStack
   TestAssert "the Single Line message's follows", the hiliteColor of sSingle is "10,20,30"
   TestAssert "the Multiple Lines script's follows", the hiliteColor of sMultiple is "10,20,30"

   put "40,50,60" into gTestMessageBoxHilite
   send "idePreferenceChanged" && quote & "cScriptEditor,editor,tabdepth" & quote & ", 3" to stack kStack
   TestAssert "not for another preference", the hiliteColor of sSingle is "10,20,30"
end TestHilitePreferenceChange

-- With no Script Editor library the selection is the engine's (empty),
-- not the colour the stack saved
on TestHiliteWithoutScriptEditor
   delete stack "revSEUtilities"
   set the hiliteColor of sSingle to kStoredHilite
   set the hiliteColor of sMultiple to kStoredHilite
   send "testUpdateHilite" to stack kStack
   TestAssert "the Single Line message's is empty", the hiliteColor of sSingle is empty
   TestAssert "the Multiple Lines script's is empty", the hiliteColor of sMultiple is empty
end TestHiliteWithoutScriptEditor
