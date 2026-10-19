script "CoreInterfaceHyperCardScripts"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: HyperTalk that compiles after File > Import Stack, by the
-- IDE's revHyperCardScriptLibrary
-- (ide/Toolset/libraries/revhypercardscriptlibrary.livecodescript), and
-- the library it adds to an imported stack
-- (ide/Toolset/libraries/revhypercardlibrary.livecodescript).

on TestSetup
   TestSkipIfNot "ide"
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revhypercardscriptlibrary.livecodescript")
end TestSetup

private function _Compiles pScript
   local tResult
   if there is not a stack "HCScriptsProbe" then create invisible stack "HCScriptsProbe"
   set the script of stack "HCScriptsProbe" to pScript
   put the result into tResult
   set the script of stack "HCScriptsProbe" to empty
   return tResult is empty
end _Compiles

private function _Lines
   local tLines, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tLines
   end repeat
   delete the last char of tLines
   return tLines
end _Lines

private function _Rewrite
   local tScript, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tScript
   end repeat
   delete the last char of tScript
   return revHyperCardRewriteScript(tScript)
end _Rewrite

private command _Close pStack
   lock messages
   if there is a stack pStack then delete stack pStack
   if there is a stack "HCScriptsProbe" then delete stack "HCScriptsProbe"
   unlock messages
end _Close

private function _ImportFile pPath, pStack
   local tError
   lock messages
   try
      import stack from file TestGetInputFile("hypercard/" & pPath)
   catch tError
   end try
   unlock messages
   TestAssert pPath && "imports", tError is empty and there is a stack pStack
   return pStack
end _ImportFile

-- The original of an object's script, kept by revHyperCardFixScripts
private function _Kept pObject
   local tSet
   put the customProperties["uHyperCard"] of pObject into tSet
   return tSet["script"]
end _Kept

on TestHyperCardScriptsRules
   -- each rule, on a script that does not compile; strings and comments
   -- are left alone
   local tScript
   put _Rewrite("on mouseUp", "  global group, stacks", "  put 1 into group", "  put " & quote & "group" & quote & " into stacks -- group", "end mouseUp") into tScript
   TestAssert "T2: variables renamed", tScript is _Lines("on mouseUp", "  global hc_group, hc_stacks", "  put 1 into hc_group", "  put " & quote & "group" & quote & " into hc_stacks -- group", "end mouseUp")

   put _Rewrite("on doMenu which", "  if which is " & quote & "Quit" & quote & " then exit doMenu", "  pass doMenu", "end doMenu") into tScript
   TestAssert "T1: on doMenu renamed with its exit and pass", tScript is _Lines("on hcDoMenu which", "  if which is " & quote & "Quit" & quote & " then exit hcDoMenu", "  pass hcDoMenu", "end hcDoMenu")

   put _Rewrite("on mouseUp", "  put the message box into x", "  put the msg into y", "end mouseUp") into tScript
   TestAssert "T4: the message box", tScript is _Lines("on mouseUp", "  put msg into x", "  put msg into y", "end mouseUp")

   put _Rewrite("on mouseUp", "  put field result into x", "  put the number of bkgnd fields into y", "end mouseUp") into tScript
   TestAssert "T3: an object name that is a keyword, quoted", tScript is _Lines("on mouseUp", "  put field " & quote & "result" & quote & " into x", "  put the number of bkgnd fields into y", "end mouseUp")

   put _Rewrite("on mouseUp", "  play harpsichord c e g bb", "end mouseUp") into tScript
   TestAssert "T5: notes quoted", line 2 of tScript is "  play harpsichord " & quote & "c e g bb" & quote

   put _Rewrite("on mouseUp", "  if length of x > 3 then put selection into y", "end mouseUp") into tScript
   TestAssert "T7: functions without the", line 2 of tScript is "  if the length of x > 3 then put the selection into y"

   put _Rewrite("on mouseUp", "  visual effect dissolve EFFECT_SPEED", "  go to stack home", "  reset menubar", "end mouseUp") into tScript
   TestAssert "T14: a visual effect from a variable", line 2 of tScript is "  do " & quote & "visual effect dissolve" & quote && "&& EFFECT_SPEED"
   TestAssert "T9: go home", line 3 of tScript is "  hcGoHome"
   TestAssert "T8: reset menubar", line 4 of tScript is "  hcResetMenubar"

   put _Rewrite("on mouseUp", "  put the version into x", "  get the long version", "  put the rect of cd window into r", "  go to cd prev", "  set the hilite of btn 1 of cd to true", "  exit to HyperCard", "end mouseUp") into tScript
   TestAssert "T10: the version", line 2 of tScript is "  put hcVersion() into x"
   TestAssert "T10: the long version", line 3 of tScript is "  get hcLongVersion()"
   TestAssert "T11: the card window", line 4 of tScript is "  put the rect of this stack into r"
   TestAssert "T11: cd prev", line 5 of tScript is "  go to prev cd"
   TestAssert "T11: of cd", line 6 of tScript is "  set the hilite of btn 1 of this cd to true"
   TestAssert "T11: exit to HyperCard", line 7 of tScript is "  exit to top"

   put _Rewrite("on mouseUp", "  put the version of scriptingLanguage " & quote & "AppleScript" & quote & " into x", "  get version of scriptingLanguage " & quote & "AppleScript" & quote, "end mouseUp") into tScript
   TestAssert "T10: the version of a scripting language", line 2 of tScript is "  put hcVersion() into x"
   TestAssert "T10: version of a scripting language, without the", line 3 of tScript is "  get hcVersion()"

   put _Rewrite("junk before", "on mouseUp", "  put 1 into x", "end mouseUp", "junk after") into tScript
   TestAssert "T0: text outside handlers", tScript is _Lines("-- junk before", "on mouseUp", "  put 1 into x", "end mouseUp", "-- junk after")

   put _Rewrite("on mouseUp", "  palette " & quote & "Navigator" & quote & ", " & quote & "100,100" & quote, "  put x into menu " & quote & "Go" & quote & " \", "  with menuMsg " & quote & "m" & quote, "  beep", "end mouseUp") into tScript
   TestAssert "T12: palette with a location", line 2 of tScript is "  hcPalette " & quote & "Navigator" & quote & ", " & quote & "100,100" & quote
   TestAssert "T12: a continued command on one line, the line count kept", line 3 of tScript is "  hcPutIntoMenu x, " & quote & "into" & quote & ", " & quote & "Go" & quote & ", " & quote & "m" & quote and line 4 of tScript is empty and line 5 of tScript is "  beep"

   put _Rewrite("on mouseUp", "  put " & quote & "x into menu Go with menuMsg y" & quote & " into tMenu", "  reset menubar -- palette a, b", "end mouseUp") into tScript
   TestAssert "T12: a command's words inside a string are not the command", line 2 of tScript is "  put " & quote & "x into menu Go with menuMsg y" & quote & " into tMenu"
   TestAssert "T8: a comment kept, and not read as a command", line 3 of tScript is "  hcResetMenubar -- palette a, b"

   put revHyperCardRewriteScript(_Lines("on mouseUp", "  popUp the short name of me, true", "end mouseUp"), "PopUp") into tScript
   TestAssert "T13: an external named like a command", line 2 of tScript is "  hcX_popUp the short name of me, true"
end TestHyperCardScriptsRules

on TestHyperCardScriptsFix
   -- a stack as an import leaves it: scripts that do not compile, one that
   -- does, one with a handler that cannot be saved by rewriting
   local tStack, tReport, tGood, tSet, tOriginal
   put "HCScripts" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("on openStack", "  global group", "  put 1 into group", "end openStack")
   create button "Good"
   put _Lines("on mouseUp", "  put 1 into x", "end mouseUp") into tGood
   set the script of button "Good" to tGood
   -- (the engine ends a script with a return)
   put the script of button "Good" into tGood
   put the script of stack tStack into tOriginal
   create button "Mixed"
   set the script of button "Mixed" to _Lines("on mouseUp", "  put 2 into y", "end mouseUp", "on mouseDown", "  put 1 +* into", "end mouseDown", "function f", "  put ( into z", "end f")
   create button "Named"
   set the script of button "Named" to _Lines("on mouseUp", "  put 3 into w", "end mouseUp", "on " & quote & "v" & quote, "  beep", "end " & quote & "v" & quote)
   unlock messages

   put revHyperCardFixScripts(tStack) into tReport
   TestAssert "a report", "HyperCard scripts: 3 rewritten, 2 salvaged" is in tReport
   TestAssert "the stack script compiles", _Compiles(the script of stack tStack)
   TestAssert "the stack script rewritten", "global hc_group" is in the script of stack tStack
   TestAssert "its HyperTalk kept", _Kept(the long id of stack tStack) is tOriginal
   TestAssert "a script that compiles: unchanged", the script of button "Good" of stack tStack is tGood
   TestAssert "a script that compiles: nothing kept", _Kept(the long id of button "Good" of stack tStack) is empty
   TestAssert "salvaged: compiles", _Compiles(the script of button "Mixed" of stack tStack)
   TestAssert "salvaged: the handler that compiled kept as it was", line 1 to 3 of the script of button "Mixed" of stack tStack is _Lines("on mouseUp", "  put 2 into y", "end mouseUp")
   TestAssert "salvaged: the bad handler passes its message", "   pass mouseDown" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: its HyperTalk inside, commented out", "   --   put 1 +* into" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: a bad function returns empty", "   return empty" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: a handler no name can call, commented out whole", _Compiles(the script of button "Named" of stack tStack) and "-- on " & quote & "v" & quote is among the lines of the script of button "Named" of stack tStack
   TestAssert "logged in the hcImportStat", "HyperCard scripts: 3 rewritten" is in the hcImportStat
   put the customProperties["uHyperCard"] of stack tStack into tSet
   TestAssert "the report kept on the stack", tSet["scripts"] is tReport

   -- the library, as the stack's behavior
   TestAssert "library added", "HyperCard Library" is among the lines of the substacks of stack tStack
   TestAssert "library is the behavior", the short name of the behavior of stack tStack is "HyperCard Library"
   TestAssert "library compiles", _Compiles(the script of stack "HyperCard Library" of stack tStack)
   _Close tStack

   -- a substack the import made with the library's name (a palette, say)
   -- is left alone
   put "HCClash" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   create invisible stack "HyperCard Library"
   set the mainStack of it to tStack
   set the script of stack "HyperCard Library" of stack tStack to _Lines("on palette", "end palette")
   set the script of stack tStack to _Lines("on openStack", "  put the message box into x", "end openStack")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "a clash: the library under a free name", the short name of the behavior of stack tStack is "HyperCard Library 2"
   TestAssert "a clash: the other substack untouched", the script of stack "HyperCard Library" of stack tStack is _Lines("on palette", "end palette") & return or the script of stack "HyperCard Library" of stack tStack is _Lines("on palette", "end palette")
   _Close tStack
end TestHyperCardScriptsFix

on TestHyperCardScriptsLibrary
   -- the rewritten scripts reach the library through the stack's behavior
   local tStack
   global gHCScriptsTest
   put "HCLibrary" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("on doMenu which", "  global gHCScriptsTest", "  put which into gHCScriptsTest", "  if which is " & quote & "Keep" & quote & " then exit doMenu", "  pass doMenu", "end doMenu")
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", "  doMenu " & quote & "Keep" & quote, "  put comma & the version after gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "doMenu routed to the stack's handler", "  hcDoMenu " & quote & "Keep" & quote is among the lines of the script of button "B" of stack tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "the stack's doMenu handler sees the script's doMenu, and the version is HyperCard's", gHCScriptsTest is "Keep,2.4.1"
   _Close tStack
end TestHyperCardScriptsLibrary

on TestHyperCardScriptsLoadedByIDE
   -- the IDE loads its libraries by sending extensionInitialize
   -- (revInternal__LoadLibrary); the library must then be in the message
   -- path, or File > Import Stack cannot call it
   local tLib
   put the long id of stack "revHyperCardScriptLibrary" into tLib
   send "extensionInitialize" to stack "revHyperCardScriptLibrary"
   TestAssert "extensionInitialize puts the library in the backScripts", tLib is among the lines of the backScripts
   send "extensionFinalize" to stack "revHyperCardScriptLibrary"
   TestAssert "extensionFinalize takes it out", tLib is not among the lines of the backScripts
end TestHyperCardScriptsLoadedByIDE

on TestHyperCardScriptsTwoImports
   -- each imported stack gets its own library, closed, whatever library
   -- of a stack imported before is in memory
   local tFirst, tSecond
   put "HCFirst" & the milliseconds into tFirst
   put "HCSecond" & the milliseconds into tSecond
   lock messages
   create invisible stack tFirst
   create invisible stack tSecond
   unlock messages
   get revHyperCardFixScripts(the long id of stack tFirst)
   get revHyperCardFixScripts(the long id of stack tSecond)
   TestAssert "the first stack has its library", "HyperCard Library" is among the lines of the substacks of stack tFirst
   TestAssert "the second stack has its own library", "HyperCard Library" is among the lines of the substacks of stack tSecond
   TestAssert "the second library is marked as the library", the uHyperCard["library"] of stack "HyperCard Library" of stack tSecond is true
   TestAssert "the libraries are not left open", "HyperCard Library" is not among the lines of the openStacks
   _Close tFirst
   _Close tSecond
end TestHyperCardScriptsTwoImports

on TestHyperCardScriptsStandIns
   -- calls to the externals stacks call most reach the library's
   -- stand-ins (those that need no dialog)
   local tStack
   global gHCScriptsTest
   put "HCStandIns" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put (MaxDepth() is the screenDepth) & comma & NewMenu(" & quote & "Tools" & quote & ", " & quote & "One" & quote & ") & comma & NewMenu(" & quote & "More" & quote & ") into gHCScriptsTest", \
         "  put comma & DeleteMenu(1) after gHCScriptsTest", \
         "  ShowMenu 2", \
         "  put comma & the result after gHCScriptsTest", \
         "  HCBalloon " & quote & "off" & quote, \
         "  HCBalloon " & quote & "query" & quote, \
         "  put comma & the result after gHCScriptsTest", \
         "  Dialoger " & quote & "Ask" & quote, \
         "  put comma & the result after gHCScriptsTest", \
         "end mouseUp")
   create button "Balloon"
   set the script of button "Balloon" to _Lines("on mouseEnter", "  HCBalloon " & quote & "Click me" & quote, "end mouseEnter")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "MaxDepth, NewMenu, DeleteMenu, ShowMenu, HCBalloon query, Dialoger", gHCScriptsTest is "true,1,2,,HyperCard menus are not supported yet,false,The Dialoger external is not supported"
   send "mouseEnter" to button "Balloon" of stack tStack
   TestAssert "HCBalloon: balloons off, no tooltip", the toolTip of button "Balloon" of stack tStack is empty
   send "HCBalloon" && quote & "on" & quote to button "B" of stack tStack
   send "mouseEnter" to button "Balloon" of stack tStack
   TestAssert "HCBalloon: the target's tooltip", the toolTip of button "Balloon" of stack tStack is "Click me"
   TestAssert "PopUpMenu items: semicolons, else returns, else commas", \
         value("hcPopUpItems(" & quote & "a;b,c" & quote & ")", button "B" of stack tStack) is _Lines("a", "b,c") \
         and value("hcPopUpItems(" & quote & "a,b" & quote & ")", button "B" of stack tStack) is _Lines("a", "b")
   TestAssert "HPopUpMenu: a submenu choice is line,item", \
         value("hcHPopUpChoice(" & quote & "Edit" & quote & " & return & " & quote & "File,Open,Save" & quote & ", " & quote & "File|Save" & quote & ")", button "B" of stack tStack) is "2,2"
   TestAssert "HPopUpMenu: an entry with no submenu is line,0", \
         value("hcHPopUpChoice(" & quote & "Edit" & quote & " & return & " & quote & "File,Open,Save" & quote & ", " & quote & "Edit" & quote & ")", button "B" of stack tStack) is "1,0"
   _Close tStack
end TestHyperCardScriptsStandIns

on TestHyperCardScriptsImported
   -- a stack the engine imports: every script compiles afterwards, and
   -- one that compiled is unchanged
   local tStack, tReport, tLine, tObject, tFailed
   put _ImportFile("TestV1.stack", "TestV1.stack") into tStack
   put revHyperCardFixScripts(tStack) into tReport
   TestAssert "TestV1: scripts rewritten", "HyperCard scripts: 4 rewritten" is in tReport
   set the itemDelimiter to tab
   repeat for each line tLine in tReport
      if item 2 of tLine is empty then next repeat
      put item 1 of tLine into tObject
      if word 1 of tObject is "Added:" then next repeat
      if not _Compiles(the script of tObject) then put tObject & return after tFailed
   end repeat
   TestAssert "TestV1: every rewritten script compiles", tFailed is empty
   _Close tStack
end TestHyperCardScriptsImported
