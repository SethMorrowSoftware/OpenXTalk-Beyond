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
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revhypercarddiskimagelibrary.livecodescript")
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

-- _Rewrite for a stack with HyperCard's message order (its
-- hyperTalkCompatible), where doMenu keeps its name
private function _RewriteHyperTalk
   local tScript, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tScript
   end repeat
   delete the last char of tScript
   return revHyperCardRewriteScript(tScript, empty, true)
end _RewriteHyperTalk

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

-- The name of the library revHyperCardFixScripts adds to a stack
private function _Library pStack
   return "HyperCard Library (" & the short name of stack pStack & ")"
end _Library

-- The substack revHyperCardFixScripts adds to a stack with HyperCard's
-- message order, as its library's behavior, for doMenu
private function _Menus pStack
   return "HyperCard Menus (" & the short name of stack pStack & ")"
end _Menus

-- The original of an object's script, kept by revHyperCardFixScripts
private function _Kept pObject
   local tSet
   put the customProperties["uHyperCard"] of pObject into tSet
   return tSet["script"]
end _Kept

-- The pages pObject's mouseUp prints in a job printing to the PDF pFile
-- (0 when it writes none): what the job's PDF names a page ("/Type
-- /Page", the pages' list "/Type /Pages" aside)
private function _PrintedPages pObject, pFile
   local tError, tData, tAt, tFound, tPages
   if there is a file pFile then delete file pFile
   open printing to pdf pFile
   try
      send "mouseUp" to pObject
   catch tError
   end try
   close printing
   if there is not a file pFile then return 0
   put URL ("binfile:" & pFile) into tData
   put 0 into tPages
   put 0 into tAt
   repeat
      put offset("/Type /Page", tData, tAt) into tFound
      if tFound is 0 then exit repeat
      add tFound to tAt
      if char tAt + 11 of tData is not "s" then add 1 to tPages
   end repeat
   return tPages
end _PrintedPages

on TestHyperCardScriptsRules
   -- each rule, on a script that does not compile; strings and comments
   -- are left alone
   local tScript
   put _Rewrite("on mouseUp", "  global group, stacks", "  put 1 into group", "  put " & quote & "group" & quote & " into stacks -- group", "end mouseUp") into tScript
   TestAssert "T2: variables renamed", tScript is _Lines("on mouseUp", "  global hc_group, hc_stacks", "  put 1 into hc_group", "  put " & quote & "group" & quote & " into hc_stacks -- group", "end mouseUp")

   put _Rewrite("on doMenu which", "  if which is " & quote & "Quit" & quote & " then exit doMenu", "  pass doMenu", "end doMenu") into tScript
   TestAssert "T1: on doMenu renamed with its exit and pass", tScript is _Lines("on hcDoMenu which", "  if which is " & quote & "Quit" & quote & " then exit hcDoMenu", "  pass hcDoMenu", "end hcDoMenu")

   -- a handler named like a command, called with values only (Video
   -- Poker's "sort" and "rename i"), and the command itself left alone
   put _Rewrite("on openCard", "  sort", "  put 2 into i", "  rename i", "  if i > 1 then rename 0", "  sort lines of x by word 2 of each", "end openCard", "on sort", "  beep", "end sort", "on rename n", "  put n into x", "end rename") into tScript
   TestAssert "T1: a bare call to a handler named like a command", line 2 of tScript is "  hc_sort"
   TestAssert "T1: a call with a variable", line 4 of tScript is "  hc_rename i"
   TestAssert "T1: a call after then, with a number", line 5 of tScript is "  if i > 1 then hc_rename 0"
   TestAssert "T1: the command with its own words is not the handler", line 6 of tScript is "  sort lines of x by word 2 of each"
   TestAssert "T1: the handlers renamed", line 8 of tScript is "on hc_sort" and line 11 of tScript is "on hc_rename n"
   TestAssert "T1: the calls compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", "  put the message box into x", "  put the msg into y", "end mouseUp") into tScript
   TestAssert "T4: the message box", tScript is _Lines("on mouseUp", "  put msg into x", "  put msg into y", "end mouseUp")

   put _Rewrite("on mouseUp", "  put field result into x", "  put the number of bkgnd fields into y", "end mouseUp") into tScript
   TestAssert "T3: an object name that is a keyword, quoted", tScript is _Lines("on mouseUp", "  put field " & quote & "result" & quote & " into x", "  put the number of bkgnd fields into y", "end mouseUp")

   put _Rewrite("on mouseUp", "  play harpsichord c e g bb", "end mouseUp") into tScript
   TestAssert "T5: notes quoted", line 2 of tScript is "  play harpsichord " & quote & "c e g bb" & quote

   put _Rewrite("on mouseUp", "  if length of x > 3 then put selection into y", "end mouseUp") into tScript
   TestAssert "T7: functions without the", line 2 of tScript is "  if the length of x > 3 then put the selection into y"
   -- (and before the "of" of the next line, a statement continued with \,
   -- "the rect of btn item 2 of value\" then "of the foundLine then",
   -- Lesson 1 Severn Ojibwe's, which this engine refused)
   put _Rewrite("on mouseUp", "  if loc of the target is within the rect of btn item 2 of value\", "  of the foundLine then beep", \
         "  put x & number\", "  of cards into y", "end mouseUp") into tScript
   TestAssert "T7: functions without the before the next line's of", line 2 to 5 of tScript \
         is _Lines("  if loc of the target is within the rect of btn item 2 of the value\", "  of the foundLine then beep", "  put x & the number\", "  of cards into y")
   TestAssert "T7: those compile", _Compiles(tScript)

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

   -- the heapSpace, which Gems of Hubble checks before it quits
   put _Rewrite("on mouseUp", "  if the HeapSpace < 1321000 then beep", "  put heapSpace() into x", "end mouseUp") into tScript
   TestAssert "T10: the heapSpace", line 2 of tScript is "  if hcHeapSpace() < 1321000 then beep"
   TestAssert "T10: heapSpace()", line 3 of tScript is "  put hcHeapSpace() into x"

   -- the short version of HyperCard, which this engine refuses
   put _Rewrite("on mouseUp", "  if the short version of HyperCard < 1.2 then beep", "  if short version of hypercard > 2.2 then beep", "end mouseUp") into tScript
   TestAssert "T10: the short version of HyperCard, with the and without", line 2 to 3 of tScript is _Lines("  if hcVersion() < 1.2 then beep", "  if hcVersion() > 2.2 then beep")
   TestAssert "T10: those compile", _Compiles(tScript)

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

   put _Rewrite("on doMenu menuItem, menu", "  if menuItem is " & quote & "Quit" & quote & " then put menu into x", "  put the short name of this card into this", "  put line this of field " & quote & "List" & quote & " into item", "  get item 2 of item", "  pass doMenu", "end doMenu") into tScript
   TestAssert "T2: parameters named like words of the grammar", line 1 of tScript is "on hcDoMenu hc_menuItem, hc_menu"
   TestAssert "T2: renamed where a variable stands", line 2 of tScript is "  if hc_menuItem is " & quote & "Quit" & quote & " then put hc_menu into x"
   TestAssert "T2: this, the word and the variable", line 3 of tScript is "  put the short name of this card into hc_this"
   TestAssert "T2: a chunk's number", line 4 of tScript is "  put line hc_this of field " & quote & "List" & quote & " into hc_item"
   TestAssert "T2: the chunk word kept", line 5 of tScript is "  get item 2 of hc_item"

   put _Rewrite("on mouseUp", "  global gOne, \", "    button", "  put 1 into button", "  get card fld button", "end mouseUp", "on mouseDown", "  get field next", "  put card fld button into t", "  put line 1 of bkgnd field title of this card into t", "  put the number of card buttons into n", "end mouseDown") into tScript
   TestAssert "T2: a global over two lines", line 3 of tScript is "    hc_button" and line 4 of tScript is "  put 1 into hc_button"
   TestAssert "T2: the variable as an object's name", line 5 of tScript is "  get card fld hc_button"
   TestAssert "T3: field next", line 8 of tScript is "  get field " & quote & "next" & quote
   TestAssert "T3: card fld button", line 9 of tScript is "  put card fld " & quote & "button" & quote & " into t"
   TestAssert "T3: a name before of this card", line 10 of tScript is "  put line 1 of bkgnd field " & quote & "title" & quote & " of this card into t"
   TestAssert "T3: card buttons: unchanged", line 11 of tScript is "  put the number of card buttons into n"

   put _Rewrite("on mouseUp", "  answer file " & quote & "Which stack?" & quote & " of type stack", "  answer " & quote & "Go?" & quote & " with " & quote & "Cancel" & quote & "," & quote & "OK" & quote, "  create stack " & quote & "New" & quote & " with bkgnd 1 in a new window", "  go to first card of " & quote & "Home" & quote, "  if x then delete item 2 to the number of items in line 3 of fld 1 of line 3 of fld 1", "  return top of window", "  choose tool 4", "  choose btn tool", "end mouseUp") into tScript
   TestAssert "T31: answer file of type stack", line 2 of tScript is "  answer file " & quote & "Which stack?" & quote & " of type " & quote & "STAK" & quote
   TestAssert "T31: answer with replies between commas", line 3 of tScript is "  answer " & quote & "Go?" & quote & " with " & quote & "Cancel" & quote & " or " & quote & "OK" & quote
   TestAssert "T31: create stack in a new window", line 4 of tScript is "  create stack " & quote & "New" & quote & " with bkgnd 1"
   TestAssert "T31: of a stack named without stack", line 5 of tScript is "  do hcGo(" & quote & "go to first card of stack tHCStack" & quote & ", quote & " & quote & "Home" & quote & " & quote)"
   TestAssert "T31: the number of items in a chunk of the same chunk", line 6 of tScript is "  if x then delete item 2 to (the number of items in line 3 of fld 1) of line 3 of fld 1"
   TestAssert "T11: of window", line 7 of tScript is "  return top of this stack"
   TestAssert "T30: choose tool 4", line 8 of tScript is "  hcChooseTool 4"
   TestAssert "T30: choose btn tool", line 9 of tScript is "  choose button tool"

   put _Rewrite("on readIt this, machine", "  read from file this for 100", "  set the hilite of btn machine of cd 1 to true", "  go to first card of stack", "  put the number of items in fld " & quote & "F" & quote & " in card " & quote & "K" & quote & " into x", "  put number of cards into n", "  if version < 2 then beep", "  domenu " & quote & "Quit HyperCard", "  delete menuItem " & quote & "New Card" & quote & " from menu " & quote & "Edit" & quote, "  play harpsichord tempo t c5e d e", "  put card field cards into x", "end readIt") into tScript
   TestAssert "T2: a variable before for", line 2 of tScript is "  read from file hc_this for 100"
   TestAssert "T2: a variable as an object's name before of", line 3 of tScript is "  set the hilite of btn hc_machine of cd 1 to true"
   TestAssert "T11: of stack", line 4 of tScript is "  go to first card of this stack"
   TestAssert "T11: in card for of card", line 5 of tScript is "  put the number of items in fld " & quote & "F" & quote & " of card " & quote & "K" & quote & " into x"
   TestAssert "T7: number of without the", line 6 of tScript is "  put the number of cards into n"
   TestAssert "T7: version without the", line 7 of tScript is "  if hcVersion() < 2 then beep"
   TestAssert "T31: a string closed at the end of the line (and Quit HyperCard to the library, T27)", line 8 of tScript is "  hcDoMenu " & quote & "Quit HyperCard" & quote
   TestAssert "T22: delete menuItem from menu", line 9 of tScript is "  hcDeleteMenuItem " & quote & "Edit" & quote & ", " & quote & "New Card" & quote
   TestAssert "T5: notes after a tempo in a variable", line 10 of tScript is "  play harpsichord tempo t " & quote & "c5e d e" & quote
   TestAssert "T3: a field named cards", line 11 of tScript is "  put card field " & quote & "cards" & quote & " into x"

   put _Rewrite("on mouseUp", "  set the visible of tool window to not the visible of tool window", "  if the visible of the message watcher then beep", "end mouseUp") into tScript
   TestAssert "T28: HyperCard's own windows: set", line 2 of tScript is "  hcSetWindow " & quote & "visible" & quote & ", " & quote & "tool" & quote & ", not hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "tool" & quote & ")"
   TestAssert "T28: the message watcher is not the message box", line 3 of tScript is "  if hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "message watcher" & quote & ") then beep"

   -- T2: a variable named len or offset before of, which HyperCard had no
   -- function of ("char stop to stop + len of field "Text"", Jargon's;
   -- "character charNo + offset of field ...", Cipher's); and the format
   -- of a convert, which is not the variable named seconds (On This
   -- Date's), where the variable after to is
   put _Rewrite("on mouseUp", "  put 1 into len", "  put 2 into offset", "  put 3 into seconds", \
         "  delete char stop to stop + len of field " & quote & "Text" & quote, \
         "  put character charNo + offset of field 1 after x", \
         "  if len > 0 then convert t to seconds", \
         "  add 1 to seconds", \
         "  put the length of x into len", \
         "end mouseUp") into tScript
   TestAssert "T2: len before of", line 5 of tScript is "  delete char stop to stop + hc_len of field " & quote & "Text" & quote
   TestAssert "T2: offset before of", line 6 of tScript is "  put character charNo + hc_offset of field 1 after x"
   TestAssert "T2: the format of a convert: unchanged", line 7 of tScript is "  if hc_len > 0 then convert t to seconds"
   TestAssert "T2: the variable after to", line 8 of tScript is "  add 1 to hc_seconds"
   TestAssert "T2: the length of: unchanged", line 9 of tScript is "  put the length of x into hc_len"
   TestAssert "T2: those compile", _Compiles(tScript)
end TestHyperCardScriptsRules

on TestHyperCardScriptsRulesForAll
   -- the rules that apply to every script, compiling or not: each takes
   -- a statement that stops with an error here where HyperCard went on
   local tScript, q, tStack, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  go to stack " & q & "Other" & q, "  if x then go to card 2 of stack tName in a new window else beep", "  go to card 3", "  go to this card of stack " & q & "Addresses" & q & " -- c", "end mouseUp") into tScript
   TestAssert "T16: go to a stack", line 2 of tScript is "  do hcGo(" & q & "go to stack tHCStack" & q & ", quote & " & q & "Other" & q & " & quote)"
   TestAssert "T16: the statement up to else, its window kept", line 3 of tScript is "  if x then do hcGo(" & q & "go to card 2 of stack tHCStack in a new window" & q & ", " & q & "tName" & q & ") else beep"
   TestAssert "T16: go to a card of this stack: unchanged", line 4 of tScript is "  go to card 3"
   TestAssert "T16: a comment kept", line 5 of tScript is "  do hcGo(" & q & "go to this card of stack tHCStack" & q & ", quote & " & q & "Addresses" & q & " & quote) -- c"

   put _Rewrite("on mouseUp", "  if x then go stack " & q & "A" & q & " else go stack " & q & "B" & q, "  if y then tabKey else set the cursor to 4", "end mouseUp") into tScript
   TestAssert "T16: both branches of a one-line if", line 2 of tScript is "  if x then do hcGo(" & q & "go stack tHCStack" & q & ", quote & " & q & "A" & q & " & quote) else do hcGo(" & q & "go stack tHCStack" & q & ", quote & " & q & "B" & q & " & quote)"
   TestAssert "T18, T17: both branches of a one-line if", line 3 of tScript is "  if y then hcTabKey else set the cursor to hcCursor(4)"

   put _Rewrite("on mouseUp", "  go to stack " & q & "Home" & q, "  set cursor to " & q & "Blue" & q, "  set the cursor to 4", "  tabKey", "  if y then arrowKey right", "  picture " & q & "Map" & q & ", resource", "end mouseUp") into tScript
   TestAssert "T9: go to stack " & q & "Home" & q, line 2 of tScript is "  hcGoHome"
   TestAssert "T17: the cursor by name", line 3 of tScript is "  set the cursor to hcCursor(" & q & "Blue" & q & ")"
   TestAssert "T17: the cursor by number", line 4 of tScript is "  set the cursor to hcCursor(4)"
   TestAssert "T18: tabKey", line 5 of tScript is "  hcTabKey"
   TestAssert "T18: arrowKey after then", line 6 of tScript is "  if y then hcArrowKey right"
   TestAssert "T18: picture", line 7 of tScript is "  hcPicture " & q & "Map" & q & ", resource"

   put _Rewrite("on mouseUp", "  hide card picture", "  show bg pict of card 3", "  hide window " & q & "scroll" & q, "  close window " & q & "Map" & q, "  show window " & q & "Map" & q & " at 10,20", "  hide scroll window", "end mouseUp") into tScript
   TestAssert "T19: hide card picture", line 2 of tScript is "  hcShowPicture " & q & "card" & q & ", false"
   TestAssert "T19: show bg pict of a card", line 3 of tScript is "  hcShowPicture " & q & "background" & q & ", true, the long id of card 3"
   TestAssert "T21: hide window", line 4 of tScript is "  hcWindow " & q & "hide" & q & ", " & q & "scroll" & q
   TestAssert "T21: close window", line 5 of tScript is "  hcWindow " & q & "close" & q & ", " & q & "Map" & q
   TestAssert "T21: show window at", line 6 of tScript is "  hcWindow " & q & "show" & q & ", " & q & "Map" & q & ", 10,20"
   TestAssert "T21: HyperCard's own windows", line 7 of tScript is "  hcWindow " & q & "hide" & q & ", " & q & "scroll" & q

   put _Rewrite("on mouseUp", "  put fileName(" & q & "STAK" & q & ") into f", "  put the fileName of this stack into g", "end mouseUp") into tScript
   TestAssert "T20: fileName()", line 2 of tScript is "  put hcX_fileName(" & q & "STAK" & q & ") into f"
   TestAssert "T20: the fileName property: unchanged", line 3 of tScript is "  put the fileName of this stack into g"

   put _Rewrite("on mouseUp", "  put fld 1 after menu " & q & "Keys" & q, "  disable menuItem " & q & "Two" & q & " of menu " & q & "Tools" & q, "  set the checkMark of menuItem 1 of menu " & q & "Tools" & q & " to true", "  if the checkmark of menuItem 1 of menu " & q & "Tools" & q & " then beep", "  delete menuItem 1 of menu " & q & "Tools" & q, "end mouseUp") into tScript
   TestAssert "T22: put after menu", line 2 of tScript is "  hcPutIntoMenu fld 1, " & q & "after" & q & ", " & q & "Keys" & q & ", empty, empty"
   TestAssert "T22: disable menuItem", line 3 of tScript is "  hcEnableMenu false, " & q & "Tools" & q & ", " & q & "Two" & q
   TestAssert "T22: set the checkMark of menuItem", line 4 of tScript is "  hcSetMenuItem " & q & "checkmark" & q & ", " & q & "Tools" & q & ", 1, true"
   TestAssert "T22: the checkMark of menuItem", line 5 of tScript is "  if hcMenuItem(" & q & "checkmark" & q & ", " & q & "Tools" & q & ", 1) then beep"
   TestAssert "T22: delete menuItem", line 6 of tScript is "  hcDeleteMenuItem " & q & "Tools" & q & ", 1"

   -- "in menu", a menu item by its place, and a property without the
   -- (Audio Help's and HyperJack's)
   put _Rewrite("on mouseUp", "  set the checkmark of menuItem tItem in menu 3 to true", "  put tName into last menuItem of menu 3 with menuMsg APHideNotes", "  disable last menuItem of menu 3", "  if checkMark of menuItem " & q & "Sound" & q & " of menu " & q & "Option" & q & " is true then beep", "  if the enabled of menuItem 2 in menu 3 then beep", "end mouseUp") into tScript
   TestAssert "T22: set ... of menuItem in menu", line 2 of tScript is "  hcSetMenuItem " & q & "checkmark" & q & ", 3, tItem, true"
   TestAssert "T22: put into last menuItem with menuMsg", line 3 of tScript is "  hcPutIntoMenu tName, " & q & "into" & q & ", 3, APHideNotes, " & q & "last" & q
   TestAssert "T22: disable last menuItem", line 4 of tScript is "  hcEnableMenu false, 3, " & q & "last" & q
   TestAssert "T22: a menu item's property without the", line 5 of tScript is "  if hcMenuItem(" & q & "checkmark" & q & ", " & q & "Option" & q & ", " & q & "Sound" & q & ") is true then beep"
   TestAssert "T22: the property of menuItem in menu", line 6 of tScript is "  if hcMenuItem(" & q & "enabled" & q & ", 3, 2) then beep"

   put _Rewrite("on mouseUp", "  start using stack " & q & "Lib" & q, "  stop using stack tName", "  print card field " & q & "Notes" & q, "  print card 3", "end mouseUp") into tScript
   TestAssert "T23: start using a stack", line 2 of tScript is "  hcStartUsing " & q & "Lib" & q
   TestAssert "T23: stop using a stack", line 3 of tScript is "  hcStopUsing tName"
   TestAssert "T24: print a field", line 4 of tScript is "  PrintField the long id of card field " & q & "Notes" & q
   TestAssert "T24: print a card: unchanged", line 5 of tScript is "  print card 3"

   put _Rewrite("on mouseUp", "  go " & q & "Addresses" & q, "  go to it in a new window", "  go to first card in bkgnd " & q & "Index" & q, "  go to the next card", "  go back", "end mouseUp") into tScript
   TestAssert "T25: go to a stack by its name", line 2 of tScript is "  hcGoTo " & q & "Addresses" & q
   TestAssert "T25: go to an expression, its window kept", line 3 of tScript is "  hcGoTo it, " & q & "in a new window" & q
   TestAssert "T25: in for of", line 4 of tScript is "  go to first card of bkgnd " & q & "Index" & q
   TestAssert "T25: go to the next card: unchanged", line 5 of tScript is "  go to the next card"
   TestAssert "T25: go back: unchanged", line 6 of tScript is "  go back"

   put _Rewrite("on mouseUp", "  set the scale of window pictureWindow to -1", "  set scroll of window " & q & "Map" & q & " to " & q & "10,10" & q, "  set hilitedButton of wd " & q & "Tools" & q & " to 0", "  set the scroll of card window to 0,0", "  set the loc of window " & q & "Map" & q & " to 10,10", "end mouseUp") into tScript
   TestAssert "T26: the scale of a window", line 2 of tScript is "  hcSetWindow " & q & "scale" & q & ", pictureWindow, -1"
   TestAssert "T26: the scroll of a window", line 3 of tScript is "  hcSetWindow " & q & "scroll" & q & ", " & q & "Map" & q & ", " & q & "10,10" & q
   TestAssert "T26: the hilitedButton of a palette", line 4 of tScript is "  hcSetWindow " & q & "hilitedbutton" & q & ", " & q & "Tools" & q & ", 0"
   TestAssert "T26: the scroll of the card window", line 5 of tScript is "  hcSetWindow " & q & "scroll" & q & ", " & q & "card window" & q & ", 0,0"
   TestAssert "T26: the loc of a window: not T26's (T46's, the library's)", line 6 of tScript is "  hcSetWindow " & q & "loc" & q & ", " & q & "Map" & q & ", 10,10"

   put _RewriteHyperTalk("on mouseUp", "  doMenu new card", "  if x then doMenu Compact Stack", "  doMenu tItem", "  doMenu the short name of me", "end mouseUp") into tScript
   TestAssert "T27: doMenu with the item not in quotes", line 2 of tScript is "  doMenu " & q & "new card" & q
   TestAssert "T27: after then, its spelling kept", line 3 of tScript is "  if x then doMenu " & q & "Compact Stack" & q
   TestAssert "T27: a variable: unchanged", line 4 of tScript is "  doMenu tItem"
   TestAssert "T27: an expression: unchanged", line 5 of tScript is "  doMenu the short name of me"

   -- without HyperCard's message order, the same doMenus go to the
   -- library's hcDoMenu (T15)
   put _Rewrite("on mouseUp", "  doMenu new card", "  if x then doMenu Compact Stack", "  doMenu tItem", "  doMenu the short name of me", "end mouseUp") into tScript
   TestAssert "T15 and T27: doMenu with the item not in quotes", line 2 of tScript is "  hcDoMenu " & q & "new card" & q
   TestAssert "T15 and T27: after then", line 3 of tScript is "  if x then hcDoMenu " & q & "Compact Stack" & q
   TestAssert "T15: a variable", line 4 of tScript is "  hcDoMenu tItem"
   TestAssert "T15: an expression", line 5 of tScript is "  hcDoMenu the short name of me"

   -- T36: the menu's name and "without dialog"
   put _Rewrite("on mouseUp", "  doMenu " & q & "Paste Button" & q & ", " & q & "Edit" & q, "  doMenu " & q & "Delete Stack..." & q & " without dialog", \
         "  if x then doMenu " & q & "Copy Card" & q & ", " & q & "Edit" & q & " without dialog", "  doMenu Paste Card, Edit", "  doMenu item 1 of x, (item 2 of x)", "end mouseUp") into tScript
   TestAssert "T36: the menu's name", line 2 of tScript is "  hcDoMenu " & q & "Paste Button" & q & ", " & q & "Edit" & q
   TestAssert "T36: without dialog", line 3 of tScript is "  hcDoMenu " & q & "Delete Stack..." & q & ", empty, " & q & "without dialog" & q
   TestAssert "T36: both, after then", line 4 of tScript is "  if x then hcDoMenu " & q & "Copy Card" & q & ", " & q & "Edit" & q & ", " & q & "without dialog" & q
   TestAssert "T36: names not in quotes (one word is its own value)", line 5 of tScript is "  hcDoMenu " & q & "Paste Card" & q & ", Edit"
   TestAssert "T36: expressions", line 6 of tScript is "  hcDoMenu item 1 of x, (item 2 of x)"
   TestAssert "T36: the script compiles", _Compiles(tScript)
   put _RewriteHyperTalk("on mouseUp", "  doMenu " & q & "Paste Button" & q & ", " & q & "Edit" & q & " without dialog", "end mouseUp") into tScript
   TestAssert "T36: with HyperCard's message order, the doMenu message with them", line 2 of tScript is "  dispatch " & q & "doMenu" & q & " with " & q & "Paste Button" & q & ", " & q & "Edit" & q & ", " & q & "without dialog" & q

   put _Rewrite("on mouseUp", "  put the visible of msg into v", "  if the visible of window " & q & "Message" & q & " then hide msg", "  set the loc of the message box to 18,30", "  set loc of msg to x", "  put the length of msg into n", "  put the rect of window " & q & "Map" & q & " into r", "end mouseUp") into tScript
   TestAssert "T28: the visible of msg", line 2 of tScript is "  put hcMessageBox(" & q & "visible" & q & ") into v"
   TestAssert "T28: the visible of window " & q & "Message" & q, line 3 of tScript is "  if hcMessageBox(" & q & "visible" & q & ") then hide msg"
   TestAssert "T28: set the loc of the message box", line 4 of tScript is "  hcSetMessageBox " & q & "loc" & q & ", 18,30"
   TestAssert "T28: set loc of msg", line 5 of tScript is "  hcSetMessageBox " & q & "loc" & q & ", x"
   TestAssert "T28: the length of msg: unchanged", line 6 of tScript is "  put the length of msg into n"
   TestAssert "T28: another window: not the message box (T46 places it)", line 7 of tScript is "  put hcWindowProperty(" & q & "rect" & q & ", " & q & "Map" & q & ") into r"

   put _Rewrite("on mouseUp", "  put " & q & "Again" & q & " after menuItem " & q & "Find" & q & " of menu " & q & "Go" & q & " \", "    with menuMessages " & q & "StartSearch" & q, "  beep", "end mouseUp") into tScript
   TestAssert "T22: a statement continued over lines, taken whole", line 2 of tScript is "  hcPutIntoMenu " & q & "Again" & q & ", " & q & "after" & q & ", " & q & "Go" & q & ", " & q & "StartSearch" & q & ", " & q & "Find" & q
   TestAssert "T22: its second line left empty, the lines after it kept", line 3 of tScript is empty and line 4 of tScript is "  beep"

   put _Rewrite("on mouseUp", "  put lastItem(the long name of HyperCard) into h", "  if the version of HyperCard < 2 then beep", "  send " & q & "doMenu Copy Text" & q & " to HyperCard", "  put the name of HyperCard into n", "  send " & q & "mouseUp" & q & " to me", "end mouseUp") into tScript
   TestAssert "T29: the long name of HyperCard", line 2 of tScript is "  put lastItem(hcHyperCardName(" & q & "long" & q & ")) into h"
   TestAssert "T29: the version of HyperCard", line 3 of tScript is "  if hcVersion() < 2 then beep"
   TestAssert "T29: send to HyperCard", line 4 of tScript is "  hcSendToHyperCard " & q & "doMenu Copy Text" & q
   TestAssert "T29: the name of HyperCard", line 5 of tScript is "  put hcHyperCardName(" & q & q & ") into n"
   TestAssert "T29: send to an object: unchanged", line 6 of tScript is "  send " & q & "mouseUp" & q & " to me"

   put _Rewrite("on mouseUp", "  choose tool x", "  choose browse tool", "  choose " & q & "Select Tool" & q, "end mouseUp") into tScript
   TestAssert "T30: choose tool x", line 2 of tScript is "  hcChooseTool x"
   TestAssert "T30: choose browse tool: unchanged", line 3 of tScript is "  choose browse tool"
   TestAssert "T30: choose a tool by a name in an expression", line 4 of tScript is "  hcChooseTool " & q & "Select Tool" & q

   put _Rewrite("on mouseUp", "  set the rect of this card to 0,0,512,342", "  set the textStyle of fld 1 to " & q & "bold,condense" & q, "  set the textStyle of fld 1 to bold", "end mouseUp") into tScript
   TestAssert "T32: the rect of this card", line 2 of tScript is "  hcSetCardRect 0,0,512,342"
   TestAssert "T32: a text style of HyperCard's", line 3 of tScript is "  set the textStyle of fld 1 to hcTextStyle(" & q & "bold,condense" & q & ")"
   TestAssert "T32: a text style of this engine's: unchanged", line 4 of tScript is "  set the textStyle of fld 1 to bold"

   -- group after a comma, which would not compile, is quoted (T12), where
   -- it was left out of the style, and T32 then takes the style
   put _Rewrite("on mouseUp", "  set textStyle of it to bold,group", "  set the textStyle of the foundChunk to bold, condense, group", "end mouseUp") into tScript
   TestAssert "T12: group after a comma in a text style is kept, quoted", line 2 of tScript is "  set textStyle of it to hcTextStyle(bold," & q & "group" & q & ")"
   TestAssert "T12: and with HyperCard's other styles", line 3 of tScript is "  set the textStyle of the foundChunk to hcTextStyle(bold, condense, " & q & "group" & q & ")"
   TestAssert "T12: the handler compiles", _Compiles(tScript)

   -- T32: the style after the "to" that is not a range's, where a range
   -- of chunks has one too (Cool Address Book's, the Dock stacks')
   put _Rewrite("on mouseUp", "  set the textStyle of word 1 to 2 of me to " & q & "Bold,Condense" & q, \
         "  set the textstyle of word sw+1 to slw of fld " & q & "situation" & q & " to " & q & "group" & q, \
         "  set the textStyle of char (item 1 of x) to (item 2 of x) of line 1 of fld 1 to " & q & "Group" & q, \
         "  set the textStyle of word 2 of fld 1 to item 1 to 2 of " & q & "shadow,outline,bold" & q, \
         "  set the textStyle of word 1 to 2 of line 2 to 3 of fld 1 to " & q & "extend" & q, \
         "end mouseUp") into tScript
   TestAssert "T32: a range of words", line 2 of tScript is "  set the textStyle of word 1 to 2 of me to hcTextStyle(" & q & "Bold,Condense" & q & ")"
   TestAssert "T32: a range by expressions", line 3 of tScript \
         is "  set the textstyle of word sw+1 to slw of fld " & q & "situation" & q & " to hcTextStyle(" & q & "group" & q & ")"
   TestAssert "T32: a range in parentheses", line 4 of tScript \
         is "  set the textStyle of char (item 1 of x) to (item 2 of x) of line 1 of fld 1 to hcTextStyle(" & q & "Group" & q & ")"
   TestAssert "T32: a range in the style", line 5 of tScript \
         is "  set the textStyle of word 2 of fld 1 to hcTextStyle(item 1 to 2 of " & q & "shadow,outline,bold" & q & ")"
   TestAssert "T32: two ranges", line 6 of tScript \
         is "  set the textStyle of word 1 to 2 of line 2 to 3 of fld 1 to hcTextStyle(" & q & "extend" & q & ")"
   TestAssert "T32: those compile", _Compiles(tScript)

   -- ... in a script that compiles, which stopped there ("condense" is
   -- no style here), where the rule took the range's "to" for the value's,
   -- did not compile, and was left out
   put "HCScriptsT32" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create field "f"
   put "alpha beta gamma" into field "f"
   create button "Style"
   set the script of button "Style" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  set the textStyle of word 1 to 2 of field " & q & "f" & q & " to " & q & "Bold,Condense" & q, \
         "  put the textStyle of word 2 of field " & q & "f" & q & " & comma & the textStyle of word 3 of field " & q & "f" & q & " into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Style" of stack tStack
   catch tError
   end try
   TestAssert "T32: as it is, a range of words set to HyperCard's styles stops", gHCScriptsTest is empty
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Style" of stack tStack
   catch tError
   end try
   -- (a word with no style of its own has an empty textStyle in a stack
   -- whose hyperTalkCompatible is false, as this one's)
   TestAssert "T32: the range of words set, the word after it not", gHCScriptsTest is "bold,condensed,"
   _Close tStack
end TestHyperCardScriptsRulesForAll

on TestHyperCardScriptsMoreForms
   -- T33: more forms HyperCard took, from the sweep of 2026-10-23
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp x", "  answer " & q & "Clear?" & q & " with Yes or No", "  answer " & q & "Q?" & q & " with x or No or " & q & "Maybe" & q, "  answer " & q & "Q?" & q & " with empty or OK", "  convert fileModDate(f, true) to short date", "  convert x to seconds", "  convert line 1 of fld 2 to seconds", "  if x then convert x + 1 to seconds", "end mouseUp") into tScript
   TestAssert "T33: an answer's replies not in quotes", line 2 of tScript is "  answer " & q & "Clear?" & q & " with " & q & "Yes" & q & " or " & q & "No" & q
   TestAssert "T33: a variable as a reply: unchanged", line 3 of tScript is "  answer " & q & "Q?" & q & " with x or " & q & "No" & q & " or " & q & "Maybe" & q
   TestAssert "T33: a constant as a reply: unchanged", line 4 of tScript is "  answer " & q & "Q?" & q & " with empty or " & q & "OK" & q
   TestAssert "T33: convert an expression", line 5 of tScript is "  get fileModDate(f, true); convert it to short date"
   TestAssert "T33: convert a variable: unchanged", line 6 of tScript is "  convert x to seconds"
   TestAssert "T33: convert a chunk: unchanged", line 7 of tScript is "  convert line 1 of fld 2 to seconds"
   TestAssert "T33: convert after then: unchanged", line 8 of tScript is "  if x then convert x + 1 to seconds"

   put _Rewrite("on mouseUp mouse", "  put mouseLoc into p", "  if optionKey is down then beep", "  if mouse is 1 then beep", "  set the cursor to Mouse Cursor", "  if version of HyperCard < 2 then beep", "  go to card 1 of home", "  go first card of stack Home", "  go to card 2 of home", "  go Electronic Parts", "  doMenu New Stack...", "end mouseUp") into tScript
   TestAssert "T33: a function without the", line 2 of tScript is "  put the mouseLoc into p"
   TestAssert "T33: a function without the, before is", line 3 of tScript is "  if the optionKey is down then beep"
   TestAssert "T33: a variable of that name: unchanged", line 4 of tScript is "  if mouse is 1 then beep"
   TestAssert "T33: a cursor's name of two words", line 5 of tScript is "  set the cursor to hcCursor(" & q & "Mouse Cursor" & q & ")"
   TestAssert "T33: version of HyperCard without the", line 6 of tScript is "  if hcVersion() < 2 then beep"
   TestAssert "T33: card 1 of home", line 7 of tScript is "  hcGoHome"
   TestAssert "T33: first card of stack Home", line 8 of tScript is "  hcGoHome"
   TestAssert "T33: another card of home: not the Home card", line 9 of tScript is not "  hcGoHome"
   TestAssert "T33: go to a stack's name of two words", line 10 of tScript is "  hcGoTo " & q & "Electronic Parts" & q
   TestAssert "T33: doMenu with dots in the item's name", line 11 of tScript is "  hcDoMenu " & q & "New Stack..." & q

   -- the corpus sweep: a modifier key after "with" stays bare, and the
   -- long version of HyperCard is still T10's
   put _Rewrite("on mouseUp", "  type " & q & "C" & q & " with commandKey", "  drag from 1,1 to 9,9 with optionKey, shiftKey", "  get the long version of HyperCard", "end mouseUp") into tScript
   TestAssert "T33: a modifier key after with: unchanged", line 2 of tScript is "  type " & q & "C" & q & " with commandKey"
   TestAssert "T33: modifier keys after with: unchanged", line 3 of tScript is "  drag from 1,1 to 9,9 with optionKey, shiftKey"
   TestAssert "T33: the long version of HyperCard: still T10's", line 4 of tScript is "  get hcLongVersion()"

   -- go home in new window, which HyperCard took for "in a new window"
   -- (My First Book of HyperCard 2's), no different for the Home stack
   put _Rewrite("on mouseUp", "  go home in new window", "  if x then go to stack home in a new window", "end mouseUp") into tScript
   TestAssert "T9: go home in new window", line 2 of tScript is "  hcGoHome"
   TestAssert "T9: go home in a new window, after then", line 3 of tScript is "  if x then hcGoHome"
end TestHyperCardScriptsMoreForms

on TestHyperCardScriptsT35
   -- T35: more forms HyperCard took, from the corpus sweep
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", "  put true in x", "  if x = on then beep", "  put off into y", \
         "  doMenu Next", "  play harpsichord c d e f fast", "  play flute tempo 200 c4 d", \
         "  if x then send " & q & "go" & q & " to card", "  if y is not off then beep", "end mouseUp") into tScript
   TestAssert "T35: put x in y", line 2 of tScript is "  put true into x"
   TestAssert "T35: on as a value", line 3 of tScript is "  if x = " & q & "on" & q & " then beep"
   TestAssert "T35: put off into", line 4 of tScript is "  put " & q & "off" & q & " into y"
   TestAssert "T35: doMenu one word", line 5 of tScript is "  hcDoMenu " & q & "Next" & q
   TestAssert "T35: play's notes not in quotes", line 6 of tScript is "  play harpsichord " & q & "c d e f fast" & q
   TestAssert "T35: play's notes after tempo", line 7 of tScript is "  play flute tempo 200 " & q & "c4 d" & q
   TestAssert "T35: send to card after then", line 8 of tScript is "  if x then send " & q & "go" & q & " to this card"
   TestAssert "T35: is not off", line 9 of tScript is "  if y is not " & q & "off" & q & " then beep"
   TestAssert "T35: the script compiles", _Compiles(tScript)

   -- a message called alone as a command (Gems of Hubble's resumeStack
   -- calls openCard), and quit as a menu item
   put _Rewrite("on resumeStack", "  openCard", "  if x then closeCard", "  pass resumeStack", "end resumeStack", "on mouseUp", "  doMenu " & q & "Quit HyperCard" & q, "end mouseUp") into tScript
   TestAssert "T35: openCard sent", line 2 of tScript is "  send " & q & "openCard" & q & " to me"
   TestAssert "T35: closeCard after then sent", line 3 of tScript is "  if x then send " & q & "closeCard" & q & " to me"
   TestAssert "T35: pass left alone", line 4 of tScript is "  pass resumeStack"
   TestAssert "T27: Quit HyperCard to the library", line 7 of tScript is "  hcDoMenu " & q & "Quit HyperCard" & q

   -- idle and the other messages alone, and HyperCard 2's debug command
   put _Rewrite("on mouseUp", "  idle", "  closeField", "  debug checkpoint", "  debug sound off", "end mouseUp") into tScript
   TestAssert "T35: idle sent", line 2 of tScript is "  send " & q & "idle" & q & " to me"
   TestAssert "T35: closeField sent", line 3 of tScript is "  send " & q & "closeField" & q & " to me"
   TestAssert "T35: debug checkpoint", line 4 of tScript is "  breakpoint"
   TestAssert "T35: debug's other options", line 5 of tScript is "  hcDebug " & q & "sound off" & q
   TestAssert "T35: the debug lines compile", _Compiles(tScript)

   -- unchanged: a count put into the message box, a variable after
   -- play's voice, a variable named on, doMenu with a variable, quoted
   -- notes
   put _Rewrite("on mouseUp", "  put the number of words in fld 1", "  play flute tNotes", \
         "  put 1 into tItem; put 2 into tNotes", "  doMenu tItem", "  play " & q & "boing" & q & " " & q & "c d" & q, \
         "  put x in y into z", "end mouseUp") into tScript
   TestAssert "T35: a count into the message box: unchanged", line 2 of tScript is "  put the number of words in fld 1"
   TestAssert "T35: play with a variable: unchanged", line 3 of tScript is "  play flute tNotes"
   TestAssert "T35: doMenu with a variable: only T15", line 5 of tScript is "  hcDoMenu tItem"
   TestAssert "T35: quoted notes: unchanged", line 6 of tScript is "  play " & q & "boing" & q & " " & q & "c d" & q
   TestAssert "T35: in before into: unchanged", line 7 of tScript is "  put x in y into z"

   -- unchanged: a chunk of a container as play's notes, as eight corpus
   -- stacks have it (the sweep found the rule had quoted them)
   put _Rewrite("on mouseUp", "  play line x of card field 1", "  play harpsichord item 2 of tNotes", \
         "  play flute the notes of me", "  play harpsichord line \", "  index of card field 1", "end mouseUp") into tScript
   TestAssert "T35: play a line of a field: unchanged", line 2 of tScript is "  play line x of card field 1"
   TestAssert "T35: play a voice and an item: unchanged", line 3 of tScript is "  play harpsichord item 2 of tNotes"
   TestAssert "T35: play a voice and the: unchanged", line 4 of tScript is "  play flute the notes of me"
   TestAssert "T35: play's notes on the next line: unchanged", line 5 of tScript is "  play harpsichord line \"

   -- the sound in quotes after then, or in parentheses (Home
   -- Improvements', Resource Library's), and a sound named by a word this
   -- engine's play takes for its own (Garbage's "play step", a video's
   -- step with no clip here); unchanged: play stop, HyperCard's own, a
   -- variable's notes, it too (Tiny Tim's, Canary's), and one note after
   -- a sound in quotes, which this engine reads as the text it is
   put _Rewrite("on mouseUp", "  if qq > 1 then play " & q & "Harpsichord" & q & " g3q d4 e ch", \
         "  play (field " & q & "Name" & q & ") tempo 220 cq e f gw", "  play step", "  play step tempo 200 c d", \
         "  if x then play stop", "  put " & q & "c d" & q & " into tNotes", "  if x then play " & q & "boing" & q & " tNotes", \
         "  play " & q & "Harpsichord" & q & " tempo 150 it", "  play harpsichord it", \
         "  if whatCharacter is space then play " & q & "Silence" & q & " r", "  play " & q & "boing" & q & "c d e", "end mouseUp") into tScript
   TestAssert "T35: play's notes after a sound in quotes, after then", line 2 of tScript \
         is "  if qq > 1 then play " & q & "Harpsichord" & q && q & "g3q d4 e ch" & q
   TestAssert "T35: play's notes after a sound in parentheses", line 3 of tScript \
         is "  play (field " & q & "Name" & q & ") tempo 220 " & q & "cq e f gw" & q
   TestAssert "T35: a sound named step", line 4 of tScript is "  play " & q & "step" & q
   TestAssert "T35: a sound named step, its tempo and notes", line 5 of tScript is "  play " & q & "step" & q & " tempo 200 " & q & "c d" & q
   TestAssert "T35: play stop: unchanged", line 6 of tScript is "  if x then play stop"
   TestAssert "T35: a variable after a sound in quotes: unchanged", line 8 of tScript is "  if x then play " & q & "boing" & q & " tNotes"
   TestAssert "T35: it after a sound in quotes: unchanged", line 9 of tScript is "  play " & q & "Harpsichord" & q & " tempo 150 it"
   TestAssert "T35: it after a voice: unchanged", line 10 of tScript is "  play harpsichord it"
   TestAssert "T35: one note after a sound in quotes: unchanged", line 11 of tScript is "  if whatCharacter is space then play " & q & "Silence" & q & " r"
   TestAssert "T35: notes against a sound in quotes, a space between", line 12 of tScript is "  play " & q & "boing" & q && q & "c d e" & q
   TestAssert "T35: the play lines compile", _Compiles(tScript)
end TestHyperCardScriptsT35

on TestHyperCardScriptsT34
   -- T34: the next forms by reach in the corpus sweep
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", "  select " & q & q, "  repeat with i is 1 to 3", "  end repeat", \
         "  sort the lines of x", "  put the number of windows into n", \
         "  put char 3 to the length of fld " & q & "body" & q & " of fld " & q & "body" & q & " into y", \
         "  put 1 into line bg fld " & q & "N" & q & " of bg fld " & q & "List" & q, \
         "  if q then reset menubar", "  unlock screen with visual dissolve to cd", \
         "  answer " & q & "Sure?" & q & " \", "  with No, Yes", "end mouseUp") into tScript
   TestAssert "T34: select an empty string", line 2 of tScript is "  select empty"
   TestAssert "T34: repeat with i is", line 3 of tScript is "  repeat with i = 1 to 3"
   TestAssert "T34: sort the lines of", line 5 of tScript is "  sort lines of x"
   TestAssert "T34: the number of windows", line 6 of tScript is "  put the number of lines of the windows into n"
   TestAssert "T34: to the length of the same field", line 7 of tScript is "  put char 3 to (the length of fld " & q & "body" & q & ") of fld " & q & "body" & q & " into y"
   TestAssert "T34: a field as a line's number", line 8 of tScript is "  put 1 into line (bg fld " & q & "N" & q & ") of bg fld " & q & "List" & q
   TestAssert "T34: reset menubar after then", line 9 of tScript is "  if q then hcResetMenubar"
   TestAssert "T34: unlock screen with visual to cd", line 10 of tScript is "  unlock screen with visual dissolve to card"
   TestAssert "T34: an answer's replies on the next line", line 11 of tScript contains "with " & q & "No" & q & " or " & q & "Yes" & q
   TestAssert "T34: the line it continued on, left empty", line 12 of tScript is empty
   TestAssert "T34: the script compiles", _Compiles(tScript)

   -- the number's field on a card the line names, when the chunk's own
   -- "of" follows (Helter Skelter's)
   put _Rewrite("on mouseUp", \
         "  put x after line cd fld " & q & "N" & q & " of cd " & q & "Main Menu" & q & " of cd fld " & q & "List" & q, \
         "  get line cd fld " & q & "N" & q & " of card id 2881 of cd fld " & q & "List" & q & " of card id 2881", \
         "  put x into line cd fld " & q & "N" & q & " of cd fld " & q & "List" & q & " of cd " & q & "Dial" & q, \
         "end mouseUp") into tScript
   TestAssert "T34: a field on a card as a line's number", line 2 of tScript \
         is "  put x after line (cd fld " & q & "N" & q & " of cd " & q & "Main Menu" & q & ") of cd fld " & q & "List" & q
   TestAssert "T34: on a card by id", line 3 of tScript \
         is "  get line (cd fld " & q & "N" & q & " of card id 2881) of cd fld " & q & "List" & q & " of card id 2881"
   TestAssert "T34: the card of the list: not the number's", line 4 of tScript \
         is "  put x into line (cd fld " & q & "N" & q & ") of cd fld " & q & "List" & q & " of cd " & q & "Dial" & q
   TestAssert "T34: the script with them compiles", _Compiles(tScript)

   -- unchanged: a line's number that is not an object, the number of a
   -- chunk, a variable named like a function in the external's place
   put _Rewrite("on mouseUp", "  put 1 into line 2 of fld 3", "  put the number of lines of the windows into n", "end mouseUp") into tScript
   TestAssert "T34: a line's number: unchanged", line 2 of tScript is "  put 1 into line 2 of fld 3"
   TestAssert "T34: already the number of lines: unchanged", line 3 of tScript is "  put the number of lines of the windows into n"

   -- a variable named date: the long date stays the function
   put _Rewrite("on mouseUp", "  put 1 into date", "  put the long date into d", "  put the number of items in date into n", "end mouseUp") into tScript
   TestAssert "T34: the variable renamed", line 2 of tScript is "  put 1 into hc_date"
   TestAssert "T34: the long date: the function", line 3 of tScript is "  put the long date into d"

   -- the arguments of an external: on and off in quotes
   put revHyperCardRewriteScript(_Lines("on mouseUp", "  ink on, 8, x", "  if x then ink off", "  put Zap(on) into y", "  put Other(on) into z", "end mouseUp"), _Lines("ink", "zap")) into tScript
   TestAssert "T34: an external command's on", line 2 of tScript contains q & "on" & q & ", 8, x"
   TestAssert "T34: an external command's off after then", line 3 of tScript contains q & "off" & q
   TestAssert "T34: an external function's on", line 4 of tScript is "  put Zap(" & q & "on" & q & ") into y"
   TestAssert "T34: not an external: unchanged", line 5 of tScript is "  put Other(on) into z"
end TestHyperCardScriptsT34

on TestHyperCardScriptsT37
   -- T37: the next forms by reach in the sweep of 2026-10-25
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", "  ResetBtns on", "  if x then ResetBtns(OFF)", "  ShowHistory " & q & "The Outcome" & q & ", 5,", \
         "  go cd", "  go to card", "  put the number of marked card i into tn", \
         "  if there is not a window " & q & "Nav" & q & " then palette " & q & "Nav" & q & "," & q & "254,0" & q, \
         "end mouseUp", "on ResetBtns pState", "end ResetBtns", "on ShowHistory pTitle, pCount, pMore", "end ShowHistory") into tScript
   TestAssert "T37: on as a handler of the stack's argument", line 2 of tScript is "  ResetBtns " & q & "on" & q
   TestAssert "T37: in parentheses, after then", line 3 of tScript is "  if x then ResetBtns(" & q & "OFF" & q & ")"
   TestAssert "T37: a comma that ends the arguments", line 4 of tScript is "  ShowHistory " & q & "The Outcome" & q & ", 5, empty"
   TestAssert "T37: go cd", line 5 of tScript is "  go this cd"
   TestAssert "T37: go to card", line 6 of tScript is "  go to this card"
   TestAssert "T37: the number of marked card i", line 7 of tScript is "  put the number of card id (the short id of marked card i) into tn"
   TestAssert "T37: palette after then", line 8 of tScript is "  if there is not a window " & q & "Nav" & q & " then hcPalette " & q & "Nav" & q & "," & q & "254,0" & q
   TestAssert "T37: the script compiles", _Compiles(tScript)

   -- unchanged: a card named, the number of marked cards, a handler
   -- that is not the stack's (no probe), a variable, a comma in quotes
   put _Rewrite("on mouseUp", "  go cd 2", "  put the number of marked cards into n", "  Other on", \
         "  ResetBtns tOn, " & q & "a," & q, "  put 1 into tOn", "end mouseUp", "on ResetBtns pState", "end ResetBtns") into tScript
   TestAssert "T37: go to a card: unchanged", line 2 of tScript is "  go cd 2"
   TestAssert "T37: the number of marked cards: unchanged", line 3 of tScript is "  put the number of marked cards into n"
   TestAssert "T37: no probe, so not known to be a command: unchanged", line 4 of tScript is "  Other on"
   TestAssert "T37: a variable, and a comma in quotes: unchanged", line 5 of tScript is "  ResetBtns tOn, " & q & "a," & q

   -- variables named like a word answer, ask and put take first; mark
   -- card; a card in this background; counts without "the"
   put _Rewrite("on mouseUp", "  answer info", "  ask question with " & q & "x" & q, "  put Header into field 1", \
         "  mark card", "  unmark cd", "  go cd " & q & "Index" & q & " in this bg", "  if there is a cd id it in this bg then beep", \
         "  set the name of card field number of card fields to " & q & "x" & q, "  put it into field number of fields", \
         "  put item number of me of x into y", "  get char 1 to 7 of line number of lines of t - 1 of t", \
         "  put line number of lines of script of target of script of target into z", "end mouseUp") into tScript
   TestAssert "T37: answer info", line 2 of tScript is "  answer (info)"
   TestAssert "T37: ask question with", line 3 of tScript is "  ask (question) with " & q & "x" & q
   TestAssert "T37: put header into", line 4 of tScript is "  put (Header) into field 1"
   TestAssert "T37: mark card", line 5 of tScript is "  mark this card"
   TestAssert "T37: unmark cd", line 6 of tScript is "  unmark this cd"
   TestAssert "T37: go to a card in this bg", line 7 of tScript is "  go cd " & q & "Index" & q & " of this bg"
   TestAssert "T37: there is a card in this bg", line 8 of tScript is "  if there is a cd id it of this bg then beep"
   TestAssert "T37: a field numbered by the count of fields", line 9 of tScript is "  set the name of card field (the number of card fields) to " & q & "x" & q
   TestAssert "T37: the same without card", line 10 of tScript is "  put it into field (the number of fields)"
   TestAssert "T37: an item numbered by the number of me", line 11 of tScript is "  put item (the number of me) of x into y"
   TestAssert "T37: a line numbered by a count of lines, its container again after it", line 12 of tScript is "  get char 1 to 7 of line (the number of lines of t - 1) of t"
   TestAssert "T37: the same, a container of several words", line 13 of tScript is "  put line (the number of lines of script of target) of script of target into z"
   TestAssert "T37: those compile", _Compiles(tScript)

   -- as before: "number of" something other than a count's objects is
   -- a card's name (T3); answer with more after the word
   put _Rewrite("on mouseUp", "  go card number of this stack", "  answer error & x", "end mouseUp") into tScript
   TestAssert "T37: number of this stack: a card's name, as before", line 2 of tScript is "  go card " & q & "number" & q & " of this stack"
   TestAssert "T37: answer error and more: unchanged", line 3 of tScript is "  answer error & x"

   -- find string, the word of a form alone that is a variable (Windoid's
   -- "on searchStackFor string"): the text to find
   put _Rewrite("on searchStackFor string", "  find string", "  if x then find string", "end searchStackFor", \
         "on mouseUp", "  find words", "end mouseUp") into tScript
   TestAssert "T37: find a variable named like a form of find", line 2 to 3 of tScript is _Lines("  find (string)", "  if x then find (string)")
   TestAssert "T37: find a form that is no variable: unchanged", line 6 of tScript is "  find words"
end TestHyperCardScriptsT37

on TestHyperCardScriptsT37Probed
   -- T37 with revHyperCardFixScripts' probes: a word that is no value
   -- here, which HyperCard took as its own text, as an argument or a
   -- value alone; and an else at the end of a line that began a block
   local tStack, tScript, q
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT37" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", "  timeStamp scrollBar", \
         "  gocd next, 1", "  if it = No then put 1 into x", "  if (iName = First) or (iName = Last) then beep", \
         "  if movie is not in the result then beep", "  put stacks into whichField", "  put in into meas", \
         "  if there is a field " & q & "x" & q & " then beep", "  if x is a number then beep", \
         "  put comma & meas & comma & whichField after gHCScriptsTest", "end mouseUp", \
         "on timeStamp pWhat", "  global gHCScriptsTest", "  put pWhat after gHCScriptsTest", "end timeStamp", \
         "on gocd pWhere, pBy", "  global gHCScriptsTest", "  put comma & pWhere & pBy after gHCScriptsTest", "end gocd", \
         "on dragIt p, q", "  drag from p to q \", "  with optionKey", "end dragIt", \
         "on notNo p", "  if p <> No then put 1 into p", "end notNo", \
         "on showChart", "  picture " & q & "Chart" & q & ", clipboard, zoom", "end showChart")
   create button "Else"
   set the script of button "Else" to _Lines("on mouseUp pChoice", "  global gHCScriptsTest", \
         "  if pChoice = 1 then put " & q & "one" & q & " into gHCScriptsTest else", \
         "  if pChoice = 2 then put " & q & "two" & q & " into gHCScriptsTest else", \
         "  put " & q & "other" & q & " into gHCScriptsTest", "  put " & q & "!" & q & " after gHCScriptsTest", \
         "  end if", "  end if", "end mouseUp", "on mouseDown", "  put 1 +* into", "end mouseDown")
   create button "Else2"
   set the script of button "Else2" to _Lines("on mouseUp pChoice", "  global gHCScriptsTest", \
         "  if pChoice = 1 or \", "  pChoice = 4 then put " & q & "one" & q & " into gHCScriptsTest else", \
         "  if pChoice = 2 then put " & q & "two" & q & " into gHCScriptsTest", "  else", \
         "    put " & q & "other" & q & " into gHCScriptsTest", "    put " & q & "!" & q & " after gHCScriptsTest", \
         "  end if", "  end if", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the script of button "B" of stack tStack into tScript
   TestAssert "T37: a handler's argument that is no value here", line 3 of tScript is "  timeStamp " & q & "scrollBar" & q
   TestAssert "T37: next as an argument", line 4 of tScript is "  gocd " & q & "next" & q & ", 1"
   TestAssert "T37: a side of a comparison", line 5 of tScript is "  if it = " & q & "No" & q & " then put 1 into x"
   TestAssert "T37: both sides in parentheses", line 6 of tScript is "  if (iName = " & q & "First" & q & ") or (iName = " & q & "Last" & q & ") then beep"
   TestAssert "T37: the left side", line 7 of tScript is "  if " & q & "movie" & q & " is not in the result then beep"
   TestAssert "T37: what put puts", line 8 of tScript is "  put " & q & "stacks" & q & " into whichField"
   TestAssert "T37: what put puts, a word of the grammar", line 9 of tScript is "  put " & q & "in" & q & " into meas"
   TestAssert "T37: there is: unchanged", line 10 of tScript is "  if there is a field " & q & "x" & q & " then beep"
   TestAssert "T37: is a number: unchanged", line 11 of tScript is "  if x is a number then beep"
   TestAssert "T37: a line that goes on with the statement before starts no command: unchanged", \
         line 24 of tScript is "  with optionKey"
   TestAssert "T37: a side of <>", line 27 of tScript is "  if p <> " & q & "No" & q & " then put 1 into p"
   TestAssert "T37: picture's words that are no value here", line 30 of tScript begins with "  hcPicture " & q & "Chart" & q & ", " & q & "clipboard" & q & ", "
   TestAssert "T37: the script compiles", _Compiles(tScript)
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "T37: the words as their own text", gHCScriptsTest is "scrollBar,next1,in,stacks"

   put the script of button "Else" of stack tStack into tScript
   TestAssert "T37: an else at the end of a line, the else of a block", line 3 of tScript is "  if pChoice = 1 then; put " & q & "one" & q & " into gHCScriptsTest ; else"
   TestAssert "T37: the handler that cannot be saved, its line left out (T39)", \
         "  -- HyperCard import: left out, it does not compile here: put 1 +* into" is among the lines of tScript
   put empty into gHCScriptsTest
   send "mouseUp 1" to button "Else" of stack tStack
   TestAssert "T37: the then", gHCScriptsTest is "one"
   send "mouseUp 2" to button "Else" of stack tStack
   TestAssert "T37: the else's then", gHCScriptsTest is "two"
   send "mouseUp 3" to button "Else" of stack tStack
   TestAssert "T37: the block of the else's else, every line of it", gHCScriptsTest is "other!"

   put the script of button "Else2" of stack tStack into tScript
   TestAssert "T37: an else at the end of a statement over two lines", line 4 of tScript is "  pChoice = 4 then; put " & q & "one" & q & " into gHCScriptsTest ; else"
   TestAssert "T37: else alone on the line after if...then", line 5 of tScript is "  if pChoice = 2 then; put " & q & "two" & q & " into gHCScriptsTest"
   put empty into gHCScriptsTest
   send "mouseUp 4" to button "Else2" of stack tStack
   TestAssert "T37: over two lines, the then", gHCScriptsTest is "one"
   put empty into gHCScriptsTest
   send "mouseUp 2" to button "Else2" of stack tStack
   TestAssert "T37: else alone, the then", gHCScriptsTest is "two"
   put empty into gHCScriptsTest
   send "mouseUp 3" to button "Else2" of stack tStack
   TestAssert "T37: else alone, every line of its block", gHCScriptsTest is "other!"
   _Close tStack
end TestHyperCardScriptsT37Probed

on TestHyperCardScriptsT37Compiled
   -- T37 in a script that compiles too: a word alone as an argument that
   -- this engine takes for an object it cannot find ("can't find card"),
   -- and stops, where HyperCard passed its text: an external's (Color
   -- Tools' "AddColor enableObject,cd,2"), one of the stack's handlers'
   -- (Instance Variables' "putVar cd, myID, ..."), a command this engine
   -- does not have (StackTools' "toggleProperty cantDelete,card,...")
   local tStack, tScript, tOriginal, q, tTab
   global gHCScriptsTest
   put quote into q
   put tab into tTab
   put "HCScriptsT37Compiled" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["externals"] of stack tStack to "XCMD" & tTab & "AddColor"
   set the script of stack tStack to _Lines("on putVar pWhere, pName, pValue", "  global gHCScriptsTest", \
         "  put pWhere & colon & pName & " & q & "=" & q & " & pValue & comma after gHCScriptsTest", "end putVar", \
         "function getVar pWhere, pName", "  return pWhere & colon & pName & comma", "end getVar")
   create button "B"
   put _Lines("on mouseUp", "  global gHCScriptsTest", "  AddColor enableObject,cd,2", \
         "  putVar cd, " & q & "x" & q & ", 5", "  if true then putVar bkgnd, " & q & "y" & q & ", 6", \
         "  put getVar(card, " & q & "z" & q & ") after gHCScriptsTest", "  putVar " & q & "stack" & q & ", " & q & "w" & q & ", 7", \
         "  put 1 into x", "  putVar x, menu, 8", "end mouseUp", \
         "on other", "  toggleProperty cantDelete,card," & q & "CantDelete" & q, "  putVar cd 1, x, 2", "  putVar x, off, 2", "end other") into tOriginal
   set the script of button "B" to tOriginal
   unlock messages
   TestAssert "T37: the script compiles as it is", _Compiles(tOriginal)
   get revHyperCardFixScripts(tStack)
   put the script of button "B" of stack tStack into tScript
   TestAssert "T37: an external's argument, compiled", line 3 of tScript is "  AddColor enableObject," & q & "cd" & q & ",2"
   TestAssert "T37: a handler of the stack's argument, compiled", line 4 of tScript is "  putVar " & q & "cd" & q & ", " & q & "x" & q & ", 5"
   TestAssert "T37: after then", line 5 of tScript is "  if true then putVar " & q & "bkgnd" & q & ", " & q & "y" & q & ", 6"
   TestAssert "T37: a function of the stack's argument, compiled", line 6 of tScript is "  put getVar(" & q & "card" & q & ", " & q & "z" & q & ") after gHCScriptsTest"
   TestAssert "T37: after a variable", line 9 of tScript is "  putVar x, " & q & "menu" & q & ", 8"
   TestAssert "T37: a command this engine does not have, compiled", line 12 of tScript is "  toggleProperty cantDelete," & q & "card" & q & "," & q & "CantDelete" & q
   TestAssert "T37: in quotes already, an object named, a variable, off: unchanged", \
         line 7 of tScript is line 7 of tOriginal and line 13 to 14 of tScript is line 13 to 14 of tOriginal
   TestAssert "T37: the script still compiles", _Compiles(tScript)
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "T37: the words as their own text, as in HyperCard", gHCScriptsTest is "cd:x=5,bkgnd:y=6,card:z,stack:w=7,1:menu=8,"
   _Close tStack
end TestHyperCardScriptsT37Compiled

on TestHyperCardScriptsT38
   -- exit and pass with another handler's name: the handler's own
   local tScript, q
   put quote into q
   put _Rewrite("on createText", "  if it is empty then exit saveToDisk", "  exit saveToDisk", "  exit repeat", "  exit to top", "  exit createText", \
         "end createText", "on keyDown whatKey", "  if whatKey is " & q & "a" & q & " then pass whatKey else beep", "  pass " & q & "doMenu" & q, \
         "end keyDown") into tScript
   TestAssert "T38: exit with another handler's name, after then", line 2 of tScript is "  if it is empty then exit createText"
   TestAssert "T38: exit with another handler's name", line 3 of tScript is "  exit createText"
   TestAssert "T38: exit repeat, exit to top and the handler's own: unchanged", line 4 to 6 of tScript is _Lines("  exit repeat", "  exit to top", "  exit createText")
   TestAssert "T38: pass a parameter's name, before else", line 9 of tScript is "  if whatKey is " & q & "a" & q & " then pass keyDown else beep"
   TestAssert "T38: pass a name in quotes", line 10 of tScript is "  pass keyDown"
   TestAssert "T38: those compile", _Compiles(tScript)

   -- global with names in quotes, or none between commas
   put _Rewrite("on mouseUp", "  Global " & q & "Mapper" & q & " -- the map", "  global a, , b,", "  global c, d", "  put 1 into Mapper", "end mouseUp") into tScript
   TestAssert "T38: a global's name in quotes", line 2 of tScript is "  Global Mapper -- the map"
   TestAssert "T38: no name between commas", line 3 of tScript is "  global a, b"
   TestAssert "T38: names alone: unchanged", line 4 of tScript is "  global c, d"
   TestAssert "T38: the globals compile", _Compiles(tScript)
   put _Rewrite("on mouseUp", "  global the short name of the target", "end mouseUp") into tScript
   TestAssert "T38: an expression after global: unchanged", line 2 of tScript is "  global the short name of the target"
end TestHyperCardScriptsT38

on TestHyperCardScriptsT39
   -- a handler that still does not compile keeps every line that does:
   -- the others are left out as comments and the handler goes on past
   -- them, or, in a repeat that only a condition ends and for return,
   -- stops there with an error that names the line
   local tStack, tScript, tError, tLeft, q
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT39" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put " & q & "a" & q & " into gHCScriptsTest", \
         "  put 1 +* into y", "  put " & q & "b" & q & " after gHCScriptsTest", "end mouseUp", \
         "on mouseDown", "  global gHCScriptsTest", "  put " & q & "c" & q & " into gHCScriptsTest", "  repeat until gHCScriptsTest is " & q & "cdd" & q, \
         "    put " & q & "d" & q & " after gHCScriptsTest", "    put 1 +* into x", "  end repeat", "end mouseDown", \
         "on mouseEnter", "  global gHCScriptsTest", "  put empty into gHCScriptsTest", "  repeat with i = 1 to 3", "    put i after gHCScriptsTest", \
         "    put 1 +* into x", "  end repeat", "end mouseEnter", \
         "on mouseLeave", "  global gHCScriptsTest", "  put " & q & "two" & q & " into gHCScriptsTest", "  put 1 + \", "     +* 2 into x", \
         "  put " & q & " lines" & q & " after gHCScriptsTest", "end mouseLeave", \
         "function twice x", "  put x * 2 into y", "  return y +* 1", "end twice", \
         "on ifParts p", "  global gHCScriptsTest", "  put " & q & "i" & q & " into gHCScriptsTest", "  if p is 1 then put 1 +* into x", \
         "  if p is 2 then put " & q & "2" & q & " after gHCScriptsTest else put 1 +* into x", "  put " & q & "!" & q & " after gHCScriptsTest", "end ifParts", \
         "on loopPart p", "  global gHCScriptsTest", "  put empty into gHCScriptsTest", "  repeat until gHCScriptsTest is " & q & "xx" & q, \
         "    put " & q & "x" & q & " after gHCScriptsTest", "    if p is 4 then put 2 +* into x", "  end repeat", "end loopPart", \
         "on badCondition", "  if 1 +* 2 then beep", "end badCondition", \
         "on elseParts p", "  global gHCScriptsTest", "  put " & q & "e" & q & " into gHCScriptsTest", "  if p is 1 then put", "  else put", \
         "  put " & q & "!" & q & " after gHCScriptsTest", "end elseParts")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the script of button "B" of stack tStack into tScript
   TestAssert "T39: the script compiles", _Compiles(tScript)
   TestAssert "T39: the line left out, a comment", line 4 of tScript is "  -- HyperCard import: left out, it does not compile here: put 1 +* into y"
   TestAssert "T39: in a repeat that a condition ends, a throw", line 12 of tScript is "    throw " & q & "HyperCard import: a line that does not compile here: put 1 +* into x" & q
   TestAssert "T39: in a repeat with, left out", line 20 of tScript is "    -- HyperCard import: left out, it does not compile here: put 1 +* into x"
   TestAssert "T39: a statement over two lines, both", line 26 to 27 of tScript is _Lines("  -- HyperCard import: left out, it does not compile here: put 1 + \", "  -- +* 2 into x")
   TestAssert "T39: return, a throw", line 32 of tScript is "  throw " & q & "HyperCard import: a line that does not compile here: return y +* 1" & q
   TestAssert "T39: a statement after then, hcLeftOut in its place", line 37 of tScript is "  if p is 1 then hcLeftOut " & q & "put 1 +* into x" & q
   TestAssert "T39: a statement after else", line 38 of tScript is "  if p is 2 then put " & q & "2" & q & " after gHCScriptsTest else hcLeftOut " & q & "put 1 +* into x" & q
   TestAssert "T39: after then in a repeat that a condition ends, a throw", line 46 of tScript is "    if p is 4 then throw " & q & "HyperCard import: a line that does not compile here: put 2 +* into x" & q
   TestAssert "T39: an if whose condition does not compile: the handler left out", "   pass badCondition" is among the lines of tScript
   TestAssert "T39: a statement whose error is given at its then or else", "  if p is 1 then hcLeftOut " & q & "put" & q is among the lines of tScript \
         and "  else hcLeftOut " & q & "put" & q is among the lines of tScript
   TestAssert "T39: the handlers' lines keep their numbers", line 33 of tScript is "end twice" and line 48 of tScript is "end loopPart"

   send "mouseUp" to button "B" of stack tStack
   TestAssert "T39: the handler goes on past the line left out", gHCScriptsTest is "ab"
   send "mouseEnter" to button "B" of stack tStack
   TestAssert "T39: and so does a repeat with", gHCScriptsTest is "123"
   send "mouseLeave" to button "B" of stack tStack
   TestAssert "T39: and past a statement over two lines", gHCScriptsTest is "two lines"
   put empty into tError
   try
      send "mouseDown" to button "B" of stack tStack
   catch tError
   end try
   TestAssert "T39: the throw stops the handler, naming the line", gHCScriptsTest is "cd" and "a line that does not compile here: put 1 +* into x" is in tError
   put empty into tError
   try
      dispatch function "twice" to button "B" of stack tStack with 2
   catch tError
   end try
   TestAssert "T39: a return that does not compile stops the function", "return y +* 1" is in tError
   send "ifParts 1" to button "B" of stack tStack
   TestAssert "T39: the handler goes on past a then left out", gHCScriptsTest is "i!"
   send "ifParts 2" to button "B" of stack tStack
   TestAssert "T39: the then that compiles runs, the else left out", gHCScriptsTest is "i2!"
   send "loopPart 3" to button "B" of stack tStack
   TestAssert "T39: the throw only where the then is taken", gHCScriptsTest is "xx"
   put empty into tError
   try
      send "loopPart 4" to button "B" of stack tStack
   catch tError
   end try
   TestAssert "T39: and there it stops the handler", gHCScriptsTest is "x" and "put 2 +* into x" is in tError
   send "elseParts 1" to button "B" of stack tStack
   TestAssert "T39: past the then left out", gHCScriptsTest is "e!"
   send "elseParts 2" to button "B" of stack tStack
   TestAssert "T39: and past the else", gHCScriptsTest is "e!"

   put revHyperCardLeftOutLines() into tLeft
   TestAssert "T39: the lines left out, listed", the number of elements of tLeft is 10
   TestAssert "T39: each with its handler, line, text and how", tLeft[1]["name"] is "mouseUp" and tLeft[1]["line"] is 4 and tLeft[1]["how"] is "skipped" \
         and tLeft[2]["name"] is "mouseDown" and tLeft[2]["line"] is 6 and tLeft[2]["how"] is "stops" and tLeft[2]["text"] is "put 1 +* into x" \
         and tLeft[4]["text"] is "put 1 + +* 2 into x" \
         and tLeft[6]["name"] is "ifParts" and tLeft[6]["line"] is 4 and tLeft[6]["text"] is "if p is 1 then put 1 +* into x" and tLeft[6]["how"] is "skipped" \
         and tLeft[8]["name"] is "loopPart" and tLeft[8]["how"] is "stops" \
         and tLeft[9]["name"] is "elseParts" and tLeft[9]["text"] is "if p is 1 then put" and tLeft[10]["text"] is "else put" and tLeft[10]["how"] is "skipped"
   put revHyperCardLeftOutHandlers() into tLeft
   TestAssert "T39: only the handler whose if does not compile left out whole", the number of elements of tLeft is 1 and tLeft[1]["name"] is "badCondition"
   _Close tStack
end TestHyperCardScriptsT39

on TestHyperCardScriptsT40
   -- open an application, or a document with one, which HyperCard
   -- launched and this engine takes for a "go"; and HyperCard 2.4's open url
   local tStack, tScript, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  open " & q & "ResEdit" & q, "  open docName with progName", "  if x then open it else open " & q & "TeachText" & q, \
         "  open MacDraw 1.9.5", "  open Hard Disk:Apps:VersaTerm Pro", "  open " & q & ":Demo:" & q & " & the short name of me with " & q & "Think C" & q, \
         "  open url tURL", "end mouseUp") into tScript
   TestAssert "T40: open an application", line 2 of tScript is "  hcOpen " & q & "ResEdit" & q
   TestAssert "T40: a document with an application", line 3 of tScript is "  hcOpen progName, docName"
   TestAssert "T40: both branches of a one-line if", line 4 of tScript is "  if x then hcOpen it else hcOpen " & q & "TeachText" & q
   TestAssert "T40: a name not in quotes, its version too", line 5 of tScript is "  hcOpen " & q & "MacDraw 1.9.5" & q
   TestAssert "T40: an HFS path not in quotes", line 6 of tScript is "  hcOpen " & q & "Hard Disk:Apps:VersaTerm Pro" & q
   TestAssert "T40: expressions", line 7 of tScript is "  hcOpen " & q & "Think C" & q & ", " & q & ":Demo:" & q & " & the short name of me"
   TestAssert "T40: open url", line 8 of tScript is "  launch url tURL"
   TestAssert "T40: those compile", _Compiles(tScript)
   put _Rewrite("on mouseUp", "  open file tPath for read", "  open printing with dialog", "  open stack " & q & "Other" & q, \
         "  open process tProc for update", "  open socket to tHost", "end mouseUp") into tScript
   TestAssert "T40: what this engine opens: unchanged", line 2 to 6 of tScript is _Lines("  open file tPath for read", "  open printing with dialog", \
         "  open stack " & q & "Other" & q, "  open process tProc for update", "  open socket to tHost")

   -- in a script that compiles as well, and the library's hcOpen
   put "HCScriptsT40" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "A"
   set the script of button "A" to _Lines("on mouseUp", "  global gHCScriptsTest", "  open " & q & "No Such Application T40" & q, \
         "  put the result into gHCScriptsTest", "  open " & q & "No Such Document" & q & " with " & q & "No Such Application T40" & q, \
         "  put return & the result after gHCScriptsTest", "  open report printing", "  put return & the result after gHCScriptsTest", "end mouseUp")
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  open MacDraw 1.9.5", "  open url theURL", "end mouseUp")
   unlock messages
   TestAssert "T40: the first script compiles here as it is", _Compiles(the script of button "A" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put the script of button "A" of stack tStack into tScript
   TestAssert "T40: in a script that compiles", line 3 of tScript is "  hcOpen " & q & "No Such Application T40" & q \
         and line 5 of tScript is "  hcOpen " & q & "No Such Application T40" & q & ", " & q & "No Such Document" & q \
         and line 7 of tScript is "  hcOpenReportPrinting empty"
   put the script of button "B" of stack tStack into tScript
   TestAssert "T40: in one that does not", line 2 to 3 of tScript is _Lines("  hcOpen " & q & "MacDraw 1.9.5" & q, "  launch url theURL")
   put empty into gHCScriptsTest
   send "mouseUp" to button "A" of stack tStack
   TestAssert "T40: no such application: HyperCard's result, and the script goes on", \
         gHCScriptsTest is _Lines("Couldn't open that application.", "Couldn't open that application.", "Report printing is not supported")
   _Close tStack
end TestHyperCardScriptsT40

on TestHyperCardScriptsT41
   -- the menu messages of put ... into menu: a statement HyperCard sent as
   -- it was written, a list of messages, and an item by its place after
   -- "the"
   local tStack, tScript, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  put " & q & "Title Card" & q & " after menu " & q & "Quotes" & q & " with menuMsg go to card id 90024", \
         "  put " & q & "New Protocol" & q & " after menu " & q & "Util" & q & " with menumsg doMenu " & q & "New Card" & q, \
         "  put " & q & "A,B,C" & q & " after menu " & q & "Tools" & q & " with menuMsg AC_Front," & q & q & ",AC_Back", \
         "  put " & q & "X,Y" & q & " after menu " & q & "M" & q & " with menuMsgs item 1 of tList, item 2 of tList", \
         "  put " & q & "Import,-" & q & " before the last menuItem of menu " & q & "File" & q & " with menuMessages " & q & "doImport," & q, \
         "  put " & q & "Sorted" & q & " after menu " & q & "Go" & q & " with menuMsg doSort", "end mouseUp") into tScript
   TestAssert "T41: a statement, in quotes", line 2 of tScript is "  hcPutIntoMenu " & q & "Title Card" & q & ", " & q & "after" & q & ", " & q & "Quotes" & q & ", " & q & "go to card id 90024" & q
   TestAssert "T41: a statement with a string", line 3 of tScript is "  hcPutIntoMenu " & q & "New Protocol" & q & ", " & q & "after" & q & ", " & q & "Util" & q & ", " & q & "doMenu " & q & " & quote & " & q & "New Card" & q & " & quote"
   TestAssert "T41: a list of messages, one value", line 4 of tScript is "  hcPutIntoMenu " & q & "A,B,C" & q & ", " & q & "after" & q & ", " & q & "Tools" & q & ", AC_Front & comma & " & q & q & " & comma & AC_Back"
   TestAssert "T41: a list of expressions", line 5 of tScript is "  hcPutIntoMenu " & q & "X,Y" & q & ", " & q & "after" & q & ", " & q & "M" & q & ", (item 1 of tList) & comma & (item 2 of tList)"
   TestAssert "T22: before the last menuItem", line 6 of tScript is "  hcPutIntoMenu " & q & "Import,-" & q & ", " & q & "before" & q & ", " & q & "File" & q & ", " & q & "doImport," & q & ", " & q & "last" & q
   TestAssert "T41: one name: unchanged", line 7 of tScript is "  hcPutIntoMenu " & q & "Sorted" & q & ", " & q & "after" & q & ", " & q & "Go" & q & ", doSort"
   TestAssert "T41: those compile", _Compiles(tScript)

   -- with the probe of revHyperCardFixScripts, a handler's call; and the
   -- library sending each message when its item is chosen
   put "HCScriptsT41" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("on hcT41Quiz pWhich", "  global gHCScriptsTest", "  put comma & pWhich after gHCScriptsTest", "end hcT41Quiz", \
         "on hcT41B", "  global gHCScriptsTest", "  put comma & " & q & "B" & q & " after gHCScriptsTest", "end hcT41B", \
         "on doMenu pItem", "  global gHCScriptsTest", "  if pItem is " & q & "T41 Item" & q & " then", "    put comma & " & q & "D" & q & " after gHCScriptsTest", \
         "  else", "    pass doMenu", "  end if", "end doMenu")
   create field "Notes"
   put "Notes T41" into field "Notes"
   hide field "Notes"
   create button "Menus"
   set the script of button "Menus" to _Lines("on mouseUp", "  put " & q & "Go Two" & q & " after menu " & q & "Util" & q & " with menuMsg go to card " & q & "Two" & q, \
         "  put " & q & "Show Notes" & q & " after menu " & q & "Util" & q & " with menumsg show fld " & q & "Notes" & q, \
         "  put " & q & "Quiz" & q & " after menu " & q & "Util" & q & " with menuMsg hcT41Quiz capitals", \
         "  put " & q & "A,B" & q & " after menu " & q & "Util" & q & " with menuMsgs hcT41A,hcT41B", \
         "  put " & q & "Add" & q & " after menu " & q & "Util" & q & " with menuMsg doMenu " & q & "T41 Item" & q, "end mouseUp")
   create button "Choose"
   set the script of button "Choose" to _Lines("on mouseUp", "  global gHCScriptsTest", "  doMenu " & q & "Show Notes" & q, \
         "  put the visible of field " & q & "Notes" & q & " into gHCScriptsTest", "  doMenu " & q & "Go Two" & q, \
         "  put comma & the short name of this card after gHCScriptsTest", "  go to card 1", "  doMenu " & q & "Quiz" & q, \
         "  doMenu " & q & "B" & q, "  doMenu " & q & "Add" & q, "end mouseUp")
   create card "Two"
   go to card 1
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the script of button "Menus" of card 1 of stack tStack into tScript
   TestAssert "T41: statements in quotes", line 2 to 3 of tScript is _Lines("  hcPutIntoMenu " & q & "Go Two" & q & ", " & q & "after" & q & ", " & q & "Util" & q & ", " & q & "go to card " & q & " & quote & " & q & "Two" & q & " & quote", \
         "  hcPutIntoMenu " & q & "Show Notes" & q & ", " & q & "after" & q & ", " & q & "Util" & q & ", " & q & "show fld " & q & " & quote & " & q & "Notes" & q & " & quote")
   TestAssert "T41: a handler's call that is no value here, in quotes (the probe)", line 4 of tScript is "  hcPutIntoMenu " & q & "Quiz" & q & ", " & q & "after" & q & ", " & q & "Util" & q & ", " & q & "hcT41Quiz capitals" & q
   TestAssert "T41: a list of names", line 5 of tScript is "  hcPutIntoMenu " & q & "A,B" & q & ", " & q & "after" & q & ", " & q & "Util" & q & ", hcT41A & comma & hcT41B"
   set the defaultStack to tStack
   send "mouseUp" to button "Menus" of card 1 of stack tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Choose" of card 1 of stack tStack
   TestAssert "T41: each message sent as HyperCard sent it (a command as written, a handler's call, a list, a doMenu)", gHCScriptsTest is "true,Two,capitals,B,D"
   _Close tStack
end TestHyperCardScriptsT41

on TestHyperCardScriptsT42
   -- do with a statement not in quotes, which HyperCard ran as it was
   -- written; and T14's visual effect from a variable after "unlock
   -- screen with"
   local tStack, tScript, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  unlock screen with visual zoom theVisEffect", "  unlock screen with wipe it", \
         "  unlock screen with visual effect dissolve EFFECT_SPEED", "  unlock screen with visual dissolve very fast", \
         "  do go cd id 13086", "end mouseUp") into tScript
   TestAssert "T14: unlock screen with a visual effect from a variable", line 2 to 4 of tScript is _Lines("  do " & q & "unlock screen with visual zoom" & q && "&& theVisEffect", \
         "  do " & q & "unlock screen with wipe" & q && "&& it", "  do " & q & "unlock screen with visual effect dissolve" & q && "&& EFFECT_SPEED")
   TestAssert "T14: unlock screen with this engine's words: unchanged", line 5 of tScript is "  unlock screen with visual dissolve very fast"
   TestAssert "T42: without the probe, a do is left as it is", line 6 of tScript is "  do go cd id 13086"

   -- with the probe of revHyperCardFixScripts: the statements run in the
   -- handler's context, its variables included
   put "HCScriptsT42" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "A"
   set the script of button "A" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put " & q & "T42" & q & " into tWhere", \
         "  do put tWhere & comma after gHCScriptsTest", "  do go cd " & q & "Two" & q, "  put the short name of this card after gHCScriptsTest", \
         "  do put " & q & "x" & q & " && the short name of this card into tOut", "  put comma & tOut after gHCScriptsTest", \
         "  put " & q & "put 1 into tOne" & q & " into tCmd", "  do tCmd", "  put comma & tOne after gHCScriptsTest", \
         "  do put 1 into", "  put " & q & "open" & q & " into theVisEffect", "  lock screen", "  unlock screen with visual zoom theVisEffect", \
         "  put comma & " & q & "end" & q & " after gHCScriptsTest", "end mouseUp")
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  do go cd " & q & "Two" & q, "  do tCmd", "end mouseUp")
   create card "Two"
   go to card 1
   unlock messages
   TestAssert "T42: the first script does not compile here as it is", not _Compiles(the script of button "A" of card 1 of stack tStack)
   TestAssert "T42: the second does", _Compiles(the script of button "B" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   put the script of button "A" of card 1 of stack tStack into tScript
   TestAssert "T42: statements in quotes", line 4 to 5 of tScript is _Lines("  do " & q & "put tWhere & comma after gHCScriptsTest" & q, \
         "  do " & q & "go cd " & q & " & quote & " & q & "Two" & q & " & quote") \
         and line 7 of tScript is "  do " & q & "put " & q & " & quote & " & q & "x" & q & " & quote & " & q & " && the short name of this card into tOut" & q
   TestAssert "T42: a do of an expression: unchanged", line 10 of tScript is "  do tCmd"
   TestAssert "T42: a statement that does not compile here either: not put in quotes", "do " & q & "put 1 into" is not in tScript
   TestAssert "T42: in a script that compiles, where the do ran its first word alone (go)", line 2 to 3 of the script of button "B" of card 1 of stack tStack \
         is _Lines("  do " & q & "go cd " & q & " & quote & " & q & "Two" & q & " & quote", "  do tCmd")
   TestAssert "T42: the script compiles", _Compiles(tScript)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "A" of card 1 of stack tStack
   TestAssert "T42: each statement run as HyperCard ran it", gHCScriptsTest is "T42,Two,x Two,1,end"
   _Close tStack
end TestHyperCardScriptsT42

on TestHyperCardScriptsT43
   -- go to a card of a stack named without the word "stack" after a
   -- background or after "in", and to a background of a stack, which this
   -- engine does not go to
   local tStack, tScript, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  go last cd of bg " & q & "stocks" & q & " of stackName", "  go bkgnd " & q & "Workouts" & q & " of importStack", \
         "  go to card " & q & "print utility" & q & " in " & q & "Utilities 1.1" & q, "  go background " & q & "The Tree" & q & " of stack oldTree", \
         "  go to card 3 in a new window", "  go cd x of bg 2", "  go to card 2 of bg 3 of this stack", "  go to the first card in naam", "end mouseUp") into tScript
   TestAssert "T43: a card of a background of a stack named without stack", line 2 of tScript is "  do hcGo(" & q & "go last cd of bg " & q & " & quote & " & q & "stocks" & q & " & quote & " & q & " of stack tHCStack" & q & ", " & q & "stackName" & q & ")"
   TestAssert "T43: a background of a stack named without stack: its first card", line 3 of tScript is "  do hcGo(" & q & "go card 1 of bkgnd " & q & " & quote & " & q & "Workouts" & q & " & quote & " & q & " of stack tHCStack" & q & ", " & q & "importStack" & q & ")"
   TestAssert "T43: in a stack", line 4 of tScript is "  do hcGo(" & q & "go to card " & q & " & quote & " & q & "print utility" & q & " & quote & " & q & " of stack tHCStack" & q & ", quote & " & q & "Utilities 1.1" & q & " & quote)"
   TestAssert "T43: a background of a stack named with stack: its first card", line 5 of tScript is "  do hcGo(" & q & "go card 1 of background " & q & " & quote & " & q & "The Tree" & q & " & quote & " & q & " of stack tHCStack" & q & ", " & q & "oldTree" & q & ")"
   TestAssert "T43: in a new window, a background of this stack: unchanged", line 6 to 8 of tScript is _Lines("  go to card 3 in a new window", "  go cd x of bg 2", "  go to card 2 of bg 3 of this stack")
   TestAssert "T43: in a stack named by a variable", line 9 of tScript is "  do hcGo(" & q & "go to the first card of stack tHCStack" & q & ", " & q & "naam" & q & ")"
   TestAssert "T43: those compile", _Compiles(tScript)

   -- and the go run: the first card of the background, and the card, of
   -- the stack a variable names
   put "HCScriptsT43" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Go"
   set the script of button "Go" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the short name of this stack into tName", \
         "  go bkgnd " & q & "Second" & q & " of tName", "  put the short name of this card into gHCScriptsTest", \
         "  go to card " & q & "Three" & q & " in tName", "  put comma & the short name of this card after gHCScriptsTest", "end mouseUp")
   -- (a go in a stack this engine compiles as a window's, and stops at)
   create button "In"
   set the script of button "In" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the short name of this stack into tName", \
         "  go last card in tName", "  put comma & the short name of this card after gHCScriptsTest", "end mouseUp")
   create card "Two"
   create group "Second"
   set the backgroundBehavior of group "Second" to true
   create card "Three"
   create card "Four"
   go to card 1
   unlock messages
   TestAssert "T43: the second script compiles here as it is", _Compiles(the script of button "In" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T43: in a script that compiles", line 4 of the script of button "In" of card 1 of stack tStack \
         is "  do hcGo(" & q & "go last card of stack tHCStack" & q & ", " & q & "tName" & q & ")"
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Go" of card 1 of stack tStack
   send "mouseUp" to button "In" of card 1 of stack tStack
   TestAssert "T43: the first card of the background, the card, and the last card, as HyperCard went", gHCScriptsTest is "Two,Three,Four"
   _Close tStack
end TestHyperCardScriptsT43

on TestHyperCardScriptsT44
   -- an object's name not in quotes that this engine reads as one of its
   -- constants ("help" is 15 here), which HyperCard took as its text
   local tStack, tScript, q, i
   put quote into q
   put _Rewrite("on mouseUp", "  show cd fld help", "  hide btn arrow of card none", "  add 1 to fld Plus", "  set the loc of bg btn help to 437,323", \
         "  put help into x", "end mouseUp", "on mouseDown", "  put " & q & "F1" & q & " into help", "  put 1 into fld help", "end mouseDown") into tScript
   TestAssert "T44: names in quotes", line 2 to 5 of tScript is _Lines("  show cd fld " & q & "help" & q, "  hide btn " & q & "arrow" & q & " of card " & q & "none" & q, \
         "  add 1 to fld " & q & "Plus" & q, "  set the loc of bg btn " & q & "help" & q & " to 437,323")
   TestAssert "T44: a value that is no object's name: unchanged", line 6 of tScript is "  put help into x"
   TestAssert "T44: a variable so named (T2) names its field still", line 9 to 10 of tScript is _Lines("  put " & q & "F1" & q & " into hc_help", "  put 1 into fld hc_help")
   -- an object called home, which this engine reads as the "home" of "go
   -- home" (Zaum Gadget's card Home); a variable called home, which
   -- HyperCard took first
   put _Rewrite("on mouseUp", "  go to card home", "  hide bg btn Home", "end mouseUp", "on mouseDown", "  put 2 into home", "  go to card home", "end mouseDown") into tScript
   TestAssert "T44: an object called home, in quotes", line 2 to 3 of tScript is _Lines("  go to card " & q & "home" & q, "  hide bg btn " & q & "Home" & q)
   TestAssert "T44: a variable called home names its card still", line 7 of tScript is "  go to card (home)"
   TestAssert "T44: those compile", _Compiles(tScript)

   -- and in a script that compiles, where "fld help" was field 15
   put "HCScriptsT44" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   repeat with i = 1 to 15
      create field ("F" & i)
   end repeat
   create field "help"
   create field "Plus"
   put 1 into field "Plus"
   create button "Names"
   set the script of button "Names" to _Lines("on mouseUp", "  put " & q & "x" & q & " into cd fld help", "  add 1 to fld Plus", "end mouseUp")
   create button "Go"
   set the script of button "Go" to _Lines("on mouseUp", "  go to card home", "end mouseUp")
   create card "Home"
   go to card 1 of stack tStack
   unlock messages
   TestAssert "T44: go to card home does not compile here as it is", not _Compiles(the script of button "Go" of card 1 of stack tStack)
   TestAssert "T44: the script compiles here as it is", _Compiles(the script of button "Names" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T44: in a script that compiles", line 2 to 3 of the script of button "Names" of card 1 of stack tStack \
         is _Lines("  put " & q & "x" & q & " into cd fld " & q & "help" & q, "  add 1 to fld " & q & "Plus" & q)
   set the defaultStack to tStack
   send "mouseUp" to button "Names" of card 1 of stack tStack
   TestAssert "T44: the fields named, as in HyperCard, and not fields 15 and 13", field "help" of card 1 of stack tStack is "x" \
         and field "Plus" of card 1 of stack tStack is 2 and field "F15" of card 1 of stack tStack is empty and field "F13" of card 1 of stack tStack is empty
   go to card 1 of stack tStack
   send "mouseUp" to button "Go" of card 1 of stack tStack
   TestAssert "T44: go to card home: the card called Home", the short name of this card of stack tStack is "Home"
   _Close tStack
end TestHyperCardScriptsT44

on TestHyperCardScriptsT45
   -- HyperCard's Home stack named but not gone to, which here is the IDE's
   -- stack "home"
   local tStack, tScript, q, tHome, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  set the script of stack " & q & "Home" & q & " to tScript", "  get the long name of stack Home", \
         "  if x then send " & q & "startUp" & q & " to stack home", "  go to stack " & q & "Home" & q, "  get the script of stack " & q & "Homer" & q, "end mouseUp") into tScript
   TestAssert "T45: Home named", line 2 to 4 of tScript is _Lines("  set the script of stack hcHome() to tScript", "  get the long name of stack hcHome()", \
         "  if x then send " & q & "startUp" & q & " to stack hcHome()")
   TestAssert "T45: a go home, another stack: unchanged", line 5 to 6 of tScript is _Lines("  hcGoHome", "  get the script of stack " & q & "Homer" & q)
   TestAssert "T45: those compile", _Compiles(tScript)
   -- Home named without "stack": a send's stack, and what has a property
   -- or a card; a variable called home: unchanged
   put _Rewrite("on mouseUp", "  if the cantmodify of home then beep", "  get the value of word 2 of the long name of home", "  send startup to Home", \
         "  go to card " & q & "Reset BBS" & q & " of home", "  get the number of cards of home", "  go to card 1 of home", "end mouseUp", \
         "on mouseDown", "  put 1 into home", "  put word 2 of home into x", "  put the length of home into x", "  add 1 to home", "end mouseDown") into tScript
   TestAssert "T45: Home named without stack", line 2 to 6 of tScript is _Lines("  if the cantmodify of stack hcHome() then beep", \
         "  get the value of word 2 of the long name of stack hcHome()", "  send startup to stack hcHome()", \
         "  go to card " & q & "Reset BBS" & q & " of stack hcHome()", "  get the number of cards of stack hcHome()")
   TestAssert "T45: its first card, T9's", line 7 of tScript is "  hcGoHome"
   TestAssert "T45: a variable called home: unchanged", line 10 to 13 of tScript \
         is _Lines("  put 1 into home", "  put word 2 of home into x", "  put the length of home into x", "  add 1 to home")
   TestAssert "T45: those compile too", _Compiles(tScript)

   -- and run, in a script that compiles, with a stack called "home" in
   -- memory as the IDE's is: its script stays as it was
   put "HCScriptsT45" & the milliseconds into tStack
   lock messages
   if there is not a stack "home" then
      create invisible stack "home"
      set the script of stack "home" to _Lines("on hcT45Home", "end hcT45Home")
      put "home" into tHome
   end if
   put the script of stack "home" into tScript
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Install"
   set the script of button "Install" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the script of stack " & q & "Home" & q & " into tHome", \
         "  put " & q & "on hcT45" & q & " & return & " & q & "end hcT45" & q & " after tHome", "  set the script of stack " & q & "Home" & q & " to tHome", \
         "  put the script of stack " & q & "Home" & q & " into gHCScriptsTest", "end mouseUp")
   create button "Start"
   set the script of button "Start" to _Lines("on mouseUp", "  global gHCScriptsTest", "  send startUp to stack " & q & "Home" & q, "  put " & q & "started" & q & " into gHCScriptsTest", "end mouseUp")
   create button "Bare"
   set the script of button "Bare" to _Lines("on mouseUp", "  global gHCScriptsTest", "  send startup to home", \
         "  if not the cantmodify of home then put the long name of home into gHCScriptsTest", "end mouseUp")
   unlock messages
   TestAssert "T45: the script compiles here as it is", _Compiles(the script of button "Install" of card 1 of stack tStack)
   TestAssert "T45: Home without stack compiles here as it is", _Compiles(the script of button "Bare" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Install" of card 1 of stack tStack
   -- (the engine ends a script with a return)
   TestAssert "T45: the script went into HyperCard's Home, the stand-in", gHCScriptsTest is _Lines("on hcT45", "end hcT45") & return \
         and the script of stack "HyperCard Home" is gHCScriptsTest
   TestAssert "T45: the IDE's home is as it was", the script of stack "home" is tScript
   -- startUp, which HyperCard's Home passed on, to the stand-in, which has
   -- no handler for it
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Start" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T45: startUp sent to the stand-in goes on, as it did to Home", gHCScriptsTest is "started"
   TestAssert "T45: and the IDE's home is still as it was", the script of stack "home" is tScript
   put empty into gHCScriptsTest
   send "mouseUp" to button "Bare" of card 1 of stack tStack
   TestAssert "T45: Home without stack, in a script that compiles: the stand-in", gHCScriptsTest is the long name of stack "HyperCard Home"
   _Close tStack

   -- the stand-in's library when the stack it was made for has gone: the
   -- next stack's
   put "HCScriptsT45b" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Ask"
   set the script of button "Ask" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the behavior of stack " & q & "Home" & q & " into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Ask" of card 1 of stack tStack
   TestAssert "T45: the stand-in has the library of the stack that asks, the first one's gone", \
         gHCScriptsTest is not empty and gHCScriptsTest is the behavior of stack tStack
   _Close tStack
   if there is a stack "HyperCard Home" then delete stack "HyperCard Home"
   if tHome is not empty then delete stack tHome
end TestHyperCardScriptsT45

on TestHyperCardScriptsT46
   -- HyperCard's windows by their top left, on the screen for a card
   -- window and from the card window's top left for every other, where
   -- this engine's loc is a stack's centre on the screen: the location of
   -- the card window, of a window, of the message box, and show ... at;
   -- show and hide card window; HyperCard's own windows named in quotes;
   -- the message box's properties without "the"
   local tStack, tScript, q, tPalette, tMessage, tOldMessage, tPlte, tPicture, tOrigin
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", "  set the loc of card window to 0,20", "  put item 1 of loc of cd window + 153 into x", "  put the location of the card window into p", \
         "  show card window at 20,50", "  hide the card window", "  if x then show cd window", \
         "  get the loc of window " & q & "Map" & q, "  set the location of window w to 10,10", \
         "  put the visible of window " & q & "Scroll" & q & " into v", "  set the loc of window " & q & "Variable Watcher" & q & " to " & q & "0,18" & q, \
         "  show msg at 15,300", "  show tool window at 72,189", "  if visible of msg then put loc of msg into p", "end mouseUp") into tScript
   TestAssert "T46: the card window's location is its top left", line 2 to 4 of tScript \
         is _Lines("  set the topLeft of this stack to 0,20", "  put item 1 of topLeft of this stack + 153 into x", "  put the topLeft of this stack into p")
   TestAssert "T46: show and hide card window", line 5 to 7 of tScript is _Lines("  hcWindow " & q & "show" & q & ", " & q & "card window" & q & ", 20,50", \
         "  hcWindow " & q & "hide" & q & ", " & q & "card window" & q, "  if x then hcWindow " & q & "show" & q & ", " & q & "card window" & q)
   TestAssert "T46: a window's location, the library's", line 8 to 9 of tScript is _Lines("  get hcWindowProperty(" & q & "loc" & q & ", " & q & "Map" & q & ")", \
         "  hcSetWindow " & q & "location" & q & ", w, 10,10")
   TestAssert "T46: HyperCard's own windows by name", line 10 to 11 of tScript is _Lines("  put hcWindowProperty(" & q & "visible" & q & ", " & q & "Scroll" & q & ") into v", \
         "  hcSetWindow " & q & "loc" & q & ", " & q & "Variable Watcher" & q & ", " & q & "0,18" & q)
   TestAssert "T46: the message box and a window of HyperCard's shown at a place", line 12 to 13 of tScript \
         is _Lines("  hcWindow " & q & "show" & q & ", " & q & "message" & q & ", 15,300", "  hcWindow " & q & "show" & q & ", " & q & "tool" & q & ", 72,189")
   TestAssert "T46: the message box's properties without the", line 14 of tScript is "  if hcMessageBox(" & q & "visible" & q & ") then put hcMessageBox(" & q & "loc" & q & ") into p"
   TestAssert "T46: those compile", _Compiles(tScript)

   -- a window's other places, the window in parentheses, a set after an
   -- else; T26's globalLoc; window id, which this engine finds no window
   -- by, and a word that goes on into an expression: unchanged; the
   -- watchers shown and hidden
   put _Rewrite("on mouseUp", "  set the rect of window " & q & "Map" & q & " to 0,0,100,100", "  put the top of window (the short name of me) into t", \
         "  if c then set the loc of window a to p else set the loc of window b to p", "  get the globalRect of window " & q & "Map" & q, \
         "  set the globalLoc of window " & q & "Map" & q & " to 1,1", "  get the loc of window id 3", "  get the loc of window item 1 of x", \
         "  show variable watcher", "  hide the message watcher", "end mouseUp") into tScript
   TestAssert "T46: a window's rect, its top", line 2 to 3 of tScript is _Lines("  hcSetWindow " & q & "rect" & q & ", " & q & "Map" & q & ", 0,0,100,100", \
         "  put hcWindowProperty(" & q & "top" & q & ", (the short name of me)) into t")
   TestAssert "T46: a set after else", line 4 of tScript is "  if c then hcSetWindow " & q & "loc" & q & ", a, p else hcSetWindow " & q & "loc" & q & ", b, p"
   TestAssert "T46: the globalRect read, the globalLoc set (T26)", line 5 to 6 of tScript is _Lines("  get hcWindowProperty(" & q & "globalrect" & q & ", " & q & "Map" & q & ")", \
         "  hcSetWindow " & q & "globalloc" & q & ", " & q & "Map" & q & ", 1,1")
   TestAssert "T46: window id, and a word that goes on: unchanged", line 7 to 8 of tScript is _Lines("  get the loc of window id 3", "  get the loc of window item 1 of x")
   TestAssert "T46: the watchers shown and hidden", line 9 to 10 of tScript is _Lines("  hcWindow " & q & "show" & q & ", " & q & "variable watcher" & q, \
         "  hcWindow " & q & "hide" & q & ", " & q & "message watcher" & q)

   -- and run: show card window at, and the loc of a window, compile here
   -- as they are; the loc of card window does not, but without "the" in a
   -- sum it does, and stops there ("can't find stack"). tPalette is another
   -- stack's card window; tPlte a palette the import made from a PLTE
   -- resource, tPicture a picture window, which HyperCard placed from the
   -- card window's top left
   put "HCScriptsT46" & the milliseconds into tStack
   put "HCScriptsT46Other" & the milliseconds into tPalette
   put "HCScriptsT46Plte" & the milliseconds into tPlte
   put "HCScriptsT46Picture" & the milliseconds into tPicture
   lock messages
   create invisible stack tPalette
   set the rect of stack tPalette to 300,300,400,400
   create invisible stack tPlte
   set the rect of stack tPlte to 300,300,400,400
   set the script of stack tPlte to _Lines("-- HyperCard palette (PLTE resource), made by the HyperCard importer", "on mouseUp", "end mouseUp")
   create invisible stack tPicture
   set the rect of stack tPicture to 300,300,400,400
   set the uHyperCard["picture"] of stack tPicture to true
   create invisible stack tStack
   set the rect of stack tStack to 100,100,612,442
   set the defaultStack to tStack
   create button "Show"
   set the script of button "Show" to _Lines("on mouseUp", "  show card window at 20,50", "end mouseUp")
   create button "Hide"
   set the script of button "Hide" to _Lines("on mouseUp", "  hide card window", "end mouseUp")
   create button "Other"
   set the script of button "Other" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set the loc of window " & q & tPalette & q & " to 10,10", \
         "  put the loc of window " & q & tPalette & q & " into gHCScriptsTest", "end mouseUp")
   create button "Plte"
   set the script of button "Plte" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set the loc of window " & q & tPlte & q & " to 10,10", \
         "  put the loc of window " & q & tPlte & q & " into gHCScriptsTest", "  show window " & q & tPlte & q & " at 20,30", \
         "  put comma & the loc of window " & q & tPlte & q & " after gHCScriptsTest", "  palette " & q & tPlte & q & ", " & q & "5,6" & q, \
         "  put comma & the loc of window " & q & tPlte & q & " after gHCScriptsTest", "end mouseUp")
   create button "Picture"
   set the script of button "Picture" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set the rect of window " & q & tPicture & q & " to 0,0,50,40", \
         "  put the rect of window " & q & tPicture & q & " into gHCScriptsTest", "  put comma & the globalLoc of window " & q & tPicture & q & " after gHCScriptsTest", "end mouseUp")
   create button "Card"
   set the script of button "Card" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set the loc of card window to 30,40", "  put the loc of card window into gHCScriptsTest", "end mouseUp")
   create button "Sum"
   set the rect of button "Sum" to 10,20,110,40
   set the script of button "Sum" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put item 1 of loc of card window + 5 into gHCScriptsTest", \
         "  put comma & (top of cd window -1) after gHCScriptsTest", "  put comma & max(left of card window + left of me, \", \
         "  top of the card window + 1) after gHCScriptsTest", "end mouseUp")
   create button "Own"
   set the script of button "Own" to _Lines("on mouseUp", "  global gHCScriptsTest", "  show window " & q & "Scroll" & q, "  show tool window", \
         "  set the loc of window " & q & "Variable Watcher" & q & " to " & q & "0,18" & q, \
         "  put the visible of window " & q & "Scroll" & q & " & comma & the visible of window " & q & "Tools" & q & " into gHCScriptsTest", \
         "  put comma & the loc of window " & q & "Variable Watcher" & q & " after gHCScriptsTest", "  show variable watcher", \
         "  put comma & the visible of the variable watcher after gHCScriptsTest", "  hide variable watcher", \
         "  put comma & the visible of the variable watcher after gHCScriptsTest", "end mouseUp")
   create button "Message"
   set the script of button "Message" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set the loc of msg to 18,30", "  put the loc of msg into gHCScriptsTest", \
         "  show msg at 40,50", "  put comma & the loc of msg after gHCScriptsTest", "end mouseUp")
   unlock messages
   TestAssert "T46: show card window at, and the loc of a window, compile here as they are", \
         _Compiles(the script of button "Show" of card 1 of stack tStack) and _Compiles(the script of button "Other" of card 1 of stack tStack)
   TestAssert "T46: a property of the card window in a sum compiles here as it is", _Compiles(the script of button "Sum" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   send "mouseUp" to button "Show" of card 1 of stack tStack
   TestAssert "T46: show card window at: shown, its top left there", the visible of stack tStack is true and the topLeft of stack tStack is "20,50"
   send "mouseUp" to button "Hide" of card 1 of stack tStack
   TestAssert "T46: hide card window hides it", the visible of stack tStack is false
   put empty into gHCScriptsTest
   send "mouseUp" to button "Other" of card 1 of stack tStack
   TestAssert "T46: another stack's card window, set and read: its top left on the screen", the topLeft of stack tPalette is "10,10" and gHCScriptsTest is "10,10"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Card" of card 1 of stack tStack
   TestAssert "T46: the card window's location, set and read, is its top left", the topLeft of stack tStack is "30,40" and gHCScriptsTest is "30,40"
   put the topLeft of stack tStack into tOrigin
   put empty into gHCScriptsTest
   send "mouseUp" to button "Sum" of card 1 of stack tStack
   TestAssert "T46: a property of the card window without the, in a sum: this stack's, its loc its top left", \
         gHCScriptsTest is (item 1 of tOrigin + 5) & comma & (item 2 of tOrigin - 1) & comma & max(item 1 of tOrigin + 10, item 2 of tOrigin + 1)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Plte" of card 1 of stack tStack
   TestAssert "T46: a palette's location, set, read, shown at and opened at: from the card window's top left", gHCScriptsTest is "10,10,20,30,5,6" \
         and the topLeft of stack tPlte is (item 1 of tOrigin + 5) & comma & (item 2 of tOrigin + 6)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Picture" of card 1 of stack tStack
   TestAssert "T46: a picture window's rect, set and read, from the card window's top left; its globalLoc on the screen", \
         gHCScriptsTest is "0,0,50,40," & tOrigin and the rect of stack tPicture is tOrigin & comma & (item 1 of tOrigin + 50) & comma & (item 2 of tOrigin + 40)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Own" of card 1 of stack tStack
   TestAssert "T46: HyperCard's own windows by name read back what was shown and set", gHCScriptsTest is "true,true,0,18,true,false"

   -- the message box: a stack "Message Box" stands for the IDE's where
   -- there is none
   lock messages
   if there is a stack "Message Box" then
      put the topLeft of stack "Message Box" into tOldMessage
   else
      create invisible stack "Message Box"
      put "Message Box" into tMessage
   end if
   unlock messages
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Message" of card 1 of stack tStack
   TestAssert "T46: the message box's location, set, read and shown at: its top left from the card window's", gHCScriptsTest is "18,30,40,50" \
         and the topLeft of stack "Message Box" is (item 1 of tOrigin + 40) & comma & (item 2 of tOrigin + 50)
   lock messages
   if tMessage is not empty then
      delete stack tMessage
   else
      set the topLeft of stack "Message Box" to tOldMessage
   end if
   unlock messages
   _Close tStack
   _Close tPalette
   _Close tPlte
   _Close tPicture
end TestHyperCardScriptsT46

on TestHyperCardScriptsT47
   -- T47: a function called by a name that is one of this engine's
   -- commands compiles here and stops at the call, as no function: the
   -- library's stand-in for the external (replace, sort, find), or the
   -- stack's own function of that name, as T1 renamed it
   local tScript, tStack, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  put replace(" & q & ":" & q & ", " & q & "," & q & ", t) into t", \
         "  get sort(fld 1, " & q & "n" & q & ")", \
         "  put find(" & q & "x" & q & ", t) into tAt", \
         "  find (t) in field 1", \
         "  if t is empty then find (t)", \
         "  put filter(t) into t", \
         "end mouseUp") into tScript
   TestAssert "T47: replace(, sort( and find( called as functions: the library's stand-ins", \
         line 2 of tScript is "  put hcX_replace(" & q & ":" & q & ", " & q & "," & q & ", t) into t" \
         and line 3 of tScript is "  get hcX_sort(fld 1, " & q & "n" & q & ")" \
         and line 4 of tScript is "  put hcX_find(" & q & "x" & q & ", t) into tAt"
   TestAssert "T47: find as a statement is the command", line 5 of tScript is "  find (t) in field 1" and line 6 of tScript is "  if t is empty then find (t)"
   TestAssert "T47: a command's name the library stands in for no external of is left as it is", line 7 of tScript is "  put filter(t) into t"

   put _Rewrite("function replace pText, pOld, pNew", "  return pText & pOld & pNew", "end replace", \
         "on mouseUp", "  put replace(1, 2, 3) into x", "end mouseUp") into tScript
   TestAssert "T47: the stack's own function of that name, as T1 renamed it", \
         line 1 of tScript is "function hc_replace pText, pOld, pNew" and line 5 of tScript is "  put hc_replace(1, 2, 3) into x"
   put revHyperCardRewriteScript(_Lines("function replace pText", "  return pText", "end replace", \
         "on mouseUp", "  put replace(1) into x", "end mouseUp"), "Replace") into tScript
   TestAssert "T47 and T13: with an external of that name too, the call is the stack's own function's, as in HyperCard", \
         line 5 of tScript is "  put hc_replace(1) into x"

   -- in a stack, scripts that compile: the stack's own function, which
   -- does not compile and T1 renames, and the library's stand-in
   put "HCT47" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the script of stack tStack to _Lines("function sort pList", "  return " & q & "own" & q & " && pList", "end sort")
   set the defaultStack to tStack
   create button "Own"
   set the script of button "Own" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put sort(" & q & "b,a" & q & ") into gHCScriptsTest", "end mouseUp")
   create button "Library"
   set the script of button "Library" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put replace(" & q & "a" & q & ", " & q & "o" & q & ", " & q & "banana" & q & ") into gHCScriptsTest", "end mouseUp")
   unlock messages
   TestAssert "T47: the calls compile as they are", _Compiles(the script of button "Own" of stack tStack) and _Compiles(the script of button "Library" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Own" of stack tStack
   TestAssert "T47, in a script that compiles: the stack's own function, renamed", gHCScriptsTest is "own b,a"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Library" of stack tStack
   TestAssert "T47, in a script that compiles: the library's Replace", gHCScriptsTest is "bonono"
   _Close tStack
end TestHyperCardScriptsT47

on TestHyperCardScriptsT48
   -- T48: HyperCard's menus read as values, which here read the IDE's
   -- menu bar, or stop with "can't find background" where there is none:
   -- the library's menus, which T22's statements change, and which start
   -- as HyperCard 2.2's menu bar
   local tScript, tStack, q, e
   global gHCScriptsTest
   put quote into q
   put numToCodepoint(8230) into e
   put _Rewrite("on mouseUp", \
         "  put menu " & q & "Font" & q & " into tFonts", \
         "  if last menuItem of menu 3 is " & q & "-" & q & " then delete last menuItem of menu 3", \
         "  repeat with x = (the number of menuItems in menu " & q & "File" & q & ")-1 down to 6", \
         "  end repeat", \
         "  if there is not a menu " & q & "Art" & q & " then create menu " & q & "Art" & q, \
         "  if there is a menuItem tItem in menu tMenu then beep", \
         "  if the menus contains " & q & "Go" & q & " then delete menu " & q & "Go" & q, \
         "  put the number of menus into n", \
         "  if " & q & "File" & q & " = name of menu 2 and the enabled of menu 3 then beep", \
         "  if x is in menu 5 then put line 2 of menu 7 into y", \
         "  put the checkMark of menuItem (i + 1) of menu 3 into y", \
         "  if there is no menuItem item i of tFonts in menu " & q & "Font" & q & " then beep", \
         "end mouseUp") into tScript
   TestAssert "T48: menu M as a value", line 2 of tScript is "  put hcMenuText(" & q & "Font" & q & ") into tFonts"
   TestAssert "T48: last menuItem as a value, and T22's delete of it", \
         line 3 of tScript is "  if hcMenuItem(" & q & "name" & q & ", 3, " & q & "last" & q & ") is " & q & "-" & q & " then hcDeleteMenuItem 3, " & q & "last" & q
   TestAssert "T48: the number of menuItems in menu", line 4 of tScript is "  repeat with x = (hcMenuItemCount(" & q & "File" & q & "))-1 down to 6"
   TestAssert "T48: there is not a menu, and T22's create", line 6 of tScript is "  if not hcThereIsMenu(" & q & "Art" & q & ") then hcCreateMenu " & q & "Art" & q
   TestAssert "T48: there is a menuItem in menu", line 7 of tScript is "  if hcThereIsMenu(tMenu, tItem) then beep"
   TestAssert "T48: the menus, and T22's delete menu", line 8 of tScript is "  if hcMenus() contains " & q & "Go" & q & " then hcDeleteMenu " & q & "Go" & q
   TestAssert "T48: the number of menus", line 9 of tScript is "  put hcMenuCount() into n"
   TestAssert "T48: a menu's name and enabled", \
         line 10 of tScript is "  if " & q & "File" & q & " = hcMenuItem(" & q & "name" & q & ", 2, empty) and hcMenuItem(" & q & "enabled" & q & ", 3, empty) then beep"
   TestAssert "T48: a menu in an expression, and a chunk of one", line 11 of tScript is "  if x is in hcMenuText(5) then put line 2 of hcMenuText(7) into y"
   TestAssert "T48: a menu item's property, the item in parentheses", line 12 of tScript is "  put hcMenuItem(" & q & "checkmark" & q & ", 3, (i + 1)) into y"
   TestAssert "T48: a menu item named by several words", line 13 of tScript is "  if not hcThereIsMenu(" & q & "Font" & q & ", item i of tFonts) then beep"

   -- what a statement changes stays T22's
   put _Rewrite("on mouseUp", \
         "  put (" & q & "About" & q & " && tName) into menuItem 1 of menu 1", \
         "  put " & q & "Duplicate" & q & " after menuItem 5 of menu " & q & "Edit" & q, \
         "  set the enabled of menu " & q & "Map" & q & " to false", \
         "  set the checkMark of menuItem (i + 1) of menu 3 to true", \
         "  delete menuItem " & q & "Cut" & q & " from menu " & q & "Edit" & q, \
         "  put menu 2 into menu " & q & "Copy" & q, \
         "  put the short name of menu 2 into x", \
         "end mouseUp") into tScript
   TestAssert "T22: put into a menuItem, what is put in parentheses", line 2 of tScript is "  hcPutIntoMenu (" & q & "About" & q & " && tName), " & q & "into" & q & ", 1, empty, 1"
   TestAssert "T22: put after a menuItem", line 3 of tScript is "  hcPutIntoMenu " & q & "Duplicate" & q & ", " & q & "after" & q & ", " & q & "Edit" & q & ", empty, 5"
   TestAssert "T22: set the enabled of a menu, not read", line 4 of tScript is "  hcSetMenuItem " & q & "enabled" & q & ", " & q & "Map" & q & ", empty, false"
   TestAssert "T22: set a property of a menu item in parentheses, not read", line 5 of tScript is "  hcSetMenuItem " & q & "checkmark" & q & ", 3, (i + 1), true"
   TestAssert "T22: delete menuItem from menu", line 6 of tScript is "  hcDeleteMenuItem " & q & "Edit" & q & ", " & q & "Cut" & q
   TestAssert "T48 and T22: a menu read, put into another", line 7 of tScript is "  hcPutIntoMenu hcMenuText(2), " & q & "into" & q & ", " & q & "Copy" & q & ", empty, empty"
   TestAssert "T48: a form HyperCard did not have, left as it is", line 8 of tScript is "  put the short name of menu 2 into x"

   -- a statement continued over lines: on its first line, the others left
   -- empty, unless the next line starts with the "then" of its "if",
   -- which must follow it: then it goes on with \ as it did
   put _Rewrite("on mouseEnter", \
         "  if the checkMark of menuItem 4 of menu 5 is true \", \
         "      and x = 1 \", \
         "      and y = 2 -- both set", \
         "  then beep", \
         "  put menu 1 \", \
         "      into x", \
         "  beep", \
         "end mouseEnter") into tScript
   TestAssert "T48: a continued if, its then on the next line, goes on with \", \
         line 2 of tScript is "  if hcMenuItem(" & q & "checkmark" & q & ", 5, 4) is true  and x = 1  and y = 2 \" \
         and line 3 of tScript is "\" and line 4 of tScript is "-- both set" and line 5 of tScript is "  then beep"
   TestAssert "T48: a continued put on one line, the line count kept", \
         line 6 of tScript is "  put hcMenuText(1)  into x" and line 7 of tScript is empty and line 8 of tScript is "  beep"
   TestAssert "T48: the continued if compiles", _Compiles(tScript)

   -- "the" before a menu item's place, in a value and in T22's statements
   put _Rewrite("on mouseUp", \
         "  set the name of the last menuItem of menu gHMnu to tName", \
         "  put the enabled of the second menuItem of menu " & q & "File" & q & " into x", \
         "  disable the last menuItem of menu 3", \
         "end mouseUp") into tScript
   TestAssert "T22: set a property of the last menuItem", line 2 of tScript is "  hcSetMenuItem " & q & "name" & q & ", gHMnu, " & q & "last" & q & ", tName"
   TestAssert "T48: a property of the second menuItem", \
         line 3 of tScript is "  put hcMenuItem(" & q & "enabled" & q & ", " & q & "File" & q & ", " & q & "second" & q & ") into x"
   TestAssert "T22: disable the last menuItem", line 4 of tScript is "  hcEnableMenu false, 3, " & q & "last" & q

   -- in a stack: the reads compile as they are, and read the library's
   -- menus, which start as HyperCard 2.2's
   put "HCT48" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Read"
   set the script of button "Read" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  get the number of menus", \
         "  put it into gHCScriptsTest", \
         "  put comma & line 1 of the menus & comma & line 8 of the menus after gHCScriptsTest", \
         "  put comma & the number of menuItems of menu " & q & "File" & q & " & comma & menuItem 2 of menu " & q & "File" & q & " & comma & last menuItem of menu 2 after gHCScriptsTest", \
         "  put comma & (there is a menu " & q & "Art" & q & ") & comma & (there is a menuItem " & q & "Find..." & q & " of menu " & q & "Go" & q & ") & comma & (there is not a menuItem " & q & "Nope" & q & " in menu 4) after gHCScriptsTest", \
         "  put comma & (the fontNames is empty or line 1 of menu " & q & "Font" & q & " is among the lines of the fontNames) & comma & (menu 7 is menu " & q & "Font" & q & ") after gHCScriptsTest", \
         "  put comma & the name of menu 3 & comma & the enabled of menu " & q & "Edit" & q & " after gHCScriptsTest", \
         "end mouseUp")
   create button "Change"
   set the script of button "Change" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  create menu " & q & "Art" & q, \
         "  put " & q & "One,Two" & q & " into menu " & q & "Art" & q, \
         "  put (there is a menu " & q & "Art" & q & ") & comma & the number of menus & comma & (menu " & q & "Art" & q & " is " & q & "One" & q & " & return & " & q & "Two" & q & ") into gHCScriptsTest", \
         "  set the name of menu " & q & "Art" & q & " to " & q & "Pictures" & q, \
         "  put comma & (there is a menu " & q & "Pictures" & q & ") & comma & (there is a menu " & q & "Art" & q & ") & comma & line 9 of the menus & comma & menuItem 2 of menu " & q & "Pictures" & q & " after gHCScriptsTest", \
         "  put " & q & "Duplicate" & q & " after menuItem 5 of menu " & q & "Edit" & q, \
         "  put comma & menuItem 6 of menu " & q & "Edit" & q & " & comma & menuItem 7 of menu " & q & "Edit" & q & " after gHCScriptsTest", \
         "  disable menu " & q & "Edit" & q, \
         "  put comma & the enabled of menu 3 after gHCScriptsTest", \
         "  delete menu 2", \
         "  put comma & the name of menu 2 after gHCScriptsTest", \
         "  reset menubar", \
         "  put comma & the number of menus & comma & (there is a menu " & q & "Pictures" & q & ") & comma & the number of menuItems of menu " & q & "Edit" & q & " after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T48: the reads compile as they are", _Compiles(the script of button "Read" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Read" of stack tStack
   TestAssert "T48: HyperCard 2.2's menus and their items, menu 7 the Font menu", \
         gHCScriptsTest is "8,Apple,Style,16,Open Stack" & e & ",Quit HyperCard,false,true,true,true,true,Edit,true"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Change" of stack tStack
   TestAssert "T48: what T22's statements change reads back; reset menubar puts HyperCard's menus back", \
         gHCScriptsTest is "true,9,true,true,false,Pictures,Two,Duplicate,Clear,false,Edit,8,false,16"
   _Close tStack
end TestHyperCardScriptsT48

on TestHyperCardScriptsT49
   -- T49: play with a sound named in a field or a button of the card or
   -- the background, whose text HyperCard played. This engine reads the
   -- "card" as a player's ("play card player "Movie"") and looks for the
   -- field without it, in a stack from HyperCard one of the background:
   -- the field in parentheses, its text (Merz Poetry, Sound Studio)
   local tScript, tStack, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  play cd fld " & q & "music box" & q, \
         "  put " & q & "c" & q & " into thisNote", \
         "  play card field sound tempo card field speed thisnote", \
         "  play card field sound thisNote", \
         "  play bg fld 1 c d e", \
         "  play bkgnd btn id 7 tempo 120", \
         "  if x then play cd fld 2 else play bg fld (n + 1)", \
         "  play cd fld help", \
         "  play flute tempo card field speed c d", \
         "end mouseUp") into tScript
   TestAssert "T49: a card field named in quotes", line 2 of tScript is "  play (cd fld " & q & "music box" & q & ")"
   TestAssert "T49: with a tempo in a card field and the notes in a variable", \
         line 4 of tScript is "  play (card field " & q & "sound" & q & ") tempo card field speed thisnote"
   TestAssert "T49: with the notes in a variable", line 5 of tScript is "  play (card field " & q & "sound" & q & ") thisNote"
   TestAssert "T49 and T35: a background field, the notes not in quotes", line 6 of tScript is "  play (bg fld 1) " & q & "c d e" & q
   TestAssert "T49: a button by its id, with a tempo", line 7 of tScript is "  play (bkgnd btn id 7) tempo 120"
   TestAssert "T49: after then and after else, a name in parentheses", \
         line 8 of tScript is "  if x then play (cd fld 2) else play (bg fld (n + 1))"
   TestAssert "T49 and T44: a name that is a constant here", line 9 of tScript is "  play (cd fld " & q & "help" & q & ")"
   TestAssert "T35: a tempo in a card field, the notes not in quotes", line 10 of tScript is "  play flute tempo card field speed " & q & "c d" & q
   TestAssert "T49: the script compiles", _Compiles(tScript)

   -- unchanged: a field of another card, a field with neither card nor
   -- background (here as in HyperCard, one of the background), a name
   -- with "the", a function's value as the name, a tempo in a field of
   -- neither, which T35 leaves as it is
   put _Rewrite("on mouseUp", \
         "  play card field 1 of card 2", \
         "  play field " & q & "x" & q, \
         "  play the short name of bg btn 1", \
         "  play card field f(1)", \
         "  play flute tempo field 2 c d", \
         "end mouseUp") into tScript
   TestAssert "T49: a field of another card: unchanged", line 2 of tScript is "  play card field 1 of card 2"
   TestAssert "T49: a field with neither card nor background: unchanged", line 3 of tScript is "  play field " & q & "x" & q
   TestAssert "T49: a name with the: unchanged", line 4 of tScript is "  play the short name of bg btn 1"
   TestAssert "T49: a function's value as the name: unchanged", line 5 of tScript is "  play card field f(1)"
   TestAssert "T35: a tempo in a field of neither: unchanged", line 6 of tScript is "  play flute tempo field 2 c d"

   -- in a script that compiles, in a stack from HyperCard: the card's
   -- field, where this engine looked for one of the background and
   -- stopped with "no such object"
   put "HCScriptsT49" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the HCAddressing of stack tStack to true
   set the defaultStack to tStack
   create field "Sound"
   put "HCScriptsNoSuchSound" into card field "Sound" of card 1 of stack tStack
   create button "Play"
   set the script of button "Play" to _Lines("on mouseUp", "  global gHCScriptsTest", "  try", \
         "    play cd fld " & q & "Sound" & q, \
         "    put " & q & "played" & q & " into gHCScriptsTest", \
         "  catch tError", \
         "    put " & q & "error" & q && "&& item 1 of tError into gHCScriptsTest", \
         "  end try", \
         "  play stop", "end mouseUp")
   unlock messages
   TestAssert "T49: the script compiles here as it is", _Compiles(the script of button "Play" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T49: in a script that compiles", line 4 of the script of button "Play" of card 1 of stack tStack is "    play (cd fld " & q & "Sound" & q & ")"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Play" of card 1 of stack tStack
   TestAssert "T49: the card's field found, as in HyperCard", gHCScriptsTest is "played"
   _Close tStack
end TestHyperCardScriptsT49

on TestHyperCardScriptsT50
   -- T50: a property of an object named by a chunk of a variable or of a
   -- function's value, which HyperCard took as the object the chunk's
   -- text names ("card field 1,card field 2"). This engine takes the
   -- object the whole text names, with the chunk as text of it, and stops
   -- with an error: the chunk in parentheses (Power Tools' buttons that
   -- scroll several fields together, in 15 stacks)
   local tScript, tStack, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseDown", \
         "  put the textHeight of item 1 of fieldList into baseLineSize", \
         "  get (scroll of last item of theFields()) - baseLineSize", \
         "  set scroll of item count of fieldList to it", \
         "  if verticalSort then get top of item i of objectList", \
         "  edit the script of item 1 of it", \
         "  put the short name of item 2 of line 1 of tObjects into x", \
         "end mouseDown") into tScript
   TestAssert "T50: the textHeight of an item of a variable", line 2 of tScript is "  put the textHeight of (item 1 of fieldList) into baseLineSize"
   TestAssert "T50: without the, the last item of a function's value", \
         line 3 of tScript is "  get (scroll of (last item of theFields())) - baseLineSize"
   TestAssert "T50: set, the item numbered by a variable", line 4 of tScript is "  set scroll of (item count of fieldList) to it"
   TestAssert "T50: after then", line 5 of tScript is "  if verticalSort then get top of (item i of objectList)"
   TestAssert "T50: of it", line 6 of tScript is "  edit the script of (item 1 of it)"
   TestAssert "T50: the short name, a chunk of a chunk", line 7 of tScript is "  put the short name of (item 2 of line 1 of tObjects) into x"
   TestAssert "T50: the script compiles", _Compiles(tScript)

   -- unchanged: a chunk of an object, a property of text, a count, a
   -- range, a property's name as a chunk's number, a function
   put _Rewrite("on mouseDown", \
         "  put the textHeight of line 1 of me into x", \
         "  put the textStyle of word 2 of tField into x", \
         "  put the number of items of fieldList into n", \
         "  put the scroll of item 1 to 2 of fieldList into x", \
         "  put item family of line 2 of tList into x", \
         "  put the length of item 1 of fieldList into n", \
         "  put the textHeight of item 1 of card field 2 into x", \
         "end mouseDown") into tScript
   TestAssert "T50: a chunk of an object: unchanged", line 2 of tScript is "  put the textHeight of line 1 of me into x"
   TestAssert "T50: a property of text: unchanged", line 3 of tScript is "  put the textStyle of word 2 of tField into x"
   TestAssert "T50: a count: unchanged", line 4 of tScript is "  put the number of items of fieldList into n"
   TestAssert "T50: a range: unchanged", line 5 of tScript is "  put the scroll of item 1 to 2 of fieldList into x"
   TestAssert "T50: a property's name as a chunk's number: unchanged", line 6 of tScript is "  put item family of line 2 of tList into x"
   TestAssert "T50: a function: unchanged", line 7 of tScript is "  put the length of item 1 of fieldList into n"
   TestAssert "T50: a chunk of a field: unchanged", line 8 of tScript is "  put the textHeight of item 1 of card field 2 into x"

   -- in a script that compiles: the objects the items name, where this
   -- engine stopped with "error in object expression"
   put "HCScriptsT50" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create field "A"
   set the textHeight of field "A" to 17
   create field "B"
   create button "Scroll"
   set the script of button "Scroll" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put theFields() into fieldList", \
         "  put the textHeight of item 1 of fieldList into gHCScriptsTest", \
         "  put comma & the short name of last item of theFields() after gHCScriptsTest", \
         "end mouseUp", \
         "function theFields", \
         "  return " & q & "card field 1,card field 2" & q, \
         "end theFields")
   unlock messages
   TestAssert "T50: the script compiles here as it is", _Compiles(the script of button "Scroll" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T50: in a script that compiles", line 4 to 5 of the script of button "Scroll" of card 1 of stack tStack \
         is _Lines("  put the textHeight of (item 1 of fieldList) into gHCScriptsTest", \
         "  put comma & the short name of (last item of theFields()) after gHCScriptsTest")
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Scroll" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T50: the fields the items name, as in HyperCard", gHCScriptsTest is "17,B"
   _Close tStack
end TestHyperCardScriptsT50

on TestHyperCardScriptsT51
   -- T51: a textFont set to a font named in several words not in quotes,
   -- which HyperCard took as the text it was. This engine sets the font
   -- to the first word and runs the rest as a command it cannot find:
   -- the name in quotes (9 stacks)
   local tScript, tStack, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  set the textfont to New York", \
         "  set textfont of me to new century schlbk", \
         "  set textfont of cd btn " & q & "Cancel" & q & " to chicago gray", \
         "  if tDim then set the textfont of the target to New Chicago", \
         "  set the textFont of char 1 to 3 of fld 1 to Cooper Black", \
         "end mouseUp") into tScript
   TestAssert "T51: the textFont, the paint text's (T53)", line 2 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", " & q & "New York" & q
   TestAssert "T51: of me, three words", line 3 of tScript is "  set textfont of me to " & q & "new century schlbk" & q
   TestAssert "T51: of a button", line 4 of tScript is "  set textfont of cd btn " & q & "Cancel" & q & " to " & q & "chicago gray" & q
   TestAssert "T51: after then", line 5 of tScript is "  if tDim then set the textfont of the target to " & q & "New Chicago" & q
   TestAssert "T51: the value after the last to, of a chunk's range", line 6 of tScript is "  set the textFont of char 1 to 3 of fld 1 to " & q & "Cooper Black" & q
   TestAssert "T51: the script compiles", _Compiles(tScript)

   -- unchanged: a chunk, a property, an expression; with no object, an
   -- object, an expression, one word and it are the paint text's (T53)
   put _Rewrite("on mouseUp", \
         "  set textFont to bg field FontName", \
         "  set textfont of fld 1 to line Keuze of fonts", \
         "  set textFont to any item of pictureFonts", \
         "  set the textFont of cd fld 2 to the textFont of fld 1", \
         "  set the textFont to Geneva", \
         "  set the textFont of me to tFont & tStyle", \
         "  set the textFont to it", \
         "end mouseUp") into tScript
   TestAssert "T51: an object, the paint text's (T53)", line 2 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", bg field FontName"
   TestAssert "T51: a chunk: unchanged", line 3 of tScript is "  set textfont of fld 1 to line Keuze of fonts"
   TestAssert "T51: any item, the paint text's (T53)", line 4 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", any item of pictureFonts"
   TestAssert "T51: a property: unchanged", line 5 of tScript is "  set the textFont of cd fld 2 to the textFont of fld 1"
   TestAssert "T51: one word, the paint text's (T53)", line 6 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", Geneva"
   TestAssert "T51: an expression: unchanged", line 7 of tScript is "  set the textFont of me to tFont & tStyle"
   TestAssert "T51: it, the paint text's (T53)", line 8 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", it"

   -- in a script that compiles: the font's whole name, where this engine
   -- stopped with "can't find handler" at its second word
   put "HCScriptsT51" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Font"
   set the script of button "Font" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  set the textFont to New York", \
         "  set the textFont of me to New Century Schlbk", \
         "  put the textFont of me into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T51: the script compiles here as it is", _Compiles(the script of button "Font" of card 1 of stack tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Font" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T51: as it is, it stops before the font is set", gHCScriptsTest is empty
   get revHyperCardFixScripts(tStack)
   TestAssert "T51: in a script that compiles", line 3 to 4 of the script of button "Font" of card 1 of stack tStack \
         is _Lines("  hcSetPaintText " & q & "textFont" & q & ", " & q & "New York" & q, \
         "  set the textFont of me to " & q & "New Century Schlbk" & q)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Font" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T51: the font's whole name, as in HyperCard", gHCScriptsTest is "New Century Schlbk"
   _Close tStack
end TestHyperCardScriptsT51

on TestHyperCardScriptsT52
   -- T52: the showPict of a card or a background, which this engine reads
   -- as true and sets to nothing, and the picture of a card or a
   -- background named, which stops with an error here: the library's
   -- hcShowPict and hcShowPicture (34 stacks read or set the showPict, 7
   -- show or hide the picture of a card they name)
   local tScript, tStack, q, tBgImage, tCardImage
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  if the showPict of this cd is true then hide pict of this cd", \
         "  else show pict of this cd", \
         "  put the showPict of this bg into PictShown", \
         "  set the showPict of this card to not boolean", \
         "  set showpict of card id 2946 to false", \
         "  set the showPict of card " & q & "Keywords" & q & " to not(the showPict of card " & q & "Keywords" & q & ")", \
         "  if showpict of this cd then nextOnThisCd", \
         "  hide picture of prev card", \
         "  show picture of bg 2", \
         "end mouseUp") into tScript
   TestAssert "T52: read, and the picture of this card hidden", line 2 of tScript is "  if hcShowPict(" & q & "card" & q & ", the long id of this cd) is true then hcShowPicture " & q & "card" & q & ", false, the long id of this cd"
   TestAssert "T52: shown after else", line 3 of tScript is "  else hcShowPicture " & q & "card" & q & ", true, the long id of this cd"
   TestAssert "T52: of a background", line 4 of tScript is "  put hcShowPict(" & q & "background" & q & ", the long id of this bg) into PictShown"
   TestAssert "T52: set", line 5 of tScript is "  hcShowPicture " & q & "card" & q & ", not boolean, the long id of this card"
   TestAssert "T52: set without the, a card by id", line 6 of tScript is "  hcShowPicture " & q & "card" & q & ", false, the long id of card id 2946"
   TestAssert "T52: set to its own read", line 7 of tScript is "  hcShowPicture " & q & "card" & q & ", not(hcShowPict(" & q & "card" & q & ", the long id of card " & q & "Keywords" & q & ")), the long id of card " & q & "Keywords" & q
   TestAssert "T52: read without the", line 8 of tScript is "  if hcShowPict(" & q & "card" & q & ", the long id of this cd) then nextOnThisCd"
   TestAssert "T52: the picture of the previous card", line 9 of tScript is "  hcShowPicture " & q & "card" & q & ", false, the long id of prev card"
   TestAssert "T52: the picture of a background", line 10 of tScript is "  hcShowPicture " & q & "background" & q & ", true, the long id of bg 2"
   TestAssert "T52: the script compiles", _Compiles(tScript)

   -- unchanged: a handler of that name, a card of another stack, text
   put _Rewrite("on mouseUp", \
         "  showPict", \
         "  put the showPict of card 1 of stack " & q & "Other" & q & " into x", \
         "  put " & q & "the showPict of this cd" & q & " into x", \
         "end mouseUp", \
         "on showPict", \
         "  beep", \
         "end showPict") into tScript
   TestAssert "T52: a handler's call: unchanged", line 2 of tScript is "  showPict"
   TestAssert "T52: a card of another stack: unchanged", line 3 of tScript is "  put the showPict of card 1 of stack " & q & "Other" & q & " into x"
   TestAssert "T52: text: unchanged", line 4 of tScript is "  put " & q & "the showPict of this cd" & q & " into x"
   TestAssert "T52: a handler: unchanged", line 6 of tScript is "on showPict"

   -- run: a card's picture (an image with no name) and its background's,
   -- read, hidden and shown as the script says
   put "HCScriptsT52" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create group "Bg"
   set the backgroundBehavior of group "Bg" to true
   create image in group "Bg"
   put it into tBgImage
   create image
   put it into tCardImage
   create button "Pict"
   set the script of button "Pict" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the showPict of this card & comma & the showPict of this bg into gHCScriptsTest", \
         "  hide pict of this cd", \
         "  hide bg pict", \
         "  put comma & the showPict of this card & comma & the showPict of this bg after gHCScriptsTest", \
         "  set the showPict of this card to true", \
         "  put comma & showpict of this cd after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Pict" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T52: as it is, the picture is always shown and hiding it stops", gHCScriptsTest is "true,true"
   get revHyperCardFixScripts(tStack)
   TestAssert "T52: in a script that compiles", _Compiles(the script of button "Pict" of card 1 of stack tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Pict" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T52: read, hidden, read, shown, as in HyperCard", gHCScriptsTest is "true,true,false,false,true"
   TestAssert "T52: the card's picture shown at the end, the background's hidden", \
         the visible of tCardImage and not the visible of tBgImage
   _Close tStack
end TestHyperCardScriptsT52

on TestHyperCardScriptsT53
   -- T53: the textFont, the textSize, the textHeight, the textStyle and
   -- the textAlign set and read with no object, HyperCard's for the text
   -- its text tool painted. This engine reads them as empty, stops at a
   -- script that sets the textStyle or the textAlign (274 statements in
   -- 37 corpus stacks) and does not compile one read before div ("the
   -- textHeight div 2", Graph Maker's) or the textStyle before any
   -- operator: the library's hcSetPaintText, which keeps what a script
   -- set, hcPaintText, which reads it back or HyperCard's default, and
   -- hcResetPaint for reset paint (21 corpus stacks read them)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  set textstyle to plain", \
         "  set the textAlign to " & q & "right" & q, \
         "  set the textStyle to bold,italic", \
         "  if tCount > 10 then set textstyle to plain else set textstyle to bold", \
         "  set textStyle to any item of theTextStyle", \
         "end mouseUp") into tScript
   TestAssert "T53: the textStyle", line 2 of tScript is "  hcSetPaintText " & q & "textStyle" & q & ", plain"
   TestAssert "T53: the textAlign, with the", line 3 of tScript is "  hcSetPaintText " & q & "textAlign" & q & ", " & q & "right" & q
   TestAssert "T53: a list of styles", line 4 of tScript is "  hcSetPaintText " & q & "textStyle" & q & ", bold,italic"
   TestAssert "T53: after then and after else", line 5 of tScript \
         is "  if tCount > 10 then hcSetPaintText " & q & "textStyle" & q & ", plain else hcSetPaintText " & q & "textStyle" & q & ", bold"
   TestAssert "T53: an expression", line 6 of tScript is "  hcSetPaintText " & q & "textStyle" & q & ", any item of theTextStyle"
   TestAssert "T53: the script compiles", _Compiles(tScript)

   -- the textSize, the textHeight and the textFont, which this engine
   -- sets so to nothing; a font named in several words not in quotes as
   -- the text it is (T51)
   put _Rewrite("on mouseUp", \
         "  set the textSize to 12", \
         "  set textHeight to 18", \
         "  set the textFont to New York", \
         "  set textfont to tFont", \
         "end mouseUp") into tScript
   TestAssert "T53: the textSize", line 2 of tScript is "  hcSetPaintText " & q & "textSize" & q & ", 12"
   TestAssert "T53: the textHeight, without the", line 3 of tScript is "  hcSetPaintText " & q & "textHeight" & q & ", 18"
   TestAssert "T53: the textFont, several words", line 4 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", " & q & "New York" & q
   TestAssert "T53: the textFont, a variable", line 5 of tScript is "  hcSetPaintText " & q & "textFont" & q & ", tFont"

   -- read (Graph Maker's "the textHeight div 2", Stack Starter's "the
   -- textStyle is "Plain""), set to its own read, and reset paint
   put _Rewrite("on mouseUp", \
         "  put the textHeight div 2 into h", \
         "  if the textStyle is " & q & "Plain" & q & " then beep", \
         "  put the textFont & comma & the TEXTSIZE into x", \
         "  set the textSize to the textSize + 2", \
         "  set the textSize of fld 1 to the textSize", \
         "  reset paint", \
         "  if x then reset paint else beep", \
         "end mouseUp") into tScript
   TestAssert "T53: a read before div", line 2 of tScript is "  put hcPaintText(" & q & "textHeight" & q & ") div 2 into h"
   TestAssert "T53: a read before is", line 3 of tScript is "  if hcPaintText(" & q & "textStyle" & q & ") is " & q & "Plain" & q & " then beep"
   TestAssert "T53: two reads, in any case", line 4 of tScript \
         is "  put hcPaintText(" & q & "textFont" & q & ") & comma & hcPaintText(" & q & "textSize" & q & ") into x"
   TestAssert "T53: set to its own read", line 5 of tScript is "  hcSetPaintText " & q & "textSize" & q & ", hcPaintText(" & q & "textSize" & q & ") + 2"
   TestAssert "T53: a field's set to the paint text's", line 6 of tScript is "  set the textSize of fld 1 to hcPaintText(" & q & "textSize" & q & ")"
   TestAssert "T53: reset paint", line 7 of tScript is "  hcResetPaint"
   TestAssert "T53: reset paint after then", line 8 of tScript is "  if x then hcResetPaint else beep"
   TestAssert "T53: the reads compile", _Compiles(tScript)

   -- unchanged: the style of an object or a chunk, set or read, the
   -- textHeight of a field; and reset printing is no reset of the paint
   -- text (T72's, the print text's)
   put _Rewrite("on mouseUp", \
         "  set the textStyle of fld 1 to bold", \
         "  set the textAlign of cd btn 2 to center", \
         "  set textStyle of word 1 of fld 1 to italic", \
         "  get the textStyle of word 1 of fld 1", \
         "  put the textHeight of fld 2 into h", \
         "  reset printing", \
         "end mouseUp") into tScript
   TestAssert "T53: of a field: unchanged", line 2 of tScript is "  set the textStyle of fld 1 to bold"
   TestAssert "T53: of a button: unchanged", line 3 of tScript is "  set the textAlign of cd btn 2 to center"
   TestAssert "T53: of a chunk: unchanged", line 4 of tScript is "  set textStyle of word 1 of fld 1 to italic"
   TestAssert "T53: a chunk's read: unchanged", line 5 of tScript is "  get the textStyle of word 1 of fld 1"
   TestAssert "T53: a field's read: unchanged", line 6 of tScript is "  put the textHeight of fld 2 into h"
   TestAssert "T53: reset printing: not the paint text's", line 7 of tScript is "  hcResetPrinting"

   -- in a script that compiles: it goes on past the sets, where this
   -- engine stopped at the first, and reads back what a script set, or
   -- HyperCard's defaults (its reference's: Geneva, 12, a textHeight of
   -- the textSize and a third of it, plain, left); a list of styles in
   -- HyperCard's order; and it goes on past reset paint, which here,
   -- with no revIcons, stops at the brushes' images it cannot find
   put "HCScriptsT53" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Paint"
   set the script of button "Paint" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put 1 into gHCScriptsTest", \
         "  set the textStyle to bold", \
         "  set the textAlign to center", \
         "  put 2 into gHCScriptsTest", \
         "end mouseUp")
   create button "Read"
   set the script of button "Read" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the textFont & comma & the textSize & comma & the textHeight & comma & the textStyle & comma & the textAlign into gHCScriptsTest", \
         "  set the textSize to 9", \
         "  set the textFont to New York", \
         "  put return & the textFont & comma & the textSize & comma & the textHeight after gHCScriptsTest", \
         "  set textStyle to italic, Bold", \
         "  set the textAlign to Right", \
         "  set the textHeight to 14", \
         "  put return & the textStyle & comma & the textAlign & comma & the textHeight after gHCScriptsTest", \
         "  reset paint", \
         "  put return & the textFont & comma & the textSize & comma & the textHeight & comma & the textStyle & comma & the textAlign after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Paint" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T53: as it is, it stops at the textStyle", gHCScriptsTest is 1
   TestAssert "T53: as it is, the reads do not compile", not _Compiles(the script of button "Read" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T53: in a script that compiles", _Compiles(the script of button "Paint" of card 1 of stack tStack)
   TestAssert "T53: the reads in a script that compiles", _Compiles(the script of button "Read" of card 1 of stack tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Read" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T53: HyperCard's defaults, as reset paint leaves them", line 1 of gHCScriptsTest is "Geneva,12,16,plain,left"
   TestAssert "T53: the font and the size a script set, the height that follows the size", line 2 of gHCScriptsTest is "New York,9,12"
   TestAssert "T53: the styles in HyperCard's order, the alignment, the height a script set", line 3 of gHCScriptsTest is "bold,italic,right,14"
   TestAssert "T53: reset paint, to HyperCard's defaults", line 4 of gHCScriptsTest is "Geneva,12,16,plain,left"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Paint" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T53: it goes on, as in HyperCard", gHCScriptsTest is 2
   _Close tStack
end TestHyperCardScriptsT53

on TestHyperCardScriptsT54
   -- T54: the cards of a background sorted, which this engine refuses
   -- ("sort: error sorting"), and sort this stack, which here is "sort
   -- cards": the background's cards sorted among the places they had,
   -- by the script's own expression, after "then" or "else" in a do (88
   -- statements in 43 corpus stacks)
   local tScript, tStack, q, tError
   global gHCScriptsTest, gHCScriptsCards
   put quote into q
   put _Rewrite("on mouseUp", \
         "  sort cards of this bg by bg field " & q & "Name" & q, \
         "  sort bkgnd " & q & "Tape Database" & q & " numeric by line 1 of field fieldName", \
         "  Sort this background descending by field " & q & "Name" & q, \
         "  sort marked cards of bkgnd 2 by fld 1", \
         "  sort this stack descending text by short name of this card", \
         "  sort stack by field FontNameSize", \
         "end mouseUp") into tScript
   TestAssert "T54: the cards of this background", line 2 of tScript \
         is "  hcSortBegin the long id of this bg, false; sort marked cards by bg field " & q & "Name" & q & "; hcSortEnd"
   TestAssert "T54: a background by name, numeric", line 3 of tScript \
         is "  hcSortBegin the long id of bkgnd " & q & "Tape Database" & q & ", false; sort marked cards numeric by line 1 of field fieldName; hcSortEnd"
   TestAssert "T54: this background, descending", line 4 of tScript \
         is "  hcSortBegin the long id of this background, false; sort marked cards descending by field " & q & "Name" & q & "; hcSortEnd"
   TestAssert "T54: the marked cards of a background by number", line 5 of tScript \
         is "  hcSortBegin the long id of bkgnd 2, true; sort marked cards by fld 1; hcSortEnd"
   TestAssert "T54: this stack", line 6 of tScript is "  sort cards descending text by short name of this card"
   TestAssert "T54: stack", line 7 of tScript is "  sort cards by field FontNameSize"
   TestAssert "T54: the script compiles", _Compiles(tScript)

   -- after then or else, or before an else, where one statement goes: a
   -- do of the three, which runs them in the handler (Software
   -- Librarian's, Book Reporter's Guild's)
   put _Rewrite("on mouseUp", \
         "  if x then sort this bg by fld 1", \
         "  else sort cards of bkgnd " & q & "A" & q & " by bg field " & q & "Name" & q, \
         "  if y then sort this bg by fld 1 else beep", \
         "end mouseUp") into tScript
   TestAssert "T54: after then, a do", line 2 of tScript \
         is "  if x then do " & q & "hcSortBegin the long id of this bg, false; sort marked cards by fld 1; hcSortEnd" & q
   TestAssert "T54: after else, a do with the quotes of the statement", line 3 of tScript \
         is "  else do " & q & "hcSortBegin the long id of bkgnd " & q & " & quote & " & q & "A" & q & " & quote & " & q \
         & ", false; sort marked cards by bg field " & q & " & quote & " & q & "Name" & q & " & quote & " & q & "; hcSortEnd" & q
   TestAssert "T54: before an else, a do", line 4 of tScript \
         is "  if y then do " & q & "hcSortBegin the long id of this bg, false; sort marked cards by fld 1; hcSortEnd" & q & " else beep"
   TestAssert "T54: the script with the dos compiles", _Compiles(tScript)

   -- unchanged: a field's lines, this engine's own sorts, a background
   -- of another stack
   put _Rewrite("on mouseUp", \
         "  sort bg fld " & q & "gobg" & q, \
         "  sort cards by fld 1", \
         "  sort marked cards descending by fld 1", \
         "  sort lines of fld 1 descending", \
         "  sort cards of bkgnd 1 of stack " & q & "Other" & q & " by fld 1", \
         "end mouseUp") into tScript
   TestAssert "T54: a background field's lines: unchanged", line 2 of tScript is "  sort bg fld " & q & "gobg" & q
   TestAssert "T54: sort cards: unchanged", line 3 of tScript is "  sort cards by fld 1"
   TestAssert "T54: sort marked cards: unchanged", line 4 of tScript is "  sort marked cards descending by fld 1"
   TestAssert "T54: sort lines: unchanged", line 5 of tScript is "  sort lines of fld 1 descending"
   TestAssert "T54: another stack's background: unchanged", line 6 of tScript is "  sort cards of bkgnd 1 of stack " & q & "Other" & q & " by fld 1"

   -- in a script that compiles: five cards, of backgrounds A and B in
   -- turn, the A cards sorted by a field of theirs named in a variable,
   -- into the places they had; the B cards and the marks left as they
   -- were. Sorted from the fourth card: A2 and A3, whose keys are equal,
   -- keep the stack's order all the same, and as this engine's sort, it
   -- ends on the first card, with closeCard and openCard to those two
   -- cards only
   put "HCScriptsT54" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the name of card 1 of stack tStack to "A1"
   create card "B1"
   create card "A2"
   create card "B2"
   create card "A3"
   go to card "A1"
   create group "A"
   set the backgroundBehavior of group "A" to true
   create field "Key" in group "A"
   place group "A" onto card "A2"
   place group "A" onto card "A3"
   go to card "B1"
   create group "B"
   set the backgroundBehavior of group "B" to true
   place group "B" onto card "B2"
   put "c" into field "Key" of card "A1"
   put "a" into field "Key" of card "A2"
   put "a" into field "Key" of card "A3"
   set the mark of card "B1" to true
   set the script of stack tStack to _Lines("on openCard", "  global gHCScriptsCards", \
         "  put " & q & "open" & q & " && the short name of the target & comma after gHCScriptsCards", "end openCard", \
         "on closeCard", "  global gHCScriptsCards", \
         "  put " & q & "close" & q & " && the short name of the target & comma after gHCScriptsCards", "end closeCard")
   create button "Sort" in group "B"
   set the script of button "Sort" of card "B1" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  local tField, tNames, i", \
         "  put " & q & "Key" & q & " into tField", \
         "  put empty into gHCScriptsTest", \
         "  sort cards of bkgnd " & q & "A" & q & " by bg field tField", \
         "  repeat with i = 1 to the number of cards", \
         "    put the short name of card i & comma after tNames", \
         "  end repeat", \
         "  put tNames & the mark of card " & q & "B1" & q & " & comma & the mark of card " & q & "A1" & q & " into gHCScriptsTest", \
         "end mouseUp")
   -- and after then, descending, in a do that reads the handler's variable
   create button "SortThen" in group "B"
   set the script of button "SortThen" of card "B1" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  local tField, tNames, i", \
         "  put " & q & "Key" & q & " into tField", \
         "  put empty into gHCScriptsTest", \
         "  if tField is not empty then sort cards of bkgnd " & q & "A" & q & " descending by bg field tField", \
         "  repeat with i = 1 to the number of cards", \
         "    put the short name of card i & comma after tNames", \
         "  end repeat", \
         "  put tNames into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   set the defaultStack to tStack
   try
      send "mouseUp" to button "Sort" of card "B1" of stack tStack
   catch tError
   end try
   TestAssert "T54: as it is, the sort stops", gHCScriptsTest is empty
   try
      send "mouseUp" to button "SortThen" of card "B1" of stack tStack
   catch tError
   end try
   TestAssert "T54: as it is, the sort after then stops", gHCScriptsTest is empty
   get revHyperCardFixScripts(tStack)
   TestAssert "T54: in a script that compiles", _Compiles(the script of button "Sort" of card "B1" of stack tStack)
   go to card "B2" of stack tStack
   set the defaultStack to tStack
   put empty into gHCScriptsCards
   try
      send "mouseUp" to button "Sort" of card "B1" of stack tStack
   catch tError
   end try
   TestAssert "T54: the A cards in their places, in order; the B cards and the marks as they were", \
         gHCScriptsTest is "A2,B1,A3,B2,A1,true,false"
   TestAssert "T54: on the first card, as this engine's sort ends", the short name of this card of stack tStack is "A2"
   TestAssert "T54: closeCard to the card it began on, openCard to the first, no other card", \
         gHCScriptsCards is "close B2,open A2,"
   put "b" into field "Key" of card "A3" of stack tStack
   set the defaultStack to tStack
   try
      send "mouseUp" to button "SortThen" of card "B1" of stack tStack
   catch tError
   end try
   TestAssert "T54: after then, in a do by the handler's variable: the A cards descending, in their places", \
         gHCScriptsTest is "A1,B1,A3,B2,A2,"
   _Close tStack
end TestHyperCardScriptsT54

on TestHyperCardScriptsT55
   -- T55: the version of a stack, which this engine takes for its own
   -- version followed by "of", so that a script with one does not compile
   -- or stops ("source is not a container"): the library's hcStackVersion,
   -- HyperCard's long version four times and the seconds (7 statements in
   -- 5 corpus stacks: StackCOMPACTER stopped as it opened)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on openStack", \
         "  get the version of this stack", \
         "  put item 1 of the version of stack " & q & "Data" & q & " into v", \
         "  return (item 4 of the long version of stack stackName >= 2000000)", \
         "  if char 1 to 2 of item 3 of the version of this stack < 2 then beep", \
         "  put the version of stack into x", \
         "  put the version into y", \
         "end openStack") into tScript
   TestAssert "T55: the version of this stack", line 2 of tScript is "  get hcStackVersion(the long id of this stack)"
   TestAssert "T55: of a stack by name", line 3 of tScript is "  put item 1 of hcStackVersion(the long id of stack " & q & "Data" & q & ") into v"
   TestAssert "T55: the long version, of a stack in a variable", line 4 of tScript is "  return (item 4 of hcStackVersion(the long id of stack stackName) >= 2000000)"
   TestAssert "T55: an item of it", line 5 of tScript is "  if char 1 to 2 of item 3 of hcStackVersion(the long id of this stack) < 2 then beep"
   TestAssert "T55: of stack, this stack", line 6 of tScript is "  put hcStackVersion(the long id of this stack) into x"
   TestAssert "T55: HyperCard's version: still T10's", line 7 of tScript is "  put hcVersion() into y"
   TestAssert "T55: the script compiles", _Compiles(tScript)

   -- in a script that compiles
   put "HCScriptsT55" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Version"
   set the script of button "Version" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  get the version of this stack", \
         "  put the number of items of it & comma & item 1 of it & comma & (item 5 of it is a number) into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Version" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T55: as it is, it stops", gHCScriptsTest is empty
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Version" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T55: five items, HyperCard's long version first", gHCScriptsTest is "5,02418000,true"
   _Close tStack
end TestHyperCardScriptsT55

on TestHyperCardScriptsT56
   -- T56: a chunk of a chunk no larger than itself, which HyperCard took
   -- chunk by chunk from the container in and this engine refuses ("bad
   -- chunk order"): as a value, the part from the first chunk out of
   -- order on in parentheses; as the destination of a put, the larger
   -- chunk through a variable (20 statements in 9 corpus stacks: Aligner,
   -- GenChart, Import SYLK, HyperBattleship, Battleships, DragTracer, Mews,
   -- and Telling Tools and its help stack)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  if item 2 of word 1 of line j of fld seqNames <> " & q & q & " then beep", \
         "  get char 3 of line n of line n of tRow", \
         "  put line a of item n of linkLists into destination", \
         "  put item 2 of word 1 of it & " & q & "." & q & " & item 3 of word 1 of it into t", \
         "  animateHit x, word 2 of char p to (p + 50) of shipList", \
         "  get the second item of the last word of fld 1", \
         "  put item 1 of word 1 of line 2 of field " & q & "Card Id" & q & " of card id 5 into hx", \
         "end mouseUp") into tScript
   TestAssert "T56: in a condition, the part from the word on", line 2 of tScript \
         is "  if item 2 of (word 1 of line j of fld seqNames) <> " & q & q & " then beep"
   TestAssert "T56: a line of the same line", line 3 of tScript is "  get char 3 of line n of (line n of tRow)"
   TestAssert "T56: a line of an item", line 4 of tScript is "  put line a of (item n of linkLists) into destination"
   TestAssert "T56: two on a line", line 5 of tScript \
         is "  put item 2 of (word 1 of it) & " & q & "." & q & " & item 3 of (word 1 of it) into t"
   TestAssert "T56: a word of a range of chars", line 6 of tScript is "  animateHit x, word 2 of (char p to (p + 50) of shipList)"
   TestAssert "T56: with ordinals", line 7 of tScript is "  get the second item of (the last word of fld 1)"
   TestAssert "T56: a field of a card", line 8 of tScript \
         is "  put item 1 of (word 1 of line 2 of field " & q & "Card Id" & q & " of card id 5) into hx"
   TestAssert "T56: the script compiles", _Compiles(tScript)

   -- the destination of a put: the larger chunk into hcChunk, the value
   -- into its chunk, and back; after then or else, a do of the three
   put _Rewrite("on mouseUp", \
         "  put x into item 1 of word 1 of line 2 of field " & q & "Card Id" & q, \
         "  put " & q & "another" & q & " into second word of line 1 of item 1 of card field " & q & "narration" & q, \
         "  if x then put y after item 1 of word 2 of z", \
         "  put item 2 of word 1 of a into item 1 of word 2 of b", \
         "end mouseUp") into tScript
   TestAssert "T56: into an item of a word", line 2 of tScript \
         is "  put word 1 of line 2 of field " & q & "Card Id" & q & " into hcChunk; put x into item 1 of hcChunk; put hcChunk into word 1 of line 2 of field " & q & "Card Id" & q
   TestAssert "T56: into a word of a line of an item", line 3 of tScript \
         is "  put item 1 of card field " & q & "narration" & q & " into hcChunk; put " & q & "another" & q & " into second word of line 1 of hcChunk; put hcChunk into item 1 of card field " & q & "narration" & q
   TestAssert "T56: after then, a do", line 4 of tScript \
         is "  if x then do " & q & "put word 2 of z into hcChunk; put y after item 1 of hcChunk; put hcChunk into word 2 of z" & q
   TestAssert "T56: the value too", line 5 of tScript \
         is "  put word 2 of b into hcChunk; put item 2 of (word 1 of a) into item 1 of hcChunk; put hcChunk into word 2 of b"
   TestAssert "T56: the script with them compiles", _Compiles(tScript)

   -- unchanged: chunks in order, a chunk of a property, what a delete
   -- or an add takes, a destination with two chunks out of order
   put _Rewrite("on mouseUp", \
         "  put item 2 of line 3 of x into word 1 of line 2 of y", \
         "  set the textStyle of item 2 of word 1 of fld 1 to bold", \
         "  delete item 2 of word 1 of x", \
         "  add 1 to item 2 of word 1 of x", \
         "  put 1 into item 1 of word 2 of char 3 to 9 of y", \
         "end mouseUp") into tScript
   TestAssert "T56: chunks in order: unchanged", line 2 of tScript is "  put item 2 of line 3 of x into word 1 of line 2 of y"
   TestAssert "T56: a chunk of a property: unchanged", line 3 of tScript is "  set the textStyle of item 2 of word 1 of fld 1 to bold"
   TestAssert "T56: what a delete takes: unchanged", line 4 of tScript is "  delete item 2 of word 1 of x"
   TestAssert "T56: what an add takes: unchanged", line 5 of tScript is "  add 1 to item 2 of word 1 of x"
   TestAssert "T56: two chunks out of order: unchanged", line 6 of tScript is "  put 1 into item 1 of word 2 of char 3 to 9 of y"

   -- in a stack: the values HyperCard gave, and a field's text changed
   -- where it did
   put "HCScriptsT56" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create field "Seq"
   put "a1,a2 b1,b2" & return & "c1,c2 d1,d2" & return & "e1,e2 f1,f2" into field "Seq"
   create button "Read"
   set the script of button "Read" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "x y" & q & " & return & " & q & "p q r" & q & " into tRow", \
         "  put item 2 of word 1 of line 2 of fld " & q & "Seq" & q & " & comma & word 2 of line 1 of line 2 of tRow" \
         & " & comma & the second item of the last word of fld " & q & "Seq" & q & " into gHCScriptsTest", \
         "end mouseUp")
   create button "Write"
   set the script of button "Write" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "Q" & q & " into item 1 of word 2 of line 3 of fld " & q & "Seq" & q, \
         "  if fld " & q & "Seq" & q & " is not empty then put " & q & "R" & q & " after second word of line 1 of item 2 of fld " & q & "Seq" & q, \
         "  put fld " & q & "Seq" & q & " into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T56: as it is, the script does not compile", not _Compiles(the script of button "Read" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T56: the scripts compile", _Compiles(the script of button "Read" of stack tStack) \
         and _Compiles(the script of button "Write" of stack tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Read" of stack tStack
   catch tError
   end try
   TestAssert "T56: an item of a word of a line, a word of a line of a line, with ordinals", gHCScriptsTest is "c2,q,f2"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Write" of stack tStack
   catch tError
   end try
   TestAssert "T56: into an item of a word of a line, after a word of a line of an item in a do", \
         gHCScriptsTest is "a1,a2 b1R,b2" & return & "c1,c2 d1,d2" & return & "e1,e2 Q,f2"
   _Close tStack
end TestHyperCardScriptsT56

on TestHyperCardScriptsT57
   -- T57: a put into a variable named in quotes ("Put 29.95 into
   -- "Price"", Type & Graphics Preview's), which HyperCard put into the
   -- variable of that name and this engine refuses: the name without its
   -- quotes (4 corpus stacks: Type & Graphics Preview, MENDELIAN GENETICS
   -- I, MathAttack and TwinPeaksTrivia)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  Put 29.95 into " & q & "Price" & q, \
         "  put the value of card field F3 into " & q & "bagone" & q, \
         "  if KFL = " & q & "Y" & q & " then put " & q & "N" & q & " into " & q & "KFL" & q & " else put " & q & "Y" & q & " into " & q & "KFL" & q, \
         "  put " & q & "x" & q & " after " & q & "Product" & q, \
         "end mouseUp") into tScript
   TestAssert "T57: into a variable named in quotes", line 2 of tScript is "  Put 29.95 into Price"
   TestAssert "T57: the value of an expression", line 3 of tScript is "  put the value of card field F3 into bagone"
   TestAssert "T57: after then and after else", line 4 of tScript \
         is "  if KFL = " & q & "Y" & q & " then put " & q & "N" & q & " into KFL else put " & q & "Y" & q & " into KFL"
   TestAssert "T57: after", line 5 of tScript is "  put " & q & "x" & q & " after Product"
   TestAssert "T57: the script compiles", _Compiles(tScript)

   -- unchanged: not a name, the message box, a word of the grammar, a
   -- string as the value
   put _Rewrite("on mouseUp", \
         "  put 1 into " & q & "two words" & q, \
         "  put 2 into " & q & "msg" & q, \
         "  put 3 into " & q & "in" & q, \
         "  put " & q & "Price" & q & " into p", \
         "end mouseUp") into tScript
   TestAssert "T57: not a name: unchanged", line 2 of tScript is "  put 1 into " & q & "two words" & q
   TestAssert "T57: the message box's name: unchanged", line 3 of tScript is "  put 2 into " & q & "msg" & q
   TestAssert "T57: a word of the grammar: unchanged", line 4 of tScript is "  put 3 into " & q & "in" & q
   TestAssert "T57: a string as the value: unchanged", line 5 of tScript is "  put " & q & "Price" & q & " into p"

   -- in a stack: the global a later line reads, as HyperCard set it
   put "HCScriptsT57" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Order"
   set the script of button "Order" to _Lines("on mouseUp", "  global gHCScriptsTest, Price, KFL", \
         "  put 0.0 into " & q & "Price" & q, \
         "  Put 29.95 into " & q & "Price" & q, \
         "  if KFL is empty then put " & q & "N" & q & " into " & q & "KFL" & q, \
         "  put Price & comma & KFL into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T57: as it is, the script does not compile", not _Compiles(the script of button "Order" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T57: the script compiles", _Compiles(the script of button "Order" of stack tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Order" of stack tStack
   catch tError
   end try
   TestAssert "T57: the variables named in quotes, read after", gHCScriptsTest is "29.95,N"
   _Close tStack
end TestHyperCardScriptsT57

on TestHyperCardScriptsT58
   -- T58: find in the marked cards, which HyperCard searched alone and
   -- this engine refuses: hcFindMarkedBegin sets the dontSearch of the
   -- cards that are not marked, and in a field, of the other fields of the
   -- marked cards, the engine's find searches, and hcFindMarkedEnd sets
   -- them back and gives back the find's result (5 corpus stacks:
   -- GuessWords, Recipe, Hyper-Ref and HyperStacks B&W and Color)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  find string searchStr of marked cards", \
         "  find string findString in bkgnd field " & q & "alpha pool" & q & " of marked cards", \
         "  find whole firstTerm in field " & q & "Record" & q & " of marked cds", \
         "  if x then find (cd fld " & q & "Key Word2" & q & " of cd Browse) of marked cards", \
         "  find string searchStr", \
         "end mouseUp") into tScript
   TestAssert "T58: find in the marked cards", line 2 of tScript \
         is "  hcFindMarkedBegin; find string searchStr; hcFindMarkedEnd the result"
   TestAssert "T58: in a field", line 3 of tScript \
         is "  hcFindMarkedBegin the long id of bkgnd field " & q & "alpha pool" & q & "; find string findString; hcFindMarkedEnd the result"
   TestAssert "T58: whole, in a field of marked cds", line 4 of tScript \
         is "  hcFindMarkedBegin the long id of field " & q & "Record" & q & "; find whole firstTerm; hcFindMarkedEnd the result"
   TestAssert "T58: after then, a do", line 5 of tScript \
         is "  if x then do " & q & "hcFindMarkedBegin; find (cd fld " & q & " & quote & " & q & "Key Word2" & q & " & quote & " & q & " of cd Browse); hcFindMarkedEnd the result" & q
   TestAssert "T58: a find of all the cards: unchanged", line 6 of tScript is "  find string searchStr"
   TestAssert "T58: the script compiles", _Compiles(tScript)

   -- in a stack: four cards, the last two marked, apple in field f of
   -- the first, second and fourth, and in field g of the third
   put "HCScriptsT58" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the name of card 1 of stack tStack to "C1"
   create group "G"
   set the backgroundBehavior of group "G" to true
   create field "f" in group "G"
   create field "g" in group "G"
   create card "C2"
   create card "C3"
   create card "C4"
   put "apple" into field "f" of card "C1"
   put "apple" into field "f" of card "C2"
   put "pear" into field "f" of card "C3"
   put "apple" into field "g" of card "C3"
   put "apple" into field "f" of card "C4"
   set the mark of card "C3" to true
   set the mark of card "C4" to true
   go to card "C1"
   create button "Find" in group "G"
   set the script of button "Find" of card "C1" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put empty into gHCScriptsTest", \
         "  find string " & q & "apple" & q & " of marked cards", \
         "  put the result & comma & the short name of this card & comma after gHCScriptsTest", \
         "  go to card 1", \
         "  find string " & q & "apple" & q & " in field " & q & "f" & q & " of marked cards", \
         "  put the result & comma & the short name of this card & comma after gHCScriptsTest", \
         "  if gHCScriptsTest is not empty then find " & q & "pear" & q & " in bkgnd field " & q & "g" & q & " of marked cards", \
         "  put the result & comma & the short name of this card & comma after gHCScriptsTest", \
         "  put the dontSearch of card 1 & the dontSearch of card 2 & the dontSearch of field " & q & "g" & q & " after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T58: as it is, the script does not compile", not _Compiles(the script of button "Find" of card "C1" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T58: the script compiles", _Compiles(the script of button "Find" of card "C1" of stack tStack)
   go to card "C1" of stack tStack
   set the defaultStack to tStack
   try
      send "mouseUp" to button "Find" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T58: the marked cards alone, the field alone, not found, and the dontSearch set back", \
         gHCScriptsTest is ",C3,,C4,not found,C4,falsefalsefalse"
   _Close tStack
end TestHyperCardScriptsT58

on TestHyperCardScriptsT3Grammar
   -- T3: a word of the grammar as an object's name, which HyperCard took
   -- for the name where nothing else could follow the object, and this
   -- engine refuses: a preposition after a field whose name it ends
   -- (Logo's field TO, Order Form's By, Thermo's BY), and after the card
   -- of a go that it ends, a preposition, a part of a card or an
   -- object's word (ChemElements' cards named for the elements, Runes'
   -- card "characters", Canary's card "buttons")
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  get bg fld toName && bg fld to", \
         "  if line i of fld to is empty then show field TO", \
         "  put fld By into theitems", \
         "  hide cd fld BY", \
         "  go card At", \
         "  go cd characters", \
         "  go to card buttons", \
         "  if x then go card In else beep", \
         "end mouseUp") into tScript
   TestAssert "T3: a preposition that ends a field's name", line 2 to 3 of tScript \
         is _Lines("  get bg fld toName && bg fld " & q & "to" & q, "  if line i of fld " & q & "to" & q & " is empty then show field " & q & "TO" & q)
   TestAssert "T3: before into, and a card field", line 4 to 5 of tScript is _Lines("  put fld " & q & "By" & q & " into theitems", "  hide cd fld " & q & "BY" & q)
   TestAssert "T3: the card of a go: a preposition, a part of a card, an object's word", line 6 to 8 of tScript \
         is _Lines("  go card " & q & "At" & q, "  go cd " & q & "characters" & q, "  go to card " & q & "buttons" & q)
   TestAssert "T3: the card of a go before else", line 9 of tScript is "  if x then go card " & q & "In" & q & " else beep"
   TestAssert "T3: those compile", _Compiles(tScript)

   -- unchanged: the next card in a new window, and a word that does not
   -- end the go (in a script with a line that does not compile: one that
   -- compiles is not rewritten line by line)
   put _Rewrite("on mouseUp", \
         "  go next card in a new window", \
         "  go to card id 3", \
         "  hide cd fld BY", \
         "end mouseUp") into tScript
   TestAssert "T3: the next card in a new window: unchanged", line 2 of tScript is "  go next card in a new window"
   TestAssert "T3: a go to a card id: unchanged", line 3 of tScript is "  go to card id 3"

   -- in a stack: the card named In, the field named TO
   put "HCScriptsT3" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the name of card 1 of stack tStack to "C1"
   create field "TO"
   create card "In"
   go to card "C1"
   create button "Go"
   set the script of button "Go" of card "C1" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "z" & q & " into field TO", \
         "  put field " & q & "TO" & q & " into gHCScriptsTest", \
         "  go card In", \
         "  put comma & the short name of this card after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T3: as it is, the script does not compile", not _Compiles(the script of button "Go" of card "C1" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T3: the script compiles", _Compiles(the script of button "Go" of card "C1" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Go" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T3: the field named TO, the card named In", gHCScriptsTest is "z,In"
   _Close tStack
end TestHyperCardScriptsT3Grammar

on TestHyperCardScriptsT59
   -- T59: a card named by an expression not in parentheses, which HyperCard
   -- took for the card the whole expression names or numbers, as both take
   -- it in a go, and this engine refuses, as it takes the card "Div-" and
   -- then cannot place the operator: the expression in parentheses, in a
   -- put's destination, a set's object and a mark (1040A's cards
   -- "Div-"&c, SalesWriter's "order"&sheet, Yeast Collection's "Liste" &&
   -- Hunderter, StackTools' mark card it + 1)
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  put empty into field i of card " & q & "Div-" & q & "&c", \
         "  put empty into line count of Field " & q & "price" & q & " of card " & q & "order" & q & "&sheet", \
         "  set lockText of field " & q & "Liste" & q & " of card " & q & "Liste" & q & " && Hunderter to true", \
         "  put field " & q & "Liste" & q & " of card " & q & "Liste" & q & " && Karte of background " & q & "Stammlisten" & q & " into field " & q & "Lager" & q, \
         "  mark card it + 1", \
         "  if x then put empty into field 2 of card " & q & "b" & q & "&c else beep", \
         "end mouseUp") into tScript
   TestAssert "T59: a put's destination", line 2 to 3 of tScript is _Lines("  put empty into field i of card (" & q & "Div-" & q & "&c)", \
         "  put empty into line count of Field " & q & "price" & q & " of card (" & q & "order" & q & "&sheet)")
   TestAssert "T59: a set's object, to the set's to", line 4 of tScript \
         is "  set lockText of field " & q & "Liste" & q & " of card (" & q & "Liste" & q & " && Hunderter) to true"
   TestAssert "T59: before of a background, one word", line 5 of tScript \
         is "  put field " & q & "Liste" & q & " of card (" & q & "Liste" & q & " && Karte) of background " & q & "Stammlisten" & q & " into field " & q & "Lager" & q
   TestAssert "T59: a mark", line 6 of tScript is "  mark card (it + 1)"
   TestAssert "T59: a put after then, to else", line 7 of tScript is "  if x then put empty into field 2 of card (" & q & "b" & q & "&c) else beep"
   TestAssert "T59: those compile", _Compiles(tScript)

   -- unchanged: a value, which compiles here as it is, and a go (in a
   -- script with a line that does not compile: one that compiles is not
   -- rewritten line by line)
   put _Rewrite("on mouseUp", \
         "  put field 1 of card " & q & "a" & q & " & x into y", \
         "  get line 1 of field " & q & "Liste" & q & " of card " & q & "Liste" & q & " && Hunderter", \
         "  go to card " & q & "order" & q & "&sheet", \
         "  mark card it + 1", \
         "end mouseUp") into tScript
   TestAssert "T59: a value, and a go: unchanged", line 2 to 4 of tScript is _Lines("  put field 1 of card " & q & "a" & q & " & x into y", \
         "  get line 1 of field " & q & "Liste" & q & " of card " & q & "Liste" & q & " && Hunderter", "  go to card " & q & "order" & q & "&sheet")

   -- in a stack: cards C1, Div-2 and order3 with a background field f
   put "HCScriptsT59" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the name of card 1 of stack tStack to "C1"
   create group "G"
   set the backgroundBehavior of group "G" to true
   create field "f" in group "G"
   create card "Div-2"
   create card "order3"
   go to card "C1"
   create button "Cards"
   set the script of button "Cards" of card "C1" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put 2 into c", \
         "  put " & q & "x" & q & " into field " & q & "f" & q & " of card " & q & "Div-" & q & "&c", \
         "  put 3 into sheet", \
         "  put " & q & "y" & q & " into line 2 of field " & q & "f" & q & " of card " & q & "order" & q & "&sheet", \
         "  set the lockText of field " & q & "f" & q & " of card " & q & "Div-" & q & " & c to true", \
         "  mark card c + 1", \
         "  put field " & q & "f" & q & " of card 2 & comma & line 2 of field " & q & "f" & q & " of card 3 into gHCScriptsTest", \
         "  put comma & the lockText of field " & q & "f" & q & " & comma & the mark of card 3 & comma & the mark of card 2 after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T59: as it is, the script does not compile", not _Compiles(the script of button "Cards" of card "C1" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T59: the script compiles", _Compiles(the script of button "Cards" of card "C1" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Cards" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T59: the cards the expressions name and number", gHCScriptsTest is "x,y,true,true,false"
   _Close tStack
end TestHyperCardScriptsT59

on TestHyperCardScriptsT60
   -- T60: a property this engine has for no object, of the window of an
   -- external (Development Library's scrollbar, Listoid's selectedLine,
   -- QuickTime Tools' currTime, Chiclette's Btn1Name), which HyperCard
   -- handed to the external and this engine refuses (a get compiles, as
   -- a get and a call of a handler "of", which fails when it runs): the
   -- library's, as for HyperCard's own windows (T28). No external runs
   -- here, so its window is never open: a set leaves "No such window" in
   -- the result, and a read gives empty. Only revHyperCardFixScripts
   -- (with its probes) finds them: a property or a function of this
   -- engine's, and a property it takes for a custom property ("the def of
   -- window w"), are left as they are
   local tStack, q, tScript, tError, tKept
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT60" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Window"
   set the script of button "Window" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  set the scrollbar of window " & q & "Message Crate" & q & " to 8", \
         "  put the result into gHCScriptsTest", \
         "  set selectedLine of window " & q & "TheList" & q & " to random(20)", \
         "  put comma & the result after gHCScriptsTest", \
         "  put Btn1Name of window " & q & "Chiclette Editor" & q & " into windName", \
         "  put comma & windName after gHCScriptsTest", \
         "  get currTime of window " & q & "Movie" & q, \
         "  put comma & it after gHCScriptsTest", \
         "  if the current of window " & q & "Clipboard" & q & " is empty then put comma & " & q & "none" & q & " after gHCScriptsTest", \
         "end mouseUp")
   create button "Kept"
   put _Lines("on mouseUp", "  set the def of window " & q & "Editor" & q & " to 1", "  get selectedLine of window " & q & "TheList" & q, \
         "  put the name of window 1 into x", "end mouseUp") into tKept
   set the script of button "Kept" to tKept
   unlock messages
   TestAssert "T60: as it is, the script does not compile", not _Compiles(the script of button "Window" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put the script of button "Window" of stack tStack into tScript
   TestAssert "T60: a set", line 3 of tScript is "  hcSetWindow " & q & "scrollbar" & q & ", " & q & "Message Crate" & q & ", 8"
   TestAssert "T60: a set without the, of a function's name", line 5 of tScript is "  hcSetWindow " & q & "selectedline" & q & ", " & q & "TheList" & q & ", random(20)"
   TestAssert "T60: a read without the, in a put and in a get", line 7 of tScript is "  put hcWindowProperty(" & q & "btn1name" & q & ", " & q & "Chiclette Editor" & q & ") into windName" \
         and line 9 of tScript is "  get hcWindowProperty(" & q & "currtime" & q & ", " & q & "Movie" & q & ")"
   TestAssert "T60: a read with the", line 11 of tScript \
         is "  if hcWindowProperty(" & q & "current" & q & ", " & q & "Clipboard" & q & ") is empty then put comma & " & q & "none" & q & " after gHCScriptsTest"
   TestAssert "T60: the script compiles", _Compiles(tScript)
   TestAssert "T60: a custom property, a function and a property of this engine's: unchanged", line 1 to 5 of the script of button "Kept" of stack tStack is tKept
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Window" of stack tStack
   catch tError
   end try
   TestAssert "T60: no such window for a set, empty for a read", gHCScriptsTest is "No such window,No such window,,,none"
   _Close tStack
end TestHyperCardScriptsT60

on TestHyperCardScriptsT61
   -- T61: HyperCard 2.2's speech ("if the speech is not done then stop
   -- speech", "get line 1 of the voices" and "speak (item 4 of
   -- pasteList) with voice it", Spooky Pictures'; "if voices() is
   -- empty"), which this engine has not: the library's hcSpeech(),
   -- hcVoices() and hcStopSpeech, by the speech SpeakString and Say use,
   -- and its Speak for a speak with a voice. A variable named speech, a
   -- property of an object and a stack's own function voices are left as
   -- they are
   local tScript, tStack, tError, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  if the speech is not done then stop speech", \
         "  get line 1 of the voices", \
         "  if voices() is empty then beep", \
         "  put the speech into x", \
         "  stop speech", \
         "  speak (item 4 of pasteList) with voice it", \
         "  if x then speak " & q & "Hello" & q & " & who with female voice -- a voice", \
         "end mouseUp") into tScript
   TestAssert "T61: the speech, and stop speech after then", line 2 of tScript is "  if hcSpeech() is not done then hcStopSpeech"
   TestAssert "T61: the voices", line 3 of tScript is "  get line 1 of hcVoices()"
   TestAssert "T61: voices()", line 4 of tScript is "  if hcVoices() is empty then beep"
   TestAssert "T61: the speech in a put, and stop speech alone", line 5 to 6 of tScript is _Lines("  put hcSpeech() into x", "  hcStopSpeech")
   TestAssert "T61: speak with a voice, and with a gender's after then", line 7 to 8 of tScript \
         is _Lines("  Speak (item 4 of pasteList)", "  if x then Speak " & q & "Hello" & q & " & who -- a voice")
   TestAssert "T61: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", "  put speech into x", "  get voices()", "  put the speech of me into y", "  put 1 +* into q", "end mouseUp", \
         "function voices", "  return 1", "end voices") into tScript
   TestAssert "T61: a variable, a property of an object and the stack's own function: unchanged", \
         line 2 to 4 of tScript is _Lines("  put speech into x", "  get voices()", "  put the speech of me into y")

   -- in a stack, where nothing is spoken
   put "HCScriptsT61" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Speech"
   set the script of button "Speech" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  if the speech is not done then stop speech", \
         "  put the speech into gHCScriptsTest", \
         "  put comma & (the number of lines of the voices >= 0) after gHCScriptsTest", \
         "  stop speech", \
         "  put comma & the speech after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T61: as it is, the script does not compile", not _Compiles(the script of button "Speech" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T61: the script compiles", _Compiles(the script of button "Speech" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Speech" of stack tStack
   catch tError
   end try
   TestAssert "T61: the speech done, the voices a list, stop speech with nothing spoken", tError is empty and gHCScriptsTest is "done,true,done"
   _Close tStack
end TestHyperCardScriptsT61

on TestHyperCardScriptsT62
   -- T62: a function of the stack named like a constant, a property or an
   -- operator of this engine (SalesWriter's comma, Power Tools' colors,
   -- Stack Dumper's Visible, Ship Shape's wrap), whose calls this engine
   -- takes for that word ("put comma(hold) into hold" does not compile,
   -- "fileName(it)" stops with an error when it runs), where HyperCard
   -- called the handler: the function and its calls renamed, as T1
   -- renames a handler whose name is refused. In a script that compiles
   -- too, where T1's functions are now renamed as well ("select line
   -- clickLine() of me", where the stack's clickLine gives a line's
   -- number and this engine's a chunk). Only a call that reaches the
   -- function from every card is renamed: one from another card, or from
   -- a background's field, still reaches this engine's own function, as
   -- HyperCard's went on to its own where no handler was
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("function comma n", "  if n is empty then exit comma", "  return n & " & q & "," & q, "end comma", \
         "function Visible place, object, n", "  pass Visible", "end Visible", \
         "on mouseUp", "  put comma(hold) into hold", "  put Visible(1, 2, 3) & the visible of me into v", "  put comma into c", "end mouseUp") into tScript
   TestAssert "T62: a function named like a constant, its exit and end", line 1 to 4 of tScript \
         is _Lines("function hc_comma n", "  if n is empty then exit hc_comma", "  return n & " & q & "," & q, "end hc_comma")
   TestAssert "T62: named like a property, its pass", line 5 to 7 of tScript is _Lines("function hc_visible place, object, n", "  pass hc_visible", "end hc_visible")
   TestAssert "T62: the calls", line 9 of tScript is "  put hc_comma(hold) into hold" \
         and line 10 of tScript is "  put hc_visible(1, 2, 3) & the visible of me into v"
   TestAssert "T62: the constant and the property: unchanged", line 11 of tScript is "  put comma into c"
   TestAssert "T62: those compile", _Compiles(tScript)

   -- in a stack with HyperCard's addressing, as an imported one: the
   -- stack's functions comma, wrap and clickLine, card 1's colors and
   -- round; calls from card 1's button (whose script does not compile)
   -- and field (whose script does), card 2's button and a background's
   -- field
   put "HCScriptsT62" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("function comma n", "  return n & " & q & "," & q, "end comma", \
         "function wrap s", "  return " & q & "[" & q & " & s & " & q & "]" & q, "end wrap", \
         "function clickLine", "  return 2", "end clickLine")
   set the name of card 1 of stack tStack to "C1"
   set the script of card "C1" to _Lines("function round x", "  return " & q & "mine" & q, "end round", \
         "function colors", "  return " & q & "red" & q, "end colors")
   create group "G"
   set the backgroundBehavior of group "G" to true
   create field "Shared" in group "G"
   set the script of field "Shared" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put round(2.6) into gHCScriptsTest", "end mouseUp")
   create button "Calls"
   set the script of button "Calls" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put comma(5) into gHCScriptsTest", \
         "  put wrap(" & q & "a" & q & ") & colors() & round(2.6) after gHCScriptsTest", \
         "end mouseUp")
   create field "Compiled"
   set the script of field "Compiled" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put line clickLine() of (" & q & "a" & q & " & return & " & q & "b" & q & ") into gHCScriptsTest", \
         "  put comma & round(2.6) & comma & the round of 2.6 after gHCScriptsTest", \
         "end mouseUp")
   create card "C2"
   create button "Other"
   set the script of button "Other" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put round(2.6) & comma & line clickLine() of (" & q & "a" & q & " & return & " & q & "b" & q & ") into gHCScriptsTest", \
         "end mouseUp")
   go to card "C1"
   set the HCAddressing of stack tStack to true
   unlock messages
   TestAssert "T62: as it is, the script of the button does not compile", not _Compiles(the script of control "Calls" of card "C1" of stack tStack)
   TestAssert "T62: as it is, the field's does", _Compiles(the script of control "Compiled" of card "C1" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put the script of control "Calls" of card "C1" of stack tStack into tScript
   TestAssert "T62: the calls of the stack's functions and the card's", line 3 to 4 of tScript is _Lines("  put hc_comma(5) into gHCScriptsTest", \
         "  put hc_wrap(" & q & "a" & q & ") & hc_colors() & hc_round(2.6) after gHCScriptsTest")
   put the script of control "Compiled" of card "C1" of stack tStack into tScript
   TestAssert "T62: in a script that compiles, T1's functions too; the round of: unchanged", line 3 to 4 of tScript \
         is _Lines("  put line hc_clickline() of (" & q & "a" & q & " & return & " & q & "b" & q & ") into gHCScriptsTest", \
         "  put comma & hc_round(2.6) & comma & the round of 2.6 after gHCScriptsTest")
   TestAssert "T62: from card 2, card 1's function: unchanged; the stack's: renamed", line 3 of the script of control "Other" of card "C2" of stack tStack \
         is "  put round(2.6) & comma & line hc_clickline() of (" & q & "a" & q & " & return & " & q & "b" & q & ") into gHCScriptsTest"
   TestAssert "T62: from a background's field, card 1's function: unchanged", line 3 of the script of control "Shared" of card "C1" of stack tStack \
         is "  put round(2.6) into gHCScriptsTest"
   TestAssert "T62: the scripts compile", _Compiles(the script of stack tStack) and _Compiles(the script of card "C1" of stack tStack) \
         and _Compiles(the script of control "Calls" of card "C1" of stack tStack)

   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to control "Calls" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T62: the stack's functions and the card's called", gHCScriptsTest is "5,[a]redmine"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to control "Compiled" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T62: the stack's clickLine and the card's round, and this engine's round of", gHCScriptsTest is "b,mine,3"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to control "Other" of card "C2" of stack tStack
   catch tError
   end try
   TestAssert "T62: from card 2, this engine's round and the stack's clickLine", gHCScriptsTest is "3,b"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to control "Shared" of card "C1" of stack tStack
   catch tError
   end try
   TestAssert "T62: from a background's field, this engine's round", gHCScriptsTest is "3"
   _Close tStack
end TestHyperCardScriptsT62

on TestHyperCardScriptsT63
   -- T63: a mark of punctuation alone as a value, which HyperCard took as
   -- the text it was ("set the itemDelimiter to :", "if theKey = . then",
   -- "digest sd,sc,sb,.,se", "put the round of x &% into ...", "put
   -- ~&it into ...") and this engine refuses (and takes # for the start
   -- of a comment): in quotes. A mark that touches a number or a word is
   -- left as it is
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  set the itemDelimiter to :", \
         "  if theKey = . then beep", \
         "  digest sb,.,sa", \
         "  put the round of x &% into field " & q & "score" & q, \
         "  put ~&it into field " & q & "images" & q, \
         "  put x & # into y", \
         "  if x is ! then beep", \
         "end mouseUp") into tScript
   TestAssert "T63: a set's value", line 2 of tScript is "  set the itemDelimiter to " & q & ":" & q
   TestAssert "T63: after an operator", line 3 of tScript is "  if theKey = " & q & "." & q & " then beep"
   TestAssert "T63: between commas", line 4 of tScript is "  digest sb," & q & "." & q & ",sa"
   TestAssert "T63: touching the operator before and after", line 5 to 6 of tScript \
         is _Lines("  put the round of x &" & q & "%" & q & " into field " & q & "score" & q, "  put " & q & "~" & q & "&it into field " & q & "images" & q)
   TestAssert "T63: a hash sign, and an exclamation mark", line 7 to 8 of tScript is _Lines("  put x & " & q & "#" & q & " into y", "  if x is " & q & "!" & q & " then beep")
   TestAssert "T63: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", "  put .5 into z", "  put 10:30 into w", "  put x.y into v", "  put 1 +* into q", "end mouseUp") into tScript
   TestAssert "T63: a mark that touches a number or a word: unchanged", line 2 to 4 of tScript is _Lines("  put .5 into z", "  put 10:30 into w", "  put x.y into v")

   -- in a stack
   put "HCScriptsT63" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Marks"
   set the script of button "Marks" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  set the itemDelimiter to :", \
         "  put item 2 of " & q & "a:b" & q & " into gHCScriptsTest", \
         "  set the itemDelimiter to comma", \
         "  put comma & (" & q & "." & q & " is .) after gHCScriptsTest", \
         "  put comma & 5 &% after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T63: as it is, the script does not compile", not _Compiles(the script of button "Marks" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T63: the script compiles", _Compiles(the script of button "Marks" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Marks" of stack tStack
   catch tError
   end try
   TestAssert "T63: the item delimiter, and the marks as text", gHCScriptsTest is "b,true,5%"
   _Close tStack
end TestHyperCardScriptsT63

on TestHyperCardScriptsT64
   -- T64: HyperCard's global properties that this engine has not
   -- ("set dialingTime to 180", Phone Dialer's; "put the language into
   -- oldlanguage" and "set language to oldlanguage", HyperBibTeX's), which
   -- it refuses to read and to set: the library's hcProperty() and
   -- hcSetProperty, which keep what a script set, and before it give
   -- HyperCard's own value. A variable of such a name, and a property of
   -- an object, are left as they are
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  set the dialingTime to 600", \
         "  set language to oldLanguage", \
         "  put the dialingTime into t", \
         "  put the LANGUAGE into oldlanguage", \
         "  if the scriptEditor is " & q & "ScriptEditor" & q & " then beep", \
         "  set the variableWatcher to " & q & "VW" & q & " -- a watcher", \
         "end mouseUp") into tScript
   TestAssert "T64: a set, with the and without", line 2 to 3 of tScript \
         is _Lines("  hcSetProperty " & q & "dialingTime" & q & ", 600", "  hcSetProperty " & q & "language" & q & ", oldLanguage")
   TestAssert "T64: a read, the name as the library takes it", line 4 to 5 of tScript \
         is _Lines("  put hcProperty(" & q & "dialingTime" & q & ") into t", "  put hcProperty(" & q & "language" & q & ") into oldlanguage")
   TestAssert "T64: a read in a condition", line 6 of tScript is "  if hcProperty(" & q & "scriptEditor" & q & ") is " & q & "ScriptEditor" & q & " then beep"
   TestAssert "T64: a set, its comment kept", line 7 of tScript is "  hcSetProperty " & q & "variableWatcher" & q & ", " & q & "VW" & q & " -- a watcher"
   TestAssert "T64: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", "  put language into x", "  put the language of me into y", "  set the language of me to 1", "  put 1 +* into q", "end mouseUp") into tScript
   TestAssert "T64: a variable and an object's property: unchanged", line 2 to 4 of tScript \
         is _Lines("  put language into x", "  put the language of me into y", "  set the language of me to 1")

   -- in a stack
   put "HCScriptsT64" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Properties"
   set the script of button "Properties" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the dialingTime into gHCScriptsTest", \
         "  set the dialingTime to 600", \
         "  put comma & the dialingTime after gHCScriptsTest", \
         "  put comma & the language after gHCScriptsTest", \
         "  set language to " & q & "French" & q, \
         "  put comma & the language after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T64: as it is, the script does not compile", not _Compiles(the script of button "Properties" of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T64: the script compiles", _Compiles(the script of button "Properties" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Properties" of stack tStack
   catch tError
   end try
   TestAssert "T64: HyperCard's values, then what the script set", gHCScriptsTest is "180,600,English,French"
   _Close tStack
end TestHyperCardScriptsT64

on TestHyperCardScriptsT2Me
   -- T2 with revHyperCardFixScripts' probe, which finds me refused as a
   -- parameter's name: in a field's script (one T2 rewrites), a card's
   -- field or a background's, "put mPP - 15 into me" and "add 5 to me" put
   -- into the field, as in HyperCard. The import took me for a variable
   -- and renamed it hc_me, so the field never changed. In a card's script,
   -- where me is no container, it is the variable still ("put (userName
   -- contains "Ari Halberstadt") into me", a stack's openStack). In a
   -- stack with HyperCard's addressing, as an imported one has
   local tScript, tStack, q, tError, tField
   global gHCScriptsTest
   put quote into q
   put _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put 2 into result", \
         "  put result into me", \
         "  add 5 to me", \
         "  if me is 7 then put the number of lines of me after gHCScriptsTest", \
         "end mouseUp") into tScript
   put "HCScriptsT2Me" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of this card of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put 2 into result", \
         "  put (result is 2) into me", \
         "  if me then put " & q & "card" & q & " into gHCScriptsTest", \
         "end mouseUp")
   create group "G"
   set the backgroundBehavior of group "G" to true
   create field "Shared" in group "G"
   set the script of field "Shared" to tScript
   create field "Score"
   set the script of field "Score" to tScript
   set the HCAddressing of stack tStack to true
   unlock messages
   TestAssert "T2: as it is, the script does not compile", not _Compiles(tScript)
   get revHyperCardFixScripts(tStack)
   repeat for each item tField in "Score,Shared"
      put the script of control tField of this card of stack tStack into tScript
      TestAssert "T2: the variable renamed, me kept, in field" && tField, line 3 to 6 of tScript is _Lines("  put 2 into hc_result", "  put hc_result into me", \
            "  add 5 to me", "  if me is 7 then put the number of lines of me after gHCScriptsTest")
      TestAssert "T2: the script compiles, in field" && tField, _Compiles(tScript)
   end repeat
   put the script of this card of stack tStack into tScript
   TestAssert "T2: in a card's script, me the variable: unchanged", line 4 to 5 of tScript \
         is _Lines("  put (hc_result is 2) into hc_me", "  if hc_me then put " & q & "card" & q & " into gHCScriptsTest")
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to control "Score" of this card of stack tStack
      send "mouseUp" to control "Shared" of this card of stack tStack
   catch tError
   end try
   TestAssert "T2: the fields' text set and read", tError is empty and gHCScriptsTest is "11" \
         and the text of control "Score" of this card of stack tStack is "7" and the text of control "Shared" of this card of stack tStack is "7"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to this card of stack tStack
   catch tError
   end try
   TestAssert "T2: the card's variable", tError is empty and gHCScriptsTest is "card"
   _Close tStack
end TestHyperCardScriptsT2Me

on TestHyperCardScriptsT2MenuBar
   -- T2: a variable named menuBar, which this engine refuses as one
   -- ("put false into menuBar", Battle of Britain's): renamed hc_menuBar,
   -- and the menu bar a "hide" or a "show" names was renamed with it, so
   -- "hide hc_menuBar" stopped with an error. That one is left as it is
   local tScript, tStack, tError
   global gHCScriptsTest
   put _Rewrite("on mouseUp", \
         "  put false into menuBar", \
         "  hide menuBar", \
         "  if menuBar then show menuBar", \
         "end mouseUp") into tScript
   TestAssert "T2: the variable renamed", line 2 of tScript is "  put false into hc_menuBar"
   TestAssert "T2: the menu bar of a hide and a show: unchanged", line 3 to 4 of tScript \
         is _Lines("  hide menuBar", "  if hc_menuBar then show menuBar")
   TestAssert "T2: those compile", _Compiles(tScript)

   -- in a stack, in a script that does not compile as it is (T2 renames
   -- in such a one only: here, for its variable named result)
   put "HCScriptsT2MenuBar" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Bar"
   set the script of button "Bar" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put false into menuBar", "  put 2 into result", "  hide menuBar", "  show menuBar", \
         "  put menuBar & comma & result into gHCScriptsTest", "end mouseUp")
   unlock messages
   TestAssert "T2: as it is, the script does not compile", not _Compiles(the script of button "Bar" of stack tStack)
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Bar" of stack tStack
   catch tError
   end try
   TestAssert "T2: the menu bar hidden and shown, the variables kept", tError is empty and gHCScriptsTest is "false,2"
   _Close tStack
end TestHyperCardScriptsT2MenuBar

on TestHyperCardScriptsT1Sends
   -- T1: a message sent to a handler T1 renames ("send move to card id
   -- cardID", HyperQuest's, whose cards have "on move", renamed hc_move),
   -- which HyperCard's handler took, and which here found no handler of
   -- that name and ran as this engine's own command, stopping with an
   -- error: the new name, in quotes. A message to a window, and one no
   -- handler of the stack is named, are left as they are, and so is one
   -- to HyperCard, named in quotes too ("send "go to next card" to
   -- "hyperCard"", Bring in the Expert's, whose stack has its own "on
   -- go"), which HyperCard's own handler took (T29)
   local tScript, tStack, q, tError, tCard
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  send move to card id cardID", \
         "  send " & q & "move north" & q & " to this card", \
         "  if x then send move else send " & q & "reset" & q & " to bkgnd btn 1", \
         "  send " & q & "close" & q & " to window " & q & "NLU" & q, \
         "  send " & q & "sort" & q & " to me", \
         "  put " & q & "send move to me" & q & " into y -- send move", \
         "  send " & q & "move north" & q & " to " & q & "hyperCard" & q, \
         "  send " & q & "move north" & q & " to HyperCard", \
         "end mouseUp", "on move", "end move", "on reset", "end reset", "on close", "end close") into tScript
   TestAssert "T1: a message to a renamed handler, not in quotes and in them, with its parameters", line 2 to 3 of tScript \
         is _Lines("  send " & q & "hc_move" & q & " to card id cardID", "  send " & q & "hc_move north" & q & " to this card")
   TestAssert "T1: after then and after else", line 4 of tScript is "  if x then send " & q & "hc_move" & q & " else send " & q & "hc_reset" & q & " to bkgnd btn 1"
   TestAssert "T1: to a window, to no handler of the stack, in a string: unchanged", line 5 to 7 of tScript \
         is _Lines("  send " & q & "close" & q & " to window " & q & "NLU" & q, "  send " & q & "sort" & q & " to me", \
         "  put " & q & "send move to me" & q & " into y -- send move")
   TestAssert "T1, T29: to HyperCard, in quotes or not: its own handler, not the stack's", line 8 to 9 of tScript \
         is _Lines("  hcSendToHyperCard " & q & "move north" & q, "  hcSendToHyperCard " & q & "move north" & q)
   TestAssert "T1: those compile", _Compiles(tScript)

   -- in a stack: the message to another card's handler
   put "HCScriptsT1Sends" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create card "North"
   put the short id of card "North" of stack tStack into tCard
   set the script of card "North" of stack tStack to _Lines("on move pHow", "  global gHCScriptsTest", \
         "  put " & q & "moved" & q & " && pHow after gHCScriptsTest", "end move")
   go to card 1 of stack tStack
   create button "Go"
   set the script of button "Go" to _Lines("on mouseUp", "  global gHCScriptsTest, cardID", \
         "  put " & tCard & " into cardID", "  send move to card id cardID", \
         "  send " & q & "move north" & q & " to card id cardID", "end mouseUp")
   -- (and HyperCard's go, past the stack's own)
   set the script of stack tStack to _Lines("on go", "  global gHCScriptsTest", \
         "  put " & q & "the stack's go" & q & " after gHCScriptsTest", "end go")
   create button "HC"
   set the script of button "HC" to _Lines("on mouseUp", \
         "  send " & q & "go to next card" & q & " to " & q & "hyperCard" & q, "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Go" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T1: the card's handler takes the message", tError is empty and gHCScriptsTest is "moved moved north"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "HC" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T29: send to HyperCard in quotes goes to the next card, not by the stack's go", \
         tError is empty and gHCScriptsTest is empty and the short name of this card of stack tStack is "North"
   _Close tStack
end TestHyperCardScriptsT1Sends

on TestHyperCardScriptsUserLevel
   -- T10: the userLevel, which in HyperCard is 1 (browsing) to 5
   -- (scripting), and here 8 until a script sets it: "if the userLevel is
   -- 5" (51 stacks of the corpus compare it with 5, and 301 read it),
   -- HyperCard's Home stack's arrow at its button ("UserLevel" && the
   -- userLevel). A read goes to
   -- the library's hcUserLevel(), 5 for 8; a set is left as it is, and so
   -- what a script set is what it reads
   local tScript, tStack, q, tError, tLevel
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on openCard", \
         "  set the userLevel to 5", \
         "  if the userLevel is 5 then beep", \
         "  set userLevel to the userLevel - 1", \
         "  set the top of cd btn " & q & "Arrow" & q & " to the top of cd btn (" & q & "UserLevel" & q & " && the userLevel)", \
         "  put " & q & "the userLevel" & q & " into x -- the userLevel", \
         "end openCard") into tScript
   TestAssert "T10: the userLevel read", line 3 of tScript is "  if hcUserLevel() is 5 then beep"
   TestAssert "T10: the userLevel set, as it is, and read", line 2 of tScript is "  set the userLevel to 5" \
         and line 4 of tScript is "  set userLevel to hcUserLevel() - 1"
   TestAssert "T10: the userLevel in a name", line 5 of tScript \
         is "  set the top of cd btn " & q & "Arrow" & q & " to the top of cd btn (" & q & "UserLevel" & q & " && hcUserLevel())"
   TestAssert "T10: the userLevel in a string and a comment, as it is", line 6 of tScript is "  put " & q & "the userLevel" & q & " into x -- the userLevel"
   TestAssert "T10: those compile", _Compiles(tScript)

   -- in a stack, with this engine's userLevel as it starts
   put the userLevel into tLevel
   set the userLevel to 8
   put "HCScriptsUserLevel" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Level"
   set the script of button "Level" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the userLevel into gHCScriptsTest", \
         "  if the userLevel is 5 then put comma & " & q & "scripting" & q & " after gHCScriptsTest", \
         "  set the userLevel to 2", \
         "  put comma & the userLevel after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "T10: the script compiles", _Compiles(the script of button "Level" of stack tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Level" of stack tStack
   catch tError
   end try
   set the userLevel to tLevel
   TestAssert "T10: HyperCard's highest level, then what the script set", gHCScriptsTest is "5,scripting,2"
   _Close tStack
end TestHyperCardScriptsUserLevel

on TestHyperCardScriptsT22Names
   -- T22: a menu or a menu item named by one word this engine does not
   -- take as a value ("create menu Control", FontCard's: an object type
   -- here), which HyperCard took as its text: the word in quotes, where
   -- revHyperCardFixScripts' probe finds it refused. A word this engine
   -- takes as a value, and a variable, as they were, a variable named by
   -- such a word too (which T2 renames before T12 and T22 read it)
   local tStack, q, tScript, tError
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT22" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Menus"
   set the script of button "Menus" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  create menu Control", \
         "  put " & q & "Set Spaces,Image,-,Show Palette" & q & " into menu Control", \
         "  disable menuItem 4 of menu Control", \
         "  set the checkMark of menuItem Image of menu Control to true", \
         "  if there is a menu Control then put true into gHCScriptsTest", \
         "  put comma & the enabled of menuItem 4 of menu Control after gHCScriptsTest", \
         "  put comma & the checkMark of menuItem Image of menu Control after gHCScriptsTest", \
         "  put " & q & "Again" & q & " after menu Control with menuMsg doAgain", \
         "  put comma & the number of menuItems of menu Control after gHCScriptsTest", \
         "  delete menu Control -- gone", \
         "  put comma & (there is a menu Control) after gHCScriptsTest", \
         "end mouseUp")
   create button "Values"
   set the script of button "Values" to _Lines("on mouseUp", "  global gHCScriptsTest", "  local tMenu", \
         "  put " & q & "Tools" & q & " into tMenu", \
         "  create menu Apple", \
         "  create menu tMenu", \
         "  put " & q & "About" & q & " into menu Apple with menuMsg doAbout", \
         "  put " & q & "Extras" & q & " into control", \
         "  create menu control", \
         "  put (there is a menu " & q & "Apple" & q & ") & comma & (there is a menu " & q & "Tools" & q & ") & comma & (there is a menu " & q & "Extras" & q & ") into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   TestAssert "T22: as it is, the script does not compile", not _Compiles(the script of button "Menus" of stack tStack)
   get revHyperCardFixScripts(tStack)
   put the script of button "Menus" of stack tStack into tScript
   TestAssert "T22: create menu named by an object type", line 3 of tScript is "  hcCreateMenu " & q & "Control" & q
   TestAssert "T22: put into it", line 4 of tScript \
         is "  hcPutIntoMenu " & q & "Set Spaces,Image,-,Show Palette" & q & ", " & q & "into" & q & ", " & q & "Control" & q & ", empty, empty"
   TestAssert "T22: disable a menuItem of it", line 5 of tScript is "  hcEnableMenu false, " & q & "Control" & q & ", 4"
   TestAssert "T22: set the checkMark of a menuItem named by an object type", line 6 of tScript \
         is "  hcSetMenuItem " & q & "checkmark" & q & ", " & q & "Control" & q & ", " & q & "Image" & q & ", true"
   TestAssert "T48: there is a menu named by an object type", line 7 of tScript is "  if hcThereIsMenu(" & q & "Control" & q & ") then put true into gHCScriptsTest"
   TestAssert "T22: a menuItem's property, of a menu named by an object type", line 8 of tScript \
         is "  put comma & hcMenuItem(" & q & "enabled" & q & ", " & q & "Control" & q & ", 4) after gHCScriptsTest"
   TestAssert "T22: of a menuItem named by an object type", line 9 of tScript \
         is "  put comma & hcMenuItem(" & q & "checkmark" & q & ", " & q & "Control" & q & ", " & q & "Image" & q & ") after gHCScriptsTest"
   -- (T12's forms, which take a whole line: with menuMsg, delete menu)
   TestAssert "T22: put after it with a menu message", line 10 of tScript \
         is "  hcPutIntoMenu " & q & "Again" & q & ", " & q & "after" & q & ", " & q & "Control" & q & ", doAgain"
   TestAssert "T48: the number of its menuItems", line 11 of tScript is "  put comma & hcMenuItemCount(" & q & "Control" & q & ") after gHCScriptsTest"
   TestAssert "T22: delete it, its comment kept", line 12 of tScript is "  hcDeleteMenu " & q & "Control" & q & " -- gone"
   TestAssert "T22: the script compiles", _Compiles(tScript)
   put the script of button "Values" of stack tStack into tScript
   TestAssert "T22: a word this engine takes as a value: as it was", line 5 of tScript is "  hcCreateMenu Apple"
   TestAssert "T22: a variable: as it was", line 6 of tScript is "  hcCreateMenu tMenu"
   TestAssert "T22: with a menu message: as it was", line 7 of tScript \
         is "  hcPutIntoMenu " & q & "About" & q & ", " & q & "into" & q & ", Apple, doAbout"
   -- (a variable named like an object type, which T2 renames first)
   TestAssert "T22: a variable named by an object type: renamed, as it was", line 9 of tScript is "  hcCreateMenu hc_control"

   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Menus" of stack tStack
   catch tError
   end try
   TestAssert "T22: the menu made, its item disabled and checked, an item put after, the menu deleted", \
         gHCScriptsTest is "true,false,true,5,false"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Values" of stack tStack
   catch tError
   end try
   TestAssert "T22: the menus named by a value and by two variables made", gHCScriptsTest is "true,true,true"
   _Close tStack
end TestHyperCardScriptsT22Names

on TestHyperCardScriptsRulesFixed
   -- two rules that broke a line HyperCard ran: T11's "in" for "of" in
   -- the operator "is in" after a card, and T2 at the end of a line
   -- that goes on with \
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", "  if the short name of this cd is in cd fld " & q & "Index" & q & " of cd 1 then beep", \
         "  if the short name of this stack is in fld 1 then beep", "  get fld Notes in card 2", "  get the name of card it in bkgnd " & q & "BBS" & q, \
         "  find cd fld " & q & "name" & q & " in cd fld " & q & "names" & q, "  find word the short name of bkgnd btn id 122 in bkgnd field kk", "end mouseUp") into tScript
   TestAssert "T11: is in after a card, as it was", line 2 to 3 of tScript is _Lines("  if the short name of this cd is in cd fld " & q & "Index" & q & " of cd 1 then beep", \
         "  if the short name of this stack is in fld 1 then beep")
   TestAssert "T11: in for of after an object's name still", line 4 to 5 of tScript is _Lines("  get fld Notes of card 2", "  get the name of card it of bkgnd " & q & "BBS" & q)
   TestAssert "T11: find's in, before the field it looks in, as it was", line 6 to 7 of tScript is _Lines("  find cd fld " & q & "name" & q & " in cd fld " & q & "names" & q, \
         "  find word the short name of bkgnd btn id 122 in bkgnd field kk")
   TestAssert "T11: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", "  put 1 into this", "  if this = 1 or this \", "  = 2 then beep", "  get the name of this \", "  card", "end mouseUp") into tScript
   TestAssert "T2: the variable before a \, read with the next line", line 2 to 4 of tScript is _Lines("  put 1 into hc_this", "  if hc_this = 1 or hc_this \", "  = 2 then beep")
   TestAssert "T2: and the word of the grammar before one", line 5 to 6 of tScript is _Lines("  get the name of this \", "  card")
   TestAssert "T2: those compile", _Compiles(tScript)
end TestHyperCardScriptsRulesFixed

on TestHyperCardScriptsMoreFormsProbed
   -- T33: a window's name this engine does not take as a value, which
   -- only revHyperCardFixScripts (with its probes) finds
   local tStack, tScript
   put "HCScripts" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Win"
   set the script of button "Win" to _Lines("on mouseUp", "  hide window Clipboard", "  hide window w", "  put mouseLoc into p", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the script of button "Win" of stack tStack into tScript
   TestAssert "T33: a window named by a word that is no value, quoted", line 2 of tScript is "  hcWindow " & quote & "hide" & quote & ", " & quote & "Clipboard" & quote
   TestAssert "T33: a window named by a variable: unchanged", line 3 of tScript is "  hcWindow " & quote & "hide" & quote & ", w"
   TestAssert "T33: the script compiles", _Compiles(tScript)
   _Close tStack
end TestHyperCardScriptsMoreFormsProbed

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
   -- (mouseDown and f compile without their bad line, T39; mouseEnter
   -- and g, with an if that has no end, do not)
   set the script of button "Mixed" to _Lines("on mouseUp", "  put 2 into y", "end mouseUp", "on mouseDown", "  put 1 +* into", "end mouseDown", "function f", "  put ( into z", "end f", \
         "on mouseEnter", "  if x then", "    put 1 +* into", "end mouseEnter", "function g", "  if x then", "  return 1", "end g")
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
   TestAssert "salvaged: a bad line left out, its handler kept", "  -- HyperCard import: left out, it does not compile here: put 1 +* into" is among the lines of the script of button "Mixed" of stack tStack \
         and "   pass mouseDown" is not among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: the same in a function", "  -- HyperCard import: left out, it does not compile here: put ( into z" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: the bad handler passes its message", "   pass mouseEnter" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: its HyperTalk inside, commented out", "   --     put 1 +* into" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: a bad function returns empty", "   return empty" is among the lines of the script of button "Mixed" of stack tStack
   TestAssert "salvaged: a handler no name can call, commented out whole", _Compiles(the script of button "Named" of stack tStack) and "-- on " & quote & "v" & quote is among the lines of the script of button "Named" of stack tStack
   TestAssert "logged in the hcImportStat", "HyperCard scripts: 3 rewritten" is in the hcImportStat
   put the customProperties["uHyperCard"] of stack tStack into tSet
   TestAssert "the report kept on the stack", tSet["scripts"] is tReport

   -- the library, as the stack's behavior
   TestAssert "library added, named after the stack", _Library(tStack) is among the lines of the substacks of stack tStack
   TestAssert "library is the behavior", the short name of the behavior of stack tStack is _Library(tStack)
   TestAssert "library compiles", _Compiles(the script of stack _Library(tStack) of stack tStack)
   _Close tStack

   -- a substack the import made with the library's name (a palette, say)
   -- is left alone
   put "HCClash" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   create invisible stack _Library(tStack)
   set the mainStack of it to tStack
   set the script of stack _Library(tStack) of stack tStack to _Lines("on palette", "end palette")
   set the script of stack tStack to _Lines("on openStack", "  put the message box into x", "end openStack")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "a clash: the library under a free name", the short name of the behavior of stack tStack is _Library(tStack) && "2"
   TestAssert "a clash: the other substack untouched", the script of stack _Library(tStack) of stack tStack is _Lines("on palette", "end palette") & return or the script of stack _Library(tStack) of stack tStack is _Lines("on palette", "end palette")
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

on TestHyperCardScriptsMenuItems
   -- HyperCard's menu items, which a stack without HyperCard's message
   -- order reaches through the library's hcDoMenu: by their names in any
   -- case, with or without their "..."
   local tStack, q
   global gHCScriptsTest
   put quote into q
   put "HCMenuItems" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   -- the buttons in a background, so each card has them
   create group "BG"
   set the backgroundBehavior of group "BG" to true
   create button "Go" in group "BG"
   set the script of button "Go" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  doMenu " & q & "Last" & q, "  put the number of this card into gHCScriptsTest", \
         "  doMenu " & q & "Prev" & q, "  put comma & the number of this card after gHCScriptsTest", \
         "  doMenu " & q & "first" & q, "  put comma & the number of this card after gHCScriptsTest", \
         "  doMenu " & q & "NEXT" & q, "  put comma & the number of this card after gHCScriptsTest", \
         "end mouseUp")
   create button "Objects" in group "BG"
   set the script of button "Objects" to _Lines("on mouseUp", "  global gHCScriptsTest", "  local tCount", \
         "  put the number of controls of this card into tCount", \
         "  doMenu " & q & "New Field" & q, \
         "  put the number of controls of this card - tCount into gHCScriptsTest", \
         "  doMenu " & q & "new button..." & q, \
         "  put comma & (there is a button " & q & "New Button" & q & ") after gHCScriptsTest", \
         "  doMenu " & q & "Compact Stack" & q, "  put comma & (the result is empty) after gHCScriptsTest", \
         "  doMenu " & q & "Keep" & q, "  put comma & (the result is empty) after gHCScriptsTest", \
         "  doMenu " & q & "No Such Item" & q & ", " & q & "Edit" & q, "  put comma & the result after gHCScriptsTest", \
         "end mouseUp")
   create button "Style" in group "BG"
   set the script of button "Style" to _Lines("on mouseUp", "  global gHCScriptsTest", "  local tLayer", \
         "  select field " & q & "F" & q, \
         "  doMenu " & q & "Bold" & q, "  put the textStyle of field " & q & "F" & q & " into gHCScriptsTest", \
         "  doMenu " & q & "Italic" & q, "  put comma & the textStyle of field " & q & "F" & q & " after gHCScriptsTest", \
         "  doMenu " & q & "bold" & q, "  put comma & the textStyle of field " & q & "F" & q & " after gHCScriptsTest", \
         "  doMenu " & q & "14" & q, "  put comma & the textSize of field " & q & "F" & q & " after gHCScriptsTest", \
         "  doMenu " & q & "Geneva" & q, "  put comma & the textFont of field " & q & "F" & q & " after gHCScriptsTest", \
         "  doMenu " & q & "Plain" & q, "  put comma & (the textStyle of field " & q & "F" & q & " is among the words of " & q & "plain normal" & q & " or the textStyle of field " & q & "F" & q & " is empty) after gHCScriptsTest", \
         "  select button " & q & "Low" & q, "  put the layer of button " & q & "Low" & q & " into tLayer", \
         "  doMenu " & q & "Bring Closer" & q, "  put comma & the layer of button " & q & "Low" & q & " - tLayer after gHCScriptsTest", \
         "  doMenu " & q & "Send Farther" & q, "  put comma & the layer of button " & q & "Low" & q & " - tLayer after gHCScriptsTest", \
         "  select field " & q & "Gone" & q, \
         "  doMenu " & q & "Clear Field" & q, "  put comma & (there is a field " & q & "Gone" & q & ") after gHCScriptsTest", \
         "  select empty", "  choose browse tool", \
         "end mouseUp")
   create card
   create card
   create button "Low"
   create button "High"
   create field "F"
   create field "Gone"
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "no menus substack without HyperCard's message order", _Menus(tStack) is not among the lines of the substacks of stack tStack

   put empty into gHCScriptsTest
   send "mouseUp" to button "Go" of stack tStack
   TestAssert "Go menu: Last, Prev, First, Next", gHCScriptsTest is "3,2,1,2"

   go card 3 of stack tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Objects" of stack tStack
   TestAssert "Objects menu: New Field, New Button (named as HyperCard named it); Compact Stack and Keep do nothing; an item there is not", \
         gHCScriptsTest is "1,true,true,true,doMenu " & q & "No Such Item" & q && "not implemented"

   put empty into gHCScriptsTest
   send "mouseUp" to button "Style" of stack tStack
   set the itemDelimiter to comma
   -- (the textStyle of bold and italic text is two items)
   TestAssert "Style menu: Bold, Italic added, Bold taken off again", item 1 to 4 of gHCScriptsTest is "bold,bold,italic,italic"
   TestAssert "Style menu: a size and a font of HyperCard's Macs", item 5 to 6 of gHCScriptsTest is "14,Geneva"
   TestAssert "Style menu: Plain", item 7 of gHCScriptsTest is true
   TestAssert "Objects menu: Bring Closer, Send Farther", item 8 to 9 of gHCScriptsTest is "1,0"
   TestAssert "Edit menu: Clear Field deletes the selected field", item 10 of gHCScriptsTest is false
   _Close tStack
end TestHyperCardScriptsMenuItems

on TestHyperCardScriptsMenusHyperTalk
   -- with HyperCard's message order, doMenu keeps its name and is a
   -- message: the stack's doMenu handler sees each item first, and the
   -- substack "HyperCard Menus (<the stack's name>)", the library's
   -- behavior, does the items no handler takes
   local tStack, tReport, q
   global gHCScriptsTest
   put quote into q
   put "HCMenusHyperTalk" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the hyperTalkCompatible of stack tStack to true
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("on doMenu which", "  global gHCScriptsTest", "  put which & comma after gHCScriptsTest", \
         "  if which is " & q & "Keep Me" & q & " then exit doMenu", "  pass doMenu", "end doMenu")
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  doMenu " & q & "Keep Me" & q, \
         "  doMenu " & q & "New Card" & q, "  put the number of cards of this stack & comma after gHCScriptsTest", \
         "  doMenu " & q & "No Such Item" & q, "  put the result after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put revHyperCardFixScripts(tStack) into tReport
   TestAssert "the stack's doMenu handler keeps its name", "on doMenu which" is among the lines of the script of stack tStack
   TestAssert "doMenu in a script keeps its name", "  doMenu " & q & "Keep Me" & q is among the lines of the script of button "B" of stack tStack
   TestAssert "the menus substack added", _Menus(tStack) is among the lines of the substacks of stack tStack
   TestAssert "as the library's behavior", the short name of the behavior of stack _Library(tStack) of stack tStack is _Menus(tStack)
   TestAssert "with its doMenu handler", "on doMenu pItem, pMenu, pWithout" is among the lines of the script of stack _Menus(tStack) of stack tStack
   TestAssert "named in the report", "HyperCard Menus" is in tReport

   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "the stack's handler sees each item, keeps one, and the menus substack does the others", \
         gHCScriptsTest is "Keep Me,New Card,2,No Such Item,doMenu " & q & "No Such Item" & q && "not implemented"

   -- a second fix adds no second menus substack
   get revHyperCardFixScripts(tStack)
   TestAssert "a second fix: one menus substack", _Menus(tStack) && "2" is not among the lines of the substacks of stack tStack
   _Close tStack
end TestHyperCardScriptsMenusHyperTalk

on TestHyperCardScriptsHomeHandlers
   -- the HyperCard 2 Home stack's handlers stacks called, which the
   -- library stands in for, and a stack's own coming first
   local tStack, q
   global gHCScriptsTest
   put quote into q
   put "HCHome" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest, Stacks, UserName", \
         "  getHomeInfo", "  setUserLevelFive", "  put the userLevel into gHCScriptsTest", "  restoreUserLevel", \
         "  put comma & lastHCItem(" & q & ":" & q & ", " & q & "HD:Stacks:Home" & q & ") after gHCScriptsTest", \
         "  put comma & (UserName is UserName) after gHCScriptsTest", \
         "  disallowInterruption", "  put comma & the cantAbort of this stack after gHCScriptsTest", "  allowInterruption", \
         "  put comma & checkHCFont(" & q & "No Such Font" & q & ", " & q & "12" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "Own"
   set the script of button "Own" to _Lines("on mouseUp", "  global gHCScriptsTest", "  getHomeInfo", "end mouseUp", \
         "on getHomeInfo", "  global gHCScriptsTest", "  put " & q & "own" & q & " into gHCScriptsTest", "end getHomeInfo")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "Home handlers: user level, lastHCItem, getHomeInfo, cantAbort, checkHCFont", gHCScriptsTest is "5,Home,true,true,No Such Font 12" & return
   put empty into gHCScriptsTest
   send "mouseUp" to button "Own" of stack tStack
   TestAssert "Home handlers: a stack's own getHomeInfo first", gHCScriptsTest is "own"
   _Close tStack
end TestHyperCardScriptsHomeHandlers

on TestHyperCardScriptsRecentCards
   -- the stacks revHyperCardFixScripts makes and the library's own windows
   -- are not recent cards: create opens a stack, and a stack's "go back",
   -- or its "pop card" after a "push recent card", went to its card
   local tStack, tPopped
   global gHCScriptsTest
   put "HCRecent" & the milliseconds into tStack
   lock messages
   if there is a stack "HyperCard Home" then delete stack "HyperCard Home"
   create invisible stack tStack
   set the hyperTalkCompatible of stack tStack to true
   set the defaultStack to tStack
   create card
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", "  get hcHome()", "  go back", \
         "  put the number of this card & comma & the short name of this stack into gHCScriptsTest", "end mouseUp")
   go to card 1 of stack tStack
   go to card 2 of stack tStack
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "recent cards: not the library's", _Library(tStack) is not in the recentCards
   TestAssert "recent cards: nor its menus'", _Menus(tStack) is not in the recentCards
   push recent card
   pop card into tPopped
   TestAssert "recent cards: push recent card, the card gone to before", tPopped is the long id of card 1 of stack tStack

   -- the library's stand-in for Home, made as the button asks for it
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of card 2 of stack tStack
   TestAssert "recent cards: go back after the library made a stack, the card gone to before", gHCScriptsTest is "1," & tStack
   TestAssert "recent cards: not the library's Home", "HyperCard Home" is not in the recentCards
   _Close tStack
   if there is a stack "HyperCard Home" then delete stack "HyperCard Home"
end TestHyperCardScriptsRecentCards

on TestHyperCardScriptsCommonExternals
   -- the externals stacks called most that the library stands in for
   local tStack, q, tLoudness, tSettable
   global gHCScriptsTest
   put quote into q
   put "HCExternals" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put Trim(" & q & "  a b " & q & " & tab) into gHCScriptsTest", \
         "  SetVolume 7", "  put comma & GetVolume() & comma & the playLoudness after gHCScriptsTest", \
         "  SetVolume 0", "  put comma & GetVolume() after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the playLoudness into tLoudness
   -- a machine with no sound output keeps the playLoudness at 0 whatever
   -- it is set to (the Linux and Windows CI runners), so the volume is
   -- only checked where it can be set
   set the playLoudness to 50
   put the playLoudness is 50 into tSettable
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   set the playLoudness to tLoudness
   if tSettable then
      TestAssert "Trim, SetVolume and GetVolume", gHCScriptsTest is "a b,7,100,0"
   else
      TestAssert "Trim", item 1 of gHCScriptsTest is "a b"
      TestSkip "SetVolume and GetVolume", "the playLoudness cannot be set on this machine"
   end if
   _Close tStack
end TestHyperCardScriptsCommonExternals

on TestHyperCardScriptsTextExternals
   -- the externals stacks call most for text and lists, as the library
   -- stands in for them, called as HyperTalk called them (replace(,
   -- sort( and find( through T47)
   local tStack, q, tExpected
   global gHCScriptsTest
   put quote into q
   put "HCText" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Case"
   set the script of button "Case" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put LowerToUpper(" & q & "abc 1" & q & ") & " & q & "|" & q & " & Quoted(" & q & "a" & q & ") & " & q & "|" & q & " & Strip(" & q & "-." & q & ", " & q & "1-2.3a-A" & q & ") into gHCScriptsTest", \
         "  put " & q & "|" & q & " & ChangeCase(" & q & "abc 123. def ghi" & q & ", 3) & " & q & "|" & q & " & ChangeCase(" & q & "it's done" & q & ", " & q & "Title" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & ChangeCase(" & q & "aBc" & q & ", " & q & "flip" & q & ") & " & q & "|" & q & " & ChangeCase(" & q & "x" & q & ", 9) after gHCScriptsTest", \
         "end mouseUp")
   create button "Replace"
   set the script of button "Replace" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put replace(" & q & "a" & q & ", " & q & "o" & q & ", " & q & "banana" & q & ") & " & q & "|" & q & " & replace(" & q & "banana" & q & ", " & q & "A" & q & ", " & q & "o" & q & ") into gHCScriptsTest", \
         "  put " & q & "|" & q & " & replace(" & q & "banana" & q & ", " & q & "A" & q & ", " & q & "o" & q & ", true) after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullReplace(" & q & "a-b-c" & q & ", " & q & "-" & q & ", " & q & "+" & q & ") & " & q & "|" & q & " & FullReplace(" & q & "a-b-c" & q & ", " & q & "-" & q & ", " & q & "+" & q & ", false) after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullReplace(" & q & "A-a" & q & ", " & q & "a" & q & ", " & q & "x" & q & ") & " & q & "|" & q & " & FullReplace(" & q & "a" & q & ", " & q & "a" & q & ", " & q & "b" & q & ", 9) after gHCScriptsTest", \
         "end mouseUp")
   create button "Sort"
   set the script of button "Sort" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put SortItems(" & q & "c,a,,b" & q & ") & " & q & "|" & q & " & SortItems(" & q & "b" & q & " & return & " & q & "a" & q & ", true) into gHCScriptsTest", \
         "  put " & q & "b" & q & " & return & " & q & "a" & q & " & return & " & q & "c" & q & " into t", \
         "  put " & q & "|" & q & " & SortLines(t, " & q & "Descending" & q & ") after gHCScriptsTest", \
         "  put " & q & "10 x" & q & " & return & " & q & "9 y" & q & " & return & " & q & "z" & q & " into t", \
         "  put " & q & "|" & q & " & sort(t, " & q & "numeric" & q & ") after gHCScriptsTest", \
         "  put " & q & "a,b" & q & " & return & " & q & "c,dd" & q & " into t", \
         "  put " & q & "|" & q & " & find(t, " & q & "DD" & q & ") & " & q & "|" & q & " & find(t, " & q & "<d" & q & ") & " & q & "|" & q & " & find(t, " & q & "c" & q & ", 2, 1) after gHCScriptsTest", \
         "end mouseUp")
   create button "FullSort"
   set the script of button "FullSort" to _Lines("on mouseUp", "  global gHCScriptsTest, FullSortList", \
         "  put " & q & "b" & q & " & return & " & q & "a" & q & " & return & " & q & "A" & q & " into t", \
         "  put FullSort(t) & " & q & "|" & q & " & FullSortList into gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullSort(t, " & q & "t=u" & q & ") & " & q & "|" & q & " & FullSortList after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullSort(" & q & "3,10,2" & q & ", " & q & "t=n" & q & ", " & q & "d=d" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullSort(" & q & "x" & q & " & return & " & q & "y" & q & " & return & " & q & "z" & q & ", " & q & "d=l" & q & ", " & q & "3,1" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullSort(" & q & "1/2/1999,12/1/1998,2/2/1999" & q & ", " & q & "T=D" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullSort(t, " & q & "q=1" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "FullFind"
   set the script of button "FullFind" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "The cat sat on the mat" & q & " into t", \
         "  put FullFind(t, " & q & "at" & q & ") & " & q & "|" & q & " & FullFind(t, " & q & "at" & q & ", false) & " & q & "|" & q & " & FullFind(t, " & q & "at" & q & ", false, true) into gHCScriptsTest", \
         "  put " & q & "upon a time" & q & " & return & " & q & "on and on" & q & " into t", \
         "  put " & q & "|" & q & " & FullFind(t, " & q & "on" & q & ", true, true) & " & q & "|" & q & " & FullFind(" & q & "Apple apple" & q & ", " & q & "apple" & q & ", true, true, true) after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullFind(" & q & "ab ab ab" & q & ", " & q & "ab" & q & ", true, true, false, 3) after gHCScriptsTest", \
         "  put " & q & "x,cat" & q & " & return & " & q & "cat,x" & q & " into t", \
         "  put " & q & "|" & q & " & FullFind(t, " & q & "cat" & q & ", true, true, false, 0, 2) & " & q & "|" & q & " & FullFind(" & q & "ab" & q & " & return & " & q & "cd" & q & ", " & q & "b" & q & " & return & " & q & "c" & q & ", false) after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullFind(" & q & "The Cat cat" & q & ", " & q & "cat" & q & ", " & q & "m=ac" & q & ") & " & q & "|" & q & " & FullFind(" & q & "a;b;cat" & q & ", " & q & "cat" & q & ", " & q & "s=;" & q & ", " & q & "i=3" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullFind(" & q & "cat cat" & q & ", " & q & "cat" & q & ", " & q & "o=2" & q & ", " & q & "m=a" & q & ") & " & q & "|" & q & " & FullFind(" & q & "concat catalog" & q & ", " & q & "cat" & q & ", " & q & "m=ab" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FullFind(" & q & "a" & q & ") & " & q & "|" & q & " & FullFind(" & q & "a" & q & ", " & q & "a" & q & ", " & q & "maybe" & q & ") & " & q & "|" & q & " & FullFind(" & q & "a" & q & ", " & q & "a" & q & ", " & q & "m=a" & q & ", " & q & "x=1" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "Others"
   set the script of button "Others" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put IsRunning(" & q & "Finder" & q & ") & " & q & "|" & q & " & ChangeFileType(" & q & "x" & q & ", " & q & "TEXT" & q & ", " & q & "ttxt" & q & ") & " & q & "|" & q & " & DialogDisplay() into gHCScriptsTest", \
         "  put " & q & "|" & q & " & ListSelect(" & q & "x" & q & ") & " & q & "|" & q & " & ListSelect(" & q & "Z" & q & ", " & q & "a,b" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "Options"
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the script of button "Options" of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  local tParams, tOptions", \
         "  put " & q & "s=2,3" & q & " into tParams[1]", \
         "  put " & q & "NoDoubleClick" & q & " into tParams[2]", \
         "  put " & q & "10,20" & q & " into tParams[3]", \
         "  put " & q & "Pick one" & q & " into tParams[4]", \
         "  put " & q & "Take" & q & " into tParams[5]", \
         "  put empty into tParams[6]", \
         "  put " & q & "Geneva,12" & q & " into tParams[7]", \
         "  put 3001 into tParams[8]", \
         "  put tab into tParams[9]", \
         "  put hcListSelectOptions(" & q & "*2#" & q & ", tParams) into tOptions", \
         "  put tOptions[" & q & "mode" & q & "] & " & q & "|" & q & " & tOptions[" & q & "sorted" & q & "] & " & q & "|" & q & " & tOptions[" & q & "numbers" & q & "] & " & q & "|" & q & " & tOptions[" & q & "select" & q & "] into gHCScriptsTest", \
         "  put " & q & "|" & q & " & tOptions[" & q & "double" & q & "] & " & q & "|" & q & " & tOptions[" & q & "topLeft" & q & "] & " & q & "|" & q & " & tOptions[" & q & "prompt" & q & "] & " & q & "|" & q & " & tOptions[" & q & "ok" & q & "] after gHCScriptsTest", \
         "  put " & q & "|" & q & " & tOptions[" & q & "cancel" & q & "] & " & q & "|" & q & " & tOptions[" & q & "font" & q & "] & " & q & "|" & q & " & tOptions[" & q & "size" & q & "] & " & q & "|" & q & " & (tOptions[" & q & "separator" & q & "] is tab) after gHCScriptsTest", \
         "  put hcListSelectOptions(" & q & "One" & q & ", empty) into tOptions", \
         "  put " & q & "|" & q & " & tOptions[" & q & "mode" & q & "] & tOptions[" & q & "select" & q & "] & tOptions[" & q & "double" & q & "] & tOptions[" & q & "ok" & q & "] & tOptions[" & q & "cancel" & q & "] & (tOptions[" & q & "separator" & q & "] is comma) after gHCScriptsTest", \
         "  put hcListSelectOptions(" & q & "Dis" & q & ", empty) into tOptions", \
         "  put " & q & "|" & q & " & tOptions[" & q & "mode" & q & "] after gHCScriptsTest", \
         "  put hcListSelectOptions(" & q & "N" & q & ", empty) into tOptions", \
         "  put tOptions[" & q & "mode" & q & "] after gHCScriptsTest", \
         "  put hcListSelectOptions(" & q & "Q" & q & ", empty) into tOptions", \
         "  put " & q & "|" & q & " & tOptions[" & q & "error" & q & "] after gHCScriptsTest", \
         "end mouseUp")

   put empty into gHCScriptsTest
   send "mouseUp" to button "Case" of stack tStack
   TestAssert "LowerToUpper, Quoted, Strip and ChangeCase", gHCScriptsTest is "ABC 1|" & q & "a" & q & "|123aA|Abc 123. Def ghi|It's Done|AbC|Error: conversion form specified in param 2 not recognized."
   put empty into gHCScriptsTest
   send "mouseUp" to button "Replace" of stack tStack
   TestAssert "Replace in both orders, and FullReplace", gHCScriptsTest is "bonono|bonono|banana|a+b+c|a+b-c|x-x|Error : Param #4 must be boolean"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Sort" of stack tStack
   put "a,b,c|a" & return & "b|c" & return & "b" & return & "a|z" & return & "9 y" & return & "10 x|2,2|2,2|0" into tExpected
   TestAssert "SortItems, SortLines, Sort and Find", gHCScriptsTest is tExpected
   put empty into gHCScriptsTest
   send "mouseUp" to button "FullSort" of stack tStack
   put "A" & return & "a" & return & "b|3,2,1|a" & return & "A" & return & "b|2,3,1|10,3,2|z" & return & "x" & return & "y|12/1/1998,1/2/1999,2/2/1999|Error : First char of param 2..n must be [t,d,c,s]" into tExpected
   TestAssert "FullSort: character codes, case not counting, numbers descending, a list's order, dates; FullSortList; an error", gHCScriptsTest is tExpected
   put empty into gHCScriptsTest
   send "mouseUp" to button "FullFind" of stack tStack
   put "|6,1,6,1|6,1,6,1" & return & "10,1,10,1" & return & "21,1,21,1|13,2,1,1" & return & "20,2,8,1|7,1,7,1|4,1,4,1" & return & "7,1,7,1|3,1,3,2|2,1,2,1" into tExpected
   put "|9,1,9,1|5,1,5,3|5,1,5,1|8,1,8,1|Error : Missing parameter(s)|Error : Param 3 must be true|false|Error : Incorrect param #4" after tExpected
   TestAssert "FullFind: whole words, every one, case, a start, items, a string over two lines, version 3's options, errors", gHCScriptsTest is tExpected
   put empty into gHCScriptsTest
   send "mouseUp" to button "Others" of stack tStack
   TestAssert "IsRunning, ChangeFileType, DialogDisplay with nothing to show, ListSelect's errors", gHCScriptsTest is "false|||Error : Missing Parameter(s)|Error : Bad Mode Parameter"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Options" of stack tStack
   TestAssert "ListSelect's options", gHCScriptsTest is "2|true|true|2,3|false|10,20|Pick one|Take||Geneva|12|true|11trueOKCanceltrue|30|Error : Bad Mode Parameter"
   _Close tStack
end TestHyperCardScriptsTextExternals

on TestHyperCardScriptsResourceExternals
   -- the library's FontName, available, IsFile, FileIsOpen and translit,
   -- for the externals of those names (the fonts; the stack's resources,
   -- from the import's list of its resource fork; a file there, or open;
   -- characters changed, taken out, or all but some taken out)
   local tStack, tTab, tFolder, tFile, q, tExpected
   global gHCScriptsTest
   put quote into q
   put tab into tTab
   put "HCScriptsResources" & the milliseconds into tStack
   put the tempName into tFolder
   create folder tFolder
   put tFolder & "/Notes" into tFile
   put "x" into URL ("file:" & tFile)
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["resources"] of stack tStack to _Lines("Xdna" & tTab & "128" & tTab & "40" & tTab & "Yeast", \
         "XDNA" & tTab & "129" & tTab & "40" & tTab & "Upper", "Xdna" & tTab & "130" & tTab & "40" & tTab, \
         "PICT" & tTab & "200" & tTab & "900" & tTab & "Chart", "Xdna" & tTab & "131" & tTab & "40" & tTab & "Plant")
   set the uHyperCard["file"] of stack tStack to tFolder & "/Stack"
   create button "Fonts"
   set the script of button "Fonts" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put (FontName() is replaceText(the fontNames, return, comma)) & comma into gHCScriptsTest", \
         "  put (available(" & q & "fonts" & q & ") is the fontNames) & comma after gHCScriptsTest", \
         "  if the fontNames is empty then put true after gHCScriptsTest else put available(font, line -1 of the fontNames) after gHCScriptsTest", \
         "  put comma & available(font, " & q & "No Font Called This" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "Resources"
   set the script of button "Resources" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put available(" & q & "Xdna" & q & ") & " & q & "|" & q & " & available(" & q & "pict" & q & ") & " & q & "|" & q & " & available(" & q & "types" & q & ") into gHCScriptsTest", \
         "  put " & q & "|" & q & " & available(" & q & "Xdna" & q & ", " & q & "Plant" & q & ") & " & q & "|" & q & " & available(" & q & "soun" & q & ") & " & q & "|" & q & " & available(" & q & "Xdna" & q & ", empty, " & q & "Other" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   create button "Files"
   set the script of button "Files" to _Lines("on mouseUp pFile", "  global gHCScriptsTest", \
         "  put IsFile(pFile) & comma & IsFile(pFile & " & q & "2" & q & ") & comma & IsFile(" & q & "Notes" & q & ") into gHCScriptsTest", \
         "  put comma & FileIsOpen(pFile) after gHCScriptsTest", "  open file pFile", \
         "  put comma & FileIsOpen(pFile) & comma & FileIsOpen(" & q & "Notes" & q & ") after gHCScriptsTest", "  close file pFile", \
         "  put comma & FileIsOpen(pFile) & comma & FileIsOpen(empty) after gHCScriptsTest", "end mouseUp")
   create button "Translit"
   set the script of button "Translit" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put translit(" & q & "ATGC" & q & ", " & q & "TACG" & q & ", " & q & "AATTGGCC" & q & ") into gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "atugcATUGC" & q & ", " & q & "TAACGTAACG" & q & ", " & q & "aTgx" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "m" & q & ", " & q & q & ", " & q & "mmol" & q & ") & " & q & "|" & q & " & translit(" & q & "ab" & q & ", " & q & "x" & q & ", " & q & "abc" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & length(translit(" & q & "\Aa" & q & ", " & q & q & ", " & q & "AaTGaC" & q & ")) after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "\ATUGC.N*" & q & ", " & q & " " & q & ", " & q & "AT1G-C" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "\t" & q & ", " & q & "," & q & ", " & q & "a" & q & " & tab & " & q & "b" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "\r" & q & ", " & q & q & ", " & q & "a" & q & " & return & " & q & "b" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(" & q & "\n" & q & ", " & q & q & ", " & q & "a" & q & " & numToChar(13) & return & " & q & "b" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & translit(comma, return, " & q & "a,b" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Fonts" of stack tStack
   TestAssert "FontName: the fonts, by commas; available: the fonts, and whether there is one", gHCScriptsTest is "true,true,true,false"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Resources" of stack tStack
   put "Yeast" & return & "Plant|Chart|Xdna" & return & "XDNA" & return & "PICT|true||" into tExpected
   TestAssert "available: the stack's named resources of a type, its case counting; PICT; the types; one by name; no sounds; none in a file", gHCScriptsTest is tExpected
   put empty into gHCScriptsTest
   send "mouseUp" && quote & tFile & quote to button "Files" of stack tStack
   TestAssert "IsFile and FileIsOpen, by path and by a name alone in the stack's folder", gHCScriptsTest is "true,false,true,false,true,true,false,Error : Missing or empty parameter"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Translit" of stack tStack
   put "TTAACCGG|TACx|ol|xxc|3|AT G C|a,b|ab|a" & return & "b|a" & return & "b" into tExpected
   TestAssert "translit: characters changed, its case counting, taken out, to the last of to; all but some; tab, return and line feed", gHCScriptsTest is tExpected
   _Close tStack
   delete file tFile
   delete folder tFolder
end TestHyperCardScriptsResourceExternals

on TestHyperCardScriptsFileExternals
   -- the library's Files, ResText, SystemPath and FindFolder, for the
   -- externals of those names: a folder's files and folders, here and
   -- on the disk image a stack came from; the text of the stack's
   -- resources, from its fork wherever the import found one; the System
   -- Folder and the folders in it, on the disk the stack came from
   local tStack, tImage, tFolder, q, tHFS, tText, tExpected
   global gHCScriptsTest
   put quote into q
   put the tempName into tFolder
   create folder tFolder
   create folder (tFolder & "/Sub")
   put "x" into url ("file:" & tFolder & "/Notes.txt")
   put "y" into url ("file:" & tFolder & "/Other")
   -- (beside it, what is not a resource fork)
   put "z" into url ("file:" & tFolder & "/._Other")
   put "w" into url ("file:" & tFolder & "/Other.rsrc")
   put url ("binfile:" & TestGetInputFile("hypercard/forks/Texts.macbinary")) into url ("binfile:" & tFolder & "/Texts")
   put url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack")) into url ("binfile:" & tFolder & "/Stack Two")
   put "data" into url ("binfile:" & tFolder & "/Bare")
   put url ("binfile:" & TestGetInputFile("hypercard/forks/Texts.rsrc")) into url ("binfile:" & tFolder & "/Bare.rsrc")
   put "data" into url ("binfile:" & tFolder & "/Plain")
   put url ("binfile:" & TestGetInputFile("hypercard/forks/Texts.appledouble")) into url ("binfile:" & tFolder & "/._Plain")

   put "HCScriptsFiles" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["file"] of stack tStack to tFolder & "/Texts"
   set the uHyperCard["externals"] of stack tStack to _Lines("XFCN" & tab & "Files", "XFCN" & tab & "ResText", "XFCN" & tab & "SystemPath", "XFCN" & tab & "FindFolder")
   create button "Files"
   set the script of button "Files" to _Lines("on mouseUp pPath, pTypes, pWhat", "  global gHCScriptsTest", \
         "  put Files(pPath, pTypes, pWhat) into gHCScriptsTest", "end mouseUp")
   create button "ResText"
   set the script of button "ResText" to _Lines("on mouseUp pType, pName, pThird", "  global gHCScriptsTest", \
         "  if pThird is empty then put ResText(pType, pName) into gHCScriptsTest", \
         "  else put ResText(pType, pName, pThird) into gHCScriptsTest", "end mouseUp")
   create button "Raw"
   set the script of button "Raw" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put ResText(" & q & "TEXT" & q & ", " & q & "Control" & q & ", false) into gHCScriptsTest", \
         "  put (gHCScriptsTest is (" & q & "a" & q & " & numToChar(1) & " & q & "b" & q & " & tab & " & q & "c" & q & " & numToChar(127) & " & q & "d" & q & ")) into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)

   -- Files: names, in the stack's folder where none is given or there is
   -- no such folder; 2 folders only, 3 both; the types from a MacBinary
   -- header, a stack's first block, .txt; no "._" file, no fork beside
   send "mouseUp" to button "Files" of stack tStack
   TestAssert "Files: the stack's folder's files", gHCScriptsTest is _Lines("Bare", "Notes.txt", "Other", "Plain", "Stack Two", "Texts")
   send "mouseUp empty, " & q & "STAK" & q to button "Files" of stack tStack
   TestAssert "Files: the stacks, by MacBinary and by the first block", gHCScriptsTest is _Lines("Stack Two", "Texts")
   send "mouseUp empty, " & q & "TEXT,ZZZZ" & q to button "Files" of stack tStack
   TestAssert "Files: a text file, of two types", gHCScriptsTest is "Notes.txt"
   send "mouseUp empty, empty, 2" to button "Files" of stack tStack
   TestAssert "Files: 2, the folders", gHCScriptsTest is "Sub"
   send "mouseUp empty, " & q & "STAK" & q & ", 3" to button "Files" of stack tStack
   TestAssert "Files: 3, the folders and the files", gHCScriptsTest is _Lines("Sub", "Stack Two", "Texts")
   send "mouseUp " & q & tFolder & "/Sub" & q to button "Files" of stack tStack
   TestAssert "Files: a path here, an empty folder", gHCScriptsTest is empty
   send "mouseUp " & q & "No Disk:No Folder" & q & ", " & q & "STAK" & q to button "Files" of stack tStack
   TestAssert "Files: no such folder, the stack's", gHCScriptsTest is _Lines("Stack Two", "Texts")
   if the platform is not "Win32" then
      put char 2 to -1 of tFolder into tHFS
      replace slash with colon in tHFS
      send "mouseUp " & q & tHFS & q & ", " & q & "TEXT" & q to button "Files" of stack tStack
      TestAssert "Files: the folder with colons, as the long name of HyperCard gives it", gHCScriptsTest is "Notes.txt"
   end if

   -- ResText: by name (case aside) or id; returns as returns; control
   -- characters as [code], or as they are with false; STR# a line each,
   -- or one; STR, the bytes after; hex; the errors the external gave
   put "From fairest creatures" & return & "we desire increase, " & numToCodepoint(8217) & "tis" into tText
   send "mouseUp TEXT, " & q & "Sn 1" & q to button "ResText" of stack tStack
   TestAssert "ResText: a TEXT resource by name, Mac text, its return a return", gHCScriptsTest is tText
   send "mouseUp TEXT, " & q & "sn 1" & q to button "ResText" of stack tStack
   TestAssert "ResText: a name, case aside", gHCScriptsTest is tText
   send "mouseUp TEXT, 128" to button "ResText" of stack tStack
   TestAssert "ResText: by id", gHCScriptsTest is tText
   send "mouseUp TEXT, " & q & "Control" & q to button "ResText" of stack tStack
   TestAssert "ResText: control characters as their codes", gHCScriptsTest is "a[1]b" & tab & "c" & numToCodepoint(127) & "d"
   send "mouseUp" to button "Raw" of stack tStack
   TestAssert "ResText: false, the bytes as they are", gHCScriptsTest is true
   send "mouseUp " & q & "STR#" & q & ", " & q & "Lines" & q to button "ResText" of stack tStack
   TestAssert "ResText: a list of strings (STR sharp), a string a line", gHCScriptsTest is _Lines("one", "two", "three")
   send "mouseUp " & q & "STR#" & q & ", " & q & "Lines" & q & ", " & q & "#2" & q to button "ResText" of stack tStack
   TestAssert "ResText: a list of strings (STR sharp), the second", gHCScriptsTest is "two"
   send "mouseUp " & q & "STR#" & q & ", " & q & "Lines" & q & ", " & q & "#4" & q to button "ResText" of stack tStack
   TestAssert "ResText: a list of strings (STR sharp), past the last", gHCScriptsTest is "Error : Index is out of range"
   send "mouseUp " & q & "STR#" & q & ", " & q & "Lines" & q & ", " & q & "#x" & q to button "ResText" of stack tStack
   TestAssert "ResText: a list of strings (STR sharp), not a number", gHCScriptsTest is "Error : Incorrect STR# item number"
   send "mouseUp STR, Pair" to button "ResText" of stack tStack
   TestAssert "ResText: STR (its space left out), the string and the bytes after", gHCScriptsTest is "word" & return & "rest"
   send "mouseUp TEXT, " & q & "Sn 1" & q & ", hex" to button "ResText" of stack tStack
   TestAssert "ResText: hex", char 1 to 8 of gHCScriptsTest is "46726F6D" and the number of chars of gHCScriptsTest is 94
   send "mouseUp TEXT, Nothing" to button "ResText" of stack tStack
   TestAssert "ResText: no such resource", gHCScriptsTest is "Error : Resource not found"
   send "mouseUp TEXTS, Nothing" to button "ResText" of stack tStack
   TestAssert "ResText: no such type", gHCScriptsTest is "Error : Bad resource type"
   send "mouseUp TEXT" to button "ResText" of stack tStack
   TestAssert "ResText: a parameter missing", gHCScriptsTest is "Error : Missing or empty parameter(s)"
   send "mouseUp TEXT, 128, Texts" to button "ResText" of stack tStack
   TestAssert "ResText: a file named alone, in the stack's folder", gHCScriptsTest is tText
   send "mouseUp TEXT, 128, Bare" to button "ResText" of stack tStack
   TestAssert "ResText: a fork beside its file, Name.rsrc", gHCScriptsTest is tText
   send "mouseUp TEXT, 128, Plain" to button "ResText" of stack tStack
   TestAssert "ResText: a fork beside its file, ._Name", gHCScriptsTest is tText
   send "mouseUp TEXT, 128, Other" to button "ResText" of stack tStack
   TestAssert "ResText: no resource fork, what is beside the file is none", gHCScriptsTest is "Error : No resource fork"
   send "mouseUp TEXT, 128, " & q & tFolder & "/Nothing" & q to button "ResText" of stack tStack
   TestAssert "ResText: no such file", gHCScriptsTest is "Error : File not found"
   _Close tStack

   -- on the disk image the stack came from: its folder there, folders by
   -- HFS paths, its resource fork there; the System Folder on its disk
   put TestGetInputFile("hypercard/forks/Stacks.dc42") into tImage
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["image"] of stack tStack to tImage
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Synthetic Stack"
   set the uHyperCard["externals"] of stack tStack to _Lines("XFCN" & tab & "Files", "XFCN" & tab & "ResText", "XFCN" & tab & "SystemPath", "XFCN" & tab & "FindFolder")
   create button "Files"
   set the script of button "Files" to _Lines("on mouseUp pPath, pTypes, pWhat", "  global gHCScriptsTest", \
         "  put Files(pPath, pTypes, pWhat) into gHCScriptsTest", "end mouseUp")
   create button "ResText"
   set the script of button "ResText" to _Lines("on mouseUp pType, pName, pThird", "  global gHCScriptsTest", \
         "  put ResText(pType, pName, pThird) into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   send "mouseUp" to button "Files" of stack tStack
   TestAssert "Files on the image: the stack's folder", gHCScriptsTest is "Synthetic Stack"
   send "mouseUp empty, empty, 3" to button "Files" of stack tStack
   TestAssert "Files on the image: 3, its folder and its file", gHCScriptsTest is _Lines("More", "Synthetic Stack")
   send "mouseUp " & q & "Old Disk:" & q & ", " & q & "TEXT" & q to button "Files" of stack tStack
   TestAssert "Files on the image: the disk's top folder, a type", gHCScriptsTest is "Read Me"
   send "mouseUp " & q & ":More" & q to button "Files" of stack tStack
   TestAssert "Files on the image: a folder in the stack's", gHCScriptsTest is "Lost Type"
   send "mouseUp " & q & "::" & q & ", empty, 2" to button "Files" of stack tStack
   TestAssert "Files on the image: the folder above, its folders", gHCScriptsTest is "Stacks"
   send "mouseUp XFCN, FileName, hex" to button "ResText" of stack tStack
   TestAssert "ResText on the image: the stack's resource fork", gHCScriptsTest is "4E75"
   send "mouseUp TEXT, 128, " & q & "Old Disk:Stacks:More:Lost Type" & q to button "ResText" of stack tStack
   TestAssert "ResText on the image: a file with no resource fork", gHCScriptsTest is "Error : No resource fork"
   _Close tStack

   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["image"] of stack tStack to tImage
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Synthetic Stack"
   set the uHyperCard["externals"] of stack tStack to _Lines("XFCN" & tab & "SystemPath", "XFCN" & tab & "FindFolder")
   create button "System"
   set the script of button "System" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put SystemPath(" & q & "noDialog:errGlobal" & q & ") & " & q & "|" & q & " & FindFolder() & " & q & "|" & q & " & FindFolder(" & q & "E" & q & ") into gHCScriptsTest", \
         "  put " & q & "|" & q & " & FindFolder(" & q & "pref" & q & ") & " & q & "|" & q & " & FindFolder(" & q & "d" & q & ") & " & q & "|" & q & " & FindFolder(" & q & "system folder" & q & ") after gHCScriptsTest", \
         "  put " & q & "|" & q & " & FindFolder(" & q & "zzzz" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   send "mouseUp" to button "System" of stack tStack
   put "Old Disk:System Folder:|Old Disk:System Folder:|Old Disk:System Folder:Extensions:|Old Disk:System Folder:Preferences:" \
         & "|Old Disk:Desktop Folder:|Old Disk:System Folder:|Error : Folder not found" into tExpected
   TestAssert "SystemPath and FindFolder: on the disk the stack came from, by letter, type and first letter", gHCScriptsTest is tExpected
   _Close tStack

   repeat for each line tText in files(tFolder & "/Sub")
      delete file (tFolder & "/Sub/" & tText)
   end repeat
   delete folder (tFolder & "/Sub")
   repeat for each line tText in files(tFolder)
      delete file (tFolder & "/" & tText)
   end repeat
   delete folder tFolder
end TestHyperCardScriptsFileExternals

on TestHyperCardScriptsDialogs
   -- the library's list dialogs, Promptoid and picture windows, which it
   -- makes hidden so that they are not seen being made, are shown, and a
   -- dialog waits for its answer: a timer picks, as the user would
   -- (made hidden and opened so, a dialog was not seen, and gave back at
   -- once what Cancel gives)
   local tStack, q, tTopLeft, tExpected
   global gHCScriptsTest
   put quote into q
   put "HCDialogs" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create image "Map"
   group it
   set the name of it to "HC Pictures"
   set the sharedBehavior of it to true
   create button "Driver"
   create button "At"
   unlock messages
   get revHyperCardFixScripts(tStack)
   -- (set after the fix, which leaves them as they are)
   set the script of button "Driver" of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest, ListSelectExit", \
         "  put " & q & "a" & q & " & return & " & q & "b" & q & " & return & " & q & "c" & q & " into tList", \
         "  pickLater 2, " & q & "OK" & q, \
         "  put XScrollBox(1, " & q & "Pick one" & q & ", tList) & " & q & "|" & q & " after gHCScriptsTest", \
         "  pickLater empty, " & q & "Cancel" & q, \
         "  put ShowList(tList, " & q & "Pick" & q & ") & " & q & "|" & q & " after gHCScriptsTest", \
         "  pickLater 3, " & q & "OK" & q, \
         "  put ListSelect(1, " & q & "a,b,c" & q & ") & " & q & "/" & q & " & ListSelectExit & " & q & "|" & q & " after gHCScriptsTest", \
         "  pickLater " & q & "1,2" & q & ", " & q & "OK" & q, \
         "  put ListSelect(" & q & "*2#" & q & ", " & q & "pear" & q & " & return & " & q & "apple" & q & " & return & " & q & "fig" & q & ", " & q & "Pick fruit" & q & ", " & q & "Take" & q & ", " & q & "Leave" & q & ") & " & q & "/" & q & " & ListSelectExit & " & q & "|" & q & " after gHCScriptsTest", \
         "  pickLater empty, " & q & "Escape" & q, \
         "  put ListSelect(3, " & q & "a,b,c" & q & ") & " & q & "/" & q & " & ListSelectExit & " & q & "|" & q & " after gHCScriptsTest", \
         "  pickLater 2, " & q & "Double" & q, \
         "  put ListSelect(1, " & q & "a,b,c" & q & ", " & q & "s=3" & q & ") & " & q & "/" & q & " & ListSelectExit after gHCScriptsTest", \
         "end mouseUp", \
         "on pickLater pLines, pHow", \
         "  send " & q & "pickIt" & q & " && quote & pLines & quote & comma & quote & pHow & quote to me in 300 milliseconds", \
         "end pickLater", \
         "on pickIt pLines, pHow", \
         "  global gHCScriptsTest", \
         "  local tDialog", \
         "  repeat for each line tDialog in the openStacks", \
         "    if tDialog begins with " & q & "HyperCard List" & q & " then exit repeat", \
         "  end repeat", \
         "  if not (tDialog begins with " & q & "HyperCard List" & q & ") then", \
         "    put " & q & "(no dialog)" & q & " after gHCScriptsTest", \
         "    exit pickIt", \
         "  end if", \
         "  put " & q & "(" & q & " & the mode of stack tDialog & comma & the visible of stack tDialog & comma & the hilitedLines of field " & q & "List" & q & " of stack tDialog & " & q & ")" & q & " after gHCScriptsTest", \
         "  if pHow is " & q & "At" & q & " then put " & q & "(" & q & " & the topLeft of stack tDialog & " & q & ")" & q & " after gHCScriptsTest", \
         "  try", \
         "    if pLines is not empty then set the hilitedLines of field " & q & "List" & q & " of stack tDialog to pLines", \
         "    switch pHow", \
         "      case " & q & "Cancel" & q, \
         "        send " & q & "mouseUp" & q & " to button " & q & "Cancel" & q & " of stack tDialog", \
         "        break", \
         "      case " & q & "Escape" & q, \
         "        send " & q & "escapeKey" & q & " to card 1 of stack tDialog", \
         "        break", \
         "      case " & q & "Double" & q, \
         "        send " & q & "mouseDoubleUp" & q & " to field " & q & "List" & q & " of stack tDialog", \
         "        break", \
         "      default", \
         "        send " & q & "mouseUp" & q & " to button " & q & "OK" & q & " of stack tDialog", \
         "    end switch", \
         "  catch tError", \
         "    put " & q & "(error)" & q & " after gHCScriptsTest", \
         "  end try", \
         "  -- (never left waiting)", \
         "  if there is a stack tDialog and the mode of stack tDialog is not 0 then close stack tDialog", \
         "end pickIt")
   set the script of button "At" of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  send " & q & "pickIt" && q & " & quote & 2 & quote & comma & quote & " & q & "At" & q & " & quote to button " & q & "Driver" & q & " in 300 milliseconds", \
         "  put ListSelect(1, " & q & "a,b" & q & ", " & q & "10,20" & q & ") after gHCScriptsTest", \
         "end mouseUp")

   set the defaultStack to tStack
   put empty into gHCScriptsTest
   send "mouseUp" to button "Driver" of stack tStack
   put "(5,true,1)2,b|(5,true,1)Cancel|(5,true,1)c/OK|(5,true,1)2,3/Take|(5,true,1)/Cancel|(5,true,3)b/OK" into tExpected
   TestAssert "XScrollBox, ShowList and ListSelect: a dialog shown, its first line or the one asked for hilited, that waits for OK, Cancel, Escape or a double click", gHCScriptsTest is tExpected
   set the defaultStack to tStack
   put the topLeft of stack tStack into tTopLeft
   put empty into gHCScriptsTest
   send "mouseUp" to button "At" of stack tStack
   TestAssert "ListSelect at a place: from the card window's top left", \
         gHCScriptsTest is "(5,true,1)(" & (item 1 of tTopLeft + 10) & comma & (item 2 of tTopLeft + 20) & ")b"
   TestAssert "no dialog is left", "HyperCard List" is not in the openStacks and "HyperCard List" is not in the mainStacks

   send "Promptoid" && q & "Hello" & q to button "Driver" of stack tStack
   TestAssert "Promptoid: a palette, shown, with the message", the visible of stack "Promptoid" and the mode of stack "Promptoid" is 4 and field "Message" of stack "Promptoid" is "Hello"
   hide stack "Promptoid"
   send "Promptoid" && q & "Again" & q to button "Driver" of stack tStack
   TestAssert "Promptoid: shown again with the next message", the visible of stack "Promptoid" and field "Message" of stack "Promptoid" is "Again"
   _Close "Promptoid"

   send "hcPicture" && q & "Map" & q & ", resource" to button "Driver" of stack tStack
   TestAssert "picture: a window shown", the visible of stack "Map" and the mode of stack "Map" is 1
   send "hcPicture" && q & "Map" & q & ", resource, plain, true, 1, true" to button "Driver" of stack tStack
   TestAssert "picture, floating: a palette shown", the visible of stack "Map" and the mode of stack "Map" is 4
   send "hcPicture" && q & "Map" & q & ", resource, plain, false" to button "Driver" of stack tStack
   TestAssert "picture, not visible: hidden", there is a stack "Map" and not the visible of stack "Map"
   _Close "Map"
   _Close tStack
end TestHyperCardScriptsDialogs

on TestHyperCardScriptsStartupExternals
   -- the externals stacks call as they open, as the library stands in for
   -- them: About (Hodgdon's menu items, nothing here; the help and credits
   -- of others, an answer dialog), SetFInfo, FullBalloons as tooltips, and
   -- IdleCursor, whose cursor shows only while the mouse is over one of
   -- the stack's windows (a headless engine has none), looked at by a
   -- hidden stack's timer that stops when the cursor is put back or the
   -- stack closes or goes
   local tStack, tGone, tCursorScript, q, tExpected, tError
   global gHCScriptsTest, gHCScriptsSeen
   put quote into q
   if there is a stack "Answer Dialog" then
      TestSkip "About, SetFInfo, FullBalloons and IdleCursor", "an Answer Dialog stack is already open"
      exit TestHyperCardScriptsStartupExternals
   end if
   put "HCStartup" & the milliseconds into tStack
   lock messages
   -- (answer opens the stack of this name: here one that keeps what it
   -- was asked to show, and closes)
   create invisible stack "Answer Dialog"
   set the script of stack "Answer Dialog" to _Lines("on openStack", "  global gHCScriptsSeen", \
         "  put the dialogData & numToChar(1) after gHCScriptsSeen", \
         "  set the dialogData to " & q & "OK" & q, "  close this stack", "end openStack")
   create invisible stack tStack
   set the defaultStack to tStack
   create field "Note"
   put "From a field" into field "Note"
   create button "About"
   set the script of button "About" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  About " & q & "About this stack..." & q & ", " & q & "Stack Help..." & q, \
         "  put the result & " & q & "|" & q & " into gHCScriptsTest", \
         "  About", \
         "  put the result & " & q & "|" & q & " after gHCScriptsTest", \
         "  about " & q & "Help DLOG" & q & ", " & q & "Help" & q & ", " & q & "Takes you to the Help Page." & q, \
         "  put the result & " & q & "|" & q & " after gHCScriptsTest", \
         "  About " & q & "A" & q & ", " & q & "B" & q & ", " & q & "C" & q, \
         "  SetFInfo " & q & "x" & q & ", " & q & "t=TEXT" & q & ", " & q & "c=ttxt" & q, \
         "  put the result after gHCScriptsTest", \
         "end mouseUp")
   create button "Balloon"
   set the script of button "Balloon" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  FullBalloons " & q & "isOn" & q, \
         "  put the result into gHCScriptsTest", \
         "  FullBalloons " & q & "showDirect" & q & ", " & q & "Hello" & q, \
         "  put " & q & "|" & q & " & the result & " & q & "|" & q & " & the toolTip of me after gHCScriptsTest", \
         "  FullBalloons " & q & "remove" & q, \
         "  put " & q & "|" & q & " & the toolTip of me after gHCScriptsTest", \
         "  FullBalloons " & q & "isShowing" & q, \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons " & q & "showField" & q & ", " & q & "cd fld 1" & q, \
         "  put " & q & "|" & q & " & the toolTip of me after gHCScriptsTest", \
         "  FullBalloons " & q & "Off" & q, \
         "  FullBalloons " & q & "isOn" & q, \
         "  put " & q & "|" & q & " & the toolTip of me & " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  HCBalloon " & q & "query" & q, \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons " & q & "showDirect" & q & ", " & q & "Not shown" & q, \
         "  put " & q & "|" & q & " & the toolTip of me after gHCScriptsTest", \
         "  FullBalloons " & q & "on" & q, \
         "  FullBalloons " & q & "showPICT" & q & ", 128", \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons " & q & "showDirect" & q, \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons " & q & "bogus" & q, \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons empty", \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "  FullBalloons " & q & "showField" & q & ", " & q & "cd fld 99" & q, \
         "  put " & q & "|" & q & " & the result after gHCScriptsTest", \
         "end mouseUp")
   create button "Cursor"
   put _Lines("on mouseUp pCursor", "  global gHCScriptsTest", \
         "  put the defaultCursor into tBefore", \
         "  IdleCursor pCursor", \
         "  put the result & (the defaultCursor is tBefore) into gHCScriptsTest", \
         "end mouseUp") into tCursorScript
   set the script of button "Cursor" to tCursorScript
   unlock messages
   get revHyperCardFixScripts(tStack)

   put empty into gHCScriptsTest
   put empty into gHCScriptsSeen
   send "mouseUp" to button "About" of stack tStack
   TestAssert "About and SetFInfo: nothing in the result", gHCScriptsTest is "|||"
   set the itemDelimiter to numToChar(1)
   TestAssert "About with a menu item or none: no dialog; with more, the texts in one (a DLOG's name left out)", \
         the number of items of gHCScriptsSeen is 2 \
         and (numToChar(0) & "Help" & return & "Takes you to the Help Page." & numToChar(0)) is in item 1 of gHCScriptsSeen \
         and "DLOG" is not in item 1 of gHCScriptsSeen \
         and (numToChar(0) & "A" & return & "B" & return & "C" & numToChar(0)) is in item 2 of gHCScriptsSeen
   set the itemDelimiter to comma

   put empty into gHCScriptsTest
   send "mouseUp" to button "Balloon" of stack tStack
   put "true||Hello||false|From a field||false|false||Error : Resource not found|Error : Missing balloon content parameter|Error : Bad action parameter|Error : Missing or empty parameter|Error : Bad field descriptor" into tExpected
   TestAssert "FullBalloons: on, a tooltip from the text or a field, taken away, off for HCBalloon too, errors", gHCScriptsTest is tExpected

   put empty into gHCScriptsTest
   send "mouseUp" && q & "watch" & q to button "Cursor" of stack tStack
   TestAssert "IdleCursor: with the mouse over no window of the stack, the defaultCursor stays", gHCScriptsTest is "true"
   TestAssert "IdleCursor: a cursor of the stack's own, watched by a stack that is not opened", \
         "hcIdleCursorWatch" is in the pendingMessages and there is a stack "revHyperCardIdleCursor" \
         and "revHyperCardIdleCursor" is not among the lines of the openStacks
   send "mouseUp" && q & "Hand" & q to button "Cursor" of stack tStack
   TestAssert "IdleCursor: Hand, the watch stops", _IdleCursorWatchStopped()
   send "mouseUp" && q & "cross" & q to button "Cursor" of stack tStack
   try
      close stack tStack
   catch tError
   end try
   TestAssert "IdleCursor: the stack closed, the watch stops", tError is empty and _IdleCursorWatchStopped()
   -- (deleted with messages locked, as a stack that goes when it closes is,
   -- which no handler of the library sees; a stack of its own, open as it
   -- is made, as a stack closed here may not open again in a headless
   -- engine)
   put tStack & "Gone" into tGone
   lock messages
   create invisible stack tGone
   set the defaultStack to tGone
   create button "Cursor"
   set the script of button "Cursor" to tCursorScript
   unlock messages
   get revHyperCardFixScripts(tGone)
   send "mouseUp" && q & "cross" & q to button "Cursor" of stack tGone
   put "hcIdleCursorWatch" is in the pendingMessages into tExpected
   _Close tGone
   TestAssert "IdleCursor: the stack deleted, the watch stops", tExpected and _IdleCursorWatchStopped()
   _Close tStack
   _Close "revHyperCardIdleCursor"
   _Close "Answer Dialog"
end TestHyperCardScriptsStartupExternals

-- Whether IdleCursor's watch stops, waiting with messages for it to run
-- (five times a second) for up to three seconds: a busy machine can run
-- a timer late, and macOS's CI did, more than 300 milliseconds late
private function _IdleCursorWatchStopped
   local i
   repeat with i = 1 to 30
      if "hcIdleCursorWatch" is not in the pendingMessages then return true
      wait 100 milliseconds with messages
   end repeat
   return "hcIdleCursorWatch" is not in the pendingMessages
end _IdleCursorWatchStopped

on TestHyperCardScriptsLibraryMessages
   -- HyperCard's messages sent to an object with no handler for them end
   -- in the library; the XFCNs with a plain equivalent answer
   local tStack, tError
   global gHCScriptsTest
   put "HCMessages" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Quiet"
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  send " & quote & "mouseUp" & quote & " to button " & quote & "Quiet" & quote, \
         "  send " & quote & "tabKey" & quote & " to this card", \
         "  send " & quote & "closeCard" & quote & " to this card", \
         "  put MultiFinder() & comma & FileExists(empty) & comma & (CapsLock() is among the words of " & quote & "true false" & quote & ") into gHCScriptsTest", \
         "end mouseUp")
   -- the rest of HyperCard's messages, called alone (rule T35 sends them)
   -- or sent: Script Printer's idle, SNOWBALL's resume, QuickTime Tools'
   -- resumeStack, ExerciseLog's newCard
   create field "F"
   create button "C"
   set the script of button "C" to _Lines("on mouseUp", "  idle", "  resumeStack", \
         "  send " & quote & "resume" & quote & " to this card", \
         "  send " & quote & "newCard" & quote & " to this card", \
         "  send " & quote & "closeField" & quote & " to field " & quote & "F" & quote, \
         "  send " & quote & "mouseWithin" & quote & " to button " & quote & "Quiet" & quote, \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "B" of stack tStack
   catch tError
   end try
   TestAssert "messages sent to no handler end in the library", tError is empty
   TestAssert "MultiFinder, FileExists and CapsLock answer", gHCScriptsTest is "true,false,true"
   try
      send "mouseUp" to button "C" of stack tStack
   catch tError
   end try
   TestAssert "the rest of HyperCard's messages, called alone or sent to no handler, end in the library", tError is empty
   _Close tStack
end TestHyperCardScriptsLibraryMessages

on TestHyperCardScriptsClassicLook
   -- File > Import Stack gives an imported stack HyperCard's black and
   -- white look: white cards, black text, round-rect buttons without 3-D
   -- edges, flat fields; a second call changes nothing
   local tStack
   put "HCClassic" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Standard"
   set the style of button "Standard" to "standard"
   create button "Check"
   set the style of button "Check" to "checkbox"
   create field "F"
   set the threeD of field "F" to true
   unlock messages
   revHyperCardClassicLook tStack
   TestAssert "the cards are white", the backgroundColor of stack tStack is "white"
   TestAssert "the text is black", the foregroundColor of stack tStack is "black"
   TestAssert "a standard button becomes a round rect", the style of button "Standard" of stack tStack is "roundrect"
   TestAssert "without its 3-D edge", the threeD of button "Standard" of stack tStack is false
   TestAssert "a check box stays a check box", the style of button "Check" of stack tStack is "checkbox"
   TestAssert "fields are flat", the threeD of field "F" of stack tStack is false
   TestAssert "the stack is marked", the uHyperCard["classic"] of stack tStack is true
   set the backgroundColor of stack tStack to "red"
   revHyperCardClassicLook tStack
   TestAssert "a second call changes nothing", the backgroundColor of stack tStack is "red"
   _Close tStack
end TestHyperCardScriptsClassicLook

on TestHyperCardScriptsSpeech
   -- SpeakString and Say, the speech XCMDs, end in the library
   local tStack, tError
   put "HCSpeech" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  SpeakString " & quote & "hello" & quote, \
         "  Say " & quote & "hello" & quote, "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   try
      send "mouseUp" to button "B" of stack tStack
   catch tError
   end try
   TestAssert "SpeakString and Say are handled", tError is empty
   _Close tStack
end TestHyperCardScriptsSpeech

on TestHyperCardScriptsSummary
   -- the summary File > Import Stack shows: the scripts rewritten, the
   -- handlers left out by name, and what the import log says is missing
   local tStack, tSummary, tLeft
   put "HCSummary" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Mixed"
   set the script of button "Mixed" to _Lines("on mouseUp", "  put 2 into y", "end mouseUp", "on mouseDown", "  if x then", "  put 1 into y", "end mouseDown", \
         "on mouseEnter", "  put 1 into y", "  put 1 +* into", "end mouseEnter")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put revHyperCardLeftOutHandlers() into tLeft
   TestAssert "the handler left out is listed", tLeft[1]["name"] is "mouseDown" and tLeft[1]["error"] is not empty
   put revHyperCardLeftOutLines() into tLeft
   TestAssert "the line left out is listed", tLeft[1]["name"] is "mouseEnter" and tLeft[1]["line"] is 3 \
         and tLeft[1]["text"] is "put 1 +* into" and tLeft[1]["how"] is "skipped" and tLeft[1]["error"] is not empty
   put revHyperCardImportSummary(tStack, "Not converting snd  id  9 " & quote & "Boo" & quote & ": MACE 3:1 compression" & return & "Not converting XCMD id 3 " & quote & "Ink" & quote) into tSummary
   TestAssert "the summary names the stack", line 1 of tSummary begins with tStack & ":"
   TestAssert "the summary names the handler left out", "mouseDown in button" is in tSummary
   TestAssert "the summary names the line left out", "mouseEnter in button" is in tSummary and ": put 1 +* into" is in tSummary
   TestAssert "the summary counts the MACE sound", "Sounds: 1 not converted (1 in MACE" is in tSummary
   TestAssert "the summary lists the other resources", "Resources not converted: XCMD x1" is in tSummary
   -- a sound the MACE decoder converted is no longer counted
   set the uHyperCard["mace"] of stack tStack to "9"
   put revHyperCardImportSummary(tStack, "Not converting snd  id  9 " & quote & "Boo" & quote & ": MACE 3:1 compression") into tSummary
   TestAssert "a decoded MACE sound is not counted", "Sounds:" is not in tSummary
   _Close tStack
end TestHyperCardScriptsSummary

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
   local tFirst, tSecond, tError
   global gHCScriptsTest
   put "HCFirst" & the milliseconds into tFirst
   put "HCSecond" & the milliseconds into tSecond
   lock messages
   create invisible stack tFirst
   create invisible stack tSecond
   unlock messages
   get revHyperCardFixScripts(the long id of stack tFirst)
   get revHyperCardFixScripts(the long id of stack tSecond)
   TestAssert "the first stack has its library", _Library(tFirst) is among the lines of the substacks of stack tFirst
   TestAssert "the second stack has its own library", _Library(tSecond) is among the lines of the substacks of stack tSecond
   TestAssert "the second library is marked as the library", the uHyperCard["library"] of stack _Library(tSecond) of stack tSecond is true
   TestAssert "the libraries are not left open", _Library(tFirst) is not among the lines of the openStacks and _Library(tSecond) is not among the lines of the openStacks
   -- (the engine knows a behavior by its stack's name: with one name for
   -- both, deleting the second stack took the first one's library)
   lock messages
   set the defaultStack to tFirst
   create button "B"
   set the script of button "B" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the version into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(the long id of stack tFirst)
   _Close tSecond
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "B" of stack tFirst
   catch tError
   end try
   TestAssert "the second stack deleted, the first one's library still answers", gHCScriptsTest is "2.4.1"
   _Close tFirst
   _Close tSecond
end TestHyperCardScriptsTwoImports

on TestHyperCardScriptsNumberName
   -- a stack whose name is a number (a CD's "007"): its library is made
   -- although the mainStack is set by name, and the stack keeps its name
   local tName, tStack, tError
   global gHCScriptsTest
   put "0" & (the milliseconds mod 100000) into tName
   lock messages
   create invisible stack tName
   put it into tStack
   set the defaultStack to tStack
   create button "B" in card 1 of tStack
   set the script of button "B" of card 1 of tStack to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the version into gHCScriptsTest", "end mouseUp")
   unlock messages
   try
      get revHyperCardFixScripts(tStack)
   catch tError
   end try
   TestAssert "a number as a name: no error", tError is empty
   TestAssert "a number as a name: the stack keeps it", the short name of tStack is tName
   TestAssert "a number as a name: its library", _Library(tName) is among the lines of the substacks of tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "B" of card 1 of tStack
   catch tError
   end try
   TestAssert "a number as a name: the library answers", gHCScriptsTest is "2.4.1"
   lock messages
   delete tStack
   unlock messages
end TestHyperCardScriptsNumberName

on TestHyperCardScriptsCommaName
   -- a stack whose name has commas, as HyperCard named a stack by its
   -- file ("W #8 - Dec 1, 1988"): its library, and with HyperCard's
   -- message order its menus, are made, each with a "_" for a comma, as
   -- this engine names a stack whose name is set with one
   local tFolder, tName, tStack, tError, tLibrary, tMenus
   global gHCScriptsTest
   put the temporary folder & "/hccomma" & the milliseconds into tFolder
   create folder tFolder
   put "A,B,C's" into tName
   put url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack")) into url ("binfile:" & tFolder & "/" & tName)
   lock messages
   try
      import stack from file (tFolder & "/" & tName)
   catch tError
   end try
   unlock messages
   TestAssert "a name with commas: imported", tError is empty and there is a stack tName
   if there is a stack tName then
      put the long id of stack tName into tStack
      lock messages
      set the hyperTalkCompatible of tStack to true
      set the defaultStack to tName
      create button "B" in card 1 of tStack
      set the script of button "B" of card 1 of tStack to _Lines("on mouseUp", "  global gHCScriptsTest", "  put the version into gHCScriptsTest", "end mouseUp")
      unlock messages
      put empty into tError
      try
         get revHyperCardFixScripts(tStack)
      catch tError
      end try
      TestAssert "a name with commas: no error", tError is empty
      TestAssert "a name with commas: the stack keeps it", the short name of tStack is tName
      put empty into tLibrary
      put empty into tMenus
      if the behavior of tStack is not empty then
         put the short name of the behavior of tStack into tLibrary
         if the behavior of stack tLibrary of tStack is not empty then
            put the short name of the behavior of stack tLibrary of tStack into tMenus
         end if
      end if
      TestAssert "a name with commas: its library, a _ for each comma", \
            tLibrary is "HyperCard Library (A_B_C's)" and tLibrary is among the lines of the substacks of tStack
      TestAssert "a name with commas: its menus, a _ for each comma", \
            tMenus is "HyperCard Menus (A_B_C's)" and tMenus is among the lines of the substacks of tStack
      put empty into gHCScriptsTest
      try
         send "mouseUp" to button "B" of card 1 of tStack
      catch tError
      end try
      TestAssert "a name with commas: the library answers", gHCScriptsTest is "2.4.1"
      lock messages
      delete tStack
      unlock messages
   end if
   delete file (tFolder & "/" & tName)
   delete folder tFolder
end TestHyperCardScriptsCommaName

on TestHyperCardScriptsStandIns
   -- calls to the externals stacks call most reach the library's
   -- stand-ins (those that need no dialog)
   local tStack
   global gHCScriptsTest
   put "HCStandIns" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Main"
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
   create button "Volume"
   set the script of button "Volume" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put volume(4) into gHCScriptsTest", \
         "  put comma & volume(9) & comma & SndVolume() after gHCScriptsTest", \
         "  put comma & hcHyperCardName(" & quote & "long" & quote & ") & comma & hcHyperCardName(" & quote & quote & ") after gHCScriptsTest", \
         "  put comma & objectExists(" & quote & "button " & quote & " & quote & " & quote & "Volume" & quote & " & quote) & comma & objectExists(" & quote & "button 99" & quote & ") & comma & objectExists(" & quote & "no such thing" & quote & ") after gHCScriptsTest", \
         "  put the loc of msg into tOldLoc", \
         "  set the loc of msg to 18,30", \
         "  put comma & (the visible of msg is among the words of " & quote & "true false" & quote & ") & comma & (the loc of msg is " & quote & "18,30" & quote & ") after gHCScriptsTest", \
         "  if tOldLoc is not empty then set the loc of msg to tOldLoc", \
         "  cHCcolorize", \
         "  cHCunColorize", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "B" of stack tStack
   TestAssert "MaxDepth, NewMenu, DeleteMenu, ShowMenu, HCBalloon query, Dialoger", gHCScriptsTest is "true,1,2,,HyperCard menus are not supported yet,false,The Dialoger external is not supported"
   put empty into gHCScriptsTest
   send "mouseUp" to button "Volume" of stack tStack
   TestAssert "volume and SndVolume keep the level; objectExists; the message box's properties; cHCcolorize and cHCunColorize do nothing", gHCScriptsTest is "7,4,4,Old Disk:Stacks:HyperCard,HyperCard,true,false,false,true,true"
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
   TestAssert "hcTextStyle: condense and extend by this engine's names, outline and shadow left out", \
         value("hcTextStyle(" & quote & "bold,condense,outline" & quote & ")", button "B" of stack tStack) is "bold,condensed" \
         and value("hcTextStyle(" & quote & "shadow" & quote & ")", button "B" of stack tStack) is "plain"
   TestAssert "hcWindowProperty: a window of HyperCard's own never shown", value("hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "tool" & quote & ")", button "B" of stack tStack) is false
   send "hcSetWindow " & quote & "visible" & quote & ", " & quote & "tool" & quote & ", true" to button "B" of stack tStack
   TestAssert "hcSetWindow: what a script sets reads back", value("hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "tool" & quote & ")", button "B" of stack tStack) is true
   send "hcSetCardRect 0,0,400,300" to button "B" of stack tStack
   TestAssert "hcSetCardRect: the stack's window takes the card's size", the width of stack tStack is 400 and the height of stack tStack is 300
   TestAssert "HPopUpMenu: an entry with no submenu is line,0", \
         value("hcHPopUpChoice(" & quote & "Edit" & quote & " & return & " & quote & "File,Open,Save" & quote & ", " & quote & "Edit" & quote & ")", button "B" of stack tStack) is "1,0"
   _Close tStack
end TestHyperCardScriptsStandIns

on TestHyperCardScriptsExternals
   -- the stack's external commands get stand-ins that leave a note in
   -- the result; its external functions, and the externals its scripts
   -- or the library define, get none. And doMenu "New Button" names the
   -- button as HyperCard did
   local tStack, tReport, tTab
   global gHCScriptsTest
   put "HCExternals" & the milliseconds into tStack
   put numToChar(9) into tTab
   lock messages
   create invisible stack tStack
   set the uHyperCard["externals"] of stack tStack to _Lines("XCMD" & tTab & "FPlay", "XCMD" & tTab & "PopUp", "XFCN" & tTab & "SysEnv", "XCMD" & tTab & "Mine", "XCMD" & tTab & "Two Words")
   set the script of stack tStack to _Lines("on Mine", "end Mine")
   set the defaultStack to tStack
   create button "X"
   set the script of button "X" to _Lines("on mouseUp", "  global gHCScriptsTest", "  FPlay " & quote & "boing" & quote, "  put the result into gHCScriptsTest", "end mouseUp")
   create button "N"
   set the script of button "N" to _Lines("on mouseUp", "  doMenu " & quote & "new button" & quote, "  set the name of button " & quote & "new button" & quote & " to " & quote & "Made" & quote, "end mouseUp")
   unlock messages
   put revHyperCardFixScripts(tStack) into tReport
   TestAssert "the report names the stand-ins", "do nothing when called: FPlay" & return is in tReport
   put empty into gHCScriptsTest
   send "mouseUp" to button "X" of stack tStack
   TestAssert "a stand-in: the script goes on, the result says why", gHCScriptsTest is "FPlay is not available"
   send "mouseUp" to button "N" of stack tStack
   TestAssert "doMenu New Button: the button HyperCard named", there is a button "Made" of stack tStack
   _Close tStack
end TestHyperCardScriptsExternals

on TestHyperCardScriptsImported
   -- a stack the engine imports: every script compiles afterwards, and
   -- one that compiled is unchanged
   local tStack, tReport, tLine, tObject, tFailed
   put _ImportFile("TestV1.stack", "TestV1.stack") into tStack
   put revHyperCardFixScripts(tStack) into tReport
   -- (4 scripts that did not compile; 52 that did, for "go home",
   -- "arrowKey", the cursor, "go" to another stack, by "stack" or by
   -- its name alone, doMenu, which goes to the library's hcDoMenu in a
   -- stack without HyperCard's message order, "open MacPaint" and
   -- "open the short name of the target with MacPaint", T40's, and the
   -- Help buttons' "help", T18's)
   TestAssert "TestV1: scripts rewritten", "HyperCard scripts: 56 rewritten" is in tReport
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

on TestHyperCardScriptsGoStack
   -- "go" to a stack that is not open: found beside the file the stack
   -- was imported from, or on its disk image, imported with its scripts
   -- fixed; one that cannot be found leaves the result set, not an error
   local tStack, tFolder, tError, q
   global gHCScriptsTest
   put quote into q
   put the temporary folder & "/hcgo" & the milliseconds into tFolder
   create folder tFolder
   put url ("binfile:" & TestGetInputFile("hypercard/TestV1.stack")) into url ("binfile:" & tFolder & "/Sibling")
   put "HCGo" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["file"] of stack tStack to tFolder & "/Main"
   set the defaultStack to tStack
   create button "Sibling"
   set the script of button "Sibling" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go to stack " & q & "Sibling" & q, "  put the result into gHCScriptsTest", "end mouseUp")
   create button "Missing"
   set the script of button "Missing" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go to stack " & q & "No Such HyperCard Stack" & q, "  put the result into gHCScriptsTest", "end mouseUp")
   create button "ByName"
   set the script of button "ByName" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go " & q & "Sibling" & q, "  put the result into gHCScriptsTest", "end mouseUp")
   create button "Where"
   set the script of button "Where" to _Lines("on mouseUp", "  global gHCScriptsTest", "  put " & q & "card 2" & q & " into tWhere", "  go to tWhere", "  put the number of this card into gHCScriptsTest", "  go to " & q & "No Such HyperCard Stack" & q, "  put comma & the result after gHCScriptsTest", "end mouseUp")
   create card
   go to card 1 of stack tStack
   create button "Image"
   set the script of button "Image" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go to card 1 of stack " & q & "Synthetic Stack" & q, "  put the result into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "a go to a stack, in a script that compiles, rewritten", "do hcGo(" is in the script of button "Sibling" of card 1 of stack tStack

   put "unset" into gHCScriptsTest
   try
      send "mouseUp" to button "Sibling" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "a stack beside the file: found, no error", tError is empty and gHCScriptsTest is empty and there is a stack "Sibling"
   if there is a stack "Sibling" then
      TestAssert "a stack beside the file: its scripts fixed", _Library("Sibling") is among the lines of the substacks of stack "Sibling"
      TestAssert "a stack beside the file: where it came from noted", the uHyperCard["file"] of stack "Sibling" is tFolder & "/Sibling"
   end if
   _Close "Sibling"

   put "unset" into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Missing" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "a stack that cannot be found: no error, the result set", tError is empty and gHCScriptsTest is not empty and gHCScriptsTest is not "unset"

   put "unset" into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "ByName" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "go to a stack by its name alone: found beside the file", tError is empty and gHCScriptsTest is empty and there is a stack "Sibling"
   _Close "Sibling"

   put "unset" into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Where" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "go to a card given by a variable; to a name that is no stack: no error, the result set", tError is empty and gHCScriptsTest is "2,No such card"
   go to card 1 of stack tStack

   lock messages
   set the uHyperCard["file"] of stack tStack to empty
   set the uHyperCard["image"] of stack tStack to TestGetInputFile("hypercard/forks/Stacks.dc42")
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Main"
   unlock messages
   put "unset" into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Image" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "a stack on the disk image: found, no error", tError is empty and gHCScriptsTest is empty and there is a stack "Synthetic Stack"
   if there is a stack "Synthetic Stack" then
      TestAssert "a stack on the disk image: its scripts fixed", _Library("Synthetic Stack") is among the lines of the substacks of stack "Synthetic Stack"
      TestAssert "a stack on the disk image: where it came from noted", the uHyperCard["imagepath"] of stack "Synthetic Stack" is "Old Disk:Stacks:Synthetic Stack"
   end if
   _Close "Synthetic Stack"

   _Close tStack
   delete file (tFolder & "/Sibling")
   delete folder tFolder
end TestHyperCardScriptsGoStack

on TestHyperCardScriptsNearestCopy
   -- a stack a script goes to, on the disk image the stack came from in
   -- two copies and not in its folder: the copy nearest the stack, whose
   -- folder has the most of the stack's folders, as the copy that came
   -- with it is; of copies as near, the first on the disk. Home, which
   -- HyperCard never asked for, is the first on the disk, as it was
   local tStack, tImage, tError, q, tLine, tPaths
   global gHCScriptsTest
   put quote into q
   put TestGetInputFile("hypercard/forks/Twins.hfs") into tImage
   set the itemDelimiter to tab
   repeat for each line tLine in revHyperCardImageStacks(tImage)
      put item 1 of tLine & return after tPaths
   end repeat
   set the itemDelimiter to comma
   TestAssert "two copies of each on the disk, the farther first", \
         tPaths is _Lines("Twins Disk:Archive:Home", "Twins Disk:Archive:Twin", "Twins Disk:Suite:Data:Home", "Twins Disk:Suite:Data:Twin") & return
   put "HCNearest" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["image"] of stack tStack to tImage
   set the uHyperCard["imagepath"] of stack tStack to "Twins Disk:Suite:Usage:Main"
   set the defaultStack to tStack
   create button "Twin"
   set the script of button "Twin" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go to stack " & q & "Twin" & q, "  put the result into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)

   put "unset" into gHCScriptsTest
   try
      send "mouseUp" to button "Twin" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "two copies: found, no error", tError is empty and gHCScriptsTest is empty and there is a stack "Twin"
   if there is a stack "Twin" then
      TestAssert "two copies: the one nearest the stack", the uHyperCard["imagepath"] of stack "Twin" is "Twins Disk:Suite:Data:Twin"
   end if
   _Close "Twin"

   lock messages
   set the uHyperCard["imagepath"] of stack tStack to "Twins Disk:Main"
   unlock messages
   put "unset" into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Twin" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "two copies as near: found, no error", tError is empty and gHCScriptsTest is empty and there is a stack "Twin"
   if there is a stack "Twin" then
      TestAssert "two copies as near: the first on the disk", the uHyperCard["imagepath"] of stack "Twin" is "Twins Disk:Archive:Twin"
   end if
   _Close "Twin"

   -- (only where no stack is called Home, so as not to touch another, an
   -- IDE's)
   if there is not a stack "Home" then
      lock messages
      set the uHyperCard["imagepath"] of stack tStack to "Twins Disk:Suite:Usage:Main"
      set the defaultStack to tStack
      create button "Home" in card 1 of stack tStack
      set the script of button "Home" of card 1 of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", "  go home", "  put the result into gHCScriptsTest", "end mouseUp")
      unlock messages
      get revHyperCardFixScripts(tStack)
      TestAssert "Home: go home, rewritten", "hcGoHome" is in the script of button "Home" of card 1 of stack tStack
      put "unset" into gHCScriptsTest
      put empty into tError
      try
         send "mouseUp" to button "Home" of card 1 of stack tStack
      catch tError
      end try
      TestAssert "Home: found, no error", tError is empty and gHCScriptsTest is empty and there is a stack "Home"
      if there is a stack "Home" then
         TestAssert "Home: the first on the disk, not the nearest", the uHyperCard["imagepath"] of stack "Home" is "Twins Disk:Archive:Home"
      end if
      _Close "Home"
   end if
   _Close tStack
end TestHyperCardScriptsNearestCopy

on TestHyperCardScriptsHelp
   -- T18: help, HyperCard's command for its Help stack ("help", a Help
   -- button's; 10 stacks of the corpus call it with no handler of their
   -- own, and miniM&M Utilities' menu button runs "if it is 2 then help"
   -- with an "on help" of its own), which here stopped the script with
   -- "can't find handler" where no handler took it: the library's hcHelp
   -- sends the message from the object whose script ran it, as HyperCard
   -- did, and then goes to a stack "HyperCard Help" found as a "go" finds
   -- one, or with none leaves "No such card" in the result. The library
   -- has no handler of help, so the message this engine sends for the F1
   -- and Help keys goes where it went. And T44: a message a send names by
   -- a word that is one of this engine's constants ("send help to card",
   -- Book Reporter's Guild's, which sent 15), in quotes
   local tScript, tStack, tFolder, tError, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  help", \
         "  if it is 2 then help else help -- the menu", \
         "  help " & q & "Topics" & q, \
         "  send " & q & "help" & q & " to HyperCard", \
         "  if it is 1 then send help to card else send help to hypercard", \
         "  send helpMe to card", \
         "end mouseUp") into tScript
   TestAssert "T18: help alone, sent from this object", line 2 of tScript is "  hcHelp the long id of me"
   TestAssert "T18: after then and after else", line 3 of tScript is "  if it is 2 then hcHelp the long id of me else hcHelp the long id of me -- the menu"
   TestAssert "T18: a stack's own help with a parameter: unchanged", line 4 of tScript is "  help " & q & "Topics" & q
   TestAssert "T29: help sent to HyperCard", line 5 of tScript is "  hcSendToHyperCard " & q & "help" & q
   TestAssert "T44: a message named by a constant, in quotes, after then and else", line 6 of tScript \
         is "  if it is 1 then send " & q & "help" & q & " to this card else hcSendToHyperCard " & q & "help" & q
   TestAssert "T44: a message that is no constant: unchanged", line 7 of tScript is "  send helpMe to this card"
   TestAssert "T18: those compile", _Compiles(tScript)

   -- in a stack with HyperCard's addressing, as an imported one has
   put the temporary folder & "/hchelp" & the milliseconds into tFolder
   create folder tFolder
   put "HCHelp" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["file"] of stack tStack to tFolder & "/Main"
   set the defaultStack to tStack
   create button "Help"
   set the script of button "Help" to _Lines("on mouseUp", "  global gHCScriptsTest", "  help", "  put the result after gHCScriptsTest", "end mouseUp")
   create button "Menu"
   set the script of button "Menu" to _Lines("on mouseUp", "  get 2", "  if it is 2 then help", "end mouseUp", \
         "on help", "  global gHCScriptsTest", "  put " & q & "its own" & q & " into gHCScriptsTest", "end help")
   create button "HC"
   set the script of button "HC" to _Lines("on mouseUp", "  global gHCScriptsTest", "  send " & q & "help" & q & " to HyperCard", "  put the result after gHCScriptsTest", "end mouseUp")
   create button "Send"
   set the script of button "Send" to _Lines("on mouseUp", "  send help to card", "end mouseUp")
   set the HCAddressing of stack tStack to true
   unlock messages
   get revHyperCardFixScripts(tStack)

   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Help" of stack tStack
   catch tError
   end try
   TestAssert "help with no Help stack: no error, the result set", tError is empty and gHCScriptsTest is "No such card"
   dispatch "help" to button "Help" of stack tStack
   TestAssert "help as the F1 and Help keys send it: no handler of the library's takes it", it is "unhandled"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Menu" of stack tStack
   catch tError
   end try
   TestAssert "help in a button with its own help: its own", tError is empty and gHCScriptsTest is "its own"

   set the script of stack tStack to _Lines("on help", "  global gHCScriptsTest", "  put " & q & "the stack's," & q & " after gHCScriptsTest", \
         "  return " & q & "its result" & q, "end help")
   put empty into gHCScriptsTest
   send "mouseUp" to button "Help" of stack tStack
   TestAssert "help: the stack's own handler takes it, and its result is the result", gHCScriptsTest is "the stack's,its result"
   put empty into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Send" of stack tStack
   catch tError
   end try
   TestAssert "T44: send help to card: the stack's handler", tError is empty and gHCScriptsTest is "the stack's,"
   put empty into gHCScriptsTest
   send "mouseUp" to button "HC" of stack tStack
   TestAssert "help sent to HyperCard: HyperCard's, not the stack's", gHCScriptsTest is "No such card"
   set the script of stack tStack to _Lines("on help", "  global gHCScriptsTest", "  put " & q & "the stack's," & q & " after gHCScriptsTest", "  pass help", "end help")
   put empty into gHCScriptsTest
   send "mouseUp" to button "Help" of stack tStack
   TestAssert "help: the stack's handler passes it on, to Help", gHCScriptsTest is "the stack's,No such card"
   set the script of stack tStack to empty

   put url ("binfile:" & TestGetInputFile("hypercard/TestV1.stack")) into url ("binfile:" & tFolder & "/HyperCard Help")
   put empty into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Help" of stack tStack
   catch tError
   end try
   TestAssert "help: the Help stack beside the file, imported and gone to", tError is empty and gHCScriptsTest is empty and there is a stack "HyperCard Help"
   _Close "HyperCard Help"
   _Close tStack
   delete file (tFolder & "/HyperCard Help")
   delete folder tFolder
end TestHyperCardScriptsHelp

on TestHyperCardScriptsT65
   -- T65: a stack that is not open, which HyperCard looked for where it
   -- looked for the stack of a "go" ("if there is a stack "Audio Help"
   -- then send "startSound" to stack "Audio Help"", HyperTEACH's; "if
   -- there is a stack ":Support Files:Pictoid XCMD" then", Pictoids'):
   -- here there was none until it was open, and a send to it stopped with
   -- "can't find stack". "there is a stack" goes to the library's
   -- hcThereIsStack, which imports a stack beside this one, or at a path
   -- from its folder, and is true when "stack" then names it; a send's
   -- stack to hcSendStack, which finds it as a "go" does. Home is T45's
   local tScript, tStack, tFolder, tError, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on openStack", \
         "  if there is a stack " & q & "Audio Help" & q & " then send " & q & "startSound" & q & " to stack " & q & "Audio Help" & q, \
         "  if there is not a stack (it & newName) then beep", \
         "  if there is no stack x and y then beep", \
         "  send attachIt to stack " & q & ":Support Files:Pictoid XCMD" & q, \
         "  if x then send " & q & "a" & q & " to stack " & q & "B" & q & " else send " & q & "c" & q & " to stack d", \
         "  send " & q & "startUp" & q & " to stack " & q & "Home" & q, \
         "  put " & q & "there is a stack X" & q & " into y -- send m to stack x", \
         "  send " & q & "a" & q & " to stack", \
         "  if there is a stack line i of tList then beep", \
         "  if there is a stack " & q & "Notes" & q & " & n then add 1 to n", \
         "end openStack") into tScript
   TestAssert "T65: there is a stack, and the send to it", line 2 of tScript \
         is "  if hcThereIsStack(" & q & "Audio Help" & q & ") then send " & q & "startSound" & q & " to stack hcSendStack(" & q & "Audio Help" & q & ")"
   TestAssert "T65: there is not a stack, a group in parentheses", line 3 of tScript is "  if not hcThereIsStack((it & newName)) then beep"
   TestAssert "T65: there is no stack, a variable", line 4 of tScript is "  if not hcThereIsStack(x) and y then beep"
   TestAssert "T65: a send to a path", line 5 of tScript is "  send attachIt to stack hcSendStack(" & q & ":Support Files:Pictoid XCMD" & q & ")"
   TestAssert "T65: a send after then and after else", line 6 of tScript \
         is "  if x then send " & q & "a" & q & " to stack hcSendStack(" & q & "B" & q & ") else send " & q & "c" & q & " to stack hcSendStack(d)"
   TestAssert "T65: Home, T45's", line 7 of tScript is "  send " & q & "startUp" & q & " to stack hcHome()"
   TestAssert "T65: a string, a comment, this stack: unchanged", line 8 to 9 of tScript \
         is _Lines("  put " & q & "there is a stack X" & q & " into y -- send m to stack x", "  send " & q & "a" & q & " to this stack")
   TestAssert "T65: a name that does not end the phrase: unchanged", line 10 to 11 of tScript \
         is _Lines("  if there is a stack line i of tList then beep", "  if there is a stack " & q & "Notes" & q & " & n then add 1 to n")
   TestAssert "T65: those compile", _Compiles(tScript)

   -- in a stack: a stack beside the file it was imported from
   put the temporary folder & "/hct65" & the milliseconds into tFolder
   create folder tFolder
   put url ("binfile:" & TestGetInputFile("hypercard/TestV1.stack")) into url ("binfile:" & tFolder & "/Sibling")
   put "HCT65" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["file"] of stack tStack to tFolder & "/Main"
   set the defaultStack to tStack
   create button "There"
   set the script of button "There" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put (there is a stack " & q & "No Such HyperCard Stack" & q & ") into gHCScriptsTest", \
         "  if there is a stack " & q & "Sibling" & q & " then put comma & " & q & "found" & q & " after gHCScriptsTest", \
         "end mouseUp")
   create button "Send"
   set the script of button "Send" to _Lines("on mouseUp", "  global gHCScriptsTest", "  send " & q & "dial 5551234" & q & " to stack " & q & "Sibling" & q, \
         "  put the result into gHCScriptsTest", "end mouseUp")
   create button "Missing"
   set the script of button "Missing" to _Lines("on mouseUp", "  send " & q & "dial 5551234" & q & " to stack " & q & "No Such HyperCard Stack" & q, "end mouseUp")
   create button "Image"
   set the script of button "Image" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put (there is a stack " & q & "Lost Type" & q & ") into gHCScriptsTest", \
         "  put comma & (there is a stack " & q & ":More:Lost Type" & q & ") after gHCScriptsTest", \
         "  put comma & (there is a stack " & q & "Lost Type" & q & ") after gHCScriptsTest", \
         "  put comma & (there is a stack " & q & "Synthetic Stack" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)

   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "There" of stack tStack
   catch tError
   end try
   TestAssert "T65: there is no such stack; there is the stack beside the file, imported", tError is empty \
         and gHCScriptsTest is "false,found" and there is a stack "Sibling"
   if there is a stack "Sibling" then
      TestAssert "T65: the stack beside the file: its scripts fixed", _Library("Sibling") is among the lines of the substacks of stack "Sibling"
   end if
   _Close "Sibling"

   put empty into tError
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Send" of stack tStack
   catch tError
   end try
   -- (its library's dial took the message)
   TestAssert "T65: a send to the stack beside the file: imported, the message sent", tError is empty \
         and gHCScriptsTest is "dial is not supported" and there is a stack "Sibling"
   _Close "Sibling"

   put empty into tError
   try
      send "mouseUp" to button "Missing" of stack tStack
   catch tError
   end try
   TestAssert "T65: a send to a stack found nowhere: the error, as before", tError is not empty

   -- on its disk image: the stack in its folder, and the one in a folder
   -- in it by its path from there, which "stack" then names by its name
   lock messages
   set the uHyperCard["file"] of stack tStack to empty
   set the uHyperCard["image"] of stack tStack to TestGetInputFile("hypercard/forks/Stacks.dc42")
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Main"
   unlock messages
   put empty into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Image" of stack tStack
   catch tError
   end try
   TestAssert "T65: on the disk image, not in its folder; by its path; then by its name; in its folder", tError is empty \
         and gHCScriptsTest is "false,false,true,true"
   _Close "Lost Type"
   _Close "Synthetic Stack"

   _Close tStack
   delete file (tFolder & "/Sibling")
   delete folder tFolder
end TestHyperCardScriptsT65

on TestHyperCardScriptsT66
   -- T66: an object named by the short name of another, without "the"
   -- ("go to card short name of the target", Endeavour Views the Earth's;
   -- "else show cd fld short name of me", Shakespeare's; 30 stacks of the
   -- corpus), which HyperCard took for the object of that name, as both
   -- take "card the short name of me": here "go" stayed where it was and a
   -- "show" stopped with an error. "the" before the name; a name read
   -- alone ("put short name of me into x"), which this engine reads, is
   -- left as it is
   local tScript, tStack, q, tError
   put quote into q
   put _Rewrite("on mouseUp", \
         "  go to card short name of the target", \
         "  show cd fld short name of me", \
         "  send mouseUp to bg btn abbr name of me", \
         "  go cd c of stack short name of me", \
         "  put short name of me into x", \
         "  put " & q & "card short name of me" & q & " into y -- card short name of me", \
         "end mouseUp") into tScript
   TestAssert "T66: a card, a field, a button, by a short name and an abbreviated one", line 2 to 4 of tScript \
         is _Lines("  go to card the short name of the target", "  show cd fld the short name of me", "  send mouseUp to bg btn the abbr name of me")
   TestAssert "T66: a stack, which T16 then finds", line 5 of tScript \
         is "  do hcGo(" & q & "go cd c of stack tHCStack" & q & ", " & q & "the short name of me" & q & ")"
   TestAssert "T66: a name read alone, a string, a comment: unchanged", line 6 to 7 of tScript \
         is _Lines("  put short name of me into x", "  put " & q & "card short name of me" & q & " into y -- card short name of me")
   TestAssert "T66: those compile", _Compiles(tScript)

   -- in a stack: a card and a field named as the buttons that go to them
   put "HCScriptsT66" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create card "Second"
   go to card 1 of stack tStack
   create button "Second"
   set the script of button "Second" to _Lines("on mouseUp", "  go to card short name of me", "end mouseUp")
   create field "Notes"
   hide field "Notes"
   create button "Notes"
   set the script of button "Notes" to _Lines("on mouseUp", "  show cd fld short name of me", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   try
      send "mouseUp" to button "Notes" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T66: the field of the button's name shown", tError is empty and the visible of field "Notes" of card 1 of stack tStack
   put empty into tError
   try
      send "mouseUp" to button "Second" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T66: the card of the button's name gone to", tError is empty and the short name of this card of stack tStack is "Second"
   _Close tStack
end TestHyperCardScriptsT66

on TestHyperCardScriptsT67
   -- T67: answer program, HyperCard 2.1's choice of a program on another
   -- Macintosh ("answer program "Pick a remote Hypercard to use:"", Chess
   -- Set!; "answer program "Choose a recipient:" of type "WILDep01"", HC
   -- Communications; 11 stacks of the corpus), whose choice went into it,
   -- and nothing when it was cancelled: this engine shows the prompt with
   -- an OK button and puts "OK" into it, and refuses "of type". The
   -- library's hcAnswerProgram says that no program can be chosen here,
   -- and its value, nothing, goes into it
   local tScript, tStack, q, tError
   global gHCScriptsTest, gHCScriptsSeen
   put quote into q
   put _Rewrite("on mouseUp", \
         "  answer program " & q & "Pick a remote Hypercard to use:" & q, \
         "  answer program " & q & "Choose a recipient:" & q & " of type " & q & "WILDep01" & q, \
         "  if x then answer program tPrompt & " & q & ":" & q & " else beep", \
         "  answer " & q & "program" & q & " with " & q & "OK" & q, \
         "end mouseUp") into tScript
   TestAssert "T67: answer program, with a type and without", line 2 to 3 of tScript \
         is _Lines("  get hcAnswerProgram(" & q & "Pick a remote Hypercard to use:" & q & ")", "  get hcAnswerProgram(" & q & "Choose a recipient:" & q & ")")
   TestAssert "T67: after then", line 4 of tScript is "  if x then get hcAnswerProgram(tPrompt & " & q & ":" & q & ") else beep"
   TestAssert "T67: an answer of the word program: unchanged", line 5 of tScript is "  answer " & q & "program" & q & " with " & q & "OK" & q
   TestAssert "T67: those compile", _Compiles(tScript)

   -- in a stack: the dialog, and it after it
   if there is a stack "Answer Dialog" then
      TestSkip "T67 in a stack", "an Answer Dialog stack is already open"
      exit TestHyperCardScriptsT67
   end if
   put "HCScriptsT67" & the milliseconds into tStack
   lock messages
   -- (answer opens the stack of this name: here one that keeps what it
   -- was asked to show, and closes as the Cancel button would)
   create invisible stack "Answer Dialog"
   set the script of stack "Answer Dialog" to _Lines("on openStack", "  global gHCScriptsSeen", \
         "  put the dialogData into gHCScriptsSeen", \
         "  set the dialogData to " & q & "Cancel" & q, "  close this stack", "end openStack")
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Opponent"
   set the script of button "Opponent" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "before" & q & " into it", \
         "  answer program " & q & "Pick a remote Hypercard to use:" & q, \
         "  put " & q & "[" & q & " & it & " & q & "]" & q & " into gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   put empty into gHCScriptsSeen
   try
      send "mouseUp" to button "Opponent" of stack tStack
   catch tError
   end try
   TestAssert "T67: the prompt shown, and that no program can be chosen", \
         "Pick a remote Hypercard to use:" is in gHCScriptsSeen and "No program" is in gHCScriptsSeen
   TestAssert "T67: it empty, as when the choice was cancelled", tError is empty and gHCScriptsTest is "[]"
   _Close tStack
   _Close "Answer Dialog"
end TestHyperCardScriptsT67

on TestHyperCardScriptsT68
   -- T68: the dragSpeed set to a number above this engine's highest,
   -- 65535 ("set the dragSpeed to 999999 -- fast enough for ya?", Logo's
   -- openStack), which this engine refuses, so the handler stopped there:
   -- this engine's highest. A dragSpeed it takes is left as it is
   local tScript, tStack, tError, tSpeed, q
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on openStack", \
         "  set the dragSpeed to 999999 -- fast enough for ya?", \
         "  if x then set dragSpeed to 70000 else beep", \
         "  set the dragSpeed to 200", \
         "end openStack") into tScript
   TestAssert "T68: a dragSpeed above the highest, the comment kept", line 2 of tScript is "  set the dragSpeed to 65535 -- fast enough for ya?"
   TestAssert "T68: after then", line 3 of tScript is "  if x then set dragSpeed to 65535 else beep"
   TestAssert "T68: a dragSpeed this engine takes: unchanged", line 4 of tScript is "  set the dragSpeed to 200"
   TestAssert "T68: those compile", _Compiles(tScript)

   -- in a stack
   put the dragSpeed into tSpeed
   put "HCScriptsT68" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Speed"
   set the script of button "Speed" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  set the dragSpeed to 999999", "  put " & q & "done" & q & " into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Speed" of stack tStack
   catch tError
   end try
   TestAssert "T68: the handler goes on, as fast as this engine drags", tError is empty and gHCScriptsTest is "done" and the dragSpeed is 65535
   set the dragSpeed to tSpeed
   _Close tStack
end TestHyperCardScriptsT68

on TestHyperCardScriptsT69
   -- T69: a "go" to a background without a card ("go to background
   -- "Game"", Art Game's openStack, which then hid a button of that
   -- background; "go bg i", "go next bkgnd"; 117 stacks of the corpus),
   -- which HyperCard went to the first card of, leaving "No such card" in
   -- the result when there was no such background. This engine stays on
   -- the card it is on, and then counts only that background's cards
   -- until a "go" names a card. The statement goes to the library's
   -- hcGoBackground; with more after the background, "card 1 of" goes
   -- before it. A "go" to a card of a background is left as it is
   local tScript, tStack, q, tError, tLine
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  go to background " & q & "Game" & q, \
         "  go bg i", \
         "  go to bkgnd id 2295", \
         "  go next bkgnd", \
         "  if x then go bg " & q & "A" & q & " else go last bg", \
         "  go to bg " & q & "X" & q & " of this stack", \
         "  go to card 1 of bg " & q & "Game" & q, \
         "  go to next card of this bg", \
         "  put " & q & "go bg 2" & q & " into y -- go bg 2", \
         "end mouseUp") into tScript
   TestAssert "T69: a background by its name, by a variable, by its id, by an ordinal", line 2 to 5 of tScript \
         is _Lines("  hcGoBackground " & q & "name" & q & ", " & q & "Game" & q, "  hcGoBackground " & q & "name" & q & ", i", \
         "  hcGoBackground " & q & "id" & q & ", 2295", "  hcGoBackground " & q & "next" & q)
   TestAssert "T69: after then and after else", line 6 of tScript \
         is "  if x then hcGoBackground " & q & "name" & q & ", " & q & "A" & q & " else hcGoBackground " & q & "last" & q
   TestAssert "T69: with more after the background, its card 1", line 7 of tScript is "  go to card 1 of bg " & q & "X" & q & " of this stack"
   TestAssert "T69: a card of a background, a string, a comment: unchanged", line 8 to 10 of tScript \
         is _Lines("  go to card 1 of bg " & q & "Game" & q, "  go to next card of this bg", "  put " & q & "go bg 2" & q & " into y -- go bg 2")
   TestAssert "T69: those compile", _Compiles(tScript)

   -- in a stack: card 1 has background A, cards 2 and 3 Game, card 4 A
   put "HCScriptsT69" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create group "A"
   set the backgroundBehavior of group "A" to true
   create card
   remove background "A" from this card
   create group "Game"
   set the backgroundBehavior of group "Game" to true
   create button "FirstRev" in group "Game"
   create card
   create card
   remove background "Game" from this card
   place background "A" onto this card
   go to card 1 of stack tStack
   repeat for each line tLine in "Game,go to background " & q & "Game" & q & cr & "Hide,go to background " & q & "Game" & q & "; hide bkgnd button " & q & "FirstRev" & q & cr \
         & "Nope,go bg " & q & "Nope" & q & cr & "Next,go next bkgnd" & cr & "Last,go last bg" & cr & "Id,go to bkgnd id " & the short id of background "Game"
      create button (item 1 of tLine)
      set the script of button (item 1 of tLine) to _Lines("on mouseUp", "  global gHCScriptsTest", \
            "  " & replaceText(item 2 to -1 of tLine, "; ", return & "  "), "  put the result into gHCScriptsTest", "end mouseUp")
   end repeat
   unlock messages
   get revHyperCardFixScripts(tStack)
   set the defaultStack to tStack
   -- (first, while no "go" has left this engine counting one background's
   -- cards, as one to a background does without the rule)
   put empty into tError
   try
      send "mouseUp" to button "Hide" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T69: a button of the background hidden on its card (Art Game's)", tError is empty \
         and not the visible of button "FirstRev" of card 2 of stack tStack
   repeat for each item tLine in "Game,Next,Last,Id"
      go to card 1 of stack tStack
      put "x" into gHCScriptsTest
      put empty into tError
      try
         send "mouseUp" to button tLine of card 1 of stack tStack
      catch tError
      end try
      TestAssert "T69:" && tLine & ": the background's first card, and every card counted", tError is empty and gHCScriptsTest is empty \
            and the number of this card of stack tStack is 2 and the number of cards of stack tStack is 4
   end repeat
   go to card 1 of stack tStack
   put empty into tError
   try
      send "mouseUp" to button "Nope" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T69: no such background: no such card, and the card stays", tError is empty and gHCScriptsTest is "No such card" \
         and the number of this card of stack tStack is 1 and the number of cards of stack tStack is 4
   _Close tStack
end TestHyperCardScriptsT69

on TestHyperCardScriptsT16Names
   -- T16: a go to a stack named by several words not in quotes, which
   -- HyperCard took as the text they were ("go to stack flood control";
   -- "go stack the stack you wish to process", whose "Where is ...?" asked
   -- for a stack): in quotes, where the probe finds no expression. A name
   -- that is an expression is kept
   local tStack, tTarget, q, tScript, tError
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT16" & the milliseconds into tStack
   put "HCScripts Flood Control" into tTarget
   lock messages
   create invisible stack tTarget
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Go"
   set the script of button "Go" to _Lines("on mouseUp", "  global gHCScriptsTest", "  go to stack HCScripts Flood Control", "  put the result into gHCScriptsTest", "end mouseUp")
   create button "Ask"
   set the script of button "Ask" to _Lines("on mouseUp", "  go stack the stack you wish to process", "  go to card " & q & "Player" & q & " of stack Chess Library", \
         "  go to stack short name of me", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put the script of button "Ask" of card 1 of stack tStack into tScript
   TestAssert "T16: a name of several words, in quotes", line 2 to 3 of tScript is _Lines("  do hcGo(" & q & "go stack tHCStack" & q & ", quote & " & q & "the stack you wish to process" & q & " & quote)", \
         "  do hcGo(" & q & "go to card " & q & " & quote & " & q & "Player" & q & " & quote & " & q & " of stack tHCStack" & q & ", quote & " & q & "Chess Library" & q & " & quote)")
   TestAssert "T16: an expression: kept (T66's the)", line 4 of tScript is "  do hcGo(" & q & "go to stack tHCStack" & q & ", " & q & "the short name of me" & q & ")"
   set the defaultStack to tStack
   put "none" into gHCScriptsTest
   try
      send "mouseUp" to button "Go" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T16: went to the stack named by several words", tError is empty and gHCScriptsTest is empty and the short name of this stack is tTarget
   _Close tTarget
   _Close tStack
end TestHyperCardScriptsT16Names

on TestHyperCardScriptsT70
   -- T70: quit, which was no command of HyperCard's but the message it
   -- sent as it quit: a stack's own "on quit" took it (Preschool
   -- Primer's, renamed hc_quit by T1), and HyperCard let it go if none
   -- did ("if it is "Cancel" then quit", NAIC Stack's). This engine's
   -- quit quit at once, in the IDE the IDE itself: the library's hcQuit
   local tScript, tStack, tOther, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  quit", \
         "  if it is " & q & "Cancel" & q & " then quit", \
         "  quit mouseUp", \
         "  if x then quit else beep", \
         "end mouseUp") into tScript
   TestAssert "T70: quit alone", line 2 of tScript is "  hcQuit the long id of me"
   TestAssert "T70: quit after then", line 3 of tScript is "  if it is " & q & "Cancel" & q & " then hcQuit the long id of me"
   TestAssert "T70: quit with a parameter", line 4 of tScript is "  hcQuit the long id of me, mouseUp"
   TestAssert "T70: quit before else", line 5 of tScript is "  if x then hcQuit the long id of me else beep"
   TestAssert "T70: those compile", _Compiles(tScript)

   -- the stack's own handler takes it, with its parameter
   put "HCScriptsT70" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("on quit pWhy", "  global gHCScriptsTest", \
         "  put " & q & "quit" & q & " && pWhy after gHCScriptsTest", "end quit")
   create button "Quit"
   set the script of button "Quit" to _Lines("on mouseUp", "  quit", "  quit mouseUp", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Quit" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T70: the stack's own handler takes quit", tError is empty and gHCScriptsTest is "quit quit mouseUp"

   -- and with no handler of it, nothing quits and the script goes on
   put "HCScriptsT70None" & the milliseconds into tOther
   lock messages
   create invisible stack tOther
   set the defaultStack to tOther
   create button "Cancel"
   set the script of button "Cancel" to _Lines("on mouseUp", "  global gHCScriptsTest", "  if true then quit", \
         "  put " & q & "went on" & q & " into gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tOther)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Cancel" of card 1 of stack tOther
   catch tError
   end try
   TestAssert "T70: with no handler of quit, nothing quits", tError is empty and gHCScriptsTest is "went on"
   _Close tOther
   _Close tStack
end TestHyperCardScriptsT70

on TestHyperCardScriptsT71
   -- T71: print of an expression, which HyperCard printed as its text
   -- ("print it", "print allHelp", "print "Index" & return & temp", 30
   -- corpus stacks). This engine prints cards: it stops at such a print
   -- ("error in object expression") and does not compile one of strings
   -- joined with "&". The library's hcPrint prints the text, and its
   -- hcPrintDocument a document of text that HyperCard had an
   -- application print ("print temp with "teachText"")
   local tScript, tCards, q, i
   put quote into q
   put _Rewrite("on mouseUp", \
         "  print it", \
         "  print allHelp", \
         "  print " & q & "Index" & q & " & return & recfile & return & the long date", \
         "  print (bg field id 5)", \
         "  print fld " & q & "scripter1" & q & " & return & fld " & q & "scripter2" & q, \
         "  if the number of chars of allHelp > 28800 then print allHelp", \
         "  print temp with " & q & "teachText" & q, \
         "  print thisFile with TeachText", \
         "  print the short name of this cd with GraphicsP", \
         "end mouseUp") into tScript
   TestAssert "T71: print of a variable", line 2 of tScript is "  hcPrint it"
   TestAssert "T71: print of another", line 3 of tScript is "  hcPrint allHelp"
   TestAssert "T71: print of strings joined", line 4 of tScript is "  hcPrint " & q & "Index" & q & " & return & recfile & return & the long date"
   TestAssert "T71: print of a field in parentheses", line 5 of tScript is "  hcPrint (bg field id 5)"
   TestAssert "T71: print of fields joined, which is no field alone", \
         line 6 of tScript is "  hcPrint fld " & q & "scripter1" & q & " & return & fld " & q & "scripter2" & q
   TestAssert "T71: print after then", line 7 of tScript is "  if the number of chars of allHelp > 28800 then hcPrint allHelp"
   TestAssert "T71: a document with an application", line 8 of tScript is "  hcPrintDocument temp, " & q & "teachText" & q
   TestAssert "T71: an application not in quotes", line 9 of tScript is "  hcPrintDocument thisFile, TeachText"
   TestAssert "T71: a document named by an expression", line 10 of tScript is "  hcPrintDocument the short name of this cd, GraphicsP"
   TestAssert "T71: those compile", _Compiles(tScript)

   -- unchanged: the cards this engine prints as HyperCard did, and its own
   -- forms; a field alone is T24's
   put _Lines("on mouseUp", \
         "  print card", \
         "  print this card", \
         "  print 6 cards", \
         "  print it cards", \
         "  print marked cards", \
         "  print all cds", \
         "  print cd 3", \
         "  print first card of bg " & q & "PPRINT" & q, \
         "  print this card from 0,84 to 506,1274", \
         "  print marked cards from 0,0 to 512,342", \
         "  print the next card", \
         "  print break", \
         "  print card field " & q & "Notes" & q, \
         "end mouseUp") into tCards
   put revHyperCardRewriteScript(tCards) into tScript
   repeat with i = 2 to 13
      TestAssert "T71: a card's print: unchanged:" && word 2 to -1 of line i of tCards, line i of tScript is line i of tCards
   end repeat
   TestAssert "T24: a field alone", line 14 of tScript is "  PrintField the long id of card field " & q & "Notes" & q
end TestHyperCardScriptsT71

on TestHyperCardScriptsT72
   -- T72: HyperCard's printTextFont, printTextSize, printTextHeight,
   -- printTextStyle and printTextAlign, which print of an expression
   -- printed in (T71), set and read ("set printTextFont to bg field
   -- FontName", "put the printTextFont into savedPrintFont"; 9 corpus
   -- stacks), and reset printing. This engine sets them to nothing and
   -- reads them as empty: the library's hcSetPrintText and hcPrintText,
   -- which keep them for hcPrint, and hcResetPrinting
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", \
         "  set the printTextFont to " & q & "Courier" & q, \
         "  set printtextfont to palatino", \
         "  set PrintTextSize to 24", \
         "  set printTextHeight to 32", \
         "  set the printTextStyle to bold,italic", \
         "  set the printTextAlign to right", \
         "  set the printTextFont to New York", \
         "  set printTextFont to bg field FontName", \
         "end mouseUp") into tScript
   TestAssert "T72: the printTextFont", line 2 of tScript is "  hcSetPrintText " & q & "printTextFont" & q & ", " & q & "Courier" & q
   TestAssert "T72: without the, in any case", line 3 of tScript is "  hcSetPrintText " & q & "printTextFont" & q & ", palatino"
   TestAssert "T72: the printTextSize", line 4 of tScript is "  hcSetPrintText " & q & "printTextSize" & q & ", 24"
   TestAssert "T72: the printTextHeight", line 5 of tScript is "  hcSetPrintText " & q & "printTextHeight" & q & ", 32"
   TestAssert "T72: a list of styles", line 6 of tScript is "  hcSetPrintText " & q & "printTextStyle" & q & ", bold,italic"
   TestAssert "T72: the printTextAlign", line 7 of tScript is "  hcSetPrintText " & q & "printTextAlign" & q & ", right"
   TestAssert "T72: a font of several words", line 8 of tScript is "  hcSetPrintText " & q & "printTextFont" & q & ", " & q & "New York" & q
   TestAssert "T72: a font in a field", line 9 of tScript is "  hcSetPrintText " & q & "printTextFont" & q & ", bg field FontName"
   TestAssert "T72: those compile", _Compiles(tScript)

   -- read, set to its own read, reset printing; the printMargins, which
   -- this engine has, unchanged
   put _Rewrite("on mouseUp", \
         "  put the printTextFont into savedPrintFont", \
         "  set the printTextFont to savedPrintFont", \
         "  set the printTextSize to the printTextSize + 2", \
         "  reset printing", \
         "  if x then reset printing else beep", \
         "  set PrintMargins to 50,40,40,40", \
         "  get the printMargins", \
         "end mouseUp") into tScript
   TestAssert "T72: a read", line 2 of tScript is "  put hcPrintText(" & q & "printTextFont" & q & ") into savedPrintFont"
   TestAssert "T72: set to what was read", line 3 of tScript is "  hcSetPrintText " & q & "printTextFont" & q & ", savedPrintFont"
   TestAssert "T72: set to its own read", line 4 of tScript is "  hcSetPrintText " & q & "printTextSize" & q & ", hcPrintText(" & q & "printTextSize" & q & ") + 2"
   TestAssert "T72: reset printing", line 5 of tScript is "  hcResetPrinting"
   TestAssert "T72: reset printing after then", line 6 of tScript is "  if x then hcResetPrinting else beep"
   TestAssert "T72: the printMargins set: unchanged", line 7 of tScript is "  set PrintMargins to 50,40,40,40"
   TestAssert "T72: the printMargins read: unchanged", line 8 of tScript is "  get the printMargins"
   TestAssert "T72: the reads compile", _Compiles(tScript)
end TestHyperCardScriptsT72

on TestHyperCardScriptsT71Printed
   -- T71 and T72 in a stack's scripts once fixed, printed to a PDF (never
   -- to a printer): the text of an expression on as many pages as it
   -- takes in the print text, more of them in a larger one, the defaults
   -- back after reset printing, a document of text as its text; and the
   -- scripts go on past the prints where this engine stopped at them
   TestSkipIfNot "external", "revpdfprinter"
   local tStack, q, tError, tFile, tDoc, tLong, tPages, tSized, tBig, tText, i
   global gHCScriptsTest, gHCScriptsPrintFile
   put quote into q
   put TestGetTestBuildFolder() & slash & "test-hc-print.pdf" into tFile
   put "HCScriptsT71" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   set the script of stack tStack to _Lines("function longText", "  local x, i", \
         "  repeat with i = 1 to 120", \
         "    put " & q & "Line" & q & " && i && " & q & "of the text that print printed" & q & " & return after x", \
         "  end repeat", "  return x", "end longText")
   create button "It"
   set the script of button "It" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put 1 into gHCScriptsTest", "  get " & q & "Hello" & q, "  print it", \
         "  put 2 into gHCScriptsTest", "end mouseUp")
   create button "Joined"
   set the script of button "Joined" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  print " & q & "Hello" & q & " & return & " & q & "World" & q, \
         "  put 3 into gHCScriptsTest", "end mouseUp")
   create button "Long"
   set the script of button "Long" to _Lines("on mouseUp", "  print longText()", "end mouseUp")
   create button "Sized"
   set the script of button "Sized" to _Lines("on mouseUp", "  set the printTextSize to 16", "  print longText()", "end mouseUp")
   create button "Big"
   set the script of button "Big" to _Lines("on mouseUp", "  set the printTextFont to " & q & "Courier" & q, \
         "  set printTextSize to 24", "  set printTextHeight to 32", \
         "  set the printTextStyle to bold,italic", "  set the printTextAlign to center", \
         "  print longText()", "end mouseUp")
   create button "Read"
   set the script of button "Read" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the printTextFont & comma & the printTextSize & comma & the printTextHeight & comma & the printTextStyle & comma & the printTextAlign into gHCScriptsTest", \
         "end mouseUp")
   create button "Reset"
   set the script of button "Reset" to _Lines("on mouseUp", "  reset printing", "end mouseUp")
   create button "Document"
   set the script of button "Document" to _Lines("on mouseUp", "  global gHCScriptsTest, gHCScriptsPrintFile", \
         "  print gHCScriptsPrintFile with " & q & "TeachText" & q, \
         "  put the result into gHCScriptsTest", "end mouseUp")
   create button "Missing"
   set the script of button "Missing" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  print " & q & "No such document" & q & " with TeachText", \
         "  put the result into gHCScriptsTest", "end mouseUp")
   unlock messages
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "It" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T71: as it is, it stops at the print", gHCScriptsTest is 1
   TestAssert "T71: as it is, strings joined do not compile", not _Compiles(the script of button "Joined" of card 1 of stack tStack)
   get revHyperCardFixScripts(tStack)
   TestAssert "T71: strings joined compile once fixed", _Compiles(the script of button "Joined" of card 1 of stack tStack)

   put _PrintedPages(the long id of button "It" of card 1 of stack tStack, tFile) into tPages
   TestAssert "T71: it goes on past the print, as in HyperCard", gHCScriptsTest is 2
   TestAssert "T71: a word of text on a page", tPages is 1
   put _PrintedPages(the long id of button "Joined" of card 1 of stack tStack, tFile) into tPages
   TestAssert "T71: strings joined on a page, and on past them", tPages is 1 and gHCScriptsTest is 3
   TestAssert "T71: no stack of the library's left", "revHyperCardPrint" is not in the openStacks
   TestAssert "T71: the defaultStack as it was", the short name of the defaultStack is tStack

   send "mouseUp" to button "Read" of card 1 of stack tStack
   TestAssert "T72: HyperCard's print text", gHCScriptsTest is "Geneva,10,13,plain,left"
   put _PrintedPages(the long id of button "Long" of card 1 of stack tStack, tFile) into tLong
   TestDiagnostic "120 lines in Geneva 10, 13 a line:" && tLong && "pages"
   TestAssert "T71: 120 lines on more pages than one", tLong > 1
   put _PrintedPages(the long id of button "Sized" of card 1 of stack tStack, tFile) into tSized
   send "mouseUp" to button "Read" of card 1 of stack tStack
   TestAssert "T72: a size alone, the height that follows it", gHCScriptsTest is "Geneva,16,21,plain,left"
   TestDiagnostic "in 16, 21 a line:" && tSized && "pages"
   TestAssert "T72: on more pages in a larger size", tSized > tLong
   put _PrintedPages(the long id of button "Big" of card 1 of stack tStack, tFile) into tBig
   send "mouseUp" to button "Read" of card 1 of stack tStack
   TestAssert "T72: what a script set, the styles in HyperCard's order", gHCScriptsTest is "Courier,24,32,bold,italic,center"
   TestDiagnostic "in Courier 24, 32 a line:" && tBig && "pages"
   TestAssert "T72: on more pages with taller lines", tBig > tSized
   send "mouseUp" to button "Reset" of card 1 of stack tStack
   send "mouseUp" to button "Read" of card 1 of stack tStack
   TestAssert "T72: reset printing, to HyperCard's print text", gHCScriptsTest is "Geneva,10,13,plain,left"
   put _PrintedPages(the long id of button "Long" of card 1 of stack tStack, tFile) into tPages
   TestAssert "T72: after reset printing, the pages there were", tPages is tLong

   -- a document of text, and one that is not there
   put TestGetTestBuildFolder() & slash & "test-hc-print.txt" into tDoc
   repeat with i = 1 to 120
      put "Line" && i && "of the text that print printed" & return after tText
   end repeat
   put tText into URL ("file:" & tDoc)
   put tDoc into gHCScriptsPrintFile
   put _PrintedPages(the long id of button "Document" of card 1 of stack tStack, tFile) into tPages
   TestAssert "T71: a document of text, as its text", tPages is tLong and gHCScriptsTest is empty
   put empty into gHCScriptsTest
   send "mouseUp" to button "Missing" of card 1 of stack tStack
   TestAssert "T71: a document that is not there", gHCScriptsTest is "Couldn't print that document."
   delete file tDoc
   _Close tStack
end TestHyperCardScriptsT71Printed

on TestHyperCardScriptsT73
   -- T73: ask password, which HyperCard answered with a number made from
   -- the reply, kept and compared by scripts ("if it = 2170878455", Sword
   -- Play's; 14 corpus stacks), where this engine gives the reply: the
   -- library's hcAskPassword, which puts that number into it. ask
   -- password clear, the reply as typed here too, is left as it is
   local tScript, q
   put quote into q
   put _Rewrite("on mouseUp", \
         "  ask password " & q & "Enter Password" & q, \
         "  Ask Password " & q & "Old" & q & " & " & q & " password" & q & " with " & q & "x" & q, \
         "  ask password " & q & "Please type your password below." & q & " &return \", \
         "  &" & q & "(If you have forgotten your password, see your owner's manual.)" & q, \
         "  if the hilite of me then ask password tPrompt else beep", \
         "  ask password (tPrompt) with (tDefault)", \
         "  ask password clear " & q & "Enter the password:" & q, \
         "  ask " & q & "password" & q, \
         "  ask password", \
         "end mouseUp") into tScript
   TestAssert "T73: ask password", line 2 of tScript is "  hcAskPassword it, " & q & "Enter Password" & q
   TestAssert "T73: an expression, in any case, with a reply given", \
         line 3 of tScript is "  hcAskPassword it, " & q & "Old" & q & " & " & q & " password" & q & ", " & q & "x" & q
   TestAssert "T73: continued over lines, on the first", \
         line 4 of tScript begins with "  hcAskPassword it, " & q & "Please type your password below." & q \
         and line 4 of tScript ends with "&" & q & "(If you have forgotten your password, see your owner's manual.)" & q \
         and line 5 of tScript is empty
   TestAssert "T73: after then", line 6 of tScript is "  if the hilite of me then hcAskPassword it, tPrompt else beep"
   TestAssert "T73: in parentheses", line 7 of tScript is "  hcAskPassword it, (tPrompt), (tDefault)"
   TestAssert "T73: ask password clear: unchanged", line 8 of tScript is "  ask password clear " & q & "Enter the password:" & q
   TestAssert "T73: ask of a string: unchanged", line 9 of tScript is "  ask " & q & "password" & q
   TestAssert "T73: ask password alone: unchanged", line 10 of tScript is "  ask password"
   delete line 10 of tScript
   TestAssert "T73: those compile", _Compiles(tScript)
end TestHyperCardScriptsT73

on TestHyperCardScriptsPasswords
   -- T73's hcAskPassword and hcPasswordNumber, and the stand-in for
   -- Dartmouth's Password XFCN (hcX_Password, called so by T13), in a
   -- stack's scripts once fixed. The dialog is a stand-in for the IDE's
   -- Ask Dialog, which keeps what it was asked and gives the reply in
   -- gHCScriptsReply (a nul is Cancel)
   local tStack, q, tSecret
   global gHCScriptsTest, gHCScriptsSeen, gHCScriptsReply
   put quote into q
   if there is a stack "Ask Dialog" then
      TestSkip "ask password and Password", "an Ask Dialog stack is already open"
      exit TestHyperCardScriptsPasswords
   end if
   put "HCPasswords" & the milliseconds into tStack
   lock messages
   create invisible stack "Ask Dialog"
   set the script of stack "Ask Dialog" to _Lines("on openStack", "  global gHCScriptsSeen, gHCScriptsReply", \
         "  put the dialogData & numToChar(1) after gHCScriptsSeen", \
         "  set the dialogData to gHCScriptsReply", "  close this stack", "end openStack")
   create invisible stack tStack
   set the defaultStack to tStack
   set the uHyperCard["externals"] of stack tStack to "XFCN" & tab & "Password"
   set the uHyperCard["resources"] of stack tStack to "XFCN" & tab & "17958" & tab & "2242" & tab & "Password"
   create button "Ask"
   set the script of button "Ask" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  ask password " & q & "Old Password" & q, \
         "  put it & " & q & "|" & q & " & the result into gHCScriptsTest", \
         "end mouseUp")
   create button "Dartmouth"
   set the script of button "Dartmouth" to _Lines("on mouseUp pCase", "  global gHCScriptsTest", \
         "  if pCase is empty then", \
         "    put password() into gHCScriptsTest", \
         "  else", \
         "    get password (" & q & "Type your password here!" & q & ", pCase)", \
         "    put it into gHCScriptsTest", \
         "  end if", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "the fix: hcAskPassword and hcX_Password", "hcAskPassword it," is in the script of button "Ask" of stack tStack \
         and "put hcX_Password() into" is in the script of button "Dartmouth" of stack tStack \
         and "get hcX_Password (" is in the script of button "Dartmouth" of stack tStack
   -- (set after the fix, which leaves them as they are)
   set the script of button "Ask" of stack tStack to the script of button "Ask" of stack tStack & return & _Lines("on numbers", "  global gHCScriptsTest", \
         "  put hcPasswordNumber(empty) & comma & hcPasswordNumber(" & q & "journal" & q & ") & comma & hcPasswordNumber(" & q & "JOURNAL" & q & ") into gHCScriptsTest", \
         "  put comma & hcPasswordNumber(" & q & "secret" & q & ") & comma & hcPasswordNumber(space) & comma & hcPasswordNumber(" & q & "test" & q & ") after gHCScriptsTest", \
         "  put comma & hcPasswordNumber(" & q & "debyeh" & q & " & numToCodepoint(252) & " & q & "ckel" & q & ") & comma & hcPasswordNumber(numToCodepoint(711)) after gHCScriptsTest", \
         "end numbers")

   -- the numbers stacks keep: an empty reply's ("Bill"), If Monks Had
   -- Macs' Journal's "journal", in any case, Lab Logger's "secret",
   -- Internet Local Info's space, MediaTalk's "test", BufferStack's
   -- "debyehuckel" with its accent, and a caron (255 in Mac Roman), whose
   -- seed is 0
   put empty into gHCScriptsTest
   send "numbers" to button "Ask" of stack tStack
   TestAssert "hcPasswordNumber: the numbers HyperCard gave", gHCScriptsTest is "1114205292,1342878572,1342878572,1309466871,2007844881,3932165314,3246591934,1114205292"

   set the defaultStack to tStack
   put "journal" into gHCScriptsReply
   put empty into gHCScriptsSeen
   send "mouseUp" to button "Ask" of stack tStack
   TestAssert "ask password: the reply's number in it, and the prompt shown, the reply hidden", gHCScriptsTest is "1342878572|" \
         and gHCScriptsSeen is ("ask clear" & numToChar(0) & numToChar(0) & "Old Password" & numToChar(0) & numToChar(1))
   put empty into gHCScriptsReply
   send "mouseUp" to button "Ask" of stack tStack
   TestAssert "ask password: an empty reply's number", gHCScriptsTest is "1114205292|"
   put numToChar(0) into gHCScriptsReply
   send "mouseUp" to button "Ask" of stack tStack
   TestAssert "ask password: cancelled, nothing, and Cancel in the result", gHCScriptsTest is "|Cancel"

   -- Dartmouth's: Encrypt of the reply in capitals, unless the second
   -- parameter is true; Cancel
   put "Secret" into gHCScriptsReply
   put empty into gHCScriptsSeen
   send "mouseUp" to button "Dartmouth" of stack tStack
   put gHCScriptsTest into tSecret
   send "mouseUp true" to button "Dartmouth" of stack tStack
   put comma & gHCScriptsTest after tSecret
   send "mouseUp false" to button "Dartmouth" of stack tStack
   put comma & gHCScriptsTest after tSecret
   TestAssert "Password: the reply's number in capitals (SECRET), as typed with true", tSecret is "6627,26079,6627"
   TestAssert "Password: its own prompt, and the one given", "Please enter your password:" is in gHCScriptsSeen and "Type your password here!" is in gHCScriptsSeen
   put empty into gHCScriptsReply
   send "mouseUp" to button "Dartmouth" of stack tStack
   put gHCScriptsTest into tSecret
   put numToChar(0) into gHCScriptsReply
   send "mouseUp" to button "Dartmouth" of stack tStack
   TestAssert "Password: an empty reply 0, cancelled Cancel", tSecret & comma & gHCScriptsTest is "0,Cancel"

   -- its first version, 1684 bytes: the reply as typed, nothing when
   -- cancelled
   set the uHyperCard["resources"] of stack tStack to "XFCN" & tab & "17958" & tab & "1684" & tab & "Password"
   put "Secret" into gHCScriptsReply
   send "mouseUp" to button "Dartmouth" of stack tStack
   put gHCScriptsTest into tSecret
   put numToChar(0) into gHCScriptsReply
   send "mouseUp" to button "Dartmouth" of stack tStack
   TestAssert "Password, its first version: the reply as typed, nothing when cancelled", tSecret & comma & gHCScriptsTest is "Secret,"
   _Close tStack
   _Close "Ask Dialog"
end TestHyperCardScriptsPasswords

on TestHyperCardScriptsSystemVersion
   -- T10: the systemVersion, which stacks compare with 7 ("if the
   -- systemVersion < 7 then", Finder Cleaner's), and which here is the
   -- host's ("NT 10.0", "14.5.0"), text to such a comparison: the
   -- library's hcSystemVersion(), "7.55" as HyperCard 2.2 gave System
   -- 7.5.5; value("the systemVersion") too (HyperBattleship!'s). Not in a
   -- string or a comment, nor a call of the stack's own function
   local tScript, tStack, q, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  if the systemVersion < 7 then beep", \
         "  if ((the SystemVersion)>=7) then beep", \
         "  put systemVersion() into x", \
         "  if (value (" & q & "the systemVersion" & q & ") < 7 ) then beep", \
         "  put " & q & "the systemVersion" & q & " into x -- the systemVersion", \
         "end mouseUp") into tScript
   TestAssert "T10: the systemVersion", line 2 of tScript is "  if hcSystemVersion() < 7 then beep"
   TestAssert "T10: the systemVersion in parentheses, in any case", line 3 of tScript is "  if ((hcSystemVersion())>=7) then beep"
   TestAssert "T10: systemVersion()", line 4 of tScript is "  put hcSystemVersion() into x"
   TestAssert "T10: value of the systemVersion", line 5 of tScript is "  if (hcSystemVersion() < 7 ) then beep"
   TestAssert "T10: the systemVersion in a string and a comment, as it is", line 6 of tScript is "  put " & q & "the systemVersion" & q & " into x -- the systemVersion"
   TestAssert "T10: those compile", _Compiles(tScript)
   put _Rewrite("on mouseUp", "  put systemVersion() into x", "  put the systemVersion into y", "end mouseUp", \
         "function systemVersion", "  return 6", "end systemVersion") into tScript
   TestAssert "T10: the stack's own systemVersion function, called with parentheses; the systemVersion, HyperCard's", \
         line 2 of tScript is "  put hc_systemversion() into x" and line 3 of tScript is "  put hcSystemVersion() into y"

   put "HCSystemVersion" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "System"
   set the script of button "System" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put the systemVersion into gHCScriptsTest", \
         "  if the systemVersion < 7 then put comma & " & q & "System 6" & q & " after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "System" of stack tStack
   catch tError
   end try
   TestAssert "T10: HyperCard's systemVersion for System 7.5.5, and so System 7", gHCScriptsTest is "7.55"
   _Close tStack
end TestHyperCardScriptsSystemVersion

on TestHyperCardScriptsSystemExternals
   -- the stand-ins for the externals that ask about the Mac, as their
   -- code gives the Mac the library describes (System 7.5.5, a model the
   -- externals do not know, a 68040 and its coprocessor, Color
   -- QuickDraw, an Apple Extended Keyboard, no AppleTalk): SysEnv (The
   -- Critical Eye, Doctor Who), the SysEnvirons function (Stack Starter)
   -- and command (CoinMaster) and MacType (Scan Calculator, GetDInfo)
   local tStack, tTab, q, tError, tReport
   global gHCScriptsTest
   put quote into q
   put numToChar(9) into tTab
   put "HCSystemExternals" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the uHyperCard["imagepath"] of stack tStack to "Old Disk:Stacks:Main"
   set the uHyperCard["externals"] of stack tStack to _Lines("XFCN" & tTab & "SysEnv", "XCMD" & tTab & "SysEnvirons", "XFCN" & tTab & "MacType")
   set the uHyperCard["resources"] of stack tStack to _Lines("XFCN" & tTab & "1" & tTab & "2722" & tTab & "SysEnv", \
         "XCMD" & tTab & "926" & tTab & "3486" & tTab & "SysEnvirons", "XFCN" & tTab & "816" & tTab & "2704" & tTab & "MacType")
   set the defaultStack to tStack
   create button "SysEnv"
   set the script of button "SysEnv" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put SysEnv() into gHCScriptsTest", \
         "  put return & SysEnv(1) after gHCScriptsTest", \
         "end mouseUp")
   create button "Fields"
   set the script of button "Fields" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  repeat with i = 1 to 9", \
         "    put SysEnvirons(i) & comma after gHCScriptsTest", \
         "  end repeat", \
         "  put SysEnvirons(" & q & "x" & q & ") & comma & SysEnvirons(10) after gHCScriptsTest", \
         "end mouseUp")
   create button "Globals"
   set the script of button "Globals" to _Lines("on mouseUp", \
         "  global machineType, systemVersion, processor, hasFPU, hasColorQD", \
         "  global atDrvrVersNum, keyBoardType, systemFolder, gHCScriptsTest", \
         "  SysEnvirons", \
         "  put machineType & " & q & "|" & q & " & systemVersion & " & q & "|" & q & " & processor & " & q & "|" & q & " & hasFPU into gHCScriptsTest", \
         "  put " & q & "|" & q & " & hasColorQD & " & q & "|" & q & " & atDrvrVersNum & " & q & "|" & q & " & keyBoardType & " & q & "|" & q & " & systemFolder after gHCScriptsTest", \
         "end mouseUp")
   create button "MacType"
   set the script of button "MacType" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put MacType() & " & q & "|" & q & " & MacType(" & q & "?" & q & ") & " & q & "|" & q & " & MacType(" & q & "=" & q & ") & " & q & "|" & q & " & MacType(" & q & "!" & q & ") into gHCScriptsTest", \
         "  get item 2 of MacType()", \
         "  delete last char of it", \
         "  delete last char of it", \
         "  if it < 7.0", \
         "  then put 2 into FNb", \
         "  else put 3 into FNb", \
         "  put " & q & "|" & q & " & FNb after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   put revHyperCardFixScripts(tStack) into tReport
   TestAssert "the fix: no stand-in for the SysEnvirons command, the library's", "do nothing when called" is not in tReport

   set the defaultStack to tStack
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "SysEnv" of stack tStack
   catch tError
   end try
   TestAssert "SysEnv: the Mac as its line, the minor version times 16, then the screen's depth and colour; a parameter refused", \
         gHCScriptsTest is "unknown,7.80.5,Motorola 68040,true,true,Apple Extended keyboard,0,-1" & return & the screenDepth & ",Color" \
         & return & "SysEnv expects no parameters."
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Fields" of stack tStack
   catch tError
   end try
   TestAssert "SysEnvirons(n): each field of the record, any other parameter as it is", gHCScriptsTest is "1,0,0755,5,true,true,4,0,-1,x,10"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Globals" of stack tStack
   catch tError
   end try
   TestAssert "SysEnvirons: the record in the script's globals, the System Folder on HyperCard's disk", \
         gHCScriptsTest is "Unknown Machine|7.5.5|68040|true|true|0|Extended ADB Keyboard|Old Disk:System Folder:"
   set the uHyperCard["resources"] of stack tStack to "XCMD" & tTab & "926" & tTab & "3190" & tTab & "SysEnvirons"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Globals" of stack tStack
   catch tError
   end try
   TestAssert "SysEnvirons, its later version: the System's name for the model, none", char 1 to 7 of gHCScriptsTest is "|7.5.5|"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "MacType" of stack tStack
   catch tError
   end try
   TestAssert "MacType: the Mac, its syntax, what it gives, its version; the System for 7.0 and later (GetDInfo's)", \
         gHCScriptsTest is "Unknown CPU,7.5.5,MC68040,true,true,Apple Extended keyboard|MacType()|<CPU>,<System>,<Processor>,<HasFPU>,<HasColorQD>,<keyboard>|Version 1.3," \
         && numToCodepoint(169) && "Frederic RINALDI 1989,1990,1991|3"
   _Close tStack
end TestHyperCardScriptsSystemExternals

on TestHyperCardScriptsT74
   -- T74: a loop that takes a path back to its folder until its last
   -- character is a colon, which HyperCard's paths always had and this
   -- engine's never have ("repeat until the last char of it is ":"", Star
   -- Trek-DS9 Guide's, on the stack's long name): it ends when the text
   -- is empty too. A loop with another way out, another line, or another
   -- text, is left as it is
   local tScript, q, tStack, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  get the long name of this stack", \
         "  repeat until the last char of it is " & q & ":" & q, \
         "    delete the last char of it", \
         "  end repeat", \
         "  repeat while last char of TEMP is not " & q & ":" & q & " -- the folder", \
         "    delete last char of TEMP", \
         "  end repeat", \
         "  Repeat While Last Char Of it <> " & q & ":" & q, \
         "    get char 1 to length(it)-1 of it", \
         "  end repeat", \
         "  repeat until char length (PathName) of PathName = " & q & ":" & q, \
         "    delete char length (PathName) of PathName", \
         "  end repeat", \
         "  put " & q & q & " into lastChar", \
         "  repeat until lastChar = " & q & ":" & q, \
         "    delete last character of stackFolder", \
         "    put last character of stackFolder into lastChar", \
         "  end repeat", \
         "  repeat until it is " & q & ":" & q, \
         "    get the last char of process", \
         "    if it is not " & q & ":" & q & " then put it before char 1 of holdPictName", \
         "    -- (and so on)", \
         "    delete the last char of process", \
         "  end repeat", \
         "  repeat until last char of pref is " & q & ":" & q & " or pref is empty", \
         "    delete last char of pref", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & "/" & q, \
         "    delete the last char of x", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & ":" & q, \
         "    delete the last char of x", \
         "    add 1 to n", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & ":" & q, \
         "    delete the last char of y", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & ":" & q, \
         "    delete the last char of x", \
         "    put y into x", \
         "  end repeat", \
         "  repeat until lastChar is " & q & ":" & q, \
         "    delete the last char of x", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & ":" & q, \
         "    if x is empty then exit repeat", \
         "    delete the last char of x", \
         "  end repeat", \
         "  repeat until the last char of x is " & q & ":" & q, \
         "    delete the last char of x", \
         "    put shortName(x) after tNames", \
         "  end repeat", \
         "end mouseUp") into tScript
   TestAssert "T74: until, the last char of it", line 3 of tScript is "  repeat until the last char of it is " & q & ":" & q & " or it is empty"
   TestAssert "T74: while, a comment kept at the end", \
         line 6 of tScript is "  repeat while last char of TEMP is not " & q & ":" & q & " and TEMP is not empty -- the folder"
   TestAssert "T74: <>, in any case, and get of all but the last char", \
         line 9 of tScript is "  Repeat While Last Char Of it <> " & q & ":" & q & " and it is not empty"
   TestAssert "T74: char length (x) of x", \
         line 12 of tScript is "  repeat until char length (PathName) of PathName = " & q & ":" & q & " or PathName is empty"
   TestAssert "T74: a variable the last character is put into", \
         line 16 of tScript is "  repeat until lastChar = " & q & ":" & q & " or stackFolder is empty"
   TestAssert "T74: got into it, and put before another variable after then", \
         line 20 of tScript is "  repeat until it is " & q & ":" & q & " or process is empty"
   TestAssert "T74: a loop that ends on empty already, unchanged", \
         line 26 of tScript is "  repeat until last char of pref is " & q & ":" & q & " or pref is empty"
   TestAssert "T74: a loop for another character, unchanged", line 29 of tScript is "  repeat until the last char of x is " & q & "/" & q
   TestAssert "T74: a loop with another statement, unchanged", line 32 of tScript is "  repeat until the last char of x is " & q & ":" & q
   TestAssert "T74: a loop that deletes from another variable, unchanged", line 36 of tScript is "  repeat until the last char of x is " & q & ":" & q
   TestAssert "T74: a loop that puts into the text, unchanged", line 39 of tScript is "  repeat until the last char of x is " & q & ":" & q
   TestAssert "T74: a loop on a variable nothing puts into, unchanged", line 43 of tScript is "  repeat until lastChar is " & q & ":" & q
   TestAssert "T74: a loop with an exit, unchanged", line 46 of tScript is "  repeat until the last char of x is " & q & ":" & q
   TestAssert "T74: a loop that calls a handler, unchanged", line 50 of tScript is "  repeat until the last char of x is " & q & ":" & q
   TestAssert "T74: those compile", _Compiles(tScript)

   -- In a script that compiles as it is, run: a path with colons gives
   -- its folder, as in HyperCard, and one without gives none, and ends
   put "HCColonLoops" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Folder"
   set the script of button "Folder" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put folderOf(" & q & "Disk:Folder:Stack" & q & ") & " & q & "|" & q & " & folderOf(" & q & "/Users/me/Stack" & q & ") into gHCScriptsTest", \
         "end mouseUp", \
         "function folderOf pPath", \
         "  get pPath", \
         "  repeat until the last char of it is " & q & ":" & q, \
         "    delete the last char of it", \
         "  end repeat", \
         "  return it", \
         "end folderOf")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put line 7 of the script of button "Folder" of stack tStack into tScript
   TestAssert "T74: in a script that compiles too", tScript is "  repeat until the last char of it is " & q & ":" & q & " or it is empty"
   -- (without it the loop would not end)
   if tScript ends with "or it is empty" then
      put empty into gHCScriptsTest
      try
         send "mouseUp" to button "Folder" of stack tStack
      catch tError
      end try
      TestAssert "T74: the folder of a path with colons, and none of one without", gHCScriptsTest is "Disk:Folder:|"
   end if
   _Close tStack
end TestHyperCardScriptsT74

on TestHyperCardScriptsT74Repeat
   -- T74: a loop with no condition that waits for the colon in an if of
   -- its own (Script Manager's folderName, the HyperTextBooks' button that
   -- reads text files, Gophers Helper's head()): "until <text> is empty"
   -- in its head. A loop that could leave with the text empty, or does
   -- anything more, is left as it is
   local tScript, q, tStack, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  repeat", \
         "    if last char of pathName is " & q & ":" & q & " then exit repeat", \
         "    delete last char of pathName", \
         "  end repeat", \
         "  repeat", \
         "    if last char of manx <> " & q & ":" & q & " then delete last char of manx", \
         "    else", \
         "      delete last char of manx", \
         "      exit repeat", \
         "    end if", \
         "  end repeat", \
         "  Repeat Forever -- to the folder", \
         "    delete the last character of r", \
         "    if the last character of r = " & q & ":" & q & " then", \
         "      return r", \
         "    end if", \
         "  end repeat", \
         "  repeat", \
         "    if last char of x is " & q & ":" & q & " then exit mouseUp", \
         "    if x is " & q & "Disk" & q & " then put 1 into y", \
         "    delete last char of x", \
         "  end repeat", \
         "  repeat", \
         "    if last char of x is not " & q & ":" & q & " then exit repeat", \
         "    delete last char of x", \
         "  end repeat", \
         "  repeat", \
         "    if last char of x is " & q & ":" & q & " then exit repeat", \
         "    delete last char of x", \
         "    add 1 to n", \
         "  end repeat", \
         "  repeat", \
         "    if last char of x is " & q & ":" & q & " then exit repeat", \
         "    delete last char of y", \
         "  end repeat", \
         "  repeat", \
         "    if last char of x is " & q & ":" & q & " then exit repeat", \
         "    delete last char of x", \
         "    put y into x", \
         "  end repeat", \
         "  repeat", \
         "    delete last char of x", \
         "    if last char of x is " & q & ":" & q & " then put x into y", \
         "  end repeat", \
         "  repeat", \
         "    exit repeat", \
         "    delete last char of x", \
         "    if last char of x is " & q & ":" & q & " then put x into y", \
         "  end repeat", \
         "  repeat while x is not empty", \
         "    if last char of x is " & q & ":" & q & " then exit repeat", \
         "    delete last char of x", \
         "  end repeat", \
         "end mouseUp") into tScript
   TestAssert "T74 repeat: an exit at the colon, then the delete", line 2 of tScript is "  repeat until pathName is empty"
   TestAssert "T74 repeat: <>, a delete after then, and the exit after else", line 6 of tScript is "  repeat until manx is empty"
   TestAssert "T74 repeat: forever, in any case, the delete first, and a return; a comment kept", \
         line 13 of tScript is "  Repeat until r is empty -- to the folder"
   TestAssert "T74 repeat: exit from the handler, and a put into another variable", line 19 of tScript is "  repeat until x is empty"
   TestAssert "T74 repeat: an exit where there is no colon, unchanged", line 24 of tScript is "  repeat"
   TestAssert "T74 repeat: another statement, unchanged", line 28 of tScript is "  repeat"
   TestAssert "T74 repeat: a delete from another variable, unchanged", line 33 of tScript is "  repeat"
   TestAssert "T74 repeat: a put into the text, unchanged", line 37 of tScript is "  repeat"
   TestAssert "T74 repeat: no exit, unchanged", line 42 of tScript is "  repeat"
   TestAssert "T74 repeat: an exit that is not in the if, unchanged", line 46 of tScript is "  repeat"
   TestAssert "T74 repeat: a loop with a condition, unchanged", line 51 of tScript is "  repeat while x is not empty"
   TestAssert "T74 repeat: those compile", _Compiles(tScript)

   -- In a script that compiles as it is, run: a path with colons gives
   -- its folder, as in HyperCard, and one without gives none, and ends
   put "HCColonRepeats" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create button "Folder"
   set the script of button "Folder" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put folderName(" & q & "Disk:Folder:Stack" & q & ") & " & q & "|" & q & " & folderName(" & q & "/Users/me/Stack" & q & ") & " & q & "|" & q & \
         " & head(" & q & "Disk:Folder:Stack" & q & ") & " & q & "|" & q & " & head(" & q & "/Users/me/Stack" & q & ") into gHCScriptsTest", \
         "end mouseUp", \
         "function folderName pPath", \
         "  repeat", \
         "    if last char of pPath is " & q & ":" & q & " then exit repeat", \
         "    delete last char of pPath", \
         "  end repeat", \
         "  delete last char of pPath", \
         "  return pPath", \
         "end folderName", \
         "function head r", \
         "  repeat forever", \
         "    delete last char of r", \
         "    if last char of r is " & q & ":" & q & " then", \
         "      return r", \
         "    end if", \
         "  end repeat", \
         "end head")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put line 6 of the script of button "Folder" of stack tStack into tScript
   put return & line 14 of the script of button "Folder" of stack tStack after tScript
   TestAssert "T74 repeat: in a script that compiles too", \
         tScript is "  repeat until pPath is empty" & return & "  repeat until r is empty"
   -- (without it the loops would not end)
   if tScript is "  repeat until pPath is empty" & return & "  repeat until r is empty" then
      put empty into gHCScriptsTest
      try
         send "mouseUp" to button "Folder" of stack tStack
      catch tError
      end try
      TestAssert "T74 repeat: the folder of a path with colons, and none of one without", gHCScriptsTest is "Disk:Folder||Disk:Folder:|"
   end if
   _Close tStack
end TestHyperCardScriptsT74Repeat

on TestHyperCardScriptsT76
   -- T76: a card numbered by a sum or a difference not in parentheses,
   -- after "of" ("put field "Season" of card it-1 into numSeasons", the
   -- Star Trek guides' openStack), which HyperCard took for the card the
   -- sum numbers, and this engine, in a script that compiles as it is,
   -- for the card of the first number, adding to the value of what it
   -- names: the sum in parentheses. A sum that goes on, an operator that
   -- binds tighter, "&", a word that is no variable's, and a card by id,
   -- are left as they are
   local tScript, q, tStack, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on mouseUp", \
         "  get the number of cards of this stack", \
         "  put field " & q & "Season" & q & " of card it-1 into numSeasons", \
         "  put 2 into i", \
         "  set name of btn i to short name of cd i-1", \
         "  put item 1 of fld 2 of cd i+1 into n1", \
         "  get the short name of card i + 1 of bkgnd " & q & "Saved" & q, \
         "  if field 1 of card i+1 is empty then beep", \
         "  put field 1 of card i+1 & return after n1", \
         "end mouseUp") into tScript
   TestAssert "T76: it-1, before into", line 3 of tScript is "  put field " & q & "Season" & q & " of card (it-1) into numSeasons"
   TestAssert "T76: at the end of the statement", line 5 of tScript is "  set name of btn i to short name of cd (i-1)"
   TestAssert "T76: a chunk of a field", line 6 of tScript is "  put item 1 of fld 2 of cd (i+1) into n1"
   TestAssert "T76: before of a background", line 7 of tScript is "  get the short name of card (i + 1) of bkgnd " & q & "Saved" & q
   TestAssert "T76: before is", line 8 of tScript is "  if field 1 of card (i+1) is empty then beep"
   TestAssert "T76: before &", line 9 of tScript is "  put field 1 of card (i+1) & return after n1"
   TestAssert "T76: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", \
         "  put 2 into x", \
         "  put field 1 of card x + 1 * 2 into y", \
         "  put field 1 of card x + 1 + 1 into y", \
         "  put field 1 of card " & q & "a" & q & " & x into y", \
         "  put the number of card buttons + 1 into y", \
         "  put field 1 of card id x + 1 into y", \
         "  put field 1 of card x - length(y) into y", \
         "  put field 1 of card x + the number of lines of y into y", \
         "end mouseUp") into tScript
   TestAssert "T76: left as they are", line 3 to 9 of tScript is _Lines("  put field 1 of card x + 1 * 2 into y", \
         "  put field 1 of card x + 1 + 1 into y", "  put field 1 of card " & q & "a" & q & " & x into y", \
         "  put the number of card buttons + 1 into y", "  put field 1 of card id x + 1 into y", \
         "  put field 1 of card x - length(y) into y", "  put field 1 of card x + the number of lines of y into y")

   -- in a stack of three cards, whose field f holds A, B and C
   put "HCScriptsT76" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create field "f"
   put "A" into field "f"
   create card
   create field "f"
   put "B" into field "f"
   create card
   create field "f"
   put "C" into field "f"
   go to card 1
   create button "Cards"
   set the script of button "Cards" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  get the number of cards of this stack", \
         "  put field " & q & "f" & q & " of card it-1 into gHCScriptsTest", \
         "  put 1 into x", \
         "  put comma & field " & q & "f" & q & " of cd x+1 after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   put empty into tError
   try
      send "mouseUp" to button "Cards" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T76: the cards the sums number", tError is empty and gHCScriptsTest is "B,B"
   _Close tStack
end TestHyperCardScriptsT76

on TestHyperCardScriptsT75
   -- T75: a select of the object or the chunk a value names, in
   -- parentheses or from a function of the stack, which HyperCard
   -- selected ("select (theLine)", the Guide to XCMDs' arrow keys, after
   -- "add 1 to word 2 of theLine"; "select after text of fieldData()",
   -- WB2D's) and this engine's select refuses: "do" with the statement and
   -- the value after it. A select it takes is left as it is
   local tScript, q, tStack, tError
   global gHCScriptsTest
   put quote into q
   put _Rewrite("on arr what", \
         "  put the selectedLine into theLine", \
         "  add 1 to word 2 of theLine", \
         "  select (theLine)", \
         "  if what is 1 then select after (theLine)", \
         "  select fieldData()", \
         "  select after text of fieldData()", \
         "  Select Before Text Of fieldData() -- the start", \
         "  select selectedLine()", \
         "  select foundLine()", \
         "  select fld (theName)", \
         "  select text of fld (theName)", \
         "  select line 2 of fld 1", \
         "  select theLine", \
         "  select " & q & q, \
         "end arr", \
         "function fieldData", \
         "  return " & q & "card field id 13" & q, \
         "end fieldData", \
         "function selectedLine", \
         "  return " & q & "line 1 of card field 1" & q, \
         "end selectedLine") into tScript
   TestAssert "T75: a value in parentheses", line 4 of tScript is "  do " & q & "select" & q & " && (theLine)"
   TestAssert "T75: after then, with after", line 5 of tScript is "  if what is 1 then do " & q & "select after" & q & " && (theLine)"
   TestAssert "T75: a function of the stack", line 6 of tScript is "  do " & q & "select" & q & " && fieldData()"
   TestAssert "T75: after text of a function of the stack", line 7 of tScript is "  do " & q & "select after text of" & q & " && fieldData()"
   TestAssert "T75: in any case, a comment kept", line 8 of tScript is "  do " & q & "Select Before Text Of" & q & " && fieldData() -- the start"
   TestAssert "T75: a function of the stack T62 renames", line 9 of tScript is "  do " & q & "select" & q & " && hc_selectedline()" \
         and line 20 of tScript is "function hc_selectedline"
   TestAssert "T75: one of this engine's functions, unchanged", line 10 of tScript is "  select foundLine()"
   TestAssert "T75: a field named by a value, unchanged", line 11 of tScript is "  select fld (theName)"
   TestAssert "T75: the text of a field named by a value, unchanged", line 12 of tScript is "  select text of fld (theName)"
   TestAssert "T75: a chunk, unchanged", line 13 of tScript is "  select line 2 of fld 1"
   TestAssert "T75: a variable, unchanged", line 14 of tScript is "  select theLine"
   TestAssert "T75: select " & q & q & ", T34's", line 15 of tScript is "  select empty"
   TestAssert "T75: those compile", _Compiles(tScript)

   put _Rewrite("on mouseUp", \
         "  select (theLine) & x", \
         "  select other()", \
         "  select (a) of (b)", \
         "end mouseUp") into tScript
   TestAssert "T75: more than a value, unchanged", line 2 of tScript is "  select (theLine) & x"
   TestAssert "T75: a call of no function of the stack, unchanged", line 3 of tScript is "  select other()"
   TestAssert "T75: a value with more after it, unchanged", line 4 of tScript is "  select (a) of (b)"

   -- Fixed by revHyperCardFixScripts and run: the line after the one
   -- selected, as the arrow key went to in HyperCard, then the end of the
   -- text of the field the function names
   put "HCSelectValue" & the milliseconds into tStack
   lock messages
   create stack tStack
   set the defaultStack to tStack
   create field "List"
   put _Lines("one", "two", "three") into field "List"
   create field "Notes"
   put "Notes" into field "Notes"
   create button "Down"
   set the script of button "Down" to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  select line 1 of card field " & q & "List" & q, \
         "  put the selectedLine into theLine", \
         "  add 1 to word 2 of theLine", \
         "  select (theLine)", \
         "  put the selectedText into gHCScriptsTest", \
         "  select after text of fieldData()", \
         "  put " & q & "|" & q & " & word 1 to 4 of the selectedChunk & " & q & "|" & q & " & the short name of the selectedField after gHCScriptsTest", \
         "  select empty", \
         "end mouseUp", \
         "function fieldData", \
         "  return " & q & "card field " & q & " & quote & " & q & "Notes" & q & " & quote", \
         "end fieldData")
   unlock messages
   get revHyperCardFixScripts(tStack)
   TestAssert "T75: in a stack fixed", line 6 of the script of button "Down" of stack tStack is "  do " & q & "select" & q & " && (theLine)"
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "Down" of stack tStack
   catch tError
   end try
   TestAssert "T75: the line after the one selected, then after the text of the field named", gHCScriptsTest is "two|char 6 to 5|Notes"
   _Close tStack
end TestHyperCardScriptsT75

on TestHyperCardScriptsT11In
   -- T11's "in" for "of" between an object and the card, background or
   -- stack it is on, in a script that compiles here as it is ("hide card
   -- field "Sentence" in card 2", Teaching to Read; "get the id of first
   -- card in bkgnd id 2618", RefStak 88), where this engine stopped with
   -- "source is not a container"; and the "in"s it runs as they are: a
   -- count's, a text chunk's, the operator "is in"
   local tStack, tBg, tScript, tError, tFirst, q
   global gHCScriptsTest
   put quote into q
   put "HCScriptsT11In" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create field "Notes"
   create button "Next"
   group field "Notes" and button "Next"
   set the backgroundBehavior of group 1 to true
   set the name of group 1 to "Bg"
   put the id of group 1 into tBg
   put the id of card 1 into tFirst
   create card "Two"
   create field "Words"
   create card "Three"
   go to card 1 of stack tStack
   create button "In"
   put _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "x" & q & " into field " & q & "Words" & q & " in card 2", \
         "  hide card field " & q & "Words" & q & " in card 2", \
         "  get the short name of bg btn " & q & "Next" & q & " in this bkgnd", "  put it into gHCScriptsTest", \
         "  get the id of first card in bkgnd id " & tBg, "  put comma & it after gHCScriptsTest", \
         "  get the short name of card " & q & "Three" & q & " in this stack", "  put comma & it after gHCScriptsTest", \
         "  put comma & the number of card fields in card 2 after gHCScriptsTest", \
         "  put comma & word 1 in field " & q & "Words" & q & " of card 2 after gHCScriptsTest", \
         "  if " & q & "x" & q & " is in field " & q & "Words" & q & " of card 2 then put comma & " & q & "is in" & q & " after gHCScriptsTest", \
         "  find the short name of bg btn " & q & "Next" & q & " in bkgnd field " & q & "Notes" & q, \
         "end mouseUp") into tScript
   set the script of button "In" to tScript
   unlock messages
   TestAssert "T11: an object in a card compiles here as it is", _Compiles(tScript)
   get revHyperCardFixScripts(tStack)
   put the script of button "In" of card 1 of stack tStack into tScript
   TestAssert "T11: in for of before a card, in a script that compiles", line 3 to 4 of tScript is _Lines( \
         "  put " & q & "x" & q & " into field " & q & "Words" & q & " of card 2", "  hide card field " & q & "Words" & q & " of card 2")
   TestAssert "T11: in for of before this background, a background's id and this stack", line 5 to 9 of tScript is _Lines( \
         "  get the short name of bg btn " & q & "Next" & q & " of this bkgnd", "  put it into gHCScriptsTest", \
         "  get the id of first card of bkgnd id " & tBg, "  put comma & it after gHCScriptsTest", \
         "  get the short name of card " & q & "Three" & q & " of this stack")
   TestAssert "T11: a count's in, a text chunk's and is in, as they were", line 11 to 13 of tScript is _Lines( \
         "  put comma & the number of card fields in card 2 after gHCScriptsTest", \
         "  put comma & word 1 in field " & q & "Words" & q & " of card 2 after gHCScriptsTest", \
         "  if " & q & "x" & q & " is in field " & q & "Words" & q & " of card 2 then put comma & " & q & "is in" & q & " after gHCScriptsTest")
   TestAssert "T11: find's in, before the field it looks in, as it was", \
         line 14 of tScript is "  find the short name of bg btn " & q & "Next" & q & " in bkgnd field " & q & "Notes" & q
   put empty into gHCScriptsTest
   set the defaultStack to tStack
   try
      send "mouseUp" to button "In" of card 1 of stack tStack
   catch tError
   end try
   TestAssert "T11: the objects in a card, a background and a stack are found", tError is empty \
         and gHCScriptsTest is "Next," & tFirst & ",Three,1,x,is in"
   TestAssert "T11: the field in card 2 filled and hidden", field "Words" of card 2 of stack tStack is "x" \
         and the visible of field "Words" of card 2 of stack tStack is false
   _Close tStack
end TestHyperCardScriptsT11In

on TestHyperCardScriptsBuiltIns
   -- HyperCard's commands this engine does not have, as the rewritten
   -- scripts call them: cursors, key commands, card pictures, picture
   -- windows, flash
   local tStack, tImage, tCursor, q
   global gHCScriptsTest
   put quote into q
   put "HCBuiltIns" & the milliseconds into tStack
   lock messages
   create invisible stack tStack
   set the defaultStack to tStack
   create card
   go to card 1 of stack tStack
   set the script of card 1 of stack tStack to _Lines("on tabKey", "  global gHCScriptsTest", "  put " & q & "tab" & q & " into gHCScriptsTest", "end tabKey")
   create image
   put the long id of it into tImage
   create image "Blue"
   put the id of it into tCursor
   group it
   set the name of it to "HC cursors"
   set the sharedBehavior of it to true
   create image "Map"
   group it
   set the name of it to "HC Pictures"
   set the sharedBehavior of it to true
   create button "Cursor"
   set the script of button "Cursor" to _Lines("on mouseUp", "  global gHCScriptsTest", "  set cursor to 4", "  put hcCursor(4) & comma & hcCursor(" & q & "watch" & q & ") & comma & hcCursor(" & q & "busy" & q & ") & comma & hcCursor(" & tCursor & ") & comma & hcCursor(77777) & comma & hcCursor(" & q & "Blue" & q & ") & comma & hcCursor(" & q & "No such" & q & ") into gHCScriptsTest", "end mouseUp")
   create button "Tool"
   set the script of button "Tool" to _Lines("on mouseUp", "  global gHCScriptsTest", "  choose tool 4", "  put the tool into gHCScriptsTest", "  choose tool " & q & "Browse" & q, "  put comma & the tool after gHCScriptsTest", "  choose tool 99", "  put comma & the result after gHCScriptsTest", "end mouseUp")
   create button "Tab"
   set the script of button "Tab" to _Lines("on mouseUp", "  tabKey", "end mouseUp")
   create button "Arrow"
   set the script of button "Arrow" to _Lines("on mouseUp", "  arrowKey right", "end mouseUp")
   create button "Picture"
   set the script of button "Picture" to _Lines("on mouseUp", "  hide card picture", "end mouseUp")
   create button "Window"
   set the script of button "Window" to _Lines("on mouseUp", "  global gHCScriptsTest", "  picture " & q & "Map" & q & ", resource, plain, false", "  put there is a stack " & q & "Map" & q & " into gHCScriptsTest", "  close window " & q & "Map" & q, "  put comma & (there is a stack " & q & "Map" & q & ") after gHCScriptsTest", "  flash 1", "  put comma & the number of graphics of this card after gHCScriptsTest", "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)

   put empty into gHCScriptsTest
   send "mouseUp" to button "Cursor" of card 1 of stack tStack
   TestAssert "hcCursor: HyperCard's numbers and names, this engine's, the stack's own by id, a missing one, by name, none", gHCScriptsTest is "14,14,6," & tCursor & ",," & tCursor & ","

   put empty into gHCScriptsTest
   send "mouseUp" to button "Tool" of card 1 of stack tStack
   TestAssert "hcChooseTool: by HyperCard's number, by name, none", gHCScriptsTest is "select tool,browse tool,No such tool"

   put empty into gHCScriptsTest
   send "mouseUp" to button "Tab" of card 1 of stack tStack
   TestAssert "tabKey: the message goes to the card", gHCScriptsTest is "tab"

   send "mouseUp" to button "Arrow" of card 1 of stack tStack
   TestAssert "arrowKey right: no handler, the next card", the number of this card of stack tStack is 2
   go to card 1 of stack tStack

   send "mouseUp" to button "Picture" of card 1 of stack tStack
   TestAssert "hide card picture: the card's image with no name hidden", not the visible of tImage

   put empty into gHCScriptsTest
   send "mouseUp" to button "Window" of card 1 of stack tStack
   TestAssert "picture opens a window, close window closes it, flash leaves nothing", gHCScriptsTest is "true,false,0"

   -- a picture window's scroll and a palette's hilitedButton
   lock messages
   create button "Scroll" in card 1 of stack tStack
   set the script of button "Scroll" of card 1 of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  picture " & q & "Map" & q & ", resource, plain, false", \
         "  set the scroll of window " & q & "Map" & q & " to 10,20", \
         "  put the topLeft of image " & q & "Picture" & q & " of stack " & q & "Map" & q & " into gHCScriptsTest", \
         "  close window " & q & "Map" & q, \
         "  set the scale of window " & q & "Map" & q & " to 1", \
         "  put comma & the result after gHCScriptsTest", \
         "  set the hilitedButton of window " & q & "HCBuiltInsPalette" & q & " to 2", \
         "  put comma & the hilite of button 1 of stack " & q & "HCBuiltInsPalette" & q & " & comma & the hilite of button 2 of stack " & q & "HCBuiltInsPalette" & q & " after gHCScriptsTest", \
         "end mouseUp")
   create invisible stack "HCBuiltInsPalette"
   set the defaultStack to "HCBuiltInsPalette"
   create button
   create button
   set the defaultStack to tStack
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Scroll" of card 1 of stack tStack
   TestAssert "the scroll of a picture window; a window not open; the hilitedButton of a palette", gHCScriptsTest is "-10,-20,No such window,false,true"
   _Close "HCBuiltInsPalette"

   -- HyperCard 2.2's menus, kept as the scripts make them
   lock messages
   create button "Menus" in card 1 of stack tStack
   set the script of button "Menus" of card 1 of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  put " & q & "One,Two,Three..." & q & " into menu " & q & "Tools" & q & " with menuMsgs " & q & "m1,m2,m3" & q, \
         "  disable menuItem " & q & "Two" & q & " of menu " & q & "Tools" & q, \
         "  set the checkMark of menuItem 1 of menu " & q & "Tools" & q & " to true", \
         "  put the checkMark of menuItem 1 of menu " & q & "Tools" & q & " & comma & the enabled of menuItem " & q & "Two" & q & " of menu " & q & "Tools" & q & " into gHCScriptsTest", \
         "  put comma & the name of menuItem " & q & "Three" & q & " of menu " & q & "Tools" & q & " after gHCScriptsTest", \
         "  delete menuItem 1 of menu " & q & "Tools" & q, \
         "  put comma & the name of menuItem 1 of menu " & q & "Tools" & q & " after gHCScriptsTest", \
         "  put comma & hcMenuMessage(" & q & "Two" & q & ") after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Menus" of card 1 of stack tStack
   TestAssert "HyperCard menus: items, checkmarks, enabled, delete, menu messages", gHCScriptsTest is "true,false,Three...,Two,m2"

   -- start using a stack HyperCard found by name, and one it could not
   lock messages
   create invisible stack "HCBuiltInsLib"
   create button "Using" in card 1 of stack tStack
   set the script of button "Using" of card 1 of stack tStack to _Lines("on mouseUp", "  global gHCScriptsTest", \
         "  start using stack " & q & "No Such Library" & q, \
         "  put the result into gHCScriptsTest", \
         "  start using stack " & q & "HCBuiltInsLib" & q, \
         "  put comma & (" & q & "HCBuiltInsLib" & q & " is among the lines of the stacksInUse) after gHCScriptsTest", \
         "  stop using stack " & q & "HCBuiltInsLib" & q, \
         "  put comma & (" & q & "HCBuiltInsLib" & q & " is among the lines of the stacksInUse) after gHCScriptsTest", \
         "end mouseUp")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   send "mouseUp" to button "Using" of card 1 of stack tStack
   TestAssert "start using: a stack not found goes on with the result", gHCScriptsTest is "Can't find stack No Such Library,true,false"
   _Close "HCBuiltInsLib"
   _Close tStack
end TestHyperCardScriptsBuiltIns
